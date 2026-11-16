extends CpuSkillEstimate
class_name CpuSmokeGrenade
## CPU が、スモークグレネード（煙幕）を使う手を見積もる（スキルは rules/skills/smoke_grenade_skill.gd）。見積もり方は docs/skills/ のこのスキルの文書の「CPU」。
## 共通の決まり（試し方、比べ方）は cpu_skill_estimate.gd と docs/cpu-ai.md。

## 中に、離れたところからしか届かない攻撃に狙われている味方がこの数だけいれば置く。
## 防げるダメージの価値の何倍を見込むか（敵は狙いを替えられるので、1 より小さい）。
const MIN_UNITS := 2
const MIN_VALUE := 20.0
const COVER_RATE := 0.75


## 煙幕を置く価値のありそうな中心: 煙幕が防ぐ攻撃に狙われている味方（もう自分の煙幕の中にいる駒は除く）を中に入れられるマス。
func targets(cpu: Variant, unit: Unit, _cells: Dictionary[Vector2i, float]) -> Dictionary[Vector2i, bool]:
	var wanted: Dictionary[Vector2i, bool] = {}
	var skill := Skills.of(unit)
	for friend: Unit in cpu._battle.units:
		if friend.side != cpu._me or cpu._smoked.has(friend.cell) or _smoke_saves(cpu, friend.cell) <= 0:
			continue
		for cell in skill.affected_cells(cpu._battle, unit, friend.cell):
			wanted[cell] = true
	return wanted


## 煙幕を置いた価値。中にいる味方（もう自分の煙幕の中にいる駒は除く）のうち、次の相手の番に、煙幕が防ぐ攻撃
## （離れたところからしか届かない攻撃）に狙われうる駒を数え、防げるダメージを見込む。
## 隣まで寄れる敵の攻撃と、スキルのダメージは防げないので数えない（CpuPlayer の _close_threats）。
## 狙われている味方が MIN_UNITS 体に満たなければ 0。
func value(cpu: Variant, used: SkillUsedEvent, sim: Battle) -> float:
	cpu._build_threats()
	var cells := Skills.by_id(used.skill).affected_cells(sim, sim.unit_by_id(used.unit_id), used.target)
	var covered := 0
	var worth := 0.0
	for unit in sim.units:
		if unit.side != cpu._me or not cells.has(unit.cell) or cpu._smoked.has(unit.cell):
			continue
		var saved := _smoke_saves(cpu, unit.cell)
		if saved > 0:
			var rate := CpuPlayer.KING_DAMAGE_VALUE if unit.kind == UnitKind.Id.KING else CpuPlayer.DAMAGE_VALUE
			covered += 1
			worth += COVER_RATE * rate * mini(saved, unit.hp)
	return worth if covered >= MIN_UNITS or worth >= MIN_VALUE else 0.0


## cell に立つ味方について、煙幕が防げるダメージ（離れたところからしか届かない攻撃のぶん）。
static func _smoke_saves(cpu: Variant, cell: Vector2i) -> int:
	var by: Dictionary = cpu._threats.get(cell, {})
	var close: Dictionary = cpu._close_threats.get(cell, {})
	var saved := 0
	for enemy_id: int in by:
		saved += by[enemy_id] - close.get(enemy_id, 0)
	return saved
