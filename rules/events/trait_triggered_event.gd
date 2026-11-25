class_name TraitTriggeredEvent
extends BattleEvent
## 軍略（Traits）のダメージの増減が、駒の攻撃 1 回に効いた。AttackDamagedEvent の直前に出る。
## unit_id は軍略を持つ側の駒（集中砲火・仇討ち・誓い・単騎は攻撃した駒、隊列は攻撃された駒）、other_id は相手。
## amount は増えた（隊列は減った）ダメージの量。補給線の回復は SupplyHealedEvent。

var trait_id: Traits.Id
var unit_id: int
var other_id: int
var amount: int


func _init(which: Traits.Id, helped_id: int, against_id: int, how_much: int) -> void:
	trait_id = which
	unit_id = helped_id
	other_id = against_id
	amount = how_much
