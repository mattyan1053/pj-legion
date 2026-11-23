extends "res://game/match_setup_panel/setup_panel_choices.gd"
## 対戦の前に、相手・手番・軍・部隊を選ぶ、飾らない最小の画面。マップは、マップ選択で選んだものを出すだけ
## （変えるのは「マップを選び直す」。マップ選択の場面へ戻る）。
##
## 選んだもの（match_choice.gd）を持ち、「対戦を始める」で start_pressed を出す。ルールは持たない。
## どちらの行も、軍を選んだあと、その軍の部隊を、既定の編成（CPU の行では「CPU の編成」）、ランダム編成、取っておいた部隊（deck_library.gd）から選ぶ。
## 出せない部隊は、理由つきで並べ、選べなくする。人どうしでも CPU 戦でも、同じ選び方と見え方。
## 部隊の中身は、パネルに文で並べず、「編成を確認」で開く（deck_preview.gd。自分の部隊も CPU の部隊も同じ見え方）。
## パネルの大きさは、選んだものに依らず同じ（部隊の名前は決まった幅で切る）。
## 対戦の途中で開いたときは、押すといまの対戦が終わるボタン（「マップを選び直す」「新しい対戦を始める」）を 2 回押させる
## （ターン終了・必殺技の確かめと同じ。docs/battle-view.md）。1 回目でボタンが「もう一度押す」になり、理由は下の文に出す。
##
## ここは、組み立て（setup）、開く・閉じる・入力、始める、マップを選び直す、行の組み立てだけ。
## 選ぶことと選んだものの映し方、部隊の寄り道は game/match_setup_panel/setup_panel_choices.gd、
## 読み込み・知らせ・調整値・部品の変数と小さな道具は setup_panel_base.gd。setup_panel_base.gd → setup_panel_choices.gd → このファイルの順に継ぐ。


