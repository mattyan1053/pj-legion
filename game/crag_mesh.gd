extends RefCounted
## 岩山（StageLook.CRAG）の形をコードで作る。ノードに依存しない。
##
## 隣り合う（辺で接する）障害物のマスのかたまりを、1 つの岩山に見せる。かたまりの内側ほど高く、縁は低い崖で終わる。
## - 形は、マスを SUBDIV x SUBDIV に分けた格子の高さ。高さは「通れるマス（と盤の外）までの距離」で決め、ノイズで崩す。
##   格子の点の高さとずれは、点の場所だけで決まる（種つき）。隣のマスとの継ぎ目は、同じ点を同じ場所に置くので隙間が出ない。
## - かたまりの縁は、マスの境目から少し内へ下がった肩（EDGE_INSET）から、境目の地面へ落ちる崖。
##   通れないマスと通れるマスの境目が、崖の裾として見える。裾は境目からはみ出さない（BASE_OUTSET まで）。
## - 斜めにだけ接するマスどうしは、つなげない（通れる 2 マスの間を、岩がふさいで見えないように）。
## - 面ごとに平らな影と色（ローポリの岩）。上を向いた面は明るい色、崖は暗い色、低いところほど暗い。
## - 結晶は、かたまりの内側の高いところに、ところどころ生やす（1 マスだけの障害物は、小さい岩に結晶 1 つ）。
##
## 駒やマウスの下のマスの手前で透かす（board_view.gd の update_occlusion）ため、形はマスごとに分けて返す
## （1 マスの形 = 岩の面と結晶の面の 2 つ。同じ形の結晶も、マスの形の中へまとめて、1 マス 1 回で描く）。

const CrystalMesh := preload("res://game/crystal_mesh.gd")

## 1 マスを何個に分けるか。
const SUBDIV := 3
## 縁の肩の高さ、内側の高さの上積み（RISE_REACH マス入ったところで出きる）、いちばん高いところ。
const EDGE_HEIGHT := 0.28
const RISE := 0.8
const RISE_REACH := 1.2
## 深いところ（RISE_REACH より内）の上積み（1 マスあたり）。大きなかたまりの真ん中が峰になる。
const DEEP_RISE := 0.45
const MAX_HEIGHT := 2.2
## 峰: 深いマス（PEAK_DEPTH 以上）から選んで、そこを中心に尖らせる（高さ PEAK、裾の半径 PEAK_RADIUS マス）。
## 峰どうしは PEAK_SPACING マスより離す。
const PEAK := 1.0
const PEAK_RADIUS := 1.5
const PEAK_DEPTH := 1.4
const PEAK_SPACING := 2.6
## 肩をマスの境目から内へ下げる距離と、裾を境目から外へ出す距離（マス）。
const EDGE_INSET := 0.14
## 出っ張った角（かたまりの角）は、もっと下げて丸める。
const CORNER_INSET := 0.24
const BASE_OUTSET := 0.02
## 崖の途中の出っ張り（外へ）の大きさ。
const BULGE := 0.07
## 高さのノイズ（大きなうねり・細かい凹凸）と、格子の点の横のずれ。
const SWELL := 0.4
const BUMP := 0.05
## 縁の肩の高さのばらつき（EDGE_HEIGHT に掛ける幅）。
const EDGE_SPREAD := Vector2(0.7, 1.5)
const JITTER := 0.07
## 結晶の数（かたまりのマス数あたり）と、大きさ（高さ）。
const CRYSTALS_PER_CELL := 0.35
const CRYSTAL_HEIGHT := Vector2(0.6, 0.95)
const LONE_CRYSTAL_HEIGHT := 0.7
const PEAK_CRYSTAL_HEIGHT := 1.1

## 面の色。
const LOW := &"low"  ## 崖の下のほう
const CLIFF := &"cliff"  ## 崖の上のほう
const TOP := &"top"  ## 上を向いた面
const CRYSTAL := &"crystal"  ## 結晶（無ければ生やさない）

var _blocked := {}  # Vector2i -> true
var _size := Vector2i.ZERO
var _seed := 0
var _peaks: Array[Vector2] = []  # 峰（大きなかたまりの内側）
var _knolls: Array[Vector2] = []  # 1 マスだけの障害物の真ん中
var _heights := {}  # Vector2i（格子の点） -> float
var _tops := {}  # [Vector2i（格子の点）, Vector2i（マス）] -> Vector3


