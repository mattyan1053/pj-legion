class_name UnitTeleportedEvent
extends BattleEvent
## 駒がスキルで、from から to へ移った（間のマスは通っていない。シャドウステップ）。
## ポータルの転移（UnitWarpedEvent）とは別: あちらは移動の道の一部で、こちらは移動ではない。

var unit_id: int
var from: Vector2i
var to: Vector2i


func _init(teleported_unit_id: int, left: Vector2i, landed: Vector2i) -> void:
	unit_id = teleported_unit_id
	from = left
	to = landed
