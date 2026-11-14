extends "res://tests/base_test.gd"
## 駒の種類ごとの能力値と、役割・軍。


func test_every_kind_has_stats() -> void:
	for id: UnitKind.Id in UnitKind.Id.values():
		assert_true(UnitKind.max_hp(id) > 0, UnitKind.display_name(id))
		assert_true(UnitKind.move_range(id) > 0, UnitKind.display_name(id))
		assert_true(UnitKind.attack_range(id) > 0, UnitKind.display_name(id))


func test_sniper() -> void:
	var id := UnitKind.Id.SNIPER
	assert_eq(UnitKind.role(id), UnitKind.Role.REARGUARD)
	assert_eq(UnitKind.army(id), UnitKind.Army.MILITARY)
	assert_eq(UnitKind.cost(id), 3)
	assert_eq(UnitKind.max_hp(id), 12)
	assert_eq(UnitKind.power(id), 9)
	assert_eq(UnitKind.move_range(id), 3)
	assert_eq(UnitKind.attack_range(id), 4)


func test_same_role_differs_by_army() -> void:
	assert_eq(UnitKind.role(UnitKind.Id.SHIELD_TROOPER), UnitKind.Role.VANGUARD)
	assert_eq(UnitKind.role(UnitKind.Id.PALADIN), UnitKind.Role.VANGUARD)
	assert_eq(UnitKind.army(UnitKind.Id.SHIELD_TROOPER), UnitKind.Army.MILITARY)
	assert_eq(UnitKind.army(UnitKind.Id.PALADIN), UnitKind.Army.FANTASY)
	assert_ne(UnitKind.max_hp(UnitKind.Id.SHIELD_TROOPER), UnitKind.max_hp(UnitKind.Id.PALADIN))


func test_healers() -> void:
	assert_eq(UnitKind.role(UnitKind.Id.MEDIC), UnitKind.Role.HEALER)
	assert_eq(UnitKind.role(UnitKind.Id.PRIEST), UnitKind.Role.HEALER)


func test_king_costs_nothing_and_has_no_role() -> void:
	assert_eq(UnitKind.cost(UnitKind.Id.KING), 0)
	assert_eq(UnitKind.role(UnitKind.Id.KING), UnitKind.Role.NONE)
	assert_eq(UnitKind.army(UnitKind.Id.KING), UnitKind.Army.NONE)


func test_neutrals() -> void:
	assert_true(UnitKind.is_neutral(UnitKind.Id.MINION))
	assert_true(UnitKind.is_neutral(UnitKind.Id.ELITE_MINION))
	assert_false(UnitKind.is_neutral(UnitKind.Id.KING))
	assert_eq(UnitKind.max_hp(UnitKind.Id.ELITE_MINION), 80)
	assert_eq(UnitKind.power(UnitKind.Id.ELITE_MINION), 10)


func test_only_vanguards_exert_zoc() -> void:
	for id: UnitKind.Id in UnitKind.Id.values():
		var expected: bool = id == UnitKind.Id.SHIELD_TROOPER or id == UnitKind.Id.PALADIN
		assert_eq(UnitKind.exerts_zoc(id), expected, UnitKind.display_name(id))
