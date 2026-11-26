extends VBoxContainer
## 駒にいま乗っている効果の札の並び（unit_effects.gd）。札 1 枚は「名前　数」（状態なら残りのターン）で、兵に良いものと悪いものを色で分ける。
## 対戦中の兵の情報の札（info_card.gd）と、兵の詳細の窓（unit_detail.gd）が使う。
## 大きさは中身に依らず同じ（幅 × 行の数。docs/ui-theme.md の「枠の大きさ」）。効果が無ければ空のまま、入りきらなければ最後を「ほか N」にする。

const Text := preload("res://game/text.gd")
const UiTheme := preload("res://game/ui_theme.gd")
const Palette := preload("res://game/ui_palette.gd")
const Steady := preload("res://game/steady.gd")
const UnitEffects := preload("res://game/unit_effects.gd")

## 札の字の大きさ、札の高さ、札の間（px）。
const FONT := 12
const CHIP_HEIGHT := 20.0
const GAP := 3.0
## 良い効果・悪い効果の色。
const COLOR_GOOD := Palette.GOOD
const COLOR_BAD := Palette.DANGER
## 駒の特性の色。
const COLOR_TRAIT := Palette.ACCENT

var _width: float
var _max_rows: int
## 出している札の文（検査用。「ほか N」も 1 行）。
var _lines: Array[String] = []


func _init(width: float, max_rows: int, steady_name := "") -> void:
	_width = width
	_max_rows = max_rows
	custom_minimum_size = Vector2(width, CHIP_HEIGHT * max_rows + GAP * (max_rows - 1))
	add_theme_constant_override("separation", int(GAP))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if steady_name != "":
		Steady.mark(self, steady_name)


## 効果の並びを出す（UnitEffects.of の結果）。
func show_effects(effects: Array) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_lines.clear()
	var rows: Array[HBoxContainer] = []
	var placed := 0
	for effect: UnitEffects.Effect in effects:
		var chip := _chip(effect)
		if not _place(rows, chip):
			chip.free()
			break
		_lines.append(effect.line())
		placed += 1
	var left := effects.size() - placed
	if left > 0:
		# 入りきらなかったぶんを「ほか N」に。札が入らなければ、前の札を外して空ける。
		while true:
			var more := _more(left)
			if _place(rows, more):
				_lines.append(Text.t("battle.effect.more", {"count": left}))
				break
			more.free()
			var last := rows[rows.size() - 1]
			if last.get_child_count() == 0:
				break
			var removed := last.get_child(last.get_child_count() - 1)
			last.remove_child(removed)
			removed.free()
			_lines.remove_at(_lines.size() - 1)
			left += 1


## 出している札の文（検査用）。
func lines() -> Array[String]:
	return _lines


## 札を、いまの行に足す。入らなければ次の行へ。行が尽きたら偽（札は木に入れない）。
func _place(rows: Array[HBoxContainer], chip: Control) -> bool:
	if not rows.is_empty():
		var row := rows[rows.size() - 1]
		var room := _width - row.get_combined_minimum_size().x - (GAP if row.get_child_count() > 0 else 0.0)
		if chip.get_combined_minimum_size().x <= room:
			row.add_child(chip)
			return true
	if rows.size() >= _max_rows or chip.get_combined_minimum_size().x > _width:
		return false
	var fresh := HBoxContainer.new()
	fresh.add_theme_constant_override("separation", int(GAP))
	fresh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fresh.custom_minimum_size = Vector2(0.0, CHIP_HEIGHT)
	add_child(fresh)
	rows.append(fresh)
	fresh.add_child(chip)
	return true


func _chip(effect: UnitEffects.Effect) -> Control:
	var color := COLOR_TRAIT if effect.is_trait else (COLOR_GOOD if effect.good else COLOR_BAD)
	var plate := _plate(color)
	var row := plate.get_child(0) as HBoxContainer
	row.add_child(_label(effect.name, color, true))
	if effect.value != "":
		row.add_child(_label(effect.value, Palette.TEXT, false))
	if effect.turns >= 0:
		var turns := _label(Text.t("battle.hud.status_turns", {"turns": effect.turns}), Palette.TEXT_DIM, false)
		row.add_child(turns)
	return plate


func _more(count: int) -> Control:
	var plate := _plate(Palette.TEXT_DIM)
	(plate.get_child(0) as HBoxContainer).add_child(_label(Text.t("battle.effect.more", {"count": count}), Palette.TEXT_DIM, false))
	return plate


func _plate(color: Color) -> PanelContainer:
	var plate := PanelContainer.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.custom_minimum_size = Vector2(0.0, CHIP_HEIGHT)
	var box := UiTheme.box(Color(color, 0.12), Color(color, 0.7), 1, 9, 0.0)
	box.content_margin_left = 7.0
	box.content_margin_right = 7.0
	box.content_margin_top = 0.0
	box.content_margin_bottom = 1.0
	plate.add_theme_stylebox_override("panel", box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(row)
	return plate


func _label(words: String, color: Color, bold: bool) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", FONT)
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_override("font", UiTheme.FONT_BOLD if bold else UiTheme.FONT_BODY)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text = words
	return label
