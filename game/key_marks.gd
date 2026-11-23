extends HBoxContainer
## 操作の案内の小さな並び: 短い句、キーの印と一語（「右クリック キャンセル」）、色の印と一語（「■ 移動」）。
## 文で操作を教えない（docs/wording.md の決まり 1）。画面の隅に小さく置く。
## 並べるもの（parts）は辞書の列。作るのは phrase・key・swatch（下の static）。

const Palette := preload("res://game/ui_palette.gd")
const UiTheme := preload("res://game/ui_theme.gd")

## 一語の字の大きさ、キーの印の字の大きさ、句の字の大きさ（px）。
const WORD_FONT_SIZE := 13
const KEY_FONT_SIZE := 12
const PHRASE_FONT_SIZE := 15
## 色の印の辺（px）。
const SWATCH_SIDE := 12.0
## 印と一語の間、組と組の間（px）。
const INNER_GAP := 4
const GAP := 12

var _parts: Array = []


## 短い句（「対象を選択」）。
static func phrase(text: String) -> Dictionary:
	return {"phrase": text}


## キーの印と一語（「右クリック」「キャンセル」）。
static func key(key_name: String, word: String) -> Dictionary:
	return {"key": key_name, "word": word}


## 色の印と一語。color は色そのものか、呼ぶ側が色に直す名前（StringName）。framed なら、塗らずに枠だけ。
static func swatch(color: Variant, word: String, framed := false) -> Dictionary:
	return {"swatch": color, "word": word, "framed": framed}


func _init() -> void:
	add_theme_constant_override("separation", GAP)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## 並べるものを替える。空なら何も出さない（高さは、置く側が決めておく）。
func set_parts(parts: Array) -> void:
	_parts = parts
	for child in get_children():
		remove_child(child)
		child.queue_free()
	for part: Dictionary in parts:
		if part.has("phrase"):
			add_child(_text(part["phrase"], PHRASE_FONT_SIZE, Palette.TEXT))
			continue
		var pair := HBoxContainer.new()
		pair.add_theme_constant_override("separation", INNER_GAP)
		pair.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pair.add_child(_key_cap(part["key"]) if part.has("key") else _swatch(part["swatch"], part.get("framed", false)))
		pair.add_child(_text(part["word"], WORD_FONT_SIZE, Palette.TEXT_DIM))
		add_child(pair)


## 並べているものを 1 行の文にしたもの（句はそのまま、キーは [キー] 一語、色の印は * 一語。間は半角の空白 2 つ）。検査用。
func parts_text() -> String:
	var texts: Array[String] = []
	for part: Dictionary in _parts:
		if part.has("phrase"):
			texts.append(part["phrase"])
		elif part.has("key"):
			texts.append("[%s] %s" % [part["key"], part["word"]])
		else:
			texts.append("* %s" % part["word"])
	return "  ".join(texts)


func _text(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## キーの印: 沈んだ地に細い縁の、小さな札。
func _key_cap(key_name: String) -> Control:
	var cap := PanelContainer.new()
	var style := UiTheme.box(Palette.INK, Palette.BORDER, 1, 4, 0.0)
	style.content_margin_left = 5.0
	style.content_margin_right = 5.0
	style.content_margin_top = 0.0
	style.content_margin_bottom = 1.0
	cap.add_theme_stylebox_override("panel", style)
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := _text(key_name, KEY_FONT_SIZE, Palette.TEXT)
	label.add_theme_constant_override("outline_size", 0)
	cap.add_child(label)
	return cap


## 色が名前のまま（呼ぶ側が色に直していない）なら、文字の色で出す。
func _swatch(color: Variant, framed: bool) -> Control:
	var mark := Panel.new()
	var solid := Color(color as Color, 1.0) if color is Color else Palette.TEXT
	mark.add_theme_stylebox_override("panel", UiTheme.box(Color(solid, 0.0) if framed else solid, solid if framed else Palette.OUTLINE, 2 if framed else 1, 2, 0.0))
	mark.custom_minimum_size = Vector2(SWATCH_SIDE, SWATCH_SIDE)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return mark
