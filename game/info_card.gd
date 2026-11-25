extends VBoxContainer
## 対戦の左下の情報の枠の中身（battle_hud.gd の情報の枠が持つ）: 駒のステータスの札と、マスの札。
## 部隊編成の右の札（unit_summary.gd）・ステータスの窓（unit_detail.gd）と同じ部品で組む（文の段落で並べない）:
## 額、役割の印と名前、札（所属・役割・軍・レベル）、能力値の行（HP・攻撃・移動・射程の棒と粒。stat_meter.gd）、経験値の棒、
## 状態の札（印と残りのターン）、特性の札、スキルの札（使える / あと N ターン）、持ち物の枠、行動の状態、いま要る説明の札。
## 幅は渡した幅で決まり、中身では変わらない。高さは fit で、渡した高さに収める（入りきらなければ、後で読めるものから省く）。

const Text := preload("res://game/text.gd")
const Names := preload("res://game/names.gd")
const UnitSheet := preload("res://game/unit_sheet.gd")
const SheetParts := preload("res://game/sheet_parts.gd")
const UnitFrame := preload("res://game/unit_frame.gd")
const RoleMark := preload("res://game/role_mark.gd")
const StatMeter := preload("res://game/stat_meter.gd")
const AbilityMark := preload("res://game/ability_mark.gd")
const ItemIcon := preload("res://game/item_icon.gd")
const UiTheme := preload("res://game/ui_theme.gd")
const Palette := preload("res://game/ui_palette.gd")

## 額の辺（px）、欄の間（px）、札の並びの間（px）。
const FRAME_SIZE := 56.0
const GAP := 5
const CHIP_GAP := 5
## 持ち物の枠の高さ、空きの枠の幅、印の辺（px）。
const SLOT_HEIGHT := 28.0
const EMPTY_SLOT_WIDTH := 48.0
const ITEM_ICON := 20.0
## レベルの札の、経験値の棒の大きさ（px）。
const EXPERIENCE_BAR := Vector2(44.0, 6.0)
## スキルの札の説明を折り返す幅を、札の幅から狭めるぶん（px。札の左右の余白と縁）。
const SUMMARY_INSET := 22.0
## 状態の札の印（丸）の辺（px）。
const STATUS_DOT := 9.0

var _width: float
## 駒の札の欄。
var _unit_box: VBoxContainer
var _frame: UnitFrame
var _role: RoleMark
var _title: Label
var _tags: ChipRows
var _meters: Array[StatMeter] = []
## 行動の状態の札（名前の右）。
var _action: HBoxContainer
var _chips: ChipRows
var _skill: VBoxContainer
var _items: HBoxContainer
var _state: Label
var _note: PanelContainer
var _note_text: Label
## マスの札の欄。
var _cell_box: VBoxContainer
var _cell_title: Label
var _cell_tags: ChipRows
var _cell_entries: VBoxContainer
## 出している文（検査用。欄ごとに 1 行）と見出し。
var _texts: Array[String] = []
var _heading := ""
## 入りきらずに省いた欄の数。
var _dropped := 0
## 欄ごとの文（検査用の text が、出している欄だけを並べる）: 状態の行、いま要る説明、スキル、持ち物、札。
var _state_plain := ""
var _note_plain := ""
var _skill_line := ""
var _items_line := ""
var _chip_lines: Array[String] = []
var _skill_summary_shown := false
## スキルの札の説明（省くときに外す）。
var _skill_summary := ""
var _skill_args: Array = []


func _init(width := 320.0) -> void:
	_width = width
	custom_minimum_size = Vector2(width, 0.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 0)
	_build_unit()
	_build_cell()


