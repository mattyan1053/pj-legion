extends Theme
## UI のテーマ。アプリの入口（app.gd）が、起動してすぐ install() で Godot の既定のテーマに重ねるので、プロジェクト全体に当たる
## （窓のテーマは CanvasLayer の先へ伝わらず、project.godot の gui/theme/custom は素材の取り込みより先に読まれるので、使わない）。
## 絵は使わず、枠とボタンは StyleBoxFlat（角丸・縁・影）で、小さな印（スイッチ、つまみ）は SVG の文字列から描く。
## 色は ui_palette.gd だけを引く。どの部品にどの種類を当てるかは docs/ui-theme.md。
##
## 画面の側は、種類の名前（下の定数）を `theme_type_variation` に入れるだけにする:
##   panel.theme_type_variation = UiTheme.PANEL_SOLID

const Palette := preload("res://game/ui_palette.gd")

const FONT_BODY := preload("res://assets/fonts/zen/ZenKakuGothicNew-Medium.ttf")
const FONT_BOLD := preload("res://assets/fonts/zen/ZenKakuGothicNew-Bold.ttf")
const FONT_HEADING := preload("res://assets/fonts/zen/ZenOldMincho-Bold.ttf")

# ---- 種類の名前（theme_type_variation に入れる） ----

## いちばん大事なボタン（その画面で次に押すもの。1 画面に 1 つ）。
const BUTTON_PRIMARY := &"ButtonPrimary"
## 取り返しのつかないことをするボタン（消す、終える）。
const BUTTON_DANGER := &"ButtonDanger"
## 板の上に並ぶ、枠の無い行のボタン（一覧の行、メニューの項目）。
const BUTTON_ROW := &"ButtonRow"
## カードのボタン（ステージ、話）。
const BUTTON_CARD := &"ButtonCard"

## ダイアログやメニューの板（ほぼ不透明、太い縁、影）。
const PANEL_SOLID := &"PanelSolid"
## 画面の上の帯と下の帯。
const PANEL_BAND_TOP := &"PanelBandTop"
const PANEL_BAND_BOTTOM := &"PanelBandBottom"
## 板の中の区切り（カード）。
const PANEL_CARD := &"PanelCard"
## 小さな札（名前の札、印）。
const PANEL_TAG := &"PanelTag"
## 縁も地も無い（並べるためだけの入れ物）。
const PANEL_NONE := &"PanelNone"

## 題字と、画面の見出し（明朝）。
const LABEL_TITLE := &"LabelTitle"
const LABEL_HEADING := &"LabelHeading"
## 板の中の小見出し（金）。
const LABEL_SECTION := &"LabelSection"
## 補足の文。
const LABEL_DIM := &"LabelDim"

const FONT_SIZE := 16
const CORNER := 6


## 既定のテーマに、このテーマを重ねる。どのコントロールを作るよりも前に、1 回だけ呼ぶ。
static func install() -> void:
	var base := ThemeDB.get_default_theme()
	if base.has_meta(&"ui_theme"):
		return
	var theme: Theme = load("res://game/ui_theme.gd").new()
	base.merge_with(theme)
	base.default_font = theme.default_font
	base.default_font_size = theme.default_font_size
	base.set_meta(&"ui_theme", true)


func _init() -> void:
	default_font = FONT_BODY
	default_font_size = FONT_SIZE
	_build_buttons()
	_build_panels()
	_build_labels()
	_build_inputs()
	_build_bars()
	_build_popups()


