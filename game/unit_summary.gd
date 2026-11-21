extends VBoxContainer
## 駒 1 体の小さなステータスの札（部隊編成の右の札。deck_screen.gd）。ステータスの窓（unit_detail.gd）と同じ部品を、狭い幅に詰めて並べる:
## 額（駒のアイコン）、役割の印と名前、札（役割・軍）とコスト、役割の説明、能力値の行（stat_meter.gd の詰めた行。棒と粒、持ち物での増減）、
## スキルの札、進化先の札。文の段落では並べない。中身は unit_sheet.gd が欄ごとの値で持つ。
## 幅は渡した幅で決まり、中身では変わらない（長い文は、幅で折り返す）。

const Text := preload("res://game/text.gd")
const Names := preload("res://game/names.gd")
const DeckText := preload("res://game/deck_text.gd")
const UnitSheet := preload("res://game/unit_sheet.gd")
const SheetParts := preload("res://game/sheet_parts.gd")
const UnitFrame := preload("res://game/unit_frame.gd")
const RoleMark := preload("res://game/role_mark.gd")
const StatMeter := preload("res://game/stat_meter.gd")
const AbilityMark := preload("res://game/ability_mark.gd")
const CostGems := preload("res://game/cost_gems.gd")
const UiTheme := preload("res://game/ui_theme.gd")
const Palette := preload("res://game/ui_palette.gd")

## 額の辺（px）と、欄の間（px）。
const FRAME_SIZE := 64.0
const GAP := 6
## 進化先の札の間（px）。
const CARD_GAP := 6.0

var _width: float
var _sheet: UnitSheet
var _frame: UnitFrame
var _role: RoleMark
var _title: Label
var _tags: HBoxContainer
var _gems: CostGems
var _note: Label
var _corner: HBoxContainer
var _meters: Array[StatMeter] = []
var _skill: VBoxContainer
var _evolutions_box: VBoxContainer
var _evolutions_head: Label
var _evolutions: HBoxContainer


func _init(width := 376.0) -> void:
	_width = width
	custom_minimum_size = Vector2(width, 0.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", GAP)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	add_child(head)
	_frame = UnitFrame.new(UnitKind.Id.KING, 0, FRAME_SIZE, false)
	head.add_child(_frame)
	var names := VBoxContainer.new()
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.add_theme_constant_override("separation", 2)
	head.add_child(names)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	names.add_child(title_row)
	_role = RoleMark.new(UnitKind.Role.NONE, 24.0)
	title_row.add_child(_role)
	_title = SheetParts.text(22, Palette.TEXT, true)
	title_row.add_child(_title)
	_tags = HBoxContainer.new()
	_tags.add_theme_constant_override("separation", 6)
	names.add_child(_tags)
	# 役割の説明は、頭の札の下（額の横）に置く（行を足さない。持ち物の欄に押されて札が低いときも、能力値とスキルまで見える）。
	_note = SheetParts.text(SheetParts.NOTE_SIZE, Palette.TEXT_DIM)
	names.add_child(_note)
	# 飾りの線の右に、呼ぶ側のボタン（「詳細」など）の場所を取る（名前や札に重ならない。空なら、線が幅いっぱい）。
	var rule_row := HBoxContainer.new()
	rule_row.add_theme_constant_override("separation", 8)
	add_child(rule_row)
	var rule := UiTheme.window_rule()
	rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rule_row.add_child(rule)
	_corner = HBoxContainer.new()
	_corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule_row.add_child(_corner)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 2)
	add_child(rows)
	for i in UnitSheet.STATS.size():
		var meter := StatMeter.new(true)
		_meters.append(meter)
		rows.add_child(meter)
	_skill = VBoxContainer.new()
	add_child(_skill)
	_evolutions_box = VBoxContainer.new()
	_evolutions_box.add_theme_constant_override("separation", 4)
	add_child(_evolutions_box)
	var evolutions_head := UiTheme.section_head("", 13)
	_evolutions_head = evolutions_head.get_child(0)
	_evolutions_box.add_child(evolutions_head)
	_evolutions = HBoxContainer.new()
	_evolutions.add_theme_constant_override("separation", int(CARD_GAP))
	_evolutions_box.add_child(_evolutions)


## 飾りの線の右の場所（「詳細」のボタンなどを入れる。入れたものの幅だけ、線が短くなる）。
func corner() -> Control:
	return _corner


