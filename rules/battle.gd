class_name Battle
extends RefCounted
## 1 回の対戦の状態（盤面と、盤上の駒）。
##
## 状態を変えるのは apply() だけ。行動（BattleAction）を受け取り、結果（ActionResult）を返す。
## 結果は、受け付けたかどうかと、起きたこと（BattleEvent）の列。見た目の側はイベントを順に再生する。
## 断った行動では、状態は何も変わらない。
##
## clone() で複製できる。複製に apply() しても元は変わらない（戦闘予測や CPU の先読みに使う）。
## 確率で決まるルールは、rng だけを使う（同じシードなら同じ結果になり、複製も元と同じ続きを引く）。
##
## 1 ターンは プレイヤー1 → プレイヤー2 → 中立 のフェーズで進む。
## プレイヤーのフェーズでは、そのプレイヤーの駒が 1 体ずつ「移動 → 攻撃か待機」で行動する。
## 行動中の駒がいる間は、ほかの駒は行動を始められない。
## レベルが上限に届いた駒がいたら、持ち主が進化先を選ぶ（EvolveAction）まで、ほかの行動は受け付けない。

var board: Board
var units: Array[Unit] = []
var turn := 1
## いまのフェーズ。どの陣営の番かで表す。
var phase := Unit.Side.PLAYER1
## 行動の途中（動いたが、攻撃も待機もしていない）の駒の番号。いなければ 0。
var acting_unit_id := 0
## 勝った陣営（Unit.Side の値）。決着していないか、引き分けなら -1。
## 決着したか（is_over）と、引き分けか（is_draw）は別に見る。決着したあとは、どの行動も受け付けない。
var winner := -1
## 引き分けで決着したか（両方の将が同時に倒れた）。
var drawn := false
## プレイヤーごとの、敵の本陣を占拠し続けたフェーズの数。添字がプレイヤー番号。
var capture_turns: Array[int] = [0, 0]
## プレイヤーごとの、拠点の確保の数（拠点。Stronghold）。添字がプレイヤー番号。
var stronghold_holds: Array[int] = [0, 0]
## 行動の途中の駒が動く前の capture_turns。移動を取り消したときに戻す。
var capture_turns_before_move: Array[int] = [0, 0]

## 敵の本陣をこの回数だけ自分のフェーズの終わりまで占拠し続けたら勝ち。
const CAPTURE_TURNS_TO_WIN := 3

## プレイヤーごとの勝ちの条件の列（GameWonEvent.Reason の値。docs/win-conditions.md）。添字がプレイヤー番号。
## 対戦を作るとき（MatchSetup.create_battle）に、戦いの定義（Scenario.win_conditions）から写す。
## 既定は、いまの対戦モードの勝ち方（Scenario.STANDARD_WIN_CONDITIONS）。
var win_conditions: Array[Array] = [
	Scenario.STANDARD_WIN_CONDITIONS.duplicate(), Scenario.STANDARD_WIN_CONDITIONS.duplicate()
]
## 「守り切る」（GameWonEvent.Reason.TURNS_HELD）のターン数。このターンの終わり（中立のフェーズのあと）まで決着しなければ、
## 守り切るが勝ちの条件にあるプレイヤーの勝ち。対戦を作るとき、戦いの定義（Scenario.hold_turns）から写す。
var hold_turns := 0

## プレイヤーごとの軍（添字がプレイヤー番号）。必殺技は軍で決まる（docs/tactical-ult.md）。
## 軍を盤に置くとき（Deployment）に決まる。決まっていなければ、最初に置いた、軍に属する駒の軍になる（add_unit）。
var armies: Array[UnitKind.Army] = [UnitKind.Army.NONE, UnitKind.Army.NONE]
## プレイヤーごとの必殺技のゲージ（0 から Ults.GAUGE_MAX）と、使った回数。ためる・使うのは Ults だけ。
var ult_gauge: Array[int] = [0, 0]
var ult_uses: Array[int] = [0, 0]