## 角丸・縁・影の付いた板の形を 1 つ作る。画面の側で、色だけ違う板が要るときにも使う。
static func box(fill: Color, border: Color, border_width := 1, corner := CORNER, margin := 12.0, shadow := 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(corner)
	style.set_content_margin_all(margin)
	style.anti_aliasing = true
	if shadow > 0:
		style.shadow_color = Palette.SHADOW
		style.shadow_size = shadow
		style.shadow_offset = Vector2(0.0, shadow * 0.5)
	return style


## 盤の上に重ねる板（半透明）。
static func overlay_box(margin := 12.0) -> StyleBoxFlat:
	return box(Palette.overlay(), Color(Palette.BORDER, 0.9), 1, 8, margin, 4)


## ダイアログの板（ほぼ不透明）。
static func solid_box(margin := 20.0) -> StyleBoxFlat:
	var style := box(Palette.solid(), Palette.BORDER, 2, 10, margin, 10)
	style.border_blend = true
	return style


# ---- ボタン ----


func _build_buttons() -> void:
	_button_type(&"Button", Palette.RAISED, Palette.RAISED_HOVER, Palette.CHOSEN, Palette.BORDER, Palette.BORDER_BRIGHT,
		Palette.TEXT, Palette.TEXT, Palette.ACCENT)
	set_type_variation(BUTTON_PRIMARY, &"Button")
	_button_type(BUTTON_PRIMARY, Palette.GOLD, Palette.GOLD_HOVER, Palette.GOLD_PRESSED, Palette.GOLD_HOVER, Palette.ACCENT,
		Palette.TEXT_ON_GOLD, Palette.TEXT_ON_GOLD, Palette.TEXT_ON_GOLD)
	set_font(&"font", BUTTON_PRIMARY, FONT_BOLD)
	set_type_variation(BUTTON_DANGER, &"Button")
	_button_type(BUTTON_DANGER, Palette.DANGER_FILL, Palette.DANGER_FILL.lightened(0.12), Palette.DANGER_FILL.darkened(0.2),
		Palette.DANGER.darkened(0.35), Palette.DANGER, Color("ffe1d8"), Color.WHITE, Color.WHITE)

	# 行のボタン: 地も縁も無く、乗ると薄く塗り、選ばれていると金の薄い塗り。
	set_type_variation(BUTTON_ROW, &"Button")
	var row := box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 4, 6.0)
	set_stylebox(&"normal", BUTTON_ROW, row)
	set_stylebox(&"disabled", BUTTON_ROW, row)
	set_stylebox(&"hover", BUTTON_ROW, box(Palette.WASH, Color(0, 0, 0, 0), 0, 4, 6.0))
	var row_chosen := box(Color(Palette.ACCENT, 0.16), Color(Palette.BORDER_BRIGHT, 0.7), 1, 4, 6.0)
	set_stylebox(&"pressed", BUTTON_ROW, row_chosen)
	set_stylebox(&"hover_pressed", BUTTON_ROW, row_chosen)

	# カードのボタン: 板と同じ地に、乗ると金の縁。
	set_type_variation(BUTTON_CARD, &"Button")
	var card := box(Palette.overlay(), Color(Palette.BORDER, 0.9), 1, 8, 10.0, 4)
	var card_hover := box(Color(Palette.RAISED, 0.96), Palette.ACCENT, 2, 8, 10.0, 6)
	set_stylebox(&"normal", BUTTON_CARD, card)
	set_stylebox(&"hover", BUTTON_CARD, card_hover)
	set_stylebox(&"pressed", BUTTON_CARD, card_hover)
	set_stylebox(&"disabled", BUTTON_CARD, box(Color(Palette.INK, 0.72), Color(Palette.BORDER, 0.4), 1, 8, 10.0))

	# スイッチ（CheckButton）とチェック（CheckBox）は、地を持たない。
	for type: StringName in [&"CheckButton", &"CheckBox"]:
		var none := StyleBoxEmpty.new()
		none.set_content_margin_all(4.0)
		for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled", &"focus"]:
			set_stylebox(state, type, none)
		set_color(&"font_pressed_color", type, Palette.TEXT)
		set_color(&"font_hover_pressed_color", type, Palette.ACCENT)
		set_constant(&"h_separation", type, 8)
	for state: StringName in [&"checked", &"checked_disabled", &"checked_mirrored", &"checked_disabled_mirrored"]:
		set_icon(state, &"CheckButton", _switch_icon(true, state.contains("disabled")))
	for state: StringName in [&"unchecked", &"unchecked_disabled", &"unchecked_mirrored", &"unchecked_disabled_mirrored"]:
		set_icon(state, &"CheckButton", _switch_icon(false, state.contains("disabled")))
	for state: StringName in [&"checked", &"checked_disabled", &"radio_checked", &"radio_checked_disabled"]:
		set_icon(state, &"CheckBox", _check_icon(true, state.contains("disabled")))
	for state: StringName in [&"unchecked", &"unchecked_disabled", &"radio_unchecked", &"radio_unchecked_disabled"]:
		set_icon(state, &"CheckBox", _check_icon(false, state.contains("disabled")))


