extends Control
## 持ち物（装備）の印。素材は使わず、コードで描く単純な形（relic_icon.gd と同じやり方）。
##
## - アイアンシールド: 鉄色の盾（上が平らで、下がとがる）。
## - スピードブーツ: 横を向いた靴と、後ろへ流れる 2 本の線。

const COLORS := {
	Equipment.Id.IRON_SHIELD: Color("b8c2cc"),
	Equipment.Id.SPEED_BOOTS: Color("6fc4ff"),
}
const COLOR_EDGE := Color(0.05, 0.06, 0.08, 0.9)

var item: Equipment.Id = Equipment.Id.IRON_SHIELD


func _init(which: Equipment.Id = Equipment.Id.IRON_SHIELD, side := 24.0) -> void:
	item = which
	custom_minimum_size = Vector2(side, side)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_meta(&"item", which)


func _draw() -> void:
	var s := minf(size.x, size.y)
	var o := (size - Vector2(s, s)) / 2.0
	var color: Color = COLORS.get(item, Color.WHITE)
	var points := PackedVector2Array()
	match item:
		Equipment.Id.IRON_SHIELD:
			for p: Vector2 in [Vector2(0.18, 0.12), Vector2(0.82, 0.12), Vector2(0.82, 0.5), Vector2(0.5, 0.9), Vector2(0.18, 0.5)]:
				points.append(o + p * s)
			draw_colored_polygon(points, color)
			draw_polyline(points + PackedVector2Array([points[0]]), COLOR_EDGE, maxf(1.0, s * 0.06))
			draw_line(o + Vector2(0.5, 0.2) * s, o + Vector2(0.5, 0.78) * s, color.darkened(0.35), maxf(1.0, s * 0.07))
		Equipment.Id.SPEED_BOOTS:
			for p: Vector2 in [
				Vector2(0.42, 0.12), Vector2(0.66, 0.12), Vector2(0.66, 0.58), Vector2(0.9, 0.7),
				Vector2(0.9, 0.86), Vector2(0.42, 0.86),
			]:
				points.append(o + p * s)
			draw_colored_polygon(points, color)
			draw_polyline(points + PackedVector2Array([points[0]]), COLOR_EDGE, maxf(1.0, s * 0.06))
			for y: float in [0.4, 0.62]:
				draw_line(o + Vector2(0.08, y) * s, o + Vector2(0.32, y) * s, color, maxf(1.0, s * 0.07))
