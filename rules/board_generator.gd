class_name BoardGenerator
extends RefCounted
## マップごとに盤面を作る。
##
## 同じマップ・同じシードからは、いつも同じ盤面ができる。
## どのマップでも、次を守る。
## - 本陣の周り（チェビシェフ距離 3 以内）と結晶泉のマス、中ボスの周り（チェビシェフ距離 1 以内）には、障害物も森も置かない
## - 両陣営の本陣どうしは、障害物を避けて歩いてつながっている。中ボスのマスにも、本陣から歩いて行ける
##
## 地形のあとに、マップごとの環境オブジェクトを置く（中央平原に起爆樽、迷宮回廊に回復の泉、双子結晶にポータル）。
## 置くのは、本陣の周りと結晶泉を除く平地で、本陣から歩いて行けるマスだけ。

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
## 中ボスの周りの、地形もオブジェクトも置かない広さ（チェビシェフ距離）。
const MID_BOSS_CLEARING := 1
## 上下の本陣のマップ（中央平原・迷宮回廊）で、中ボスを本陣の列から左右へ離す量。
const MID_BOSS_SPREAD := 6
## 双子結晶で、中ボスを中央の壁から上下へ離す量（壁のいちばん上の行・下の行から、このマス数）。
const MID_BOSS_WALL_GAP := 4
## 双子結晶の砲台の場所（左上の角から、縦横にこれだけ内側。右下は点対称）。
const BATTERY_CORNER := 7
## 中央平原・迷宮回廊の砲台の、左右の端からの列（0 から数える）。
const BATTERY_EDGE := 1
## 迷宮回廊の回復の泉を、本陣の列から左右へ離す量と、真ん中の行から自分の本陣の側へ寄せる量。
const SPRING_SPREAD := 5
const SPRING_SETBACK := 7
const WALL_RATIO := 0.10
const FOREST_RATIO := 0.15
## 連結しない盤面ができたら、シードをずらして作り直す回数。尽きたら壁を削ってつなぐ。
const MAX_ATTEMPTS := 10
## 中央平原の起爆樽の数。
const MIN_BARRELS := 4
const MAX_BARRELS := 6
## 回復の泉・ポータルを置きたいマスが使えないとき、近くを探す広さ（チェビシェフ距離）。
const OBJECT_SEARCH_RADIUS := 3
## オブジェクトの配置に使う乱数のシードを、地形のシードからずらす量。
const OBJECT_SEED_OFFSET := 1_000_003


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
	board.mid_boss_cells = mid_boss_cells_for(stage, size)
	board.battery_spots = battery_spots_for(stage, size)

	var protected := protected_cells(board)
	for attempt in MAX_ATTEMPTS:
		var rng := RandomNumberGenerator.new()
		rng.seed = map_seed + attempt
		match stage:
			Stage.PLAIN:
				_scatter(board, protected, rng)
				# 中央 6 x 6 の障害物は除く（森は残す）。
				_clear_obstacles(board, protected, Rect2i(center - Vector2i(3, 3), Vector2i(6, 6)))
			Stage.LABYRINTH:
				_build_labyrinth(board, protected, rng)
			Stage.TWIN_SPRINGS:
				_scatter(board, protected, rng)
				# 中央の横長の帯（30 x 30 なら x:10〜20, y:12〜18）を壁でふさぐ。
				_fill_rect(board, protected, Rect2i(center - Vector2i(5, 3), Vector2i(11, 7)), Terrain.Type.OBSTACLE)
		if _hqs_connected(board) and _mid_bosses_reachable(board):
			_place_objects(board, stage, map_seed, protected)
			return board

	if stage == Stage.TWIN_SPRINGS:
		# 中央を貫くとマップの形が崩れるので、盤の外周を空けてつなぐ。
		for rect: Rect2i in [
			Rect2i(0, 0, size.x, 1), Rect2i(0, size.y - 1, size.x, 1),
			Rect2i(0, 0, 1, size.y), Rect2i(size.x - 1, 0, 1, size.y),
		]:
			_fill_rect(board, protected, rect, Terrain.Type.NORMAL)
	else:
		carve_corridor(board)
	for cell in board.mid_boss_cells:
		if not board.is_reachable(board.hq_cells[0], cell):
			carve_corridor(board, cell)
	_place_objects(board, stage, map_seed, protected)
	return board


## マップの、砲台を置ける場所（2 つ。本陣どうしを入れ替える点対称で、どちらの本陣からもほぼ同じ遠さ）。
## 盤の真ん中（拠点と、正面のぶつかり合い）から外し、脇に置く（人間の案。Issue #47 の 11/22）。
## - 中央平原・迷宮回廊: 左右の端から BATTERY_EDGE 列目の、真ん中の行（中ボスと結晶泉の中立の駒が届かない）
## - 双子結晶: 左上と右下の角の内側（左右の道の、両方の本陣から同じ道のりの辺り）
static func battery_spots_for(stage: Stage, size: Vector2i) -> Array[Vector2i]:
	var first: Vector2i
	if stage == Stage.TWIN_SPRINGS:
		first = Vector2i(BATTERY_CORNER, BATTERY_CORNER)
	else:
		first = Vector2i(BATTERY_EDGE, ((size - Vector2i.ONE) / 2).y)
	# 本陣どうしを入れ替える点対称（中央平原・迷宮回廊の本陣は、列の真ん中より 1 つ左。双子結晶は対角）。
	var hqs_sum := Vector2i(size.x - 1, size.y - 1) if stage == Stage.TWIN_SPRINGS else Vector2i(2 * ((size / 2).x - 1), size.y - 1)
	return [first, hqs_sum - first]


