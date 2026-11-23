extends Control
## 勝利条件（GameWonEvent.Reason）の印。絵は使わず、ここで描く（docs/win-conditions.md の「画面」、docs/ui-theme.md）。
## 対戦の始めの「対戦ルール」の札、出撃準備の勝ち方の欄、上の帯の勝ち方の札の 3 か所で同じ印を使い、同じものだと分かるようにする。
## 縫い目の様子の印（sign_mark.gd）と同じ形: 暗い丸い札の上に、金の形（勝ち方は金、縫い目の様子は生成り）。
## - 将の撃破: 冠　- 本陣の占拠: 旗の立つ塔　- 拠点の確保: 輪と旗竿　- 守り切る: 砂時計
## - 全滅させる: 交わる 2 本の剣　- 中ボスの撃破: 角のある兜

const Palette := preload("res://game/ui_palette.gd")

## 描く勝ち方（GameWonEvent.Reason の値。-1 なら何も描かない）。
var reason := -1:
	set(value):
		reason = value
		queue_redraw()
## 丸い札を描くか。偽なら形だけ（上の帯の小さな札）。
var plate := true


func _init(reason_ := -1, side := 28.0, plate_ := true) -> void:
	reason = reason_
	plate = plate_
	custom_minimum_size = Vector2(side, side)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if reason < 0:
		return
	var s := minf(size.x, size.y)
	var center := size / 2.0
	if plate:
		draw_circle(center, s * 0.5, Palette.INK)
		draw_arc(center, s * 0.5 - 0.5, 0.0, TAU, 32, Palette.BORDER_BRIGHT, 1.0, true)
	var o := center - Vector2(s, s) / 2.0
	var ink := Palette.GOLD
	var line := maxf(1.4, s * 0.08)
	var p := func(x: float, y: float) -> Vector2: return o + Vector2(x, y) * s
	var poly := func(points: Array) -> PackedVector2Array:
		var out := PackedVector2Array()
		for point: Array in points:
			out.append(p.call(point[0], point[1]))
		return out
	match reason:
		GameWonEvent.Reason.KING_DEFEATED:
			draw_colored_polygon(poly.call([[0.24, 0.68], [0.24, 0.36], [0.37, 0.5], [0.5, 0.3], [0.63, 0.5], [0.76, 0.36], [0.76, 0.68]]), ink)
			draw_line(p.call(0.24, 0.74), p.call(0.76, 0.74), ink, line, true)
		GameWonEvent.Reason.HQ_CAPTURED:
			draw_colored_polygon(poly.call([[0.3, 0.78], [0.3, 0.46], [0.36, 0.46], [0.36, 0.52], [0.43, 0.52], [0.43, 0.46], [0.5, 0.46],
				[0.5, 0.78]]), ink)
			draw_line(p.call(0.58, 0.78), p.call(0.58, 0.2), ink, line * 0.8, true)
			draw_colored_polygon(poly.call([[0.58, 0.2], [0.8, 0.28], [0.58, 0.36]]), ink)
		GameWonEvent.Reason.STRONGHOLD_HELD:
			draw_arc(p.call(0.46, 0.66), s * 0.2, 0.0, TAU, 24, ink, line, true)
			draw_line(p.call(0.62, 0.66), p.call(0.62, 0.2), ink, line * 0.8, true)
			draw_colored_polygon(poly.call([[0.62, 0.2], [0.82, 0.27], [0.62, 0.34]]), ink)
		GameWonEvent.Reason.TURNS_HELD:
			draw_line(p.call(0.3, 0.24), p.call(0.7, 0.24), ink, line, true)
			draw_line(p.call(0.3, 0.76), p.call(0.7, 0.76), ink, line, true)
			draw_colored_polygon(poly.call([[0.35, 0.28], [0.65, 0.28], [0.5, 0.5]]), ink)
			draw_polyline(poly.call([[0.5, 0.5], [0.35, 0.72], [0.65, 0.72], [0.5, 0.5]]), ink, line * 0.7, true)
		GameWonEvent.Reason.ROUTED:
			draw_line(p.call(0.26, 0.26), p.call(0.72, 0.72), ink, line, true)
			draw_line(p.call(0.74, 0.26), p.call(0.28, 0.72), ink, line, true)
			draw_line(p.call(0.2, 0.66), p.call(0.34, 0.8), ink, line * 1.3, true)
			draw_line(p.call(0.8, 0.66), p.call(0.66, 0.8), ink, line * 1.3, true)
		GameWonEvent.Reason.BOSS_SLAIN:
			draw_colored_polygon(poly.call([[0.3, 0.74], [0.3, 0.48], [0.36, 0.38], [0.5, 0.34], [0.64, 0.38], [0.7, 0.48], [0.7, 0.74],
				[0.56, 0.74], [0.56, 0.58], [0.44, 0.58], [0.44, 0.74]]), ink)
			draw_polyline(poly.call([[0.34, 0.42], [0.24, 0.32], [0.24, 0.2]]), ink, line, true)
			draw_polyline(poly.call([[0.66, 0.42], [0.76, 0.32], [0.76, 0.2]]), ink, line, true)
