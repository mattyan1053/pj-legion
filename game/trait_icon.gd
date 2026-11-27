extends Control
## 軍略の印（docs/troop-traits.md）。絵は使わず、ここで描く小さな図。効き方が一目で分かる形にする。
## 丸は兵、四角は敵、矢印は攻撃。味方は生成り、効く所は軍略の軍の色、敵は暗い赤。
## - 集中砲火: 2 本の矢が 1 つの敵に集まる
## - 隊列: 同じ形の兵が 2 体並び、上に盾の線
## - 補給線: 十字（回復役）の隣の兵に、上向きの矢
## - 仇討ち: 倒れた兵（×）から、敵へ太い矢
## - 誓い: 糸で結んだ 2 人が、同じ敵へ矢
## - 守護: 大きな兵（パラディン）の隣の兵に、敵の矢が盾で止まる

const Palette := preload("res://game/ui_palette.gd")

var trait_id := Traits.NONE:
	set(value):
		trait_id = value
		queue_redraw()
## 描かずに薄く見せるか（選んでいない札）。
var dim := false:
	set(value):
		dim = value
		queue_redraw()


func _init(id := Traits.NONE, side := 40.0) -> void:
	trait_id = id
	custom_minimum_size = Vector2(side, side)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if trait_id == Traits.NONE:
		return
	var s := minf(size.x, size.y)
	var o := (size - Vector2(s, s)) / 2.0
	draw_circle(size / 2.0, s * 0.5, Palette.INK)
	draw_arc(size / 2.0, s * 0.5 - 0.5, 0.0, TAU, 32, Palette.BORDER, 1.0, true)
	var army := Traits.army_of(trait_id)
	var key := Palette.NATION_MILITARY if army == UnitKind.Army.MILITARY else Palette.NATION_FANTASY
	var ally := Palette.TEXT
	var foe := Palette.TEAM_RED.darkened(0.1)
	if dim:
		key = key.darkened(0.45)
		ally = Palette.TEXT_OFF
		foe = foe.darkened(0.45)
	var line := maxf(1.4, s * 0.06)
	var p := func(x: float, y: float) -> Vector2: return o + Vector2(x, y) * s
	match trait_id:
		Traits.Id.FOCUS:
			_foe(p.call(0.7, 0.5), s, foe)
			_ally(p.call(0.24, 0.28), s, ally)
			_ally(p.call(0.24, 0.72), s, ally)
			_arrow(p.call(0.32, 0.32), p.call(0.6, 0.46), key, line)
			_arrow(p.call(0.32, 0.68), p.call(0.6, 0.54), key, line)
		Traits.Id.RANKS:
			_ally(p.call(0.36, 0.6), s, ally)
			_ally(p.call(0.64, 0.6), s, ally)
			draw_line(p.call(0.22, 0.36), p.call(0.78, 0.36), key, line * 1.6, true)
			draw_line(p.call(0.22, 0.36), p.call(0.22, 0.44), key, line * 1.2, true)
			draw_line(p.call(0.78, 0.36), p.call(0.78, 0.44), key, line * 1.2, true)
		Traits.Id.SUPPLY:
			var c: Vector2 = p.call(0.33, 0.6)
			var arm := s * 0.13
			var half := s * 0.045
			draw_rect(Rect2(c - Vector2(half, arm), Vector2(half * 2.0, arm * 2.0)), key)
			draw_rect(Rect2(c - Vector2(arm, half), Vector2(arm * 2.0, half * 2.0)), key)
			_ally(p.call(0.66, 0.6), s, ally)
			_arrow(p.call(0.66, 0.42), p.call(0.66, 0.16), key, line)
		Traits.Id.VENGEANCE:
			var x: Vector2 = p.call(0.24, 0.5)
			var r := s * 0.09
			draw_line(x - Vector2(r, r), x + Vector2(r, r), Palette.TEXT_OFF, line, true)
			draw_line(x - Vector2(r, -r), x + Vector2(r, -r), Palette.TEXT_OFF, line, true)
			_foe(p.call(0.72, 0.5), s, foe)
			_arrow(p.call(0.36, 0.5), p.call(0.6, 0.5), key, line * 1.6)
		Traits.Id.OATH:
			_ally(p.call(0.24, 0.3), s, ally)
			_ally(p.call(0.24, 0.7), s, ally)
			draw_line(p.call(0.24, 0.38), p.call(0.24, 0.62), key, line * 1.2, true)
			_foe(p.call(0.72, 0.5), s, foe)
			_arrow(p.call(0.33, 0.33), p.call(0.6, 0.46), ally, line)
			_arrow(p.call(0.33, 0.67), p.call(0.6, 0.54), key, line * 1.6)
		Traits.Id.GUARD:
			draw_circle(p.call(0.24, 0.36), s * 0.11, ally)
			_ally(p.call(0.24, 0.66), s, ally)
			draw_line(p.call(0.42, 0.44), p.call(0.42, 0.84), key, line * 1.8, true)
			_foe(p.call(0.8, 0.64), s, foe)
			_arrow(p.call(0.7, 0.64), p.call(0.5, 0.64), foe, line)


func _ally(at: Vector2, s: float, color: Color) -> void:
	draw_circle(at, s * 0.075, color)


func _foe(at: Vector2, s: float, color: Color) -> void:
	var half := s * 0.09
	draw_rect(Rect2(at - Vector2(half, half), Vector2(half, half) * 2.0), color)


func _arrow(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	var direction := (to - from).normalized()
	var side := Vector2(-direction.y, direction.x)
	var head := width * 2.4
	draw_line(from, to - direction * head * 0.6, color, width, true)
	draw_colored_polygon(PackedVector2Array([to, to - direction * head + side * head * 0.6, to - direction * head - side * head * 0.6]), color)
