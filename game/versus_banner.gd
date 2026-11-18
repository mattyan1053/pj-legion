extends Control
## 対戦の組み合わせの帯（対戦設定のパネルの頭）。どの軍とどの軍が、どのマップで戦うかを、ひと目で見せる。
## 左に 1 人目（先手の行）、右に 2 人目（後手の行）: 国の紋（crest.gd）、だれか（「あなた・先手（青）」など）、軍の名前（国の色、明朝）。
## 真ん中に、マップの縮図（map_card.gd の絵。真鍮の縁と四隅の鉤）。地は、左右の端から真ん中へ消える陣営の色。
## 手番がランダムの間は、陣営が決まっていないので、地に色を付けない。絵は使わず、ここで描く。大きさは中身で変わらない。

const Palette := preload("res://game/ui_palette.gd")
const UiTheme := preload("res://game/ui_theme.gd")
const Crest := preload("res://game/crest.gd")

const HEIGHT := 96.0
const CREST_SIZE := 60.0
## 縮図を収める四角（px）。盤の縦横比のまま、この中に収める。
const MAP_BOX := Vector2(132.0, 84.0)
const FRAME_CORNER := 10.0

var _tints: Array[Color] = [Color(0, 0, 0, 0), Color(0, 0, 0, 0)]
var _crests: Array[Crest] = []
var _who: Array[Label] = []
var _army: Array[Label] = []
var _map: Texture2D


func _init() -> void:
	custom_minimum_size = Vector2(0.0, HEIGHT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # 縮図のマスの粒を、ぼかさない
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 18.0
	row.offset_right = -18.0
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	for side in 2:
		var crest := Crest.new(UnitKind.Army.MILITARY, CREST_SIZE)
		crest.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var names := VBoxContainer.new()
		names.alignment = BoxContainer.ALIGNMENT_CENTER
		names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		names.add_theme_constant_override("separation", 0)
		names.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var who := Label.new()
		who.add_theme_font_size_override("font_size", 16)
		who.add_theme_font_override("font", UiTheme.FONT_BOLD)
		var army := Label.new()
		army.add_theme_font_size_override("font_size", 26)
		army.add_theme_font_override("font", UiTheme.FONT_HEADING)
		for label: Label in [who, army]:
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if side == 0 else HORIZONTAL_ALIGNMENT_RIGHT
			label.clip_text = true
			label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			names.add_child(label)
		# 左は「紋・名前」、右は「名前・紋」（真ん中の縮図をはさんで向き合う）。
		if side == 0:
			row.add_child(crest)
			row.add_child(names)
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(MAP_BOX.x, 0.0)
			gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(gap)
		else:
			row.add_child(names)
			row.add_child(crest)
		_crests.append(crest)
		_who.append(who)
		_army.append(army)


## side（0 = 左、1 = 右）の中身: だれか who、軍 army、軍の名前 army_name、地の色 tint（透明なら色を付けない）。
func show_side(side: int, who: String, army: UnitKind.Army, army_name: String, tint: Color) -> void:
	_who[side].text = who
	_who[side].add_theme_color_override("font_color", Palette.TEXT if tint.a <= 0.0 else Palette.team_text(tint))
	_army[side].text = army_name
	_army[side].add_theme_color_override("font_color", Crest.color_of(army).lightened(0.25))
	_crests[side].army = army
	_crests[side].queue_redraw()
	_tints[side] = tint
	queue_redraw()


## 真ん中の縮図の絵。
func show_map(texture: Texture2D) -> void:
	_map = texture
	queue_redraw()


## 出している文（[左のだれか, 左の軍, 右のだれか, 右の軍]。検査用）。
func texts() -> Array[String]:
	return [_who[0].text, _army[0].text, _who[1].text, _army[1].text]


func has_map() -> bool:
	return _map != null


## 縮図を描く四角（この部品の座標で）。
func map_rect() -> Rect2:
	if _map == null:
		return Rect2(size / 2.0, Vector2.ZERO)
	var image := Vector2(_map.get_size())
	var scale_ := minf(MAP_BOX.x / image.x, MAP_BOX.y / image.y)
	var drawn := image * scale_
	return Rect2((size - drawn) / 2.0, drawn)


func _draw() -> void:
	var middle := size.x / 2.0
	# 地: 左右の端から真ん中へ消える陣営の色（決まっていなければ、枠の真鍮を薄く）。
	for side in 2:
		var tint := _tints[side] if _tints[side].a > 0.0 else Palette.BORDER
		var strength := 0.34 if _tints[side].a > 0.0 else 0.16
		var edge := 0.0 if side == 0 else size.x
		draw_polygon(
			PackedVector2Array([Vector2(edge, 0.0), Vector2(middle, 0.0), Vector2(middle, size.y), Vector2(edge, size.y)]),
			PackedColorArray([Color(tint, strength), Color(tint, 0.0), Color(tint, 0.0), Color(tint, strength)]))
	# 上と下の細い線（両端が濃く、真ん中へ薄く）。
	for y: float in [0.5, size.y - 0.5]:
		for side in 2:
			var tint := _tints[side] if _tints[side].a > 0.0 else Palette.BORDER_BRIGHT
			var edge := 0.0 if side == 0 else size.x
			draw_polygon(
				PackedVector2Array([Vector2(edge, y - 0.75), Vector2(middle, y - 0.75), Vector2(middle, y + 0.75), Vector2(edge, y + 0.75)]),
				PackedColorArray([Color(tint.lightened(0.3), 0.9), Color(Palette.BORDER, 0.5), Color(Palette.BORDER, 0.5), Color(tint.lightened(0.3), 0.9)]))
	if _map == null:
		return
	var rect := map_rect()
	draw_rect(rect.grow(4.0), Color(Palette.INK, 0.9))
	draw_texture_rect(_map, rect, false)
	var outer := rect.grow(4.0)
	draw_rect(outer, Palette.BORDER, false, 2.0)
	for corner: Vector2 in [Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(0.0, 1.0), Vector2(1.0, 1.0)]:
		var at := outer.position + corner * outer.size
		var inward := Vector2(1.0, 1.0) - corner * 2.0
		draw_line(at, at + Vector2(inward.x * FRAME_CORNER, 0.0), Palette.BORDER_BRIGHT, 2.0)
		draw_line(at, at + Vector2(0.0, inward.y * FRAME_CORNER), Palette.BORDER_BRIGHT, 2.0)
