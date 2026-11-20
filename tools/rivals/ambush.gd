extends CpuPlayer
## 測るための版（--rival に渡す。Issue #47 の「待つのは得か」）: 相手が届く所へ来るまで待ち、来たら叩いて、そこからはいまの CPU と同じに戦う CPU。
## - 待っている間は、tools/rivals/hold.gd と同じ（この番に相手のプレイヤーの駒へ攻撃を届かせられる駒だけが、動いて手を出す）。
## - どれかの駒が手を出せた番から先、またはターン WAIT_UNTIL から先は、いまの CPU（CpuPlayer）と同じ。
##
##   godot --headless --path . -s res://tools/cpu_matches.gd -- --games=216 --pairings=mixed --squads=random --rival=res://tools/rivals/ambush.gd

## このターンからは、待たない（両方が待つと、どちらも動かないため）。
const WAIT_UNTIL := 8

var _released := false
var _released_battle: Battle = null


func next_action(battle: Battle) -> BattleAction:
	if battle != _released_battle:
		_released_battle = battle
		_released = false
	return super.next_action(battle)


func _plan(unit: Unit) -> BattleAction:
	if not _released and _battle.turn < WAIT_UNTIL:
		if not _engaged(unit):
			return WaitAction.new(unit.id)
		_released = true
	return super._plan(unit)


## unit が、この番に（動いてから）相手のプレイヤーの駒に攻撃を届かせうるか。
func _engaged(unit: Unit) -> bool:
	var cells: Dictionary[Vector2i, float] = {unit.cell: 0.0}
	for cell in _battle.options(unit.id).move_cells:
		cells[cell] = 0.0
	_moved_reach = Statuses.stat_after_move(unit, Unit.Stat.ATTACK_RANGE)
	for candidate in _candidates(unit, cells):
		var other := _battle.unit_by_id(candidate[2])
		if other != null and (other.side == _foe) and _can_reach(unit, cells, other):
			return true
	return false


## cells のどれかから、other に本当に手が届くか（_candidates は歩数だけの目安）。攻撃は盾の射線と煙幕もルールに聞く。
func _can_reach(unit: Unit, cells: Dictionary[Vector2i, float], other: Unit) -> bool:
	var healer := UnitKind.role(unit.kind) == UnitKind.Role.HEALER
	for cell in cells:
		var reach := _reach_from(unit, cell)
		if healer:
			if Combat.distance(cell, other.cell) <= reach:
				return true
		elif Combat.reaches(_battle, cell, other.cell, reach) and FieldEffects.smoke_covering(_battle, cell, other) == null:
			return true
	return false
