class_name MoveAction
extends RefCounted
## 駒を移動範囲の中のマスへ動かす。巡航なら移動力は 2 倍。
##
## いまのマスを行き先にしてもよい（動かない移動）。

var unit_id: int
var to: Vector2i
var cruise: bool


func _init(moving_unit_id: int, destination: Vector2i, is_cruise := false) -> void:
	unit_id = moving_unit_id
	to = destination
	cruise = is_cruise


func is_valid(battle: Battle) -> bool:
	var unit := battle.unit_by_id(unit_id)
	return unit != null and Movement.reachable(battle, unit, cruise).has(to)


func execute(battle: Battle) -> Array:
	var unit := battle.unit_by_id(unit_id)
	var path := Movement.path_to(battle, unit, to, cruise)
	unit.cell = to
	return [UnitMovedEvent.new(unit_id, path)]
