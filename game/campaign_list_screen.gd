extends Node
## 物語を選ぶ場面（docs/story.md の「物語を選ぶ」）。タイトルの「ストーリー」のあと、話の一覧の前。
## 背景はタイトルと同じ、裂けた空の下の結晶の森（title_backdrop.gd の VIEW_STORY）。場面の決まりは scene_flow.gd。
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
const TitleBackdrop := preload("res://game/title_backdrop.gd")
const DeckText := preload("res://game/deck_text.gd")
const Campaign := preload("res://game/campaign.gd")
const Story := preload("res://game/story.gd")
const UnitIcons := preload("res://game/unit_icons.gd")
const CardPicker := preload("res://game/card_picker.gd")
const TextWrap := preload("res://game/text_wrap.gd")
const Steady := preload("res://game/steady.gd")
const HeroNameWindow := preload("res://game/hero_name_window.gd")

signal finished(outcome: StringName)

## カードの大きさ。紹介の 1 行（物語のファイルの intro。40 字まで）が INTRO_MAX_LINES 行に折り返しても収まる高さ。
const CARD_SIZE := Vector2(320.0, 316.0)
## カードの中身の余白（px）: 左右、上（国の色の帯の下から）、下。中身は、この内側の真ん中に置く。
const CARD_PAD_SIDE := 14.0
const CARD_PAD_TOP := 20.0
const CARD_PAD_BOTTOM := 14.0
## 紹介の 1 行の文字の大きさ（px）と、折り返す幅（カードの幅から、左右の余白を引いたもの）。
## 行の数が少ない物語でも INTRO_MAX_LINES 行ぶんの高さを取る（カードの中の並びが、物語でそろう）。
const INTRO_FONT := 15
const INTRO_WIDTH := CARD_SIZE.x - CARD_PAD_SIDE * 2.0 - 8.0
const INTRO_MAX_LINES := 3
## カードの顔（その物語の軍の、将と最初から雇える駒のアイコン）の大きさ（px）と、準備中のカードの暗さ。
## 顔の並びは、決まった幅（FACES_WIDTH）の欄に収める: 入らなければ重ねを深くし、FACES_MAX より多ければ「ほか N」にまとめる。
const FACE_SIZE := 72.0
const FACES_WIDTH := CARD_SIZE.x - CARD_PAD_SIDE * 2.0
const FACES_MAX := 5
const FACES_OVERLAP := 8.0
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
## キーとマウスの受け方（card_picker.gd）。
var _keys: CardPicker
## 主人公の名前を付ける窓（物語を初めて選んだとき）。
var _hero_window: HeroNameWindow
var _backdrop: TitleBackdrop


func _ready() -> void:
	if context == null:
		context = AppContext.new()  # アプリを通さずに置いたとき
	# 背景はタイトルと同じ世界（裂けた空の下の結晶の森）。縫い目が真ん中に来るので、左のカードは琥珀の空、右のカードは菫の空の下に並ぶ。
	# 物語のカードに乗せると、その物語の景色（国の側の空、国の色の空、その物語の話のマップ。title_backdrop.gd の show_story）に替わる。
	_backdrop = TitleBackdrop.new(TitleBackdrop.VIEW_STORY)
	add_child(_backdrop)
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(UiTheme.vista_shade())
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
	heading.add_theme_font_override("font", UiTheme.spaced_heading(6))
	var ornament := Ornament.new(440.0, 16.0)
	ornament.color = Palette.ACCENT
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
	row.add_theme_constant_override("separation", 64)  # 2 枚の間に、空の縫い目が通る
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
	_hero_window = HeroNameWindow.new()
	_hero_window.setup(context.overlays)
	layer.add_child(_hero_window)
	_keys = CardPicker.new(context.overlays, context.play_sound)
	_keys.count = func() -> int: return Story.campaigns().size()
	_keys.enabled = func(i: int) -> bool: return Story.is_ready(Story.campaigns()[i])
	_keys.current = func() -> int: return _key_index
	_keys.selected = select_by_key
	_keys.chosen = func(i: int) -> void: choose(Story.campaigns()[i])
	_keys.back = press_back


func resume_label() -> String:
	return Text.t("story.campaigns.resume")


## 物語 campaign を選んで、その話の一覧へ。準備中の物語なら何もしない。
## 主人公の名前をまだ決めていない物語なら、先に名前の窓を出す（docs/story.md の「主人公の名前」。検査とスクリーンショットでは出さず、既定の名前のまま進む）。
func choose(campaign: Campaign) -> void:
	if not Story.is_ready(campaign):
		return
	if not context.story.is_hero_named(campaign) and context.checking == &"":
		ask_hero_name(campaign)
		return
	context.story.choose_campaign(campaign)
	finished.emit(&"open")


## 物語 campaign の主人公の名前を訊き、決まったら、その物語の話の一覧へ。
func ask_hero_name(campaign: Campaign) -> void:
	if _hero_window.is_open():
		return
	context.play_sound(&"menu_open")
	_hero_window.ask(context.story.hero_name(campaign), campaign.hero, campaign.hero_role(), func(named: String) -> void:
		context.story.name_hero(campaign, named)
		context.story.choose_campaign(campaign)
		finished.emit(&"open"))


## 主人公の名前の窓（検査用）。
func hero_window() -> HeroNameWindow:
	return _hero_window


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


func _input(event: InputEvent) -> void:
	_keys.input(event, get_viewport())


