extends "res://tests/base_test.gd"
## 戦績の集計（BattleStats。docs/battle-stats.md）。

const CpuGame := preload("res://tests/support/cpu_game.gd")
const Maps := preload("res://tests/support/maps.gd")

const P1 := Unit.Side.PLAYER1
const P2 := Unit.Side.PLAYER2
const NEUTRAL := Unit.Side.NEUTRAL


## battle に action を渡し、起きたことを stats に食わせる。
func _apply(battle: Battle, stats: BattleStats, action: BattleAction) -> ActionResult:
	var result := battle.apply(action)
	assert_true(result.accepted, "行動が断られた")
	stats.feed_all(result.events)
	return result


func test_attack_damage_and_kill_go_to_the_attacker() -> void:
	var battle := Maps.battle(["......", "......"])
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(0, 1))
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(2, 0))
	var stats := BattleStats.new(battle)
	var hit := _apply(battle, stats, AttackAction.new(sniper.id, paladin.id)).events[0] as AttackDamagedEvent
	assert_eq(stats.units[sniper.id].damage, hit.amount)
	assert_eq(stats.units[sniper.id].kills, 0)
	paladin.hp = 1
	_apply(battle, stats, MoveAction.new(commando.id, Vector2i(1, 0)))
	var last := _apply(battle, stats, AttackAction.new(commando.id, paladin.id)).events[0] as AttackDamagedEvent
	assert_eq(stats.units[commando.id].damage, last.amount)
	assert_eq(stats.units[commando.id].kills, 1)
	assert_eq(stats.units[sniper.id].kills, 0)
	assert_true(stats.units[paladin.id].defeated)
	assert_eq(stats.sides[P1].damage, hit.amount + last.amount)
	assert_eq(stats.sides[P1].kills, 1)
	assert_eq(stats.sides[P2].losses, 1)
	assert_eq(stats.sides[P2].damage, 0)


func test_neutral_damage_and_kills_are_counted_apart() -> void:
	var battle := Maps.battle(["......"])
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	var minion := battle.add_unit(UnitKind.Id.MINION, NEUTRAL, Vector2i(2, 0))
	minion.hp = 1
	var stats := BattleStats.new(battle)
	var hit := _apply(battle, stats, AttackAction.new(sniper.id, minion.id)).events[0] as AttackDamagedEvent
	assert_eq(stats.units[sniper.id].damage, 0)
	assert_eq(stats.units[sniper.id].neutral_damage, hit.amount)
	assert_eq(stats.units[sniper.id].neutral_kills, 1)
	assert_eq(stats.units[sniper.id].kills, 0)
	assert_eq(stats.sides[P1].neutral_kills, 1)


func test_barrel_blast_counts_for_the_attacker_except_on_allies() -> void:
	var battle := Maps.battle([
		".....",
		".FB..",
		".....",
		".....",
	])
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(4, 3))
	var enemy := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(3, 0))
	var ally := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(1, 1))
	enemy.hp = 1
	var stats := BattleStats.new(battle)
	var result := _apply(battle, stats, AttackBarrelAction.new(sniper.id, Vector2i(2, 1)))
	var on_enemy := 0
	for event in result.events:
		if event is ExplosionDamagedEvent and (event as ExplosionDamagedEvent).unit_id == enemy.id:
			on_enemy = (event as ExplosionDamagedEvent).amount
	assert_true(ally.hp < ally.max_hp(), "味方が爆発に巻き込まれていない")
	assert_eq(stats.units[sniper.id].damage, on_enemy)
	assert_eq(stats.units[sniper.id].kills, 1)
	assert_eq(stats.sides[P1].losses, 0)


func test_one_fireball_can_kill_several_units() -> void:
	var battle := Maps.battle(["........", "........", "........"])
	var sorcerer := battle.add_unit(UnitKind.Id.SORCERER, P1, Vector2i(1, 1))
	var a := battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(4, 1))
	var b := battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(5, 1))
	a.hp = 1
	b.hp = 1
	var stats := BattleStats.new(battle)
	_apply(battle, stats, UseSkillAction.new(sorcerer.id, Vector2i(4, 1)))
	assert_eq(stats.units[sorcerer.id].kills, 2)
	assert_eq(stats.units[sorcerer.id].skill_uses, 1)
	assert_eq(stats.sides[P1].skill_uses, 1)
	assert_true(stats.units[sorcerer.id].damage >= 2)


