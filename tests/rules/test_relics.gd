extends "res://tests/base_test.gd"
## 聖遺物: 中ボスを倒した陣営が受け取る、効果が駒の聖遺物の層に入る、あとから置かれた駒・進化した駒・複製・必殺技のゲージ（docs/relic-buff.md）。

const Maps := preload("res://tests/support/maps.gd")

const P1 := Unit.Side.PLAYER1
const P2 := Unit.Side.PLAYER2
const NEUTRAL := Unit.Side.NEUTRAL
const WISDOM := Relics.Id.WISDOM
const COURAGE := Relics.Id.COURAGE

## 壁の無い 16 x 5 の盤面。中ボスの場所は、左 (4, 2) と右 (11, 2)。
const OPEN_ROWS: Array[String] = [
	"................",
	"................",
	"................",
	"................",
	"................",
]
const LEFT := Vector2i(4, 2)
const RIGHT := Vector2i(11, 2)


func _battle() -> Battle:
	var battle := Maps.battle(OPEN_ROWS)
	battle.board.mid_boss_cells = [LEFT, RIGHT]
	return battle


## HP 1 の中ボス。
func _weak_boss(battle: Battle, home: Vector2i) -> Unit:
	var unit := battle.add_unit(UnitKind.Id.ELITE_MINION, NEUTRAL, home)
	unit.home_cell = home
	unit.hp = 1
	return unit


func _of_type(events: Array[BattleEvent], type: Script) -> Array[BattleEvent]:
	var result: Array[BattleEvent] = []
	for event in events:
		if event.get_script() == type:
			result.append(event)
	return result


func _index_of(events: Array[BattleEvent], type: Script) -> int:
	for i in events.size():
		if events[i].get_script() == type:
			return i
	return -1


# ---- 種類 ----


func test_left_boss_holds_wisdom_and_right_boss_holds_courage() -> void:
	assert_eq(Relics.of_boss(0), WISDOM)
	assert_eq(Relics.of_boss(1), COURAGE)
	assert_eq(Relics.of_boss(2), -1, "聖遺物を持たない番号")
	assert_eq(Relics.boss_of(COURAGE), 1)
	assert_eq(Relics.bonus(WISDOM), {Unit.Stat.MAX_HP: Relics.WISDOM_MAX_HP})
	assert_eq(Relics.bonus(COURAGE), {Unit.Stat.POWER: Relics.COURAGE_POWER})
	for id: Relics.Id in [WISDOM, COURAGE]:
		assert_ne(Relics.display_name(id), "")
		assert_true(Relics.summary(id).contains(str(Relics.bonus(id).values()[0])), "説明に量が出る")


# ---- 受け取る ----


func test_slaying_the_left_boss_grants_wisdom_to_the_slayers_side_only() -> void:
	var battle := _battle()
	var boss := _weak_boss(battle, LEFT)
	var slayer := battle.add_unit(UnitKind.Id.COMMANDO, P1, LEFT + Vector2i(0, 1))
	var king := battle.add_unit(UnitKind.Id.KING, P1, Vector2i(0, 4))
	var foe := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(15, 0))
	king.hp = 12
	var events := battle.apply(AttackAction.new(slayer.id, boss.id)).events

	assert_eq(Relics.held(battle, P1), [WISDOM] as Array[Relics.Id])
	assert_true(Relics.held(battle, P2).is_empty(), "相手は受け取らない")
	assert_eq(Relics.holder(battle, WISDOM), P1)
	assert_eq(Relics.holder(battle, COURAGE), -1)
	assert_true(Relics.has(battle, P1, WISDOM))
	# 将も含めて、陣営の駒すべての最大 HP が上がり、いまの HP も同じだけ増える（受けているダメージは変わらない）。
	assert_eq(slayer.max_hp(), UnitKind.max_hp(UnitKind.Id.COMMANDO) + Relics.WISDOM_MAX_HP)
	assert_eq(slayer.hp, slayer.max_hp())
	assert_eq(king.max_hp(), UnitKind.max_hp(UnitKind.Id.KING) + Relics.WISDOM_MAX_HP)
	assert_eq(king.hp, 12 + Relics.WISDOM_MAX_HP)
	assert_eq(foe.max_hp(), UnitKind.max_hp(UnitKind.Id.PALADIN), "相手の駒は変わらない")
	assert_eq(slayer.power(), UnitKind.power(UnitKind.Id.COMMANDO), "英知は攻撃力を変えない")

	# UnitDefeatedEvent、MidBossDefeatedEvent、RelicGainedEvent の順。経験値はそのあと。
	var at := _index_of(events, RelicGainedEvent)
	assert_eq(at, _index_of(events, MidBossDefeatedEvent) + 1)
	assert_true(at < _index_of(events, ExperienceGainedEvent))
	var gained := events[at] as RelicGainedEvent
	assert_eq(gained.side, P1)
	assert_eq(gained.relic, WISDOM)
	assert_eq(gained.boss_index, 0)
	assert_eq(gained.bonus, Relics.bonus(WISDOM))
	assert_eq(gained.unit_ids, [slayer.id, king.id] as Array[int])
	assert_eq(gained.max_hp[king.id], king.max_hp())
	assert_eq(gained.hp[king.id], king.hp)
	assert_eq(gained.power[slayer.id], slayer.power())


