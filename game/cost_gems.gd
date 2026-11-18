extends Control
## コストの宝石。コストの 1 を、菱形の宝石 1 個で見せる（絵は使わず、ここで描く）。
## - 並び（slots = 0）: count 個の金の宝石を、右詰めで並べる（駒 1 体・持ち物 1 個のコスト）。
## - 目盛り（slots > 0）: 上限 slots 個ぶんの溝を並べ、count 個を金で埋める（部隊のコスト / コスト上限）。
##   5 個ごとに少し空けて、数えやすくする。count が上限を超えたら、全部を危険の色にする。
## 大きさは中身で変わらない（溝の数と幅だけで決まる）。

const Palette := preload("res://game/ui_palette.gd")

## 5 個ごとの切れ目の幅（宝石の間隔に足す。px）。
const GROUP := 5
const GROUP_GAP := 4.0

var count := 0:
	set(value):
		count = value
		queue_redraw()
var slots := 0:
	set(value):
		slots = value
		queue_redraw()
## 宝石 1 個の幅（px）。目盛りは、幅に収まらなければ詰める。
var gem := 9.0


func _init(count_ := 0, slots_ := 0, gem_ := 9.0, width := 0.0) -> void:
	count = count_
	slots = slots_
	gem = gem_
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var natural := _span(maxi(count_, slots_), gem_ + 2.0)
	custom_minimum_size = Vector2(width if width > 0.0 else natural, gem_ * 1.5)


## n 個を pitch の間隔で並べたときの幅。
static func _span(n: int, pitch: float) -> float:
	if n <= 0:
		return 0.0
	return n * pitch + float((n - 1) / GROUP) * GROUP_GAP


func _draw() -> void:
	var total := maxi(count, slots)
	if total <= 0:
		return
	var pitch := gem + 2.0
	var groups := float((total - 1) / GROUP)
	if _span(total, pitch) > size.x:
		pitch = maxf(3.0, (size.x - groups * GROUP_GAP) / total)
	var half := Vector2(minf(gem, pitch - 1.0) * 0.5, gem * 0.7)
	var over := slots > 0 and count > slots
	var lit := Palette.DANGER if over else Palette.ACCENT
	var body := Palette.DANGER_FILL.lightened(0.2) if over else Palette.GOLD
	# 並びは右詰め、目盛りは左詰め。
	var start := 0.0 if slots > 0 else size.x - _span(total, pitch)
	for i in total:
		var at := Vector2(start + i * pitch + float(i / GROUP) * GROUP_GAP + pitch * 0.5, size.y * 0.5)
		var diamond := PackedVector2Array([at + Vector2(0.0, -half.y), at + Vector2(half.x, 0.0), at + Vector2(0.0, half.y), at + Vector2(-half.x, 0.0)])
		if i < count:
			draw_colored_polygon(diamond, body)
			# 上の左の面だけ明るくして、石の切り口に見せる。
			draw_colored_polygon(PackedVector2Array([at + Vector2(0.0, -half.y), at, at + Vector2(-half.x, 0.0)]), lit)
		else:
			draw_colored_polygon(diamond, Palette.INK)
			draw_polyline(diamond + PackedVector2Array([diamond[0]]), Color(Palette.BORDER, 0.9), 1.0, true)
