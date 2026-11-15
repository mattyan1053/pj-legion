extends Node3D
## タイトルと対戦の設定の場面の背景。対戦と同じ景色（空、霞、光、盤と盤の外の景色）を、駒を置かずに、ゆっくり回りながら見せる。
## 素材は足さない（対戦の画面の部品をそのまま使う）。

const BoardPrototype := preload("res://prototype/board_prototype.gd")
const BoardView := preload("res://prototype/board_view.gd")
const OrbitCamera := preload("res://prototype/orbit_camera.gd")
const StageLook := preload("res://prototype/stage_look.gd")

## 回る速さ（ラジアン / 秒）。
const TURN_SPEED := 0.05
## 背景の盤の種（いつも同じ景色にする）と、カメラの距離・見下ろす角度。
const LOOK_SEED := 7
const DISTANCE := 30.0
const PITCH := 38.0

var _rig: OrbitCamera


func _ready() -> void:
	StageLook.build_environment(self)
	var board := BoardGenerator.generate(BoardGenerator.Stage.PLAIN, LOOK_SEED)
	var view := BoardView.new()
	add_child(view)
	view.setup(board, LOOK_SEED, BoardPrototype.TEAM_COLORS)
	_rig = OrbitCamera.new()
	add_child(_rig)
	_rig.controls_enabled = false  # 背景なので、キーとホイールでは動かさない
	_rig.position = BoardView.cell_center(board.size / 2)
	_rig.bounds = Rect2(Vector2.ZERO, Vector2(board.size))
	_rig._target_distance = DISTANCE
	_rig.set_pitch(PITCH)


func _process(delta: float) -> void:
	_rig._target_yaw += TURN_SPEED * delta
