extends Node3D
## 対戦の演出（攻撃が当たる形、待機のサイン）。素材は使わず、コードで作る形・色・動き（トゥイーン）だけで描く。
##
## 再生する側（battle_screen.gd）が、イベントの再生の中から呼ぶ。ここはルールを持たず、何をどこに出すかだけを受け取る。
## 演出の起点は、種類ごとに 1 つのメソッドにまとめてある（効果音を足すときは、ここに足せば全部の場面で鳴る）。
## 効果音は、形が出る瞬間に鳴らす（play_sound。呼ぶ側が渡す。渡さなければ鳴らさない）。
## どれも出したら待たずに返す（呼ぶ側の待ち時間は変えない）。出したものは、消えたら自分で取り除く。
##
## 描き方は、光に左右されない色（unshaded）と透明度だけ。後処理（グロー）や画面のシェーダーには頼らない
## （コンテナのソフトウェア描画でも、実機の Vulkan でも同じに見えるように）。

const Text := preload("res://game/text.gd")

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

## 当たり方ごとの効果音（sound_catalog.gd の名前）。当たる瞬間に鳴る。
const STYLE_SOUNDS := {
	Style.SLAM: &"hit_slam",
	Style.SLASH: &"hit_slash",
	Style.SHOT: &"hit_shot",
	Style.MAGIC: &"hit_magic",
	Style.PLAIN: &"hit_plain",
}

## 飛んでいく弾の、飛ぶ時間（秒）。攻撃の動きが当たる瞬間に着くよう、その分だけ早く撃ち出す。
const SHOT_TIME := 0.09
const MAGIC_TIME := 0.2
## 体のどの高さに当てるか。
const BODY_HEIGHT := 0.6

## スキルごとの色（使った駒の足元の輪と、効果の形）。通常の攻撃の色とは別にする。
const SKILL_COLORS := {
	Skill.Id.FIREBALL: Color("ff5a1f"),
	Skill.Id.TACTICAL_BARRICADE: Color("e8d3a0"),
	Skill.Id.SMOKE_GRENADE: Color("9aa3ad"),
	Skill.Id.SAINT_PLACE: Color("ffe27a"),
	Skill.Id.DIVINE_SHIELD: Color("6fe8ff"),
	Skill.Id.PRECISION_AIM: Color("ff3355"),
	Skill.Id.SHADOW_STEP: Color("8a4dff"),
	Skill.Id.ADRENALINE_SHOT: Color("b6ff4a"),
	Skill.Id.BONE_RAISE: Color("9fe0c8"),
	Skill.Id.WAR_DRUM: Color("ff8a3d"),
}
## スキルの系統ごとの効果音（sound_catalog.gd の名前）。形が対象に届いた瞬間に鳴る。
## 8 種を全部別にはせず、系統でまとめる: 炎、守り（壁・盾）、聖、風と影（煙幕・影の移動）、集中（照準・アドレナリン）。
const SKILL_SOUNDS := {
	Skill.Id.FIREBALL: &"skill_fire",
	Skill.Id.TACTICAL_BARRICADE: &"skill_guard",
	Skill.Id.DIVINE_SHIELD: &"skill_guard",
	Skill.Id.SAINT_PLACE: &"skill_holy",
	Skill.Id.SMOKE_GRENADE: &"skill_wind",
	Skill.Id.SHADOW_STEP: &"skill_wind",
	Skill.Id.PRECISION_AIM: &"skill_focus",
	Skill.Id.ADRENALINE_SHOT: &"skill_focus",
	Skill.Id.BONE_RAISE: &"skill_holy",
	Skill.Id.WAR_DRUM: &"skill_guard",
}
## スキルの形が対象に届くまでの秒数（使った駒の手振りが終わる瞬間に届く）。呼ぶ側はこの時間だけ待ってから効果を見せる。
const SKILL_TIME := 0.4
## ファイアボール・スモークグレネードが飛ぶ時間。
const THROW_TIME := 0.26

## 待機のサインの色（行動済みの駒の暗さに合わせた、落ち着いた白）。
const COLOR_WAIT := Color("dfe6ee")

## 効果音を鳴らすところ（名前を 1 つ受け取る。battle_screen.gd が context.play_sound を渡す）。
var play_sound := Callable()

## 使い回す形（作るのは 1 回だけ）。
static var _slash_mesh: ArrayMesh
static var _ring_mesh: TorusMesh
static var _ball_mesh: SphereMesh
static var _bolt_mesh: BoxMesh
static var _column_mesh: CylinderMesh


