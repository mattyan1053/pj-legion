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
const MatchSetupPanel := preload("res://prototype/match_setup_panel.gd")
const Queries := preload("res://prototype/battle_queries.gd")
const ForecastText := preload("res://prototype/forecast_text.gd")
const Autoplay := preload("res://prototype/autoplay.gd")
const StatsText := preload("res://prototype/stats_text.gd")
const MenuPlacement := preload("res://prototype/menu_placement.gd")
const NeutralPlayback := preload("res://prototype/neutral_playback.gd")

const NO_CELL := Vector2i(-1, -1)
const NOTHING_SPECIAL := "特別なものは無い"
const TEAM_COLORS: Array[Color] = [Color("3a7bd5"), Color("d64545"), Color("e0b83a")]

## 1 マス歩くのにかける秒数（巡航は速く走る）。中立の駒は、目で追えるよう、ゆっくり歩かせる。
const STEP_TIME := 0.16
const CRUISE_STEP_TIME := 0.1
const NEUTRAL_STEP_TIME := 0.26

const COLOR_MOVE := Color(0.35, 0.65, 1.0, 0.5)
const COLOR_CRUISE := Color(1.0, 0.82, 0.3, 0.4)
const COLOR_PATH := Color(1.0, 1.0, 1.0, 0.75)
const COLOR_TARGET := Color(1.0, 0.2, 0.15, 0.7)
const COLOR_HEAL := Color(0.3, 0.95, 0.45, 0.7)
const COLOR_BLAST := Color(1.0, 0.55, 0.1, 0.6)
const COLOR_SKILL := Color(0.55, 0.25, 0.95, 0.7)
const COLOR_SKILL_AREA := Color(1.0, 0.55, 0.9, 0.85)
const COLOR_EXPERIENCE := Color("9fd8ff")
const COLOR_LEVEL_UP := Color("ffd34a")
const COLOR_EVOLUTION := Color("d9a6ff")
const COLOR_RELIC := Color("ffe08a")
const COLOR_INSPECT := Color(0.8, 0.93, 1.0, 0.5)
const COLOR_THREAT := Color(0.95, 0.05, 0.2, 0.62)
const COLOR_SELECTED := Color(1.0, 0.9, 0.3, 0.9)

## 押してから離すまでにマウスがこれより動いたら、クリックではなくドラッグ（視点の回転）と見る（px）。
const DRAG_THRESHOLD := 8.0
## ドラッグで視点を回す速さ（1 px あたりのラジアン）。
const DRAG_ROTATE_SPEED := 0.008

## 駒のそばのメニューの項目の名前。
const MENU_ATTACK := &"attack"
const MENU_HEAL := &"heal"
const MENU_SKILL := &"skill"
const MENU_WAIT := &"wait"
const MENU_UNDO := &"undo"
const MENU_BACK := &"back"
## メニューが隠したくないものの重み（menu_placement.gd）。攻撃・回復・スキルの相手、ほかの駒、届くマス、情報の枠。
const MENU_WEIGHT_TARGET := 12.0
const MENU_WEIGHT_UNIT := 4.0
const MENU_WEIGHT_MOVE := 1.0
const MENU_WEIGHT_CRUISE := 0.4
const MENU_WEIGHT_PANEL := 6.0

## 対象を選んでいる途中か。その間は、塗るのは対象のマスだけで、クリックは対象を選ぶ（ほかのマスなら、やめる）。
## NONE でも、赤・緑のマスを直接クリックすれば攻撃・回復できる（メニューの「攻撃」「回復」は、相手だけを見せる近道）。
enum Mode { NONE, ATTACK, HEAL, SKILL }

## CPU の駒が動き出す前に、カメラを寄せて見せる秒数と、1 体の行動が終わってから次の駒までの間。
const CPU_FOCUS_TIME := 0.35
const CPU_PAUSE := 0.45
## 中立のフェーズで、攻撃する駒へカメラを寄せてから動き出すまでの秒数と、その駒の場面が終わってから次までの間。
const NEUTRAL_FOCUS_TIME := 0.5
const NEUTRAL_PAUSE := 0.5

const WIN_REASONS := {
	GameWonEvent.Reason.KING_DEFEATED: "敵の将を倒した",
	GameWonEvent.Reason.HQ_CAPTURED: "敵の本陣を占拠し続けた",
}

const DRAW_REASONS := {
	GameDrawnEvent.Reason.BOTH_KINGS_DEFEATED: "両方の将が同時に倒れた",
}

var battle: Battle
## いまの対戦の戦績。行動のたびに、起きたことを食わせる（決着の画面に要点を出す）。
var stats: BattleStats
var stage := BoardGenerator.Stage.PLAIN
var map_seed := 0

var _board_view: BoardView
var _views := {}  # 駒の番号 -> UnitView
var _hud: BattleHud
var _setup_panel: MatchSetupPanel
var _rig: OrbitCamera
var _selection_ring: MeshInstance3D

## 対戦の設定画面で選んだもの（trial_setup.gd）。やり直し（F1〜F3、結果のボタン）も、これで始める。
var match_choice: RefCounted = TrialSetup.new()
## 相手を CPU が動かすか。偽なら、2 人が交代で操作する。CPU が動かすのは match_choice.cpu_side()。
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
var _barricade_targets: Array[Vector2i] = []
var _heal_targets: Array[Unit] = []
var _skill_cells: Array[Vector2i] = []
var _mode := Mode.NONE
## クリックして情報を出しているマス（駒のいないマス。無ければ NO_CELL）。
var _inspected_cell := NO_CELL
## 左ボタンを押した場所と、そこが駒のいるマスか、押してからドラッグになったか。
var _press_position := Vector2.ZERO
var _pressing := false
var _press_on_unit := false
var _dragging := false
var _menu_placement := MenuPlacement.new()
## メニューを置いたときのカメラ（動いたら置き直す）。
var _menu_camera := Transform3D()
var _menu_dirty := true
## マウスが乗っているメニューの項目（乗っていなければ空の名前）。その項目の説明を、左下の枠に出す。
var _menu_hover_id := &""
## 対戦を始めたことがあるか（起動した直後の設定画面だけ偽。偽の間は、設定画面を閉じて戻る先が無い）。
var _battle_started := false
## 中立のフェーズの静かな場面（動いただけ、湧いただけ）をまとめて流している途中か。この間は、カメラを動かさない。
var _quiet_playback := false
## まとめて流している場面のうち、まだ終わっていないものの数。
var _beats_running := 0
## カメラが追いかけた駒の番号 -> 回数。検査用。
var camera_follows := {}
## 必殺技を使うかを、もう一度押して確かめている途中か（対象を選ばず、取り消せないので、1 回では使わない）。
var _confirming_ult := false
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
	_hud.menu_pressed.connect(_on_menu_pressed)
	_hud.menu_hovered.connect(_on_menu_hovered)
	_hud.ult_pressed.connect(press_ult)
	_hud.end_turn_pressed.connect(press_end_turn)
	_hud.restart_pressed.connect(_on_restart_pressed)
	_hud.evolution_chosen.connect(choose_evolution)
	_hud.opponent_pressed.connect(toggle_opponent)
	_hud.setup_pressed.connect(open_setup)
	_setup_panel = MatchSetupPanel.new()
	_hud.add_child(_setup_panel)
	_setup_panel.setup(TEAM_COLORS)
	_setup_panel.visible = false
	_setup_panel.start_pressed.connect(_on_setup_chosen)
	_setup_panel.cancelled.connect(_refresh)

	var autoplay := OS.get_cmdline_user_args().has("--autoplay")
	var shots := OS.get_cmdline_user_args().has("--shots")
	# 検査は、人の操作の入口を両方のプレイヤーで通すところから始める（CPU の番は、検査の中で切り替えて通す）。
	set_opponent(not (autoplay or shots))
	_battle_started = autoplay or shots
	# 検査では毎回同じ対戦にする。遊ぶときは毎回違う盤面にする。
	start_battle(BoardGenerator.Stage.PLAIN, 20261114 if autoplay or shots else int(Time.get_unix_time_from_system()))
	if autoplay:
		add_child(Autoplay.new(self))
	elif shots:
		# スクリーンショットの道具（tools/screenshots.gd）。遊ぶときは読み込まない。
		add_child(load("res://tools/screenshots.gd").new(self))
	else:
		open_setup()  # 遊ぶときは、まず対戦の設定を選ぶ（後ろの盤面は既定の設定で作っておく）