## blocked: 障害物のマス（Vector2i の配列）。size: 盤の大きさ。look_seed: 同じ種からは同じ形。
func _init(blocked: Array[Vector2i], size: Vector2i, look_seed: int) -> void:
	for cell in blocked:
		_blocked[cell] = true
	_size = size
	_seed = look_seed
	_peaks = _choose_peaks()
	for cell: Vector2i in _blocked:
		if [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN].all(func(side: Vector2i) -> bool: return not _blocked.has(cell + side)):
			_knolls.append(Vector2(cell) + Vector2(0.5, 0.5))


## マスごとの形（Vector2i -> ArrayMesh）。面 0 が岩（頂点の色つき）、面 1 が結晶（生やしたマスだけ）。
## マテリアルは付けない（呼ぶ側が面ごとに当てる）。colors は LOW・CLIFF・TOP（と CRYSTAL）。
func build(colors: Dictionary) -> Dictionary:
	var crystal_cells := crystal_spots() if colors.has(CRYSTAL) else {}
	var crystal := CrystalMesh.cluster()
	var meshes := {}
	for cell: Vector2i in _blocked:
		var rock := SurfaceTool.new()
		rock.begin(Mesh.PRIMITIVE_TRIANGLES)
		_add_top(rock, cell, colors)
		_add_cliffs(rock, cell, colors)
		var mesh := rock.commit()
		if crystal_cells.has(cell):
			var shards := SurfaceTool.new()
			shards.begin(Mesh.PRIMITIVE_TRIANGLES)
			for place: Transform3D in crystal_cells[cell]:
				shards.append_from(crystal, 0, place)
			shards.commit(mesh)
		meshes[cell] = mesh
	return meshes


## 結晶を生やす場所（Vector2i -> Array[Transform3D]）。かたまりごとに、内側の高いマスから選ぶ。
func crystal_spots() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed * 7919 + 17
	var spots := {}
	for group in groups():
		var count := maxi(1, roundi(group.size() * CRYSTALS_PER_CELL))
		# 内側（通れるマスから遠い）ほど先に。同じ深さなら種で混ぜる。
		var ranked: Array = []
		for cell: Vector2i in group:
			ranked.append([-_depth(cell) + rng.randf() * 0.6, cell])
		ranked.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		var taken: Array[Vector2i] = []
		for entry: Array in ranked:
			var cell: Vector2i = entry[1]
			if taken.size() >= count:
				break
			# 隣り合うマスに続けて生やさない（ところどころに見えるように）。
			if taken.any(func(other: Vector2i) -> bool: return absi(other.x - cell.x) <= 1 and absi(other.y - cell.y) <= 1):
				continue
			taken.append(cell)
			spots[cell] = _crystal_places(cell, group.size() == 1, rng)
	# 峰の上には、大きな結晶。
	for top in _peaks:
		var cell := Vector2i(floori(top.x), floori(top.y))
		var i := roundi(top.x * SUBDIV)
		var j := roundi(top.y * SUBDIV)
		var ground := _top_point(i, j, cell)
		var shape := Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(0.6, 1.0, 0.6) * PEAK_CRYSTAL_HEIGHT)
		var places: Array = spots.get(cell, [])
		places.append(Transform3D(shape, ground - Vector3(0, 0.12, 0)))
		spots[cell] = places
	return spots


## 辺で接する障害物のかたまり（Array[Vector2i] の配列）。
func groups() -> Array[Array]:
	var seen := {}
	var found: Array[Array] = []
	for start: Vector2i in _blocked:
		if seen.has(start):
			continue
		var group: Array[Vector2i] = []
		var queue: Array[Vector2i] = [start]
		seen[start] = true
		while not queue.is_empty():
			var cell: Vector2i = queue.pop_back()
			group.append(cell)
			for side: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var next := cell + side
				if _blocked.has(next) and not seen.has(next):
					seen[next] = true
					queue.append(next)
		found.append(group)
	return found


## 格子の点 (i, j) の高さ（地面からの高さ、マス）。縁の点は EDGE_HEIGHT 前後。
func height_at(i: int, j: int) -> float:
	var key := Vector2i(i, j)
	if not _heights.has(key):
		_heights[key] = _height_at(i, j)
	return _heights[key]


