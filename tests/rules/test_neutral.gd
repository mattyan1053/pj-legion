extends "res://tests/base_test.gd"
## 中立のフェーズ: エナジー・コアが結晶泉に湧き、縄張りの中で近くのプレイヤーの駒を襲う（docs/neutral-minion.md）。

const Maps := preload("res://tests/support/maps.gd")

const P1 := Unit.Side.PLAYER1
const P2 := Unit.Side.PLAYER2
const NEUTRAL := Unit.Side.NEUTRAL


## プレイヤー2 のフェーズまで進めておく（次の EndPhaseAction で中立のフェーズが回る）。
func _to_player2(battle: Battle) -> void:
	battle.apply(EndPhaseAction.new())


## 中立のフェーズを 1 回回し、そこで起きたこと（中立の PhaseStartedEvent の次から、次のフェーズの手前まで）を返す。
func _neutral_phase(battle: Battle) -> Array[BattleEvent]:
	if battle.phase == P1:
		_to_player2(battle)
	var events := battle.apply(EndPhaseAction.new()).events
	var result: Array[BattleEvent] = []
	var inside := false
	for event in events:
		var started := event as PhaseStartedEvent
		if started != null:
			inside = started.side == NEUTRAL
			continue
		if inside:
			result.append(event)
	return result


func _core(battle: Battle, cell: Vector2i, home := Board.NO_CELL) -> Unit:
	var unit := battle.add_unit(UnitKind.Id.MINION, NEUTRAL, cell)
	unit.home_cell = cell if home == Board.NO_CELL else home
	return unit


func _types(events: Array[BattleEvent]) -> Array[Script]:
	var result: Array[Script] = []
	for event in events:
		result.append(event.get_script())
	return result


# ---- 湧く ----


func test_turn_1_spawns_a_core_on_every_font() -> void:
	var battle := Maps.battle([
		".......",
		".*...*.",
		".......",
	])
	var events := _neutral_phase(battle)
	assert_eq(events.size(), 2)
	var first := events[0] as UnitSpawnedEvent
	var second := events[1] as UnitSpawnedEvent
	assert_eq(first.cell, Vector2i(1, 1))
	assert_eq(second.cell, Vector2i(5, 1))
	assert_eq(first.kind, UnitKind.Id.MINION)
	assert_eq(first.side, NEUTRAL)
	assert_eq(first.home_cell, Vector2i(1, 1))
	assert_eq(first.hp, 12)
	assert_eq(first.max_hp, 12)
	var unit := battle.unit_by_id(first.unit_id)
	assert_eq(unit.cell, Vector2i(1, 1))
	assert_eq(unit.home_cell, Vector2i(1, 1))
	assert_eq(unit.side, NEUTRAL)


func test_a_font_keeps_one_core_while_it_lives() -> void:
	var battle := Maps.battle([
		"*......",
		".......",
	])
	_neutral_phase(battle)
	var core := battle.unit_at(Vector2i(0, 0))
	# 遠くへ動かしても、その泉の駒は生きているので、もう湧かない。
	core.cell = Vector2i(4, 1)
	for i in 10:
		var events := _neutral_phase(battle)
		assert_eq(_types(events).count(UnitSpawnedEvent), 0)
	assert_eq(battle.units.size(), 1)


func test_a_font_respawns_by_chance_after_its_core_falls() -> void:
	var battle := Maps.battle([
		"*......",
		".......",
	])
	_neutral_phase(battle)
	battle.units.clear()
	var phases_until_spawn := 0
	while Neutral.guardian_of(battle, Vector2i(0, 0)) == null:
		phases_until_spawn += 1
		assert_true(phases_until_spawn < 100, "いつまでも湧かない")
		if phases_until_spawn >= 100:
			return
		_neutral_phase(battle)
	assert_eq(battle.unit_at(Vector2i(0, 0)).kind, UnitKind.Id.MINION)


func test_respawn_chance_is_about_the_tuning_value() -> void:
	var spawned := 0
	var trials := 400
	for i in trials:
		var battle := Battle.new(Maps.board(["*."]), i)
		battle.turn = 2
		battle.phase = P2
		if not Neutral.spawn(battle).is_empty():
			spawned += 1
	assert_between(spawned * 100.0 / trials, Neutral.RESPAWN_CHANCE_PERCENT - 8, Neutral.RESPAWN_CHANCE_PERCENT + 8)