## 倒れた中ボス -> 倒した陣営（docs/neutral-mid-boss.md）。キーは中ボスの番号（Board.mid_boss_cells の添字）。
## 値は MidBossDefeatedEvent.slayer_side と同じ（止めを刺した駒がいなければ -1）。倒れた中ボスは湧き直さない。
var mid_boss_slayers: Dictionary[int, int] = {}
## プレイヤーごとの、持っている聖遺物（Relics.Id の並び。受け取った順）。添字がプレイヤー番号。docs/relic-buff.md。
## 足すのは Relics.grant だけ（駒の聖遺物の層と、そろえて変える）。
var relics: Array[Array] = [[], []]

## 組み方（選べる決まり OptionalRules.FORMATION。Formation）が入の対戦か。対戦を作るとき（MatchSetup.create_battle）に決まる。
var formation := false
## このフェーズに、分隊の駒が攻撃した相手（駒の番号 -> 攻撃した駒の (番号, 兵種) の並び）。追い撃ち（Formation）が読む。フェーズの始めに空になる。
var focus_marks: Dictionary[int, Array] = {}

## この対戦でめくられた縫い目の様子の札（Seam.Sign の並び。選べる決まり OptionalRules.SEAM）。対戦を作るとき（MatchSetup.create_battle）に決まる。空なら札は無い。
var signs: Array[int] = []

## ルールが使う、ただ 1 つの乱数。ほかの乱数を使うと、シードを固定しても結果がそろわない。
var rng := RandomNumberGenerator.new()

var _next_unit_id := 1


func _init(battle_board: Board, rng_seed := 0) -> void:
	board = battle_board
	rng.seed = rng_seed


## 状態を丸ごと複製する。複製と元は、どちらに apply() してももう片方に影響しない。
## 駒の番号は元と同じなので、同じ行動をどちらにも渡せる。乱数は元と同じ続きを引く。
func clone() -> Battle:
	var copy := Battle.new(board.copy())
	StateCopy.copy_fields(self, copy, [&"board", &"units", &"rng"])
	for unit in units:
		copy.units.append(unit.copy())
	copy.rng.seed = rng.seed
	copy.rng.state = rng.state
	return copy


## 駒を置く（対戦の準備用）。置けないマスなら null。
## 装備を持たせられる。その種類が持てない装備の並び（将・中立に持たせる、数の上限、重ねて持てる数、役割の限り。Equipment.is_valid_for）なら null。
func add_unit(
	kind: UnitKind.Id, side: Unit.Side, cell: Vector2i, equipment: Array[Equipment.Id] = []
) -> Unit:
	if not board.is_walkable(cell) or unit_at(cell) != null:
		return null
	if not Equipment.is_valid_for(kind, equipment):
		return null
	var unit := Unit.new(_next_unit_id, kind, side, cell, equipment)
	_next_unit_id += 1
	units.append(unit)
	if side != Unit.Side.NEUTRAL and armies[side] == UnitKind.Army.NONE:
		armies[side] = UnitKind.army(kind)
	Relics.equip(self, unit)  # 聖遺物を取ったあとに置かれた駒にも、効果が掛かる
	Seam.equip(self, unit)  # 縫い目の様子の札（射程・移動力・回復量。最大 HP は変えない）
	unit.site_range = MapObject.battery_bonus(board, unit, unit.cell)
	return unit