func _unhandled_input(event: InputEvent) -> void:
	_keys.unhandled_input(event, get_viewport())


## キーボードで index 番目の物語のカードを選ぶ（マウスを乗せたときと同じ見た目にする）。-1 で選ぶのをやめる。
func select_by_key(index: int) -> void:
	var listed := Story.campaigns()
	if _key_index >= 0:
		CardPicker.light(_cards[listed[_key_index]], false)
	_key_index = index
	if index >= 0:
		var card: Button = _cards[listed[index]]
		CardPicker.light(card, true)
		focus(listed[index])


## 物語 campaign を選んでいる（マウスを乗せた・キーで選んだ）: 背景を、その物語の景色に替える（とどまったら）。準備中の物語は替えない。
## 地面は、その物語でまだクリアしていない最初の話のマップ（Story.scape_episode_in）。
func focus(campaign: Campaign) -> void:
	if not Story.is_ready(campaign):
		return
	var episode := context.story.scape_episode_in(campaign)
	if _backdrop.story_key() == episode.id:
		return
	_backdrop.queue_story(campaign.army, episode.map.make_board(), episode.look, episode.id)


## 背景（検査とスクリーンショットの道具用）。
func backdrop() -> TitleBackdrop:
	return _backdrop


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
	if ready:
		card.mouse_entered.connect(focus.bind(campaign))
		card.mouse_exited.connect(func() -> void: _backdrop.cancel_queued())

	Steady.mark(card, "campaigns.card")
	card.add_child(CardDecor.new(campaign.army, ready))
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = CARD_PAD_SIDE
	column.offset_right = -CARD_PAD_SIDE
	column.offset_top = CARD_PAD_TOP
	column.offset_bottom = -CARD_PAD_BOTTOM
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 8)
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
	if campaign.intro != "":
		# 紹介の 1 行: 遊ぶ人が誰として、何をする物語か（物語のファイルの intro）。カードの幅で、語の途中で切らずに折り返す。
		var intro := _label("", INTRO_FONT)
		var font := UiTheme.FONT_BODY
		intro.text = TextWrap.fold(campaign.intro_for(context.story.hero_name(campaign)), INTRO_WIDTH,
			func(character: String) -> float: return font.get_string_size(character, HORIZONTAL_ALIGNMENT_LEFT, -1, INTRO_FONT).x)
		intro.add_theme_color_override("font_color", COLOR_TEXT_DIM if ready else COLOR_LOCKED)
		intro.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		intro.custom_minimum_size.y = font.get_height(INTRO_FONT) * INTRO_MAX_LINES + intro.get_theme_constant("line_spacing") * (INTRO_MAX_LINES - 1)
		column.add_child(intro)
	var status := _label(status_text(campaign), 18)
	var all_cleared: bool = ready and context.story.cleared_count(campaign) == campaign.episodes.size()
	status.add_theme_color_override("font_color", COLOR_CLEARED if all_cleared else (COLOR_NEW if ready else COLOR_LOCKED))
	column.add_child(status)
	return card


## カードの顔: その物語で人が使う軍の、将と最初から雇える駒（人の軍の青）。文字だけの札にしない。
## 並びは決まった幅（FACES_WIDTH）の欄の真ん中: 入らなければ重ねを深くし、FACES_MAX より多い駒は「ほか N」にまとめる。
static func faces_row(campaign: Campaign, ready := true) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.custom_minimum_size = Vector2(FACES_WIDTH, FACE_SIZE)
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var kinds: Array[UnitKind.Id] = [UnitKind.Id.KING]
	kinds.append_array(campaign.starting_kinds)
	var shown := mini(kinds.size(), FACES_MAX)
	var rest := kinds.size() - shown
	var more: Label = null
	var room := FACES_WIDTH
	if rest > 0:
		more = Label.new()
		more.text = Text.t("story.campaigns.more_faces", {"count": rest})
		more.add_theme_font_size_override("font_size", 14)
		more.add_theme_color_override("font_color", COLOR_TEXT_DIM)
		more.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		more.mouse_filter = Control.MOUSE_FILTER_IGNORE
		room -= more.get_minimum_size().x + FACES_OVERLAP
	# 少し重ねて、隊のように並べる。欄に入らない数なら、入るまで重ねを深くする。
	var gap := -FACES_OVERLAP
	if shown > 1:
		gap = minf(gap, floorf((room - FACE_SIZE * shown) / (shown - 1)))
	row.add_theme_constant_override("separation", int(gap))
	for i in shown:
		var face := UnitIcons.rect(kinds[i], 0, false, FACE_SIZE)
		if not ready:
			face.modulate = LOCKED_SHADE
		row.add_child(face)
	if more != null:
		# 「ほか N」は重ねない: 顔の並びとの間を、重ねたぶんだけ戻して空ける。
		var pad := MarginContainer.new()
		pad.add_theme_constant_override("margin_left", int(FACES_OVERLAP - gap))
		pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pad.add_child(more)
		row.add_child(pad)
	return row


## 顔の並び row に並んだ顔の数（「ほか N」は数えない。検査用）。
static func faces_shown(row: HBoxContainer) -> int:
	var count := 0
	for child in row.get_children():
		if child is TextureRect:
			count += 1
	return count


## 物語 campaign のカード（検査用）。
func card_of(campaign: Campaign) -> Button:
	return _cards[campaign]


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