## 駒の種類ごとの当たり方。前衛と将は叩く、奇襲は斬る、射撃の後衛（スナイパー、骸骨射手、糸針）は撃つ、魔法の後衛・プリースト・中ボス・杖を持つ魔物（骸骨術師、骸骨鼓手）は魔法。
static func hit_style(kind: UnitKind.Id) -> Style:
	match kind:
		UnitKind.Id.SNIPER, UnitKind.Id.SKELETON_ARCHER, UnitKind.Id.NEEDLE:
			return Style.SHOT
		UnitKind.Id.SORCERER, UnitKind.Id.PRIEST, UnitKind.Id.ELITE_MINION, UnitKind.Id.SKELETON_CALLER, UnitKind.Id.SKELETON_DRUMMER:
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
	_sound(STYLE_SOUNDS[style])
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
	label.text = Text.t("battle.menu.wait")
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
	tween.parallel().tween_property(label, "outline_modulate:a", 0.0, 0.6).set_ease(Tween.EASE_IN)  # 縁取りも一緒に消す
	tween.tween_callback(label.queue_free)


## スキルを使った。使った駒の足元にスキルの色の輪が広がり（通常の攻撃と見分ける）、スキルごとの形が対象に出る。
## user は使った駒の足元、target は対象のマスの中心。形は SKILL_TIME 秒で対象に届く（呼ぶ側は、そのあとに効果を見せる）。
func skill_flash(skill: Skill.Id, user: Vector3, target: Vector3) -> void:
	var color: Color = SKILL_COLORS[skill]
	_ring(user + Vector3(0.0, 0.05, 0.0), color, 0.3, 1.7, 0.4)
	_ring(user + Vector3(0.0, 0.07, 0.0), Color.WHITE, 0.2, 1.0, 0.25)
	var body := target + Vector3(0.0, BODY_HEIGHT, 0.0)
	match skill:
		Skill.Id.FIREBALL:
			_lob(user, target, SKILL_TIME - THROW_TIME, THROW_TIME, color, 0.5, 0.6)
		Skill.Id.SMOKE_GRENADE:
			_lob(user, target, SKILL_TIME - THROW_TIME, THROW_TIME, Color("4a525c"), 0.2, 1.4)
	await _wait(SKILL_TIME)
	if not is_inside_tree():
		return
	_sound(SKILL_SOUNDS[skill])
	match skill:
		Skill.Id.FIREBALL:
			_burst(target + Vector3(0.0, 0.4, 0.0), color, 2.6, 0.36)
			_burst(target + Vector3(0.0, 0.4, 0.0), Color("ffd84a"), 1.4, 0.24)
			_ring(target + Vector3(0.0, 0.06, 0.0), color, 0.6, 3.4, 0.4)
		Skill.Id.SMOKE_GRENADE:
			for i in 5:
				var angle := TAU * i / 5.0
				_puff(target + Vector3(cos(angle) * 0.6, 0.3, sin(angle) * 0.6), color)
			_puff(target + Vector3(0.0, 0.4, 0.0), color)
		Skill.Id.TACTICAL_BARRICADE:
			_pillar(target, color, 0.45, 1.3, 0.35)
			_ring(target + Vector3(0.0, 0.06, 0.0), color, 0.4, 1.4, 0.3)
		Skill.Id.SAINT_PLACE:
			_pillar(target, color, 0.7, 3.2, 0.5)
			_ring(target + Vector3(0.0, 0.06, 0.0), color, 0.6, 3.2, 0.5)
		Skill.Id.DIVINE_SHIELD:
			_bubble(body, color)
		Skill.Id.PRECISION_AIM:
			_reticle(body, color)
		Skill.Id.SHADOW_STEP:
			for i in 4:
				var angle := TAU * i / 4.0 + 0.4
				_puff(user + Vector3(cos(angle) * 0.35, 0.5, sin(angle) * 0.35), color)
		Skill.Id.ADRENALINE_SHOT:
			_rise(target, color)
		Skill.Id.BONE_RAISE:
			_pillar(target, color, 0.4, 1.4, 0.35)
			_rise(target, color)
		Skill.Id.WAR_DRUM:
			_ring(user + Vector3(0.0, 0.06, 0.0), color, 0.6, 4.2, 0.5)


## 必殺技を使った陣営の駒すべてに、同時に陣営の色の光の柱が立つ（駒ごとに順には出さない）。
## 音はここでは鳴らさない（必殺技の音は、画面が光る瞬間に 1 回だけ鳴らし、山がこの柱に重なる。battle_screen.gd）。
func ult_burst(points: Array[Vector3], color: Color) -> void:
	for at in points:
		_pillar(at, color, 0.5, 2.4, 0.45)
		_ring(at + Vector3(0.0, 0.05, 0.0), color, 0.3, 1.5, 0.4)


# ---- 形 ----


func _sound(name: StringName) -> void:
	if play_sound.is_valid():
		play_sound.call(name)


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