func test_slaying_the_right_boss_grants_courage() -> void:
	var battle := _battle()
	var boss := _weak_boss(battle, RIGHT)
	var slayer := battle.add_unit(UnitKind.Id.SPELLBLADE, P2, RIGHT + Vector2i(0, 1))
	var priest := battle.add_unit(UnitKind.Id.PRIEST, P2, Vector2i(15, 4))
	var foe := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	battle.apply(EndPhaseAction.new())
	battle.apply(AttackAction.new(slayer.id, boss.id))

	assert_eq(Relics.held(battle, P2), [COURAGE] as Array[Relics.Id])
	assert_eq(slayer.power(), UnitKind.power(UnitKind.Id.SPELLBLADE) + Relics.COURAGE_POWER)
	assert_eq(priest.power(), UnitKind.power(UnitKind.Id.PRIEST) + Relics.COURAGE_POWER, "回復役は回復量が上がる")
	assert_eq(slayer.max_hp(), UnitKind.max_hp(UnitKind.Id.SPELLBLADE), "勇気は最大 HP を変えない")
	assert_eq(foe.power(), UnitKind.power(UnitKind.Id.SNIPER))
	# 上がった攻撃力は、ダメージの計算にそのまま効く。
	assert_eq(Combat.damage(battle, slayer, foe), UnitKind.power(UnitKind.Id.SPELLBLADE) + Relics.COURAGE_POWER)


func test_one_side_can_hold_both_relics() -> void:
	var battle := _battle()
	var left := _weak_boss(battle, LEFT)
	var right := _weak_boss(battle, RIGHT)
	var first := battle.add_unit(UnitKind.Id.COMMANDO, P1, LEFT + Vector2i(0, 1))
	var second := battle.add_unit(UnitKind.Id.COMMANDO, P1, RIGHT + Vector2i(0, 1))
	battle.apply(AttackAction.new(second.id, right.id))
	battle.apply(AttackAction.new(first.id, left.id))

	assert_eq(Relics.held(battle, P1), [COURAGE, WISDOM] as Array[Relics.Id], "受け取った順")
	assert_eq(Relics.total_bonus(battle, P1), {Unit.Stat.POWER: Relics.COURAGE_POWER, Unit.Stat.MAX_HP: Relics.WISDOM_MAX_HP})
	assert_eq(first.power(), UnitKind.power(UnitKind.Id.COMMANDO) + Relics.COURAGE_POWER)
	assert_eq(first.max_hp(), UnitKind.max_hp(UnitKind.Id.COMMANDO) + Relics.WISDOM_MAX_HP)


func test_skill_kill_grants_the_relic_to_the_users_side() -> void:
	var battle := _battle()
	var boss := _weak_boss(battle, LEFT)
	var sorcerer := battle.add_unit(UnitKind.Id.SORCERER, P1, LEFT + Vector2i(0, 2))
	var events := battle.apply(UseSkillAction.new(sorcerer.id, boss.cell)).events
	assert_eq(_of_type(events, RelicGainedEvent).size(), 1)
	assert_eq(Relics.held(battle, P1), [WISDOM] as Array[Relics.Id])


func test_units_falling_in_the_same_blast_are_not_saved_by_wisdom() -> void:
	# 樽の爆発が、左の中ボスと、そのあとに並ぶ味方（将も）を同時に倒す。英知の +HP で、倒れた駒が生き残ってはいけない。
	var battle := Maps.battle([
		"................",
		"................",
		"....B...........",
		"................",
		"................",
	] as Array[String])
	battle.board.mid_boss_cells = [Vector2i(3, 1), RIGHT]
	var boss := _weak_boss(battle, Vector2i(3, 1))
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(5, 3))
	var king := battle.add_unit(UnitKind.Id.KING, P1, Vector2i(4, 3))
	king.hp = 3
	var shooter := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(8, 2))
	battle.add_unit(UnitKind.Id.KING, P2, Vector2i(15, 4))
	var events := battle.apply(AttackBarrelAction.new(shooter.id, Vector2i(4, 2))).events
	assert_true(battle.unit_by_id(boss.id) == null)
	assert_true(Relics.has(battle, P1, WISDOM), "樽を撃った駒の陣営が受け取る")
	assert_true(battle.unit_by_id(sniper.id) == null, "同じ爆発で倒れた駒は、倒れる")
	assert_true(battle.unit_by_id(king.id) == null, "将も倒れる")
	assert_eq(battle.winner, P2)
	var gained := _of_type(events, RelicGainedEvent)[0] as RelicGainedEvent
	assert_eq(gained.unit_ids, [shooter.id] as Array[int], "倒れた駒には掛からない")
	assert_eq(shooter.max_hp(), UnitKind.max_hp(UnitKind.Id.SNIPER) + Relics.WISDOM_MAX_HP)


