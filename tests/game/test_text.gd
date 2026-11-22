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
	"res://game/steady_probe.gd",  # 枠の見張りが、動いた枠を知らせる文（開発用）
	"res://game/autoplay_sweeps.gd",  # 自動の対戦の通しの点検が、くい違いを知らせる文（開発用）
	"res://game/story_file.gd",  # 話・物語・マップのファイルの書き間違いの文（開発用。ファイルを書く人が読む）
	"res://game/episode.gd",
	"res://game/campaign.gd",
	"res://game/maps.gd",
	"res://game/text_wrap.gd",  # 折り返しの決まり（行頭・行末に置かない文字の並び。画面の文ではない）
]
## まだ表へ移していないファイルと、そこに残っている直書きの日本語の数（これより増えたら落ちる）。移したら行を消す。
const PENDING := {
}
## names.gd が列挙から作る鍵の頭と、その列挙（表の鍵が、どれかの列挙の値に当たること）。
const FAMILIES := {
	"side": [Unit.Side, ["", ".short"]],
	"army": [UnitKind.Army, [""]],
	"role": [UnitKind.Role, ["", ".summary"]],
	"stat": [Unit.Stat, [""]],
	"trait": [Evolution.Trait, ["", ".short"]],
	"field_effect": [FieldEffect.Type, [""]],
	"unit": [UnitKind.Id, [""]],
	"evolution": [Evolution.Id, [""]],
	"item": [Equipment.Id, [""]],
	"skill": [Skill.Id, ["", ".summary"]],
	"ult": [Ult.Id, ["", ".summary"]],
	"status": [Status.Type, ["", ".summary"]],
	"relic": [Relics.Id, ["", ".summary", ".short", ".effect"]],
	"stage": [BoardGenerator.Stage, [""]],
}
## 画面の文のうち、列挙から鍵を作るもの（頭 -> [列挙, 欄]。鍵は「頭.列挙の名前の小文字[.欄]」）。
const SCREEN_FAMILIES := {
	"battle.goal.win": [GameWonEvent.Reason, ["", ".last"]],
	"battle.goal.lose": [GameWonEvent.Reason, ["", ".last"]],
	"stats.ending": [BattleStats.Ending, [""]],
	"side.story": [{"PLAYER1": 0, "PLAYER2": 1}, [""]],
	"setup.trial": [{"BATTERY": 0, "STRONGHOLD": 1}, ["", ".note"]],
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


## コードが文字で書いた鍵。all が偽なら Text.t("鍵") の形だけ、真なら鍵の形の文字の値すべて
## （表の鍵を、いったん定数の表に置いてから Text.t に渡すもの。勝ち方の理由など）。
func _literal_keys(all := false) -> Dictionary:
	var keys := {}
	var head := "\"" if all else "Text\\.(?:t|has)\\(\""
	var pattern := RegEx.create_from_string(head + "([a-z0-9_]+(?:\\.[a-z0-9_]+)+)\"")
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
			assert_ne(Text.t(key), key, "%s の %s の文が空か、表が読み込まれていない" % [file, key])
	assert_true(seen.size() > 0)


## 差し込んだ名前（駒・陣営・スキルなど）と、前後の かな・漢字 の間に空白を置かない（docs/wording.md の 8。「スペルブレード を表示中」にしない）。
## 英字や数で終わりうる名前（軍の名前 {army}・{origin}、部隊の名前 {name}）と、数・マスの座標は見ない。
func test_no_space_between_a_name_and_kana() -> void:
	var names := "unit|attacker|target|healer|other|side|effect|status|enemy|evolution|ult|relic|skill|place|kind|role"
	var after := RegEx.create_from_string("\\{(" + names + ")\\} [\\x{3041}-\\x{30ff}\\x{4e00}-\\x{9fff}]")
	var before := RegEx.create_from_string("[\\x{3041}-\\x{30ff}\\x{4e00}-\\x{9fff}] \\{(" + names + ")\\}")
	for file: String in DirAccess.get_files_at(TEXT_DIR):
		if not file.ends_with(".csv"):
			continue
		var csv := FileAccess.open(TEXT_DIR + file, FileAccess.READ)
		while not csv.eof_reached():
			var row := csv.get_csv_line()
			if row.size() >= 2:
				assert_true(after.search(row[1]) == null and before.search(row[1]) == null, "%s の %s: 名前の前後に空白（%s）" % [file, row[0], row[1]])


## 表の CSV は Godot の翻訳の取り込みに乗せない（取り込みが並べて取り込むところで落ちることがあった。docs/text.md）。
func test_the_tables_are_kept_as_they_are_not_imported() -> void:
	for file: String in _table():
		var settings := ConfigFile.new()
		assert_eq(settings.load(TEXT_DIR + file + ".import"), OK, "%s.import が無い" % file)
		assert_eq(settings.get_value("remap", "importer", ""), "keep", "%s.import の importer が keep でない" % file)


func test_every_key_in_code_is_in_the_table() -> void:
	var keys := _literal_keys()
	for key: String in keys:
		assert_true(Text.has(key), "%s が引く鍵 %s が表に無い" % [keys[key], key])


func test_every_key_in_the_table_is_used() -> void:
	var literal := _literal_keys(true)
	for file: String in _table():
		for key: String in _table()[file]:
			assert_true(literal.has(key) or _is_family_key(key), "%s の鍵 %s を、どのコードも引いていない" % [file, key])


## names.gd や画面が列挙から作る鍵か（頭.列挙の名前の小文字[.欄]）。
func _is_family_key(key: String) -> bool:
	for head: String in SCREEN_FAMILIES:
		if key.begins_with(head + "."):
			var rest := key.trim_prefix(head + ".").split(".")
			var enum_names: Dictionary = SCREEN_FAMILIES[head][0]
			var field := "" if rest.size() == 1 else "." + ".".join(rest.slice(1))
			return enum_names.has(rest[0].to_upper()) and (SCREEN_FAMILIES[head][1] as Array).has(field)
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
	var probe := "user://text_probe_%d.gd" % (Time.get_ticks_usec() + randi())  # 並べて回すプロセスと名前がぶつからないように
	var file := FileAccess.open(probe, FileAccess.WRITE)
	file.store_string("# コメント「無視」\nvar a := \"直書き\"  ## 説明「無視」\npush_error(\"開発用\")\nvar b := \"plain\" + \"、\"\n")
	file.close()
	assert_eq(_hard_coded(probe), 2)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(probe))


## 括弧の中に括弧を入れない（docs/wording.md の 8）。差し込む文が括弧を持つ文（持ち物の効果、聖遺物の効果）で、組み上がった文を見る。
func test_no_brackets_inside_brackets() -> void:
	const DeckText := preload("res://game/deck_text.gd")
	var lines: Array[String] = []
	for item: Equipment.Id in Equipment.Id.values():
		lines.append(Text.t("story.news.item", {"item": Names.item(item), "effect": DeckText.equipment_effect(item)}))
	for relic: Relics.Id in Relics.Id.values():
		for key: String in ["battle.log.relic", "battle.banner.relic", "battle.forecast.relic"]:
			lines.append(Text.t(key, {"side": "青", "relic": Names.relic(relic), "effect": Names.relic_summary(relic)}))
	for line: String in lines:
		var depth := 0
		var deepest := 0
		for letter: String in line:
			depth += 1 if letter == "（" else (-1 if letter == "）" else 0)
			deepest = maxi(deepest, depth)
		assert_true(deepest <= 1, "括弧が二重: %s" % line)
