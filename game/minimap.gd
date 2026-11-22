extends Control
## 対戦の画面のミニマップ（docs/minimap.md）。盤の縮図、駒の点、目印、カメラが見ている範囲を描き、
## クリックとドラッグで、その場所を知らせる（カメラを動かすのは呼ぶ側）。
## 置き場所・座標・見ている範囲の計算は minimap_geometry.gd、地面の塗り分けは map_card.gd（マップ選択のカードと同じ）。

const Text := preload("res://game/text.gd")
const Palette := preload("res://game/ui_palette.gd")
const Geometry := preload("res://game/minimap_geometry.gd")
const MapCard := preload("res://game/map_card.gd")
const UnitView := preload("res://game/unit_view.gd")

## ミニマップの上で押した・押したまま動かした。point は盤の座標（x / z）。
signal pointed(point: Vector2)

const COLOR_BACK := Palette.OVERLAY
const COLOR_MINION := Color("ffd34a")
const COLOR_DOT_EDGE := Color(0.0, 0.0, 0.0, 0.75)
const COLOR_VIEW := Color(1.0, 1.0, 1.0, 0.95)
const COLOR_VIEW_FILL := Color(1.0, 1.0, 1.0, 0.10)
## 駒の点の半径（1 マスの大きさに掛ける）。中ボスは大きく、菱形にする。
const DOT_RADIUS := 0.65
const BOSS_RADIUS := 0.95
## 縮図を薄くする（盤の上の点と、見ている範囲の線が目立つように）。
const MAP_ALPHA := 0.92

## 枠の四隅の鉤の長さ。
const FRAME_CORNER := 12.0

var team_colors: Array[Color] = []
var _board: Board
var _texture: ImageTexture
## 描く駒（[盤の座標, Unit.Side, 中ボスか] の列）。
var _dots: Array = []
## カメラが見ている範囲（盤の座標の多角形。盤の外は切り落としたもの）。
var _view := PackedVector2Array()
var _pressing := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = Text.t("battle.minimap.tooltip")


## 盤 board（見た目 look_name。stage_look.gd の名前）を描き始める。盤の大きさに合わせて、自分の大きさも決める。
func show_board(board: Board, look_name: StringName) -> void:
	_board = board
	var px := Geometry.cell_px(board.size)
	_texture = ImageTexture.create_from_image(MapCard.draw(board, look_name, team_colors, px, false))
	size = Geometry.map_size(board.size)
	_dots.clear()
	_view = PackedVector2Array()
	queue_redraw()


## 駒の点と、カメラが見ている範囲を描き直す。battle の駒の見た目（views。番号 -> UnitView）のいまの位置を使う
## （歩いている途中の駒も、その場所に出る）。camera と画面の大きさ screen から、見ている範囲を求める。
func refresh(battle: Battle, views: Dictionary, camera: Camera3D, screen: Vector2) -> void:
	if _board == null:
		return
	_dots.clear()
	for unit_id: int in views:
		var unit := battle.unit_by_id(unit_id)
		if unit == null:
			continue
		var view: UnitView = views[unit_id]
		_dots.append([Vector2(view.position.x, view.position.z), unit.side, unit.kind == UnitKind.Id.ELITE_MINION])
	var quad := Geometry.view_quad(camera.global_position, camera.global_transform.basis, camera.fov, screen.x / maxf(screen.y, 1.0))
	_view = Geometry.clip_to_board(quad, _board.size)
	queue_redraw()


## 描いている盤の大きさ（マス。盤がまだ無ければ、ふつうの盤の大きさ）。
func board_size() -> Vector2i:
	return _board.size if _board != null else BoardGenerator.DEFAULT_SIZE