func test_healing_counts_for_the_healer_and_the_sanctuary_owner() -> void:
	var battle := Maps.battle([".....", ".....", "....."])
	var medic := battle.add_unit(UnitKind.Id.MEDIC, P1, Vector2i(0, 0))
	var priest := battle.add_unit(UnitKind.Id.PRIEST, P1, Vector2i(1, 1))
	var wounded := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(3, 1))
	var other := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 1))
	wounded.hp -= 30
	other.hp -= 5
	var stats := BattleStats.new(battle)
	var healed := _apply(battle, stats, HealAction.new(medic.id, other.id)).events[0] as HealerHealedEvent
	assert_eq(stats.units[medic.id].healing, healed.amount)
	_apply(battle, stats, UseSkillAction.new(priest.id, Vector2i(3, 1)))
	var by_sanctuary := 0
	for i in 3:
		for event in _apply(battle, stats, EndPhaseAction.new()).events:
			if event is SanctuaryHealedEvent:
				by_sanctuary += (event as SanctuaryHealedEvent).amount
	assert_true(by_sanctuary >= FieldEffects.SANCTUARY_HEAL, "聖域が回復しなかった")
	assert_eq(stats.units[priest.id].healing, by_sanctuary)
	assert_eq(stats.sides[P1].healing, healed.amount + by_sanctuary)


func test_level_evolution_ult_relic_and_mid_boss() -> void:
	var battle := Maps.battle(["......"])
	var trooper := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(0, 0))
	var boss := battle.add_unit(UnitKind.Id.ELITE_MINION, NEUTRAL, Vector2i(3, 0))
	var stats := BattleStats.new(battle)
	battle.turn = 4
	trooper.level = 2
	stats.feed(LevelUpEvent.new(trooper, {}))
	trooper.level = 3
	stats.feed(LevelUpEvent.new(trooper, {}))
	trooper.evolution = Evolution.Id.BULWARK
	stats.feed(UnitEvolvedEvent.new(trooper))
	stats.feed(UltUsedEvent.new(P2, Ult.Id.MANA_ERUPTION))
	battle.turn = 6
	stats.feed(UltUsedEvent.new(P2, Ult.Id.MANA_ERUPTION))
	stats.feed(MidBossDefeatedEvent.new(1, boss, trooper))
	stats.feed(RelicGainedEvent.new(P1, Relics.Id.COURAGE, 1, [trooper] as Array[Unit], 30, 30))
	var record := stats.units[trooper.id]
	assert_eq(record.level, 3)
	assert_eq(record.evolution, Evolution.Id.BULWARK)
	assert_eq(record.evolved_turn, 4)
	assert_eq(record.boss_kills, 1)
	assert_eq(stats.sides[P1].level_ups, 2)
	assert_eq(stats.sides[P1].evolutions, 1)
	assert_eq(stats.sides[P1].relics, [Relics.Id.COURAGE] as Array[Relics.Id])
	assert_eq(stats.sides[P2].ult_uses, 2)
	assert_eq(stats.sides[P2].first_ult_turn, 4)
	assert_eq(stats.mid_bosses, [[6, 1, P1]] as Array[Array])


func test_spawned_neutrals_get_a_record() -> void:
	var battle := Maps.battle(["......"])
	var stats := BattleStats.new(battle)
	var minion := battle.add_unit(UnitKind.Id.MINION, NEUTRAL, Vector2i(4, 0))
	stats.feed(UnitSpawnedEvent.new(minion))
	assert_eq(stats.units[minion.id].side, NEUTRAL)
	assert_eq(stats.units[minion.id].kind, UnitKind.Id.MINION)


func test_ending_winner_and_turns() -> void:
	var battle := Maps.battle(["......", "......"])
	battle.board.hq_cells = [Vector2i(0, 1), Vector2i(5, 0)]
	battle.add_unit(UnitKind.Id.KING, P1, Vector2i(0, 1))
	var king := battle.add_unit(UnitKind.Id.KING, P2, Vector2i(5, 0))
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(3, 0))
	var stats := BattleStats.new(battle)
	_apply(battle, stats, EndPhaseAction.new())
	_apply(battle, stats, EndPhaseAction.new())  # 中立の番は、続けて終わる
	assert_eq(battle.phase, P1)
	assert_false(stats.is_over())
	assert_eq(stats.turns, 2)
	king.hp = 1
	_apply(battle, stats, AttackAction.new(sniper.id, king.id))
	assert_true(stats.is_over())
	assert_eq(stats.ending, BattleStats.Ending.KING_DEFEATED)
	assert_eq(stats.winner, P1)
	assert_eq(stats.turns, 2)
	assert_eq(stats.units[sniper.id].kills, 1)
	assert_eq(stats.sides[P2].losses, 0, "将は倒された駒に数えない")


