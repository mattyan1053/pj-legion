extends "res://tests/base_test.gd"
## 編成の検査: 対戦に出せる形かどうかと、出せない理由。

const MILITARY := UnitKind.Army.MILITARY
const FANTASY := UnitKind.Army.FANTASY
const BOOTS := Equipment.Id.SPEED_BOOTS
const SHIELD := Equipment.Id.IRON_SHIELD
const Problem := Deck.Problem


func _deck(army: UnitKind.Army, kinds: Array[UnitKind.Id]) -> Deck:
	var deck := Deck.new(army)
	for kind in kinds:
		deck.add(kind)
	return deck


func _problems(list: Array[Deck.Problem]) -> Array[Deck.Problem]:
	return list


func test_empty_deck_has_no_units() -> void:
	var deck := Deck.new(MILITARY)
	assert_eq(deck.problems(), _problems([Problem.NO_UNITS]))
	assert_false(deck.is_valid())


func test_one_unit_within_budget_is_valid() -> void:
	var deck := _deck(MILITARY, [UnitKind.Id.SNIPER])
	assert_eq(deck.problems(), _problems([]))
	assert_true(deck.is_valid())


func test_exactly_on_budget_is_valid() -> void:
	# FANTASY の予算は 18。コスト 3 の駒が 6 体でちょうど。
	var fantasy := _deck(FANTASY, [
		UnitKind.Id.SORCERER, UnitKind.Id.SORCERER, UnitKind.Id.SPELLBLADE,
		UnitKind.Id.SPELLBLADE, UnitKind.Id.PRIEST, UnitKind.Id.PRIEST,
	])
	assert_eq(fantasy.total_cost(), 18)
	assert_true(fantasy.is_valid())
	# MILITARY の予算は 24。前衛 6 体でちょうど。
	var military := _deck(MILITARY, [
		UnitKind.Id.SHIELD_TROOPER, UnitKind.Id.SHIELD_TROOPER, UnitKind.Id.SHIELD_TROOPER,
		UnitKind.Id.SHIELD_TROOPER, UnitKind.Id.SHIELD_TROOPER, UnitKind.Id.SHIELD_TROOPER,
	])
	assert_eq(military.total_cost(), 24)
	assert_true(military.is_valid())


func test_one_over_budget_is_invalid() -> void:
	var fantasy := _deck(FANTASY, [
		UnitKind.Id.SORCERER, UnitKind.Id.SORCERER, UnitKind.Id.SPELLBLADE,
		UnitKind.Id.SPELLBLADE, UnitKind.Id.PRIEST, UnitKind.Id.PRIEST,
	])
	assert_true(fantasy.entries[0].equip(BOOTS), "予算を超える装備も持たせられる")
	assert_eq(fantasy.total_cost(), 19)
	assert_eq(fantasy.problems(), _problems([Problem.OVER_BUDGET]))
	# 外せば戻る。
	fantasy.entries[0].unequip(BOOTS)
	assert_true(fantasy.is_valid())


func test_budget_depends_on_the_army() -> void:
	# 同じコスト 20 でも、MILITARY（24）は通り、FANTASY（18）は通らない。
	var military := _deck(MILITARY, [
		UnitKind.Id.SHIELD_TROOPER, UnitKind.Id.SHIELD_TROOPER, UnitKind.Id.SHIELD_TROOPER,
		UnitKind.Id.SHIELD_TROOPER, UnitKind.Id.SHIELD_TROOPER,
	])
	var fantasy := _deck(FANTASY, [
		UnitKind.Id.PALADIN, UnitKind.Id.PALADIN, UnitKind.Id.PALADIN,
		UnitKind.Id.PALADIN, UnitKind.Id.PALADIN,
	])
	assert_eq(military.total_cost(), 20)
	assert_eq(fantasy.total_cost(), 20)
	assert_true(military.is_valid())
	assert_eq(fantasy.problems(), _problems([Problem.OVER_BUDGET]))


func test_add_refuses_the_seventh_unit() -> void:
	var deck := Deck.new(MILITARY)
	for i in Deck.MAX_UNITS:
		assert_true(deck.add(UnitKind.Id.SNIPER) != null)
	assert_eq(deck.add(UnitKind.Id.SNIPER), null)
	assert_eq(deck.entries.size(), 6)
	# 1 体外せば、また雇える。
	deck.remove(deck.entries[0])
	assert_true(deck.add(UnitKind.Id.MEDIC) != null)
	assert_eq(deck.entries.size(), 6)


