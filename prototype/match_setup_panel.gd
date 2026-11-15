extends Control
## 対戦の前に、軍・ステージ・相手・手番を選ぶ、飾らない最小の画面。
##
## 選んだもの（trial_setup.gd）を持ち、「対戦を始める」で start_pressed を出す。ルールは持たない。
## 人が動かすプレイヤーは、軍を選んだあと、その軍の部隊を、取っておいた部隊（deck_library.gd）か既定の編成から選ぶ。
## 出せない部隊は、理由つきで並べ、選べなくする。CPU の編成は軍ごとの CPU の編成（中身を文字で見せる）。

## 選んだもの（trial_setup.gd の値。呼ぶ側に渡すのは写し）。
signal start_pressed(choice: RefCounted)
## 何も変えずに閉じた（「対戦へ戻る」、右クリック、Esc）。いまの対戦は、そのまま続く。
signal cancelled

const TrialSetup := preload("res://prototype/trial_setup.gd")
const DeckText := preload("res://prototype/deck_text.gd")

const ARMY_NAMES := {UnitKind.Army.MILITARY: "MILITARY", UnitKind.Army.FANTASY: "FANTASY"}
const ARMIES: Array[UnitKind.Army] = [UnitKind.Army.MILITARY, UnitKind.Army.FANTASY]
const COLOR_PANEL := Color(0.07, 0.09, 0.12, 0.92)
const COLOR_TEXT_DIM := Color(0.75, 0.78, 0.82)

var _choice: RefCounted = TrialSetup.new()
var _team_colors: Array[Color] = []
## 選択肢の名前 -> その行のボタン（値 -> Button）。
var _rows := {}
var _deck_labels: Array[Label] = []
## プレイヤーごとの、部隊を選ぶ行と、その選択肢（並びの番号 -> 部隊の id。空は既定の編成）。
var _deck_rows: Array[Control] = []
var _deck_pickers: Array[OptionButton] = []
var _deck_choices: Array = [[], []]
## 取っておいた部隊（deck_library.gd）。無ければ既定の編成だけ。
var _library: RefCounted
var _side_row: Control
var _side_caption: Label
var _start_button: Button
var _back_button: Button
var _warning: Label
## 閉じて、いまの対戦へ戻れるか（起動した直後の、まだ対戦を始めていないときだけ偽）。
var _cancellable := false


## 開いている重なる画面の積み上げ（overlay_stack.gd。AppContext.overlays）。見えている間は積んでおく。
var _overlays: RefCounted


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
	shade.color = Color(0.0, 0.0, 0.0, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL
	style.set_corner_radius_all(6)
	style.set_content_margin_all(18.0)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)

	var title := _label(30)
	title.text = "対戦の設定"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	var stages := {}
	for stage: BoardGenerator.Stage in MatchSetup.STAGE_NAMES:
		stages[stage] = "%d %s" % [stage, MatchSetup.stage_name(stage)]
	_add_row(column, "ステージ", &"stage", stages)
	_add_row(column, "相手", &"opponent", {true: "CPU", false: "人（2 人で交代）"})
	_side_row = _add_row(column, "あなたの手番", &"human_side", {
		Unit.Side.PLAYER1: "先手（青）", Unit.Side.PLAYER2: "後手（赤）",
	})
	_side_caption = _side_row.get_child(0) as Label
	for side in 2:
		var names := {}
		for army in ARMIES:
			names[army] = ARMY_NAMES[army]
		var row := _add_row(column, "%s の軍" % ["先手（青）", "後手（赤）"][side], StringName("army%d" % side), names)
		(row.get_child(0) as Label).add_theme_color_override("font_color", _team_colors[side].lightened(0.4))
		var deck_row := HBoxContainer.new()
		deck_row.add_theme_constant_override("separation", 8)
		column.add_child(deck_row)
		var deck_caption := _label(18)
		deck_caption.text = "　部隊"
		deck_caption.custom_minimum_size = Vector2(170.0, 0.0)
		deck_row.add_child(deck_caption)
		var picker := OptionButton.new()
		picker.focus_mode = Control.FOCUS_NONE
		picker.add_theme_font_size_override("font_size", 17)
		picker.custom_minimum_size = Vector2(470.0, 40.0)
		picker.fit_to_longest_item = false
		picker.clip_text = true
		picker.get_popup().add_theme_font_size_override("font_size", 17)
		var picked_side := side
		picker.item_selected.connect(func(index: int) -> void: _on_deck_picked(picked_side, index))
		deck_row.add_child(picker)
		_deck_rows.append(deck_row)
		_deck_pickers.append(picker)
		var deck := _label(14)
		deck.add_theme_color_override("font_color", COLOR_TEXT_DIM)
		column.add_child(deck)
		_deck_labels.append(deck)

	var note := _label(14)
	note.text = "部隊は、タイトルの「部隊の編成」で組んで取っておける。CPU は軍ごとの編成。先手から動く"
	note.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(note)
	# 対戦の途中で開いたときは、始めるといまの対戦が失われることを書く。
	_warning = _label(15)
	_warning.text = "「新しい対戦を始める」を押すと、いまの対戦は終わる（元には戻せない）"
	_warning.add_theme_color_override("font_color", Color("ffb86b"))
	_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_warning)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(buttons)
	_back_button = _button("対戦へ戻る")
	_back_button.custom_minimum_size = Vector2(220.0, 52.0)
	_back_button.pressed.connect(cancel)
	buttons.add_child(_back_button)
	_start_button = _button("対戦を始める")
	_start_button.custom_minimum_size = Vector2(220.0, 52.0)
	_start_button.set_meta(&"sound", &"ui_confirm")  # 決める音（sound.gd）
	_start_button.pressed.connect(confirm)
	buttons.add_child(_start_button)
	_show_choice()


