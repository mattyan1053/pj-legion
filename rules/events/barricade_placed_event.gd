class_name BarricadePlacedEvent
extends FieldEffectPlacedEvent
## 盾が置かれた。cells は 1 マス（center と同じ）。durability は置いたときの耐久力。

var durability: int


func _init(effect: FieldEffect) -> void:
	_fill(effect)
	durability = effect.durability
