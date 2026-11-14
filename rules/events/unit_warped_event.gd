class_name UnitWarpedEvent
extends BattleEvent
## 駒がポータルを通って、from のポータルから to のポータルへ移った（間のマスは歩いていない）。

var unit_id: int
var from: Vector2i
var to: Vector2i


func _init(warped_unit_id: int, entered: Vector2i, exited: Vector2i) -> void:
	unit_id = warped_unit_id
	from = entered
	to = exited