## sheet の駒を出す。title は名前の欄の文（空なら駒の名前。部隊の駒は「4. コマンドー」）。
func show_sheet(sheet: UnitSheet, title := "") -> void:
	_sheet = sheet
	_title.text = title if title != "" else sheet.name
	_frame.set_kind(sheet.kind, sheet.side, sheet.evolved != Evolution.Id.NONE)
	var role := UnitKind.role(sheet.kind)
	_role.role = role
	_role.visible = role != UnitKind.Role.NONE
	_clear(_tags)
	for words in sheet.tags():
		_tags.add_child(SheetParts.tag(words, Palette.TEXT))
	if sheet.cost() > 0:
		var cost := SheetParts.text(12, Palette.TEXT_DIM)
		cost.text = Text.t("deck.sheet.cost", {"cost": sheet.cost()})
		cost.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_tags.add_child(cost)
		_gems = CostGems.new(sheet.cost(), 0, 7.0)
		_gems.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_tags.add_child(_gems)
	var note := Names.role_summary(role)
	if sheet.borrowed:
		note = Text.t("deck.detail.borrowed", {"origin": Names.army(UnitKind.army(sheet.kind)), "army": Names.army(sheet.army)})
	SheetParts.fold(_note, note, _width - FRAME_SIZE - 12.0)
	_note.visible = note != ""
	for i in _meters.size():
		var line: UnitSheet.StatLine = sheet.stats[i]
		var pips := line.stat == Unit.Stat.MOVE_RANGE or line.stat == Unit.Stat.ATTACK_RANGE
		_meters[i].show_stat(line.name, line.value, line.plain, sheet.scale_of(line.stat), pips, sheet.hp if line.stat == Unit.Stat.MAX_HP else -1)
	_clear(_skill)
	if sheet.skill != null:
		var state := sheet.skill_state if sheet.skill_state != "" else Text.t("deck.sheet.cooldown", {"turns": sheet.skill.cooldown()})
		_skill.add_child(SheetParts.ability_card(AbilityMark.Type.SKILL, Text.t("deck.sheet.skill"), Names.skill(sheet.skill), state, Names.skill_summary(sheet.skill), _width, false, 24.0, 15))
	else:
		_skill.add_child(SheetParts.ability_card(AbilityMark.Type.SKILL, Text.t("deck.sheet.skill"), Text.t("deck.sheet.no_skill"), "", "", _width, true, 24.0, 15))
	_clear(_evolutions)
	_evolutions_box.visible = not sheet.evolutions.is_empty()
	if not sheet.evolutions.is_empty():
		_evolutions_head.text = Text.t("deck.sheet.evolved") if sheet.evolved != Evolution.Id.NONE else Text.t("deck.sheet.evolution", {"level": Growth.MAX_LEVEL})
		var card_width := (_width - CARD_GAP * (sheet.evolutions.size() - 1)) / sheet.evolutions.size()
		for evolution in sheet.evolutions:
			var parts: Array[String] = []
			var bonus := DeckText.bonus_text(Evolution.bonuses(evolution), sheet.kind)
			if bonus != "":
				parts.append(bonus)
			for which in Evolution.traits(evolution):
				parts.append(Names.trait_text(which))
			_evolutions.add_child(_evolution_card(Names.evolution(evolution), Text.join_comma(parts), card_width))


## 進化先の小さな札: 名前と、能力値の増減・特性（幅で折り返す）。
func _evolution_card(title: String, summary: String, width: float) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(width, 0.0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := UiTheme.box(Palette.RAISED, Palette.BORDER, 1, 6, 7.0)
	box.border_width_left = 3
	card.add_theme_stylebox_override("panel", box)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	card.add_child(column)
	var name_label := SheetParts.text(14, Palette.TEXT, true)
	name_label.text = title
	column.add_child(name_label)
	var note := SheetParts.text(12, Palette.GOOD)
	SheetParts.fold(note, summary, width - 18.0)
	column.add_child(note)
	return card


## いま出している中身（検査用）。
func shown_sheet() -> UnitSheet:
	return _sheet


## 札の中身が、決めた幅からはみ出している量（px。0 以下なら収まっている。検査用。画面に出して 1 コマ待ってから呼ぶ）。
func overflow() -> float:
	return get_combined_minimum_size().x - _width


## 名前の欄の文（検査用）。
func title_text() -> String:
	return _title.text


## 能力値の行（検査用。HP、攻撃か回復、移動、射程の順）。
func stat_meters() -> Array[StatMeter]:
	return _meters


func _clear(box: Container) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
