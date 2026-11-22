extends Node
## マップ選択の場面（タイトルの「対戦」のあと、対戦設定の前）。カードから、戦うマップを選ぶ（docs/map-select.md）。
## 背景は、タイトルと同じ裂けた空の下の、選んでいるマップの景色（title_backdrop.gd の VIEW_VERSUS）。場面の決まりは scene_flow.gd。選べるマップの一覧は versus_fields.gd。
##
## - カードは 2 段: 上の段が生成のマップ（毎回形が変わる）、下の段が手で作ったマップ（いつも同じ形）。
##   段に収まらないほど増えたら、その段を横に送れる（ホイールでも）。
## - カードには、そのマップの盤の縮図（map_card.gd。盤はルールが作る）、番号と名前、置かれているもの、形の札を載せる。
## - マウスを乗せたカードは明るくなり、少し大きくなって、下の欄にマップの説明が出る。欄の大きさは、いちばん長い説明に合わせて固定する。
## - カードのクリックで、選んだマップを context.match_choice に入れて &"pick"（対戦設定へ）。キーボードでは、左右の矢印で選んで Enter
##   （card_keys.gd。選んだカードはマウスを乗せたときと同じに明るくなり、説明が出る。1〜9 のキーでも、その番号のカード）。
## - 「部隊編成」で、対戦用の部隊を組む（寄り道。戻るとここ）。
## - 「タイトルへ戻る」（右クリック・Esc でも）で &"back"。

const SceneFlow := preload("res://game/scene_flow.gd")
const Steady := preload("res://game/steady.gd")
const MatchChoice := preload("res://game/match_choice.gd")
const Text := preload("res://game/text.gd")
const Palette := preload("res://game/ui_palette.gd")
const UiTheme := preload("res://game/ui_theme.gd")
const AppContext := preload("res://game/app_context.gd")
const TitleBackdrop := preload("res://game/title_backdrop.gd")
const BattleScreen := preload("res://game/battle_screen.gd")
const MapCard := preload("res://game/map_card.gd")
const MapFrame := preload("res://game/map_frame.gd")
const Ornament := preload("res://game/ui_ornament.gd")
const VersusFields := preload("res://game/versus_fields.gd")
const SteadyBox := preload("res://game/steady_box.gd")
const CardKeys := preload("res://game/card_keys.gd")

## 背景の景色の盤の種（いつも同じ景色）、カードに乗せてから景色を替え始めるまでの秒数、幕を沈める・戻す秒数と、沈めたときの濃さ。
const SCAPE_SEED := 7
const SCAPE_DELAY := 0.25
const SCAPE_FADE_OUT := 0.12
const SCAPE_FADE_IN := 0.35
const SCAPE_CURTAIN := 0.75

signal finished(outcome: StringName)

## 縮図の盤の種（いつも同じ縮図にする。対戦の盤は、始めるときに種を決めて作り直す）。
const MAP_SEED := 3
## カードの大きさと、縮図の大きさ（縮図はカードの左に置く）。
const CARD_SIZE := Vector2(340.0, 150.0)
const MAP_SIZE := 126.0
const CARD_GAP := 20
## マウスを乗せたカードの大きさ。
const HOVER_SCALE := 1.04
const HOVER_TIME := 0.12
const PROMPT := "map_select.prompt"
## 段の見出しと、カードの形の札（生成のマップ / 手で作ったマップ）。
const ROW_GENERATED := "map_select.row.generated"
const ROW_HAND := "map_select.row.hand"
const TAG_GENERATED := "map_select.tag.generated"
const TAG_HAND := "map_select.tag.hand"

const COLOR_CARD := Palette.OVERLAY
const COLOR_CARD_HOVER := Color(Palette.RAISED, 0.96)
const COLOR_BORDER := Color(Palette.BORDER, 0.9)
const COLOR_BORDER_HOVER := Palette.ACCENT
const COLOR_PANEL := Palette.OVERLAY
const COLOR_TEXT_DIM := Palette.TEXT_DIM
const COLOR_TAG_GENERATED := Color("4fb8c9")
const COLOR_TAG_HAND := Color("d9a441")

