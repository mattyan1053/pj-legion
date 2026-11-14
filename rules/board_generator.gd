class_name BoardGenerator
extends RefCounted
## ステージごとに盤面を作る。
##
## 同じステージ・同じシードからは、いつも同じ盤面ができる。
## どのステージでも、次を守る。
## - 本陣の周り（チェビシェフ距離 3 以内）と結晶泉のマスには、障害物も森も置かない
## - 両陣営の本陣どうしは、障害物を避けて歩いてつながっている

enum Stage {
	PLAIN = 1,  ## 中央平原: 障害物は少なめ、中央は空ける
	LABYRINTH = 2,  ## 迷宮回廊: 2 マスおきの格子の壁に、ところどころ穴を空ける
	TWIN_SPRINGS = 3,  ## 双子結晶: 中央を大きな壁でふさぎ、左右の道に分ける
}

const DEFAULT_SIZE := Vector2i(30, 30)
## これより小さいと、本陣・結晶泉・中央の壁が盤からはみ出したり重なったりする
## （双子結晶の中央の壁は中心から左右 5 マスで、右の結晶泉（x = 幅 - 5）にかからないには幅 22 が要る）。
const MIN_SIZE := Vector2i(22, 22)
const PROTECT_RADIUS := 3
const WALL_RATIO := 0.10
const FOREST_RATIO := 0.15
## 連結しない盤面ができたら、シードをずらして作り直す回数。尽きたら壁を削ってつなぐ。
const MAX_ATTEMPTS := 10


## size が MIN_SIZE より小さいときは作らずに null を返す。
static func generate(stage: Stage, map_seed: int, size := DEFAULT_SIZE) -> Board:
	if size.x < MIN_SIZE.x or size.y < MIN_SIZE.y:
		return null
	var board := Board.new(size)
	var center := size / 2
	if stage == Stage.TWIN_SPRINGS:
		# 本陣は対角（左下と右上）。結晶泉は左右の道に上下対称に置く。
		board.hq_cells = [Vector2i(4, size.y - 1), Vector2i(size.x - 5, 0)]
		board.font_cells = [
			Vector2i(4, center.y - 2), Vector2i(4, center.y + 2),
			Vector2i(size.x - 5, center.y - 2), Vector2i(size.x - 5, center.y + 2),
		]
	else:
		# 本陣は上下の中央。結晶泉は中央を囲む 4 か所。
		board.hq_cells = [Vector2i(center.x - 1, size.y - 1), Vector2i(center.x - 1, 0)]
		board.font_cells = [
			center + Vector2i(-2, -2), center + Vector2i(2, -2),
			center + Vector2i(-2, 2), center + Vector2i(2, 2),
		]
	for cell in board.font_cells:
		board.set_terrain(cell, Terrain.Type.FONT)

	var protected := protected_cells(board)
	for attempt in MAX_ATTEMPTS:
		var rng := RandomNumberGenerator.new()
		rng.seed = map_seed + attempt
		match stage:
			Stage.PLAIN:
				_scatter(board, protected, rng)
				# 中央 6 x 6 は空ける。
				_fill_rect(board, protected, Rect2i(center - Vector2i(3, 3), Vector2i(6, 6)), Terrain.Type.NORMAL)
			Stage.LABYRINTH:
				_build_labyrinth(board, protected, rng)
			Stage.TWIN_SPRINGS:
				_scatter(board, protected, rng)
				# 中央の横長の帯（30 x 30 なら x:10〜20, y:12〜18）を壁でふさぐ。
				_fill_rect(board, protected, Rect2i(center - Vector2i(5, 3), Vector2i(11, 7)), Terrain.Type.OBSTACLE)
		if _hqs_connected(board):
			return board

	if stage == Stage.TWIN_SPRINGS:
		# 中央を貫くとステージの形が崩れるので、盤の外周を空けてつなぐ。
		for rect: Rect2i in [
			Rect2i(0, 0, size.x, 1), Rect2i(0, size.y - 1, size.x, 1),
			Rect2i(0, 0, 1, size.y), Rect2i(size.x - 1, 0, 1, size.y),
		]:
			_fill_rect(board, protected, rect, Terrain.Type.NORMAL)
	else:
		carve_corridor(board)
	return board


## 地形を置いてはいけないマス（本陣の周りと結晶泉）。Vector2i -> true。
static func protected_cells(board: Board) -> Dictionary:
	var cells := {}
	for hq in board.hq_cells:
		for dy in range(-PROTECT_RADIUS, PROTECT_RADIUS + 1):
			for dx in range(-PROTECT_RADIUS, PROTECT_RADIUS + 1):
				var cell := hq + Vector2i(dx, dy)
				if board.in_bounds(cell):
					cells[cell] = true
	for cell in board.font_cells:
		cells[cell] = true
	return cells


## 壁を無視した最短の道で本陣どうしを結び、その道の上の壁を平地にする。
static func carve_corridor(board: Board) -> void:
	var from := board.hq_cells[0]
	var to := board.hq_cells[1]
	var parent := {from: from}
	var queue: Array[Vector2i] = [from]
	var head := 0
	while head < queue.size() and not parent.has(to):
		var cell := queue[head]
		head += 1
		for direction in Board.DIRECTIONS:
			var next := cell + direction
			if board.in_bounds(next) and not parent.has(next):
				parent[next] = cell
				queue.append(next)

	var cell := to
	while cell != from:
		if board.terrain_at(cell) == Terrain.Type.OBSTACLE:
			board.set_terrain(cell, Terrain.Type.NORMAL)
		cell = parent[cell]


static func _hqs_connected(board: Board) -> bool:
	return board.is_reachable(board.hq_cells[0], board.hq_cells[1])


## 守るマス以外を、障害物・森・平地に塗り直す。
static func _scatter(board: Board, protected: Dictionary, rng: RandomNumberGenerator) -> void:
	for y in board.size.y:
		for x in board.size.x:
			var cell := Vector2i(x, y)
			if protected.has(cell):
				continue
			var roll := rng.randf()
			var type := Terrain.Type.NORMAL
			if roll < WALL_RATIO:
				type = Terrain.Type.OBSTACLE
			elif roll < WALL_RATIO + FOREST_RATIO:
				type = Terrain.Type.FOREST
			board.set_terrain(cell, type)


## 偶数の列・行を壁の線にして、穴を空ける。奇数 x 奇数のマスはいつも通路。
## 穴は中央（結晶泉）に近いほど空きやすい。
static func _build_labyrinth(board: Board, protected: Dictionary, rng: RandomNumberGenerator) -> void:
	var center := board.size / 2
	for y in board.size.y:
		for x in board.size.x:
			var cell := Vector2i(x, y)
			if protected.has(cell):
				continue
			var type := Terrain.Type.NORMAL
			if x % 2 == 0 or y % 2 == 0:
				var dx := absf(x - center.x) / center.x
				var dy := absf(y - center.y) / center.y
				var centerness := 1.0 - minf(1.0, (dx + dy) / 2.0)  # 中央 = 1、端 = 0
				var opening := 0.50 + 0.18 * centerness
				if rng.randf() >= opening:
					type = Terrain.Type.OBSTACLE
			board.set_terrain(cell, type)


static func _fill_rect(board: Board, protected: Dictionary, rect: Rect2i, type: Terrain.Type) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var cell := Vector2i(x, y)
			if board.in_bounds(cell) and not protected.has(cell):
				board.set_terrain(cell, type)
