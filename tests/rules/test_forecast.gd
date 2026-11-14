extends "res://tests/base_test.gd"
## 戦闘予測（docs/battle-forecast.md）: 行動をいま行ったら何が起きるかを、状態を変えずに返す。
## 予測は、直後に同じ行動をしたときの結果と一致すること。

const Maps := preload("res://tests/support/maps.gd")

const P1 := Unit.Side.PLAYER1
const P2 := Unit.Side.PLAYER2
const NEUTRAL := Unit.Side.NEUTRAL


func _open() -> Battle:
	return Maps.battle([
		"........",
		"..F.....",
		"........",
		"........",
	])


## 予測した行動を実際に行い、駒ごとの HP と、倒れたか、入った経験値が予測と一致することを確かめる。
func _matches_the_real_result(battle: Battle, action: BattleAction) -> void:
	var forecast := Forecast.of(battle, action)
	var ids: Array[int] = []
	for unit in battle.units:
		ids.append(unit.id)
	var experience: Dictionary[int, int] = {}
	for unit in battle.units:
		experience[unit.id] = unit.experience + (unit.level - 1) * Growth.EXPERIENCE_PER_LEVEL
	var result := battle.apply(action)
	assert_eq(result.accepted, forecast.accepted)
	assert_eq(result.events.size(), forecast.events.size(), "同じイベントの列")
	for id in ids:
		var unit := battle.unit_by_id(id)
		var outcome := forecast.outcome(id)
		if outcome == null:
			continue
		assert_eq(outcome.hp_after, unit.hp if unit != null else 0, "残りの HP")
		assert_eq(outcome.defeated, unit == null, "倒れるか")
		if unit != null:
			var gained := unit.experience + (unit.level - 1) * Growth.EXPERIENCE_PER_LEVEL - experience[id]
			if unit.level < Growth.MAX_LEVEL:
				assert_eq(outcome.experience, gained, "経験値")
	assert_eq(forecast.gauge_after, battle.ult_gauge, "ゲージ")
	assert_eq(forecast.winner, battle.winner)


func test_attack_damage_and_remaining_hp() -> void:
	var battle := _open()
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(4, 2))
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(5, 2))
	var forecast := Forecast.of(battle, AttackAction.new(commando.id, paladin.id))
	assert_true(forecast.accepted)
	var hit := forecast.outcome(paladin.id)
	assert_eq(hit.hp_before, paladin.hp)
	assert_eq(hit.damage, commando.power())
	assert_eq(hit.hp_after, paladin.hp - commando.power())
	assert_false(hit.defeated)
	assert_false(hit.forest)
	assert_eq(forecast.outcome(commando.id).experience, Growth.HIT_EXPERIENCE)
	assert_eq(paladin.hp, paladin.max_hp(), "予測では状態は変わらない")
	_matches_the_real_result(battle, AttackAction.new(commando.id, paladin.id))


func test_forest_critical_barrier_and_smoke() -> void:
	var battle := _open()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(2, 3))
	var in_forest := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(2, 1))
	var forest := Forecast.of(battle, AttackAction.new(sniper.id, in_forest.id)).outcome(in_forest.id)
	assert_true(forest.forest)
	assert_eq(forest.damage, sniper.power() * Combat.FOREST_DAMAGE_RATE_PERCENT / 100)
	Statuses.add(sniper, Status.Type.AIM, 2)
	var critical := Forecast.of(battle, AttackAction.new(sniper.id, in_forest.id)).outcome(in_forest.id)
	assert_true(critical.critical)
	assert_eq(critical.damage, sniper.power() * 2 * Combat.FOREST_DAMAGE_RATE_PERCENT / 100, "倍率のあとに森")
	Statuses.add(in_forest, Status.Type.BARRIER, 2)
	var blocked := Forecast.of(battle, AttackAction.new(sniper.id, in_forest.id))
	assert_eq(blocked.outcome(in_forest.id).damage, 0)
	assert_eq(blocked.outcome(in_forest.id).blocked_by, Status.Type.BARRIER)
	assert_true(blocked.outcome(in_forest.id).statuses_removed.has(Status.Type.BARRIER), "バリアは外れる")
	assert_true(blocked.outcome(sniper.id).statuses_removed.has(Status.Type.AIM), "照準も外れる")
	Statuses.remove(in_forest, Status.Type.BARRIER, StatusRemovedEvent.Reason.EXPIRED)
	FieldEffects.place_smoke(battle, P2, in_forest.cell)
	var smoked := Forecast.of(battle, AttackAction.new(sniper.id, in_forest.id))
	assert_true(smoked.outcome(in_forest.id).smoked)
	assert_eq(smoked.outcome(in_forest.id).hp_after, in_forest.hp)
	assert_eq(smoked.outcome(sniper.id).experience, 0, "阻まれた攻撃では経験値は入らない")
	_matches_the_real_result(battle, AttackAction.new(sniper.id, in_forest.id))


