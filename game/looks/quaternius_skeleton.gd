extends RefCounted
## 魔物の骸骨の体（assets/quaternius/monsters/Skeleton.fbx。Quaternius の Animated Monster Pack、CC0）。
## 「人物」と「ミニ」の組が、魔物（骸骨兵・骸骨射手・骸骨重兵・骸骨術師・骸骨鼓手・骸骨旗手・骸骨の将）の形に使う。
## 骸骨旗手は、ほかの組でもこの形（monster_body.gd）。
##
## 素材は骨の色の 1 面だけで、何も持たない。6 種は、持ち物（同じ作者の RPG Characters の武器と、コードで組む盾・太鼓）、
## 大きさ、骨の色で見分ける。陣営の色は、腰に巻いた布と、盾・太鼓の面に出す（足元の円盤にも出る）。
## 動きは素材の 4 つ（立つ・走る・殴る・倒れる）。被弾と身ぶりの動きは無いので、unit_body.gd の代わりの動きになる。

const UnitBody := preload("res://game/unit_body.gd")
const ModelBody := preload("res://game/looks/model_body.gd")

const MODEL := "res://assets/quaternius/monsters/Skeleton.fbx"
const WEAPON_DIR := "res://assets/quaternius/weapons/"
## 素材は cm で入っている（骨の親が 100 倍）。足から頭の上までが 5.25 ほど。
const RAW_HEIGHT := 5.25
const MOVES := {
	&"idle": &"SkeletonArmature|Skeleton_Idle", &"run": &"SkeletonArmature|Skeleton_Running",
	&"attack": &"SkeletonArmature|Skeleton_Attack", &"death": &"SkeletonArmature|Skeleton_Death",
}
## 腕の骨（素材では「脚.001」という名前で入っている）。手は骨の先（骨の空間の +Y、ARM_END の所）。
const HAND_RIGHT := "R.DownLeg.001"
const HAND_LEFT := "L.DownLeg.001"
const ARM_END := 0.0075
const WAIST := "Hips"

## 種類ごとの形。"right" / "left" は手に持つもの（ITEMS の名前）、"scale" は大きさ、"bone" は骨の色。
const KINDS := {
	UnitKind.Id.SKELETON: {"right": "dagger", "scale": 0.92, "bone": Color("e6dcc3")},
	UnitKind.Id.SKELETON_ARCHER: {"right": "bow", "scale": 1.0, "bone": Color("d9ccb0")},
	UnitKind.Id.SKELETON_BRUTE: {"right": "sword", "left": "shield", "scale": 1.22, "bone": Color("a89f8f")},
	UnitKind.Id.SKELETON_CALLER: {"right": "cleric_staff", "scale": 0.95, "bone": Color("c9c0d6")},
	UnitKind.Id.SKELETON_DRUMMER: {"right": "stick", "left": "drum", "scale": 1.05, "bone": Color("e0cfa8")},
	UnitKind.Id.SKELETON_BANNER: {"right": "flag", "scale": 1.0, "bone": Color("d6c9a6")},
}
## 将の別の姿（unit_looks.gd の KING_LOOKS の名前 -> KINDS と同じ形）。
const KING_LOOKS := {
	&"skeleton_mage": {"right": "staff", "scale": 1.18, "bone": Color("8f8a99")},
}

## 持ち物。"file" は weapons/ の FBX（絵は別の PNG）、無ければコードで組む（"build"）。
## "on" は手でなく付ける骨（太鼓は腰）。"turn" は手に付けるときの回し方（度）、"at" はずらし（手の空間。1 は素材の 1 cm）。
const ITEMS := {
	"dagger": {"file": "Rogue_Dagger", "turn": Vector3(180.0, 0.0, -30.0), "at": Vector3.ZERO},
	"sword": {"file": "Warrior_Sword", "turn": Vector3(180.0, 0.0, -30.0), "at": Vector3.ZERO},
	"bow": {"file": "Ranger_Bow", "turn": Vector3(0.0, 90.0, 0.0), "at": Vector3.ZERO},
	"staff": {"file": "Wizard_Staff", "turn": Vector3(180.0, 0.0, -15.0), "at": Vector3.ZERO},
	"cleric_staff": {"file": "Cleric_Staff", "turn": Vector3(180.0, 0.0, -15.0), "at": Vector3.ZERO},
	"stick": {"build": "stick", "turn": Vector3(180.0, 0.0, -30.0), "at": Vector3.ZERO},
	"flag": {"build": "flag", "turn": Vector3(180.0, 0.0, -10.0), "at": Vector3.ZERO},
	"shield": {"build": "shield", "turn": Vector3(0.0, 90.0, 0.0), "at": Vector3.ZERO},
	"drum": {"build": "drum", "on": WAIST, "turn": Vector3(0.0, 0.0, -20.0), "at": Vector3(0.007, 0.006, 0.0)},
}
## 武器の FBX も cm で入っていて、付ける骨の親も 100 倍。体の倍率で割って、「人物」の武器と同じ大きさにする。
## 背の低い組（「ミニ」）では、背の割合で小さくする（REFERENCE_HEIGHT は「人物」の背）。
const WEAPON_SIZE := 0.0042
const REFERENCE_HEIGHT := 1.52

