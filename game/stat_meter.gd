extends HBoxContainer
## 能力値 1 つの行（駒の詳細の窓。unit_detail.gd）: 名前、いまの値（太字）、持ち物などでの増減（色と矢印）、目盛り。
## 目盛りは、HP と攻撃が目盛り線つきの棒、移動と射程が菱形の粒。素の値のぶんは金、増えたぶんは良い知らせの色、
## 減ったぶんは危険の色の抜き。HP の棒は、枠の長さが最大 HP（小さい駒でも読めるよう、下駄を履かせる）、塗りがいまの HP。
## いまの HP の割合の色で埋める（減っているぶんは沈める）。
## 大きさは中身で変わらない（名前・値・増減の欄は幅を決めてある）。

const Text := preload("res://game/text.gd")
const Palette := preload("res://game/ui_palette.gd")
const UiTheme := preload("res://game/ui_theme.gd")

const NAME_WIDTH := 48.0
const VALUE_WIDTH := 96.0
const DELTA_WIDTH := 64.0
const ROW_HEIGHT := 26.0

var _name: Label
var _value: Label
var _delta: Label
var _meter: Meter


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 8)
	custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	_name = _label(14, Palette.TEXT_DIM, false, NAME_WIDTH)
	_value = _label(19, Palette.TEXT, true, VALUE_WIDTH)
	_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_delta = _label(14, Palette.GOOD, true, DELTA_WIDTH)
	_meter = Meter.new()
	_meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(_meter)


func _label(font_size: int, color: Color, bold: bool, width: float) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if bold:
		label.add_theme_font_override("font", UiTheme.FONT_BOLD)
	label.custom_minimum_size = Vector2(width, 0.0)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(label)
	return label


## 名前 stat_name、いまの値 value、素の値 plain、目盛りの端 scale。pips なら粒、でなければ棒。
## hp は HP の行だけ（いまの HP。-1 なら HP の行でない）。
func show_stat(stat_name: String, value: int, plain: int, scale: int, pips: bool, hp := -1) -> void:
	_name.text = stat_name
	_value.text = str(value) if hp < 0 else Text.t("deck.sheet.hp_value", {"hp": hp, "max": value})
	var delta := value - plain
	_delta.text = "" if delta == 0 else Text.t("deck.sheet.gain" if delta > 0 else "deck.sheet.loss", {"amount": absi(delta)})
	_delta.add_theme_color_override("font_color", Palette.GOOD if delta > 0 else Palette.DANGER)
	_value.add_theme_color_override("font_color", Palette.TEXT if delta == 0 else (Palette.GOOD if delta > 0 else Palette.DANGER).lightened(0.35))
	_meter.value = value
	_meter.plain = plain
	_meter.scale_max = maxi(scale, 1)
	_meter.pips = pips
	_meter.hp = hp
	_meter.queue_redraw()


## 出している文（検査用。名前、値、増減）。
func texts() -> Array[String]:
	return [_name.text, _value.text, _delta.text]


