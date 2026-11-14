class_name SmokeBlockedEvent
extends BattleEvent
## 駒の攻撃が煙幕に阻まれ、ダメージが 0 になった（HP は変わらない）。effect_id は阻んだ煙幕。
## 攻撃した駒の行動は、攻撃したのと同じに終わる（AttackAction なら、このあとに UnitActedEvent が続く）。

var attacker_id: int
var target_id: int
var effect_id: int


func _init(by_unit_id: int, attacked_unit_id: int, smoke_id: int) -> void:
	attacker_id = by_unit_id
	target_id = attacked_unit_id
	effect_id = smoke_id
