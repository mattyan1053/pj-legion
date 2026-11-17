extends Node3D
## 駒 1 体の見た目。
##
## 駒そのものの形と動き（体。unit_body.gd）は、いま使っている駒の見た目の組（unit_looks.gd）が作る。
## ここは、どの組でも同じに付けるもの（足元の円盤・HP の棒・進化と状態の輪・将の冠）と、行動済みの暗さ、倒れて消えるところを持つ。
## 陣営の色は、足元の円盤と、組が決める体の色の付け方で出す。
## 頭の上には何も出さない（駒の情報は、クリックかマウスを乗せて、画面の枠で確かめる）。
## 盤の上で分かるのは、足元だけ: 行動済みの駒は暗い。HP が減っている駒は、足元に小さい棒が出る（減っていなければ出ない）。
## 進化した駒は、足元の円盤を金の輪が囲む。状態（バリア、照準など）が付いている駒は、その外に水色の細い輪が出る。
##
## ルールは持たない。何を見せるかは、呼ぶ側（イベントを再生する側）が決める。

const UnitLooks := preload("res://game/unit_looks.gd")
const UnitBody := preload("res://game/unit_body.gd")

## 行動済みの駒は、この明るさまで暗くする。
const ACTED_SHADE := 0.42
## 足元の HP の棒（減っている駒だけ）。
const BAR_SIZE := Vector2i(34, 5)
const BAR_PIXEL := 0.016
const COLOR_GOLD := Color("f2c84b")
const COLOR_STATUS := Color("7fe3ff")

var _body: UnitBody
var _kind: UnitKind.Id
var _team_color: Color
var _max_hp := 1
## いま持っている HP（減っていれば、足元の棒に出る）。検査用。
var shown_hp := 0
var _height := 1.3  # 駒の高さ（頭の上。将は冠まで）
var _acted := false
var _dying := false
var _base_material: StandardMaterial3D
var _bar: Sprite3D
var _evolved_ring: MeshInstance3D
var _status_ring: MeshInstance3D


## look は将の別の姿（unit_looks.gd の KING_LOOKS の名前。空か知らない名前なら、いつもの将。将でない駒には効かない）。
## look_set は駒の見た目の組の名前（空なら、いま使っている組。アイコンを写す道具が組を選ぶのに使う）。
func setup(kind: UnitKind.Id, team_color: Color, hp: int, max_hp: int, look := &"", look_set := &"") -> void:
	_kind = kind
	_team_color = team_color
	_max_hp = max_hp
	_add_base(team_color)
	var looks := UnitLooks.active() if look_set == &"" else UnitLooks.of(look_set)
	var king_look := look if kind == UnitKind.Id.KING and UnitLooks.KING_LOOKS.has(look) else &""
	_body = looks.build(kind, team_color, king_look, global_position if is_inside_tree() else position)
	_body.view = self
	add_child(_body)
	_height = _body.body_height
	if kind == UnitKind.Id.KING:
		_add_crown()
	_add_bar()
	set_hp(hp)
	play_idle()


func play_idle() -> void:
	if not _dying:
		_body.play_idle()


## 話し始めの小さな身振り（会話の場面の話し手の姿。talk_figure.gd）。終われば立ち姿に戻る。
func play_gesture() -> void:
	_body.play_gesture()


func play_run() -> void:
	_body.play_run()


## 攻撃の動き。当たる瞬間までの秒数を返す（呼ぶ側がそこでダメージを見せる）。
func play_attack() -> float:
	return _body.play_attack()


func play_hit() -> void:
	_body.play_hit()


## 倒れる動きをして、自分を取り除く。終わるまで待てる。
func play_death() -> void:
	_dying = true
	_bar.visible = false
	var wait := _body.play_death()
	if wait > 0.0:
		# 木の時計ではなく自分の子の Timer で待つ（場面を抜けてこの駒が消えたら、続きを走らない）。
		var timer := Timer.new()
		timer.one_shot = true
		timer.wait_time = wait
		add_child(timer)
		timer.start()
		await timer.timeout
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE * 0.01, 0.3)
	await tween.finished
	queue_free()


