class_name SanctuaryHealedEvent
extends UnitHealedEvent
## 駒が、持ち主のフェーズの始めに聖域で回復した。effect_id は回復させた聖域。

var effect_id: int


func _init(sanctuary_id := 0, healed_unit_id := 0, healed := 0, hp_after := 0) -> void:
	effect_id = sanctuary_id
	unit_id = healed_unit_id
	amount = healed
	hp = hp_after
	cause = Cause.SANCTUARY