## 倒れた駒を盤から取り除く。by は止めを刺した駒（攻撃した駒、スキルを使った駒、爆発した樽を攻撃した駒）。
## 返すのは UnitDefeatedEvent。組み方が入で、誓いを結んだ駒なら、続けて誓いが切れる（Formation.on_defeated）。中ボスなら、続けて MidBossDefeatedEvent（倒した陣営を mid_boss_slayers に控える）と、
## 倒した陣営がいれば RelicGainedEvent（その中ボスの聖遺物を受け取る。Relics.grant）。
## 倒れると何か起きる魔物なら、続けてそのイベント（骸骨旗手の奮起、ほつれの結び目。Monsters.on_defeated）。
func remove_unit(unit: Unit, by: Unit = null) -> Array[BattleEvent]:
	units.erase(unit)
	if acting_unit_id == unit.id:
		acting_unit_id = 0
	Ults.charge_defeat(self, unit)
	var events: Array[BattleEvent] = [UnitDefeatedEvent.new(unit)]
	events.append_array(Formation.on_defeated(self, unit))
	events.append_array(Monsters.on_defeated(self, unit))
	var boss_index := mid_boss_index(unit)
	if boss_index != -1:
		var slayer := by if by != null and by.side != Unit.Side.NEUTRAL else null
		var event := MidBossDefeatedEvent.new(boss_index, unit, slayer)
		mid_boss_slayers[boss_index] = event.slayer_side
		events.append(event)
		var relic := Relics.of_boss(boss_index)
		if slayer != null and relic != -1:
			events.append_array(Relics.grant(self, slayer.side, relic as Relics.Id, boss_index))
	return events


## 駒が中ボスなら、その番号（Board.mid_boss_cells の添字）。中ボスでなければ -1。
func mid_boss_index(unit: Unit) -> int:
	if unit.kind != UnitKind.Id.ELITE_MINION:
		return -1
	return board.mid_boss_cells.find(unit.home_cell)


## 中ボスが倒れたか。
func is_mid_boss_defeated(boss_index: int) -> bool:
	return mid_boss_slayers.has(boss_index)


func unit_at(cell: Vector2i) -> Unit:
	for unit in units:
		if unit.cell == cell:
			return unit
	return null


func unit_by_id(unit_id: int) -> Unit:
	for unit in units:
		if unit.id == unit_id:
			return unit
	return null


## そのマスが、side から見て敵の支配領域（ZOC）に入っているか。
## ZOC は、ZOC を作る駒（Unit.exerts_zoc）の周り 8 マス（駒のいるマスそのものは含まない）。
## ZOC で止まらない駒（Unit.ignores_zoc）にとっての判定は、移動の側（Movement）が見る。
func is_in_enemy_zoc(cell: Vector2i, side: Unit.Side) -> bool:
	for unit in units:
		if unit.side == side or not unit.exerts_zoc():
			continue
		var d := (cell - unit.cell).abs()
		if maxi(d.x, d.y) == 1:
			return true
	return false


## 進化先を選ぶのを待っている駒。いなければ null。
## いる間は、その駒の EvolveAction のほかは受け付けない（can_apply）。選ぶのは、その駒の持ち主（いまのフェーズのプレイヤー）。
func evolving_unit() -> Unit:
	for unit in units:
		if unit.evolution_ready:
			return unit
	return null


## その駒が、いま行動できるか（自分のフェーズで、行動済みでなく、ほかの駒が行動の途中でなく、進化先を選ぶ途中でもない）。
func can_act(unit: Unit) -> bool:
	return (
		unit != null
		and unit.side == phase
		and phase != Unit.Side.NEUTRAL
		and not unit.acted
		and (acting_unit_id == 0 or acting_unit_id == unit.id)
		and evolving_unit() == null
	)


## 駒の行動を終える（行動済みにする）。
func finish_action(unit: Unit) -> UnitActedEvent:
	unit.acted = true
	unit.has_moved = false
	unit.cruised = false
	unit.move_locked = false
	unit.clear_move_steps()
	if acting_unit_id == unit.id:
		acting_unit_id = 0
	return UnitActedEvent.new(unit.id)


## 駒を、行動の途中のままにする（行動を終えないスキルを使ったあと。Skills.use）。
## 動いたあとと同じ扱いになる: もう動けず、攻撃・待機で行動を終える。ほかの駒は行動を始められない。
## ただし、移動の取り消しはできない（スキルを使う前には戻れない）。
func hold_action(unit: Unit) -> void:
	acting_unit_id = unit.id
	unit.has_moved = true
	unit.move_origin = unit.cell
	unit.move_locked = true
	unit.can_keep_moving = false
	unit.just_warped = false


