extends Node3D
## 見た目の試作。ルール（rules/）につないで、2 人が 1 台で交代しながら対戦する。
##
## ここはルールを持たない。操作を行動（BattleAction）にして Battle.apply() に渡し、
## 返ってきたイベントを順に再生するだけ。選べることは Battle.can_apply() と rules/ の問い合わせで出す。
## 盤面・駒・ライト・カメラ・文字はすべてコードで組み立てる。

const OrbitCamera := preload("res://prototype/orbit_camera.gd")
const UnitView := preload("res://prototype/unit_view.gd")
const BoardView := preload("res://prototype/board_view.gd")
const BattleHud := preload("res://prototype/battle_hud.gd")
const TrialSetup := preload("res://prototype/trial_setup.gd")
const Queries := preload("res://prototype/battle_queries.gd")
const Autoplay := preload("res://prototype/autoplay.gd")

const NO_CELL := Vector2i(-1, -1)
const TEAM_COLORS: Array[Color] = [Color("3a7bd5"), Color("d64545"), Color("e0b83a")]

## 1 マス歩くのにかける秒数（巡航は速く走る）。
const STEP_TIME := 0.16
const CRUISE_STEP_TIME := 0.1

const COLOR_MOVE := Color(0.35, 0.65, 1.0, 0.5)
const COLOR_CRUISE := Color(1.0, 0.82, 0.3, 0.4)
const COLOR_PATH := Color(1.0, 1.0, 1.0, 0.75)
const COLOR_TARGET := Color(1.0, 0.2, 0.15, 0.7)
const COLOR_INSPECT := Color(1.0, 1.0, 1.0, 0.28)
const COLOR_SELECTED := Color(1.0, 0.9, 0.3, 0.9)

const WIN_REASONS := {
	GameWonEvent.Reason.KING_DEFEATED: "敵の将を倒した",
	GameWonEvent.Reason.HQ_CAPTURED: "敵の本陣を占拠し続けた",
}

var battle: Battle
var stage := BoardGenerator.Stage.PLAIN
var map_seed := 0

var _board_view: BoardView
var _views := {}  # 駒の番号 -> UnitView
var _hud: BattleHud
var _rig: OrbitCamera
var _selection_ring: MeshInstance3D

var _selected_id := 0
var _hover_cell := NO_CELL
## イベントを再生している間は、操作を受け付けない。
var _busy := false
## 未行動の駒を残したままターンを終えるかを、もう一度押して確かめている途中か。
var _confirming_end := false
## いまの選択で選べること（_refresh が作り直す）。
var _move_cells := {}  # マス -> 巡航でしか届かないか
var _targets: Array[Unit] = []
var _painted := {}  # 塗っているマス -> Color（道の表示を重ねる前のもの）


func _ready() -> void:
	_build_environment()
	_rig = OrbitCamera.new()
	add_child(_rig)
	_build_selection_ring()
	_hud = BattleHud.new()
	add_child(_hud)
	_hud.setup(TEAM_COLORS)
	_hud.wait_pressed.connect(press_wait)
	_hud.cancel_pressed.connect(cancel)
	_hud.end_turn_pressed.connect(press_end_turn)
	_hud.restart_pressed.connect(_on_restart_pressed)

	var autoplay := OS.get_cmdline_user_args().has("--autoplay")
	# 検査では毎回同じ対戦にする。遊ぶときは毎回違う盤面にする。
	start_battle(BoardGenerator.Stage.PLAIN, 20261114 if autoplay else int(Time.get_unix_time_from_system()))
	if autoplay:
		add_child(Autoplay.new(self))


