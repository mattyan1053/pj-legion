extends CpuSkillEstimate
class_name CpuShadowStep
## CPU が、シャドウステップを使う手を見積もる（スキルは rules/skills/shadow_step_skill.gd）。見積もり方は docs/skills/ のこのスキルの文書の「CPU」。
## 共通の決まり（試し方、比べ方）は cpu_skill_estimate.gd と docs/cpu-ai.md。


## シャドウステップで跳ぶ価値のありそうなマス:
## - 歩いては攻撃が届かない敵（相手のプレイヤーの駒）を、攻撃できるマス（歩いて届く敵は、歩いて攻撃する手が比べている）。
##   中立の駒を殴るためには跳ばない（跳べるのは数ターンに 1 回。相手の駒のために取っておく）
## - 空いている敵の本陣
## - 自分の本陣に乗っている敵のマス（入れ替わって、占拠を切る）
func targets(cpu: Variant, unit: Unit, cells: Dictionary[Vector2i, float]) -> Dictionary[Vector2i, bool]:
	var wanted: Dictionary[Vector2i, bool] = {}
	var reach: int = cpu._moved_reach if cells.size() > 1 else unit.attack_range()
	for other: Unit in cpu._battle.units:
		if other.side != cpu._foe:
			continue
		if other.cell == cpu._my_hq:
			wanted[other.cell] = true
		if cells.size() > 1 and cpu._in_reach(unit, cells, other.cell):
			continue
		for dy in range(-reach, reach + 1):
			for dx in range(-reach + absi(dy), reach - absi(dy) + 1):
				wanted[other.cell + Vector2i(dx, dy)] = true
	if cpu._foe_hq != Board.NO_CELL and cpu._battle.unit_at(cpu._foe_hq) == null:
		wanted[cpu._foe_hq] = true
	return wanted


## シャドウステップで跳んだ価値。跳んだ先から続けてできる攻撃（駒・樽・盾）のうち、いちばん良いものの価値に、
## 立つマスの価値の差（跳んだ先 − いまのマス）を足す。続けてできる攻撃は、跳んだあとの複製（sim）のルールに聞く。
## 攻撃できる相手がいなければ 0（跳ぶだけの手は選ばない）。ただし、次の 2 つは攻撃できなくても数える。
## - 敵の本陣のマスに着く（立つマスの価値に入っている）
## - 自分の本陣に乗っている敵と入れ替わる（占拠が途切れる。CpuPlayer.OCCUPIER_KILL_BONUS を足す）
func value(cpu: Variant, used: SkillUsedEvent, sim: Battle) -> float:
	var unit: Unit = cpu._battle.unit_by_id(used.unit_id)
	cpu._build_threats()
	cpu._set_goal(unit)
	var best := 0.0
	var killed_id := 0
	for action in sim.options(used.unit_id).actions():
		if not (action is AttackAction or action is AttackBarrelAction or action is AttackBarricadeAction):
			continue
		var after := sim.clone()
		var worth: float = cpu._outcome_value(after, after.apply(action).events)
		if worth > best:
			best = worth
			var attack := action as AttackAction
			killed_id = attack.target_id if attack != null and after.unit_by_id(attack.target_id) == null else 0
	var swapped: Unit = cpu._battle.unit_at(used.target)
	if swapped != null and swapped.side == cpu._foe and used.target == cpu._my_hq:
		best += CpuPlayer.OCCUPIER_KILL_BONUS
	if best <= 0.0 and used.target != cpu._foe_hq:
		return 0.0
	var from: Vector2i = cpu._stand if cpu._stand != Board.NO_CELL else unit.cell
	return best + cpu._position_value(unit, used.target, killed_id, true) - cpu._position_value(unit, from, 0, true)
