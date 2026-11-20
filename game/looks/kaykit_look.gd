extends "res://game/looks/look_set.gd"
## 駒の見た目の組「KayKit」: 頭の大きい人形のような低ポリの人物（assets/kaykit/）。
##
## KayKit のキャラクターは、持ちうる武器や盾がすべて付いた状態で入っているので、
## 種類ごとに使わないものを隠す。陣営の色は、服の差し色（マント・帽子など）で出す。
## 魔物（骸骨）は KayKit の骸骨の素材に、別の素材の武器を手の骨に付ける。
## 中立の駒は、どの組とも同じ結晶のコア（core_body.gd）。

const ModelBody := preload("res://game/looks/model_body.gd")

const MODEL_SCALE := 0.5
## 体の高さ（大きさ 1 のとき）。
const MODEL_HEIGHT := 1.3
## 種類によらない動きの名前（KayKit のキャラクターと骸骨に共通のアニメーション）。
const MOVES := {&"run": &"Running_A", &"hit": &"Hit_A", &"death": &"Death_A", &"gesture": &"Interact"}
## テクスチャは 128 x 256 の色見本を並べたもの。"accent" に挙げた見本（列, 行）を陣営の色に塗り替える。
const SWATCH_SIZE := Vector2i(128, 256)

## 駒の種類ごとの形。"model" は MODELS の名前、"show" は持たせる小物（それ以外の小物は隠す）。
## "idle" と "attack" は、その種類の立ち姿と攻撃のアニメーション。"scale" は大きさ（無ければ 1）。
const KINDS := {
	UnitKind.Id.KING: {
		"model": "knight", "show": ["2H_Sword"], "scale": 1.18,
		"idle": "2H_Melee_Idle", "attack": "2H_Melee_Attack_Slice",
	},
	UnitKind.Id.SHIELD_TROOPER: {
		"model": "knight", "show": ["1H_Sword", "Rectangle_Shield"],
		"idle": "Idle", "attack": "1H_Melee_Attack_Chop",
	},
	UnitKind.Id.PALADIN: {
		"model": "knight", "show": ["1H_Sword", "Badge_Shield"],
		"idle": "Idle", "attack": "1H_Melee_Attack_Slice_Diagonal",
	},
	UnitKind.Id.SNIPER: {
		"model": "rogue", "show": ["2H_Crossbow"],
		"idle": "Idle", "attack": "2H_Ranged_Shoot",
	},
	UnitKind.Id.COMMANDO: {
		"model": "rogue", "show": ["Knife", "Knife_Offhand"],
		"idle": "Idle", "attack": "Dualwield_Melee_Attack_Slice",
	},
	UnitKind.Id.MEDIC: {
		"model": "mage", "show": ["Spellbook_open"],
		"idle": "Idle", "attack": "Spellcast_Shoot",
	},
	UnitKind.Id.SORCERER: {
		"model": "mage", "show": ["2H_Staff"],
		"idle": "Idle", "attack": "Spellcast_Shoot",
	},
	UnitKind.Id.SPELLBLADE: {
		"model": "barbarian", "show": ["2H_Axe"],
		"idle": "2H_Melee_Idle", "attack": "2H_Melee_Attack_Slice",
	},
	UnitKind.Id.PRIEST: {
		"model": "mage", "show": ["Spellbook", "1H_Wand"],
		"idle": "Idle", "attack": "Spellcast_Shoot",
	},
	# 魔物（docs/unit-roster.md の「魔物」）。骸骨の素材は武器を持たないので、"hold" の小物を手の骨に付ける。
	UnitKind.Id.SKELETON: {
		"model": "skeleton_minion", "show": [], "hold": {"handslot.r": "blade"}, "scale": 0.92,
		"idle": "Idle", "attack": "1H_Melee_Attack_Chop",
	},
	UnitKind.Id.SKELETON_ARCHER: {
		"model": "skeleton_rogue", "show": [], "hold": {"handslot.r": "crossbow"},
		"idle": "2H_Ranged_Aiming", "attack": "2H_Ranged_Shoot",
	},
	UnitKind.Id.SKELETON_BRUTE: {
		"model": "skeleton_warrior", "show": [], "hold": {"handslot.r": "axe", "handslot.l": "large_shield"}, "scale": 1.22,
		"idle": "Idle_Combat", "attack": "1H_Melee_Attack_Chop",
	},
	# 骸骨術師は骸骨の将と同じ素材で、小さく（将は 1.18）。骸骨鼓手は骸骨兵の素材に、杖を太鼓のばちの代わりに持たせる。
	UnitKind.Id.SKELETON_CALLER: {
		"model": "skeleton_mage", "show": [], "hold": {"handslot.r": "staff"}, "scale": 0.9,
		"idle": "Idle", "attack": "Spellcast_Shoot",
	},
	UnitKind.Id.SKELETON_DRUMMER: {
		"model": "skeleton_minion", "show": [], "hold": {"handslot.r": "staff", "handslot.l": "blade"}, "scale": 1.05,
		"idle": "Idle_Combat", "attack": "1H_Melee_Attack_Chop",
	},
}

