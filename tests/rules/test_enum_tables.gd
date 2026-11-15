extends "res://tests/base_test.gd"
## 列挙の値ごとの表（rules/）。列挙の値を足したら、表にも載っていること。
##
## 載せ忘れても、エラーにならずに黙って弱く・遅くなる表がある（CPU のスキルの表は、載っていないと
## 「全部の対象を試す」「ダメージのイベントだけで見積もる」に落ちる）。ここで、足したときに気付けるようにする。


## enum_values のすべてが table に載っているか。skip は載せなくてよい値（載っていたら、それも知らせる）。
func _assert_covers(table: Dictionary, enum_values: Array, label: String, skip: Array = []) -> void:
	for value: int in enum_values:
		if skip.has(value):
			assert_false(table.has(value), "%s の除外に %d があるのに、表にも載っている" % [label, value])
		else:
			assert_true(table.has(value), "%s に %d が無い" % [label, value])
	for key: Variant in table:
		assert_true(enum_values.has(key), "%s に列挙に無い値 %s がある" % [label, key])


## table の値がすべて、CpuPlayer のメソッドの名前になっているか（call() で呼ぶので、綴りを誤っても読み込みでは気付かない）。
func _assert_methods(table: Dictionary, label: String) -> void:
	var cpu := CpuPlayer.new()
	for key: Variant in table:
		assert_true(cpu.has_method(table[key]), "%s の %s が CpuPlayer に無い" % [label, table[key]])


# --- CPU（rules/cpu_player.gd） ---


func test_every_skill_has_cpu_targets() -> void:
	# 対象を絞らないと、選べるマスを全部、複製の上で試す。どのスキルでも絞る。
	_assert_covers(CpuPlayer.SKILL_TARGETS, Skill.Id.values(), "SKILL_TARGETS")
	_assert_methods(CpuPlayer.SKILL_TARGETS, "SKILL_TARGETS")


func test_every_skill_has_a_cpu_value_or_is_left_out_on_purpose() -> void:
	# 載せないのは、ダメージ・回復・経験値のイベントだけで価値が決まるスキル（_outcome_value がそのまま読む）。
	var by_events_only := [Skill.Id.FIREBALL]
	_assert_covers(CpuPlayer.SKILL_VALUES, Skill.Id.values(), "SKILL_VALUES", by_events_only)
	_assert_methods(CpuPlayer.SKILL_VALUES, "SKILL_VALUES")


func test_every_ult_has_a_cpu_rule() -> void:
	# 載っていないと、CPU が必殺技を使えるときに辞書を引いてエラーになる。
	_assert_covers(CpuPlayer.ULT_USES, Ult.Id.values(), "ULT_USES")
	_assert_methods(CpuPlayer.ULT_USES, "ULT_USES")


func test_every_role_has_a_cpu_style_and_order() -> void:
	_assert_covers(CpuPlayer.STYLES, UnitKind.Role.values(), "STYLES")
	for role: UnitKind.Role in UnitKind.Role.values():
		assert_true(CpuPlayer.ROLE_ORDER.has(role), "ROLE_ORDER に %d が無い" % role)
	assert_eq(CpuPlayer.ROLE_ORDER.size(), UnitKind.Role.size(), "ROLE_ORDER に同じ役割が 2 度ある")


# --- 一覧と表 ---


func test_every_ult_is_listed() -> void:
	var ids := {}
	for ult in Ults.ALL:
		ids[ult.id()] = true
	_assert_covers(ids, Ult.Id.values(), "Ults.ALL")
	assert_eq(Ults.ALL.size(), Ult.Id.size(), "Ults.ALL に同じ必殺技が 2 度ある")
	# 軍ごとに 1 つ（NONE は持たない）。
	for army: UnitKind.Army in UnitKind.Army.values():
		if army != UnitKind.Army.NONE:
			assert_true(Ults.of_army(army) != null, "軍 %d に必殺技が無い" % army)


func test_every_role_grows() -> void:
	# 役割を持たない駒（将、中立）は、経験値で育たない。
	_assert_covers(Growth.GAINS, UnitKind.Role.values(), "Growth.GAINS", [UnitKind.Role.NONE])


func test_every_stage_has_a_name() -> void:
	_assert_covers(MatchSetup.STAGE_NAMES, BoardGenerator.Stage.values(), "MatchSetup.STAGE_NAMES")


func test_every_relic_equipment_evolution_and_kind_is_in_its_table() -> void:
	_assert_covers(Relics._TABLE, Relics.Id.values(), "Relics._TABLE")
	for id: Relics.Id in Relics.Id.values():
		assert_true(Relics.OF_BOSS.has(id), "聖遺物 %d を落とす中ボスがいない" % id)
	_assert_covers(Equipment._TABLE, Equipment.Id.values(), "Equipment._TABLE")
	_assert_covers(Evolution._TABLE, Evolution.Id.values(), "Evolution._TABLE", [Evolution.Id.NONE])  # NONE は「進化していない」
	_assert_covers(UnitKind._TABLE, UnitKind.Id.values(), "UnitKind._TABLE")
