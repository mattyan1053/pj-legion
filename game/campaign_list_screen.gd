extends Node
## 物語を選ぶ場面（docs/story.md の「物語を選ぶ」）。タイトルの「ストーリー」のあと、話の一覧の前。
## 背景は対戦と同じ景色（backdrop.gd）。場面の決まりは scene_flow.gd。
##
## - 物語（軍 1 つと話の列。story.gd の CAMPAIGNS）をカードで並べる。カードには物語の名前、軍、クリアした話の数。
## - 話の無い物語は「準備中」の札で、押せない。遊べる物語が 1 つでも、選ぶ場面は飛ばさない（物語が増えていくことを見せる）。
## - カードのクリックで、その物語を選んで &"open"（その物語の話の一覧へ）。キーボードでは、左右の矢印で選んで Enter（card_keys.gd。1〜9 のキーでも）。
## - 「タイトルへ戻る」（右クリック・Esc でも）で &"back"。

const SceneFlow := preload("res://game/scene_flow.gd")
const Text := preload("res://game/text.gd")
const Palette := preload("res://game/ui_palette.gd")
const UiTheme := preload("res://game/ui_theme.gd")
const Ornament := preload("res://game/ui_ornament.gd")
const Crest := preload("res://game/crest.gd")
const AppContext := preload("res://game/app_context.gd")
const Backdrop := preload("res://game/backdrop.gd")
const DeckText := preload("res://game/deck_text.gd")
const Campaign := preload("res://game/campaign.gd")
const Story := preload("res://game/story.gd")
const UnitIcons := preload("res://game/unit_icons.gd")
const CardKeys := preload("res://game/card_keys.gd")

signal finished(outcome: StringName)

const CARD_SIZE := Vector2(320.0, 270.0)
## カードの顔（その物語の軍の、将と最初から雇える駒のアイコン）の大きさ（px）と、準備中のカードの暗さ。
const FACE_SIZE := 72.0
const LOCKED_SHADE := Color(0.4, 0.4, 0.45)

## 色は話の一覧（episode_list_screen.gd）とそろえる。
const COLOR_TEXT_DIM := Palette.TEXT_DIM
const COLOR_CLEARED := Palette.ACCENT
const COLOR_NEW := Palette.INFO
const COLOR_LOCKED := Palette.TEXT_OFF

var context: AppContext
## 物語（campaign.gd）-> カード（Button）。
var _cards := {}
## 左右の矢印で選んでいるカードの番号（物語の並びの順。選んでいなければ -1）。
var _key_index := -1


func _ready() -> void:
	if context == null:
		context = AppContext.new()  # アプリを通さずに置いたとき
	add_child(Backdrop.new())
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(UiTheme.scene_shade())
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_top = 36.0
	root.offset_bottom = -28.0
	root.add_theme_constant_override("separation", 10)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var heading := _label(Text.t("story.campaigns.heading"), 40)
	heading.theme_type_variation = UiTheme.LABEL_HEADING
	heading.add_theme_constant_override("outline_size", 10)  # 景色の上に直に置くので、縁取りを太くする
	root.add_child(heading)
	var ornament := Ornament.new(360.0, 14.0)
	ornament.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	root.add_child(ornament)
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
		# カードの下に、その物語のストーリー用の部隊を組む「部隊編成」（準備中の物語には出さない）。
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 8)
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(column)
		var card := _build_card(campaign)
		column.add_child(card)
		_cards[campaign] = card
		var decks := Button.new()
		decks.text = Text.t("setup.edit_deck")
		decks.focus_mode = Control.FOCUS_NONE
		decks.add_theme_font_size_override("font_size", 16)
		decks.custom_minimum_size = Vector2(0.0, 40.0)
		decks.pressed.connect(press_edit_decks.bind(campaign))
		decks.modulate = Color.WHITE if Story.is_ready(campaign) else Color.TRANSPARENT  # 場所は取っておき、カードの高さをそろえる
		decks.disabled = not Story.is_ready(campaign)
		column.add_child(decks)
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


## 物語 campaign の「部隊編成」: その物語のストーリー用の部隊を組む（寄り道。編成の「物語選択へ戻る」で、ここへ戻る）。
## 物語を、いまの物語にしてから始める（取っておいた部隊を、その物語の出撃準備で選んでおく）。準備中の物語なら何もしない。
func press_edit_decks(campaign: Campaign) -> void:
	if not Story.is_ready(campaign):
		return
	context.story.choose_campaign(campaign)
	context.start_run(Story.deck_run(campaign, SceneFlow.CAMPAIGNS, "story.episodes.back"))


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
	if context.overlays.is_open():
		return
	var listed := Story.campaigns()
	var step := CardKeys.direction(event)
	if step != 0:
		get_viewport().set_input_as_handled()
		select_by_key(CardKeys.next(_key_index, step, listed.size(), func(i: int) -> bool: return Story.is_ready(listed[i])))
		return
	if CardKeys.is_accept(event) and _key_index >= 0:
		get_viewport().set_input_as_handled()
		context.play_sound(&"ui_confirm")
		choose(listed[_key_index])
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var number := -1
	if event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_9:
		number = event.physical_keycode - KEY_1
	elif event.physical_keycode >= KEY_KP_1 and event.physical_keycode <= KEY_KP_9:
		number = event.physical_keycode - KEY_KP_1
	if number >= 0 and number < Story.campaigns().size() and Story.is_ready(Story.campaigns()[number]):
		context.play_sound(&"ui_confirm")
		choose(Story.campaigns()[number])


