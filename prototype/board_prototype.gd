extends Node3D
## 見た目の試作。ルール（rules/）につないで、1 人で CPU と、または 2 人が 1 台で交代しながら対戦する。
##
## 相手（プレイヤー2）を CPU にすると、その番は CpuPlayer が返す行動を、人の操作と同じ入口（_do）に 1 つずつ流す。
## ここはルールを持たない。操作を行動（BattleAction）にして Battle.apply() に渡し、
## 返ってきたイベントを順に再生するだけ。選べることはルールの問い合わせ（Battle.options）で出す。
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
const COLOR_HEAL := Color(0.3, 0.95, 0.45, 0.7)
const COLOR_BLAST := Color(1.0, 0.55, 0.1, 0.6)
const COLOR_EXPERIENCE := Color("9fd8ff")
const COLOR_LEVEL_UP := Color("ffd34a")
const COLOR_EVOLUTION := Color("d9a6ff")
const COLOR_INSPECT := Color(1.0, 1.0, 1.0, 0.28)
const COLOR_SELECTED := Color(1.0, 0.9, 0.3, 0.9)

## CPU が動かすプレイヤー（相手を CPU にしているとき）。
const CPU_SIDE := Unit.Side.PLAYER2
## CPU の駒が動き出す前に、カメラを寄せて見せる秒数と、1 体の行動が終わってから次の駒までの間。
const CPU_FOCUS_TIME := 0.35
const CPU_PAUSE := 0.45

const WIN_REASONS := {
	GameWonEvent.Reason.KING_DEFEATED: "敵の将を倒した",
	GameWonEvent.Reason.HQ_CAPTURED: "敵の本陣を占拠し続けた",
}

const DRAW_REASONS := {
	GameDrawnEvent.Reason.BOTH_KINGS_DEFEATED: "両方の将が同時に倒れた",
}

var battle: Battle
var stage := BoardGenerator.Stage.PLAIN
var map_seed := 0

var _board_view: BoardView
var _views := {}  # 駒の番号 -> UnitView
var _hud: BattleHud
var _rig: OrbitCamera
var _selection_ring: MeshInstance3D

## 相手（プレイヤー2）を CPU が動かすか。偽なら、2 人が交代で操作する。
var cpu_opponent := true
## CPU が実行した行動の数。検査用。
var cpu_actions := 0
var _cpu := CpuPlayer.new()
## CPU の番を進めている途中か（行動と行動の間の待ち時間も含む）。この間は、操作を受け付けない。
var _cpu_running := false

var _selected_id := 0
var _hover_cell := NO_CELL
## イベントを再生している間は、操作を受け付けない。
var _busy := false
## 未行動の駒を残したままターンを終えるかを、もう一度押して確かめている途中か。
var _confirming_end := false
## いまの選択で選べること（_refresh が作り直す）。
var _move_cells := {}  # マス -> 巡航でしか届かないか
var _targets: Array[Unit] = []
var _barrel_targets: Array[Vector2i] = []
var _heal_targets: Array[Unit] = []
## 再生したイベントの数（イベントのスクリプト -> 回数）。検査用。
var played := {}
var _players := event_players()
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
	_hud.evolution_chosen.connect(choose_evolution)
	_hud.opponent_pressed.connect(toggle_opponent)

	var autoplay := OS.get_cmdline_user_args().has("--autoplay")
	# 検査は、人の操作の入口を両方のプレイヤーで通すところから始める（CPU の番は、検査の中で切り替えて通す）。
	set_opponent(not autoplay)
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
			KEY_1, KEY_KP_1:
				choose_evolution(0)
			KEY_2, KEY_KP_2:
				choose_evolution(1)
			KEY_F1:
				start_battle(BoardGenerator.Stage.PLAIN, map_seed + 1)
			KEY_F2:
				start_battle(BoardGenerator.Stage.LABYRINTH, map_seed + 1)
			KEY_F3:
				start_battle(BoardGenerator.Stage.TWIN_SPRINGS, map_seed + 1)
			KEY_F4:
				toggle_opponent()


