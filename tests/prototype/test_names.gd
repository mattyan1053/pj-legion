extends "res://tests/base_test.gd"
## 画面に出す名前の表（prototype/names.gd）。列挙の値を足したら、表にも載っていること。

const Names := preload("res://prototype/names.gd")


## enum_values のすべてが table に、空でない文で載っているか。skip は載せなくてよい値。
func _assert_covers(table: Dictionary, enum_values: Array, label: String, skip: Array = []) -> void:
	for value: int in enum_values:
		if skip.has(value):
			continue
		assert_true(table.has(value), "%s に %d が無い" % [label, value])
		assert_ne(String(table.get(value, "")), "", "%s の %d が空" % [label, value])


func test_every_side_has_names() -> void:
	_assert_covers(Names.SIDE_NAMES, Unit.Side.values(), "SIDE_NAMES")
	_assert_covers(Names.SIDE_WORDS, Unit.Side.values(), "SIDE_WORDS")


func test_every_army_has_a_name() -> void:
	_assert_covers(Names.ARMY_NAMES, UnitKind.Army.values(), "ARMY_NAMES")


func test_every_role_has_a_name() -> void:
	# 役割を持たない駒（将、中立）は、役割の名前を出さない。
	_assert_covers(Names.ROLE_NAMES, UnitKind.Role.values(), "ROLE_NAMES", [UnitKind.Role.NONE])


func test_every_stat_has_a_name_in_order() -> void:
	_assert_covers(Names.STAT_NAMES, Unit.Stat.values(), "STAT_NAMES")
	assert_eq(Names.STAT_NAMES.keys(), Unit.Stat.values(), "能力の並びが、列挙の順と違う")


func test_every_trait_has_a_text() -> void:
	_assert_covers(Names.TRAIT_TEXTS, Evolution.Trait.values(), "TRAIT_TEXTS")


func test_every_field_effect_has_a_name() -> void:
	_assert_covers(Names.FIELD_EFFECT_NAMES, FieldEffect.Type.values(), "FIELD_EFFECT_NAMES")
