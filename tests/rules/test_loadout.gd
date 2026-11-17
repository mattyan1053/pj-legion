extends "res://tests/base_test.gd"
## 編成: ロスター、装備、コスト、予算、軍を盤に置くこと、駒の実効値の層。

const Maps := preload("res://tests/support/maps.gd")

const P1 := Unit.Side.PLAYER1
const P2 := Unit.Side.PLAYER2
const MILITARY := UnitKind.Army.MILITARY
const FANTASY := UnitKind.Army.FANTASY
const BOOTS := Equipment.Id.SPEED_BOOTS
const SHIELD := Equipment.Id.IRON_SHIELD
const P1_HQ := Vector2i(3, 6)
const P2_HQ := Vector2i(3, 0)


func _battle(rows: Array[String] = []) -> Battle:
	if rows.is_empty():
		rows = [
			".......",
			".......",
			".......",
			".......",
			".......",
			".......",
			".......",
		]
	var battle := Maps.battle(rows)
	battle.board.hq_cells = [P1_HQ, P2_HQ]
	return battle


func _cells(units: Array[Unit]) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for unit in units:
		cells.append(unit.cell)
	return cells


# --- ロスターと予算 ---


func test_roster_of_each_army() -> void:
	assert_eq(
		Deck.roster(MILITARY),
		[UnitKind.Id.SHIELD_TROOPER, UnitKind.Id.SNIPER, UnitKind.Id.COMMANDO, UnitKind.Id.MEDIC] as Array[UnitKind.Id],
	)
	assert_eq(
		Deck.roster(FANTASY),
		[UnitKind.Id.PALADIN, UnitKind.Id.SORCERER, UnitKind.Id.SPELLBLADE, UnitKind.Id.PRIEST] as Array[UnitKind.Id],
	)
	assert_eq(Deck.roster(UnitKind.Army.NONE).size(), 0)


func test_roster_is_ordered_by_role() -> void:
	for army: UnitKind.Army in [MILITARY, FANTASY]:
		var roles: Array[UnitKind.Role] = []
		for kind in Deck.roster(army):
			roles.append(UnitKind.role(kind))
		assert_eq(
			roles,
			[UnitKind.Role.VANGUARD, UnitKind.Role.REARGUARD, UnitKind.Role.RAIDER, UnitKind.Role.HEALER] as Array[UnitKind.Role],
		)


func test_budget_of_each_army() -> void:
	assert_eq(Deck.budget_of(MILITARY), 24)
	assert_eq(Deck.budget_of(FANTASY), 18)
	assert_eq(Deck.budget_of(UnitKind.Army.NONE), 0)
	assert_eq(Deck.new(FANTASY).budget(), 18)


func test_deck_refuses_kinds_outside_its_roster() -> void:
	var deck := Deck.new(MILITARY)
	assert_eq(deck.add(UnitKind.Id.SORCERER), null)
	assert_eq(deck.add(UnitKind.Id.KING), null)
	assert_eq(deck.add(UnitKind.Id.MINION), null)
	assert_eq(deck.entries.size(), 0)
	assert_true(deck.add(UnitKind.Id.SNIPER) != null)
	assert_eq(deck.entries.size(), 1)


func test_deck_removes_an_entry() -> void:
	var deck := Deck.new(MILITARY)
	var sniper := deck.add(UnitKind.Id.SNIPER)
	var medic := deck.add(UnitKind.Id.MEDIC)
	assert_true(deck.remove(sniper))
	assert_false(deck.remove(sniper))
	assert_eq(deck.entries, [medic] as Array[DeckEntry])


# --- 装備 ---


func test_the_first_two_items_cost_one_and_stack() -> void:
	for item: Equipment.Id in [BOOTS, SHIELD]:
		assert_eq(Equipment.cost(item), 1, str(Equipment.Id.find_key(item)))
		assert_eq(Equipment.stack_limit(item), Equipment.MAX_PER_UNIT)
		assert_true(Equipment.roles(item).is_empty())


