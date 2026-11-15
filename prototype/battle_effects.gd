extends Node3D
## 対戦の演出（攻撃が当たる形、待機のサイン）。素材は使わず、コードで作る形・色・動き（トゥイーン）だけで描く。
##
## 再生する側（board_prototype.gd）が、イベントの再生の中から呼ぶ。ここはルールを持たず、何をどこに出すかだけを受け取る。
## 演出の起点は、種類ごとに 1 つのメソッドにまとめてある（効果音を足すときは、ここに足せば全部の場面で鳴る）。
## どれも出したら待たずに返す（呼ぶ側の待ち時間は変えない）。出したものは、消えたら自分で取り除く。
##
## 描き方は、光に左右されない色（unshaded）と透明度だけ。後処理（グロー）や画面のシェーダーには頼らない
## （コンテナのソフトウェア描画でも、実機の Vulkan でも同じに見えるように）。

## 攻撃の当たり方。駒の種類から決まる（hit_style）。
enum Style {
	SLAM,  ## 叩く（前衛・将）: 相手の足元から、地面を這う衝撃の輪が広がる。
	SLASH,  ## 斬る（奇襲）: 相手の体に、斜めの白い弧が走る。
	SHOT,  ## 撃つ（スナイパー）: 細い光の弾が、まっすぐ速く飛んで当たり、火花が散る。
	MAGIC,  ## 魔法（ソーサラー、プリースト、中ボス）: 光る球が飛んで当たり、色の光が弾ける。
	PLAIN,  ## そのほか（衛生兵、エナジー・コア）: 当たったところに、小さい光が弾ける。
}

## 当たり方ごとの色。
## 明るい緑の地面の上でも埋もれないよう、彩度の高い色にする。
const STYLE_COLORS := {
	Style.SLAM: Color("ff9a3c"),
	Style.SLASH: Color("ffffff"),
	Style.SHOT: Color("ffd84a"),
	Style.MAGIC: Color("b45cff"),
	Style.PLAIN: Color("ffcf6a"),
}

## 飛んでいく弾の、飛ぶ時間（秒）。攻撃の動きが当たる瞬間に着くよう、その分だけ早く撃ち出す。
const SHOT_TIME := 0.09
const MAGIC_TIME := 0.2
## 体のどの高さに当てるか。
const BODY_HEIGHT := 0.6

## 待機のサインの色（行動済みの駒の暗さに合わせた、落ち着いた白）。
const COLOR_WAIT := Color("dfe6ee")

## 使い回す形（作るのは 1 回だけ）。
static var _slash_mesh: ArrayMesh
static var _ring_mesh: TorusMesh
static var _ball_mesh: SphereMesh
static var _bolt_mesh: BoxMesh


## 駒の種類ごとの当たり方。前衛と将は叩く、奇襲は斬る、射撃の後衛は撃つ、魔法の後衛・プリースト・中ボスは魔法。
static func hit_style(kind: UnitKind.Id) -> Style:
	match kind:
		UnitKind.Id.SNIPER:
			return Style.SHOT
		UnitKind.Id.SORCERER, UnitKind.Id.PRIEST, UnitKind.Id.ELITE_MINION:
			return Style.MAGIC
	match UnitKind.role(kind):
		UnitKind.Role.VANGUARD:
			return Style.SLAM
		UnitKind.Role.RAIDER:
			return Style.SLASH
	return Style.SLAM if kind == UnitKind.Id.KING else Style.PLAIN


## 攻撃が当たる形を出す。from は攻撃する駒の足元、to は当たる相手の足元（どちらも盤の上の位置）。
## hit_in は、攻撃の動きを始めてから当たる瞬間までの秒数（弾は、それに間に合うように撃ち出す）。
## 当たったところの形は、hit_in 秒後に出る。
func strike(style: Style, from: Vector3, to: Vector3, hit_in: float) -> void:
	var color: Color = STYLE_COLORS[style]
	var body := to + Vector3(0.0, BODY_HEIGHT, 0.0)
	match style:
		Style.SHOT:
			_projectile(from, to, maxf(hit_in - SHOT_TIME, 0.0), SHOT_TIME, color, true)
		Style.MAGIC:
			_projectile(from, to, maxf(hit_in - MAGIC_TIME, 0.0), MAGIC_TIME, color, false)
	await _wait(hit_in)
	if not is_inside_tree():
		return
	match style:
		Style.SLAM:
			_ring(to + Vector3(0.0, 0.06, 0.0), color, 0.4, 2.1, 0.36)
			_ring(to + Vector3(0.0, 0.08, 0.0), Color.WHITE, 0.3, 1.3, 0.24)
			_burst(body - Vector3(0.0, 0.25, 0.0), Color.WHITE, 0.8, 0.16)
		Style.SLASH:
			_slash(body, from, color)
		Style.SHOT:
			_tracer(from + Vector3(0.0, BODY_HEIGHT + 0.1, 0.0), body, color)
			_sparks(body, from, Color("ff8a3a"))
		Style.MAGIC:
			_burst(body, color, 1.5, 0.32)
			_ring(body, color.lightened(0.35), 0.3, 1.4, 0.3, true)
		Style.PLAIN:
			_burst(body, color, 0.8, 0.22)