## ボタンの 1 種類ぶん（ふつう・乗った・押した／選ばれている・押せない・キーボードの印）。
func _button_type(type: StringName, fill: Color, fill_hover: Color, fill_pressed: Color, border: Color, border_hover: Color,
		text: Color, text_hover: Color, text_pressed: Color) -> void:
	var normal := box(fill, border, 1, CORNER, 6.0, 2)
	normal.content_margin_left = 10.0
	normal.content_margin_right = 10.0
	normal.border_width_bottom = 2
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = fill_hover
	hover.border_color = border_hover
	hover.shadow_size = 4
	# 押した: 影を消し、下の縁を上へ移して、沈んで見せる。
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = fill_pressed
	pressed.border_color = border_hover
	pressed.border_width_bottom = 1
	pressed.border_width_top = 2
	pressed.shadow_size = 0
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(Palette.RAISED.darkened(0.25), 0.7)
	disabled.border_color = Color(Palette.BORDER, 0.35)
	disabled.shadow_size = 0
	var focus := box(Color(0, 0, 0, 0), Palette.ACCENT, 2, CORNER, 8.0)
	focus.draw_center = false
	focus.set_expand_margin_all(2.0)
	set_stylebox(&"normal", type, normal)
	set_stylebox(&"hover", type, hover)
	set_stylebox(&"pressed", type, pressed)
	set_stylebox(&"hover_pressed", type, pressed)
	set_stylebox(&"disabled", type, disabled)
	set_stylebox(&"focus", type, focus)
	set_color(&"font_color", type, text)
	set_color(&"font_hover_color", type, text_hover)
	set_color(&"font_focus_color", type, text_hover)
	set_color(&"font_pressed_color", type, text_pressed)
	set_color(&"font_hover_pressed_color", type, text_pressed)
	set_color(&"font_disabled_color", type, Palette.TEXT_OFF)
	set_color(&"icon_normal_color", type, text)
	set_color(&"icon_hover_color", type, text_hover)
	set_color(&"icon_pressed_color", type, text_pressed)
	set_color(&"icon_disabled_color", type, Palette.TEXT_OFF)


# ---- 板 ----


func _build_panels() -> void:
	for type: StringName in [&"PanelContainer", &"Panel"]:
		set_stylebox(&"panel", type, overlay_box())
	set_type_variation(PANEL_SOLID, &"PanelContainer")
	set_stylebox(&"panel", PANEL_SOLID, solid_box())

	# 帯: 画面の端に付くので角は丸めず、内側の辺にだけ縁を引く。
	for top: bool in [true, false]:
		var band := box(Palette.overlay(), Palette.BORDER, 0, 0, 8.0, 6)
		band.shadow_offset = Vector2(0.0, 2.0 if top else -2.0)
		if top:
			band.border_width_bottom = 2
		else:
			band.border_width_top = 2
		var type := PANEL_BAND_TOP if top else PANEL_BAND_BOTTOM
		set_type_variation(type, &"PanelContainer")
		set_stylebox(&"panel", type, band)

	set_type_variation(PANEL_CARD, &"PanelContainer")
	set_stylebox(&"panel", PANEL_CARD, box(Color(Palette.RAISED, 0.55), Color(Palette.BORDER, 0.6), 1, CORNER, 10.0))
	set_type_variation(PANEL_TAG, &"PanelContainer")
	var tag := box(Palette.RAISED, Palette.BORDER, 1, 4, 3.0)
	tag.content_margin_left = 8.0
	tag.content_margin_right = 8.0
	set_stylebox(&"panel", PANEL_TAG, tag)
	set_type_variation(PANEL_NONE, &"PanelContainer")
	set_stylebox(&"panel", PANEL_NONE, StyleBoxEmpty.new())

	var line := StyleBoxLine.new()
	line.color = Color(Palette.BORDER, 0.8)
	line.thickness = 1
	set_stylebox(&"separator", &"HSeparator", line)
	var vertical := line.duplicate() as StyleBoxLine
	vertical.vertical = true
	set_stylebox(&"separator", &"VSeparator", vertical)


# ---- 文字 ----