## 見ている範囲（ミニマップの中の位置。左上からの px）。検査用。
func view_on_map() -> PackedVector2Array:
	var points := PackedVector2Array()
	for point in _view:
		points.append(Geometry.to_map(point, _board.size))
	return points


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_BACK)
	if _board == null:
		_draw_frame()
		return
	var px := float(Geometry.cell_px(_board.size))
	draw_texture(_texture, Vector2.ONE * Geometry.PADDING, Color(1, 1, 1, MAP_ALPHA))
	# 目印（対戦の途中で消えるもの（樽）もあるので、盤から毎回読む）。
	for cell in _board.spring_cells:
		draw_rect(_cell_rect(cell, px, 0.2), MapCard.COLOR_SPRING)
	for cell in _board.battery_cells:
		draw_rect(_cell_rect(cell, px, 0.2), MapCard.COLOR_BATTERY)
	if _board.stronghold_cell != Board.NO_CELL:
		var mark := _cell_rect(_board.stronghold_cell, px, 0.1)
		draw_rect(mark, MapCard.COLOR_STRONGHOLD, false, maxf(1.0, px * 0.25))
	for cell: Vector2i in _board.portal_exits:
		draw_arc(_center(cell), px * 0.42, 0.0, TAU, 12, MapCard.COLOR_PORTAL, maxf(1.0, px * 0.3))
	for cell in _board.barrel_cells:
		draw_circle(_center(cell), px * 0.32, MapCard.COLOR_BARREL)
	# 駒（中ボスは最後に、大きな菱形で）。
	for boss: bool in [false, true]:
		for dot: Array in _dots:
			if dot[2] != boss:
				continue
			var at := Geometry.to_map(dot[0], _board.size)
			if boss:
				var r := px * BOSS_RADIUS
				var diamond := PackedVector2Array([at + Vector2(0, -r), at + Vector2(r, 0), at + Vector2(0, r), at + Vector2(-r, 0)])
				draw_colored_polygon(diamond, MapCard.COLOR_MID_BOSS)
				diamond.append(diamond[0])
				draw_polyline(diamond, COLOR_DOT_EDGE, 1.0)
			else:
				var r := px * DOT_RADIUS
				draw_circle(at, r + 1.0, COLOR_DOT_EDGE)
				draw_circle(at, r, _side_color(dot[1]))
	# カメラが見ている範囲。
	if _view.size() >= 3:
		var points := view_on_map()
		draw_colored_polygon(points, COLOR_VIEW_FILL)
		points.append(points[0])
		draw_polyline(points, COLOR_VIEW, 1.5, true)
	_draw_frame()


## 枠: 真鍮の縁と、四隅の明るい鉤（地図の額に見せる）。
func _draw_frame() -> void:
	draw_rect(Rect2(Vector2.ONE, size - Vector2.ONE * 2.0), Palette.BORDER, false, 2.0)
	var reach := minf(FRAME_CORNER, minf(size.x, size.y) / 3.0)
	for corner: Vector2 in [Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(0.0, 1.0), Vector2(1.0, 1.0)]:
		var at := Vector2(1.0, 1.0) + corner * (size - Vector2.ONE * 2.0)
		var inward := Vector2(1.0, 1.0) - corner * 2.0
		draw_line(at, at + Vector2(inward.x * reach, 0.0), Palette.BORDER_BRIGHT, 2.0)
		draw_line(at, at + Vector2(0.0, inward.y * reach), Palette.BORDER_BRIGHT, 2.0)


func _gui_input(event: InputEvent) -> void:
	if take_input(event):
		accept_event()


## マウスの入力（位置はミニマップの左上から）を受ける。押す・押したまま動かすと、そこを知らせる。受けたら真。
func take_input(event: InputEvent) -> bool:
	if _board == null:
		return false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_pressing = event.pressed
		if event.pressed:
			pointed.emit(Geometry.to_board(event.position, _board.size))
		return true
	if event is InputEventMouseMotion and _pressing:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			pointed.emit(Geometry.to_board(event.position, _board.size))
		else:
			_pressing = false
		return true
	return false


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_pressing = false


func _side_color(side: Unit.Side) -> Color:
	if side == Unit.Side.NEUTRAL:
		return COLOR_MINION
	return team_colors[side] if side < team_colors.size() else Color.WHITE


func _center(cell: Vector2i) -> Vector2:
	return Geometry.to_map(Vector2(cell) + Vector2(0.5, 0.5), _board.size)


func _cell_rect(cell: Vector2i, px: float, inset: float) -> Rect2:
	var at := Geometry.to_map(Vector2(cell), _board.size)
	return Rect2(at + Vector2.ONE * px * inset, Vector2.ONE * px * (1.0 - inset * 2.0))
