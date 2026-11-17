extends "res://tests/base_test.gd"
## 駒の詳しい説明の文（DeckText.detail_lines。編成確認と出撃準備の詳細、部隊編成の駒の札）。

const DeckText := preload("res://game/deck_text.gd")
const Names := preload("res://game/names.gd")
const Maps := preload("res://tests/support/maps.gd")


func test_a_starting_level_adds_the_level_up_gains_to_the_stats() -> void:
	# 対戦の始めに Growth.start_at で伸ばした駒と、同じ値を出す。
	var battle := Maps.battle([".."])
	var unit := battle.add_unit(UnitKind.Id.PALADIN, Unit.Side.PLAYER1, Vector2i(0, 0))
	Growth.start_at(unit, 2, 0)
	var lines := DeckText.detail_lines(UnitKind.Id.PALADIN, [], -1, true, 2)
	var expected := DeckText.stats_line(UnitKind.Id.PALADIN, {
		Unit.Stat.MAX_HP: unit.max_hp() - UnitKind.max_hp(UnitKind.Id.PALADIN),
		Unit.Stat.POWER: unit.power() - UnitKind.power(UnitKind.Id.PALADIN),
	})
	assert_true(lines.has(expected), "Lv2 の能力値が出ない: %s" % [lines])
	assert_false(lines.has(DeckText.stats_line(UnitKind.Id.PALADIN)), "Lv1 の能力値のまま")


func test_items_show_their_effects_and_the_stats_with_items() -> void:
	var held: Array[Equipment.Id] = [Equipment.Id.IRON_SHIELD, Equipment.Id.IRON_SHIELD]
	var text := "\n".join(DeckText.detail_lines(UnitKind.Id.SHIELD_TROOPER, held))
	assert_true(text.contains(Names.item(Equipment.Id.IRON_SHIELD) + " ×2"), text)
	assert_true(text.contains(DeckText.equipment_effect(Equipment.Id.IRON_SHIELD)), text)
	assert_true(text.contains(DeckText.stats_line(UnitKind.Id.SHIELD_TROOPER, DeckText.equipment_bonus(held))), text)
	assert_false("\n".join(DeckText.detail_lines(UnitKind.Id.SHIELD_TROOPER, held, -1, false)).contains(Names.item(Equipment.Id.IRON_SHIELD)),
		"部隊編成の画面の札には、持ち物の行を入れない")


func test_monsters_show_no_cost() -> void:
	var text := "\n".join(DeckText.detail_lines(UnitKind.Id.SKELETON_BRUTE))
	assert_false(text.contains("コスト"), text)