func test_boss_falling_without_a_slayer_grants_nothing() -> void:
	var battle := _battle()
	var boss := _weak_boss(battle, LEFT)
	battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(0, 4))
	var events := battle.remove_unit(boss)
	assert_eq(_of_type(events, MidBossDefeatedEvent).size(), 1)
	assert_true(_of_type(events, RelicGainedEvent).is_empty())
	assert_eq(Relics.holder(battle, WISDOM), -1)


func test_core_kill_grants_nothing() -> void:
	var battle := _battle()
	var core := battle.add_unit(UnitKind.Id.MINION, NEUTRAL, Vector2i(8, 2))
	core.hp = 1
	var slayer := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(8, 3))
	var events := battle.apply(AttackAction.new(slayer.id, core.id)).events
	assert_true(_of_type(events, RelicGainedEvent).is_empty())
	assert_true(Relics.held(battle, P1).is_empty())


# ---- 層 ----


func test_relic_layer_sits_between_equipment_and_temporary_bonus() -> void:
	var battle := _battle()
	var trooper := battle.add_unit(
		UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(0, 0), [Equipment.Id.IRON_SHIELD] as Array[Equipment.Id]
	)
	trooper.hp -= 20
	Relics.grant(battle, P1, WISDOM, 0)
	Relics.grant(battle, P1, COURAGE, 1)
	var base_hp := UnitKind.max_hp(UnitKind.Id.SHIELD_TROOPER) + Equipment.bonus(Equipment.Id.IRON_SHIELD, Unit.Stat.MAX_HP)
	assert_eq(trooper.base_stat(Unit.Stat.MAX_HP), base_hp, "層 1 は書き換えない")
	assert_eq(trooper.max_hp(), base_hp + Relics.WISDOM_MAX_HP)
	assert_eq(trooper.hp, base_hp - 20 + Relics.WISDOM_MAX_HP)
	# 一時的な補正（総員突撃）は、聖遺物の上に乗る。
	battle.ult_gauge[P1] = Ults.GAUGE_MAX
	battle.apply(UseUltAction.new())
	assert_eq(
		trooper.power(),
		UnitKind.power(UnitKind.Id.SHIELD_TROOPER) + Relics.COURAGE_POWER + AllOutAssaultUlt.POWER_BONUS,
	)
	assert_eq(trooper.base_stat(Unit.Stat.POWER), UnitKind.power(UnitKind.Id.SHIELD_TROOPER))


func test_relic_lasts_through_the_phases() -> void:
	var battle := _battle()
	var unit := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(0, 0))
	battle.add_unit(UnitKind.Id.KING, P2, Vector2i(15, 4))
	Relics.grant(battle, P1, COURAGE, 1)
	for i in 9:
		battle.apply(EndPhaseAction.new())
	assert_eq(unit.power(), UnitKind.power(UnitKind.Id.COMMANDO) + Relics.COURAGE_POWER)
	assert_true(Relics.has(battle, P1, COURAGE))


func test_units_placed_after_the_relic_get_its_effect() -> void:
	var battle := _battle()
	battle.add_unit(UnitKind.Id.KING, P1, Vector2i(0, 0))
	Relics.grant(battle, P1, WISDOM, 0)
	Relics.grant(battle, P1, COURAGE, 1)
	var late := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(1, 0))
	assert_eq(late.max_hp(), UnitKind.max_hp(UnitKind.Id.SNIPER) + Relics.WISDOM_MAX_HP)
	assert_eq(late.hp, late.max_hp(), "置かれた駒は、最大 HP と同じ HP")
	assert_eq(late.power(), UnitKind.power(UnitKind.Id.SNIPER) + Relics.COURAGE_POWER)
	var other := battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(15, 0))
	assert_eq(other.max_hp(), UnitKind.max_hp(UnitKind.Id.SNIPER), "相手の駒には掛からない")
	var core := battle.add_unit(UnitKind.Id.MINION, NEUTRAL, Vector2i(8, 0))
	assert_eq(core.max_hp(), UnitKind.max_hp(UnitKind.Id.MINION), "中立の駒には掛からない")


