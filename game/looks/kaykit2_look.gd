extends "res://game/looks/look_set.gd"
## 駒の見た目の組「KayKit 2」: 「人形」（KayKit Adventurers 1.0）と同じ作者の、作り直された 2.0 の人物（assets/kaykit/adventurers2/）。
## 頭の大きい人形の絵柄のまま、顔・髪・服の作りが細かい。人物は 8 人（騎士・盗賊・頭巾の盗賊・魔法使い・野伏・技師・蛮族・ドルイド）。
##
## 2.0 の人物は、体が部品（頭・兜・帽子・マント・腕・脚・背負い物）に分かれていて、どの人物も同じ骨組み（Rig_Medium、骨 23 本）。
## 頭を替えると、顔・髪・ひげが替わる。部品の付け替えで、名前のある人物（unit_looks.gd の PERSONS）を描き分ける。
## 武器と盾は別のファイル（props/）で、手の付け所の骨（handslot.r / handslot.l）に付ける。
## 動きも別のファイル（animations/。KayKit Character Animations 1.1 の Rig_Medium）で、体に後から足す。
## 魔物（骸骨）と将の別の姿（骸骨の将）は、「人形」の組の骸骨（同じ作者の Skeletons 1.0）をそのまま使う。

const ModelBody := preload("res://game/looks/model_body.gd")
const UnitLooks := preload("res://game/unit_looks.gd")
const Kaykit := preload("res://game/looks/kaykit_look.gd")

const DIR := "res://assets/kaykit/adventurers2/"
const MODEL_SCALE := 0.5
## 体の高さ（大きさ 1 のとき）。
const MODEL_HEIGHT := 1.3
## 動き（animations/ の 4 つのファイルの名前）。
const ANIMATION_FILES := ["Rig_Medium_General", "Rig_Medium_MovementBasic", "Rig_Medium_CombatMelee", "Rig_Medium_CombatRanged"]
## 種類によらない動きの名前。
const MOVES := {&"run": &"Running_A", &"hit": &"Hit_A", &"death": &"Death_A", &"gesture": &"Interact"}
const IDLE := "Idle_A"
const MELEE_1H := "Melee_1H_Attack_Chop"
const MELEE_2H := "Melee_2H_Attack_Slice"
const DUAL := "Melee_Dualwield_Attack_Slice"
const SHOOT_2H := "Ranged_2H_Shoot"
const BOW := "Ranged_Bow_Release"
const MAGIC := "Ranged_Magic_Shoot"
## テクスチャは 128 x 256 の色見本を 8 x 4 に並べたもの（1.0 と同じ並び）。どの人物も (1, 0) が髪（ひげ）の色。
const SWATCH_SIZE := Vector2i(128, 256)
const HAIR := Vector2i(1, 0)

## 素材の人物。"parts" は付け外しできる部品（kind や人物の "show" に挙げたものだけ出す）、"accent" は陣営の色に塗る色見本（列, 行）。
const MODELS := {
	"knight": {"file": "Knight", "parts": ["Knight_Helmet", "Knight_HelmetVisor", "Knight_Cape"], "accent": [Vector2i(0, 1)]},
	"rogue": {"file": "Rogue", "parts": ["Rogue_Cape"], "accent": [Vector2i(0, 1), Vector2i(1, 1)]},
	"rogue_hooded": {"file": "Rogue_Hooded", "parts": ["RogueHooded_Cape", "RogueHooded_Mask"], "accent": [Vector2i(0, 1), Vector2i(1, 1)]},
	"mage": {"file": "Mage", "parts": ["Mage_Hat", "Mage_Cape"], "accent": [Vector2i(0, 1), Vector2i(1, 1)]},
	"ranger": {"file": "Ranger", "parts": ["Ranger_Cape", "Ranger_Quiver"], "accent": [Vector2i(0, 1)]},
	"engineer": {"file": "Engineer", "parts": ["Engineer_Backpack", "Engineer_Goggles"], "accent": [Vector2i(1, 1)]},
	"barbarian": {"file": "Barbarian", "parts": ["Barbarian_BearHat"], "accent": [Vector2i(0, 1)]},
	"druid": {"file": "Druid", "parts": ["Druid_Backpack"], "accent": [Vector2i(0, 1), Vector2i(1, 1)]},
}

