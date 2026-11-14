extends Node3D
## 駒 1 体の見た目。
##
## KayKit のキャラクターは、持ちうる武器や盾がすべて付いた状態で入っているので、
## 種類ごとに使わないものを隠す。陣営の色は、足元の円盤と、服の差し色（マント・帽子など）で出す。
## 中立の駒（エナジー・コア / エリートミニオン）は、素材を使わずコードで組み立てる、宙に浮く結晶のコア。
## 頭の上に、HP のバーと、役割の 1 文字 + HP の数を出す。行動済みの駒は暗くする。
##
## ルールは持たない。何を見せるかは、呼ぶ側（イベントを再生する側）が決める。

const CrystalMesh := preload("res://prototype/crystal_mesh.gd")

const MODEL_SCALE := 0.5
const BLEND_TIME := 0.15
## テクスチャは 128 x 256 の色見本を並べたもの。"accent" に挙げた見本（列, 行）を陣営の色に塗り替える。
const SWATCH_SIZE := Vector2i(128, 256)

## 駒の種類ごとの形。"model" は MODELS の名前、"show" は持たせる小物（それ以外の小物は隠す）。
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
}

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
}

## 中立の駒の形。size は全体の大きさ、rings は周りを回る輪の数、shards は周りを回る欠片の数。
const CORES := {
	UnitKind.Id.MINION: {"size": 1.0, "rings": 1, "shards": 0},
	UnitKind.Id.ELITE_MINION: {"size": 1.45, "rings": 2, "shards": 3},
}
const CORE_HEIGHT := 0.55
const CORE_RING_COLOR := Color("8a6a2c")

## 頭の上の札に出す、役割の 1 文字。
const ROLE_MARKS := {
	UnitKind.Role.VANGUARD: "前",
	UnitKind.Role.REARGUARD: "後",
	UnitKind.Role.RAIDER: "奇",
	UnitKind.Role.HEALER: "回",
}

## 行動済みの駒は、この明るさまで暗くする。
const ACTED_SHADE := 0.42
const BAR_SIZE := Vector2i(44, 6)
const BAR_PIXEL := 0.018
const COLOR_GOLD := Color("f2c84b")

## 塗り替えたマテリアルの使い回し（"モデル:色:暗さ" -> StandardMaterial3D）。
static var _team_materials := {}

var _player: AnimationPlayer
var _idle: StringName = &"Idle"
var _attack: StringName = &""
var _core: Node3D  # 浮いて回る部分（中立の駒だけ）
var _core_phase := 0.0
var _core_time := 0.0

var _kind: UnitKind.Id
var _team_color: Color
var _max_hp := 1
## いま札に出している HP。検査用。
var shown_hp := 0
var _height := 1.3  # 札を出す高さ
var _acted := false
var _dying := false
var _model_name := ""
var _model_meshes: Array[MeshInstance3D] = []
var _base_material: StandardMaterial3D
var _bar: Sprite3D
var _tag: Label3D


func setup(kind: UnitKind.Id, team_color: Color, hp: int, max_hp: int) -> void:
	_kind = kind
	_team_color = team_color
	_max_hp = max_hp
	_add_base(team_color)
	if KINDS.has(kind):
		_add_model(KINDS[kind])
	elif CORES.has(kind):
		_add_core(CORES[kind], team_color)
		_height = 1.0 * float(CORES[kind]["size"]) + 0.15
	else:
		_add_placeholder(team_color)
	if kind == UnitKind.Id.KING:
		_add_crown()
	_add_tag()
	set_hp(hp)
	play_idle()


func _process(delta: float) -> void:
	if _core == null:
		return
	_core_time += delta
	var t := _core_time + _core_phase
	_core.position.y = CORE_HEIGHT * _core.scale.y + sin(t * 2.0) * 0.05
	_core.rotation.y = t * 0.8


func play_idle() -> void:
	if not _dying:
		_play(_idle, true)


func play_run() -> void:
	_play(&"Running_A", true)


## 攻撃の動き。当たる瞬間までの秒数を返す（呼ぶ側がそこでダメージを見せる）。
func play_attack() -> float:
	if _player != null and _player.has_animation(_attack):
		_play(_attack, false)
		return 0.4
	# アニメーションの無い駒（中立のコア）は、その場で跳ねる。
	var tween := create_tween()
	tween.tween_property(self, "position:y", 0.35, 0.12)
	tween.tween_property(self, "position:y", 0.0, 0.12)
	return 0.2


