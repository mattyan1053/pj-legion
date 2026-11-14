class_name Board
extends RefCounted
## 盤面。マス目ごとの地形と、本陣（HQ）・結晶泉の位置を持つ。
##
## 大きさは作るときに決める（30 x 30 決め打ちにしない）。
## 座標は Vector2i(列, 行)。左上が (0, 0) で、行は下へ増える。

## 上下左右。隣のマスをたどるときの順番もこれで固定する（結果を毎回同じにするため）。
const DIRECTIONS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]

var size: Vector2i
## プレイヤーごとの本陣のマス。添字がプレイヤー番号（0 = プレイヤー1、1 = プレイヤー2）。
var hq_cells: Array[Vector2i] = []
var font_cells: Array[Vector2i] = []

var _terrain := PackedByteArray()


func _init(board_size: Vector2i) -> void:
	assert(board_size.x > 0 and board_size.y > 0)
	size = board_size
	_terrain.resize(size.x * size.y)
	_terrain.fill(Terrain.Type.NORMAL)


## 同じ盤面を作る（Battle.clone() が使う）。
func copy() -> Board:
	var result := Board.new(size)
	StateCopy.copy_fields(self, result)
	return result


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y


func terrain_at(cell: Vector2i) -> Terrain.Type:
	assert(in_bounds(cell))
	return _terrain[_index(cell)] as Terrain.Type


func set_terrain(cell: Vector2i, type: Terrain.Type) -> void:
	assert(in_bounds(cell))
	_terrain[_index(cell)] = type


## 盤の外は入れない扱い。
func is_walkable(cell: Vector2i) -> bool:
	return in_bounds(cell) and Terrain.is_walkable(terrain_at(cell))


## 入るのに使う移動力。入れないマスは -1。
func move_cost(cell: Vector2i) -> int:
	if not is_walkable(cell):
		return -1
	return Terrain.move_cost(terrain_at(cell))


func blocks_range(cell: Vector2i) -> bool:
	return in_bounds(cell) and Terrain.blocks_range(terrain_at(cell))


## そのマスを本陣にしているプレイヤーの番号。本陣でなければ -1。
func hq_owner(cell: Vector2i) -> int:
	return hq_cells.find(cell)


## 入れるマスだけを上下左右にたどって、from から to へ行けるか。森は通れる。
func is_reachable(from: Vector2i, to: Vector2i) -> bool:
	if not is_walkable(from) or not is_walkable(to):
		return false
	var visited := {from: true}
	var queue: Array[Vector2i] = [from]
	var head := 0
	while head < queue.size():
		var cell := queue[head]
		head += 1
		if cell == to:
			return true
		for direction in DIRECTIONS:
			var next := cell + direction
			if not visited.has(next) and is_walkable(next):
				visited[next] = true
				queue.append(next)
	return false


func count_terrain(type: Terrain.Type) -> int:
	return _terrain.count(type)


func _index(cell: Vector2i) -> int:
	return cell.y * size.x + cell.x
