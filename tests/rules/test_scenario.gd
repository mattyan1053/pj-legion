extends "res://tests/base_test.gd"
## 戦いの定義（Scenario）と、対戦設定（MatchSetup）がそれを読むところ（docs/scenario.md）。


## 編成の決まりの検査を通らない部隊（9 体。対戦のロスターに無い駒と、予算を超える数）。
func _horde() -> Deck:
	var deck := Deck.new(UnitKind.Army.FANTASY)
	for i in 9:
		deck.entries.append(DeckEntry.new(UnitKind.Id.SNIPER if i == 0 else Deck.roster(UnitKind.Army.FANTASY)[0]))
	return deck


func test_versus_scenario_is_the_generated_stage() -> void:
	for stage: BoardGenerator.Stage in BoardGenerator.Stage.values():
		var scenario := Scenario.versus(stage)
		assert_eq(scenario.title, "", "生成のステージの名前は、画面の文の表が持つ（game/names.gd の stage）")
		assert_eq(scenario.stage, stage)
		assert_eq(scenario.board_size, BoardGenerator.DEFAULT_SIZE)
		assert_false(scenario.is_fixed(Unit.Side.PLAYER1) or scenario.is_fixed(Unit.Side.PLAYER2))


func test_versus_setup_carries_the_stage_scenario() -> void:
	var setup := MatchSetup.versus_cpu(
		BoardGenerator.Stage.LABYRINTH, 4, MatchSetup.default_deck(UnitKind.Army.MILITARY), UnitKind.Army.FANTASY
	)
	assert_eq(setup.scenario.stage, BoardGenerator.Stage.LABYRINTH)
	# 盤は戦いの定義の盤（生成）と同じ。
	var expected := BoardGenerator.generate(BoardGenerator.Stage.LABYRINTH, 4)
	var board := setup.create_battle().board
	assert_eq(board.hq_cells, expected.hq_cells)
	for y in board.size.y:
		for x in board.size.x:
			assert_eq(board.terrain_at(Vector2i(x, y)), expected.terrain_at(Vector2i(x, y)))


func test_fixed_deck_is_deployed_as_written_without_the_deck_check() -> void:
	var horde := _horde()
	assert_false(horde.is_valid())
	var scenario := Scenario.versus(BoardGenerator.Stage.PLAIN)
	scenario.fix_deck(Unit.Side.PLAYER2, horde)
	var setup := MatchSetup.new()
	setup.scenario = scenario
	setup.set_human(Unit.Side.PLAYER1, MatchSetup.default_deck(UnitKind.Army.MILITARY))
	setup.controllers[Unit.Side.PLAYER2] = MatchSetup.Controller.CPU
	assert_true(setup.is_valid(), "決め打ちの側は、選んだ編成が無くても、決まりの検査を通らなくても始められる")
	assert_true(setup.deck_of(Unit.Side.PLAYER2) == horde)
	assert_eq(setup.army_of(Unit.Side.PLAYER2), UnitKind.Army.FANTASY)
	assert_eq(setup.cpu_sides(), [Unit.Side.PLAYER2] as Array[Unit.Side])
	var battle := setup.create_battle()
	var kinds: Array[UnitKind.Id] = []
	for unit in battle.units:
		if unit.side == Unit.Side.PLAYER2:
			kinds.append(unit.kind)
	var wanted: Array[UnitKind.Id] = [UnitKind.Id.KING]
	for entry in horde.entries:
		wanted.append(entry.kind)
	assert_eq(kinds, wanted, "将と、書いたとおりの 9 体")
	assert_eq(battle.armies[Unit.Side.PLAYER2], UnitKind.Army.FANTASY)


func test_fixed_deck_wins_over_the_chosen_deck() -> void:
	var setup := MatchSetup.versus_cpu(
		BoardGenerator.Stage.PLAIN, 1, MatchSetup.default_deck(UnitKind.Army.MILITARY), UnitKind.Army.MILITARY
	)
	var horde := _horde()
	setup.scenario.fix_deck(Unit.Side.PLAYER2, horde)
	assert_true(setup.deck_of(Unit.Side.PLAYER2) == horde, "CPU の編成（CpuDeck）より決め打ちの部隊")
	assert_eq(setup.army_of(Unit.Side.PLAYER2), UnitKind.Army.FANTASY)


