class_name PrecisionAimSkill
extends Skill
## 精密照準（スナイパー）。動かずに構えて、次の自分の番の攻撃を強める。docs/skills/precision-aim.md。
##
## 使うと、自分に照準（Status.Type.AIM）が付く。照準の間は射程が伸び、次の攻撃 1 回が確定クリティカルになる。
## 照準は、攻撃を 1 回するか、ほかのマスへ動くか、期限が来ると外れる（駒の状態の決まり。Statuses）。
## 使ったターンは行動を終えるので、強めた攻撃を撃てるのは次の自分の番で、構えたマスからだけ。

# ---- 調整値 ----

const COOLDOWN := 3
## 照準の残りのターン数（付けたときの値）。2 なら、次の自分の番の間は残り、その次の自分の番の始めに消える。
const AIM_TURNS := 2
## 照準の間に伸びる射程。
const RANGE_BONUS := 3
## 確定クリティカルの倍率（%）。攻撃力に掛ける（森の軽減は、そのあと）。
const CRITICAL_PERCENT := 200


func id() -> Skill.Id:
	return Skill.Id.PRECISION_AIM


func kind() -> UnitKind.Id:
	return UnitKind.Id.SNIPER


## 説明の文（game/text/names.csv の skill.precision_aim.summary）に差し込む値。
func summary_args() -> Dictionary:
	return {"range": RANGE_BONUS, "times": CRITICAL_PERCENT / 100}


func cooldown() -> int:
	return COOLDOWN


## このターンに、ほかのマスへ動いていないこと。
func is_ready(_battle: Battle, unit: Unit) -> bool:
	return not unit.has_moved or unit.cell == unit.move_origin


## 自分に使う。対象は自分のマスだけ。
func target_cells(_battle: Battle, unit: Unit) -> Array[Vector2i]:
	return [unit.cell]


func apply(_battle: Battle, unit: Unit, _target: Vector2i) -> Array[BattleEvent]:
	return [Statuses.add(unit, Status.Type.AIM, AIM_TURNS)]