func test_defeat_experience_level_up_and_evolution() -> void:
	var battle := _open()
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(4, 2))
	commando.level = Growth.MAX_LEVEL - 1
	commando.experience = Growth.EXPERIENCE_PER_LEVEL - Growth.DEFEAT_EXPERIENCE
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(5, 2))
	sniper.hp = 1
	var forecast := Forecast.of(battle, AttackAction.new(commando.id, sniper.id))
	assert_true(forecast.outcome(sniper.id).defeated)
	assert_eq(forecast.defeated_ids(), [sniper.id] as Array[int])
	var grown := forecast.outcome(commando.id)
	assert_eq(grown.experience, Growth.DEFEAT_EXPERIENCE)
	assert_eq(grown.levels_gained, 1)
	assert_true(grown.evolution_ready)
	assert_false(commando.evolution_ready)


func test_barrel_lists_everyone_in_the_blast_including_the_attacker() -> void:
	var battle := Maps.battle([
		".....",
		"..B..",
		".....",
	])
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(1, 1))
	var friend := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(3, 0))
	var enemy := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(2, 2))
	Statuses.add(enemy, Status.Type.BARRIER, 2)
	var forecast := Forecast.of(battle, AttackBarrelAction.new(commando.id, Vector2i(2, 1)))
	for unit: Unit in [commando, friend, enemy]:
		assert_true(forecast.outcome(unit.id).exploded, unit.display_name())
	assert_eq(forecast.outcome(commando.id).damage, MapObject.BLAST_DAMAGE, "自分も巻き込まれる")
	assert_eq(forecast.outcome(friend.id).damage, MapObject.BLAST_DAMAGE)
	assert_eq(forecast.outcome(friend.id).hp_after, maxi(0, friend.hp - MapObject.BLAST_DAMAGE))
	assert_eq(forecast.outcome(enemy.id).blocked_by, Status.Type.BARRIER, "バリアは爆発も防ぐ")
	_matches_the_real_result(battle, AttackBarrelAction.new(commando.id, Vector2i(2, 1)))


func test_barricade_durability() -> void:
	var battle := _open()
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(4, 2))
	FieldEffects.place_barricade(battle, P2, Vector2i(5, 2))
	var before := battle.board.barricade_at(Vector2i(5, 2)).durability
	var forecast := Forecast.of(battle, AttackBarricadeAction.new(commando.id, Vector2i(5, 2)))
	assert_eq(forecast.barricades.size(), 1)
	var chipped := forecast.barricades[0]
	assert_eq(chipped.durability_before, before)
	assert_eq(chipped.durability_after, maxi(0, before - FieldEffects.barricade_damage(commando)))
	assert_eq(chipped.destroyed, chipped.durability_after == 0)
	assert_eq(battle.board.barricade_at(Vector2i(5, 2)).durability, before, "予測では削れない")


func test_heal_is_clamped_to_max_hp() -> void:
	var battle := _open()
	var medic := battle.add_unit(UnitKind.Id.MEDIC, P1, Vector2i(4, 2))
	var friend := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(5, 2))
	friend.hp = friend.max_hp() - 3
	var healed := Forecast.of(battle, HealAction.new(medic.id, friend.id)).outcome(friend.id)
	assert_eq(healed.healed, 3)
	assert_eq(healed.hp_after, friend.max_hp())
	assert_eq(Forecast.of(battle, HealAction.new(medic.id, friend.id)).outcome(medic.id).experience, Growth.HEAL_EXPERIENCE)
	_matches_the_real_result(battle, HealAction.new(medic.id, friend.id))


