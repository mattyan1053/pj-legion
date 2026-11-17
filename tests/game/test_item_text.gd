extends "res://tests/base_test.gd"
## 持ち物の効果の文と、持てない理由（game/deck_text.gd）。部隊編成の持ち物の欄が使う。

const DeckText := preload("res://game/deck_text.gd")
const ItemIcon := preload("res://game/item_icon.gd")


func test_every_item_has_an_effect_text_and_an_icon_color() -> void:
	for item: Equipment.Id in Equipment.Id.values():
		assert_ne(DeckText.equipment_effect(item), "", str(Equipment.Id.find_key(item)))
		assert_true(ItemIcon.COLORS.has(item), "印の色: %s" % Equipment.Id.find_key(item))


func test_effect_text_reads_stats_traits_and_holders() -> void:
	assert_eq(DeckText.equipment_effect(Equipment.Id.SPEED_BOOTS), "移動 +2")
	assert_eq(DeckText.equipment_effect(Equipment.Id.LONG_SCOPE), "射程 +1（後衛専用）")
	assert_eq(DeckText.equipment_effect(Equipment.Id.WAR_BANNER).ends_with("（前衛以外）"), true)
	assert_true(DeckText.equipment_effect(Equipment.Id.JET_PACK).begins_with("移動 +2、"), "能力値が先、特性があと")


func test_refusal_names_the_reason() -> void:
	var none: Array[Equipment.Id] = []
	assert_eq(DeckText.item_refusal(UnitKind.Id.COMMANDO, none, Equipment.Id.LONG_SCOPE), "後衛専用")
	assert_eq(DeckText.item_refusal(UnitKind.Id.SHIELD_TROOPER, none, Equipment.Id.WAR_BANNER), "前衛以外")
	assert_eq(DeckText.item_refusal(UnitKind.Id.SNIPER, none, Equipment.Id.LONG_SCOPE), "", "持てる")
	var held: Array[Equipment.Id] = [Equipment.Id.REGEN_CHARM]
	assert_eq(DeckText.item_refusal(UnitKind.Id.SNIPER, held, Equipment.Id.REGEN_CHARM), "1 体 1 個まで")
	var boots: Array[Equipment.Id] = [Equipment.Id.SPEED_BOOTS, Equipment.Id.SPEED_BOOTS]
	assert_eq(DeckText.item_refusal(UnitKind.Id.SNIPER, boots, Equipment.Id.SPEED_BOOTS), "", "重ねられる持ち物は、数の上限だけが限り（理由は出さない）")
