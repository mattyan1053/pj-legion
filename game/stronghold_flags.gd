extends Control
## 拠点ごとの持ち主の旗の並び（上の帯の下の、拠点の札の中。docs/battle-view.md の「画面に出るもの」）。絵は使わず、ここで描く。
## 拠点 1 つにつき小さな旗 1 本: 確保を進めている陣営の色（盤の上の拠点の旗と同じ）、だれも進めていなければ白い縁だけ。
## 幅は決まっている（WIDTH）。旗が ROOM 本より多いと、間を詰めて同じ幅に収める（拠点の数で札の大きさを変えない）。

const Palette := preload("res://game/ui_palette.gd")

## 旗 1 本の大きさ（px）と、欄の幅（px）、間を詰めずに並ぶ本数。
const FLAG := Vector2(12.0, 16.0)
const ROOM := 3
const GAP := 5.0
const WIDTH := FLAG.x * ROOM + GAP * (ROOM - 1)
## だれのものでもない拠点の旗の色。
const COLOR_FREE := Color("f4f1e6")

## 拠点ごとの持ち主（プレイヤー番号。だれも確保を進めていなければ -1）。
var owners: Array[int] = []:
	set(value):
		owners = value
		queue_redraw()
## 陣営の色（添字がプレイヤー番号）と、色を白へ寄せる割合（急ぎの赤い地の上で沈まないように）。
var team_colors: Array = []
var lighten := 0.3:
	set(value):
		lighten = value
		queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(WIDTH, FLAG.y)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## 旗 index の左上（欄の中）。本数が ROOM までなら左から GAP おき、多ければ欄の幅に均して詰める。
func flag_position(index: int) -> Vector2:
	var count := owners.size()
	var step := FLAG.x + GAP
	if count > ROOM:
		step = (WIDTH - FLAG.x) / float(count - 1)
	return Vector2(step * index, (size.y - FLAG.y) / 2.0)


func _draw() -> void:
	for index in owners.size():
		var at := flag_position(index)
		var owner_side := owners[index]
		var owned := owner_side >= 0 and owner_side < team_colors.size()
		var color: Color = (team_colors[owner_side] as Color).lightened(lighten) if owned else COLOR_FREE
		# 竿と、右へなびく三角の旗。持ち主がいれば塗り、いなければ縁だけ。
		draw_line(at + Vector2(1.0, 0.0), at + Vector2(1.0, FLAG.y), Color(COLOR_FREE, 0.9), 1.5)
		var cloth := PackedVector2Array([at + Vector2(2.0, 1.0), at + Vector2(FLAG.x, 5.0), at + Vector2(2.0, 9.0)])
		if owned:
			draw_colored_polygon(cloth, color)
			draw_polyline(PackedVector2Array([cloth[0], cloth[1], cloth[2]]), Palette.INK, 1.0, true)
		else:
			draw_polyline(PackedVector2Array([cloth[0], cloth[1], cloth[2]]), Color(COLOR_FREE, 0.75), 1.2, true)
