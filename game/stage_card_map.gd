extends RefCounted
## ステージ選択のカードに載せる、盤面の縮図（Image）。盤（Board）をマスごとに色で塗る。ノードに依存しない（テストから呼べる）。
## 絵は描かず、ルールが作る盤（BoardGenerator）とステージの色合い（stage_look.gd）から作る。
##
## 塗り分け: 平地・森・岩（障害物）・結晶泉はステージの色合い、本陣は陣営の色（周りを薄く）、中ボスは紫、
## 起爆樽は橙、回復の泉は水色、ポータルは明るい紫。

const StageLook := preload("res://game/stage_look.gd")

## 1 マスの大きさ（px）。
const CELL := 6
const COLOR_MID_BOSS := Color("b04fd6")
const COLOR_BARREL := Color("e08a2e")
const COLOR_SPRING := Color("8fe3ff")
const COLOR_PORTAL := Color("d9a6ff")
## 市松に少し明るさを変える（マスの粒が見えるように）。
const CHECKER := 0.05


## stage の盤 board の縮図。team_colors はプレイヤー番号ごとの色。
static func draw(board: Board, stage: int, team_colors: Array[Color]) -> Image:
	var look := StageLook.of(stage)
	var image := Image.create(board.size.x * CELL, board.size.y * CELL, false, Image.FORMAT_RGB8)
	for y in board.size.y:
		for x in board.size.x:
			var cell := Vector2i(x, y)
			var color := cell_color(board, cell, look, team_colors)
			if (x + y) % 2 == 0:
				color = color.lightened(CHECKER)
			image.fill_rect(Rect2i(x * CELL, y * CELL, CELL, CELL), color)
	# 小さいものは、マスの真ん中に点で置く（地面の色が周りに残るように）。
	for cell in board.barrel_cells:
		_dot(image, cell, COLOR_BARREL)
	for cell in board.spring_cells:
		_dot(image, cell, COLOR_SPRING)
	for cell: Vector2i in board.portal_exits:
		_dot(image, cell, COLOR_PORTAL)
	return image


## マスの地面の色（本陣と中ボスは、その印の色）。
static func cell_color(board: Board, cell: Vector2i, look: Dictionary, team_colors: Array[Color]) -> Color:
	for side in board.hq_cells.size():
		var hq: Vector2i = board.hq_cells[side]
		if cell == hq:
			return team_colors[side]
		if maxi(absi(cell.x - hq.x), absi(cell.y - hq.y)) <= 1:
			return team_colors[side].darkened(0.35)
	if board.mid_boss_cells.has(cell):
		return COLOR_MID_BOSS
	match board.terrain_at(cell):
		Terrain.Type.OBSTACLE:
			return look[StageLook.OBSTACLE].darkened(0.25)
		Terrain.Type.FOREST:
			return look[StageLook.FOREST]
		Terrain.Type.FONT:
			return look[StageLook.FONT]
	return look[StageLook.NORMAL]


static func _dot(image: Image, cell: Vector2i, color: Color) -> void:
	var inset := CELL / 4
	image.fill_rect(Rect2i(cell.x * CELL + inset, cell.y * CELL + inset, CELL - inset * 2, CELL - inset * 2), color)
