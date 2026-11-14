class_name UnitsSwappedEvent
extends BattleEvent
## 2 体の駒の位置が入れ替わった（シャドウステップで、敵のいるマスを選んだ）。
## unit_id は from にいて other_from へ移り、other_id は other_from にいて from へ移った。

var unit_id: int
var from: Vector2i
var other_id: int
var other_from: Vector2i


func _init(swapping_unit_id: int, left: Vector2i, swapped_unit_id: int, other_left: Vector2i) -> void:
	unit_id = swapping_unit_id
	from = left
	other_id = swapped_unit_id
	other_from = other_left