func _build_labels() -> void:
	set_color(&"font_color", &"Label", Palette.TEXT)
	set_color(&"font_outline_color", &"Label", Palette.OUTLINE)
	set_color(&"font_shadow_color", &"Label", Color(0, 0, 0, 0))
	set_color(&"default_color", &"RichTextLabel", Palette.TEXT)

	set_type_variation(LABEL_TITLE, &"Label")
	set_font(&"font", LABEL_TITLE, FONT_HEADING)
	set_font_size(&"font_size", LABEL_TITLE, 52)
	set_color(&"font_color", LABEL_TITLE, Palette.ACCENT)
	set_color(&"font_outline_color", LABEL_TITLE, Palette.OUTLINE)
	set_color(&"font_shadow_color", LABEL_TITLE, Color(0.0, 0.0, 0.0, 0.55))
	set_constant(&"outline_size", LABEL_TITLE, 8)
	set_constant(&"shadow_offset_y", LABEL_TITLE, 4)
	set_constant(&"shadow_outline_size", LABEL_TITLE, 10)

	set_type_variation(LABEL_HEADING, &"Label")
	set_font(&"font", LABEL_HEADING, FONT_HEADING)
	set_font_size(&"font_size", LABEL_HEADING, 28)
	set_color(&"font_color", LABEL_HEADING, Palette.TEXT)
	set_constant(&"outline_size", LABEL_HEADING, 5)

	set_type_variation(LABEL_SECTION, &"Label")
	set_font(&"font", LABEL_SECTION, FONT_BOLD)
	set_font_size(&"font_size", LABEL_SECTION, 17)
	set_color(&"font_color", LABEL_SECTION, Palette.ACCENT)

	set_type_variation(LABEL_DIM, &"Label")
	set_color(&"font_color", LABEL_DIM, Palette.TEXT_DIM)


# ---- 入力欄 ----


func _build_inputs() -> void:
	var field := box(Palette.INK, Palette.BORDER, 1, 4, 8.0)
	var field_focus := box(Palette.INK, Palette.ACCENT, 2, 4, 7.0)
	for type: StringName in [&"LineEdit", &"TextEdit"]:
		set_stylebox(&"normal", type, field)
		set_stylebox(&"focus", type, field_focus)
		set_stylebox(&"read_only", type, box(Color(Palette.INK, 0.6), Color(Palette.BORDER, 0.4), 1, 4, 8.0))
		set_color(&"font_color", type, Palette.TEXT)
		set_color(&"font_placeholder_color", type, Palette.TEXT_OFF)
		set_color(&"caret_color", type, Palette.ACCENT)
		set_color(&"selection_color", type, Color(Palette.GOLD, 0.45))
		set_color(&"font_selected_color", type, Color.WHITE)


# ---- スライダー、送りの棒、進み具合の棒 ----


func _build_bars() -> void:
	var groove := box(Palette.INK, Palette.BORDER, 1, 4, 0.0)
	groove.content_margin_top = 4.0
	groove.content_margin_bottom = 4.0
	var filled := box(Palette.GOLD, Palette.GOLD_HOVER, 1, 4, 0.0)
	for type: StringName in [&"HSlider", &"VSlider"]:
		set_stylebox(&"slider", type, groove)
		set_stylebox(&"grabber_area", type, filled)
		set_stylebox(&"grabber_area_highlight", type, box(Palette.GOLD_HOVER, Palette.ACCENT, 1, 4, 0.0))
		set_icon(&"grabber", type, _knob_icon(Palette.TEXT, Palette.BORDER))
		set_icon(&"grabber_highlight", type, _knob_icon(Color.WHITE, Palette.ACCENT))
		set_icon(&"grabber_disabled", type, _knob_icon(Palette.TEXT_OFF, Palette.BORDER))

	for type: StringName in [&"VScrollBar", &"HScrollBar"]:
		var track := box(Color(Palette.INK, 0.7), Color(0, 0, 0, 0), 0, 5, 5.0)
		set_stylebox(&"scroll", type, track)
		set_stylebox(&"scroll_focus", type, track)
		set_stylebox(&"grabber", type, box(Palette.BORDER, Color(0, 0, 0, 0), 0, 5, 0.0))
		set_stylebox(&"grabber_highlight", type, box(Palette.BORDER_BRIGHT, Color(0, 0, 0, 0), 0, 5, 0.0))
		set_stylebox(&"grabber_pressed", type, box(Palette.ACCENT, Color(0, 0, 0, 0), 0, 5, 0.0))

	set_stylebox(&"background", &"ProgressBar", box(Palette.INK, Palette.BORDER, 1, 4, 2.0))
	set_stylebox(&"fill", &"ProgressBar", box(Palette.GOLD, Color(0, 0, 0, 0), 0, 3, 0.0))
	set_color(&"font_color", &"ProgressBar", Palette.TEXT)
	set_color(&"font_outline_color", &"ProgressBar", Palette.OUTLINE)
	set_constant(&"outline_size", &"ProgressBar", 4)