var context: AppContext
## マップの鍵 -> カード（Button）。
var _cards := {}
var _note_title: Label
var _note: Label
var _hovered: StringName = &""
## 背景（裂けた空の下の、マップの景色）と、いま背景に見せているマップ、次に見せるマップ（替える途中でなければ空）。
var _backdrop: TitleBackdrop
var _curtain: ColorRect
var _scape_field: StringName = &""
var _scape_next: StringName = &""
var _scape_tween: Tween
## 左右の矢印で選んでいる間か（マウスを動かすまで）。
var _by_key := false


func _ready() -> void:
	# 背景は、タイトル・物語の選択と同じ裂けた空の下の、選んでいるマップの景色（カードに乗せると、そのマップの景色に替わる）。
	_scape_field = context.match_choice.field if context != null and VersusFields.has(context.match_choice.field) else VersusFields.DEFAULT
	_backdrop = TitleBackdrop.new(TitleBackdrop.VIEW_VERSUS, VersusFields.card_board(_scape_field, SCAPE_SEED), VersusFields.look_of(_scape_field))
	add_child(_backdrop)
	var layer := CanvasLayer.new()
	add_child(layer)
	# 景色を替えるときに、いちど沈める幕（替わる瞬間を見せない）。
	_curtain = ColorRect.new()
	_curtain.color = Color(Palette.INK, 0.0)
	_curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_curtain)
	layer.add_child(UiTheme.vista_shade())
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_top = 22.0
	root.offset_bottom = -20.0
	root.add_theme_constant_override("separation", 8)
	root.alignment = BoxContainer.ALIGNMENT_CENTER  # 段が 1 つでも 2 つでも、上下の真ん中に寄せる
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var heading := _label(Text.t("map_select.heading"), 36)
	heading.theme_type_variation = UiTheme.LABEL_HEADING
	heading.add_theme_constant_override("outline_size", 10)  # 景色の上に直に置くので、縁取りを太くする
	root.add_child(heading)
	# 見出しの下の飾りの線（物語選択・話の一覧と同じ）。
	var ornament := Ornament.new(360.0, 14.0)
	ornament.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	root.add_child(ornament)

	var generated: Array[StringName] = []
	var hand: Array[StringName] = []
	for field in VersusFields.ids():
		(generated if VersusFields.is_generated(field) else hand).append(field)
	for group: Array[StringName] in [generated, hand]:
		if group.is_empty():
			continue
		var caption := _label(Text.t(ROW_GENERATED if group == generated else ROW_HAND), 17)
		caption.add_theme_color_override("font_color", (COLOR_TAG_GENERATED if group == generated else COLOR_TAG_HAND).lightened(0.3))
		# 背景の景色の上でも読めるよう、暗い札に載せる。
		var caption_panel := _panel(COLOR_PANEL)
		caption_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		(caption_panel.get_theme_stylebox("panel") as StyleBoxFlat).set_content_margin_all(4.0)
		(caption_panel.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_left = 16.0
		(caption_panel.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_right = 16.0
		caption_panel.add_child(caption)
		root.add_child(caption_panel)
		root.add_child(_card_row(group))

	var note_panel := _panel(COLOR_PANEL)
	note_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	note_panel.custom_minimum_size = Vector2(CARD_SIZE.x * 3 + CARD_GAP * 2, 84.0)
	Steady.mark(note_panel, "map_select.note")
	root.add_child(note_panel)
	var note_column := VBoxContainer.new()
	note_column.add_theme_constant_override("separation", 4)
	note_panel.add_child(note_column)
	_note_title = _label("", 19)
	_note_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	note_column.add_child(_note_title)
	_note = _label("", 16)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_note.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	note_column.add_child(_note)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 16)
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(footer)
	var back := Button.new()
	back.text = Text.t("menu.to_title")
	back.focus_mode = Control.FOCUS_NONE
	back.add_theme_font_size_override("font_size", 18)
	back.custom_minimum_size = Vector2(220.0, 44.0)
	back.pressed.connect(press_back)
	footer.add_child(back)
	var decks := Button.new()
	decks.text = Text.t("setup.edit_deck")
	decks.focus_mode = Control.FOCUS_NONE
	decks.add_theme_font_size_override("font_size", 18)
	decks.custom_minimum_size = Vector2(220.0, 44.0)
	decks.pressed.connect(press_edit_decks)
	footer.add_child(decks)
	# 説明の欄は、いちばん長い説明が収まる大きさに固定する（乗せたカードで大きさが変わると、カードの段まで動いて揺れる）。
	var notes: Array[Callable] = []
	for field: StringName in _cards:
		notes.append(_show_note.bind(field))
	notes.append(_show_note.bind(&""))
	SteadyBox.fit_largest(note_panel, notes)


## 1 段ぶんのカード。幅に収まらなければ、横に送れる（収まれば真ん中に寄せる）。
func _card_row(fields: Array[StringName]) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	# マウスを乗せたカードが大きくなっても、段の上下で切れないだけの余白。
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var room := ceili(CARD_SIZE.y * (HOVER_SCALE - 1.0) / 2.0) + 2
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, room + (UiTheme.SCROLL_ROW_EDGE if side in ["margin_left", "margin_right"] else 0))
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(margin)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", CARD_GAP)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)
	for field in fields:
		var card := _build_card(field)
		row.add_child(card)
		_cards[field] = card
	return scroll


