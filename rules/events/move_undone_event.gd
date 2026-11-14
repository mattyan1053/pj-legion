class_name MoveUndoneEvent
extends BattleEvent
## 移動が取り消され、駒が from から to（動く前のマス）へ戻った。

var unit_id: int
var from: Vector2i
var to: Vector2i


func _init(undone_unit_id: int, moved_to: Vector2i, back_to: Vector2i) -> void:
	unit_id = undone_unit_id
	from = moved_to
	to = back_to