# ---- 重ねて出るもの（ツールチップ、選択肢） ----


func _build_popups() -> void:
	var tip := box(Color(Palette.INK, 0.97), Palette.BORDER_BRIGHT, 1, 4, 6.0, 4)
	tip.content_margin_left = 10.0
	tip.content_margin_right = 10.0
	set_stylebox(&"panel", &"TooltipPanel", tip)
	set_color(&"font_color", &"TooltipLabel", Palette.TEXT)
	set_color(&"font_shadow_color", &"TooltipLabel", Color(0, 0, 0, 0))
	set_font_size(&"font_size", &"TooltipLabel", 15)

	set_stylebox(&"panel", &"PopupMenu", box(Palette.solid(), Palette.BORDER_BRIGHT, 1, 4, 6.0))
	set_stylebox(&"hover", &"PopupMenu", box(Palette.RAISED_HOVER, Color(0, 0, 0, 0), 0, 3, 4.0))
	set_color(&"font_color", &"PopupMenu", Palette.TEXT)
	set_color(&"font_hover_color", &"PopupMenu", Palette.ACCENT)
	set_color(&"font_disabled_color", &"PopupMenu", Palette.TEXT_OFF)
	set_color(&"font_separator_color", &"PopupMenu", Palette.TEXT_DIM)
	set_constant(&"v_separation", &"PopupMenu", 8)
	set_constant(&"item_start_padding", &"PopupMenu", 8)
	set_constant(&"item_end_padding", &"PopupMenu", 8)
	for state: StringName in [&"radio_checked", &"checked"]:
		set_icon(state, &"PopupMenu", _check_icon(true, false))
	for state: StringName in [&"radio_unchecked", &"unchecked"]:
		set_icon(state, &"PopupMenu", _check_icon(false, false))


# ---- 小さな印（SVG の文字列から。画面を拡大しても描き直されて、ぼやけない） ----


## スイッチ（オンは金の溝に明るいつまみが右、オフは暗い溝に灰のつまみが左）。
static func _switch_icon(on: bool, disabled: bool) -> Texture2D:
	var track := Palette.GOLD if on else Palette.INK
	var edge := Palette.ACCENT if on else Palette.BORDER
	var knob := Palette.TEXT if on else Palette.TEXT_DIM
	var opacity := 0.45 if disabled else 1.0
	return _svg(44, 24, """<g opacity="%s"><rect x="1" y="3" width="42" height="18" rx="9" fill="#%s" stroke="#%s" stroke-width="1.5"/>
<circle cx="%d" cy="12" r="7" fill="#%s" stroke="#%s" stroke-width="1"/></g>""" % [
		opacity, track.to_html(false), edge.to_html(false), 33 if on else 11, knob.to_html(false), Palette.OUTLINE.to_html(false)])


## チェックと丸の印（選ばれていると金の点）。
static func _check_icon(on: bool, disabled: bool) -> Texture2D:
	var opacity := 0.45 if disabled else 1.0
	var dot := """<circle cx="9" cy="9" r="4" fill="#%s"/>""" % Palette.ACCENT.to_html(false) if on else ""
	return _svg(18, 18, """<g opacity="%s"><circle cx="9" cy="9" r="7.5" fill="#%s" stroke="#%s" stroke-width="1.5"/>%s</g>""" % [
		opacity, Palette.INK.to_html(false), (Palette.BORDER_BRIGHT if on else Palette.BORDER).to_html(false), dot])


## スライダーのつまみ。
static func _knob_icon(fill: Color, edge: Color) -> Texture2D:
	return _svg(20, 20, """<circle cx="10" cy="10" r="8" fill="#%s" stroke="#%s" stroke-width="2"/>
<circle cx="10" cy="10" r="3" fill="#%s"/>""" % [fill.to_html(false), Palette.OUTLINE.to_html(false), edge.to_html(false)])


static func _svg(width: int, height: int, body: String) -> Texture2D:
	return DPITexture.create_from_string(
		"""<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">%s</svg>""" % [width, height, width, height, body])