func _process(delta: float) -> void:
	# カメラが動くとマウスの下のマスも変わるので、マウスの動きではなく毎フレーム追う。
	_update_hover()
	var focus_cells: Array[Vector2i] = []
	for view: UnitView in _views.values():
		focus_cells.append(BoardView.cell_of(view.position))
	if battle.board.in_bounds(_hover_cell):
		focus_cells.append(_hover_cell)
	_board_view.update_occlusion(_rig.camera, _rig.global_position, focus_cells, delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			click_cell(_cell_under_mouse())
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			cancel()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE:
				cancel()
			KEY_SPACE:
				press_wait()
			KEY_ENTER, KEY_KP_ENTER:
				press_end_turn()
			KEY_F1:
				start_battle(BoardGenerator.Stage.PLAIN, map_seed + 1)
			KEY_F2:
				start_battle(BoardGenerator.Stage.LABYRINTH, map_seed + 1)
			KEY_F3:
				start_battle(BoardGenerator.Stage.TWIN_SPRINGS, map_seed + 1)


# ---- 対戦の始まり ----


## 盤面を作り、軍を置いて、最初から始める。再生の途中なら何もしない。
func start_battle(battle_stage: BoardGenerator.Stage, battle_seed: int) -> void:
	if _busy:
		return
	stage = battle_stage
	map_seed = battle_seed
	battle = TrialSetup.create(stage, map_seed)

	if _board_view != null:
		_board_view.queue_free()
	for view: UnitView in _views.values():
		view.queue_free()
	_views.clear()

	_board_view = BoardView.new()
	add_child(_board_view)
	_board_view.setup(battle.board, map_seed, TEAM_COLORS)
	for unit in battle.units:
		_add_view(unit)

	_rig.bounds = Rect2(Vector2.ZERO, Vector2(battle.board.size))
	_rig.position = _camera_point(Unit.Side.PLAYER1)
	_selected_id = 0
	_confirming_end = false
	_hud.hide_result()
	_hud.show_banner("ターン %d　%s の番" % [battle.turn, BattleHud.SIDE_NAMES[battle.phase]], TEAM_COLORS[battle.phase])
	_refresh()


func _add_view(unit: Unit) -> void:
	var view: UnitView = UnitView.new()
	view.position = BoardView.cell_center(unit.cell)
	add_child(view)
	view.setup(unit.kind, TEAM_COLORS[unit.side], unit.hp, unit.max_hp())
	# 敵の本陣のほうを向いて立つ。
	var enemy_hq := battle.board.hq_cells[1 - unit.side] if unit.side != Unit.Side.NEUTRAL else unit.cell + Vector2i.DOWN
	view.face(BoardView.cell_center(enemy_hq) - view.position)
	view.set_acted(unit.acted)
	_views[unit.id] = view


func _on_restart_pressed(new_stage: int, new_board: bool) -> void:
	if new_board:
		start_battle(new_stage as BoardGenerator.Stage, map_seed + 1)
	else:
		start_battle(stage, map_seed)


# ---- 操作（マウス・キー・ボタンのどれからも、ここを通る） ----


func is_busy() -> bool:
	return _busy


func selected_unit() -> Unit:
	return battle.unit_by_id(_selected_id)


## 画面の駒がいまいるマス（駒の番号 -> マス）。検査用。
func view_cells() -> Dictionary:
	var cells := {}
	for unit_id: int in _views:
		cells[unit_id] = BoardView.cell_of(_views[unit_id].position)
	return cells


## 盤面のマスを選ぶ。選んでいる駒の攻撃できる相手なら攻撃、動けるマスなら移動、駒なら選び直す。
func click_cell(cell: Vector2i) -> void:
	if _busy or battle.is_over() or not battle.board.in_bounds(cell):
		return
	var clicked := battle.unit_at(cell)
	if clicked != null and _targets.has(clicked):
		_do(AttackAction.new(_selected_id, clicked.id))
	elif battle.acting_unit_id != 0:
		pass  # 動いたあとは、攻撃・待機・取り消しのどれかを選ぶ。
	elif _move_cells.has(cell):
		_do(MoveAction.new(_selected_id, cell, _move_cells[cell]))
	else:
		_select(clicked.id if clicked != null else 0)


## 選んでいる駒を待機させる。
func press_wait() -> void:
	if not _busy and _selected_id != 0:
		_do(WaitAction.new(_selected_id))


## 動いたあとなら移動を取り消す。そうでなければ選択をやめる。
func cancel() -> void:
	if _busy:
		return
	if battle.acting_unit_id != 0:
		_do(UndoMoveAction.new(battle.acting_unit_id))
	else:
		_select(0)


## ターンを終える。未行動の駒が残っていれば、もう一度押すまで終えない。
func press_end_turn() -> void:
	if _busy or battle.is_over():
		return
	if Queries.unacted_count(battle) > 0 and not _confirming_end:
		_confirming_end = true
		_refresh()
		return
	_do(EndPhaseAction.new())


func _select(unit_id: int) -> void:
	_selected_id = unit_id
	_confirming_end = false
	_refresh()


## 行動をルールに渡し、起きたことを再生する。断られたら何もしない。
func _do(action: BattleAction) -> void:
	var result := battle.apply(action)
	if not result.accepted:
		return
	_busy = true
	_confirming_end = false
	_board_view.show_cells({})
	_selection_ring.visible = false
	_hud.set_actions(false, false, false)
	_hud.set_end_turn(false, "ターン終了")
	for event in result.events:
		await _play(event)
	_busy = false

	if battle.acting_unit_id != 0:
		_selected_id = battle.acting_unit_id  # 動いたあと。続けて攻撃・待機・取り消しを選ぶ。
	elif not action is UndoMoveAction:
		_selected_id = 0
	_refresh()


# ---- イベントの再生 ----


func _play(event: BattleEvent) -> void:
	if event is UnitMovedEvent:
		await _play_moved(event)
	elif event is MoveUndoneEvent:
		await _play_undone(event)
	elif event is UnitDamagedEvent:
		await _play_damaged(event)
	elif event is UnitHealedEvent:
		# 回復の操作は、まだ画面に無い。イベントが来たら、HP の表示だけは合わせる。
		_view(event.unit_id).set_hp(event.hp)
		_pop_number(_view(event.unit_id).position, "+%d" % event.amount, Color("9cf09c"))
	elif event is UnitDefeatedEvent:
		await _play_defeated(event)
	elif event is UnitActedEvent:
		_view(event.unit_id).set_acted(true)
	elif event is PhaseStartedEvent:
		await _play_phase_started(event)
	elif event is CaptureProgressEvent:
		_play_capture(event)
	elif event is GameWonEvent:
		await get_tree().create_timer(0.4).timeout
		_hud.show_result(event.winner, WIN_REASONS[event.reason])


func _play_moved(event: UnitMovedEvent) -> void:
	if event.path.size() < 2:
		return
	var view := _view(event.unit_id)
	# 巡航かどうかはイベントに無いので、駒の状態から読む（再生の時点では、まだ行動の途中）。
	var unit := battle.unit_by_id(event.unit_id)
	var step_time := CRUISE_STEP_TIME if unit != null and unit.cruised else STEP_TIME
	view.play_run()
	for i in range(1, event.path.size()):
		var target := BoardView.cell_center(event.path[i])
		view.face(target - view.position)
		var tween := create_tween()
		tween.tween_property(view, "position", target, step_time)
		await tween.finished
	view.play_idle()


func _play_undone(event: MoveUndoneEvent) -> void:
	var view := _view(event.unit_id)
	var tween := create_tween()
	tween.tween_property(view, "position", BoardView.cell_center(event.to), 0.15)
	await tween.finished


func _play_damaged(event: UnitDamagedEvent) -> void:
	var attacker := _view(event.attacker_id)
	var target := _view(event.unit_id)
	attacker.face(target.position - attacker.position)
	target.face(attacker.position - target.position)
	await get_tree().create_timer(attacker.play_attack()).timeout
	target.play_hit()
	target.set_hp(event.hp)
	_pop_number(target.position, "-%d" % event.amount)
	await get_tree().create_timer(0.45).timeout


func _play_defeated(event: UnitDefeatedEvent) -> void:
	var view := _view(event.unit_id)
	_views.erase(event.unit_id)
	await view.play_death()


func _play_phase_started(event: PhaseStartedEvent) -> void:
	_refresh_status(event.turn, event.side)
	if event.side == Unit.Side.NEUTRAL:
		return  # 中立の駒の動きはまだ無いので、何も見せずに通り過ぎる。
	for unit in battle.units:
		if unit.side == event.side:
			_view(unit.id).set_acted(false)
	_hud.show_banner("ターン %d　%s の番" % [event.turn, BattleHud.SIDE_NAMES[event.side]], TEAM_COLORS[event.side])
	_rig.focus_on(_camera_point(event.side))
	await get_tree().create_timer(0.5).timeout


func _play_capture(event: CaptureProgressEvent) -> void:
	_refresh_status(battle.turn, battle.phase)
	var hq := battle.board.hq_cells[1 - event.player]
	var text := "占拠 %d / %d" % [event.turns, Battle.CAPTURE_TURNS_TO_WIN] if event.turns > 0 else "占拠が途切れた"
	_pop_number(BoardView.cell_center(hq), text, TEAM_COLORS[event.player].lightened(0.4))


## 盤面の上に、浮かんで消える文字を出す（ダメージの数など）。
func _pop_number(at: Vector3, text: String, color := Color("ffe9a8")) -> void:
	var label := Label3D.new()
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.008
	label.font_size = 64
	label.outline_size = 16
	label.modulate = color
	label.render_priority = 5
	label.outline_render_priority = 4
	label.position = at + Vector3(0.0, 1.5, 0.0)
	add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "position:y", 2.4, 0.8)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8).set_ease(Tween.EASE_IN)
	tween.tween_callback(label.queue_free)


