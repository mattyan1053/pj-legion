class_name UseTacticAction
extends BattleAction
## いまのフェーズのプレイヤーが、手札の作戦を 1 枚使う（docs/tactics.md）。
##
## 駒の行動ではない（駒を指さない。対象も選ばない）。使っても、どの駒の行動も使わない。同じ札は、1 回の対戦に 1 回だけ。

var tactic: Tactics.Id


func _init(used: Tactics.Id) -> void:
	tactic = used


func is_valid(battle: Battle) -> bool:
	return Tactics.can_use(battle, tactic)


func execute(battle: Battle) -> Array[BattleEvent]:
	return Tactics.use(battle, tactic)