# ---- 対戦の始まり ----


## 盤面を作り、軍を置いて、最初から始める。再生の途中と CPU の番の間は何もしない。
func start_battle(battle_stage: BoardGenerator.Stage, battle_seed: int) -> void:
	if is_busy():
		return
	start_with(TrialSetup.create(battle_stage, battle_seed), battle_stage, battle_seed)


## 用意した対戦を、最初から始める（検査では、小さな盤面を作って渡す）。再生の途中と CPU の番の間は何もしない。
func start_with(new_battle: Battle, battle_stage: BoardGenerator.Stage, battle_seed: int) -> void:
	if is_busy():
		return
	stage = battle_stage
	map_seed = battle_seed
	battle = new_battle

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
	_hud.show_banner("ターン %d　%s の番" % [battle.turn, _side_name(battle.phase)], TEAM_COLORS[battle.phase])
	_refresh()
	_run_cpu()


func _add_view(unit: Unit) -> void:
	var view: UnitView = UnitView.new()
	view.position = BoardView.cell_center(unit.cell)
	add_child(view)
	view.setup(unit.kind, TEAM_COLORS[unit.side], unit.hp, unit.max_hp())
	if unit.level > 1:
		view.set_growth(unit.level, unit.max_hp())
		view.set_hp(unit.hp)
	if unit.evolution != Evolution.Id.NONE:
		view.set_evolved(unit.max_hp())
		view.set_hp(unit.hp)
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


## 操作を受け付けない間か（イベントの再生の途中か、CPU の番を進めている途中）。
func is_busy() -> bool:
	return _busy or _cpu_running


## 相手（プレイヤー2）を CPU にするか、人にするかを決める。対戦の途中でも切り替えられる
## （CPU にすれば、プレイヤー2 の番の続きを CPU が引き取る。人にすれば、CPU はいまの行動を最後に手を止める）。
func set_opponent(cpu: bool) -> void:
	cpu_opponent = cpu
	_hud.set_opponent("相手: CPU（F4 で人に）" if cpu else "相手: 人（F4 で CPU に）")
	if battle != null and not is_busy():
		_select(0)
		_run_cpu()


func toggle_opponent() -> void:
	set_opponent(not cpu_opponent)


## いまが、CPU が動かす番か。
func _is_cpu_turn() -> bool:
	return cpu_opponent and not battle.is_over() and battle.phase == CPU_SIDE


## 番の知らせに出す陣営の名前（CPU が動かすなら、そう書く）。
func _side_name(side: Unit.Side) -> String:
	var side_name: String = BattleHud.SIDE_NAMES[side]
	return side_name + " CPU" if cpu_opponent and side == CPU_SIDE else side_name


func selected_unit() -> Unit:
	return battle.unit_by_id(_selected_id)


## 画面の駒がいまいるマス（駒の番号 -> マス）。検査用。
func view_cells() -> Dictionary:
	var cells := {}
	for unit_id: int in _views:
		cells[unit_id] = BoardView.cell_of(_views[unit_id].position)
	return cells


## 画面の駒が札に出している HP（駒の番号 -> HP）。検査用。
func view_hps() -> Dictionary:
	var hps := {}
	for unit_id: int in _views:
		hps[unit_id] = _views[unit_id].shown_hp
	return hps


## 画面に樽が描かれているマス。検査用。
func barrel_view_cells() -> Array[Vector2i]:
	return _board_view.barrel_cells()


## いま出ている結果の見出し（出ていなければ空）。検査用。
func result_title() -> String:
	return _hud.result_title()


## 盤面のマスを選ぶ。選んでいる駒の攻撃できる相手・樽なら攻撃、回復できる味方なら回復、動けるマスなら移動、駒なら選び直す。
func click_cell(cell: Vector2i) -> void:
	if is_busy() or battle.is_over() or not battle.board.in_bounds(cell):
		return
	var clicked := battle.unit_at(cell)
	if clicked != null and _targets.has(clicked):
		_do(AttackAction.new(_selected_id, clicked.id))
	elif clicked != null and _heal_targets.has(clicked):
		_do(HealAction.new(_selected_id, clicked.id))
	elif _barrel_targets.has(cell):
		_do(AttackBarrelAction.new(_selected_id, cell))
	elif battle.acting_unit_id != 0:
		pass  # 動いたあとは、攻撃・回復・待機・取り消しのどれかを選ぶ。
	elif _move_cells.has(cell):
		_do(MoveAction.new(_selected_id, cell, _move_cells[cell]))
	else:
		_select(clicked.id if clicked != null else 0)


