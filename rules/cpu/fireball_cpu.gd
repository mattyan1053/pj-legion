extends CpuSkillEstimate
class_name CpuFireball
## CPU が、ファイアボールを使う手を見積もる（スキルは rules/skills/fireball_skill.gd）。見積もり方は docs/skills/ のこのスキルの文書の「CPU」。
## 共通の決まり（試し方、比べ方）は cpu_skill_estimate.gd と docs/cpu-ai.md。


## ファイアボールを撃つ価値のありそうな中心: 敵（中立の駒も）のどれかに当たるマス。
func targets(cpu: CpuPlayer, unit: Unit, _cells: Dictionary[Vector2i, float]) -> Dictionary[Vector2i, bool]:
	var wanted: Dictionary[Vector2i, bool] = {}
	var skill := Skills.of(unit)
	for other in cpu._battle.units:
		if other.side == cpu._me:
			continue
		# 十字は対称なので、「other を中心にしたときに効果が及ぶマス」が「other に当たる中心」になる。
		for cell in skill.affected_cells(cpu._battle, unit, other.cell):
			wanted[cell] = true
	return wanted