func _height_at(i: int, j: int) -> float:
	var at := Vector2(float(i), float(j)) / SUBDIV
	var reach := _distance_to_open(at)
	var rise := smoothstep(0.0, RISE_REACH, reach)
	var deep := DEEP_RISE * clampf(reach - RISE_REACH * 0.8, 0.0, 2.0)
	# 尾根のノイズ（谷と稜線が交互に出る）。
	var ridge := 1.0 - absf(_value_noise(at * 0.8) * 2.0 - 1.0)
	var swell := (ridge - 0.5) * 2.0 * SWELL * rise
	var bump := (_hash(i, j, 1) - 0.5) * 2.0 * BUMP * (0.4 + 0.6 * rise)
	var peak := 0.0
	for top in _peaks:
		peak = maxf(peak, PEAK * clampf(1.0 - at.distance_to(top) / PEAK_RADIUS, 0.0, 1.0))
	# 1 マスだけの障害物も、真ん中を尖らせる（平たい板に見えないように）。
	for top in _knolls:
		peak = maxf(peak, PEAK * clampf(1.0 - at.distance_to(top) / 0.5, 0.0, 1.0))
	return clampf(EDGE_HEIGHT + RISE * rise + deep + swell + bump + peak * rise, EDGE_HEIGHT * 0.7, MAX_HEIGHT)


## 峰の場所（マスの単位の座標）。深いマスを深い順に、間を空けて。
func _choose_peaks() -> Array[Vector2]:
	var deep: Array = []
	for cell: Vector2i in _blocked:
		var depth := _depth(cell)
		if depth >= PEAK_DEPTH:
			deep.append([-depth - _hash(cell.x, cell.y, 30) * 0.5, cell])
	deep.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var peaks: Array[Vector2] = []
	for entry: Array in deep:
		var cell: Vector2i = entry[1]
		var at := Vector2(cell) + Vector2(0.3 + 0.4 * _hash(cell.x, cell.y, 31), 0.3 + 0.4 * _hash(cell.x, cell.y, 32))
		if peaks.all(func(other: Vector2) -> bool: return other.distance_to(at) >= PEAK_SPACING):
			peaks.append(at)
	return peaks


## 縁の点 (i, j) の肩の高さ。
func edge_height(i: int, j: int) -> float:
	var at := Vector2(float(i), float(j)) / SUBDIV
	var spread := lerpf(EDGE_SPREAD.x, EDGE_SPREAD.y, _value_noise(at * 1.6 + Vector2(7.3, 2.1)))
	return EDGE_HEIGHT * spread + (_hash(i, j, 3) - 0.5) * 0.08


## 一番近い通れるマス（盤の外も）までの距離（マス）。
func _distance_to_open(at: Vector2) -> float:
	var best := 4.0
	var base := Vector2i(floori(at.x), floori(at.y))
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var cell := base + Vector2i(dx, dy)
			if _is_blocked(cell):
				continue
			var nearest := Vector2(clampf(at.x, cell.x, cell.x + 1.0), clampf(at.y, cell.y, cell.y + 1.0))
			best = minf(best, at.distance_to(nearest))
	return best


## マスの深さ（マスの中心から通れるマスまでの距離）。
func _depth(cell: Vector2i) -> float:
	return _distance_to_open(Vector2(cell) + Vector2(0.5, 0.5))


func _is_blocked(cell: Vector2i) -> bool:
	return _blocked.has(cell)


## 格子の点 (i, j) を、マス cell の側から見た上の面の場所。
## 縁の点は内へ下げる。向きは、cell と辺でつながる障害物のマス（点のまわりの 2x2 の中）の、通れる側の向きの和。
func _top_point(i: int, j: int, cell: Vector2i) -> Vector3:
	var key := [Vector2i(i, j), cell]
	if not _tops.has(key):
		_tops[key] = _find_top_point(i, j, cell)
	return _tops[key]


func _find_top_point(i: int, j: int, cell: Vector2i) -> Vector3:
	var edge := _outward(i, j, cell)
	var outward := Vector2(edge.x, edge.y)
	var x := float(i) / SUBDIV
	var z := float(j) / SUBDIV
	if outward != Vector2.ZERO:
		var inset := CORNER_INSET if edge.z == 1.0 and outward.x != 0.0 and outward.y != 0.0 else EDGE_INSET
		x -= outward.x * inset
		z -= outward.y * inset
		# 縁に沿う向きにだけ、少しずらす（縁の線がまっすぐすぎないように）。
		var along := Vector2(absf(outward.y), absf(outward.x))
		var shift := (_hash(i, j, 2) - 0.5) * 2.0 * JITTER * 0.6
		x += along.x * shift
		z += along.y * shift
		return Vector3(x, edge_height(i, j), z)
	x += (_hash(i, j, 4) - 0.5) * 2.0 * JITTER
	z += (_hash(i, j, 5) - 0.5) * 2.0 * JITTER
	return Vector3(x, height_at(i, j), z)


