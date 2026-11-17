extends "res://tests/base_test.gd"
## 対戦設定（MatchSetup）と、そこから対戦を作る入口（docs/match-setup.md）。

const STAGES: Array[BoardGenerator.Stage] = [
	BoardGenerator.Stage.PLAIN, BoardGenerator.Stage.LABYRINTH, BoardGenerator.Stage.TWIN_SPRINGS,
]


func _counts(battle: Battle) -> Array:
	var counts := [0, 0, 0]
	for unit in battle.units:
		counts[unit.side] += 1
	return counts


func test_versus_cpu_deploys_both_armies_on_every_stage() -> void:
	for stage in STAGES:
		for battle_seed in 10:
			var setup := MatchSetup.versus_cpu(
				stage, battle_seed, MatchSetup.default_deck(UnitKind.Army.MILITARY), UnitKind.Army.FANTASY
			)
			var battle := setup.create_battle()
			var wanted := [
				1 + setup.decks[0].entries.size(), 1 + setup.decks[1].entries.size(), 0,
			]
			assert_eq(_counts(battle), wanted, "マップ %d 種 %d" % [stage, battle_seed])
			assert_eq(battle.armies, [UnitKind.Army.MILITARY, UnitKind.Army.FANTASY] as Array[UnitKind.Army])


func test_battle_starts_at_player1_turn_1_with_kings_on_their_hq() -> void:
	for stage in STAGES:
		var setup := MatchSetup.versus_human(
			stage, 3, MatchSetup.default_deck(UnitKind.Army.FANTASY), MatchSetup.default_deck(UnitKind.Army.MILITARY)
		)
		var battle := setup.create_battle()
		assert_eq(battle.turn, 1)
		assert_eq(battle.phase, Unit.Side.PLAYER1)
		for side: Unit.Side in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
			var king := battle.unit_at(battle.board.hq_cells[side])
			assert_true(king != null and king.kind == UnitKind.Id.KING and king.side == side, "マップ %d" % stage)


func test_cpu_side_gets_the_cpu_deck_of_its_army() -> void:
	var human := Deck.new(UnitKind.Army.MILITARY)
	human.add(UnitKind.Id.SNIPER)
	var setup := MatchSetup.versus_cpu(BoardGenerator.Stage.PLAIN, 1, human, UnitKind.Army.MILITARY, Unit.Side.PLAYER2)
	assert_eq(setup.controllers, [MatchSetup.Controller.CPU, MatchSetup.Controller.HUMAN] as Array[MatchSetup.Controller])
	assert_eq(setup.cpu_sides(), [Unit.Side.PLAYER1] as Array[Unit.Side])
	assert_true(setup.decks[Unit.Side.PLAYER2] == human)
	var expected := CpuDeck.build(UnitKind.Army.MILITARY)
	var cpu_deck := setup.decks[Unit.Side.PLAYER1]
	assert_eq(cpu_deck.entries.size(), expected.entries.size())
	for i in expected.entries.size():
		assert_eq(cpu_deck.entries[i].kind, expected.entries[i].kind)
		assert_eq(cpu_deck.entries[i].equipment, expected.entries[i].equipment)


func test_default_deck_is_valid_for_every_army() -> void:
	for army: UnitKind.Army in [UnitKind.Army.MILITARY, UnitKind.Army.FANTASY]:
		var deck := MatchSetup.default_deck(army)
		assert_true(deck.is_valid())
		assert_eq(deck.army, army)


func test_missing_deck_is_refused() -> void:
	var setup := MatchSetup.new()
	setup.set_human(Unit.Side.PLAYER1, MatchSetup.default_deck(UnitKind.Army.MILITARY))
	assert_eq(setup.problems(), [MatchSetup.Problem.NO_DECK] as Array[MatchSetup.Problem])
	assert_eq(setup.create_battle(), null)


func test_deck_that_fails_the_deck_check_is_refused() -> void:
	var empty := Deck.new(UnitKind.Army.FANTASY)
	var setup := MatchSetup.versus_cpu(BoardGenerator.Stage.PLAIN, 1, empty, UnitKind.Army.MILITARY)
	assert_eq(setup.problems(), [MatchSetup.Problem.INVALID_DECK] as Array[MatchSetup.Problem])
	assert_eq(setup.create_battle(), null)


