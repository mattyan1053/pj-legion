class_name UnitMovedEvent
extends RefCounted
## 駒が動いた。path は出発したマスから着いたマスまで（両端を含む）。見た目はこの道どおりに歩かせる。

var unit_id: int
var path: Array[Vector2i]


func _init(moved_unit_id: int, walked: Array[Vector2i]) -> void:
	unit_id = moved_unit_id
	path = walked
