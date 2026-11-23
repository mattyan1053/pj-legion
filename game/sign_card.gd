extends PanelContainer
## 縫い目の様子の札 1 枚（docs/seam-signs.md）: 印（sign_mark.gd）、名前、効果の文（2 行まで）。
## 対戦中、上の帯の下の札の名前をクリックすると出す窓（hud_top_bar.gd）に使う。大きさは中身（札）に依らず同じ（SIZE。docs/ui-theme.md の「枠の大きさ」）。

const Text := preload("res://game/text.gd")
const Names := preload("res://game/names.gd")
const Steady := preload("res://game/steady.gd")
const UiTheme := preload("res://game/ui_theme.gd")
const Palette := preload("res://game/ui_palette.gd")
const SignMark := preload("res://game/sign_mark.gd")
const TextWrap := preload("res://game/text_wrap.gd")

## 札の大きさ（px）と、印の大きさ。
const SIZE := Vector2(380.0, 132.0)
const MARK_SIDE := 64.0
## 効果の文の字の大きさ・折り返す幅・行の数の上限。文は語の途中で切らずに折り返す（text_wrap.gd。tools/wrap_audit.gd が全部の札を見る）。
const SUMMARY_FONT := 15
const SUMMARY_WIDTH := SIZE.x - MARK_SIDE - 50.0
const SUMMARY_MAX_LINES := 2

var _mark: SignMark
var _name: Label
var _summary: Label
## 効果の文の、折り返す前の文（検査用）。
var _summary_plain := ""


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
	_summary.add_theme_font_override("font", UiTheme.FONT_BODY)  # 折り返しを測る字と同じに
	_summary.add_theme_font_size_override("font_size", SUMMARY_FONT)
	_summary.add_theme_color_override("font_color", Palette.TEXT_DIM)
	_summary.max_lines_visible = SUMMARY_MAX_LINES
	_summary.custom_minimum_size = Vector2(SUMMARY_WIDTH, 44.0)
	column.add_child(_summary)


## 札 sign（Seam.Sign の値）を見せる。
func show_sign(sign: int) -> void:
	_mark.sign = sign
	_name.text = Names.sign_name(sign)
	_summary_plain = Names.sign_summary(sign)
	_summary.text = TextWrap.fold(_summary_plain, SUMMARY_WIDTH, func(character: String) -> float:
		return UiTheme.FONT_BODY.get_string_size(character, HORIZONTAL_ALIGNMENT_LEFT, -1, SUMMARY_FONT).x)


## 見せている文（検査用）。
func shown_text() -> String:
	return "%s %s" % [_name.text, _summary_plain]
