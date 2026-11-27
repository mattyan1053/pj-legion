class_name CardHealedEvent
extends UnitHealedEvent
## 駒が、札（手当て・補給）で回復した。card は使った札。

var card: Card.Id


func _init(by_card := Card.Id.MEND, healed_unit_id := 0, healed := 0, hp_after := 0) -> void:
	card = by_card
	unit_id = healed_unit_id
	amount = healed
	hp = hp_after
	cause = Cause.CARD
