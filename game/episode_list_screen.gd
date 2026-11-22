extends Node
## 話の一覧の場面（docs/story.md）。物語を選ぶ場面（campaign_list_screen.gd）のあと。いまの物語（story.gd の campaign）の話のカードを並べ、選んだ話の流れ（出撃準備 → 会話 → 対戦 → 会話）を始める。
## 背景はタイトルと同じ、裂けた空の下の結晶の森を、その物語の国の側の空へ向いて見たもの（title_backdrop.gd）。場面の決まりは scene_flow.gd。話の流れを終えたら、ここへ戻る（story.gd の run_of）。
##
## - カードには、話の番号と名前、盤の縮図（map_card.gd。両軍の駒の初期位置に点）、クリアしたか、クリアで増えるもの（駒、持ち物、コストの上限）を載せる。
## - 話が多いと横に並びきらないので、横に送れる枠に入れる。チュートリアルの話（lesson のある話）の番号には「（演習）」を付ける。
##   同じマップを使い回す話でも、初期位置の違いが見える。
## - 話は一本道。前の話をクリアしていない話のカードは押せない（「第 N 話をクリアすると遊べる」）。クリアした話は遊び直せる。
##   まだ遊べない話は、名前・縮図・顔を伏せる（「？？？」。遊べるようになるまで中身を見せない）。番号と、開く条件とクリアで増えるものは見せる。
## - カードのクリックで、その話を始める。キーボードでは、左右の矢印で選んで Enter（card_keys.gd。1〜9 のキーでも、その番号の話）。
## - 下の欄に、いま雇える駒・持ち物・コストの上限（クリアした話から求める）。
## - 「部隊編成」で、この物語のストーリー用の部隊を組む（寄り道。戻るとここ）。
## - 「物語を選び直す」（右クリック・Esc でも）で &"back"（物語を選ぶ場面へ）。

const Text := preload("res://game/text.gd")
const Steady := preload("res://game/steady.gd")
const Names := preload("res://game/names.gd")
const Palette := preload("res://game/ui_palette.gd")
const UiTheme := preload("res://game/ui_theme.gd")
const Ornament := preload("res://game/ui_ornament.gd")
const Crest := preload("res://game/crest.gd")
const AppContext := preload("res://game/app_context.gd")
const TitleBackdrop := preload("res://game/title_backdrop.gd")
const NationDecor := preload("res://game/nation_decor.gd")
const BattleScreen := preload("res://game/battle_screen.gd")
const MapCard := preload("res://game/map_card.gd")
const MapFrame := preload("res://game/map_frame.gd")
const Episode := preload("res://game/episode.gd")
const Story := preload("res://game/story.gd")
const StoryBattle := preload("res://game/story_battle.gd")
const UnitIcons := preload("res://game/unit_icons.gd")
const SceneFlow := preload("res://game/scene_flow.gd")
const TextWrap := preload("res://game/text_wrap.gd")
const CardKeys := preload("res://game/card_keys.gd")
const UnitFrame := preload("res://game/unit_frame.gd")
const App := preload("res://game/app.gd")

signal finished(outcome: StringName)

const CARD_WIDTH := 280.0
## 下の欄（いま雇える駒・持ち物・コスト上限）の文の幅。
const ROSTER_WIDTH := 830.0
## 縮図の 1 マスの大きさ（px）と、縮図を置く枠の高さ。
const MAP_CELL := 8
const MAP_HEIGHT := 180.0
## 縮図の右下に重ねる、その話の顔（敵の話し手の姿のアイコン）の大きさ（px）。
const FACE_SIZE := 72.0
## 主な人物の欄（物語のファイルの [cast]）: 姿の額の大きさと、人と人の間（px）。
const CAST_FACE := 40.0
const CAST_GAP := 22

const COLOR_PANEL := Palette.OVERLAY
const COLOR_TEXT_DIM := Palette.TEXT_DIM
const COLOR_CLEARED := Palette.ACCENT
const COLOR_NEW := Palette.INFO
const COLOR_LOCKED := Palette.TEXT_OFF

var context: AppContext
## 話（episode.gd）-> カード（Button）。
var _cards := {}
var _roster: Label
var _saved: Label
var _scroll: ScrollContainer
var _backdrop: TitleBackdrop
## 左右の矢印で選んでいるカードの番号（話の並びの順。選んでいなければ -1）。
var _key_index := -1