func test_a_unit_standing_on_the_font_blocks_the_spawn() -> void:
	var battle := Maps.battle([
		"*......",
		".......",
	])
	var sitter := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(0, 0))
	var events := _neutral_phase(battle)
	assert_eq(_types(events).count(UnitSpawnedEvent), 0)
	assert_eq(battle.unit_at(Vector2i(0, 0)), sitter)


func test_spawned_cores_wait_until_the_next_neutral_phase() -> void:
	var battle := Maps.battle([
		"*.......",
	])
	battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(2, 0))
	var events := _neutral_phase(battle)
	assert_eq(_types(events), [UnitSpawnedEvent] as Array[Script], "湧いたフェーズには動かない")
	events = _neutral_phase(battle)
	assert_eq(_types(events), [UnitMovedEvent, AttackDamagedEvent] as Array[Script])


# ---- 動いて攻撃する ----


func test_core_walks_to_the_nearest_player_unit_and_attacks() -> void:
	var battle := Maps.battle([
		"........",
		"........",
	])
	var core := _core(battle, Vector2i(0, 0))
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(3, 0))
	battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(6, 1))
	var events := _neutral_phase(battle)
	assert_eq(_types(events), [UnitMovedEvent, AttackDamagedEvent] as Array[Script])
	var moved := events[0] as UnitMovedEvent
	assert_eq(moved.unit_id, core.id)
	assert_eq(moved.path, [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)] as Array[Vector2i])
	assert_false(moved.cruise)
	var hit := events[1] as AttackDamagedEvent
	assert_eq(hit.attacker_id, core.id)
	assert_eq(hit.unit_id, sniper.id)
	assert_eq(hit.amount, 4)
	assert_eq(sniper.hp, 8)
	assert_eq(core.cell, Vector2i(2, 0))


func test_core_attacks_without_moving_when_already_in_range() -> void:
	var battle := Maps.battle([
		"....",
	])
	_core(battle, Vector2i(1, 0))
	var king := battle.add_unit(UnitKind.Id.KING, P2, Vector2i(2, 0))
	var events := _neutral_phase(battle)
	assert_eq(_types(events), [AttackDamagedEvent] as Array[Script])
	assert_eq(king.hp, 30 - 4)


func test_core_uses_the_same_damage_as_players_forest_reduces_it() -> void:
	var battle := Maps.battle([
		".F",
	])
	_core(battle, Vector2i(0, 0))
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(1, 0))
	var events := _neutral_phase(battle)
	assert_eq((events[0] as AttackDamagedEvent).amount, 4 * 80 / 100)
	assert_eq(sniper.hp, 12 - 3)


func test_core_defeats_a_weak_unit() -> void:
	var battle := Maps.battle([
		"..",
	])
	_core(battle, Vector2i(0, 0))
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(1, 0))
	sniper.hp = 3
	var events := _neutral_phase(battle)
	assert_eq(_types(events), [AttackDamagedEvent, UnitDefeatedEvent] as Array[Script])
	assert_false(battle.units.has(sniper))


func test_core_moves_with_its_own_move_range() -> void:
	var battle := Maps.battle([
		"..........",
	])
	var core := _core(battle, Vector2i(0, 0), Vector2i(2, 0))
	battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(6, 0))
	var events := _neutral_phase(battle)
	assert_eq(_types(events), [UnitMovedEvent] as Array[Script])
	assert_eq(core.cell, Vector2i(2, 0), "移動力 2 まで")


func test_core_stays_inside_its_territory() -> void:
	var battle := Maps.battle([
		"............",
	])
	var core := _core(battle, Vector2i(0, 0))
	# 家から 5（縄張り 4 + 射程 1）なので狙うが、縄張りの外には出ない。
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(5, 0))
	for i in 4:
		_neutral_phase(battle)
	assert_eq(core.cell, Vector2i(Neutral.TERRITORY_RADIUS, 0))
	assert_true(sniper.hp < sniper.max_hp(), "縄張りの端から攻撃する")


func test_core_ignores_units_out_of_reach_of_its_territory() -> void:
	var battle := Maps.battle([
		"............",
	])
	var core := _core(battle, Vector2i(0, 0))
	battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(Neutral.TERRITORY_RADIUS + 2, 0))
	var events := _neutral_phase(battle)
	assert_eq(events.size(), 0)
	assert_eq(core.cell, Vector2i(0, 0))


