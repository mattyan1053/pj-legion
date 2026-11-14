class_name SpringHealedEvent
extends UnitHealedEvent
## 駒が、フェーズの始めに回復の泉で回復した。cell は泉のマス（駒のいるマス）。回復した駒は持たない。

var cell: Vector2i


func _init(spring_cell: Vector2i, healed_unit_id: int, healed: int, hp_after: int) -> void:
	cell = spring_cell
	unit_id = healed_unit_id
	amount = healed
	hp = hp_after
	cause = Cause.SPRING
