extends Node
## ステージ選択の場面（タイトルの「始める」のあと、対戦の設定の前）。3 枚のカードから、戦うステージを選ぶ。
## 背景は対戦と同じ景色（backdrop.gd）。場面の決まりは scene_flow.gd。
##
## - カードには、そのステージの盤の縮図（stage_card_map.gd。盤はルールが作る）と名前、置かれているものを載せる。
## - マウスを乗せたカードは明るくなり、少し大きくなって、下の欄にステージの説明が出る。
## - カードのクリック（1〜3 のキーでも）で、選んだステージを context.match_choice に入れて &"pick"（対戦の設定へ）。
## - 「タイトルへ戻る」（右クリック・Esc でも）で &"back"。

const AppContext := preload("res://game/app_context.gd")
const Backdrop := preload("res://game/backdrop.gd")
const BattleScreen := preload("res://game/battle_screen.gd")
const StageCardMap := preload("res://game/stage_card_map.gd")
const StageLook := preload("res://game/stage_look.gd")

signal finished(outcome: StringName)

## ステージの説明（カードにマウスを乗せると出す）と、カードに載せる置かれているもの。
const STAGE_NOTES := {
	BoardGenerator.Stage.PLAIN: {
		"tags": "広場 ・ 起爆樽",
		"text": "開けた平地。中央は遮るもののない広場で、まわりに岩と森が散らばる。\n中央の左右に起爆樽。正面からぶつかり合う、基本の戦場。",
	},
	BoardGenerator.Stage.LABYRINTH: {
		"tags": "迷路 ・ 回復の泉",
		"text": "格子に並んだ壁が通路を作る迷路。射線が通りにくく、本陣へは回り道になる。\n左右に回復の泉。遠くから撃つより、角を曲がって近づく駒が強い。",
	},
	BoardGenerator.Stage.TWIN_SPRINGS: {
		"tags": "2 本の道 ・ ポータル",
		"text": "中央を大きな壁がふさぎ、戦場は左右 2 本の道に分かれる。本陣は対角。\nどちらの道にも、上下をつなぐポータル。どちらで攻め、どちらで守るか。",
	},
}
## 縮図の盤の種（いつも同じ縮図にする。対戦の盤は、始めるときに種を決めて作り直す）。
const MAP_SEED := 3
const MAP_SIZE := 240.0
const CARD_WIDTH := 300.0
## マウスを乗せたカードの大きさ。
const HOVER_SCALE := 1.04
const HOVER_TIME := 0.12
const PROMPT := "カードにマウスを乗せると、ステージの説明が出る。クリックで選んで、対戦の設定へ進む。"

const COLOR_CARD := Color(0.07, 0.09, 0.12, 0.88)
const COLOR_CARD_HOVER := Color(0.16, 0.2, 0.27, 0.95)
const COLOR_BORDER := Color(1.0, 1.0, 1.0, 0.12)
const COLOR_BORDER_HOVER := Color("ffd76a")
const COLOR_PANEL := Color(0.07, 0.09, 0.12, 0.82)
const COLOR_TEXT_DIM := Color(0.8, 0.83, 0.88)

var context: AppContext
## ステージ -> カード（Button）。
var _cards := {}
var _note_title: Label
var _note: Label
var _hovered := -1


func _ready() -> void:
	add_child(Backdrop.new())
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_top = 36.0
	root.offset_bottom = -28.0
	root.add_theme_constant_override("separation", 18)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var heading := _label("作戦領域を選ぶ", 40)
	root.add_child(heading)
	var sub := _label("SELECT BATTLEFIELD", 16)
	sub.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	sub.add_theme_constant_override("line_spacing", 0)
	root.add_child(sub)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 28)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(row)
	for stage: BoardGenerator.Stage in MatchSetup.STAGE_NAMES:
		var card := _build_card(stage)
		row.add_child(card)
		_cards[stage] = card

	var note_panel := _panel(COLOR_PANEL)
	note_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	note_panel.custom_minimum_size = Vector2(CARD_WIDTH * 3 + 28 * 2, 96.0)
	root.add_child(note_panel)
	var note_column := VBoxContainer.new()
	note_column.add_theme_constant_override("separation", 4)
	note_panel.add_child(note_column)
	_note_title = _label("", 20)
	_note_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	note_column.add_child(_note_title)
	_note = _label("", 17)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_note.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	note_column.add_child(_note)

	var back := Button.new()
	back.text = "タイトルへ戻る"
	back.focus_mode = Control.FOCUS_NONE
	back.add_theme_font_size_override("font_size", 18)
	back.custom_minimum_size = Vector2(220.0, 48.0)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(press_back)
	root.add_child(back)
	_show_note(-1)


func resume_label() -> String:
	return "ステージ選択へ戻る"


## stage を選んで、対戦の設定へ進む。
func choose(stage: BoardGenerator.Stage) -> void:
	context.match_choice.stage = stage
	finished.emit(&"pick")