## 決着したか（どちらかが勝ったか、引き分け）。
func is_over() -> bool:
	return winner != -1 or drawn


## 引き分けで決着したか。
func is_draw() -> bool:
	return drawn


## そのマスのポータルから移れる先。ポータルでないか、行き先にほかの駒（陣営を問わない）がいれば Board.NO_CELL。
func portal_exit(cell: Vector2i) -> Vector2i:
	var exit := board.portal_exit(cell)
	if exit != Board.NO_CELL and unit_at(exit) != null:
		return Board.NO_CELL
	return exit


## side の駒が盤に残っているか。
func _has_units(side: Unit.Side) -> bool:
	for unit in units:
		if unit.side == side:
			return true
	return false


## player が、その勝ち方（GameWonEvent.Reason）で勝てるか。
func wins_by(player: Unit.Side, condition: GameWonEvent.Reason) -> bool:
	return win_conditions[player].has(condition)


## player が敵の本陣に自分の駒を乗せているか。
func occupies_enemy_hq(player: Unit.Side) -> bool:
	if board.hq_cells.size() < 2:
		return false
	var occupant := unit_at(board.hq_cells[1 - player])
	return occupant != null and occupant.side == player


## player のフェーズの終わりに、敵の本陣の占拠を数える。乗せていれば 1 進め、いなければ 0 に戻す。
## 数が変わったときだけイベントを出す。規定の回数に達したら勝ち。
## 占拠が勝ちの条件に無いプレイヤーは数えない（数は 0 のまま。イベントも出さない）。
func count_capture(player: Unit.Side) -> Array[BattleEvent]:
	if not wins_by(player, GameWonEvent.Reason.HQ_CAPTURED):
		return []
	var before := capture_turns[player]
	capture_turns[player] = before + 1 if occupies_enemy_hq(player) else 0
	var events: Array[BattleEvent] = []
	if capture_turns[player] != before:
		events.append(CaptureProgressEvent.new(player, capture_turns[player]))
	if capture_turns[player] >= CAPTURE_TURNS_TO_WIN:
		winner = player
		events.append(GameWonEvent.new(player, GameWonEvent.Reason.HQ_CAPTURED))
	return events


## 守り切るまでの残りのターン数（いまのターンを含む）。守り切るが、どちらの勝ちの条件にも無ければ -1。
func turns_left() -> int:
	if _holder() == -1:
		return -1
	return maxi(0, hold_turns - turn + 1)


## ターンの終わり（中立のフェーズのあと。次のターンへ進む前）に決まること。
## 守り切るターン数のターンが終わったら、守り切るが勝ちの条件にあるプレイヤーの勝ち。
func end_turn() -> Array[BattleEvent]:
	var holder := _holder()
	if is_over() or holder == -1 or turn < hold_turns:
		return []
	winner = holder
	return [GameWonEvent.new(holder as Unit.Side, GameWonEvent.Reason.TURNS_HELD)]


## 守り切るが勝ちの条件にあるプレイヤー。いなければ -1。両方にあれば、プレイヤー1（両方に置く定義は作らない）。
func _holder() -> int:
	if hold_turns <= 0:
		return -1
	for player: Unit.Side in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
		if wins_by(player, GameWonEvent.Reason.TURNS_HELD):
			return player
	return -1


## 駒がいま選べること（動けるマス、攻撃・回復できる相手、待機・取り消し、進化先）。状態は変えない。
## can_apply() が受け付ける行動と一致する。行動できない駒・いない駒では、すべて空。
func options(unit_id: int) -> UnitOptions:
	return UnitOptions.of(self, unit_id)


## いまの状態で、その行動を受け付けるか。状態は変えない。
func can_apply(action: BattleAction) -> bool:
	if is_over():
		return false
	if evolving_unit() != null and not action is EvolveAction:
		return false  # 進化先を選ぶまで、ほかの行動は待たせる
	return action.is_valid(self)


