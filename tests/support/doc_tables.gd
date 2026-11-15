extends RefCounted
## docs/ の Markdown の表を読む（tests/docs/test_doc_values.gd が、表の調整値をコードと突き合わせるのに使う）。
##
## 文書の側に機械のための印は要らない。ふつうの表（| 見出し | ... |、次の行が | --- | ...）をそのまま読む。

## 表 1 つ。
class Table:
	extends RefCounted
	## 文書のパス（res://docs/...）と、表の見出しの行の番号（1 から）。
	var path := ""
	var line := 0
	## 表のすぐ上にある、いちばん近い節の見出し（# を除いたもの）。
	var section := ""
	var headers: PackedStringArray = []
	var rows: Array[PackedStringArray] = []

	## 列の番号。見出しが name と一致する列、無ければ -1。
	func column(name: String) -> int:
		return headers.find(name)

	## 列 key_column（既定は先頭）が key と一致する最初の行。無ければ空。
	func row(key: String, key_column := 0) -> PackedStringArray:
		for cells: PackedStringArray in rows:
			if key_column < cells.size() and cells[key_column] == key:
				return cells
		return PackedStringArray()

	## 失敗の報告に使う、表の場所。
	func where() -> String:
		return "%s:%d（「%s」の表）" % [path.trim_prefix("res://"), line, section]


## path の文書にある表を、上から順に返す。
static func read(path: String) -> Array[Table]:
	var tables: Array[Table] = []
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return tables
	var lines := text.split("\n")
	var section := ""
	var current: Table = null
	var index := 0
	while index < lines.size():
		var line := lines[index].strip_edges()
		if line.begins_with("#"):
			section = line.lstrip("#").strip_edges()
		if current != null:
			if line.begins_with("|"):
				current.rows.append(_cells(line))
				index += 1
				continue
			current = null
		if line.begins_with("|") and index + 1 < lines.size() and lines[index + 1].strip_edges().begins_with("| ---"):
			current = Table.new()
			current.path = path
			current.line = index + 1
			current.section = section
			current.headers = _cells(line)
			tables.append(current)
			index += 2
			continue
		index += 1
	return tables


## docs/ の下の文書（.md）のパスを、すべて返す。
static func documents(dir_path := "res://docs") -> Array[String]:
	var found: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return found
	for file: String in dir.get_files():
		if file.ends_with(".md"):
			found.append(dir_path.path_join(file))
	for sub: String in dir.get_directories():
		found.append_array(documents(dir_path.path_join(sub)))
	return found


## text の中の数を、前から順に返す（+5、−1、0.5、200% の 200 など）。
static func numbers(text: String) -> Array[float]:
	var found: Array[float] = []
	var regex := RegEx.create_from_string("[+\\-−]?\\d+(?:\\.\\d+)?")
	for match: RegExMatch in regex.search_all(text):
		found.append(float(match.get_string().replace("−", "-").replace("+", "")))
	return found


## text の中の、`` で囲んだ部分を前から順に返す。
static func code_spans(text: String) -> Array[String]:
	var found: Array[String] = []
	var regex := RegEx.create_from_string("`([^`]+)`")
	for match: RegExMatch in regex.search_all(text):
		found.append(match.get_string(1))
	return found


static func _cells(line: String) -> PackedStringArray:
	var inner := line.strip_edges().trim_prefix("|").trim_suffix("|")
	var cells := PackedStringArray()
	for cell: String in inner.split("|"):
		cells.append(cell.strip_edges())
	return cells
