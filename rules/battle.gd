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


## 行動を受け付けて状態を進め、起きたことを返す。受け付けられなければ空の列。
func apply(action: Variant) -> Array:
	if not action.is_valid(self):
		return []
	return action.execute(self)