func _process(delta: float) -> void:
	# カメラが動くとマウスの下のマスも変わるので、マウスの動きではなく毎フレーム追う。
	_update_hover()
	var focus_cells: Array[Vector2i] = []
	for view: UnitView in _views.values():
		focus_cells.append(BoardView.cell_of(view.position))
	if battle.board.in_bounds(_hover_cell):
		focus_cells.append(_hover_cell)
	_board_view.update_occlusion(_rig.camera, _rig.global_position, focus_cells, delta)
	_place_menu()


func _unhandled_input(event: InputEvent) -> void:
	if _setup_panel.visible:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# 押しただけでは何もしない。離すまでに動かなければクリック、動けば視点の回転（駒の上で押したときは、いつもクリック）。
			_pressing = true
			_dragging = false
			_press_position = event.position
			var cell := _cell_under_mouse()
			_press_on_unit = battle.board.in_bounds(cell) and battle.unit_at(cell) != null
		elif _pressing:
			_pressing = false
			if not _dragging:
				click_cell(_cell_at(_press_position))
			_dragging = false
	elif event is InputEventMouseMotion and _pressing:
		if not event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			# ボタンを、帯やメニューの上で離した（離したことが、ここへは届かない）。押していないのに回り続けないよう、やめる。
			_pressing = false
			_dragging = false
		elif not _press_on_unit:
			if not _dragging and event.position.distance_to(_press_position) > DRAG_THRESHOLD:
				_dragging = true
			if _dragging:
				_rig.rotate_by(-event.relative.x * DRAG_ROTATE_SPEED)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		cancel()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE:
				cancel()
			KEY_SPACE:
				press_wait()
			KEY_F:
				press_skill()
			KEY_G:
				press_ult()
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


## いまの設定（match_choice）のステージを battle_stage にして、盤面を作り、軍を置いて、最初から始める。
## 対戦はルールの入口（MatchSetup.create_battle）で作る。再生の途中と CPU の番の間は何もしない。
func start_battle(battle_stage: BoardGenerator.Stage, battle_seed: int) -> void:
	if is_busy():
		return
	match_choice.stage = battle_stage
	match_choice.cpu_opponent = cpu_opponent
	start_with(match_choice.to_setup(battle_seed).create_battle(), battle_stage, battle_seed)


## 対戦の設定画面を、いまの設定で開く。再生の途中と CPU の番の間は何もしない。
## 開いただけでは、いまの対戦は変わらない（「対戦へ戻る」・右クリック・Esc で、そのまま戻れる）。
## 新しい対戦になるのは、設定画面で始めるボタンを押したときだけ。
func open_setup() -> void:
	if is_busy():
		return
	match_choice.cpu_opponent = cpu_opponent
	_setup_panel.open(match_choice, _battle_started, _battle_started and not battle.is_over())


## 対戦の設定画面（検査用）。
func setup_panel() -> MatchSetupPanel:
	return _setup_panel


func _on_setup_chosen(chosen: RefCounted) -> void:
	_battle_started = true
	match_choice = chosen
	# いまの対戦の続きを CPU に渡さないよう、set_opponent は通さない（新しい対戦が、始めに CPU の番を見る）。
	cpu_opponent = chosen.cpu_opponent
	_show_opponent()
	start_battle(chosen.stage, map_seed + 1)


## 用意した対戦を、最初から始める（検査では、小さな盤面を作って渡す）。再生の途中と CPU の番の間は何もしない。
func start_with(new_battle: Battle, battle_stage: BoardGenerator.Stage, battle_seed: int) -> void:
	if is_busy():
		return
	stage = battle_stage
	map_seed = battle_seed
	battle = new_battle
	stats = BattleStats.new(battle)

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
	_mode = Mode.NONE
	_inspected_cell = NO_CELL
	_pressing = false
	_confirming_end = false
	_confirming_ult = false
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


## 操作を受け付けない間か（イベントの再生の途中か、CPU の番を進めている途中か、対戦の設定画面を開いている間）。
func is_busy() -> bool:
	return _busy or _cpu_running or _setup_panel.visible


## 相手（match_choice.cpu_side() のプレイヤー）を CPU にするか、人にするかを決める。対戦の途中でも切り替えられる
## （CPU にすれば、相手の番の続きを CPU が引き取る。人にすれば、CPU はいまの行動を最後に手を止める）。
func set_opponent(cpu: bool) -> void:
	cpu_opponent = cpu
	match_choice.cpu_opponent = cpu
	_show_opponent()
	if battle != null and not is_busy():
		if _is_cpu_turn():
			_select(0)
			_run_cpu()
		else:
			_refresh()  # 自分の番の途中なら、選んでいる駒（動いたあとの駒）はそのまま。


func _show_opponent() -> void:
	_hud.set_opponent("相手: CPU" if cpu_opponent else "相手: 人")


func toggle_opponent() -> void:
	set_opponent(not cpu_opponent)


## いまが、CPU が動かす番か。
func _is_cpu_turn() -> bool:
	return cpu_opponent and not battle.is_over() and battle.phase == match_choice.cpu_side()


## 番の知らせに出す陣営の名前（CPU が動かすなら、そう書く）。
func _side_name(side: Unit.Side) -> String:
	var side_name: String = BattleHud.SIDE_NAMES[side]
	return side_name + " CPU" if cpu_opponent and side == match_choice.cpu_side() else side_name


func selected_unit() -> Unit:
	return battle.unit_by_id(_selected_id)


## 画面の駒がいまいるマス（駒の番号 -> マス）。検査用。
func view_cells() -> Dictionary:
	var cells := {}
	for unit_id: int in _views:
		cells[unit_id] = BoardView.cell_of(_views[unit_id].position)
	return cells


## 画面の駒が持っている HP（駒の番号 -> HP。減っていれば、足元の棒に出る）。検査用。
func view_hps() -> Dictionary:
	var hps := {}
	for unit_id: int in _views:
		hps[unit_id] = _views[unit_id].shown_hp
	return hps


## 画面に樽が描かれているマス。検査用。
func barrel_view_cells() -> Array[Vector2i]:
	return _board_view.barrel_cells()


## 画面に描かれている盤の上の効果の番号（小さい順）。検査用。
func field_effect_view_ids() -> Array[int]:
	return _board_view.field_effect_ids()


## いま出ている結果の見出し（出ていなければ空）。検査用。
func result_title() -> String:
	return _hud.result_title()


## いま出ている戦績の要点（出ていなければ空）。検査用。
func result_stats() -> String:
	return _hud.result_stats()


## 盤面のマスをクリックする。選んでいる駒の攻撃できる相手・樽なら攻撃、回復できる味方なら回復、動けるマスなら移動、
## 駒なら選び直す。駒のいないマスなら、選ぶのをやめて、そのマスの情報を出す。
## 対象を選んでいる途中（メニューの攻撃・回復・スキル）なら、対象のマスで行動し、ほかのマスでは選ぶのをやめる。
func click_cell(cell: Vector2i) -> void:
	if is_busy() or battle.is_over() or not battle.board.in_bounds(cell):
		return
	if _confirming_ult:
		# 必殺技を確かめている途中のクリックは、確かめるのをやめるだけ（移動や攻撃はしない）。
		_confirming_ult = false
		_refresh()
		return
	var clicked := battle.unit_at(cell)
	if _mode == Mode.SKILL:
		if _skill_cells.has(cell):
			_do(UseSkillAction.new(_selected_id, cell))
		else:
			_leave_mode()
		return
	if clicked != null and _targets.has(clicked) and _mode != Mode.HEAL:
		_do(AttackAction.new(_selected_id, clicked.id))
	elif clicked != null and _heal_targets.has(clicked) and _mode != Mode.ATTACK:
		_do(HealAction.new(_selected_id, clicked.id))
	elif _barrel_targets.has(cell) and _mode != Mode.HEAL:
		_do(AttackBarrelAction.new(_selected_id, cell))
	elif _barricade_targets.has(cell) and _mode != Mode.HEAL:
		_do(AttackBarricadeAction.new(_selected_id, cell))
	elif _mode != Mode.NONE:
		_leave_mode()
	elif battle.acting_unit_id != 0:
		pass  # 動いたあとは、攻撃・回復・待機・取り消しのどれかを選ぶ。
	elif _move_cells.has(cell):
		_do(MoveAction.new(_selected_id, cell, _move_cells[cell]))
	else:
		_select(clicked.id if clicked != null else 0)
		if clicked == null:
			_inspected_cell = cell
			_refresh()


