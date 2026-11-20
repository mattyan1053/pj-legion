class_name WaitAction
extends BattleAction
## 駒の行動を終える（待機）。動かずに待機してもよい。

var unit_id: int


func _init(waiting_unit_id: int) -> void:
	unit_id = waiting_unit_id


func is_valid(battle: Battle) -> bool:
	return battle.can_act(battle.unit_by_id(unit_id))


func execute(battle: Battle) -> Array[BattleEvent]:
	var unit := battle.unit_by_id(unit_id)
	if RuleProbe.f("brace") > 0 and unit.has_moved and unit.cell != unit.move_origin and not unit.cruised:
		unit.braced = true
	return [battle.finish_action(unit)]