## 行動を受け付けて状態を進め、起きたことを返す。受け付けられなければ、何も変えずに断る。
## 砲台の上の後衛の射程を付け直す（MapObject.battery_bonus）。駒を置いたときと、行動のたびに呼ぶ。砲台の無い盤では何もしない。
func refresh_sites() -> void:
	if board.battery_cells.is_empty():
		return
	for unit in units:
		unit.site_range = MapObject.battery_bonus(board, unit, unit.cell)


func apply(action: BattleAction) -> ActionResult:
	if not can_apply(action):
		return ActionResult.rejected()
	var ready: Array[bool] = [Ults.is_ready(self, Unit.Side.PLAYER1), Ults.is_ready(self, Unit.Side.PLAYER2)]
	var events := action.execute(self)
	refresh_sites()
	events.append_array(settle(events))
	# 必殺技のゲージは、ダメージ・撃破・フェーズの始めにたまる。この行動でいっぱいになったら、最後に知らせる。
	for side: Unit.Side in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
		if not ready[side] and Ults.is_ready(self, side) and not is_over():
			events.append(UltReadyEvent.new(side, Ults.of(self, side).id()))
	return ActionResult.new(true, events)


## 起きたこと（events）のあとに決まること。決まったことのイベントを返す。
## apply() が行動のあとに呼ぶ。中立のフェーズは駒 1 体の行動ごとに呼ぶ（決着したら、その先へ進まない）。
## 同じイベントで 2 度呼んでも、2 度目は何も起きない。
## - 将が倒れたら、相手のプレイヤーの勝ち。両方の将が同じ行動で倒れたら、引き分け。
##   将の撃破が勝ちの条件に無いプレイヤーは、相手の将を倒しても勝たない
## - 全滅が勝ちの条件にあるプレイヤーは、相手の駒が盤に 1 体も残っていなければ勝ち（将の撃破のあとに見る）
## - 中ボスの撃破が勝ちの条件にあるプレイヤーは、どちらかの中ボスに止めを刺したら勝ち（聖遺物を受け取ったあと。全滅のあとに見る）
## - 敵の本陣から自分の駒がいなくなったら、占拠の数を 0 に戻す（フェーズの終わりを待たない）
func settle(events: Array[BattleEvent]) -> Array[BattleEvent]:
	var extra: Array[BattleEvent] = []
	var fallen: Array[Unit.Side] = []  # 将が倒れて、負けるプレイヤー（相手が将の撃破で勝てるもの）
	for event in events:
		var defeated := event as UnitDefeatedEvent
		if defeated == null or defeated.kind != UnitKind.Id.KING:
			continue
		if defeated.side == Unit.Side.NEUTRAL or fallen.has(defeated.side):
			continue
		if wins_by((1 - defeated.side) as Unit.Side, GameWonEvent.Reason.KING_DEFEATED):
			fallen.append(defeated.side)
	if not is_over() and fallen.size() == 2:
		drawn = true
		extra.append(GameDrawnEvent.new(GameDrawnEvent.Reason.BOTH_KINGS_DEFEATED))
	elif not is_over() and fallen.size() == 1:
		winner = 1 - fallen[0]
		extra.append(GameWonEvent.new(winner, GameWonEvent.Reason.KING_DEFEATED))
	for player: Unit.Side in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
		if not is_over() and wins_by(player, GameWonEvent.Reason.ROUTED) and not _has_units((1 - player) as Unit.Side):
			winner = player
			extra.append(GameWonEvent.new(player, GameWonEvent.Reason.ROUTED))
	for event in events:
		var slain := event as MidBossDefeatedEvent
		if is_over() or slain == null or slain.slayer_side < 0:
			continue
		if wins_by(slain.slayer_side as Unit.Side, GameWonEvent.Reason.BOSS_SLAIN):
			winner = slain.slayer_side
			extra.append(GameWonEvent.new(winner, GameWonEvent.Reason.BOSS_SLAIN))
	for player: Unit.Side in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
		if capture_turns[player] > 0 and not occupies_enemy_hq(player):
			capture_turns[player] = 0
			extra.append(CaptureProgressEvent.new(player, 0))
	return extra
