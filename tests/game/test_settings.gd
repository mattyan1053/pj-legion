extends "res://tests/base_test.gd"
## 遊ぶ人ごとの設定（game/settings.gd）と、取っておく仕組み（game/save_store.gd）。
## ファイルは user:// の下の、テストだけのディレクトリに書き、終わったら消す。

const Settings := preload("res://game/settings.gd")
const SaveStore := preload("res://game/save_store.gd")

const SENSITIVITY := Settings.MOUSE_SENSITIVITY
const INVERT := Settings.INVERT_VERTICAL_DRAG
const SPEED := Settings.CPU_PLAYBACK_SPEED


func _store() -> SaveStore:
	var dir := "user://test_settings_%d" % (Time.get_ticks_usec() + randi())
	return SaveStore.new(dir)


func _clean(store: SaveStore) -> void:
	for file in DirAccess.get_files_at(store.dir):
		DirAccess.remove_absolute(store.dir.path_join(file))
	DirAccess.remove_absolute(store.dir)


func _write_raw(store: SaveStore, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(store.dir)
	var file := FileAccess.open(store.path_of(Settings.STORE_NAME), FileAccess.WRITE)
	file.store_string(text)
	file.close()


func test_starts_with_the_defaults() -> void:
	var settings := Settings.new()
	for key in Settings.keys():
		assert_eq(settings.value(key), settings.default_value(key), String(key))
		assert_true(settings.is_default(key), String(key))
	assert_eq(settings.value(SENSITIVITY), 100, "感度の既定は 100%（OrbitCamera.DEFAULT_DRAG_SENSITIVITY のまま）")


func test_every_item_is_well_formed() -> void:
	# 画面（settings_panel.gd）は ITEMS だけを見て行を作るので、項目の形がそろっていること。
	var seen := {}
	for entry in Settings.ITEMS:
		var key: StringName = entry["key"]
		assert_false(seen.has(key), "名前が重なっている: %s" % key)
		seen[key] = true
		for field: String in ["section", "label", "note", "kind", "default"]:
			assert_true(entry.has(field), "%s に %s が無い" % [key, field])
		assert_eq(Settings.normalize(entry, entry["default"]), entry["default"], "%s の既定の値が、入れられる値でない" % key)
		if entry["kind"] == Settings.Kind.SLIDER:
			assert_true(entry["min"] < entry["max"] and entry["step"] > 0, String(key))


func test_slider_values_are_clamped_and_snapped() -> void:
	var settings := Settings.new()
	settings.set_value(SENSITIVITY, 1000)
	assert_eq(settings.value(SENSITIVITY), 300, "上限に収まらない")
	settings.set_value(SENSITIVITY, -5)
	assert_eq(settings.value(SENSITIVITY), 25, "下限に収まらない")
	settings.set_value(SENSITIVITY, 147.0)
	assert_eq(settings.value(SENSITIVITY), 145, "刻み（5）にそろわない")
	assert_eq(typeof(settings.value(SENSITIVITY)), TYPE_INT, "スライダーの値は整数で持つ")
	settings.set_value(SENSITIVITY, "fast")
	assert_eq(settings.value(SENSITIVITY), 145, "型の違う値で変わった")


func test_toggle_and_choice_reject_wrong_values() -> void:
	var settings := Settings.new()
	settings.set_value(INVERT, 1)
	assert_eq(settings.value(INVERT), false, "オン・オフに数が入った")
	settings.set_value(INVERT, true)
	assert_eq(settings.value(INVERT), true)
	settings.set_value(SPEED, 7)
	assert_eq(settings.value(SPEED), 1, "選択肢に無い値が入った")
	settings.set_value(SPEED, 2.0)
	assert_eq(settings.value(SPEED), 2, "JSON から来た小数の 2.0 を、選択肢の 2 と見なさない")


func test_changes_are_announced_once() -> void:
	var settings := Settings.new()
	var heard: Array[StringName] = []
	settings.changed.connect(func(key: StringName) -> void: heard.append(key))
	settings.set_value(SENSITIVITY, 150)
	settings.set_value(SENSITIVITY, 150)
	assert_eq(heard, [SENSITIVITY] as Array[StringName], "同じ値でも知らせた")
	settings.reset(SENSITIVITY)
	assert_eq(settings.value(SENSITIVITY), 100, "既定に戻らない")
	settings.set_value(INVERT, true)
	settings.set_value(SPEED, 3)
	heard.clear()
	settings.reset_all()
	assert_eq(heard, [INVERT, SPEED] as Array[StringName], "既定のままの項目まで知らせた、か、知らせ漏れた")


func test_saved_settings_come_back() -> void:
	var store := _store()
	var settings := Settings.new()
	settings.store = store
	settings.set_value(SENSITIVITY, 175)
	settings.set_value(INVERT, true)
	settings.set_value(SPEED, 3)
	assert_true(settings.save(), "書けない")
	assert_false(FileAccess.file_exists(store.path_of(Settings.STORE_NAME) + ".tmp"), "一時のファイルが残った")
	var loaded := Settings.new()
	loaded.store = store
	loaded.load_saved()
	assert_eq(loaded.to_dict(), settings.to_dict(), "読み直すと違う")
	var saved := store.read(Settings.STORE_NAME)
	assert_eq(saved.get("version"), Settings.FORMAT_VERSION, "形の版が書かれていない")
	_clean(store)


func test_missing_or_broken_files_give_the_defaults() -> void:
	var store := _store()
	var settings := Settings.new()
	settings.store = store
	settings.load_saved()
	assert_eq(settings.to_dict(), Settings.new().to_dict(), "ファイルが無いのに、既定でない")
	for text: String in ["", "{ not json", "[1, 2, 3]", "{\"version\": 1}", "{\"version\": \"one\", \"data\": {}}", "{\"version\": 1, \"data\": [1]}"]:
		_write_raw(store, text)
		settings.set_value(SENSITIVITY, 200)
		settings.load_saved()
		# 読めないファイルは「無い」とみなす（いまの値を変えない。起動したばかりなら既定の値のまま）。
		assert_eq(settings.value(SENSITIVITY), 200, "読めないファイル %s で、値が変わった" % text)
	_clean(store)


func test_bad_values_in_a_readable_file_fall_back() -> void:
	var store := _store()
	_write_raw(store, JSON.stringify({"version": 1, "data": {
		"mouse_sensitivity": 9999, "invert_vertical_drag": "yes", "cpu_playback_speed": 2, "volume": 50,
	}}))
	var settings := Settings.new()
	settings.store = store
	settings.load_saved()
	assert_eq(settings.value(SENSITIVITY), 300, "範囲の外の値を、範囲に収めない")
	assert_eq(settings.value(INVERT), false, "型の違う値を、既定に戻さない")
	assert_eq(settings.value(SPEED), 2, "正しい値まで捨てた")
	assert_false(settings.to_dict().has("volume"), "知らない項目を持ち込んだ")
	_clean(store)


func test_older_or_newer_files_keep_the_known_items() -> void:
	# 項目が足りない古いファイル、版が新しいファイルでも、知っている項目は読む（足りない項目は既定の値）。
	var store := _store()
	_write_raw(store, JSON.stringify({"version": 99, "data": {"mouse_sensitivity": 60}}))
	var settings := Settings.new()
	settings.store = store
	settings.set_value(SPEED, 3)
	settings.load_saved()
	assert_eq(settings.value(SENSITIVITY), 60, "知っている項目を読まない")
	assert_eq(settings.value(SPEED), 1, "ファイルに無い項目が、既定の値にならない")
	# 新しい版のファイルの、知らない項目と版は、書き戻しても落とさない（save_format.gd）。
	_write_raw(store, JSON.stringify({"version": 99, "data": {"mouse_sensitivity": 60, "future_item": "on"}}))
	settings.load_saved()
	settings.set_value(SPEED, 3)
	assert_true(settings.save())
	var saved: Dictionary = store.read(Settings.STORE_NAME)
	assert_eq(saved["version"], 99, "版を下げない")
	assert_eq(saved["data"]["future_item"], "on", "知らない項目を落とさない")
	assert_eq(saved["data"][String(SPEED)], 3)
	_clean(store)


func test_store_keeps_separate_collections() -> void:
	# 設定のほかのまとまり（後で部隊編成など）も、名前を変えて同じ仕組みで置ける。
	var store := _store()
	assert_true(store.write("settings", 1, {"a": 1}))
	assert_true(store.write("decks", 3, {"list": [{"name": "x"}]}))
	assert_eq(store.read("settings"), {"version": 1, "data": {"a": 1.0}})
	assert_eq(store.read("decks")["version"], 3)
	assert_eq(store.read("decks")["data"]["list"][0]["name"], "x")
	assert_eq(store.read("nothing"), {}, "無いまとまりは空")
	assert_eq(store.read("../escape"), {}, "名前に使えない文字を通した")
	store.remove("decks")
	assert_eq(store.read("decks"), {}, "消せない")
	_clean(store)
