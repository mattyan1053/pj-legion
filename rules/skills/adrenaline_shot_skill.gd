class_name AdrenalineShotSkill
extends Skill
## アドレナリン注射（衛生兵）。行動済みの味方 1 体を、行動前に戻す。docs/skills/adrenaline-shot.md。
##
## - 対象は、回復と同じ射程の中の、行動済みの味方（自分は選べない）
## - 対象は、このフェーズにもう一度、移動から行動できる
## - 対象に反動（Status.Type.FATIGUE。攻撃力が下がる）が付く。もう一度の行動から、次の自分の番の終わりまで続く
## - 1 体の衛生兵が、対戦中に使える回数に上限がある（Skill.max_uses）

# ---- 調整値 ----

const COOLDOWN := 3
## 1 体の衛生兵が、対戦中に使える回数。
const MAX_USES := 2
## 反動の残りのターン数（付けたときの値）。2 なら、もう一度の行動と次の自分の番の間は残り、その次の自分の番の始めに消える。
const FATIGUE_TURNS := 2
## 反動の間に下がる攻撃力（回復役なら回復量）。
const POWER_PENALTY := 3


func id() -> Skill.Id:
	return Skill.Id.ADRENALINE_SHOT


func kind() -> UnitKind.Id:
	return UnitKind.Id.MEDIC


## 説明の文（game/text/names.csv の skill.adrenaline_shot.summary）に差し込む値。
func summary_args() -> Dictionary:
	return {"penalty": POWER_PENALTY, "uses": MAX_USES}


func cooldown() -> int:
	return COOLDOWN


func max_uses() -> int:
	return MAX_USES


func target_cells(battle: Battle, unit: Unit) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for other in battle.units:
		if other == unit or other.side != unit.side or not other.acted:
			continue
		if Combat.distance(unit.cell, other.cell) <= unit.attack_range():
			result.append(other.cell)
	return result


func apply(battle: Battle, _unit: Unit, target: Vector2i) -> Array[BattleEvent]:
	var friend := battle.unit_at(target)
	friend.reset_action()
	return [UnitReactivatedEvent.new(friend.id), Statuses.add(friend, Status.Type.FATIGUE, FATIGUE_TURNS)]