## 作ったマテリアルの使い回し（名前 -> Material）。
static var _materials := {}


## 骸骨の体。height は「人物」の組の人物の背（倍率 1 の駒の高さ）。それに合わせて縮める。
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
		for hand: String in ["right", "left"]:
			if shape.has(hand):
				_hold(bones, HAND_RIGHT if hand == "right" else HAND_LEFT, ITEMS[shape[hand]], team_color, model_scale * REFERENCE_HEIGHT / height)
		_wrap(bones, team_color)
	return body


## 持ち物を手の骨に付ける。
## shrink は、持ち物を体の倍率で割るときの値（体の倍率を、背の割合で直したもの）。
static func _hold(bones: Skeleton3D, bone: String, item: Dictionary, team_color: Color, shrink: float) -> void:
	var attachment := BoneAttachment3D.new()
	attachment.bone_name = item.get("on", bone)
	bones.add_child(attachment)
	var hand := Node3D.new()
	if not item.has("on"):
		hand.position = Vector3(0.0, ARM_END, 0.0)
	attachment.add_child(hand)
	var prop: Node3D
	if item.has("file"):
		prop = (load(WEAPON_DIR + "%s.fbx" % item["file"]) as PackedScene).instantiate()
		prop.scale = Vector3.ONE * WEAPON_SIZE / shrink
		var texture: Texture2D = load(WEAPON_DIR + "%s_Texture.png" % item["file"])
		for mesh: MeshInstance3D in prop.find_children("*", "MeshInstance3D", true, false):
			mesh.material_override = _textured(item["file"], texture)
	else:
		prop = _built(item["build"], team_color)
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


## コードで組む持ち物（素材に無いもの）。大きさは「人物」の盤の駒の 1 m を 1 とした値（_hold が体の倍率で直す）。
static func _built(kind: String, team_color: Color) -> Node3D:
	var root := Node3D.new()
	var wood := _plain("wood", Color("7a5236"), 0.9)
	match kind:
		"stick":
			var stick := _part(_cylinder(0.018, 0.018, 0.34), wood)
			stick.position.y = 0.12
			root.add_child(stick)
			var knob := _part(_sphere(0.04), _plain("bone", Color("e6dcc3"), 0.8))
			knob.position.y = 0.3
			root.add_child(knob)
		"flag":
			# 手から上へ伸びる竿と、先の陣営の色の旗（あの日の旗）。
			var pole := _part(_cylinder(0.016, 0.016, 1.1), wood)
			pole.position.y = 0.3
			root.add_child(pole)
			var cloth := _part(_box(Vector3(0.36, 0.26, 0.012)), _plain("team:" + team_color.to_html(), team_color, 0.9))
			cloth.position = Vector3(0.19, 0.72, 0.0)
			root.add_child(cloth)
		"shield":
			var face := _part(_cylinder(0.2, 0.2, 0.04), _plain("team:" + team_color.to_html(), team_color, 0.8))
			face.rotation_degrees = Vector3(0.0, 0.0, 90.0)
			root.add_child(face)
			var boss := _part(_sphere(0.06), _plain("iron", Color("6b6b70"), 0.5))
			boss.position.x = -0.03
			root.add_child(boss)
		"drum":
			var shell := _part(_cylinder(0.15, 0.15, 0.16), wood)
			root.add_child(shell)
			var band := _part(_cylinder(0.153, 0.153, 0.06), _plain("team:" + team_color.to_html(), team_color, 0.8))
			shell = band
			root.add_child(shell)
			var top := _part(_cylinder(0.155, 0.155, 0.02), _plain("hide", Color("e8dcc0"), 0.9))
			top.position.y = 0.085
			root.add_child(top)
			var rim := _part(_cylinder(0.157, 0.157, 0.02), _plain("iron", Color("6b6b70"), 0.5))
			rim.position.y = -0.08
			root.add_child(rim)
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


static func _sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
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


static func _textured(file: String, texture: Texture2D) -> Material:
	var key := "weapon:" + file
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_texture = texture
		material.roughness = 0.7
		_materials[key] = material
	return _materials[key]
