extends CanvasLayer
## 会話のログの窓（docs/story.md の「会話のログ」）。会話の場面で、これまでに出した文を、話し手の名前の札（陣営の色）と文で並べる。
##
## 何を並べるかは開く側が渡す（会話の行の列。story.gd の talk_of の "lines"）。ここはルールを持たない。
## - 窓の見た目は、ほかの窓と同じ（docs/ui-theme.md の「窓」）: 後ろを幕で沈め、板は PANEL_SOLID、見出しは明朝で真ん中、その下に飾りの線、
##   閉じるボタンは下の真ん中。
## - 開いている間は、画面の全体を覆って、クリック・ホイール・キーを後ろ（会話）へ通さない。
## - 開くと、いちばん下（いま出している文）を見せる。ホイールと上下の矢印・PageUp/PageDown・Home/End で遡る。
## - 右クリック・Esc・L・「閉じる」・板の外のクリックで閉じる。いちばん下でホイールを下へ回しても閉じる（会話へ戻る）。

const Text := preload("res://game/text.gd")
const Palette := preload("res://game/ui_palette.gd")
const UiTheme := preload("res://game/ui_theme.gd")
const TextWrap := preload("res://game/text_wrap.gd")

## 開いた・閉じた。
signal opened
signal closed

## システムメニュー（20）より下、会話の場面の文字より上。
const LAYER := 15
const PANEL_WIDTH := 820.0
## 板の上下の、画面の端からの余白（px）。
const MARGIN_Y := 40.0
## 名前の札の幅（名前の長さに依らず、文の頭をそろえる）。
const PLATE_WIDTH := 150.0
const NAME_FONT := 16
const TEXT_FONT := 18
## 文を折り返す幅（px）: 板の幅から、板の余白（左右 20）、縦のスクロールの棒のぶん（20）、名前の札と間（14）を引いたもの。
const TEXT_WIDTH := PANEL_WIDTH - 40.0 - 20.0 - PLATE_WIDTH - 14.0
## 矢印のキー 1 回で動かす量（px）。PageUp/PageDown は板の見えている高さの 8 割。
const KEY_STEP := 60.0
## 名前の札の色（0 = 人の軍、1 = 敵の軍、2 = 知らせ。talk_screen.gd の TEAM_COLORS と同じ）。
const TEAM_COLORS: Array[Color] = [Palette.TEAM_BLUE, Palette.TEAM_RED, Palette.TEXT_OFF]
const NOTICE_SIDE := 2
## 地の文の行の side（episode.gd の NARRATION_SIDE）。札を出さず（場所は取る）、文を明朝で。
const NARRATION_SIDE := 3

var _overlay: Control
var _panel: PanelContainer
var _scroll: ScrollContainer
var _rows_box: VBoxContainer
var _title: Label
## 開いている重なる画面の積み上げ（overlay_stack.gd。AppContext.overlays）。
var _overlays: RefCounted
## 並べている行の数。
var _count := 0


func setup(overlays: RefCounted) -> void:
	_overlays = overlays
	layer = LAYER
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visible = false
	_overlay.gui_input.connect(_on_overlay_input)
	add_child(_overlay)
	var shade := ColorRect.new()
	shade.color = Palette.SHADE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(shade)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiTheme.solid_box(20.0))
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -PANEL_WIDTH / 2.0
	_panel.offset_right = PANEL_WIDTH / 2.0
	_panel.offset_top = MARGIN_Y
	_panel.offset_bottom = -MARGIN_Y
	_overlay.add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_panel.add_child(column)

	_title = Label.new()
	_title.text = Text.t("talk.log.title")
	UiTheme.style_window_title(_title)
	column.add_child(_title)
	column.add_child(UiTheme.window_rule())

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)
	_rows_box = VBoxContainer.new()
	_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows_box.add_theme_constant_override("separation", 10)
	_scroll.add_child(_rows_box)

	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(foot)
	var close_button := Button.new()
	close_button.text = Text.t("talk.log.close")
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.add_theme_font_size_override("font_size", 17)
	close_button.custom_minimum_size = Vector2(180.0, 42.0)
	close_button.pressed.connect(close)
	foot.add_child(close_button)


## ログを開く。lines は会話の行の列（{"side", "name", "text"}。story.gd の talk_of の "lines"）のうち、これまでに出したもの。
func open(lines: Array) -> void:
	for child in _rows_box.get_children():
		_rows_box.remove_child(child)
		child.queue_free()
	_count = 0
	for line: Dictionary in lines:
		_rows_box.add_child(_row(line))
		_count += 1
	_overlay.visible = true
	_overlays.open(self)
	opened.emit()
	await get_tree().process_frame  # 並べた大きさが決まってから、いちばん下へ
	scroll_to_end()