func _build_unit() -> void:
	_unit_box = _column(self)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_unit_box.add_child(head)
	_frame = UnitFrame.new(UnitKind.Id.KING, 0, FRAME_SIZE)
	_frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	head.add_child(_frame)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 3)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(names)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 6)
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	names.add_child(title_row)
	_role = RoleMark.new(UnitKind.Role.NONE, 18.0)
	title_row.add_child(_role)
	_title = SheetParts.text(17, Palette.TEXT, true)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title.clip_text = true
	title_row.add_child(_title)
	_action = HBoxContainer.new()
	_action.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.add_child(_action)
	_tags = _flow(names, _width - FRAME_SIZE - 10.0)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 1)
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_unit_box.add_child(rows)
	for i in UnitSheet.STATS.size():
		var meter := StatMeter.new(true)
		_meters.append(meter)
		rows.add_child(meter)
	_chips = _flow(_unit_box, _width)
	_skill = _column(_unit_box)
	_items = HBoxContainer.new()
	_items.add_theme_constant_override("separation", CHIP_GAP)
	_items.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_unit_box.add_child(_items)
	_state = SheetParts.text(12, Palette.TEXT_DIM)
	_unit_box.add_child(_state)
	# いま要る説明（メニューの項目を押すと何が起きるか、選んでいるスキルの中身）。金の縁の札。
	_note = PanelContainer.new()
	_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var note_box := UiTheme.box(Color(Palette.CHOSEN, 0.55), Palette.GOLD, 1, 6, 8.0)
	note_box.border_width_left = 3
	_note.add_theme_stylebox_override("panel", note_box)
	_unit_box.add_child(_note)
	_note_text = SheetParts.text(14, Palette.ACCENT)
	_note.add_child(_note_text)


func _build_cell() -> void:
	_cell_box = _column(self)
	_cell_box.visible = false
	_cell_title = SheetParts.text(19, Palette.TEXT, true)
	_cell_box.add_child(_cell_title)
	_cell_tags = _flow(_cell_box, _width)
	_cell_box.add_child(UiTheme.window_rule())
	_cell_entries = _column(_cell_box)


