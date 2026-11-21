extends Control
## スキル・必殺技・進化先の札の頭に置く印（絵は使わず、ここで描く。役割の印 role_mark.gd と同じやり方）。
## 暗い丸い札に、種類ごとの形。色は役割で決める: スキルは生成り、必殺技は金、進化は良い知らせの色。
## - スキル: 四つ角の星。 - 必殺技: 八方へ伸びる光。 - 進化: 上向きの山形 2 つ。 - 特性: 小さな菱形。

const Palette := preload("res://game/ui_palette.gd")

enum Type { SKILL, ULT, EVOLUTION, TRAIT }

var type := Type.SKILL:
	set(value):
		type = value
		queue_redraw()
## 沈める（スキルを持たない駒の札など）。
var dim := false:
	set(value):
		dim = value
		queue_redraw()


func _init(type_ := Type.SKILL, side := 28.0) -> void:
	type = type_
	custom_minimum_size = Vector2(side, side)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func ink() -> Color:
	if dim:
		return Palette.TEXT_OFF
	match type:
		Type.ULT:
			return Palette.ACCENT
		Type.EVOLUTION:
			return Palette.GOOD
	return Palette.TEXT


func _draw() -> void:
	var s := minf(size.x, size.y)
	var center := size / 2.0
	var color := ink()
	draw_circle(center, s * 0.5, Palette.INK)
	draw_arc(center, s * 0.5 - 0.75, 0.0, TAU, 32, Color(color, 0.7) if type == Type.ULT and not dim else Palette.BORDER_BRIGHT if not dim else Palette.BORDER, 1.5, true)
	match type:
		Type.SKILL:
			draw_colored_polygon(_star(center, s * 0.36, s * 0.1, 4, -PI / 2.0), color)
		Type.ULT:
			draw_colored_polygon(_star(center, s * 0.4, s * 0.15, 8, -PI / 2.0), color)
			draw_circle(center, s * 0.09, Palette.INK)
		Type.EVOLUTION:
			var line := maxf(1.6, s * 0.1)
			for lift: float in [-0.12, 0.12]:
				var mid := center + Vector2(0.0, s * lift)
				draw_polyline(PackedVector2Array([mid + Vector2(-s * 0.2, s * 0.08), mid + Vector2(0.0, -s * 0.12), mid + Vector2(s * 0.2, s * 0.08)]), color, line, true)
		Type.TRAIT:
			draw_colored_polygon(_star(center, s * 0.24, s * 0.17, 2, -PI / 2.0), color)


## points 個の角を持つ星（外の半径 outer、内の半径 inner）。
func _star(center: Vector2, outer: float, inner: float, points: int, turn: float) -> PackedVector2Array:
	var shape := PackedVector2Array()
	for i in points * 2:
		var radius := outer if i % 2 == 0 else inner
		shape.append(center + Vector2.from_angle(turn + PI * i / points) * radius)
	return shape