## 砲台を置く（選べる決まり TrialRules.BATTERY が入の対戦だけ。MatchSetup.create_battle が呼ぶ）。
## 置ける場所（Board.battery_spots）が障害物なら平地にし、本陣から歩いて行けなければ道を削る。ほかの環境オブジェクトがあるマスには置かない。
static func arm_batteries(board: Board) -> void:
	for cell in board.battery_spots:
		if not board.in_bounds(cell) or board.object_at(cell) != MapObject.Type.NONE or board.hq_cells.has(cell):
			continue
		if board.terrain_at(cell) == Terrain.Type.FONT:
			continue
		if not Terrain.is_walkable(board.terrain_at(cell)):
			board.set_terrain(cell, Terrain.Type.NORMAL)
		if not board.is_reachable(board.hq_cells[0], cell):
			carve_corridor(board, cell)
		board.add_battery(cell)


## マップの中ボスのマス（0 = 左、1 = 右）。両方のプレイヤーに公平になるように置く（docs/neutral-mid-boss.md）。
## - 中央平原・迷宮回廊: 盤の真ん中の行の高さで、本陣の列から左右へ MID_BOSS_SPREAD。
##   本陣どうしを入れ替える点対称（盤の行の数が偶数なので、真ん中の行は 2 つある）で、左右の中ボスが入れ替わる
## - 双子結晶: 中央の壁の上と下（0 = 上、1 = 下）。盤の列の真ん中で、壁から MID_BOSS_WALL_GAP。
##   上の中ボスへは、プレイヤー1 はポータルを抜けて、プレイヤー2 は歩いて、ほぼ同じ歩数で着く（下はその逆）。
##   ポータルの出口のそばには置かない（出た先ですぐ狩れると、そのポータルに近い側だけのものになる）
static func mid_boss_cells_for(stage: Stage, size: Vector2i) -> Array[Vector2i]:
	if stage == Stage.TWIN_SPRINGS:
		var center := size / 2
		var top := Vector2i(center.x, center.y - 3 - MID_BOSS_WALL_GAP)
		return [top, size - Vector2i.ONE - top]
	var hq_x := (size / 2).x - 1
	var upper := ((size - Vector2i.ONE) / 2).y
	return [Vector2i(hq_x - MID_BOSS_SPREAD, upper), Vector2i(hq_x + MID_BOSS_SPREAD, size.y - 1 - upper)]


## 迷宮回廊の回復の泉のマス。左の泉はプレイヤー1 の側、右の泉はプレイヤー2 の側に、本陣どうしを入れ替える点対称で置く
## （どちらのプレイヤーにも、近い泉と遠い泉が 1 つずつ）。中ボスの届く範囲（縄張り + 射程）と、そこへ撃てる距離の外。
static func spring_cells_for(size: Vector2i) -> Array[Vector2i]:
	var hq_x := (size / 2).x - 1
	var lower := size.y - 1 - ((size - Vector2i.ONE) / 2).y
	var left := Vector2i(hq_x - SPRING_SPREAD, lower + SPRING_SETBACK)
	return [left, Vector2i(2 * hq_x - left.x, size.y - 1 - left.y)]


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
	for boss in board.mid_boss_cells:
		for dy in range(-MID_BOSS_CLEARING, MID_BOSS_CLEARING + 1):
			for dx in range(-MID_BOSS_CLEARING, MID_BOSS_CLEARING + 1):
				var cell := boss + Vector2i(dx, dy)
				if board.in_bounds(cell):
					cells[cell] = true
	return cells


## 壁を無視した最短の道で、プレイヤー1 の本陣と to（既定はプレイヤー2 の本陣）を結び、その道の上の壁を平地にする。
static func carve_corridor(board: Board, to := Board.NO_CELL) -> void:
	var from := board.hq_cells[0]
	if to == Board.NO_CELL:
		to = board.hq_cells[1]
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