func test_every_item_costs_something_and_does_something() -> void:
	for item: Equipment.Id in Equipment.Id.values():
		assert_true(Equipment.cost(item) >= 1, str(Equipment.Id.find_key(item)))
		var adds := false
		for stat: Unit.Stat in Unit.Stat.values():
			adds = adds or Equipment.bonus(item, stat) != 0
		assert_true(adds or not Equipment.traits(item).is_empty(), "能力値か特性のどちらかを持つ: %s" % Equipment.Id.find_key(item))


func test_new_items_do_not_stack() -> void:
	var entry := Deck.new(MILITARY).add(UnitKind.Id.COMMANDO)
	assert_true(entry.equip(Equipment.Id.POWER_GAUNTLET))
	assert_false(entry.equip(Equipment.Id.POWER_GAUNTLET), "重ねられない装備の 2 個目は断る")
	assert_true(entry.equip(Equipment.Id.REGEN_CHARM), "違う装備なら持てる")
	assert_eq(entry.equipment.size(), 2)


func test_role_limited_items() -> void:
	var deck := Deck.new(MILITARY)
	assert_true(deck.add(UnitKind.Id.SNIPER).equip(Equipment.Id.LONG_SCOPE), "遠眼鏡は後衛が持てる")
	for kind: UnitKind.Id in [UnitKind.Id.SHIELD_TROOPER, UnitKind.Id.COMMANDO, UnitKind.Id.MEDIC]:
		assert_false(deck.add(kind).equip(Equipment.Id.LONG_SCOPE), "遠眼鏡は後衛だけ: %s" % UnitKind.Id.find_key(kind))
	assert_false(Deck.new(MILITARY).add(UnitKind.Id.SHIELD_TROOPER).equip(Equipment.Id.WAR_BANNER), "前衛は軍旗を持てない（元から支配領域を作る）")
	for kind: UnitKind.Id in [UnitKind.Id.SNIPER, UnitKind.Id.COMMANDO, UnitKind.Id.MEDIC]:
		assert_true(Deck.new(MILITARY).add(kind).equip(Equipment.Id.WAR_BANNER), str(UnitKind.Id.find_key(kind)))
	assert_false(Equipment.fits(Equipment.Id.REGEN_CHARM, UnitKind.Id.KING), "将はどの装備も持てない")


func test_add_unit_refuses_items_the_kind_cannot_hold() -> void:
	var battle := _battle()
	assert_eq(battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(0, 0), [Equipment.Id.LONG_SCOPE] as Array[Equipment.Id]), null)
	assert_eq(battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0), [Equipment.Id.LONG_SCOPE, Equipment.Id.LONG_SCOPE] as Array[Equipment.Id]), null)
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0), [Equipment.Id.LONG_SCOPE] as Array[Equipment.Id])
	assert_eq(sniper.attack_range(), UnitKind.attack_range(UnitKind.Id.SNIPER) + 1)


func test_stat_items_add_to_the_base_layer() -> void:
	var battle := _battle()
	var medic := battle.add_unit(UnitKind.Id.MEDIC, P1, Vector2i(0, 0), [Equipment.Id.POWER_GAUNTLET] as Array[Equipment.Id])
	assert_eq(medic.power(), UnitKind.power(UnitKind.Id.MEDIC) + 2, "回復役は回復量が増える")
	var trooper := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(1, 0), [Equipment.Id.DRAGON_SCALE] as Array[Equipment.Id])
	assert_eq(trooper.max_hp(), UnitKind.max_hp(UnitKind.Id.SHIELD_TROOPER) + 20)
	assert_eq(trooper.hp, trooper.max_hp())


func test_trait_items_grant_the_evolution_traits() -> void:
	var battle := _battle()
	var cell := Vector2i(0, 0)
	var traits := {
		Equipment.Id.REGEN_CHARM: [Evolution.Trait.REGENERATION],
		Equipment.Id.TRAIL_MAP: [Evolution.Trait.FOREST_WALK],
		Equipment.Id.SHADOW_CLOAK: [Evolution.Trait.IGNORES_ZOC],
		Equipment.Id.WAR_BANNER: [Evolution.Trait.EXERTS_ZOC],
		Equipment.Id.JET_PACK: [Evolution.Trait.IGNORES_ZOC, Evolution.Trait.FOREST_WALK],
		Equipment.Id.DRAGON_SCALE: [Evolution.Trait.REGENERATION],
	}
	for item: Equipment.Id in traits:
		var unit := battle.add_unit(UnitKind.Id.COMMANDO, P1, cell, [item] as Array[Equipment.Id])
		cell.x += 1
		for which: Evolution.Trait in Evolution.Trait.values():
			assert_eq(unit.has_trait(which), (traits[item] as Array).has(which), "%s / %s" % [Equipment.Id.find_key(item), Evolution.Trait.find_key(which)])
	var plain := battle.add_unit(UnitKind.Id.COMMANDO, P1, cell)
	assert_false(plain.exerts_zoc())
	assert_false(plain.ignores_zoc())


