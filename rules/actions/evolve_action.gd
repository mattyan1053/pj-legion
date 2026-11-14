class_name EvolveAction
extends BattleAction
## 進化先を選ぶ。レベルが上限に届いて、進化先を選ぶのを待っている駒（Battle.evolving_unit）だけが選べる。
##
## 選ぶのは駒の持ち主（上限に届くのは自分の行動なので、いつも自分のフェーズの中）。
## 選んだ進化先の能力値の増減と特性は、すぐに駒へ反映する。最大 HP が伸びたぶんは、いまの HP も増える。
## 駒の行動は、進化の前にもう終わっている（進化しても、もう一度は行動できない）。

var unit_id: int
var evolution: Evolution.Id


func _init(evolving_unit_id: int, to: Evolution.Id) -> void:
	unit_id = evolving_unit_id
	evolution = to


func is_valid(battle: Battle) -> bool:
	var unit := battle.evolving_unit()
	return unit != null and unit.id == unit_id and Evolution.options_for(unit.kind).has(evolution)


func execute(battle: Battle) -> Array[BattleEvent]:
	var unit := battle.unit_by_id(unit_id)
	unit.evolve(evolution)
	return [UnitEvolvedEvent.new(unit)]
