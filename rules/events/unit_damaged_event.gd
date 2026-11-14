class_name UnitDamagedEvent
extends BattleEvent
## 駒が攻撃を受けた。hp は受けたあとの HP。

var attacker_id: int
var unit_id: int
var amount: int
var hp: int


func _init(by_unit_id: int, damaged_unit_id: int, damage: int, hp_after: int) -> void:
	attacker_id = by_unit_id
	unit_id = damaged_unit_id
	amount = damage
	hp = hp_after