## 放物線で飛ぶ玉（ファイアボール、煙幕の弾）。delay 秒待ってから、from から to へ travel 秒で飛ぶ。
func _lob(from: Vector3, to: Vector3, delay: float, travel: float, color: Color, size: float, height: float) -> void:
	var start := from + Vector3(0.0, BODY_HEIGHT + 0.2, 0.0)
	var end := to + Vector3(0.0, 0.4, 0.0)
	await _wait(delay)
	if not is_inside_tree():
		return
	var node := _add(_ball(), _material(color), start)
	node.scale = Vector3.ONE * size
	if size >= 0.4:
		var core := _add(_ball(), _material(Color("ffe08a")), Vector3.ZERO, node)
		core.scale = Vector3.ONE * 0.55
	var arc := func(t: float) -> void:
		node.position = start.lerp(end, t) + Vector3(0.0, sin(t * PI) * height, 0.0)
	var tween := create_tween()
	tween.tween_method(arc, 0.0, 1.0, travel)
	tween.tween_callback(node.queue_free)


## 灰色の煙の塊（膨らみながら薄れる）。
func _puff(at: Vector3, color: Color) -> void:
	var material := _material(Color(color, 0.75))
	var node := _add(_ball(), material, at)
	node.scale = Vector3.ONE * 0.3
	var tween := create_tween()
	tween.tween_property(node, "scale", Vector3.ONE * 1.1, 0.5).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(node, "position:y", at.y + 0.3, 0.5)
	tween.parallel().tween_property(material, "albedo_color:a", 0.0, 0.5).set_ease(Tween.EASE_IN)
	tween.tween_callback(node.queue_free)


## 地面から立つ光の柱（盾が立つ、聖域、必殺技）。radius は太さ、height は高さ。
func _pillar(at: Vector3, color: Color, radius: float, height: float, time: float) -> void:
	var material := _material(Color(color, 0.55))
	var node := Node3D.new()  # 足元を原点にして、上へ伸ばす
	node.position = at
	add_child(node)
	_add(_column(), material, Vector3(0.0, 0.5, 0.0), node)
	node.scale = Vector3(radius, 0.05, radius)
	var tween := create_tween()
	tween.tween_property(node, "scale", Vector3(radius, height, radius), time * 0.4).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale:x", radius * 0.2, time * 0.6)
	tween.parallel().tween_property(node, "scale:z", radius * 0.2, time * 0.6)
	tween.parallel().tween_property(material, "albedo_color:a", 0.0, time * 0.6)
	tween.tween_callback(node.queue_free)


## 駒を包む泡（バリア）。膨らんで、しばらく残って消える。
func _bubble(at: Vector3, color: Color) -> void:
	var material := _material(Color(color, 0.4))
	var node := _add(_ball(), material, at)
	node.scale = Vector3.ONE * 0.4
	var tween := create_tween()
	tween.tween_property(node, "scale", Vector3.ONE * 1.5, 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_interval(0.15)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.25)
	tween.tween_callback(node.queue_free)
	_ring(at, color.lightened(0.4), 0.5, 1.6, 0.3, true)


## 照準（相手に向かって縮む輪と十字）。
func _reticle(at: Vector3, color: Color) -> void:
	var material := _material(color)
	var node := _add(_ring_shape(), material, at)
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		node.look_at(camera.global_position, Vector3.UP)
		node.rotate_object_local(Vector3.RIGHT, PI / 2.0)
	node.scale = Vector3(2.4, 1.0, 2.4)
	for i in 4:
		var tick := _add(_bolt(), material, Vector3.ZERO, node)
		tick.rotation.y = PI / 2.0 * i
		tick.position = Vector3(sin(PI / 2.0 * i), 0.0, cos(PI / 2.0 * i)) * 0.5
		tick.scale = Vector3(1.0, 1.0, 0.35)
	var tween := create_tween()
	tween.tween_property(node, "scale", Vector3(0.9, 1.0, 0.9), 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_interval(0.12)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.2)
	tween.tween_callback(node.queue_free)


## 足元から立ち昇る光の粒（アドレナリン注射）。
func _rise(at: Vector3, color: Color) -> void:
	for i in 6:
		var angle := TAU * i / 6.0
		var start := at + Vector3(cos(angle) * 0.3, 0.1, sin(angle) * 0.3)
		var material := _material(color)
		var spark := _add(_bolt(), material, start)
		spark.rotation.x = PI / 2.0  # 縦に長い
		spark.scale = Vector3(1.2, 1.2, 0.4)
		var tween := create_tween()
		tween.tween_interval(0.04 * i)
		tween.tween_property(spark, "position:y", start.y + 1.5, 0.35).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(material, "albedo_color:a", 0.0, 0.35).set_ease(Tween.EASE_IN)
		tween.tween_callback(spark.queue_free)
	_burst(at + Vector3(0.0, BODY_HEIGHT, 0.0), color, 1.0, 0.25)


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


## 高さ 1 の円柱（中心が原点）。
static func _column() -> CylinderMesh:
	if _column_mesh == null:
		_column_mesh = CylinderMesh.new()
		_column_mesh.top_radius = 0.5
		_column_mesh.bottom_radius = 0.5
		_column_mesh.height = 1.0
		_column_mesh.radial_segments = 16
		_column_mesh.rings = 1
		_column_mesh.cap_top = false
		_column_mesh.cap_bottom = false
	return _column_mesh


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
