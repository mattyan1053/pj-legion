extends "res://tests/base_test.gd"
## ファイアボール（docs/skills/fireball.md）。ダメージのあるスキルの共通の入口（Skills.deal_damage）も、ここで確かめる。

const Maps := preload("res://tests/support/maps.gd")

const P1 := Unit.Side.PLAYER1
const P2 := Unit.Side.PLAYER2

const OPEN_ROWS: Array[String] = [
	"................",
	"................",
	"................",
	"................",
	"................",
]
const HQ1 := Vector2i(0, 4)
const HQ2 := Vector2i(15, 0)


func _cpu_battle() -> Battle:
	var battle := Maps.battle(OPEN_ROWS)
	battle.board.hq_cells = [HQ1, HQ2]
	battle.add_unit(UnitKind.Id.KING, P1, HQ1)
	battle.add_unit(UnitKind.Id.KING, P2, HQ2)
	return battle


func _damaged(events: Array[BattleEvent]) -> Array[SkillDamagedEvent]:
	var result: Array[SkillDamagedEvent] = []
	for event in events:
		if event is SkillDamagedEvent:
			result.append(event)
	return result


func _experience(events: Array[BattleEvent]) -> Array[ExperienceGainedEvent]:
	var result: Array[ExperienceGainedEvent] = []
	for event in events:
		if event is ExperienceGainedEvent:
			result.append(event)
	return result


func test_sorcerer_has_it() -> void:
	var skill := Skills.of_kind(UnitKind.Id.SORCERER)
	assert_eq(skill.id(), Skill.Id.FIREBALL)
	assert_eq(skill.cooldown(), FireballSkill.COOLDOWN)


func test_center_can_be_any_cell_within_range() -> void:
	var battle := Maps.battle([
		"#########",
		"#...#...#",
		"#..F....#",
		"#.......#",
		"#########",
	])
	var sorcerer := battle.add_unit(UnitKind.Id.SORCERER, P1, Vector2i(4, 2))
	var cells := battle.options(sorcerer.id).skill_cells
	for y in battle.board.size.y:
		for x in battle.board.size.x:
			var cell := Vector2i(x, y)
			assert_eq(cells.has(cell), Combat.distance(sorcerer.cell, cell) <= FireballSkill.CENTER_RANGE, "中心に選べるか %s" % cell)
	assert_true(cells.has(sorcerer.cell), "自分のマス")
	assert_true(cells.has(Vector2i(4, 1)), "壁のマス")


func test_affected_cells_are_a_cross_cut_at_the_edge() -> void:
	var battle := Maps.battle([".....", ".....", "....."])
	var sorcerer := battle.add_unit(UnitKind.Id.SORCERER, P1, Vector2i(2, 1))
	var skill := Skills.of(sorcerer)
	assert_eq(
		skill.affected_cells(battle, sorcerer, Vector2i(3, 1)),
		[Vector2i(3, 0), Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1), Vector2i(3, 2)] as Array[Vector2i],
	)
	assert_eq(
		skill.affected_cells(battle, sorcerer, Vector2i(0, 0)),
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)] as Array[Vector2i],
	)


func test_hits_every_enemy_in_the_cross_and_spares_allies() -> void:
	var battle := Maps.battle([".......", ".......", ".......", "......."])
	var sorcerer := battle.add_unit(UnitKind.Id.SORCERER, P1, Vector2i(0, 1))
	var center := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(3, 1))
	var above := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P2, Vector2i(3, 0))
	var minion := battle.add_unit(UnitKind.Id.MINION, Unit.Side.NEUTRAL, Vector2i(4, 1))
	var ally := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(2, 1))
	var outside := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(4, 2))
	var events := battle.apply(UseSkillAction.new(sorcerer.id, Vector2i(3, 1))).events
	assert_true(events[0] is SkillUsedEvent)
	var damaged := _damaged(events)
	assert_eq(damaged.size(), 3)
	# 上の行から、左の列から。
	assert_eq(damaged[0].unit_id, above.id)
	assert_eq(damaged[1].unit_id, center.id)
	assert_eq(damaged[2].unit_id, minion.id)
	for event in damaged:
		assert_eq(event.cause, UnitDamagedEvent.Cause.SKILL)
		assert_eq(event.user_id, sorcerer.id)
		assert_eq(event.skill, Skill.Id.FIREBALL)
		assert_eq(event.amount, FireballSkill.DAMAGE)
	assert_eq(center.hp, center.max_hp() - FireballSkill.DAMAGE)
	assert_eq(minion.hp, minion.max_hp() - FireballSkill.DAMAGE)
	assert_eq(ally.hp, ally.max_hp(), "味方には当たらない")
	assert_eq(outside.hp, outside.max_hp(), "十字の外")
	assert_true(events[-1] is UnitActedEvent)
	assert_true(sorcerer.acted)