func resume_label() -> String:
	return Text.t("map_select.resume")


## field（versus_fields.gd の鍵）を選んで、対戦設定へ進む。
func choose(field: StringName) -> void:
	context.match_choice.field = field
	finished.emit(&"pick")


## 「部隊編成」: 対戦用の部隊を組む（寄り道。編成の「マップ選択へ戻る」で、ここへ戻る）。
## 取っておいた部隊は、対戦設定の人の行の部隊に選ばれる。
func press_edit_decks() -> void:
	context.start_run(MatchChoice.deck_run(context.match_choice.human_row(), SceneFlow.MAP_SELECT, "map_select.resume"))


## 「タイトルへ戻る」。
func press_back() -> void:
	finished.emit(&"back")


## field のカードにマウスを乗せた（空なら離れた）。検査とスクリーンショットの道具も使う。
func hover(field: StringName) -> void:
	if _hovered == field:
		return
	if _hovered != &"":
		_set_card_hovered(_cards[_hovered], false)
	_hovered = field
	if field != &"":
		_set_card_hovered(_cards[field], true)
		_scroll_into_view(_cards[field])
		_queue_scape(field)
	else:
		_cancel_queued_scape()
	_show_note(field)


## 背景の景色を field のマップのものに替える。カードの上を通り過ぎるだけでは替えない（SCAPE_DELAY 秒とどまったら、幕を沈めて替える）。
func _queue_scape(field: StringName) -> void:
	if field == _scape_next or (_scape_next == &"" and field == _scape_field):
		return
	_scape_next = field
	if _scape_tween != null:
		_scape_tween.kill()
	_scape_tween = create_tween()
	_scape_tween.tween_interval(SCAPE_DELAY)
	_scape_tween.tween_property(_curtain, "color:a", SCAPE_CURTAIN, SCAPE_FADE_OUT)
	_scape_tween.tween_callback(_swap_scape)
	_scape_tween.tween_property(_curtain, "color:a", 0.0, SCAPE_FADE_IN)