func play_hit() -> void:
	if _player != null and _player.has_animation(&"Hit_A"):
		_play(&"Hit_A", false)
	else:
		var tween := create_tween()
		tween.tween_property(self, "scale", Vector3.ONE * 0.8, 0.08)
		tween.tween_property(self, "scale", Vector3.ONE, 0.12)


## 倒れる動きをして、自分を取り除く。終わるまで待てる。
func play_death() -> void:
	_dying = true
	_bar.visible = false
	_tag.visible = false
	if _player != null and _player.has_animation(&"Death_A"):
		_play(&"Death_A", false)
		await get_tree().create_timer(0.75).timeout
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE * 0.01, 0.3)
	await tween.finished
	queue_free()


## 盤面上の向き（y は見ない）へ体を向ける。
func face(direction: Vector3) -> void:
	if Vector2(direction.x, direction.z).length() < 0.001:
		return
	rotation.y = atan2(direction.x, direction.z)


func set_hp(hp: int) -> void:
	shown_hp = hp
	var image := Image.create_empty(BAR_SIZE.x, BAR_SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.05, 0.05, 0.07, 0.9))
	var inner := BAR_SIZE - Vector2i(2, 2)
	var filled := ceili(inner.x * clampf(float(hp) / _max_hp, 0.0, 1.0))
	if filled > 0:
		var ratio := float(hp) / _max_hp
		var color := Color("5fd35f") if ratio > 0.5 else (Color("e8c23a") if ratio > 0.25 else Color("e8503a"))
		image.fill_rect(Rect2i(1, 1, filled, inner.y), color)
	_bar.texture = ImageTexture.create_from_image(image)
	var mark: String = ROLE_MARKS.get(UnitKind.role(_kind), "")
	if _kind == UnitKind.Id.KING:
		mark = "将"
	_tag.text = ("%s %d" % [mark, hp]).strip_edges()


## 行動済みの駒を暗くする。
func set_acted(acted: bool) -> void:
	if _acted == acted:
		return
	_acted = acted
	var shade := ACTED_SHADE if acted else 1.0
	_base_material.albedo_color = _team_color.darkened(1.0 - shade) if acted else _team_color
	_base_material.emission_energy_multiplier = 0.05 if acted else 0.4
	_tag.modulate = Color(0.6, 0.6, 0.6) if acted else Color.WHITE
	if not _model_meshes.is_empty():
		var material := _team_material(_model_meshes[0].mesh.surface_get_material(0), shade)
		for mesh in _model_meshes:
			mesh.material_override = material