## 駒の種類ごとの形。"model" は MODELS の名前、"show" は出す部品、"right"・"left" は手に持つもの（props/ のファイルの名前）、
## "idle" と "attack" は立ち姿と攻撃の動き、"scale" は大きさ（無ければ 1）。
const KINDS := {
	UnitKind.Id.KING: {
		"model": "knight", "show": ["Knight_Helmet", "Knight_HelmetVisor", "Knight_Cape"], "right": "sword_2handed", "scale": 1.18,
		"idle": "Melee_2H_Idle", "attack": MELEE_2H,
	},
	UnitKind.Id.SHIELD_TROOPER: {
		"model": "knight", "show": ["Knight_Helmet", "Knight_HelmetVisor"], "right": "sword_1handed", "left": "shield_square",
		"attack": MELEE_1H,
	},
	UnitKind.Id.PALADIN: {
		"model": "knight", "show": ["Knight_Helmet", "Knight_Cape"], "right": "sword_1handed", "left": "shield_badge",
		"attack": MELEE_1H,
	},
	# 連邦（山の 3 州。銃と規律）の後衛は、長い銃。
	# 立ち姿は銃を構えたまま。素材の狙いと射撃の動きは、頭の数コマが「構えるまで」なので、飛ばして本体だけを使う（kaykit_look.gd の KINDS の説明）。
	UnitKind.Id.SNIPER: {
		"model": "ranger", "show": ["Ranger_Cape"], "right": "shotgun", "idle": "Ranged_2H_Aiming", "attack": SHOOT_2H,
		"skip": {&"idle": Kaykit.AIM_SKIP, &"attack": Kaykit.SHOT_SKIP}, "hit": Kaykit.SHOT_HIT,
	},
	UnitKind.Id.COMMANDO: {
		"model": "rogue_hooded", "show": ["RogueHooded_Mask"], "right": "dagger", "left": "dagger", "attack": DUAL,
	},
	# 衛生兵は、背負い物の技師に薬瓶。
	UnitKind.Id.MEDIC: {"model": "engineer", "show": ["Engineer_Backpack"], "right": "potion_medium_red", "attack": MAGIC},
	UnitKind.Id.SORCERER: {"model": "mage", "show": ["Mage_Hat", "Mage_Cape"], "right": "staff", "attack": MAGIC},
	UnitKind.Id.SPELLBLADE: {
		"model": "barbarian", "show": ["Barbarian_BearHat"], "right": "sword_2handed", "idle": "Melee_2H_Idle", "attack": MELEE_2H,
	},
	UnitKind.Id.PRIEST: {"model": "druid", "show": ["Druid_Backpack"], "right": "druid_staff", "attack": MAGIC},
}

