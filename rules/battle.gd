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
## 行動の途中の駒が動く前の capture_turns。移動を取り消したときに戻す。
var capture_turns_before_move: Array[int] = [0, 0]

## 敵の本陣をこの回数だけ自分のフェーズの終わりまで占拠し続けたら勝ち。
const CAPTURE_TURNS_TO_WIN := 3

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
## 装備を持たせられる。装備を持てない種類（将・中立）に持たせるか、持てる数を超えていれば null。
func add_unit(
	kind: UnitKind.Id, side: Unit.Side, cell: Vector2i, equipment: Array[Equipment.Id] = []
) -> Unit:
	if not board.is_walkable(cell) or unit_at(cell) != null:
		return null
	if equipment.size() > Equipment.MAX_PER_UNIT:
		return null
	if not equipment.is_empty() and not Equipment.can_equip(kind):
		return null
	var unit := Unit.new(_next_unit_id, kind, side, cell, equipment)
	_next_unit_id += 1
	units.append(unit)
	return unit


## 倒れた駒を盤から取り除く。
func remove_unit(unit: Unit) -> UnitDefeatedEvent:
	units.erase(unit)
	if acting_unit_id == unit.id:
		acting_unit_id = 0
	return UnitDefeatedEvent.new(unit)


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


## player が敵の本陣に自分の駒を乗せているか。
func occupies_enemy_hq(player: Unit.Side) -> bool:
	if board.hq_cells.size() < 2:
		return false
	var occupant := unit_at(board.hq_cells[1 - player])
	return occupant != null and occupant.side == player


## player のフェーズの終わりに、敵の本陣の占拠を数える。乗せていれば 1 進め、いなければ 0 に戻す。
## 数が変わったときだけイベントを出す。規定の回数に達したら勝ち。
func count_capture(player: Unit.Side) -> Array[BattleEvent]:
	var before := capture_turns[player]
	capture_turns[player] = before + 1 if occupies_enemy_hq(player) else 0
	var events: Array[BattleEvent] = []
	if capture_turns[player] != before:
		events.append(CaptureProgressEvent.new(player, capture_turns[player]))
	if capture_turns[player] >= CAPTURE_TURNS_TO_WIN:
		winner = player
		events.append(GameWonEvent.new(player, GameWonEvent.Reason.HQ_CAPTURED))
	return events


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
func apply(action: BattleAction) -> ActionResult:
	if not can_apply(action):
		return ActionResult.rejected()
	var events := action.execute(self)
	events.append_array(settle(events))
	return ActionResult.new(true, events)


## 起きたこと（events）のあとに決まること。決まったことのイベントを返す。
## apply() が行動のあとに呼ぶ。中立のフェーズは駒 1 体の行動ごとに呼ぶ（決着したら、その先へ進まない）。
## 同じイベントで 2 度呼んでも、2 度目は何も起きない。
## - 将が倒れたら、相手のプレイヤーの勝ち。両方の将が同じ行動で倒れたら、引き分け
## - 敵の本陣から自分の駒がいなくなったら、占拠の数を 0 に戻す（フェーズの終わりを待たない）
func settle(events: Array[BattleEvent]) -> Array[BattleEvent]:
	var extra: Array[BattleEvent] = []
	var fallen: Array[Unit.Side] = []  # 将が倒れたプレイヤー
	for event in events:
		var defeated := event as UnitDefeatedEvent
		if defeated == null or defeated.kind != UnitKind.Id.KING:
			continue
		if defeated.side != Unit.Side.NEUTRAL and not fallen.has(defeated.side):
			fallen.append(defeated.side)
	if not is_over() and fallen.size() == 2:
		drawn = true
		extra.append(GameDrawnEvent.new(GameDrawnEvent.Reason.BOTH_KINGS_DEFEATED))
	elif not is_over() and fallen.size() == 1:
		winner = 1 - fallen[0]
		extra.append(GameWonEvent.new(winner, GameWonEvent.Reason.KING_DEFEATED))
	for player: Unit.Side in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
		if capture_turns[player] > 0 and not occupies_enemy_hq(player):
			capture_turns[player] = 0
			extra.append(CaptureProgressEvent.new(player, 0))
	return extra
