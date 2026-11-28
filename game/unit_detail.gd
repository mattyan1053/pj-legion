extends "res://game/window_base.gd"
## 駒 1 体のステータスの重なる画面（docs/deck-screen.md の「駒の詳細」）。編成確認（deck_preview.gd）・出撃準備（sortie_screen.gd）・
## 部隊編成（deck_screen.gd）・対戦の駒の情報の枠（battle_hud.gd）から開く。中身は unit_sheet.gd が欄ごとの値で持ち、ここは並べるだけ。
##
## 左に駒の姿（unit_portrait.gd）・レベルと経験値の棒・コスト・持ち物の欄。右に名前と札（役割・軍）、能力値の行（stat_meter.gd。持ち物での増減を色と矢印で）、
## スキルと必殺技の札、進化先の札。文の段落では並べない。
## 「閉じる」・右クリック・Esc・枠の外のクリックで閉じる。色や枠は UI のテーマ（ui_theme.gd。板は PANEL_SOLID）が当たる。

const Text := preload("res://game/text.gd")
const Names := preload("res://game/names.gd")
const DeckText := preload("res://game/deck_text.gd")
const UnitSheet := preload("res://game/unit_sheet.gd")
const SheetParts := preload("res://game/sheet_parts.gd")
const UnitPortrait := preload("res://game/unit_portrait.gd")
const RoleMark := preload("res://game/role_mark.gd")
const StatMeter := preload("res://game/stat_meter.gd")
const AbilityMark := preload("res://game/ability_mark.gd")
const CostGems := preload("res://game/cost_gems.gd")
const ItemIcon := preload("res://game/item_icon.gd")
const NationDecor := preload("res://game/nation_decor.gd")
const EffectChips := preload("res://game/effect_chips.gd")

## 左の列（姿）と右の列（欄）の幅。合わせて、1280×720 の論理の画面に余白を持って収まる。
## 右の列は、スキルの名前と札がいちばん長い札（スモークグレネード・クールダウン 3 ターン）が、2 枚並べて収まる幅。
const LEFT_WIDTH := 216.0
const RIGHT_WIDTH := 710.0
const PORTRAIT_SIZE := Vector2(LEFT_WIDTH, 236.0)
const GAP := 10.0
## いま乗っている効果の札の欄の行の数。
const EFFECT_ROWS := 2
## 状態の文の欄の行の数（1 つの状態が 1 行。入りきらない状態は、効果の札にだけ出る）。
const STATUS_ROWS := 2
const STATUS_LINE_HEIGHT := 19.0
## 持ち物の枠 1 つの高さ（持っていても空きでも同じ。名前と、2 行に折り返した効果が入る）。
const SLOT_HEIGHT := 77.0
## 窓の板の大きさ（駒・持ち物・開く場所に依らず同じ。docs/deck-screen.md の「駒の詳細」）。
## 高さは、いちばん長い列（対戦中の回復役の右の列: スキルの札・進化先・状態の 2 行・効果の札 2 行）と、閉じるボタンが入る高さ。
const WINDOW_SIZE := Vector2(984.0, 688.0)
## 札の中の説明の文字の大きさ。
const NOTE_SIZE := SheetParts.NOTE_SIZE

## 閉じた（対戦の画面が、止めていた時間と視点の操作を戻す）。
signal closed

var _sheet: UnitSheet
var _decor: NationDecor
var _portrait: UnitPortrait
var _role: RoleMark
var _title: Label
var _tags: HBoxContainer
var _note: Label
var _level_box: VBoxContainer
var _level: Label
var _experience: ProgressBar
var _experience_text: Label
var _cost_row: HBoxContainer
var _cost: Label
var _gems: CostGems
var _meters: Array[StatMeter] = []
var _statuses: VBoxContainer
## いま乗っている効果の札（対戦中の駒だけ。決まった大きさ）。
var _effects: EffectChips
var _abilities: HBoxContainer
var _items_head: Label
var _items_box: VBoxContainer
var _items: VBoxContainer
var _evolutions_box: VBoxContainer
var _evolutions_head: Label
var _evolutions: HBoxContainer


