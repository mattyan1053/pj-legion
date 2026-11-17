extends Control
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

## 選んだもの（match_choice.gd の値。呼ぶ側に渡すのは写し）。
signal start_pressed(choice: RefCounted)
## 何も変えずに閉じた（「対戦へ戻る」、右クリック、Esc）。いまの対戦は、そのまま続く。
signal cancelled
## 「マップを選び直す」。いまの選択（写し）を渡す。持ち主がマップ選択の場面へ進む。
signal map_pressed(choice: RefCounted)
## 「部隊編成」。いまの選択（写し）と、部隊を組むプレイヤーを渡す。持ち主が部隊編成へ寄り道する。
signal decks_pressed(choice: RefCounted, side: Unit.Side)

const Text := preload("res://game/text.gd")
const Palette := preload("res://game/ui_palette.gd")
const UiTheme := preload("res://game/ui_theme.gd")
const MatchChoice := preload("res://game/match_choice.gd")
const VersusFields := preload("res://game/versus_fields.gd")
const DeckText := preload("res://game/deck_text.gd")
const DeckPreview := preload("res://game/deck_preview.gd")
const Names := preload("res://game/names.gd")
const BattleUiState := preload("res://game/battle_ui_state.gd")

const ARMIES: Array[UnitKind.Army] = [UnitKind.Army.MILITARY, UnitKind.Army.FANTASY]
## パネルの中身の幅（px）。選んだものに依らず、この幅に固定する。
const PANEL_WIDTH := 900.0
## 見出しの列の幅と、部隊を選ぶ欄の幅（px）。
const CAPTION_WIDTH := 190.0
const PICKER_WIDTH := 330.0
## 手番の「ランダム」のボタンの値（Unit.Side の値と重ならない）。
const RANDOM_SIDE := -1
## 確かめの間のボタンの文字（「マップ変更」と、始めるボタン）と、下の文（理由）。
const CONFIRM_MAP_BUTTON := "setup.confirm.map"
const CONFIRM_START_BUTTON := "setup.confirm.start"
const MAP_TEXT := "setup.map"
const WARNING_TEXT := "setup.warning"
const CONFIRM_MAP_TEXT := "setup.confirm_map"
const CONFIRM_START_TEXT := "setup.confirm_start"

