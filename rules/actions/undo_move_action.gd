class_name UndoMoveAction
extends RefCounted
## 動いたあと、攻撃も待機もしていない駒を、動く前のマスへ戻す。駒は行動前の状態に戻る。

var unit_id: int


func _init(moved_unit_id: int) -> void:
	unit_id = moved_unit_id


func is_valid(battle: Battle) -> bool:
	var unit := battle.unit_by_id(unit_id)
	return battle.can_act(unit) and unit.has_moved


func execute(battle: Battle) -> Array:
	var unit := battle.unit_by_id(unit_id)
	var from := unit.cell
	unit.cell = unit.move_origin
	unit.has_moved = false
	unit.cruised = false
	battle.acting_unit_id = 0
	return [MoveUndoneEvent.new(unit.id, from, unit.cell)]