## overlays は、開いている重なる画面の積み上げ（AppContext.overlays）。
func setup(overlays: RefCounted) -> void:
	var panel := build_window(overlays, "", WINDOW_SIZE, 0.5, true)
	# 大きさは駒・持ち物・開く場所に依らず同じ（docs/ui-theme.md の「枠の大きさ」）。中身が少ない駒は、列の下を空けたままにする。
	Steady.mark(panel, "unit_detail.window", Steady.SIZE)
	# 上の縁に、軍の国の色の帯（軍なしの駒は出さない）。
	_decor = NationDecor.new(UnitKind.Army.NONE, 0.0, 70.0)
	panel.add_child(_decor)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", GAP)
	panel.add_child(column)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	column.add_child(body)
	body.add_child(_build_left())
	body.add_child(_build_right())
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var close := Button.new()
	close.text = Text.t("common.close")
	close.focus_mode = Control.FOCUS_NONE
	close.add_theme_font_size_override("font_size", 17)
	close.custom_minimum_size = Vector2(180.0, 40.0)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(close_detail)
	column.add_child(close)


## 左の列: 駒の姿、レベルと経験値の棒、コスト、持ち物の欄。
func _build_left() -> Control:
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(LEFT_WIDTH, 0.0)
	left.add_theme_constant_override("separation", GAP)
	_portrait = UnitPortrait.new(PORTRAIT_SIZE)
	left.add_child(_portrait)
	_level_box = VBoxContainer.new()
	_level_box.add_theme_constant_override("separation", 3)
	left.add_child(_level_box)
	var level_row := HBoxContainer.new()
	_level_box.add_child(level_row)
	_level = _text(20, Palette.ACCENT, true)
	_level.add_theme_font_override("font", UiTheme.FONT_HEADING)
	_level.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_row.add_child(_level)
	_experience_text = _text(13, Palette.TEXT_DIM)
	_experience_text.size_flags_vertical = Control.SIZE_SHRINK_END
	level_row.add_child(_experience_text)
	_experience = ProgressBar.new()
	_experience.show_percentage = false
	_experience.custom_minimum_size = Vector2(0.0, 8.0)
	_experience.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_level_box.add_child(_experience)
	_cost_row = HBoxContainer.new()
	_cost_row.add_theme_constant_override("separation", 8)
	left.add_child(_cost_row)
	_cost = _text(14, Palette.TEXT_DIM)
	_cost.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cost_row.add_child(_cost)
	_gems = CostGems.new(0, 0, 10.0, 80.0)
	_cost_row.add_child(_gems)
	_items_box = VBoxContainer.new()
	_items_box.add_theme_constant_override("separation", 5)
	left.add_child(_items_box)
	var items_head := UiTheme.section_head("", 14)
	_items_head = items_head.get_child(0)
	_items_box.add_child(items_head)
	_items = VBoxContainer.new()
	_items.add_theme_constant_override("separation", 5)
	_items_box.add_child(_items)
	return left


