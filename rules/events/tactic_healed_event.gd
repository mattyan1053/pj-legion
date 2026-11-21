class_name TacticHealedEvent
extends UnitHealedEvent
## 駒が、作戦（補給）で回復した。


func _init(healed_unit_id: int, healed: int, hp_after: int) -> void:
	unit_id = healed_unit_id
	amount = healed
	hp = hp_after
	cause = Cause.TACTIC
