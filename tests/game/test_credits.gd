extends "res://tests/base_test.gd"
## クレジット（docs/credits.md）: 表（game/credits.csv）が素材の記録と合うこと、窓と書き出しの文書が同じ表から作られること、窓の大きさ。

const Credits := preload("res://game/credits.gd")
const CreditsPanel := preload("res://game/credits_panel.gd")
const CreditsExport := preload("res://addons/credits_export/export_plugin.gd")
const OverlayStack := preload("res://game/overlay_stack.gd")


func test_every_row_is_complete_and_points_at_a_license_text() -> void:
	var rows := Credits.rows()
	assert_true(rows.size() > 0, "表が読めない")
	for row in rows:
		for column in Credits.COLUMNS:
			assert_ne(row.get(column, ""), "", "%s の %s が空" % [row.get("name", "?"), column])
		assert_true(Credits.GROUPS.has(row["group"]), "知らない種類: %s" % row["group"])
		assert_true(FileAccess.file_exists("res://" + row["license_file"]), "ライセンスの文が無い: %s" % row["license_file"])
		assert_true(row["source"].begins_with("https://"), "出どころが URL でない: %s" % row["source"])


## assets/ のライセンスの文（LICENSE*）は、どれも表のどこかの行が指している（入れた素材が表から漏れない）。
## スクリプトで作った素材（assets/unit_icons/。元の素材と同じ CC0）は、作者のいる素材ではないので除く。
func test_every_license_in_assets_is_in_the_table() -> void:
	var listed := Credits.license_files()
	for path in _licenses("res://assets"):
		if path.begins_with("assets/unit_icons/"):
			continue
		assert_true(listed.has(path), "クレジットの表に載っていない素材のライセンス: %s" % path)


## 文の同梱を求めるライセンス（SIL OFL）の素材は、窓にライセンスの文がそのまま載る。書き出しにも含める（export_presets.cfg）。
func test_ofl_text_is_shown_and_exported() -> void:
	var panel := CreditsPanel.new()
	panel.setup(OverlayStack.new())
	var shown := "\n".join(panel.shown_lines())
	for row in Credits.rows():
		assert_true(shown.contains(row["name"]) and shown.contains(row["author"]), "窓に無い素材: %s" % row["name"])
		if CreditsPanel.SHOWN_LICENSES.has(row["license"]):
			var text := FileAccess.get_file_as_string("res://" + row["license_file"])
			assert_true(text.length() > 100 and shown.contains(text), "ライセンスの文が窓に無い: %s" % row["license_file"])
	panel.free()
	var presets := ConfigFile.new()
	assert_eq(presets.load("res://export_presets.cfg"), OK)
	var include: String = presets.get_value("preset.0", "include_filter", "")
	for pattern: String in ["game/credits.csv", "assets/*/*/LICENSE*"]:
		assert_true(include.contains(pattern), "書き出しに %s が入らない: %s" % [pattern, include])


## 書き出しに添える文書（CREDITS.txt）と licenses/ を、表から書ける。
func test_the_export_writes_credits_and_licenses_beside_the_exe() -> void:
	var dir := "user://test_credits_%d" % randi()
	DirAccess.make_dir_recursive_absolute(dir)
	assert_true(CreditsExport.write_beside(ProjectSettings.globalize_path(dir)))
	var text := FileAccess.get_file_as_string(dir.path_join("CREDITS.txt"))
	for row in Credits.rows():
		assert_true(text.contains(row["name"]) and text.contains(row["source"]), "CREDITS.txt に無い: %s" % row["name"])
	for path in Credits.license_files():
		assert_true(FileAccess.file_exists(dir.path_join("licenses").path_join(Credits.license_copy_name(path))), "licenses/ に無い: %s" % path)


## 窓は決まった大きさで、中身は送れる（どの画面の大きさでも、論理の 1280×720 に収まる）。
func test_the_window_keeps_its_size_and_scrolls() -> void:
	var panel := CreditsPanel.new()
	panel.setup(OverlayStack.new())
	await settle(panel)
	panel.open_credits()
	await settle(panel)
	var board: Control = panel.get_child(1).get_child(0)
	assert_eq(board.size, CreditsPanel.SIZE, "窓の大きさが中身で変わる")
	assert_true(panel.scroll_room() > 0, "中身が窓の中で送れない")
	panel.free()


func _licenses(root: String) -> Array[String]:
	var found: Array[String] = []
	for file in DirAccess.get_files_at(root):
		if file.begins_with("LICENSE") and not file.ends_with(".import"):
			found.append(root.trim_prefix("res://").path_join(file))
	for sub in DirAccess.get_directories_at(root):
		found.append_array(_licenses(root.path_join(sub)))
	return found
