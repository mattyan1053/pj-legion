extends Node3D
## タイトルの背景。世界（「空の縫い目」。docs/story.md）を 1 枚で見せる:
## 裂けた空（rift_sky.gdshader）の下の、結晶の森。裂け目の光を背にして、岩山と結晶と木立が影になる。
## 素材は足さない（盤と景色は対戦の画面の部品、空はシェーダー）。カメラは低く構えて、ゆっくり左右に振る。

const BattleScreen := preload("res://game/battle_screen.gd")
const BoardView := preload("res://game/board_view.gd")
const StageLook := preload("res://game/stage_look.gd")
const RIFT_SKY := preload("res://game/rift_sky.gdshader")

## 盤の種（いつも同じ景色にする）。
const LOOK_SEED := 7
## 霞と地平の色、裂け目から差す光、まわりの光。
const HAZE := Color("6f6aa0")
const RIFT_LIGHT := Color("c9f1ff")
const AMBIENT := Color("7a7fc4")
## カメラ: 盤の手前の端から、盤の向こう（-Z）の空を見る。高さ、盤の端からの距離、見上げる角度、画角（度）。
const CAMERA_HEIGHT := 3.4
const CAMERA_BACK := 5.0
const CAMERA_TILT := 9.0
const CAMERA_FOV := 52.0
## 左右に振る幅（度）と、1 往復の秒数。
const SWAY := 3.5
const SWAY_PERIOD := 46.0
## 空の球の半径。
const SKY_RADIUS := 1800.0
## 入ったときに、裂け目の光が差してくるまでの秒数。
const REVEAL_TIME := 1.4

var _camera: Camera3D
var _sky: ShaderMaterial
var _time := 0.0


func _ready() -> void:
	StageLook.build_environment(self)
	var board_sky := get_node(StageLook.SKY_NODE)  # 盤の空は使わない（裂けた空を描く）
	remove_child(board_sky)
	board_sky.free()
	var board := BoardGenerator.generate(BoardGenerator.Stage.TWIN_SPRINGS, LOOK_SEED)
	var view := BoardView.new()
	add_child(view)
	view.setup(board, LOOK_SEED, BattleScreen.TEAM_COLORS, StageLook.CRYSTAL_FOREST)
	view.set_grid_visible(false)
	# 空気は、結晶の森のものから、裂け目の光の夕闇に替える（光は、裂け目のある -Z の空から、低く手前へ差す）。
	var look := view.look.duplicate()
	look[StageLook.HAZE] = HAZE
	look[StageLook.SUN] = RIFT_LIGHT
	look[StageLook.AMBIENT] = AMBIENT
	look[StageLook.SUN_PITCH] = -16.0
	look[StageLook.SUN_YAW] = 172.0
	look[StageLook.SUN_ENERGY] = 1.5
	look[StageLook.AMBIENT_ENERGY] = 0.5
	StageLook.apply(self, look)

	_camera = Camera3D.new()
	_camera.fov = CAMERA_FOV
	_camera.far = SKY_RADIUS * 1.5
	_camera.position = Vector3(board.size.x / 2.0, CAMERA_HEIGHT, board.size.y + CAMERA_BACK)
	add_child(_camera)

	_sky = ShaderMaterial.new()
	_sky.shader = RIFT_SKY
	_sky.set_shader_parameter(&"horizon", HAZE)
	_sky.set_shader_parameter(&"reveal", 0.0)
	var dome := SphereMesh.new()
	dome.radius = SKY_RADIUS
	dome.height = SKY_RADIUS * 2.0
	dome.radial_segments = 48
	dome.rings = 24
	var sky := MeshInstance3D.new()
	sky.mesh = dome
	sky.material_override = _sky
	sky.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sky.position = _camera.position
	add_child(sky)
	create_tween().tween_method(func(value: float) -> void: _sky.set_shader_parameter(&"reveal", value), 0.0, 1.0, REVEAL_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_aim()


func _process(delta: float) -> void:
	_time += delta
	_aim()


func _aim() -> void:
	var yaw := deg_to_rad(SWAY) * sin(_time * TAU / SWAY_PERIOD)
	_camera.rotation = Vector3(deg_to_rad(CAMERA_TILT), yaw, 0.0)
