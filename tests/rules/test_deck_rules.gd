extends "res://tests/base_test.gd"
## 編成の決まり（DeckRules）: 外から渡した決まりで、雇える駒・予算・数の上限が決まること。
## 既定（対戦の決まり）では、前と同じ検査になること。

const MILITARY := UnitKind.Army.MILITARY
const FANTASY := UnitKind.Army.FANTASY
const Problem := Deck.Problem


## MILITARY だけを選べ、スナイパーと衛生兵だけを雇え、予算 7、2 体までの決まり（ストーリーの途中のような）。
func _narrow_rules() -> DeckRules:
	return DeckRules.new(&"narrow", 2, {
		MILITARY: [UnitKind.Id.SNIPER, UnitKind.Id.MEDIC] as Array[UnitKind.Id],
	}, {MILITARY: 7})


func _problems(list: Array[Deck.Problem]) -> Array[Deck.Problem]:
	return list


# --- 対戦の決まり ---


func test_versus_rules_keep_the_values_of_each_army() -> void:
	var rules := DeckRules.versus()
	assert_eq(rules.id, DeckRules.VERSUS)
	assert_eq(rules.armies(), [MILITARY, FANTASY] as Array[UnitKind.Army])
	assert_eq(rules.max_units, Deck.MAX_UNITS)
	assert_eq(rules.max_units, 6)
	assert_eq(rules.budget(MILITARY), 24)
	assert_eq(rules.budget(FANTASY), 18)
	assert_eq(rules.budget(UnitKind.Army.NONE), 0)
	assert_eq(
		rules.roster(MILITARY),
		[UnitKind.Id.SHIELD_TROOPER, UnitKind.Id.SNIPER, UnitKind.Id.COMMANDO, UnitKind.Id.MEDIC] as Array[UnitKind.Id],
	)
	assert_eq(
		rules.roster(FANTASY),
		[UnitKind.Id.PALADIN, UnitKind.Id.SORCERER, UnitKind.Id.SPELLBLADE, UnitKind.Id.PRIEST] as Array[UnitKind.Id],
	)
	assert_true(rules.roster(UnitKind.Army.NONE).is_empty())


func test_versus_rules_are_the_default_of_a_deck() -> void:
	var deck := Deck.new(FANTASY)
	assert_eq(deck.rules, DeckRules.versus())
	assert_eq(deck.budget(), Deck.budget_of(FANTASY))
	assert_eq(deck.available_kinds(), Deck.roster(FANTASY))


func test_rules_are_found_by_name() -> void:
	assert_eq(DeckRules.by_id(DeckRules.VERSUS), DeckRules.versus())
	assert_eq(DeckRules.by_id(&"story"), null)


func test_roster_returns_a_copy() -> void:
	var roster := DeckRules.versus().roster(MILITARY)
	roster.clear()
	assert_eq(DeckRules.versus().roster(MILITARY).size(), 4)


func test_cpu_deck_is_the_same_with_the_versus_rules_passed() -> void:
	for army: UnitKind.Army in [MILITARY, FANTASY]:
		var plain := CpuDeck.build(army)
		var passed := CpuDeck.build(army, DeckRules.versus())
		assert_eq(plain.entries.size(), passed.entries.size())
		for i in plain.entries.size():
			assert_eq(plain.entries[i].kind, passed.entries[i].kind)
			assert_eq(plain.entries[i].equipment, passed.entries[i].equipment)


# --- 外から渡した決まり ---


func test_passed_rules_decide_what_can_be_hired() -> void:
	var deck := Deck.new(MILITARY, _narrow_rules())
	assert_eq(deck.available_kinds(), [UnitKind.Id.SNIPER, UnitKind.Id.MEDIC] as Array[UnitKind.Id])
	assert_eq(deck.add(UnitKind.Id.SHIELD_TROOPER), null, "対戦の決まりでは雇えるが、この決まりでは雇えない")
	assert_true(deck.add(UnitKind.Id.SNIPER) != null)
	assert_true(deck.add(UnitKind.Id.MEDIC) != null)
	assert_eq(deck.add(UnitKind.Id.SNIPER), null, "数の上限は決まりの値（2）")
	assert_eq(deck.budget(), 7)
	assert_eq(deck.problems(), _problems([]))


