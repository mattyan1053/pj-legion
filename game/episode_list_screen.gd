extends Node
## 話の一覧の場面（docs/story.md）。物語を選ぶ場面（campaign_list_screen.gd）のあと。いまの物語（story.gd の campaign）の話のカードを並べ、選んだ話の流れ（会話 → 出撃の準備 → 対戦 → 会話）を始める。
## 背景は対戦と同じ景色（backdrop.gd）。場面の決まりは scene_flow.gd。話の流れを終えたら、ここへ戻る（story.gd の run_of）。
##
## - カードには、話の番号と名前、盤の縮図（stage_card_map.gd。両軍の駒の初期位置に点）、クリアしたか、クリアで増えるもの（駒、持ち物、コストの上限）を載せる。
## - 話が多いと横に並びきらないので、横に送れる枠に入れる。チュートリアルの話（LESSON のある話）の番号には「（演習）」を付ける。
##   同じマップを使い回す話でも、初期位置の違いが見える。
## - 話は一本道。前の話をクリアしていない話のカードは押せない（「第 N 話をクリアすると遊べる」）。クリアした話は遊び直せる。
## - カードのクリック（1〜9 のキーでも）で、その話を始める。
## - 下の欄に、いま雇える駒・持ち物・コストの上限（クリアした話から求める）。
## - 「物語を選び直す」（右クリック・Esc でも）で &"back"（物語を選ぶ場面へ）。

const Palette := preload("res://game/ui_palette.gd")
const UiTheme := preload("res://game/ui_theme.gd")
const AppContext := preload("res://game/app_context.gd")
const Backdrop := preload("res://game/backdrop.gd")
const BattleScreen := preload("res://game/battle_screen.gd")
const StageCardMap := preload("res://game/stage_card_map.gd")
const Story := preload("res://game/story.gd")
const StoryBattle := preload("res://game/story_battle.gd")

signal finished(outcome: StringName)

const CARD_WIDTH := 280.0
## 縮図の 1 マスの大きさ（px）と、縮図を置く枠の高さ。
const MAP_CELL := 8
const MAP_HEIGHT := 180.0

const COLOR_PANEL := Palette.OVERLAY
const COLOR_TEXT_DIM := Palette.TEXT_DIM
const COLOR_CLEARED := Palette.ACCENT
const COLOR_NEW := Palette.INFO
const COLOR_LOCKED := Palette.TEXT_OFF

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
	layer.add_child(UiTheme.vignette())
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_top = 36.0
	root.offset_bottom = -28.0
	root.add_theme_constant_override("separation", 18)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var heading := _label(context.story.campaign.TITLE, 40)
	heading.theme_type_variation = UiTheme.LABEL_HEADING
	heading.add_theme_constant_override("outline_size", 10)  # 景色の上に直に置くので、縁取りを太くする
	root.add_child(heading)
	var sub := _label("話を選ぶ", 18)
	sub.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	root.add_child(sub)

	# 話が多いと横に並びきらないので、横に送れる枠に入れる（マウスのホイールでも送れる）。
	# 開いたときは、次に遊ぶ話のカードが見えるところまで送っておく。
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0.0, MAP_HEIGHT + 172.0)
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	root.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(center)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(row)
	for episode: Script in context.story.campaign.EPISODES:
		var card := _build_card(episode)
		row.add_child(card)
		_cards[episode] = card
	scroll.ensure_control_visible.call_deferred(_cards[context.story.next_episode()])

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
	back.text = "物語を選び直す"
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


## 「物語を選び直す」。
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


## 下の欄の文: いま雇える駒、持たせられる持ち物、部隊のコストの上限（話をクリアすると増える）。
func roster_text() -> String:
	var now: RefCounted = context.story.unlocked()
	var kinds: Array[String] = []
	for kind: UnitKind.Id in now.kinds:
		kinds.append(UnitKind.display_name(kind))
	var items: Array[String] = []
	for item: Equipment.Id in now.items:
		items.append(Equipment.display_name(item))
	return "いま雇える駒: %s\n持ち物: %s　　コストの上限: %d\n（話をクリアすると増える。部隊は「部隊の編成」の「ストーリー用」で組める）" % [
		"・".join(kinds), "・".join(items) if not items.is_empty() else "なし", now.budget]


## 話 episode のクリアで増えるものの短い文（無ければ空）。カードに出す。
static func rewards_text(episode: Script) -> String:
	var parts: Array[String] = []
	for kind: UnitKind.Id in episode.UNLOCKS:
		parts.append(UnitKind.display_name(kind))
	for item: Equipment.Id in StoryBattle.unlock_items_of(episode):
		parts.append(Equipment.display_name(item))
	if StoryBattle.budget_up_of(episode) > 0:
		parts.append("コスト +%d" % StoryBattle.budget_up_of(episode))
	return "" if parts.is_empty() else "クリアで増える:\n" + "・".join(parts)


## 話 episode の状態の文。
func status_text(episode: Script) -> String:
	if context.story.is_cleared(episode.ID):
		return "クリア済み"
	if not context.story.is_available(episode):
		return "第 %d 話をクリアすると遊べる" % (Story.number_of(episode) - 1)
	return "未クリア"


## 右クリックと Esc は 1 つ戻る（物語を選ぶ場面へ）。カードの上でも効くよう、ボタンより先に受ける。
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
	var listed: Array[Script] = context.story.campaign.EPISODES
	if number >= 0 and number < listed.size() and context.story.is_available(listed[number]):
		context.play_sound(&"ui_confirm")
		choose(listed[number])


func _build_card(episode: Script) -> Button:
	var available: bool = context.story.is_available(episode)
	var card := Button.new()
	card.focus_mode = Control.FOCUS_NONE
	card.custom_minimum_size = Vector2(CARD_WIDTH, MAP_HEIGHT + 170.0)
	card.disabled = not available
	card.set_meta(&"sound", &"ui_confirm")  # 決める音（sound.gd）
	card.theme_type_variation = UiTheme.BUTTON_CARD  # カードの板と、乗ったときの金の縁（docs/ui-theme.md）
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
	var number := _label(("第 %d 話（演習）" if StoryBattle.lesson_of(episode) != "" else "第 %d 話") % Story.number_of(episode), 16)
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
	if rewards_text(episode) != "":
		var unlocks := _label(rewards_text(episode), 15)
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
	var style := UiTheme.box(color, Color(Palette.BORDER, 0.9), 1, 8, 14.0)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel


func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", 5)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
