extends "res://game/looks/look_set.gd"
## 駒の見た目の組「Quaternius」: 服で役どころの分かる、低ポリの人物（assets/quaternius/。Quaternius、CC0）。
##
## 素材は人物ごとに服が違うので、種類ごとに別の人物を当てる（MILITARY は兵士・忍者・医者、FANTASY は騎士・魔法使い・忍びの女剣士・エルフ）。
## 素材の人物は何も持たないので、同じ作者の RPG Characters の武器を右手の骨に付ける。
## 陣営の色は、服の面（"accent" に挙げたマテリアル）を塗り替える。将は大きくしない（人物の素材は背が高く、会話の枠に収まらない）。魔物は、同じ作者の骸骨（quaternius_skeleton.gd）。将の別の姿（骸骨の将）も骸骨。
## 動きは素材のアニメーション（立つ・歩く・殴る・撃つ・被弾・負け・勝ち）。走る動きは無いので、歩く動きで代える。

const ModelBody := preload("res://game/looks/model_body.gd")
const Skeleton := preload("res://game/looks/quaternius_skeleton.gd")

const DIR := "res://assets/quaternius/"
## 素材は cm で入っている（骨の親が 100 倍）。盤の駒の大きさへの倍率と、そのときの体の高さ。
const MODEL_SCALE := 0.47
const MODEL_HEIGHT := 1.52
## 種類によらない動きの名前。
const MOVES := {
	&"idle": &"CharacterArmature|Idle", &"run": &"CharacterArmature|Walk", &"hit": &"CharacterArmature|RecieveHit",
	&"death": &"CharacterArmature|Defeat", &"gesture": &"CharacterArmature|Victory",
}
const MELEE := &"CharacterArmature|Punch"
const SHOOT := &"CharacterArmature|Shoot_OneHanded"
## 攻撃の出入りのつなぎの秒数。
const ATTACK_BLEND := 0.2

## 種類ごとの形。"model" は characters/ のファイルの名前、"hold" は右手に持つ武器（WEAPONS の名前）、
## "attack" は攻撃の動き、"accent" は陣営の色に塗るマテリアル（名前 -> 暗くする割合）。"scale" は大きさ（無ければ 1）。
const KINDS := {
	UnitKind.Id.KING: {"model": "Knight_Golden_Male", "hold": "sword", "attack": MELEE, "accent": {"Detail": 0.1, "Red": 0.3}},
	UnitKind.Id.SHIELD_TROOPER: {"model": "Soldier_Male", "hold": "sword", "attack": MELEE, "accent": {"Main": 0.1, "Helmet": 0.3}},
	UnitKind.Id.SNIPER: {"model": "Soldier_Female", "hold": "bow", "attack": SHOOT, "accent": {"Main": 0.1}},
	UnitKind.Id.COMMANDO: {"model": "Ninja_Male", "hold": "dagger", "attack": MELEE, "accent": {"Details": 0.0, "Main": 0.55}},
	UnitKind.Id.MEDIC: {"model": "Doctor_Female_Young", "hold": "", "attack": SHOOT, "accent": {"Black": 0.1}},
	UnitKind.Id.PALADIN: {"model": "Knight_Male", "hold": "sword", "attack": MELEE, "accent": {"Detail": 0.1, "Red": 0.3, "Armor_Dark": 0.45}},
	UnitKind.Id.SORCERER: {"model": "Elf", "hold": "staff", "attack": SHOOT, "accent": {"Clothes": 0.1, "Hat": 0.3}},
	UnitKind.Id.SPELLBLADE: {"model": "Ninja_Female", "hold": "sword", "attack": MELEE, "accent": {"Main": 0.1, "Details": 0.5}},
	UnitKind.Id.PRIEST: {"model": "Wizard", "hold": "cleric_staff", "attack": SHOOT, "accent": {"Clothes": 0.1, "Hat": 0.3}},
}

## 武器（weapons/ のファイルと、その絵）。素材の FBX は絵を中に持たないので、絵を別に貼る。
## "turn" は右手の骨に付けるときの回し方（度）、"at" はずらし（骨の空間）。
const WEAPONS := {
	"sword": {"file": "Warrior_Sword", "turn": Vector3(-90.0, 0.0, 0.0), "at": Vector3.ZERO},
	"dagger": {"file": "Rogue_Dagger", "turn": Vector3(-90.0, 0.0, 0.0), "at": Vector3.ZERO},
	"bow": {"file": "Ranger_Bow", "turn": Vector3(0.0, 0.0, 0.0), "at": Vector3.ZERO},
	"staff": {"file": "Wizard_Staff", "turn": Vector3(-90.0, 0.0, 0.0), "at": Vector3.ZERO},
	"cleric_staff": {"file": "Cleric_Staff", "turn": Vector3(-90.0, 0.0, 0.0), "at": Vector3.ZERO},
}
const HAND_BONE := "Fist.R"
## 武器も cm で入っていて、付ける骨の親も 100 倍なので、ここで縮める。
const WEAPON_SCALE := 0.011

