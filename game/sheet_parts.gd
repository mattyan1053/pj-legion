extends RefCounted
## ステータスの窓（unit_detail.gd）と、小さなステータスの札（unit_summary.gd）が共に使う部品:
## 小さな札（役割・軍・クールダウン）、スキル・必殺技・進化先の札、文字、折り返し。色と枠は UI のテーマ（ui_theme.gd）。

const TextWrap := preload("res://game/text_wrap.gd")
const AbilityMark := preload("res://game/ability_mark.gd")
const UiTheme := preload("res://game/ui_theme.gd")
const Palette := preload("res://game/ui_palette.gd")

## 札の中の説明の文字の大きさ。
const NOTE_SIZE := 13


static func text(font_size: int, color: Color, bold := false) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if bold:
		label.add_theme_font_override("font", UiTheme.FONT_BOLD)
	return label


## label に、width で折り返した words を入れる（字の幅は、label の字と大きさで測る）。
static func fold(label: Label, words: String, width: float) -> void:
	var font := label.get_theme_font(&"font")
	var font_size := label.get_theme_font_size(&"font_size")
	label.text = TextWrap.fold(words, width, func(character: String) -> float:
		return font.get_string_size(character, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)


## 小さな札（役割・軍・クールダウン）。
static func tag(words: String, color: Color, font_size := 12) -> Control:
	var plate := PanelContainer.new()
	plate.theme_type_variation = UiTheme.PANEL_TAG
	plate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := text(font_size, color)
	label.text = words
	plate.add_child(label)
	return plate


## 札 1 枚: 頭に印・種類の小さな文字（kind_text）・名前・右に状態（state）、下に説明（summary）。off なら沈める（スキルなし）。
## mark_size は印の辺、title_size は名前の字の大きさ（小さな札では小さくする）。
## summary_inset は、説明を折り返す幅を札の幅からどれだけ狭めるか（px。札の余白のぶん。狭い札では詰める）。
static func ability_card(type: AbilityMark.Type, kind_text: String, title: String, state: String, summary: String, width: float,
		off := false, mark_size := 26.0, title_size := 16, summary_inset := 36.0) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(width, 0.0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var accent := Palette.BORDER
	if type == AbilityMark.Type.ULT:
		accent = Palette.GOLD
	var box := UiTheme.box(Color(Palette.INK, 0.5) if off else Palette.RAISED, Color(accent, 0.5 if off else 1.0), 1, 6, 9.0)
	if not off:
		box.border_width_left = 3
	card.add_theme_stylebox_override("panel", box)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	card.add_child(column)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	column.add_child(head)
	var mark := AbilityMark.new(type, mark_size)
	mark.dim = off
	head.add_child(mark)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", -3)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(names)
	if kind_text != "" and not off:
		var kind_label := text(11, mark.ink().darkened(0.15))
		kind_label.text = kind_text
		names.add_child(kind_label)
	var name_label := text(title_size, Palette.TEXT_OFF if off else Palette.TEXT, true)
	name_label.text = title
	names.add_child(name_label)
	if state != "":
		head.add_child(tag(state, Palette.TEXT_DIM))
	if summary != "":
		var note := text(NOTE_SIZE, Palette.GOOD if type == AbilityMark.Type.EVOLUTION else Palette.TEXT_DIM)
		fold(note, summary, width - summary_inset)
		column.add_child(note)
	return card
