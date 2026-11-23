extends PanelContainer
## 対戦の始めの「対戦ルール」に並べる札 1 枚（docs/battle-view.md の「対戦ルール」）: 印、短い名前、1 行の説明。
## 勝利条件の札は勝ち方の印（goal_mark.gd）、縫い目の様子の札は様子の印（sign_mark.gd）。
## 大きさは中身に依らず同じ（SIZE。docs/ui-theme.md の「枠の大きさ」）。

const Steady := preload("res://game/steady.gd")
const UiTheme := preload("res://game/ui_theme.gd")
const Palette := preload("res://game/ui_palette.gd")
const GoalMark := preload("res://game/goal_mark.gd")
const SignMark := preload("res://game/sign_mark.gd")

## 札の大きさ（px）と、印の大きさ。
const SIZE := Vector2(214.0, 92.0)
const MARK_SIDE := 40.0

var _goal_mark: GoalMark
var _sign_mark: SignMark
var _name: Label
var _line: Label


func _init() -> void:
	theme_type_variation = UiTheme.PANEL_CARD
	custom_minimum_size = SIZE
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Steady.mark(self, "battle.rule_card")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	_goal_mark = GoalMark.new(-1, MARK_SIDE)
	row.add_child(_goal_mark)
	_sign_mark = SignMark.new(-1, MARK_SIDE)
	row.add_child(_sign_mark)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(column)
	_name = Label.new()
	_name.theme_type_variation = UiTheme.LABEL_HEADING
	_name.add_theme_font_size_override("font_size", 18)
	_name.clip_text = true
	column.add_child(_name)
	_line = Label.new()
	_line.add_theme_font_size_override("font_size", 13)
	_line.add_theme_color_override("font_color", Palette.TEXT_DIM)
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.max_lines_visible = 2
	_line.custom_minimum_size = Vector2(SIZE.x - MARK_SIDE - 40.0, 0.0)
	column.add_child(_line)


## 勝利条件の札（reason は GameWonEvent.Reason の値）。
func show_goal(reason: int, title: String, line: String) -> void:
	_goal_mark.reason = reason
	_goal_mark.visible = true
	_sign_mark.visible = false
	_name.text = title
	_line.text = line


## 縫い目の様子の札（sign は Seam.Sign の値）。
func show_sign(sign: int, title: String, line: String) -> void:
	_sign_mark.sign = sign
	_sign_mark.visible = true
	_goal_mark.visible = false
	_name.text = title
	_line.text = line


## 見せている文（名前と説明。検査用）。
func shown_text() -> String:
	return "%s %s" % [_name.text, _line.text]


## 説明の文の行が、欄に収まっているか（はみ出して切れていないか。検査用）。
func fits() -> bool:
	return _line.get_line_count() <= _line.max_lines_visible
