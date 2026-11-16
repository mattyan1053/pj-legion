extends RefCounted
## 駒 1 体の札（名前、役割、コスト、能力値、持ち物）。編成の確認（deck_preview.gd）と、部隊の編成の画面で使う。
## 札は既定の部品（PanelContainer、Label）だけで組む。色や枠は UI のテーマ（ui_theme.gd の PANEL_CARD）が当たる。

const DeckText := preload("res://game/deck_text.gd")
const UiTheme := preload("res://game/ui_theme.gd")

## 札の幅（px）。並べたときに、中身で幅が変わらないように決めておく。
const WIDTH := 220.0


## kind の駒の札。equipment は持ち物（同じものはまとめて「×2」）。将（UnitKind.Id.KING）はコストを書かない（自動で加わる）。
static func build(kind: UnitKind.Id, equipment: Array[Equipment.Id] = []) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(WIDTH, 0.0)
	card.set_meta(&"kind", kind)
	card.theme_type_variation = UiTheme.PANEL_CARD
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	card.add_child(column)
	var title := _label(UnitKind.display_name(kind), 17)
	title.name = "Name"
	column.add_child(title)
	var role := DeckText.role_name(kind)
	var head := ("本陣に置く" if kind == UnitKind.Id.KING else "%s　コスト %d" % [role, UnitKind.cost(kind)])
	column.add_child(_label(head, 13, true))
	column.add_child(_label(DeckText.stats_line(kind, DeckText.equipment_bonus(equipment)), 13, true))
	if not equipment.is_empty():
		column.add_child(HSeparator.new())
		for line in equipment_lines(equipment):
			column.add_child(_label(line, 13))
	return card


## 持ち物の行（「アイアンシールド ×2」）。持たせた順で、同じものは 1 行にまとめる。
static func equipment_lines(equipment: Array[Equipment.Id]) -> Array[String]:
	var lines: Array[String] = []
	var seen: Array[Equipment.Id] = []
	for item in equipment:
		if seen.has(item):
			continue
		seen.append(item)
		var count := equipment.count(item)
		lines.append(Equipment.display_name(item) + (" ×%d" % count if count > 1 else ""))
	return lines


static func _label(text: String, font_size: int, dim := false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.clip_text = true
	if dim:
		label.modulate.a = 0.75
	return label