## カードから離れた: まだ待っている間（幕を沈め始める前）なら、景色を替えるのをやめる（通り過ぎただけでは替えない）。
## 幕がもう沈み始めていたら、そのまま替える（途中で戻すと、ちらつく）。
func _cancel_queued_scape() -> void:
	if _scape_next == &"" or _curtain.color.a > 0.0:
		return
	_scape_next = &""
	if _scape_tween != null:
		_scape_tween.kill()
		_scape_tween = null


func _swap_scape() -> void:
	if _scape_next == &"":
		return
	_scape_field = _scape_next
	_scape_next = &""
	_backdrop.show_scape(VersusFields.card_board(_scape_field, SCAPE_SEED), VersusFields.look_of(_scape_field))


## 背景の景色を、待たずに、乗せているマップのものに替える（スクリーンショットの道具用）。
func show_scape_now() -> void:
	if _scape_tween != null:
		_scape_tween.kill()
	_curtain.color.a = 0.0
	_swap_scape()


## 背景がいま見せている景色の見た目の名前（検査用）。
func backdrop_look() -> StringName:
	return _backdrop.shown_look()


## 背景に見せている（替える途中なら、これから見せる）マップ（検査用）。
func scape_field() -> StringName:
	return _scape_next if _scape_next != &"" else _scape_field


## マウスを乗せているカードのマップ（無ければ空）と、説明の欄の文字。検査用。
func hovered_field() -> StringName:
	return _hovered


func note_text() -> String:
	return _note_title.text + "\n" + _note.text


## カードのマップの鍵（画面の並びの順）。検査用。
func card_fields() -> Array[StringName]:
	var fields: Array[StringName] = []
	fields.assign(_cards.keys())
	return fields


## field のカード（検査とスクリーンショットの道具用）。
func card_of(field: StringName) -> Control:
	return _cards[field]


## field のカードの真ん中（画面の座標）。検査用。
func card_center(field: StringName) -> Vector2:
	return (_cards[field] as Control).get_global_rect().get_center()


## 右クリックと Esc は 1 つ戻る（タイトルへ）。カードの上でも効くよう、ボタンより先に受ける。
## 重なる画面（システムメニュー）が開いている間は、そちらが受ける。
func _input(event: InputEvent) -> void:
	if context.overlays.is_open():
		return
	if _by_key and CardKeys.is_pointer_move(event):
		# マウスに持ち替えた: マウスの下のカードに乗ったことにする（無ければ、選びをやめる）。
		_by_key = false
		hover(_field_at((event as InputEventMouseMotion).global_position))
	var right: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT
	var escape: bool = event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE
	if right or escape:
		get_viewport().set_input_as_handled()
		context.play_sound(&"ui_back")
		press_back()


## 左右の矢印で選んで Enter で決める。1〜9 のキー（テンキーでも）なら、その番号のカードを選ぶ。
func _unhandled_input(event: InputEvent) -> void:
	if context.overlays.is_open():
		return
	var listed := VersusFields.ids()
	var step := CardKeys.direction(event)
	if step != 0:
		get_viewport().set_input_as_handled()
		var index := CardKeys.next(listed.find(_hovered), step, listed.size(), func(_i: int) -> bool: return true)
		if index >= 0:
			_by_key = true
			hover(listed[index])
		return
	if CardKeys.is_accept(event) and _hovered != &"":
		get_viewport().set_input_as_handled()
		context.play_sound(&"ui_confirm")
		choose(_hovered)
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key: Key = event.physical_keycode
	var number := -1
	if key >= KEY_1 and key <= KEY_9:
		number = key - KEY_1 + 1
	elif key >= KEY_KP_1 and key <= KEY_KP_9:
		number = key - KEY_KP_1 + 1
	var fields := VersusFields.ids()
	if number >= 1 and number <= fields.size():
		context.play_sound(&"ui_confirm")
		choose(fields[number - 1])


## 画面の点 at の下のカードのマップ（無ければ空）。
func _field_at(at: Vector2) -> StringName:
	for field: StringName in _cards:
		if (_cards[field] as Control).get_global_rect().has_point(at):
			return field
	return &""


