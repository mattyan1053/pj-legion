class_name UnitActedEvent
extends RefCounted
## 駒がこのフェーズの行動を終えた（行動済みになった）。

var unit_id: int


func _init(acted_unit_id: int) -> void:
	unit_id = acted_unit_id
