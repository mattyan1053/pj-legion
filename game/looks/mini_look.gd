extends "res://game/looks/look_set.gd"
## 駒の見た目の組「Mini」: 頭の大きい、顔のある小さな人形（assets/kenney/mini-characters/。Kenney、CC0）。
##
## 素材は人物ごとに髪・服・顔が違うので、種類ごとに別の人物を当て、同じ素材の武器・盾・小物を腕の骨に付ける。
## 素材の絵は、色ごとの濃淡の帯（RAMP の大きさ）を並べた 1 枚。"accent" に挙げた帯を陣営の色に塗り替える。
## 魔物は、ゾンビと宇宙人とロボットで代わりにする（骸骨は無い）。被弾の動きは無いので、unit_body.gd の代わりの動き。

const ModelBody := preload("res://game/looks/model_body.gd")

const DIR := "res://assets/kenney/mini-characters/"
## 盤の駒の大きさへの倍率と、そのときの体の高さ。
const MODEL_SCALE := 1.5
const MODEL_HEIGHT := 1.22
## 種類によらない動きの名前。
const MOVES := {&"idle": &"idle", &"run": &"walk", &"death": &"die", &"gesture": &"emote-yes"}
const MELEE := &"attack-melee-right"
const SHOOT := &"holding-right-shoot"
## 絵の中の、色の帯 1 本の大きさ（px）。帯は (列, 行) で指す。
const RAMP := Vector2i(64, 128)
const BLUE := Vector2i(0, 1)
const ORANGE := Vector2i(0, 2)
const YELLOW := Vector2i(0, 3)
const BROWN := Vector2i(1, 2)
const SLATE := Vector2i(1, 3)
const PURPLE := Vector2i(2, 1)
const METAL := Vector2i(2, 3)
const DARK := Vector2i(3, 3)
const GREEN := Vector2i(4, 2)
const RED := Vector2i(7, 2)
const WHITE := Vector2i(7, 3)

## 種類ごとの形。"model" は character-<名前>.glb、"right"・"left" は腕に持つもの（ITEMS の名前）、
## "attack" は攻撃の動き、"accent" は陣営の色に塗る帯。"scale" は大きさ（無ければ 1）。
const KINDS := {
	UnitKind.Id.KING: {"model": "knight", "right": "sword", "left": "shield_round", "attack": MELEE, "accent": [SLATE, BLUE], "scale": 1.18},
	UnitKind.Id.SHIELD_TROOPER: {"model": "soldier", "right": "shooter", "left": "shield_rectangle", "attack": SHOOT, "accent": [GREEN]},
	UnitKind.Id.SNIPER: {"model": "female-c", "right": "shooter", "attack": SHOOT, "accent": [RED]},
	UnitKind.Id.COMMANDO: {"model": "raider", "right": "sword", "attack": MELEE, "accent": [GREEN]},
	UnitKind.Id.MEDIC: {"model": "female-e", "right": "defibrillator", "attack": SHOOT, "accent": [DARK]},
	UnitKind.Id.PALADIN: {"model": "knight", "right": "sword", "left": "shield_rectangle", "attack": MELEE, "accent": [SLATE, BLUE]},
	UnitKind.Id.SORCERER: {"model": "male-b", "right": "staff", "attack": SHOOT, "accent": [RED]},
	UnitKind.Id.SPELLBLADE: {"model": "female-a", "right": "sword", "attack": MELEE, "accent": [PURPLE]},
	UnitKind.Id.PRIEST: {"model": "female-d", "right": "holy_staff", "attack": SHOOT, "accent": [SLATE]},
	UnitKind.Id.SKELETON: {"model": "zombie", "right": "sword", "attack": MELEE, "accent": [SLATE], "scale": 0.92},
	UnitKind.Id.SKELETON_ARCHER: {"model": "zombie", "right": "bow", "attack": SHOOT, "accent": [SLATE]},
	UnitKind.Id.SKELETON_BRUTE: {"model": "robot", "right": "sword", "left": "shield_round", "attack": MELEE, "accent": [YELLOW], "scale": 1.2},
	UnitKind.Id.SKELETON_CALLER: {"model": "alien", "right": "dark_staff", "attack": SHOOT, "accent": [WHITE], "scale": 0.92},
	UnitKind.Id.SKELETON_DRUMMER: {"model": "zombie", "right": "cane", "left": "shield_round", "attack": MELEE, "accent": [SLATE], "scale": 1.05},
}
## 将の別の姿（unit_looks.gd の KING_LOOKS の名前 -> KINDS と同じ形）。
const KING_LOOKS := {
	&"skeleton_mage": {"model": "alien", "right": "dark_staff", "attack": SHOOT, "accent": [WHITE], "scale": 1.18},
}