func close() -> void:
	if not is_open():
		return
	_overlay.visible = false
	_overlays.close(self)
	closed.emit()


func is_open() -> bool:
	return _overlay.visible


## 並べている行の数。検査用。
func row_count() -> int:
	return _count


## 並べている行の [名前, 文] の列。検査用。
func row_texts() -> Array:
	var texts := []
	for row in _rows_box.get_children():
		texts.append([row.get_meta(&"name"), row.get_meta(&"text")])
	return texts


## いまの位置（0 でいちばん上）と、いちばん下の値。検査とスクリーンショットの道具用。
func scroll_value() -> int:
	return _scroll.scroll_vertical


func scroll_max() -> int:
	return maxi(int(_scroll.get_v_scroll_bar().max_value - _scroll.get_v_scroll_bar().page), 0)


func scroll_to(value: int) -> void:
	_scroll.scroll_vertical = value


func scroll_to_end() -> void:
	_scroll.scroll_vertical = scroll_max()


## 板が画面に占める四角。検査用。
func panel_rect() -> Rect2:
	return _panel.get_global_rect()


func _row(line: Dictionary) -> Control:
	var narration := int(line.get("side", 0)) == NARRATION_SIDE
	var side := clampi(int(line.get("side", 0)), 0, TEAM_COLORS.size() - 1)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_meta(&"name", line.get("name", ""))
	row.set_meta(&"text", line.get("text", ""))
	# 名前の札（会話の場面の札と同じ色の決まり。知らせは金）。
	var plate_style := StyleBoxFlat.new()
	plate_style.set_corner_radius_all(4)
	plate_style.set_border_width_all(1)
	plate_style.content_margin_left = 10.0
	plate_style.content_margin_right = 10.0
	plate_style.content_margin_top = 2.0
	plate_style.content_margin_bottom = 2.0
	if side == NOTICE_SIDE:
		plate_style.bg_color = Palette.CHOSEN
		plate_style.border_color = Palette.BORDER_BRIGHT
	else:
		plate_style.bg_color = TEAM_COLORS[side].darkened(0.15)
		plate_style.border_color = TEAM_COLORS[side].lightened(0.35)
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", plate_style)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.custom_minimum_size = Vector2(PLATE_WIDTH, 0.0)
	plate.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	if narration:
		plate.modulate.a = 0.0  # 地の文は札を出さない（文の頭は、ほかの行とそろえる）
	row.add_child(plate)
	var name_label := _label(NAME_FONT, Color.WHITE)
	name_label.add_theme_font_override("font", UiTheme.FONT_BOLD)
	name_label.text = line.get("name", "")
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.clip_text = true
	plate.add_child(name_label)
	var text := _label(TEXT_FONT, Palette.TEXT)
	if narration:
		text.add_theme_font_override("font", UiTheme.FONT_HEADING)
	var font := UiTheme.FONT_HEADING if narration else UiTheme.FONT_BODY
	text.text = TextWrap.fold(line.get("text", ""), TEXT_WIDTH,
		func(character: String) -> float: return font.get_string_size(character, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_FONT).x)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	return row


## 板の外を押したら閉じる。
func _on_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
			and not _panel.get_global_rect().has_point(event.position):
		close()


## 開いている間の右クリック・Esc・L は閉じる。いちばん下でホイールを下へ回しても閉じる。矢印などのキーで遡る。
## キーは後ろ（会話の送り）へ通さない。
func _input(event: InputEvent) -> void:
	if not is_open() or not _overlays.is_top(self):
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			get_viewport().set_input_as_handled()
			close()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and _scroll.scroll_vertical >= scroll_max():
			get_viewport().set_input_as_handled()
			close()
		return
	if not event is InputEventKey:
		return
	get_viewport().set_input_as_handled()
	if not event.pressed:
		return
	var page := _scroll.size.y * 0.8
	match event.physical_keycode:
		KEY_ESCAPE, KEY_L:
			if not event.echo:
				close()
		KEY_UP, KEY_W:
			scroll_to(int(_scroll.scroll_vertical - KEY_STEP))
		KEY_DOWN, KEY_S:
			scroll_to(int(_scroll.scroll_vertical + KEY_STEP))
		KEY_PAGEUP:
			scroll_to(int(_scroll.scroll_vertical - page))
		KEY_PAGEDOWN:
			scroll_to(int(_scroll.scroll_vertical + page))
		KEY_HOME:
			scroll_to(0)
		KEY_END:
			scroll_to_end()


## 場面を抜けるなどで木から抜けたら、積み上げから降ろす。
func _exit_tree() -> void:
	if _overlays != null:
		_overlays.close(self)


func _label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
