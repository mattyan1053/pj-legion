extends CpuPlayer
## 測るための版（--rival に渡す。Issue #47 の「先手の不利は、手番か、踏み込みか」）: 先手のとき、最初の番（ターン 1）を何もせずに終える CPU。
## 先手が「わざと待って、実質の後手に回る」手が、遊ぶ人にとって得かを見る。ほかは、いまの CPU（CpuPlayer）と同じ。
##
##   godot --headless --path . -s res://tools/cpu_matches.gd -- --games=216 --pairings=mixed --squads=random --rival=res://tools/rivals/pass_first.gd


func next_action(battle: Battle) -> BattleAction:
	if battle.turn == 1 and battle.phase == Unit.Side.PLAYER1 and not battle.is_over() and battle.evolving_unit() == null:
		return EndPhaseAction.new()
	return super.next_action(battle)
