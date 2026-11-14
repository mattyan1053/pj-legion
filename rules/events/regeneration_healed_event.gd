class_name RegenerationHealedEvent
extends UnitHealedEvent
## 再生の特性（Evolution.Trait.REGENERATION）を持つ駒が、自分のフェーズの始めに回復した。


func _init(healed_unit_id: int, healed: int, hp_after: int) -> void:
	unit_id = healed_unit_id
	amount = healed
	hp = hp_after
	cause = Cause.REGENERATION