## 行動を終えた（待機した）駒のサイン。足元の輪が縮んで沈み、小さく「待機」が出て消える。
func wait_sign(at: Vector3) -> void:
	_ring(at + Vector3(0.0, 0.05, 0.0), COLOR_WAIT, 1.1, 0.5, 0.35)
	var label := Label3D.new()
	label.text = "待機"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.006
	label.font_size = 56
	label.outline_size = 12
	label.modulate = COLOR_WAIT
	label.render_priority = 5
	label.outline_render_priority = 4
	label.position = at + Vector3(0.0, 1.45, 0.0)
	add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "position:y", at.y + 1.75, 0.6).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.6).set_ease(Tween.EASE_IN)
	tween.tween_callback(label.queue_free)


# ---- 形 ----


func _wait(seconds: float) -> Signal:
	return get_tree().create_timer(seconds, false).timeout


func _material(color: Color, billboard := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = true  # 駒の体に埋もれないように、いつも手前に描く
	material.render_priority = 3
	if billboard:
		material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		material.billboard_keep_scale = true
	return material


func _add(mesh: Mesh, material: Material, at: Vector3, parent: Node = self) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.position = at
	parent.add_child(node)
	return node


## 弾。delay 秒待ってから、from から to へ travel 秒で飛ぶ。thin なら細長い光（矢弾）、そうでなければ光る球。
func _projectile(from: Vector3, to: Vector3, delay: float, travel: float, color: Color, thin: bool) -> void:
	var start := from + Vector3(0.0, BODY_HEIGHT + 0.1, 0.0)
	var end := to + Vector3(0.0, BODY_HEIGHT, 0.0)
	await _wait(delay)
	if not is_inside_tree():
		return
	var node: MeshInstance3D
	if thin:
		node = _add(_bolt(), _material(color), start)
		node.look_at_from_position(start, end, Vector3.UP)
	else:
		node = _add(_ball(), _material(color.lightened(0.5)), start)
		node.scale = Vector3.ONE * 0.26
		var halo := _add(_ball(), _material(Color(color, 0.5)), Vector3.ZERO, node)
		halo.scale = Vector3.ONE * 1.9
	var tween := create_tween()
	tween.tween_property(node, "position", end, travel)
	tween.tween_callback(node.queue_free)


## 地面に平たく広がって消える輪。flat でなければ、カメラのほうを向く輪（魔法が弾けた形）。
func _ring(at: Vector3, color: Color, from_size: float, to_size: float, time: float, facing := false) -> void:
	var material := _material(color)
	var node := _add(_ring_shape(), material, at)
	if facing:
		var camera := get_viewport().get_camera_3d()
		if camera != null:
			node.look_at(camera.global_position, Vector3.UP)
			node.rotate_object_local(Vector3.RIGHT, PI / 2.0)
	node.scale = Vector3(from_size, 1.0, from_size)
	var tween := create_tween()
	tween.tween_property(node, "scale", Vector3(to_size, 1.0, to_size), time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.parallel().tween_property(material, "albedo_color:a", 0.0, time).set_ease(Tween.EASE_IN)
	tween.tween_callback(node.queue_free)


## 広がって消える光の球。
func _burst(at: Vector3, color: Color, size: float, time: float) -> void:
	var material := _material(Color(color, 0.8))
	var node := _add(_ball(), material, at)
	node.scale = Vector3.ONE * size * 0.3
	var tween := create_tween()
	tween.tween_property(node, "scale", Vector3.ONE * size, time).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(material, "albedo_color:a", 0.0, time)
	tween.tween_callback(node.queue_free)


## 斜めの弧（斬撃）。カメラのほうを向き、短く伸びて消える。攻撃した側から見て、手前から奥へ振り抜く向きは問わない。
func _slash(at: Vector3, from: Vector3, color: Color) -> void:
	# 攻撃した駒が画面の左にいれば左から、右にいれば右から斬る向きにする（左右を反転する）。
	var mirror := 1.0
	var camera := get_viewport().get_camera_3d()
	if camera != null and camera.unproject_position(from).x > camera.unproject_position(at).x:
		mirror = -1.0
	# 白い弧の下に、少し大きい濃い色の弧を敷く（明るい地面の上でも縁が見えるように）。
	for layer: Array in [[Color("2b5cff", 0.85), 1.12], [color, 1.0]]:
		var material := _material(layer[0], true)
		var node := _add(_slash_shape(), material, at)
		var size: float = layer[1] * 1.3
		node.scale = Vector3(mirror * size * 0.5, size * 0.5, size)
		var tween := create_tween()
		tween.tween_property(node, "scale", Vector3(mirror * size, size, size), 0.09).set_ease(Tween.EASE_OUT)
		tween.tween_interval(0.06)
		tween.tween_property(material, "albedo_color:a", 0.0, 0.2)
		tween.tween_callback(node.queue_free)
	_burst(at, color, 0.5, 0.14)


## 弾の通った跡（撃った駒から相手までの細い光の線）。当たった瞬間に引いて、細くなりながら消える。
func _tracer(from: Vector3, to: Vector3, color: Color) -> void:
	var length := from.distance_to(to)
	if length < 0.01:
		return
	var material := _material(Color(color, 0.9))
	var node := _add(_bolt(), material, (from + to) / 2.0)
	node.look_at_from_position((from + to) / 2.0, to, Vector3.UP)
	node.scale = Vector3(0.6, 0.6, length / _bolt().size.z)
	var tween := create_tween()
	tween.tween_property(node, "scale:x", 0.1, 0.22)
	tween.parallel().tween_property(node, "scale:y", 0.1, 0.22)
	tween.parallel().tween_property(material, "albedo_color:a", 0.0, 0.22).set_ease(Tween.EASE_IN)
	tween.tween_callback(node.queue_free)


## 細かい火花（撃った弾が当たったところ）。撃った側と反対へ散る。
func _sparks(at: Vector3, from: Vector3, color: Color) -> void:
	var away := (at - from)
	away.y = 0.0
	away = away.normalized() if away.length() > 0.001 else Vector3.FORWARD
	var side := away.cross(Vector3.UP)
	for i in 7:
		var spread := (i - 3) * 0.3
		var direction := (away + side * spread + Vector3(0.0, 0.3 + 0.2 * (i % 2), 0.0)).normalized()
		var material := _material(color)
		var spark := _add(_ball(), material, at)
		spark.scale = Vector3.ONE * 0.22
		var tween := create_tween()
		tween.tween_property(spark, "position", at + direction * 0.9, 0.28).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(spark, "scale", Vector3.ONE * 0.08, 0.28)
		tween.parallel().tween_property(material, "albedo_color:a", 0.0, 0.26).set_ease(Tween.EASE_IN)
		tween.tween_callback(spark.queue_free)
	_burst(at, Color.WHITE, 0.8, 0.14)


static func _ball() -> SphereMesh:
	if _ball_mesh == null:
		_ball_mesh = SphereMesh.new()
		_ball_mesh.radius = 0.5
		_ball_mesh.height = 1.0
		_ball_mesh.radial_segments = 12
		_ball_mesh.rings = 6
	return _ball_mesh


static func _bolt() -> BoxMesh:
	if _bolt_mesh == null:
		_bolt_mesh = BoxMesh.new()
		_bolt_mesh.size = Vector3(0.08, 0.08, 0.9)  # look_at の向き（-Z）に長い
	return _bolt_mesh


static func _ring_shape() -> TorusMesh:
	if _ring_mesh == null:
		_ring_mesh = TorusMesh.new()
		_ring_mesh.inner_radius = 0.38
		_ring_mesh.outer_radius = 0.5
		_ring_mesh.rings = 32
		_ring_mesh.ring_segments = 4
	return _ring_mesh


## 斬撃の弧: 真ん中が太く、両端が細い三日月の帯。左上から右下へ斜めに走る形（画面の平面に置く）。
static func _slash_shape() -> ArrayMesh:
	if _slash_mesh != null:
		return _slash_mesh
	var vertices := PackedVector3Array()
	var steps := 14
	var radius := 0.55
	var tilt := deg_to_rad(-35.0)
	for i in steps + 1:
		var t := float(i) / steps
		var angle := lerpf(deg_to_rad(200.0), deg_to_rad(340.0), t)
		var width := sin(t * PI) * 0.16
		var outer := Vector2(cos(angle), sin(angle)) * (radius + width)
		var inner := Vector2(cos(angle), sin(angle)) * (radius - width * 0.4)
		vertices.append(Vector3(outer.rotated(tilt).x, -outer.rotated(tilt).y - 0.25, 0.0))
		vertices.append(Vector3(inner.rotated(tilt).x, -inner.rotated(tilt).y - 0.25, 0.0))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	_slash_mesh = ArrayMesh.new()
	_slash_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLE_STRIP, arrays)
	return _slash_mesh