## 目盛り（棒か粒）。
class Meter:
	extends Control

	const Palette := preload("res://game/ui_palette.gd")

	## 棒の目盛り線の間隔（端の値がこれより大きいほど、粗くする）。
	const TICKS := [[30, 5], [60, 10], [100000, 20]]

	## HP の棒の枠の長さの下駄（最大 HP がどれだけ小さくても、棒の欄のこの割合はある。残りを最大 HP の大小で伸ばす）。
	## 枠が短いと、HP が減った駒の塗りが数 px になって、割合が読めない。
	const HP_FRAME_FLOOR := 0.45

	var value := 0
	var plain := 0
	var scale_max := 1
	var pips := false
	var hp := -1

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(120.0, 14.0)

	func _draw() -> void:
		if pips:
			_draw_pips()
		else:
			_draw_bar()

	## HP の棒の枠の長さ（棒の欄の幅に対する割合）: 最大 HP が目盛りの端なら 1、小さくても HP_FRAME_FLOOR はある。
	static func hp_frame_ratio(max_hp: int, scale: int) -> float:
		return lerpf(HP_FRAME_FLOOR, 1.0, clampf(float(max_hp) / float(maxi(scale, 1)), 0.0, 1.0))

	func _draw_bar() -> void:
		var groove := Rect2(Vector2.ZERO, size)
		var unit := (size.x - 4.0) / float(scale_max)
		if hp >= 0:
			# HP の枠は最大 HP の長さ（満タンの駒の棒が、欠けて見えないように）。その先は、目盛りの端までの淡い跡だけ。
			# 枠の中は、その駒の最大 HP が端（塗りの割合が、いまの HP の割合）。
			draw_rect(groove, Color(Palette.INK, 0.35))
			var top := maxi(maxi(value, plain), 1)
			unit = (size.x - 4.0) * hp_frame_ratio(top, scale_max) / float(top)
			groove.size.x = unit * top + 4.0
		draw_rect(groove, Palette.INK)
		var inner := groove.grow(-2.0)
		var kept := mini(value, plain)
		var base := Palette.GOLD
		if hp >= 0:
			# HP: いまの HP を割合の色で、減っているぶんを沈んだ赤で。
			base = Palette.hp(float(hp) / maxf(value, 1.0))
			draw_rect(Rect2(inner.position, Vector2(unit * value, inner.size.y)), Color(Palette.DANGER_FILL, 0.55))
			draw_rect(Rect2(inner.position, Vector2(unit * mini(hp, value), inner.size.y)), base.darkened(0.12))
			if value > plain and hp > plain:
				# 持ち物で増えたぶんは、明るい帯で見せる。
				draw_rect(Rect2(inner.position + Vector2(unit * plain, 0.0), Vector2(unit * (mini(hp, value) - plain), inner.size.y)), Palette.GOOD)
		else:
			draw_rect(Rect2(inner.position, Vector2(unit * kept, inner.size.y)), base)
			if value > plain:
				draw_rect(Rect2(inner.position + Vector2(unit * plain, 0.0), Vector2(unit * (value - plain), inner.size.y)), Palette.GOOD)
		if value < plain:
			var lost := Rect2(inner.position + Vector2(unit * value, 0.0), Vector2(unit * (plain - value), inner.size.y))
			draw_rect(lost, Color(Palette.DANGER, 0.22))
			draw_rect(lost.grow(-0.5), Palette.DANGER, false, 1.0)
		# 上の縁の淡い光（棒に厚みを見せる）。
		draw_rect(Rect2(inner.position, Vector2(unit * maxi(value, plain), inner.size.y * 0.35)), Color(1.0, 1.0, 1.0, 0.14))
		var step := 5
		for pair: Array in TICKS:
			if (maxi(value, plain) if hp >= 0 else scale_max) <= pair[0]:
				step = pair[1]
				break
		var at := step
		while at < (maxi(value, plain) if hp >= 0 else scale_max):
			var x := inner.position.x + unit * at
			draw_line(Vector2(x, inner.position.y), Vector2(x, inner.end.y), Color(Palette.INK, 0.75), 1.0)
			at += step
		draw_rect(groove.grow(-0.5), Palette.BORDER, false, 1.0)

	func _draw_pips() -> void:
		var pitch := minf(size.x / float(scale_max), 20.0)
		var half := Vector2(minf(pitch * 0.5 - 2.0, 6.5), size.y * 0.5)
		for i in scale_max:
			var at := Vector2(pitch * (i + 0.5), size.y * 0.5)
			var diamond := PackedVector2Array([at + Vector2(0.0, -half.y), at + Vector2(half.x, 0.0), at + Vector2(0.0, half.y), at + Vector2(-half.x, 0.0)])
			var outline := diamond + PackedVector2Array([diamond[0]])
			if i < mini(value, plain):
				draw_colored_polygon(diamond, Palette.GOLD)
				draw_colored_polygon(PackedVector2Array([diamond[0], at, diamond[3]]), Palette.ACCENT)
			elif i < value:
				draw_colored_polygon(diamond, Palette.GOOD.darkened(0.2))
				draw_colored_polygon(PackedVector2Array([diamond[0], at, diamond[3]]), Palette.GOOD)
			elif i < plain:
				draw_colored_polygon(diamond, Color(Palette.DANGER, 0.18))
				draw_polyline(outline, Palette.DANGER, 1.0, true)
			else:
				draw_colored_polygon(diamond, Palette.INK)
				draw_polyline(outline, Color(Palette.BORDER, 0.8), 1.0, true)
