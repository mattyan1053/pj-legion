extends Control
## 対戦の途中の会話の札（docs/story.md の「対戦の途中の会話」）。画面の左上に、会話の場面と同じ見た目（話し手の名前の札と文の枠）で、
## 短い台詞を数秒出して消す。対戦は止めない（クリックを受けない。盤の操作の邪魔をしない）。
##
## 台詞が重なったら、順に出す（前の台詞が消えてから次）。出す長さは実際の時間で測る（CPU の番の早送りや、
## 自動の対戦の速さ（Engine.time_scale）で縮めない。メニューを開いて止めている間は進めない）。

const BattleCues := preload("res://game/battle_cues.gd")

## 1 つの台詞を出しておく時間（秒）: 基本 + 1 文字あたり。
const SHOW_BASE := 2.2
const SHOW_PER_CHAR := 0.07
## 出てくる・消えるときのフェード（秒）。
const FADE := 0.25
const WIDTH := 460.0
## 上の帯の下の、勝ち方の札（battle_hud.gd。守り切る・全滅させる話で出る）より下。
const TOP := 94.0
const LEFT := 16.0

const TEAM_COLORS: Array[Color] = [Color("3a7bd5"), Color("d64545"), Color("6b7280")]
const COLOR_BOX := Color(0.06, 0.08, 0.11, 0.9)
const COLOR_BORDER := Color(1.0, 1.0, 1.0, 0.14)
const COLOR_TEXT := Color(0.95, 0.96, 0.98)

## まだ出していない台詞。
var _queue: Array[BattleCues.Line] = []
## いま出している台詞と、出してからの時間（実際の秒）。
var _current: BattleCues.Line
var _elapsed := 0.0
var _plate_style: StyleBoxFlat
var _name: Label
var _text: Label
var _column: VBoxContainer


## 札の部品は、木に入れる前に作っておく（テストから木に入れずに使える）。
func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2(LEFT, TOP)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 0)
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.custom_minimum_size = Vector2(WIDTH, 0.0)
	add_child(_column)
	var top_row := HBoxContainer.new()
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(top_row)
	_plate_style = StyleBoxFlat.new()
	_plate_style.set_corner_radius_all(4)
	_plate_style.corner_radius_bottom_left = 0
	_plate_style.corner_radius_bottom_right = 0
	_plate_style.content_margin_left = 14.0
	_plate_style.content_margin_right = 14.0
	_plate_style.content_margin_top = 2.0
	_plate_style.content_margin_bottom = 2.0
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", _plate_style)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(plate)
	_name = _label(17, Color.WHITE)
	plate.add_child(_name)
	var box_style := StyleBoxFlat.new()
	box_style.bg_color = COLOR_BOX
	box_style.border_color = COLOR_BORDER
	box_style.set_border_width_all(1)
	box_style.set_corner_radius_all(6)
	box_style.corner_radius_top_left = 0
	box_style.content_margin_left = 16.0
	box_style.content_margin_right = 16.0
	box_style.content_margin_top = 10.0
	box_style.content_margin_bottom = 10.0
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", box_style)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(box)
	_text = _label(19, COLOR_TEXT)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(WIDTH - 32.0, 0.0)
	box.add_child(_text)
	visible = false


## 台詞を出す順に積む。
func say(lines: Array[BattleCues.Line]) -> void:
	_queue.append_array(lines)
	if _current == null:
		_next()


## 出している台詞と、積んである台詞を消す（新しい対戦を始めるとき）。
func clear() -> void:
	_queue.clear()
	_current = null
	visible = false


## いま出している台詞（無ければ null）。
func current() -> BattleCues.Line:
	return _current


## まだ出していない台詞の数。
func pending() -> int:
	return _queue.size()


func _process(delta: float) -> void:
	if _current == null:
		return
	# Engine.time_scale で縮めない（実際の秒）。0（メニューで止めている間）なら進めない。
	if Engine.time_scale <= 0.0:
		return
	_elapsed += delta / Engine.time_scale
	var shown := _duration(_current)
	modulate.a = clampf(minf(_elapsed / FADE, (shown - _elapsed) / FADE), 0.0, 1.0)
	if _elapsed >= shown:
		_next()


func _next() -> void:
	_current = null if _queue.is_empty() else _queue.pop_front()
	_elapsed = 0.0
	visible = _current != null
	if _current == null:
		return
	_name.text = _current.name
	_plate_style.bg_color = TEAM_COLORS[clampi(_current.side, 0, TEAM_COLORS.size() - 1)].darkened(0.15)
	_text.text = _current.text
	modulate.a = 0.0


static func _duration(line: BattleCues.Line) -> float:
	return SHOW_BASE + SHOW_PER_CHAR * line.text.length()


func _label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
