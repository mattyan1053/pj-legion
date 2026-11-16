extends Control
## 聖遺物のアイコン（上の帯の陣営の欄）。素材は使わず、コードで描く単純な形。
## 持っていない聖遺物は、暗い輪郭だけ（どこで点くかが分かる）。手に入れると、聖遺物の色で点く（点いた瞬間に少し大きく弾む）。
##
## - 英知（最大 HP）: 菱形の宝石（水色）。
## - 勇気（攻撃力）: 上を向いた剣（橙）。

const Names := preload("res://game/names.gd")

const SIZE := 22.0
const COLORS := {
	Relics.Id.WISDOM: Color("7fe0ff"),
	Relics.Id.COURAGE: Color("ffa04a"),
}
const COLOR_OFF := Color(1.0, 1.0, 1.0, 0.28)
const COLOR_EDGE := Color(0.05, 0.06, 0.08, 0.9)

var relic: Relics.Id = Relics.Id.WISDOM
## 点いているか（その陣営が持っているか）。
var lit := false


func _init(which: Relics.Id = Relics.Id.WISDOM) -> void:
	relic = which
	custom_minimum_size = Vector2(SIZE, SIZE)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_PASS
	pivot_offset = Vector2(SIZE, SIZE) / 2.0
	_update_tooltip()


## 点ける・消す。点いた瞬間だけ、少し大きく弾ませる。
func set_lit(on: bool) -> void:
	if on == lit:
		return
	lit = on
	_update_tooltip()
	queue_redraw()
	if on and is_inside_tree():
		scale = Vector2.ONE * 1.7
		create_tween().tween_property(self, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _update_tooltip() -> void:
	tooltip_text = "%s（%s）: %s" % [Names.relic(relic), "持っている" if lit else "持っていない", Names.relic_summary(relic)]


func _draw() -> void:
	var color: Color = COLORS[relic] if lit else COLOR_OFF
	var points := _shape()
	if lit:
		draw_colored_polygon(points, color)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, COLOR_EDGE if lit else color, 1.5 if lit else 1.2, true)


## 形（このアイコンの四角の中の点の列）。
func _shape() -> PackedVector2Array:
	var s := SIZE
	match relic:
		Relics.Id.COURAGE:
			# 上を向いた剣: 刃、鍔、柄。
			return PackedVector2Array([
				Vector2(s * 0.5, s * 0.02), Vector2(s * 0.66, s * 0.18), Vector2(s * 0.66, s * 0.6),
				Vector2(s * 0.82, s * 0.6), Vector2(s * 0.82, s * 0.7), Vector2(s * 0.57, s * 0.7),
				Vector2(s * 0.57, s * 0.96), Vector2(s * 0.43, s * 0.96), Vector2(s * 0.43, s * 0.7),
				Vector2(s * 0.18, s * 0.7), Vector2(s * 0.18, s * 0.6), Vector2(s * 0.34, s * 0.6),
				Vector2(s * 0.34, s * 0.18),
			])
	# 菱形の宝石（上が平たい）。
	return PackedVector2Array([
		Vector2(s * 0.28, s * 0.12), Vector2(s * 0.72, s * 0.12), Vector2(s * 0.96, s * 0.4),
		Vector2(s * 0.5, s * 0.94), Vector2(s * 0.04, s * 0.4),
	])