## 名前のある人物の形（unit_looks.gd の PERSONS の名前 -> その人の駒の種類の形への書き足し）。
## 人物像（docs/story.md の「口調の見本」の「見た目」の行）に合わせて、同じ骨組みの人物の部品を付け替える。
## "head": 頭を別の人物の頭に替える（顔・髪・ひげが替わる）。"paint": 色見本の塗り替え（人物 -> {色見本 -> 色}）。
const PERSONS := {
	# ハーデン（20 代前半の男の士官）。兜の騎士の将のまま、面頬を上げて若い顔（騎士の頭）を見せる。
	&"harden": {"show": ["Knight_Helmet", "Knight_Cape"]},
	# 40 代の古参の男。技師の頭（ひげ）を茶色に、兜を脱ぐ。大きな盾。少し大きく。
	&"dawson": {
		"head": "engineer", "show": [], "scale": 1.08, "left": "shield_badge",
		"paint": {"engineer": {HAIR: Color("6e5a48")}},
	},
	# 10 代後半の女。小柄。盗賊（女）の体と頭に、長い銃。
	&"noe": {"model": "rogue", "show": [], "scale": 0.92},
	# 40 代の女の衛生兵。盗賊の女の頭（髪は白の混じった茶）。技師の背負い物に薬瓶。
	&"marta": {"head": "rogue", "show": ["Engineer_Backpack"], "paint": {"rogue": {HAIR: Color("8f7f74")}}},
	# 20 代の男の斥候。野伏の頭（男）に、頭巾の盗賊の軽装。短い刃物 2 本。
	&"pip": {"head": "ranger", "show": ["RogueHooded_Cape"]},
	# 20 代半ばの女の騎士。鎧と盾の騎士の、兜を脱いだ姿（盗賊の女の頭、金の髪）。
	&"yelda": {"head": "rogue", "show": ["Knight_Cape"], "paint": {"rogue": {HAIR: Color("d8b26a")}}},
	# 70 歳近い男の導師。禿げ頭に白いひげ（蛮族の頭）、長い衣（魔法使い）に杖と本。
	&"ul": {
		"model": "mage", "head": "barbarian", "show": ["Mage_Cape"], "right": "staff", "left": "spellbook_open",
		"paint": {"barbarian": {HAIR: Color("e8e6e0")}},
	},
	# 14 歳の男の子。騎士の若い頭（ひげ無し）に、とんがり帽子の魔法使いを、小さく。
	&"tio": {"head": "knight", "show": ["Mage_Hat"], "right": "wand", "scale": 0.84, "paint": {"knight": {HAIR: Color("8a5a3a")}}},
	# 20 代後半の女の影刃。細身で身軽。盗賊の体に、魔法使いの長い黒髪の頭と両手の剣。
	&"seris": {"model": "rogue", "head": "mage", "show": ["Rogue_Cape"]},
	# 40 代の女の将校。騎士の鎧とマントに、盗賊の女の頭（栗色の髪）と長い銃。
	&"valt": {
		"model": "knight", "head": "rogue", "show": ["Knight_Cape"], "scale": 1.04,
		"paint": {"rogue": {HAIR: Color("6b4a3a")}},
	},
	# 30 代の女の軍曹。騎士を真似た鎧と四角い盾（マントは外す）。暗い茶の髪。
	&"drill_sergeant": {
		"head": "rogue", "show": [], "left": "shield_square", "paint": {"rogue": {HAIR: Color("4a2e24")}},
	},
}

## 動きの表（ANIMATION_FILES をまとめたもの。初めて使うときに作る）。
static var _animations: AnimationLibrary
## 塗り替えたマテリアルの使い回し（"人物:色:暗さ:名前の人物" -> Material）。
static var _materials := {}


func _init() -> void:
	icon_dir = "res://assets/unit_icons/kaykit2"


func build(kind: UnitKind.Id, team_color: Color, look: StringName, at: Vector3) -> UnitBody:
	if PERSONS.has(look):
		return _model_body(person_shape(look), team_color, look)
	if kind == UnitKind.Id.KING and UnitLooks.KING_LOOKS.has(look):
		# 将の別の姿（骸骨の将）は、「人形」の組のもの。
		return UnitLooks.of(&"kaykit").build(kind, team_color, look, at)
	if KINDS.has(kind):
		return _model_body(KINDS[kind], team_color)
	# 魔物と将の別の姿は、「人形」の組の骸骨。
	return UnitLooks.of(&"kaykit").build(kind, team_color, look, at)


func has_person(person: StringName) -> bool:
	return PERSONS.has(person)