## 駒のそばのメニューの項目を押す（クリックと同じ道を通る）。出ていて押せる項目なら真を返す。
func press_menu(id: StringName) -> bool:
	return not is_busy() and _hud.press_menu(id)


func _on_menu_pressed(id: StringName) -> void:
	if is_busy() or battle.is_over() or _selected_id == 0:
		return
	_confirming_ult = false
	match id:
		MENU_ATTACK:
			_enter_mode(Mode.ATTACK)
		MENU_HEAL:
			_enter_mode(Mode.HEAL)
		MENU_SKILL:
			if not _skill_cells.is_empty():
				_enter_mode(Mode.SKILL)
		MENU_WAIT:
			_do(WaitAction.new(_selected_id))
		MENU_UNDO:
			if battle.acting_unit_id != 0:
				_do(UndoMoveAction.new(battle.acting_unit_id))
		MENU_BACK:
			_leave_mode()


func _on_menu_hovered(id: StringName) -> void:
	_menu_hover_id = id
	if not _busy:
		_update_info()


## メニューの項目の説明（押すと何が起きるか）。マウスを乗せている間、左下の枠に出す。
func _menu_note(id: StringName, unit: Unit) -> String:
	match id:
		MENU_ATTACK:
			return "攻撃: 赤いマスの相手（樽・盾も）を選んで攻撃する。攻撃すると、この駒の行動は終わる。相手にマウスを乗せると、見込みが出る"
		MENU_HEAL:
			return "回復: 緑のマスの味方を選んで回復する（回復量 %d）。回復すると、この駒の行動は終わる" % unit.power()
		MENU_SKILL:
			var skill := Skills.of(unit)
			var after := "使うと、この駒の行動は終わる" if skill.ends_action() else "使ったあと、続けて攻撃できる（移動は取り消せなくなる）"
			return "%s: %s\n%s。%s" % [skill.display_name(), skill.summary(), after, BattleHud.skill_state_text(unit)]
		MENU_WAIT:
			return "待機: 何もせずに、この駒の行動を終える"
		MENU_UNDO:
			return "移動を取り消す: 動く前のマスへ戻して、選び直す"
		MENU_BACK:
			return "やめる: 対象を選ぶのをやめて、メニューへ戻る"
	return ""


func _enter_mode(mode: Mode) -> void:
	_mode = mode
	_refresh()


func _leave_mode() -> void:
	_mode = Mode.NONE
	_refresh()


## 選んでいる駒を待機させる（メニューの「待機」）。
func press_wait() -> void:
	press_menu(MENU_WAIT)


## 選んでいる駒のスキルの対象を選び始める（メニューのスキルの項目）。もう選んでいる途中なら、やめる（メニューの「やめる」）。
func press_skill() -> void:
	press_menu(MENU_BACK if _mode == Mode.SKILL else MENU_SKILL)


## いまの番のプレイヤーの必殺技を使う。対象を選ばず、取り消せないので、1 回目は確かめるだけで、もう一度押すと使う。
## ゲージがいっぱいでなければ何もしない。駒を選んでいなくても、駒が行動の途中でも使える。
func press_ult() -> void:
	if is_busy() or not battle.can_apply(UseUltAction.new()):
		return
	if not _confirming_ult:
		_confirming_ult = true
		_mode = Mode.NONE
		_refresh()
		return
	_do(UseUltAction.new())


## 必殺技を使うかを確かめている途中か。検査用。
func is_confirming_ult() -> bool:
	return _confirming_ult


## 必殺技のボタンに出している文字と、押せるか。上の帯のゲージの文字。検査用。
func ult_button_text() -> String:
	return _hud.ult_button_text()


func is_ult_enabled() -> bool:
	return _hud.is_ult_enabled()


func ult_gauge_text(player: int) -> String:
	return _hud.ult_gauge_text(player)


## 上の帯に出ている、陣営の聖遺物の文字（持っていなければ空）。検査用。
func relic_text(player: int) -> String:
	return _hud.relic_text(player)


## スキルの対象を選んでいる途中か。検査用。
func is_choosing_skill_target() -> bool:
	return _mode == Mode.SKILL


## 攻撃・回復の相手を選んでいる途中か（メニューの「攻撃」「回復」を押したあと）。検査用。
func is_choosing_target() -> bool:
	return _mode == Mode.ATTACK or _mode == Mode.HEAL


## メニューのスキルの項目に出している文字と、押せるか。検査用。
func skill_button_text() -> String:
	return _hud.menu_text(MENU_SKILL)


func is_skill_enabled() -> bool:
	return _hud.is_menu_enabled(MENU_SKILL)


## 駒のそばのメニューに出ている項目の名前（上から）と、画面に占める四角、置いてよい範囲。検査用。
func menu_ids() -> Array[StringName]:
	return _hud.menu_ids()


func menu_rect() -> Rect2:
	_place_menu()
	return _hud.menu_rect()


func menu_area() -> Rect2:
	return _hud.menu_area()


## マスの中央が画面に出る位置（px）。検査とスクリーンショットの道具用。
func cell_screen_position(cell: Vector2i) -> Vector2:
	return _rig.camera.unproject_position(BoardView.cell_center(cell))


## カメラが寄っていく先（盤面の上の点）。検査用。
func camera_focus() -> Vector3:
	return _rig.focus_point()


## カメラの向き（回していく先。ラジアン）。検査用。
func camera_yaw() -> float:
	return _rig.target_yaw()


## 左下の情報の枠に出ている文（見出しを除く）。検査用。
func info_text() -> String:
	return _hud.info_text()


## 左下の情報の枠の見出し（出ていなければ空）。検査用。
func info_title() -> String:
	return _hud.info_title()


## 戻す（右クリック・Esc）。必殺技を確かめている途中か、対象を選んでいる途中なら、それをやめる。
## 動いたあとなら移動を取り消す。そうでなければ選択をやめる（マスの情報も消す）。
func cancel() -> void:
	if is_busy():
		return
	if _confirming_ult:
		_confirming_ult = false
		_refresh()
		return
	if _mode != Mode.NONE:
		_leave_mode()
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
	if unit_id != _selected_id:
		_menu_placement.reset()
	_selected_id = unit_id
	_inspected_cell = NO_CELL
	_mode = Mode.NONE
	_confirming_end = false
	_confirming_ult = false
	_refresh()


## 行動の外でルールに起きたことを再生する（検査用）。
## スキルのまだ無い盤の上の効果（煙幕）も通すため、検査はルールの FieldEffects.place_* で置いて、その結果をここで再生する。
func play_events(events: Array[BattleEvent]) -> void:
	_busy = true
	await _play_all(events)
	_busy = false
	_refresh()


## 行動を、人の操作と同じ入口で行う（スクリーンショットの道具用）。受け付けられたかを返す。
func act(action: BattleAction) -> bool:
	return await _do(action)


## カメラを cell のあたりへ寄せる（スクリーンショットの道具用）。
func focus_camera(cell: Vector2i) -> void:
	_rig.focus_on(BoardView.cell_center(cell))


