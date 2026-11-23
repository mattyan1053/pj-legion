extends RefCounted
## 盤の上の小さな棒（駒の HP、盾の耐久）。いつもカメラを向き、木や岩に隠れない。
## 駒の見た目（unit_view.gd）と盤の見た目（board_view.gd）が同じ形で出す（読み方を変えないため）。

const Palette := preload("res://game/ui_palette.gd")

## 棒の大きさ（px）と、1 px の盤の上の大きさ。
const SIZE := Vector2i(34, 5)
const PIXEL := 0.016
## 棒の地の色。
const COLOR_BACK := Color(0.05, 0.05, 0.07, 0.9)


## 棒を作る（まだ何も描かない。fill で描く）。
static func make() -> Sprite3D:
	var bar := Sprite3D.new()
	bar.pixel_size = PIXEL
	bar.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bar.no_depth_test = true
	bar.shaded = false
	bar.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	bar.render_priority = 2
	return bar


## 棒を、残りの割合 ratio（0〜1）で描く。color を渡さなければ、残りで緑・黄・赤（HP の色）。
static func fill(bar: Sprite3D, ratio: float, color: Variant = null) -> void:
	var image := Image.create_empty(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill(COLOR_BACK)
	var inner := SIZE - Vector2i(2, 2)
	ratio = clampf(ratio, 0.0, 1.0)
	var filled := ceili(inner.x * ratio)
	if filled > 0:
		image.fill_rect(Rect2i(1, 1, filled, inner.y), color if color is Color else Palette.hp(ratio))
	bar.texture = ImageTexture.create_from_image(image)
	bar.set_meta(&"ratio", ratio)


## いま描いている残りの割合（描いていなければ -1）。検査用。
static func ratio_of(bar: Sprite3D) -> float:
	return bar.get_meta(&"ratio", -1.0)
