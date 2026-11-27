class_name UnitPushedEvent
extends BattleEvent
## 駒が、札（押し出し）で from から隣の to へ動かされた。移動ではない（移動力を使わず、取り消せない）。

var unit_id: int
var from: Vector2i
var to: Vector2i


func _init(pushed_unit_id: int, left: Vector2i, landed: Vector2i) -> void:
	unit_id = pushed_unit_id
	from = left
	to = landed