## 選んでいる駒を待機させる。
func press_wait() -> void:
	if not is_busy() and _selected_id != 0:
		_do(WaitAction.new(_selected_id))


## 動いたあとなら移動を取り消す。そうでなければ選択をやめる。
func cancel() -> void:
	if is_busy():
		return
	if battle.acting_unit_id != 0:
		_do(UndoMoveAction.new(battle.acting_unit_id))
	else:
		_select(0)


## 進化先を選ぶ（index は選択肢の何番目か）。進化先を選ぶのを待っている駒がいるときだけ。
func choose_evolution(index: int) -> void:
	if is_busy() or battle.is_over():
		return
	var unit := battle.evolving_unit()
	if unit == null:
		return
	var choices := battle.options(unit.id).evolutions
	if index >= 0 and index < choices.size():
		_do(EvolveAction.new(unit.id, choices[index]))


## 進化先の選択肢を出しているか。検査用。
func is_choosing_evolution() -> bool:
	return _hud.is_evolution_shown()


## ターンを終える。未行動の駒が残っていれば、もう一度押すまで終えない。進化先を選ぶ途中は終えられない。
func press_end_turn() -> void:
	if is_busy() or battle.is_over() or battle.evolving_unit() != null:
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


## 行動をルールに渡し、起きたことを再生する。断られたら何もしない。受け付けられたかを返す。
func _do(action: BattleAction) -> bool:
	var result := battle.apply(action)
	if not result.accepted:
		return false
	_busy = true
	_confirming_end = false
	_board_view.show_cells({})
	_selection_ring.visible = false
	_hud.set_actions(false, false, false)
	_hud.set_end_turn(false, "ターン終了")
	_hud.hide_evolution()
	for event in result.events:
		await _play(event)
	_busy = false

	var evolving := battle.evolving_unit()
	if _is_cpu_turn():
		_selected_id = 0  # CPU の番は、選べることを出さない。
	elif evolving != null and not battle.is_over():
		_selected_id = evolving.id  # 進化先を選ぶまで、この駒を見せる。
	elif battle.acting_unit_id != 0:
		_selected_id = battle.acting_unit_id  # 動いたあと。続けて攻撃・回復・待機・取り消しを選ぶ。
	elif not action is UndoMoveAction:
		_selected_id = 0
	_refresh()
	_run_cpu()
	return true


# ---- CPU の番 ----


## CPU の番なら、CPU の行動を 1 つずつ、人の操作と同じ入口（_do）に流す。番が終わるか、決着するか、相手を人に切り替えるまで続ける。
## 何をしたか追えるように、駒が動き出す前にカメラを寄せ、1 体の行動が終わるたびに間を置く。
## 動かずに待機するだけの駒は、見せるものが無いので間を置かない。
func _run_cpu() -> void:
	if _cpu_running or _busy or not _is_cpu_turn():
		return
	_cpu_running = true
	_refresh()
	var played_battle := battle
	while battle == played_battle and _is_cpu_turn():
		var action := _cpu.next_action(battle)
		if action == null:
			break
		var unit: Unit = battle.unit_by_id(action.get(&"unit_id")) if &"unit_id" in action else null
		var idle := action is WaitAction and unit != null and not unit.has_moved
		if unit != null and not unit.has_moved and not idle and not action is EvolveAction:
			_rig.focus_on(_view(unit.id).position)
			await get_tree().create_timer(CPU_FOCUS_TIME).timeout
		if not await _do(action):
			break  # CPU の行動は必ず受け付けられるはず。そうでなければ、同じ行動を繰り返さずに手を止める。
		cpu_actions += 1
		if not (action is MoveAction or action is EndPhaseAction or idle or battle.is_over()):
			await get_tree().create_timer(CPU_PAUSE).timeout
	_cpu_running = false
	# 番の途中で相手を人に切り替えたら、動いたあとの駒を選んだ状態で引き渡す。
	_selected_id = battle.acting_unit_id
	_refresh()


