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


# --- 取っておいた部隊を選ぶ ---


func _saved_fantasy(library: RefCounted) -> RefCounted:
	var deck := Deck.new(UnitKind.Army.FANTASY)
	deck.add(UnitKind.Id.SPELLBLADE).equip(Equipment.Id.SPEED_BOOTS)
	deck.add(UnitKind.Id.PRIEST)
	return library.add("速攻", deck)


func test_chosen_deck_goes_into_the_match() -> void:
	var library: RefCounted = preload("res://prototype/deck_library.gd").new()
	var item := _saved_fantasy(library)
	var choice := TrialSetup.new()
	choice.choose_deck(Unit.Side.PLAYER1, item.id, item.deck)
	assert_eq(choice.armies[0], UnitKind.Army.FANTASY, "軍は部隊の軍になる")
	var setup: MatchSetup = choice.to_setup(1)
	assert_true(setup.is_valid())
	assert_eq(setup.decks[0].entries.size(), 2)
	assert_eq(setup.decks[0].entries[0].equipment, [Equipment.Id.SPEED_BOOTS] as Array[Equipment.Id])
	assert_eq(setup.decks[1].entries.size(), CpuDeck.build(UnitKind.Army.FANTASY).entries.size(), "CPU はいつも CPU の編成")
	var battle := setup.create_battle()
	assert_eq(battle.units.filter(func(unit: Unit) -> bool: return unit.side == Unit.Side.PLAYER1).size(), 3, "将 + 2 体")


func test_both_humans_choose_their_own_decks() -> void:
	var library: RefCounted = preload("res://prototype/deck_library.gd").new()
	var item := _saved_fantasy(library)
	var choice := TrialSetup.new()
	choice.cpu_opponent = false
	choice.choose_deck(Unit.Side.PLAYER2, item.id, item.deck)
	var setup: MatchSetup = choice.to_setup(1)
	assert_eq(setup.decks[0].entries.size(), MatchSetup.default_deck(UnitKind.Army.MILITARY).entries.size(), "先手は既定の編成")
	assert_eq(setup.decks[1].entries.size(), 2, "後手は選んだ部隊")


func test_cpu_side_ignores_a_chosen_deck() -> void:
	var library: RefCounted = preload("res://prototype/deck_library.gd").new()
	var item := _saved_fantasy(library)
	var choice := TrialSetup.new()
	choice.choose_deck(Unit.Side.PLAYER2, item.id, item.deck)  # 人どうしのときに選んでいた
	assert_false(choice.is_human(Unit.Side.PLAYER2))
	var setup: MatchSetup = choice.to_setup(1)
	assert_eq(setup.decks[1].entries.size(), CpuDeck.build(UnitKind.Army.FANTASY).entries.size())


func test_changing_the_army_drops_the_chosen_deck() -> void:
	var library: RefCounted = preload("res://prototype/deck_library.gd").new()
	var item := _saved_fantasy(library)
	var choice := TrialSetup.new()
	choice.choose_deck(Unit.Side.PLAYER1, item.id, item.deck)
	choice.choose_army(Unit.Side.PLAYER1, UnitKind.Army.FANTASY)
	assert_eq(choice.deck_ids[0], item.id, "同じ軍なら残る")
	choice.choose_army(Unit.Side.PLAYER1, UnitKind.Army.MILITARY)
	assert_eq(choice.deck_ids[0], "")
	assert_eq(choice.decks[0], null)


func test_refresh_follows_the_library() -> void:
	var library: RefCounted = preload("res://prototype/deck_library.gd").new()
	var item := _saved_fantasy(library)
	var choice := TrialSetup.new()
	choice.choose_deck(Unit.Side.PLAYER1, item.id, item.deck)
	var rebuilt: Deck = item.deck.copy()
	rebuilt.add(UnitKind.Id.PALADIN)
	library.replace(item.id, item.name, rebuilt)
	choice.refresh_decks(library)
	assert_eq(choice.decks[0].entries.size(), 3, "組み直した中身になる")
	var over: Deck = rebuilt.copy()
	for i in 3:
		over.add(UnitKind.Id.PALADIN)
	library.replace(item.id, item.name, over)
	choice.refresh_decks(library)
	assert_eq(choice.deck_ids[0], "", "出せなくなったら既定の編成に戻す")
	choice.choose_deck(Unit.Side.PLAYER1, item.id, rebuilt)
	library.remove(item.id)
	choice.refresh_decks(library)
	assert_eq(choice.deck_ids[0], "", "消えたら既定の編成に戻す")


func test_copy_does_not_share_the_chosen_deck() -> void:
	var library: RefCounted = preload("res://prototype/deck_library.gd").new()
	var item := _saved_fantasy(library)
	var choice := TrialSetup.new()
	choice.choose_deck(Unit.Side.PLAYER1, item.id, item.deck)
	var other: RefCounted = choice.copy()
	other.decks[0].add(UnitKind.Id.PALADIN)
	assert_eq(choice.decks[0].entries.size(), 2)
	assert_eq(other.deck_ids[0], item.id)