## 行動をルールに渡し、起きたことを再生する。断られたら何もしない。受け付けられたかを返す。
func _do(action: BattleAction) -> bool:
	var result := battle.apply(action)
	if not result.accepted:
		return false
	stats.feed_all(result.events)
	_busy = true
	_mode = Mode.NONE
	_inspected_cell = NO_CELL
	_confirming_end = false
	_confirming_ult = false
	_board_view.show_cells({})
	_board_view.set_marked(NO_CELL)
	_selection_ring.visible = false
	_hud.set_menu([])
	_hud.set_ult_button(_hud.ult_button_text(), false, _ult_summary())
	_hud.set_end_turn(false, _hud.end_turn_text())
	_hud.hide_evolution()
	await _play_all(result.events)
	_busy = false

	var evolving := battle.evolving_unit()
	if _is_cpu_turn():
		_selected_id = 0  # CPU の番は、選べることを出さない。
	elif evolving != null and not battle.is_over():
		_selected_id = evolving.id  # 進化先を選ぶまで、この駒を見せる。
	elif battle.acting_unit_id != 0:
		_selected_id = battle.acting_unit_id  # 動いたあと。続けて攻撃・回復・待機・取り消しを選ぶ。
	elif not (action is UndoMoveAction or action is UseUltAction):
		_selected_id = 0  # 必殺技は駒の行動ではないので、選んでいた駒はそのまま。
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
		UnitTeleportedEvent: &"_play_teleported",
		UnitsSwappedEvent: &"_play_swapped",
		UnitReactivatedEvent: &"_play_reactivated",
		MoveUndoneEvent: &"_play_undone",
		AttackDamagedEvent: &"_play_attack_damaged",
		ExplosionDamagedEvent: &"_play_explosion_damaged",
		SkillDamagedEvent: &"_play_skill_damaged",
		HealerHealedEvent: &"_play_healer_healed",
		SpringHealedEvent: &"_play_spring_healed",
		RegenerationHealedEvent: &"_play_regeneration_healed",
		ExperienceGainedEvent: &"_play_experience_gained",
		LevelUpEvent: &"_play_level_up",
		EvolutionOfferedEvent: &"_play_evolution_offered",
		UnitEvolvedEvent: &"_play_evolved",
		UnitDefeatedEvent: &"_play_defeated",
		MidBossDefeatedEvent: &"_play_mid_boss_defeated",
		RelicGainedEvent: &"_play_relic_gained",
		UnitSpawnedEvent: &"_play_spawned",
		BarrelExplodedEvent: &"_play_barrel_exploded",
		BarricadePlacedEvent: &"_play_field_effect_placed",
		AreaEffectPlacedEvent: &"_play_field_effect_placed",
		FieldEffectTickedEvent: &"_play_field_effect_ticked",
		FieldEffectRemovedEvent: &"_play_field_effect_removed",
		BarricadeDamagedEvent: &"_play_barricade_damaged",
		SmokeBlockedEvent: &"_play_smoke_blocked",
		SanctuaryHealedEvent: &"_play_sanctuary_healed",
		SkillUsedEvent: &"_play_skill_used",
		SkillReadyEvent: &"_play_skill_ready",
		UltUsedEvent: &"_play_ult_used",
		UltReadyEvent: &"_play_ult_ready",
		StatusAppliedEvent: &"_play_status_applied",
		StatusRemovedEvent: &"_play_status_removed",
		UnitActedEvent: &"_play_acted",
		PhaseStartedEvent: &"_play_phase_started",
		CaptureProgressEvent: &"_play_capture",
		GameWonEvent: &"_play_won",
		GameDrawnEvent: &"_play_drawn",
	}


## 起きたことを、起きた順に再生する。中立のフェーズの中身だけは、見せ方の単位（場面）に分けて再生する。
func _play_all(events: Array[BattleEvent]) -> void:
	var i := 0
	while i < events.size():
		var event := events[i]
		await _play(event)
		i += 1
		var started := event as PhaseStartedEvent
		if started == null or started.side != Unit.Side.NEUTRAL:
			continue
		# 中立のフェーズの中身は、次のフェーズの始まり（か決着）の手前まで。
		var phase: Array[BattleEvent] = []
		while i < events.size() and not (events[i] is PhaseStartedEvent or events[i] is GameWonEvent or events[i] is GameDrawnEvent):
			phase.append(events[i])
			i += 1
		await _play_neutral_phase(phase)


## 中立のフェーズを、目で追える形で再生する（neutral_playback.gd）。
## - 動いただけ・湧いただけの駒（静かな場面）は、カメラを動かさずに、続いているものをまとめて同時に流す。
## - 攻撃した駒（見せる場面）は、カメラを寄せてから、1 体ずつ、ゆっくり歩かせて追いかけ、攻撃を見せて、間を置く。
## 起きた順は変えない。
func _play_neutral_phase(events: Array[BattleEvent]) -> void:
	for group: Array in NeutralPlayback.groups(NeutralPlayback.beats(events)):
		var first: NeutralPlayback.Beat = group[0]
		if first.quiet:
			_quiet_playback = true
			for beat: NeutralPlayback.Beat in group:
				_beats_running += 1
				_play_beat(beat)  # 待たずに始めて、同時に流す
			while _beats_running > 0:
				await get_tree().process_frame
			_quiet_playback = false
			continue
		if _views.has(first.actor_id):
			_rig.focus_on(_view(first.actor_id).position)
			await get_tree().create_timer(NEUTRAL_FOCUS_TIME).timeout
		for event in first.events:
			await _play(event)
		await get_tree().create_timer(NEUTRAL_PAUSE).timeout


func _play_beat(beat: NeutralPlayback.Beat) -> void:
	for event in beat.events:
		await _play(event)
	_beats_running -= 1


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
	var unit := battle.unit_by_id(event.unit_id)
	var step_time := CRUISE_STEP_TIME if event.cruise else STEP_TIME
	if unit != null and unit.side == Unit.Side.NEUTRAL:
		step_time = NEUTRAL_STEP_TIME
	# 自分で動かしていない駒（CPU の駒、中立の駒）は、歩いている間、カメラが追いかける（長く歩いても、画面の外へ出ていかない）。
	var followed := _camera_follows(unit)
	if followed:
		camera_follows[event.unit_id] = camera_follows.get(event.unit_id, 0) + 1
		_rig.follow(view)
	view.play_run()
	for i in range(1, event.path.size()):
		var target := BoardView.cell_center(event.path[i])
		view.face(target - view.position)
		var tween := create_tween()
		tween.tween_property(view, "position", target, step_time)
		await tween.finished
	view.play_idle()
	if followed:
		_rig.follow(null)


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
	if not _quiet_playback:
		_rig.focus_on(to)  # 行き先が画面の外でも、どこへ出たかが見えるようにする（静かな場面では、カメラを動かさない）。
	_flash(to, color, 0.9)
	var grow := create_tween()
	grow.tween_property(view, "scale", Vector3.ONE, 0.16)
	await grow.finished


## 駒の攻撃。攻撃の動きのあとに被弾。
func _play_attack_damaged(event: AttackDamagedEvent) -> void:
	var target := _view(event.unit_id)
	var attacker := _view(event.attacker_id)
	_show_strike(event.attacker_id, attacker, target)
	attacker.face(target.position - attacker.position)
	target.face(attacker.position - target.position)
	await get_tree().create_timer(attacker.play_attack()).timeout
	await _play_hit(event, Color("ffe9a8"), 0.45)


## 爆発のダメージ（攻撃した駒がいない）は、被弾だけを続けて見せる。
func _play_explosion_damaged(event: ExplosionDamagedEvent) -> void:
	await _play_hit(event, Color("ffb14a"), 0.15)


## スキルのダメージ（使った駒の動きは SkillUsedEvent が見せた）は、被弾だけを続けて見せる。
func _play_skill_damaged(event: SkillDamagedEvent) -> void:
	await _play_hit(event, Color("ff7a4a"), 0.15)


func _play_hit(event: UnitDamagedEvent, color: Color, wait: float) -> void:
	var target := _view(event.unit_id)
	target.play_hit()
	target.set_hp(event.hp)
	if event.is_blocked():
		_pop_number(target.position, "%s が防いだ" % Status.display_name(event.blocked_by as Status.Type), Color("9fd8ff"))
	elif event.critical:
		_pop_number(target.position, "クリティカル -%d" % event.amount, Color("ff5a4a"))
	else:
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


## 盤の上に効果が置かれた。描いて、中心に光を出す。
func _play_field_effect_placed(event: FieldEffectPlacedEvent) -> void:
	_board_view.add_field_effect(event.effect_id, event.type, event.side, event.cells)
	var at := BoardView.cell_center(event.center)
	_flash(at + Vector3(0.0, 0.3, 0.0), TEAM_COLORS[event.side], 1.2 if event.type == FieldEffect.Type.BARRICADE else 2.4)
	_pop_number(at, BattleHud.FIELD_EFFECT_NAMES[event.type], TEAM_COLORS[event.side].lightened(0.4))
	await get_tree().create_timer(0.3).timeout


