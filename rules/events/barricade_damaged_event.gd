class_name BarricadeDamagedEvent
extends BattleEvent
## 盾が駒の攻撃で削れた。amount は減った耐久力（残りより大きくてもそのまま）、durability は受けたあとの耐久力。
## 0 になったら、このすぐあとに FieldEffectRemovedEvent（DESTROYED）が続く。

var attacker_id: int
var effect_id: int
var cell: Vector2i
var amount: int
var durability: int


func _init(by_unit_id: int, barricade: FieldEffect, damage: int) -> void:
	attacker_id = by_unit_id
	effect_id = barricade.id
	cell = barricade.center
	amount = damage
	durability = barricade.durability
