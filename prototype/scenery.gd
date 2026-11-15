extends Node3D
## 盤の外の景色（森と岩山）。戦う範囲の外も地続きの場所に見えるように置く。見た目だけで、ルールには関わらない。
##
## 置き方の決まり（layout。検査が確かめる）:
## - 盤の端から CLEAR マスまでは何も置かない（境目が分かり、端の駒に重ならない）。
## - 高さは、盤の端からの距離 × HEIGHT_PER_DISTANCE まで。カメラはいちばん浅い角度でも約 35 度で見下ろすので、
##   これより低ければ、盤の中のものを隠さない（カメラにも当たらない）。近くは低い木だけ、遠くほど大きい岩山になる。
## - 盤の端から REACH マスより先には置かない（その先は霞で見えない）。

const TREE_SCENES: Array[PackedScene] = [
	preload("res://assets/kaykit/medieval-hexagon/trees_A_small.gltf"),
	preload("res://assets/kaykit/medieval-hexagon/trees_B_small.gltf"),
]
const MOUNTAIN_SCENE := preload("res://assets/kaykit/medieval-hexagon/mountain_A.gltf")
## 素材の高さ（大きさ 1 のとき）。
const TREE_HEIGHT := 1.11
const MOUNTAIN_HEIGHT := 1.43

const CLEAR := 2.0
const REACH := 66.0
const HEIGHT_PER_DISTANCE := 0.5
## 木と岩山の候補を置く間隔（マス）。
const TREE_SPACING := 2.1
const MOUNTAIN_SPACING := 4.6
## 岩山を置き始める距離。
const MOUNTAIN_FROM := 7.0
## まとめて描く区画の大きさ（マス）。区画ごとに、見えていなければ描かない。
const CHUNK := 34.0
## 盤の端からこの距離までの区画だけ、影を落とす。
const SHADOW_WITHIN := 30.0
## 景色の色に掛ける色。盤の上の木立や岩山より沈ませて、盤の上のものより目立たないようにする。
const TINT := Color(0.84, 0.88, 0.86)

enum Kind { TREE_A, TREE_B, MOUNTAIN }


## 置くもの。{ kind, position: Vector3, scale: float, yaw: float, distance: float（盤の端から）} の配列。
## 同じ盤の大きさと種からは、同じ並びになる。
static func layout(board_size: Vector2i, look_seed: int) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = look_seed
	var woods := FastNoiseLite.new()
	woods.seed = look_seed
	woods.frequency = 0.055
	var ridges := FastNoiseLite.new()
	ridges.seed = look_seed + 1
	ridges.frequency = 0.032

	var items: Array[Dictionary] = []
	var size := Vector2(board_size)
	var area := Rect2(Vector2.ONE * -REACH, size + Vector2.ONE * 2.0 * REACH)

	var z := area.position.y
	while z < area.end.y:
		var x := area.position.x
		while x < area.end.x:
			var at := Vector2(x, z) + Vector2(rng.randf(), rng.randf()) * MOUNTAIN_SPACING * 0.8
			x += MOUNTAIN_SPACING
			var distance := distance_outside(at, size)
			if distance < MOUNTAIN_FROM or distance > REACH:
				continue
			if ridges.get_noise_2d(at.x, at.y) < 0.12:
				continue
			# 遠いほど大きい。高さの決まりも守る。
			var grown := lerpf(1.3, 5.0, clampf((distance - MOUNTAIN_FROM) / 40.0, 0.0, 1.0)) * rng.randf_range(0.75, 1.2)
			grown = minf(grown, distance * HEIGHT_PER_DISTANCE / MOUNTAIN_HEIGHT)
			items.append(_item(Kind.MOUNTAIN, at, grown, rng.randf() * TAU, distance))
		z += MOUNTAIN_SPACING

	z = area.position.y
	while z < area.end.y:
		var x := area.position.x
		while x < area.end.x:
			var at := Vector2(x, z) + Vector2(rng.randf(), rng.randf()) * TREE_SPACING * 0.9
			x += TREE_SPACING
			var distance := distance_outside(at, size)
			if distance < CLEAR or distance > REACH:
				continue
			# 森はかたまりで生える。盤の近くはまばらに、離れるほど濃く。岩山の並ぶところは避ける。
			var wood := woods.get_noise_2d(at.x, at.y)
			var needed := lerpf(0.22, -0.08, clampf((distance - CLEAR) / 22.0, 0.0, 1.0))
			if wood < needed or ridges.get_noise_2d(at.x, at.y) > 0.2:
				continue
			var grown := lerpf(0.62, 1.25, clampf(distance / 30.0, 0.0, 1.0)) * rng.randf_range(0.85, 1.2)
			grown = minf(grown, distance * HEIGHT_PER_DISTANCE / TREE_HEIGHT)
			var kind := Kind.TREE_A if rng.randf() < 0.5 else Kind.TREE_B
			items.append(_item(kind, at, grown, rng.randf() * TAU, distance))
		z += TREE_SPACING
	return items


## 盤（0, 0）〜 size の外へ、どれだけ離れているか（マス）。中なら 0。
static func distance_outside(at: Vector2, size: Vector2) -> float:
	return (at - at.clamp(Vector2.ZERO, size)).length()


## 置くものの高さ（マス）。
static func height_of(item: Dictionary) -> float:
	return (MOUNTAIN_HEIGHT if item.kind == Kind.MOUNTAIN else TREE_HEIGHT) * float(item.scale)


func setup(board_size: Vector2i, look_seed: int) -> void:
	var meshes := {
		Kind.TREE_A: _mesh_of(TREE_SCENES[0]),
		Kind.TREE_B: _mesh_of(TREE_SCENES[1]),
		Kind.MOUNTAIN: _mesh_of(MOUNTAIN_SCENE),
	}
	var materials := {}
	for kind: Kind in meshes:
		var material: BaseMaterial3D = (meshes[kind] as Mesh).surface_get_material(0).duplicate()
		material.albedo_color = material.albedo_color * TINT
		materials[kind] = material
	# 区画と種類ごとにまとめる（[区画, 種類] -> 置くものの配列）。
	var groups := {}
	for item in layout(board_size, look_seed):
		var at: Vector3 = item.position
		var key := [Vector2i(floori(at.x / CHUNK), floori(at.z / CHUNK)), item.kind]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(item)

	for key: Array in groups:
		var items: Array = groups[key]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = meshes[key[1]]
		multimesh.instance_count = items.size()
		var nearest := INF
		for i in items.size():
			var item: Dictionary = items[i]
			var turned := Basis(Vector3.UP, item.yaw).scaled(Vector3.ONE * float(item.scale))
			multimesh.set_instance_transform(i, Transform3D(turned, item.position))
			nearest = minf(nearest, item.distance)
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multimesh
		instance.material_override = materials[key[1]]
		if nearest > SHADOW_WITHIN:
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)


static func _item(kind: Kind, at: Vector2, grown: float, yaw: float, distance: float) -> Dictionary:
	return {"kind": kind, "position": Vector3(at.x, 0.0, at.y), "scale": grown, "yaw": yaw, "distance": distance}


## 素材のシーンの中の形（どれも 1 つで、原点に置いてある）。
static func _mesh_of(scene: PackedScene) -> Mesh:
	var root := scene.instantiate()
	var found: MeshInstance3D = root.find_children("*", "MeshInstance3D", true, false)[0]
	var mesh := found.mesh
	root.free()
	return mesh
