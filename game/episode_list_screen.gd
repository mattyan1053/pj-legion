extends Node
## 話の一覧の場面（docs/story.md）。タイトルの「ストーリー」のあと。話のカードを並べ、選んだ話の流れ（会話 → 対戦 → 会話）を始める。
## 背景は対戦と同じ景色（backdrop.gd）。場面の決まりは scene_flow.gd。話の流れを終えたら、ここへ戻る（story.gd の run_of）。
##
## - カードには、話の番号と名前、盤の縮図（stage_card_map.gd。両軍の駒の初期位置に点）、クリアしたか、クリアで増える駒を載せる。
##   同じマップを使い回す話でも、初期位置の違いが見える。
## - 話は一本道。前の話をクリアしていない話のカードは押せない（「第 N 話をクリアすると遊べる」）。クリアした話は遊び直せる。
## - カードのクリック（1〜9 のキーでも）で、その話を始める。
## - 下の欄に、いま雇える駒（クリアした話から求める）。
## - 「タイトルへ戻る」（右クリック・Esc でも）で &"back"。

const AppContext := preload("res://game/app_context.gd")
const Backdrop := preload("res://game/backdrop.gd")
const BattleScreen := preload("res://game/battle_screen.gd")
const StageCardMap := preload("res://game/stage_card_map.gd")
const Story := preload("res://game/story.gd")

signal finished(outcome: StringName)

const CARD_WIDTH := 280.0
## 縮図の 1 マスの大きさ（px）と、縮図を置く枠の高さ。
const MAP_CELL := 8
const MAP_HEIGHT := 200.0

const COLOR_CARD := Color(0.07, 0.09, 0.12, 0.88)
const COLOR_CARD_HOVER := Color(0.16, 0.2, 0.27, 0.95)
const COLOR_CARD_LOCKED := Color(0.05, 0.06, 0.08, 0.7)
const COLOR_BORDER := Color(1.0, 1.0, 1.0, 0.12)
const COLOR_BORDER_HOVER := Color("ffd76a")
const COLOR_PANEL := Color(0.07, 0.09, 0.12, 0.82)
const COLOR_TEXT_DIM := Color(0.8, 0.83, 0.88)
const COLOR_CLEARED := Color("ffd76a")
const COLOR_NEW := Color("8fe3ff")
const COLOR_LOCKED := Color(0.6, 0.62, 0.66)

var context: AppContext
## 話（Script）-> カード（Button）。
var _cards := {}
var _roster: Label


func _ready() -> void:
	if context == null:
		context = AppContext.new()  # アプリを通さずに置いたとき
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

	root.add_child(_label("ストーリー", 40))
	var sub := _label("話を選ぶ", 18)
	sub.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	root.add_child(sub)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 28)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(row)
	for episode in Story.EPISODES:
		var card := _build_card(episode)
		row.add_child(card)
		_cards[episode] = card

	var note := _panel(COLOR_PANEL)
	note.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	note.custom_minimum_size = Vector2(860.0, 0.0)
	root.add_child(note)
	_roster = _label("", 17)
	_roster.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	_roster.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_roster.custom_minimum_size = Vector2(830.0, 0.0)
	note.add_child(_roster)
	_roster.text = roster_text()

	var back := Button.new()
	back.text = "タイトルへ戻る"
	back.focus_mode = Control.FOCUS_NONE
	back.add_theme_font_size_override("font_size", 18)
	back.custom_minimum_size = Vector2(220.0, 48.0)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(press_back)
	root.add_child(back)


func resume_label() -> String:
	return "話の一覧へ戻る"


## 話 episode を始める（会話（前）から）。遊べない話なら何もしない。
func choose(episode: Script) -> void:
	if not context.story.is_available(episode):
		return
	context.start_run(context.story.run_now(episode))


## 「タイトルへ戻る」。
func press_back() -> void:
	finished.emit(&"back")


## 並んでいる話と、遊べるか（検査用）。
func episodes() -> Array:
	return _cards.keys()


func is_card_enabled(episode: Script) -> bool:
	return not (_cards[episode] as Button).disabled


## 話 episode のカードの状態の文（「クリア済み」など。検査用）。
func card_status(episode: Script) -> String:
	return status_text(episode)


