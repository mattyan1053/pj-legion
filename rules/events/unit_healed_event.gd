class_name UnitHealedEvent
extends BattleEvent
## 駒が回復を受けた。amount は実際に増えた HP、hp は受けたあとの HP。
## 回復役の回復でないもの（回復の泉）では、healer_id は 0。

enum Cause {
	HEAL,  ## 回復役の回復
	SPRING,  ## 回復の泉
}

var healer_id: int
var unit_id: int
var amount: int
var hp: int
var cause: Cause


func _init(
	by_unit_id: int, healed_unit_id: int, healed: int, hp_after: int, why := Cause.HEAL
) -> void:
	healer_id = by_unit_id
	unit_id = healed_unit_id
	amount = healed
	hp = hp_after
	cause = why
