extends "res://game/unit_body.gd"
## 骨と動きの入った素材の人形の体（KayKit など）。動きは素材のアニメーションを名前で引く。
## 名前の無い動きは、unit_body.gd の代わりの動きになる。

const BLEND_TIME := 0.15
## 攻撃の動きを始めてから当たるまでの秒数と、倒れる動きを待つ秒数（素材のアニメーションの場合）。
const ATTACK_HIT := 0.4
const DEATH_TIME := 0.75

var _player: AnimationPlayer
## 動きの名前（idle・run・attack・hit・death・gesture） -> 素材のアニメーションの名前。
var _moves := {}
var _meshes: Array[MeshInstance3D] = []
## 明るさ（float） -> 体に当てるマテリアル。
var _material_for: Callable
var _dying := false


## model（素材のシーンを実体にしたもの）を体にする。moves は動きの名前の表、material_for は明るさからマテリアルを返す。
func set_model(model: Node3D, moves: Dictionary, material_for: Callable) -> void:
	add_child(model)
	_moves = moves
	_material_for = material_for
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		_meshes.append(mesh)
	set_shade(1.0)
	_player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _player != null:
		_player.animation_finished.connect(_on_animation_finished)


func play_idle() -> void:
	if not _dying:
		_play(&"idle", true)


func play_run() -> void:
	_play(&"run", true)


func play_gesture() -> void:
	_play(&"gesture", false)


func play_attack() -> float:
	if _has(&"attack"):
		_play(&"attack", false)
		return ATTACK_HIT
	return super()


func play_hit() -> void:
	if _has(&"hit"):
		_play(&"hit", false)
	else:
		super()


func play_death() -> float:
	_dying = true
	if _has(&"death"):
		_play(&"death", false)
		return DEATH_TIME
	return 0.0


func set_shade(shade: float) -> void:
	if _meshes.is_empty() or not _material_for.is_valid():
		return
	var material: Material = _material_for.call(shade)
	for mesh in _meshes:
		mesh.material_override = material


func _has(move: StringName) -> bool:
	return _player != null and _player.has_animation(_moves.get(move, &""))


func _play(move: StringName, loop: bool) -> void:
	if not _has(move):
		return
	var animation: StringName = _moves[move]
	_player.get_animation(animation).loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	_player.play(animation, BLEND_TIME)


## 1 回きりの動き（攻撃・被弾・身振り）が終わったら、立ち姿に戻る。
func _on_animation_finished(_animation: StringName) -> void:
	play_idle()
