extends CpuSkillEstimate
class_name CpuPrecisionAim
## CPU が、精密照準を使う手を見積もる（スキルは rules/skills/precision_aim_skill.gd）。見積もり方は docs/skills/ のこのスキルの文書の「CPU」。
## 共通の決まり（試し方、比べ方）は cpu_skill_estimate.gd と docs/cpu-ai.md。

## 次の自分の番に、強めた攻撃を当てられそうな敵 1 体への、その攻撃の価値の何倍を見込むか。
## いま伸びた射程の中にいる敵（RATE）と、1 回動けば入ってくる敵（WATCH_RATE）。
## いまの位置から攻撃できる敵は数えない（構えるより、いま撃つほうが早い）。
const RATE := 0.4
const WATCH_RATE := 0.2


## 照準は、動かずに構える（いまのマスだけ）。
func targets(_cpu: Variant, unit: Unit, _cells: Dictionary[Vector2i, float]) -> Dictionary[Vector2i, bool]:
	return {unit.cell: true}


## 照準を付けた価値。次の自分の番に、構えたマスから強めた攻撃を当てられそうな敵のうち、いちばん価値の高い 1 体ぶん。
## 当てたときのダメージは、構えたあとの複製（sim）のルールの答え（Combat.damage。確定クリティカル、森、煙幕、バリアを通る）。
## - いまの位置から攻撃できる敵は数えない
## - 伸びた射程の中にいる敵は RATE、相手が 1 回動けば入ってくる距離の敵は WATCH_RATE（距離は目安。地形は見ない）
func value(cpu: Variant, used: SkillUsedEvent, sim: Battle) -> float:
	var unit: Unit = cpu._battle.unit_by_id(used.unit_id)
	var aimed := sim.unit_by_id(used.unit_id)
	var best := 0.0
	if Statuses.has(unit, Status.Type.AIM):
		return best  # もう構えている
	for enemy: Unit in cpu._battle.units:
		if enemy.side != cpu._foe or Combat.can_attack(cpu._battle, unit, enemy):
			continue
		var rate := WATCH_RATE
		if Combat.can_attack(sim, aimed, sim.unit_by_id(enemy.id)):
			rate = RATE
		elif Combat.distance(unit.cell, enemy.cell) > aimed.attack_range() + enemy.move_range():
			continue
		var amount := Combat.damage(sim, aimed, sim.unit_by_id(enemy.id))
		if amount > 0:
			best = maxf(best, rate * cpu._damage_value(enemy, maxi(0, enemy.hp - amount)))
	return best