## いまの選択を choice の写しにして、画面を出す。開いただけでは、何も変わらない。
## cancellable が真なら、「対戦へ戻る」（右クリック・Esc でも）で、何も変えずに閉じられる。
## in_progress が真なら（決着していない対戦の途中）、始めるといまの対戦が失われることを書く。
## back_text は閉じるボタンの文字（対戦の設定の場面では「タイトルへ戻る」）。new_battle が真なら、始めるボタンを「新しい対戦を始める」にする
## （対戦の途中から開いたとき）。
func open(choice: RefCounted, cancellable := false, in_progress := false, back_text := "対戦へ戻る", new_battle := true) -> void:
	_choice = choice.copy()
	_choice.refresh_decks(_library)  # 編成の画面で消した・組み直した部隊に合わせる
	_cancellable = cancellable
	_back_button.visible = cancellable
	_back_button.text = back_text
	_warning.visible = cancellable and in_progress
	_start_button.text = "新しい対戦を始める" if cancellable and new_battle else "対戦を始める"
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
## 閉じられないとき（起動した直後）の Esc は受けない（戻すものが無いので、持ち主がシステムメニューを開く）。
func _input(event: InputEvent) -> void:
	if not visible or not _overlays.is_top(self):
		return
	var right: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT
	var escape: bool = event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE
	if right or (escape and _cancellable):
		get_viewport().set_input_as_handled()
		cancel()


## いま選んでいるもの（写しではない。検査用）。
func current_choice() -> RefCounted:
	return _choice


func choose_stage(stage: BoardGenerator.Stage) -> void:
	_choice.stage = stage
	_show_choice()


func choose_opponent(cpu: bool) -> void:
	_choice.cpu_opponent = cpu
	_show_choice()


func choose_human_side(side: Unit.Side) -> void:
	_choice.human_side = side
	_show_choice()


func choose_army(side: Unit.Side, army: UnitKind.Army) -> void:
	_choice.choose_army(side, army)
	_show_choice()


## side の部隊を、取っておいた部隊 id にする（空なら既定の編成）。出せない部隊・知らない id なら何もせず false。
func choose_deck(side: Unit.Side, id: String) -> bool:
	if id == "":
		_choice.choose_default(side)
		_show_choice()
		return true
	var item: Variant = _library.find(id) if _library != null else null
	if item == null or not item.playable() or item.deck.rules.id != DeckRules.VERSUS:
		return false
	_choice.choose_deck(side, id, item.deck)
	_show_choice()
	return true