## overlays は、開いている重なる画面の積み上げ（AppContext.overlays）。見えている間（visible）は、時間を止めない重なりとして積む。
func setup(team_colors: Array[Color], library: RefCounted, overlays: RefCounted) -> void:
	_team_colors = team_colors
	_library = library
	_overlays = overlays
	visibility_changed.connect(_track_overlay)
	_track_overlay()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Palette.SHADE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var style := UiTheme.solid_box(18.0)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	panel.add_child(column)

	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	Steady.mark(panel, "setup.panel", Steady.RECT)
	_panel = panel
	var title := _label(28)
	title.theme_type_variation = UiTheme.LABEL_HEADING
	title.text = Text.t("setup.title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	# どの軍とどの軍が、どのマップで戦うか（下の行で選んだものが、すぐここに出る）。
	_banner = VersusBanner.new()
	column.add_child(_banner)

	var map_row := _caption_row(column, Text.t("setup.caption.map"))
	_map_name = _label(18)
	_map_name.custom_minimum_size = Vector2(PICKER_WIDTH, 0.0)
	_map_name.clip_text = true
	_map_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	map_row.add_child(_map_name)
	_map_button = _button(Text.t(MAP_TEXT))
	_map_button.custom_minimum_size = Vector2(200.0, 40.0)
	_map_button.pressed.connect(press_map)
	map_row.add_child(_map_button)
	_add_row(column, Text.t("setup.caption.opponent"), &"opponent", {true: "CPU", false: Text.t("setup.opponent.human")})
	var side_row := _add_row(column, Text.t("setup.caption.side"), &"human_side", {
		Unit.Side.PLAYER1: Text.t("setup.side.first"), Unit.Side.PLAYER2: Text.t("setup.side.second"), RANDOM_SIDE: Text.t("setup.side.random"),
	})
	_side_caption = side_row.get_child(0) as Label
	# 選べる決まり（docs/match-setup.md の「選べる決まり」）。決まりごとに 1 行: 「あり」「なし」と、右に決まりのひとことの説明（決まった大きさ）。
	for rule: StringName in RULE_ROWS:
		var rule_row := _add_row(column, Text.t("setup.caption.%s" % rule), StringName("rule_%s" % rule),
			{true: Text.t("setup.rule.on"), false: Text.t("setup.rule.off")})
		for button: Button in (_rows[StringName("rule_%s" % rule)] as Dictionary).values():
			button.custom_minimum_size = Vector2(TRIAL_BUTTON_WIDTH, TRIAL_BUTTON_HEIGHT)
			button.add_theme_font_size_override("font_size", 15)
		var note := _label(13)
		note.text = rule_note(rule)
		note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.max_lines_visible = 1
		note.custom_minimum_size = TRIAL_NOTE_SIZE
		Steady.mark(note, "setup.rule_note")
		rule_row.add_child(note)
		_rule_notes[rule] = note
	# 対戦モードの先手が必殺技のゲージをためて始まるなら（Ults.FIRST_PLAYER_START_GAUGE が 0 より大きい）、手番の行の右に書いておく。
	# 2 行にして、ボタンの高さに収める（行もパネルも大きくしない）。
	_first_gauge_note = _label(14)
	_first_gauge_note.text = first_gauge_note()
	_first_gauge_note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_first_gauge_note.visible = not _first_gauge_note.text.is_empty()
	side_row.add_child(_first_gauge_note)
	for side in 2:
		# 軍と部隊の 2 行は、プレイヤーごとに 1 つの板にまとめる（左の縁に陣営の色。_show_choice）。
		var side_box := PanelContainer.new()
		Steady.mark(side_box, "setup.side")
		column.add_child(side_box)
		_side_boxes.append(side_box)
		var side_column := VBoxContainer.new()
		side_column.add_theme_constant_override("separation", 4)
		side_box.add_child(side_column)
		var names := {}
		for army in ARMIES:
			names[army] = Names.army(army)
		var row := _add_row(side_column, "", StringName("army%d" % side), names)
		_who_labels.append(row.get_child(0) as Label)
		(row.get_child(0) as Label).add_theme_font_override("font", UiTheme.FONT_BOLD)
		var deck_row := _caption_row(side_column, Text.t("setup.caption.deck"))
		var picker := OptionButton.new()
		picker.focus_mode = Control.FOCUS_NONE
		picker.add_theme_font_size_override("font_size", 17)
		picker.custom_minimum_size = Vector2(PICKER_WIDTH, 40.0)
		picker.fit_to_longest_item = false
		picker.clip_text = true
		picker.get_popup().add_theme_font_size_override("font_size", 17)
		var picked_side := side
		picker.item_selected.connect(func(index: int) -> void: _on_deck_picked(picked_side, index))
		deck_row.add_child(picker)
		_deck_pickers.append(picker)
		var look := _button(Text.t("setup.deck_preview"))
		look.pressed.connect(func() -> void: open_preview(picked_side))
		deck_row.add_child(look)
		_preview_buttons.append(look)
		var place := _button(Text.t("setup.placement"))
		place.pressed.connect(func() -> void: open_placement(picked_side))
		deck_row.add_child(place)
		_placement_buttons.append(place)
		var edit := _button(Text.t("setup.edit_deck"))
		edit.custom_minimum_size = Vector2(170.0, 40.0)
		edit.pressed.connect(func() -> void: press_edit_decks(picked_side))
		deck_row.add_child(edit)
		_edit_buttons.append(edit)

	# 対戦の途中で開いたときは、始めるといまの対戦が失われることを書く。
	_warning = _label(15)
	_warning.text = Text.t(WARNING_TEXT)
	_warning.add_theme_color_override("font_color", Palette.WARN)
	_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_warning)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(buttons)
	_back_button = _button(Text.t("setup.back_to_battle"))
	_back_button.custom_minimum_size = Vector2(220.0, 46.0)
	_back_button.pressed.connect(cancel)
	buttons.add_child(_back_button)
	_start_button = _button(Text.t("setup.start"))
	_start_button.custom_minimum_size = Vector2(220.0, 46.0)
	_start_button.set_meta(&"sound", &"ui_confirm")  # 決める音（sound.gd）
	_start_button.theme_type_variation = UiTheme.BUTTON_PRIMARY
	_start_button.pressed.connect(press_start)
	buttons.add_child(_start_button)
	_preview = DeckPreview.new()
	add_child(_preview)
	_preview.setup(overlays)
	_placement = DeployDialog.new()
	add_child(_placement)
	_placement.setup(overlays)
	_placement.closed.connect(func() -> void:
		if _placing_row != -1:
			_choice.placements[_placing_row] = _placement.offsets()
		_placing_row = -1
		_show_choice())
	_show_choice()