## 右の列: 名前と札、役割の説明、能力値、状態、スキルと必殺技、進化先。
func _build_right() -> Control:
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(RIGHT_WIDTH, 0.0)
	right.add_theme_constant_override("separation", GAP)
	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", 4)
	right.add_child(head)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 10)
	head.add_child(title_row)
	_role = RoleMark.new(UnitKind.Role.NONE, 30.0)
	title_row.add_child(_role)
	_title = Label.new()
	_title.theme_type_variation = UiTheme.LABEL_HEADING
	_title.add_theme_font_size_override("font_size", 28)
	title_row.add_child(_title)
	_tags = HBoxContainer.new()
	_tags.add_theme_constant_override("separation", 6)
	_tags.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tags.alignment = BoxContainer.ALIGNMENT_END
	title_row.add_child(_tags)
	_note = _text(NOTE_SIZE, Palette.TEXT_DIM)
	head.add_child(_note)
	right.add_child(UiTheme.window_rule())
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 3)
	right.add_child(rows)
	for i in UnitSheet.STATS.size():
		var meter := StatMeter.new()
		_meters.append(meter)
		rows.add_child(meter)
	_abilities = HBoxContainer.new()
	_abilities.add_theme_constant_override("separation", GAP)
	right.add_child(_abilities)
	_evolutions_box = VBoxContainer.new()
	_evolutions_box.add_theme_constant_override("separation", 5)
	right.add_child(_evolutions_box)
	var evolutions_head := UiTheme.section_head("", 14)
	_evolutions_head = evolutions_head.get_child(0)
	_evolutions_box.add_child(evolutions_head)
	_evolutions = HBoxContainer.new()
	_evolutions.add_theme_constant_override("separation", GAP)
	_evolutions_box.add_child(_evolutions)
	# 対戦中の駒の状態と、いま乗っている効果の札は、列の下に寄せる（空のときに、能力値とスキルの札の間が空かない）。
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(spacer)
	_statuses = VBoxContainer.new()
	_statuses.add_theme_constant_override("separation", 0)
	_statuses.custom_minimum_size = Vector2(RIGHT_WIDTH, STATUS_LINE_HEIGHT * STATUS_ROWS)
	_statuses.alignment = BoxContainer.ALIGNMENT_END
	Steady.mark(_statuses, "unit_detail.statuses")
	right.add_child(_statuses)
	_effects = EffectChips.new(RIGHT_WIDTH, EFFECT_ROWS, "unit_detail.effects")
	right.add_child(_effects)
	return right


## kind の駒（持ち物 equipment、始めのレベル level）のステータスを開く。side は陣営の色、deck_army は部隊の軍（必殺技と国の色。-1 なら駒の種類の軍）。
## look は将の姿（unit_looks.gd の KING_LOOKS。空ならいつもの将）。
func open(kind: UnitKind.Id, equipment: Array[Equipment.Id] = [], side := 0, deck_army := -1, level := 1, look := &"") -> void:
	open_sheet(UnitSheet.of_kind(kind, equipment, side, deck_army, level, look))


## sheet（unit_sheet.gd。編成の駒か、対戦中の駒）のステータスを開く。
func open_sheet(sheet: UnitSheet) -> void:
	_sheet = sheet
	var evolved := sheet.evolved != Evolution.Id.NONE
	_decor.army = sheet.army
	_portrait.show_unit(sheet.kind, sheet.side, sheet.army, evolved, sheet.look)
	var role := UnitKind.role(sheet.kind)
	_role.role = role
	_role.visible = role != UnitKind.Role.NONE
	_title.text = sheet.name
	_clear(_tags)
	for tag in sheet.tags():
		_tags.add_child(_tag(tag, Palette.TEXT))
	if sheet.strike > 0:
		# 回復役の攻撃（能力値の棒は回復の値なので、名前の右に札で）。
		_tags.add_child(_tag(Text.t("deck.sheet.strike", {"power": sheet.strike}), Palette.TEXT))
	var note := Names.role_summary(role)
	if sheet.borrowed:
		note = Text.t("deck.detail.borrowed", {"origin": Names.army(UnitKind.army(sheet.kind)), "army": Names.army(sheet.army)})
	_note.text = note
	_note.visible = note != ""
	_show_level(sheet)
	for i in _meters.size():
		var line: UnitSheet.StatLine = sheet.stats[i]
		var is_hp := line.stat == Unit.Stat.MAX_HP
		var pips := line.stat == Unit.Stat.MOVE_RANGE or line.stat == Unit.Stat.ATTACK_RANGE
		_meters[i].show_stat(line.name, line.value, line.plain, sheet.scale_of(line.stat), pips, sheet.hp if is_hp else -1)
	_show_statuses(sheet)
	_show_abilities(sheet)
	_show_items(sheet)
	_show_evolutions(sheet)
	visible = true