## 点 (i, j) で、cell の側のかたまりの縁が外へ向く向き（x と y に、各軸 -1・0・1。縁でなければ 0）と、
## 点のまわりで cell とつながる障害物のマスの数（z。1 で両軸が外向きなら、出っ張った角）。
func _outward(i: int, j: int, cell: Vector2i) -> Vector3:
	var xs: Array = [floori(float(i) / SUBDIV) - 1, floori(float(i) / SUBDIV)] if i % SUBDIV == 0 else [floori(float(i) / SUBDIV)]
	var zs: Array = [floori(float(j) / SUBDIV) - 1, floori(float(j) / SUBDIV)] if j % SUBDIV == 0 else [floori(float(j) / SUBDIV)]
	var around: Array[Vector2i] = []
	for z: int in zs:
		for x: int in xs:
			around.append(Vector2i(x, z))
	# cell と辺でつながる障害物のマス（点のまわりの中で）。
	var group: Array[Vector2i] = [cell]
	var grew := true
	while grew:
		grew = false
		for other in around:
			if other in group or not _is_blocked(other):
				continue
			if group.any(func(g: Vector2i) -> bool: return absi(g.x - other.x) + absi(g.y - other.y) == 1):
				group.append(other)
				grew = true
	var sum := Vector2.ZERO
	for g in group:
		for other in around:
			if absi(g.x - other.x) + absi(g.y - other.y) == 1 and not _is_blocked(other):
				sum += Vector2(other - g)
	return Vector3(signf(sum.x), signf(sum.y), group.size())


## マス cell の上の面（SUBDIV x SUBDIV の四角を、三角 2 枚ずつ）。
func _add_top(st: SurfaceTool, cell: Vector2i, colors: Dictionary) -> void:
	for b in SUBDIV:
		for a in SUBDIV:
			var i := cell.x * SUBDIV + a
			var j := cell.y * SUBDIV + b
			var p00 := _top_point(i, j, cell)
			var p10 := _top_point(i + 1, j, cell)
			var p01 := _top_point(i, j + 1, cell)
			var p11 := _top_point(i + 1, j + 1, cell)
			if _hash(i, j, 6) < 0.5:
				_face(st, p00, p10, p11, colors, i, j, 0)
				_face(st, p00, p11, p01, colors, i, j, 1)
			else:
				_face(st, p00, p10, p01, colors, i, j, 0)
				_face(st, p10, p11, p01, colors, i, j, 1)


## マス cell の、通れるマスに面した辺の崖（肩 → 途中の出っ張り → 裾）。
func _add_cliffs(st: SurfaceTool, cell: Vector2i, colors: Dictionary) -> void:
	for side: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if _is_blocked(cell + side):
			continue
		# 辺の両端の格子の点（外から見て左から右へ、の順は _face が面の向きで直す）。
		var start: Vector2i
		var step: Vector2i
		match side:
			Vector2i.UP:
				start = Vector2i(cell.x * SUBDIV, cell.y * SUBDIV)
				step = Vector2i(1, 0)
			Vector2i.DOWN:
				start = Vector2i(cell.x * SUBDIV, (cell.y + 1) * SUBDIV)
				step = Vector2i(1, 0)
			Vector2i.LEFT:
				start = Vector2i(cell.x * SUBDIV, cell.y * SUBDIV)
				step = Vector2i(0, 1)
			_:
				start = Vector2i((cell.x + 1) * SUBDIV, cell.y * SUBDIV)
				step = Vector2i(0, 1)
		for k in SUBDIV:
			var a := start + step * k
			var b := a + step
			var top_a := _top_point(a.x, a.y, cell)
			var top_b := _top_point(b.x, b.y, cell)
			var mid_a := _mid_point(a, cell)
			var mid_b := _mid_point(b, cell)
			var base_a := _base_point(a, cell)
			var base_b := _base_point(b, cell)
			_face(st, top_a, top_b, mid_b, colors, a.x, a.y, 2, Vector3(side.x, 0, side.y))
			_face(st, top_a, mid_b, mid_a, colors, a.x, a.y, 3, Vector3(side.x, 0, side.y))
			_face(st, mid_a, mid_b, base_b, colors, a.x, a.y, 4, Vector3(side.x, 0, side.y))
			_face(st, mid_a, base_b, base_a, colors, a.x, a.y, 5, Vector3(side.x, 0, side.y))