func test_walls_barricades_forest_and_smoke_do_not_stop_it() -> void:
	var battle := Maps.battle([
		".#F..",
		".#...",
		".#...",
	])
	var sorcerer := battle.add_unit(UnitKind.Id.SORCERER, P1, Vector2i(0, 1))
	var in_forest := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(2, 0))
	var in_smoke := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(3, 1))
	FieldEffects.place_barricade(battle, P2, Vector2i(1, 0))
	FieldEffects.place_smoke(battle, P2, Vector2i(3, 1))
	assert_true(battle.can_apply(UseSkillAction.new(sorcerer.id, Vector2i(2, 1))))
	battle.apply(UseSkillAction.new(sorcerer.id, Vector2i(2, 1)))
	assert_eq(in_forest.hp, in_forest.max_hp() - FireballSkill.DAMAGE, "森で減らない")
	assert_eq(in_smoke.hp, in_smoke.max_hp() - FireballSkill.DAMAGE, "煙幕で防がれない")


func test_damage_does_not_depend_on_the_users_power() -> void:
	var battle := Maps.battle([".....", "....."])
	var sorcerer := battle.add_unit(UnitKind.Id.SORCERER, P1, Vector2i(0, 0))
	sorcerer.add_growth(Unit.Stat.POWER, 5)
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(2, 0))
	battle.apply(UseSkillAction.new(sorcerer.id, Vector2i(2, 0)))
	assert_eq(paladin.hp, paladin.max_hp() - FireballSkill.DAMAGE)


func test_barrels_and_barricades_are_not_hit() -> void:
	var battle := Maps.battle(["..B..", "....."])
	var sorcerer := battle.add_unit(UnitKind.Id.SORCERER, P1, Vector2i(0, 1))
	FieldEffects.place_barricade(battle, P2, Vector2i(3, 0))
	battle.apply(UseSkillAction.new(sorcerer.id, Vector2i(2, 0)))
	assert_true(battle.board.barrel_cells.has(Vector2i(2, 0)), "樽は爆発しない")
	assert_eq(battle.board.barricade_at(Vector2i(3, 0)).durability, FieldEffects.BARRICADE_DURABILITY, "盾は削れない")


func test_can_be_cast_on_an_empty_cross() -> void:
	var battle := Maps.battle([".....", "....."])
	var sorcerer := battle.add_unit(UnitKind.Id.SORCERER, P1, Vector2i(0, 0))
	var result := battle.apply(UseSkillAction.new(sorcerer.id, Vector2i(3, 0)))
	assert_true(result.accepted)
	assert_eq(result.events.size(), 2, "SkillUsedEvent と UnitActedEvent だけ")
	assert_eq(sorcerer.skill_cooldown, FireballSkill.COOLDOWN)


func test_defeats_are_listed_after_all_the_damage() -> void:
	var battle := Maps.battle([".....", ".....", "....."])
	var sorcerer := battle.add_unit(UnitKind.Id.SORCERER, P1, Vector2i(0, 1))
	var first := battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(2, 0))
	var second := battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(2, 1))
	first.hp = 4
	second.hp = 7
	var events := battle.apply(UseSkillAction.new(sorcerer.id, Vector2i(2, 1))).events
	assert_true(events[1] is SkillDamagedEvent and events[2] is SkillDamagedEvent)
	assert_eq((events[1] as SkillDamagedEvent).amount, FireballSkill.DAMAGE, "残りの HP より多くても、そのままの量（攻撃と同じ）")
	assert_eq((events[1] as SkillDamagedEvent).hp, 0)
	assert_eq((events[3] as UnitDefeatedEvent).unit_id, first.id)
	assert_eq((events[4] as UnitDefeatedEvent).unit_id, second.id)
	assert_eq(battle.units.size(), 1)


func test_experience_is_the_best_single_hit() -> void:
	var battle := Maps.battle([".....", ".....", "....."])
	var sorcerer := battle.add_unit(UnitKind.Id.SORCERER, P1, Vector2i(0, 1))
	battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(2, 0))
	battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(2, 1))
	var gained := _experience(battle.apply(UseSkillAction.new(sorcerer.id, Vector2i(2, 1))).events)
	assert_eq(gained.size(), 1, "当てた数によらず 1 回")
	assert_eq(gained[0].amount, Growth.HIT_EXPERIENCE)
	assert_eq(gained[0].reason, ExperienceGainedEvent.Reason.HIT)


func test_experience_for_a_defeat() -> void:
	var battle := Maps.battle([".....", ".....", "....."])
	var sorcerer := battle.add_unit(UnitKind.Id.SORCERER, P1, Vector2i(0, 1))
	battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(2, 0))
	var minion := battle.add_unit(UnitKind.Id.MINION, Unit.Side.NEUTRAL, Vector2i(2, 2))
	minion.hp = 3
	var gained := _experience(battle.apply(UseSkillAction.new(sorcerer.id, Vector2i(2, 1))).events)
	assert_eq(gained[0].amount, Growth.NEUTRAL_DEFEAT_EXPERIENCE)
	assert_eq(gained[0].reason, ExperienceGainedEvent.Reason.DEFEAT)
	var other := Maps.battle([".....", ".....", "....."])
	var caster := other.add_unit(UnitKind.Id.SORCERER, P1, Vector2i(0, 1))
	other.add_unit(UnitKind.Id.MINION, Unit.Side.NEUTRAL, Vector2i(2, 0)).hp = 3
	other.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(2, 2)).hp = 1
	var more := _experience(other.apply(UseSkillAction.new(caster.id, Vector2i(2, 1))).events)
	assert_eq(more[0].amount, Growth.DEFEAT_EXPERIENCE, "プレイヤーの駒を倒した 50（中立を倒した 30 より多い）")