## 駒の札を出す。sheet は対戦中の駒のステータス（UnitSheet.of_unit）、tint は陣営の色。
## side_tag は所属の札の文（「自軍」「敵」など）、level_tag はレベルの札の文（育たない駒は空）、
## experience は [いまの経験値, 次のレベルまで]（出さないなら空の列）。
## chips は札にする短い文の列（[文, 色] の列。特性）。action は行動の状態（名前の右の札。「未行動」）、
## state はそのほかの状態（いるマスなど。札の下の小さな行）、note はいま要る説明（無ければ空）。
## skill_note が偽なら、スキルの札に説明を出さない（note のほうに出しているとき）。
func show_unit(
	sheet: UnitSheet, title: String, tint: Color, side_tag: String, level_tag: String, experience: Array, chips: Array,
	action: String, state: String, note: String, skill_note := true
) -> void:
	_unit_box.visible = true
	_cell_box.visible = false
	_dropped = 0
	_heading = title
	_texts.clear()
	_title.text = title
	_title.add_theme_color_override("font_color", tint.lightened(0.45))
	_frame.set_kind(sheet.kind, sheet.side, sheet.evolved != Evolution.Id.NONE, sheet.look)
	_frame.edge = Color(tint.lightened(0.15), 0.9)
	var role := UnitKind.role(sheet.kind)
	_role.role = role
	_role.visible = role != UnitKind.Role.NONE
	_tags.clear()
	var tag_texts: Array[String] = [side_tag]
	_tags.add(SheetParts.tag(side_tag, tint.lightened(0.5)))
	for words in sheet.tags():
		if words == Text.t("deck.card.king"):
			continue  # 「本陣に配置」は編成の札の言葉
		_tags.add(SheetParts.tag(words, Palette.TEXT))
		tag_texts.append(words)
	if sheet.borrowed:
		var origin := Text.t("battle.hud.origin", {"origin": Names.army(UnitKind.army(sheet.kind))})
		_tags.add(SheetParts.tag(origin, Palette.TEXT_DIM))
		tag_texts.append(origin)
	if level_tag != "":
		_tags.add(_level_chip(level_tag, experience))
		tag_texts.append(level_tag)
	_clear(_action)
	if sheet.strike > 0:
		var strike := Text.t("deck.sheet.strike", {"power": sheet.strike})
		_action.add_child(SheetParts.tag(strike, Palette.TEXT))
		tag_texts.append(strike)
	if action != "":
		_action.add_child(SheetParts.tag(action, Palette.TEXT_DIM))
		tag_texts.append(action)
	_texts.append(Text.t("battle.hud.separator").join(tag_texts))
	for i in _meters.size():
		var line: UnitSheet.StatLine = sheet.stats[i]
		var pips := line.stat == Unit.Stat.MOVE_RANGE or line.stat == Unit.Stat.ATTACK_RANGE
		_meters[i].show_stat(line.name, line.value, line.plain, sheet.scale_of(line.stat), pips, sheet.hp if line.stat == Unit.Stat.MAX_HP else -1)
		_texts.append(" ".join(_meters[i].texts()).strip_edges())
	if not experience.is_empty():
		_texts.append(Text.t("deck.sheet.experience", {"experience": experience[0], "needed": experience[1]}))
	_chips.clear()
	_chip_lines.clear()
	for status: Array in sheet.statuses:
		_chips.add(_status_chip(status[0], status[1]))
		_chip_lines.append(Text.t("battle.hud.status_chip", {"status": Names.status(status[0]), "turns": status[1]}))
	for chip: Array in chips:
		_chips.add(SheetParts.tag(chip[0], chip[1]))
		_chip_lines.append(chip[0])
	_chips.visible = not _chips.is_empty()
	_skill_summary = ""
	_clear(_skill)
	if sheet.skill == null:
		# スキルを持たない駒も、同じ場所に沈めた札を出す（札の並びを、駒によって変えない）。
		_skill.add_child(SheetParts.ability_card(AbilityMark.Type.SKILL, Text.t("deck.sheet.skill"), Text.t("deck.sheet.no_skill"), "", "", _width, true, 22.0, 15))
	else:
		_skill_summary = Names.skill_summary(sheet.skill) if skill_note else ""
		_skill_args = [Names.skill(sheet.skill), sheet.skill_state]
		_add_skill_card(_skill_summary)
	_skill_line = Text.t("battle.hud.skill", {"skill": Names.skill(sheet.skill), "state": sheet.skill_state}) if sheet.skill != null else ""
	_show_items(sheet)
	_state.visible = state != ""
	_state_plain = state
	SheetParts.fold(_state, state, _width)
	_note.visible = note != ""
	_note_plain = note
	SheetParts.fold(_note_text, note, _width - 20.0)


## マスの札を出す。title は見出し（マスの位置）、tags は札にする短い文（地形の名前）、
## entries は [名前, 説明の行の列] の列（地形・環境オブジェクト・盤の上の効果）。
func show_cell(title: String, tags: Array[String], entries: Array) -> void:
	_unit_box.visible = false
	_cell_box.visible = true
	_dropped = 0
	_heading = title
	_texts.clear()
	_cell_title.text = title
	_cell_tags.clear()
	for words in tags:
		_cell_tags.add(SheetParts.tag(words, Palette.TEXT, 13))
	_cell_tags.visible = not tags.is_empty()
	_clear(_cell_entries)
	for entry: Array in entries:
		var notes: Array = entry[1]
		_cell_entries.add_child(_entry_card(entry[0], notes))
		_texts.append(entry[0])
		for note: String in notes:
			_texts.append(note)


## 中身を、高さ height（px）に収める。入りきらなければ、後で読めるものから順に省く
## （いるマスなどの状態の行 → スキルの説明 → 持ち物 → 状態・特性の札。「詳細」の窓と、マスを押した札で読める）。
## スキルの名前と、いま要る説明は省かない。何度呼んでも同じ結果（省いたものを戻してから、測り直す）。並べ直しを待たずに、いまの中身から求める。
func fit(height: float) -> void:
	_dropped = 0
	if not _unit_box.visible:
		return
	_state.visible = _state_plain != ""
	_items.visible = _items_line != ""
	_chips.visible = not _chips.is_empty()
	if _skill_summary != "" and not _skill_summary_shown:
		_clear(_skill)
		_add_skill_card(_skill_summary)
	if _over(height) > 0.0 and _state.visible:
		_state.visible = false
		_dropped += 1
	if _over(height) > 0.0 and _skill_summary != "":
		_clear(_skill)
		_add_skill_card("")
		_dropped += 1
	for part: Control in [_items, _chips]:
		if _over(height) <= 0.0:
			break
		if part.visible:
			part.visible = false
			_dropped += 1


