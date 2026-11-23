extends "res://game/result_screen/result_actions.gd"
## リザルトの画面。決着したら、対戦の画面（盤面）の上に重ねて、段階的に出す（result_summary.gd の中身）。
##
## 1. 勝敗の見出し（VICTORY / DEFEAT、人どうしは勝った側の名前）が中央に大きく出て、上へ退く。
## 2. 戦績（マップ・経過ターン・敵軍撃破・中立撃破・聖遺物）が 1 行ずつ出る。
## 3. MVP が拡大しながら出る。
## 4. 行き先のボタンと、入力の案内が出る。**ここまで出そろうまで、行き先は選べない。**
## 出そろう前のクリック（Enter・Space でも）は、演出を飛ばして全部を出すだけ（行き先は選ばない）。
## 出そろったあとの Enter は、「次へ」を出していればそれ、「同じマップで再戦」にすると決めていればそれ（ストーリーで負けたとき）、
## どちらでもなければタイトルへ（ボタンの「タイトルへ」と同じ）。Enter で選ぶボタンは、文字を大きくして目立たせる。両方の陣営の詳しい戦績は畳んでおき、ボタンで開く。
##
## 何を出すかは呼ぶ側（result_summary.gd）が決める。ここは見せ方と、押されたことを signal で知らせるだけ。
##
## ここは、段階的に出す流れ（present・飛ばす・入力）と、戦績と MVP の組み立てだけ。部分ごとのファイル（game/result_screen/result_*.gd）:
## 決着のあとのひとこと（result_remark）、詳しい戦績の表（result_table）、行き先のボタン（result_actions）。
## 読み込み・知らせ・調整値・部品の変数と部品を作る道具は result_base。ファイルは result_base.gd からこの順に継いで積み重なり、
## このファイルが最後（前のファイルは、後のファイルの関数を呼べない）。


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP  # 後ろの盤面へクリックを通さない
	visible = false
	_shade = ColorRect.new()
	_shade.color = COLOR_SHADE
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shade)
	_glow = ResultGlow.new()
	add_child(_glow)

	_headline = _label(76)
	_headline.theme_type_variation = UiTheme.LABEL_HEADING
	_headline.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_headline.add_theme_constant_override("outline_size", 14)
	add_child(_headline)
	_reason = _label(20)
	_reason.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_reason)

	_body = VBoxContainer.new()
	_body.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_body.offset_top = BODY_TOP
	_body.add_theme_constant_override("separation", 6)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_body)
	_build_stats()
	_build_mvp()
	_build_detail()
	_build_actions()
	_build_remark()


## summary（result_summary.gd）を、段階的に出し始める。
func present(summary: RefCounted) -> void:
	_summary = summary
	_revealed = false
	_skipped = false
	_elapsed = 0.0
	if _tween != null:
		_tween.kill()
	_headline.text = summary.headline
	_headline.add_theme_color_override("font_color", _headline_color(summary))
	# 後ろの光と粒: 勝ち（どちらかの陣営の勝ちも）は光と紙吹雪、負けは沈めて灰、引き分けは無し。
	if summary.tone == ResultSummary.Tone.DEFEAT:
		_glow.play(false, _headline_color(summary))
	elif summary.tone == ResultSummary.Tone.VICTORY or summary.tone == ResultSummary.Tone.SIDE:
		_glow.play(true, _headline_color(summary))
	else:
		_glow.stop()
	_reason.text = summary.reason
	_stats_title.text = Text.t("result.stats_title", {"side": summary.focus_name})
	for row: Array in _stat_rows:
		for label: Label in row:
			label.queue_free()
	_stat_rows.clear()
	for label: Label in _stat_pads:
		label.queue_free()
	_stat_pads.clear()
	for line: Array in summary.lines:
		var name_label := _label(18)
		name_label.text = line[0]
		name_label.add_theme_color_override("font_color", COLOR_DIM)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		name_label.custom_minimum_size = Vector2(130.0, 0.0)
		var value_label := _label(STAT_FONT)
		value_label.add_theme_font_override("font", UiTheme.FONT_BOLD)
		value_label.text = line[1]
		_stats_grid.add_child(name_label)
		_stats_grid.add_child(value_label)
		_stat_rows.append([name_label, value_label])
	# 行の少ない戦績でも、上限の行の数ぶんの高さを取る（空の行で埋める。戦績の枠の大きさを中身で変えない）。
	for i in range(summary.lines.size(), ResultSummary.MAX_LINES):
		var name_label := _label(18)
		var value_label := _label(STAT_FONT)
		value_label.add_theme_font_override("font", UiTheme.FONT_BOLD)
		value_label.text = " "
		_stats_grid.add_child(name_label)
		_stats_grid.add_child(value_label)
		_stat_pads.append_array([name_label, value_label])
	_mvp_icon.visible = summary.mvp_name != ""
	if summary.mvp_name != "":
		_mvp_icon.set_kind(summary.mvp_kind, summary.mvp_side, summary.mvp_evolved, _king_look(summary.mvp_side))
		_mvp_icon.edge = team_colors[summary.mvp_side] if summary.mvp_side >= 0 and summary.mvp_side < team_colors.size() else Color(0, 0, 0, 0)
		_mvp_name.text = summary.mvp_name
		_mvp_numbers.text = summary.mvp_numbers
	else:
		_mvp_name.text = Text.t("result.mvp_none")
		_mvp_numbers.text = Text.t("result.mvp_none_note")
	_detail.text = summary.detail_head
	for side in _table_tabs.size():
		_table_tabs[side].text = summary.tables[side]["name"] if side < summary.tables.size() else ""
	show_table(summary.focus_side if summary.focus_side >= 0 and summary.focus_side < 2 else 0)
	_detail_text = summary.detail
	_show_detail(false)

	# 始めの形: 見出しは中央で透明、ほかは場所を取ったまま透明（出るときに配置が動かないように）。
	_shade.modulate.a = 0.0
	_glow.modulate.a = 0.0
	_headline.modulate.a = 0.0
	_headline.position.y = HEADLINE_CENTER_Y
	_headline.scale = Vector2.ONE * 1.25
	_reason.modulate.a = 0.0
	_stats_panel.modulate.a = 0.0
	for row: Array in _stat_rows:
		for label: Label in row:
			label.modulate.a = 0.0
	_mvp_panel.modulate.a = 0.0
	_actions.modulate.a = 0.0
	set_remark([])  # 台詞は、出したあとで対戦の画面が渡す（負けた話だけ）
	_set_buttons_enabled(false)
	visible = true
	# 大きさが決まってから、見出しの拡大の中心を決める。
	await get_tree().process_frame
	if _summary != summary:
		return
	_headline.pivot_offset = _headline.size / 2.0
	_place_reason()
	_stage()