## いまの選択を choice の写しにして、画面を出す。開いただけでは、何も変わらない。
## cancellable が真なら、「対戦へ戻る」（右クリック・Esc でも）で、何も変えずに閉じられる。
## in_progress が真なら（決着していない対戦の途中）、始めるといまの対戦が失われることを書く。
## back_text は閉じるボタンの文字（対戦設定の場面では「マップ選択へ戻る」）。閉じるボタンがマップ選択へ行くときは、
## 「マップ変更」を出さない（同じ所へ行くボタンを 2 つ並べない）。new_battle が真なら、始めるボタンを「新しい対戦を始める」にする
## （対戦の途中から開いたとき）。対戦の途中から開いたときは「部隊編成」を出さない（対戦設定の場面だけ）。
func open(choice: RefCounted, cancellable := false, in_progress := false, back_text := "", new_battle := true) -> void:
	_choice = choice.copy()
	_can_edit_decks = not (cancellable and new_battle)
	_preview.close_preview()
	_choice.refresh_decks(_library)  # 編成の画面で消した・組み直した部隊に合わせる
	_cancellable = cancellable
	_in_progress = cancellable and in_progress
	_back_button.visible = cancellable
	_back_button.text = back_text if back_text != "" else Text.t("setup.back_to_battle")
	_map_button.visible = back_text == ""
	_warning.visible = _in_progress
	_start_text = Text.t("setup.start_new") if cancellable and new_battle else Text.t("setup.start")
	_confirming = null
	_show_choice()
	visible = true


## 何も変えずに閉じる（閉じられるときだけ）。
func cancel() -> void:
	if not visible or not _cancellable:
		return
	visible = false
	cancelled.emit()


## 見えているかに合わせて、重なる画面の積み上げに積む・降ろす（開く・閉じるのどの道でも、見えなくなれば降ろす）。
func _track_overlay() -> void:
	if visible and is_inside_tree():
		_overlays.open(self)
	else:
		_overlays.close(self)


func _exit_tree() -> void:
	if _overlays != null:
		_overlays.close(self)


## 閉じられるか。検査用。
func is_cancellable() -> bool:
	return _cancellable


## 右クリックと Esc は、ほかの画面と同じに「戻す」（閉じられるときだけ）。開いている間は、盤面へ通さない。
## 確かめの途中なら、閉じずに確かめだけをやめる。
## 閉じられないとき（起動した直後）の Esc は受けない（戻すものが無いので、持ち主がシステムメニューを開く）。
func _input(event: InputEvent) -> void:
	if not visible or not _overlays.is_top(self):
		return
	var right: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT
	var escape: bool = event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE
	if (right or escape) and _confirming != null:
		get_viewport().set_input_as_handled()
		stop_confirm()
	elif right or (escape and _cancellable):
		get_viewport().set_input_as_handled()
		cancel()


## 「マップを選び直す」。対戦の途中なら、1 回目は確かめるだけで、もう一度押すとマップ選択へ（_press_or_confirm）。
func press_map() -> void:
	_press_or_confirm(_map_button, _leave_for_map)


func _leave_for_map() -> void:
	stop_confirm()
	visible = false
	map_pressed.emit(_choice.copy())


## 「マップ変更」が出ているか（検査用）。
func map_button_shown() -> bool:
	return _map_button.visible


## 対戦の組み合わせの帯（検査用）。
func banner() -> VersusBanner:
	return _banner


## label の見出しと、values（値 -> 名前）のボタンを並べた 1 行。押すと、その値を選ぶ。
func _add_row(column: VBoxContainer, caption: String, key: StringName, values: Dictionary) -> HBoxContainer:
	var row := _caption_row(column, caption)
	var buttons := {}
	for value: Variant in values:
		var button := _button(values[value])
		button.toggle_mode = true
		button.pressed.connect(func() -> void: _choose(key, value))
		row.add_child(button)
		buttons[value] = button
	_rows[key] = buttons
	return row


## 見出し（決まった幅）だけを置いた 1 行。
func _caption_row(column: VBoxContainer, caption: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	var label := _label(18)
	label.text = caption
	label.custom_minimum_size = Vector2(CAPTION_WIDTH, 0.0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	return row
