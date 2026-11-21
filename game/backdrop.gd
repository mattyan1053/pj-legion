extends Node3D
## 部隊編成・会話・出撃準備の場面の背景。対戦と同じ景色（空、霞、光、盤と盤の外の景色）を、駒を置かずに、ゆっくり回りながら見せる。
## 素材は足さない（対戦の画面の部品をそのまま使う）。
## 盤と見た目を渡さなければ、中央平原の生成の盤（いつも同じ）。ストーリーの会話は、話の盤と見た目を渡す。

const BattleScreen := preload("res://game/battle_screen.gd")
const BoardView := preload("res://game/board_view.gd")
const OrbitCamera := preload("res://game/orbit_camera.gd")
const StageLook := preload("res://game/stage_look.gd")

## 回る速さ（ラジアン / 秒）。
const TURN_SPEED := 0.05
## 背景の盤の種（いつも同じ景色にする）と、カメラの距離・見下ろす角度。
const LOOK_SEED := 7
const DISTANCE := 30.0
const PITCH := 38.0

var _rig: OrbitCamera
var _board: Board
var _look: StringName


func _init(board: Board = null, look := StageLook.DEFAULT) -> void:
	_board = board
	_look = look


func _ready() -> void:
	StageLook.build_environment(self)
	var board := _board if _board != null else BoardGenerator.generate(BoardGenerator.Stage.PLAIN, LOOK_SEED)
	var view := BoardView.new()
	add_child(view)
	view.setup(board, LOOK_SEED, BattleScreen.TEAM_COLORS, _look)
	StageLook.apply(self, view.look)
	_rig = OrbitCamera.new()
	add_child(_rig)
	_rig.controls_enabled = false  # 背景なので、キーとホイールでは動かさない
	_rig.position = BoardView.cell_center(board.size / 2)
	_rig.bounds = Rect2(Vector2.ZERO, Vector2(board.size))
	_rig._target_distance = DISTANCE
	_rig.set_pitch(PITCH)


func _process(delta: float) -> void:
	_rig._target_yaw += TURN_SPEED * delta