## 中身が、高さ height からはみ出している高さ（px。収まっていれば 0 以下）。
func _over(height: float) -> float:
	return get_combined_minimum_size().y - height


## 省いた欄の数。検査用。
func dropped() -> int:
	return _dropped


## 高さ height に収まらず、下が切れているか。検査用。
func is_cut(height: float) -> bool:
	return _over(height) > 0.5


## 中身が、決めた幅からはみ出している量（px。0 以下なら収まっている）。検査用。
func overflow() -> float:
	return get_combined_minimum_size().x - _width


## 出している文（欄ごとに 1 行。省いた欄は入らない）と、見出し。検査用。
func text() -> String:
	var shown := _texts.duplicate()
	if not _unit_box.visible:
		return "\n".join(shown)
	if _chips.visible:
		shown.append_array(_chip_lines)
	if _skill_line != "":
		shown.append(_skill_line)
		if _skill_summary != "" and _skill_summary_shown:
			shown.append(_skill_summary)
	if _items.visible:
		shown.append(_items_line)
	if _state.visible:
		shown.append(_state_plain)
	if _note.visible:
		shown.append(_note_plain)
	return "\n".join(shown)


func heading() -> String:
	return _heading


## 能力値の行（HP、攻撃か回復、移動、射程の順）。検査用。
func stat_meters() -> Array[StatMeter]:
	return _meters


func _add_skill_card(summary: String) -> void:
	_skill_summary_shown = summary != ""
	_skill.add_child(SheetParts.ability_card(AbilityMark.Type.SKILL, Text.t("deck.sheet.skill"), _skill_args[0], _skill_args[1], summary, _width, false, 22.0, 15, SUMMARY_INSET))


## 持ち物の枠: 持っているものは、印と名前の枠（同じものは「×2」とまとめ、幅を分け合う）。空きは、数だけ小さな沈めた枠。持てない駒は出さない。
func _show_items(sheet: UnitSheet) -> void:
	_clear(_items)
	_items.visible = sheet.item_slots > 0
	_items_line = ""
	if sheet.item_slots <= 0:
		return
	var names: Array[String] = []
	var held := 0
	for item: Array in sheet.items:
		held += int(item[1])
		var words := Names.item(item[0])
		if int(item[1]) > 1:
			words = Text.t("battle.hud.item_count", {"item": words, "count": item[1]})
		names.append(words)
		var slot := _slot(true)
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var row := slot.get_child(0)
		row.add_child(ItemIcon.new(item[0], ITEM_ICON))
		var label := SheetParts.text(12, Palette.TEXT)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.clip_text = true
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.text = words
		row.add_child(label)
		_items.add_child(slot)
	for i in maxi(sheet.item_slots - held, 0):
		var slot := _slot(false)
		if held == 0:
			slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var label := SheetParts.text(12, Palette.TEXT_OFF)
		label.text = Text.t("deck.sheet.no_item")
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.get_child(0).add_child(label)
		_items.add_child(slot)
	_items_line = Text.t("battle.hud.equipment", {"items": Text.join_dot(names) if not names.is_empty() else Text.t("battle.hud.no_items")})


func _slot(filled: bool) -> PanelContainer:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(EMPTY_SLOT_WIDTH, SLOT_HEIGHT)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_theme_stylebox_override("panel", UiTheme.box(Palette.RAISED if filled else Color(Palette.INK, 0.5), Color(Palette.BORDER, 1.0 if filled else 0.5), 1, 5, 5.0))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(row)
	return slot