var _choice: RefCounted = MatchChoice.new()
var _team_colors: Array[Color] = []
## 選択肢の名前 -> その行のボタン（値 -> Button）。
var _rows := {}
## プレイヤーごとの、軍の行の見出し（「あなた」「CPU」など）、部隊を選ぶ欄、「編成確認」、「部隊編成」、その選択肢
## （並びの番号 -> 部隊の id。空は既定の編成、MatchChoice.RANDOM はランダム編成）。
var _who_labels: Array[Label] = []
var _deck_pickers: Array[OptionButton] = []
var _preview_buttons: Array[Button] = []
var _edit_buttons: Array[Button] = []
var _deck_choices: Array = [[], []]
var _map_name: Label
var _map_button: Button
var _preview: DeckPreview
## 「部隊編成」を出すか（対戦設定の場面だけ。対戦の途中では出さない）。
var _can_edit_decks := false
## 取っておいた部隊（deck_library.gd）。無ければ既定の編成だけ。
var _library: RefCounted
var _side_caption: Label
var _first_gauge_note: Label
var _start_button: Button
var _back_button: Button
var _warning: Label
## 閉じて、いまの対戦へ戻れるか（起動した直後の、まだ対戦を始めていないときだけ偽）。
var _cancellable := false
## 決着していない対戦の途中で開いたか（押すと対戦が終わるボタンを 2 回押させる）。
var _in_progress := false
## 2 回目を待っているボタン（無ければ null）と、確かめを始めた時刻（ミリ秒）。
var _confirming: Button
var _confirm_started_msec := 0
## 始めるボタンのいまの文字（確かめをやめたら戻す）。
var _start_text := ""


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
	title.text = Text.t("setup.title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

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
	# 対戦モードの先手は、必殺技のゲージがたまった状態から始まる（Ults.FIRST_PLAYER_START_GAUGE）。手番の行の右に書いておく。
	# 2 行にして、ボタンの高さに収める（行もパネルも大きくしない）。
	_first_gauge_note = _label(14)
	_first_gauge_note.text = first_gauge_note()
	_first_gauge_note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_first_gauge_note.visible = not _first_gauge_note.text.is_empty()
	side_row.add_child(_first_gauge_note)
	for side in 2:
		column.add_child(HSeparator.new())
		var names := {}
		for army in ARMIES:
			names[army] = Names.army(army)
		var row := _add_row(column, "", StringName("army%d" % side), names)
		_who_labels.append(row.get_child(0) as Label)
		var deck_row := _caption_row(column, Text.t("setup.caption.deck"))
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
		var edit := _button(Text.t("setup.edit_deck"))
		edit.custom_minimum_size = Vector2(170.0, 40.0)
		edit.pressed.connect(func() -> void: press_edit_decks(picked_side))
		deck_row.add_child(edit)
		_edit_buttons.append(edit)
	column.add_child(HSeparator.new())

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
	_back_button.custom_minimum_size = Vector2(220.0, 52.0)
	_back_button.pressed.connect(cancel)
	buttons.add_child(_back_button)
	_start_button = _button(Text.t("setup.start"))
	_start_button.custom_minimum_size = Vector2(220.0, 52.0)
	_start_button.set_meta(&"sound", &"ui_confirm")  # 決める音（sound.gd）
	_start_button.theme_type_variation = UiTheme.BUTTON_PRIMARY
	_start_button.pressed.connect(press_start)
	buttons.add_child(_start_button)
	_preview = DeckPreview.new()
	add_child(_preview)
	_preview.setup(overlays)
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


## いま選んでいるもの（写しではない。検査用）。
func current_choice() -> RefCounted:
	return _choice


## マップを field（versus_fields.gd の鍵）にする。
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


## side の部隊を、取っておいた部隊 id にする（空なら既定の編成、MatchChoice.RANDOM ならランダム編成）。出せない部隊・知らない id なら何もせず false。
func choose_deck(side: Unit.Side, id: String) -> bool:
	if id == "":
		_choice.choose_default(side)
		_show_choice()
		return true
	if id == MatchChoice.RANDOM:
		_choice.choose_random(side)
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


## 「対戦を始める」のボタン。対戦の途中なら、1 回目は確かめるだけで、もう一度押すと始める（_press_or_confirm）。
func press_start() -> void:
	_press_or_confirm(_start_button, confirm)


## 対戦を始める（確かめずに）。画面を閉じて、選んだものの写しを知らせる。
func confirm() -> void:
	stop_confirm()
	visible = false
	start_pressed.emit(_choice.copy())


## 押すといまの対戦が終わるボタン。対戦の途中でなければ、すぐ do。対戦の途中なら、1 回目はボタンを「もう一度押す」にして
## 理由を下の文に出すだけ。同じボタンをもう一度押すと do。確かめに変わった直後（BattleUiState.CONFIRM_GUARD_MSEC）の
## 2 回目は受けない（ダブルクリックで確かめを飛ばさない）。ほかの操作、右クリック・Esc で確かめをやめる。
func _press_or_confirm(button: Button, do: Callable) -> void:
	if not _in_progress:
		do.call()
		return
	if _confirming != button:
		stop_confirm()
		_confirming = button
		_confirm_started_msec = Time.get_ticks_msec()
		button.text = Text.t(CONFIRM_MAP_BUTTON) if button == _map_button else Text.t(CONFIRM_START_BUTTON)
		button.theme_type_variation = UiTheme.BUTTON_DANGER
		_warning.text = Text.t(CONFIRM_MAP_TEXT) if button == _map_button else Text.t(CONFIRM_START_TEXT)
		return
	if Time.get_ticks_msec() - _confirm_started_msec < BattleUiState.CONFIRM_GUARD_MSEC:
		return
	do.call()


## 確かめをやめる（ボタンと下の文を戻す）。確かめていなければ何もしない。
func stop_confirm() -> void:
	_confirming = null
	_map_button.text = Text.t(MAP_TEXT)
	_map_button.theme_type_variation = &""
	_start_button.text = _start_text
	_start_button.theme_type_variation = UiTheme.BUTTON_PRIMARY
	_warning.text = Text.t(WARNING_TEXT)


## 確かめの途中なら、下に出している理由の文（確かめていなければ空）。検査用。
func confirming_text() -> String:
	return "" if _confirming == null else _warning.text


## 確かめを始めた直後の、2 回目を受けない間を、もう過ぎたことにする。検査用（人が間を置いてもう一度押すのと同じ）。
func pass_confirm_guard() -> void:
	_confirm_started_msec -= BattleUiState.CONFIRM_GUARD_MSEC


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
	stop_confirm()  # 選び直したら、確かめはやめる
	var side_value: int = RANDOM_SIDE if _choice.random_side else _choice.human_side
	var current := {
		&"opponent": _choice.cpu_opponent, &"human_side": side_value,
		&"army0": _choice.armies[0], &"army1": _choice.armies[1],
	}
	for key: StringName in _rows:
		var buttons: Dictionary = _rows[key]
		for value: Variant in buttons:
			(buttons[value] as Button).set_pressed_no_signal(value == current[key])
	_map_name.text = "%d %s" % [VersusFields.number_of(_choice.field), VersusFields.title_of(_choice.field)]
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
		_edit_buttons[side].visible = human and _can_edit_decks
		_fill_deck_picker(side as Unit.Side)
		# ランダム編成は対戦を作るときに組むので、まだ組んでいなければ見せるものが無い（対戦の途中なら、いまの対戦の部隊を見せる）。
		var shown := preview_deck(side as Unit.Side) != null
		_preview_buttons[side].disabled = not shown
		_preview_buttons[side].tooltip_text = "" if shown else Text.t("setup.deck.random_note")


## 手番の行の注記（先手の必殺技のゲージ。始めが 0 なら空）。
static func first_gauge_note() -> String:
	if Ults.FIRST_PLAYER_START_GAUGE <= 0:
		return ""
	return Text.t("setup.side.first_gauge", {"percent": Ults.FIRST_PLAYER_START_GAUGE * 100 / Ults.GAUGE_MAX})


## side の行の見出し。CPU 戦なら「あなた」「CPU」と手番、人どうしなら手番だけ。
func who_text(side: Unit.Side) -> String:
	var turn: String = [Text.t("setup.side.first"), Text.t("setup.side.second")][side]
	if not _choice.cpu_opponent:
		return turn
	var who := Text.t("setup.who.you") if _choice.is_human(side) else "CPU"
	return who if _choice.random_side else Text.t("setup.who_side", {"who": who, "turn": turn})


## side の部隊（「編成確認」で出すもの）。選んだ部隊か既定の編成（CPU の行なら CPU の編成。中身は既定の編成と同じ）。
## ランダム編成なら、最後に作った対戦で組んだ部隊（まだ組んでいなければ null）。
func preview_deck(side: Unit.Side) -> Deck:
	if _choice.is_random(side):
		return _choice.drawn_deck(side)
	if not _choice.is_human(side) and _choice.deck_ids[side] == "":
		return CpuDeck.build(_choice.armies[side])
	return _choice.deck_for(side)


## 「編成を確認」: side の部隊を札にして出す。
func open_preview(side: Unit.Side) -> void:
	stop_confirm()
	var deck := preview_deck(side)
	if deck == null:
		return
	# ランダムの間は陣営が決まっていないので、あなたは青、CPU は赤で見せる。
	_preview.open(who_text(side), deck, side)


## side の「編成確認」を押せるか（検査用）。
func can_preview(side: Unit.Side) -> bool:
	return not _preview_buttons[side].disabled


## 編成の確認の画面（検査用）。
func preview() -> DeckPreview:
	return _preview


## 「マップを選び直す」。対戦の途中なら、1 回目は確かめるだけで、もう一度押すとマップ選択へ（_press_or_confirm）。
func press_map() -> void:
	_press_or_confirm(_map_button, _leave_for_map)


func _leave_for_map() -> void:
	stop_confirm()
	visible = false
	map_pressed.emit(_choice.copy())


## 「部隊編成」（side の部隊を組む）。
func press_edit_decks(side: Unit.Side) -> void:
	visible = false
	decks_pressed.emit(_choice.copy(), side)


## 「マップ変更」が出ているか（検査用）。
func map_button_shown() -> bool:
	return _map_button.visible


## 「部隊編成」が出ているか（検査用）。
func can_edit_decks() -> bool:
	return _can_edit_decks


## side の部隊の選択肢を並べ直す: 既定の編成（CPU の行では「CPU の編成」）、ランダム編成、その軍の取っておいた部隊（出せないものは理由つきで、選べない）。
func _fill_deck_picker(side: Unit.Side) -> void:
	var army: UnitKind.Army = _choice.armies[side]
	var default_deck := MatchSetup.default_deck(army)
	var default_key := "setup.deck.default" if _choice.is_human(side) else "setup.deck.cpu"
	var options: Array = [
		["", Text.t(default_key, {"cost": default_deck.total_cost(), "budget": default_deck.budget()}), true],
		[MatchChoice.RANDOM, Text.t("setup.deck.random"), true],
	]
	if _library != null:
		for item: RefCounted in _library.for_rules(DeckRules.VERSUS, army):
			var playable: bool = item.playable()
			var text := Text.t("setup.deck.saved", {"name": item.name, "cost": item.deck.total_cost(), "budget": item.deck.budget()})
			if not playable:
				text = Text.t("setup.deck.unplayable", {"name": item.name, "issue": item.issues()[0]})
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