func _show_level(sheet: UnitSheet) -> void:
	_level_box.visible = sheet.grows
	if sheet.grows:
		var top := sheet.level >= Growth.MAX_LEVEL
		_level.text = Text.t("deck.sheet.level", {"level": sheet.level})
		_experience.max_value = Growth.EXPERIENCE_PER_LEVEL
		_experience.value = Growth.EXPERIENCE_PER_LEVEL if top else sheet.experience
		_experience_text.text = Text.t("deck.sheet.level_max") if top else Text.t("deck.sheet.experience", {"experience": sheet.experience, "needed": Growth.EXPERIENCE_PER_LEVEL})
		# 魔物は進化しないので、経験値は出さない（レベルは上がるので Lv だけ）。場所は空けたまま（下の欄が動かない）。
		var monster := UnitKind.is_monster(sheet.kind)
		if monster:
			_experience_text.text = ""
		_experience.modulate.a = 0.0 if monster else 1.0
	_cost_row.visible = sheet.cost() > 0
	_cost.text = Text.t("deck.sheet.cost", {"cost": sheet.cost()})
	_gems.count = sheet.cost()


func _show_statuses(sheet: UnitSheet) -> void:
	_effects.visible = sheet.in_battle
	_effects.show_effects(sheet.effects)
	_clear(_statuses)
	_statuses.visible = sheet.in_battle
	for status: Array in sheet.statuses.slice(0, STATUS_ROWS):
		var line := _text(NOTE_SIZE, Palette.INFO)
		line.text = Text.t("battle.hud.status", {"status": Names.status(status[0]), "turns": status[1], "effect": Names.status_summary(status[0])})
		line.custom_minimum_size = Vector2(RIGHT_WIDTH, STATUS_LINE_HEIGHT)
		line.clip_text = true
		line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_statuses.add_child(line)


## スキルと必殺技の札（横に並べる。必殺技を持たない軍なしの駒は、スキルの札だけを幅いっぱいに）。
func _show_abilities(sheet: UnitSheet) -> void:
	_clear(_abilities)
	var cards := 2 if sheet.ult != null else 1
	var width := (RIGHT_WIDTH - GAP * (cards - 1)) / cards
	if sheet.skill != null:
		var state := sheet.skill_state if sheet.skill_state != "" else Text.t("deck.sheet.cooldown", {"turns": sheet.skill.cooldown()})
		_abilities.add_child(_card(AbilityMark.Type.SKILL, Text.t("deck.sheet.skill"), Names.skill(sheet.skill), state, Names.skill_summary(sheet.skill), width))
	else:
		_abilities.add_child(_card(AbilityMark.Type.SKILL, Text.t("deck.sheet.skill"), Text.t("deck.sheet.no_skill"), "", "", width, true))
	if sheet.ult != null:
		_abilities.add_child(_card(AbilityMark.Type.ULT, Text.t("deck.sheet.ult"), Names.ult(sheet.ult), Names.army(sheet.army), Names.ult_summary(sheet.ult), width))


## 持ち物の欄（持てる数だけの枠。持っていない枠は沈める）。持てない駒（将・魔物）は欄ごと出さない。
func _show_items(sheet: UnitSheet) -> void:
	_clear(_items)
	_items_box.visible = sheet.item_slots > 0
	if sheet.item_slots <= 0:
		return
	var held := 0
	for item: Array in sheet.items:
		held += int(item[1])
	_items_head.text = Text.t("deck.sheet.items", {"count": held, "max": sheet.item_slots})
	# 持っている 1 個が、枠 1 つ（同じ持ち物を重ねていても、枠は個数ぶん）。
	var pieces: Array[Equipment.Id] = []
	for held_item: Array in sheet.items:
		for n in int(held_item[1]):
			pieces.append(held_item[0])
	var slots := maxi(sheet.item_slots, pieces.size())
	var width := LEFT_WIDTH
	for i in slots:
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(width, SLOT_HEIGHT)
		Steady.mark(slot, "unit_detail.item_slot")
		_items.add_child(slot)
		if i >= pieces.size():
			slot.add_theme_stylebox_override("panel", UiTheme.box(Color(Palette.INK, 0.5), Color(Palette.BORDER, 0.5), 1, 6, 6.0))
			var none := _text(NOTE_SIZE, Palette.TEXT_OFF)
			none.text = Text.t("deck.sheet.no_item")
			none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			none.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			slot.add_child(none)
			continue
		var item := pieces[i]
		slot.add_theme_stylebox_override("panel", UiTheme.box(Palette.RAISED, Palette.BORDER, 1, 6, 6.0))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slot.add_child(row)
		row.add_child(ItemIcon.new(item, 28.0))
		var words := VBoxContainer.new()
		words.add_theme_constant_override("separation", 0)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(words)
		var item_name := _text(14, Palette.TEXT, true)
		item_name.text = Names.item(item)
		words.add_child(item_name)
		var effect := _text(NOTE_SIZE, Palette.GOOD)
		_fold(effect, DeckText.equipment_effect(item), width - 28.0 - 8.0 - 14.0)
		words.add_child(effect)
		slot.tooltip_text = DeckText.equipment_traits_text(item)
		slot.mouse_filter = Control.MOUSE_FILTER_STOP if slot.tooltip_text != "" else Control.MOUSE_FILTER_IGNORE