## 煙幕・聖域の残りが減った。描き方は変えない（残りはマスの説明に出る）。
func _play_field_effect_ticked(_event: FieldEffectTickedEvent) -> void:
	pass


## 盤の上の効果が消えた（期間が尽きた・盾が壊れた）。
func _play_field_effect_removed(event: FieldEffectRemovedEvent) -> void:
	_board_view.remove_field_effect(event.effect_id)
	if event.reason == FieldEffectRemovedEvent.Reason.DESTROYED:
		var at := BoardView.cell_center(event.cells[0])
		_flash(at + Vector3(0.0, 0.3, 0.0), Color("d8d0c0"), 1.4)
		_pop_number(at, "盾が壊れた", Color("d8d0c0"))
		await get_tree().create_timer(0.3).timeout


## 盾を攻撃した。攻撃の動きのあと、減った耐久を出す。
func _play_barricade_damaged(event: BarricadeDamagedEvent) -> void:
	var at := BoardView.cell_center(event.cell)
	var attacker := _view(event.attacker_id)
	attacker.face(at - attacker.position)
	await get_tree().create_timer(attacker.play_attack()).timeout
	_pop_number(at, "耐久 -%d" % event.amount, Color("ffe9a8"))
	await get_tree().create_timer(0.3).timeout


## 攻撃が煙幕に阻まれた。攻撃の動きのあと、相手に灰色の光と「防いだ」を出す（HP は変わらない）。
func _play_smoke_blocked(event: SmokeBlockedEvent) -> void:
	var target := _view(event.target_id)
	var attacker := _view(event.attacker_id)
	_show_strike(event.attacker_id, attacker, target)
	attacker.face(target.position - attacker.position)
	target.face(attacker.position - target.position)
	await get_tree().create_timer(attacker.play_attack()).timeout
	_flash(target.position + Vector3(0.0, 0.3, 0.0), BoardView.COLOR_SMOKE, 1.2)
	_pop_number(target.position, "煙幕で防いだ", Color("d0d4da"))
	await get_tree().create_timer(0.4).timeout


## スキルで跳んだ（シャドウステップ）。その場で縮んで消え、着いたマスに現れる。
func _play_teleported(event: UnitTeleportedEvent) -> void:
	await _blink([[_view(event.unit_id), event.to]])


## 2 体の位置が入れ替わった（シャドウステップ）。2 体とも同時に消えて、互いのマスに現れる。
func _play_swapped(event: UnitsSwappedEvent) -> void:
	await _blink([[_view(event.unit_id), event.other_from], [_view(event.other_id), event.from]])


## 駒を、間を通さずに別のマスへ移す。moves は [駒の見た目, 行き先のマス] の列（同時に移す）。
func _blink(moves: Array[Array]) -> void:
	var color := Color("b98cff")
	var shrink := create_tween().set_parallel()
	for move in moves:
		var view: UnitView = move[0]
		_flash(view.position, color, 0.9)
		shrink.tween_property(view, "scale", Vector3.ONE * 0.05, 0.14)
	await shrink.finished
	var grow := create_tween().set_parallel()
	for move in moves:
		var view: UnitView = move[0]
		view.position = BoardView.cell_center(move[1])
		_flash(view.position, color, 0.9)
		grow.tween_property(view, "scale", Vector3.ONE, 0.14)
	_rig.focus_on((moves[0][0] as UnitView).position)
	await grow.finished


## 行動済みの駒が、行動前に戻った（アドレナリン注射）。行動済みの見た目を戻し、光と知らせを出す。
func _play_reactivated(event: UnitReactivatedEvent) -> void:
	var view := _view(event.unit_id)
	view.set_acted(false)
	_flash(view.position, Color("ffd24a"), 0.9)
	_pop_number(view.position + Vector3(0.0, 0.3, 0.0), "もう一度行動できる", Color("ffd24a"))
	await get_tree().create_timer(0.25).timeout


## 聖域（フェーズの始め）も、光と数を出す。
func _play_sanctuary_healed(event: SanctuaryHealedEvent) -> void:
	await _play_heal(event, true)


## スキルを使った。対象のほうを向いて手を振り、スキルの名前を出す（効果は、続くイベントが見せる）。
func _play_skill_used(event: SkillUsedEvent) -> void:
	var view := _view(event.unit_id)
	var at := BoardView.cell_center(event.target)
	if not at.is_equal_approx(view.position):
		view.face(at - view.position)
	_pop_number(view.position + Vector3(0.0, 0.5, 0.0), Skills.by_id(event.skill).display_name(), Color("dcc4ff"))
	await get_tree().create_timer(view.play_attack()).timeout


## スキルをまた使えるようになった。描き方は変えない（残りは駒の情報とスキルのボタンに出る）。
func _play_skill_ready(_event: SkillReadyEvent) -> void:
	pass


## 必殺技を使った。必殺技の名前を大きく出す（効果は、続くイベントが見せる）。飾らない最小の形。
func _play_ult_used(event: UltUsedEvent) -> void:
	_refresh_status(battle.turn, battle.phase)
	_hud.show_banner("%s　必殺技: %s!!" % [_side_name(event.side), Ults.by_id(event.ult).display_name()], BattleHud.ULT_COLORS[event.ult])
	await get_tree().create_timer(0.7).timeout


## 必殺技のゲージがいっぱいになった。上の帯のゲージを「READY」にする（ボタンは、自分の番に押せるようになる）。
func _play_ult_ready(_event: UltReadyEvent) -> void:
	_refresh_status(battle.turn, battle.phase)


## 駒に状態が付いた。状態の名前を出す（付いている状態は、駒の情報に出る）。
func _play_status_applied(event: StatusAppliedEvent) -> void:
	_pop_number(_view(event.unit_id).position, Status.display_name(event.status), Color("9fd8ff"))
	await get_tree().create_timer(0.25).timeout


## 駒の状態が外れた。使い切ったときは、ダメージや攻撃の再生が見せているので、ここでは何も出さない。
func _play_status_removed(event: StatusRemovedEvent) -> void:
	if event.reason == StatusRemovedEvent.Reason.CONSUMED:
		return
	var why := "が解けた" if event.reason == StatusRemovedEvent.Reason.MOVED else "が消えた"
	_pop_number(_view(event.unit_id).position, Status.display_name(event.status) + why, Color("b8c4d0"))
	await get_tree().create_timer(0.2).timeout


func _play_acted(event: UnitActedEvent) -> void:
	_view(event.unit_id).set_acted(true)


func _play_won(event: GameWonEvent) -> void:
	await get_tree().create_timer(0.4).timeout
	_hud.show_result(event.winner, WIN_REASONS[event.reason], _stats_text())


func _play_drawn(event: GameDrawnEvent) -> void:
	await get_tree().create_timer(0.4).timeout
	_hud.show_draw(DRAW_REASONS[event.reason], _stats_text())


## 決着の画面に出す戦績の要点。
func _stats_text() -> String:
	var names: Array[String] = []
	for side: Unit.Side in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
		names.append(_side_name(side))
	return StatsText.text(stats, MatchSetup.stage_name(stage), names)


func _play_defeated(event: UnitDefeatedEvent) -> void:
	var view := _view(event.unit_id)
	_views.erase(event.unit_id)
	await view.play_death()


## 中ボスが倒れた（駒が消えるのは UnitDefeatedEvent が見せた）。倒した陣営を、その色で知らせる。
func _play_mid_boss_defeated(event: MidBossDefeatedEvent) -> void:
	var at := BoardView.cell_center(event.cell)
	# 中ボスは左右（中央平原・迷宮回廊）か上下（双子結晶）に 1 体ずつ。番号 0 が左か上。
	var cells := battle.board.mid_boss_cells
	var stacked := cells.size() == 2 and absi(cells[0].y - cells[1].y) > absi(cells[0].x - cells[1].x)
	var side := ("上" if stacked else "左") if event.boss_index == 0 else ("下" if stacked else "右")
	if event.slayer_side < 0:
		_pop_number(at, "%sの中ボスが倒れた" % side)
		return
	var color: Color = TEAM_COLORS[event.slayer_side]
	_flash(at + Vector3(0.0, 0.6, 0.0), color, 2.4)
	_pop_number(at, "%s が%sの中ボスを倒した" % [_side_name(event.slayer_side as Unit.Side), side], color.lightened(0.4))
	await get_tree().create_timer(0.6).timeout


