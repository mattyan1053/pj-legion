extends PanelContainer
## 軍略の札 1 枚（docs/troop-traits.md）: 印（trait_icon.gd）、名前、効果（数。目立つ色で先に）、効く相手（2 行まで）。
## 対戦中、上の帯の軍略の札をクリックすると出す窓（hud_top_bar.gd）に使う。縫い目の様子の札の窓（sign_card.gd）と同じ作り。
## 大きさは中身（軍略）に依らず同じ（SIZE。docs/ui-theme.md の「枠の大きさ」）。

const Names := preload("res://game/names.gd")
const Steady := preload("res://game/steady.gd")
const UiTheme := preload("res://game/ui_theme.gd")
const Palette := preload("res://game/ui_palette.gd")
const TraitIcon := preload("res://game/trait_icon.gd")
const TextWrap := preload("res://game/text_wrap.gd")

## 札の大きさ（px）と、印の大きさ。
const SIZE := Vector2(380.0, 132.0)
const MARK_SIDE := 64.0
## 名前と効果の字の大きさ。
const NAME_FONT := 22
const EFFECT_FONT := 17
## 効く相手の文の字の大きさ・折り返す幅・行の数の上限。文は語の途中で切らずに折り返す（text_wrap.gd。tools/wrap_audit.gd が全部の札を見る）。
const WHEN_FONT := 14
const WHEN_WIDTH := SIZE.x - MARK_SIDE - 50.0
const WHEN_MAX_LINES := 2

var _mark: TraitIcon
var _name: Label
var _effect: Label
var _when: Label
## 効く相手の文の、折り返す前の文（検査用）。
var _when_plain := ""


func _init() -> void:
	theme_type_variation = UiTheme.PANEL_CARD
	custom_minimum_size = SIZE
	clip_contents = true
	Steady.mark(self, "traits.card")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	add_child(row)
	_mark = TraitIcon.new(Traits.NONE, MARK_SIDE)
	row.add_child(_mark)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 0)
	row.add_child(column)
	_name = Label.new()
	_name.theme_type_variation = UiTheme.LABEL_HEADING
	_name.add_theme_font_size_override("font_size", NAME_FONT)
	_name.clip_text = true
	column.add_child(_name)
	_effect = Label.new()
	_effect.add_theme_font_override("font", UiTheme.FONT_BOLD)
	_effect.add_theme_font_size_override("font_size", EFFECT_FONT)
	_effect.add_theme_color_override("font_color", Palette.GOLD)
	_effect.clip_text = true
	column.add_child(_effect)
	_when = Label.new()
	_when.add_theme_font_override("font", UiTheme.FONT_BODY)  # 折り返しを測る字と同じに
	_when.add_theme_font_size_override("font_size", WHEN_FONT)
	_when.add_theme_color_override("font_color", Palette.TEXT_DIM)
	_when.max_lines_visible = WHEN_MAX_LINES
	_when.custom_minimum_size = Vector2(WHEN_WIDTH, 0.0)
	column.add_child(_when)


## 軍略 id（Traits.Id の値）を見せる。
func show_trait(id: int) -> void:
	_mark.trait_id = id
	_name.text = Names.troop_trait(id)
	_effect.text = Names.troop_trait_effect(id)
	_when_plain = Names.troop_trait_when(id)
	_when.text = TextWrap.fold(_when_plain, WHEN_WIDTH, func(character: String) -> float:
		return UiTheme.FONT_BODY.get_string_size(character, HORIZONTAL_ALIGNMENT_LEFT, -1, WHEN_FONT).x)


## 見せている文（名前、効果、効く相手。検査用）。
func shown_text() -> String:
	return "%s %s %s" % [_name.text, _effect.text, _when_plain]