func test_over_budget_deck_passes_only_when_the_budget_is_ignored() -> void:
	var deck := Deck.new(UnitKind.Army.FANTASY)
	for i in Deck.MAX_UNITS:
		deck.add(Deck.roster(UnitKind.Army.FANTASY)[0])
	assert_eq(deck.problems(), [Deck.Problem.OVER_BUDGET] as Array[Deck.Problem])
	var setup := MatchSetup.versus_human(BoardGenerator.Stage.PLAIN, 1, deck, MatchSetup.default_deck(UnitKind.Army.MILITARY))
	assert_eq(setup.create_battle(), null)
	setup.ignore_budget = true
	assert_true(setup.is_valid())
	assert_eq(_counts(setup.create_battle())[0], 1 + Deck.MAX_UNITS)
	# 予算のほかの検査は、予算を無視しても通らない。
	setup.decks[0] = Deck.new(UnitKind.Army.FANTASY)
	assert_eq(setup.problems(), [MatchSetup.Problem.INVALID_DECK] as Array[MatchSetup.Problem])


func test_too_small_board_is_refused() -> void:
	var setup := MatchSetup.versus_cpu(
		BoardGenerator.Stage.PLAIN, 1, MatchSetup.default_deck(UnitKind.Army.MILITARY), UnitKind.Army.FANTASY
	)
	setup.scenario.board_size = BoardGenerator.MIN_SIZE - Vector2i.ONE
	assert_eq(setup.problems(), [MatchSetup.Problem.NO_BOARD] as Array[MatchSetup.Problem])
	assert_eq(setup.create_battle(), null)


func test_same_setup_makes_the_same_battle_every_time() -> void:
	var setup := MatchSetup.versus_cpu(
		BoardGenerator.Stage.TWIN_SPRINGS, 9, MatchSetup.default_deck(UnitKind.Army.FANTASY), UnitKind.Army.MILITARY
	)
	var a := setup.create_battle()
	var b := setup.create_battle()
	assert_eq(a.rng.state, b.rng.state)
	assert_eq(a.units.size(), b.units.size())
	for i in a.units.size():
		assert_eq(a.units[i].kind, b.units[i].kind)
		assert_eq(a.units[i].cell, b.units[i].cell)
	for y in a.board.size.y:
		for x in a.board.size.x:
			assert_eq(a.board.terrain_at(Vector2i(x, y)), b.board.terrain_at(Vector2i(x, y)))


func test_on_scenario_makes_no_cpu_deck_for_a_fixed_enemy() -> void:
	var defined := Scenario.versus(BoardGenerator.Stage.PLAIN)
	var fixed := Deck.new(UnitKind.Army.FANTASY)
	fixed.entries.append(DeckEntry.new(UnitKind.Id.PALADIN))
	defined.fix_deck(Unit.Side.PLAYER2, fixed)
	var human := MatchSetup.default_deck(UnitKind.Army.MILITARY)
	var setup := MatchSetup.on_scenario(defined, 5, Unit.Side.PLAYER1, human)
	assert_eq(setup.cpu_sides(), [Unit.Side.PLAYER2] as Array[Unit.Side])
	assert_eq(setup.decks[Unit.Side.PLAYER2], null, "決め打ちの敵には、CPU の編成を作らない")
	assert_eq(setup.deck_of(Unit.Side.PLAYER2), fixed)
	assert_eq(setup.deck_of(Unit.Side.PLAYER1), human)
	assert_true(setup.is_valid())


func test_versus_cpu_goes_through_on_scenario() -> void:
	var human := MatchSetup.default_deck(UnitKind.Army.FANTASY)
	var versus := MatchSetup.versus_cpu(BoardGenerator.Stage.LABYRINTH, 3, human, UnitKind.Army.MILITARY, Unit.Side.PLAYER2)
	var same := MatchSetup.on_scenario(Scenario.versus(BoardGenerator.Stage.LABYRINTH), 3, Unit.Side.PLAYER2, human, UnitKind.Army.MILITARY)
	assert_eq(versus.cpu_sides(), same.cpu_sides())
	assert_eq(versus.army_of(Unit.Side.PLAYER1), UnitKind.Army.MILITARY)
	assert_eq(versus.create_battle().units.size(), same.create_battle().units.size())