## side の番が来たときにカメラが見る地点。将のいるところから、少し敵の本陣のほうへ寄せる
## （将が盤の端にいると、画面の半分が盤の外になるため）。
func _camera_point(side: Unit.Side) -> Vector3:
	var king := Queries.king_of(battle, side)
	var from := BoardView.cell_center(king.cell if king != null else battle.board.hq_cells[side])
	var toward := BoardView.cell_center(battle.board.hq_cells[1 - side]) - from
	return from + toward.limit_length(4.0)


func _view(unit_id: int) -> UnitView:
	return _views[unit_id]


# ---- 表示の作り直し ----


## いまの状態と選択から、塗るマス・メニュー・文字を作り直す。
func _refresh() -> void:
	var unit := selected_unit()
	if unit == null:
		_selected_id = 0
	_move_cells = Queries.move_cells(battle, unit)
	_targets = Queries.attack_targets(battle, unit)

	_painted = {}
	if unit != null and not battle.is_over():
		if battle.can_act(unit):
			for cell: Vector2i in _move_cells:
				_painted[cell] = COLOR_CRUISE if _move_cells[cell] else COLOR_MOVE
			for target in _targets:
				_painted[target.cell] = COLOR_TARGET
		else:
			for cell in Queries.inspect_cells(battle, unit):
				_painted[cell] = COLOR_INSPECT
	_show_painted()

	_selection_ring.visible = unit != null
	if unit != null:
		_selection_ring.position = BoardView.cell_center(unit.cell) + Vector3(0.0, 0.04, 0.0)

	_refresh_status(battle.turn, battle.phase)
	_refresh_hint(unit)
	var unacted := Queries.unacted_count(battle)
	if _confirming_end:
		_hud.set_end_turn(true, "未行動 %d 体。もう一度で終了" % unacted)
	else:
		_hud.set_end_turn(not battle.is_over(), "ターン終了")
	var can_act := unit != null and not battle.is_over() and battle.can_act(unit)
	_hud.set_actions(can_act, unit != null and not battle.is_over(), unit != null and unit.has_moved)
	_update_info()