func test_passed_rules_decide_the_checks() -> void:
	var deck := Deck.new(MILITARY, _narrow_rules())
	deck.add(UnitKind.Id.SNIPER)
	deck.add(UnitKind.Id.MEDIC)
	deck.entries[0].equip(Equipment.Id.SPEED_BOOTS)
	deck.entries[0].equip(Equipment.Id.SPEED_BOOTS)
	assert_eq(deck.total_cost(), 8)
	assert_eq(deck.problems(), _problems([Problem.OVER_BUDGET]), "予算 7 を超える")
	# 直に組み立てた編成（保存したものの読み込み）でも、決まりで調べる。
	deck.entries.append(DeckEntry.new(UnitKind.Id.COMMANDO))
	assert_eq(deck.problems(), _problems([Problem.TOO_MANY_UNITS, Problem.OVER_BUDGET, Problem.NOT_IN_ROSTER]))


func test_an_army_the_rules_do_not_offer_cannot_hire() -> void:
	var deck := Deck.new(FANTASY, _narrow_rules())
	assert_true(deck.available_kinds().is_empty())
	assert_eq(deck.add(UnitKind.Id.PALADIN), null)
	assert_eq(deck.budget(), 0)
	assert_false(deck.is_valid())


func test_cpu_deck_follows_the_passed_rules() -> void:
	var deck := CpuDeck.build(MILITARY, _narrow_rules())
	assert_eq(deck.rules.id, &"narrow")
	assert_true(deck.is_valid(), str(deck.problems()))
	assert_true(deck.total_cost() <= 7)
	for entry in deck.entries:
		assert_true(entry.kind in [UnitKind.Id.SNIPER, UnitKind.Id.MEDIC])


# --- 写しと並べ替え ---


func test_copy_is_independent() -> void:
	var deck := Deck.new(MILITARY)
	deck.add(UnitKind.Id.SNIPER).equip(Equipment.Id.SPEED_BOOTS)
	var other := deck.copy()
	assert_eq(other.rules, deck.rules)
	assert_eq(other.army, MILITARY)
	other.entries[0].equip(Equipment.Id.IRON_SHIELD)
	other.add(UnitKind.Id.MEDIC)
	assert_eq(deck.entries.size(), 1)
	assert_eq(deck.entries[0].equipment, [Equipment.Id.SPEED_BOOTS] as Array[Equipment.Id])
	assert_eq(other.total_cost(), 3 + 2 + 3)


func test_move_reorders_entries() -> void:
	var deck := Deck.new(MILITARY)
	var a := deck.add(UnitKind.Id.SHIELD_TROOPER)
	var b := deck.add(UnitKind.Id.SNIPER)
	var c := deck.add(UnitKind.Id.MEDIC)
	assert_true(deck.move(2, 0))
	assert_eq(deck.entries, [c, a, b] as Array[DeckEntry])
	assert_true(deck.move(0, 1))
	assert_eq(deck.entries, [a, c, b] as Array[DeckEntry])
	assert_false(deck.move(0, 3))
	assert_false(deck.move(-1, 0))
	assert_eq(deck.entries, [a, c, b] as Array[DeckEntry])


# --- 配置の図 ---


