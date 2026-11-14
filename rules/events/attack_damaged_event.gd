class_name AttackDamagedEvent
extends UnitDamagedEvent
## 駒が、駒の攻撃でダメージを受けた。attacker_id は攻撃した駒。

var attacker_id: int


func _init(by_unit_id: int, damaged_unit_id: int, damage: int, hp_after: int) -> void:
	attacker_id = by_unit_id
	unit_id = damaged_unit_id
	amount = damage
	hp = hp_after
	cause = Cause.ATTACK