## 名前のある人物の形（PERSONS の書き足しを、その人の駒の種類の形に重ねたもの）。
static func person_shape(person: StringName) -> Dictionary:
	var shape: Dictionary = KINDS[UnitLooks.PERSONS[person]].duplicate()
	shape.merge(PERSONS[person], true)
	return shape


func _model_body(shape: Dictionary, team_color: Color, person := &"") -> UnitBody:
	var model_name: String = shape["model"]
	var model: Node3D = (load(DIR + "%s.glb" % MODELS[model_name]["file"]) as PackedScene).instantiate()
	var size: float = shape.get("scale", 1.0)
	model.scale = Vector3.ONE * MODEL_SCALE * size
	var skeleton := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for mesh: MeshInstance3D in skeleton.find_children("*", "MeshInstance3D", false, false):
		mesh.set_meta(&"kaykit2_model", model_name)
	var shown: Array = shape["show"]
	for part_name: String in MODELS[model_name]["parts"]:
		var part := skeleton.find_child(part_name, false, false) as Node3D
		if part != null:
			part.visible = shown.has(part_name)
	if shape.has("head"):
		_swap_head(skeleton, model_name, shape["head"], shown)
	for slot: String in ["right", "left"]:
		if shape.get(slot, "") != "":
			_hold(skeleton, "handslot.r" if slot == "right" else "handslot.l", shape[slot])

	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	player.add_animation_library(&"", _library())
	model.add_child(player)
	var moves := MOVES.duplicate()
	moves[&"idle"] = StringName(shape.get("idle", IDLE))
	moves[&"attack"] = StringName(shape["attack"])

	var body := ModelBody.new()
	body.body_height = MODEL_HEIGHT * size
	body.set_model(model, moves, Callable())
	body.set_timing(shape.get("skip", {}), shape.get("hit", ModelBody.ATTACK_HIT), shape.get("blend", ModelBody.BLEND_TIME))
	var paint := shape.get("paint", {}) as Dictionary
	body.set_surface_materials(func(mesh: MeshInstance3D, shade: float) -> void:
		var original := mesh.mesh.surface_get_material(0)
		if original == null:
			return
		if not mesh.has_meta(&"kaykit2_model"):
			mesh.material_override = _dimmed(original, shade)
			return
		var from: String = mesh.get_meta(&"kaykit2_model")
		mesh.material_override = _team_material(from, team_color, original, shade, person, paint.get(from, {})))
	return body


## 頭を、別の人物の頭（と、その人物の部品のうち show に挙げたもの）に替える。どの人物も同じ骨組みなので、そのまま付け替えられる。
static func _swap_head(skeleton: Skeleton3D, model_name: String, donor_name: String, shown: Array) -> void:
	var own_head := skeleton.find_child("*_Head", false, false)
	if own_head != null:
		own_head.get_parent().remove_child(own_head)
		own_head.free()
	# 帽子・兜は頭に合わせて作られているので、頭を替えたら外す（替えた先の人物の部品で、show にあるものは付ける）。
	for part_name: String in MODELS[model_name]["parts"]:
		if part_name.ends_with("_Hat") or part_name.contains("Helmet") or part_name.ends_with("_Mask"):
			var part := skeleton.find_child(part_name, false, false) as Node3D
			if part != null and not shown.has(part_name):
				part.visible = false
	var donor: Node3D = (load(DIR + "%s.glb" % MODELS[donor_name]["file"]) as PackedScene).instantiate()
	var donor_skeleton := donor.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for mesh: MeshInstance3D in donor_skeleton.find_children("*", "MeshInstance3D", false, false):
		var name := String(mesh.name)
		if not (name.ends_with("_Head") or shown.has(name)):
			continue
		donor_skeleton.remove_child(mesh)
		mesh.owner = null  # 元の人物は消すので、持ち主を外す
		mesh.set_meta(&"kaykit2_model", donor_name)
		skeleton.add_child(mesh)
		mesh.skeleton = NodePath("..")
	donor.free()


