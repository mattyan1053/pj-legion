extends "res://tests/base_test.gd"
## 試作の対戦の設定画面で選ぶもの（trial_setup.gd）から、ルールの対戦の設定（MatchSetup）を作る。

const TrialSetup := preload("res://prototype/trial_setup.gd")


func test_default_is_human_first_military_against_cpu_fantasy() -> void:
	var setup: MatchSetup = TrialSetup.new().to_setup(1)
	assert_eq(setup.stage, BoardGenerator.Stage.PLAIN)
	assert_eq(setup.controllers, [MatchSetup.Controller.HUMAN, MatchSetup.Controller.CPU] as Array[MatchSetup.Controller])
	assert_eq(setup.army_of(Unit.Side.PLAYER1), UnitKind.Army.MILITARY)
	assert_eq(setup.army_of(Unit.Side.PLAYER2), UnitKind.Army.FANTASY)
	assert_true(setup.is_valid())


func test_human_can_play_second() -> void:
	var choice := TrialSetup.new()
	choice.human_side = Unit.Side.PLAYER2
	choice.armies = [UnitKind.Army.FANTASY, UnitKind.Army.MILITARY] as Array[UnitKind.Army]
	assert_eq(choice.cpu_side(), Unit.Side.PLAYER1)
	var setup: MatchSetup = choice.to_setup(1)
	assert_eq(setup.cpu_sides(), [Unit.Side.PLAYER1] as Array[Unit.Side])
	assert_eq(setup.army_of(Unit.Side.PLAYER1), UnitKind.Army.FANTASY)
	assert_eq(setup.army_of(Unit.Side.PLAYER2), UnitKind.Army.MILITARY)
	var battle := setup.create_battle()
	assert_eq(battle.phase, Unit.Side.PLAYER1)
	assert_eq(battle.armies, [UnitKind.Army.FANTASY, UnitKind.Army.MILITARY] as Array[UnitKind.Army])


func test_two_humans_take_the_default_deck_of_each_army() -> void:
	for armies: Array[UnitKind.Army] in [
		[UnitKind.Army.MILITARY, UnitKind.Army.MILITARY] as Array[UnitKind.Army],
		[UnitKind.Army.FANTASY, UnitKind.Army.FANTASY] as Array[UnitKind.Army],
	]:
		var choice := TrialSetup.new()
		choice.cpu_opponent = false
		choice.human_side = Unit.Side.PLAYER2  # 人どうしでは見ない
		choice.armies = armies
		var setup: MatchSetup = choice.to_setup(1)
		assert_true(setup.cpu_sides().is_empty())
		for side: Unit.Side in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
			assert_eq(setup.decks[side].entries.size(), MatchSetup.default_deck(armies[side]).entries.size())
			assert_true(setup.decks[side].is_valid())


func test_copy_does_not_share_the_armies() -> void:
	var choice := TrialSetup.new()
	var other: RefCounted = choice.copy()
	other.armies[0] = UnitKind.Army.FANTASY
	other.stage = BoardGenerator.Stage.LABYRINTH
	assert_eq(choice.armies[0], UnitKind.Army.MILITARY)
	assert_eq(choice.stage, BoardGenerator.Stage.PLAIN)
