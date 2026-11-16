extends RefCounted
## 話と物語のファイル（game/story/。docs/story.md の「話のファイル」）の書式を読む。中身の意味は読まない（episode.gd、campaign.gd が読む）。
## ノードに依存しない。
##
## 書式:
## - 1 行ずつ読む。空の行と、行頭（空白のあと）が # の行は読み飛ばす。
## - 「[名前]」の行で節を始める。最初の節より前に、ほかの行は書けない。同じ節を 2 度は書けない。
## - 節の中の行は、そのまま（前後の空白を除いて）持つ。読み方は節の種類で違う:
##   - 値の節（values）: 「キー = 値」。同じキーを何行も書くと、その順の列になる（列にしてよいキーだけ）。
##   - 文の節（rows）: 1 行が 1 つ（会話の行、話の id の行など）。
##   - そのままの節（open・parse の raw に名前を渡す。マップの文字の格子）: # で始まる行も読み飛ばさない（# は障害物の文字）。空の行だけ読み飛ばす。
## - 書き間違いは「ファイル:行: 何がおかしいか」の文にして problems に貯める（読み込みを止めない）。

## ファイルのパス（書き間違いの文の頭に付ける）。
var path := ""
## 節の名前 -> {"line": 見出しの行, "rows": [{"line": 行, "text": 文}, …]}。
var sections := {}
## 書き間違い（空なら正しい）。
var problems: PackedStringArray = []


## path のファイルを読む。読めなければ problems に書く。
static func open(file_path: String, raw: Array = []) -> RefCounted:
	var text := FileAccess.get_file_as_string(file_path)
	if text == "" and FileAccess.get_open_error() != OK:
		var failed: RefCounted = new()
		failed.path = file_path
		failed.problems.append("%s: 読めない（%s）" % [file_path, error_string(FileAccess.get_open_error())])
		return failed
	return parse(text, file_path, raw)


## 文 text を、ファイル file_path の中身として読む（テストは、わざと壊した文を渡す）。
## raw: そのままの節の名前（# で始まる行を、その節の行として読む）。
static func parse(text: String, file_path := "", raw: Array = []) -> RefCounted:
	var file: RefCounted = new()
	file.path = file_path
	var current := ""
	var number := 0
	for source_line: String in text.split("\n"):
		number += 1
		var line := source_line.strip_edges()
		if line == "" or (line.begins_with("#") and not raw.has(current)):
			continue
		if line.begins_with("[") and line.ends_with("]"):
			current = line.substr(1, line.length() - 2).strip_edges()
			if file.sections.has(current):
				file.problem(number, "節 [%s] が 2 度ある（%d 行目にもある）" % [current, file.sections[current]["line"]])
			else:
				file.sections[current] = {"line": number, "rows": []}
			continue
		if current == "":
			file.problem(number, "節（[名前] の行）より前に書いてある: %s" % line)
			continue
		file.sections[current]["rows"].append({"line": number, "text": line})
	return file


## 行 line の書き間違いを貯める。
func problem(line: int, message: String) -> void:
	problems.append("%s:%d: %s" % [path, line, message])


## 知らない節があれば、書き間違いにする（known: 書いてよい節の名前）。
func check_sections(known: Array) -> void:
	for name: String in sections:
		if not known.has(name):
			problem(sections[name]["line"], "知らない節 [%s]（書けるのは %s）" % [name, ", ".join(known.map(func(each: String) -> String: return "[%s]" % each))])


func has(name: String) -> bool:
	return sections.has(name)


## 節 name の見出しの行（無ければ 0）。
func line_of(name: String) -> int:
	return sections[name]["line"] if sections.has(name) else 0


## 文の節 name の行（[{"line": 行, "text": 文}, …]。節が無ければ空）。
func rows(name: String) -> Array:
	return sections[name]["rows"] if sections.has(name) else []


## 値の節 name を読む: キー -> [{"line": 行, "value": 値の文}, …]（書いた順）。
## keys: 書いてよいキー。lists: 何行も書いてよいキー。知らないキー・「=」の無い行・列でないキーの重なりは、書き間違いにする。
func values(name: String, keys: Array, lists: Array = []) -> Dictionary:
	var found := {}
	for row: Dictionary in rows(name):
		var text: String = row["text"]
		var at := text.find("=")
		if at < 0:
			problem(row["line"], "「キー = 値」の形でない: %s" % text)
			continue
		var key := text.substr(0, at).strip_edges()
		var value := text.substr(at + 1).strip_edges()
		if not keys.has(key):
			problem(row["line"], "[%s] の知らないキー「%s」（書けるのは %s）" % [name, key, ", ".join(keys)])
			continue
		if found.has(key) and not lists.has(key):
			problem(row["line"], "「%s」が 2 度ある（%d 行目にもある）" % [key, found[key][0]["line"]])
			continue
		if not found.has(key):
			found[key] = []
		found[key].append({"line": row["line"], "value": value})
	return found


# ---- 値の読み方（書き間違いは、その行の problem にする） ----


## 列挙の名前（小文字。UnitKind.Id の SHIELD_TROOPER なら shield_trooper）を値に直す。知らない名前なら -1。
static func enum_value(names: Dictionary, word: String) -> int:
	var upper := word.strip_edges().to_upper()
	return names[upper] if names.has(upper) else -1


## 列挙 names の、書ける名前の並び（小文字。書き間違いの文に出す）。
static func enum_words(names: Dictionary, skip: Array = []) -> String:
	var words: PackedStringArray = []
	for name: String in names:
		if not skip.has(names[name]):
			words.append(name.to_lower())
	return ", ".join(words)


## 整数の文を読む。読めなければ problem にして fallback。
func integer(entry: Dictionary, fallback := 0) -> int:
	var text: String = entry["value"]
	if not text.is_valid_int():
		problem(entry["line"], "整数でない: %s" % text)
		return fallback
	return text.to_int()


## マスの列（「8,9  5,9  11,9」。x,y を空白で区切る）を読む。
func cells(entry: Dictionary) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	for word: String in (entry["value"] as String).split(" ", false):
		var parts := word.split(",")
		if parts.size() != 2 or not parts[0].strip_edges().is_valid_int() or not parts[1].strip_edges().is_valid_int():
			problem(entry["line"], "マスは「x,y」（空白で区切る）: %s" % word)
			continue
		found.append(Vector2i(parts[0].to_int(), parts[1].to_int()))
	return found