## 陣営が聖遺物を受け取った。控えめに見せる: 上の帯に聖遺物の名前を出し、効果の掛かった駒の HP のバーを描き直し、
## 駒の上に小さい光と、効果（最大 HP +N など）を出す。画面を覆う演出はしない。
func _play_relic_gained(event: RelicGainedEvent) -> void:
	_refresh_status(battle.turn, battle.phase)
	var color: Color = TEAM_COLORS[event.side]
	var text := Relics.summary(event.relic).trim_prefix("軍の全員の")
	for unit_id in event.unit_ids:
		if not _views.has(unit_id):
			continue
		var view := _view(unit_id)
		view.set_max_hp(event.max_hp[unit_id])
		view.set_hp(event.hp[unit_id])
		_flash(view.position + Vector3(0.0, 0.5, 0.0), COLOR_RELIC, 1.0)
		_pop_number(view.position + Vector3(0.0, 0.5, 0.0), text, COLOR_RELIC)
	_hud.show_banner("%s　%s を手に入れた（%s）" % [_side_name(event.side), Relics.display_name(event.relic), Relics.summary(event.relic)], color)
	await get_tree().create_timer(0.7).timeout


## 中立の駒が結晶泉に湧いた（中ボスが現れた）。光とともに、小さい形から大きくする。
func _play_spawned(event: UnitSpawnedEvent) -> void:
	var at := BoardView.cell_center(event.cell)
	var view: UnitView = UnitView.new()
	view.position = at
	add_child(view)
	view.setup(event.kind, TEAM_COLORS[event.side], event.hp, event.max_hp)
	view.face(BoardView.cell_center(event.cell + Vector2i.DOWN) - at)
	_views[event.unit_id] = view
	if not _quiet_playback:
		_rig.focus_on(at)
	_flash(at + Vector3(0.0, 0.4, 0.0), TEAM_COLORS[event.side], 1.6)
	view.scale = Vector3.ONE * 0.05
	var grow := create_tween()
	grow.tween_property(view, "scale", Vector3.ONE, 0.3)
	await grow.finished


## 駒が歩く間、カメラが追いかけるか。自分で動かしていない駒（CPU の番の駒、中立の駒）だけ。
## 中立のフェーズの静かな場面をまとめて流している間は、追わない（何体も同時に動く）。
func _camera_follows(unit: Unit) -> bool:
	if unit == null or _quiet_playback:
		return false
	return unit.side == Unit.Side.NEUTRAL or (_cpu_running and unit.side == match_choice.cpu_side())


## 自分で動かしていない駒（CPU の番の駒、中立の駒）の攻撃は、攻撃する駒と相手の間へカメラを寄せる（どちらも見えるように）。
func _show_strike(attacker_id: int, attacker: UnitView, target: UnitView) -> void:
	var unit := battle.unit_by_id(attacker_id)
	if unit != null and (unit.side == Unit.Side.NEUTRAL or (_cpu_running and unit.side == match_choice.cpu_side())):
		_rig.focus_on((attacker.position + target.position) / 2.0)


func _play_phase_started(event: PhaseStartedEvent) -> void:
	_refresh_status(event.turn, event.side)
	if event.side == Unit.Side.NEUTRAL:
		# 中立の駒は行動済みを持たないので、明るさは変えない。カメラは、攻撃する駒だけを追う（_play_neutral_phase）。
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
	if _cpu_running or not battle.can_apply(UseUltAction.new()):
		_confirming_ult = false
	var unit := selected_unit()
	if unit == null:
		_selected_id = 0
	_move_cells = Queries.move_cells(battle, unit)
	_targets = Queries.attack_targets(battle, unit)
	_barrel_targets = Queries.barrel_targets(battle, unit)
	_barricade_targets = Queries.barricade_targets(battle, unit)
	_heal_targets = Queries.heal_targets(battle, unit)
	_skill_cells = Queries.skill_cells(battle, unit)
	var cpu_turn := _cpu_running or _is_cpu_turn()
	if unit == null or battle.is_over() or cpu_turn or not battle.can_act(unit):
		_mode = Mode.NONE
	elif _mode == Mode.SKILL and _skill_cells.is_empty():
		_mode = Mode.NONE
	elif _mode == Mode.ATTACK and not _can_attack():
		_mode = Mode.NONE
	elif _mode == Mode.HEAL and _heal_targets.is_empty():
		_mode = Mode.NONE
	if unit != null:
		_inspected_cell = NO_CELL

	_painted = {}
	if unit != null and not battle.is_over():
		if _mode == Mode.SKILL:
			for cell in _skill_cells:
				_painted[cell] = COLOR_SKILL
		elif battle.can_act(unit):
			if _mode == Mode.NONE:
				for cell: Vector2i in _move_cells:
					_painted[cell] = COLOR_CRUISE if _move_cells[cell] else COLOR_MOVE
			if _mode != Mode.HEAL:
				for target in _targets:
					_painted[target.cell] = COLOR_TARGET
				for cell in _barrel_targets:
					_painted[cell] = COLOR_TARGET
				for cell in _barricade_targets:
					_painted[cell] = COLOR_TARGET
			if _mode != Mode.ATTACK:
				for target in _heal_targets:
					_painted[target.cell] = COLOR_HEAL
		else:
			# 相手の駒（中立も）は、次の番に攻撃・スキルが届くマス（脅威範囲）を赤で。その上に移動範囲を白で。
			if unit.side != battle.phase:
				for cell in Queries.threat_cells(battle, unit):
					_painted[cell] = COLOR_THREAT
			for cell in Queries.inspect_cells(battle, unit):
				_painted[cell] = COLOR_INSPECT
	_show_painted()

	_selection_ring.visible = unit != null
	if unit != null:
		_selection_ring.position = BoardView.cell_center(unit.cell) + Vector3(0.0, 0.04, 0.0)

	_board_view.set_marked(_inspected_cell)
	# 状態（バリア、照準など）が付いている駒は、足元の輪で分かるようにする。
	for shown in battle.units:
		if _views.has(shown.id):
			_view(shown.id).set_status_mark(not Statuses.types_of(shown).is_empty())
	_refresh_status(battle.turn, battle.phase)
	_refresh_hint(unit)
	var evolving := battle.evolving_unit()
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
		var can_end := not battle.is_over() and evolving == null
		_hud.set_end_turn(can_end, "ターン終了", can_end and unacted == 0)
	_hud.set_menu(_menu_items(unit) if not cpu_turn and evolving == null else [])
	_menu_dirty = true
	_hud.set_ult_button(
		_ult_button_text(), not cpu_turn and battle.can_apply(UseUltAction.new()), _ult_summary(), _confirming_ult
	)
	_update_info()


## 選んでいる駒が、いまの位置から攻撃できるもの（相手・樽・盾）があるか。
func _can_attack() -> bool:
	return not (_targets.is_empty() and _barrel_targets.is_empty() and _barricade_targets.is_empty())


## 駒のそばのメニューに出す項目（[名前, 文字, 押せるか] の列）。いま選べるものだけを並べる。
## スキルは、持っている駒なら、使えない間も理由を添えて出す（押せない）。行動できない駒では空。
func _menu_items(unit: Unit) -> Array:
	var items: Array = []
	if unit == null or battle.is_over() or not battle.can_act(unit):
		return items
	if _mode != Mode.NONE:
		return [[MENU_BACK, "やめる", true]]
	if _can_attack():
		items.append([MENU_ATTACK, "攻撃", true])
	if not _heal_targets.is_empty():
		items.append([MENU_HEAL, "回復", true])
	if Skills.of(unit) != null:
		items.append([MENU_SKILL, _skill_button_text(unit), not _skill_cells.is_empty()])
	items.append([MENU_WAIT, "待機", true])
	if battle.options(unit.id).can_undo:
		items.append([MENU_UNDO, "移動を取り消す", true])
	return items


