extends "res://tests/base_test.gd"
## 駒の種類ごとの能力値と、役割・軍。


func test_every_kind_has_stats() -> void:
	for id: UnitKind.Id in UnitKind.Id.values():
		assert_true(UnitKind.max_hp(id) > 0, str(UnitKind.Id.find_key(id)))
		assert_true(UnitKind.move_range(id) > 0, str(UnitKind.Id.find_key(id)))
		assert_true(UnitKind.attack_range(id) > 0, str(UnitKind.Id.find_key(id)))


func test_sniper() -> void:
	var id := UnitKind.Id.SNIPER
	assert_eq(UnitKind.role(id), UnitKind.Role.REARGUARD)
	assert_eq(UnitKind.army(id), UnitKind.Army.MILITARY)
	assert_eq(UnitKind.cost(id), 3)
	assert_eq(UnitKind.max_hp(id), 13)
	assert_eq(UnitKind.power(id), 7)
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
	assert_eq(UnitKind.max_hp(UnitKind.Id.ELITE_MINION), 50)
	assert_eq(UnitKind.power(UnitKind.Id.ELITE_MINION), 10)


func test_only_vanguards_exert_zoc() -> void:
	for id: UnitKind.Id in UnitKind.Id.values():
		var expected: bool = id in [UnitKind.Id.SHIELD_TROOPER, UnitKind.Id.PALADIN, UnitKind.Id.SKELETON_BRUTE]
		assert_eq(UnitKind.exerts_zoc(id), expected, str(UnitKind.Id.find_key(id)))


## 魔物は役割を持ち、軍を持たない。将と中立の駒は魔物ではない。
func test_monsters_have_a_role_but_no_army() -> void:
	var monsters: Array[UnitKind.Id] = [
		UnitKind.Id.SKELETON, UnitKind.Id.SKELETON_ARCHER, UnitKind.Id.SKELETON_BRUTE,
		UnitKind.Id.SKELETON_CALLER, UnitKind.Id.SKELETON_DRUMMER,
	]
	for id: UnitKind.Id in UnitKind.Id.values():
		assert_eq(UnitKind.is_monster(id), monsters.has(id), str(UnitKind.Id.find_key(id)))
	for id in monsters:
		assert_eq(UnitKind.army(id), UnitKind.Army.NONE)
		assert_ne(UnitKind.role(id), UnitKind.Role.NONE)
		assert_false(UnitKind.is_neutral(id))
		assert_false(Equipment.can_equip(id), "魔物は持ち物を持てない")


## 魔物はどの軍のロスターにも入らない（雇えない）。
func test_monsters_are_not_in_any_roster() -> void:
	var rules := DeckRules.versus()
	for army in rules.armies():
		for kind in rules.roster(army):
			assert_false(UnitKind.is_monster(kind), str(UnitKind.Id.find_key(kind)))


## 種類ごとの特徴: 骸骨兵は弱く速い、骸骨射手は射程がある、骸骨重兵は堅くて遅い（docs/unit-roster.md の「魔物」）。
func test_each_monster_has_its_own_edge() -> void:
	assert_true(UnitKind.max_hp(UnitKind.Id.SKELETON) < UnitKind.max_hp(UnitKind.Id.SNIPER) + 2, "骸骨兵は脆い")
	assert_true(UnitKind.attack_range(UnitKind.Id.SKELETON_ARCHER) > 1)
	assert_true(UnitKind.max_hp(UnitKind.Id.SKELETON_BRUTE) > UnitKind.max_hp(UnitKind.Id.PALADIN), "骸骨重兵はパラディンより堅い")
	assert_true(UnitKind.move_range(UnitKind.Id.SKELETON_BRUTE) < UnitKind.move_range(UnitKind.Id.PALADIN), "骸骨重兵はパラディンより遅い")


func test_a_fresh_raider_cannot_one_shot_a_fresh_sniper() -> void:
	# レベル 1 どうしでは、奇襲の一撃でスナイパーは落ちない。育った奇襲（レベル 2）なら落とせる（docs/unit-roster.md）。
	var sniper_hp := UnitKind.max_hp(UnitKind.Id.SNIPER)
	var raider_gain: int = Growth.GAINS[UnitKind.Role.RAIDER][Unit.Stat.POWER]
	for raider: UnitKind.Id in [UnitKind.Id.COMMANDO, UnitKind.Id.SPELLBLADE]:
		assert_true(UnitKind.power(raider) < sniper_hp, str(UnitKind.Id.find_key(raider)))
		assert_true(UnitKind.power(raider) + raider_gain >= sniper_hp, str(UnitKind.Id.find_key(raider)))
