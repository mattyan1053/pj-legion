extends "res://tests/base_test.gd"
## 出来事（rules/events/）を種類ごとに読む所の見張り（docs/battle.md の「出来事を 1 つ足すとき」）。
##
## 再生（test_event_playback.gd）とログ（test_battle_log.gd）と同じ作りで、戦績・予測のまとめ・CPU の手の価値・実測の道具・中立の再生の 5 か所を見る。
## どこも「読む出来事」（read_events）と「読まないと決めた出来事」（skipped_events）の表を持つ。
## - 出来事の種類の全部が、どちらか一方に入っていること（親を読めば子も読む）。新しい出来事を足すと、ここで落ちる
## - 読む表が、そのファイルが実際に `is` / `as` で名前を出す出来事と同じであること（表とコードがずれない）

const EVENTS_DIR := "res://rules/events"
const READERS: Array[String] = [
	"res://rules/battle_stats.gd",
	"res://rules/forecast.gd",
	"res://rules/cpu/cpu_outcome_value.gd",
	"res://tools/cpu_match.gd",
	"res://game/neutral_playback.gd",
]


## 出来事の種類（抽象の親を除く）。
func _event_scripts() -> Array[Script]:
	var scripts: Array[Script] = []
	for file in DirAccess.get_files_at(EVENTS_DIR):
		if file.ends_with(".gd"):
			var script: Script = load(EVENTS_DIR.path_join(file))
			if not script.is_abstract():
				scripts.append(script)
	return scripts


## script と、その親の出来事（BattleEvent まで）。
func _lineage(script: Script) -> Array[Script]:
	var result: Array[Script] = []
	var current := script
	while current != null:
		result.append(current)
		current = current.get_base_script()
	return result


## ファイルが `is` / `as` で名前を出す出来事のクラス名。
func _named_in_source(path: String) -> Array[String]:
	var source := FileAccess.get_file_as_string(path)
	var pattern := RegEx.create_from_string("\\b(?:is|as)\\s+([A-Z]\\w*Event)\\b")
	var names: Array[String] = []
	for found in pattern.search_all(source):
		var name := found.get_string(1)
		if not names.has(name):
			names.append(name)
	names.sort()
	return names


func _class_names(scripts: Array) -> Array[String]:
	var names: Array[String] = []
	for script: Script in scripts:
		names.append(String(script.get_global_name()))
	names.sort()
	return names


func test_every_event_is_read_or_skipped_by_each_reader() -> void:
	var events := _event_scripts()
	assert_true(events.size() >= 40, "出来事のスクリプトを見つけられていない")
	for path in READERS:
		var reader: GDScript = load(path)
		var read: Array = reader.call(&"read_events")
		var skipped: Array = reader.call(&"skipped_events")
		var where := path.get_file()
		for script in events:
			var name := String(script.get_global_name())
			var is_read := _lineage(script).any(func(line: Script) -> bool: return read.has(line))
			var is_skipped := skipped.has(script)
			assert_true(is_read or is_skipped, "%s: 出来事 %s を読むか、読まない表に足す（docs/battle.md の「出来事を 1 つ足すとき」）" % [where, name])
			assert_false(is_read and is_skipped, "%s: 出来事 %s が、読む表と読まない表の両方にある" % [where, name])
		for script: Script in skipped:
			assert_true(events.has(script), "%s: 読まない表に、出来事の種類でないものがある: %s" % [where, script.resource_path])
		var unique := {}
		for script: Script in skipped:
			unique[script] = true
		assert_eq(unique.size(), skipped.size(), "%s: 読まない表に同じものが 2 度ある" % where)


func test_the_read_table_matches_the_code() -> void:
	for path in READERS:
		var reader: GDScript = load(path)
		var read: Array = reader.call(&"read_events")
		assert_eq(_class_names(read), _named_in_source(path),
			"%s: 読む表（read_events）が、コードの `is` / `as` と違う" % path.get_file())