func _refresh_status(turn: int, phase: Unit.Side) -> void:
	var counts: Array[int] = [
		Queries.unit_count(battle, Unit.Side.PLAYER1), Queries.unit_count(battle, Unit.Side.PLAYER2),
	]
	_hud.set_status(turn, phase, counts, battle.capture_turns, Battle.CAPTURE_TURNS_TO_WIN)


func _refresh_hint(unit: Unit) -> void:
	if battle.is_over():
		_hud.set_hint("決着")
	elif unit == null:
		_hud.set_hint("駒をクリックして選ぶ。相手の駒を選ぶと、動ける範囲が見える")
	elif not battle.can_act(unit):
		_hud.set_hint("この駒はいま動かせない（白いマスは移動範囲）")
	elif unit.has_moved:
		if unit.cruised:
			_hud.set_hint("巡航で動いたので攻撃できない。待機するか、移動を取り消す")
		elif _targets.is_empty():
			_hud.set_hint("攻撃できる相手がいない。待機するか、移動を取り消す")
		else:
			_hud.set_hint("赤いマスの相手をクリックで攻撃。または待機、移動の取り消し")
	else:
		_hud.set_hint("青: 移動　黄: 巡航（2 倍動けるが攻撃できない）　赤: 攻撃できる相手")


## 塗ったマスに、マウスの下のマスまでの道を重ねて出す。
func _show_painted() -> void:
	var colors := _painted
	var unit := selected_unit()
	if unit != null and not _busy and _move_cells.has(_hover_cell):
		colors = _painted.duplicate()
		for cell in Movement.path_to(battle, unit, _hover_cell, _move_cells[_hover_cell]):
			if cell != unit.cell:
				colors[cell] = COLOR_PATH
	_board_view.show_cells(colors)


