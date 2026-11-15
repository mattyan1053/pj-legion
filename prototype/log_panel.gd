extends CanvasLayer
## 対戦のログの画面（docs/battle-log.md）。画面の右に、ログ（battle_log.gd）の行を、フェーズの区切りごとに並べる。
##
## 何を書くかはログが決める。ここは並べて、選ばれた行を知らせるだけ（ルールを持たない）。
## - 開いている間は、画面の全体を覆って、クリック・ドラッグ・ホイール・キーを後ろ（盤面）へ通さない。
## - 右クリック・Esc・「閉じる」・パネルの外のクリックで閉じる。
## - 開くたびに、前に開いてから増えた・書き換わった行だけを作り直し、いちばん下（最新）を見せる。
## - 行は、新しいほうから CHUNK 行ずつ作る。いちばん上までさかのぼると、その前の CHUNK 行を足す（長い対戦でも、開くのが重くならない）。

const BattleLog := preload("res://prototype/battle_log.gd")
const TextWrap := preload("res://prototype/text_wrap.gd")

## 開いた・閉じた（後ろの画面は、これを受けて止まる・動き出す）。
signal opened
signal closed
## 行が選ばれた（クリック）。entry はログの行。
signal entry_chosen(entry: BattleLog.Entry)

## システムメニュー（20）より下、対戦の画面の文字（1）より上。
const LAYER := 15
## 一度に作る行の数。
const CHUNK := 60
## 上の端からこれより近くまでさかのぼったら、その前の行を足す（px）。
const LOAD_MARGIN := 120.0
const PANEL_WIDTH := 470.0
const MARGIN := 8.0
## 上の帯（対戦の画面）と、その下の視点の操作の説明は隠さない。
const TOP_GAP := 84.0
## 行の文の幅（パネルの幅から、余白と、陣営の色の帯と、スクロールの棒のぶんを引く）。
const TEXT_WIDTH := PANEL_WIDTH - 72.0
const FONT_SIZE := 15
const HEADER_FONT_SIZE := 16
const COLOR_PANEL := Color(0.08, 0.1, 0.13, 0.95)
const COLOR_ROW_HOVER := Color(1.0, 1.0, 1.0, 0.07)
const COLOR_ROW_CHOSEN := Color(1.0, 0.85, 0.35, 0.16)
const COLOR_TEXT := Color(0.9, 0.92, 0.95)
const COLOR_TEXT_DIM := Color(0.72, 0.75, 0.8)
const COLOR_NEUTRAL := Color(0.78, 0.78, 0.74)

var _team_colors: Array[Color] = []
var _overlay: Control
var _panel: PanelContainer
var _scroll: ScrollContainer
var _rows_box: VBoxContainer
## 並べている行（ログの _first 番目の行から、同じ順に）。
var _rows: Array[Control] = []
var _first := 0
var _loading := false
var _log: BattleLog
var _chosen: Control
var _char_widths := {}


func setup(team_colors: Array[Color]) -> void:
	_team_colors = team_colors
	layer = LAYER
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visible = false
	_overlay.gui_input.connect(_on_overlay_input)
	add_child(_overlay)

	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12.0)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", style)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	_panel.offset_left = -PANEL_WIDTH - MARGIN
	_panel.offset_right = -MARGIN
	_panel.offset_top = TOP_GAP
	_panel.offset_bottom = -MARGIN
	_overlay.add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_panel.add_child(column)

	var title_row := HBoxContainer.new()
	column.add_child(title_row)
	var title := _label(22, COLOR_TEXT)
	title.text = "ログ"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	var close_button := Button.new()
	close_button.text = "閉じる"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.add_theme_font_size_override("font_size", 16)
	close_button.custom_minimum_size = Vector2(96.0, 34.0)
	close_button.pressed.connect(close)
	title_row.add_child(close_button)
	var hint := _label(13, COLOR_TEXT_DIM)
	hint.text = "行を押すと、その場所と駒を盤の上で示す"
	column.add_child(hint)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)
	_rows_box = VBoxContainer.new()
	_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows_box.add_theme_constant_override("separation", 2)
	_scroll.add_child(_rows_box)
	_scroll.get_v_scroll_bar().value_changed.connect(_on_scrolled)


## ログを開く。前に開いてから増えた・書き換わった行を作り直し、いちばん下を見せる。
func open(battle_log: BattleLog) -> void:
	var from := battle_log.take_changes() if battle_log == _log else 0
	var size := battle_log.entries.size()
	if battle_log != _log or size - from > CHUNK:
		# 新しいログか、前に開いてから行がたくさん増えた: 新しいほうの CHUNK 行だけを作り直す。
		_clear()
		_log = battle_log
		_first = maxi(size - CHUNK, 0)
		_build_from(_first)
	else:
		_build_from(maxi(from, _first))
	_overlay.visible = true
	opened.emit()
	await get_tree().process_frame  # 並べ直した大きさが決まってから、いちばん下へ
	_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)


func close() -> void:
	if not is_open():
		return
	_overlay.visible = false
	closed.emit()


func is_open() -> bool:
	return _overlay.visible


## 並べている行の数（見出しを含む）と、いちばん上の行のログの番号。検査用。
func row_count() -> int:
	return _rows.size()


func first_row() -> int:
	return _first


## ログの i 番目の行を選ぶ（クリックと同じ道）。並べていなければ、何もしない。検査用。
func choose(i: int) -> void:
	if i >= _first and i < _first + _rows.size():
		_choose(_rows[i - _first], _log.entries[i])


## パネルが画面に占める四角。検査用。
func panel_rect() -> Rect2:
	return _panel.get_global_rect()


## いまの位置からスクロールする（検査とスクリーンショットの道具用）。0 で、いちばん上。
func scroll_to(value: int) -> void:
	_scroll.scroll_vertical = value