func test_entry_holds_duplicates_up_to_three() -> void:
	var entry := Deck.new(MILITARY).add(UnitKind.Id.SNIPER)
	assert_true(entry.equip(BOOTS))
	assert_true(entry.equip(BOOTS))
	assert_true(entry.equip(SHIELD))
	assert_eq(entry.count(BOOTS), 2)
	assert_eq(entry.count(SHIELD), 1)
	assert_false(entry.equip(SHIELD), "4 個目は持てない")
	assert_eq(entry.equipment.size(), 3)


func test_entry_unequips() -> void:
	var entry := Deck.new(MILITARY).add(UnitKind.Id.SNIPER)
	entry.equip(BOOTS)
	assert_false(entry.unequip(SHIELD))
	assert_true(entry.unequip(BOOTS))
	assert_eq(entry.equipment.size(), 0)


# --- コスト ---


func test_total_cost_adds_units_and_equipment() -> void:
	var deck := Deck.new(MILITARY)
	assert_eq(deck.total_cost(), 0)
	var sniper := deck.add(UnitKind.Id.SNIPER)
	assert_eq(deck.total_cost(), 3)
	sniper.equip(BOOTS)
	sniper.equip(BOOTS)
	assert_eq(deck.total_cost(), 5)
	var trooper := deck.add(UnitKind.Id.SHIELD_TROOPER)
	trooper.equip(SHIELD)
	trooper.equip(SHIELD)
	trooper.equip(BOOTS)
	assert_eq(deck.total_cost(), 5 + 4 + 3)
	sniper.unequip(BOOTS)
	deck.remove(trooper)
	assert_eq(deck.total_cost(), 4)


func test_cost_does_not_depend_on_the_army() -> void:
	# 陣営による割引は無い。同じ役割どうしのコストは、どちらの軍でも種類の表の値そのまま。
	for kind in Deck.roster(MILITARY) + Deck.roster(FANTASY):
		var deck := Deck.new(UnitKind.army(kind))
		deck.add(kind)
		assert_eq(deck.total_cost(), UnitKind.cost(kind), str(UnitKind.Id.find_key(kind)))
	assert_eq(UnitKind.cost(UnitKind.Id.KING), 0)


# --- 実効値の層 ---


func test_boots_add_move_range() -> void:
	var battle := _battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0), [BOOTS])
	assert_eq(sniper.move_range(), UnitKind.move_range(UnitKind.Id.SNIPER) + 2)
	assert_eq(sniper.max_hp(), UnitKind.max_hp(UnitKind.Id.SNIPER))


func test_shield_adds_max_hp_and_starts_full() -> void:
	var battle := _battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0), [SHIELD])
	assert_eq(sniper.max_hp(), UnitKind.max_hp(UnitKind.Id.SNIPER) + 30)
	assert_eq(sniper.hp, sniper.max_hp())


func test_duplicate_equipment_stacks() -> void:
	var battle := _battle()
	var boots := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0), [BOOTS, BOOTS, BOOTS])
	assert_eq(boots.move_range(), UnitKind.move_range(UnitKind.Id.SNIPER) + 6)
	var mixed := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(1, 0), [BOOTS, SHIELD, BOOTS])
	assert_eq(mixed.move_range(), UnitKind.move_range(UnitKind.Id.SNIPER) + 4)
	assert_eq(mixed.max_hp(), UnitKind.max_hp(UnitKind.Id.SNIPER) + 30)
	assert_eq(mixed.hp, mixed.max_hp())


