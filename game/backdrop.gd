extends Node3D
## 部隊編成・会話・出撃準備の場面の背景。対戦と同じ景色（空、霞、光、盤と盤の外の景色）を、駒を置かずに、ゆっくり回りながら見せる。
## 素材は足さない（対戦の画面の部品をそのまま使う）。
## 盤と見た目を渡さなければ、中央平原の生成の盤（いつも同じ）。ストーリーの会話は、話の盤と見た目を渡す。
## 対戦（shown）を渡せば、その盤に、その駒を立たせる（ストーリーの会話。前の会話は初期位置、あとの会話は決着したときの駒）。
## 駒は敵の本陣のほうを向いて立ち、HP の棒は出さない（満タンで見せる）。

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
## 駒を立たせるときに、見る中心を盤の真ん中から味方の本陣へ寄せる割合。
const TOWARD_FRIENDS := 0.45

const UnitView := preload("res://game/unit_view.gd")

var _rig: OrbitCamera
var _board: Board
var _look: StringName
var _shown: Battle
var _king_looks: Array[StringName] = []
var _people := {}
## 立たせた駒の見た目（検査用）。
var unit_views: Array[UnitView] = []
var unit_sides: Array[int] = []
## 景色だけを見せるか（木に入れる前に決める）。真なら、マス目の線と、本陣の旗・地面の陣営の色・拠点の印を出さない
## （別の場所の会話とカットシーンの背景。盤ではなく、その場所として見せる）。
var scenery_only := false
var _view: BoardView


## shown: 駒を立たせる対戦（盤は shown の盤を使う）。king_looks: 陣営ごとの将の姿（battle_source.gd の king_looks）。
## people: 名前のある人物の形の付いた駒（駒の id -> unit_looks.gd の PERSONS の名前。将の姿より先）。
func _init(board: Board = null, look := StageLook.DEFAULT, shown: Battle = null, king_looks: Array[StringName] = [], people := {}) -> void:
	_board = shown.board if shown != null else board
	_look = look
	_shown = shown
	_king_looks = king_looks
	_people = people


func _ready() -> void:
	StageLook.build_environment(self)
	var board := _board if _board != null else BoardGenerator.generate(BoardGenerator.Stage.PLAIN, LOOK_SEED)
	var view := BoardView.new()
	_view = view
	add_child(view)
	view.scenery_only = scenery_only
	view.setup(board, LOOK_SEED, BattleScreen.TEAM_COLORS, _look)
	StageLook.apply(self, view.look)
	if _shown != null:
		for unit: Unit in _shown.units:
			_add_unit(unit)
	_rig = OrbitCamera.new()
	add_child(_rig)
	_rig.controls_enabled = false  # 背景なので、キーとホイールでは動かさない
	_rig.position = BoardView.cell_center(board.size / 2)
	if _shown != null:
		# 駒を立たせるときは、見る中心を味方の本陣のほうへ寄せる（手前の味方が、下の文の枠の後ろに隠れない）。
		var toward := BoardView.cell_center(board.hq_cells[Unit.Side.PLAYER1]) - _rig.position
		_rig.position += toward * TOWARD_FRIENDS
	_rig.bounds = Rect2(Vector2.ZERO, Vector2(board.size))
	_rig._target_distance = DISTANCE
	_rig.set_pitch(PITCH)


func _add_unit(unit: Unit) -> void:
	var view := UnitView.new()
	view.position = BoardView.cell_center(unit.cell)
	add_child(view)
	var king_look: StringName = _king_looks[unit.side] if unit.side < _king_looks.size() else &""
	view.setup(unit.kind, BattleScreen.TEAM_COLORS[unit.side], unit.max_hp(), unit.max_hp(), _people.get(unit.id, king_look))
	if unit.evolution != Evolution.Id.NONE:
		view.set_evolved(unit.max_hp())
	var enemy_hq := _shown.board.hq_cells[1 - unit.side] if unit.side != Unit.Side.NEUTRAL else unit.cell + Vector2i.DOWN
	view.face(BoardView.cell_center(enemy_hq) - view.position)
	unit_views.append(view)
	unit_sides.append(unit.side)


func _process(delta: float) -> void:
	_rig._target_yaw += TURN_SPEED * delta


## 背景の盤の見た目（検査用）。
func board_view() -> BoardView:
	return _view
