class_name UnitDamagedEvent
extends BattleEvent
## 駒がダメージを受けた。hp は受けたあとの HP。
## 駒の攻撃でないダメージ（起爆樽の爆発）では、attacker_id は 0。

enum Cause {
	ATTACK,  ## 駒の攻撃
	EXPLOSION,  ## 起爆樽の爆発
}

var attacker_id: int
var unit_id: int
var amount: int
var hp: int
var cause: Cause


func _init(
	by_unit_id: int, damaged_unit_id: int, damage: int, hp_after: int, why := Cause.ATTACK
) -> void:
	attacker_id = by_unit_id
	unit_id = damaged_unit_id
	amount = damage
	hp = hp_after
	cause = why