## 手に持つもの（props/ の file）を、手の付け所の骨に付ける。
static func _hold(skeleton: Skeleton3D, bone: String, file: String) -> void:
	var attachment := BoneAttachment3D.new()
	attachment.bone_name = bone
	skeleton.add_child(attachment)
	attachment.add_child((load(DIR + "props/%s.gltf" % file) as PackedScene).instantiate())


## 動きの表（animations/ の 4 つを 1 つにまとめたもの）。
static func _library() -> AnimationLibrary:
	if _animations != null:
		return _animations
	_animations = AnimationLibrary.new()
	for file: String in ANIMATION_FILES:
		var source: Node = (load(DIR + "animations/%s.glb" % file) as PackedScene).instantiate()
		var player := source.find_child("AnimationPlayer", true, false) as AnimationPlayer
		for animation_name: StringName in player.get_animation_list():
			if not _animations.has_animation(animation_name):
				_animations.add_animation(animation_name, player.get_animation(animation_name))
		source.free()
	return _animations


## 持ち物のマテリアルを暗くしたもの（行動済みの駒）。
static func _dimmed(source: Material, shade: float) -> Material:
	if shade >= 1.0:
		return null
	var key := "dim:%d:%s" % [source.get_instance_id(), shade]
	if not _materials.has(key):
		var material := source.duplicate() as StandardMaterial3D
		material.albedo_color = Color(shade, shade, shade)
		_materials[key] = material
	return _materials[key]


## 人物のマテリアルを、差し色だけ陣営の色にしたものに差し替える（「人形」の組と同じ塗り方）。
## 明るさの濃淡は元のまま残し、色相と彩度だけを変える。shade は全体の明るさ（行動済みの駒は暗くする）。
## person と paint は名前のある人物の塗り替え（paint: 色見本 -> 色。陣営の色より先に塗り、塗った見本は陣営の色にしない）。
static func _team_material(model_name: String, team_color: Color, source: Material, shade: float, person := &"", paint := {}) -> Material:
	var key := "%s:%s:%s:%s" % [model_name, team_color.to_html(), shade, person]
	if _materials.has(key):
		return _materials[key]
	if shade < 1.0:
		var dimmed := _team_material(model_name, team_color, source, 1.0, person, paint).duplicate() as StandardMaterial3D
		dimmed.albedo_color = Color(shade, shade, shade)
		_materials[key] = dimmed
		return dimmed

	var material := source.duplicate() as StandardMaterial3D
	var image := material.albedo_texture.get_image()
	if image.is_compressed():
		image.decompress()
	image.clear_mipmaps()
	image.convert(Image.FORMAT_RGBA8)
	for swatch: Vector2i in paint:
		var origin := swatch * SWATCH_SIZE
		var to: Color = paint[swatch]
		var middle := image.get_pixel(origin.x + SWATCH_SIZE.x / 2, origin.y + SWATCH_SIZE.y / 2)
		for y in SWATCH_SIZE.y:
			for x in SWATCH_SIZE.x:
				var c := image.get_pixel(origin.x + x, origin.y + y)
				var ratio := c.v / maxf(middle.v, 0.01)
				image.set_pixel(origin.x + x, origin.y + y, Color(to.r * ratio, to.g * ratio, to.b * ratio, c.a).clamp())
	for swatch: Vector2i in MODELS[model_name]["accent"]:
		if paint.has(swatch):
			continue
		var origin := swatch * SWATCH_SIZE
		for y in SWATCH_SIZE.y:
			for x in SWATCH_SIZE.x:
				var c := image.get_pixel(origin.x + x, origin.y + y)
				image.set_pixel(origin.x + x, origin.y + y, Color.from_hsv(team_color.h, maxf(c.s, team_color.s * 0.8), c.v, c.a))
	image.generate_mipmaps()
	material.albedo_texture = ImageTexture.create_from_image(image)
	_materials[key] = material
	return material
