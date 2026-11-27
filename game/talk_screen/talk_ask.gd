extends "res://game/talk_screen/talk_choice.gd"
## 会話の場面（game/talk_screen.gd）の選択肢（docs/story.md の「選択肢」）: 問いの行（"choice" を持つ行）を出しきったら、答えを選ばせる。
## 選んだ答えは、記録（story.gd の choose_answer）に覚える。出す条件（"when"）を持つ行は、答えに合うものだけを出す。
##
## - 答えは、クリックか、上下の矢印（W/S）で選んで Enter・Space、数字のキー（1〜3）。選ぶまで、先へ進まない（「スキップ」も止まる）。
## - 右クリックで前の文へ戻れる。選んだあとに問いの行へ戻れば、選び直せる。
## - 枠は、いつも答え 3 つぶんの大きさで、舞台の真ん中（答えの数と長さで変えない）。


## 選択肢 choice の、いま覚えている答えの鍵（この場面で選んだもの、無ければ記録。まだ選んでいなければ空）。
func _answer_of(choice: StringName) -> String:
	if _answers.has(choice):
		return _answers[choice]
	return context.story.answer_of(choice) if context.story != null else ""


## いま出す行の列を作り直す（渡された行のうち、出す条件の合うもの）。
func _refresh_lines() -> void:
	_lines = []
	for line: Dictionary in talk.get("lines", []):
		var when: Dictionary = line.get("when", {})
		if when.is_empty() or (_answer_of(when["choice"]) == String(when["answer"])) != bool(when.get("not", false)):
			_lines.append(line)


## いまの行の選択肢（{"name", "options"}。選ばせる行でなければ空）。
func _choice_here() -> Dictionary:
	return _lines[_index].get("choice", {}) if _index < _lines.size() else {}


## 答えを選ばせているか。
func is_asking() -> bool:
	return _options != null and _options.visible


## 出している答えの文（検査用）。
func option_texts() -> Array[String]:
	var texts: Array[String] = []
	for button in _option_buttons:
		if button.visible:
			texts.append(button.text)
	return texts


## 選択肢の枠が画面に占める四角（検査用）。
func options_rect() -> Rect2:
	return _options.get_global_rect()


## 選択肢の枠を作る（隠したまま）。舞台の真ん中に、決まった大きさで置く。
func _build_options() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(center)
	_options = PanelContainer.new()
	_options.add_theme_stylebox_override("panel", UiTheme.solid_box(18.0))
	_options.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 枠の上の右クリックも、前の文へ戻る入力へ通す（ボタンは押せる）
	_options.visible = false
	Steady.mark(_options, "talk.options", Steady.SIZE)
	center.add_child(_options)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", OPTION_GAP)
	column.custom_minimum_size = Vector2(OPTION_SIZE.x, OPTION_SIZE.y * OPTION_SLOTS + OPTION_GAP * (OPTION_SLOTS - 1))
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_options.add_child(column)
	for i in OPTION_SLOTS:
		var button := Button.new()
		button.custom_minimum_size = OPTION_SIZE
		button.add_theme_font_size_override("font_size", OPTION_FONT)
		button.clip_text = true
		button.focus_mode = Control.FOCUS_NONE
		button.set_meta(&"sound", &"ui_confirm")
		button.pressed.connect(Callable(self, &"press_option").bind(i))  # press_option は talk_screen.gd（行を出す関数を呼ぶ）
		button.mouse_entered.connect(_mark_option.bind(i))
		column.add_child(button)
		_option_buttons.append(button)


## いまの行が選ばせる行で、文が出きっていれば、答えを出す。
func _ask_if_due() -> void:
	var choice := _choice_here()
	if choice.is_empty() or _ended or _answered_last or is_asking() or _shown < float(_text.get_total_character_count()):
		return
	var options: Array = choice["options"]
	var chosen := _answer_of(choice["name"])
	_option_at = -1
	for i in _option_buttons.size():
		_option_buttons[i].visible = i < options.size()
		if i < options.size():
			_option_buttons[i].text = options[i]["text"]
			if String(options[i]["key"]) == chosen:
				_option_at = i  # 選び直しに戻ってきたときは、前に選んだ答えに印
	_mark_option(_option_at)
	_options.visible = true
	_skip.disabled = true
	_set_guide(true)
	context.play_sound(&"menu_open")


func _close_options() -> void:
	if _options != null and _options.visible:
		_options.visible = false
		_skip.disabled = false
		_set_guide(false)


## キーで選んでいる答え at に印を付ける（押す前の見た目）。
func _mark_option(at: int) -> void:
	_option_at = at
	for i in _option_buttons.size():
		_option_buttons[i].theme_type_variation = UiTheme.BUTTON_PRIMARY if i == at else &""


## 下の案内を、選ぶ間のもの（「次へ」を出さない）と、ふだんのものに替える。
func _set_guide(asking: bool) -> void:
	var parts := [
		KeyMarks.key(Text.t("common.key.right_click"), Text.t("talk.guide.back")),
		KeyMarks.key(Text.t("common.key.wheel"), Text.t("talk.guide.log")),
	]
	if not asking:
		parts.push_front(KeyMarks.key(Text.t("common.key.click"), Text.t("talk.guide.next")))
	_hint.set_parts(parts)


## 会話のログに並べる行: これまでに出した行（いまの行まで）。選んだ答えは、問いの行のあとに 1 行で残す。
func _log_lines() -> Array:
	var rows: Array = []
	for i in mini(_index + 1, _lines.size()):
		rows.append(_lines[i])
		var choice: Dictionary = _lines[i].get("choice", {})
		if (i < _index or _answered_last) and not choice.is_empty():
			for option: Dictionary in choice["options"]:
				if String(option["key"]) == _answer_of(choice["name"]):
					rows.append({"side": 0, "name": Text.t("talk.answer.plate"), "text": option["text"]})
	return rows