## 段階を、出し始めてからの時刻で並べる（どれも、始めからの時刻で置く）。
func _stage() -> void:
	_tween = create_tween().set_parallel(true)
	var t := _tween
	# 1. 勝敗の見出し
	t.tween_property(_shade, "modulate:a", 1.0, 0.35)
	t.tween_property(_glow, "modulate:a", 1.0, GLOW_IN).set_delay(0.1)
	t.tween_property(_headline, "modulate:a", 1.0, HEADLINE_IN)
	t.tween_property(_headline, "scale", Vector2.ONE, HEADLINE_IN).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_reason, "modulate:a", 1.0, HEADLINE_IN).set_delay(0.15)
	# 上へ退く
	t.tween_property(_headline, "position:y", HEADLINE_TOP_Y, RISE_TIME).set_delay(HEADLINE_RISE_AT) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_headline, "scale", Vector2.ONE * HEADLINE_SHRUNK, RISE_TIME).set_delay(HEADLINE_RISE_AT) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	t.tween_method(func(_v: float) -> void: _place_reason(), 0.0, 1.0, RISE_TIME).set_delay(HEADLINE_RISE_AT)
	# 2. 戦績を 1 行ずつ
	t.tween_property(_stats_panel, "modulate:a", 1.0, 0.2).set_delay(STATS_AT)
	t.tween_property(_remark, "modulate:a", 1.0, 0.3).set_delay(STATS_AT)
	var at := STATS_AT + 0.1
	for row: Array in _stat_rows:
		t.tween_callback(_sound.bind(&"ui_click")).set_delay(at)
		for label: Label in row:
			t.tween_property(label, "modulate:a", 1.0, 0.18).set_delay(at)
		at += STAT_GAP
	# 3. MVP
	at += MVP_GAP
	t.tween_callback(func() -> void:
		_mvp_panel.pivot_offset = _mvp_panel.size / 2.0
		_sound(&"relic")).set_delay(at)
	t.tween_property(_mvp_panel, "modulate:a", 1.0, MVP_IN * 0.6).set_delay(at)
	t.tween_property(_mvp_panel, "scale", Vector2.ONE, MVP_IN).from(Vector2.ONE * 0.6).set_delay(at) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# 4. 行き先と、入力の案内
	at += MVP_IN + PROMPT_GAP
	t.tween_property(_actions, "modulate:a", 1.0, 0.25).set_delay(at)
	t.tween_callback(_on_revealed).set_delay(at + 0.25)


## 全部が出そろったか（行き先を選べるか）。
func is_revealed() -> bool:
	return _revealed


## 演出を飛ばして、全部を出す（出そろっていれば何もしない）。飛ばした直後の少しの間は、行き先のボタンを押せない。
func skip() -> void:
	if not visible or _revealed:
		return
	_skipped = true
	if _tween != null and _tween.is_valid():
		_tween.custom_step(60.0)
	elif _summary != null:
		# まだ始まっていない（大きさを決める 1 フレームの間）。始めてから飛ばす。
		await get_tree().process_frame
		if _tween != null and _tween.is_valid():
			_tween.custom_step(60.0)


## 演出を、出し始めてから seconds 秒のところで止める（スクリーンショットの道具が、段階ごとに撮るのに使う）。
func hold_at(seconds: float) -> void:
	while visible and (_tween == null or not _tween.is_valid()):
		await get_tree().process_frame
	if _tween != null and _tween.is_valid():
		_tween.pause()
		_tween.custom_step(seconds)


