extends Node3D
## 盤のカットシーンの舞台（docs/battle-view.md の「盤のカットシーン」）。台本（cut_script.gd）の始めの盤に兵を立たせ、
## 出来事の塊を再生（battle_playback.gd）で見せる。対戦（Battle）も上の帯も使わない（再生に渡す場面の道具は、何もしない物）。
## 文を出すのは、これを背景に置く場面（会話の場面）。ここは盤だけ。
##
## - play(events): 出来事の塊を再生し、終わるまで待つ。
## - finish(events): 残りの出来事を見せずに済ませ、終わりの盤に作り直す（スキップ）。再生の途中なら、その塊の残りも見せない。

const BattleScreen := preload("res://game/battle_screen.gd")
const BattlePlayback := preload("res://game/battle_playback.gd")
const BattleEffects := preload("res://game/battle_effects.gd")
const BoardView := preload("res://game/board_view.gd")
const OrbitCamera := preload("res://game/orbit_camera.gd")
const StageLook := preload("res://game/stage_look.gd")
const UnitView := preload("res://game/unit_view.gd")
const CutScript := preload("res://game/cut_script.gd")

## 盤の飾りの種（いつも同じ景色にする）と、カメラの距離・見下ろす角度。
const LOOK_SEED := 7
const DISTANCE := 19.0
const PITCH := 44.0

## 毎フレームの終わりに出る（再生が、まとめて流す場面の終わりを待つのに使う）。
signal frame_passed

var _script: CutScript
var _look: StringName
var _looks := {}
var _sound := Callable()
var _views := {}
var _rig: OrbitCamera
var _playback: BattlePlayback
var _board_view: BoardView
## 再生している途中か。
var playing := false


## cut: 読んだ台本。look: 盤の見た目。looks: 兵の名前 -> 人物の形（unit_looks.gd の PERSONS の名前）。
## play_sound: 効果音を鳴らす (name)。無ければ鳴らさない。
func _init(cut: CutScript, look := StageLook.DEFAULT, looks := {}, play_sound := Callable()) -> void:
	_script = cut
	_look = look
	for name: String in looks:
		if cut.names.has(name):
			_looks[cut.names[name]] = looks[name]
	_sound = play_sound


func _ready() -> void:
	StageLook.build_environment(self)
	_board_view = BoardView.new()
	_board_view.scenery_only = true  # マス目の線も本陣の旗も出さない（盤ではなく、その場所として見せる）
	add_child(_board_view)
	_board_view.setup(_script.start.board, LOOK_SEED, BattleScreen.TEAM_COLORS, _look)
	StageLook.apply(self, _board_view.look)
	_rig = OrbitCamera.new()
	add_child(_rig)
	_rig.controls_enabled = false
	_rig.bounds = Rect2(Vector2.ZERO, Vector2(_script.start.board.size))
	_rig._target_distance = DISTANCE
	_rig.set_pitch(PITCH)
	_rig.jump_to(BoardView.cell_center(_script.camera_cell))
	var effects := BattleEffects.new()
	effects.play_sound = _play_sound
	add_child(effects)
	_playback = BattlePlayback.new()
	add_child(_playback)
	_playback.setup(self, _views, _rig, null, effects, null, BattleScreen.TEAM_COLORS, {}, {})
	_playback.set_board_view(_board_view)
	_playback.replay = _script.fresh_start()  # 台本は話が持ち回るので、再生のたびに新しい始めの盤
	_playback.unit_looks = _looks
	_playback.refresh_status = func(_turn: int, _phase: Unit.Side) -> void: pass
	_playback.side_name = func(_side: Unit.Side) -> String: return ""
	_playback.camera_point = func(_side: Unit.Side) -> Vector3: return _rig.focus_point()
	_playback.cpu_side = func() -> Unit.Side: return Unit.Side.NEUTRAL
	_playback.play_sound = _play_sound
	_playback.sync_views = _sync_views
	_playback.frame_passed = frame_passed
	_sync_views()


func _process(_delta: float) -> void:
	frame_passed.emit()


func _play_sound(name: StringName) -> void:
	if _sound.is_valid():
		_sound.call(name)


## 出来事の塊 events を再生する（終わるまで待つ）。
func play(events: Array) -> void:
	var typed: Array[BattleEvent] = []
	typed.assign(events)
	playing = true
	await _playback.play_all(typed)
	playing = false


## 残りの出来事 events を見せずに済ませ、終わりの盤にする（スキップ）。再生の途中なら、その塊の残りも見せない。
func finish(events: Array) -> void:
	_playback.skipping = true
	while playing:
		await frame_passed
	var typed: Array[BattleEvent] = []
	typed.assign(events)
	await _playback.play_all(typed)


## 再生の盤（検査用）。
func replay() -> RefCounted:
	return _playback.replay


## 兵の見た目（駒の番号 -> unit_view.gd。検査用）。
func views() -> Dictionary:
	return _views


## カメラ（検査用）。
func rig() -> OrbitCamera:
	return _rig


## 兵の見た目を、再生の盤のいまに合わせる（始めと、見せずに済ませたあと）。いなくなった兵は消し、いない兵は立たせ、マスと HP を合わせる。
func _sync_views() -> void:
	var board: RefCounted = _playback.replay
	for id: int in _views.keys():
		if board.piece(id) == null:
			(_views[id] as Node).queue_free()
			_views.erase(id)
	for id: int in board.pieces:
		var piece: RefCounted = board.piece(id)
		if not _views.has(id):
			var view := UnitView.new()
			add_child(view)
			view.setup(piece.kind, BattleScreen.TEAM_COLORS[piece.side], piece.hp, piece.max_hp, _looks.get(id, &""))
			_views[id] = view
			view.position = BoardView.cell_center(piece.cell)
			_face_first(view, piece)
		var shown: UnitView = _views[id]
		shown.position = BoardView.cell_center(piece.cell)
		shown.scale = Vector3.ONE
		shown.set_hp(piece.hp)
		shown.set_status_mark(not piece.statuses.is_empty())


## 立たせたときの向き: 相手の陣営の本陣のほう（中立は手前）。本陣の無い盤なら、盤の真ん中のほう。
func _face_first(view: UnitView, piece: RefCounted) -> void:
	var board: Board = _script.start.board
	var toward := Vector2i(piece.cell.x, piece.cell.y + 1)
	if piece.side != Unit.Side.NEUTRAL and board.hq_cells.size() > 1 - piece.side:
		toward = board.hq_cells[1 - piece.side]
	elif piece.side != Unit.Side.NEUTRAL:
		toward = board.size / 2
	view.face(BoardView.cell_center(toward) - view.position)
