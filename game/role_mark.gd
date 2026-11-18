extends Control
## 役割の印（前衛・後衛・奇襲・回復）。絵は使わず、ここで描く。色は付けず、形で見分ける
## （色は陣営・国・危険などの意味に取ってあるため。docs/ui-theme.md）。
## - 前衛: 盾。 - 後衛: 照準。 - 奇襲: 短剣。 - 回復: 十字。
## 暗い丸い札の上に、生成りの形。役割を持たない駒（将、魔物の一部）は何も描かない。

const Palette := preload("res://game/ui_palette.gd")

var role := UnitKind.Role.NONE:
	set(value):
		role = value
		queue_redraw()
## 丸い札を描くか（駒の額の隅に重ねるとき）。偽なら形だけ（文の横に並べるとき）。
var plate := true


func _init(role_ := UnitKind.Role.NONE, side := 18.0, plate_ := true) -> void:
	role = role_
	plate = plate_
	custom_minimum_size = Vector2(side, side)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if role == UnitKind.Role.NONE:
		return
	var s := minf(size.x, size.y)
	var center := size / 2.0
	if plate:
		draw_circle(center, s * 0.5, Palette.INK)
		draw_arc(center, s * 0.5 - 0.5, 0.0, TAU, 28, Palette.BORDER_BRIGHT, 1.0, true)
	var o := center - Vector2(s, s) / 2.0
	var ink := Palette.TEXT
	var line := maxf(1.4, s * 0.1)
	match role:
		UnitKind.Role.VANGUARD:
			draw_colored_polygon(_shape(o, s, [Vector2(0.28, 0.26), Vector2(0.72, 0.26), Vector2(0.72, 0.52), Vector2(0.5, 0.78), Vector2(0.28, 0.52)]), ink)
		UnitKind.Role.REARGUARD:
			draw_arc(center, s * 0.22, 0.0, TAU, 24, ink, line, true)
			for direction: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				draw_line(center + direction * s * 0.12, center + direction * s * 0.34, ink, line, true)
		UnitKind.Role.RAIDER:
			draw_colored_polygon(_shape(o, s, [Vector2(0.76, 0.22), Vector2(0.56, 0.6), Vector2(0.42, 0.46)]), ink)
			draw_line(o + Vector2(0.32, 0.44) * s, o + Vector2(0.58, 0.7) * s, ink, line, true)
			draw_line(o + Vector2(0.43, 0.59) * s, o + Vector2(0.27, 0.75) * s, ink, line * 1.2, true)
		UnitKind.Role.HEALER:
			var arm := s * 0.25
			var half := s * 0.085
			draw_rect(Rect2(center - Vector2(half, arm), Vector2(half * 2.0, arm * 2.0)), ink)
			draw_rect(Rect2(center - Vector2(arm, half), Vector2(arm * 2.0, half * 2.0)), ink)


func _shape(o: Vector2, s: float, points: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for p: Vector2 in points:
		result.append(o + p * s)
	return result
