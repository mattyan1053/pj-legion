class_name SanctuaryHealedEvent
extends UnitHealedEvent
## 駒が、持ち主のフェーズの始めに聖域で回復した。effect_id は回復させた聖域。

var effect_id: int


func _init(sanctuary_id: int, healed_unit_id: int, healed: int, hp_after: int) -> void:
	effect_id = sanctuary_id
	unit_id = healed_unit_id
	amount = healed
	hp = hp_after
	cause = Cause.SANCTUARY