## 下の欄の文: いま雇える駒。
func roster_text() -> String:
	var names: Array[String] = []
	for kind in context.story.unlocked_kinds():
		names.append(UnitKind.display_name(kind))
	return "いま雇える駒: %s（話をクリアすると増える）" % "・".join(names)


## 話 episode の状態の文。
func status_text(episode: Script) -> String:
	if context.story.is_cleared(episode.ID):
		return "クリア済み"
	if not context.story.is_available(episode):
		return "第 %d 話をクリアすると遊べる" % (Story.number_of(episode) - 1)
	return "未クリア"


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
	var number := -1
	if event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_9:
		number = event.physical_keycode - KEY_1
	elif event.physical_keycode >= KEY_KP_1 and event.physical_keycode <= KEY_KP_9:
		number = event.physical_keycode - KEY_KP_1
	if number >= 0 and number < Story.EPISODES.size() and context.story.is_available(Story.EPISODES[number]):
		context.play_sound(&"ui_confirm")
		choose(Story.EPISODES[number])


func _build_card(episode: Script) -> Button:
	var available: bool = context.story.is_available(episode)
	var card := Button.new()
	card.focus_mode = Control.FOCUS_NONE
	card.custom_minimum_size = Vector2(CARD_WIDTH, MAP_HEIGHT + 150.0)
	card.disabled = not available
	card.set_meta(&"sound", &"ui_confirm")  # 決める音（sound.gd）
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var hovered := state != "normal" and state != "disabled"
		var style := StyleBoxFlat.new()
		style.bg_color = COLOR_CARD_LOCKED if state == "disabled" else (COLOR_CARD_HOVER if hovered else COLOR_CARD)
		style.border_color = COLOR_BORDER_HOVER if hovered else COLOR_BORDER
		style.set_border_width_all(3 if hovered else 2)
		style.set_corner_radius_all(8)
		card.add_theme_stylebox_override(state, style)
	card.pressed.connect(choose.bind(episode))

	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 12.0
	column.offset_right = -12.0
	column.offset_top = 12.0
	column.offset_bottom = -10.0
	column.add_theme_constant_override("separation", 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(column)
	var number := _label("第 %d 話" % Story.number_of(episode), 16)
	number.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	column.add_child(number)
	column.add_child(_label(episode.TITLE, 24))
	var map := TextureRect.new()
	map.texture = ImageTexture.create_from_image(map_image(episode))
	map.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	map.custom_minimum_size = Vector2(0.0, MAP_HEIGHT)
	map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not available:
		map.modulate = Color(0.45, 0.45, 0.45)
	column.add_child(map)
	var status := _label(status_text(episode), 18)
	var cleared: bool = context.story.is_cleared(episode.ID)
	status.add_theme_color_override("font_color", COLOR_CLEARED if cleared else (COLOR_NEW if available else COLOR_LOCKED))
	column.add_child(status)
	if not episode.UNLOCKS.is_empty():
		var names: Array[String] = []
		for kind: UnitKind.Id in episode.UNLOCKS:
			names.append(UnitKind.display_name(kind))
		var unlocks := _label("クリアで増える駒: %s" % "・".join(names), 15)
		unlocks.add_theme_color_override("font_color", COLOR_TEXT_DIM if available else COLOR_LOCKED)
		column.add_child(unlocks)
	return card


## 話 episode の盤の縮図。両軍の駒の初期位置（初めて遊ぶときの既定の編成で置いたもの）に、陣営の色の点を打つ。
static func map_image(episode: Script) -> Image:
	var battle := Story.first_battle(episode).make_setup(1).create_battle()
	var image := StageCardMap.draw(battle.board, episode.LOOK, BattleScreen.TEAM_COLORS, MAP_CELL)
	for unit in battle.units:
		if unit.side == Unit.Side.NEUTRAL or unit.kind == UnitKind.Id.KING:
			continue
		var corner := unit.cell * MAP_CELL
		image.fill_rect(Rect2i(corner, Vector2i(MAP_CELL, MAP_CELL)), Color.BLACK)
		image.fill_rect(Rect2i(corner + Vector2i(1, 1), Vector2i(MAP_CELL - 2, MAP_CELL - 2)), BattleScreen.TEAM_COLORS[unit.side].lightened(0.2))
	return image


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
