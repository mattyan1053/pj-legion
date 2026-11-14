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

var board: Board
var units: Array[Unit] = []
var turn := 1
## いまのフェーズ。どの陣営の番かで表す。
var phase := Unit.Side.PLAYER1
## 行動の途中（動いたが、攻撃も待機もしていない）の駒の番号。いなければ 0。
var acting_unit_id := 0
## 勝った陣営（Unit.Side の値）。決着していなければ -1。決着したあとは、どの行動も受け付けない。
var winner := -1
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
## ZOC は前衛の駒の周り 8 マス（駒のいるマスそのものは含まない）。
func is_in_enemy_zoc(cell: Vector2i, side: Unit.Side) -> bool:
	for unit in units:
		if unit.side == side or not UnitKind.exerts_zoc(unit.kind):
			continue
		var d := (cell - unit.cell).abs()
		if maxi(d.x, d.y) == 1:
			return true
	return false


## その駒が、いま行動できるか（自分のフェーズで、行動済みでなく、ほかの駒が行動の途中でない）。
func can_act(unit: Unit) -> bool:
	return (
		unit != null
		and unit.side == phase
		and phase != Unit.Side.NEUTRAL
		and not unit.acted
		and (acting_unit_id == 0 or acting_unit_id == unit.id)
	)


## 駒の行動を終える（行動済みにする）。
func finish_action(unit: Unit) -> UnitActedEvent:
	unit.acted = true
	unit.has_moved = false
	unit.cruised = false
	if acting_unit_id == unit.id:
		acting_unit_id = 0
	return UnitActedEvent.new(unit.id)


func is_over() -> bool:
	return winner != -1


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


## いまの状態で、その行動を受け付けるか。状態は変えない。
func can_apply(action: BattleAction) -> bool:
	return not is_over() and action.is_valid(self)


## 行動を受け付けて状態を進め、起きたことを返す。受け付けられなければ、何も変えずに断る。
func apply(action: BattleAction) -> ActionResult:
	if not can_apply(action):
		return ActionResult.rejected()
	var events := action.execute(self)
	events.append_array(_after_action(events))
	return ActionResult.new(true, events)


## 行動のあとに決まること。
## - 将が倒れたら、相手のプレイヤーの勝ち
## - 敵の本陣から自分の駒がいなくなったら、占拠の数を 0 に戻す（フェーズの終わりを待たない）
func _after_action(events: Array[BattleEvent]) -> Array[BattleEvent]:
	var extra: Array[BattleEvent] = []
	for event in events:
		var defeated := event as UnitDefeatedEvent
		if defeated == null or defeated.kind != UnitKind.Id.KING or is_over():
			continue
		if defeated.side == Unit.Side.PLAYER1 or defeated.side == Unit.Side.PLAYER2:
			winner = 1 - defeated.side
			extra.append(GameWonEvent.new(winner, GameWonEvent.Reason.KING_DEFEATED))
	for player: Unit.Side in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
		if capture_turns[player] > 0 and not occupies_enemy_hq(player):
			capture_turns[player] = 0
			extra.append(CaptureProgressEvent.new(player, 0))
	return extra
