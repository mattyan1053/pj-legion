extends Control
## 盤の縮図の額。縮図を出している TextureRect の子にすると、出ている絵の四角（縦横比のまま真ん中に収めたもの）の周りに、
## 真鍮の縁と四隅の明るい鉤を描く（ミニマップ・対戦設定の帯の縮図と同じ向き）。絵は使わず、ここで描く。

const Palette := preload("res://game/ui_palette.gd")

## 四隅の鉤の長さ（px）。
const CORNER := 9.0
## 絵から縁までの間（px）。
const GAP := 2.0


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	resized.connect(queue_redraw)


## 親の TextureRect が出している絵の四角（この部品の座標で）。絵が無ければ、部品の全体。
func picture_rect() -> Rect2:
	var holder := get_parent() as TextureRect
	if holder == null or holder.texture == null:
		return Rect2(Vector2.ZERO, size)
	var picture := Vector2(holder.texture.get_size())
	var drawn := picture * minf(size.x / picture.x, size.y / picture.y)
	return Rect2((size - drawn) / 2.0, drawn)


func _draw() -> void:
	var outer := picture_rect().grow(GAP)
	draw_rect(outer, Palette.BORDER, false, 2.0)
	var reach := minf(CORNER, minf(outer.size.x, outer.size.y) / 3.0)
	for corner: Vector2 in [Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(0.0, 1.0), Vector2(1.0, 1.0)]:
		var at := outer.position + corner * outer.size
		var inward := Vector2(1.0, 1.0) - corner * 2.0
		draw_line(at, at + Vector2(inward.x * reach, 0.0), Palette.BORDER_BRIGHT, 2.0)
		draw_line(at, at + Vector2(0.0, inward.y * reach), Palette.BORDER_BRIGHT, 2.0)
