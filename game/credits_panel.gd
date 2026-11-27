extends Control
## クレジットの窓（docs/credits.md）。タイトルの「クレジット」で開く重なる画面。
## 中身は game/credits.csv（credits.gd）から作る: 種類ごと（フォント、兵と魔物、盤、音）に、素材名・作者・ライセンス・出どころ。
## 最後に、文の同梱を求めるライセンス（SIL OFL）の文をそのまま載せる。
## 窓は決まった大きさで、中身は窓の中で送る（docs/ui-theme.md の「枠の大きさ」）。
## 「閉じる」・右クリック・Esc・窓の外のクリックで閉じる。

const Text := preload("res://game/text.gd")
const CardKeys := preload("res://game/card_keys.gd")
const UiTheme := preload("res://game/ui_theme.gd")
const Palette := preload("res://game/ui_palette.gd")
const Steady := preload("res://game/steady.gd")
const Credits := preload("res://game/credits.gd")

## 窓の板の大きさ（px。1280×720 の論理の画面に余白を持って収まる）と、中身の欄の幅。
const SIZE := Vector2(880.0, 600.0)
const BODY_WIDTH := SIZE.x - 80.0
## 文を同梱して載せるライセンス（この名前のライセンスの文を、窓の最後に出す）。
const SHOWN_LICENSES: Array[String] = ["SIL Open Font License 1.1"]
## ホイール 1 目盛りで送る量（px）。
const WHEEL_STEP := 48

## 閉じた。
signal closed

var _overlays: RefCounted
var _scroll: ScrollContainer
var _body: VBoxContainer
## 載せている文（検査用。1 行ずつ）。
var _lines: Array[String] = []


## overlays は、開いている重なる画面の積み上げ（AppContext.overlays）。
func setup(overlays: RefCounted) -> void:
	_overlays = overlays
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	visibility_changed.connect(_track_overlay)
	var shade := ColorRect.new()
	shade.color = Color(Palette.SHADE, 0.5)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			close_credits())
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.theme_type_variation = UiTheme.PANEL_SOLID
	panel.custom_minimum_size = SIZE
	Steady.mark(panel, "credits.window")
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var title := Label.new()
	title.theme_type_variation = UiTheme.LABEL_HEADING
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = Text.t("credits.title")
	column.add_child(title)
	column.add_child(UiTheme.window_rule())
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.get_v_scroll_bar().custom_step = WHEEL_STEP
	column.add_child(_scroll)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 4)
	_body.custom_minimum_size = Vector2(BODY_WIDTH, 0.0)
	_scroll.add_child(_body)
	_fill()
	var close := Button.new()
	close.text = Text.t("common.close")
	close.focus_mode = Control.FOCUS_NONE
	close.add_theme_font_size_override("font_size", 17)
	close.custom_minimum_size = Vector2(180.0, 40.0)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(close_credits)
	column.add_child(close)


func open_credits() -> void:
	_scroll.scroll_vertical = 0
	visible = true


func close_credits() -> void:
	visible = false


## 載せている文（検査用）。
func shown_lines() -> Array[String]:
	return _lines


## 窓の板の大きさ（検査用）。
func panel_size() -> Vector2:
	return SIZE


## いちばん下まで送る（スクリーンショットの道具用）。
func scroll_to_end() -> void:
	_scroll.scroll_vertical = scroll_room()


## 中身を、いちばん下まで送ったときの送りの量（検査用。送れるか）。
func scroll_room() -> int:
	return int(_scroll.get_v_scroll_bar().max_value - _scroll.get_v_scroll_bar().page)


func _fill() -> void:
	_add_text(Text.t("credits.thanks"), 15, Palette.TEXT_DIM)
	for group in Credits.GROUPS:
		var head := UiTheme.section_head(Text.t("credits.group." + group), 18)
		_body.add_child(head)
		_lines.append(Text.t("credits.group." + group))
		for row in Credits.rows_of(group):
			var name_row := HBoxContainer.new()
			name_row.add_theme_constant_override("separation", 12)
			_body.add_child(name_row)
			var title_label := _label(row["name"], 16, Palette.TEXT, true)
			title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			name_row.add_child(title_label)
			name_row.add_child(_label(row["license"], 14, Palette.ACCENT, false))
			_add_text(row["author"], 14, Palette.TEXT)
			_add_text(row["source"], 13, Palette.TEXT_DIM)
			_lines.append("%s %s %s %s" % [row["name"], row["author"], row["license"], row["source"]])
	# 文の同梱を求めるライセンスは、その文をそのまま載せる（フォントの OFL）。
	var shown := {}
	for row in Credits.rows():
		if SHOWN_LICENSES.has(row["license"]) and not shown.has(row["license_file"]):
			shown[row["license_file"]] = true
			_body.add_child(UiTheme.section_head(Text.t("credits.license_text", {"name": row["name"]}), 16))
			var file := FileAccess.open("res://" + row["license_file"], FileAccess.READ)
			var words := file.get_as_text() if file != null else ""
			_add_text(words.strip_edges(), 12, Palette.TEXT_DIM)
			_lines.append(words)


func _add_text(words: String, font_size: int, color: Color) -> void:
	var label := _label(words, font_size, color, false)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(BODY_WIDTH, 0.0)
	_body.add_child(label)


func _label(words: String, font_size: int, color: Color, bold: bool) -> Label:
	var label := Label.new()
	label.text = words
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if bold:
		label.add_theme_font_override("font", UiTheme.FONT_BOLD)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _track_overlay() -> void:
	if _overlays == null:
		return
	if visible and is_inside_tree():
		_overlays.open(self)
	else:
		_overlays.close(self)
		closed.emit()


func _exit_tree() -> void:
	if _overlays != null:
		_overlays.close(self)


func _input(event: InputEvent) -> void:
	if not visible or _overlays == null or not _overlays.is_top(self):
		return
	if CardKeys.is_back(event):
		close_credits()
		get_viewport().set_input_as_handled()
