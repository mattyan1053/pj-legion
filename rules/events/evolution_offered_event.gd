class_name EvolutionOfferedEvent
extends BattleEvent
## 駒のレベルが上限に届き、進化先を選べるようになった。choices は選べる進化先（A、B の順）。
##
## このあと、持ち主が EvolveAction で選ぶまで、ほかの行動は受け付けない（Battle.evolving_unit）。
## レベルが上限に届いた LevelUpEvent のすぐあとに出る。

var unit_id: int
var choices: Array[Evolution.Id]


func _init(ready_unit_id: int, offered: Array[Evolution.Id]) -> void:
	unit_id = ready_unit_id
	choices = offered.duplicate()