## メニューを、選んでいる駒のそばに置く。駒の位置を画面に投影し、攻撃の相手・届くマス・ほかの駒・情報の枠を
## 隠さない側を選ぶ（menu_placement.gd）。カメラが動いたら置き直すので、回しても動かしても付いてくる。
func _place_menu() -> void:
	var size := _hud.menu_size()
	var unit := selected_unit()
	if size == Vector2.ZERO or unit == null or not _views.has(unit.id):
		return
	var camera: Camera3D = _rig.camera
	if not _menu_dirty and camera.global_transform.is_equal_approx(_menu_camera):
		return
	_menu_dirty = false
	_menu_camera = camera.global_transform
	var view := _view(unit.id)
	var anchor := _screen_rect(view.position, 0.45, view.height())
	var obstacles: Array = []
	for cell: Vector2i in _painted:
		var color: Color = _painted[cell]
		var weight := MENU_WEIGHT_TARGET
		if color == COLOR_MOVE:
			weight = MENU_WEIGHT_MOVE
		elif color == COLOR_CRUISE:
			weight = MENU_WEIGHT_CRUISE
		if cell != unit.cell:
			obstacles.append([_screen_rect(BoardView.cell_center(cell), 0.4, 0.0), weight])
	for other_id: int in _views:
		if other_id != unit.id:
			var other := _view(other_id)
			obstacles.append([_screen_rect(other.position, 0.35, other.height()), MENU_WEIGHT_UNIT])
	if _hud.info_rect().has_area():
		obstacles.append([_hud.info_rect(), MENU_WEIGHT_PANEL])
	_hud.place_menu(_menu_placement.place(anchor, size, _hud.menu_area(), obstacles), anchor.get_center())


## 盤面の上の、at を中心に半径 radius・高さ height の柱が、画面に占める四角。カメラの後ろなら、画面の外の四角。
func _screen_rect(at: Vector3, radius: float, height: float) -> Rect2:
	var camera: Camera3D = _rig.camera
	if camera.is_position_behind(at):
		return Rect2(-10000.0, -10000.0, 1.0, 1.0)
	var rect := Rect2(camera.unproject_position(at), Vector2.ZERO)
	var right := camera.global_transform.basis.x
	var forward := right.cross(Vector3.UP)
	for corner: Vector3 in [right, -right, forward, -forward]:
		rect = rect.expand(camera.unproject_position(at + corner * radius))
		if height > 0.0:
			rect = rect.expand(camera.unproject_position(at + corner * radius + Vector3.UP * height))
	return rect


## 必殺技のボタンが、どのプレイヤーのものか。CPU と対戦するときは、いつも人のプレイヤー（CPU の番の間も）。
## 人どうしでは、いまの番のプレイヤー（中立の番では、プレイヤー1）。
func _ult_side() -> Unit.Side:
	if cpu_opponent:
		return match_choice.human_side
	if battle.phase == Unit.Side.NEUTRAL:
		return Unit.Side.PLAYER1
	return battle.phase


## 必殺技のボタンの上に出す説明。
func _ult_summary() -> String:
	var ult := Ults.of(battle, _ult_side())
	return ult.summary() if ult != null else ""


## 必殺技のボタンの文字。
func _ult_button_text() -> String:
	var side := _ult_side()
	var ult := Ults.of(battle, side)
	if ult == null:
		return "必殺技（なし）"
	if _confirming_ult:
		return "もう一度押すと %s 発動" % ult.display_name()
	if Ults.is_ready(battle, side):
		return "必殺技: %s（使える）" % ult.display_name()
	return "必殺技: %s（%d%%）" % [ult.display_name(), Ults.percent(battle, side)]


## 選べる対象が自分のマスだけのスキル（自分に使うスキル）を、選んでいるか。
func _is_self_skill(unit: Unit) -> bool:
	return unit != null and _skill_cells.size() == 1 and _skill_cells[0] == unit.cell


## メニューのスキルの項目の文字。使えるならスキルの名前（回数に上限があれば残りも）、使えないなら理由。
func _skill_button_text(unit: Unit) -> String:
	var skill := Skills.of(unit)
	if skill == null:
		return ""
	if unit.skill_cooldown > 0:
		return "スキル（あと %d ターン）" % unit.skill_cooldown
	var uses := Skills.uses_left(unit)
	if uses == 0:
		return "スキル（使い切った）"
	if _skill_cells.is_empty():
		return "スキル（いまは使えない）"
	if uses > 0:
		return "%s（あと %d 回）" % [skill.display_name(), uses]
	return skill.display_name()


