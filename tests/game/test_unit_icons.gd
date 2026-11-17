extends "res://tests/base_test.gd"
## 駒のアイコン（game/unit_icons.gd と assets/unit_icons/）。

const Names := preload("res://game/names.gd")
const UnitIcons := preload("res://game/unit_icons.gd")
const BattleScreen := preload("res://game/battle_screen.gd")
const UnitView := preload("res://game/unit_view.gd")


func test_every_variant_has_a_picture() -> void:
	for variant: Array in UnitIcons.variants():
		var texture := UnitIcons.texture(variant[0], variant[1], variant[2], variant[3])
		assert_true(texture != null, "アイコンが無い: %s（tools/unit_icons.sh で書き直す）" % UnitIcons.file_name(variant[0], variant[1], variant[2], variant[3]))


## 将の別の姿（骸骨の将など）は、いつもの将と違う絵。将でない駒には効かない。
func test_king_looks_have_their_own_picture() -> void:
	for look: StringName in UnitView.KING_LOOKS:
		var texture := UnitIcons.texture(UnitKind.Id.KING, 1, false, look)
		assert_true(texture != null and texture != UnitIcons.texture(UnitKind.Id.KING, 1), "%s の将のアイコン" % look)
	assert_eq(UnitIcons.texture(UnitKind.Id.SNIPER, 1, false, &"skeleton_mage"), UnitIcons.texture(UnitKind.Id.SNIPER, 1))


func test_every_unit_kind_has_an_icon_on_both_sides() -> void:
	for kind: UnitKind.Id in UnitKind.Id.values():
		for side in 2:
			assert_true(UnitIcons.texture(kind, side) != null, "%s に陣営 %d のアイコンが無い" % [Names.kind(kind), side])
			assert_true(UnitIcons.texture(kind, side, true) != null, "%s に進化後のアイコンが無い" % Names.kind(kind))


func test_colors_match_the_battle_teams() -> void:
	# アイコンは対戦の画面の陣営の色で写す。色を変えたら、両方を変えて写し直す。
	assert_eq(UnitIcons.COLORS, BattleScreen.TEAM_COLORS)