## 将の別の姿（unit_looks.gd の KING_LOOKS の名前 -> KINDS と同じ形）。
const KING_LOOKS := {
	&"skeleton_mage": {
		"model": "skeleton_mage", "show": [], "hold": {"handslot.r": "staff"}, "scale": 1.18,
		"idle": "Idle", "attack": "Spellcast_Shoot",
	},
}

## 骸骨の小物（手の骨に付ける別の素材）。
const HELD_PROPS := {
	"blade": "res://assets/kaykit/skeletons/Skeleton_Blade.gltf",
	"crossbow": "res://assets/kaykit/skeletons/Skeleton_Crossbow.gltf",
	"axe": "res://assets/kaykit/skeletons/Skeleton_Axe.gltf",
	"large_shield": "res://assets/kaykit/skeletons/Skeleton_Shield_Large_A.gltf",
	"staff": "res://assets/kaykit/skeletons/Skeleton_Staff.gltf",
}
## 手の骨に付けたままでは向きが合わない小物の回し方（度）。杖は、そのままだと横に寝るので立てる。
const HELD_PROP_TURNS := {"staff": Vector3(0.0, 0.0, 90.0)}

## 素材のキャラクター。"props" は付け外しできる小物、"accent" は陣営の色に塗り替える色見本（列, 行）。
const MODELS := {
	"knight": {
		"scene": "res://assets/kaykit/adventurers/Knight.glb",
		"props": [
			"1H_Sword_Offhand", "Badge_Shield", "Rectangle_Shield", "Round_Shield", "Spike_Shield",
			"1H_Sword", "2H_Sword",
		],
		"accent": [Vector2i(0, 1), Vector2i(2, 2)],
	},
	"barbarian": {
		"scene": "res://assets/kaykit/adventurers/Barbarian.glb",
		"props": ["1H_Axe_Offhand", "Barbarian_Round_Shield", "1H_Axe", "2H_Axe", "Mug"],
		"accent": [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 2)],
	},
	"mage": {
		"scene": "res://assets/kaykit/adventurers/Mage.glb",
		"props": ["Spellbook", "Spellbook_open", "1H_Wand", "2H_Staff"],
		"accent": [Vector2i(0, 1), Vector2i(1, 1), Vector2i(7, 1), Vector2i(2, 1), Vector2i(1, 2)],
	},
	"rogue": {
		"scene": "res://assets/kaykit/adventurers/Rogue.glb",
		"props": ["Knife_Offhand", "1H_Crossbow", "2H_Crossbow", "Knife", "Throwable"],
		"accent": [Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 2)],
	},
	"skeleton_minion": {"scene": "res://assets/kaykit/skeletons/Skeleton_Minion.glb", "props": [], "accent": [Vector2i(5, 0)]},
	"skeleton_rogue": {"scene": "res://assets/kaykit/skeletons/Skeleton_Rogue.glb", "props": [], "accent": [Vector2i(2, 2)]},
	"skeleton_warrior": {"scene": "res://assets/kaykit/skeletons/Skeleton_Warrior.glb", "props": [], "accent": [Vector2i(2, 2)]},
	"skeleton_mage": {"scene": "res://assets/kaykit/skeletons/Skeleton_Mage.glb", "props": [], "accent": [Vector2i(2, 2)]},
}

