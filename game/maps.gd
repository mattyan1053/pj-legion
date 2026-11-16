extends RefCounted
## 手で作ったマップ（docs/hand-map.md）を、名前（id）で引く。game/maps/ の 1 ファイルが 1 マップ（ファイルの名前が id）。ノードに依存しない。
## 話のファイル（episode.gd）は map = <id> で、対戦モードの盤の一覧（versus_fields.gd）は id で指す。
##
## ファイルの書式は話のファイルと同じ（story_file.gd）: [map] に title、[rows] に文字の格子（1 文字 1 マス。この節の中では # も障害物の文字）。
## ルール（rules/）はファイルを読まない。ここで読んだ HandMap を、戦いの定義（Scenario.on_map）に渡す。

const StoryFile := preload("res://game/story_file.gd")

## マップを置く所（ファイルの名前が id）。
const DIR := "res://game/maps/"

## 読んだマップ（id -> find の返すもの）。マップは読むだけなので、1 度読めば使い回す。
static var _cache := {}


## id のマップ: {"map": HandMap, "title": 名前, "problems": 書き間違い（「ファイル:行: …」の文）}。ファイルが無ければ空。
static func find(id: String) -> Dictionary:
	if _cache.has(id):
		return _cache[id]
	var file_path := DIR + id + ".txt"
	if id == "" or not id.is_valid_filename() or not FileAccess.file_exists(file_path):
		return {}
	var found := load_file(file_path)
	for problem: String in found["problems"]:
		push_error("マップの書き間違い: " + problem)
	_cache[id] = found
	return found


## マップのファイル file_path を読む（tools/cpu_matches.gd の --map も使う）。
static func load_file(file_path: String) -> Dictionary:
	return read(StoryFile.open(file_path, ["rows"]))


## 文 text を、マップのファイル file_path の中身として読む（テストは、わざと壊した文を渡す）。
static func parse(text: String, file_path := "probe.txt") -> Dictionary:
	return read(StoryFile.parse(text, file_path, ["rows"]))


static func read(file: RefCounted) -> Dictionary:
	file.check_sections(["map", "rows"])
	var values: Dictionary = file.values("map", ["title"])
	var title := ""
	if values.has("title"):
		title = values["title"][0]["value"]
	if title == "":
		file.problem(maxi(file.line_of("map"), 1), "[map] に title が無い")
	var rows := PackedStringArray()
	for row: Dictionary in file.rows("rows"):
		rows.append(row["text"])
		if (row["text"] as String).length() != (file.rows("rows")[0]["text"] as String).length():
			file.problem(row["line"], "行の長さ（%d）が、最初の行（%d）と違う" % [(row["text"] as String).length(), (file.rows("rows")[0]["text"] as String).length()])
	var map := HandMap.new(rows)
	if rows.is_empty():
		file.problem(maxi(file.line_of("rows"), 1), "[rows] に文字の格子が無い")
	else:
		for problem: HandMap.Problem in map.problems():
			file.problem(file.line_of("rows"), "盤にできない: %s（docs/hand-map.md）" % HandMap.Problem.keys()[problem].to_lower())
	return {"map": map, "title": title, "problems": file.problems}


## game/maps/ のマップの id の並び（ファイルの名前の順）。
static func ids() -> PackedStringArray:
	var found := PackedStringArray()
	for file: String in DirAccess.get_files_at(DIR):
		if file.ends_with(".txt"):
			found.append(file.get_basename())
	return found
