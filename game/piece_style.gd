extends RefCounted
## 駒の描き方の上乗せ（素材を替えずに効く手）。どの駒の見た目の組にも同じに掛ける（unit_view.gd が呼ぶ）。
## いまは縁取りだけ（オプションの「駒の縁取り」。docs/battle-view.md の「駒の縁取り」）: 体の面を裏返した殻を少し太らせて、暗い色で描く。
## 縁は、駒を作るときに付ける（オプションを変えたら、次に作る駒から）。ノードに依存しない（マテリアルを返すだけ）。

## 縁の太さ（盤の上の大きさ）と色。
const OUTLINE_WIDTH := 0.012
const OUTLINE_COLOR := Color(0.07, 0.06, 0.08)

static var outline := false

## 面の大きさの倍率 -> 縁のマテリアル。
static var _materials := {}


## 体の面に縁を付ける（outline が切りなら何もしない）。縁の太さは、面の大きさの倍率で割って、どの組でも同じ見た目の太さにする。
static func add_outline(body: Node3D) -> void:
	if not outline:
		return
	for mesh: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
		mesh.material_overlay = outline_material(_scale_to(mesh, body))


## 大きさの倍率 size の面に付ける、縁のマテリアル。
static func outline_material(size: float) -> Material:
	var key := snappedf(size, 0.0001)
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.cull_mode = BaseMaterial3D.CULL_FRONT
		material.grow = true
		material.grow_amount = OUTLINE_WIDTH / maxf(size, 0.0001)
		material.albedo_color = OUTLINE_COLOR
		_materials[key] = material
	return _materials[key]


## node から top までの、積み重なった大きさの倍率（x の向きで測る）。
static func _scale_to(node: Node3D, top: Node3D) -> float:
	var size := 1.0
	var at: Node = node
	while at != null and at != top:
		if at is Node3D:
			size *= (at as Node3D).scale.x
		at = at.get_parent()
	return size
