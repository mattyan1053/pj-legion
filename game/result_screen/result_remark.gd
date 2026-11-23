extends "res://game/result_screen/result_base.gd"
## リザルトの画面の、決着のあとのひとこと（話し手の顔と台詞の行）。


## 負けたときの台詞（battle_cues.gd の Line の列。ストーリーの話の [lost]）を、戦績の左の板に出す。空なら板を隠す。
## 出し始めたあと（present のあと）に渡す。戦績と一緒に出てくる（出そろったあとに渡したら、すぐ出す）。
func set_remark(lines: Array) -> void:
	for child in _remark_rows.get_children():
		child.queue_free()
	_remark_texts.clear()
	for line: BattleCues.Line in lines:
		_remark_rows.add_child(_remark_row(line))
		_remark_texts.append("%s: %s" % [line.name, line.text])
	_remark.visible = not lines.is_empty() and not _detail_panel.visible
	_remark.modulate.a = 1.0 if _revealed else 0.0
	_remark.reset_size()


## 出している負けたときの台詞（「名前: 文」の列。出していなければ空）。検査用。
func remark_texts() -> Array[String]:
	return _remark_texts.duplicate() if visible else [] as Array[String]


## 負けたときの台詞の板が画面に占める四角（出していなければ大きさ 0）。検査用。
func remark_rect() -> Rect2:
	return _remark.get_global_rect() if visible and _remark.visible else Rect2()


## 負けたときの台詞の板。戦績の列の左に、見出しの下から。
func _build_remark() -> void:
	_remark = _panel(Palette.BORDER)
	_remark.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_remark.offset_right = -230.0 - REMARK_GAP
	_remark.offset_left = _remark.offset_right - REMARK_WIDTH
	_remark.offset_top = BODY_TOP
	_remark.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_remark.custom_minimum_size = Vector2(REMARK_WIDTH, 0.0)
	_remark.visible = false
	add_child(_remark)
	_remark_rows = VBoxContainer.new()
	_remark_rows.add_theme_constant_override("separation", 10)
	_remark_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_remark.add_child(_remark_rows)


## 台詞の 1 行: 話し手のアイコン（陣営の色の縁）と、名前の札（陣営の色）、その下に文。
func _remark_row(line: BattleCues.Line) -> HBoxContainer:
	var team := _side_color(line.side)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var used := 0.0
	if not line.figure.is_empty() and line.side < 2:
		var frame := PanelContainer.new()
		frame.add_theme_stylebox_override("panel", UiTheme.box(Color(Palette.INK, 0.85), team.lightened(0.2), 1, 5, 0.0))
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		frame.add_child(_face(line))
		row.add_child(frame)
		used += REMARK_FACE + 2.0 + 10.0
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(column)
	var plate_style := StyleBoxFlat.new()
	plate_style.bg_color = team.darkened(0.15)
	plate_style.border_color = team.lightened(0.35)
	plate_style.set_border_width_all(1)
	plate_style.set_corner_radius_all(4)
	plate_style.content_margin_left = 10.0
	plate_style.content_margin_right = 10.0
	plate_style.content_margin_top = 1.0
	plate_style.content_margin_bottom = 1.0
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", plate_style)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(plate)
	var speaker := _label(15)
	speaker.add_theme_font_override("font", UiTheme.FONT_BOLD)
	speaker.text = line.name
	plate.add_child(speaker)
	var said := _label(REMARK_FONT)
	var font := said.get_theme_font("font")
	var style := _remark.get_theme_stylebox("panel")
	var width := REMARK_WIDTH - style.get_minimum_size().x - used
	said.text = TextWrap.fold(line.text, width,
		func(character: String) -> float: return font.get_string_size(character, HORIZONTAL_ALIGNMENT_LEFT, -1, REMARK_FONT).x)
	column.add_child(said)
	return row


## 話し手のアイコン（胸から上。対戦の途中の台詞の札と同じ）。
func _face(line: BattleCues.Line) -> TextureRect:
	var face := UnitIcons.rect(line.figure["kind"], line.side, false, REMARK_FACE)
	face.texture = UnitIcons.bust(line.figure["kind"], line.side, line.figure.get("evolved", false), line.figure.get("look", &""))
	return face