## 腕に持つもの。"file" は素材のファイル、"at" は手からのずらし、"turn" は回し方（度）。どちらも、立っているときに駒がまっすぐ立つ向きで書く。
const ITEMS := {
	"sword": {"file": "weapon-sword", "at": Vector3(0.0, 0.02, 0.04), "turn": Vector3(25.0, 0.0, 0.0)},
	"bow": {"file": "weapon-bow", "at": Vector3(0.0, -0.2, 0.06), "turn": Vector3.ZERO},
	"shooter": {"file": "weapon-shooter", "at": Vector3(0.0, 0.0, 0.08), "turn": Vector3.ZERO},
	"cane": {"file": "aid-cane", "at": Vector3(0.0, -0.26, 0.04), "turn": Vector3.ZERO},
	"defibrillator": {"file": "aid-defibrillator-red", "at": Vector3(-0.04, -0.2, 0.04), "turn": Vector3.ZERO},
	# 杖は素材に無いので、コードで組む（柄と、光る玉）。"orb" は玉の色。
	"staff": {"orb": Color("ffb040"), "at": Vector3(0.0, -0.3, 0.04), "turn": Vector3.ZERO},
	"holy_staff": {"orb": Color("fff2b0"), "at": Vector3(0.0, -0.3, 0.04), "turn": Vector3.ZERO},
	"dark_staff": {"orb": Color("b060ff"), "at": Vector3(0.0, -0.3, 0.04), "turn": Vector3.ZERO},
	"shield_round": {"file": "shield-round", "at": Vector3(0.02, 0.0, 0.1), "turn": Vector3.ZERO},
	"shield_rectangle": {"file": "shield-rectangle", "at": Vector3(0.02, -0.14, 0.1), "turn": Vector3.ZERO},
}
const ARM_RIGHT := "arm-right"
const ARM_LEFT := "arm-left"
## 腕の骨から手までの長さと、立っているときの腕の傾き（度。腕は斜め下へ下がっている）。
const ARM_LENGTH := 0.24
const ARM_HANG := 45.0
const STAFF_LENGTH := 0.62

## 塗り替えたマテリアルの使い回し（"帯の並び:色:暗さ" -> StandardMaterial3D）。
static var _materials := {}


func _init() -> void:
	icon_dir = "res://assets/unit_icons/mini"


func build(kind: UnitKind.Id, team_color: Color, look: StringName, at: Vector3) -> UnitBody:
	if kind == UnitKind.Id.KING and KING_LOOKS.has(look):
		return _model_body(KING_LOOKS[look], team_color)
	if KINDS.has(kind):
		return _model_body(KINDS[kind], team_color)
	return super(kind, team_color, look, at)


func _model_body(shape: Dictionary, team_color: Color) -> UnitBody:
	var model: Node3D = (load(DIR + "character-%s.glb" % shape["model"]) as PackedScene).instantiate()
	var size: float = shape.get("scale", 1.0)
	model.scale = Vector3.ONE * MODEL_SCALE * size
	var source: Material = null
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	if not meshes.is_empty():
		source = (meshes[0] as MeshInstance3D).mesh.surface_get_material(0)
	# 素材の持ち物は体と同じ絵なので、先に付けて、体と一緒に塗る。コードで組む杖は、あとから付ける（体のマテリアルを当てない）。
	for arm: String in ["right", "left"]:
		if shape.has(arm) and not ITEMS[shape[arm]].has("orb"):
			_hold(model, ARM_RIGHT if arm == "right" else ARM_LEFT, ITEMS[shape[arm]])
	var moves := MOVES.duplicate()
	moves[&"attack"] = shape["attack"]
	var accent: Array = shape["accent"]
	var body := ModelBody.new()
	body.body_height = MODEL_HEIGHT * size
	body.set_model(model, moves, func(shade: float) -> Material: return _team_material(accent, team_color, source, shade))
	for arm: String in ["right", "left"]:
		if shape.has(arm) and ITEMS[shape[arm]].has("orb"):
			_hold(model, ARM_RIGHT if arm == "right" else ARM_LEFT, ITEMS[shape[arm]])
	return body


