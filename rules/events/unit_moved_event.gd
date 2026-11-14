class_name UnitMovedEvent
extends BattleEvent
## 駒が動いた。path は出発したマスから着いたマスまで（両端を含む）。見た目はこの道どおりに歩かせる。
## 隣り合うマスだけが並ぶ。ポータルを通った移動は、転移（UnitWarpedEvent）をはさんで、歩いた区間ごとに分かれる。
## cruise は巡航（攻撃を諦めて、移動力 2 倍で動く）だったか。

var unit_id: int
var path: Array[Vector2i]
var cruise: bool


func _init(moved_unit_id: int, walked: Array[Vector2i], is_cruise := false) -> void:
	unit_id = moved_unit_id
	path = walked
	cruise = is_cruise