## レベルの札: 「Lv 2」と、次のレベルまでの経験値の小さな棒（experience が [いま, 次まで]。空なら棒は出さない）。
func _level_chip(words: String, experience: Array) -> Control:
	var plate := SheetParts.tag(words, Palette.ACCENT) as PanelContainer
	if experience.is_empty():
		return plate
	var label := plate.get_child(0)
	plate.remove_child(label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(row)
	row.add_child(label)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(EXPERIENCE_BAR.x, EXPERIENCE_BAR.y)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.max_value = maxf(experience[1], 1.0)
	bar.value = experience[0]
	bar.add_theme_stylebox_override("background", UiTheme.box(Palette.INK, Palette.BORDER, 1, 2, 0.0))
	bar.add_theme_stylebox_override("fill", UiTheme.box(Palette.GOLD, Palette.INK, 1, 2, 0.0))
	row.add_child(bar)
	return plate


## 状態の札: 印（丸）、名前、残りのターン数。
func _status_chip(type: Status.Type, turns: int) -> Control:
	var plate := PanelContainer.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := UiTheme.box(Color(Palette.INFO, 0.12), Color(Palette.INFO, 0.7), 1, 9, 0.0)
	box.content_margin_left = 7.0
	box.content_margin_right = 4.0
	box.content_margin_top = 1.0
	box.content_margin_bottom = 2.0
	plate.add_theme_stylebox_override("panel", box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(row)
	var dot := Panel.new()
	dot.custom_minimum_size = Vector2(STATUS_DOT, STATUS_DOT)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.add_theme_stylebox_override("panel", UiTheme.box(Palette.INFO, Palette.INK, 1, int(STATUS_DOT), 0.0))
	row.add_child(dot)
	var name_label := SheetParts.text(12, Palette.INFO, true)
	name_label.text = Names.status(type)
	row.add_child(name_label)
	var turns_label := SheetParts.text(11, Palette.TEXT)
	turns_label.text = Text.t("battle.hud.status_turns", {"turns": turns})
	turns_label.add_theme_stylebox_override("normal", UiTheme.box(Color(Palette.INK, 0.8), Color(Palette.INK, 0.0), 0, 7, 5.0))
	row.add_child(turns_label)
	return plate


## マスの札の 1 枚: 名前（太字）と、説明の行（幅で折り返す）。
func _entry_card(title: String, notes: Array) -> Control:
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := UiTheme.box(Palette.RAISED, Palette.BORDER, 1, 6, 8.0)
	box.border_width_left = 3
	card.add_theme_stylebox_override("panel", box)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(column)
	var name_label := SheetParts.text(15, Palette.TEXT, true)
	name_label.text = title
	column.add_child(name_label)
	for words: String in notes:
		var note := SheetParts.text(SheetParts.NOTE_SIZE, Palette.TEXT_DIM)
		SheetParts.fold(note, words, _width - 22.0)
		column.add_child(note)
	return card


func _column(parent: Control) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", GAP)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(column)
	return column


func _flow(parent: Control, width: float) -> ChipRows:
	var flow := ChipRows.new(width)
	parent.add_child(flow)
	return flow


func _clear(box: Container) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()


## 札を左から並べ、幅に入らなければ次の行へ送る入れ物。
## HFlowContainer は、並べ直すまで高さが決まらない。ここは、足したときに行を決めるので、足した直後に高さが分かる（fit が待たずに測れる）。
class ChipRows:
	extends VBoxContainer

	var _room: float
	var _row: HBoxContainer

	func _init(width: float) -> void:
		_room = width
		add_theme_constant_override("separation", 3)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func add(chip: Control) -> void:
		if _row == null:
			_new_row()
		_row.add_child(chip)
		if _row.get_child_count() > 1 and _row.get_combined_minimum_size().x > _room:
			_row.remove_child(chip)
			_new_row()
			_row.add_child(chip)

	func clear() -> void:
		for child in get_children():
			remove_child(child)
			child.queue_free()
		_row = null

	func is_empty() -> bool:
		return get_child_count() == 0

	func _new_row() -> void:
		_row = HBoxContainer.new()
		_row.add_theme_constant_override("separation", CHIP_GAP)
		_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_row)
