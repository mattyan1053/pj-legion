extends RefCounted
## 手で作ったマップ（docs/hand-map.md）を、名前（id）で引く。game/maps/ の 1 ファイルが 1 マップ（ファイルの名前が id）。ノードに依存しない。
## 話のファイル（episode.gd）は map = <id> で、対戦モードの盤の一覧（versus_fields.gd）は id で指す。
##
## ファイルの書式は話のファイルと同じ（story_file.gd）: [map] に title と look（見た目。stage_look.gd の名前）、
## [rows] に文字の格子（1 文字 1 マス。この節の中では # も障害物の文字）。
## ルール（rules/）はファイルを読まない。ここで読んだ HandMap を、戦いの定義（Scenario.on_map）に渡す。

const StoryFile := preload("res://game/story_file.gd")
const StageLook := preload("res://game/stage_look.gd")

## マップを置く所（ファイルの名前が id）。
const DIR := "res://game/maps/"

## 読んだマップ（id -> find の返すもの）。マップは読むだけなので、1 度読めば使い回す。
static var _cache := {}


## id のマップ: {"map": HandMap, "title": 名前, "look": 見た目の名前（stage_look.gd）, "problems": 書き間違い（「ファイル:行: …」の文）}。ファイルが無ければ空。
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
	var values: Dictionary = file.values("map", ["title", "look"])
	var title := ""
	if values.has("title"):
		title = values["title"][0]["value"]
	if title == "":
		file.problem(maxi(file.line_of("map"), 1), "[map] に title が無い")
	# 見た目（景色）。マップが決める。書かなければ既定の見た目。
	var look := StageLook.DEFAULT
	if values.has("look"):
		var entry: Dictionary = values["look"][0]
		look = StringName(entry["value"])
		if not StageLook.THEMES.has(look):
			file.problem(entry["line"], "知らない見た目「%s」（書けるのは %s）" % [look, ", ".join(StageLook.THEMES.keys())])
			look = StageLook.DEFAULT
	var rows := PackedStringArray()
	for row: Dictionary in file.rows("rows"):
		rows.append(row["text"])
		if (row["text"] as String).length() != (file.rows("rows")[0]["text"] as String).length():
			file.problem(row["line"], "行の長さ（%d）が、最初の行（%d）と違う" % [(row["text"] as String).length(), (file.rows("rows")[0]["text"] as String).length()])
	var map := HandMap.new(rows)
	if rows.is_empty():
		file.problem(maxi(file.line_of("rows"), 1), "[rows] に文字の格子が無い")
	else:
		var row_lines: Array[int] = []
		for row: Dictionary in file.rows("rows"):
			row_lines.append(row["line"])
		for problem: HandMap.Problem in map.problems():
			match problem:
				HandMap.Problem.STRONGHOLD_COUNT:
					# 2 つ目の H のある行で言う。
					var seen := 0
					for k in rows.size():
						seen += rows[k].count(HandMap.STRONGHOLD)
						if seen >= 2:
							file.problem(row_lines[k], "拠点の場所（%s）が 2 つ以上ある（1 つだけ書ける）" % HandMap.STRONGHOLD)
							break
				HandMap.Problem.STRONGHOLD_UNUSABLE:
					var site := map.stronghold_site()
					file.problem(row_lines[site.y], "拠点の場所（%s。%d 列目）に拠点を置けない（中ボスから %d マス以内か、どちらかの本陣から歩いて行けない）" % [
						HandMap.STRONGHOLD, site.x + 1, Stronghold.BOSS_CLEARANCE])
				_:
					file.problem(file.line_of("rows"), "盤にできない: %s（docs/hand-map.md）" % HandMap.Problem.keys()[problem].to_lower())
	return {"map": map, "title": title, "look": look, "problems": file.problems}


## game/maps/ のマップの id の並び（ファイルの名前の順）。
static func ids() -> PackedStringArray:
	var found := PackedStringArray()
	for file: String in DirAccess.get_files_at(DIR):
		if file.ends_with(".txt"):
			found.append(file.get_basename())
	return found