## 進化先の札（選べる 2 つ。進化した駒は、その進化先だけ）。進化しない駒（将・魔物）は欄ごと出さない。
func _show_evolutions(sheet: UnitSheet) -> void:
	_clear(_evolutions)
	_evolutions_box.visible = not sheet.evolutions.is_empty()
	if sheet.evolutions.is_empty():
		return
	var done := sheet.evolved != Evolution.Id.NONE
	_evolutions_head.text = Text.t("deck.sheet.evolved") if done else Text.t("deck.sheet.evolution", {"level": Growth.MAX_LEVEL})
	var width := (RIGHT_WIDTH - GAP * (sheet.evolutions.size() - 1)) / sheet.evolutions.size()
	for evolution in sheet.evolutions:
		var parts: Array[String] = []
		var bonus := DeckText.bonus_text(Evolution.bonuses(evolution), sheet.kind)
		if bonus != "":
			parts.append(bonus)
		for which in Evolution.traits(evolution):
			parts.append(Names.trait_text(which))
		_evolutions.add_child(_card(AbilityMark.Type.EVOLUTION, "", Names.evolution(evolution), "", Text.join_comma(parts), width))


## 札 1 枚（sheet_parts.gd）。
func _card(type: AbilityMark.Type, kind_text: String, title: String, state: String, summary: String, width: float, off := false) -> Control:
	return SheetParts.ability_card(type, kind_text, title, state, summary, width, off)


## 小さな札（役割・軍・クールダウン）。
func _tag(text: String, color: Color) -> Control:
	return SheetParts.tag(text, color)


func _text(font_size: int, color: Color, bold := false) -> Label:
	return SheetParts.text(font_size, color, bold)


## label に、width で折り返した text を入れる。
func _fold(label: Label, text: String, width: float) -> void:
	SheetParts.fold(label, text, width)


func _clear(box: Container) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()


func close_detail() -> void:
	visible = false


## いま出している駒の名前と、欄の文の全部（検査用）。
func title_text() -> String:
	return _title.text


func body_text() -> String:
	return _sheet.text() if _sheet != null else ""


## 出している、乗っている効果の札の文（検査用）。
func effect_lines() -> Array[String]:
	return _effects.lines() if _effects.visible else ([] as Array[String])


## いま出している中身（検査用）。
func shown_sheet() -> UnitSheet:
	return _sheet


## 能力値の行（検査用。HP、攻撃か回復、移動、射程の順）。
func stat_meters() -> Array[StatMeter]:
	return _meters


## 窓の板の大きさ（検査用。論理の画面に収まるか）。
func panel_size() -> Vector2:
	return window_panel().get_combined_minimum_size()


## 持ち物の枠の大きさ（検査用。持っていても空きでも同じ高さ）。
func item_slot_sizes() -> Array[Vector2]:
	var sizes: Array[Vector2] = []
	if _items_box.visible:
		for slot: Control in _items.get_children():
			sizes.append(slot.size)
	return sizes


## 経験値（文と棒）が見えているか（検査用。魔物は出さない）。
func shows_experience() -> bool:
	return _level_box.visible and _experience_text.text != "" and _experience.modulate.a > 0.0


func _on_hidden() -> void:
	closed.emit()
