class_name UnitWarpedEvent
extends BattleEvent
## 駒がポータルを通って、from のポータルから to のポータルへ移った（間のマスは歩いていない）。
## cruise は、この移動が巡航だったか（前後の UnitMovedEvent と同じ値）。

var unit_id: int
var from: Vector2i
var to: Vector2i
var cruise: bool


func _init(warped_unit_id: int, entered: Vector2i, exited: Vector2i, is_cruise := false) -> void:
	unit_id = warped_unit_id
	from = entered
	to = exited
	cruise = is_cruise