func test_add_does_not_look_at_the_budget() -> void:
	var deck := Deck.new(FANTASY)
	for i in 6:
		assert_true(deck.add(UnitKind.Id.PALADIN) != null)
	assert_eq(deck.total_cost(), 24)
	assert_eq(deck.problems(), _problems([Problem.OVER_BUDGET]))


func test_hand_built_deck_with_too_many_units() -> void:
	var deck := _deck(MILITARY, [UnitKind.Id.SNIPER])
	for i in 6:
		deck.entries.append(DeckEntry.new(UnitKind.Id.SNIPER))
	assert_eq(deck.entries.size(), 7)
	assert_eq(deck.problems(), _problems([Problem.TOO_MANY_UNITS]))


func test_hand_built_deck_with_too_much_equipment() -> void:
	var deck := _deck(MILITARY, [UnitKind.Id.SNIPER, UnitKind.Id.MEDIC])
	deck.entries[0].equipment = [BOOTS, BOOTS, SHIELD, SHIELD]
	deck.entries[1].equipment = [BOOTS, BOOTS, BOOTS, BOOTS]
	assert_eq(deck.problems(), _problems([Problem.TOO_MUCH_EQUIPMENT]), "同じ理由は 1 回だけ")
	deck.entries[0].equipment = [BOOTS, BOOTS, SHIELD]
	deck.entries[1].equipment = [BOOTS, BOOTS, BOOTS]
	assert_true(deck.is_valid(), "3 個までは通る")


func test_hand_built_deck_with_units_outside_the_roster() -> void:
	for kind: UnitKind.Id in [UnitKind.Id.SORCERER, UnitKind.Id.KING, UnitKind.Id.MINION]:
		var deck := _deck(MILITARY, [UnitKind.Id.SNIPER])
		deck.entries.append(DeckEntry.new(kind))
		assert_eq(deck.problems(), _problems([Problem.NOT_IN_ROSTER]), UnitKind.display_name(kind))


func test_deck_without_an_army_is_never_valid() -> void:
	var deck := Deck.new(UnitKind.Army.NONE)
	assert_eq(deck.problems(), _problems([Problem.NO_UNITS]))
	deck.entries.append(DeckEntry.new(UnitKind.Id.SNIPER))
	assert_eq(deck.problems(), _problems([Problem.OVER_BUDGET, Problem.NOT_IN_ROSTER]))


func test_every_problem_is_reported_in_order() -> void:
	var deck := Deck.new(FANTASY)
	for i in 7:
		deck.entries.append(DeckEntry.new(UnitKind.Id.SNIPER))
	deck.entries[3].equipment = [SHIELD, SHIELD, SHIELD, SHIELD]
	assert_eq(
		deck.problems(),
		_problems([
			Problem.TOO_MANY_UNITS, Problem.OVER_BUDGET,
			Problem.TOO_MUCH_EQUIPMENT, Problem.NOT_IN_ROSTER,
		]),
	)


func test_checking_does_not_change_the_deck() -> void:
	var deck := _deck(FANTASY, [UnitKind.Id.PALADIN, UnitKind.Id.PRIEST])
	deck.entries[0].equip(SHIELD)
	deck.problems()
	deck.is_valid()
	assert_eq(deck.entries.size(), 2)
	assert_eq(deck.entries[0].equipment, [SHIELD] as Array[Equipment.Id])
	assert_eq(deck.total_cost(), 8)


func test_deploy_does_not_check_the_deck() -> void:
	# 検査は、対戦を始める側が編成を渡す前にする。deploy は渡された編成をそのまま置く。
	var battle := Battle.new(BoardGenerator.generate(BoardGenerator.Stage.values()[0], 7))
	var deck := Deck.new(FANTASY)
	for i in 6:
		deck.add(UnitKind.Id.PALADIN)
	assert_false(deck.is_valid())
	assert_eq(Deployment.deploy(battle, Unit.Side.PLAYER1, deck).size(), 7)