# ---- イベントの再生 ----


## イベントの種類（スクリプト）-> 再生するメソッドの名前。
## rules/events/ のイベントは、すべてここに載せる（載っていない種類があると、テストが落ちる）。
static func event_players() -> Dictionary:
	return {
		UnitMovedEvent: &"_play_moved",
		UnitWarpedEvent: &"_play_warped",
		MoveUndoneEvent: &"_play_undone",
		AttackDamagedEvent: &"_play_attack_damaged",
		ExplosionDamagedEvent: &"_play_explosion_damaged",
		HealerHealedEvent: &"_play_healer_healed",
		SpringHealedEvent: &"_play_spring_healed",
		RegenerationHealedEvent: &"_play_regeneration_healed",
		ExperienceGainedEvent: &"_play_experience_gained",
		LevelUpEvent: &"_play_level_up",
		EvolutionOfferedEvent: &"_play_evolution_offered",
		UnitEvolvedEvent: &"_play_evolved",
		UnitDefeatedEvent: &"_play_defeated",
		UnitSpawnedEvent: &"_play_spawned",
		BarrelExplodedEvent: &"_play_barrel_exploded",
		UnitActedEvent: &"_play_acted",
		PhaseStartedEvent: &"_play_phase_started",
		CaptureProgressEvent: &"_play_capture",
		GameWonEvent: &"_play_won",
		GameDrawnEvent: &"_play_drawn",
	}


func _play(event: BattleEvent) -> void:
	var kind: Script = event.get_script()
	if not _players.has(kind):
		push_error("再生できないイベント: %s" % kind.resource_path)
		return
	played[kind] = played.get(kind, 0) + 1
	await call(_players[kind], event)


func _play_moved(event: UnitMovedEvent) -> void:
	if event.path.size() < 2:
		return
	var view := _view(event.unit_id)
	_follow_neutral(event.unit_id)
	var step_time := CRUISE_STEP_TIME if event.cruise else STEP_TIME
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


## 道順どおりに歩いたあとの、ポータルの転移。入ったポータルで縮んで消え、出たポータルに現れる。
func _play_warped(event: UnitWarpedEvent) -> void:
	var view := _view(event.unit_id)
	var color := BoardView.portal_color(battle.board, event.from)
	var to := BoardView.cell_center(event.to)
	_flash(BoardView.cell_center(event.from), color, 0.9)
	var shrink := create_tween()
	shrink.tween_property(view, "scale", Vector3.ONE * 0.05, 0.16)
	await shrink.finished
	view.position = to
	_rig.focus_on(to)  # 行き先が画面の外でも、どこへ出たかが見えるようにする。
	_flash(to, color, 0.9)
	var grow := create_tween()
	grow.tween_property(view, "scale", Vector3.ONE, 0.16)
	await grow.finished


## 駒の攻撃。攻撃の動きのあとに被弾。
func _play_attack_damaged(event: AttackDamagedEvent) -> void:
	var target := _view(event.unit_id)
	var attacker := _view(event.attacker_id)
	_follow_neutral(event.attacker_id)
	attacker.face(target.position - attacker.position)
	target.face(attacker.position - target.position)
	await get_tree().create_timer(attacker.play_attack()).timeout
	await _play_hit(event, Color("ffe9a8"), 0.45)


## 爆発のダメージ（攻撃した駒がいない）は、被弾だけを続けて見せる。
func _play_explosion_damaged(event: ExplosionDamagedEvent) -> void:
	await _play_hit(event, Color("ffb14a"), 0.15)