func test_no_experience_when_nothing_is_hit() -> void:
	var battle := Maps.battle([".....", "....."])
	var sorcerer := battle.add_unit(UnitKind.Id.SORCERER, P1, Vector2i(0, 0))
	battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(3, 0))
	assert_true(_experience(battle.apply(UseSkillAction.new(sorcerer.id, Vector2i(3, 0))).events).is_empty())


func test_defeating_the_king_wins() -> void:
	var battle := Maps.battle([".....", "....."])
	var sorcerer := battle.add_unit(UnitKind.Id.SORCERER, P1, Vector2i(0, 0))
	battle.add_unit(UnitKind.Id.KING, P1, Vector2i(0, 1))
	var king := battle.add_unit(UnitKind.Id.KING, P2, Vector2i(3, 0))
	king.hp = FireballSkill.DAMAGE
	battle.apply(UseSkillAction.new(sorcerer.id, Vector2i(3, 0)))
	assert_eq(battle.winner, P1)


func test_preview_matches_and_changes_nothing() -> void:
	var battle := Maps.battle([".....", ".....", "....."])
	var sorcerer := battle.add_unit(UnitKind.Id.SORCERER, P1, Vector2i(0, 1))
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(2, 1))
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(3, 1))
	sniper.hp = 5
	var preview := _damaged(Skills.preview(battle, sorcerer.id, Vector2i(2, 1)))
	assert_eq(paladin.hp, paladin.max_hp(), "予測で状態が変わった")
	assert_eq(battle.units.size(), 3)
	assert_eq(sorcerer.skill_cooldown, 0)
	var actual := _damaged(battle.apply(UseSkillAction.new(sorcerer.id, Vector2i(2, 1))).events)
	assert_eq(preview.size(), actual.size())
	for i in actual.size():
		assert_eq(preview[i].unit_id, actual[i].unit_id)
		assert_eq(preview[i].amount, actual[i].amount)
		assert_eq(preview[i].hp, actual[i].hp)


# --- CPU ---


func test_cpu_hits_two_enemies_at_once() -> void:
	var battle := _cpu_battle()
	var sorcerer := battle.add_unit(UnitKind.Id.SORCERER, P1, Vector2i(3, 2))
	battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(6, 1))
	battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(6, 3))
	var cpu := CpuPlayer.new()
	var used: UseSkillAction = null
	while used == null and not battle.is_over() and battle.phase == P1:
		var action := cpu.next_action(battle)
		assert_true(battle.apply(action).accepted)
		if action is UseSkillAction:
			used = action
	assert_true(used != null, "ファイアボールを使わなかった")
	assert_eq(used.unit_id, sorcerer.id)
	var hit := 0
	for unit in battle.units:
		if unit.side == P2 and unit.hp < unit.max_hp():
			hit += 1
	assert_eq(hit, 2, "2 体に当てていない")


func test_cpu_finishes_an_enemy_out_of_attack_reach() -> void:
	var battle := Maps.battle([
		"................",
		"...#............",
		"..#.#...........",
		"...#............",
		"................",
	])
	battle.board.hq_cells = [HQ1, HQ2]
	battle.add_unit(UnitKind.Id.KING, P1, HQ1)
	battle.add_unit(UnitKind.Id.KING, P2, HQ2)
	var sorcerer := battle.add_unit(UnitKind.Id.SORCERER, P1, Vector2i(3, 2))
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(6, 2))
	sniper.hp = FireballSkill.DAMAGE
	var cpu := CpuPlayer.new()
	var used: UseSkillAction = null
	while used == null and not battle.is_over() and battle.phase == P1:
		var action := cpu.next_action(battle)
		assert_true(battle.apply(action).accepted)
		if action is UseSkillAction:
			used = action
	assert_true(used != null and used.unit_id == sorcerer.id, "壁に囲まれて動けず、届くのはファイアボールだけなのに使わなかった")
	assert_eq(battle.unit_by_id(sniper.id), null, "倒していない")


func test_cpu_does_not_waste_it_on_allies_only() -> void:
	var battle := _cpu_battle()
	var sorcerer := battle.add_unit(UnitKind.Id.SORCERER, P1, Vector2i(3, 2))
	battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(5, 2)).acted = true
	var cpu := CpuPlayer.new()
	while not battle.is_over() and battle.phase == P1:
		var action := cpu.next_action(battle)
		assert_false(action is UseSkillAction and (action as UseSkillAction).unit_id == sorcerer.id, "当てる敵がいないのに使った")
		battle.apply(action)
