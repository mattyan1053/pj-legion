extends RefCounted
## マップ選択のカードと、対戦の画面のミニマップ（minimap.gd）に載せる、盤面の縮図（Image）。盤（Board）をマスごとに色で塗る。ノードに依存しない（テストから呼べる）。
## 絵は描かず、ルールが作る盤（BoardGenerator）とマップの見た目（stage_look.gd）の色から作る。
##
## 塗り分け: 平地・森・岩（障害物）・結晶泉はマップの見た目の色、本陣は陣営の色（周りを薄く）、中ボスは紫、
## 起爆樽は橙、回復の泉は水色、ポータルは明るい紫。

const StageLook := preload("res://game/stage_look.gd")

## 1 マスの大きさ（px）。
const CELL := 6
const COLOR_MID_BOSS := Color("b04fd6")
const COLOR_BARREL := Color("e08a2e")
const COLOR_SPRING := Color("8fe3ff")
const COLOR_BATTERY := Color("ffb347")
const COLOR_PORTAL := Color("d9a6ff")
## 市松に少し明るさを変える（マスの粒が見えるように）。
const CHECKER := 0.05


## 見た目 look_name（stage_look.gd の名前）で描いた、盤 board の縮図。team_colors はプレイヤー番号ごとの色。cell_size は 1 マスの大きさ（px）。
## objects が偽なら、地面と本陣だけを塗り、市松の明るさの差も付けない（中ボス・樽・泉・ポータルは描かない。対戦の画面の
## ミニマップは小さいので、市松はざらついて見える。対戦の途中で変わるものは、上から描き足す。minimap.gd）。
static func draw(board: Board, look_name: StringName, team_colors: Array[Color], cell_size := CELL, objects := true) -> Image:
	var look := StageLook.of(look_name)
	var image := Image.create(board.size.x * cell_size, board.size.y * cell_size, false, Image.FORMAT_RGB8)
	for y in board.size.y:
		for x in board.size.x:
			var cell := Vector2i(x, y)
			var color := cell_color(board, cell, look, team_colors, objects)
			if objects and (x + y) % 2 == 0:
				color = color.lightened(CHECKER)
			image.fill_rect(Rect2i(x * cell_size, y * cell_size, cell_size, cell_size), color)
	if not objects:
		return image
	# 小さいものは、マスの真ん中に点で置く（地面の色が周りに残るように）。
	for cell in board.barrel_cells:
		_dot(image, cell, COLOR_BARREL, cell_size)
	for cell in board.spring_cells:
		_dot(image, cell, COLOR_SPRING, cell_size)
	for cell in board.battery_cells:
		_dot(image, cell, COLOR_BATTERY, cell_size)
	for cell: Vector2i in board.portal_exits:
		_dot(image, cell, COLOR_PORTAL, cell_size)
	return image


## マスの地面の色（本陣と、mid_boss が真なら中ボスは、その印の色）。
static func cell_color(board: Board, cell: Vector2i, look: Dictionary, team_colors: Array[Color], mid_boss := true) -> Color:
	for side in board.hq_cells.size():
		var hq: Vector2i = board.hq_cells[side]
		if cell == hq:
			return team_colors[side]
		if maxi(absi(cell.x - hq.x), absi(cell.y - hq.y)) <= 1:
			return team_colors[side].darkened(0.35)
	if mid_boss and board.mid_boss_cells.has(cell):
		return COLOR_MID_BOSS
	match board.terrain_at(cell):
		Terrain.Type.OBSTACLE:
			return look[StageLook.OBSTACLE].darkened(0.25)
		Terrain.Type.FOREST:
			return look[StageLook.FOREST]
		Terrain.Type.FONT:
			return look[StageLook.FONT]
	return look[StageLook.NORMAL]


static func _dot(image: Image, cell: Vector2i, color: Color, cell_size: int) -> void:
	var inset := cell_size / 4
	image.fill_rect(Rect2i(cell.x * cell_size + inset, cell.y * cell_size + inset, cell_size - inset * 2, cell_size - inset * 2), color)
