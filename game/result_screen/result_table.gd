extends "res://game/result_screen/result_remark.gd"
## リザルトの画面の「詳しい戦績（両軍）」の表。


## 詳しい戦績を開く・閉じる。
func toggle_detail() -> void:
	_show_detail(not _detail_panel.visible)


func _show_detail(open: bool) -> void:
	_detail_panel.visible = open
	_stats_panel.visible = not open
	_mvp_panel.visible = not open
	_remark.visible = not open and not _remark_texts.is_empty()  # 詳しい戦績の表は横に広いので、台詞の板と重ねない
	_detail_button.text = Text.t("result.detail_back") if open else Text.t("result.detail_open")


## 詳しい戦績（両軍）: 全体の 1 行、陣営の切り替え、陣営の 1 行、駒ごとの表（行が駒、列が数。長ければ縦に送る）。
func _build_detail() -> void:
	_detail_panel = _panel(Palette.BORDER)
	_detail_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_detail_panel.visible = false
	_body.add_child(_detail_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	_detail_panel.add_child(column)
	_detail = _label(15)
	_detail.add_theme_color_override("font_color", COLOR_DIM)
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_detail)
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 8)
	column.add_child(tabs)
	for side in 2:
		var tab := Button.new()
		tab.toggle_mode = true
		tab.focus_mode = Control.FOCUS_NONE
		tab.custom_minimum_size = Vector2(220.0, 34.0)
		tab.add_theme_font_size_override("font_size", 16)
		tab.pressed.connect(func() -> void: show_table(side))
		tabs.add_child(tab)
		_table_tabs.append(tab)
	_table_summary = _label(15)
	_table_summary.add_theme_color_override("font_color", COLOR_DIM)
	_table_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_table_summary)
	var header_box := PanelContainer.new()
	header_box.add_theme_stylebox_override("panel", UiTheme.box(Color.TRANSPARENT, Color.TRANSPARENT, 0, UiTheme.CORNER, 2.0))
	column.add_child(header_box)
	var header := _table_line()
	header_box.add_child(header)
	var icon_room := Control.new()
	icon_room.custom_minimum_size = Vector2(TABLE_ICON, 0.0)
	header.add_child(icon_room)
	header.add_child(_table_cell(Text.t("result.table.unit"), TABLE_NAME_WIDTH, true, HORIZONTAL_ALIGNMENT_LEFT))
	for spec: Array in StatsText.COLUMNS:
		header.add_child(_table_cell(Text.t(spec[1]), TABLE_NUMBER_WIDTH, true))
	header.add_child(_table_cell("", TABLE_STATE_WIDTH, true))
	column.add_child(HSeparator.new())
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0.0, TABLE_HEIGHT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_table_rows = VBoxContainer.new()
	_table_rows.add_theme_constant_override("separation", 2)
	scroll.add_child(_table_rows)


## 詳しい戦績の表に、side の陣営の駒を出す（切り替えのボタンと同じ）。
func show_table(side: int) -> void:
	if _summary == null or _summary.tables.size() <= side:
		return
	_table_side = side
	for i in _table_tabs.size():
		_table_tabs[i].set_pressed_no_signal(i == side)
	var table: Dictionary = _summary.tables[side]
	_table_summary.text = table["summary"]
	for child in _table_rows.get_children():
		_table_rows.remove_child(child)
		child.queue_free()
	for index: int in table["rows"].size():
		_table_rows.add_child(_table_row(table["rows"][index], index % 2 == 1))


## いま表に出している陣営と、その行の駒の名前（検査用）。
func table_side() -> int:
	return _table_side


func table_names() -> Array[String]:
	var names: Array[String] = []
	for row in _table_rows.get_children():
		if not row.is_queued_for_deletion():
			names.append((row.get_child(0).get_child(1) as Label).text)
	return names


func _king_look(side: int) -> StringName:
	return king_looks[side] if side >= 0 and side < king_looks.size() else &""


## 表の 1 行（駒）。MVP の行は金の薄い地・左の金の線・金の文字、倒れた駒は名前を沈めて「倒れた」の印。
## striped は 1 行おきの薄い地（数を横に追いやすく）。
func _table_row(row: Dictionary, striped := false) -> Control:
	# どの行も同じ余白の地にして、列の位置をそろえる（左の線は余白の外へ描く）。
	var panel := PanelContainer.new()
	var fill := Color(Palette.ACCENT, 0.14) if row["mvp"] else (Color(Palette.WASH, 0.035) if striped else Color.TRANSPARENT)
	var plate := UiTheme.box(fill, Palette.ACCENT, 0, 4, 2.0)
	if row["mvp"]:
		plate.border_width_left = 3
		plate.expand_margin_left = 3.0
	panel.add_theme_stylebox_override("panel", plate)
	var line := _table_line()
	panel.add_child(line)
	var icon := UnitFrame.new(row["kind"], row["side"], TABLE_ICON, false, row["evolved"], _king_look(row["side"]))
	if row["side"] >= 0 and row["side"] < team_colors.size():
		icon.edge = Color(team_colors[row["side"]], 0.8)
	line.add_child(icon)
	var name_label := _table_cell(("★ " if row["mvp"] else "") + row["name"], TABLE_NAME_WIDTH, false, HORIZONTAL_ALIGNMENT_LEFT)
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	line.add_child(name_label)
	for spec: Array in StatsText.COLUMNS:
		var value: int = row[spec[0]]
		var cell := _table_cell(str(value) if value != 0 else "-", TABLE_NUMBER_WIDTH)
		if value != 0:
			cell.add_theme_font_override("font", UiTheme.FONT_BOLD)
		else:
			cell.add_theme_color_override("font_color", Palette.TEXT_OFF)
		line.add_child(cell)
	var state := _table_cell(Text.t("result.table.defeated") if row["defeated"] else "", TABLE_STATE_WIDTH, true)
	state.add_theme_color_override("font_color", Palette.DANGER.lerp(Palette.TEXT_DIM, 0.35))
	line.add_child(state)
	if row["defeated"] and not row["mvp"]:
		name_label.add_theme_color_override("font_color", COLOR_DIM)
	if row["mvp"]:
		for cell in line.get_children():
			if cell is Label and cell != state:
				(cell as Label).add_theme_color_override("font_color", COLOR_MVP)
	if row["defeated"]:
		icon.modulate.a = 0.45
	return panel


func _table_line() -> HBoxContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 6)
	line.custom_minimum_size = Vector2(0.0, TABLE_ROW_HEIGHT - 4.0)
	return line


func _table_cell(text: String, width: float, dim := false, align := HORIZONTAL_ALIGNMENT_RIGHT) -> Label:
	var label := _label(TABLE_NAME_FONT if not dim else TABLE_HEADING_FONT)
	label.text = text
	label.custom_minimum_size = Vector2(width, 0.0)
	label.clip_text = true  # 列の幅を中身で広げない（見出しと数の列がずれないように）
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_vertical = Control.SIZE_FILL
	if dim:
		label.add_theme_color_override("font_color", COLOR_DIM)
	return label
