class_name Battle
extends RefCounted
## 1 回の対戦の状態（盤面と、盤上の駒）。
##
## 状態を変えるのは apply() だけ。行動（Action）を受け取り、起きたこと（イベント）の列を返す。
## 見た目の側はイベントを順に再生する。受け付けられない行動には空の列を返し、状態は変えない。

var board: Board
var units: Array[Unit] = []

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


## 行動を受け付けて状態を進め、起きたことを返す。受け付けられなければ空の列。
func apply(action: Variant) -> Array:
	if not action.is_valid(self):
		return []
	return action.execute(self)