func test_side_without_a_fixed_deck_still_needs_a_valid_chosen_deck() -> void:
	var setup := MatchSetup.new()
	setup.scenario.fix_deck(Unit.Side.PLAYER2, _horde())
	assert_eq(setup.problems(), [MatchSetup.Problem.NO_DECK] as Array[MatchSetup.Problem])
	setup.set_human(Unit.Side.PLAYER1, Deck.new(UnitKind.Army.MILITARY))
	assert_eq(setup.problems(), [MatchSetup.Problem.INVALID_DECK] as Array[MatchSetup.Problem])


func test_win_conditions_default_to_the_versus_ways_and_reach_the_battle() -> void:
	var scenario := Scenario.versus(BoardGenerator.Stage.PLAIN)
	for side: Unit.Side in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
		assert_eq(scenario.win_conditions_of(side), Scenario.STANDARD_WIN_CONDITIONS)
	var only_king: Array[GameWonEvent.Reason] = [GameWonEvent.Reason.KING_DEFEATED]
	scenario.set_win_conditions(Unit.Side.PLAYER2, only_king)
	var setup := MatchSetup.new()
	setup.scenario = scenario
	setup.set_human(Unit.Side.PLAYER1, MatchSetup.default_deck(UnitKind.Army.MILITARY))
	setup.set_human(Unit.Side.PLAYER2, MatchSetup.default_deck(UnitKind.Army.FANTASY))
	var battle := setup.create_battle()
	assert_eq(battle.win_conditions[Unit.Side.PLAYER1], Scenario.STANDARD_WIN_CONDITIONS)
	assert_eq(battle.win_conditions[Unit.Side.PLAYER2], only_king)
	battle.win_conditions[Unit.Side.PLAYER2].append(GameWonEvent.Reason.HQ_CAPTURED)
	assert_eq(scenario.win_conditions_of(Unit.Side.PLAYER2), only_king, "対戦の側を変えても、定義は変わらない")


func test_holding_side_keeps_the_usual_ways_and_reaches_the_battle() -> void:
	var scenario := Scenario.versus(BoardGenerator.Stage.PLAIN)
	assert_eq(scenario.hold_turns, 0)
	scenario.hold_for(Unit.Side.PLAYER1, 8)
	var held: Array[GameWonEvent.Reason] = [
		GameWonEvent.Reason.KING_DEFEATED, GameWonEvent.Reason.HQ_CAPTURED, GameWonEvent.Reason.TURNS_HELD
	]
	assert_eq(scenario.win_conditions_of(Unit.Side.PLAYER1), held)
	assert_eq(scenario.win_conditions_of(Unit.Side.PLAYER2), Scenario.STANDARD_WIN_CONDITIONS, "攻める側は変えない")
	var setup := MatchSetup.new()
	setup.scenario = scenario
	setup.set_human(Unit.Side.PLAYER1, MatchSetup.default_deck(UnitKind.Army.MILITARY))
	setup.set_human(Unit.Side.PLAYER2, MatchSetup.default_deck(UnitKind.Army.FANTASY))
	var battle := setup.create_battle()
	assert_eq(battle.hold_turns, 8)
	assert_eq(battle.turns_left(), 8)
	assert_true(battle.wins_by(Unit.Side.PLAYER1, GameWonEvent.Reason.TURNS_HELD))


