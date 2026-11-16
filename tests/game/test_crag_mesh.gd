extends "res://tests/base_test.gd"
## 岩山の形（game/crag_mesh.gd）。辺で接する障害物のかたまりを 1 つの岩山にし、通れるマスにはみ出さない。

const CragMesh := preload("res://game/crag_mesh.gd")

const COLORS := {CragMesh.LOW: Color.BLACK, CragMesh.CLIFF: Color.GRAY, CragMesh.TOP: Color.WHITE, CragMesh.CRYSTAL: Color.BLUE}
## 双子結晶の真ん中のような大きなかたまり、結晶の渓谷のような 2 行の帯、1 マスだけ、斜めにだけ接する 2 マス。
const ROWS: Array[String] = [
	"...........",
	".######....",
	".######..#.",
	".######....",
	".######.#..",
	"........#..",
	"#.######...",
	".#######...",
	"...........",
]


func test_every_obstacle_gets_its_own_piece() -> void:
	var blocked := _blocked(ROWS)
	var meshes := _crag(ROWS).build(COLORS)
	assert_eq(meshes.size(), blocked.size(), "障害物のマスごとに 1 つの形")
	for cell: Vector2i in blocked:
		assert_true(meshes.has(cell), "マス %s の形が無い" % cell)


func test_groups_follow_side_neighbours_only() -> void:
	# 斜めにだけ接するマス（左下の 1 マスと、帯）は別のかたまり。
	var sizes: Array = _crag(ROWS).groups().map(func(group: Array) -> int: return group.size())
	sizes.sort()
	assert_eq(sizes, [1, 1, 2, 13, 24])


func test_rock_stays_off_open_cells() -> void:
	# 岩は、通れるマスへ、裾の分しかはみ出さない（境目がひと目で分かる）。
	var blocked := _blocked(ROWS)
	var meshes := _crag(ROWS).build(COLORS)
	var margin := CragMesh.BASE_OUTSET + CragMesh.BULGE + 0.001
	for cell: Vector2i in meshes:
		for v in _vertices(meshes[cell]):
			var at := Vector2(v.x, v.z)
			var nearest := 99.0
			for other in blocked:
				var inside := Vector2(clampf(at.x, other.x, other.x + 1.0), clampf(at.y, other.y, other.y + 1.0))
				nearest = minf(nearest, at.distance_to(inside))
			assert_true(nearest <= margin, "マス %s の岩が通れるマスへはみ出す: %s" % [cell, v])
			assert_true(v.y >= -0.05 and v.y <= CragMesh.MAX_HEIGHT + 0.001, "マス %s の岩の高さ: %s" % [cell, v])


func test_inside_is_higher_than_the_rim() -> void:
	# かたまりの内側ほど高い。縁は低い崖。1 マスだけの障害物は、大きなかたまりの真ん中より低い。
	var meshes := _crag(ROWS).build(COLORS)
	var inner := _top(meshes[Vector2i(3, 2)])
	var rim := _top(meshes[Vector2i(1, 1)])
	var lone := _top(meshes[Vector2i(9, 2)])
	assert_true(inner > rim, "内側 %.2f が縁 %.2f より高くない" % [inner, rim])
	assert_true(inner > lone, "内側 %.2f が 1 マスの岩 %.2f より高くない" % [inner, lone])
	assert_true(lone > CragMesh.EDGE_HEIGHT, "1 マスの岩が平たい（%.2f）" % lone)


func test_neighbours_share_their_seam() -> void:
	# 隣り合うマスは、境目の点を同じ場所に置く（継ぎ目に隙間が出ない）。
	var crag := _crag(ROWS)
	for cell: Vector2i in [Vector2i(2, 2), Vector2i(3, 6), Vector2i(8, 4)]:
		var right := cell + Vector2i.RIGHT
		var below := cell + Vector2i.DOWN
		for k in CragMesh.SUBDIV + 1:
			var i := (cell.x + 1) * CragMesh.SUBDIV
			var j := cell.y * CragMesh.SUBDIV + k
			if _blocked(ROWS).has(right):
				assert_eq(crag._top_point(i, j, cell), crag._top_point(i, j, right), "%s と右の継ぎ目" % cell)
			i = cell.x * CragMesh.SUBDIV + k
			j = (cell.y + 1) * CragMesh.SUBDIV
			if _blocked(ROWS).has(below):
				assert_eq(crag._top_point(i, j, cell), crag._top_point(i, j, below), "%s と下の継ぎ目" % cell)


func test_crystals_grow_here_and_there() -> void:
	var crag := _crag(ROWS)
	var spots := crag.crystal_spots()
	assert_true(spots.has(Vector2i(9, 2)), "1 マスだけの障害物に結晶が無い")
	var in_big := spots.keys().filter(func(cell: Vector2i) -> bool: return cell.x >= 1 and cell.x <= 6 and cell.y >= 1 and cell.y <= 4)
	assert_between(in_big.size(), 2, 10, "大きなかたまりの結晶の数")
	# 結晶の色が無ければ、生やさない。
	var plain := COLORS.duplicate()
	plain.erase(CragMesh.CRYSTAL)
	for mesh: ArrayMesh in crag.build(plain).values():
		assert_eq(mesh.get_surface_count(), 1, "結晶の色が無いのに結晶がある")


func test_same_seed_gives_the_same_shape() -> void:
	var a := _crag(ROWS, 3).build(COLORS)
	var b := _crag(ROWS, 3).build(COLORS)
	var c := _crag(ROWS, 4).build(COLORS)
	var cell := Vector2i(3, 2)
	assert_eq(_vertices(a[cell]), _vertices(b[cell]))
	assert_ne(_vertices(a[cell]), _vertices(c[cell]))


func _crag(rows: Array[String], look_seed := 1) -> CragMesh:
	return CragMesh.new(_blocked(rows), Vector2i(rows[0].length(), rows.size()), look_seed)


func _blocked(rows: Array[String]) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in rows.size():
		for x in rows[y].length():
			if rows[y][x] == "#":
				cells.append(Vector2i(x, y))
	return cells


## 岩（面 0）のいちばん高いところ。
func _top(mesh: ArrayMesh) -> float:
	var top := 0.0
	for v: Vector3 in _vertices(mesh):
		top = maxf(top, v.y)
	return top


func _vertices(mesh: ArrayMesh) -> PackedVector3Array:
	return mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
