extends Control
## 国の紋。絵は使わず、ここで描く（世界は docs/story.md の「世界と登場人物」）。形と色は軍の見た目の表（game/army_look.gd）から読む（軍なしは、表の最初の軍の紋と色）。
## - gear（機械の国ベルク連邦）: 歯車と、その中の山形（階級章）。色は琥珀。
## - crystal（魔法の国リュエル騎士領）: 結晶の菱形と、その中の四つの光の星。色は菫。
## 物語のカードの地紋（薄く大きく）や、見出しの脇に置く。色と濃さは渡せる（既定は国の色）。

const ArmyLook := preload("res://game/army_look.gd")
const Palette := preload("res://game/ui_palette.gd")

var army := UnitKind.Army.NONE
## 描く色（透明なら、国の色）。
var tint := Color(0, 0, 0, 0)


func _init(army_ := UnitKind.Army.NONE, size_ := 64.0, tint_ := Color(0, 0, 0, 0)) -> void:
	army = army_
	tint = tint_
	custom_minimum_size = Vector2.ONE * size_
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## 国の色（軍ごと。軍の見た目の表）。
static func color_of(army_: UnitKind.Army) -> Color:
	return ArmyLook.color(army_)


func _draw() -> void:
	var color := tint if tint.a > 0.0 else color_of(army)
	var center := size / 2.0
	var radius := minf(size.x, size.y) / 2.0
	match ArmyLook.crest(army):
		&"crystal":
			_draw_crystal(center, radius, color)
		_:
			_draw_gear(center, radius, color)


## 歯車（8 枚の歯の輪）と、中の山形 2 本。
func _draw_gear(center: Vector2, radius: float, color: Color) -> void:
	var teeth := 8
	var outer := PackedVector2Array()
	for i in teeth:
		var base := TAU * i / teeth
		# 歯 1 枚: 谷 → 歯の立ち上がり → 歯の先 → 歯の下り。
		for step: Array in [[-0.5, 0.74], [-0.28, 0.74], [-0.2, 1.0], [0.2, 1.0], [0.28, 0.74]]:
			outer.append(center + Vector2.UP.rotated(base + float(step[0]) * TAU / teeth) * radius * float(step[1]))
	outer.append(outer[0])
	var width := maxf(1.5, radius * 0.09)
	draw_polyline(outer, color, width, true)
	draw_arc(center, radius * 0.52, 0.0, TAU, 40, color, width, true)
	for lift: float in [0.16, -0.12]:
		var chevron := PackedVector2Array([
			center + Vector2(-radius * 0.3, radius * (lift + 0.12)), center + Vector2(0.0, radius * (lift - 0.14)),
			center + Vector2(radius * 0.3, radius * (lift + 0.12))])
		draw_polyline(chevron, color, width, true)


## 結晶の菱形（外と内の 2 重）と、中の四つの光の星。
func _draw_crystal(center: Vector2, radius: float, color: Color) -> void:
	var width := maxf(1.5, radius * 0.09)
	for scale_: float in [1.0, 0.8]:
		var diamond := PackedVector2Array([
			center + Vector2(0.0, -radius * scale_), center + Vector2(radius * 0.72 * scale_, 0.0),
			center + Vector2(0.0, radius * scale_), center + Vector2(-radius * 0.72 * scale_, 0.0), center + Vector2(0.0, -radius * scale_)])
		draw_polyline(diamond, color if scale_ == 1.0 else Color(color, color.a * 0.6), width if scale_ == 1.0 else width * 0.6, true)
	var star := PackedVector2Array()
	for i in 8:
		var reach := radius * (0.5 if i % 2 == 0 else 0.13)
		star.append(center + Vector2.UP.rotated(TAU * i / 8.0) * reach)
	draw_colored_polygon(star, color)
