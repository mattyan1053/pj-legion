extends Control
## 対戦の前に、相手・手番・軍・部隊を選ぶ、飾らない最小の画面。ステージは、ステージ選択で選んだものを出すだけ
## （変えるのは「ステージを選び直す」。ステージ選択の場面へ戻る）。
##
## 選んだもの（match_choice.gd）を持ち、「対戦を始める」で start_pressed を出す。ルールは持たない。
## 人が動かすプレイヤーは、軍を選んだあと、その軍の部隊を、取っておいた部隊（deck_library.gd）か既定の編成から選ぶ。
## 出せない部隊は、理由つきで並べ、選べなくする。CPU の編成は軍ごとの CPU の編成。
## 部隊の中身は、パネルに文で並べず、「編成を確認」で開く（deck_preview.gd。自分の部隊も CPU の部隊も同じ見え方）。
## パネルの大きさは、選んだものに依らず同じ（部隊の名前は決まった幅で切る）。

## 選んだもの（match_choice.gd の値。呼ぶ側に渡すのは写し）。
signal start_pressed(choice: RefCounted)
## 何も変えずに閉じた（「対戦へ戻る」、右クリック、Esc）。いまの対戦は、そのまま続く。
signal cancelled
## 「ステージを選び直す」。いまの選択（写し）を渡す。持ち主がステージ選択の場面へ進む。
signal stage_pressed(choice: RefCounted)
## 「部隊を編成する」。いまの選択（写し）と、部隊を組むプレイヤーを渡す。持ち主が部隊の編成へ寄り道する。
signal decks_pressed(choice: RefCounted, side: Unit.Side)

const Palette := preload("res://game/ui_palette.gd")
const UiTheme := preload("res://game/ui_theme.gd")
const MatchChoice := preload("res://game/match_choice.gd")
const VersusFields := preload("res://game/versus_fields.gd")
const DeckText := preload("res://game/deck_text.gd")
const DeckPreview := preload("res://game/deck_preview.gd")
const Names := preload("res://game/names.gd")

const ARMIES: Array[UnitKind.Army] = [UnitKind.Army.MILITARY, UnitKind.Army.FANTASY]
## パネルの中身の幅（px）。選んだものに依らず、この幅に固定する。
const PANEL_WIDTH := 900.0
## 見出しの列の幅と、部隊を選ぶ欄の幅（px）。
const CAPTION_WIDTH := 190.0
const PICKER_WIDTH := 330.0
## 手番の「ランダム」のボタンの値（Unit.Side の値と重ならない）。
const RANDOM_SIDE := -1

var _choice: RefCounted = MatchChoice.new()
var _team_colors: Array[Color] = []
## 選択肢の名前 -> その行のボタン（値 -> Button）。
var _rows := {}
## プレイヤーごとの、軍の行の見出し（「あなた」「CPU」など）、部隊を選ぶ欄、CPU の編成の欄、「部隊を編成する」、その選択肢
## （並びの番号 -> 部隊の id。空は既定の編成）。
var _who_labels: Array[Label] = []
var _deck_pickers: Array[OptionButton] = []
var _cpu_labels: Array[Label] = []
var _edit_buttons: Array[Button] = []
var _deck_choices: Array = [[], []]
var _stage_name: Label
var _stage_button: Button
var _preview: DeckPreview
## 「部隊を編成する」を出すか（対戦の設定の場面だけ。対戦の途中では出さない）。
var _can_edit_decks := false
## 取っておいた部隊（deck_library.gd）。無ければ既定の編成だけ。
var _library: RefCounted
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
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)

	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	var title := _label(30)
	title.theme_type_variation = UiTheme.LABEL_HEADING
	title.text = "対戦の設定"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	var stage_row := _caption_row(column, "ステージ")
	_stage_name = _label(18)
	_stage_name.custom_minimum_size = Vector2(PICKER_WIDTH, 0.0)
	_stage_name.clip_text = true
	_stage_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	stage_row.add_child(_stage_name)
	_stage_button = _button("ステージを選び直す")
	_stage_button.custom_minimum_size = Vector2(200.0, 40.0)
	_stage_button.pressed.connect(press_stage)
	stage_row.add_child(_stage_button)
	_add_row(column, "相手", &"opponent", {true: "CPU", false: "人（2 人で交代）"})
	var side_row := _add_row(column, "手番", &"human_side", {
		Unit.Side.PLAYER1: "先手（青）", Unit.Side.PLAYER2: "後手（赤）", RANDOM_SIDE: "ランダム",
	})
	_side_caption = side_row.get_child(0) as Label
	for side in 2:
		column.add_child(HSeparator.new())
		var names := {}
		for army in ARMIES:
			names[army] = Names.ARMY_NAMES[army]
		var row := _add_row(column, "", StringName("army%d" % side), names)
		_who_labels.append(row.get_child(0) as Label)
		var deck_row := _caption_row(column, "部隊")
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
		var cpu_label := _label(18)
		cpu_label.text = "CPU の編成"
		cpu_label.custom_minimum_size = Vector2(PICKER_WIDTH, 40.0)
		cpu_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		deck_row.add_child(cpu_label)
		_cpu_labels.append(cpu_label)
		var look := _button("編成を確認")
		look.pressed.connect(func() -> void: open_preview(picked_side))
		deck_row.add_child(look)
		var edit := _button("部隊を編成する")
		edit.custom_minimum_size = Vector2(170.0, 40.0)
		edit.pressed.connect(func() -> void: press_edit_decks(picked_side))
		deck_row.add_child(edit)
		_edit_buttons.append(edit)
	column.add_child(HSeparator.new())

	# 対戦の途中で開いたときは、始めるといまの対戦が失われることを書く。
	_warning = _label(15)
	_warning.text = "ステージを選び直す・新しい対戦を始めると、いまの対戦は終わる"
	_warning.add_theme_color_override("font_color", Palette.WARN)
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
	_start_button.theme_type_variation = UiTheme.BUTTON_PRIMARY
	_start_button.pressed.connect(confirm)
	buttons.add_child(_start_button)
	_preview = DeckPreview.new()
	add_child(_preview)
	_preview.setup(overlays)
	_show_choice()


