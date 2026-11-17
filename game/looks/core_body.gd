extends "res://game/unit_body.gd"
## 中立の駒（エナジー・コア / エリートミニオン）の体。素材を使わずコードで組み立てる、宙に浮く結晶のコア。
## どの組でも使える（組が中立の駒の形を持たなければ、これになる）。動きは unit_body.gd の代わりの動き。

const CrystalMesh := preload("res://game/crystal_mesh.gd")

## 中立の駒の形。size は全体の大きさ、rings は周りを回る輪の数、shards は周りを回る欠片の数。
## "color" があれば、結晶をその色にする（中ボスは、小さい中立の駒と色でも見分けられるようにする）。
## "spikes" は、足元から外へ突き出す大きい結晶の数。
const CORES := {
	UnitKind.Id.MINION: {"size": 1.0, "rings": 1, "shards": 0, "spikes": 0},
	UnitKind.Id.ELITE_MINION: {"size": 1.7, "rings": 2, "shards": 4, "spikes": 5, "color": Color("a13df0")},
}
const CORE_HEIGHT := 0.55
const CORE_RING_COLOR := Color("8a6a2c")

var _core: Node3D  # 浮いて回る部分
var _core_phase := 0.0
var _core_time := 0.0


static func has_shape(kind: UnitKind.Id) -> bool:
	return CORES.has(kind)


## kind の形で組み立てる。phase_from は揺れの位相を決める位置（駒ごとにずらす。位置から決めるので毎回同じ）。
func build(kind: UnitKind.Id, team_color: Color, phase_from: Vector3) -> void:
	var shape: Dictionary = CORES[kind]
	body_height = 1.0 * float(shape["size"]) + 0.15
	var color: Color = shape.get("color", team_color)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = color
	glow.emission_enabled = true
	glow.emission = color
	glow.emission_energy_multiplier = 0.9 if shape.has("color") else 0.3
	glow.roughness = 0.3
	var metal := StandardMaterial3D.new()
	metal.albedo_color = CORE_RING_COLOR
	metal.metallic = 0.6
	metal.roughness = 0.4

	_core = Node3D.new()
	_core.scale = Vector3.ONE * float(shape["size"])
	add_child(_core)
	_core_phase = fposmod(phase_from.x * 1.7 + phase_from.z * 3.1, TAU)

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

	# 足元から外へ突き出す結晶（回らない。中ボスの縄張りの主らしさ）。
	for i in int(shape["spikes"]):
		var angle := TAU * i / float(shape["spikes"]) + 0.3
		var outward := Vector3(cos(angle), 0.0, sin(angle))
		var spike := MeshInstance3D.new()
		spike.mesh = shard_mesh
		spike.material_override = glow
		spike.scale = Vector3(0.09, 0.42, 0.09)
		spike.position = outward * 0.3
		spike.rotate(outward.cross(Vector3.UP).normalized(), -deg_to_rad(28.0))
		add_child(spike)


func _process(delta: float) -> void:
	if _core == null:
		return
	_core_time += delta
	var t := _core_time + _core_phase
	_core.position.y = CORE_HEIGHT * _core.scale.y + sin(t * 2.0) * 0.05
	_core.rotation.y = t * 0.8
