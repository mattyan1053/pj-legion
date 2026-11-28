extends "res://tests/base_test.gd"
## 回復の共通の道（Mend）: 上限で止める、出来事に結果を書く、HP を増やすのは Mend だけ。

const Maps := preload("res://tests/support/maps.gd")

const ROOT := "res://rules"


func test_give_stops_at_max_hp_and_fills_the_event() -> void:
	var battle := Maps.battle(["...."])
	var unit := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, Unit.Side.PLAYER1, Vector2i(0, 0))
	unit.hp = unit.max_hp() - 3
	var event := Mend.give(unit, 10, SupplyHealedEvent.new(7)) as SupplyHealedEvent
	assert_eq(unit.hp, unit.max_hp())
	assert_eq(event.medic_id, 7)
	assert_eq(event.unit_id, unit.id)
	assert_eq(event.amount, 3)
	assert_eq(event.hp, unit.max_hp())
	assert_eq(Mend.amount(unit, 10), 0)  # 満タンなら 0（負にならない）


func test_only_mend_raises_hp_in_the_rules() -> void:
	var pattern := RegEx.create_from_string("(?m)^[^#\\n]*\\.hp\\s*\\+=")
	for path: String in _scripts(ROOT):
		if path.ends_with("/mend.gd"):
			continue
		var source := FileAccess.get_file_as_string(path)
		assert_true(pattern.search(source) == null, "%s が HP を直に増やしている（Mend.give を通す）" % path)


func _scripts(dir_path: String) -> Array[String]:
	var found: Array[String] = []
	for sub in DirAccess.get_directories_at(dir_path):
		found.append_array(_scripts(dir_path.path_join(sub)))
	for file in DirAccess.get_files_at(dir_path):
		if file.ends_with(".gd"):
			found.append(dir_path.path_join(file))
	return found
