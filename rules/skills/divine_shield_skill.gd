class_name DivineShieldSkill
extends Skill
## ディバインシールド（パラディン）。自分にバリアを付ける。docs/skills/divine-shield.md。
##
## バリアそのものの決まり（次に受けるダメージを 1 回だけ 0 にして外れる）は、駒の状態（Status.Type.BARRIER）と
## ダメージの解決（Hit）。駒の攻撃、起爆樽の爆発、スキルのダメージのどれも防ぐ。

# ---- 調整値 ----

const COOLDOWN := 4
## バリアの残りのターン数（付けたときの値）。2 なら、使ったターンと次のターンの相手の番を越えて、
## その次の自分の番の始めに消える。
const BARRIER_TURNS := 2


func id() -> Skill.Id:
	return Skill.Id.DIVINE_SHIELD


func kind() -> UnitKind.Id:
	return UnitKind.Id.PALADIN


func display_name() -> String:
	return "ディバインシールド"


func summary() -> String:
	return "自分にバリア（%d ターン。次に受けるダメージを 1 回だけ 0 にする。攻撃・爆発・魔法のどれも）を付ける" % BARRIER_TURNS


func cooldown() -> int:
	return COOLDOWN


## 自分に使う。対象は自分のマスだけ。
func target_cells(_battle: Battle, unit: Unit) -> Array[Vector2i]:
	return [unit.cell]


func apply(_battle: Battle, unit: Unit, _target: Vector2i) -> Array[BattleEvent]:
	return [Statuses.add(unit, Status.Type.BARRIER, BARRIER_TURNS)]
