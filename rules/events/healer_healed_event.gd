class_name HealerHealedEvent
extends UnitHealedEvent
## 駒が、回復役の回復を受けた。healer_id は回復した駒。

var healer_id: int


func _init(by_unit_id := 0, healed_unit_id := 0, healed := 0, hp_after := 0) -> void:
	healer_id = by_unit_id
	unit_id = healed_unit_id
	amount = healed
	hp = hp_after
	cause = Cause.HEAL
