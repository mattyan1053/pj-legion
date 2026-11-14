class_name UnitDefeatedEvent
extends RefCounted
## 駒が倒れ、盤から取り除かれた。cell は倒れたマス。

var unit_id: int
var cell: Vector2i


func _init(defeated_unit_id: int, at: Vector2i) -> void:
	unit_id = defeated_unit_id
	cell = at