func test_core_returns_home_when_nobody_is_around() -> void:
	var battle := Maps.battle([
		"........",
	])
	var core := _core(battle, Vector2i(4, 0), Vector2i(0, 0))
	var events := _neutral_phase(battle)
	assert_eq(_types(events), [UnitMovedEvent] as Array[Script])
	assert_eq(core.cell, Vector2i(2, 0))
	_neutral_phase(battle)
	assert_eq(core.cell, Vector2i(0, 0))
	assert_eq(_neutral_phase(battle).size(), 0, "家にいれば動かない")


func test_nearest_target_then_lowest_hp() -> void:
	var battle := Maps.battle([
		".....",
		".....",
		".....",
	])
	var core := _core(battle, Vector2i(2, 1))
	var far := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	var near_full := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(2, 0))
	var near_hurt := battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(2, 2))
	far.hp = 1
	near_hurt.hp = 10
	assert_eq(Neutral.target_of(battle, core), near_hurt)
	var events := _neutral_phase(battle)
	assert_eq((events[0] as AttackDamagedEvent).unit_id, near_hurt.id)
	assert_eq(near_full.hp, near_full.max_hp())


func test_ties_are_broken_by_rng_and_reach_both_players() -> void:
	var picked := {}
	for i in 40:
		var battle := Battle.new(Maps.board([".....", ".....", "....."]), i)
		var core := _core(battle, Vector2i(2, 1))
		var top := battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(2, 0))
		battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(2, 2))
		var target := Neutral.target_of(battle, core)
		picked[target.side] = true
		assert_true(target == top or target.cell == Vector2i(2, 2))
	assert_eq(picked.size(), 2, "同点ならどちらのプレイヤーも狙われる")


func test_cores_do_not_attack_each_other() -> void:
	var battle := Maps.battle([
		"...",
	])
	_core(battle, Vector2i(0, 0))
	_core(battle, Vector2i(1, 0))
	var events := _neutral_phase(battle)
	assert_eq(events.size(), 0)


func test_cores_act_one_by_one_in_id_order() -> void:
	var battle := Maps.battle([
		"........",
	])
	var first := _core(battle, Vector2i(0, 0))
	var second := _core(battle, Vector2i(6, 0))
	var king := battle.add_unit(UnitKind.Id.KING, P1, Vector2i(3, 0))
	var events := _neutral_phase(battle)
	assert_eq(_types(events), [UnitMovedEvent, AttackDamagedEvent, UnitMovedEvent, AttackDamagedEvent] as Array[Script])
	assert_eq((events[0] as UnitMovedEvent).unit_id, first.id)
	assert_eq((events[2] as UnitMovedEvent).unit_id, second.id)
	assert_eq((events[3] as AttackDamagedEvent).hp, king.hp)
	assert_eq(king.hp, 30 - 8)


func test_neutral_units_are_never_marked_acted() -> void:
	var battle := Maps.battle([
		"...",
	])
	var core := _core(battle, Vector2i(0, 0))
	battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(2, 0))
	var events := _neutral_phase(battle)
	assert_eq(_types(events).count(UnitActedEvent), 0)
	assert_false(core.acted)


func test_players_can_attack_cores() -> void:
	var battle := Maps.battle([
		"...",
	])
	var core := _core(battle, Vector2i(1, 0))
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(0, 0))
	var events := battle.apply(AttackAction.new(commando.id, core.id)).events
	assert_eq(
		_types(events),
		[AttackDamagedEvent, UnitDefeatedEvent, ExperienceGainedEvent, UnitActedEvent] as Array[Script]
	)


func test_players_cannot_move_cores() -> void:
	var battle := Maps.battle([
		"...",
	])
	var core := _core(battle, Vector2i(0, 0))
	assert_false(battle.apply(MoveAction.new(core.id, Vector2i(1, 0))).accepted)
	assert_true(battle.options(core.id).is_empty())


# ---- 勝ち負け ----