func test_relic_stays_through_level_up_and_evolution() -> void:
	var battle := _battle()
	var unit := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(0, 0))
	Relics.grant(battle, P1, WISDOM, 0)
	Relics.grant(battle, P1, COURAGE, 1)
	Growth.gain(unit, Growth.EXPERIENCE_PER_LEVEL * 2, ExperienceGainedEvent.Reason.DEFEAT)
	assert_true(unit.evolution_ready)
	var choice := Evolution.options_for(unit.kind)[0]
	assert_true(battle.apply(EvolveAction.new(unit.id, choice)).accepted)
	assert_eq(unit.max_hp(), unit.base_stat(Unit.Stat.MAX_HP) + Relics.WISDOM_MAX_HP)
	assert_eq(unit.power(), unit.base_stat(Unit.Stat.POWER) + Relics.COURAGE_POWER)
	assert_eq(unit.hp, unit.max_hp())


# ---- 必殺技のゲージ ----


func test_relic_charges_the_ult_gauge() -> void:
	var battle := _battle()
	var boss := _weak_boss(battle, LEFT)
	var slayer := battle.add_unit(UnitKind.Id.COMMANDO, P1, LEFT + Vector2i(0, 1))
	battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(15, 0))
	var before := battle.ult_gauge[P1]
	var events := battle.apply(AttackAction.new(slayer.id, boss.id)).events
	var gained := _of_type(events, RelicGainedEvent)[0] as RelicGainedEvent
	# 止めのダメージ 1 のぶん（DEALT_GAIN）と、聖遺物のぶん。
	assert_eq(battle.ult_gauge[P1], before + Ults.DEALT_GAIN + Relics.ULT_GAIN)
	assert_eq(gained.ult_gain, Relics.ULT_GAIN)
	assert_eq(gained.ult_gauge, battle.ult_gauge[P1])
	assert_eq(battle.ult_gauge[P2], 0, "相手のゲージは変わらない")


func test_relic_filling_the_gauge_announces_ult_ready() -> void:
	var battle := _battle()
	var boss := _weak_boss(battle, RIGHT)
	var slayer := battle.add_unit(UnitKind.Id.COMMANDO, P1, RIGHT + Vector2i(0, 1))
	battle.ult_gauge[P1] = Ults.GAUGE_MAX - 100
	var events := battle.apply(AttackAction.new(slayer.id, boss.id)).events
	assert_eq(battle.ult_gauge[P1], Ults.GAUGE_MAX, "いっぱいを超えない")
	var gained := _of_type(events, RelicGainedEvent)[0] as RelicGainedEvent
	assert_eq(gained.ult_gain, 100 - Ults.DEALT_GAIN, "実際にたまった量")
	assert_true(events[-1] is UltReadyEvent)


# ---- 複製と予測 ----


func test_clone_copies_relics_and_keeps_them_apart() -> void:
	var battle := _battle()
	var unit := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(0, 0))
	Relics.grant(battle, P1, WISDOM, 0)
	var copy := battle.clone()
	assert_eq(Relics.held(copy, P1), [WISDOM] as Array[Relics.Id])
	assert_eq(copy.unit_by_id(unit.id).max_hp(), unit.max_hp())
	Relics.grant(copy, P1, COURAGE, 1)
	Relics.grant(copy, P2, COURAGE, 1)
	assert_eq(Relics.held(battle, P1), [WISDOM] as Array[Relics.Id], "複製に足しても、元は変わらない")
	assert_true(Relics.held(battle, P2).is_empty())
	assert_eq(unit.power(), UnitKind.power(UnitKind.Id.COMMANDO))
	assert_eq(copy.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(1, 0)).power(), UnitKind.power(UnitKind.Id.SNIPER) + Relics.COURAGE_POWER)


func test_preview_on_a_clone_shows_the_relic_without_changing_the_battle() -> void:
	var battle := _battle()
	var boss := _weak_boss(battle, LEFT)
	var slayer := battle.add_unit(UnitKind.Id.COMMANDO, P1, LEFT + Vector2i(0, 1))
	var events := battle.clone().apply(AttackAction.new(slayer.id, boss.id)).events
	assert_eq(_of_type(events, RelicGainedEvent).size(), 1)
	assert_true(Relics.held(battle, P1).is_empty())
	assert_eq(slayer.max_hp(), UnitKind.max_hp(UnitKind.Id.COMMANDO))