func _ready() -> void:
	if context == null:
		context = AppContext.new()  # アプリを通さずに置いたとき
	# 背景はタイトルと同じ裂けた空の下で、その物語の国の側の空へ向き、空をその国の色へ寄せる（ベルク連邦は琥珀、リュエル騎士領は菫）。
	# 地面は、選んでいる話のマップの景色（開いたときは次に遊ぶ話。カードに乗せると、その話のマップに替わる。title_backdrop.gd の show_story）。
	var army: UnitKind.Army = context.story.campaign.army
	_backdrop = TitleBackdrop.new()
	var first := context.story.next_episode()
	_backdrop.show_story(army, first.map.make_board(), first.look, first.id)
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

	# 見出し: 物語の名前を、その国の紋で左右から挟む。
	var nation := Crest.color_of(army)
	var head_row := HBoxContainer.new()
	head_row.alignment = BoxContainer.ALIGNMENT_CENTER
	head_row.add_theme_constant_override("separation", 18)
	head_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(head_row)
	head_row.add_child(Crest.new(army, 44.0, nation.lightened(0.15)))
	var heading := _label(context.story.campaign.title, 40)
	heading.theme_type_variation = UiTheme.LABEL_HEADING
	heading.add_theme_font_override("font", UiTheme.spaced_heading(4))
	heading.add_theme_constant_override("outline_size", 10)  # 景色の上に直に置くので、縁取りを太くする
	head_row.add_child(heading)
	head_row.add_child(Crest.new(army, 44.0, nation.lightened(0.15)))
	var ornament := Ornament.new(440.0, 16.0)
	ornament.color = nation.lightened(0.1)  # その物語の国の色
	ornament.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	root.add_child(ornament)
	# 見出しの下: 主な人物（物語のファイルの [cast]。姿の額・名前・立ち位置）。書いていない物語は「話の選択」の小見出し。
	if context.story.campaign.cast.is_empty():
		var sub := _label(Text.t("story.episodes.sub"), 18)
		sub.add_theme_color_override("font_color", COLOR_TEXT_DIM)
		root.add_child(sub)
	else:
		root.add_child(cast_row(context.story.campaign))

	# 話が多いと横に並びきらないので、横に送れる枠に入れる（マウスのホイールでも送れる）。
	# 開いたときは、次に遊ぶ話のカードが見えるところまで送っておく。
	var scroll := ScrollContainer.new()
	_scroll = scroll
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0.0, MAP_HEIGHT + 172.0)
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	root.add_child(scroll)
	# 左右に余白を置き、送り切ったときもカードが画面の端に付かないようにする（マップ選択とそろえる）。
	# 幅に収まれば真ん中に寄せる。
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", UiTheme.SCROLL_ROW_EDGE)
	margin.add_theme_constant_override("margin_right", UiTheme.SCROLL_ROW_EDGE)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(margin)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 28)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)
	for episode: Episode in context.story.campaign.episodes:
		var card := _build_card(episode)
		row.add_child(card)
		_cards[episode] = card
	scroll.ensure_control_visible.call_deferred(_cards[context.story.next_episode()])

	var note := _panel(COLOR_PANEL)
	note.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	note.custom_minimum_size = Vector2(860.0, 0.0)
	root.add_child(note)
	note.add_child(NationDecor.new(army, 0.0, 40.0))  # 上の縁に、その国の色の帯
	_roster = _label("", 17)
	_roster.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	_roster.custom_minimum_size = Vector2(ROSTER_WIDTH, 0.0)
	note.add_child(_roster)
	# 持ち物が増えると 1 行に収まらない。Label の折り返しは語の切れ目を見ない（「コスト上限:」と数を分ける）ので、ここで折り返す。
	var font := _roster.get_theme_font("font")
	var font_size := _roster.get_theme_font_size("font_size")
	_roster.text = TextWrap.fold(roster_text(), ROSTER_WIDTH, func(character: String) -> float:
		return font.get_string_size(character, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 16)
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(footer)
	var back := Button.new()
	back.text = Text.t("story.episodes.back")
	back.focus_mode = Control.FOCUS_NONE
	back.add_theme_font_size_override("font_size", 18)
	back.custom_minimum_size = Vector2(220.0, 48.0)
	back.pressed.connect(press_back)
	footer.add_child(back)
	var decks := Button.new()
	decks.text = Text.t("setup.edit_deck")
	decks.focus_mode = Control.FOCUS_NONE
	decks.add_theme_font_size_override("font_size", 18)
	decks.custom_minimum_size = Vector2(220.0, 48.0)
	decks.pressed.connect(press_edit_decks)
	footer.add_child(decks)
	# 最後に保存した所（オートセーブ。docs/save-slots.md）。ほかの並びを動かさないよう、画面の右下の隅に置く。
	_saved = _label(saved_text(), 14)
	_saved.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	_saved.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_saved.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_saved.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_saved.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_saved.offset_right = -18.0
	_saved.offset_bottom = -10.0
	layer.add_child(_saved)


func resume_label() -> String:
	return Text.t("story.episodes.resume")


## 話 episode を始める（出撃準備から）。遊べない話なら何もしない。
func choose(episode: Episode) -> void:
	if not context.story.is_available(episode):
		return
	context.start_run(context.story.run_now(episode))


## 「部隊編成」: この物語のストーリー用の部隊を組む（寄り道。編成の「話の一覧へ戻る」で、ここへ戻る）。
func press_edit_decks() -> void:
	context.start_run(Story.deck_run(context.story.campaign, SceneFlow.EPISODES, "story.episodes.resume"))


## 「物語を選び直す」。
func press_back() -> void:
	finished.emit(&"back")


## 並んでいる話と、遊べるか（検査用）。
func episodes() -> Array:
	return _cards.keys()


func is_card_enabled(episode: Episode) -> bool:
	return not (_cards[episode] as Button).disabled


## 話 episode のカードの状態の文（「クリア済み」など。検査用）。
func card_status(episode: Episode) -> String:
	return status_text(episode)


## 下の欄の文: いま雇える駒、持たせられる持ち物、部隊のコストの上限（話をクリアすると増える）。
## 最後にオートセーブした時刻の文（「最後のオートセーブ: 日時」）。
func saved_text() -> String:
	return App.last_saved_text(context.slots)


func roster_text() -> String:
	var now: RefCounted = context.story.unlocked()
	var kinds: Array[String] = []
	for kind: UnitKind.Id in now.kinds:
		kinds.append(Names.kind(kind))
	var items: Array[String] = []
	for item: Equipment.Id in now.items:
		items.append(Names.item(item))
	return Text.t("story.episodes.roster", {
		"kinds": Text.join_dot(kinds), "items": Text.join_dot(items) if not items.is_empty() else Text.t("battle.hud.no_items"), "budget": now.budget,
	})


## 下の欄に出している文（折り返したあと。検査用）。
func roster_shown() -> String:
	return _roster.text


## 話 episode のクリアで増えるものの短い文（無ければ空）。カードに出す。
static func rewards_text(episode: Episode) -> String:
	var parts: Array[String] = []
	for kind: UnitKind.Id in episode.unlock_kinds:
		parts.append(Names.kind(kind))
	for item: Equipment.Id in episode.unlock_items:
		parts.append(Names.item(item))
	if episode.budget_up > 0:
		parts.append(Text.t("story.episodes.reward_budget", {"amount": episode.budget_up}))
	return "" if parts.is_empty() else Text.t("story.episodes.rewards", {"rewards": Text.join_dot(parts)})


## 話 episode の状態の文。
func status_text(episode: Episode) -> String:
	if context.story.is_cleared(episode.id):
		return Text.t("story.episodes.cleared")
	if not context.story.is_available(episode):
		return Text.t("story.episodes.locked", {"number": (Story.number_of(episode) - 1)})
	return Text.t("story.episodes.not_cleared")


## 右クリックと Esc は 1 つ戻る（物語を選ぶ場面へ）。カードの上でも効くよう、ボタンより先に受ける。
## 重なる画面（システムメニュー）が開いている間は、そちらが受ける。
func _input(event: InputEvent) -> void:
	if context.overlays.is_open():
		return
	if _key_index >= 0 and CardKeys.is_pointer_move(event):
		select_by_key(-1)  # マウスに持ち替えた（キーで送ってカードがマウスの下へ来ただけでは、やめない）
	if CardKeys.is_back(event):
		get_viewport().set_input_as_handled()
		context.play_sound(&"ui_back")
		press_back()


func _unhandled_input(event: InputEvent) -> void:
	if context.overlays.is_open():
		return
	var listed: Array[Episode] = context.story.campaign.episodes
	var step := CardKeys.direction(event)
	if step != 0:
		get_viewport().set_input_as_handled()
		var start := listed.find(context.story.next_episode())
		select_by_key(CardKeys.next(_key_index, step, listed.size(), func(i: int) -> bool: return context.story.is_available(listed[i]), start))
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
	if number >= 0 and number < listed.size() and context.story.is_available(listed[number]):
		context.play_sound(&"ui_confirm")
		choose(listed[number])


## キーボードで index 番目の話のカードを選ぶ（マウスを乗せたときと同じ見た目にし、見える所まで送る）。-1 で選ぶのをやめる。
func select_by_key(index: int) -> void:
	var listed: Array[Episode] = context.story.campaign.episodes
	if _key_index >= 0:
		(_cards[listed[_key_index]] as Button).remove_theme_stylebox_override("normal")
	_key_index = index
	if index < 0:
		return
	var card: Button = _cards[listed[index]]
	card.add_theme_stylebox_override("normal", card.get_theme_stylebox("hover"))
	_scroll.ensure_control_visible(card)
	focus(listed[index])


## 話 episode を選んでいる（マウスを乗せた・キーで選んだ）: 背景の景色を、その話のマップのものに替える（とどまったら）。まだ遊べない話は替えない。
func focus(episode: Episode) -> void:
	if not context.story.is_available(episode) or _backdrop.story_key() == episode.id:
		return
	_backdrop.queue_story(context.story.campaign.army, episode.map.make_board(), episode.look, episode.id)


## 背景が見せている（替える途中なら、これから見せる）話の id と、待たずに替える入口（検査とスクリーンショットの道具用）。
func backdrop() -> TitleBackdrop:
	return _backdrop


## キーボードで選んでいる話（無ければ null。検査用）。
func key_choice() -> Episode:
	return null if _key_index < 0 else context.story.campaign.episodes[_key_index]


func _build_card(episode: Episode) -> Button:
	var available: bool = context.story.is_available(episode)
	var card := Button.new()
	card.focus_mode = Control.FOCUS_NONE
	card.custom_minimum_size = Vector2(CARD_WIDTH, MAP_HEIGHT + 170.0)
	Steady.mark(card, "episodes.card")
	card.disabled = not available
	card.set_meta(&"sound", &"ui_confirm")  # 決める音（sound.gd）
	card.theme_type_variation = UiTheme.BUTTON_CARD  # カードの板と、乗ったときの金の縁（docs/ui-theme.md）
	card.pressed.connect(choose.bind(episode))
	if available:
		card.mouse_entered.connect(focus.bind(episode))
		card.mouse_exited.connect(func() -> void: _backdrop.cancel_queued())

	# 上の縁に国の色の帯と淡い光（物語のカードと同じ向き）。まだ遊べない話は色を抜く。次に遊ぶ話は、帯を金にして目立たせる。
	var decor := NationDecor.new(context.story.campaign.army, 0.0, 70.0)
	decor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not available:
		decor.band_color = Color(Palette.TEXT_OFF, 0.6)
	elif episode == context.story.next_episode() and not context.story.is_cleared(episode.id):
		decor.band_color = Palette.ACCENT
	card.add_child(decor)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 12.0
	column.offset_right = -12.0
	column.offset_top = 14.0
	column.offset_bottom = -10.0
	column.add_theme_constant_override("separation", 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(column)
	var number := _label(Text.t("story.episodes.number_drill" if episode.lesson != "" else "story.episodes.number", {"number": Story.number_of(episode)}), 16)
	number.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	column.add_child(number)
	var title := _label(card_title(episode), 24)
	title.add_theme_font_override("font", UiTheme.FONT_HEADING)
	if not available:
		title.add_theme_color_override("font_color", COLOR_LOCKED)
	column.add_child(title)
	var map := TextureRect.new()
	if available:
		map.texture = ImageTexture.create_from_image(map_image(episode))
	map.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	map.custom_minimum_size = Vector2(0.0, MAP_HEIGHT)
	map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not available:
		map.modulate = Color(0.45, 0.45, 0.45)
	column.add_child(map)
	if not available:
		# 伏せた縮図: 封をした札（暗い地に斜めの細い線、薄い国の紋）の上に「？？？」。後ろの景色は透かさない。
		map.add_child(Sealed.new(context.story.campaign.army))
	map.add_child(MapFrame.new())  # 真鍮の縁と四隅の鉤（選べない話は、縮図ごと沈む）
	if available:
		map.add_child(face_of(episode))
	else:
		var hidden := _label(Text.t("story.episodes.hidden"), 30)
		hidden.add_theme_font_override("font", UiTheme.FONT_HEADING)
		hidden.add_theme_color_override("font_color", Palette.TEXT_DIM)
		hidden.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hidden.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hidden.modulate = Color(1.0 / 0.45, 1.0 / 0.45, 1.0 / 0.45)  # 縮図ごと沈めたぶんを戻す（字は読めるように）
		map.add_child(hidden)
	var status := _label(status_text(episode), 18)
	var cleared: bool = context.story.is_cleared(episode.id)
	status.add_theme_color_override("font_color", COLOR_CLEARED if cleared else (COLOR_NEW if available else COLOR_LOCKED))
	column.add_child(status)
	if rewards_text(episode) != "":
		var unlocks := _label(rewards_text(episode), 15)
		unlocks.add_theme_color_override("font_color", COLOR_TEXT_DIM if available else COLOR_LOCKED)
		column.add_child(unlocks)
	return card


## カードに出す話の名前（まだ遊べない話は伏せる）。
func card_title(episode: Episode) -> String:
	return episode.title if context.story.is_available(episode) else Text.t("story.episodes.hidden")


## カードに縮図と顔を出しているか（まだ遊べない話は伏せる。検査用）。
func is_card_revealed(episode: Episode) -> bool:
	var card: Button = _cards[episode]
	for node in card.find_children("*", "TextureRect", true, false):
		if (node as TextureRect).texture != null:
			return true
	return false


## 話の顔: 敵の話し手の姿（話のファイルの figure。骸骨の将なども）のアイコンを、縮図の右下に重ねる。
static func face_of(episode: Episode) -> TextureRect:
	var figure: Dictionary = episode.figures[1]
	var face := UnitIcons.rect(figure["kind"], 1, figure.get("evolved", false), FACE_SIZE, figure.get("look", &""))
	face.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	face.offset_left = -FACE_SIZE
	face.offset_top = -FACE_SIZE
	return face


## 話 episode の盤の縮図。両軍の駒の初期位置（初めて遊ぶときの既定の編成で置いたもの）に、陣営の色の点を打つ。
static func map_image(episode: Episode) -> Image:
	var battle := Story.first_battle(episode).make_setup(1).create_battle()
	var image := MapCard.draw(battle.board, episode.look, BattleScreen.TEAM_COLORS, MAP_CELL)
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


## 主な人物の欄: 1 人ずつ、姿の額（人の軍の色）と、名前・立ち位置を横に並べる。
func cast_row(campaign: RefCounted) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", CAST_GAP)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.name = &"Cast"
	for person: Dictionary in campaign.cast:
		var figure: Dictionary = person["figure"]
		var entry := HBoxContainer.new()
		entry.add_theme_constant_override("separation", 8)
		entry.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(entry)
		var frame := UnitFrame.new(figure["kind"], 0, CAST_FACE, false, figure.get("evolved", false), figure.get("look", &""))
		frame.edge = Crest.color_of(campaign.army)
		entry.add_child(frame)
		var words := VBoxContainer.new()
		words.add_theme_constant_override("separation", -2)
		words.alignment = BoxContainer.ALIGNMENT_CENTER
		words.mouse_filter = Control.MOUSE_FILTER_IGNORE
		entry.add_child(words)
		var name_label := _label(person["name"], 16)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		name_label.add_theme_font_override("font", UiTheme.FONT_BOLD)
		words.add_child(name_label)
		var role := _label(person["role"], 13)
		role.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		role.add_theme_color_override("font_color", COLOR_TEXT_DIM)
		words.add_child(role)
	return row


func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", 5)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## 伏せた縮図の地（まだ遊べない話）。封をした札に見せる: 暗い地、斜めの細い線、真ん中に薄い国の紋。絵は使わず、ここで描く。
class Sealed extends Control:
	const Palette := preload("res://game/ui_palette.gd")
	const Crest := preload("res://game/crest.gd")
	## 斜めの線の間隔（px）。
	const HATCH := 12.0

	func _init(army: UnitKind.Army) -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = true
		var crest := Crest.new(army, 0.0, Color(Palette.TEXT_DIM, 0.22))
		crest.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 22)
		add_child(crest)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Palette.INK)
		var line := Color(Palette.BORDER_BRIGHT, 0.2)
		var at := -size.y
		while at < size.x:
			draw_line(Vector2(at, size.y), Vector2(at + size.y, 0.0), line, 1.0, true)
			at += HATCH
