extends CpuSkillEstimate
class_name CpuAdrenalineShot
## CPU が、アドレナリン注射を使う手を見積もる（スキルは rules/skills/adrenaline_shot_skill.gd）。見積もり方は docs/skills/ のこのスキルの文書の「CPU」。
## 共通の決まり（試し方、比べ方）は cpu_skill_estimate.gd と docs/cpu-ai.md。

## 対象が、いまの位置からもう一度手を出したときの価値（いちばん良い攻撃・回復）が、この値以上なら使う
## （回数に限りがあるので、倒せる・将を殴れるくらいの手に取っておく）。見込む価値は、その手の価値の何倍か。
const MIN_VALUE := 30.0
const RATE := 0.75


## アドレナリン注射の対象: 行動済みの味方（回復役と将も、ルールが選ばせるなら試す）。
func targets(cpu: Variant, unit: Unit, _cells: Dictionary[Vector2i, float]) -> Dictionary[Vector2i, bool]:
	var wanted: Dictionary[Vector2i, bool] = {}
	for friend: Unit in cpu._battle.units:
		if friend.side == cpu._me and friend != unit and friend.acted:
			wanted[friend.cell] = true
	return wanted


## アドレナリン注射を使った価値。対象が、いまの位置からもう一度手を出したとき（攻撃・樽・盾・回復。動く手とスキルは見ない）の、
## いちばん良い手の価値の RATE 倍。その手の価値が MIN_VALUE に満たなければ 0。
## できる手は、使ったあとの複製（sim）のルールに聞く。
func value(cpu: Variant, used: SkillUsedEvent, sim: Battle) -> float:
	var friend := sim.unit_at(used.target)
	var best := 0.0
	for action in sim.options(friend.id).actions():
		if action is MoveAction or action is WarpAction or action is WaitAction or action is UndoMoveAction or action is UseSkillAction:
			continue
		var after := sim.clone()
		best = maxf(best, cpu._outcome_value(after, after.apply(action).events))
	return RATE * best if best >= MIN_VALUE else 0.0
