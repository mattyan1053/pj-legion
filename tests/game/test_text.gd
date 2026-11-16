extends "res://tests/base_test.gd"
## 画面の文の表（game/text/*.csv。docs/text.md）と、コードの文の見張り。
## - コードが引く鍵（Text.t("…") の文字の鍵）は、どれも表にある。
## - 表の鍵は、どれもコードから引かれる（文字の鍵か、names.gd が列挙から作る鍵）。
## - 表に無い直書きの日本語が、ルールと画面のコードに増えていない（まだ表へ移していないファイルは、いまの数まで許す）。

const Text := preload("res://game/text.gd")
const Names := preload("res://game/names.gd")
const TEXT_DIR := "res://game/text/"
## 見張るコード。
const CODE_DIRS := ["res://game/", "res://rules/"]
## 直書きの日本語を見ないファイル（画面に出さない文だけを持つもの）。
const NOT_SHOWN := [
	"res://game/autoplay.gd",  # 自動の対戦が、くい違いを知らせる文（開発用）
	"res://game/story_file.gd",  # 話・物語・マップのファイルの書き間違いの文（開発用。ファイルを書く人が読む）
	"res://game/episode.gd",
	"res://game/campaign.gd",
	"res://game/maps.gd",
]
## まだ表へ移していないファイルと、そこに残っている直書きの日本語の数（これより増えたら落ちる）。移したら行を消す。
const PENDING := {
	"res://game/app.gd": 7,
	"res://game/battle_effects.gd": 1,
	"res://game/battle_hud.gd": 60,
	"res://game/battle_log.gd": 85,
	"res://game/battle_playback.gd": 27,
	"res://game/battle_screen.gd": 22,
	"res://game/battle_texts.gd": 80,
	"res://game/campaign_list_screen.gd": 9,
	"res://game/deck_library.gd": 13,
	"res://game/deck_preview.gd": 2,
	"res://game/deck_screen.gd": 66,
	"res://game/deck_text.gd": 21,
	"res://game/episode_list_screen.gd": 15,
	"res://game/forecast_panel.gd": 12,
	"res://game/forecast_text.gd": 26,
	"res://game/log_panel.gd": 3,
	"res://game/match_choice.gd": 1,
	"res://game/match_setup_panel.gd": 30,
	"res://game/minimap.gd": 1,
	"res://game/relic_icon.gd": 3,
	"res://game/result_screen.gd": 17,
	"res://game/result_summary.gd": 12,
	"res://game/settings.gd": 32,
	"res://game/settings_panel.gd": 6,
	"res://game/setup_screen.gd": 2,
	"res://game/sortie_screen.gd": 18,
	"res://game/stage_select_screen.gd": 10,
	"res://game/stats_text.gd": 36,
	"res://game/story.gd": 4,
	"res://game/system_menu.gd": 4,
	"res://game/talk_screen.gd": 3,
	"res://game/text_wrap.gd": 5,
	"res://game/title_screen.gd": 6,
	"res://game/unit_card.gd": 2,
	"res://game/versus_fields.gd": 12,
	"res://game/win_text.gd": 28,
}
## names.gd が列挙から作る鍵の頭と、その列挙（表の鍵が、どれかの列挙の値に当たること）。
const FAMILIES := {
	"side": [Unit.Side, ["", ".short"]],
	"army": [UnitKind.Army, [""]],
	"role": [UnitKind.Role, [""]],
	"stat": [Unit.Stat, [""]],
	"trait": [Evolution.Trait, [""]],
	"field_effect": [FieldEffect.Type, [""]],
	"unit": [UnitKind.Id, [""]],
	"evolution": [Evolution.Id, [""]],
	"item": [Equipment.Id, [""]],
	"skill": [Skill.Id, ["", ".summary"]],
	"ult": [Ult.Id, ["", ".summary"]],
	"status": [Status.Type, [""]],
	"relic": [Relics.Id, ["", ".summary"]],
	"stage": [BoardGenerator.Stage, [""]],
}


## 表の鍵（ファイルの名前 -> 鍵の列）。
func _table() -> Dictionary:
	var found := {}
	for file: String in DirAccess.get_files_at(TEXT_DIR):
		if not file.ends_with(".csv"):
			continue
		var keys: Array[String] = []
		var csv := FileAccess.open(TEXT_DIR + file, FileAccess.READ)
		var header := csv.get_csv_line()
		assert_eq(Array(header), ["keys", "ja"], "%s の 1 行目" % file)
		while not csv.eof_reached():
			var row := csv.get_csv_line()
			if row.size() >= 1 and row[0] != "":
				assert_eq(row.size(), 2, "%s の %s: 列が 2 つでない（文の中の , は \"\" で囲む）" % [file, row[0]])
				keys.append(row[0])
		found[file] = keys
	return found


