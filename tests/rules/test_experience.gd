extends "res://tests/base_test.gd"
## 経験値の獲得、レベルアップ、能力値の伸び（docs/experience-levelup.md）。

const Maps := preload("res://tests/support/maps.gd")

const P1 := Unit.Side.PLAYER1
const P2 := Unit.Side.PLAYER2
const NEUTRAL := Unit.Side.NEUTRAL


func _battle() -> Battle:
	return Maps.battle([
		"......",
		"..F...",
		"......",
	])


func _types(events: Array[BattleEvent]) -> Array[Script]:
	var result: Array[Script] = []
	for event in events:
		result.append(event.get_script())
	return result


func test_a_hit_that_leaves_the_target_standing_gives_10() -> void:
	var battle := _battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	var target := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(3, 0))
	var events := battle.apply(AttackAction.new(sniper.id, target.id)).events
	assert_eq(_types(events), [AttackDamagedEvent, ExperienceGainedEvent, UnitActedEvent] as Array[Script])
	var gained := events[1] as ExperienceGainedEvent
	assert_eq(gained.unit_id, sniper.id)
	assert_eq(gained.amount, 10)
	assert_eq(gained.reason, ExperienceGainedEvent.Reason.HIT)
	assert_eq(gained.experience, 10)
	assert_eq(sniper.experience, 10)
	assert_eq(sniper.level, 1)


func test_defeating_a_player_unit_gives_50_without_the_hit() -> void:
	var battle := _battle()
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(0, 0))  # 攻撃力 12
	var target := battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(1, 0))
	target.hp = 12
	var events := battle.apply(AttackAction.new(commando.id, target.id)).events
	assert_eq(
		_types(events),
		[AttackDamagedEvent, UnitDefeatedEvent, ExperienceGainedEvent, UnitActedEvent] as Array[Script]
	)
	var gained := events[2] as ExperienceGainedEvent
	assert_eq(gained.amount, 50)
	assert_eq(gained.reason, ExperienceGainedEvent.Reason.DEFEAT)
	assert_eq(commando.experience, 50)


func test_defeating_a_neutral_gives_80() -> void:
	var battle := _battle()
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(0, 0))
	var core := battle.add_unit(UnitKind.Id.MINION, NEUTRAL, Vector2i(1, 0))  # HP 12
	battle.apply(AttackAction.new(commando.id, core.id))
	assert_eq(commando.experience, 80)


func test_a_forest_that_saves_the_target_gives_only_the_hit() -> void:
	var battle := _battle()
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(1, 1))
	var core := battle.add_unit(UnitKind.Id.MINION, NEUTRAL, Vector2i(2, 1))  # 森で 12 → 9
	assert_eq(Growth.attack_experience(battle, commando, core), 10)
	battle.apply(AttackAction.new(commando.id, core.id))
	assert_eq(core.hp, 3)
	assert_eq(commando.experience, 10)


func test_healing_gives_20() -> void:
	var battle := _battle()
	var medic := battle.add_unit(UnitKind.Id.MEDIC, P1, Vector2i(0, 0))
	var ally := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(1, 0))
	ally.hp = 15  # 1 だけ回復する
	var events := battle.apply(HealAction.new(medic.id, ally.id)).events
	assert_eq(_types(events), [HealerHealedEvent, ExperienceGainedEvent, UnitActedEvent] as Array[Script])
	var gained := events[1] as ExperienceGainedEvent
	assert_eq(gained.amount, 20)  # 回復した量によらない
	assert_eq(gained.reason, ExperienceGainedEvent.Reason.HEAL)
	assert_eq(medic.experience, 20)


func test_kings_and_neutrals_do_not_grow() -> void:
	var battle := _battle()
	var king := battle.add_unit(UnitKind.Id.KING, P1, Vector2i(0, 0))
	var target := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(1, 0))
	var events := battle.apply(AttackAction.new(king.id, target.id)).events
	assert_eq(_types(events), [AttackDamagedEvent, UnitActedEvent] as Array[Script])
	assert_eq(king.experience, 0)
	assert_false(Growth.can_grow(king))
	var core := battle.add_unit(UnitKind.Id.MINION, NEUTRAL, Vector2i(5, 2))
	assert_false(Growth.can_grow(core))
	assert_eq(Growth.gain(core, 100, ExperienceGainedEvent.Reason.HIT), [] as Array[BattleEvent])
	assert_eq(core.level, 1)


