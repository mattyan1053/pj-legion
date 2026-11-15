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
		_triangle(st, a, b + up, b)
		_triangle(st, a, a + up, b + up)
		# 先端
		_triangle(st, a + up, tip, b + up)

	# 頂点を共有しないので、法線は面ごとになる（角張った見た目）。
	st.generate_normals()
	return st.commit()


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
