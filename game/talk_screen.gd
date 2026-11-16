extends Node
## 会話の場面（docs/story.md）。立ち絵は無く、話し手の名前の札（陣営の色）と、文の枠だけ。背景は対戦と同じ景色（backdrop.gd）。
## 背景は、話の盤（渡されなければ、タイトルと同じ景色）。場面の決まりは scene_flow.gd。流れ（run.gd）が、会話（story.gd の talk_of）を渡す。
##
## - クリック・Enter・Space で次の文へ。文が出きる前なら、出しきるだけ。最後の文のあとは Run.NEXT で終える（流れの次の場面へ）。
## - 右クリックで 1 つ前の文へ戻る。Esc はシステムメニュー（ほかの場面と同じ）。
## - 「飛ばす」で、残りを読まずに Run.NEXT で終える。

const AppContext := preload("res://game/app_context.gd")
const Backdrop := preload("res://game/backdrop.gd")
const Run := preload("res://game/run.gd")

signal finished(outcome: StringName)

## 文を出す速さ（1 秒あたりの文字数）。検査では待たない。
const CHARS_PER_SECOND := 45.0
const BOX_WIDTH := 980.0
const BOX_HEIGHT := 150.0
const BOX_BOTTOM := 40.0
## 送りの印の明滅の周期（秒）。
const BLINK_PERIOD := 1.2
## 陣営の色（battle_screen.gd の TEAM_COLORS と同じ。0 = 人の軍、1 = 敵の軍）。
const TEAM_COLORS: Array[Color] = [Color("3a7bd5"), Color("d64545")]

const COLOR_BOX := Color(0.06, 0.08, 0.11, 0.9)
const COLOR_BORDER := Color(1.0, 1.0, 1.0, 0.14)
const COLOR_TEXT := Color(0.95, 0.96, 0.98)
const COLOR_DIM := Color(0.78, 0.81, 0.86)

var context: AppContext
## 渡された会話（{"title": 見出し, "lines": [{"side", "name", "text"}, …]}）。
var talk := {}
var _index := 0
var _shown := 0.0  # いまの文の、出した文字数
var _elapsed := 0.0
var _plate: PanelContainer
var _plate_style: StyleBoxFlat
var _name: Label
var _text: Label
var _hint: Label
var _count: Label
var _skip: Button


func _ready() -> void:
	if context == null:
		context = AppContext.new()  # アプリを通さずに置いたとき
	var given: Variant = context.run_data(&"talk")
	if given != null:
		talk = given
	add_child(Backdrop.new(talk.get("board"), talk.get("look", &"")))
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var heading := _label(26, COLOR_TEXT)
	heading.text = talk.get("title", "")
	heading.position = Vector2(32.0, 24.0)
	root.add_child(heading)

	var bottom := VBoxContainer.new()
	bottom.add_theme_constant_override("separation", 0)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.custom_minimum_size = Vector2(BOX_WIDTH, 0.0)
	bottom.offset_left = -BOX_WIDTH / 2.0
	bottom.offset_right = BOX_WIDTH / 2.0
	bottom.offset_bottom = -BOX_BOTTOM
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(bottom)

	var top_row := HBoxContainer.new()
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(top_row)
	_plate_style = StyleBoxFlat.new()
	_plate_style.set_corner_radius_all(4)
	_plate_style.corner_radius_bottom_left = 0
	_plate_style.corner_radius_bottom_right = 0
	_plate_style.content_margin_left = 18.0
	_plate_style.content_margin_right = 18.0
	_plate_style.content_margin_top = 4.0
	_plate_style.content_margin_bottom = 4.0
	_plate = PanelContainer.new()
	_plate.add_theme_stylebox_override("panel", _plate_style)
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(_plate)
	_name = _label(22, Color.WHITE)
	_plate.add_child(_name)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(spacer)
	_skip = Button.new()
	_skip.text = "飛ばす"
	_skip.focus_mode = Control.FOCUS_NONE
	_skip.add_theme_font_size_override("font_size", 17)
	_skip.custom_minimum_size = Vector2(110.0, 36.0)
	_skip.size_flags_vertical = Control.SIZE_SHRINK_END
	_skip.pressed.connect(press_skip)
	top_row.add_child(_skip)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0.0, 6.0)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(gap)

	var box_style := StyleBoxFlat.new()
	box_style.bg_color = COLOR_BOX
	box_style.border_color = COLOR_BORDER
	box_style.set_border_width_all(1)
	box_style.set_corner_radius_all(6)
	box_style.content_margin_left = 28.0
	box_style.content_margin_right = 28.0
	box_style.content_margin_top = 18.0
	box_style.content_margin_bottom = 12.0
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", box_style)
	box.custom_minimum_size = Vector2(BOX_WIDTH, BOX_HEIGHT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(box)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(column)
	_text = _label(25, COLOR_TEXT)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_text)
	var foot := HBoxContainer.new()
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(foot)
	_count = _label(15, COLOR_DIM)
	_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(_count)
	_hint = _label(15, COLOR_DIM)
	_hint.text = "クリック・Enter で次へ ▼　右クリックで戻る"
	foot.add_child(_hint)

	_show_line(0)


