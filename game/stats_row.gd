extends HBoxContainer
## 能力値の並び（「HP 44　攻撃 6　移動 3　射程 1」）を、項目ごとに幅のそろった欄へ分けて出す。
## 名前は補足の色で小さく、数は本文の色で太く。札を縦に並べたとき、数が同じ所にそろって読める。
## 文は渡された 1 行（DeckText.stats_line など）をそのまま使い、全角の空白で項目に、最後の半角の空白で名前と数に分ける
## （分けられない項目は、そのまま出す）。

const Palette := preload("res://game/ui_palette.gd")
const UiTheme := preload("res://game/ui_theme.gd")

var _font_size: int
var _cell_width: float


## cell_width は 1 項目の幅（px。0 なら中身の幅）。
func _init(text := "", font_size := 13, cell_width := 0.0) -> void:
	_font_size = font_size
	_cell_width = cell_width
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 0 if cell_width > 0.0 else 10)
	set_line(text)


## 出している 1 行（検査用）。
func line() -> String:
	return get_meta(&"line", "")


func set_line(text: String) -> void:
	if text == line() and get_child_count() > 0:
		return
	set_meta(&"line", text)
	for child in get_children():
		remove_child(child)
		child.queue_free()
	if text == "":
		return
	for part: String in text.split(char(0x3000), false):
		var cell := HBoxContainer.new()
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_theme_constant_override("separation", 4)
		cell.custom_minimum_size = Vector2(_cell_width, 0.0)
		add_child(cell)
		var cut := part.rfind(" ")
		if cut <= 0:
			cell.add_child(_label(part, Palette.TEXT, false))
			continue
		var name_label := _label(part.substr(0, cut), Palette.TEXT_DIM, false)
		name_label.add_theme_font_size_override("font_size", maxi(_font_size - 2, 10))
		name_label.size_flags_vertical = Control.SIZE_SHRINK_END
		cell.add_child(name_label)
		cell.add_child(_label(part.substr(cut + 1), Palette.TEXT, true))


func _label(text: String, color: Color, bold: bool) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", _font_size)
	label.add_theme_color_override("font_color", color)
	if bold:
		label.add_theme_font_override("font", UiTheme.FONT_BOLD)
	return label