func _play_hit(event: UnitDamagedEvent, color: Color, wait: float) -> void:
	var target := _view(event.unit_id)
	target.play_hit()
	target.set_hp(event.hp)
	_pop_number(target.position, "-%d" % event.amount, color)
	await get_tree().create_timer(wait).timeout


## 回復役の回復。回復役が相手のほうを向いて手を振り、相手に光と数を出す。
func _play_healer_healed(event: HealerHealedEvent) -> void:
	var healer := _view(event.healer_id)
	var target := _view(event.unit_id)
	healer.face(target.position - healer.position)
	await get_tree().create_timer(healer.play_attack()).timeout
	await _play_heal(event, true)


## 回復の泉（フェーズの始め）は、光と数を出す。
func _play_spring_healed(event: SpringHealedEvent) -> void:
	await _play_heal(event, true)


## 再生（進化先の特性。フェーズの始め）も、光と数を出す。
func _play_regeneration_healed(event: RegenerationHealedEvent) -> void:
	await _play_heal(event, true)


func _play_heal(event: UnitHealedEvent, glow: bool) -> void:
	var view := _view(event.unit_id)
	view.set_hp(event.hp)
	_pop_number(view.position, "+%d" % event.amount, Color("9cf09c"))
	if glow:
		_flash(view.position, BoardView.COLOR_SPRING_CROSS, 0.8)
	await get_tree().create_timer(0.35).timeout


## 経験値が入った。数を小さく出すだけ（たまった量は左下の駒の情報に出る）。
func _play_experience_gained(event: ExperienceGainedEvent) -> void:
	var view := _view(event.unit_id)
	_pop_number(view.position + Vector3(0.0, 0.35, 0.0), "経験 +%d" % event.amount, COLOR_EXPERIENCE)
	await get_tree().create_timer(0.2).timeout


## レベルが上がった。札のレベルと HP のバーを描き直し、光と知らせを出す。
func _play_level_up(event: LevelUpEvent) -> void:
	var view := _view(event.unit_id)
	view.set_growth(event.level, event.max_hp)
	view.set_hp(event.hp)
	_flash(view.position + Vector3(0.0, 0.5, 0.0), COLOR_LEVEL_UP, 1.4)
	_pop_number(view.position + Vector3(0.0, 0.6, 0.0), "レベル %d！" % event.level, COLOR_LEVEL_UP)
	await get_tree().create_timer(0.5).timeout


## 進化先を選べるようになった。光と知らせだけ（選択肢は、再生が終わったあとに _refresh が出す）。
func _play_evolution_offered(event: EvolutionOfferedEvent) -> void:
	var view := _view(event.unit_id)
	_flash(view.position + Vector3(0.0, 0.5, 0.0), COLOR_EVOLUTION, 1.6)
	_pop_number(view.position + Vector3(0.0, 0.6, 0.0), "進化できる！", COLOR_EVOLUTION)
	await get_tree().create_timer(0.4).timeout


## 進化した。札に印を付け、HP のバーを新しい最大 HP で描き直し、進化先の名前を出す。
func _play_evolved(event: UnitEvolvedEvent) -> void:
	var view := _view(event.unit_id)
	view.set_evolved(event.max_hp)
	view.set_hp(event.hp)
	_flash(view.position + Vector3(0.0, 0.5, 0.0), COLOR_EVOLUTION, 1.8)
	_pop_number(view.position + Vector3(0.0, 0.6, 0.0), Evolution.display_name(event.evolution), COLOR_EVOLUTION)
	await get_tree().create_timer(0.6).timeout


## 攻撃の動きのあと、樽を消して、爆発の届いたマスを塗る（続くダメージの再生の間も塗ったまま）。
func _play_barrel_exploded(event: BarrelExplodedEvent) -> void:
	var at := BoardView.cell_center(event.cell)
	if _views.has(event.attacker_id):
		var attacker := _view(event.attacker_id)
		attacker.face(at - attacker.position)
		await get_tree().create_timer(attacker.play_attack()).timeout
	_board_view.remove_barrel(event.cell)
	var colors := {event.cell: COLOR_BLAST}
	for cell in event.blast_cells:
		colors[cell] = COLOR_BLAST
	_board_view.show_cells(colors)
	_flash(at + Vector3(0.0, 0.3, 0.0), Color("ff8a2a"), 2.6)
	_pop_number(at, "爆発", Color("ff8a2a"))
	await get_tree().create_timer(0.3).timeout