func _process(delta: float) -> void:
	_elapsed += delta
	if _index < line_count() and _shown < _line_length():
		_shown = minf(_shown + delta * CHARS_PER_SECOND, _line_length())
		_text.visible_characters = int(_shown)
	_hint.modulate.a = 1.0 if not is_line_shown() else 0.5 + 0.5 * (0.5 + 0.5 * cos(_elapsed * TAU / BLINK_PERIOD))


func _unhandled_input(event: InputEvent) -> void:
	if context.overlays.is_open():
		return
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				press_next()
			MOUSE_BUTTON_RIGHT:
				press_back()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				press_next()
			KEY_ESCAPE:
				context.open_menu()


## 次へ: 文が出きる前なら出しきる。出ていたら次の文へ。最後の文のあとは、会話を終える。
func press_next() -> void:
	if not is_line_shown():
		_shown = _line_length()
		_text.visible_characters = -1
		return
	if _index + 1 < line_count():
		context.play_sound(&"ui_click")
		_show_line(_index + 1)
	else:
		_end()


## 1 つ前の文へ戻る（最初の文なら何もしない）。戻った文は出しきって見せる。
func press_back() -> void:
	if _index == 0:
		return
	context.play_sound(&"ui_back")
	_show_line(_index - 1)
	_shown = _line_length()
	_text.visible_characters = -1


## 「飛ばす」: 残りを読まずに会話を終える。
func press_skip() -> void:
	_end()


func line_count() -> int:
	return talk.get("lines", []).size()


## いま出している文の番号（0 から）。
func line_index() -> int:
	return _index


## いまの文が出きっているか。
func is_line_shown() -> bool:
	return _index >= line_count() or _shown >= _line_length()


## いまの話し手の名前と文（検査用）。
func speaker() -> String:
	return _name.text


func line_text() -> String:
	return _text.text


func _show_line(index: int) -> void:
	_index = index
	_shown = 0.0
	if index >= line_count():
		_name.text = ""
		_text.text = ""
		_count.text = ""
		_plate.visible = false
		return
	var line: Dictionary = talk["lines"][index]
	_plate.visible = true
	_name.text = line.get("name", "")
	_plate_style.bg_color = TEAM_COLORS[clampi(int(line.get("side", 0)), 0, TEAM_COLORS.size() - 1)].darkened(0.15)
	_text.text = line.get("text", "")
	_count.text = "%d / %d" % [index + 1, line_count()]
	if context.checking != &"":
		_shown = _line_length()  # 検査とスクリーンショットは、文を出しきって始める
	_text.visible_characters = -1 if is_line_shown() else 0


func _line_length() -> float:
	return float(_text.get_total_character_count())


var _ended := false


func _end() -> void:
	if _ended:
		return
	_ended = true
	context.play_sound(&"ui_confirm")
	finished.emit(Run.NEXT)


func _label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
