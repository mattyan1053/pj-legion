class_name FormationTriggeredEvent
extends BattleEvent
## 組み方（Formation）の効果が、駒の攻撃 1 回に効いた。AttackDamagedEvent の直前に出る。
## unit_id は効果を受けた駒（追い撃ち・仇討ちは攻撃した駒、肩並べは攻撃された駒）、other_id は相手。
## amount は増えた（肩並べは減った）ダメージの量。

var effect: Formation.Effect
var unit_id: int
var other_id: int
var amount: int


func _init(which: Formation.Effect, helped_id: int, against_id: int, how_much: int) -> void:
	effect = which
	unit_id = helped_id
	other_id = against_id
	amount = how_much