func _play_acted(event: UnitActedEvent) -> void:
	_view(event.unit_id).set_acted(true)


func _play_won(event: GameWonEvent) -> void:
	await get_tree().create_timer(0.4).timeout
	_hud.show_result(event.winner, WIN_REASONS[event.reason])


func _play_drawn(event: GameDrawnEvent) -> void:
	await get_tree().create_timer(0.4).timeout
	_hud.show_draw(DRAW_REASONS[event.reason])


func _play_defeated(event: UnitDefeatedEvent) -> void:
	var view := _view(event.unit_id)
	_views.erase(event.unit_id)
	await view.play_death()


## 中立の駒が結晶泉に湧いた。光とともに、小さい形から大きくする。
func _play_spawned(event: UnitSpawnedEvent) -> void:
	var at := BoardView.cell_center(event.cell)
	var view: UnitView = UnitView.new()
	view.position = at
	add_child(view)
	view.setup(event.kind, TEAM_COLORS[event.side], event.hp, event.max_hp)
	view.face(BoardView.cell_center(event.cell + Vector2i.DOWN) - at)
	_views[event.unit_id] = view
	_rig.focus_on(at)
	_flash(at + Vector3(0.0, 0.4, 0.0), TEAM_COLORS[event.side], 1.6)
	view.scale = Vector3.ONE * 0.05
	var grow := create_tween()
	grow.tween_property(view, "scale", Vector3.ONE, 0.3)
	await grow.finished


## 中立の駒が動く・攻撃するときは、カメラをその駒へ寄せる（どの駒の番かが分かるように）。
func _follow_neutral(unit_id: int) -> void:
	var unit := battle.unit_by_id(unit_id)
	if unit != null and unit.side == Unit.Side.NEUTRAL:
		_rig.focus_on(_view(unit_id).position)


func _play_phase_started(event: PhaseStartedEvent) -> void:
	_refresh_status(event.turn, event.side)
	if event.side == Unit.Side.NEUTRAL:
		# 中立の駒は行動済みを持たないので、明るさは変えない。カメラは動く駒を追う（_follow_neutral）。
		_hud.show_banner("ターン %d　%s の番" % [event.turn, _side_name(event.side)], TEAM_COLORS[event.side])
		await get_tree().create_timer(0.5).timeout
		return
	for unit in battle.units:
		if unit.side == event.side:
			_view(unit.id).set_acted(false)
	_hud.show_banner("ターン %d　%s の番" % [event.turn, _side_name(event.side)], TEAM_COLORS[event.side])
	_rig.focus_on(_camera_point(event.side))
	await get_tree().create_timer(0.5).timeout


func _play_capture(event: CaptureProgressEvent) -> void:
	_refresh_status(battle.turn, battle.phase)
	var hq := battle.board.hq_cells[1 - event.player]
	var text := "占拠 %d / %d" % [event.turns, Battle.CAPTURE_TURNS_TO_WIN] if event.turns > 0 else "占拠が途切れた"
	_pop_number(BoardView.cell_center(hq), text, TEAM_COLORS[event.player].lightened(0.4))


