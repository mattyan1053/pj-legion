class_name UnitMovedEvent
extends BattleEvent
## 駒が動いた。path は出発したマスから着いたマスまで（両端を含む）。見た目はこの道どおりに歩かせる。
## 隣り合うマスだけが並ぶ。ポータルを通った移動は、転移（UnitWarpedEvent）をはさんで、歩いた区間ごとに分かれる。

var unit_id: int
var path: Array[Vector2i]


func _init(moved_unit_id: int, walked: Array[Vector2i]) -> void:
	unit_id = moved_unit_id
	path = walked
