class_name UnitHealedEvent
extends BattleEvent
## 駒が回復を受けた。amount は実際に増えた HP、hp は受けたあとの HP。

var healer_id: int
var unit_id: int
var amount: int
var hp: int


func _init(by_unit_id: int, healed_unit_id: int, healed: int, hp_after: int) -> void:
	healer_id = by_unit_id
	unit_id = healed_unit_id
	amount = healed
	hp = hp_after