## 肌と目の色。素材の人物は、肌が黒（ほぼ黒の "Skin"）で目が白（"Face"）の絵柄で、盤の大きさでは顔が黒くつぶれる。
## その 2 つの面を、肌の色と暗い目に塗り替える（ゾンビ・ゴブリンなど、肌が黒でない人物はそのまま）。種類ごとの "skin" で肌の色を替えられる。
const SKIN := Color("e3b48f")
const EYES := Color("2b2421")
## 素材の肌がこれより暗ければ、塗り替える（黒い肌の絵柄の人物だけ）。
const DARK_SKIN := 0.15

## 塗り替えたマテリアルの使い回し（"モデル:面:色:暗さ" -> StandardMaterial3D）。
static var _materials := {}


func _init() -> void:
	icon_dir = "res://assets/unit_icons/quaternius"


func build(kind: UnitKind.Id, team_color: Color, look: StringName, at: Vector3) -> UnitBody:
	if kind == UnitKind.Id.KING and Skeleton.KING_LOOKS.has(look):
		return Skeleton.build(Skeleton.KING_LOOKS[look], team_color, MODEL_HEIGHT)
	if Skeleton.KINDS.has(kind):
		return Skeleton.build(Skeleton.KINDS[kind], team_color, MODEL_HEIGHT)
	if KINDS.has(kind):
		return _model_body(KINDS[kind], team_color)
	return super(kind, team_color, look, at)


func _model_body(shape: Dictionary, team_color: Color) -> UnitBody:
	var model_name: String = shape["model"]
	var model: Node3D = (load(DIR + "characters/%s.fbx" % model_name) as PackedScene).instantiate()
	var size: float = shape.get("scale", 1.0)
	model.scale = Vector3.ONE * MODEL_SCALE * size
	if shape["hold"] != "":
		_hold(model, WEAPONS[shape["hold"]])
	var moves := MOVES.duplicate()
	moves[&"attack"] = shape["attack"]
	var accent: Dictionary = shape["accent"]
	var body := ModelBody.new()
	body.body_height = MODEL_HEIGHT * size
	body.set_model(model, moves, Callable())
	# この素材は、立ち姿と攻撃の頭の姿勢が離れている（腕を大きく振りかぶる）ので、攻撃の出入りのつなぎを少し長くする。
	body.set_timing({}, ModelBody.ATTACK_HIT, ATTACK_BLEND)
	var skin: Color = shape.get("skin", SKIN)
	body.set_surface_materials(func(mesh: MeshInstance3D, shade: float) -> void: _paint(mesh, model_name, accent, team_color, skin, shade))
	return body


## 武器を右手の骨に付ける。
static func _hold(model: Node3D, weapon: Dictionary) -> void:
	var skeleton := model.find_children("*", "Skeleton3D", true, false)
	if skeleton.is_empty():
		return
	var attachment := BoneAttachment3D.new()
	attachment.bone_name = HAND_BONE
	skeleton[0].add_child(attachment)
	var prop: Node3D = (load(DIR + "weapons/%s.fbx" % weapon["file"]) as PackedScene).instantiate()
	prop.scale = Vector3.ONE * WEAPON_SCALE
	prop.rotation_degrees = weapon["turn"]
	prop.position = weapon["at"]
	var texture: Texture2D = load(DIR + "weapons/%s_Texture.png" % weapon["file"])
	for mesh: MeshInstance3D in prop.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = _weapon_material(weapon["file"], texture)
	attachment.add_child(prop)


static func _weapon_material(file: String, texture: Texture2D) -> Material:
	var key := "weapon:" + file
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_texture = texture
		material.roughness = 0.7
		_materials[key] = material
	return _materials[key]


## 体の面ごとに、陣営の色（accent の面）、肌と目の色（黒い肌の絵柄の人物だけ）、明るさ（shade）を当てる。
static func _paint(mesh: MeshInstance3D, model_name: String, accent: Dictionary, team_color: Color, skin: Color, shade: float) -> void:
	var dark_skin := _has_dark_skin(mesh.mesh)
	for i in mesh.mesh.get_surface_count():
		var source := mesh.mesh.surface_get_material(i) as StandardMaterial3D
		if source == null:
			continue
		var key := "%s:%d:%s:%s:%s" % [model_name, i, team_color.to_html(), skin.to_html(), shade]
		if not _materials.has(key):
			var material := source.duplicate() as StandardMaterial3D
			var color := source.albedo_color
			if accent.has(source.resource_name):
				color = team_color.darkened(accent[source.resource_name])
			elif dark_skin and source.resource_name == "Skin":
				color = skin
			elif dark_skin and source.resource_name == "Face":
				color = EYES
			material.albedo_color = Color(color.r * shade, color.g * shade, color.b * shade, color.a)
			_materials[key] = material
		mesh.set_surface_override_material(i, _materials[key])


## 肌（"Skin" の面）が黒い絵柄の人物か。
static func _has_dark_skin(mesh: Mesh) -> bool:
	for i in mesh.get_surface_count():
		var source := mesh.surface_get_material(i) as StandardMaterial3D
		if source != null and source.resource_name == "Skin":
			return source.albedo_color.get_luminance() < DARK_SKIN
	return false