func _add_base(team_color: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.4
	mesh.bottom_radius = 0.4
	mesh.height = 0.04
	_base_material = StandardMaterial3D.new()
	_base_material.albedo_color = team_color
	_base_material.emission_enabled = true
	_base_material.emission = team_color
	_base_material.emission_energy_multiplier = 0.4
	var base := MeshInstance3D.new()
	base.mesh = mesh
	base.material_override = _base_material
	base.position.y = 0.02
	base.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(base)


func _add_model(kind: Dictionary) -> void:
	_model_name = kind["model"]
	var source: Dictionary = MODELS[_model_name]
	var scene: PackedScene = load(source["scene"])
	var model: Node3D = scene.instantiate()
	var size: float = kind.get("scale", 1.0)
	model.scale = Vector3.ONE * MODEL_SCALE * size
	_height = 1.3 * size
	add_child(model)

	var material: Material = null
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if material == null:
			material = _team_material(mesh.mesh.surface_get_material(0), 1.0)
		mesh.material_override = material
		_model_meshes.append(mesh)

	var shown: Array = kind["show"]
	for node_name: String in source["props"]:
		var part := model.find_child(node_name, true, false) as Node3D
		if part != null:
			part.visible = shown.has(node_name)

	_idle = kind["idle"]
	_attack = kind["attack"]
	_player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _player != null:
		_player.animation_finished.connect(_on_animation_finished)


## キャラクターのマテリアルを、差し色だけ陣営の色にしたものに差し替える。
## 明るさの濃淡は元のまま残し、色相と彩度だけを変える。shade は全体の明るさ（行動済みの駒は暗くする）。
func _team_material(source: Material, shade: float) -> Material:
	var key := "%s:%s:%s" % [_model_name, _team_color.to_html(), shade]
	if _team_materials.has(key):
		return _team_materials[key]
	if shade < 1.0:
		var dimmed := _team_material(source, 1.0).duplicate() as StandardMaterial3D
		dimmed.albedo_color = Color(shade, shade, shade)
		_team_materials[key] = dimmed
		return dimmed

	var material := source.duplicate() as StandardMaterial3D
	var image := material.albedo_texture.get_image()
	if image.is_compressed():
		image.decompress()
	image.clear_mipmaps()
	image.convert(Image.FORMAT_RGBA8)

	for swatch: Vector2i in MODELS[_model_name]["accent"]:
		var origin := swatch * SWATCH_SIZE
		for y in SWATCH_SIZE.y:
			for x in SWATCH_SIZE.x:
				var c := image.get_pixel(origin.x + x, origin.y + y)
				c = Color.from_hsv(_team_color.h, maxf(c.s, _team_color.s * 0.8), c.v, c.a)
				image.set_pixel(origin.x + x, origin.y + y, c)

	image.generate_mipmaps()
	material.albedo_texture = ImageTexture.create_from_image(image)
	_team_materials[key] = material
	return material


## 将の目印。頭の上に浮かぶ金の輪。
func _add_crown() -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.13
	mesh.outer_radius = 0.19
	mesh.rings = 20
	mesh.ring_segments = 6
	var material := StandardMaterial3D.new()
	material.albedo_color = COLOR_GOLD
	material.emission_enabled = true
	material.emission = COLOR_GOLD
	material.emission_energy_multiplier = 0.5
	var crown := MeshInstance3D.new()
	crown.mesh = mesh
	crown.material_override = material
	crown.position.y = _height - 0.02
	crown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(crown)
	_height += 0.2


## 頭の上の札（HP のバーと、役割の 1 文字 + HP の数）。いつもカメラを向き、木や岩に隠れない。
func _add_tag() -> void:
	_bar = Sprite3D.new()
	_bar.pixel_size = BAR_PIXEL
	_bar.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bar.no_depth_test = true
	_bar.shaded = false
	_bar.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_bar.render_priority = 2
	_bar.position.y = _height
	add_child(_bar)

	_tag = Label3D.new()
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.no_depth_test = true
	_tag.pixel_size = 0.0055
	_tag.font_size = 52
	_tag.outline_size = 12
	_tag.render_priority = 3
	_tag.outline_render_priority = 2
	_tag.position.y = _height + 0.2
	add_child(_tag)


func _add_core(shape: Dictionary, color: Color) -> void:
	var glow := StandardMaterial3D.new()
	glow.albedo_color = color
	glow.emission_enabled = true
	glow.emission = color
	glow.emission_energy_multiplier = 0.3
	glow.roughness = 0.3
	var metal := StandardMaterial3D.new()
	metal.albedo_color = CORE_RING_COLOR
	metal.metallic = 0.6
	metal.roughness = 0.4

	_core = Node3D.new()
	_core.scale = Vector3.ONE * float(shape["size"])
	add_child(_core)
	# 駒ごとに揺れの位相をずらす（全部が揃って動かないように）。位置から決めるので毎回同じ。
	_core_phase = fposmod(global_position.x * 1.7 + global_position.z * 3.1, TAU)

	var body := MeshInstance3D.new()
	body.mesh = CrystalMesh.octahedron()
	body.material_override = glow
	body.scale = Vector3(0.2, 0.28, 0.2)
	_core.add_child(body)

	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.27
	ring_mesh.outer_radius = 0.31
	ring_mesh.rings = 24
	ring_mesh.ring_segments = 6
	for i in int(shape["rings"]):
		var ring := MeshInstance3D.new()
		ring.mesh = ring_mesh
		ring.material_override = metal
		ring.rotation = Vector3(deg_to_rad(70.0), deg_to_rad(90.0 * i), 0.0)
		_core.add_child(ring)

	var shard_mesh := CrystalMesh.build()
	for i in int(shape["shards"]):
		var angle := TAU * i / float(shape["shards"])
		var shard := MeshInstance3D.new()
		shard.mesh = shard_mesh
		shard.material_override = glow
		shard.scale = Vector3(0.04, 0.12, 0.04)
		shard.position = Vector3(cos(angle) * 0.42, -0.06, sin(angle) * 0.42)
		_core.add_child(shard)


func _add_placeholder(team_color: Color) -> void:
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.28
	mesh.height = 0.95
	var material := StandardMaterial3D.new()
	material.albedo_color = team_color
	material.roughness = 0.9
	var body := MeshInstance3D.new()
	body.mesh = mesh
	body.material_override = material
	body.position.y = 0.475
	add_child(body)


func _play(animation: StringName, loop: bool) -> void:
	if _player == null or not _player.has_animation(animation):
		return
	_player.get_animation(animation).loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	_player.play(animation, BLEND_TIME)


## 1 回きりの動き（攻撃・被弾）が終わったら、立ち姿に戻る。
func _on_animation_finished(_animation: StringName) -> void:
	play_idle()
