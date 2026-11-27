class_name CutTurnedEvent
extends BattleEvent
## 台本の出来事（カットシーン）: 兵が、マス toward のほうを向く（その場で、短く回る）。

var unit_id: int
var toward: Vector2i


func _init(turned_unit_id: int, toward_cell: Vector2i) -> void:
	unit_id = turned_unit_id
	toward = toward_cell