## 盤面上の向き（y は見ない）へ体を向ける。
func face(direction: Vector3) -> void:
	if Vector2(direction.x, direction.z).length() < 0.001:
		return
	rotation.y = atan2(direction.x, direction.z)


## 駒の種類（演出の当たり方を決める）。
func unit_kind() -> UnitKind.Id:
	return _kind


## 駒の高さ（頭の上まで）。画面に占める四角を出すのに使う。
func height() -> float:
	return _height


## HP を変える。減っていれば、足元に小さい棒を出す（満タンなら出さない）。
func set_hp(hp: int) -> void:
	shown_hp = hp
	_bar.visible = hp < _max_hp and not _dying
	if not _bar.visible:
		return
	var image := Image.create_empty(BAR_SIZE.x, BAR_SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.05, 0.05, 0.07, 0.9))
	var inner := BAR_SIZE - Vector2i(2, 2)
	var ratio := clampf(float(hp) / _max_hp, 0.0, 1.0)
	var filled := ceili(inner.x * ratio)
	if filled > 0:
		var color := Color("5fd35f") if ratio > 0.5 else (Color("e8c23a") if ratio > 0.25 else Color("e8503a"))
		image.fill_rect(Rect2i(1, 1, filled, inner.y), color)
	_bar.texture = ImageTexture.create_from_image(image)


## レベルと最大 HP を変える（レベルアップ）。棒は次の set_hp で描き直す。
func set_growth(_level: int, max_hp: int) -> void:
	_max_hp = max_hp


## 最大 HP だけを変える（聖遺物）。棒は次の set_hp で描き直す。
func set_max_hp(max_hp: int) -> void:
	_max_hp = max_hp


## 進化した駒の最大 HP を変え、足元に金の輪を付ける。棒は次の set_hp で描き直す（進化先の名前は、駒の情報に出る）。
func set_evolved(max_hp: int) -> void:
	_max_hp = max_hp
	if _evolved_ring == null:
		_evolved_ring = _add_ring(0.41, 0.49, COLOR_GOLD)


## 状態（バリア、照準など）が付いているかを、足元の水色の輪で見せる（何の状態かは、駒の情報に出る）。
func set_status_mark(marked: bool) -> void:
	if marked and _status_ring == null:
		_status_ring = _add_ring(0.52, 0.56, COLOR_STATUS)
	if _status_ring != null:
		_status_ring.visible = marked


## 足元の輪（平たい輪。光に左右されない色）。
func _add_ring(inner: float, outer: float, color: Color) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 32
	mesh.ring_segments = 6
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var ring := MeshInstance3D.new()
	ring.mesh = mesh
	ring.material_override = material
	ring.scale = Vector3(1.0, 0.25, 1.0)
	ring.position.y = 0.03
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	return ring


## 行動済みの駒を暗くする。
func set_acted(acted: bool) -> void:
	if _acted == acted:
		return
	_acted = acted
	var shade := ACTED_SHADE if acted else 1.0
	_base_material.albedo_color = _team_color.darkened(1.0 - shade) if acted else _team_color
	_base_material.emission_energy_multiplier = 0.05 if acted else 0.4
	_body.set_shade(shade)


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


## 足元の HP の棒。いつもカメラを向き、木や岩に隠れない。駒の体には重ねず、マスの手前の縁に出す。
func _add_bar() -> void:
	_bar = Sprite3D.new()
	_bar.pixel_size = BAR_PIXEL
	_bar.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bar.no_depth_test = true
	_bar.shaded = false
	_bar.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_bar.render_priority = 2
	_bar.offset = Vector2(0.0, -BAR_SIZE.y * 2.0)
	_bar.position.y = 0.0
	_bar.visible = false
	add_child(_bar)
