extends "res://game/result_screen/result_table.gd"
## リザルトの画面の行き先のボタン（もう一度・新しいマップ・対戦設定・部隊変更・次へ・抜ける）と、入力の案内。


func _buttons_ready() -> bool:
	return not _buttons.is_empty() and _buttons[0].mouse_filter != Control.MOUSE_FILTER_IGNORE


## 出す行き先を決める（対戦の画面が、渡されたもの（battle_source.gd）に聞いて決める）。
## boards は「新しいマップ」で選べるマップの [鍵, 名前] の列（並びの順にボタンを出す）、setup は「対戦設定へ」、squad は「部隊を選び直す」を出すか。
## 「同じマップで再戦」と、流れの外への行き先（set_leave。既定は「タイトルへ」）は、いつも出す。
func set_destinations(boards: Array[Array], setup: bool, squad := false) -> void:
	while _board_buttons.size() < boards.size():
		var button := _button("", 0.0)
		button.set_meta(&"sound", &"ui_confirm")
		button.mouse_filter = _again_button.mouse_filter
		button.pressed.connect(func() -> void: restart_pressed.emit(button.get_meta(&"field"), true))
		_again_button.get_parent().add_child(button)
		_board_buttons.append(button)
	for index in _board_buttons.size():
		var button := _board_buttons[index]
		button.visible = index < boards.size()
		if button.visible:
			button.set_meta(&"field", boards[index][0])
			button.text = Text.t("result.new_board", {"board": boards[index][1]})
	_setup_button.visible = setup
	_squad_button.visible = squad


## 「次へ」を出すか（対戦の画面が、渡されたもの（battle_source.gd）に聞いて決める。決着の画面を出すたびに決める）。
## retry は、「次へ」が無いときの Enter を「同じマップで再戦」にするか（偽ならタイトルへ）。
## 「次へ」を出すときは、流れの外への行き先（「話の一覧へ」）を出さない。勝った話の「次へ」の先には、あとの会話と増えたものの知らせがあり、
## 並べると、読まずに一覧へ戻ってしまう（会話は「スキップ」で飛ばせ、読み終えたところでも「話の一覧へ」を選べる。メニューからも出られる）。
func set_continue(shown: bool, retry := false) -> void:
	_continue_button.visible = shown
	_leave_button.visible = not shown
	_enter_retries = retry and not shown
	_again_button.add_theme_font_size_override("font_size", BIG_FONT if _enter_retries else BUTTON_FONT)
	_prompt.text = Text.t("result.prompt", {"destination": enter_destination()})
	_mark_enter_button()


## 流れの外への行き先のボタンの文（既定は「タイトルへ」。対戦モードは「マップ選択へ」、ストーリーは「話の一覧へ」。battle_source.gd の leave）。
## 押すと title_pressed（対戦の画面が、その行き先へ進む）。
func set_leave(text: String) -> void:
	_leave_button.text = text
	_prompt.text = Text.t("result.prompt", {"destination": enter_destination()})
	_mark_enter_button()


## Enter で選ぶボタンを、いちばん大事なボタンの見た目（金の地）にする。ほかの行き先は、ふつうのボタン。
func _mark_enter_button() -> void:
	var target := _continue_button if _continue_button.visible else (_again_button if _enter_retries else _leave_button)
	for button: Button in [_continue_button, _again_button, _leave_button]:
		button.theme_type_variation = UiTheme.BUTTON_PRIMARY if button == target else &""


## 流れの外への行き先のボタンを出しているか。検査用。
func can_leave() -> bool:
	return _leave_button.visible


## 流れの外への行き先のボタンの文。検査用。
func leave_text() -> String:
	return _leave_button.text


## 入力の案内（「行き先を選ぶ（Enter で…）」）の、画面の上の場所。検査用。
func prompt_rect() -> Rect2:
	return _prompt.get_global_rect()


## 出そろったあとの Enter で選ぶ行き先の名前（ボタンの文字）。
func enter_destination() -> String:
	if _continue_button.visible:
		return _continue_button.text
	if _enter_retries:
		return _again_button.text
	return _leave_button.text


## 流れの外への行き先のボタン（「話の一覧へ」など）を押す（出していなければ何もしない）。
func press_leave() -> void:
	if _leave_button.visible:
		title_pressed.emit()