func _refresh_status(turn: int, phase: Unit.Side) -> void:
	var counts: Array[int] = [
		Queries.unit_count(battle, Unit.Side.PLAYER1), Queries.unit_count(battle, Unit.Side.PLAYER2),
	]
	var relics: Array[String] = []
	var relic_notes: Array[String] = []
	for side: Unit.Side in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
		var names: Array[String] = []
		var notes: Array[String] = []
		for relic in Relics.held(battle, side):
			names.append(Relics.display_name(relic).trim_suffix("の聖遺物"))
			notes.append("%s: %s" % [Relics.display_name(relic), Relics.summary(relic)])
		relics.append("・".join(names))
		relic_notes.append("
".join(notes))
	_hud.set_relics(relics, relic_notes)
	_hud.set_status(turn, phase, counts, battle.capture_turns, Battle.CAPTURE_TURNS_TO_WIN)
	var percents: Array[int] = []
	var names: Array[String] = []
	for side: Unit.Side in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
		var ult := Ults.of(battle, side)
		percents.append(Ults.percent(battle, side))
		names.append(ult.display_name() if ult != null else "")
	_hud.set_ult_gauges(percents, names)


## 下の帯の、いまできることの説明。クリックだけで進められる言い方で、短く書く。
func _refresh_hint(unit: Unit) -> void:
	if battle.is_over():
		_hud.set_hint("決着")
	elif _cpu_running or _is_cpu_turn():
		_hud.set_hint("相手（CPU）の番")
	elif battle.evolving_unit() != null:
		_hud.set_hint("進化先を選ぶ（上のボタン）")
	elif _confirming_ult:
		_hud.set_hint("もう一度押すと必殺技を使う（取り消せない）。右クリックか、盤面のクリックでやめる")
	elif unit == null:
		_hud.set_hint("駒をクリックして選ぶ。相手の駒をクリックすると、動ける範囲と攻撃の届く範囲が見える")
	elif _mode == Mode.SKILL and _is_self_skill(unit):
		_hud.set_hint("%s: この駒（紫のマス）をクリックで使う。右クリックでやめる" % Skills.of(unit).display_name())
	elif _mode == Mode.SKILL:
		var after := "使うと行動を終える" if Skills.of(unit).ends_action() else "使ったあと、続けて攻撃できる"
		_hud.set_hint("%s: 紫のマスをクリックで使う（%s）。右クリックでやめる" % [Skills.of(unit).display_name(), after])
	elif _mode == Mode.ATTACK:
		_hud.set_hint("攻撃: 赤いマスの相手をクリック。右クリックでやめる")
	elif _mode == Mode.HEAL:
		_hud.set_hint("回復: 緑のマスの味方をクリック。右クリックでやめる")
	elif not battle.can_act(unit):
		if unit.side != battle.phase:
			_hud.set_hint("相手の駒。白: 動ける範囲　赤: 次の番に攻撃が届く範囲")
		else:
			_hud.set_hint("この駒は行動を終えている（白: 動ける範囲）")
	elif unit.move_locked:
		_hud.set_hint("スキルを使った。駒のそばのメニューから、攻撃か待機を選ぶ（取り消せない）")
	elif unit.has_moved:
		if unit.cruised:
			_hud.set_hint("巡航で動いたので、攻撃はできない。駒のそばのメニューから、待機か取り消しを選ぶ")
		else:
			_hud.set_hint("駒のそばのメニューから行動を選ぶ。右クリックで移動を取り消す")
	elif UnitKind.role(unit.kind) == UnitKind.Role.HEALER:
		_hud.set_hint("青: 移動　黄: 巡航（遠くへ動けるが、回復できない）　緑: 回復できる味方\nマスをクリックで移動。行動は駒のそばのメニューから")
	else:
		_hud.set_hint("青: 移動　黄: 巡航（遠くへ動けるが、攻撃できない）　赤: 攻撃できる相手\nマスをクリックで移動。行動は駒のそばのメニューから")


## 塗ったマスに、マウスの下のマスまでの道か、マウスの下の樽の爆発が届くマスを重ねて出す。
func _show_painted() -> void:
	var colors := _painted
	var unit := selected_unit()
	if unit != null and not _busy and _mode == Mode.SKILL:
		if _skill_cells.has(_hover_cell):
			colors = _painted.duplicate()
			for cell in Skills.of(unit).affected_cells(battle, unit, _hover_cell):
				colors[cell] = COLOR_SKILL_AREA
	elif unit != null and not _busy and _barrel_targets.has(_hover_cell):
		colors = _painted.duplicate()
		for cell in MapObject.blast_cells(battle.board, _hover_cell):
			colors[cell] = COLOR_BLAST
	elif unit != null and not _busy and _mode == Mode.NONE and _move_cells.has(_hover_cell):
		colors = _painted.duplicate()
		for cell in Movement.path_to(battle, unit, _hover_cell, _move_cells[_hover_cell]):
			if cell != unit.cell:
				colors[cell] = COLOR_PATH
	# 駒のいるマスの、攻撃・回復・スキルの対象の色は、駒の足元の円盤に隠れないよう、その上に塗る。
	var raised := {}
	for cell: Vector2i in colors:
		if colors[cell] in [COLOR_TARGET, COLOR_HEAL, COLOR_SKILL, COLOR_SKILL_AREA] and battle.unit_at(cell) != null:
			raised[cell] = true
	_board_view.show_cells(colors, raised)


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


## マウスの下の駒（いなければ選んでいる駒。それも無ければ、クリックしたマス）の情報を左下の枠に、
## マウスの下のマスの短い説明を下の帯に出す。
func _update_info() -> void:
	var hovered: Unit = null
	if _hover_cell != NO_CELL:
		hovered = battle.unit_at(_hover_cell)
	_hud.show_cell(_cell_line(_hover_cell) if _hover_cell != NO_CELL else "")

	var shown := hovered if hovered != null else selected_unit()
	if shown == null:
		if _inspected_cell != NO_CELL:
			_hud.show_cell_info(_cell_title(_inspected_cell), _cell_body(_inspected_cell))
		else:
			_hud.show_unit(null, "", "")
		return
	if _mode == Mode.SKILL:
		# スキルの対象を選んでいる間は、使う駒と、マウスの下のマスに使ったときの見込みを出す。
		var user := selected_unit()
		var skill := Skills.of(user)
		var skill_text := skill.summary()
		# 自分に使うスキルは、対象が 1 つなので、マウスを乗せなくても見込みを出す。
		if _is_self_skill(user):
			skill_text += "\n" + _skill_forecast(user, user.cell)
		elif _skill_cells.has(_hover_cell):
			skill_text += "\n" + _skill_forecast(user, _hover_cell)
		_hud.show_unit(user, "%s の対象を選んでいる" % skill.display_name(), skill_text, false)
		return
	if _menu_hover_id != &"" and selected_unit() != null and _hud.menu_ids().has(_menu_hover_id):
		# メニューの項目にマウスを乗せている間は、その項目を押すと何が起きるかを出す。
		_hud.show_unit(selected_unit(), "", _menu_note(_menu_hover_id, selected_unit()), _menu_hover_id != MENU_SKILL)
		return
	if hovered == null and _barrel_targets.has(_hover_cell) and _mode != Mode.HEAL:
		var barrel := Forecast.of(battle, AttackBarrelAction.new(shown.id, _hover_cell))
		_hud.show_unit(shown, "樽を狙っている", "樽を爆発させる（%d ダメージ）\n%s" % [MapObject.BLAST_DAMAGE, ForecastText.describe(battle, barrel, shown)])
		return
	if hovered == null and _barricade_targets.has(_hover_cell) and _mode != Mode.HEAL:
		var barricade := Forecast.of(battle, AttackBarricadeAction.new(shown.id, _hover_cell))
		_hud.show_unit(shown, "盾を狙っている", ForecastText.describe(battle, barricade, shown))
		return
	var state := "行動済み" if shown.acted else "未行動"
	if shown.side == Unit.Side.NEUTRAL:
		state = ""
	if shown.has_moved:
		state = "行動の途中（巡航で移動した）" if shown.cruised else "行動の途中（移動した）"
	if shown.move_locked:
		state = "行動の途中（スキルを使った）"
	# 駒のいるマスの地形（森にいれば、受けるダメージが減る）。平地は書かない。
	if battle.board.terrain_at(shown.cell) != Terrain.Type.NORMAL:
		state += ("\n" if state != "" else "") + "いるマス: " + BattleHud.TERRAIN_NAMES[battle.board.terrain_at(shown.cell)]
	var forecast := ""
	var attacker := selected_unit()
	# 攻撃・回復の見込み。実際と同じ処理を、状態を変えずに走らせる（Forecast）。
	if hovered != null and _targets.has(hovered) and _mode != Mode.HEAL:
		forecast = ForecastText.describe(battle, Forecast.of(battle, AttackAction.new(attacker.id, hovered.id)), attacker)
	elif hovered != null and _heal_targets.has(hovered) and _mode != Mode.ATTACK:
		forecast = ForecastText.describe(battle, Forecast.of(battle, HealAction.new(attacker.id, hovered.id)), attacker)
	_hud.show_unit(shown, state, forecast)


## マスの見出し（位置と地形の名前）。
func _cell_title(cell: Vector2i) -> String:
	var terrain: String = BattleHud.TERRAIN_NAMES[battle.board.terrain_at(cell)]
	return "マス (%d, %d)　%s" % [cell.x, cell.y, terrain.get_slice("（", 0)]


## マスの説明を、左下の枠に出す形にしたもの。「名前（説明。説明）」を、名前の行と、字下げした説明の行に分ける。
func _cell_body(cell: Vector2i) -> String:
	var lines: Array[String] = []
	for note in _cell_notes(cell):
		if not note.ends_with("）") or not note.contains("（"):
			lines.append(note)
			continue
		lines.append(note.get_slice("（", 0))
		for part in note.substr(note.find("（") + 1).trim_suffix("）").split("。", false):
			lines.append("　" + part.strip_edges())
	return "\n".join(lines)


## マスの説明（行ごと）: 地形の効果、本陣、盤の上の効果、環境オブジェクト。
func _cell_notes(cell: Vector2i) -> Array[String]:
	var notes: Array[String] = []
	var terrain: String = BattleHud.TERRAIN_NAMES[battle.board.terrain_at(cell)]
	if terrain.contains("（"):
		notes.append(terrain.get_slice("（", 1).trim_suffix("）"))
	var hq_owner := battle.board.hq_owner(cell)
	if hq_owner >= 0:
		notes.append("%s の本陣" % BattleHud.SIDE_NAMES[hq_owner])
	for effect in battle.board.field_effects_at(cell):
		notes.append(BattleHud.field_effect_text(effect))
	var type := battle.board.object_at(cell)
	if type != MapObject.Type.NONE:
		var text: String = BattleHud.OBJECT_NAMES[type]
		if type == MapObject.Type.PORTAL:
			var exit := battle.board.portal_exit(cell)
			text += " → (%d, %d)" % [exit.x, exit.y]
			if battle.portal_exit(cell) == Board.NO_CELL:
				text += "（行き先に駒がいて、いまは使えない）"
		notes.append(text)
	if notes.is_empty():
		notes.append(NOTHING_SPECIAL)
	return notes


## マスの説明を 1 行にしたもの（下の帯。マウスの下のマス）。
func _cell_line(cell: Vector2i) -> String:
	var notes := _cell_notes(cell)
	var title := _cell_title(cell)
	return title if notes[0] == NOTHING_SPECIAL else "%s　%s" % [title, "　".join(notes)]


## スキルを target に使ったときの見込み（戦闘予測。Forecast）。
func _skill_forecast(user: Unit, target: Vector2i) -> String:
	return ForecastText.describe(battle, Forecast.of(battle, UseSkillAction.new(user.id, target)), user)


func _cell_under_mouse() -> Vector2i:
	return _cell_at(get_viewport().get_mouse_position())


## 画面の at（px）の下にあるマス。盤の外へ外れることもある。
func _cell_at(at: Vector2) -> Vector2i:
	var camera: Camera3D = _rig.camera
	var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(camera.project_ray_origin(at), camera.project_ray_normal(at))
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