## いま出しているもの（result_summary.gd。出ていなければ null）。
func shown_summary() -> RefCounted:
	return _summary if visible else null


func hide_result() -> void:
	if _tween != null:
		_tween.kill()
	_summary = null
	_revealed = false
	visible = false


## いま出ている見出し（出ていなければ空）。検査用。
func headline() -> String:
	return _headline.text if visible else ""


## いま出している詳しい戦績（出ていなければ空。畳んでいても返す）。検査用。
func detail_text() -> String:
	return _detail_text if visible else ""


## 戦績の行の文字（[項目, 値] の列）。検査用。
func stat_lines() -> Array:
	return _summary.lines if visible and _summary != null else []


## MVP の名前（いなければ「該当なし」）。検査用。
func mvp_text() -> String:
	return _mvp_name.text if visible else ""


## 押せる行き先のボタンの文字（出そろう前は空）。検査用。
func enabled_buttons() -> Array[String]:
	var texts: Array[String] = []
	for button in _buttons:
		if button.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			texts.append(button.text)
	return texts


func is_detail_open() -> bool:
	return _detail_panel.visible


func _process(delta: float) -> void:
	if not visible:
		return
	_elapsed += delta
	if _revealed:
		_prompt.modulate.a = 0.45 + 0.55 * (0.5 + 0.5 * cos(_elapsed * TAU / BLINK_PERIOD))


func _gui_input(event: InputEvent) -> void:
	# 出そろう前のクリックは、飛ばすだけ（ボタンは押せないので、ここへ届く）。
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not _revealed:
		skip()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or (overlays != null and overlays.is_open()):
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if not _revealed:
				skip()
			elif event.physical_keycode != KEY_SPACE and _buttons_ready():
				if _continue_button.visible:
					press_continue()
				elif _enter_retries:
					press_again()
				else:
					title_pressed.emit()
			get_viewport().set_input_as_handled()


func _on_revealed() -> void:
	_revealed = true
	_elapsed = 0.0
	if _skipped:
		await get_tree().create_timer(SKIP_GUARD, true, false, true).timeout
		if not _revealed:
			return
	_set_buttons_enabled(true)
	revealed.emit()


func _headline_color(summary: RefCounted) -> Color:
	match summary.tone:
		ResultSummary.Tone.VICTORY:
			return COLOR_VICTORY
		ResultSummary.Tone.DEFEAT:
			return COLOR_DEFEAT
		ResultSummary.Tone.SIDE:
			if summary.winner < team_colors.size():
				return team_colors[summary.winner].lightened(0.4)
	return COLOR_DRAW


func _build_stats() -> void:
	_stats_panel = _panel(Palette.BORDER)
	_stats_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_stats_panel.custom_minimum_size = Vector2(460.0, 0.0)
	Steady.mark(_stats_panel, "result.stats")
	_body.add_child(_stats_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	_stats_panel.add_child(column)
	_stats_title = _label(17)
	_stats_title.theme_type_variation = UiTheme.LABEL_SECTION
	column.add_child(_flanked(_stats_title, Palette.BORDER_BRIGHT))
	_stats_grid = GridContainer.new()
	_stats_grid.columns = 2
	_stats_grid.add_theme_constant_override("h_separation", 18)
	_stats_grid.add_theme_constant_override("v_separation", 0)
	_stats_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_stats_grid)


func _build_mvp() -> void:
	_mvp_panel = _panel(Color(Palette.BORDER_BRIGHT, 0.85))
	_mvp_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_mvp_panel.custom_minimum_size = Vector2(460.0, 0.0)
	Steady.mark(_mvp_panel, "result.mvp")
	_body.add_child(_mvp_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	_mvp_panel.add_child(column)
	_mvp_head = _label(24)
	_mvp_head.text = "★ M V P ★"
	_mvp_head.add_theme_font_override("font", UiTheme.FONT_HEADING)
	_mvp_head.add_theme_color_override("font_color", COLOR_MVP)
	column.add_child(_flanked(_mvp_head, COLOR_MVP))
	# アイコン（左）と、名前・数（右）を 1 段に並べる（アイコンのぶん、枠を高くしない）。
	var mvp_row := HBoxContainer.new()
	mvp_row.alignment = BoxContainer.ALIGNMENT_CENTER
	mvp_row.add_theme_constant_override("separation", 10)
	column.add_child(mvp_row)
	_mvp_icon = UnitFrame.new(UnitKind.Id.KING, 0, 64.0)
	mvp_row.add_child(_mvp_icon)
	var mvp_lines := VBoxContainer.new()
	mvp_lines.add_theme_constant_override("separation", 0)
	mvp_lines.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mvp_row.add_child(mvp_lines)
	_mvp_name = _label(28)
	_mvp_name.add_theme_font_override("font", UiTheme.FONT_BOLD)
	_mvp_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mvp_lines.add_child(_mvp_name)
	_mvp_numbers = _label(19)
	_mvp_numbers.add_theme_color_override("font_color", COLOR_DIM)
	_mvp_numbers.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mvp_lines.add_child(_mvp_numbers)