## 塗り替えたマテリアルの使い回し（"モデル:色:暗さ" -> StandardMaterial3D）。
static var _team_materials := {}


func build(kind: UnitKind.Id, team_color: Color, look: StringName, at: Vector3) -> UnitBody:
	if kind == UnitKind.Id.KING and KING_LOOKS.has(look):
		return _model_body(KING_LOOKS[look], team_color)
	if KINDS.has(kind):
		return _model_body(KINDS[kind], team_color)
	return super(kind, team_color, look, at)


func _model_body(shape: Dictionary, team_color: Color) -> UnitBody:
	var model_name: String = shape["model"]
	var source: Dictionary = MODELS[model_name]
	var model: Node3D = (load(source["scene"]) as PackedScene).instantiate()
	var size: float = shape.get("scale", 1.0)
	model.scale = Vector3.ONE * MODEL_SCALE * size
	_hold_props(model, shape.get("hold", {}))

	var shown: Array = shape["show"]
	for node_name: String in source["props"]:
		var part := model.find_child(node_name, true, false) as Node3D
		if part != null:
			part.visible = shown.has(node_name)

	var original: Material = null
	var first := model.find_children("*", "MeshInstance3D", true, false)
	if not first.is_empty():
		original = (first[0] as MeshInstance3D).mesh.surface_get_material(0)
	var moves := MOVES.duplicate()
	moves[&"idle"] = StringName(shape["idle"])
	moves[&"attack"] = StringName(shape["attack"])

	var body := ModelBody.new()
	body.body_height = MODEL_HEIGHT * size
	body.set_model(model, moves, func(shade: float) -> Material: return _team_material(model_name, team_color, original, shade))
	return body


## 小物を手の骨に付ける（hold: 骨の名前 -> HELD_PROPS の名前）。
static func _hold_props(model: Node3D, hold: Dictionary) -> void:
	if hold.is_empty():
		return
	var skeleton := model.find_children("*", "Skeleton3D", true, false)
	if skeleton.is_empty():
		return
	for bone: String in hold:
		var attachment := BoneAttachment3D.new()
		attachment.bone_name = bone
		skeleton[0].add_child(attachment)
		var prop: Node3D = (load(HELD_PROPS[hold[bone]]) as PackedScene).instantiate()
		prop.rotation_degrees = HELD_PROP_TURNS.get(hold[bone], Vector3.ZERO)
		attachment.add_child(prop)


## キャラクターのマテリアルを、差し色だけ陣営の色にしたものに差し替える。
## 明るさの濃淡は元のまま残し、色相と彩度だけを変える。shade は全体の明るさ（行動済みの駒は暗くする）。
static func _team_material(model_name: String, team_color: Color, source: Material, shade: float) -> Material:
	var key := "%s:%s:%s" % [model_name, team_color.to_html(), shade]
	if _team_materials.has(key):
		return _team_materials[key]
	if shade < 1.0:
		var dimmed := _team_material(model_name, team_color, source, 1.0).duplicate() as StandardMaterial3D
		dimmed.albedo_color = Color(shade, shade, shade)
		_team_materials[key] = dimmed
		return dimmed

	var material := source.duplicate() as StandardMaterial3D
	var image := material.albedo_texture.get_image()
	if image.is_compressed():
		image.decompress()
	image.clear_mipmaps()
	image.convert(Image.FORMAT_RGBA8)

	for swatch: Vector2i in MODELS[model_name]["accent"]:
		var origin := swatch * SWATCH_SIZE
		for y in SWATCH_SIZE.y:
			for x in SWATCH_SIZE.x:
				var c := image.get_pixel(origin.x + x, origin.y + y)
				c = Color.from_hsv(team_color.h, maxf(c.s, team_color.s * 0.8), c.v, c.a)
				image.set_pixel(origin.x + x, origin.y + y, c)

	image.generate_mipmaps()
	material.albedo_texture = ImageTexture.create_from_image(image)
	_team_materials[key] = material
	return material