## side の部隊の選択肢（[id, 文字, 選べるか] の列。並びは画面と同じ）。検査用。
func deck_options(side: Unit.Side) -> Array:
	return _deck_choices[side].duplicate(true)


func _on_deck_picked(side: Unit.Side, index: int) -> void:
	var options: Array = _deck_choices[side]
	if index < 0 or index >= options.size() or not choose_deck(side, options[index][0]):
		_show_choice()


## 「対戦を始める」。画面を閉じて、選んだものの写しを知らせる。
func confirm() -> void:
	visible = false
	start_pressed.emit(_choice.copy())


func _choose(key: StringName, value: Variant) -> void:
	match key:
		&"stage":
			choose_stage(value)
		&"opponent":
			choose_opponent(value)
		&"human_side":
			choose_human_side(value)
		&"army0":
			choose_army(Unit.Side.PLAYER1, value)
		&"army1":
			choose_army(Unit.Side.PLAYER2, value)


func _show_choice() -> void:
	if _rows.is_empty():
		return
	var current := {
		&"stage": _choice.stage, &"opponent": _choice.cpu_opponent, &"human_side": _choice.human_side,
		&"army0": _choice.armies[0], &"army1": _choice.armies[1],
	}
	for key: StringName in _rows:
		var buttons: Dictionary = _rows[key]
		for value: Variant in buttons:
			(buttons[value] as Button).set_pressed_no_signal(value == current[key])
	# 人どうしなら、手番は選ばない（先手・後手の 2 人が交代する）。
	for button: Button in _rows[&"human_side"].values():
		button.disabled = not _choice.cpu_opponent
	_side_caption.modulate.a = 1.0 if _choice.cpu_opponent else 0.4
	var match_setup: MatchSetup = _choice.to_setup(0)
	for side in 2:
		var human: bool = _choice.is_human(side as Unit.Side)
		_deck_rows[side].visible = human
		if human:
			_fill_deck_picker(side as Unit.Side)
		var who := "人" if human else "CPU の編成"
		_deck_labels[side].text = "　%s: %s" % [who, DeckText.deck_summary(match_setup.decks[side])]


## side の部隊の選択肢を並べ直す: 既定の編成と、その軍の取っておいた部隊（出せないものは理由つきで、選べない）。
func _fill_deck_picker(side: Unit.Side) -> void:
	var army: UnitKind.Army = _choice.armies[side]
	var default_deck := MatchSetup.default_deck(army)
	var options: Array = [["", "既定の編成（コスト %d / %d）" % [default_deck.total_cost(), default_deck.budget()], true]]
	if _library != null:
		for item: RefCounted in _library.for_rules(DeckRules.VERSUS, army):
			var playable: bool = item.playable()
			var text := "%s（コスト %d / %d）" % [item.name, item.deck.total_cost(), item.deck.budget()]
			if not playable:
				text = "%s — 出せない: %s" % [item.name, item.issues()[0]]
			options.append([item.id, text, playable])
	_deck_choices[side] = options
	var picker := _deck_pickers[side]
	picker.clear()
	var chosen := 0
	for i in options.size():
		picker.add_item(options[i][1], i)
		picker.set_item_disabled(i, not options[i][2])
		if options[i][0] == _choice.deck_ids[side]:
			chosen = i
	picker.select(chosen)


## label の見出しと、values（値 -> 名前）のボタンを並べた 1 行。押すと、その値を選ぶ。
func _add_row(column: VBoxContainer, caption: String, key: StringName, values: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	var label := _label(18)
	label.text = caption
	label.custom_minimum_size = Vector2(170.0, 0.0)
	row.add_child(label)
	var buttons := {}
	for value: Variant in values:
		var button := _button(values[value])
		button.toggle_mode = true
		button.pressed.connect(func() -> void: _choose(key, value))
		row.add_child(button)
		buttons[value] = button
	_rows[key] = buttons
	return row


func _label(font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	return label


func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 17)
	button.custom_minimum_size = Vector2(150.0, 40.0)
	button.focus_mode = Control.FOCUS_NONE
	return button