func test_start_gauge_reaches_the_battle_within_the_gauge() -> void:
	var scenario := Scenario.on_map(HandMap.new(PackedStringArray(["..2..", ".....", ".....", "..1.."])), "試し")
	assert_eq(scenario.start_gauge, [Ults.FIRST_PLAYER_START_GAUGE, 0] as Array[int], "対戦モードの定義は、先手だけためて始まる")
	scenario.set_start_gauge(Unit.Side.PLAYER1, 800)
	scenario.set_start_gauge(Unit.Side.PLAYER2, Ults.GAUGE_MAX + 50)
	assert_eq(scenario.start_gauge, [800, Ults.GAUGE_MAX] as Array[int], "いっぱいを超えない")
	var setup := MatchSetup.humans_on(scenario, 1, MatchSetup.default_deck(UnitKind.Army.MILITARY), MatchSetup.default_deck(UnitKind.Army.FANTASY))
	setup.ignore_budget = true
	var battle := setup.create_battle()
	assert_eq(battle.ult_gauge, [800, Ults.GAUGE_MAX] as Array[int])
	assert_eq(Scenario.versus(BoardGenerator.Stage.PLAIN).start_gauge, [Ults.FIRST_PLAYER_START_GAUGE, 0] as Array[int], "生成の盤も同じ")
	assert_eq(Scenario.new().start_gauge, [0, 0] as Array[int], "定義の既定は 0")
	assert_true(Ults.FIRST_PLAYER_START_GAUGE < Ults.GAUGE_MAX, "先手でも、始めから必殺技は使えない")


## 駒の始めのレベルと経験値（start_growth）: 部隊の並びの順に将でない駒へ当て、レベルアップと同じだけ伸ばす。既定は空。
func test_start_growth_reaches_the_placed_units() -> void:
	var scenario := Scenario.on_map(HandMap.new(PackedStringArray(["..2..", ".....", ".....", "..1.."])), "試し")
	assert_eq(scenario.start_growth, [[], []] as Array[Array], "既定は空（どの駒もレベル 1・経験値 0）")
	var deck := Deck.new(UnitKind.Army.FANTASY)
	for kind: UnitKind.Id in [UnitKind.Id.SORCERER, UnitKind.Id.PALADIN, UnitKind.Id.PRIEST]:
		deck.entries.append(DeckEntry.new(kind))
	scenario.fix_deck(Unit.Side.PLAYER1, deck)
	scenario.set_start_growth(Unit.Side.PLAYER1, [[2, 110], [Growth.MAX_LEVEL + 1, Growth.EXPERIENCE_PER_LEVEL + 5]])
	assert_eq(scenario.start_growth[0], [[2, 110], [Growth.MAX_LEVEL - 1, Growth.EXPERIENCE_PER_LEVEL - 1]], "進化の手前に収める")
	var setup := MatchSetup.humans_on(scenario, 1, null, MatchSetup.default_deck(UnitKind.Army.MILITARY))
	setup.ignore_budget = true
	var battle := setup.create_battle()
	var by_kind := {}
	for unit in battle.units:
		by_kind[[unit.side, unit.kind]] = unit
	var sorcerer: Unit = by_kind[[Unit.Side.PLAYER1, UnitKind.Id.SORCERER]]
	assert_eq([sorcerer.level, sorcerer.experience], [2, 110])
	var gains: Dictionary = Growth.GAINS[UnitKind.Role.REARGUARD]
	assert_eq(sorcerer.max_hp(), UnitKind.max_hp(UnitKind.Id.SORCERER) + gains[Unit.Stat.MAX_HP], "1 レベルぶん伸びる")
	assert_eq(sorcerer.hp, sorcerer.max_hp(), "HP も伸びたぶん増える")
	assert_eq(sorcerer.power(), UnitKind.power(UnitKind.Id.SORCERER) + gains[Unit.Stat.POWER])
	assert_false(sorcerer.evolution_ready, "進化は対戦の中で選ぶ")
	var priest: Unit = by_kind[[Unit.Side.PLAYER1, UnitKind.Id.PRIEST]]
	assert_eq([priest.level, priest.experience], [1, 0], "列より後ろの駒はいつもどおり")
	assert_eq(by_kind[[Unit.Side.PLAYER1, UnitKind.Id.KING]].level, 1, "将には当てない")
	for unit in battle.units:
		if unit.side == Unit.Side.PLAYER2:
			assert_eq([unit.level, unit.experience], [1, 0], "決めていない側はいつもどおり")
	# 次の 1 撃で上限のレベルに届き、進化先を選ぶことになる。
	assert_true(Growth.preview(sorcerer, Growth.HIT_EXPERIENCE).evolution_ready)
	assert_eq(Scenario.versus(BoardGenerator.Stage.PLAIN).start_growth, [[], []] as Array[Array], "対戦モードは使わない")
