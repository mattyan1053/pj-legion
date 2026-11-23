extends "res://game/battle_hud/hud_top_bar.gd"
## 対戦の画面の下の帯: マスの一行、操作の案内、ターン終了、必殺技、おまかせ、早送りとスキップ、脅威範囲と相手の切り替え。


## 必殺技のボタン（下の帯）。text はボタンの文字、enabled は押せるか。summary は必殺技の説明（必殺技が無ければ空）。
## 説明は、ボタンにマウスを乗せている間と、pinned が真の間（使うかを確かめている間）だけ、ボタンの上に出す。
## percent はゲージの溜まり具合（0〜100。負なら出さない）、side はその陣営。押せない間、ボタンの中に陣営の色で溜まり具合を出す。
func set_ult_button(text: String, enabled: bool, summary: String, pinned := false, percent := -1, side := Unit.Side.PLAYER1) -> void:
	_ult_button.text = text
	_ult_button.disabled = not enabled
	_ult_fill_ratio = clampf(percent / 100.0, 0.0, 1.0) if percent >= 0 and not enabled else -1.0
	_ult_fill_color = _side_color(side)
	_ult_fill.queue_redraw()
	_set_folded(_ult_summary, summary, ULT_SUMMARY_WIDTH)
	_ult_pinned = pinned
	_show_ult_summary()
	_fold_hint()


## 必殺技のボタンの中のゲージ（押せない間だけ）: 左から溜まり具合まで陣営の色を薄く敷き、下の辺に溝と陣営の色の棒。
## 溜まった先の端に、明るい細い線。
func _draw_ult_fill() -> void:
	if _ult_fill_ratio < 0.0:
		return
	var inset := 3.0
	var area := Rect2(Vector2(inset, inset), _ult_fill.size - Vector2(inset, inset) * 2.0)
	var filled := area.size.x * _ult_fill_ratio
	if filled > 0.0:
		_ult_fill.draw_rect(Rect2(area.position, Vector2(filled, area.size.y)), Color(_ult_fill_color, 0.26))
	var groove := Rect2(area.position.x, area.end.y - ULT_FILL_BAR, area.size.x, ULT_FILL_BAR)
	_ult_fill.draw_rect(groove, Color(Palette.INK, 0.9))
	if filled > 0.0:
		_ult_fill.draw_rect(Rect2(groove.position, Vector2(filled, ULT_FILL_BAR)), _ult_fill_color.lightened(0.25))
		_ult_fill.draw_rect(Rect2(area.position.x + filled - 1.0, area.position.y, 1.0, area.size.y), Color(_ult_fill_color.lightened(0.5), 0.6))


func _show_ult_summary() -> void:
	_ult_panel.visible = _ult_summary.text != "" and (_ult_pinned or _ult_button.is_hovered())


func ult_button_text() -> String:
	return _ult_button.text


func is_ult_enabled() -> bool:
	return not _ult_button.disabled


## マウスの下のマスの説明。盤の外なら空を渡す。
func show_cell(text: String) -> void:
	_cell_text = text
	_fold_cell()


## マスの説明を、案内と同じ幅で折り返す。行の数は、案内が 1 行なら 2 行まで、案内が 2 行なら 1 行（帯の高さは変えない）。
## 入らなければ字を小さくし、それでも入らなければ、最後の行を「…」で切る。
func _fold_cell() -> void:
	if _cell_label == null:
		return
	var font := _cell_label.get_theme_font("font")
	var room := _hint_room()
	var lines := 1 if _hint_label.text.contains("\n") else 2
	var folded := ""
	for size: int in [CELL_FONT_SIZE, CELL_FONT_SIZE_SMALL]:
		folded = TextWrap.fold(_cell_text, room, func(character: String) -> float: return _char_width(font, size, character))
		_cell_label.add_theme_font_size_override("font_size", size)
		if folded.count("\n") < lines:
			break
	_cell_label.max_lines_visible = lines
	_cell_label.text = folded


## マスの説明のうち、帯に収まらずに切れる行（3 行目から）。検査用。
func cell_cut_lines() -> Array[String]:
	var cut: Array[String] = []
	cut.assign(Array(_cell_label.text.split("\n")).slice(_cell_label.max_lines_visible))
	return cut


## 下の帯に出しているマスの説明（折り返したあと）。検査用。
func cell_line_text() -> String:
	return _cell_label.text


func set_hint(text: String) -> void:
	_hint_text = text
	_fold_hint()


## 案内を、いま使える幅で折り返し直す。右のボタンの文字や出し入れが変わると、使える幅も変わるので、そのたびに呼ぶ。
func _fold_hint() -> void:
	if _hint_label != null:
		# 2 行に分かれるときは、行の長さをそろえる（2 行目に 1 語だけ残さない）。
		var font := _hint_label.get_theme_font("font")
		var font_size := _hint_label.get_theme_font_size("font_size")
		_hint_label.text = TextWrap.fold_even(_hint_text, _hint_room(), func(character: String) -> float: return _char_width(font, font_size, character))
		_fold_cell()  # 案内の行の数で、マスの説明の字の大きさが変わる


