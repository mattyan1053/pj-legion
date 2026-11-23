extends Control
## 縫い目の様子の札（Seam.Sign）の印。絵は使わず、ここで描く（docs/seam-signs.md、docs/ui-theme.md）。
## 暗い丸い札の上に、生成りの形。札ごとに形で見分ける（色は陣営・国・危険などの意味に取ってあるので、付けない）。
## - 天裂の名残り: 霞（3 本の波）　- 糸の満ち: 満ちる器　- 糸のゆるみ: たるんだ糸　- 骨の眠り: 閉じた目
## - 仮縫いのずれ: 入れ違う 2 本の矢　- 縫い代の風: 流れる 3 本の風　- 天裂の光: 裂け目から射す光　- 深い茂み: 木立　- 張りつめた糸: 張った糸と留め

const Palette := preload("res://game/ui_palette.gd")

## 描く札（Seam.Sign の値。-1 なら何も描かない）。
var sign := -1:
	set(value):
		sign = value
		queue_redraw()
## 丸い札を描くか。偽なら形だけ。
var plate := true


func _init(sign_ := -1, side := 28.0, plate_ := true) -> void:
	sign = sign_
	plate = plate_
	custom_minimum_size = Vector2(side, side)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if sign < 0:
		return
	var s := minf(size.x, size.y)
	var center := size / 2.0
	if plate:
		draw_circle(center, s * 0.5, Palette.INK)
		draw_arc(center, s * 0.5 - 0.5, 0.0, TAU, 32, Palette.BORDER_BRIGHT, 1.0, true)
	var o := center - Vector2(s, s) / 2.0
	var ink := Palette.TEXT
	var line := maxf(1.4, s * 0.08)
	var p := func(x: float, y: float) -> Vector2: return o + Vector2(x, y) * s
	match sign:
		Seam.Sign.HAZE:
			for row: float in [0.36, 0.5, 0.64]:
				draw_polyline(_wave(o, s, row, 0.24, 0.76, 0.05), ink, line, true)
		Seam.Sign.BRIM:
			draw_polyline(PackedVector2Array([p.call(0.3, 0.3), p.call(0.34, 0.74), p.call(0.66, 0.74), p.call(0.7, 0.3)]), ink, line, true)
			draw_colored_polygon(PackedVector2Array([p.call(0.33, 0.5), p.call(0.67, 0.5), p.call(0.655, 0.72), p.call(0.345, 0.72)]), ink)
		Seam.Sign.LOOSE:
			var sag := PackedVector2Array()
			for i in 13:
				var t := i / 12.0
				sag.append(p.call(0.22 + 0.56 * t, 0.36 + 0.3 * sin(t * PI)))
			draw_polyline(sag, ink, line, true)
			draw_circle(p.call(0.22, 0.36), s * 0.05, ink)
			draw_circle(p.call(0.78, 0.36), s * 0.05, ink)
		Seam.Sign.HUSH:
			var lid := PackedVector2Array()
			for i in 13:
				var t := i / 12.0
				lid.append(p.call(0.24 + 0.52 * t, 0.46 + 0.14 * sin(t * PI)))
			draw_polyline(lid, ink, line, true)
			for x: float in [0.34, 0.5, 0.66]:
				draw_line(p.call(x, 0.53 + (0.06 if x == 0.5 else 0.03)), p.call(x + (x - 0.5) * 0.3, 0.68), ink, line * 0.8, true)
		Seam.Sign.SHIFT:
			draw_line(p.call(0.26, 0.34), p.call(0.72, 0.66), ink, line, true)
			draw_line(p.call(0.26, 0.66), p.call(0.72, 0.34), ink, line, true)
			_head(p.call(0.74, 0.67), Vector2(1.0, 0.7).normalized(), s * 0.13, ink)
			_head(p.call(0.74, 0.33), Vector2(1.0, -0.7).normalized(), s * 0.13, ink)
		Seam.Sign.GALE:
			for row: Array in [[0.34, 0.22, 0.7], [0.5, 0.3, 0.78], [0.66, 0.22, 0.62]]:
				var y: float = row[0]
				draw_line(p.call(row[1], y), p.call(row[2], y), ink, line, true)
				draw_arc(p.call(row[2], y - 0.06), s * 0.06, -PI / 2.0, PI / 2.0, 8, ink, line, true)
		Seam.Sign.GLEAM:
			draw_line(p.call(0.5, 0.2), p.call(0.5, 0.44), ink, line * 1.4, true)
			for i in 5:
				var angle := PI * (0.15 + 0.175 * i)
				var from: Vector2 = p.call(0.5, 0.48) + Vector2(cos(angle), sin(angle)) * s * 0.06
				draw_line(from, from + Vector2(cos(angle), sin(angle)) * s * 0.22, ink, line, true)
		Seam.Sign.THICKET:
			for x: float in [0.35, 0.65]:
				draw_colored_polygon(PackedVector2Array([p.call(x, 0.24), p.call(x + 0.15, 0.62), p.call(x - 0.15, 0.62)]), ink)
				draw_line(p.call(x, 0.6), p.call(x, 0.76), ink, line, true)
		Seam.Sign.TAUT:
			draw_line(p.call(0.22, 0.5), p.call(0.78, 0.5), ink, line, true)
			for x: float in [0.22, 0.78]:
				draw_line(p.call(x, 0.36), p.call(x, 0.64), ink, line * 1.3, true)


## 横の波（row の高さ、x0 から x1 まで、振れ幅 amp。どれも札の大きさに対する割合）。
static func _wave(o: Vector2, s: float, row: float, x0: float, x1: float, amp: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 17:
		var t := i / 16.0
		points.append(o + Vector2(x0 + (x1 - x0) * t, row + amp * sin(t * TAU * 1.5)) * s)
	return points


## 矢じり（tip の先、向き dir、大きさ size）。
func _head(tip: Vector2, dir: Vector2, length: float, ink: Color) -> void:
	var side := dir.orthogonal()
	draw_colored_polygon(PackedVector2Array([tip, tip - dir * length + side * length * 0.55, tip - dir * length - side * length * 0.55]), ink)
