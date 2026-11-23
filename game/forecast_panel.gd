extends PanelContainer
## 戦闘予測のパネル。攻撃・回復・スキルの対象にマウスを乗せている間、対象のそばに出す（置き場所は呼ぶ側が決める）。
##
## 中身は ForecastText.summarize()（Forecast をそのまま読んだもの）。ここは並べて描くだけで、ルールも計算も持たない。
## 一目で分かることを上に置く: 見出し（何をするか）→ 目立つ知らせ（倒せる、自分も巻き込まれる、決着）→ 駒ごとの行
## （名前、HP の行（情報の枠と同じ部品で、棒に減り方・増え方を重ねる）、内訳）→ 駒に属さないこと（置かれる効果、盾、聖遺物、必殺技のゲージ）。

const Palette := preload("res://game/ui_palette.gd")
const Text := preload("res://game/text.gd")
const ForecastText := preload("res://game/forecast_text.gd")
const TextWrap := preload("res://game/text_wrap.gd")
const UiTheme := preload("res://game/ui_theme.gd")
const SheetParts := preload("res://game/sheet_parts.gd")
const InfoCard := preload("res://game/info_card.gd")
const StatMeter := preload("res://game/stat_meter.gd")

## 中身の幅（px）。盤を隠しすぎないよう、情報の枠（320）より狭くする。
const WIDTH := 250.0
const COLOR_BACK := Palette.SOLID
const COLOR_TITLE := Palette.ACCENT
const COLOR_DIM := Palette.TEXT_DIM
const COLOR_DEFEAT := Palette.DANGER
const COLOR_WARN := Palette.WARN
## 何かが起きる駒がこれより多いと、駒ごとに 1 行の詰めた形にする（樽の爆発は 8 体まで巻き込むので、パネルが画面の高さを超えないように）。
const COMPACT_FROM := 4
## 小さな札の字の大きさと、札の左右の余白の見積もり（px。これを足して幅に入らない文は、札にしない）。
const CHIP_FONT_SIZE := 13
const CHIP_PADDING := 20.0


var _column: VBoxContainer
var _team_colors: Array[Color] = []
var _measure: Callable
## 出している中身（検査用）。
var _shown_text := ""


func setup(team_colors: Array[Color], measure: Callable) -> void:
	_team_colors = team_colors
	_measure = measure
	# 板は UI のテーマの形。上の縁を太い金にして、予測（金の見出し）の札に見せる。
	var style := UiTheme.box(COLOR_BACK, COLOR_TITLE.darkened(0.3), 1, 6, 8.0, 5)
	style.border_width_top = 3
	add_theme_stylebox_override("panel", style)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_column = VBoxContainer.new()
	_column.custom_minimum_size = Vector2(WIDTH, 0.0)  # 幅は中身で変えない（「何も起きない」だけでも同じ幅）
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_theme_constant_override("separation", 2)
	add_child(_column)


