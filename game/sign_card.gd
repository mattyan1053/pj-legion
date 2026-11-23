extends PanelContainer
## 縫い目の様子の札 1 枚（docs/seam-signs.md）: 印（sign_mark.gd）、名前、効果の文（2 行まで）。
## 札がめくられる窓（signs_window.gd）に並べる。大きさは中身（札）に依らず同じ（SIZE。docs/ui-theme.md の「枠の大きさ」）。

const Text := preload("res://game/text.gd")
const Names := preload("res://game/names.gd")
const Steady := preload("res://game/steady.gd")
const UiTheme := preload("res://game/ui_theme.gd")
const Palette := preload("res://game/ui_palette.gd")
const SignMark := preload("res://game/sign_mark.gd")

## 札の大きさ（px）と、印の大きさ。
const SIZE := Vector2(380.0, 132.0)
const MARK_SIDE := 64.0

var _mark: SignMark
var _name: Label
var _summary: Label


func _init() -> void:
	theme_type_variation = UiTheme.PANEL_CARD
	custom_minimum_size = SIZE
	clip_contents = true
	Steady.mark(self, "signs.card")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	add_child(row)
	_mark = SignMark.new(-1, MARK_SIDE)
	row.add_child(_mark)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 4)
	row.add_child(column)
	_name = Label.new()
	_name.theme_type_variation = UiTheme.LABEL_HEADING
	_name.add_theme_font_size_override("font_size", 22)
	_name.clip_text = true
	column.add_child(_name)
	_summary = Label.new()
	_summary.add_theme_font_size_override("font_size", 15)
	_summary.add_theme_color_override("font_color", Palette.TEXT_DIM)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.max_lines_visible = 2
	_summary.custom_minimum_size = Vector2(SIZE.x - MARK_SIDE - 50.0, 44.0)
	column.add_child(_summary)


## 札 sign（Seam.Sign の値）を見せる。
func show_sign(sign: int) -> void:
	_mark.sign = sign
	_name.text = Names.sign_name(sign)
	_summary.text = Names.sign_summary(sign)


## 見せている文（検査用）。
func shown_text() -> String:
	return "%s %s" % [_name.text, _summary.text]
