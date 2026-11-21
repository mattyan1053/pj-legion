class_name Board
extends RefCounted
## 盤面。マス目ごとの地形と、本陣（HQ）・結晶泉・環境オブジェクト（起爆樽、回復の泉、ポータル）の位置と、
## 盤の上の効果（盾、煙幕、聖域。FieldEffect）を持つ。
##
## 環境オブジェクトは地形とは別の層で、置いても地形は変わらない。1 マスに 1 つまで。
## 盤の上の効果は、地形とも環境オブジェクトとも別の層（docs/field-effects.md）。効果の計算と、置く・消すのは FieldEffects。
## 大きさは作るときに決める（30 x 30 決め打ちにしない）。
## 座標は Vector2i(列, 行)。左上が (0, 0) で、行は下へ増える。

## 「マスが無い」を表す値（盤の外）。
const NO_CELL := Vector2i(-1, -1)
## 上下左右。隣のマスをたどるときの順番もこれで固定する（結果を毎回同じにするため）。
const DIRECTIONS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]

var size: Vector2i
## プレイヤーごとの本陣のマス。添字がプレイヤー番号（0 = プレイヤー1、1 = プレイヤー2）。
var hq_cells: Array[Vector2i] = []
var font_cells: Array[Vector2i] = []
## 中ボス（エリートミニオン）を置くマス。添字が中ボスの番号（0 = 左、1 = 右。docs/neutral-mid-boss.md）。
var mid_boss_cells: Array[Vector2i] = []
## 起爆樽のマス。爆発した樽はここから消える。
var barrel_cells: Array[Vector2i] = []
## 回復の泉のマス。
var spring_cells: Array[Vector2i] = []
## 砲台を置ける場所（盤の出どころが決める。置かれるまでは何もしない）。
var battery_spots: Array[Vector2i] = []
## 置かれた砲台（試しの決まりが入の対戦だけ。BoardGenerator.arm_batteries）。
var battery_cells: Array[Vector2i] = []
## ポータルのマス -> 対になるポータルのマス。対の両方が、互いを指して入る。
var portal_exits: Dictionary[Vector2i, Vector2i] = {}
## 盤の上の効果（置いた順。番号の小さい順でもある）。
var field_effects: Array[FieldEffect] = []
## 入れるマスが変わるたびに 1 進む（樽が消えた、盾が置かれた・消えた）。歩けるマスの表を覚えておく側（CPU）が見る。
var walkable_revision := 0

var _terrain := PackedByteArray()
## 盾のあるマス -> その盾の番号。is_walkable() が毎回効果を全部調べずに済むように持つ。
var _barricades: Dictionary[Vector2i, int] = {}
var _next_field_effect_id := 1


func _init(board_size: Vector2i) -> void:
	assert(board_size.x > 0 and board_size.y > 0)
	size = board_size
	_terrain.resize(size.x * size.y)
	_terrain.fill(Terrain.Type.NORMAL)


## 同じ盤面を作る（Battle.clone() が使う）。
func copy() -> Board:
	var result := Board.new(size)
	StateCopy.copy_fields(self, result, [&"field_effects"])
	for effect in field_effects:
		result.field_effects.append(effect.copy())
	return result


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y


func terrain_at(cell: Vector2i) -> Terrain.Type:
	assert(in_bounds(cell))
	return _terrain[_index(cell)] as Terrain.Type


func set_terrain(cell: Vector2i, type: Terrain.Type) -> void:
	assert(in_bounds(cell))
	_terrain[_index(cell)] = type


## 盤の外は入れない扱い。起爆樽と盾のあるマスにも入れない。
func is_walkable(cell: Vector2i) -> bool:
	return (
		in_bounds(cell)
		and Terrain.is_walkable(terrain_at(cell))
		and MapObject.is_walkable(object_at(cell))
		and not _barricades.has(cell)
	)


## そのマスにある環境オブジェクトの種類。無ければ MapObject.Type.NONE。
func object_at(cell: Vector2i) -> MapObject.Type:
	if barrel_cells.has(cell):
		return MapObject.Type.BARREL
	if spring_cells.has(cell):
		return MapObject.Type.SPRING
	if battery_cells.has(cell):
		return MapObject.Type.BATTERY
	if portal_exits.has(cell):
		return MapObject.Type.PORTAL
	return MapObject.Type.NONE


## 環境オブジェクトを置けるマスか（盤の中で、入れる地形で、まだ何も置かれていない）。
func can_place_object(cell: Vector2i) -> bool:
	return is_walkable(cell) and object_at(cell) == MapObject.Type.NONE


## 起爆樽を置く。置けなければ偽。
func add_barrel(cell: Vector2i) -> bool:
	if not can_place_object(cell):
		return false
	barrel_cells.append(cell)
	walkable_revision += 1
	return true


func remove_barrel(cell: Vector2i) -> void:
	if barrel_cells.has(cell):
		barrel_cells.erase(cell)
		walkable_revision += 1


## 回復の泉を置く。置けなければ偽。
func add_spring(cell: Vector2i) -> bool:
	if not can_place_object(cell):
		return false
	spring_cells.append(cell)
	return true


## 互いを行き先にするポータルを 2 つ置く。どちらかが置けなければ、どちらも置かずに偽。
func add_battery(cell: Vector2i) -> bool:
	if not can_place_object(cell):
		return false
	battery_cells.append(cell)
	return true


func add_portal_pair(a: Vector2i, b: Vector2i) -> bool:
	if a == b or not can_place_object(a) or not can_place_object(b):
		return false
	portal_exits[a] = b
	portal_exits[b] = a
	return true


## そのマスのポータルの行き先（対になるポータルのマス）。ポータルでなければ NO_CELL。
## 行き先に駒がいて使えないかどうかは、Battle.portal_exit() が見る。
func portal_exit(cell: Vector2i) -> Vector2i:
	return portal_exits.get(cell, NO_CELL)


## 盤の上の効果を置き、番号を振る。置けるかどうかは呼ぶ側（FieldEffects）が確かめる。
func add_field_effect(effect: FieldEffect) -> void:
	effect.id = _next_field_effect_id
	_next_field_effect_id += 1
	field_effects.append(effect)
	if effect.type == FieldEffect.Type.BARRICADE:
		_barricades[effect.center] = effect.id
		walkable_revision += 1


func remove_field_effect(effect: FieldEffect) -> void:
	field_effects.erase(effect)
	if effect.type == FieldEffect.Type.BARRICADE:
		_barricades.erase(effect.center)
		walkable_revision += 1


func field_effect_by_id(effect_id: int) -> FieldEffect:
	for effect in field_effects:
		if effect.id == effect_id:
			return effect
	return null


## そのマスにある効果（番号の小さい順）。無ければ空。
func field_effects_at(cell: Vector2i) -> Array[FieldEffect]:
	var result: Array[FieldEffect] = []
	for effect in field_effects:
		if effect.cells.has(cell):
			result.append(effect)
	return result


## そのマスの盾。無ければ null。
func barricade_at(cell: Vector2i) -> FieldEffect:
	if not _barricades.has(cell):
		return null
	return field_effect_by_id(_barricades[cell])


## 盾が 1 つでもあるか（射線を調べずに済ませるため）。
func has_barricades() -> bool:
	return not _barricades.is_empty()


## マスを「上の行から、左の列から」の順に並べるときの比較。
static func in_reading_order(a: Vector2i, b: Vector2i) -> bool:
	return a.y < b.y or (a.y == b.y and a.x < b.x)


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
