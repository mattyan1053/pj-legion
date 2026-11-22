extends "res://game/looks/look_set.gd"
## 駒の見た目の組「KayKit」: 頭の大きい人形のような低ポリの人物（assets/kaykit/）。
##
## KayKit のキャラクターは、持ちうる武器や盾がすべて付いた状態で入っているので、
## 種類ごとに使わないものを隠す。陣営の色は、服の差し色（マント・帽子など）で出す。
## 魔物（骸骨）は KayKit の骸骨の素材に、別の素材の武器を手の骨に付ける。
## 中立の駒は、どの組とも同じ結晶のコア（core_body.gd）。

const ModelBody := preload("res://game/looks/model_body.gd")
const UnitLooks := preload("res://game/unit_looks.gd")

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

## 名前のある人物の形（unit_looks.gd の PERSONS の名前 -> その人の駒の種類の形への書き足し）。
## 人物像（docs/story.md の「口調の見本」の「見た目」の行）に合わせて、同じ骨組みのキャラクターの部品を付け替える。
## "swap": 体の部品の付け替え（元の部品 -> [キャラクター, 部品]）。頭を替えると、顔・髪・ひげが替わる。
## "borrow": 別のキャラクターの小物（[キャラクター, 小物] の列。同じ名前の付け所に付け、いつも出す）。
## "hide": 隠す部品（兜・帽子・マントなど）。
## "paint": 色見本の塗り替え（キャラクター -> {色見本（列, 行） -> 色}）。髪の色、衣の色。塗った見本は陣営の色にしない。
## どの KayKit のキャラクターも、色見本の (1, 0) が髪（ひげ）の色。
const PERSONS := {
	# ハーデン（20 代前半の男の士官）は、兜の騎士の将の形のままで合うので書かない。
	# 40 代の古参の男。がっしりした体に、使い込んだ鎧と大きな盾。禿げ頭にひげの頭（Barbarian）で、兜は脱ぐ。少し大きく。
	&"dawson": {
		"swap": {"Knight_Head": ["barbarian", "Barbarian_Head"]}, "hide": ["Knight_Helmet"], "scale": 1.08,
		"paint": {"barbarian": {Vector2i(1, 0): Color("6e5a48")}},
	},
	# 10 代後半の女。小柄。軽装に長い弓（クロスボウ）。
	&"noe": {"scale": 0.92},
	# 40 代の女の衛生兵。髪の長い女の頭（Rogue）に、白い上着（Mage の衣を白に）。帽子は無し。髪は白の混じった茶。
	&"marta": {
		"swap": {"Mage_Head": ["rogue", "Rogue_Head"]}, "hide": ["Mage_Hat"],
		"paint": {
			"mage": {Vector2i(0, 1): Color("e4e6e8"), Vector2i(1, 1): Color("e4e6e8"), Vector2i(7, 1): Color("9aa0a6")},
			"rogue": {Vector2i(1, 0): Color("8f7f74")},
		},
	},
	# 20 代の男の斥候。頭巾をかぶった軽装（髪を出したノエと見分ける）。短い刃物 2 本。
	&"pip": {"model": "rogue_hooded"},
	# 20 代半ばの女の騎士。鎧と盾の騎士の、兜を脱いだ姿（髪の長い女の頭）。将の印は駒の見た目が付ける。
	&"yelda": {
		"swap": {"Knight_Head": ["rogue", "Rogue_Head"]}, "hide": ["Knight_Helmet"],
		"paint": {"rogue": {Vector2i(1, 0): Color("d8b26a")}},
	},
	# 70 歳近い男の導師。禿げ頭に白いひげ（Barbarian の頭）、長い衣（Mage）に杖と本。
	&"ul": {
		"swap": {"Mage_Head": ["barbarian", "Barbarian_Head"]}, "hide": ["Mage_Hat"],
		"show": ["2H_Staff", "Spellbook"],
		"paint": {"barbarian": {Vector2i(1, 0): Color("e8e6e0")}},
	},
	# 14 歳の男の子。とんがり帽子の若い顔の魔法使いを、小さく。
	&"tio": {"scale": 0.86},
	# 20 代後半の女の影刃。細身で身軽。軽装（Rogue）に、黒い髪と両手の剣（Knight の剣）。
	&"seris": {
		"model": "rogue", "show": [], "borrow": [["knight", "2H_Sword"]],
		"paint": {"rogue": {Vector2i(1, 0): Color("2a2630")}},
	},
	# 40 代の女の将校。背筋の伸びた鎧（Knight の体とマント）に、女の頭（髪は栗色）と長い弓（Rogue のクロスボウ）。
	&"valt": {
		"model": "knight", "show": [], "borrow": [["rogue", "2H_Crossbow"]],
		"swap": {"Knight_Head": ["rogue", "Rogue_Head"]}, "hide": ["Knight_Helmet"], "scale": 1.04,
		"paint": {"rogue": {Vector2i(1, 0): Color("6b4a3a")}},
	},
	# 30 代の女の軍曹。騎士を真似た鎧と盾に兜。兜の下から長い髪が出る（女の頭）。
	&"drill_sergeant": {
		"swap": {"Knight_Head": ["rogue", "Rogue_Head"]},
		"paint": {"rogue": {Vector2i(1, 0): Color("5a3a2c")}},
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
	# 頭巾をかぶった Rogue（体と小物は Rogue と同じ。頭だけ頭巾の形）。
	"rogue_hooded": {
		"scene": "res://assets/kaykit/adventurers/Rogue_Hooded.glb",
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
	if PERSONS.has(look):
		return _model_body(person_shape(look), team_color, look)
	if kind == UnitKind.Id.KING and KING_LOOKS.has(look):
		return _model_body(KING_LOOKS[look], team_color)
	if KINDS.has(kind):
		return _model_body(KINDS[kind], team_color)
	return super(kind, team_color, look, at)


func has_person(person: StringName) -> bool:
	return PERSONS.has(person)


## 名前のある人物の形（PERSONS の書き足しを、その人の駒の種類の形に重ねたもの）。
static func person_shape(person: StringName) -> Dictionary:
	var shape: Dictionary = KINDS[UnitLooks.PERSONS[person]].duplicate()
	shape.merge(PERSONS[person], true)
	return shape


## person は名前のある人物（PERSONS の名前。色の塗り替えを人物ごとに分ける）。
func _model_body(shape: Dictionary, team_color: Color, person := &"") -> UnitBody:
	var model_name: String = shape["model"]
	var source: Dictionary = MODELS[model_name]
	var model: Node3D = (load(source["scene"]) as PackedScene).instantiate()
	var size: float = shape.get("scale", 1.0)
	model.scale = Vector3.ONE * MODEL_SCALE * size
	_hold_props(model, shape.get("hold", {}))
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mesh.set_meta(&"kaykit_model", model_name)

	var shown: Array = shape["show"]
	for node_name: String in source["props"]:
		var part := model.find_child(node_name, true, false) as Node3D
		if part != null:
			part.visible = shown.has(node_name)
	_swap_parts(model, shape.get("swap", {}))
	_borrow_props(model, shape.get("borrow", []))
	for node_name: String in shape.get("hide", []):
		var hidden := model.find_child(node_name, true, false) as Node3D
		if hidden != null:
			hidden.visible = false

	var moves := MOVES.duplicate()
	moves[&"idle"] = StringName(shape["idle"])
	moves[&"attack"] = StringName(shape["attack"])

	var body := ModelBody.new()
	body.body_height = MODEL_HEIGHT * size
	body.set_model(model, moves, Callable())
	var paint := shape.get("paint", {}) as Dictionary
	body.set_surface_materials(func(mesh: MeshInstance3D, shade: float) -> void:
		var from: String = mesh.get_meta(&"kaykit_model", model_name)
		var original := mesh.mesh.surface_get_material(0)
		if original == null:
			return
		mesh.material_override = _team_material(from, team_color, original, shade, person, paint.get(from, {})))
	return body


## 体の部品（骨に沿って曲がる面）を、別のキャラクターの同じ場所の部品に替える（swap: 元の部品の名前 -> [キャラクター, 部品の名前]）。
## KayKit の Adventurers は、どのキャラクターも同じ骨組み（骨の名前と並びが同じ）なので、部品をそのまま付け替えられる。
static func _swap_parts(model: Node3D, swap: Dictionary) -> void:
	if swap.is_empty():
		return
	var skeleton := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for old_name: String in swap:
		var old_part := model.find_child(old_name, true, false)
		if old_part != null:
			old_part.get_parent().remove_child(old_part)
			old_part.free()
		var donor_name: String = swap[old_name][0]
		var donor: Node3D = (load(MODELS[donor_name]["scene"]) as PackedScene).instantiate()
		var part := donor.find_child(swap[old_name][1], true, false) as MeshInstance3D
		part.get_parent().remove_child(part)
		part.set_meta(&"kaykit_model", donor_name)
		skeleton.add_child(part)
		part.skeleton = NodePath("..")
		donor.free()


## 別のキャラクターの小物・かぶり物を、同じ名前の付け所（手・頭・胸の骨）に付ける（borrow: [キャラクター, 小物の名前] の列）。
static func _borrow_props(model: Node3D, borrow: Array) -> void:
	for entry: Array in borrow:
		var donor_name: String = entry[0]
		var donor: Node3D = (load(MODELS[donor_name]["scene"]) as PackedScene).instantiate()
		var prop := donor.find_child(entry[1], true, false) as Node3D
		var slot := model.find_child(String(prop.get_parent().name), true, false)
		var kept := prop.transform
		prop.get_parent().remove_child(prop)
		prop.set_meta(&"kaykit_model", donor_name)
		prop.visible = true
		slot.add_child(prop)
		prop.transform = kept
		donor.free()


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
## person と paint は名前のある人物の塗り替え（paint: 色見本（列, 行） -> 色。陣営の色より先に塗り、塗った見本は陣営の色にしない）。
static func _team_material(model_name: String, team_color: Color, source: Material, shade: float, person := &"", paint := {}) -> Material:
	var key := "%s:%s:%s:%s" % [model_name, team_color.to_html(), shade, person]
	if _team_materials.has(key):
		return _team_materials[key]
	if shade < 1.0:
		var dimmed := _team_material(model_name, team_color, source, 1.0, person, paint).duplicate() as StandardMaterial3D
		dimmed.albedo_color = Color(shade, shade, shade)
		_team_materials[key] = dimmed
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
				# 見本の中の濃淡（真ん中との明るさの比）を残して、決めた色にする。
				var ratio := c.v / maxf(middle.v, 0.01)
				image.set_pixel(origin.x + x, origin.y + y, Color(to.r * ratio, to.g * ratio, to.b * ratio, c.a).clamp())
	for swatch: Vector2i in MODELS[model_name]["accent"]:
		if paint.has(swatch):
			continue
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