func _update_hover() -> void:
	var cell := _cell_under_mouse() if not _hud.is_mouse_over_ui() else NO_CELL
	if not battle.board.in_bounds(cell):
		cell = NO_CELL
	if cell == _hover_cell:
		return
	_hover_cell = cell
	_board_view.set_cursor(cell)
	if not _busy:
		_show_painted()
		_update_info()


## マウスの下の駒（いなければ選んでいる駒）の情報と、マスの説明を出す。
func _update_info() -> void:
	var cell_text := ""
	var hovered: Unit = null
	if _hover_cell != NO_CELL:
		hovered = battle.unit_at(_hover_cell)
		cell_text = "マス (%d, %d)　%s" % [
			_hover_cell.x, _hover_cell.y, BattleHud.TERRAIN_NAMES[battle.board.terrain_at(_hover_cell)],
		]
		var hq_owner := battle.board.hq_owner(_hover_cell)
		if hq_owner >= 0:
			cell_text += "　%s の本陣" % BattleHud.SIDE_NAMES[hq_owner]
	_hud.show_cell(cell_text)

	var shown := hovered if hovered != null else selected_unit()
	if shown == null:
		_hud.show_unit(null, "", "")
		return
	var state := "行動済み" if shown.acted else "未行動"
	if shown.has_moved:
		state = "行動の途中（巡航で移動した）" if shown.cruised else "行動の途中（移動した）"
	var forecast := ""
	var attacker := selected_unit()
	if hovered != null and _targets.has(hovered):
		# 攻撃の見込み。実際の攻撃と同じ計算（Combat.damage）を、状態を変えずに使う。
		var amount := Combat.damage(battle, attacker, hovered)
		var left := maxi(0, hovered.hp - amount)
		forecast = "攻撃すると %d ダメージ → %s" % [amount, "倒せる" if left == 0 else "残り HP %d" % left]
	_hud.show_unit(shown, state, forecast)


func _cell_under_mouse() -> Vector2i:
	var camera: Camera3D = _rig.camera
	var mouse := get_viewport().get_mouse_position()
	var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(
		camera.project_ray_origin(mouse), camera.project_ray_normal(mouse)
	)
	if hit == null:
		return NO_CELL
	var point: Vector3 = hit
	return BoardView.cell_of(point)


# ---- 光・目印 ----


func _build_environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("1b2430")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b8c4d6")
	environment.ambient_light_energy = 0.45
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.ssao_enabled = true

	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -35.0, 0.0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	add_child(sun)


func _build_selection_ring() -> void:
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.38
	ring_mesh.outer_radius = 0.47
	var material := StandardMaterial3D.new()
	material.albedo_color = COLOR_SELECTED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_selection_ring = MeshInstance3D.new()
	_selection_ring.mesh = ring_mesh
	_selection_ring.material_override = material
	_selection_ring.scale = Vector3(1.0, 0.15, 1.0)
	_selection_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_selection_ring.visible = false
	add_child(_selection_ring)
