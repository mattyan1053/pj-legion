extends CpuSkillEstimate
class_name CpuWarDrum
## CPU が、骨太鼓を使う手を見積もる（スキルは rules/skills/war_drum_skill.gd）。見積もり方は docs/skills/war-drum.md の「CPU」。
## 共通の決まり（試し方、比べ方）は cpu_skill_estimate.gd と docs/cpu-ai.md。

## 突撃が効く味方 1 体ごとの価値。
const ALLY_VALUE := 20.0
## 太鼓を鳴らすために立つマスの候補の数（立つマスの価値の高い順）。
const TRIES := 3


## 太鼓を鳴らす価値のありそうなマス（自分のマスが対象）: 立てるマスを、立つマスの価値の高い順に TRIES か所と、いまのマス。
func targets(_cpu: Variant, unit: Unit, cells: Dictionary[Vector2i, float]) -> Dictionary[Vector2i, bool]:
	var wanted: Dictionary[Vector2i, bool] = {unit.cell: true}
	var ranked: Array[Array] = []
	for cell in cells:
		ranked.append([cells[cell], cell])
	ranked.sort_custom(func(a: Array, b: Array) -> bool:
		return a[0] > b[0] or (a[0] == b[0] and Board.in_reading_order(a[1], b[1])))
	for entry: Array in ranked.slice(0, TRIES):
		wanted[entry[1]] = true
	return wanted


## 骨太鼓の価値: 突撃が付いた味方のうち、このフェーズにまだ動けて（行動前で、動いていない）、回復役でなく、
## 伸びた移動力 + 射程の中に敵の駒がいるものを数え、1 体ごとに ALLY_VALUE。
func value(cpu: Variant, used: SkillUsedEvent, sim: Battle) -> float:
	var me: Unit.Side = cpu._me
	var drummer := sim.unit_by_id(used.unit_id)
	var count := 0
	for friend in WarDrumSkill.drummed(sim, drummer):
		if friend.acted or friend.has_moved or UnitKind.role(friend.kind) == UnitKind.Role.HEALER:
			continue
		var reach := friend.move_range() + friend.attack_range()
		for other in sim.units:
			if other.side == 1 - me and Combat.distance(friend.cell, other.cell) <= reach:
				count += 1
				break
	return ALLY_VALUE * count
