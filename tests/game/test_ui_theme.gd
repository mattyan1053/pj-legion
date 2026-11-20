extends "res://tests/base_test.gd"
## UI のテーマ（game/ui_theme.gd）と色（game/ui_palette.gd）。読みやすさ（文字と地の濃淡の差）を、数で固定する。

const UiTheme := preload("res://game/ui_theme.gd")
const Palette := preload("res://game/ui_palette.gd")

## 文字と地の明るさの比（WCAG のコントラスト比）の下限。本文は 4.5、押せない文字は「読めるが沈んでいる」3。
const CONTRAST_TEXT := 4.5
const CONTRAST_OFF := 3.0


func test_text_stands_out_from_every_ground() -> void:
	for ground: Color in [Palette.INK, Palette.PANEL, Palette.RAISED, Palette.RAISED_HOVER]:
		for text: Color in [Palette.TEXT, Palette.TEXT_DIM, Palette.ACCENT]:
			assert_true(_contrast(text, ground) >= CONTRAST_TEXT, "%s の上の %s" % [ground.to_html(false), text.to_html(false)])
	# 選ばれているボタンと危険なボタンの上には、本文か強調の文字だけを置く（補足は置かない）。
	for text: Color in [Palette.TEXT, Palette.ACCENT]:
		assert_true(_contrast(text, Palette.CHOSEN) >= CONTRAST_TEXT, "選ばれているボタンの %s" % text.to_html(false))
	assert_true(_contrast(Palette.TEXT, Palette.DANGER_FILL) >= CONTRAST_TEXT, "危険なボタンの文字")
	assert_true(_contrast(Color.WHITE, Palette.GO_READY) >= CONTRAST_OFF, "ターン終了の文字")
	for ground: Color in [Palette.PANEL, Palette.RAISED]:
		for text: Color in [Palette.GOOD, Palette.WARN, Palette.DANGER, Palette.INFO,
				Palette.team_text(Palette.TEAM_BLUE), Palette.team_text(Palette.TEAM_RED)]:
			assert_true(_contrast(text, ground) >= CONTRAST_TEXT, "%s の上の %s" % [ground.to_html(false), text.to_html(false)])
		assert_true(_contrast(Palette.TEXT_OFF, ground) >= CONTRAST_OFF, "押せない文字")
	for ground: Color in [Palette.GOLD, Palette.GOLD_HOVER, Palette.GOLD_PRESSED]:
		assert_true(_contrast(Palette.TEXT_ON_GOLD, ground) >= CONTRAST_TEXT, "金の地の上の文字")


## 盤の上に重ねる半透明の板は、後ろがいちばん明るい（白い）ときでも、本文と補足が読める。
func test_overlay_stays_readable_over_a_bright_board() -> void:
	var ground := Color.WHITE.lerp(Palette.PANEL, Palette.ALPHA_OVERLAY)
	for text: Color in [Palette.TEXT, Palette.TEXT_DIM, Palette.ACCENT]:
		assert_true(_contrast(text, ground) >= CONTRAST_TEXT, "白い盤の上の板の %s" % text.to_html(false))


## タイトルのメニューは景色の上に直に並ぶ。後ろがいちばん明るい（白い）ときでも、ふつうの文字と、乗ったときの金の文字が読める。
func test_title_menu_stays_readable_over_a_bright_sky() -> void:
	var theme := UiTheme.new()
	for state: Array in [[&"normal", &"font_color"], [&"hover", &"font_hover_color"]]:
		var fill := (theme.get_stylebox(state[0], UiTheme.BUTTON_MENU) as StyleBoxFlat).bg_color
		var ground := Color.WHITE.lerp(Color(fill, 1.0), fill.a)
		assert_true(_contrast(theme.get_color(state[1], UiTheme.BUTTON_MENU), ground) >= CONTRAST_TEXT, "タイトルのメニューの %s" % state[0])


## 国の色（物語のカードの「軍」の文字に使う）は、板の上で読める。
func test_nation_colors_are_readable_on_a_card() -> void:
	for nation: Color in [Palette.NATION_MILITARY, Palette.NATION_FANTASY]:
		assert_true(_contrast(nation.lightened(0.25), Palette.PANEL) >= CONTRAST_TEXT, nation.to_html(false))


func test_every_button_kind_has_every_state() -> void:
	var theme := UiTheme.new()
	for type: StringName in [&"Button", UiTheme.BUTTON_PRIMARY, UiTheme.BUTTON_DANGER, UiTheme.BUTTON_ROW, UiTheme.BUTTON_CARD,
			UiTheme.BUTTON_MENU, UiTheme.BUTTON_GHOST, UiTheme.BUTTON_ACTION]:
		for state: StringName in [&"normal", &"hover", &"pressed", &"disabled"]:
			assert_true(theme.has_stylebox(state, type), "%s の %s" % [type, state])
		if type != &"Button":
			assert_eq(theme.get_type_variation_base(type), &"Button", type)


func test_every_panel_and_label_kind_is_a_variation() -> void:
	var theme := UiTheme.new()
	for type: StringName in [UiTheme.PANEL_SOLID, UiTheme.PANEL_BAND_TOP, UiTheme.PANEL_BAND_BOTTOM, UiTheme.PANEL_CARD,
			UiTheme.PANEL_TAG, UiTheme.PANEL_NONE]:
		assert_eq(theme.get_type_variation_base(type), &"PanelContainer", type)
		assert_true(theme.has_stylebox(&"panel", type), type)
	for type: StringName in [UiTheme.LABEL_TITLE, UiTheme.LABEL_HEADING, UiTheme.LABEL_SECTION, UiTheme.LABEL_DIM]:
		assert_eq(theme.get_type_variation_base(type), &"Label", type)


func test_fonts_carry_japanese() -> void:
	for font: Font in [UiTheme.FONT_BODY, UiTheme.FONT_BOLD, UiTheme.FONT_HEADING]:
		for character: String in ["A", "あ", "カ", "編", "隊"]:
			assert_true(font.has_char(character.unicode_at(0)), character)


static func _contrast(a: Color, b: Color) -> float:
	var high := maxf(_luminance(a), _luminance(b))
	var low := minf(_luminance(a), _luminance(b))
	return (high + 0.05) / (low + 0.05)


static func _luminance(color: Color) -> float:
	var linear := color.srgb_to_linear()
	return 0.2126 * linear.r + 0.7152 * linear.g + 0.0722 * linear.b
