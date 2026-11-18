extends Control
## 画面の中央の知らせの帯（番の切り替わり、必殺技、聖遺物）。画面の幅いっぱいに、真ん中が濃く、両端へ消える帯を描き、
## 上と下の縁に細い線を引く。文字は、上に重ねる Label（label）。絵は使わない。
##
## 出すとき（play）は、帯が上下に開き、文字が横から滑り込む。消えるまでの長さは、開く動きを足しても変えない（待ち時間を増やさない）。
## 強い知らせ（strong。必殺技）は、帯を高くし、縁の線を金にする。

const Palette := preload("res://game/ui_palette.gd")
const UiTheme := preload("res://game/ui_theme.gd")

## 帯の高さ（ふつう・強い知らせ）。
const HEIGHT := 84.0
const HEIGHT_STRONG := 108.0
## 帯の地の濃さ（真ん中）と、陣営の色を混ぜる割合。
const FILL_ALPHA := 0.82
const TINT := 0.38
## 開くまで・出ている間・消えるまでの秒数。
const OPEN_TIME := 0.16
const HOLD_TIME := 0.9
const FADE_TIME := 0.5
## 文字が滑り込む距離。
const SLIDE := 36.0

var label: Label
var _color := Color.WHITE
var _strong := false
## 帯の開き具合（0〜1）。
var _open := 1.0
var _tween: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", UiTheme.FONT_HEADING)
	label.add_theme_constant_override("outline_size", 10)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	resized.connect(_place_label)


## text を color（陣営や必殺技の色）の帯で出す。
func play(text: String, color: Color, strong := false) -> void:
	_color = color
	_strong = strong
	custom_minimum_size.y = HEIGHT_STRONG if strong else HEIGHT
	size.y = custom_minimum_size.y
	label.text = text
	label.add_theme_font_size_override("font_size", 46 if strong else 40)
	label.add_theme_color_override("font_color", Palette.ACCENT if strong else color.lightened(0.62))
	_place_label()
	modulate.a = 1.0
	visible = true
	if _tween != null:
		_tween.kill()
	_set_open(0.0)
	_tween = create_tween()
	_tween.tween_method(_set_open, 0.0, 1.0, OPEN_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(HOLD_TIME - OPEN_TIME)
	_tween.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	_tween.tween_callback(hide)


## すぐに消す。
func stop() -> void:
	if _tween != null:
		_tween.kill()
	visible = false


func _set_open(value: float) -> void:
	_open = value
	label.modulate.a = value
	label.position.x = (1.0 - value) * -SLIDE
	queue_redraw()


func _place_label() -> void:
	label.size = size
	label.position = Vector2((1.0 - _open) * -SLIDE, 0.0)


func _draw() -> void:
	var half := size.y / 2.0 * _open
	if half <= 0.5:
		return
	var middle := size.y / 2.0
	var fill := Color(Palette.INK.lerp(_color, TINT), FILL_ALPHA)
	var clear := Color(fill, 0.0)
	var line := Palette.ACCENT if _strong else _color.lightened(0.45)
	var line_clear := Color(line, 0.0)
	# 横に 4 つに分けて、両端へ消える。
	var stops: Array[float] = [0.0, 0.22, 0.78, 1.0]
	var fills: Array[Color] = [clear, fill, fill, clear]
	var lines: Array[Color] = [line_clear, line, line, line_clear]
	for i in 3:
		var left := size.x * stops[i]
		var right := size.x * stops[i + 1]
		draw_polygon(
			PackedVector2Array([Vector2(left, middle - half), Vector2(right, middle - half), Vector2(right, middle + half), Vector2(left, middle + half)]),
			PackedColorArray([fills[i], fills[i + 1], fills[i + 1], fills[i]]))
		for edge: float in [middle - half, middle + half - 2.0]:
			draw_polygon(
				PackedVector2Array([Vector2(left, edge), Vector2(right, edge), Vector2(right, edge + 2.0), Vector2(left, edge + 2.0)]),
				PackedColorArray([lines[i], lines[i + 1], lines[i + 1], lines[i]]))
		if _strong:
			# 強い知らせは、縁の内側にもう 1 本、細い線。
			for edge: float in [middle - half + 6.0, middle + half - 7.0]:
				draw_polygon(
					PackedVector2Array([Vector2(left, edge), Vector2(right, edge), Vector2(right, edge + 1.0), Vector2(left, edge + 1.0)]),
					PackedColorArray([Color(lines[i], lines[i].a * 0.6), Color(lines[i + 1], lines[i + 1].a * 0.6), Color(lines[i + 1], lines[i + 1].a * 0.6), Color(lines[i], lines[i].a * 0.6)]))
