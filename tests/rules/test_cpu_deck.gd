extends "res://tests/base_test.gd"
## CPU の編成（docs/cpu-ai.md）。

const ARMIES: Array[UnitKind.Army] = [UnitKind.Army.MILITARY, UnitKind.Army.FANTASY]


func test_deck_is_valid_for_each_army() -> void:
	for army in ARMIES:
		var deck := CpuDeck.build(army)
		assert_eq(deck.army, army)
		assert_true(deck.is_valid(), "軍 %d: %s" % [army, deck.problems()])


func test_deck_has_every_role() -> void:
	for army in ARMIES:
		var roles := {}
		for entry in CpuDeck.build(army).entries:
			roles[UnitKind.role(entry.kind)] = true
		assert_eq(roles.size(), 4, "軍 %d" % army)


func test_deck_spends_the_whole_budget() -> void:
	for army in ARMIES:
		var deck := CpuDeck.build(army)
		assert_eq(deck.total_cost(), deck.budget(), "軍 %d" % army)


func test_same_army_gets_the_same_deck() -> void:
	for army in ARMIES:
		var a := CpuDeck.build(army)
		var b := CpuDeck.build(army)
		assert_eq(a.entries.size(), b.entries.size())
		for i in a.entries.size():
			assert_eq(a.entries[i].kind, b.entries[i].kind)
			assert_eq(a.entries[i].equipment, b.entries[i].equipment)


func test_no_army_gets_an_empty_deck() -> void:
	assert_true(CpuDeck.build(UnitKind.Army.NONE).entries.is_empty())