func test_open_field_slots_match_deployment_on_an_open_board() -> void:
	var rows: Array[String] = []
	for y in 9:
		rows.append(".........")
	for hq: Vector2i in [Vector2i(4, 8), Vector2i(4, 0)]:
		var battle := preload("res://tests/support/maps.gd").battle(rows)
		battle.board.hq_cells = [hq, Vector2i(4, 0) if hq.y == 8 else Vector2i(4, 8)]
		var deck := Deck.new(MILITARY)
		for i in Deck.MAX_UNITS:
			deck.add(UnitKind.Id.SNIPER)
		var placed := Deployment.deploy(battle, Unit.Side.PLAYER1, deck)
		var slots := Deployment.open_field_slots(Deck.MAX_UNITS)
		var forward := Deployment.forward(battle.board, hq)
		assert_eq(placed.size(), Deck.MAX_UNITS + 1)
		for i in slots.size():
			assert_eq(placed[i + 1].cell, hq + Vector2i(slots[i].x, 0) + forward * slots[i].y, "%d 番目（本陣 %s）" % [i, hq])
	assert_eq(Deployment.open_field_slots(2), [Vector2i(0, 1), Vector2i(-1, 1)] as Array[Vector2i])
	assert_eq(Deployment.open_field_slots(6)[5], Vector2i(0, 2))


# --- 持たせられる装備 ---


func test_rules_allow_every_item_unless_told_otherwise() -> void:
	for item: Equipment.Id in Equipment.Id.values():
		assert_true(_narrow_rules().allows_item(item), "渡さなければ、どの装備も")
	assert_eq(_narrow_rules().items(), _all_items())


func test_versus_allows_only_the_versus_items() -> void:
	assert_eq(DeckRules.versus().items(), DeckRules.VERSUS_ITEMS)
	assert_eq(DeckRules.versus().shown_items(), DeckRules.VERSUS_ITEMS, "対戦の編成の画面には、持たせられる装備だけが並ぶ")
	for item: Equipment.Id in Equipment.Id.values():
		assert_eq(DeckRules.versus().allows_item(item), DeckRules.VERSUS_ITEMS.has(item), str(Equipment.Id.find_key(item)))


func test_listed_items_include_the_allowed_ones_in_item_order() -> void:
	var rules := DeckRules.new(&"some", 6, {MILITARY: DeckRules.versus().roster(MILITARY)}, {MILITARY: 24},
			[Equipment.Id.REGEN_CHARM], [Equipment.Id.JET_PACK, Equipment.Id.SPEED_BOOTS])
	assert_eq(rules.items(), [Equipment.Id.REGEN_CHARM] as Array[Equipment.Id])
	assert_eq(rules.shown_items(), [Equipment.Id.SPEED_BOOTS, Equipment.Id.REGEN_CHARM, Equipment.Id.JET_PACK] as Array[Equipment.Id])
	assert_false(rules.allows_item(Equipment.Id.JET_PACK), "並べるだけで、持たせられはしない")


func test_items_left_out_of_the_rules_are_a_problem() -> void:
	var rules := DeckRules.new(&"shields", 6, {MILITARY: DeckRules.versus().roster(MILITARY)}, {MILITARY: 24},
			[Equipment.Id.IRON_SHIELD])
	assert_eq(rules.items(), [Equipment.Id.IRON_SHIELD] as Array[Equipment.Id])
	assert_false(rules.allows_item(Equipment.Id.SPEED_BOOTS))
	var deck := Deck.new(MILITARY, rules)
	var entry := deck.add(UnitKind.Id.COMMANDO)
	entry.equip(Equipment.Id.IRON_SHIELD)
	assert_true(deck.is_valid(), str(deck.problems()))
	assert_true(entry.equip(Equipment.Id.SPEED_BOOTS), "装備は決まりを知らないので、持たせられる（検査で分かる）")
	assert_eq(deck.problems(), _problems([Problem.ITEM_NOT_ALLOWED]))
	entry.unequip(Equipment.Id.SPEED_BOOTS)
	assert_true(deck.is_valid())
	var versus := Deck.new(MILITARY)
	versus.add(UnitKind.Id.COMMANDO).equip(Equipment.Id.SPEED_BOOTS)
	assert_true(versus.is_valid(), "対戦の決まりは、どの装備も持たせられる")


func _all_items() -> Array[Equipment.Id]:
	var items: Array[Equipment.Id] = []
	items.assign(Equipment.Id.values())
	return items