func _show_note(field: StringName) -> void:
	if field == &"":
		_note_title.text = Text.t("map_select.choose")
		_note.text = Text.t(PROMPT)
		return
	_note_title.text = Text.t("map_select.note_title", {
		"number": VersusFields.number_of(field), "title": VersusFields.title_of(field), "tags": VersusFields.tags_of(field), "shape": _shape_tag(field),
	})
	_note.text = VersusFields.note_of(field)


func _shape_tag(field: StringName) -> String:
	return Text.t(TAG_GENERATED if VersusFields.is_generated(field) else TAG_HAND)


## 横に送れる段で、カードが見えるところまで送る（キーやスクリーンショットの道具で、はみ出たカードに乗せたとき）。
func _scroll_into_view(card: Control) -> void:
	var scroll := card.get_parent().get_parent().get_parent() as ScrollContainer
	if scroll != null and scroll.is_inside_tree():
		scroll.ensure_control_visible(card)


func _build_card(field: StringName) -> Button:
	var card := Button.new()
	card.focus_mode = Control.FOCUS_NONE
	card.custom_minimum_size = CARD_SIZE
	Steady.mark(card, "map_select.card")
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
	card.pressed.connect(choose.bind(field))
	# キーで選んでいる間は、乗ったことにしない（キーで送ったカードがマウスの下へ来ても、選びが替わらないように）。
	card.mouse_entered.connect(func() -> void:
		if not _by_key:
			hover(field))
	card.mouse_exited.connect(func() -> void:
		if not _by_key and _hovered == field:
			hover(&""))

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 12.0
	row.offset_right = -12.0
	row.offset_top = 12.0
	row.offset_bottom = -12.0
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)
	var board := VersusFields.card_board(field, MAP_SEED)
	if board != null and OptionalRules.DEFAULTS.has(OptionalRules.STRONGHOLD):
		Stronghold.arm(board, MAP_SEED)  # 拠点（対戦モードの既定の勝ち方）も、縮図に印を描く
	var map := TextureRect.new()
	map.texture = ImageTexture.create_from_image(MapCard.draw(board, VersusFields.look_of(field), BattleScreen.TEAM_COLORS))
	map.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	map.custom_minimum_size = Vector2(MAP_SIZE, MAP_SIZE)
	map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map.add_child(MapFrame.new())  # 真鍮の縁と四隅の鉤
	row.add_child(map)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 8)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(column)
	var name_label := _label("%d  %s" % [VersusFields.number_of(field), VersusFields.title_of(field)], 22)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(name_label)
	var tags := _label(VersusFields.tags_of(field), 15)
	tags.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	tags.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	column.add_child(tags)
	column.add_child(_shape_chip(field))
	return card


## 形の札（生成のマップは「毎回ちがう形」、手で作ったマップは「いつも同じ形」）。
func _shape_chip(field: StringName) -> PanelContainer:
	var color := COLOR_TAG_GENERATED if VersusFields.is_generated(field) else COLOR_TAG_HAND
	var style := StyleBoxFlat.new()
	style.bg_color = color.darkened(0.55)
	style.border_color = color
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 2.0
	style.content_margin_bottom = 2.0
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", style)
	chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var text := _label(_shape_tag(field), 14)
	text.add_theme_color_override("font_color", color.lightened(0.35))
	chip.add_child(text)
	return chip


func _set_card_hovered(card: Button, hovered: bool) -> void:
	card.pivot_offset = card.size / 2.0
	var tween := card.create_tween()
	tween.tween_property(card, "scale", Vector2.ONE * (HOVER_SCALE if hovered else 1.0), HOVER_TIME)
	# 道具が乗せたことにしたとき（マウスが乗っていないとき）も、明るい見た目にする。
	card.add_theme_stylebox_override("normal", card.get_meta(&"hover_style" if hovered else &"normal_style"))


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
