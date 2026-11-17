extends CpuPlayer
## 測るための版（--rival に渡す。Issue #47 の「待つのは得か」）: 相手が届く所へ来るまで待つ CPU。
## 駒は、この番に相手のプレイヤーの駒へ攻撃を届かせられる（回復の駒は、手負いの味方を回復できる）ときだけ動いて手を出し、
## そうでなければ動かずに待機する。本陣へも中ボスへも、自分からは向かわない。ほかは、いまの CPU（CpuPlayer）と同じ。
## 両方がこの版だと、どちらも動かない。
##
##   godot --headless --path . -s res://tools/cpu_matches.gd -- --games=216 --pairings=mixed --squads=random --rival=res://tools/rivals/hold.gd


func _plan(unit: Unit) -> BattleAction:
	if not _engaged(unit):
		return WaitAction.new(unit.id)
	return super._plan(unit)


## unit が、この番に（動いてから）相手のプレイヤーの駒に攻撃を届かせうるか。回復の駒なら、手負いの味方を回復できるか。
func _engaged(unit: Unit) -> bool:
	var cells: Dictionary[Vector2i, float] = {unit.cell: 0.0}
	for cell in _battle.options(unit.id).move_cells:
		cells[cell] = 0.0
	_moved_reach = Statuses.stat_after_move(unit, Unit.Stat.ATTACK_RANGE)
	for candidate in _candidates(unit, cells):
		var other := _battle.unit_by_id(candidate[2])
		if other != null and (other.side == _foe or other.side == _me):
			return true
	return false
