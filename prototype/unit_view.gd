extends Node3D
## 駒 1 体の見た目。
##
## KayKit のキャラクターは、持ちうる武器や盾がすべて付いた状態で入っているので、
## 種類ごとに使わないものを隠す。陣営の色は、足元の円盤と、服の差し色（マント・帽子など）で出す。
## 中立の駒（"core" / "elite"）は、素材を使わずコードで組み立てる、宙に浮く結晶のコア。

const CrystalMesh := preload("res://prototype/crystal_mesh.gd")

const MODEL_SCALE := 0.5
const BLEND_TIME := 0.15
## テクスチャは 128 x 256 の色見本を並べたもの。"accent" に挙げた見本（列, 行）を陣営の色に塗り替える。
const SWATCH_SIZE := Vector2i(128, 256)

const KINDS := {
	"knight": {
		"scene": "res://assets/kaykit/adventurers/Knight.glb",
		"hide": ["1H_Sword_Offhand", "Rectangle_Shield", "Round_Shield", "Spike_Shield", "2H_Sword"],
		"idle": "Idle",
		"accent": [Vector2i(0, 1), Vector2i(2, 2)],
	},
	"barbarian": {
		"scene": "res://assets/kaykit/adventurers/Barbarian.glb",
		"hide": ["1H_Axe_Offhand", "Barbarian_Round_Shield", "1H_Axe", "Mug"],
		"idle": "2H_Melee_Idle",
		"accent": [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 2)],
	},
	"mage": {
		"scene": "res://assets/kaykit/adventurers/Mage.glb",
		"hide": ["Spellbook", "Spellbook_open", "1H_Wand"],
		"idle": "Idle",
		"accent": [Vector2i(0, 1), Vector2i(1, 1), Vector2i(7, 1), Vector2i(2, 1), Vector2i(1, 2)],
	},
	"rogue": {
		"scene": "res://assets/kaykit/adventurers/Rogue.glb",
		"hide": ["Knife_Offhand", "1H_Crossbow", "Knife", "Throwable"],
		"idle": "Idle",
		"accent": [Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 2)],
	},
}

## 塗り替えたマテリアルの使い回し（"種類:色" -> StandardMaterial3D）。
static var _team_materials := {}

## 中立の駒の形。size は全体の大きさ、rings は周りを回る輪の数、shards は周りを回る欠片の数。
const CORES := {
	"core": {"size": 1.0, "rings": 1, "shards": 0},
	"elite": {"size": 1.45, "rings": 2, "shards": 3},
}
const CORE_HEIGHT := 0.55
const CORE_RING_COLOR := Color("8a6a2c")

var _player: AnimationPlayer
var _idle: StringName = &"Idle"
var _core: Node3D  # 浮いて回る部分（中立の駒だけ）
var _core_phase := 0.0
var _core_time := 0.0


## kind が KINDS にも CORES にも無ければ、仮の形（カプセル）で出す。
func setup(kind: String, team_color: Color) -> void:
	_add_base(team_color)
	if KINDS.has(kind):
		_add_model(kind, team_color)
	elif CORES.has(kind):
		_add_core(CORES[kind], team_color)
	else:
		_add_placeholder(team_color)
	play_idle()


func _process(delta: float) -> void:
	if _core == null:
		return
	_core_time += delta
	var t := _core_time + _core_phase
	_core.position.y = CORE_HEIGHT * _core.scale.y + sin(t * 2.0) * 0.05
	_core.rotation.y = t * 0.8


func play_idle() -> void:
	_play(_idle)


func play_run() -> void:
	_play(&"Running_A")


## 盤面上の向き（y は見ない）へ体を向ける。
func face(direction: Vector3) -> void:
	if Vector2(direction.x, direction.z).length() < 0.001:
		return
	rotation.y = atan2(direction.x, direction.z)


func _add_base(team_color: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.4
	mesh.bottom_radius = 0.4
	mesh.height = 0.04
	var material := StandardMaterial3D.new()
	material.albedo_color = team_color
	material.emission_enabled = true
	material.emission = team_color
	material.emission_energy_multiplier = 0.4
	var base := MeshInstance3D.new()
	base.mesh = mesh
	base.material_override = material
	base.position.y = 0.02
	base.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(base)


func _add_model(kind_name: String, team_color: Color) -> void:
	var kind: Dictionary = KINDS[kind_name]
	var scene: PackedScene = load(kind["scene"])
	var model: Node3D = scene.instantiate()
	model.scale = Vector3.ONE * MODEL_SCALE
	add_child(model)

	var material: Material = null
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if material == null:
			material = _team_material(kind_name, mesh.mesh.surface_get_material(0), team_color)
		mesh.material_override = material

	for node_name: String in kind["hide"]:
		var part := model.find_child(node_name, true, false) as Node3D
		if part != null:
			part.visible = false

	_idle = kind["idle"]
	_player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer


## キャラクターのマテリアルを、差し色だけ陣営の色にしたものに差し替える。
## 明るさの濃淡は元のまま残し、色相と彩度だけを変える。
func _team_material(kind_name: String, source: Material, team_color: Color) -> Material:
	var key := "%s:%s" % [kind_name, team_color.to_html()]
	if _team_materials.has(key):
		return _team_materials[key]

	var material := source.duplicate() as StandardMaterial3D
	var image := material.albedo_texture.get_image()
	if image.is_compressed():
		image.decompress()
	image.clear_mipmaps()
	image.convert(Image.FORMAT_RGBA8)

	for swatch: Vector2i in KINDS[kind_name]["accent"]:
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


func _play(animation: StringName) -> void:
	if _player == null or not _player.has_animation(animation):
		return
	_player.get_animation(animation).loop_mode = Animation.LOOP_LINEAR
	_player.play(animation, BLEND_TIME)