## コードのファイル（res:// のパス）の並び。
func _code_files() -> Array[String]:
	var files: Array[String] = []
	var dirs: Array[String] = []
	dirs.assign(CODE_DIRS)
	while not dirs.is_empty():
		var dir: String = dirs.pop_back()
		for sub: String in DirAccess.get_directories_at(dir):
			dirs.append(dir + sub + "/")
		for file: String in DirAccess.get_files_at(dir):
			if file.ends_with(".gd"):
				files.append(dir + file)
	return files


## コードが文字で書いた鍵（Text.t("鍵"）。
func _literal_keys() -> Dictionary:
	var keys := {}
	var pattern := RegEx.create_from_string("Text\\.(?:t|has)\\(\"([a-z0-9_]+(?:\\.[a-z0-9_]+)+)\"")
	for file: String in _code_files() + _tool_files():
		for found in pattern.search_all(FileAccess.get_file_as_string(file)):
			keys[found.get_string(1)] = file
	return keys


func _tool_files() -> Array[String]:
	var files: Array[String] = []
	for file: String in DirAccess.get_files_at("res://tools/"):
		if file.ends_with(".gd"):
			files.append("res://tools/" + file)
	return files


func test_the_table_has_unique_keys_with_text() -> void:
	var seen := {}
	for file: String in _table():
		for key: String in _table()[file]:
			assert_false(seen.has(key), "鍵 %s が %s と %s の 2 か所にある" % [key, seen.get(key), file])
			seen[key] = file
			assert_ne(Text.t(key), key, "%s の %s の文が空か、表が読み込まれていない（project.godot の locale/translations）" % [file, key])
	assert_true(seen.size() > 0)


func test_every_key_in_code_is_in_the_table() -> void:
	var keys := _literal_keys()
	for key: String in keys:
		assert_true(Text.has(key), "%s が引く鍵 %s が表に無い" % [keys[key], key])


func test_every_key_in_the_table_is_used() -> void:
	var literal := _literal_keys()
	for file: String in _table():
		for key: String in _table()[file]:
			assert_true(literal.has(key) or _is_family_key(key), "%s の鍵 %s を、どのコードも引いていない" % [file, key])


## names.gd が列挙から作る鍵か（頭.列挙の名前の小文字[.欄]）。
func _is_family_key(key: String) -> bool:
	var parts := key.split(".")
	if not FAMILIES.has(parts[0]) or parts.size() < 2:
		return false
	var names: Dictionary = FAMILIES[parts[0]][0]
	var suffix := "" if parts.size() == 2 else "." + ".".join(parts.slice(2))
	return names.has(parts[1].to_upper()) and (FAMILIES[parts[0]][1] as Array).has(suffix)


## 直書きの日本語（文字の値のうち、かな・漢字・全角の記号を含むもの）を数える。コメントと、開発用の出力の行は数えない。
func _hard_coded(file: String) -> int:
	var count := 0
	var literal := RegEx.create_from_string("\"([^\"\\\\]|\\\\.)*\"")
	var japanese := RegEx.create_from_string("[\\x{3000}-\\x{30ff}\\x{4e00}-\\x{9fff}\\x{ff01}-\\x{ff60}]")
	for line: String in FileAccess.get_file_as_string(file).split("\n"):
		var code := line.strip_edges()
		if code.begins_with("#") or code.begins_with("push_error") or code.begins_with("push_warning") or code.begins_with("printerr") \
				or code.begins_with("print(") or code.begins_with("assert("):
			continue
		var at := code.find("##")
		if at >= 0:
			code = code.substr(0, at)
		for found in literal.search_all(code):
			if japanese.search(found.get_string()) != null:
				count += 1
	return count


func test_no_new_hard_coded_japanese() -> void:
	for file: String in _code_files():
		if NOT_SHOWN.has(file):
			continue
		var count := _hard_coded(file)
		var allowed: int = PENDING.get(file, 0)
		assert_true(count <= allowed, "%s に、表に無い直書きの日本語が %d（許すのは %d）。画面の文は game/text/ の表へ（docs/text.md）" % [file, count, allowed])
		if PENDING.has(file):
			assert_true(count == allowed, "%s の直書きが %d に減った。PENDING を %d に直す（0 なら行を消す）" % [file, count, count])


## 見張りそのものが効くこと。
func test_the_watch_counts_literals_but_not_comments() -> void:
	var probe := "user://text_probe.gd"
	var file := FileAccess.open(probe, FileAccess.WRITE)
	file.store_string("# コメント「無視」\nvar a := \"直書き\"  ## 説明「無視」\npush_error(\"開発用\")\nvar b := \"plain\" + \"、\"\n")
	file.close()
	assert_eq(_hard_coded(probe), 2)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(probe))
