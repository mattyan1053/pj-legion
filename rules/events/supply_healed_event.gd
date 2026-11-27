class_name SupplyHealedEvent
extends UnitHealedEvent
## 補給線（軍略。Traits）: 駒が、自分のフェーズの始めに、隣り合う回復役（medic_id）のそばで回復した。

var medic_id: int


func _init(by_medic_id := 0, healed_unit_id := 0, healed := 0, hp_after := 0) -> void:
	medic_id = by_medic_id
	unit_id = healed_unit_id
	amount = healed
	hp = hp_after
	cause = Cause.SUPPLY