func test_unit_without_equipment_has_the_kind_stats() -> void:
	var battle := _battle()
	for kind: UnitKind.Id in UnitKind.Id.values():
		var unit := Unit.new(1, kind, P1, Vector2i.ZERO)
		assert_eq(unit.max_hp(), UnitKind.max_hp(kind))
		assert_eq(unit.hp, UnitKind.max_hp(kind))
		assert_eq(unit.power(), UnitKind.power(kind))
		assert_eq(unit.move_range(), UnitKind.move_range(kind))
		assert_eq(unit.attack_range(), UnitKind.attack_range(kind))
	assert_eq(battle.units.size(), 0)


func test_layers_add_up_in_order() -> void:
	var battle := _battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0), [SHIELD, BOOTS])
	sniper.relic_bonus[Unit.Stat.MAX_HP] = 10
	sniper.relic_bonus[Unit.Stat.POWER] = 1
	sniper.temporary_bonus[Unit.Stat.POWER] = 5
	sniper.temporary_bonus[Unit.Stat.MOVE_RANGE] = 2
	assert_eq(sniper.base_stat(Unit.Stat.MAX_HP), 13 + 30, "層 1 は聖遺物を含まない")
	assert_eq(sniper.max_hp(), 13 + 30 + 10)
	assert_eq(sniper.power(), 7 + 1 + 5)
	assert_eq(sniper.move_range(), 3 + 2 + 2)
	assert_eq(sniper.attack_range(), 4)
	sniper.temporary_bonus.clear()
	assert_eq(sniper.power(), 7 + 1, "一時的な補正が消えても、聖遺物は残る")
	assert_eq(sniper.move_range(), 3 + 2)


func test_effective_stats_do_not_go_negative() -> void:
	var battle := _battle()
	var medic := battle.add_unit(UnitKind.Id.MEDIC, P1, Vector2i(0, 0))
	medic.temporary_bonus[Unit.Stat.POWER] = -100
	medic.temporary_bonus[Unit.Stat.MOVE_RANGE] = -100
	medic.temporary_bonus[Unit.Stat.MAX_HP] = -100
	assert_eq(medic.power(), 0)
	assert_eq(medic.move_range(), 0)
	assert_eq(medic.max_hp(), 1)


func test_rules_use_effective_stats() -> void:
	var battle := _battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 6), [BOOTS])
	var king := battle.add_unit(UnitKind.Id.KING, P2, Vector2i(0, 0))
	# 移動力 3 + 2。
	assert_true(Movement.reachable(battle, sniper).has(Vector2i(0, 1)))
	assert_false(Movement.reachable(battle, sniper).has(Vector2i(1, 1)))
	# 攻撃力と射程は、補正を足した値で決まる。
	assert_false(Combat.can_attack(battle, sniper, king))
	sniper.temporary_bonus[Unit.Stat.ATTACK_RANGE] = 2
	assert_true(Combat.can_attack(battle, sniper, king))
	sniper.relic_bonus[Unit.Stat.POWER] = 1
	assert_eq(Combat.damage(battle, sniper, king), 8)


func test_add_unit_refuses_bad_equipment() -> void:
	var battle := _battle()
	assert_eq(battle.add_unit(UnitKind.Id.KING, P1, Vector2i(0, 0), [BOOTS]), null, "将は装備を持てない")
	assert_eq(battle.add_unit(UnitKind.Id.MINION, Unit.Side.NEUTRAL, Vector2i(0, 0), [SHIELD]), null)
	assert_eq(battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0), [BOOTS, BOOTS, BOOTS, BOOTS]), null)
	assert_eq(battle.units.size(), 0)
	# 断った駒は番号を使わない。
	assert_eq(battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0)).id, 1)


func test_unit_does_not_share_the_equipment_list() -> void:
	var battle := _battle()
	var entry := Deck.new(MILITARY).add(UnitKind.Id.SNIPER)
	entry.equip(BOOTS)
	var sniper := battle.add_unit(entry.kind, P1, Vector2i(0, 0), entry.equipment)
	entry.equip(BOOTS)
	assert_eq(sniper.equipment, [BOOTS] as Array[Equipment.Id])


