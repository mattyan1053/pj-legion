extends Node3D
## 駒 1 体の見た目。
##
## KayKit のキャラクターは、持ちうる武器や盾がすべて付いた状態で入っているので、
## 種類ごとに使わないものを隠す。足元の円盤が陣営の色。

const MODEL_SCALE := 0.42
const BLEND_TIME := 0.15

const KINDS := {
	"knight": {
		"scene": "res://assets/kaykit/adventurers/Knight.glb",
		"hide": ["1H_Sword_Offhand", "Rectangle_Shield", "Round_Shield", "Spike_Shield", "2H_Sword"],
		"idle": "Idle",
	},
	"barbarian": {
		"scene": "res://assets/kaykit/adventurers/Barbarian.glb",
		"hide": ["1H_Axe_Offhand", "Barbarian_Round_Shield", "1H_Axe", "Mug"],
		"idle": "2H_Melee_Idle",
	},
	"mage": {
		"scene": "res://assets/kaykit/adventurers/Mage.glb",
		"hide": ["Spellbook", "Spellbook_open", "1H_Wand"],
		"idle": "Idle",
	},
	"rogue": {
		"scene": "res://assets/kaykit/adventurers/Rogue.glb",
		"hide": ["Knife_Offhand", "1H_Crossbow", "Knife", "Throwable"],
		"idle": "Idle",
	},
}

var _player: AnimationPlayer
var _idle: StringName = &"Idle"


## kind が KINDS に無ければ、仮の形（カプセル）で出す。
func setup(kind: String, team_color: Color) -> void:
	_add_base(team_color)
	if KINDS.has(kind):
		_add_model(KINDS[kind])
	else:
		_add_placeholder(team_color)
	play_idle()


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


func _add_model(kind: Dictionary) -> void:
	var scene: PackedScene = load(kind["scene"])
	var model: Node3D = scene.instantiate()
	model.scale = Vector3.ONE * MODEL_SCALE
	add_child(model)

	for node_name: String in kind["hide"]:
		var part := model.find_child(node_name, true, false) as Node3D
		if part != null:
			part.visible = false

	_idle = kind["idle"]
	_player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer


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