## いまの選択を choice の写しにして、画面を出す。開いただけでは、何も変わらない。
## cancellable が真なら、「対戦へ戻る」（右クリック・Esc でも）で、何も変えずに閉じられる。
## in_progress が真なら（決着していない対戦の途中）、始めるといまの対戦が失われることを書く。
## back_text は閉じるボタンの文字（対戦の設定の場面では「ステージ選択へ戻る」）。new_battle が真なら、始めるボタンを「新しい対戦を始める」にする
## （対戦の途中から開いたとき）。対戦の途中から開いたときは「部隊を編成する」を出さない（対戦の設定の場面だけ）。
func open(choice: RefCounted, cancellable := false, in_progress := false, back_text := "対戦へ戻る", new_battle := true) -> void:
	_choice = choice.copy()
	_can_edit_decks = not (cancellable and new_battle)
	_preview.close_preview()
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


## ステージを field（versus_fields.gd の鍵）にする。
func choose_field(field: StringName) -> void:
	_choice.field = field
	_show_choice()


func choose_opponent(cpu: bool) -> void:
	_choice.cpu_opponent = cpu
	_show_choice()


func choose_human_side(side: Unit.Side) -> void:
	_choice.human_side = side
	_choice.random_side = false
	_show_choice()


## 手番を「ランダム」にする（対戦を作るたびに、種から先手・後手を引く）。
func choose_random_side() -> void:
	_choice.random_side = true
	_show_choice()


func choose_army(side: Unit.Side, army: UnitKind.Army) -> void:
	_choice.choose_army(side, army)
	_show_choice()


## side の部隊の選択肢を開く（スクリーンショットの道具用）。
func open_deck_picker(side: Unit.Side) -> void:
	_deck_pickers[side].show_popup()


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
		&"opponent":
			choose_opponent(value)
		&"human_side":
			if value == RANDOM_SIDE:
				choose_random_side()
			else:
				choose_human_side(value)
		&"army0":
			choose_army(Unit.Side.PLAYER1, value)
		&"army1":
			choose_army(Unit.Side.PLAYER2, value)


func _show_choice() -> void:
	if _rows.is_empty():
		return
	var side_value: int = RANDOM_SIDE if _choice.random_side else _choice.human_side
	var current := {
		&"opponent": _choice.cpu_opponent, &"human_side": side_value,
		&"army0": _choice.armies[0], &"army1": _choice.armies[1],
	}
	for key: StringName in _rows:
		var buttons: Dictionary = _rows[key]
		for value: Variant in buttons:
			(buttons[value] as Button).set_pressed_no_signal(value == current[key])
	_stage_name.text = "%d %s" % [VersusFields.number_of(_choice.field), VersusFields.title_of(_choice.field)]
	# 人どうしなら、手番は選ばない（先手・後手の 2 人が交代する）。
	for button: Button in _rows[&"human_side"].values():
		button.disabled = not _choice.cpu_opponent
	_side_caption.modulate.a = 1.0 if _choice.cpu_opponent else 0.4
	for side in 2:
		var human: bool = _choice.is_human(side as Unit.Side)
		_who_labels[side].text = who_text(side as Unit.Side)
		_who_labels[side].remove_theme_color_override("font_color")
		if not (_choice.cpu_opponent and _choice.random_side):
			_who_labels[side].add_theme_color_override("font_color", _team_colors[side].lightened(0.4))
		_deck_pickers[side].visible = human
		_cpu_labels[side].visible = not human
		_edit_buttons[side].visible = human and _can_edit_decks
		if human:
			_fill_deck_picker(side as Unit.Side)


## side の行の見出し。CPU 戦なら「あなた」「CPU」と手番、人どうしなら手番だけ。
func who_text(side: Unit.Side) -> String:
	var turn: String = ["先手（青）", "後手（赤）"][side]
	if not _choice.cpu_opponent:
		return turn
	var who := "あなた" if _choice.is_human(side) else "CPU"
	return who if _choice.random_side else "%s・%s" % [who, turn]


## side の部隊（「編成を確認」で出すもの）。人なら選んだ部隊か既定の編成、CPU なら軍ごとの CPU の編成。
func preview_deck(side: Unit.Side) -> Deck:
	if _choice.is_human(side):
		return _choice.deck_for(side)
	return CpuDeck.build(_choice.armies[side])


## 「編成を確認」: side の部隊を札にして出す。
func open_preview(side: Unit.Side) -> void:
	# ランダムの間は陣営が決まっていないので、あなたは青、CPU は赤で見せる。
	_preview.open(who_text(side), preview_deck(side), side)


## 編成の確認の画面（検査用）。
func preview() -> DeckPreview:
	return _preview


## 「ステージを選び直す」。
func press_stage() -> void:
	visible = false
	stage_pressed.emit(_choice.copy())


## 「部隊を編成する」（side の部隊を組む）。
func press_edit_decks(side: Unit.Side) -> void:
	visible = false
	decks_pressed.emit(_choice.copy(), side)


## 「部隊を編成する」が出ているか（検査用）。
func can_edit_decks() -> bool:
	return _can_edit_decks


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


func _label(font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", 4)
	return label


func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 17)
	button.custom_minimum_size = Vector2(150.0, 40.0)
	button.focus_mode = Control.FOCUS_NONE
	return button
