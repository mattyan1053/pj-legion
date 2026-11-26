extends PanelContainer
## 軍略の札 1 枚（docs/troop-traits.md）: 印（trait_icon.gd）、名前、文（条件 → 効果の 1 文。効果の所は目立つ色。2 行まで。trait_sentence.gd）。
## 対戦中、上の帯の軍略の札をクリックすると出す窓（hud_top_bar.gd）に使う。縫い目の様子の札の窓（sign_card.gd）と同じ作り。
## 大きさは中身（軍略）に依らず同じ（SIZE。docs/ui-theme.md の「枠の大きさ」）。

const Names := preload("res://game/names.gd")
const Steady := preload("res://game/steady.gd")
const UiTheme := preload("res://game/ui_theme.gd")
const Palette := preload("res://game/ui_palette.gd")
const TraitIcon := preload("res://game/trait_icon.gd")
const TraitSentence := preload("res://game/trait_sentence.gd")

## 札の大きさ（px）と、印の大きさ。
const SIZE := Vector2(380.0, 132.0)
const MARK_SIDE := 64.0
## 名前の字の大きさ。
const NAME_FONT := 22
## 文の字の大きさ・折り返す幅・行の数の上限。文は語の途中で切らずに折り返す（text_wrap.gd。tools/wrap_audit.gd が全部の札を見る）。
const TEXT_FONT := 16
const TEXT_WIDTH := SIZE.x - MARK_SIDE - 50.0
const TEXT_MAX_LINES := 2

var _mark: TraitIcon
var _name: Label
var _sentence: TraitSentence


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
	_sentence = TraitSentence.new(TEXT_WIDTH, TEXT_FONT, TEXT_MAX_LINES, Palette.TEXT, Palette.GOLD)
	column.add_child(_sentence)


## 軍略 id（Traits.Id の値）を見せる。
func show_trait(id: int) -> void:
	_mark.trait_id = id
	_name.text = Names.troop_trait(id)
	_sentence.trait_id = id


## 見せている文（名前と文。検査用）。
func shown_text() -> String:
	return "%s %s" % [_name.text, _sentence.shown_text()]
