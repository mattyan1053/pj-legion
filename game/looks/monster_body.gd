extends RefCounted
## 骸骨でない魔物（大蝙蝠・ほつれ・糸針）と骸骨旗手の体。どの見た目の組でも同じ形（組が形を持たなければ、look_set.gd がこれを使う）。
##
## - 大蝙蝠: Quaternius の Animated Monster Pack の Bat（assets/quaternius/monsters/Bat.fbx。CC0）。宙に浮かせる。腹を陣営の色に塗る
## - ほつれ: 同じパックの Slime（Slime.fbx）。体を糸の青白い色に塗り、目を陣営の色にする
## - 糸針: 素材を使わず、コードで組む結晶の針の束（crystal_mesh.gd）。根元の輪が陣営の色
## - 骸骨旗手: 「人物」の組の骸骨（quaternius_skeleton.gd）に、陣営の色の旗を持たせたもの
## 動きは素材の 4〜5 つ（立つ・走る・殴る・倒れる。大蝙蝠は被弾も）。糸針は unit_body.gd の代わりの動き。

const UnitBody := preload("res://game/unit_body.gd")
const ModelBody := preload("res://game/looks/model_body.gd")
const Skeleton := preload("res://game/looks/quaternius_skeleton.gd")
const CrystalMesh := preload("res://game/crystal_mesh.gd")
const Palette := preload("res://game/ui_palette.gd")

const DIR := "res://assets/quaternius/monsters/"
## 糸（結晶）の青白い色。ほつれの体と、糸針の針。
const THREAD := Palette.MONSTER_GLOW

## 素材ごとの形。"raw" は素材の足から頭の上までの高さ（素材は cm で入っていて、骨の親が 100 倍）、"size" は駒の背に対する大きさ、
## "lift" は浮かせる高さ（駒の背に対する割合）、"turn" は前を向かせる回し方（度）、"paint" は塗り替える面（素材のマテリアルの名前 -> "team" か色）。
const MODELS := {
	UnitKind.Id.BAT: {
		"file": "Bat", "raw": 4.3, "size": 0.65, "lift": 0.3,
		"moves": {
			&"idle": &"BatArmature|Bat_Flying", &"run": &"BatArmature|Bat_Flying", &"attack": &"BatArmature|Bat_Attack",
			&"hit": &"BatArmature|Bat_Hit", &"death": &"BatArmature|Bat_Death",
		},
		"paint": {"Belly": "team"},
	},
	UnitKind.Id.FRAY: {
		"file": "Slime", "raw": 3.06, "size": 0.5, "lift": 0.0, "turn": -90.0,
		"moves": {
			&"idle": &"Armature|Slime_Idle", &"run": &"Armature|Slime_Walk", &"attack": &"Armature|Slime_Attack",
			&"death": &"Armature|Slime_Death",
		},
		"paint": {"Body": THREAD, "Eyes": "team"},
	},
}

## 塗り替えたマテリアルの使い回し（"面:色:暗さ" -> Material）。
static var _materials := {}


static func has_shape(kind: UnitKind.Id) -> bool:
	return MODELS.has(kind) or kind == UnitKind.Id.NEEDLE or kind == UnitKind.Id.SKELETON_BANNER


## kind の体。height は、その組の人の駒の背（倍率 1 の駒の高さ）。
static func build(kind: UnitKind.Id, team_color: Color, height: float) -> UnitBody:
	if kind == UnitKind.Id.SKELETON_BANNER:
		return Skeleton.build(Skeleton.KINDS[kind], team_color, height)
	if kind == UnitKind.Id.NEEDLE:
		return _needle(team_color, height)
	return _model(MODELS[kind], team_color, height)


static func _model(shape: Dictionary, team_color: Color, height: float) -> UnitBody:
	var model: Node3D = (load(DIR + "%s.fbx" % shape["file"]) as PackedScene).instantiate()
	var size: float = shape["size"]
	model.scale = Vector3.ONE * height * size / float(shape["raw"])
	model.position.y = height * float(shape["lift"])
	model.rotation_degrees.y = shape.get("turn", 0.0)
	var body := ModelBody.new()
	body.body_height = height * (size + float(shape["lift"]))
	body.set_model(model, shape["moves"], Callable())
	var paint: Dictionary = shape["paint"]
	body.set_surface_materials(func(mesh: MeshInstance3D, shade: float) -> void: _paint(mesh, paint, team_color, shade))
	return body


## 面ごとに、素材の色（paint にあれば、その色か陣営の色）を暗さ shade で塗る。
static func _paint(mesh: MeshInstance3D, paint: Dictionary, team_color: Color, shade: float) -> void:
	for i in mesh.mesh.get_surface_count():
		var original := mesh.mesh.surface_get_material(i) as StandardMaterial3D
		var name := original.resource_name if original != null else ""
		var color: Color = original.albedo_color if original != null else Color.WHITE
		if paint.has(name):
			color = team_color if paint[name] is String else paint[name]
		var key := "%s:%s:%s" % [name, color.to_html(), shade]
		if not _materials.has(key):
			var material := StandardMaterial3D.new()
			material.albedo_color = Color(color.r * shade, color.g * shade, color.b * shade)
			material.roughness = 0.8
			_materials[key] = material
		mesh.set_surface_override_material(i, _materials[key])


## 糸針: 地面から斜めに突き出す結晶の針の束と、根元の陣営の色の輪。
static func _needle(team_color: Color, height: float) -> UnitBody:
	var body := NeedleBody.new()
	var crystal := StandardMaterial3D.new()
	crystal.albedo_color = THREAD
	crystal.emission_enabled = true
	crystal.emission = THREAD
	crystal.emission_energy_multiplier = 0.35
	crystal.roughness = 0.3
	var shard := CrystalMesh.build()
	# [向き（度）, 外へ出す距離, 傾き（度）, 高さ（駒の背に対する割合）, 太さ]
	for spec: Array in [[0.0, 0.0, 0.0, 0.95, 0.07], [40.0, 0.12, 22.0, 0.62, 0.05], [160.0, 0.13, 26.0, 0.55, 0.05], [280.0, 0.12, 20.0, 0.7, 0.05]]:
		var toward := Vector3.RIGHT.rotated(Vector3.UP, deg_to_rad(spec[0]))
		var needle := MeshInstance3D.new()
		needle.mesh = shard
		needle.material_override = crystal
		needle.scale = Vector3(spec[4], height * float(spec[3]), spec[4])
		needle.position = toward * float(spec[1])
		if spec[2] > 0.0:
			needle.rotate(toward.cross(Vector3.UP).normalized(), -deg_to_rad(spec[2]))
		body.add_child(needle)
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.16
	ring_mesh.outer_radius = 0.22
	var ring := MeshInstance3D.new()
	ring.mesh = ring_mesh
	var band := StandardMaterial3D.new()
	band.albedo_color = team_color
	band.roughness = 0.7
	ring.material_override = band
	ring.position.y = 0.05
	body.add_child(ring)
	body.crystal = crystal
	body.body_height = height * 0.95
	return body


## 糸針の体。暗さは針の光で出す。
class NeedleBody:
	extends "res://game/unit_body.gd"
	var crystal: StandardMaterial3D

	func set_shade(shade: float) -> void:
		if crystal != null:
			crystal.albedo_color = Color(THREAD.r * shade, THREAD.g * shade, THREAD.b * shade)
			crystal.emission_energy_multiplier = 0.35 * shade
