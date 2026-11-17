extends Control
## 持ち物（装備）の印。素材は使わず、コードで描く単純な形（relic_icon.gd と同じやり方）。
## 小さく（18 px）並べても見分けられるよう、持ち物ごとに形と色の両方を変える。
##
## - アイアンシールド: 鉄色の盾（上が平らで、下がとがる）。
## - スピードブーツ: 横を向いた靴と、後ろへ流れる 2 本の線。
## - 力の籠手: 赤銅色の握りこぶし（指の節の線）。
## - 遠眼鏡: 斜めの真鍮の筒と、先のレンズ。
## - 再生の護符: 緑の丸に白い十字。
## - 獣道の地図: 生成りの紙に、点線の道。
## - 隠れ蓑: 紫の頭巾つきの外套。
## - 軍旗: 竿と赤い旗。
## - 試作ジェットパック（ストーリー専用）: 灰色の 2 本の筒と、下へ吹く炎。
## - 古竜の鱗（ストーリー専用）: 碧の鱗（丸い盾形を 2 枚重ねる）。

const COLORS := {
	Equipment.Id.IRON_SHIELD: Color("b8c2cc"),
	Equipment.Id.SPEED_BOOTS: Color("6fc4ff"),
	Equipment.Id.POWER_GAUNTLET: Color("e0884a"),
	Equipment.Id.LONG_SCOPE: Color("d9b45a"),
	Equipment.Id.REGEN_CHARM: Color("5fcf7f"),
	Equipment.Id.TRAIL_MAP: Color("d8c79a"),
	Equipment.Id.SHADOW_CLOAK: Color("9a86e0"),
	Equipment.Id.WAR_BANNER: Color("e05a5a"),
	Equipment.Id.JET_PACK: Color("a9b8c8"),
	Equipment.Id.DRAGON_SCALE: Color("3fbfa8"),
}
const COLOR_EDGE := Color(0.05, 0.06, 0.08, 0.9)
const COLOR_MARK := Color(0.97, 0.97, 0.95)
const COLOR_FLAME := Color("ffb347")

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
	var edge := maxf(1.0, s * 0.06)
	var line := maxf(1.0, s * 0.07)
	match item:
		Equipment.Id.IRON_SHIELD:
			_fill(_shape(o, s, [Vector2(0.18, 0.12), Vector2(0.82, 0.12), Vector2(0.82, 0.5), Vector2(0.5, 0.9), Vector2(0.18, 0.5)]), color, edge)
			draw_line(o + Vector2(0.5, 0.2) * s, o + Vector2(0.5, 0.78) * s, color.darkened(0.35), line)
		Equipment.Id.SPEED_BOOTS:
			_fill(_shape(o, s, [
				Vector2(0.42, 0.12), Vector2(0.66, 0.12), Vector2(0.66, 0.58), Vector2(0.9, 0.7),
				Vector2(0.9, 0.86), Vector2(0.42, 0.86),
			]), color, edge)
			for y: float in [0.4, 0.62]:
				draw_line(o + Vector2(0.08, y) * s, o + Vector2(0.32, y) * s, color, line)
		Equipment.Id.POWER_GAUNTLET:
			_fill(_shape(o, s, [
				Vector2(0.2, 0.3), Vector2(0.8, 0.3), Vector2(0.86, 0.42), Vector2(0.86, 0.62), Vector2(0.7, 0.72),
				Vector2(0.68, 0.9), Vector2(0.32, 0.9), Vector2(0.3, 0.72), Vector2(0.14, 0.6), Vector2(0.14, 0.42),
			]), color, edge)
			for x: float in [0.35, 0.5, 0.65]:
				draw_line(o + Vector2(x, 0.31) * s, o + Vector2(x, 0.5) * s, color.darkened(0.4), line)
		Equipment.Id.LONG_SCOPE:
			_fill(_shape(o, s, [Vector2(0.1, 0.72), Vector2(0.62, 0.2), Vector2(0.8, 0.38), Vector2(0.28, 0.9)]), color, edge)
			draw_circle(o + Vector2(0.74, 0.26) * s, s * 0.16, color.lightened(0.3))
			draw_arc(o + Vector2(0.74, 0.26) * s, s * 0.16, 0.0, TAU, 20, COLOR_EDGE, edge)
		Equipment.Id.REGEN_CHARM:
			draw_circle(o + Vector2(0.5, 0.5) * s, s * 0.38, color)
			draw_arc(o + Vector2(0.5, 0.5) * s, s * 0.38, 0.0, TAU, 24, COLOR_EDGE, edge)
			draw_line(o + Vector2(0.5, 0.3) * s, o + Vector2(0.5, 0.7) * s, COLOR_MARK, maxf(1.5, s * 0.12))
			draw_line(o + Vector2(0.3, 0.5) * s, o + Vector2(0.7, 0.5) * s, COLOR_MARK, maxf(1.5, s * 0.12))
		Equipment.Id.TRAIL_MAP:
			_fill(_shape(o, s, [Vector2(0.12, 0.18), Vector2(0.88, 0.12), Vector2(0.88, 0.82), Vector2(0.12, 0.88)]), color, edge)
			var path: Array[Vector2] = [Vector2(0.22, 0.76), Vector2(0.4, 0.58), Vector2(0.56, 0.62), Vector2(0.78, 0.3)]
			for i in path.size() - 1:
				draw_dashed_line(o + path[i] * s, o + path[i + 1] * s, color.darkened(0.6), line, maxf(2.0, s * 0.1))
		Equipment.Id.SHADOW_CLOAK:
			_fill(_shape(o, s, [
				Vector2(0.5, 0.08), Vector2(0.7, 0.24), Vector2(0.88, 0.9), Vector2(0.12, 0.9), Vector2(0.3, 0.24),
			]), color, edge)
			draw_circle(o + Vector2(0.5, 0.32) * s, s * 0.11, color.darkened(0.6))
		Equipment.Id.WAR_BANNER:
			draw_line(o + Vector2(0.24, 0.08) * s, o + Vector2(0.24, 0.94) * s, COLOR_EDGE, maxf(1.5, s * 0.1))
			_fill(_shape(o, s, [Vector2(0.28, 0.12), Vector2(0.88, 0.2), Vector2(0.72, 0.36), Vector2(0.88, 0.52), Vector2(0.28, 0.56)]), color, edge)
		Equipment.Id.JET_PACK:
			for x: float in [0.2, 0.54]:
				_fill(_shape(o, s, [Vector2(x, 0.12), Vector2(x + 0.26, 0.12), Vector2(x + 0.26, 0.64), Vector2(x, 0.64)]), color, edge)
				_fill(_shape(o, s, [Vector2(x + 0.03, 0.66), Vector2(x + 0.23, 0.66), Vector2(x + 0.13, 0.94)]), COLOR_FLAME, edge * 0.5)
		Equipment.Id.DRAGON_SCALE:
			for shift: Vector2 in [Vector2(-0.1, -0.08), Vector2(0.1, 0.08)]:
				var points: Array[Vector2] = []
				for p: Vector2 in [Vector2(0.5, 0.86), Vector2(0.24, 0.56), Vector2(0.28, 0.28), Vector2(0.5, 0.16), Vector2(0.72, 0.28), Vector2(0.76, 0.56)]:
					points.append(p * 0.8 + Vector2(0.1, 0.1) + shift)
				_fill(_shape(o, s, points), color if shift.x > 0.0 else color.darkened(0.3), edge)


func _shape(o: Vector2, s: float, points: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for p: Vector2 in points:
		result.append(o + p * s)
	return result


func _fill(points: PackedVector2Array, color: Color, edge: float) -> void:
	draw_colored_polygon(points, color)
	draw_polyline(points + PackedVector2Array([points[0]]), COLOR_EDGE, edge)
