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
## 明るさ（float） -> 体に当てるマテリアル（体の全部の面に同じものを当てる素材）。
var _material_for: Callable
## (MeshInstance3D, 明るさ) -> 面ごとにマテリアルを当てる（面ごとに色の違う素材）。_material_for より先に見る。
var _surface_painter: Callable
var _dying := false
## 動きの頭を飛ばす秒数（動きの名前 -> 秒）。素材の動きが「構えるまでの数コマ + 本体」になっているとき、本体だけを使う
## （狙いの動きを立ち姿として繰り返すと、繰り返すたびに構え直して、姿勢が飛ぶ）。
var _skips := {}
## 攻撃の動きを始めてから当たるまでの秒数（頭を飛ばした攻撃は、そのぶん早く当たる）。
var _attack_hit := ATTACK_HIT
## 攻撃へ入るときと、攻撃から立ち姿へ戻るときのつなぎの秒数。立ち姿と攻撃の姿勢が離れている形は、長くする（短いと姿勢が飛んで見える）。
var _attack_blend := BLEND_TIME
## いま再生している動きの名前（idle・attack など）。
var _current := &""


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


## 動きの間合いを、素材の動きに合わせる（set_model のあと。どれも省ける）。
## skips は動きの頭を飛ばす秒数（動きの名前 -> 秒）、attack_hit は攻撃が当たるまでの秒数、attack_blend は攻撃の出入りのつなぎの秒数。
func set_timing(skips: Dictionary, attack_hit := ATTACK_HIT, attack_blend := BLEND_TIME) -> void:
	_skips = skips
	_attack_hit = attack_hit
	_attack_blend = attack_blend


func play_attack() -> float:
	if _has(&"attack"):
		_play(&"attack", false, _attack_blend)
		return _attack_hit
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


## 面ごとにマテリアルを当てる関数を使う（set_model のあと）。
func set_surface_materials(painter: Callable) -> void:
	_surface_painter = painter
	set_shade(1.0)


func set_shade(shade: float) -> void:
	if _surface_painter.is_valid():
		for mesh in _meshes:
			_surface_painter.call(mesh, shade)
		return
	if _meshes.is_empty() or not _material_for.is_valid():
		return
	var material: Material = _material_for.call(shade)
	for mesh in _meshes:
		mesh.material_override = material


func _has(move: StringName) -> bool:
	return _player != null and _player.has_animation(_moves.get(move, &""))


func _play(move: StringName, loop: bool, blend := BLEND_TIME) -> void:
	if not _has(move):
		return
	var animation: StringName = _moves[move]
	_player.get_animation(animation).loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	_current = move
	var skip: float = _skips.get(move, 0.0)
	if skip > 0.0:
		# 頭を飛ばして、残りだけを再生する（繰り返す動きは、残りの中で繰り返す）。
		_player.play_section(animation, skip, -1.0, blend)
	else:
		_player.play(animation, blend)


## 1 回きりの動き（攻撃・被弾・身振り）が終わったら、立ち姿に戻る。攻撃のあとは、攻撃の出入りのつなぎの長さで戻る。
func _on_animation_finished(_animation: StringName) -> void:
	if not _dying:
		_play(&"idle", true, _attack_blend if _current == &"attack" else BLEND_TIME)


## 動きのつなぎ目で、姿勢がどれだけ飛ぶか。検査用（測ると再生が止まる）。
## "idle_loop": 立ち姿の繰り返しの終わりと頭の、いちばん離れた骨の角度（度）。
## "attack_in"・"attack_out": 立ち姿から攻撃の頭へ、攻撃の終わりから立ち姿へ、つなぎの間に骨が回る速さ（度 / 秒。いちばん速い骨）。
## 骨組みか動きが無ければ空。
func motion_jumps() -> Dictionary:
	var skeletons := find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty() or not _has(&"idle") or not _has(&"attack"):
		return {}
	var skeleton := skeletons[0] as Skeleton3D
	var idle_start := _pose_at(skeleton, &"idle", _skips.get(&"idle", 0.0))
	# 終わりは、長さの少し手前で測る（繰り返す動きは、長さちょうどを頭へ回り込ませる）。
	var idle_end := _pose_at(skeleton, &"idle", _player.get_animation(_moves[&"idle"]).length - 0.001)
	var attack_start := _pose_at(skeleton, &"attack", _skips.get(&"attack", 0.0))
	var attack_end := _pose_at(skeleton, &"attack", _player.get_animation(_moves[&"attack"]).length - 0.001)
	return {
		"idle_loop": _pose_gap(idle_end, idle_start),
		"attack_in": _pose_gap(idle_start, attack_start) / _attack_blend,
		"attack_out": _pose_gap(attack_end, idle_start) / _attack_blend,
	}


func _pose_at(skeleton: Skeleton3D, move: StringName, time: float) -> Array[Quaternion]:
	_player.play(_moves[move])
	_player.seek(time, true)
	var pose: Array[Quaternion] = []
	for bone in skeleton.get_bone_count():
		pose.append(skeleton.get_bone_pose_rotation(bone))
	_player.stop()
	return pose


static func _pose_gap(a: Array[Quaternion], b: Array[Quaternion]) -> float:
	var worst := 0.0
	for bone in a.size():
		worst = maxf(worst, rad_to_deg(2.0 * acos(clampf(absf(a[bone].dot(b[bone])), 0.0, 1.0))))
	return worst