## 広がって消える光の球（爆発、転移、泉の回復）。size は広がりきったときの直径。
func _flash(at: Vector3, color: Color, size: float) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color, 0.7)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var ball := MeshInstance3D.new()
	ball.mesh = SphereMesh.new()
	ball.material_override = material
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ball.position = at
	ball.scale = Vector3.ONE * size * 0.2
	add_child(ball)
	var tween := create_tween()
	tween.tween_property(ball, "scale", Vector3.ONE * size, 0.35).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(material, "albedo_color:a", 0.0, 0.35)
	tween.tween_callback(ball.queue_free)


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
	_barrel_targets = Queries.barrel_targets(battle, unit)
	_heal_targets = Queries.heal_targets(battle, unit)

	_painted = {}
	if unit != null and not battle.is_over():
		if battle.can_act(unit):
			for cell: Vector2i in _move_cells:
				_painted[cell] = COLOR_CRUISE if _move_cells[cell] else COLOR_MOVE
			for target in _targets:
				_painted[target.cell] = COLOR_TARGET
			for target in _heal_targets:
				_painted[target.cell] = COLOR_HEAL
			for cell in _barrel_targets:
				_painted[cell] = COLOR_TARGET
		else:
			for cell in Queries.inspect_cells(battle, unit):
				_painted[cell] = COLOR_INSPECT
	_show_painted()

	_selection_ring.visible = unit != null
	if unit != null:
		_selection_ring.position = BoardView.cell_center(unit.cell) + Vector3(0.0, 0.04, 0.0)

	_refresh_status(battle.turn, battle.phase)
	_refresh_hint(unit)
	var evolving := battle.evolving_unit()
	var cpu_turn := _cpu_running or _is_cpu_turn()
	if evolving != null and not battle.is_over() and not cpu_turn:
		var healer := UnitKind.role(evolving.kind) == UnitKind.Role.HEALER
		var texts: Array[String] = []
		for choice in battle.options(evolving.id).evolutions:
			texts.append(BattleHud.evolution_text(choice, healer))
		_hud.show_evolution("%s の進化先を選ぶ" % UnitKind.display_name(evolving.kind), texts)
	else:
		_hud.hide_evolution()
	var unacted := Queries.unacted_count(battle)
	if cpu_turn:
		_hud.set_end_turn(false, "CPU の番")
	elif _confirming_end:
		_hud.set_end_turn(true, "未行動 %d 体。もう一度で終了" % unacted)
	else:
		_hud.set_end_turn(not battle.is_over() and evolving == null, "ターン終了")
	var can_act := unit != null and not battle.is_over() and battle.can_act(unit) and not cpu_turn
	_hud.set_actions(can_act, unit != null and not battle.is_over() and not cpu_turn, unit != null and unit.has_moved)
	_update_info()


func _refresh_status(turn: int, phase: Unit.Side) -> void:
	var counts: Array[int] = [
		Queries.unit_count(battle, Unit.Side.PLAYER1), Queries.unit_count(battle, Unit.Side.PLAYER2),
	]
	_hud.set_status(turn, phase, counts, battle.capture_turns, Battle.CAPTURE_TURNS_TO_WIN)


func _refresh_hint(unit: Unit) -> void:
	if battle.is_over():
		_hud.set_hint("決着")
	elif _cpu_running or _is_cpu_turn():
		_hud.set_hint("CPU が考えている…（F4 で、相手を人に切り替える）")
	elif battle.evolving_unit() != null:
		_hud.set_hint("進化先を選ぶ（上のボタンか、1・2 のキー）。選ぶまで、ほかの操作はできない")
	elif unit == null:
		_hud.set_hint("駒をクリックして選ぶ。相手の駒を選ぶと、動ける範囲が見える")
	elif not battle.can_act(unit):
		_hud.set_hint("この駒はいま動かせない（白いマスは移動範囲）")
	elif unit.has_moved:
		if unit.cruised:
			_hud.set_hint("巡航で動いたので攻撃できない。待機するか、移動を取り消す")
		elif not _heal_targets.is_empty():
			_hud.set_hint("緑のマスの味方をクリックで回復。または待機、移動の取り消し")
		elif UnitKind.role(unit.kind) == UnitKind.Role.HEALER:
			_hud.set_hint("回復できる味方がいない。待機するか、移動を取り消す")
		elif _targets.is_empty() and _barrel_targets.is_empty():
			_hud.set_hint("攻撃できる相手がいない。待機するか、移動を取り消す")
		else:
			_hud.set_hint("赤いマスの相手か樽をクリックで攻撃。または待機、移動の取り消し")
	elif UnitKind.role(unit.kind) == UnitKind.Role.HEALER:
		_hud.set_hint("青: 移動　黄: 巡航（2 倍動けるが回復できない）　緑: 回復（減っている味方）")
	else:
		_hud.set_hint("青: 移動　黄: 巡航（2 倍動けるが攻撃できない）　赤: 攻撃（相手・樽）")