## 下の帯の案内のうち、案内に使える幅に収まらない行（3 行目からは、収まっていても切れる）。検査用。
func hint_cut_lines() -> Array[String]:
	var font := _hint_label.get_theme_font(&"font")
	var font_size := _hint_label.get_theme_font_size(&"font_size")
	var room := _hint_room()
	var cut: Array[String] = []
	var lines := _hint_label.text.split("\n")
	for i in lines.size():
		if i >= _hint_label.max_lines_visible or font.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > room + 0.5:
			cut.append(lines[i])
	return cut


## 下の帯で、案内に使える幅: 帯の幅から、右のボタンとスイッチ（出ているもの）の幅と間を引いた残り。
## 並べ直しを待たずに求める（ボタンの文字が変わった直後にも正しい）。
func _hint_room() -> float:
	var column := _hint_label.get_parent() as Control
	var row := column.get_parent() as HBoxContainer
	var panel := row.get_parent() as Control
	var room := panel.get_viewport_rect().size.x - panel.get_theme_stylebox(&"panel").get_minimum_size().x
	var shown := row.get_children().filter(func(child: Node) -> bool: return (child as Control).visible)
	room -= row.get_theme_constant(&"separation") * (shown.size() - 1)
	for child: Control in shown:
		if child != column:
			room -= child.get_combined_minimum_size().x
	return room


## ターン終了のボタン。ready が真なら、明るくして目立たせる（動かせる駒が残っていないとき）。
func set_end_turn(enabled: bool, text: String, ready := false) -> void:
	_end_turn_button.disabled = not enabled
	_end_turn_button.text = text
	_end_turn_style.bg_color = COLOR_END_TURN_READY if ready else COLOR_END_TURN
	_fold_hint()


## 相手の番の「早送り」「スキップ」を出すか（出している間は、必殺技のボタンを隠す）。fast は早送りが入っているか、
## can_skip はスキップを押せるか（スキップの途中は「スキップ中…」にして押せない）。
func set_watch_controls(shown: bool, fast: bool, can_skip: bool) -> void:
	_watch_box.visible = shown
	_ult_button.visible = not shown
	_auto_button.visible = not shown
	_fast_button.set_pressed_no_signal(fast)
	_skip_button.disabled = not can_skip
	_skip_button.text = Text.t("battle.hud.skip") if can_skip else Text.t("battle.hud.skipping")
	_fold_hint()


## 自分の番の「おまかせ」。confirming なら、もう一度押すと任せる、の形にする。
func set_auto_button(enabled: bool, confirming: bool) -> void:
	_auto_button.disabled = not enabled
	_auto_button.text = Text.t("battle.hud.auto_confirm") if confirming else Text.t("battle.hud.auto")
	_fold_hint()


## 「おまかせ」の文字と、押せるか。検査用。
func auto_button_state() -> Array:
	return [_auto_button.text, not _auto_button.disabled]


## 相手の番の「早送り」「スキップ」: [出ているか, 早送りが入っているか]。検査用。
func watch_controls_state() -> Array[bool]:
	return [_watch_box.visible, _fast_button.button_pressed]


## 相手の番の「スキップ」を押す（クリックと同じ道）。出ていて押せれば真。検査用。
func press_skip() -> bool:
	if not _watch_box.visible or _skip_button.disabled:
		return false
	_skip_button.pressed.emit()
	return true


## 敵の全員の脅威範囲の切り替えを、出しているかに合わせる。
func set_threat_button(shown: bool) -> void:
	_threat_button.set_pressed_no_signal(shown)
	_fold_hint()


func end_turn_text() -> String:
	return _end_turn_button.text


## 相手を切り替えるボタンの文字（いまの相手を書く）。空なら、ボタンを出さない（切り替えられない対戦）。
func set_opponent(text: String) -> void:
	_opponent_button.text = text
	_opponent_button.visible = text != ""
	_fold_hint()


## 相手を切り替えるボタンを出しているか。検査用。
func opponent_shown() -> bool:
	return _opponent_button.visible


