extends Control
## 対戦の前に、軍・ステージ・相手・手番を選ぶ、飾らない最小の画面。
##
## 選んだもの（trial_setup.gd）を持ち、「対戦を始める」で start_pressed を出す。ルールは持たない。
## 編成は軍ごとの既定の編成で、中身を文字で見せるだけ（選べない）。

## 選んだもの（trial_setup.gd の値。呼ぶ側に渡すのは写し）。
signal start_pressed(choice: RefCounted)

const TrialSetup := preload("res://prototype/trial_setup.gd")

const ARMY_NAMES := {UnitKind.Army.MILITARY: "MILITARY", UnitKind.Army.FANTASY: "FANTASY"}
const ARMIES: Array[UnitKind.Army] = [UnitKind.Army.MILITARY, UnitKind.Army.FANTASY]
const COLOR_PANEL := Color(0.07, 0.09, 0.12, 0.92)
const COLOR_TEXT_DIM := Color(0.75, 0.78, 0.82)

var _choice: RefCounted = TrialSetup.new()
var _team_colors: Array[Color] = []
## 選択肢の名前 -> その行のボタン（値 -> Button）。
var _rows := {}
var _deck_labels: Array[Label] = []
var _side_row: Control
var _side_caption: Label


func setup(team_colors: Array[Color]) -> void:
	_team_colors = team_colors
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
		var deck := _label(14)
		deck.add_theme_color_override("font_color", COLOR_TEXT_DIM)
		column.add_child(deck)
		_deck_labels.append(deck)

	var note := _label(14)
	note.text = "編成は軍ごとの既定の編成（予算どおり）。先手から動く"
	note.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(note)
	var start := _button("対戦を始める")
	start.custom_minimum_size = Vector2(220.0, 52.0)
	start.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start.pressed.connect(confirm)
	column.add_child(start)
	_show_choice()


## いまの選択を choice の写しにして、画面を出す。
func open(choice: RefCounted) -> void:
	_choice = choice.copy()
	_show_choice()
	visible = true


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
	_choice.armies[side] = army
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
		var who := "CPU" if match_setup.is_cpu(side as Unit.Side) else "人"
		_deck_labels[side].text = "　%s: %s" % [who, _deck_text(match_setup.decks[side])]


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


static func _deck_text(deck: Deck) -> String:
	var parts: Array[String] = ["将"]
	for entry in deck.entries:
		var text := UnitKind.display_name(entry.kind)
		for item in entry.equipment:
			text += "+" + Equipment.display_name(item)
		parts.append(text)
	return "、".join(parts)


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
