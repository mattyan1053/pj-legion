extends CpuSkillEstimate
class_name CpuSaintPlace
## CPU が、セイントプレイス（聖域）を使う手を見積もる（スキルは rules/skills/saint_place_skill.gd）。見積もり方は docs/skills/ のこのスキルの文書の「CPU」。
## 共通の決まり（試し方、比べ方）は cpu_skill_estimate.gd と docs/cpu-ai.md。

## 中に、減っている味方がこの数だけいれば置く。1 体が回復すると見込むのは、聖域の回復の何回ぶんまでか。
const MIN_UNITS := 2
const EXPECTED_HEALS := 2


## 聖域を置く価値のありそうな中心: 減っている味方（もう自分の聖域の中にいる駒は除く）を中に入れられるマス。
func targets(cpu: Variant, unit: Unit, _cells: Dictionary[Vector2i, float]) -> Dictionary[Vector2i, bool]:
	var wanted: Dictionary[Vector2i, bool] = {}
	var skill := Skills.of(unit)
	for friend: Unit in cpu._battle.units:
		if friend.side != cpu._me or friend.hp >= friend.max_hp() or FieldEffects.sanctuary_of(cpu._battle, friend) != null:
			continue
		# 3 x 3 は対称なので、「friend を中心にしたときに効果が及ぶマス」が「friend を中に入れられる中心」になる。
		for cell in skill.affected_cells(cpu._battle, unit, friend.cell):
			wanted[cell] = true
	return wanted


## 聖域を置いた価値。中にいる、減っている味方（もう自分の聖域の中にいる駒は除く）の、見込める回復量。
## 減っている味方が MIN_UNITS 体に満たなければ 0（回復役は、ふつうの回復のほうが早い）。
func value(cpu: Variant, used: SkillUsedEvent, sim: Battle) -> float:
	var cells := Skills.by_id(used.skill).affected_cells(sim, sim.unit_by_id(used.unit_id), used.target)
	var wounded := 0
	var total := 0
	for unit in sim.units:
		if unit.side != cpu._me or not cells.has(unit.cell) or _in_own_sanctuary(cpu, unit.cell):
			continue
		var missing := unit.max_hp() - unit.hp
		if missing > 0:
			wounded += 1
			total += mini(missing, FieldEffects.SANCTUARY_HEAL * EXPECTED_HEALS)
	return CpuPlayer.HEAL_VALUE * total if wounded >= MIN_UNITS else 0.0


## cell が、置く前から自分の聖域の中か。
static func _in_own_sanctuary(cpu: Variant, cell: Vector2i) -> bool:
	for effect: FieldEffect in cpu._board.field_effects:
		if effect.type == FieldEffect.Type.SANCTUARY and effect.side == cpu._me and effect.cells.has(cell):
			return true
	return false