func test_neutrals_attacking_give_no_experience() -> void:
	var battle := Maps.battle([
		"*..",
	])
	battle.board.font_cells = [Vector2i(0, 0)]
	var core := battle.add_unit(UnitKind.Id.MINION, NEUTRAL, Vector2i(0, 0))
	core.home_cell = Vector2i(0, 0)
	battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(1, 0))
	battle.phase = NEUTRAL
	var events := Neutral.play_phase(battle)
	assert_true(_types(events).has(AttackDamagedEvent))
	assert_false(_types(events).has(ExperienceGainedEvent))


func test_barrel_blasts_give_no_experience() -> void:
	var battle := Maps.battle([
		"..B.",
	])
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	var core := battle.add_unit(UnitKind.Id.MINION, NEUTRAL, Vector2i(3, 0))  # HP 12。爆発 15 で倒れる
	var events := battle.apply(AttackBarrelAction.new(sniper.id, Vector2i(2, 0))).events
	assert_eq(battle.unit_by_id(core.id), null)
	assert_false(_types(events).has(ExperienceGainedEvent))
	assert_eq(sniper.experience, 0)


func test_reaching_100_levels_up_and_carries_the_rest() -> void:
	var battle := _battle()
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(0, 0))
	commando.experience = 90
	var target := battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(1, 0))
	target.hp = 5
	var events := battle.apply(AttackAction.new(commando.id, target.id)).events
	assert_eq(
		_types(events),
		[AttackDamagedEvent, UnitDefeatedEvent, ExperienceGainedEvent, LevelUpEvent, UnitActedEvent] as Array[Script]
	)
	assert_eq((events[2] as ExperienceGainedEvent).experience, 140)  # レベルアップの前
	var up := events[3] as LevelUpEvent
	assert_eq(up.unit_id, commando.id)
	assert_eq(up.level, 2)
	assert_eq(up.experience, 40)
	assert_eq(up.gains, {Unit.Stat.MAX_HP: 3, Unit.Stat.POWER: 1})
	assert_eq(up.max_hp, 19)
	assert_eq(up.hp, 19)
	assert_eq(up.power, 13)
	assert_eq(commando.level, 2)
	assert_eq(commando.experience, 40)


func test_gains_depend_on_the_role() -> void:
	var battle := _battle()
	var expected := {
		UnitKind.Id.SHIELD_TROOPER: [44 + 6, 6 + 1],
		UnitKind.Id.SNIPER: [16 + 3, 9 + 1],
		UnitKind.Id.COMMANDO: [16 + 3, 12 + 1],
		UnitKind.Id.MEDIC: [20 + 3, 15 + 2],  # 回復ロールは回復量が伸びる
		UnitKind.Id.PALADIN: [40 + 6, 7 + 1],
		UnitKind.Id.SORCERER: [16 + 3, 8 + 1],
		UnitKind.Id.SPELLBLADE: [18 + 3, 11 + 1],
		UnitKind.Id.PRIEST: [18 + 3, 12 + 2],
	}
	var x := 0
	for kind: UnitKind.Id in expected:
		var unit := battle.add_unit(kind, P1, Vector2i(x % 6, 2 if x >= 6 else 0))
		x += 1
		Growth.gain(unit, 100, ExperienceGainedEvent.Reason.HIT)
		assert_eq([unit.max_hp(), unit.power()], expected[kind], UnitKind.display_name(kind))
		assert_eq(unit.move_range(), UnitKind.move_range(kind))
		assert_eq(unit.attack_range(), UnitKind.attack_range(kind))


func test_growth_keeps_the_damage_taken_and_the_base_values() -> void:
	var battle := _battle()
	var trooper := battle.add_unit(
		UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(0, 0), [Equipment.Id.IRON_SHIELD] as Array[Equipment.Id]
	)
	assert_eq(trooper.max_hp(), 74)
	trooper.hp = 30  # 44 減っている
	Growth.gain(trooper, 100, ExperienceGainedEvent.Reason.HIT)
	assert_eq(trooper.max_hp(), 80)
	assert_eq(trooper.hp, 36)  # 増えたぶんだけ増え、減っている量は 44 のまま
	assert_eq(UnitKind.max_hp(UnitKind.Id.SHIELD_TROOPER), 44)  # 種類の表は書き換えない
	assert_eq(trooper.growth_bonus, {Unit.Stat.MAX_HP: 6, Unit.Stat.POWER: 1})
	assert_eq(trooper.relic_bonus, {})