func test_core_defeating_a_king_ends_the_game_in_the_neutral_phase() -> void:
	var battle := Maps.battle([
		"*......",
		".......",
	])
	var first := _core(battle, Vector2i(0, 1), Vector2i(0, 1))
	var second := _core(battle, Vector2i(3, 1), Vector2i(3, 1))
	var king := battle.add_unit(UnitKind.Id.KING, P2, Vector2i(1, 1))
	battle.add_unit(UnitKind.Id.KING, P1, Vector2i(6, 0))
	king.hp = 2
	_to_player2(battle)
	var events := battle.apply(EndPhaseAction.new()).events
	assert_eq(_types(events), [PhaseStartedEvent, AttackDamagedEvent, UnitDefeatedEvent, GameWonEvent] as Array[Script])
	assert_eq((events[1] as AttackDamagedEvent).attacker_id, first.id)
	assert_eq((events[3] as GameWonEvent).winner, P1)
	assert_true(battle.is_over())
	assert_eq(battle.turn, 1, "次のターンへは進まない")
	assert_eq(battle.phase, NEUTRAL)
	assert_eq(second.cell, Vector2i(3, 1), "決着のあとの駒は動かない")
	assert_eq(battle.units.size(), 3, "決着のあとは湧かない")


func test_core_defeating_the_hq_occupant_resets_the_capture_right_away() -> void:
	var board := Maps.board([
		"....",
		"....",
	])
	board.hq_cells = [Vector2i(0, 1), Vector2i(3, 0)]
	var battle := Battle.new(board)
	var raider := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(3, 0))
	raider.hp = 1
	_core(battle, Vector2i(2, 0))
	battle.apply(EndPhaseAction.new())  # 占拠 1
	assert_eq(battle.capture_turns[P1], 1)
	var events := battle.apply(EndPhaseAction.new()).events
	assert_eq(
		_types(events),
		[PhaseStartedEvent, AttackDamagedEvent, UnitDefeatedEvent, CaptureProgressEvent, PhaseStartedEvent] as Array[Script],
	)
	assert_eq(battle.capture_turns[P1], 0)


# ---- 乱数と複製 ----


func test_same_seed_same_neutral_phases_and_clone_continues_the_same() -> void:
	var a := _seeded(11)
	var b := _seeded(11)
	for i in 6:
		assert_eq(_cycle(b), _cycle(a))
	assert_eq(_snapshot(a), _snapshot(b))

	var copy := a.clone()
	for i in 8:
		assert_eq(_cycle(copy), _cycle(a))
	assert_eq(_snapshot(copy), _snapshot(a))


func test_different_seeds_can_differ() -> void:
	var seen := {}
	for battle_seed in 6:
		var battle := _seeded(battle_seed)
		var log: Array[String] = []
		for i in 6:
			log.append(_cycle(battle))
		seen[" | ".join(log)] = true
	assert_true(seen.size() > 1, "湧き直しが乱数で変わっていない")


## 泉が 4 つあり、プレイヤーの駒が中央にいる盤面。
func _seeded(battle_seed: int) -> Battle:
	var battle := Battle.new(Maps.board([
		"*.......*",
		".........",
		".........",
		"*.......*",
	]), battle_seed)
	battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(4, 1))
	battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(4, 2))
	return battle


## 中立のフェーズを 1 回回し、起きたことを文字にする。そのあと、コアを 1 体取り除く（倒されたことにして、湧き直させる）。
func _cycle(battle: Battle) -> String:
	var text := _describe(_neutral_phase(battle))
	for unit in battle.units:
		if unit.side == NEUTRAL:
			battle.units.erase(unit)
			break
	return text


func _snapshot(battle: Battle) -> String:
	var parts: Array[String] = []
	for unit in battle.units:
		parts.append("%d:%d@%s/%d" % [unit.id, unit.kind, unit.cell, unit.hp])
	return " ".join(parts)


func _describe(events: Array[BattleEvent]) -> String:
	var parts: Array[String] = []
	for event in events:
		parts.append(event.get_script().get_global_name())
		var moved := event as UnitMovedEvent
		if moved != null:
			parts.append(str(moved.path))
		var hit := event as UnitDamagedEvent
		if hit != null:
			parts.append("%d->%d" % [hit.unit_id, hit.hp])
		var spawned := event as UnitSpawnedEvent
		if spawned != null:
			parts.append("%d@%s" % [spawned.unit_id, spawned.cell])
	return " ".join(parts)
