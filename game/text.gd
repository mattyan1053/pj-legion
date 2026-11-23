extends RefCounted
## 画面の文の表（docs/text.md）を引く。ノードに依存しない（ルールの外の、画面・道具・テストから使う）。
##
## 文は game/text/*.csv（1 行目が keys,ja、そのあと 1 行に「鍵,文」）にある。日本語 1 つだけで、文を 1 か所で読んで直すための表。
## 数や名前を差し込む文は、名前つきの差し込み（{name}）で書き、t の args で渡す（語順は表の側で決める）。
## 表に無い鍵は、鍵そのものが返る（tests/game/test_text.gd が、コードの鍵が表にあることを確かめる）。
##
## 表は、最初に引くときに、DIR の CSV をすべて自分で読む。Godot の翻訳の取り込み（csv_translation）には乗せない
## （取り込みが CSV を並べて取り込むところで、Godot ごと落ちることがあったため。docs/text.md）。
## CSV の .import は importer="keep"（取り込まず、書き出しにそのまま入れる）。

## 表を置く所。
const DIR := "res://game/text/"

## 鍵 -> 文。最初に引くときに読む。
static var _table := {}
static var _loaded := false
## どの文にも差し込める値（名前 -> 値。args に同じ名前があれば args が勝つ）。
## 表の「default.<名前>」の鍵が既定の値（いまは default.boss = 中ボスの名前「番人」）。対戦の画面が、対戦ごとに入れ替える（names.gd の set_boss）。
static var shared := {}


## 鍵 key の文。args（と shared）があれば、文の {名前} に差し込む。
static func t(key: String, args: Dictionary = {}) -> String:
	_load()
	var text: String = _table.get(key, key)
	if not text.contains("{"):
		return text
	return text.format(shared.merged(args, true))


## 鍵 key が表にあるか。
static func has(key: String) -> bool:
	_load()
	return _table.has(key)


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	for file: String in DirAccess.get_files_at(DIR):
		if file.ends_with(".csv"):
			_read(DIR + file)
	for key: String in _table:
		if key.begins_with("default.") and not shared.has(key.trim_prefix("default.")):
			shared[key.trim_prefix("default.")] = _table[key]


## CSV を 1 つ読んで、表に足す（1 行目は見出し。文の中の \n は改行にする）。
static func _read(path: String) -> void:
	var csv := FileAccess.open(path, FileAccess.READ)
	if csv == null:
		push_error("text: %s を開けない" % path)
		return
	csv.get_csv_line()
	while not csv.eof_reached():
		var row := csv.get_csv_line()
		if row.size() >= 2 and row[0] != "":
			_table[row[0]] = row[1].c_unescape()


## 括弧で囲む（「（…）」。表の common.paren）。
static func paren(text: String) -> String:
	return t("common.paren", {"text": text})


## 注の並び（「（巡航・ポータル経由）」）。無ければ空。
static func notes(parts: Array) -> String:
	return "" if parts.is_empty() else paren(join_dot(parts))


## 「・」でつなぐ（表の common.joiner.dot）。
static func join_dot(parts: Array) -> String:
	return t("common.joiner.dot").join(PackedStringArray(parts))


## 「、」でつなぐ（表の common.joiner.comma）。
static func join_comma(parts: Array) -> String:
	return t("common.joiner.comma").join(PackedStringArray(parts))
