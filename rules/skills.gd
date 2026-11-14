class_name Skills
extends RefCounted
## スキルの共通の決まり（docs/active-skills.md）。誰が・いつ使えるか、クールダウン、使ったときの流れ。
##
## スキルごとの中身は Skill の子のクラス（rules/skills/）。ここの問い合わせは状態を変えない。
## 状態を変えるのは use（UseSkillAction が呼ぶ）と start_phase（EndPhaseAction が呼ぶ）。
##
## - スキルは駒の種類で決まる（of）。将と中立の駒は持たない
## - 使えるのは、クールダウンが 0 で、巡航で動いていない駒（can_use）。動いたあとでも、動かずにでもよい
## - 使うと、クールダウンが付き、行動を終える（攻撃・回復・待機のかわり）
## - クールダウンは、持ち主のフェーズの始めに 1 減る（盤の上の効果の期間と同じ数え方）

## すべてのスキル。足すときは、ここに 1 つ並べる。
static var ALL: Array[Skill] = [
	TacticalBarricadeSkill.new(),
	SaintPlaceSkill.new(),
	SmokeGrenadeSkill.new(),
	FireballSkill.new(),
	DivineShieldSkill.new(),
	PrecisionAimSkill.new(),
]

static var _by_kind: Dictionary[UnitKind.Id, Skill] = {}
static var _by_id: Dictionary[Skill.Id, Skill] = {}


static func _index() -> void:
	if not _by_id.is_empty():
		return
	for skill in ALL:
		assert(not _by_kind.has(skill.kind()) and not _by_id.has(skill.id()), "スキルが重なっている")
		_by_kind[skill.kind()] = skill
		_by_id[skill.id()] = skill


## その種類の駒のスキル。持たない種類なら null。
static func of_kind(kind: UnitKind.Id) -> Skill:
	_index()
	return _by_kind.get(kind)


## unit のスキル。持たなければ null。
static func of(unit: Unit) -> Skill:
	return of_kind(unit.kind) if unit != null else null


static func by_id(id: Skill.Id) -> Skill:
	_index()
	return _by_id[id]


## unit が、いまスキルを使える状態か（対象があるかは見ない）。
## 自分の番か・行動済みでないか（Battle.can_act）は、行動の側（UseSkillAction）が見る。
static func can_use(battle: Battle, unit: Unit) -> bool:
	var skill := of(unit)
	if skill == null or unit.skill_cooldown > 0 or unit.cruised:
		return false
	return skill.is_ready(battle, unit)


## unit がいまの位置からスキルの対象に選べるマス。上の行から、左の列から。使えない駒では空。
static func target_cells(battle: Battle, unit: Unit) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not can_use(battle, unit):
		return result
	result = of(unit).target_cells(battle, unit)
	result.sort_custom(Board.in_reading_order)
	return result


static func can_target(battle: Battle, unit: Unit, target: Vector2i) -> bool:
	return can_use(battle, unit) and of(unit).target_cells(battle, unit).has(target)


## unit が target にスキルを使う（使えるかどうかは呼ぶ側が確かめる）。起きたことを返す。
## SkillUsedEvent、スキルの効果のイベント、UnitActedEvent の順。
static func use(battle: Battle, unit: Unit, target: Vector2i) -> Array[BattleEvent]:
	var skill := of(unit)
	unit.skill_cooldown = skill.cooldown()
	var events: Array[BattleEvent] = [SkillUsedEvent.new(unit.id, skill.id(), target, unit.skill_cooldown)]
	events.append_array(skill.apply(battle, unit, target))
	events.append(battle.finish_action(unit))
	return events


## ダメージのあるスキルの共通の入口（スキルの apply が呼ぶ）。user のスキルが、hits の駒に、それぞれの量のダメージを同時に与える。
## hits は [駒, 量] の列（並びのとおりにイベントが出る。ふつうは上の行から、左の列から）。起きたことを返す:
## 1. 駒ごとの SkillDamagedEvent（同時に当たる。間にほかのイベントをはさまない。量は、残りの HP より多くてもそのまま）。
##    ダメージは、駒の攻撃や樽の爆発と同じ解決（Hit）を通る。バリアのある駒には 0 で、バリアが外れる（StatusRemovedEvent。全員のダメージのあと）
## 2. HP が 0 になった駒の UnitDefeatedEvent（同じ並び）
## 3. user に入る経験値（Growth.damage_experience で相手ごとに数え、いちばん多く入る 1 体ぶんだけ）
## 将が倒れたときの決着は、ほかの行動と同じに Battle.settle が決める。
static func deal_damage(battle: Battle, user: Unit, hits: Array[Array]) -> Array[BattleEvent]:
	var skill := of(user).id()
	var events: Array[BattleEvent] = []
	var experience := 0
	var defeated := false
	var after: Array[BattleEvent] = []
	for hit in hits:
		var victim: Unit = hit[0]
		var resolved := Hit.resolve(user, victim, hit[1], UnitDamagedEvent.Cause.SKILL)
		after.append_array(resolved.apply())
		events.append(SkillDamagedEvent.new(skill, resolved))
		var gained := Growth.damage_experience(victim, victim.hp)
		if gained > experience:
			experience = gained
			defeated = victim.hp == 0
	events.append_array(after)
	for hit in hits:
		var victim: Unit = hit[0]
		if victim.hp == 0 and battle.units.has(victim):
			events.append(battle.remove_unit(victim))
	var reason := ExperienceGainedEvent.Reason.DEFEAT if defeated else ExperienceGainedEvent.Reason.HIT
	events.append_array(Growth.gain(user, experience, reason))
	return events


## 駒 unit_id が target にスキルを使ったら起きること（戦闘予測）。状態は変えない。使えなければ空。
## 実際に使うのと同じ処理を、複製の上で走らせる。
static func preview(battle: Battle, unit_id: int, target: Vector2i) -> Array[BattleEvent]:
	return battle.clone().apply(UseSkillAction.new(unit_id, target)).events


## side のフェーズの始めに、side の駒のクールダウンが 1 減る（EndPhaseAction が、盤の上の効果のあとに呼ぶ）。
## 0 になった駒には SkillReadyEvent。駒の番号の順。
static func start_phase(battle: Battle, side: Unit.Side) -> Array[BattleEvent]:
	var events: Array[BattleEvent] = []
	for unit in battle.units:
		if unit.side != side or unit.skill_cooldown <= 0:
			continue
		unit.skill_cooldown -= 1
		if unit.skill_cooldown == 0:
			events.append(SkillReadyEvent.new(unit.id, of(unit).id()))
	return events