func test_draw_has_no_winner() -> void:
	var battle := Maps.battle(["......"])
	var stats := BattleStats.new(battle)
	stats.feed(GameDrawnEvent.new(GameDrawnEvent.Reason.BOTH_KINGS_DEFEATED))
	assert_eq(stats.ending, BattleStats.Ending.DRAW)
	assert_eq(stats.winner, -1)


func test_mvp_is_the_non_king_that_dealt_the_most_damage() -> void:
	var battle := Maps.battle(["......"])
	var king := battle.add_unit(UnitKind.Id.KING, P1, Vector2i(0, 0))
	var a := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(1, 0))
	var b := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(2, 0))
	var c := battle.add_unit(UnitKind.Id.MEDIC, P1, Vector2i(3, 0))
	var stats := BattleStats.new(battle)
	assert_eq(stats.mvp(P1), null, "ダメージを与えた駒がいなければ MVP はいない")
	stats.units[king.id].damage = 99
	stats.units[a.id].damage = 30
	stats.units[b.id].damage = 30
	stats.units[c.id].damage = 0
	assert_eq(stats.mvp(P1).unit_id, a.id, "同じなら番号の小さいほう")
	stats.units[b.id].kills = 1
	assert_eq(stats.mvp(P1).unit_id, b.id, "同じダメージなら、倒した数が多いほう")
	stats.units[a.id].damage = 31
	assert_eq(stats.mvp(P1).unit_id, a.id)
	assert_eq(stats.mvp(P2), null)


## CPU どうしの 1 局（ほかのテストと共有する。tests/support/cpu_game.gd）を最後まで数える。
## 陣営の合計が、駒ごとの戦績の和と合う。
func test_side_totals_match_the_unit_records_in_a_cpu_game() -> void:
	var battle := CpuGame.start()
	var stats := BattleStats.new(battle)
	CpuGame.replay(battle, func(result: ActionResult) -> void: stats.feed_all(result.events))
	_assert_side_totals(stats)
	assert_eq(stats.turns, battle.turn)
	assert_true(stats.ending != BattleStats.Ending.NONE, "決着を数えていない")


## 生成した盤面（中立の駒がいる）で、CPU どうしに 8 ターン進めて数える。盤面が大きく、時間が掛かるので長い検査に回す
## （PR ごとの検査では、上の小さい盤面の 1 局と、自動の対戦の決着の画面がこの集計を通る）。
func test_long_side_totals_match_the_unit_records_on_a_generated_stage() -> void:
	var setup := MatchSetup.versus_cpu(
		BoardGenerator.Stage.PLAIN, 2, MatchSetup.default_deck(UnitKind.Army.MILITARY), UnitKind.Army.FANTASY
	)
	setup.set_cpu(P1, UnitKind.Army.MILITARY)
	var battle := setup.create_battle()
	var stats := BattleStats.new(battle)
	var cpu := CpuPlayer.new()
	while not battle.is_over() and battle.turn <= 8:
		_apply(battle, stats, cpu.next_action(battle))
	_assert_side_totals(stats)
	assert_eq(stats.turns, battle.turn)


## 陣営ごとに、駒の戦績の和が陣営の合計と合うこと。どちらの陣営もダメージを与えていること。
func _assert_side_totals(stats: BattleStats) -> void:
	for side: Unit.Side in [P1, P2]:
		var totals := [0, 0, 0, 0, 0]
		for record in stats.records_of(side):
			totals[0] += record.damage
			totals[1] += record.kills
			totals[2] += record.neutral_kills
			totals[3] += record.healing
			totals[4] += record.skill_uses
		var side_record := stats.sides[side]
		assert_eq(totals, [
			side_record.damage, side_record.kills, side_record.neutral_kills, side_record.healing, side_record.skill_uses,
		])
		assert_true(side_record.damage > 0, "ダメージを与えていない")