func _build_bottom() -> void:
	var panel := _panel()
	var band := UiTheme.band_box(false)
	band.content_margin_top = BOTTOM_BAR_MARGIN
	band.content_margin_bottom = BOTTOM_BAR_MARGIN
	panel.add_theme_stylebox_override("panel", band)
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.custom_minimum_size = Vector2(0.0, BOTTOM_BAR_HEIGHT)
	Steady.mark(panel, "battle.bottom_band", Steady.RECT)
	add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	# 案内の頭の、金の細い線（案内の欄がどこから始まるかの目印。幅は _hint_room が引く）。
	var hint_mark := ColorRect.new()
	hint_mark.color = Palette.BORDER_BRIGHT
	hint_mark.custom_minimum_size = Vector2(3.0, 44.0)
	hint_mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hint_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(hint_mark)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(column)
	# いまできること。長ければ 2 行まで折り返す（ボタンを画面の外へ押し出さない）。
	_hint_label = _label(17)
	_hint_label.max_lines_visible = 2
	_hint_label.clip_text = true
	column.add_child(_hint_label)
	# マウスの下のマスの説明。長ければ 2 行まで折り返す（拠点の説明のように長いものも読める。_fold_cell）。
	_cell_label = _label(CELL_FONT_SIZE)
	_cell_label.max_lines_visible = 2
	_cell_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_cell_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	column.add_child(_cell_label)

	# 駒に属さない操作は、いつも同じ場所（右下）に置く。
	# 敵の全員の脅威範囲の切り替え。入・切が見て分かるよう、スイッチの形にする。
	_threat_button = CheckButton.new()
	_threat_button.text = Text.t("battle.hud.threat")
	_threat_button.focus_mode = Control.FOCUS_NONE
	_threat_button.add_theme_font_size_override("font_size", 17)
	_threat_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_threat_button.tooltip_text = Text.t("battle.hud.threat.tooltip")
	_threat_button.pressed.connect(threat_toggled.emit)
	row.add_child(_threat_button)
	_watch_box = HBoxContainer.new()
	_watch_box.add_theme_constant_override("separation", 8)
	_watch_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_watch_box.visible = false
	row.add_child(_watch_box)
	_fast_button = _button(Text.t("battle.hud.fast"), fast_forward_toggled)
	_fast_button.toggle_mode = true
	_fast_button.custom_minimum_size = Vector2(120.0, 44.0)
	_fast_button.theme_type_variation = UiTheme.BUTTON_GHOST
	_fast_button.tooltip_text = Text.t("battle.hud.fast.tooltip")
	_watch_box.add_child(_fast_button)
	_skip_button = _button(Text.t("battle.hud.skip"), skip_pressed)
	_skip_button.custom_minimum_size = Vector2(120.0, 44.0)
	_skip_button.theme_type_variation = UiTheme.BUTTON_GHOST
	_skip_button.tooltip_text = Text.t("battle.hud.skip.tooltip")
	_watch_box.add_child(_skip_button)
	_ult_button = _button(Text.t("battle.hud.ult"), ult_pressed)
	_ult_button.custom_minimum_size = Vector2(220.0, 48.0)
	_ult_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_ult_button.disabled = true
	# 押せるとき（ゲージが READY）は、金の縁と金の文字（押せない間は、テーマの押せない形）。
	var ult_ready := UiTheme.box(Palette.CHOSEN, Palette.ACCENT, 2, UiTheme.CORNER, 6.0, 4)
	_ult_button.add_theme_stylebox_override("normal", ult_ready)
	var ult_hover := ult_ready.duplicate() as StyleBoxFlat
	ult_hover.bg_color = Palette.CHOSEN.lightened(0.12)
	_ult_button.add_theme_stylebox_override("hover", ult_hover)
	_ult_button.add_theme_color_override("font_color", Palette.ACCENT)
	_ult_button.add_theme_color_override("font_hover_color", Palette.ACCENT)
	_ult_button.add_theme_font_override("font", UiTheme.FONT_BOLD)
	_ult_fill = Control.new()
	_ult_fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ult_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ult_fill.draw.connect(_draw_ult_fill)
	_ult_button.add_child(_ult_fill)
	_ult_button.mouse_entered.connect(_show_ult_summary)
	_ult_button.mouse_exited.connect(_show_ult_summary)
	row.add_child(_ult_button)
	_auto_button = _button(Text.t("battle.hud.auto"), auto_pressed)
	_auto_button.custom_minimum_size = Vector2(112.0, 44.0)
	_auto_button.theme_type_variation = UiTheme.BUTTON_GHOST
	_auto_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_auto_button.tooltip_text = Text.t("battle.hud.auto.tooltip")
	_auto_button.disabled = true
	row.add_child(_auto_button)
	# ターン終了は、見つけやすいよう色を付けて、いちばん端に置く（駒のそばのメニューからは離れている）。
	_end_turn_button = _button(Text.t("battle.hud.end_turn"), end_turn_pressed)
	_end_turn_button.custom_minimum_size = Vector2(210.0, 60.0)
	_end_turn_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_end_turn_button.add_theme_font_size_override("font_size", 21)
	_end_turn_button.add_theme_font_override("font", UiTheme.FONT_BOLD)
	_end_turn_style = UiTheme.box(COLOR_END_TURN, COLOR_END_TURN_READY.lightened(0.3), 2, 8, 6.0, 4)
	_end_turn_button.add_theme_stylebox_override("normal", _end_turn_style)
	_end_turn_button.add_theme_stylebox_override("hover", _end_turn_style)
	row.add_child(_end_turn_button)

	# 必殺技の説明。ボタンの上に、マウスを乗せている間と、使うかを確かめている間だけ出す。
	_ult_panel = _panel(COLOR_PANEL_SOLID)
	_ult_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_ult_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_ult_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_ult_panel.offset_left = -10.0
	_ult_panel.offset_right = -10.0
	_ult_panel.offset_top = -BOTTOM_BAR_HEIGHT - 8.0
	_ult_panel.offset_bottom = -BOTTOM_BAR_HEIGHT - 8.0
	_ult_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ult_panel.visible = false
	add_child(_ult_panel)
	_ult_summary = _label(15)
	_ult_panel.add_child(_ult_summary)
