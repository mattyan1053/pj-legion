extends Control
## 片側へ細く薄くなる線。見出しの左右に置いて、見出しを真ん中に立てる（決着の画面の「戦績」「MVP」）。絵は使わず、ここで描く。
## toward_right が真なら、左が濃く、右へ消える。

const Palette := preload("res://game/ui_palette.gd")

var color := Palette.BORDER_BRIGHT:
	set(value):
		color = value
		queue_redraw()
var toward_right := true


func _init(toward_right_ := true, color_ := Palette.BORDER_BRIGHT, width := 40.0) -> void:
	toward_right = toward_right_
	color = color_
	custom_minimum_size = Vector2(width, 8.0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var y := size.y / 2.0
	var thick := Vector2(0.0 if toward_right else size.x, y)
	var thin := Vector2(size.x if toward_right else 0.0, y)
	draw_polygon(
		PackedVector2Array([thick + Vector2(0.0, -1.0), thin + Vector2(0.0, -0.4), thin + Vector2(0.0, 0.4), thick + Vector2(0.0, 1.0)]),
		PackedColorArray([color, Color(color, 0.0), Color(color, 0.0), color]))
	# 濃い側の端に、小さな菱形。
	var gem := 3.0
	var at := thick + Vector2(gem if toward_right else -gem, 0.0)
	draw_colored_polygon(PackedVector2Array([at + Vector2(0.0, -gem), at + Vector2(gem, 0.0), at + Vector2(0.0, gem), at + Vector2(-gem, 0.0)]), color)