## 「同じマップで再戦」を押す。
func press_again() -> void:
	restart_pressed.emit(&"", false)


## 「もう一度見る」を出すか（対戦の画面が、記録を取っているか（対戦モード）で決める。決着の画面を出すたびに決める）。
func set_replay(shown: bool) -> void:
	_replay_button.visible = shown


## 「もう一度見る」を出しているか。検査用。
func can_replay() -> bool:
	return _replay_button.visible


## 「もう一度見る」を押す（出していなければ何もしない）。
func press_replay() -> void:
	if _replay_button.visible:
		replay_pressed.emit()


## 「次へ」を出しているか。検査用。
func can_continue() -> bool:
	return _continue_button.visible


## 「次へ」を押す（出していなければ何もしない）。
func press_continue() -> void:
	if _continue_button.visible:
		continue_pressed.emit()


## 「対戦設定へ」を出しているか。検査用。
func can_go_to_setup() -> bool:
	return _setup_button.visible


## 「部隊を選び直す」を出しているか。検査用。
func can_choose_squad() -> bool:
	return _squad_button.visible


## 「部隊を選び直す」を押す（出していなければ何もしない）。
func press_choose_squad() -> void:
	if _squad_button.visible:
		squad_pressed.emit()


## 「新しいマップ」で出しているマップの鍵。検査用。
func new_board_fields() -> Array[StringName]:
	var shown: Array[StringName] = []
	for button in _board_buttons:
		if button.visible:
			shown.append(button.get_meta(&"field"))
	return shown


func _set_buttons_enabled(enabled: bool) -> void:
	for button in _buttons:
		button.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE


## 理由の行を、見出しのすぐ下に置く（見出しの大きさに合わせる）。
func _place_reason() -> void:
	var height := _headline.size.y * _headline.scale.y
	var top := _headline.position.y + _headline.size.y / 2.0 - height / 2.0
	_reason.position.y = top + height - 6.0


func _build_actions() -> void:
	_actions = VBoxContainer.new()
	_actions.add_theme_constant_override("separation", 6)
	_actions.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_body.add_child(_actions)
	var row := _row()
	# 「次へ」は「同じマップで再戦」と同じ行の先頭に置く（ストーリーでは新しい盤面のボタンが出ないので、行が空く。
	# 行を分けると、戦績の行が多いときにボタンが画面の下の帯に重なる）。
	_continue_button = _button(Text.t("result.next"), 240.0)
	_continue_button.set_meta(&"sound", &"ui_confirm")
	_continue_button.theme_type_variation = UiTheme.BUTTON_PRIMARY
	_continue_button.add_theme_font_size_override("font_size", BIG_FONT)
	_continue_button.pressed.connect(press_continue)
	_continue_button.visible = false
	row.add_child(_continue_button)
	_again_button = _button(Text.t("result.again"), 240.0)
	_again_button.set_meta(&"sound", &"ui_confirm")
	_again_button.pressed.connect(press_again)
	row.add_child(_again_button)
	# 「新しいマップ」のボタンは、この行に set_destinations が足す。
	var leave := _row()
	_setup_button = _button(Text.t("result.setup"), 320.0)
	_setup_button.pressed.connect(setup_pressed.emit)
	leave.add_child(_setup_button)
	_squad_button = _button(Text.t("result.squad"), 220.0)
	_squad_button.pressed.connect(press_choose_squad)
	_squad_button.visible = false
	leave.add_child(_squad_button)
	_replay_button = _button(Text.t("result.replay"), 180.0)
	_replay_button.pressed.connect(press_replay)
	_replay_button.visible = false
	leave.add_child(_replay_button)
	_leave_button = _button(Text.t("result.to_title"), 180.0)
	_leave_button.pressed.connect(title_pressed.emit)
	leave.add_child(_leave_button)
	_detail_button = _button("", 220.0)
	_detail_button.theme_type_variation = UiTheme.BUTTON_GHOST  # たまに開くもの。行き先のボタンより控えめに
	_detail_button.pressed.connect(toggle_detail)
	leave.add_child(_detail_button)
	_prompt = _label(16)
	_prompt.text = Text.t("result.prompt_title")
	_prompt.add_theme_color_override("font_color", COLOR_DIM)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_actions.add_child(_prompt)
