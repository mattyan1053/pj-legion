extends SubViewportContainer
## 会話の場面の、話し手の姿（docs/story.md の「会話」）。絵は描かず、盤の駒の 3D の形（unit_view.gd）を、
## 小さい 3D の枠（SubViewport。背景は透明）に立たせる。陣営の色も盤の駒と同じ。
##
## 話している側は明るく大きく、話していない側は暗く小さく（set_speaking）。話し始めに小さな身振りをする。
## 置き場所と大きさは、会話の場面（talk_screen.gd）が決める（枠いっぱいに、足元を下の端に合わせて写す）。

const RenderTone := preload("res://game/render_tone.gd")
const UnitView := preload("res://game/unit_view.gd")
const Palette := preload("res://game/ui_palette.gd")

## 陣営（0 = 人の軍、1 = 敵の軍）の色。盤の駒と同じ（battle_screen.gd の TEAM_COLORS）。
const TEAM_COLORS: Array[Color] = [Palette.TEAM_BLUE, Palette.TEAM_RED]
## 枠の縦に対する横の割合。
const ASPECT := 0.62
## 話していない側の大きさと明るさ。
const QUIET_SCALE := 0.86
const QUIET_SHADE := Color(0.42, 0.44, 0.5)
## 話していない側の暗さに混ぜる陣営の色の割合（暗くても、どちらの側の人かが色で分かる。同じ騎士の形が向き合う会話のため）。
const QUIET_TEAM_TINT := 0.5
## 話す・黙るの切り替えの時間（秒）。
const SWITCH_TIME := 0.22
## 話の中央へ向ける角度（ラジアン。左の姿は右へ、右の姿は左へ向く）。
const TURN := 0.42
## カメラ: 縦の画角（度）、高さ、駒からの距離、見る高さ。駒（将で冠まで 1.8 ほど）が枠の 8 割ほどに収まる。
const FOV := 30.0
const CAMERA_HEIGHT := 1.05
const CAMERA_DISTANCE := 3.8
const LOOK_HEIGHT := 0.84

var side := 0
## 立つ所（0 = 左、1 = 右）と、話し手の番号（会話の行の "who"。会話の場面が付ける）。
var place := 0
var who := 0
var _view: Node3D
var _speaking := false
var _tween: Tween


## kind の駒（evolved なら進化後の形。look は将の別の姿）を、陣営 side_ の色で立たせる。
## place_ は立つ所（0 = 左で右を向く、1 = 右で左を向く。書かなければ、人の軍が左、敵の軍が右）。
## crown なら、将の姿でなくても将の目印（頭の上の金の輪）を付ける。
func _init(kind: UnitKind.Id, side_: int, evolved := false, look := &"", place_ := -1, crown := false) -> void:
	side = side_
	place = clampi(side_, 0, 1) if place_ < 0 else place_
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	add_child(viewport)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.75, 0.78, 0.9)
	environment.ambient_light_energy = 0.55 * RenderTone.ambient_scale()  # Forward+ は暗く出る（render_tone.gd）
	var world := WorldEnvironment.new()
	world.environment = environment
	viewport.add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(deg_to_rad(-38.0), deg_to_rad(25.0 if place == 0 else -25.0), 0.0)
	light.light_energy = 1.15
	viewport.add_child(light)

	var camera := Camera3D.new()
	camera.fov = FOV
	camera.position = Vector3(0.0, CAMERA_HEIGHT, CAMERA_DISTANCE)
	viewport.add_child(camera)
	camera.look_at_from_position(camera.position, Vector3(0.0, LOOK_HEIGHT, 0.0))

	_view = UnitView.new()
	viewport.add_child(_view)
	var hp := UnitKind.max_hp(kind)
	_view.setup(kind, TEAM_COLORS[clampi(side, 0, 1)], hp, hp, look)
	if evolved:
		_view.set_evolved(hp)
	if crown:
		_view.show_crown()
	_view.rotation.y = TURN if place == 0 else -TURN
	resized.connect(_on_resized)


func _on_resized() -> void:
	pivot_offset = Vector2(size.x / 2.0, size.y)  # 小さくするときは、足元を軸に


## 話しているか。now なら、動きを挟まずにすぐ変える（検査とスクリーンショット）。
## 黙っていた側が話し始めたら、小さな身振りをする。
func set_speaking(speaking: bool, now := false) -> void:
	var starts := speaking and not _speaking
	_speaking = speaking
	var target_scale := Vector2.ONE * (1.0 if speaking else QUIET_SCALE)
	var target_shade := Color.WHITE if speaking else quiet_shade()
	if _tween != null:
		_tween.kill()
	if now:
		scale = target_scale
		modulate = target_shade
	else:
		_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tween.tween_property(self, "scale", target_scale, SWITCH_TIME)
		_tween.tween_property(self, "modulate", target_shade, SWITCH_TIME)
	if starts and not now:
		gesture()


## 話していない側の明るさ（暗い灰色に、陣営の色を混ぜる）。
func quiet_shade() -> Color:
	var team := TEAM_COLORS[clampi(side, 0, 1)]
	return QUIET_SHADE.lerp(Color(team.r * 0.6, team.g * 0.6, team.b * 0.6), QUIET_TEAM_TINT)


## 話し始めの小さな身振り。
func gesture() -> void:
	_view.play_gesture()


func is_speaking() -> bool:
	return _speaking