func _mid_point(p: Vector2i, cell: Vector2i) -> Vector3:
	var top := _top_point(p.x, p.y, cell)
	var base := _base_point(p, cell)
	var edge := _outward(p.x, p.y, cell)
	var bulge := BULGE * (_hash(p.x, p.y, 7) - 0.3)
	var share := 0.4 + 0.2 * _hash(p.x, p.y, 8)
	var at := base.lerp(top, share)
	return at + Vector3(edge.x, 0.0, edge.y) * bulge


func _base_point(p: Vector2i, cell: Vector2i) -> Vector3:
	var edge := _outward(p.x, p.y, cell)
	var outward := Vector2(edge.x, edge.y)
	return Vector3(float(p.x) / SUBDIV + outward.x * BASE_OUTSET, -0.02, float(p.y) / SUBDIV + outward.y * BASE_OUTSET)


## 三角 1 枚。面の法線で色を決め、頂点で共有しない（面ごとに平らな影）。
## facing（崖の外向き）を渡したら、表がその向きになるように並べる。渡さなければ上向きを表に。
func _face(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, colors: Dictionary, i: int, j: int, salt: int, facing := Vector3.UP) -> void:
	var normal := (b - a).cross(c - a)
	if normal.length_squared() < 1e-10:
		return
	normal = normal.normalized()
	if normal.dot(facing) < 0.0:
		var swap := b
		b = c
		c = swap
		normal = -normal
	var up := clampf(normal.y, 0.0, 1.0)
	var high := clampf((a.y + b.y + c.y) / 3.0 / MAX_HEIGHT, 0.0, 1.0)
	var cliff: Color = (colors[LOW] as Color).lerp(colors[CLIFF], clampf(high * 1.6, 0.0, 1.0))
	var color := cliff.lerp(colors[TOP], smoothstep(0.55, 0.85, up))
	color = color.darkened((_hash(i, j, 10 + salt) - 0.5) * 0.16)
	st.set_color(color)
	st.set_normal(normal)
	# Godot は時計回りを表とする（外から見て反時計回りの a → b → c を、入れ替えて置く）。
	st.add_vertex(a)
	st.set_color(color)
	st.set_normal(normal)
	st.add_vertex(c)
	st.set_color(color)
	st.set_normal(normal)
	st.add_vertex(b)


## マス cell に生やす結晶の置き方。上の面の高さに合わせて、少し埋めて立てる。
func _crystal_places(cell: Vector2i, lone: bool, rng: RandomNumberGenerator) -> Array[Transform3D]:
	var places: Array[Transform3D] = []
	var a := rng.randi_range(1, SUBDIV - 1)
	var b := rng.randi_range(1, SUBDIV - 1)
	if lone:
		a = SUBDIV / 2
		b = SUBDIV / 2
	var i := cell.x * SUBDIV + a
	var j := cell.y * SUBDIV + b
	var ground := _top_point(i, j, cell)
	var height := LONE_CRYSTAL_HEIGHT if lone else rng.randf_range(CRYSTAL_HEIGHT.x, CRYSTAL_HEIGHT.y)
	var lean := Basis(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized(), deg_to_rad(rng.randf_range(0, 12)))
	var shape := lean * Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(0.55, 1.0, 0.55) * height)
	places.append(Transform3D(shape, ground - Vector3(0, 0.08, 0)))
	return places


## 点ごとの決まった乱数（0〜1）。
func _hash(i: int, j: int, salt: int) -> float:
	var h := hash([i, j, salt, _seed])
	return float(h & 0xffff) / 65535.0


## なめらかな値のノイズ（0〜1）。マスの単位の座標で。
func _value_noise(at: Vector2) -> float:
	var base := Vector2i(floori(at.x), floori(at.y))
	var f := at - Vector2(base)
	f = f * f * (Vector2(3, 3) - 2.0 * f)
	var v00 := _hash(base.x, base.y, 20)
	var v10 := _hash(base.x + 1, base.y, 20)
	var v01 := _hash(base.x, base.y + 1, 20)
	var v11 := _hash(base.x + 1, base.y + 1, 20)
	return lerpf(lerpf(v00, v10, f.x), lerpf(v01, v11, f.x), f.y)
