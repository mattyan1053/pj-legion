extends "res://tests/base_test.gd"
## 対戦モードで選べる盤の一覧（game/versus_fields.gd。docs/stage-select.md の「選べる盤」）。

const VersusFields := preload("res://game/versus_fields.gd")
const StageLook := preload("res://game/stage_look.gd")


func test_every_field_has_a_key_a_board_a_look_and_card_text() -> void:
	var seen := {}
	for field in VersusFields.all_ids():
		assert_false(seen.has(field), "鍵が重なっている: %s" % field)
		seen[field] = true
		assert_true(VersusFields.title_of(field) != "", "名前が無い: %s" % field)
		assert_true(VersusFields.tags_of(field) != "", "ひとことの特徴が無い: %s" % field)
		assert_true(VersusFields.note_of(field) != "", "説明が無い: %s" % field)
		assert_true(StageLook.THEMES.has(VersusFields.look_of(field)), "見た目が無い: %s" % field)
		var defined := VersusFields.scenario_of(field)
		assert_true(defined != null and defined.can_make_board(), "盤を作れない: %s" % field)
		assert_eq(defined.title, VersusFields.title_of(field))
		assert_true(VersusFields.card_board(field, 3) != null, "カードの縮図の盤が無い: %s" % field)


func test_generated_stages_come_first_in_the_order_of_the_stages() -> void:
	var expected: Array[StringName] = []
	for stage: BoardGenerator.Stage in MatchSetup.STAGE_NAMES:
		expected.append(VersusFields.field_of_stage(stage))
	assert_eq(VersusFields.generated_ids(), expected)
	assert_eq(VersusFields.ids().slice(0, expected.size()), expected, "生成のステージを先に並べる（F1〜F3 と番号がいまのまま）")
	for index in expected.size():
		assert_eq(VersusFields.number_of(expected[index]), index + 1)
		assert_eq(VersusFields.scenario_of(expected[index]).stage, MatchSetup.STAGE_NAMES.keys()[index])


func test_the_generated_stages_keep_their_names_and_looks() -> void:
	assert_eq(VersusFields.title_of(VersusFields.PLAIN), "中央平原")
	assert_eq(VersusFields.look_of(VersusFields.PLAIN), StageLook.GRASSLAND)
	assert_eq(VersusFields.look_of(VersusFields.LABYRINTH), StageLook.STONE_WALLS)
	assert_eq(VersusFields.look_of(VersusFields.TWIN_SPRINGS), StageLook.CRYSTAL_FOREST)
	assert_true(VersusFields.has(VersusFields.DEFAULT) and VersusFields.is_shown(VersusFields.DEFAULT))


func test_hand_maps_are_the_same_on_every_seed_and_hidden_ones_are_not_shown() -> void:
	for field in VersusFields.all_ids():
		if VersusFields.is_generated(field):
			continue
		var first := VersusFields.scenario_of(field).make_board(1)
		var other := VersusFields.scenario_of(field).make_board(42)
		assert_eq(first.size, other.size, str(field))
		assert_eq(first.hq_cells, other.hq_cells, str(field))
		assert_eq(VersusFields.ids().has(field), VersusFields.is_shown(field))
		assert_eq(VersusFields.number_of(field) > 0, VersusFields.is_shown(field), "出さない盤には番号が付かない")


func test_unknown_keys_have_nothing() -> void:
	assert_false(VersusFields.has(&"nowhere"))
	assert_true(VersusFields.scenario_of(&"nowhere") == null)
	assert_eq(VersusFields.number_of(&"nowhere"), 0)
	assert_eq(VersusFields.field_of_stage(-1 as BoardGenerator.Stage), &"")