func test_max_hp_drops_cut_the_hp() -> void:
	var battle := _battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	var before := sniper.max_hp()
	sniper.temporary_bonus[Unit.Stat.MAX_HP] = -6
	sniper.follow_max_hp(before)
	assert_eq(sniper.hp, 10)
	before = sniper.max_hp()
	sniper.temporary_bonus.clear()
	sniper.follow_max_hp(before)
	assert_eq(sniper.hp, 16)


func test_level_3_is_the_cap() -> void:
	var battle := _battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	sniper.level = 2
	sniper.experience = 90
	var events := Growth.gain(sniper, 50, ExperienceGainedEvent.Reason.DEFEAT)
	assert_eq(_types(events), [ExperienceGainedEvent, LevelUpEvent] as Array[Script])
	assert_eq(sniper.level, 3)
	assert_eq(sniper.experience, 0)  # 上が無いので、余りは捨てる
	assert_eq((events[1] as LevelUpEvent).experience, 0)
	var target := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(3, 0))
	events = battle.apply(AttackAction.new(sniper.id, target.id)).events
	assert_eq(_types(events), [AttackDamagedEvent, UnitActedEvent] as Array[Script])
	assert_eq(sniper.level, 3)
	assert_eq(sniper.experience, 0)


func test_a_big_gain_can_level_up_twice() -> void:
	var battle := _battle()
	var priest := battle.add_unit(UnitKind.Id.PRIEST, P1, Vector2i(0, 0))
	var events := Growth.gain(priest, 250, ExperienceGainedEvent.Reason.HEAL)
	assert_eq(_types(events), [ExperienceGainedEvent, LevelUpEvent, LevelUpEvent] as Array[Script])
	assert_eq((events[1] as LevelUpEvent).level, 2)
	assert_eq((events[1] as LevelUpEvent).experience, 150)
	assert_eq((events[2] as LevelUpEvent).level, 3)
	assert_eq(priest.power(), 12 + 4)
	assert_eq(priest.max_hp(), 18 + 6)


func test_preview_does_not_change_the_unit_and_matches_gain() -> void:
	var battle := _battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	sniper.experience = 70
	var outcome := Growth.preview(sniper, 50)
	assert_eq(outcome.gained, 50)
	assert_eq(outcome.level, 2)
	assert_eq(outcome.experience, 20)
	assert_eq(outcome.levels_gained, 1)
	assert_eq(sniper.level, 1)
	assert_eq(sniper.experience, 70)
	assert_eq(sniper.max_hp(), 16)
	Growth.gain(sniper, 50, ExperienceGainedEvent.Reason.DEFEAT)
	assert_eq([sniper.level, sniper.experience], [outcome.level, outcome.experience])

	sniper.level = Growth.MAX_LEVEL
	sniper.experience = 0
	assert_eq(Growth.preview(sniper, 50).gained, 0)


func test_forecasting_on_a_clone_leaves_the_original() -> void:
	var battle := _battle()
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(0, 0))
	commando.experience = 60
	var target := battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(1, 0))
	target.hp = 12
	var copy := battle.clone()
	var events := copy.apply(AttackAction.new(commando.id, target.id)).events
	assert_true(_types(events).has(LevelUpEvent))
	var grown := copy.unit_by_id(commando.id)
	assert_eq([grown.level, grown.experience, grown.max_hp()], [2, 10, 19])
	assert_eq([commando.level, commando.experience, commando.max_hp()], [1, 60, 16])
	assert_eq(commando.growth_bonus, {})


func test_clone_copies_the_growth() -> void:
	var battle := _battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	Growth.gain(sniper, 130, ExperienceGainedEvent.Reason.HIT)
	var copy := battle.clone().unit_by_id(sniper.id)
	assert_eq([copy.level, copy.experience, copy.max_hp(), copy.power()], [2, 30, 19, 10])
	Growth.gain(copy, 100, ExperienceGainedEvent.Reason.HIT)
	assert_eq([sniper.level, sniper.max_hp()], [2, 19])  # 複製を育てても、元は変わらない
