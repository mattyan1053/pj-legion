extends RefCounted
## 測るための版（--rival に渡す。docs/skills/shadow-step.md の「調整値」）: シャドウステップで相手の将と入れ替わり、味方の届くところへ引きずり出して倒す手を、狙って使う CPU。
## そうできる手が無ければ、いまの CPU（CpuPlayer）と同じ。狙った回数は、1 回ごとに PULL の行で出す。
##
##   godot --headless --path . -s res://tools/cpu_matches.gd -- --games=240 --pairings=mixed --rival=res://tools/rivals/shadow_step_pull.gd
var cpu := CpuPlayer.new()
var plan: Array[BattleAction] = []
var pulls := 0

func next_action(battle: Battle) -> BattleAction:
	while not plan.is_empty():
		var queued: BattleAction = plan.pop_front()
		if battle.can_apply(queued):
			return queued
		plan.clear()
	if battle.phase == Unit.Side.PLAYER1 or battle.phase == Unit.Side.PLAYER2:
		var found := _find_pull(battle)
		if not found.is_empty():
			pulls += 1
			print("PULL turn=%d" % battle.turn)
			plan = found
			return plan.pop_front()
	return cpu.next_action(battle)


func _find_pull(battle: Battle) -> Array[BattleAction]:
	var me := battle.phase
	var king: Unit = null
	for unit in battle.units:
		if unit.kind == UnitKind.Id.KING and unit.side != me and unit.side != Unit.Side.NEUTRAL:
			king = unit
	if king == null:
		return []
	for unit in battle.units:
		if unit.side != me or unit.kind != UnitKind.Id.SPELLBLADE or not battle.can_act(unit) or unit.has_moved:
			continue
		var options := battle.options(unit.id)
		var cells: Array[Vector2i] = [unit.cell]
		cells.append_array(options.move_cells.keys())
		for cell in cells:
			if maxi(absi(cell.x - king.cell.x), absi(cell.y - king.cell.y)) > ShadowStepSkill.RANGE:
				continue
			var sim := battle.clone()
			var steps: Array[BattleAction] = []
			if cell != unit.cell:
				var move := MoveAction.new(unit.id, cell)
				if not sim.can_apply(move):
					continue
				sim.apply(move)
				steps.append(move)
			var step := UseSkillAction.new(unit.id, king.cell)
			if not sim.can_apply(step):
				continue
			sim.apply(step)
			steps.append(step)
			# 跳んだ駒の行動を終えてから、ほかの味方の届くぶんを数える。
			var pulled := sim.unit_by_id(king.id)
			var first := 0
			var strike := AttackAction.new(unit.id, king.id)
			if sim.can_apply(strike):
				first = Combat.damage(sim, sim.unit_by_id(unit.id), pulled)
				sim.apply(strike)
			else:
				sim.apply(WaitAction.new(unit.id))
			if sim.is_over() or first + _reachable_damage(sim, me, king.id) >= pulled.hp + first:
				return steps
	return []


## 将（king_id）へ、このフェーズにまだ届く味方の攻撃の合計（目安）。
func _reachable_damage(sim: Battle, me: Unit.Side, king_id: int) -> int:
	var king := sim.unit_by_id(king_id)
	var total := 0
	for unit in sim.units:
		if unit.side != me or not sim.can_act(unit) or UnitKind.role(unit.kind) == UnitKind.Role.HEALER:
			continue
		var options := sim.options(unit.id)
		if king_id in options.attack_target_ids:
			total += Combat.damage(sim, unit, king)
			continue
		if unit.has_moved:
			continue
		# 動いた先から、ルールで撃てるか（盾の射線、煙幕も）を、複製の上で動いて確かめる。
		for cell: Vector2i in options.move_cells:
			if Combat.distance(cell, king.cell) > unit.attack_range():
				continue
			var moved := sim.clone()
			moved.apply(MoveAction.new(unit.id, cell))
			var mover := moved.unit_by_id(unit.id)
			var target := moved.unit_by_id(king_id)
			if Combat.can_attack(moved, mover, target):
				total += Combat.damage(moved, mover, target)
				break
	return total
