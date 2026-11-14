class_name UseSkillAction
extends BattleAction
## 駒がいまの位置から、スキルを使う（docs/active-skills.md）。使うと行動を終える。
##
## どのスキルかは駒の種類で決まる。対象はマスで指す（自分に使うスキルは自分のマス、駒を選ぶスキルはその駒のマス）。
## 動かずに使ってもよい。巡航で動いた駒と、クールダウンが残っている駒は使えない。

var unit_id: int
var target: Vector2i


func _init(user_id: int, target_cell: Vector2i) -> void:
	unit_id = user_id
	target = target_cell


func is_valid(battle: Battle) -> bool:
	var unit := battle.unit_by_id(unit_id)
	return battle.can_act(unit) and Skills.can_target(battle, unit, target)


func execute(battle: Battle) -> Array[BattleEvent]:
	return Skills.use(battle, battle.unit_by_id(unit_id), target)