func test_clone_copies_every_layer() -> void:
	var battle := _battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0), [SHIELD, BOOTS])
	sniper.relic_bonus[Unit.Stat.POWER] = 1
	sniper.temporary_bonus[Unit.Stat.MOVE_RANGE] = 2
	sniper.hp = 40

	var copy := battle.clone()
	var copied := copy.unit_by_id(sniper.id)
	assert_eq(copied.equipment, sniper.equipment)
	assert_eq(copied.hp, 40)
	assert_eq(copied.max_hp(), 43)
	assert_eq(copied.power(), 8)
	assert_eq(copied.move_range(), 7)

	copied.equipment.clear()
	copied.relic_bonus[Unit.Stat.POWER] = 9
	copied.temporary_bonus.clear()
	assert_eq(sniper.equipment.size(), 2)
	assert_eq(sniper.power(), 8)
	assert_eq(sniper.move_range(), 7)


# --- 軍を盤に置く ---


func test_deploy_puts_the_king_on_the_hq() -> void:
	var battle := _battle()
	var placed := Deployment.deploy(battle, P1, Deck.new(MILITARY))
	assert_eq(placed.size(), 1)
	assert_eq(placed[0].kind, UnitKind.Id.KING)
	assert_eq(placed[0].side, P1)
	assert_eq(placed[0].cell, P1_HQ)
	assert_eq(placed[0].equipment.size(), 0)


func test_deploy_fills_the_front_row_from_the_centre() -> void:
	var battle := _battle()
	var deck := Deck.new(MILITARY)
	for kind in Deck.roster(MILITARY):
		deck.add(kind)
	deck.add(UnitKind.Id.SNIPER)
	deck.add(UnitKind.Id.SNIPER)
	var placed := Deployment.deploy(battle, P1, deck)
	assert_eq(placed.size(), 7)
	# プレイヤー1 の本陣は下の端。前は上。
	assert_eq(
		_cells(placed),
		[
			P1_HQ,
			Vector2i(3, 5), Vector2i(2, 5), Vector2i(4, 5), Vector2i(1, 5), Vector2i(5, 5),
			Vector2i(3, 4),
		] as Array[Vector2i],
	)
	# 編成の並びの順に置かれる。
	for index in deck.entries.size():
		assert_eq(placed[index + 1].kind, deck.entries[index].kind)
		assert_eq(placed[index + 1].side, P1)


func test_deploy_faces_the_centre_of_the_board() -> void:
	var battle := _battle()
	var deck := Deck.new(FANTASY)
	deck.add(UnitKind.Id.PALADIN)
	deck.add(UnitKind.Id.PRIEST)
	var placed := Deployment.deploy(battle, P2, deck)
	assert_eq(_cells(placed), [P2_HQ, Vector2i(3, 1), Vector2i(2, 1)] as Array[Vector2i])


func test_deploy_skips_blocked_cells() -> void:
	var battle := _battle([
		".......",
		".......",
		".......",
		".......",
		".......",
		".F#....",
		".......",
	])
	battle.board.hq_cells = [Vector2i(1, 6), P2_HQ]
	battle.add_unit(UnitKind.Id.MINION, Unit.Side.NEUTRAL, Vector2i(1, 5))
	var deck := Deck.new(MILITARY)
	for i in 4:
		deck.add(UnitKind.Id.SNIPER)
	var placed := Deployment.deploy(battle, P1, deck)
	# 本陣の列は 1。行は列 -1〜3 のうち盤の中だけ。(1,5) は駒、(2,5) は障害物。
	assert_eq(
		_cells(placed),
		[Vector2i(1, 6), Vector2i(0, 5), Vector2i(3, 5), Vector2i(1, 4), Vector2i(0, 4)] as Array[Vector2i],
	)


func test_deploy_applies_equipment() -> void:
	var battle := _battle()
	var deck := Deck.new(FANTASY)
	var sorcerer := deck.add(UnitKind.Id.SORCERER)
	sorcerer.equip(BOOTS)
	sorcerer.equip(BOOTS)
	sorcerer.equip(SHIELD)
	deck.add(UnitKind.Id.PRIEST)
	var placed := Deployment.deploy(battle, P1, deck)
	assert_eq(placed[1].equipment, [BOOTS, BOOTS, SHIELD] as Array[Equipment.Id])
	assert_eq(placed[1].move_range(), UnitKind.move_range(UnitKind.Id.SORCERER) + 4)
	assert_eq(placed[1].max_hp(), UnitKind.max_hp(UnitKind.Id.SORCERER) + 30)
	assert_eq(placed[1].hp, placed[1].max_hp())
	assert_eq(placed[2].equipment.size(), 0)
	assert_eq(placed[2].hp, UnitKind.max_hp(UnitKind.Id.PRIEST))