func test_fireball_lists_each_victim() -> void:
	var battle := _open()
	var sorcerer := battle.add_unit(UnitKind.Id.SORCERER, P1, Vector2i(0, 1))
	var in_forest := battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(2, 1))
	var shielded := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(3, 1))
	Statuses.add(shielded, Status.Type.BARRIER, 2)
	var forecast := Forecast.of(battle, UseSkillAction.new(sorcerer.id, Vector2i(2, 1)))
	assert_eq(forecast.outcome(in_forest.id).damage, FireballSkill.DAMAGE, "森で減らない")
	assert_false(forecast.outcome(in_forest.id).forest)
	assert_eq(forecast.outcome(shielded.id).blocked_by, Status.Type.BARRIER)
	assert_eq(Skills.preview(battle, sorcerer.id, Vector2i(2, 1)).size(), forecast.events.size(), "Skills.preview は同じ予測のイベント")
	_matches_the_real_result(battle, UseSkillAction.new(sorcerer.id, Vector2i(2, 1)))


func test_ult_and_gauge() -> void:
	var battle := _open()
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(4, 2))
	battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(5, 2))
	battle.ult_gauge[P1] = Ults.GAUGE_MAX
	var forecast := Forecast.of(battle, UseUltAction.new())
	assert_true(forecast.outcome(commando.id).statuses_applied.has(Status.Type.ASSAULT))
	assert_eq(forecast.gauge_before[P1], Ults.GAUGE_MAX)
	assert_eq(forecast.gauge_after[P1], 0)
	assert_eq(battle.ult_gauge[P1], Ults.GAUGE_MAX)


func test_attack_charges_the_gauges() -> void:
	var battle := _open()
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(4, 2))
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(5, 2))
	var forecast := Forecast.of(battle, AttackAction.new(commando.id, paladin.id))
	assert_eq(forecast.gauge_after[P1], commando.power() * Ults.DEALT_GAIN)
	assert_eq(forecast.gauge_after[P2], commando.power() * Ults.TAKEN_GAIN)


func test_mid_boss_kill_shows_the_relic() -> void:
	var battle := _open()
	battle.board.mid_boss_cells = [Vector2i(5, 2)]
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(4, 2))
	var boss := battle.add_unit(UnitKind.Id.ELITE_MINION, NEUTRAL, Vector2i(5, 2))
	boss.home_cell = boss.cell
	boss.hp = 1
	var forecast := Forecast.of(battle, AttackAction.new(commando.id, boss.id))
	assert_eq(forecast.relics.size(), 1)
	assert_eq(forecast.relics[0].side, P1)
	assert_true(battle.relics[P1].is_empty())


func test_king_kill_shows_the_winner() -> void:
	var battle := _open()
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(4, 2))
	var king := battle.add_unit(UnitKind.Id.KING, P2, Vector2i(5, 2))
	king.hp = 1
	assert_eq(Forecast.of(battle, AttackAction.new(commando.id, king.id)).winner, P1)
	assert_false(battle.is_over())


func test_shadow_step_shows_where_units_go() -> void:
	var battle := _open()
	var blade := battle.add_unit(UnitKind.Id.SPELLBLADE, P1, Vector2i(1, 2))
	var enemy := battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(3, 2))
	var forecast := Forecast.of(battle, UseSkillAction.new(blade.id, enemy.cell))
	assert_eq(forecast.outcome(blade.id).moved_to, Vector2i(3, 2))
	assert_eq(forecast.outcome(enemy.id).moved_to, Vector2i(1, 2))


func test_rejected_action_has_no_outcome() -> void:
	var battle := _open()
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(0, 0))
	var far := battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(7, 3))
	var forecast := Forecast.of(battle, AttackAction.new(commando.id, far.id))
	assert_false(forecast.accepted)
	assert_true(forecast.events.is_empty())
	assert_true(forecast.units.is_empty())
	assert_eq(forecast.after, null)


func test_forecast_does_not_draw_from_the_battle_rng() -> void:
	# 中立の駒が同点の相手を選ぶとき（Neutral._closest）、乱数を引く。予測は複製の乱数で引く。
	var battle := Maps.battle([
		".......",
		".......",
		".......",
	])
	battle.rng.seed = 7
	battle.add_unit(UnitKind.Id.KING, P1, Vector2i(0, 0))
	battle.add_unit(UnitKind.Id.KING, P2, Vector2i(6, 0))
	battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(2, 1))
	battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(4, 1))
	var minion := battle.add_unit(UnitKind.Id.MINION, NEUTRAL, Vector2i(3, 1))
	minion.home_cell = minion.cell
	battle.apply(EndPhaseAction.new())  # プレイヤー2 の番。次の終わりで中立のフェーズ
	var state := battle.rng.state
	var forecast := Forecast.of(battle, EndPhaseAction.new())
	assert_eq(battle.rng.state, state, "元の乱数は進まない")
	_matches_the_real_result(battle, EndPhaseAction.new())
	assert_true(forecast.accepted)
