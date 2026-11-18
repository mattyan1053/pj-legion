extends "res://game/unit_body.gd"
## 駒の見た目の組「盤の駒」（token_look.gd）の体。素材を使わず、コードで組んだ形を、簡単な変形で動かす。
## 立ち姿はゆっくり上下に揺れ、走ると小さく跳ね、攻撃は前へ突き出し、被弾は後ろへ傾き、倒れるときは横に倒れる。

## 体の前は +Z（駒の見た目の face が、体の +Z を向ける）。
const FORWARD := Vector3(0.0, 0.0, 1.0)
const ATTACK_HIT := 0.22
const DEATH_TIME := 0.45
## 光るもの（杖の玉、回復の十字）の光の強さ。
const GLOW_ENERGY := 0.8

## [MeshInstance3D, 元の色] の列（明るさを変えるとき、元の色から塗り直す）。
var _parts: Array = []
## 動く部分（台座の上。台座は動かさない）。
var figure := Node3D.new()
var _mode := &"idle"
var _time := 0.0
var _phase := 0.0
var _tween: Tween
var _dying := false
## マテリアルの使い回し（"色:光る" -> StandardMaterial3D）。
static var _materials := {}


func _init() -> void:
	add_child(figure)


## 揺れの位相（駒ごとにずらす）。
func set_phase(at: Vector3) -> void:
	_phase = fposmod(at.x * 1.3 + at.z * 2.3, TAU)


## 形を 1 つ足す（parent に。mesh の形、色、置き場所、回し方（度））。光るものは glow。
## lit は、光の当たらない側でも沈まないよう、自分の色でほのかに光らせる強さ（陣営の色の胴。0 なら光らない）。
func part(parent: Node3D, mesh: Mesh, color: Color, at: Vector3, turn := Vector3.ZERO, glow := false, lit := 0.0) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	instance.rotation_degrees = turn
	var energy := GLOW_ENERGY if glow else lit
	instance.material_override = _material(color, energy)
	parent.add_child(instance)
	_parts.append([instance, color, energy])
	return instance


func set_shade(shade: float) -> void:
	for entry: Array in _parts:
		var color: Color = entry[1]
		(entry[0] as MeshInstance3D).material_override = _material(Color(color.r * shade, color.g * shade, color.b * shade, color.a), entry[2])


static func _material(color: Color, energy: float) -> StandardMaterial3D:
	var key := "%s:%s" % [color.to_html(), energy]
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.55
		if energy > 0.0:
			material.emission_enabled = true
			material.emission = color
			material.emission_energy_multiplier = energy
		_materials[key] = material
	return _materials[key]


func _process(delta: float) -> void:
	if _dying or (_tween != null and _tween.is_running()):
		return
	_time += delta
	var t := _time + _phase
	match _mode:
		&"run":
			figure.position.y = absf(sin(t * 11.0)) * 0.09
			figure.rotation.z = sin(t * 11.0) * 0.08
		_:
			figure.position.y = sin(t * 2.2) * 0.025
			figure.rotation.z = 0.0


func play_idle() -> void:
	if not _dying:
		_mode = &"idle"


func play_run() -> void:
	_mode = &"run"


func play_gesture() -> void:
	_start()
	_tween.tween_property(figure, "position:y", 0.14, 0.12)
	_tween.tween_property(figure, "position:y", 0.0, 0.12)
	_tween.tween_property(figure, "position:y", 0.08, 0.1)
	_tween.tween_property(figure, "position:y", 0.0, 0.1)


func play_attack() -> float:
	_start()
	_tween.tween_property(figure, "rotation:x", deg_to_rad(-12.0), 0.1)
	_tween.parallel().tween_property(figure, "position", FORWARD * -0.06, 0.1)
	_tween.tween_property(figure, "rotation:x", deg_to_rad(22.0), 0.1)
	_tween.parallel().tween_property(figure, "position", FORWARD * 0.22 + Vector3.UP * 0.04, 0.1)
	_tween.tween_property(figure, "rotation:x", 0.0, 0.2)
	_tween.parallel().tween_property(figure, "position", Vector3.ZERO, 0.2)
	return ATTACK_HIT


func play_hit() -> void:
	_start()
	_tween.tween_property(figure, "rotation:x", deg_to_rad(-20.0), 0.07)
	_tween.parallel().tween_property(figure, "position", FORWARD * -0.08, 0.07)
	_tween.tween_property(figure, "rotation:x", 0.0, 0.18)
	_tween.parallel().tween_property(figure, "position", Vector3.ZERO, 0.18)


func play_death() -> float:
	_start()
	_dying = true
	_tween.tween_property(figure, "rotation:z", deg_to_rad(88.0), DEATH_TIME).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(figure, "position:y", 0.12, DEATH_TIME)
	return DEATH_TIME


func _start() -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
