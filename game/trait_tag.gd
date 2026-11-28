extends HBoxContainer
## 軍略の札: 印（trait_icon.gd）と名前（「集中砲火」）。対戦の上の帯、部隊の一覧、「編成を確認」が同じ形で出す。
## 幅は、いちばん長い名前で決める（軍略を替えても、札の幅も、隣の部品の位置も動かない。docs/ui-theme.md の「枠の大きさ」）。
## 名前の色は軍略の軍の色（盤の上の札・輪・線と同じ色）。

const ArmyLook := preload("res://game/army_look.gd")
const Names := preload("res://game/names.gd")
const Palette := preload("res://game/ui_palette.gd")
const UiTheme := preload("res://game/ui_theme.gd")
const TraitIcon := preload("res://game/trait_icon.gd")

var trait_id := Traits.NONE:
	set(value):
		trait_id = value
		_mark.trait_id = value
		_name.text = Names.troop_trait(value)
		var army := Traits.army_of(value) if value != Traits.NONE else UnitKind.Army.NONE
		_name.add_theme_color_override("font_color", ArmyLook.color(army).lightened(0.3))

var _mark: TraitIcon
var _name: Label


func _init(icon_side := 24.0, font_size := 14, outline := 0) -> void:
	add_theme_constant_override("separation", 4)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_mark = TraitIcon.new(Traits.NONE, icon_side)
	add_child(_mark)
	_name = Label.new()
	_name.add_theme_font_override("font", UiTheme.FONT_BOLD)
	_name.add_theme_font_size_override("font_size", font_size)
	_name.add_theme_constant_override("outline_size", outline)
	_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name.clip_text = true
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name.custom_minimum_size = Vector2(name_width(font_size), 0.0)
	add_child(_name)


## いちばん長い軍略の名前の幅（px）。
static func name_width(font_size: int) -> float:
	var widest := 0.0
	for id: int in Traits.Id.values():
		widest = maxf(widest, UiTheme.FONT_BOLD.get_string_size(Names.troop_trait(id), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	return ceilf(widest) + 2.0


## 出している名前（検査用）。
func shown_name() -> String:
	return _name.text
