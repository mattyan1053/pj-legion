extends Node
## 物語を選ぶ場面（docs/story.md の「物語を選ぶ」）。タイトルの「ストーリー」のあと、話の一覧の前。
## 背景は対戦と同じ景色（backdrop.gd）。場面の決まりは scene_flow.gd。
##
## - 物語（軍 1 つと話の列。story.gd の CAMPAIGNS）をカードで並べる。カードには物語の名前、軍、クリアした話の数。
## - 話の無い物語は「準備中」の札で、押せない。遊べる物語が 1 つでも、選ぶ場面は飛ばさない（物語が増えていくことを見せる）。
## - カードのクリック（1〜9 のキーでも）で、その物語を選んで &"open"（その物語の話の一覧へ）。
## - 「タイトルへ戻る」（右クリック・Esc でも）で &"back"。

const Text := preload("res://game/text.gd")
const Palette := preload("res://game/ui_palette.gd")
const UiTheme := preload("res://game/ui_theme.gd")
const AppContext := preload("res://game/app_context.gd")
const Backdrop := preload("res://game/backdrop.gd")
const DeckText := preload("res://game/deck_text.gd")
const Campaign := preload("res://game/campaign.gd")
const Story := preload("res://game/story.gd")

signal finished(outcome: StringName)

const CARD_SIZE := Vector2(320.0, 200.0)

## 色は話の一覧（episode_list_screen.gd）とそろえる。
const COLOR_TEXT_DIM := Palette.TEXT_DIM
const COLOR_CLEARED := Palette.ACCENT
const COLOR_NEW := Palette.INFO
const COLOR_LOCKED := Palette.TEXT_OFF

var context: AppContext
## 物語（campaign.gd）-> カード（Button）。
var _cards := {}


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

	var heading := _label(Text.t("story.campaigns.heading"), 40)
	heading.theme_type_variation = UiTheme.LABEL_HEADING
	heading.add_theme_constant_override("outline_size", 10)  # 景色の上に直に置くので、縁取りを太くする
	root.add_child(heading)
	var sub := _label(Text.t("story.campaigns.sub"), 18)
	sub.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	root.add_child(sub)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(spacer)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 28)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(row)
	for campaign in Story.campaigns():
		var card := _build_card(campaign)
		row.add_child(card)
		_cards[campaign] = card
	var spacer_below := Control.new()
	spacer_below.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer_below.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(spacer_below)

	var back := Button.new()
	back.text = Text.t("menu.to_title")
	back.focus_mode = Control.FOCUS_NONE
	back.add_theme_font_size_override("font_size", 18)
	back.custom_minimum_size = Vector2(220.0, 48.0)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(press_back)
	root.add_child(back)


func resume_label() -> String:
	return Text.t("story.campaigns.resume")


## 物語 campaign を選んで、その話の一覧へ。準備中の物語なら何もしない。
func choose(campaign: Campaign) -> void:
	if not Story.is_ready(campaign):
		return
	context.story.choose_campaign(campaign)
	finished.emit(&"open")


## 「タイトルへ戻る」。
func press_back() -> void:
	finished.emit(&"back")


## 並んでいる物語（検査用）。
func campaigns() -> Array:
	return _cards.keys()


func is_card_enabled(campaign: Campaign) -> bool:
	return not (_cards[campaign] as Button).disabled


## 物語 campaign の状態の文（検査用にも）: 「準備中」「全 N 話」「M / N 話クリア」「全 N 話クリア」。
func status_text(campaign: Campaign) -> String:
	if not Story.is_ready(campaign):
		return Text.t("story.campaigns.preparing")
	var total: int = campaign.episodes.size()
	var cleared: int = context.story.cleared_count(campaign)
	if cleared == 0:
		return Text.t("story.campaigns.total", {"total": total})
	if cleared == total:
		return Text.t("story.campaigns.all_cleared", {"total": total})
	return Text.t("story.campaigns.cleared", {"cleared": cleared, "total": total})


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
	if number >= 0 and number < Story.campaigns().size() and Story.is_ready(Story.campaigns()[number]):
		context.play_sound(&"ui_confirm")
		choose(Story.campaigns()[number])


func _build_card(campaign: Campaign) -> Button:
	var ready := Story.is_ready(campaign)
	var card := Button.new()
	card.focus_mode = Control.FOCUS_NONE
	card.custom_minimum_size = CARD_SIZE
	card.disabled = not ready
	card.set_meta(&"sound", &"ui_confirm")  # 決める音（sound.gd）
	card.theme_type_variation = UiTheme.BUTTON_CARD  # カードの板と、乗ったときの金の縁（docs/ui-theme.md）
	card.pressed.connect(choose.bind(campaign))

	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 14.0
	column.offset_right = -14.0
	column.offset_top = 18.0
	column.offset_bottom = -14.0
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 10)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(column)
	var title := _label(campaign.title, 26)
	if not ready:
		title.add_theme_color_override("font_color", COLOR_LOCKED)
	column.add_child(title)
	var army := _label(Text.t("story.campaigns.army", {"army": DeckText.army_name(campaign.army)}), 16)
	army.add_theme_color_override("font_color", COLOR_TEXT_DIM if ready else COLOR_LOCKED)
	column.add_child(army)
	var status := _label(status_text(campaign), 18)
	var all_cleared: bool = ready and context.story.cleared_count(campaign) == campaign.episodes.size()
	status.add_theme_color_override("font_color", COLOR_CLEARED if all_cleared else (COLOR_NEW if ready else COLOR_LOCKED))
	column.add_child(status)
	return card


func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
