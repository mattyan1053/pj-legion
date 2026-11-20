extends CpuSkillEstimate
class_name CpuBoneRaise
## CPU が、骨起こしを使う手を見積もる（スキルは rules/skills/bone_raise_skill.gd）。見積もり方は docs/skills/bone-raise.md の「CPU」。
## 共通の決まり（試し方、比べ方）は cpu_skill_estimate.gd と docs/cpu-ai.md。

## 骸骨兵を 1 体起こす価値（敵を 1 体倒す価値と同じ物差し。docs/cpu-ai.md の「手の価値」）。
const RAISE_VALUE := 60.0
## 起こすマスが敵の駒に 1 マス近いごとに足す価値（前へ起こす）。
const NEAR_VALUE := 1.0


## 骨起こしの対象: 選べるマス（隣の空いたマス。多くて 4 つ）を全部試す。
func targets(cpu: Variant, unit: Unit, _cells: Dictionary[Vector2i, float]) -> Dictionary[Vector2i, bool]:
	var wanted: Dictionary[Vector2i, bool] = {}
	var battle: Battle = cpu._battle
	for cell in Skills.of(unit).target_cells(battle, unit):
		wanted[cell] = true
	return wanted


## 骨起こしの価値: RAISE_VALUE に、起こしたマスが敵の駒に近いぶん（NEAR_VALUE × 近さ）を足す。
func value(cpu: Variant, used: SkillUsedEvent, sim: Battle) -> float:
	var me: Unit.Side = cpu._me
	var nearest := 99
	for other in sim.units:
		if other.side == 1 - me:
			nearest = mini(nearest, Combat.distance(used.target, other.cell))
	return RAISE_VALUE + NEAR_VALUE * maxi(0, 30 - nearest)