func test_deploy_both_sides_without_overlap() -> void:
	var battle := _battle()
	var deck := Deck.new(MILITARY)
	for i in 6:
		deck.add(UnitKind.Id.COMMANDO)
	var placed := Deployment.deploy(battle, P1, deck) + Deployment.deploy(battle, P2, deck)
	assert_eq(placed.size(), 14)
	var seen := {}
	for unit in placed:
		assert_false(seen.has(unit.cell), "同じマスに 2 体")
		seen[unit.cell] = true
		assert_eq(battle.unit_at(unit.cell), unit)


func test_deploy_places_nothing_when_the_hq_is_taken() -> void:
	var battle := _battle()
	battle.add_unit(UnitKind.Id.MINION, Unit.Side.NEUTRAL, P1_HQ)
	var deck := Deck.new(MILITARY)
	deck.add(UnitKind.Id.SNIPER)
	assert_eq(Deployment.deploy(battle, P1, deck).size(), 0)
	assert_eq(battle.units.size(), 1)
	assert_eq(Deployment.deploy(battle, Unit.Side.NEUTRAL, deck).size(), 0, "中立に本陣は無い")


func test_deploy_leaves_out_units_with_no_room() -> void:
	var battle := _battle([
		"...",
		"...",
	])
	battle.board.hq_cells = [Vector2i(1, 1), Vector2i(1, 0)]
	battle.add_unit(UnitKind.Id.KING, P2, Vector2i(1, 0))
	var deck := Deck.new(MILITARY)
	for i in 3:
		deck.add(UnitKind.Id.SNIPER)
	var placed := Deployment.deploy(battle, P1, deck)
	assert_eq(_cells(placed), [Vector2i(1, 1), Vector2i(0, 0), Vector2i(2, 0)] as Array[Vector2i])


func test_deploy_on_generated_boards() -> void:
	var deck := Deck.new(MILITARY)
	for i in 6:
		deck.add(UnitKind.Id.SNIPER)
	for stage: BoardGenerator.Stage in BoardGenerator.Stage.values():
		var battle := Battle.new(BoardGenerator.generate(stage, 7))
		for side: Unit.Side in [P1, P2]:
			var placed := Deployment.deploy(battle, side, deck)
			assert_eq(placed.size(), 7, "マップ %d" % stage)
			var hq := battle.board.hq_cells[side]
			for unit in placed:
				var d := (unit.cell - hq).abs()
				assert_true(maxi(d.x, d.y) <= 2, "本陣のそば（マップ %d）" % stage)


func test_regeneration_from_an_item_heals_once_even_with_the_evolution() -> void:
	var battle := _battle()
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(0, 0), [Equipment.Id.REGEN_CHARM] as Array[Equipment.Id])
	paladin.hp -= 20
	assert_eq(Evolution.regeneration_heal(paladin), Evolution.REGENERATION_HEAL)
	assert_true(Evolution.regeneration_targets(battle, P1).has(paladin))
	paladin.evolve(Evolution.Id.SACRED)
	assert_eq(Evolution.regeneration_heal(paladin), Evolution.REGENERATION_HEAL, "進化先と装備の両方が与えても 1 回ぶん")


func test_trail_map_walks_into_forest_like_plain_ground() -> void:
	var battle := _battle([
		".......",
		".FFF...",
		".......",
		".......",
		".......",
		".......",
		".......",
	])
	var walker := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 1), [Equipment.Id.TRAIL_MAP] as Array[Equipment.Id])
	var plain := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 2))
	assert_eq(walker.move_cost(battle.board, Vector2i(1, 1)), 1)
	assert_true(plain.move_cost(battle.board, Vector2i(1, 1)) > 1)
