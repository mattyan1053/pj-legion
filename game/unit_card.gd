extends RefCounted
## 駒 1 体の札（名前、役割、コスト、能力値、持ち物）。編成の確認（deck_preview.gd）と、部隊の編成の画面で使う。
## 札は既定の部品（PanelContainer、Label）だけで組む。色や枠は UI のテーマ（ui_theme.gd の PANEL_CARD）が当たる。

const Text := preload("res://game/text.gd")
const Names := preload("res://game/names.gd")
const DeckText := preload("res://game/deck_text.gd")
const UnitIcons := preload("res://game/unit_icons.gd")
const ItemIcon := preload("res://game/item_icon.gd")
const UiTheme := preload("res://game/ui_theme.gd")

## 札の幅（px）。並べたときに、中身で幅が変わらないように決めておく。
const WIDTH := 220.0


## kind の駒の札。equipment は持ち物（同じものはまとめて「×2」）。将（UnitKind.Id.KING）はコストを書かない（自動で加わる）。
## side は、アイコンの陣営の色（Unit.Side の値）。
static func build(kind: UnitKind.Id, equipment: Array[Equipment.Id] = [], side := 0) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(WIDTH, 0.0)
	card.set_meta(&"kind", kind)
	card.theme_type_variation = UiTheme.PANEL_CARD
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	card.add_child(column)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	column.add_child(top)
	top.add_child(UnitIcons.rect(kind, side, false, 48.0))
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 0)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(names)
	var title := _label(Names.kind(kind), 17)
	title.name = "Name"
	names.add_child(title)
	var role := DeckText.role_name(kind)
	var head := Text.t("deck.card.king") if kind == UnitKind.Id.KING else Text.t("deck.detail.role", {"role": role, "cost": UnitKind.cost(kind)})
	names.add_child(_label(head, 13, true))
	column.add_child(_label(DeckText.stats_line(kind, DeckText.equipment_bonus(equipment)), 13, true))
	if not equipment.is_empty():
		column.add_child(HSeparator.new())
		for item: Array in grouped_equipment(equipment):
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 4)
			row.add_child(ItemIcon.new(item[0], 18.0))
			row.add_child(_label(Names.item(item[0]) + (" ×%d" % item[1] if item[1] > 1 else ""), 13))
			column.add_child(row)
	return card


## 持ち物の行（「アイアンシールド ×2」）。持たせた順で、同じものは 1 行にまとめる。
static func equipment_lines(equipment: Array[Equipment.Id]) -> Array[String]:
	var lines: Array[String] = []
	for item: Array in grouped_equipment(equipment):
		lines.append(Names.item(item[0]) + (" ×%d" % item[1] if item[1] > 1 else ""))
	return lines


## 持ち物を [種類, 数] にまとめた列（持たせた順）。
static func grouped_equipment(equipment: Array[Equipment.Id]) -> Array:
	var groups: Array = []
	var seen: Array[Equipment.Id] = []
	for item in equipment:
		if seen.has(item):
			continue
		seen.append(item)
		groups.append([item, equipment.count(item)])
	return groups


static func _label(text: String, font_size: int, dim := false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.clip_text = true
	if dim:
		label.modulate.a = 0.75
	return label
