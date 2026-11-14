class_name AttackDamagedEvent
extends UnitDamagedEvent
## 駒が、駒の攻撃でダメージを受けた。attacker_id は攻撃した駒。

var attacker_id: int


func _init(hit: Hit) -> void:
	attacker_id = hit.source.id
	_fill(hit)
