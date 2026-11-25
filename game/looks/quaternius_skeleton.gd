extends RefCounted
## 骸骨旗手の体（assets/quaternius/monsters/Skeleton.fbx。Quaternius の Animated Monster Pack、CC0）。monster_body.gd が使う。
## ほかの骸骨（骸骨兵・骸骨射手など）は「人形」の組の KayKit の骸骨（kaykit_look.gd）。
##
## 素材は骨の色の 1 面だけで、何も持たない。コードで組む旗を持たせる。陣営の色は、腰に巻いた布と旗に出す（足元の円盤にも出る）。
## 動きは素材の 4 つ（立つ・走る・殴る・倒れる）。被弾と身ぶりの動きは無いので、unit_body.gd の代わりの動きになる。

const UnitBody := preload("res://game/unit_body.gd")
const ModelBody := preload("res://game/looks/model_body.gd")

const MODEL := "res://assets/quaternius/monsters/Skeleton.fbx"
## 素材は cm で入っている（骨の親が 100 倍）。足から頭の上までが 5.25 ほど。
const RAW_HEIGHT := 5.25
const MOVES := {
	&"idle": &"SkeletonArmature|Skeleton_Idle", &"run": &"SkeletonArmature|Skeleton_Running",
	&"attack": &"SkeletonArmature|Skeleton_Attack", &"death": &"SkeletonArmature|Skeleton_Death",
}
## 腕の骨（素材では「脚.001」という名前で入っている）。手は骨の先（骨の空間の +Y、ARM_END の所）。
const HAND_RIGHT := "R.DownLeg.001"
const ARM_END := 0.0075
const WAIST := "Hips"

## 種類ごとの形。"right" は手に持つもの（ITEMS の名前）、"scale" は大きさ、"bone" は骨の色。
const KINDS := {
	UnitKind.Id.SKELETON_BANNER: {"right": "flag", "scale": 1.0, "bone": Color("d6c9a6")},
}

## 持ち物（コードで組む。"build"）。"turn" は手に付けるときの回し方（度）、"at" はずらし（手の空間。1 は素材の 1 cm）。
const ITEMS := {
	"flag": {"build": "flag", "turn": Vector3(180.0, 0.0, -10.0), "at": Vector3.ZERO},
}
## 持ち物の大きさは、背の割合で直す（REFERENCE_HEIGHT は持ち物を組んだときの背）。
const REFERENCE_HEIGHT := 1.52

## 作ったマテリアルの使い回し（名前 -> Material）。
static var _materials := {}


## 骸骨の体。height は組の人の駒の背（倍率 1 の駒の高さ）。それに合わせて縮める。
static func build(shape: Dictionary, team_color: Color, height: float) -> UnitBody:
	var size: float = shape.get("scale", 1.0)
	var model_scale := height / RAW_HEIGHT * size
	var model: Node3D = (load(MODEL) as PackedScene).instantiate()
	model.scale = Vector3.ONE * model_scale
	var bone_color: Color = shape["bone"]
	var body := ModelBody.new()
	body.body_height = height * size
	body.set_model(model, MOVES, func(shade: float) -> Material: return _bone(bone_color, shade))
	# 持ち物と布は、体のマテリアルが当たらないように、体を作ったあとに付ける。
	var skeleton := model.find_children("*", "Skeleton3D", true, false)
	if not skeleton.is_empty():
		var bones := skeleton[0] as Skeleton3D
		_hold(bones, HAND_RIGHT, ITEMS[shape["right"]], team_color, model_scale * REFERENCE_HEIGHT / height)
		_wrap(bones, team_color)
	return body


## 持ち物を手の骨に付ける。
## shrink は、持ち物を体の倍率で割るときの値（体の倍率を、背の割合で直したもの）。
static func _hold(bones: Skeleton3D, bone: String, item: Dictionary, team_color: Color, shrink: float) -> void:
	var attachment := BoneAttachment3D.new()
	attachment.bone_name = bone
	bones.add_child(attachment)
	var hand := Node3D.new()
	hand.position = Vector3(0.0, ARM_END, 0.0)
	attachment.add_child(hand)
	var prop := _built(item["build"], team_color)
	prop.scale = Vector3.ONE * 0.01 / shrink
	prop.rotation_degrees = item["turn"]
	prop.position = item["at"]
	hand.add_child(prop)


## 腰に巻いた布（陣営の色）。
static func _wrap(bones: Skeleton3D, team_color: Color) -> void:
	var attachment := BoneAttachment3D.new()
	attachment.bone_name = WAIST
	bones.add_child(attachment)
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0052
	mesh.bottom_radius = 0.0068
	mesh.height = 0.0042
	mesh.radial_segments = 8
	mesh.rings = 1
	var cloth := MeshInstance3D.new()
	cloth.mesh = mesh
	cloth.material_override = _plain("team:" + team_color.to_html(), team_color, 0.95)
	cloth.position = Vector3(0.0, -0.0005, 0.0)
	attachment.add_child(cloth)


## コードで組む持ち物（素材に無いもの）。大きさは背 REFERENCE_HEIGHT の駒の 1 m を 1 とした値（_hold が体の倍率で直す）。
static func _built(kind: String, team_color: Color) -> Node3D:
	var root := Node3D.new()
	var wood := _plain("wood", Color("7a5236"), 0.9)
	match kind:
		"flag":
			# 手から上へ伸びる竿と、先の陣営の色の旗（あの日の旗）。
			var pole := _part(_cylinder(0.016, 0.016, 1.1), wood)
			pole.position.y = 0.3
			root.add_child(pole)
			var cloth := _part(_box(Vector3(0.36, 0.26, 0.012)), _plain("team:" + team_color.to_html(), team_color, 0.9))
			cloth.position = Vector3(0.19, 0.72, 0.0)
			root.add_child(cloth)
	return root


static func _part(mesh: Mesh, material: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	return part


static func _cylinder(top: float, bottom: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 10
	mesh.rings = 1
	return mesh


static func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh



static func _bone(color: Color, shade: float) -> Material:
	return _plain("bone:%s:%s" % [color.to_html(), shade], Color(color.r * shade, color.g * shade, color.b * shade), 0.85)


static func _plain(key: String, color: Color, roughness: float) -> Material:
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = roughness
		_materials[key] = material
	return _materials[key]