## キーボードで index 番目の物語のカードを選ぶ（マウスを乗せたときと同じ見た目にする）。-1 で選ぶのをやめる。
func select_by_key(index: int) -> void:
	var listed := Story.campaigns()
	if _key_index >= 0:
		(_cards[listed[_key_index]] as Button).remove_theme_stylebox_override("normal")
	_key_index = index
	if index >= 0:
		var card: Button = _cards[listed[index]]
		card.add_theme_stylebox_override("normal", card.get_theme_stylebox("hover"))


## キーボードで選んでいる物語（無ければ null。検査用）。
func key_choice() -> Campaign:
	return null if _key_index < 0 else Story.campaigns()[_key_index]


func _build_card(campaign: Campaign) -> Button:
	var ready := Story.is_ready(campaign)
	var card := Button.new()
	card.focus_mode = Control.FOCUS_NONE
	card.custom_minimum_size = CARD_SIZE
	card.disabled = not ready
	card.set_meta(&"sound", &"ui_confirm")  # 決める音（sound.gd）
	card.theme_type_variation = UiTheme.BUTTON_CARD  # カードの板と、乗ったときの金の縁（docs/ui-theme.md）
	card.pressed.connect(choose.bind(campaign))
	card.mouse_entered.connect(func() -> void: select_by_key(-1))  # マウスに持ち替えたら、キーの選びはやめる

	card.add_child(CardDecor.new(campaign.army, ready))
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
	column.add_child(faces_row(campaign, ready))
	var title := _label(campaign.title, 26)
	title.add_theme_font_override("font", UiTheme.FONT_HEADING)
	if not ready:
		title.add_theme_color_override("font_color", COLOR_LOCKED)
	column.add_child(title)
	var army := _label(Text.t("story.campaigns.army", {"army": DeckText.army_name(campaign.army)}), 16)
	army.add_theme_color_override("font_color", Crest.color_of(campaign.army).lightened(0.25) if ready else COLOR_LOCKED)
	column.add_child(army)
	var status := _label(status_text(campaign), 18)
	var all_cleared: bool = ready and context.story.cleared_count(campaign) == campaign.episodes.size()
	status.add_theme_color_override("font_color", COLOR_CLEARED if all_cleared else (COLOR_NEW if ready else COLOR_LOCKED))
	column.add_child(status)
	return card


## カードの顔: その物語で人が使う軍の、将と最初から雇える駒（人の軍の青）。文字だけの札にしない。
static func faces_row(campaign: Campaign, ready := true) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", -8)  # 少し重ねて、隊のように並べる
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var kinds: Array[UnitKind.Id] = [UnitKind.Id.KING]
	kinds.append_array(campaign.starting_kinds)
	for kind in kinds:
		var face := UnitIcons.rect(kind, 0, false, FACE_SIZE)
		if not ready:
			face.modulate = LOCKED_SHADE
		row.add_child(face)
	return row


func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## 物語のカードの飾り: その国の色の帯（上の縁）と、薄く大きな国の紋（地紋）。準備中の物語は、色を抜く。
class CardDecor extends Control:
	const BAND := 5.0
	const INSET := 2.0
	var _army: UnitKind.Army
	var _ready_to_play: bool

	func _init(army: UnitKind.Army, ready: bool) -> void:
		_army = army
		_ready_to_play = ready
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var color := Crest.color_of(army) if ready else Palette.TEXT_OFF
		var crest := Crest.new(army, 0.0, Color(color, 0.16 if ready else 0.08))
		crest.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		crest.offset_left = 30.0
		crest.offset_right = -30.0
		crest.offset_top = 26.0
		crest.offset_bottom = -22.0
		add_child(crest)

	func _draw() -> void:
		var color := Crest.color_of(_army) if _ready_to_play else Palette.TEXT_OFF
		# 上の縁の帯（真ん中が濃く、両端へ薄く）と、その下の淡い光。
		var middle := size.x / 2.0
		for part: Array in [[INSET + 6.0, middle, 0.25, 1.0], [middle, size.x - INSET - 6.0, 1.0, 0.25]]:
			draw_polygon(
				PackedVector2Array([Vector2(part[0], INSET), Vector2(part[1], INSET), Vector2(part[1], INSET + BAND), Vector2(part[0], INSET + BAND)]),
				PackedColorArray([Color(color, part[2]), Color(color, part[3]), Color(color, part[3]), Color(color, part[2])]))
		draw_polygon(
			PackedVector2Array([Vector2(INSET, INSET + BAND), Vector2(size.x - INSET, INSET + BAND), Vector2(size.x - INSET, size.y * 0.5), Vector2(INSET, size.y * 0.5)]),
			PackedColorArray([Color(color, 0.14), Color(color, 0.14), Color(color, 0.0), Color(color, 0.0)]))