## 「タイトルへ戻る」。
func press_back() -> void:
	finished.emit(&"back")


## stage のカードにマウスを乗せた（-1 なら離れた）。検査とスクリーンショットの道具も使う。
func hover(stage: int) -> void:
	if _hovered == stage:
		return
	if _hovered != -1:
		_set_card_hovered(_cards[_hovered], false)
	_hovered = stage
	if stage != -1:
		_set_card_hovered(_cards[stage], true)
	_show_note(stage)


## マウスを乗せているカードのステージ（無ければ -1）と、説明の欄の文字。検査用。
func hovered_stage() -> int:
	return _hovered


func note_text() -> String:
	return _note_title.text + "\n" + _note.text


func card_stages() -> Array:
	return _cards.keys()


## stage のカードの真ん中（画面の座標）。検査用。
func card_center(stage: int) -> Vector2:
	return (_cards[stage] as Control).get_global_rect().get_center()


## 右クリックと Esc は 1 つ戻る（タイトルへ）。カードの上でも効くよう、ボタンより先に受ける。
## 重なる画面（システムメニュー）が開いている間は、そちらが受ける。
func _input(event: InputEvent) -> void:
	if context.overlays.is_open():
		return
	var right: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT
	var escape: bool = event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE
	if right or escape:
		get_viewport().set_input_as_handled()
		context.play_sound(&"ui_back")
		press_back()


func _unhandled_input(event: InputEvent) -> void:
	if context.overlays.is_open() or not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_1, KEY_KP_1:
			_choose_by_key(BoardGenerator.Stage.PLAIN)
		KEY_2, KEY_KP_2:
			_choose_by_key(BoardGenerator.Stage.LABYRINTH)
		KEY_3, KEY_KP_3:
			_choose_by_key(BoardGenerator.Stage.TWIN_SPRINGS)


func _choose_by_key(stage: BoardGenerator.Stage) -> void:
	context.play_sound(&"ui_confirm")
	choose(stage)


func _show_note(stage: int) -> void:
	if stage == -1:
		_note_title.text = "ステージを選ぶ"
		_note.text = PROMPT
		return
	_note_title.text = "%d  %s　　%s" % [stage, MatchSetup.stage_name(stage), STAGE_NOTES[stage]["tags"]]
	_note.text = STAGE_NOTES[stage]["text"]


func _build_card(stage: BoardGenerator.Stage) -> Button:
	var card := Button.new()
	card.focus_mode = Control.FOCUS_NONE
	card.custom_minimum_size = Vector2(CARD_WIDTH, MAP_SIZE + 96.0)
	card.set_meta(&"sound", &"ui_confirm")  # 決める音（sound.gd）
	for state: String in ["normal", "hover", "pressed", "hover_pressed"]:
		var hovered := state != "normal"
		var style := StyleBoxFlat.new()
		style.bg_color = COLOR_CARD_HOVER if hovered else COLOR_CARD
		style.border_color = COLOR_BORDER_HOVER if hovered else COLOR_BORDER
		style.set_border_width_all(3 if hovered else 2)
		style.set_corner_radius_all(8)
		card.add_theme_stylebox_override(state, style)
		card.set_meta(&"hover_style" if hovered else &"normal_style", style)
	card.pressed.connect(choose.bind(stage))
	card.mouse_entered.connect(hover.bind(stage))
	card.mouse_exited.connect(func() -> void:
		if _hovered == stage:
			hover(-1))

	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 12.0
	column.offset_right = -12.0
	column.offset_top = 12.0
	column.offset_bottom = -10.0
	column.add_theme_constant_override("separation", 6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(column)
	var board := BoardGenerator.generate(stage, MAP_SEED)
	var map := TextureRect.new()
	map.texture = ImageTexture.create_from_image(StageCardMap.draw(board, StageLook.name_of_stage(stage), BattleScreen.TEAM_COLORS))
	map.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	map.custom_minimum_size = Vector2(MAP_SIZE, MAP_SIZE)
	map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(map)
	var name_label := _label("%d  %s" % [stage, MatchSetup.stage_name(stage)], 24)
	column.add_child(name_label)
	var tags := _label(STAGE_NOTES[stage]["tags"], 15)
	tags.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	column.add_child(tags)
	return card


func _set_card_hovered(card: Button, hovered: bool) -> void:
	card.pivot_offset = card.size / 2.0
	var tween := card.create_tween()
	tween.tween_property(card, "scale", Vector2.ONE * (HOVER_SCALE if hovered else 1.0), HOVER_TIME)
	# 道具が乗せたことにしたとき（マウスが乗っていないとき）も、明るい見た目にする。
	card.add_theme_stylebox_override("normal", card.get_meta(&"hover_style" if hovered else &"normal_style"))


func _panel(color: Color) -> PanelContainer:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(8)
	style.set_content_margin_all(14.0)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel


func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
