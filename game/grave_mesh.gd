extends RefCounted
## 墓標の形をコードで作る（古戦場の盤の外の景色。stage_look.gd）。素材は使わない。
##
## 傾いた石の板が 3 枚、少しずつ離れて立つ。板は、四角い胴の上に山形の頭。面ごとに平らな影が付く。
## 高さ 1・差し渡しおよそ 1.4 に収まる。形は決まっている（同じ形を、向きと大きさを変えて並べる）。


static func cluster() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# [置く所（x, z）, 向き（度）, 傾き（度）, 高さ, 幅]
	for spec: Array in [[Vector2(0.0, 0.0), 8.0, -6.0, 1.0, 0.42], [Vector2(-0.48, 0.2), -14.0, 12.0, 0.72, 0.36], [Vector2(0.46, -0.16), 20.0, 5.0, 0.56, 0.32]]:
		var at: Vector2 = spec[0]
		var basis := Basis(Vector3.UP, deg_to_rad(spec[1])) * Basis(Vector3.RIGHT, deg_to_rad(spec[2]))
		_add_slab(st, Transform3D(basis, Vector3(at.x, 0.0, at.y)), spec[3], spec[4])
	st.generate_normals()
	return st.commit()


## 石の板 1 枚（幅 width、高さ height、厚さは幅の 3 分の 1）。地面に少し埋めて、傾けても裾が浮かないようにする。
static func _add_slab(st: SurfaceTool, place: Transform3D, height: float, width: float) -> void:
	var half := width / 2.0
	var deep := width / 6.0
	var shoulder := height * 0.8
	# 前から見た輪郭（右回り）: 左下、右下、右肩、頭、左肩。
	var outline: Array[Vector2] = [Vector2(-half, -0.1), Vector2(half, -0.1), Vector2(half, shoulder), Vector2(0.0, height), Vector2(-half, shoulder)]
	var front: Array[Vector3] = []
	var back: Array[Vector3] = []
	for point in outline:
		front.append(place * Vector3(point.x, point.y, deep))
		back.append(place * Vector3(point.x, point.y, -deep))
	for i in range(1, outline.size() - 1):
		_triangle(st, front[0], front[i], front[i + 1])
		_triangle(st, back[0], back[i + 1], back[i])
	for i in outline.size():
		var next := (i + 1) % outline.size()
		_triangle(st, front[i], back[i], back[next])
		_triangle(st, front[i], back[next], front[next])


## a → b → c が外から見て反時計回りになるように渡す（Godot は時計回りを表とするので、ここで入れ替える）。
static func _triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(b)