## 塗ったマスに、マウスの下のマスまでの道か、マウスの下の樽の爆発が届くマスを重ねて出す。
func _show_painted() -> void:
	var colors := _painted
	var unit := selected_unit()
	if unit != null and not _busy and _barrel_targets.has(_hover_cell):
		colors = _painted.duplicate()
		for cell in MapObject.blast_cells(battle.board, _hover_cell):
			colors[cell] = COLOR_BLAST
	elif unit != null and not _busy and _move_cells.has(_hover_cell):
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
		cell_text += _object_text(_hover_cell)
	_hud.show_cell(cell_text)

	var shown := hovered if hovered != null else selected_unit()
	if shown == null:
		_hud.show_unit(null, "", "")
		return
	if hovered == null and _barrel_targets.has(_hover_cell):
		_hud.show_unit(shown, "樽を狙っている", _blast_forecast(shown, _hover_cell))
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
		# 経験値の見込みも、実際と同じ計算（Growth）を状態を変えずに使う。
		var growth := Growth.preview(attacker, Growth.attack_experience(battle, attacker, hovered))
		if growth.gained > 0:
			forecast += "\n経験 +%d%s" % [growth.gained, "（レベルアップ）" if growth.levels_gained > 0 else ""]
	elif hovered != null and _heal_targets.has(hovered):
		# 回復の見込み。実際の回復と同じ計算（Healing.amount、Growth）を、状態を変えずに使う。
		var amount := Healing.amount(attacker, hovered)
		forecast = "回復すると +%d → HP %d / %d" % [amount, hovered.hp + amount, hovered.max_hp()]
		var growth := Growth.preview(attacker, Growth.heal_experience())
		if growth.gained > 0:
			forecast += "\n経験 +%d%s" % [growth.gained, "（レベルアップ）" if growth.levels_gained > 0 else ""]
	_hud.show_unit(shown, state, forecast)


## マスにある環境オブジェクトの説明（無ければ空）。
func _object_text(cell: Vector2i) -> String:
	var type := battle.board.object_at(cell)
	if type == MapObject.Type.NONE:
		return ""
	var text: String = "　" + BattleHud.OBJECT_NAMES[type]
	if type == MapObject.Type.PORTAL:
		var exit := battle.board.portal_exit(cell)
		text += " → (%d, %d)" % [exit.x, exit.y]
		if battle.portal_exit(cell) == Board.NO_CELL:
			text += "（行き先に駒がいて、いまは使えない）"
	return text


## 樽を攻撃したときの見込み。実際の爆発と同じ計算（MapObject.blast_victims / blast_damage）を使う。
func _blast_forecast(attacker: Unit, barrel: Vector2i) -> String:
	var counts := {"敵": 0, "味方": 0}
	var falls := {"敵": 0, "味方": 0}
	var kings: Array[String] = []
	for victim in MapObject.blast_victims(battle, barrel):
		var who := "味方" if victim.side == attacker.side else "敵"
		counts[who] += 1
		if victim.hp <= MapObject.blast_damage(victim):
			falls[who] += 1
			if victim.kind == UnitKind.Id.KING:
				kings.append(who)
	var parts: Array[String] = []
	for who: String in counts:
		if counts[who] > 0:
			parts.append("%s %d 体" % [who, counts[who]] + ("（%d 体倒れる）" % falls[who] if falls[who] > 0 else ""))
	if parts.is_empty():
		return "樽を爆発させる（巻き込む駒はいない）"
	var text := "樽を爆発させる → %d ダメージ: %s" % [MapObject.BLAST_DAMAGE, "、".join(parts)]
	if MapObject.blast_cells(battle.board, barrel).has(attacker.cell):
		text += "\n自分も巻き込まれる"
	for who in kings:
		text += "\n%sの将が倒れる" % who
	return text


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