func _clear() -> void:
	for row in _rows:
		_rows_box.remove_child(row)
		row.queue_free()
	_rows.clear()
	_first = 0
	_chosen = null


## ログの from 番目から先の行を作り直す。
func _build_from(from: int) -> void:
	while _rows.size() > from - _first:
		var row: Control = _rows.pop_back()
		if row == _chosen:
			_chosen = null
		_rows_box.remove_child(row)
		row.queue_free()
	for i in range(from, _log.entries.size()):
		var row := _row(_log.entries[i], i)
		_rows_box.add_child(row)
		_rows.append(row)


func _row(entry: BattleLog.Entry, index: int) -> Control:
	var color := _side_color(entry.side)
	if entry.header:
		var box := VBoxContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# ターンの変わり目には線を引く（フェーズの区切りより強く）。
		var previous_turn := -1
		for i in range(index - 1, -1, -1):
			if _log.entries[i].header:
				previous_turn = _log.entries[i].turn
				break
		if index > 0:
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(0.0, 10.0 if previous_turn != entry.turn else 4.0)
			gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			box.add_child(gap)
			if previous_turn != entry.turn:
				var line := ColorRect.new()
				line.color = Color(1.0, 1.0, 1.0, 0.18)
				line.custom_minimum_size = Vector2(0.0, 1.0)
				line.mouse_filter = Control.MOUSE_FILTER_IGNORE
				box.add_child(line)
		var label := _label(HEADER_FONT_SIZE, color.lightened(0.35))
		label.text = entry.text
		box.add_child(label)
		return box

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.set_corner_radius_all(4)
	style.content_margin_left = 0.0
	style.content_margin_top = 3.0
	style.content_margin_bottom = 3.0
	style.content_margin_right = 4.0
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", style)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var line_box := HBoxContainer.new()
	line_box.add_theme_constant_override("separation", 8)
	line_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(line_box)
	# 行の主の陣営の色の帯。
	var strip := ColorRect.new()
	strip.color = color
	strip.custom_minimum_size = Vector2(4.0, 0.0)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line_box.add_child(strip)
	var texts := VBoxContainer.new()
	texts.add_theme_constant_override("separation", 0)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_box.add_child(texts)
	var main := _label(FONT_SIZE, color.lightened(0.55) if entry.side >= 0 else COLOR_TEXT)
	_set_folded(main, entry.text, TEXT_WIDTH)
	texts.add_child(main)
	if not entry.details.is_empty():
		var details := _label(FONT_SIZE - 1, COLOR_TEXT_DIM)
		_set_folded(details, "\n".join(entry.details), TEXT_WIDTH - 16.0)
		# 続きの行は、少し字下げする。
		var indent := MarginContainer.new()
		indent.add_theme_constant_override("margin_left", 16)
		indent.mouse_filter = Control.MOUSE_FILTER_IGNORE
		indent.add_child(details)
		texts.add_child(indent)
	row.mouse_entered.connect(func() -> void: _paint(row, style))
	row.mouse_exited.connect(func() -> void: _paint(row, style))
	row.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_choose(row, entry))
	return row


func _choose(row: Control, entry: BattleLog.Entry) -> void:
	if entry.header:
		return
	var before := _chosen
	_chosen = row
	if before != null and is_instance_valid(before):
		_paint(before, before.get_theme_stylebox("panel") as StyleBoxFlat)
	_paint(row, row.get_theme_stylebox("panel") as StyleBoxFlat)
	entry_chosen.emit(entry)


func _paint(row: Control, style: StyleBoxFlat) -> void:
	if row == _chosen:
		style.bg_color = COLOR_ROW_CHOSEN
	elif row.get_global_rect().has_point(row.get_global_mouse_position()):
		style.bg_color = COLOR_ROW_HOVER
	else:
		style.bg_color = Color(0.0, 0.0, 0.0, 0.0)


## いちばん上の近くまでさかのぼったら、その前の CHUNK 行を足す。足した高さのぶんだけ下げて、見ていた行を動かさない。
func _on_scrolled(value: float) -> void:
	if _loading or _first == 0 or value > LOAD_MARGIN or not is_open():
		return
	_loading = true
	var bar := _scroll.get_v_scroll_bar()
	var height_before := bar.max_value
	var start := maxi(_first - CHUNK, 0)
	var added: Array[Control] = []
	for i in range(start, _first):
		var row := _row(_log.entries[i], i)
		_rows_box.add_child(row)
		_rows_box.move_child(row, i - start)
		added.append(row)
	added.append_array(_rows)
	_rows = added
	_first = start
	await get_tree().process_frame
	_scroll.scroll_vertical = int(_scroll.scroll_vertical + bar.max_value - height_before)
	_loading = false


## パネルの外を押したら閉じる。
func _on_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()


## 開いている間の右クリックと Esc は閉じる。キーは後ろ（盤面の操作）へ通さない。
func _input(event: InputEvent) -> void:
	if not is_open():
		return
	var right: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT
	var escape: bool = event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE
	if right or escape:
		get_viewport().set_input_as_handled()
		close()
	elif event is InputEventKey:
		get_viewport().set_input_as_handled()


func _side_color(side: int) -> Color:
	if side == Unit.Side.NEUTRAL or side < 0:
		return COLOR_NEUTRAL
	return _team_colors[side] if side < _team_colors.size() else COLOR_NEUTRAL


func _label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _set_folded(label: Label, text: String, width: float) -> void:
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	label.text = TextWrap.fold(text, width, func(character: String) -> float:
		var key := "%d:%s" % [font_size, character]
		if not _char_widths.has(key):
			_char_widths[key] = font.get_string_size(character, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		return _char_widths[key])