## マップごとの環境オブジェクトを置く。地形とは別の乱数を使う（地形は、オブジェクトの有無で変わらない）。
static func _place_objects(board: Board, stage: Stage, map_seed: int, protected: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed + OBJECT_SEED_OFFSET
	match stage:
		Stage.PLAIN:
			_place_barrels(board, protected, rng)
		Stage.LABYRINTH:
			# 左右に 1 つずつ（spring_cells_for）。壁や森なら平地にして、いつも同じ場所に置く（左右を点対称に保つ）。
			# 迷路の乱数は引き直さないので、泉のマスのほかは、泉を動かす前と同じ盤面になる。
			for cell in spring_cells_for(board.size):
				board.set_terrain(cell, Terrain.Type.NORMAL)
				if not board.is_reachable(board.hq_cells[0], cell):
					carve_corridor(board, cell)
				board.add_spring(cell)
		Stage.TWIN_SPRINGS:
			# 左右の道それぞれに、上の端寄りと下の端寄りを結ぶ対を 1 組ずつ。
			for x: int in [5, board.size.x - 6]:
				var top := _free_cell_near(board, protected, Vector2i(x, 4))
				var bottom := _free_cell_near(board, protected, Vector2i(x, board.size.y - 5))
				if top != Board.NO_CELL and bottom != Board.NO_CELL:
					board.add_portal_pair(top, bottom)


## 起爆樽を、中央の左右の帯（30 x 30 なら x:8〜10 と x:20〜22、y:10〜20）に、左右交互に置く。
## 樽は通れないので、通れる場所が分かれてしまう置き方（道をふさぐ置き方）はしない。
static func _place_barrels(board: Board, protected: Dictionary, rng: RandomNumberGenerator) -> void:
	var center := board.size / 2
	var zones: Array[Array] = []
	for left: int in [center.x - 7, center.x + 5]:
		var cells: Array[Vector2i] = []
		for y in range(center.y - 5, center.y + 6):
			for x in range(left, left + 3):
				cells.append(Vector2i(x, y))
		_shuffle(cells, rng)
		zones.append(cells)
	var wanted := rng.randi_range(MIN_BARRELS, MAX_BARRELS)
	var open_cells := _reachable_count(board)
	var placed := 0
	var side := 0
	while placed < wanted and not (zones[0].is_empty() and zones[1].is_empty()):
		var zone: Array = zones[side]
		side = 1 - side
		while not zone.is_empty():
			var cell: Vector2i = zone.pop_back()
			if not _is_free(board, protected, cell):
				continue
			board.add_barrel(cell)
			if _reachable_count(board) == open_cells - 1:
				open_cells -= 1
				placed += 1
				break
			board.remove_barrel(cell)


## spot にいちばん近い、オブジェクトを置けるマス（spot 自身を含む）。本陣から歩いて行けるものだけ。
## 近い順（チェビシェフ距離）に、上の行から、左の列から探す。無ければ Board.NO_CELL。
static func _free_cell_near(board: Board, protected: Dictionary, spot: Vector2i) -> Vector2i:
	for radius in OBJECT_SEARCH_RADIUS + 1:
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var cell := spot + Vector2i(dx, dy)
				if _is_free(board, protected, cell) and board.is_reachable(board.hq_cells[0], cell):
					return cell
	return Board.NO_CELL


## オブジェクトを置いてよいマスか（守るマスでない平地で、まだ何も置かれていない）。
static func _is_free(board: Board, protected: Dictionary, cell: Vector2i) -> bool:
	return (
		board.in_bounds(cell)
		and not protected.has(cell)
		and board.terrain_at(cell) == Terrain.Type.NORMAL
		and board.can_place_object(cell)
	)


## プレイヤー1 の本陣から歩いて行けるマスの数。
static func _reachable_count(board: Board) -> int:
	var visited := {board.hq_cells[0]: true}
	var queue: Array[Vector2i] = [board.hq_cells[0]]
	var head := 0
	while head < queue.size():
		var cell := queue[head]
		head += 1
		for direction in Board.DIRECTIONS:
			var next := cell + direction
			if not visited.has(next) and board.is_walkable(next):
				visited[next] = true
				queue.append(next)
	return queue.size()


## 渡した乱数で並べ替える（Array.shuffle() は全体の乱数を使うので、シードで固定できない）。
static func _shuffle(cells: Array[Vector2i], rng: RandomNumberGenerator) -> void:
	for i in range(cells.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var kept := cells[i]
		cells[i] = cells[j]
		cells[j] = kept


static func _hqs_connected(board: Board) -> bool:
	return board.is_reachable(board.hq_cells[0], board.hq_cells[1])


static func _mid_bosses_reachable(board: Board) -> bool:
	for cell in board.mid_boss_cells:
		if not board.is_reachable(board.hq_cells[0], cell):
			return false
	return true


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


## rect の中の障害物を平地にする（森はそのまま）。
static func _clear_obstacles(board: Board, protected: Dictionary, rect: Rect2i) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var cell := Vector2i(x, y)
			if board.in_bounds(cell) and not protected.has(cell) and board.terrain_at(cell) == Terrain.Type.OBSTACLE:
				board.set_terrain(cell, Terrain.Type.NORMAL)


static func _fill_rect(board: Board, protected: Dictionary, rect: Rect2i, type: Terrain.Type) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var cell := Vector2i(x, y)
			if board.in_bounds(cell) and not protected.has(cell):
				board.set_terrain(cell, type)
