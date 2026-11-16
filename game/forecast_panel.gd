extends PanelContainer
## 戦闘予測のパネル。攻撃・回復・スキルの対象にマウスを乗せている間、対象のそばに出す（置き場所は呼ぶ側が決める）。
##
## 中身は ForecastText.summarize()（Forecast をそのまま読んだもの）。ここは並べて描くだけで、ルールも計算も持たない。
## 一目で分かることを上に置く: 見出し（何をするか）→ 目立つ知らせ（倒せる、自分も巻き込まれる、決着）→ 駒ごとの行
## （名前、HP の棒の減り方・増え方、数、内訳）→ 駒に属さないこと（置かれる効果、盾、聖遺物、必殺技のゲージ）。

const Palette := preload("res://game/ui_palette.gd")
const ForecastText := preload("res://game/forecast_text.gd")
const TextWrap := preload("res://game/text_wrap.gd")

## 中身の幅（px）。盤を隠しすぎないよう、情報の枠（320）より狭くする。
const WIDTH := 250.0
const COLOR_BACK := Palette.SOLID
const COLOR_TITLE := Palette.ACCENT
const COLOR_DIM := Palette.TEXT_DIM
const COLOR_DEFEAT := Palette.DANGER
const COLOR_WARN := Palette.WARN
const COLOR_HEAL := Palette.GOOD
const COLOR_LOSS := Palette.HP_LOW
const COLOR_BAR_BACK := Palette.INK
## 何かが起きる駒がこれより多いと、駒ごとに 1 行の詰めた形にする（樽の爆発は 8 体まで巻き込むので、パネルが画面の高さを超えないように）。
const COMPACT_FROM := 4


## HP の棒。前の HP と後の HP を並べて描く（減るぶんは赤、増えるぶんは緑、残りは HP の色）。
class HpChange:
	extends Control
	var before := 0
	var after := 0
	var max_hp := 1

	func _init() -> void:
		custom_minimum_size = Vector2(0.0, 9.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var full := size.x
		var height := size.y
		draw_rect(Rect2(0.0, 0.0, full, height), COLOR_BAR_BACK)
		var top := maxi(before, after)
		var low := mini(before, after)
		var ratio := float(after) / maxf(float(max_hp), 1.0)
		var color := Palette.hp(ratio)
		draw_rect(Rect2(0.0, 0.0, full * low / maxf(max_hp, 1.0), height), color)
		if top > low:
			var change := COLOR_HEAL if after > before else COLOR_LOSS.lightened(0.15)
			var from := full * low / maxf(max_hp, 1.0)
			draw_rect(Rect2(from, 0.0, full * (top - low) / maxf(max_hp, 1.0), height), change)


var _column: VBoxContainer
var _team_colors: Array[Color] = []
var _measure: Callable
## 出している中身（検査用）。
var _shown_text := ""


func setup(team_colors: Array[Color], measure: Callable) -> void:
	_team_colors = team_colors
	_measure = measure
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_BACK
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8.0)
	style.border_color = COLOR_TITLE.darkened(0.3)
	style.set_border_width_all(1)
	add_theme_stylebox_override("panel", style)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_column = VBoxContainer.new()
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_theme_constant_override("separation", 2)
	add_child(_column)


## 予測を出す。title は何をするか（「攻撃: スナイパー」など）。summary が何も起きないなら、そう書く。
func show_summary(title: String, summary: ForecastText.Summary) -> void:
	for child in _column.get_children():
		_column.remove_child(child)
		child.queue_free()
	var texts: Array[String] = [title]
	_add_label(title, 16, COLOR_TITLE)
	if summary.hurts_actor:
		_add_label("自分も巻き込まれる！", 16, COLOR_WARN)
		texts.append("自分も巻き込まれる！")
	if summary.defeats > 0:
		var text := "倒せる！" if summary.defeats == 1 else "%d 体を倒せる！" % summary.defeats
		_add_label(text, 16, COLOR_DEFEAT)
		texts.append(text)
	var compact := summary.rows.size() >= COMPACT_FROM
	for row in summary.rows:
		var name := ("自分（%s）" % row.name) if row.is_actor else row.name
		if compact:
			texts.append(_add_compact_row(name, row))
			continue
		_add_label(name, 15, _side_color(row.side).lightened(0.4))
		texts.append(name)
		var hp := ForecastText.hp_text(row)
		if hp != "":
			var bar := HpChange.new()
			bar.before = row.hp_before
			bar.after = row.hp_after
			bar.max_hp = maxi(row.max_hp, 1)
			_column.add_child(bar)
			var color := Color.WHITE
			if row.defeated:
				color = COLOR_DEFEAT
			elif row.healed > 0:
				color = COLOR_HEAL
			elif row.blocked:
				color = COLOR_DIM
			_add_label(hp, 17, color)
			texts.append(hp)
		if not row.notes.is_empty():
			var notes := "・".join(row.notes)
			_add_label(notes, 14, COLOR_DIM)
			texts.append(notes)
		for effect in row.effects:
			_add_label(effect, 14, COLOR_DIM)
			texts.append(effect)
	for line in summary.lines:
		_add_label(line, 15, COLOR_TITLE if summary.decides and line == summary.lines[-1] else Palette.TEXT)
		texts.append(line)
	if summary.rows.is_empty() and summary.lines.is_empty():
		_add_label("何も起きない", 15, COLOR_DIM)
		texts.append("何も起きない")
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
		line += "（%s）" % "・".join(row.notes)
	var color := _side_color(row.side).lightened(0.4)
	if row.defeated:
		color = COLOR_DEFEAT
	elif row.is_actor and row.damage > 0:
		color = COLOR_WARN
	_add_label(line, 14, color)
	if not row.effects.is_empty():
		var effects := "　" + "、".join(row.effects)
		_add_label(effects, 13, COLOR_DIM)
		line += "\n" + effects
	return line


func hide_summary() -> void:
	visible = false
	_shown_text = ""


## 出している中身の文（出していなければ空）。検査用。
func shown_text() -> String:
	return _shown_text if visible else ""


func _add_label(text: String, font_size: int, color: Color) -> void:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font := label.get_theme_font("font")
	label.text = TextWrap.fold(text, WIDTH, func(character: String) -> float: return _measure.call(font, font_size, character))
	_column.add_child(label)


func _side_color(side: Unit.Side) -> Color:
	return _team_colors[side] if side < _team_colors.size() else Color.WHITE
