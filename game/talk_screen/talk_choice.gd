extends "res://game/talk_screen/talk_figures.gd"
## 会話の場面（game/talk_screen.gd）の終わり方: 会話を終える、あとの会話の行き先の選択（「次の話へ」「話の一覧へ」）。


func _end() -> void:
	if _ended:
		return
	if next_episode() != null:
		_open_choice()
		return
	_ended = true
	context.play_sound(&"ui_confirm")
	finished.emit(Run.NEXT)


## 会話を終えたあとに始められる次の話（渡された会話の "next_episode" が、いま遊べるときだけ。無ければ null）。
func next_episode() -> RefCounted:
	var next: RefCounted = talk.get("next_episode")
	if next == null or context.story == null or not context.story.is_available(next):
		return null
	return next


## 「スキップ」を出しているか（検査用）。
func is_skip_shown() -> bool:
	return _skip.visible


## 行き先の選択を出しているか。
func is_choosing() -> bool:
	return _choice != null and _choice.visible


## 「次の話へ」: 次の話の流れを（出撃準備から）始める。
func press_next_episode() -> void:
	var next := next_episode()
	if next == null or _ended:
		return
	_ended = true
	context.play_sound(&"ui_confirm")
	context.start_run(context.story.run_now(next))


## 「話の一覧へ」: 流れを終えて、話の一覧へ。
func press_to_episodes() -> void:
	if _ended:
		return
	_ended = true
	context.play_sound(&"ui_confirm")
	finished.emit(Run.NEXT)


func _open_choice() -> void:
	if _choice == null:
		var center := CenterContainer.new()
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_layer.add_child(center)
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", UiTheme.solid_box(22.0))
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 枠の上の右クリックも、選ぶのをやめる入力へ通す（ボタンは押せる）
		center.add_child(panel)
		# 縦に積む（横に並べると、枠が左右の話し手の手や武器に重なる）。
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		panel.add_child(row)
		var next := Button.new()
		next.text = Text.t("talk.next_episode")
		next.theme_type_variation = UiTheme.BUTTON_PRIMARY
		next.custom_minimum_size = Vector2(CHOICE_WIDTH, 52.0)
		next.add_theme_font_size_override("font_size", 22)
		next.focus_mode = Control.FOCUS_NONE
		next.set_meta(&"sound", &"ui_confirm")
		next.pressed.connect(press_next_episode)
		row.add_child(next)
		var list := Button.new()
		list.text = Text.t("result.to_episodes")
		list.custom_minimum_size = Vector2(CHOICE_WIDTH, 46.0)
		list.add_theme_font_size_override("font_size", 18)
		list.focus_mode = Control.FOCUS_NONE
		list.pressed.connect(press_to_episodes)
		row.add_child(list)
		_choice = center
	_choice.visible = true
	_hint.visible = false  # 「クリック: 次へ」と「スキップ」は、選ぶ間は出さない
	_skip.visible = false
	context.play_sound(&"menu_open")


## 行き先の選択の間の入力: Enter で「次の話へ」、右クリックで選択をやめて最後の文へ。Esc はシステムメニュー。
func _choice_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_choice.visible = false
		_hint.visible = true
		_skip.visible = true
		context.play_sound(&"ui_back")
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ENTER, KEY_KP_ENTER:
				press_next_episode()
			KEY_ESCAPE:
				context.open_menu()
