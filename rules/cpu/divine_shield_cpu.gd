extends CpuSkillEstimate
class_name CpuDivineShield
## CPU が、ディバインシールド（バリア）を使う手を見積もる（スキルは rules/skills/divine_shield_skill.gd）。見積もり方は docs/skills/ のこのスキルの文書の「CPU」。
## 共通の決まり（試し方、比べ方）は cpu_skill_estimate.gd と docs/cpu-ai.md。

## 張るために立つマスの候補の数（立つマスの価値の高い順）。
const TRIES := 3
## 次の相手の番に自分に届く攻撃のうち、いちばん弱い 1 回を防ぐと見込む（敵は弱い攻撃で先にはがす）。
## その価値は、その攻撃 1 回ぶんのダメージの価値の何倍か（攻撃されないまま期限で消えることもあるので、1 より小さい）。
const COVER_RATE := 0.75


## バリアを張る価値のありそうなマス（自分のマスが対象）: 立てるマスのうち、次の相手の番に攻撃されうるマスを、
## 立つマスの価値の高い順に TRIES か所。いまのマスは、攻撃されうるなら必ず入れる。
func targets(cpu: Variant, unit: Unit, cells: Dictionary[Vector2i, float]) -> Dictionary[Vector2i, bool]:
	var wanted: Dictionary[Vector2i, bool] = {}
	if Statuses.blocking(unit) != -1:
		return wanted
	var ranked: Array[Array] = []
	for cell in cells:
		if cpu._threat_at(unit, cell, 0) > 0:
			ranked.append([cpu._position_value(unit, cell, 0, true), cell])
	ranked.sort_custom(func(a: Array, b: Array) -> bool:
		return a[0] > b[0] or (a[0] == b[0] and Board.in_reading_order(a[1], b[1])))
	for entry: Array in ranked.slice(0, TRIES):
		wanted[entry[1]] = true
	if cpu._threat_at(unit, unit.cell, 0) > 0:
		wanted[unit.cell] = true
	return wanted


## バリアを付けた価値。次の相手の番に、いまのマスの自分を攻撃できる敵がいれば、防げる 1 回ぶんを見込む
## （相手は弱い攻撃で先にはがすので、届く攻撃のうち、いちばん弱いもの）。攻撃されそうになければ 0（バリアは期限で消える）。
func value(cpu: Variant, used: SkillUsedEvent, sim: Battle) -> float:
	cpu._build_threats()
	var unit: Unit = cpu._battle.unit_by_id(used.unit_id)
	if Statuses.blocking(unit) != -1:
		return 0.0
	var shielded := sim.unit_by_id(used.unit_id)
	var saved: int = cpu._barrier_saves(unit, shielded.cell)
	return COVER_RATE * CpuPlayer.DAMAGE_VALUE * mini(saved, unit.hp)
