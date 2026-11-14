class_name Battle
extends RefCounted
## 1 回の対戦の状態（盤面と、盤上の駒）。
##
## 状態を変えるのは apply() だけ。行動（Action）を受け取り、起きたこと（イベント）の列を返す。
## 見た目の側はイベントを順に再生する。受け付けられない行動には空の列を返し、状態は変えない。
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

## 敵の本陣をこの回数だけ自分のフェーズの終わりまで占拠し続けたら勝ち。
const CAPTURE_TURNS_TO_WIN := 3

var _next_unit_id := 1


func _init(battle_board: Board) -> void:
	board = battle_board


## 駒を置く（対戦の準備用）。置けないマスなら null。
func add_unit(kind: UnitKind.Id, side: Unit.Side, cell: Vector2i) -> Unit:
	if not board.is_walkable(cell) or unit_at(cell) != null:
		return null
	var unit := Unit.new(_next_unit_id, kind, side, cell)
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
func count_capture(player: Unit.Side) -> Array:
	var before := capture_turns[player]
	capture_turns[player] = before + 1 if occupies_enemy_hq(player) else 0
	var events: Array = []
	if capture_turns[player] != before:
		events.append(CaptureProgressEvent.new(player, capture_turns[player]))
	if capture_turns[player] >= CAPTURE_TURNS_TO_WIN:
		winner = player
		events.append(GameWonEvent.new(player, GameWonEvent.Reason.HQ_CAPTURED))
	return events


## 行動を受け付けて状態を進め、起きたことを返す。受け付けられなければ空の列。
func apply(action: Variant) -> Array:
	if is_over() or not action.is_valid(self):
		return []
	var events: Array = action.execute(self)
	events.append_array(_after_action(events))
	return events


## 行動のあとに決まること。
## - 将が倒れたら、相手のプレイヤーの勝ち
## - 敵の本陣から自分の駒がいなくなったら、占拠の数を 0 に戻す（フェーズの終わりを待たない）
func _after_action(events: Array) -> Array:
	var extra: Array = []
	for event in events:
		if event is UnitDefeatedEvent and event.kind == UnitKind.Id.KING and not is_over():
			if event.side == Unit.Side.PLAYER1 or event.side == Unit.Side.PLAYER2:
				winner = 1 - event.side
				extra.append(GameWonEvent.new(winner, GameWonEvent.Reason.KING_DEFEATED))
	for player in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
		if capture_turns[player] > 0 and not occupies_enemy_hq(player):
			capture_turns[player] = 0
			extra.append(CaptureProgressEvent.new(player, 0))
	return extra
