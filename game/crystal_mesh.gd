extends RefCounted
## 結晶の形をコードで作る。
##
## 六角柱の上に六角錐を載せた、面ごとに平らな影の付く形。
## 大きさは 1 本あたり「半径 1・高さ 1」なので、置くときに scale で合わせる。

const SIDES := 6
const BODY_HEIGHT := 0.7


static func build() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_crystal(st, Transform3D.IDENTITY)
	# 頂点を共有しないので、法線は面ごとになる（角張った見た目）。
	st.generate_normals()
	return st.commit()


## 結晶の群れ（太い 1 本のまわりに、傾いた細いものが並ぶ）。景色と、障害物の上の結晶に使う。
## 高さ 1・差し渡しおよそ 1 に収まる。形は決まっている（同じ形を向きと大きさを変えて並べる）。
static func cluster() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_crystal(st, Transform3D(Basis.from_scale(Vector3(0.2, 1.0, 0.2)), Vector3.ZERO))
	# [向き（度）, 外へ出す距離, 傾き（度）, 高さ, 太さ]
	for spec: Array in [[20.0, 0.16, 24.0, 0.72, 0.15], [140.0, 0.18, 30.0, 0.58, 0.13], [250.0, 0.15, 20.0, 0.66, 0.14], [320.0, 0.3, 46.0, 0.36, 0.1], [200.0, 0.32, 52.0, 0.3, 0.09]]:
		var toward := Vector3.RIGHT.rotated(Vector3.UP, deg_to_rad(spec[0]))
		var axis := toward.cross(Vector3.UP).normalized()
		var basis := Basis(axis, -deg_to_rad(spec[2])) * Basis.from_scale(Vector3(spec[4], spec[3], spec[4]))
		_add_crystal(st, Transform3D(basis, toward * float(spec[1])))
	st.generate_normals()
	return st.commit()


## 結晶 1 本を、place で動かして足す。
static func _add_crystal(st: SurfaceTool, place: Transform3D) -> void:
	var ring: Array[Vector3] = []
	for i in SIDES:
		var angle := TAU * i / SIDES
		ring.append(Vector3(cos(angle), 0.0, sin(angle)))
	var tip := Vector3(0.0, 1.0, 0.0)
	var up := Vector3(0.0, BODY_HEIGHT, 0.0)

	for i in SIDES:
		var a := ring[i]
		var b := ring[(i + 1) % SIDES]
		# 側面（四角を三角 2 枚で）。
		_triangle(st, place * a, place * (b + up), place * b)
		_triangle(st, place * a, place * (a + up), place * (b + up))
		# 先端
		_triangle(st, place * (a + up), place * tip, place * (b + up))


## a → b → c が外から見て反時計回りになるように渡す。
## Godot は時計回りを表とするので、ここで順を入れ替えて置く。
static func _triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(b)


## 正八面体（上下に尖った菱形）。中立の駒のコアに使う。半径 1。
static func octahedron() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring: Array[Vector3] = [Vector3.RIGHT, Vector3.BACK, Vector3.LEFT, Vector3.FORWARD]
	for i in 4:
		var a := ring[i]
		var b := ring[(i + 1) % 4]
		_triangle(st, a, Vector3.UP, b)
		_triangle(st, a, b, Vector3.DOWN)
	st.generate_normals()
	return st.commit()