## 予測を出す。title は何をするか（「攻撃: スナイパー」など）。summary が何も起きないなら、そう書く。
func show_summary(title: String, summary: ForecastText.Summary) -> void:
	for child in _column.get_children():
		_column.remove_child(child)
		child.queue_free()
	var texts: Array[String] = [title]
	_add_label(title, 16, COLOR_TITLE, true)
	_add_rule()
	# 目立つ知らせ（巻き込まれる、倒せる）は、色の札にして、ほかの行と見分ける。
	if summary.hurts_actor:
		_add_alert(Text.t("battle.forecast.self_hurt"), COLOR_WARN)
		texts.append(Text.t("battle.forecast.self_hurt"))
	if summary.defeats > 0:
		var text := Text.t("battle.forecast.defeats_one") if summary.defeats == 1 else Text.t("battle.forecast.defeats", {"count": summary.defeats})
		_add_alert(text, COLOR_DEFEAT)
		texts.append(text)
	var compact := summary.rows.size() >= COMPACT_FROM
	for row in summary.rows:
		var name := Text.t("battle.forecast.self_named", {"unit": row.name}) if row.is_actor else row.name
		if compact:
			texts.append(_add_compact_row(name, row))
			continue
		_add_label(name, 15, _side_color(row.side).lightened(0.4), true)
		texts.append(name)
		if row.damage >= 0 or row.healed > 0:
			# HP の行は、情報の枠と同じ部品（名前・あとの HP・増減・棒）。減るぶん・増えるぶんを棒に色で重ねる。文の段落にしない。
			var meter := StatMeter.new(true)
			meter.show_change(Text.t("deck.sheet.hp"), row.hp_before, row.hp_after, maxi(row.max_hp, 1), row.defeated)
			_column.add_child(meter)
			texts.append(" ".join(meter.texts()))
		# 内訳（クリティカル、森で軽減）と、ほかに起きること（付く状態など）は、小さな札にして並べる（情報の枠の札と同じ形）。
		var chips := _add_chips()
		for note in row.notes:
			_add_chip(chips, note, COLOR_DIM)
		if not row.notes.is_empty():
			texts.append(Text.join_dot(row.notes))
		for effect in row.effects:
			_add_chip(chips, effect, Palette.INFO)
			texts.append(effect)
	if not summary.lines.is_empty() and not summary.rows.is_empty():
		_add_rule()
	# 駒に属さないこと（経験、必殺技のゲージ、置かれる効果）も札に。決着は金の字。
	var line_chips := _add_chips()
	for line in summary.lines:
		_add_chip(line_chips, line, COLOR_TITLE if summary.decides and line == summary.lines[-1] else Palette.TEXT)
		texts.append(line)
	if summary.rows.is_empty() and summary.lines.is_empty():
		_add_label(Text.t("battle.forecast.nothing"), 15, COLOR_DIM)
		texts.append(Text.t("battle.forecast.nothing"))
	_shown_text = "\n".join(texts)
	visible = true
	reset_size()


## 詰めた形の 1 体ぶん: 「名前: N ダメージ → 倒れる（爆発）」を 1 行に（HP の棒は描かない）。ほかに起きることは、続けて 1 行に。
func _add_compact_row(name: String, row: ForecastText.Row) -> String:
	var line := name
	var hp := ForecastText.hp_text(row)
	if hp != "":
		line += ": " + hp
	if not row.notes.is_empty():
		line += Text.notes(row.notes)
	var color := _side_color(row.side).lightened(0.4)
	if row.defeated:
		color = COLOR_DEFEAT
	elif row.is_actor and row.damage > 0:
		color = COLOR_WARN
	_add_label(line, 14, color)
	if not row.effects.is_empty():
		var effects := Text.t("battle.log.detail", {"text": Text.join_comma(row.effects)})
		_add_label(effects, 13, COLOR_DIM)
		line += "\n" + effects
	return line


func hide_summary() -> void:
	visible = false
	_shown_text = ""


## 出している中身の文（出していなければ空）。検査用。
func shown_text() -> String:
	return _shown_text if visible else ""


## 札を並べる入れ物（幅に入らなければ次の行へ送る）。
func _add_chips() -> InfoCard.ChipRows:
	var chips := InfoCard.ChipRows.new(WIDTH)
	_column.add_child(chips)
	return chips


## 短い文は小さな札に、札の幅に入らない長い文は、折り返した行にする。
func _add_chip(chips: InfoCard.ChipRows, text: String, color: Color) -> void:
	var font := UiTheme.FONT_BODY
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, CHIP_FONT_SIZE).x + CHIP_PADDING > WIDTH:
		var label := _add_label(text, 14, color)
		_column.move_child(label, chips.get_index() + 1)
		return
	chips.add(SheetParts.tag(text, color, CHIP_FONT_SIZE))


## 区切りの細い線。
func _add_rule() -> void:
	var rule := HSeparator.new()
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(rule)


## 目立つ知らせの札（color の縁と薄い地、太字、真ん中寄せ）。
func _add_alert(text: String, color: Color) -> void:
	var label := _add_label(text, 16, color, true)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_stylebox_override("normal", UiTheme.alert_box(color))


func _add_label(text: String, font_size: int, color: Color, bold := false) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if bold:
		label.add_theme_font_override("font", UiTheme.FONT_BOLD)
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font := label.get_theme_font("font")
	label.text = TextWrap.fold(text, WIDTH, func(character: String) -> float: return _measure.call(font, font_size, character))
	_column.add_child(label)
	return label


func _side_color(side: Unit.Side) -> Color:
	return _team_colors[side] if side < _team_colors.size() else Color.WHITE