## 持ち物を腕の骨に付ける。
static func _hold(model: Node3D, bone: String, item: Dictionary) -> void:
	var skeleton := model.find_children("*", "Skeleton3D", true, false)
	if skeleton.is_empty():
		return
	var attachment := BoneAttachment3D.new()
	attachment.bone_name = bone
	skeleton[0].add_child(attachment)
	# 手の位置に、腕の傾きを打ち消した軸を置く（持ち物を、駒がまっすぐ立つ向きで書けるように）。
	var side := -1.0 if bone == ARM_RIGHT else 1.0
	var hand := Node3D.new()
	hand.position = Vector3(side * ARM_LENGTH, 0.0, 0.0)
	hand.rotation_degrees = Vector3(0.0, 0.0, side * ARM_HANG)
	attachment.add_child(hand)
	var prop: Node3D = _staff(item["orb"]) if item.has("orb") else (load(DIR + "%s.glb" % item["file"]) as PackedScene).instantiate()
	prop.position = item["at"]
	prop.rotation_degrees = item["turn"]
	hand.add_child(prop)


## 杖（柄と、光る玉）。素材の絵を使わない。
static func _staff(orb_color: Color) -> Node3D:
	var staff := Node3D.new()
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("8a5a3c")
	wood.roughness = 0.9
	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.top_radius = 0.022
	shaft_mesh.bottom_radius = 0.022
	shaft_mesh.height = STAFF_LENGTH
	shaft_mesh.radial_segments = 6
	shaft_mesh.rings = 1
	var shaft := MeshInstance3D.new()
	shaft.mesh = shaft_mesh
	shaft.material_override = wood
	shaft.position.y = STAFF_LENGTH * 0.5
	staff.add_child(shaft)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = orb_color
	glow.emission_enabled = true
	glow.emission = orb_color
	glow.emission_energy_multiplier = 0.8
	var orb_mesh := SphereMesh.new()
	orb_mesh.radius = 0.065
	orb_mesh.height = 0.13
	orb_mesh.radial_segments = 8
	orb_mesh.rings = 4
	var orb := MeshInstance3D.new()
	orb.mesh = orb_mesh
	orb.material_override = glow
	orb.position.y = STAFF_LENGTH + 0.05
	staff.add_child(orb)
	return staff


## 素材のマテリアルを、accent の帯だけ陣営の色にしたものに差し替える（濃淡は残し、色相と彩度を替える）。
## shade は全体の明るさ（行動済みの駒は暗くする）。持ち物にも同じものが当たる（絵が同じ 1 枚なので）。
static func _team_material(accent: Array, team_color: Color, source: Material, shade: float) -> Material:
	var key := "%s:%s:%s" % [accent, team_color.to_html(), shade]
	if _materials.has(key):
		return _materials[key]
	if shade < 1.0:
		var dimmed := _team_material(accent, team_color, source, 1.0).duplicate() as StandardMaterial3D
		dimmed.albedo_color = Color(shade, shade, shade)
		_materials[key] = dimmed
		return dimmed
	var material := source.duplicate() as StandardMaterial3D
	var image := material.albedo_texture.get_image()
	if image.is_compressed():
		image.decompress()
	image.clear_mipmaps()
	image.convert(Image.FORMAT_RGBA8)
	for ramp: Vector2i in accent:
		var origin := ramp * RAMP
		for y in RAMP.y:
			for x in RAMP.x:
				var c := image.get_pixel(origin.x + x, origin.y + y)
				image.set_pixel(origin.x + x, origin.y + y, Color.from_hsv(team_color.h, maxf(c.s, team_color.s * 0.8), c.v, c.a))
	material.albedo_texture = ImageTexture.create_from_image(image)
	_materials[key] = material
	return material
