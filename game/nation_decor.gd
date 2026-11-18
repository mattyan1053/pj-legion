extends Control
## 板の、軍（国）の飾り: 上の縁に国の色の帯（真ん中が濃く、両端へ薄く）と、その下の淡い光、右下に薄く大きな国の紋（crest.gd）。
## 板（PanelContainer）やカード（Button）の**最初の子**にする。入れ物が中身の枠（余白の内側）に置いても、親の板いっぱいに描く。
## 入れ物の並びの大きさには関わらない（最小の大きさは 0。入力は通す）。
## 軍なし（UnitKind.Army.NONE）は、枠の真鍮で帯だけを描く。

const Palette := preload("res://game/ui_palette.gd")
const Crest := preload("res://game/crest.gd")

const BAND := 4.0
## 板の縁の内側へ寄せる幅（板の縁の線を塗りつぶさない）。
const INSET := 2.0

var army := UnitKind.Army.NONE:
	set(value):
		if army == value and _crest != null:
			return
		army = value
		_make_crest()
		queue_redraw()
## 帯の下の光の届く深さ（px。0 で出さない）。
var glow := 90.0
## 紋の大きさ（px。0 で出さない）と濃さ。
var crest_size := 0.0
var crest_alpha := 0.09
## 帯の色（透明なら、軍の国の色）。軍なしの板に、陣営の色の帯を付けるときに渡す。
var band_color := Color(0, 0, 0, 0):
	set(value):
		band_color = value
		queue_redraw()
var _crest: Crest


func _init(army_ := UnitKind.Army.NONE, crest_size_ := 0.0, glow_ := 90.0) -> void:
	crest_size = crest_size_
	glow = glow_
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	army = army_
	resized.connect(_place_crest)
	item_rect_changed.connect(_place_crest)


static func color_of(army_: UnitKind.Army) -> Color:
	return Palette.BORDER_BRIGHT if army_ == UnitKind.Army.NONE else Crest.color_of(army_)


## 親の板の四角（この部品の座標で）。
func _board() -> Rect2:
	var parent := get_parent() as Control
	return Rect2(-position, parent.size) if parent != null else Rect2(Vector2.ZERO, size)


func _make_crest() -> void:
	if _crest != null:
		remove_child(_crest)
		_crest.queue_free()
		_crest = null
	if crest_size <= 0.0 or army == UnitKind.Army.NONE:
		return
	_crest = Crest.new(army, crest_size, Color(Crest.color_of(army), crest_alpha))
	add_child(_crest)
	_place_crest()


func _place_crest() -> void:
	queue_redraw()
	if _crest == null:
		return
	var board := _board()
	_crest.size = Vector2.ONE * crest_size
	_crest.position = board.end - Vector2.ONE * (crest_size + 14.0)


func _draw() -> void:
	var board := _board()
	var color := band_color if band_color.a > 0.0 else color_of(army)
	var left := board.position.x + INSET
	var right := board.end.x - INSET
	var top := board.position.y + INSET
	var middle := (left + right) / 2.0
	for part: Array in [[left + 8.0, middle, 0.2, 1.0], [middle, right - 8.0, 1.0, 0.2]]:
		draw_polygon(
			PackedVector2Array([Vector2(part[0], top), Vector2(part[1], top), Vector2(part[1], top + BAND), Vector2(part[0], top + BAND)]),
			PackedColorArray([Color(color, part[2]), Color(color, part[3]), Color(color, part[3]), Color(color, part[2])]))
	if glow > 0.0:
		draw_polygon(
			PackedVector2Array([Vector2(left, top + BAND), Vector2(right, top + BAND), Vector2(right, top + BAND + glow), Vector2(left, top + BAND + glow)]),
			PackedColorArray([Color(color, 0.11), Color(color, 0.11), Color(color, 0.0), Color(color, 0.0)]))
