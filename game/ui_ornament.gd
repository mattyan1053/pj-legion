extends Control
## 飾りの線。真ん中に菱形、左右へ細くなる線、両端に小さな菱形（題字の下、見出しの下に置く）。絵は使わず、ここで描く。
## 色は渡されたもの（既定は目立たせる枠の真鍮）。grow（0〜1）で、真ん中から左右へ伸びる（入ったときの動きに使う）。

const Palette := preload("res://game/ui_palette.gd")

var color := Palette.BORDER_BRIGHT:
	set(value):
		color = value
		queue_redraw()
var grow := 1.0:
	set(value):
		grow = value
		queue_redraw()


func _init(width := 320.0, height := 16.0) -> void:
	custom_minimum_size = Vector2(width, height)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var center := size / 2.0
	var half := size.x / 2.0 * grow
	var gem := minf(size.y / 2.0, 6.0)
	if half <= gem * 2.0:
		return
	for direction: float in [-1.0, 1.0]:
		var from := center + Vector2(direction * gem * 1.9, 0.0)
		var to := center + Vector2(direction * (half - gem), 0.0)
		# 真ん中から端へ、細く薄くなる線。
		draw_polygon(
			PackedVector2Array([from + Vector2(0.0, -1.0), to + Vector2(0.0, -0.4), to + Vector2(0.0, 0.4), from + Vector2(0.0, 1.0)]),
			PackedColorArray([color, Color(color, 0.25), Color(color, 0.25), color]))
		_gem(center + Vector2(direction * (half - gem * 0.5), 0.0), gem * 0.45, Color(color, 0.7))
	_gem(center, gem, color)
	_gem(center, gem * 0.45, Palette.INK)


func _gem(at: Vector2, radius: float, fill: Color) -> void:
	draw_colored_polygon(PackedVector2Array([at + Vector2(0.0, -radius), at + Vector2(radius, 0.0), at + Vector2(0.0, radius), at + Vector2(-radius, 0.0)]), fill)
