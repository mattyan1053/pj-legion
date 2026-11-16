extends Node3D
## 対戦の場面（俯瞰 3D の盤面と、操作・演出）。ルール（rules/）につないで、1 人で CPU と、または 2 人が 1 台で交代しながら対戦する。
## 場面の決まり（context、finished、システムメニューの項目）は scene_flow.gd。
## 対戦は、渡された「対戦の設定を作ってくれるもの」（battle_source.gd。流れ（run.gd）が渡す。無ければ context.match_choice）から作る。
## どのモードの対戦かは知らない。やり直し・ステージの替え・相手の切り替え・対戦の設定のパネルは、それに聞いてから出す。
##
## 相手（プレイヤー2）を CPU にすると、その番は CpuPlayer が返す行動を、人の操作と同じ入口（_do）に 1 つずつ流す。
## ここはルールを持たない。操作を行動（BattleAction）にして Battle.apply() に渡し、
## 返ってきたイベントを順に再生するだけ。選べることはルールの問い合わせ（Battle.options）で出す。
## 盤面・駒・ライト・カメラ・文字はすべてコードで組み立てる。

const OrbitCamera := preload("res://game/orbit_camera.gd")
const UnitView := preload("res://game/unit_view.gd")
const BoardView := preload("res://game/board_view.gd")
const BattleHud := preload("res://game/battle_hud.gd")
const Names := preload("res://game/names.gd")
const BattleSource := preload("res://game/battle_source.gd")
const MatchSetupPanel := preload("res://game/match_setup_panel.gd")
const Queries := preload("res://game/battle_queries.gd")
const ForecastText := preload("res://game/forecast_text.gd")
const Autoplay := preload("res://game/autoplay.gd")
const ResultSummary := preload("res://game/result_summary.gd")
const PhaseFocus := preload("res://game/phase_focus.gd")
const SystemMenu := preload("res://game/system_menu.gd")
const Settings := preload("res://game/settings.gd")
const AppContext := preload("res://game/app_context.gd")
const BattleLog := preload("res://game/battle_log.gd")
const LogPanel := preload("res://game/log_panel.gd")
const BattleUiState := preload("res://game/battle_ui_state.gd")
const BattleTexts := preload("res://game/battle_texts.gd")
const BattlePlayback := preload("res://game/battle_playback.gd")
const PanelLayout := preload("res://game/panel_layout.gd")
const BattleEffects := preload("res://game/battle_effects.gd")
const StageLook := preload("res://game/stage_look.gd")
const Run := preload("res://game/run.gd")
const WinText := preload("res://game/win_text.gd")
const BattleCues := preload("res://game/battle_cues.gd")
const BattleTalk := preload("res://game/battle_talk.gd")
const VersusFields := preload("res://game/versus_fields.gd")

## 場面が終わった（scene_flow.gd の行き先の名前: 決着の画面の「対戦の設定へ」は &"setup"、「タイトルへ」は &"title"。
## 「次へ」（渡されたものが許したときだけ出る。ストーリー）は Run.NEXT）。
signal finished(outcome: StringName)

const NO_CELL := Vector2i(-1, -1)
const TEAM_COLORS: Array[Color] = [Color("3a7bd5"), Color("d64545"), Color("e0b83a")]

const COLOR_MOVE := Color(0.35, 0.65, 1.0, 0.5)
const COLOR_CRUISE := Color(1.0, 0.82, 0.3, 0.4)
const COLOR_PATH := Color(1.0, 1.0, 1.0, 0.75)
const COLOR_TARGET := Color(1.0, 0.2, 0.15, 0.7)
const COLOR_HEAL := Color(0.3, 0.95, 0.45, 0.7)
const COLOR_SKILL := Color(0.55, 0.25, 0.95, 0.7)
const COLOR_SKILL_AREA := Color(1.0, 0.55, 0.9, 0.85)
const COLOR_INSPECT := Color(0.8, 0.93, 1.0, 0.5)
## ターン終了を確かめている間の、まだ行動していない駒の足元。
const COLOR_UNACTED := Color(1.0, 0.85, 0.35, 0.6)
const COLOR_THREAT := Color(0.95, 0.05, 0.2, 0.62)
const COLOR_SELECTED := Color(1.0, 0.9, 0.3, 0.9)
## 見ている（閲覧している）駒の足元の輪。選んでいる駒の黄の輪と見分ける。
const COLOR_INSPECTED := Color(0.85, 0.95, 1.0, 0.95)
## ログの行を選んだときに示す、出来事のあったマスと、関わった駒のいまのマス。
const COLOR_LOG_PLACE := Color(1.0, 0.82, 0.25, 0.75)
const COLOR_LOG_UNIT := Color(0.95, 0.97, 1.0, 0.7)

## 駒のそばのメニューの項目の名前（battle_texts.gd）。
const MENU_ATTACK := BattleTexts.MENU_ATTACK
const MENU_HEAL := BattleTexts.MENU_HEAL
const MENU_SKILL := BattleTexts.MENU_SKILL
const MENU_WAIT := BattleTexts.MENU_WAIT
const MENU_UNDO := BattleTexts.MENU_UNDO
const MENU_BACK := BattleTexts.MENU_BACK

## 対象を選んでいる途中か（battle_ui_state.gd）。
const Mode := BattleUiState.Mode

## CPU の駒が動き出す前に、カメラを寄せて見せる秒数と、1 体の行動が終わってから次の駒までの間。
const CPU_FOCUS_TIME := 0.35
const CPU_PAUSE := 0.45

## いまの対戦。再生（battle_playback.gd）にも渡す。
var battle: Battle:
	set(value):
		battle = value
		if _playback != null:
			_playback.battle = value
## フェーズの始めにカメラが寄る駒を決める（phase_focus.gd）。行動のたびに、起きたことを食わせる。
var _phase_focus := PhaseFocus.new()
## いまの対戦の戦績。行動のたびに、起きたことを食わせる（決着の画面に要点を出す）。
var stats: BattleStats
## 対戦のログ（battle_log.gd）。再生（battle_playback.gd）が、再生したイベントを、再生した順に食わせる。
var battle_log: BattleLog:
	set(value):
		battle_log = value
		if _playback != null:
			_playback.battle_log = value
## いまの盤の見た目の名前（stage_look.gd）と、決着の画面の「作戦領域」に出す名前（戦いの定義の名前）。
var look := StageLook.DEFAULT
var area_name := ""
var map_seed := 0

var _board_view: BoardView
var _effects: BattleEffects
var _views := {}  # 駒の番号 -> UnitView
var _hud: BattleHud
var _setup_panel: MatchSetupPanel
var _rig: OrbitCamera
var _selection_ring: MeshInstance3D
var _inspect_ring: MeshInstance3D

## システムメニューに足す項目の名前。
const SYSTEM_MATCH_SETUP := &"match_setup"

## アプリ（app.gd）から渡されるもの。場面を作ってから木に入れる前に入る。
var context: AppContext
## 遊ぶ人ごとの設定（settings.gd。context が持つ）。
var settings: Settings
## ふだんの時間の速さ（Engine.time_scale）。自動の対戦は、検査を短く済ませるために上げる。
## システムメニューを開いている間は 0（止める）、CPU の駒の番は設定の「CPU の番の速さ」を掛ける（_update_time_scale）。
var time_scale_base := 1.0
var _system_menu: SystemMenu
var _log_panel: LogPanel
## CPU の駒の行動を再生している途中か（設定の「CPU の番の速さ」を効かせる）。
var _cpu_fast := false

## 対戦の設定を作ってくれるもの（battle_source.gd）。やり直し（F1〜F3、結果のボタン）も、これで始める。
var source: BattleSource
## 相手を CPU が動かすか。偽なら、2 人が交代で操作する。CPU が動かすのは source.cpu_side()。
## 対戦を作るときに、対戦の設定（MatchSetup.controllers）から決める。対戦の途中の切り替え（F4）で変わる。
var cpu_opponent := true
## CPU が実行した行動の数。検査用。
var cpu_actions := 0
var _cpu := CpuPlayer.new()
## 操作の状態（選んでいる駒、見ている駒、対象を選ぶ途中、確かめ、押している途中、再生と CPU の番の途中）。battle_ui_state.gd。
var _ui := BattleUiState.new()
## 対戦の途中の会話（battle_cues.gd）と、その札（battle_talk.gd）。台詞は渡すもの（source.talk_cues）が持つ。
var _cues: BattleCues
var _talk: BattleTalk
## 敵の全員の脅威範囲（Threat.against）を、盤に重ねて出しているか（下の帯の切り替え）。
var _threat_shown := false
var _hover_cell := NO_CELL
## いまの選択で選べること（_refresh が作り直す）。
var _move_cells := {}  # マス -> 巡航でしか届かないか
var _targets: Array[Unit] = []
var _barrel_targets: Array[Vector2i] = []
var _barricade_targets: Array[Vector2i] = []
var _heal_targets: Array[Unit] = []
var _skill_cells: Array[Vector2i] = []
## 駒のそばのメニューと、戦闘予測のパネルの置き場所（panel_layout.gd）。
var _layout: PanelLayout
## 検査で、マウスを乗せたことにしているマス（hover）。NO_CELL ならマウスの位置。
var _hover_forced := NO_CELL
## 対戦を始めたことがあるか（起動した直後の設定画面だけ偽。偽の間は、設定画面を閉じて戻る先が無い）。
var _battle_started := false
## カメラが追いかけた駒の番号 -> 回数。検査用。
var camera_follows := {}
## 再生したイベントの数（イベントのスクリプト -> 回数）。検査用。
var played := {}
## イベントの再生（battle_playback.gd）。
var _playback: BattlePlayback
var _painted := {}  # 塗っているマス -> Color（道の表示を重ねる前のもの）


func _ready() -> void:
	if context == null:
		context = AppContext.new()  # アプリを通さずに置いたとき（既定の設定で始める）
	StageLook.build_environment(self)
	_rig = OrbitCamera.new()
	add_child(_rig)
	_effects = BattleEffects.new()
	_effects.play_sound = func(name: StringName) -> void: context.play_sound(name)
	add_child(_effects)
	_selection_ring = _build_ring(COLOR_SELECTED, 0.38, 0.47)
	_inspect_ring = _build_ring(COLOR_INSPECTED, 0.40, 0.50)
	_hud = BattleHud.new()
	add_child(_hud)
	_hud.setup(TEAM_COLORS)
	_playback = BattlePlayback.new()
	add_child(_playback)
	_playback.setup(self, _views, _rig, _hud, _effects, _ui, TEAM_COLORS, played, camera_follows)
	_playback.refresh_status = _refresh_status
	_playback.side_name = _side_name
	_playback.result_summary = _result_summary
	_playback.camera_point = _camera_point
	_playback.cpu_side = func() -> Unit.Side: return source.cpu_side()
	_playback.play_sound = func(name: StringName) -> void: context.play_sound(name)
	_playback.frame_passed = frame_passed
	_layout = PanelLayout.new(_rig, _hud, _views, COLOR_MOVE, COLOR_CRUISE)
	_hud.menu_pressed.connect(_on_menu_pressed)
	_hud.menu_hovered.connect(_on_menu_hovered)
	_hud.ult_pressed.connect(press_ult)
	_hud.end_turn_pressed.connect(press_end_turn)
	_hud.restart_pressed.connect(_on_restart_pressed)
	_hud.evolution_chosen.connect(choose_evolution)
	_hud.opponent_pressed.connect(toggle_opponent)
	_hud.threat_toggled.connect(toggle_threat)
	_hud.log_pressed.connect(open_log)
	_hud.setup_pressed.connect(func() -> void: finished.emit(&"setup"))
	_hud.title_pressed.connect(func() -> void: finished.emit(&"title"))
	_hud.result_screen().continue_pressed.connect(func() -> void: finished.emit(Run.NEXT))
	_hud.result_screen().squad_pressed.connect(func() -> void: finished.emit(Run.PREVIOUS))
	_hud.result_shown.connect(_on_result_shown)
	_hud.minimap().pointed.connect(_on_minimap_pointed)
	_hud.result_screen().overlays = context.overlays
	_hud.result_screen().play_sound = func(name: StringName) -> void: context.play_sound(name)
	_talk = BattleTalk.new()
	_hud.add_talk_card(_talk)
	_setup_panel = MatchSetupPanel.new()
	_hud.add_child(_setup_panel)
	_setup_panel.setup(TEAM_COLORS, context.decks, context.overlays)
	_setup_panel.visible = false
	_setup_panel.start_pressed.connect(_on_setup_chosen)
	_setup_panel.cancelled.connect(_refresh)
	_setup_panel.stage_pressed.connect(func(choice: RefCounted) -> void:
		context.match_choice = choice
		finished.emit(&"stage"))
	_log_panel = LogPanel.new()
	add_child(_log_panel)
	_log_panel.setup(TEAM_COLORS, context.overlays)
	_log_panel.opened.connect(_on_overlay_opened)
	_log_panel.closed.connect(_on_log_closed)
	_log_panel.entry_chosen.connect(_on_log_entry_chosen)
	_log_panel.opened.connect(func() -> void: context.play_sound(&"menu_open"))
	_log_panel.closed.connect(func() -> void: context.play_sound(&"menu_close"))

	settings = context.settings
	settings.changed.connect(_on_setting_changed)
	_apply_settings()
	_system_menu = context.system_menu
	_system_menu.opened.connect(_on_system_menu_opened)
	_system_menu.closed.connect(_on_system_menu_closed)

	# 流れが渡すもの。流れの外から置かれた（スクリーンショットの道具など）なら、対戦の設定の場面で選んだもの。
	var given: Variant = context.run_data()
	source = given if given != null else context.match_choice.copy()
	_battle_started = true
	# 検査では毎回同じ対戦にする。遊ぶときは毎回違う盤面にする（context.battle_seed）。
	start_battle(context.battle_seed())
	if context.checking == AppContext.CHECK_AUTOPLAY and not is_instance_valid(context.autoplay):
		context.autoplay = Autoplay.new(self)
		add_child(context.autoplay)


func _exit_tree() -> void:
	# メニューで止めた時間や、CPU の番の速さを、ほかの場面へ持ち越さない。
	Engine.time_scale = 1.0


## 毎フレームの終わり（_process の終わり）。再生の途中で、次のフレームまで待つのに使う。
signal frame_passed


func _process(delta: float) -> void:
	# カメラが動くとマウスの下のマスも変わるので、マウスの動きではなく毎フレーム追う（メニューの後ろでは追わない）。
	if not context.overlays.pauses():
		_update_hover()
	var focus_cells: Array[Vector2i] = []
	for view: UnitView in _views.values():
		focus_cells.append(BoardView.cell_of(view.position))
	if battle.board.in_bounds(_hover_cell):
		focus_cells.append(_hover_cell)
	_board_view.update_occlusion(_rig.camera, _rig.global_position, focus_cells, delta)
	_hud.place_minimap()
	if _hud.minimap().visible:
		_hud.minimap().refresh(battle, _views, _rig.camera, get_viewport().get_visible_rect().size)
	_layout.place_menu(selected_unit(), _painted)
	_layout.place_forecast(battle, selected_unit())
	frame_passed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if context.overlays.is_open():
		# 開いている間の入力は、重なる画面（メニュー・ログ・対戦の設定）が受ける（ここへ届いても、盤面には使わない）。
		# 対戦の設定がいちばん上なら、閉じられるときは Esc で閉じる（setup_panel が先に受ける）。閉じられない（起動した直後）なら、メニューを開く。
		var escape: bool = event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE
		if escape and context.overlays.is_top(_setup_panel):
			open_system_menu()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# 押しただけでは何もしない。離すまでに動かなければクリック、動けば視点を回す・傾ける（駒の上で押したときは、いつもクリック）。
			var cell := _cell_under_mouse()
			_ui.press(event.position, battle.board.in_bounds(cell) and battle.unit_at(cell) != null)
		elif _ui.release():
			click_cell(_cell_at(_ui.press_position))
	elif event is InputEventMouseMotion and _ui.pressing:
		if not event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			# ボタンを、帯やメニューの上で離した（離したことが、ここへは届かない）。押していないのに回り続けないよう、やめる。
			_ui.cancel_press()
		elif _ui.drag(event.position):
			_rig.drag(event.relative)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		cancel()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE:
				press_escape()
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
			KEY_F1, KEY_F2, KEY_F3:
				_start_on_nth_field(event.physical_keycode - KEY_F1)
			KEY_F4:
				toggle_opponent()
			KEY_T:
				toggle_threat()


# ---- 対戦の始まり ----


## 渡されたもの（source）が作る種 battle_seed の対戦の設定で、盤面を作り、軍を置いて、最初から始める。
## 対戦はルールの入口（MatchSetup.create_battle）で作る。相手を CPU が動かすかも、その設定から決める。
## 再生の途中と CPU の番の間は何もしない。
func start_battle(battle_seed: int) -> void:
	if is_busy():
		return
	var setup := source.make_setup(battle_seed)
	cpu_opponent = setup.is_cpu(source.cpu_side())
	_show_opponent()
	start_with(setup.create_battle(), source.look(), battle_seed, setup.scenario.title)


## ステージを field（versus_fields.gd の鍵）に替えて、新しい対戦を始める（F1〜F3、決着の画面の「新しい盤面」）。
## 渡されたものが、そのステージを選べない（source.new_board_fields() に無い）なら何もしない。
func start_on_field(field: StringName, battle_seed: int) -> void:
	if is_busy() or not source.new_board_fields().has(field):
		return
	source.choose_field(field)
	start_battle(battle_seed)


## F1〜F3: 「新しい盤面」で選べるステージの index 番目で、新しい対戦を始める（無ければ何もしない）。
func _start_on_nth_field(index: int) -> void:
	var fields := source.new_board_fields()
	if index < fields.size():
		start_on_field(fields[index], map_seed + 1)


## 対戦の設定画面を、いまの設定で開く。再生の途中と CPU の番の間は何もしない。
## 開いただけでは、いまの対戦は変わらない（「対戦へ戻る」・右クリック・Esc で、そのまま戻れる）。
## 新しい対戦になるのは、設定画面で始めるボタンを押したときだけ。
## 渡されたものが対戦の設定のパネルを開けない（source.can_open_setup() が偽）なら何もしない。
func open_setup() -> void:
	if is_busy() or not source.can_open_setup():
		return
	_setup_panel.open(source, _battle_started, _battle_started and not battle.is_over())


## 対戦の設定画面（検査用）。
func setup_panel() -> MatchSetupPanel:
	return _setup_panel


func _on_setup_chosen(chosen: RefCounted) -> void:
	_battle_started = true
	source = chosen
	context.match_choice = chosen.copy()  # 次に対戦の設定の場面を開いたときも、これを出す
	# いまの対戦の続きを CPU に渡さないよう、set_opponent は通さない（新しい対戦が、始めに CPU の番を見る）。
	start_battle(map_seed + 1)


## 用意した対戦を、最初から始める（検査では、小さな盤面を作って渡す）。再生の途中と CPU の番の間は何もしない。
## battle_look は盤の見た目の名前（stage_look.gd）、battle_area は決着の画面の「作戦領域」（空なら出さない）。
func start_with(new_battle: Battle, battle_look: StringName, battle_seed: int, battle_area := "") -> void:
	if is_busy():
		return
	look = battle_look
	area_name = battle_area
	map_seed = battle_seed
	battle = new_battle
	stats = BattleStats.new(battle)
	_phase_focus.clear()
	_log_panel.close()
	var names: Array[String] = []
	for side: Unit.Side in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
		names.append(_side_name(side))
	battle_log = BattleLog.new(battle, names)

	if _board_view != null:
		_board_view.queue_free()
	for view: UnitView in _views.values():
		view.queue_free()
	_views.clear()

	_board_view = BoardView.new()
	add_child(_board_view)
	_board_view.setup(battle.board, map_seed, TEAM_COLORS, look)
	_hud.minimap().show_board(battle.board, look)
	_playback.set_board_view(_board_view)
	StageLook.apply(self, _board_view.look)
	for unit in battle.units:
		_add_view(unit)

	_rig.fit_board(battle.board.size)  # 見てよい範囲と、引きの上限（小さい盤ほど寄せる）
	_rig.position = _camera_point(Unit.Side.PLAYER1)
	_ui.clear_for_new_battle()
	# 前の対戦のマウスの下のマス（盤の大きさが違えば、盤の外のマス）と、そこから決めた予測のパネル・メニューの置き場所を持ち越さない。
	# マウスの下のマスは、次のコマで新しい盤から拾い直す（_update_hover）。
	_hover_cell = NO_CELL
	_hover_forced = NO_CELL
	_hud.hide_forecast()
	_layout.clear_forecast()
	_layout.reset_menu()
	_hud.hide_result()
	_hud.result_screen().set_destinations(_new_boards(), source.can_open_setup(), source.can_choose_squad())
	context.resume_scene_music()  # 決着の曲のあとの「やり直す」でも、対戦の曲へ戻る
	_hud.show_banner("ターン %d　%s の番" % [battle.turn, _side_name(battle.phase)], TEAM_COLORS[battle.phase])
	_cues = source.talk_cues()
	_talk.clear()
	_say(_cues.on_start(battle))
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


## 決着の画面が出た。決着の曲を 1 回鳴らす: 人が勝てば勝ちの曲、CPU に負けたときと引き分けは負けの曲。
## 人どうしは、どちらかが勝っているので勝ちの曲。
## 渡されたもの（source）が許せば「次へ」を出し、人が勝ったことを知らせる（ストーリーのクリアの記録）。
func _on_result_shown(draw: bool, winner: Unit.Side) -> void:
	_talk.clear()  # 決着の画面に、前の台詞を残さない
	context.play_jingle(result_music(draw, winner, cpu_opponent, _human_side()))
	var won := cpu_opponent and not draw and winner == _human_side()
	_hud.result_screen().set_continue(source.can_continue(won), source.retries_on_enter(won))
	if won:
		source.record_win(context)


## 対戦の途中の会話の台詞を、上の帯のすぐ下の札に順に出し、ログにも書く。
func _say(lines: Array[BattleCues.Line]) -> void:
	if lines.is_empty():
		return
	for line in lines:
		battle_log.say(line.name, line.text, line.side)
	_talk.say(lines)


## いま画面に出ている、対戦の途中の会話の台詞（無ければ null。検査とスクリーンショットの道具用）。
func talk_line() -> BattleCues.Line:
	return _talk.current()


## 対戦の途中の会話の札が画面に占める四角と、上の帯の下の決まった枠（勝ち方の札、視点の案内）とミニマップの四角。検査用。
func talk_card_rect() -> Rect2:
	return _talk.card_rect()


func talk_card_neighbors() -> Array[Rect2]:
	var rects := _hud.top_tag_rects()
	rects.append(minimap_rect())
	return rects


## 対戦の途中の会話の札に、台詞を出す（検査用。ふだんは話の CUES から出す）。
func say_for_check(lines: Array[BattleCues.Line]) -> void:
	_talk.say(lines)


## 決着の曲の名前（sound_catalog.gd の MUSIC）。against_cpu は CPU との対戦か、human_side はそのときの人の側。
static func result_music(draw: bool, winner: Unit.Side, against_cpu: bool, human_side: Unit.Side) -> StringName:
	if draw or (against_cpu and winner != human_side):
		return &"defeat"
	return &"victory"


func _on_restart_pressed(field: StringName, new_board: bool) -> void:
	if new_board:
		start_on_field(field, map_seed + 1)
	else:
		start_battle(map_seed)


## 決着の画面の「新しい盤面」のボタン: [鍵, 名前] の列。
func _new_boards() -> Array[Array]:
	var boards: Array[Array] = []
	for field in source.new_board_fields():
		boards.append([field, VersusFields.title_of(field)])
	return boards


# ---- 操作（マウス・キー・ボタンのどれからも、ここを通る） ----


## 操作を受け付けない間か（イベントの再生の途中か、CPU の番を進めている途中か、重なる画面（対戦の設定画面・システムメニュー・ログ）を開いている間）。
func is_busy() -> bool:
	return _ui.busy or _ui.cpu_running or context.overlays.is_open()


# ---- システムメニューと設定 ----


## Esc。戻すものがあれば戻す（右クリックと同じ）。何も無ければ（再生の途中や CPU の番も）、システムメニューを開く。
func press_escape() -> void:
	if not cancel():
		open_system_menu()


## システムメニューを開く（右上のボタン、Esc）。いつでも開ける（CPU の番や再生の途中でも）。開くのはアプリ（app.gd）。
## 開いている間は時間を止める（再生も CPU の番も、その場で止まり、閉じると続きから進む）。
func open_system_menu() -> void:
	context.open_menu()


func _on_system_menu_opened() -> void:
	_log_panel.close()  # ログの上にメニューを重ねない
	_on_overlay_opened()


## システムメニューかログを開いた: 押している途中の操作をやめ、視点の操作と時間を止める。
func _on_overlay_opened() -> void:
	_ui.cancel_press()
	_rig.controls_enabled = false
	_update_time_scale()


# ---- ログ ----


## ログを開く（上の帯の「ログ」）。いつでも開ける（CPU の番や再生の途中でも）。システムメニューと同じく、開いている間は時間を止める。
## 対戦の設定画面の上では開かない。
func open_log() -> void:
	if context.overlays.is_open() or battle_log == null:
		return
	_hud.hide_banner()
	_log_panel.open(battle_log)


## ログの画面（検査とスクリーンショットの道具用）。
func log_panel() -> LogPanel:
	return _log_panel


func _on_log_closed() -> void:
	_rig.controls_enabled = true
	_update_time_scale()
	# 行を選んで示したマスを消し、いまの番の表示に戻す。再生の途中なら、続きの再生が描く。
	if _ui.busy:
		_board_view.show_cells({})
	else:
		_refresh()


## ログの行を選んだ: その出来事のあったマスへカメラを移し、そこと、関わった駒のいまのマスを塗る。
## 時間を止めているので、カメラは寄っていかずに、すぐ移る。
func _on_log_entry_chosen(entry: BattleLog.Entry) -> void:
	var colors := {}
	var focus := entry.cell
	for unit_id in entry.unit_ids:
		var unit := battle.unit_by_id(unit_id)
		if unit != null:
			colors[unit.cell] = COLOR_LOG_UNIT
			if focus == NO_CELL:
				focus = unit.cell
	if battle.board.in_bounds(entry.cell):
		colors[entry.cell] = COLOR_LOG_PLACE
	_board_view.show_cells(colors)
	_board_view.show_danger([])
	_selection_ring.visible = false
	_inspect_ring.visible = false
	if battle.board.in_bounds(focus):
		_rig.jump_to(BoardView.cell_center(focus))


# ---- ミニマップ ----


## ミニマップの上で押した・ドラッグした（point は盤の座標 x / z）: そこを画面の中央にする（すぐに移る。駒を追うのもやめる）。
## 重なる画面（システムメニュー・ログ・対戦の設定画面）を開いている間は動かさない（どれもミニマップを覆う）。
func _on_minimap_pointed(point: Vector2) -> void:
	if context.overlays.is_open():
		return
	point_minimap(point)


## ミニマップで盤の座標 point（x / z）を指したのと同じにする（検査とスクリーンショットの道具用）。
func point_minimap(point: Vector2) -> void:
	_rig.follow(null)
	_rig.jump_to(Vector3(point.x, 0.0, point.y))


## ミニマップに、画面の座標のマウスの入力を渡す（ミニマップが受けるのと同じ道。検査用）。
func feed_minimap_input(event: InputEventMouse) -> void:
	var local := event.duplicate() as InputEventMouse
	local.position = event.position - _hud.minimap_rect().position
	_hud.minimap().take_input(local)


## ミニマップが画面に占める四角（出していなければ大きさ 0）。検査とスクリーンショットの道具用。
func minimap_rect() -> Rect2:
	return _hud.minimap_rect()


## ミニマップに描いている、カメラが見ている範囲（ミニマップの中の位置）。検査用。
func minimap_view() -> PackedVector2Array:
	return _hud.minimap().view_on_map()


## システムメニュー（検査とスクリーンショットの道具用）。
func system_menu() -> SystemMenu:
	return _system_menu


## システムメニューの「戻る」の文字（scene_flow.gd の場面の決まり）。
func resume_label() -> String:
	return "対戦の設定へ戻る" if _setup_panel.visible else "対戦へ戻る"


## システムメニューに足す項目。対戦の設定画面の上で開いたら、「対戦の設定へ」は出さない（もう開いている）。
## 渡されたものが対戦の設定のパネルを開けないなら、出さない。
func menu_items() -> Array:
	if _setup_panel.visible or not source.can_open_setup():
		return []
	return [[SYSTEM_MATCH_SETUP, "対戦の設定へ", ""]]


## 抜けると失われるもの（決着していない対戦）があるか。あれば、タイトルへ戻る・ゲームを終える前に確かめる。
func in_progress() -> bool:
	return battle != null and not battle.is_over()


func on_menu_item(id: StringName) -> void:
	if id == SYSTEM_MATCH_SETUP:
		_open_setup_when_ready()


func _on_system_menu_closed() -> void:
	_rig.controls_enabled = not context.overlays.pauses()
	_update_time_scale()


## 対戦の設定画面を開く。CPU の番や再生の途中なら、それが終わってから開く（対戦の途中で盤面を差し替えないため）。
func _open_setup_when_ready() -> void:
	var played_battle := battle
	if is_busy():
		_hud.show_banner("CPU の番が終わったら、対戦の設定を開く" if _ui.cpu_running else "動きが終わったら、対戦の設定を開く", Color.WHITE)
	while is_busy() and battle == played_battle and not _setup_panel.visible:
		await frame_passed
	if battle == played_battle:
		open_setup()


func _on_setting_changed(_key: StringName) -> void:
	_apply_settings()


## 設定の値を効かせる。項目を足したら、ここに 1 行足す（settings.gd）。
func _apply_settings() -> void:
	_rig_settings()
	_update_time_scale()
	if _hud != null:
		_hud.set_minimap_shown(settings.value(Settings.SHOW_MINIMAP))


func _rig_settings() -> void:
	if _rig == null:
		return
	_rig.drag_sensitivity = OrbitCamera.DEFAULT_DRAG_SENSITIVITY * settings.value(Settings.MOUSE_SENSITIVITY) / 100.0
	_rig.invert_vertical = settings.value(Settings.INVERT_VERTICAL_DRAG)


## ふだんの時間の速さを決める（自動の対戦が上げる）。
func set_time_scale_base(scale: float) -> void:
	time_scale_base = scale
	_update_time_scale()


func _update_time_scale() -> void:
	var scale := time_scale_base
	if context.overlays.pauses():
		scale = 0.0
	elif _cpu_fast:
		scale *= float(settings.value(Settings.CPU_PLAYBACK_SPEED))
	Engine.time_scale = scale


## CPU の駒の行動を再生する間だけ、設定の速さを掛ける（検査からも呼ぶ）。
func set_cpu_fast(fast: bool) -> void:
	if _cpu_fast != fast:
		_cpu_fast = fast
		_update_time_scale()


## 相手（source.cpu_side() のプレイヤー）を CPU にするか、人にするかを決める。対戦の途中でも切り替えられる
## （CPU にすれば、相手の番の続きを CPU が引き取る。人にすれば、CPU はいまの行動を最後に手を止める）。
## 次に作る対戦（やり直し）にも持ち越す（source.set_cpu_opponent）。検査とスクリーンショットの道具も、CPU を止めるのに使う。
func set_opponent(cpu: bool) -> void:
	cpu_opponent = cpu
	source.set_cpu_opponent(cpu)
	_show_opponent()
	if battle != null and not is_busy():
		if _is_cpu_turn():
			_select(0)
			_run_cpu()
		else:
			_refresh()  # 自分の番の途中なら、選んでいる駒（動いたあとの駒）はそのまま。


## 下の帯の「相手」のボタン。切り替えられない（source.can_switch_opponent() が偽）なら出さない。
func _show_opponent() -> void:
	if not source.can_switch_opponent():
		_hud.set_opponent("")
		return
	_hud.set_opponent("相手: CPU" if cpu_opponent else "相手: 人")


## 下の帯に「相手」のボタンが出ているか。検査用。
func opponent_switch_shown() -> bool:
	return _hud.opponent_shown()


## 相手を人と CPU で切り替える（F4、下の帯の「相手」のボタン）。切り替えられないなら何もしない。
func toggle_opponent() -> void:
	if source.can_switch_opponent():
		set_opponent(not cpu_opponent)


## いまが、CPU が動かす番か。
func _is_cpu_turn() -> bool:
	return cpu_opponent and not battle.is_over() and battle.phase == source.cpu_side()


## 番の知らせに出す陣営の名前（CPU が動かすなら、そう書く）。
func _side_name(side: Unit.Side) -> String:
	var side_name: String = Names.SIDE_NAMES[side]
	return side_name + " CPU" if cpu_opponent and side == source.cpu_side() else side_name


## CPU と対戦するときに、人が動かすプレイヤー（相手の反対）。
func _human_side() -> Unit.Side:
	return (1 - source.cpu_side()) as Unit.Side


func selected_unit() -> Unit:
	return battle.unit_by_id(_ui.selected_id)


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


## いま出ている詳しい戦績（出ていなければ空）。検査用。
func result_stats() -> String:
	return _hud.result_stats()


## リザルトの画面（result_screen.gd）。検査とスクリーンショットの道具用。
func result_screen() -> Control:
	return _hud.result_screen()


## 盤面のマスをクリックする。選んでいる駒の攻撃できる相手・樽なら攻撃、回復できる味方なら回復、動けるマスなら移動、
## 行動できる自分の駒なら選び直す。ほかの駒（相手、中立、行動を終えた味方）なら、選択はそのままで、その駒を見る（_inspect）。
## 駒のいないマスなら、選ぶのをやめて、そのマスの情報を出す。
## 対象を選んでいる途中（メニューの攻撃・回復・スキル）なら、対象のマスで行動し、ほかの駒なら見て、駒のいないマスでは選ぶのをやめる。
## 駒を見ている間のクリックは見るだけ: ほかの駒なら見る駒を替え、そのほか（駒のいないマス、見ている駒、選んでいる駒）なら見るのをやめて、
## 元の行動の途中へ戻る（移動や攻撃はしない）。
func click_cell(cell: Vector2i) -> void:
	if is_busy() or battle.is_over() or not battle.board.in_bounds(cell):
		return
	if _ui.confirming_ult:
		# 必殺技を確かめている途中のクリックは、確かめるのをやめるだけ（移動や攻撃はしない）。
		_ui.confirming_ult = false
		_refresh()
		return
	var clicked := battle.unit_at(cell)
	if _ui.inspected_id != 0:
		if clicked == null or clicked.id == _ui.inspected_id or clicked.id == _ui.selected_id:
			_inspect(0)
		elif _can_select(clicked) and battle.acting_unit_id == 0 and _ui.mode == Mode.NONE:
			_select(clicked.id)
		else:
			_inspect(clicked.id)
		return
	# 選んでいる駒のほかの駒で、行動の相手にならないもの（見るだけ）。
	var other := clicked != null and clicked.id != _ui.selected_id
	if _ui.mode == Mode.SKILL:
		if _skill_cells.has(cell):
			_do(UseSkillAction.new(_ui.selected_id, cell))
		elif other:
			_inspect(clicked.id)
		else:
			_leave_mode()
		return
	if clicked != null and _targets.has(clicked) and _ui.mode != Mode.HEAL:
		_do(AttackAction.new(_ui.selected_id, clicked.id))
	elif clicked != null and _heal_targets.has(clicked) and _ui.mode != Mode.ATTACK:
		_do(HealAction.new(_ui.selected_id, clicked.id))
	elif _barrel_targets.has(cell) and _ui.mode != Mode.HEAL:
		_do(AttackBarrelAction.new(_ui.selected_id, cell))
	elif _barricade_targets.has(cell) and _ui.mode != Mode.HEAL:
		_do(AttackBarricadeAction.new(_ui.selected_id, cell))
	elif other and (_ui.mode != Mode.NONE or battle.acting_unit_id != 0 or not _can_select(clicked)):
		_inspect(clicked.id)
	elif _ui.mode != Mode.NONE:
		_leave_mode()
	elif battle.acting_unit_id != 0:
		pass  # 動いたあとは、攻撃・回復・待機・取り消しのどれかを選ぶ。
	elif _move_cells.has(cell):
		_do(MoveAction.new(_ui.selected_id, cell, _move_cells[cell]))
	else:
		_select(clicked.id if clicked != null else 0)
		if clicked == null:
			_ui.inspected_cell = cell
			_refresh()


## その駒を、行動させる駒として選べるか（いまの番の人のプレイヤーの、行動できる駒）。選べない駒は、クリックすると見るだけ。
func _can_select(unit: Unit) -> bool:
	return unit != null and unit.side == battle.phase and not _is_cpu_turn() and battle.can_act(unit)


## 駒を見る（閲覧）。選んでいる駒、動いたあとの状態、対象を選ぶ途中は、そのまま残す。0 なら見るのをやめる。
func _inspect(unit_id: int) -> void:
	_ui.inspect(unit_id)
	_refresh()


## 見ている駒（見ていなければ null）。検査用。
func inspected_unit() -> Unit:
	return battle.unit_by_id(_ui.inspected_id) if _ui.inspected_id != 0 else null


## 敵の全員の脅威範囲を出す・消す（下の帯の切り替え、T）。いつでも切り替えられ、出したままにできる。
func toggle_threat() -> void:
	_threat_shown = not _threat_shown
	if not _ui.busy:
		_refresh()


## 敵の全員の脅威範囲を出しているか。検査用。
func is_threat_shown() -> bool:
	return _threat_shown


## 盤に重ねて出している、敵の全員の脅威範囲のマス（出していなければ空）。検査用。
func threat_overlay_cells() -> Array[Vector2i]:
	return _board_view.danger_cells()


## 見ている・選んでいる駒の脅威範囲として、塗っているマス（濃い赤）。検査用。
func threat_painted_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell: Vector2i in _painted:
		if _painted[cell] == COLOR_THREAT:
			cells.append(cell)
	return cells


## 駒のそばのメニューの項目を押す（クリックと同じ道を通る）。出ていて押せる項目なら真を返す。
func press_menu(id: StringName) -> bool:
	return not is_busy() and _hud.press_menu(id)


func _on_menu_pressed(id: StringName) -> void:
	if is_busy() or battle.is_over() or _ui.selected_id == 0:
		return
	_ui.focus_selected()  # メニューを押したら、見るのをやめて、選んでいる駒の行動へ戻る
	match id:
		MENU_ATTACK:
			_enter_mode(Mode.ATTACK)
		MENU_HEAL:
			_enter_mode(Mode.HEAL)
		MENU_SKILL:
			if not _skill_cells.is_empty():
				_enter_mode(Mode.SKILL)
		MENU_WAIT:
			_do(WaitAction.new(_ui.selected_id))
		MENU_UNDO:
			if battle.acting_unit_id != 0:
				_do(UndoMoveAction.new(battle.acting_unit_id))
		MENU_BACK:
			_leave_mode()


func _on_menu_hovered(id: StringName) -> void:
	_ui.menu_hover_id = id
	if not _ui.busy:
		_update_info()


func _enter_mode(mode: BattleUiState.Mode) -> void:
	_ui.mode = mode
	_refresh()


func _leave_mode() -> void:
	_ui.mode = Mode.NONE
	_refresh()


## 選んでいる駒を待機させる（メニューの「待機」）。
func press_wait() -> void:
	press_menu(MENU_WAIT)


## 選んでいる駒のスキルの対象を選び始める（メニューのスキルの項目）。もう選んでいる途中なら、やめる（メニューの「やめる」）。
func press_skill() -> void:
	press_menu(MENU_BACK if _ui.mode == Mode.SKILL else MENU_SKILL)


## いまの番のプレイヤーの必殺技を使う。対象を選ばず、取り消せないので、1 回目は確かめるだけで、もう一度押すと使う。
## ゲージがいっぱいでなければ何もしない。駒を選んでいなくても、駒が行動の途中でも使える。
func press_ult() -> void:
	if is_busy() or not battle.can_apply(UseUltAction.new()):
		return
	if not _ui.confirming_ult:
		_ui.start_confirming_ult(Time.get_ticks_msec())
		_refresh()
		return
	if _ui.confirm_guarded(Time.get_ticks_msec()):
		return  # 確かめに変わった直後の 2 回目（ダブルクリック・連打）は受けない
	_do(UseUltAction.new())


## 必殺技を使うかを確かめている途中か。検査用。
func is_confirming_ult() -> bool:
	return _ui.confirming_ult


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
	return _ui.mode == Mode.SKILL


## 攻撃・回復の相手を選んでいる途中か（メニューの「攻撃」「回復」を押したあと）。検査用。
func is_choosing_target() -> bool:
	return _ui.mode == Mode.ATTACK or _ui.mode == Mode.HEAL


## メニューのスキルの項目に出している文字と、押せるか。検査用。
func skill_button_text() -> String:
	return _hud.menu_text(MENU_SKILL)


func is_skill_enabled() -> bool:
	return _hud.is_menu_enabled(MENU_SKILL)


## 駒のそばのメニューに出ている項目の名前（上から）と、画面に占める四角、置いてよい範囲。検査用。
func menu_ids() -> Array[StringName]:
	return _hud.menu_ids()


func menu_rect() -> Rect2:
	_layout.place_menu(selected_unit(), _painted)
	return _hud.menu_rect()


func menu_area() -> Rect2:
	return _hud.menu_area()


## マスの中央が画面に出る位置（px）。検査とスクリーンショットの道具用。
func cell_screen_position(cell: Vector2i) -> Vector2:
	return _rig.camera.unproject_position(BoardView.cell_center(cell))


## カメラの向き（回していく先。ラジアン）。検査用。
func camera_yaw() -> float:
	return _rig.target_yaw()


## カメラの見下ろす角度（傾けていく先。度）。検査用。
func camera_pitch() -> float:
	return _rig.target_pitch()


## カメラの見下ろす角度を pitch（度）にする（範囲に収める）。スクリーンショットの道具用。
func set_camera_pitch(pitch: float) -> void:
	_rig.set_pitch(pitch)


## カメラの距離と向き（度）を決める。スクリーンショットの道具用。
func set_camera_view(distance: float, yaw_degrees: float) -> void:
	_rig.set_view(distance, yaw_degrees)


## カメラを、すぐに point を中央に見る位置へ置く（追うのをやめる）。スクリーンショットの道具用。
func place_camera(point: Vector3) -> void:
	_rig.place_at(point)


## カメラがいま見ている地点（盤面の上）。スクリーンショットの道具用。
func camera_center() -> Vector3:
	return _rig.position


## ドラッグの感度と、縦のドラッグを逆にしているか（設定が効いているかを見る）。検査用。
func camera_drag_settings() -> Array:
	return [_rig.drag_sensitivity, _rig.invert_vertical]


## 画面の中央の知らせ（番の知らせなど）が出ているか。スクリーンショットの道具用。
func is_banner_shown() -> bool:
	return _hud.is_banner_shown()


## メニューの項目 id にマウスを乗せたことにする（空なら、離したことにする）。検査とスクリーンショットの道具用。
func hover_menu_item(id: StringName) -> void:
	_on_menu_hovered(id)


## 盤面への入力を、マウスやキーと同じ道で渡す。検査用。
func feed_input(event: InputEvent) -> void:
	_unhandled_input(event)


## cell に、見ている駒の白い輪を出す（駒がいなくても）。スクリーンショットの道具用。
func mark_cell(cell: Vector2i) -> void:
	_inspect_ring.position = BoardView.cell_center(cell) + Vector3(0.0, 0.04, 0.0)
	_inspect_ring.visible = true


## 画面を通さずに起きたこと events（対戦の始めから）を数えて、side の番の始めにカメラが寄る駒を返す。スクリーンショットの道具用。
func phase_focus_after(events: Array[BattleEvent], side: Unit.Side) -> Unit:
	_phase_focus.feed(battle, events)
	return _phase_focus.unit_for(battle, side)


## 左下の情報の枠に出ている文（見出しを除く）。検査用。
func info_text() -> String:
	return _hud.info_text()


## 左下の情報の枠の見出し（出ていなければ空）。検査用。
func info_title() -> String:
	return _hud.info_title()


## 戻す（右クリック・Esc）。必殺技を確かめている途中か、対象を選んでいる途中なら、それをやめる。
## 動いたあとなら移動を取り消す。そうでなければ選択をやめる（マスの情報も消す）。ターン終了の確かめも、やめる。
## 戻したものがあったかを返す（無ければ、Esc はシステムメニューを開く）。戻したら、戻す音を鳴らす。
func cancel() -> bool:
	var done := _cancel()
	if done:
		context.play_sound(&"ui_back")
	return done


func _cancel() -> bool:
	if is_busy():
		return false
	match _ui.back(battle.acting_unit_id != 0):
		BattleUiState.Back.DONE:
			_refresh()
		BattleUiState.Back.UNDO_MOVE:
			_do(UndoMoveAction.new(battle.acting_unit_id))
		BattleUiState.Back.DESELECT:
			_select(0)
		_:
			return false
	return true


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
## 確かめに変わった直後の 2 回目（ダブルクリック・Enter の連打）は受けない（BattleUiState.CONFIRM_GUARD_MSEC）。
func press_end_turn() -> void:
	if is_busy() or battle.is_over() or battle.evolving_unit() != null:
		return
	if Queries.unacted_count(battle) > 0:
		if not _ui.confirming_end:
			_ui.start_confirming_end(Time.get_ticks_msec())
			_refresh()
			return
		if _ui.confirm_guarded(Time.get_ticks_msec()):
			return
	_do(EndPhaseAction.new())


## 確かめを始めた直後の、2 回目を受けない間を、もう過ぎたことにする。検査用（人が間を置いてもう一度押すのと同じ）。
func pass_confirm_guard() -> void:
	_ui.confirm_started_msec -= BattleUiState.CONFIRM_GUARD_MSEC


## ターン終了を確かめている途中か。検査用。
func is_confirming_end() -> bool:
	return _ui.confirming_end


func _select(unit_id: int) -> void:
	if _ui.select(unit_id):
		_layout.reset_menu()
		if unit_id != 0:
			context.play_sound(&"ui_confirm")  # 駒を選んだ（決める音）
	_refresh()


## 行動の外でルールに起きたことを再生する（検査用）。
## スキルのまだ無い盤の上の効果（煙幕）も通すため、検査はルールの FieldEffects.place_* で置いて、その結果をここで再生する。
func play_events(events: Array[BattleEvent]) -> void:
	_ui.busy = true
	await _playback.play_all(events)
	_ui.busy = false
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
	_phase_focus.feed(battle, result.events)  # フェーズの始めにカメラが寄る駒（再生の中の PhaseStartedEvent より前に食わせる）
	_ui.busy = true
	_ui.clear_after_action()
	_board_view.show_cells({})
	_board_view.show_danger([])
	_board_view.set_marked(NO_CELL)
	_selection_ring.visible = false
	_inspect_ring.visible = false
	_hud.set_menu([])
	_hud.hide_forecast()
	_hud.set_ult_button(_hud.ult_button_text(), false, _ult_summary())
	_hud.set_end_turn(false, _hud.end_turn_text())
	_hud.hide_evolution()
	await _playback.play_all(result.events)
	_ui.busy = false
	# 対戦の途中の会話: 起きたことを見せ終えてから出す（演出と重ねない）。決着した行動のあとは出さない（BattleCues が見る）。
	_say(_cues.on_events(battle, result.events))

	var evolving := battle.evolving_unit()
	_ui.settle_after_action(
		_is_cpu_turn(),
		evolving.id if evolving != null and not battle.is_over() else 0,
		battle.acting_unit_id,
		action is UndoMoveAction or action is UseUltAction,
	)
	_refresh()
	_run_cpu()
	return true


# ---- CPU の番 ----


## CPU の番なら、CPU の行動を 1 つずつ、人の操作と同じ入口（_do）に流す。番が終わるか、決着するか、相手を人に切り替えるまで続ける。
## 何をしたか追えるように、駒が動き出す前にカメラを寄せ、1 体の行動が終わるたびに間を置く。
## 動かずに待機するだけの駒は、見せるものが無いので間を置かない。
func _run_cpu() -> void:
	if _ui.cpu_running or _ui.busy or not _is_cpu_turn():
		return
	_ui.cpu_running = true
	_refresh()
	var played_battle := battle
	while battle == played_battle and _is_cpu_turn():
		var action := _cpu.next_action(battle)
		if action == null:
			break
		var unit: Unit = battle.unit_by_id(action.get(&"unit_id")) if &"unit_id" in action else null
		var idle := action is WaitAction and unit != null and not unit.has_moved
		# 設定の「CPU の番の速さ」は、CPU の駒の行動にだけ効かせる（番を終えたあとの中立の番は、ふだんの速さで見せる）。
		set_cpu_fast(not action is EndPhaseAction)
		if unit != null and not unit.has_moved and not idle and not action is EvolveAction:
			_rig.focus_on(_view(unit.id).position)
			await _playback.after(CPU_FOCUS_TIME)
		if not await _do(action):
			break  # CPU の行動は必ず受け付けられるはず。そうでなければ、同じ行動を繰り返さずに手を止める。
		cpu_actions += 1
		if not (action is MoveAction or action is EndPhaseAction or idle or battle.is_over()):
			await _playback.after(CPU_PAUSE)
	set_cpu_fast(false)
	_ui.cpu_running = false
	# 番の途中で相手を人に切り替えたら、動いたあとの駒を選んだ状態で引き渡す。
	_ui.selected_id = battle.acting_unit_id
	_refresh()


# ---- 決着の画面 ----


## リザルトの画面に出すもの（result_summary.gd）。draw なら引き分けで、winner は見ない。
func _result_summary(draw: bool, winner: Unit.Side, reason: String) -> RefCounted:
	var names: Array[String] = []
	for side: Unit.Side in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
		names.append(_side_name(side))
	return ResultSummary.of(stats, draw, winner, reason, cpu_opponent, _human_side(), names, area_name)


## side の番が来たときにカメラが見る地点。寄る駒（phase_focus.gd。前回最後に動かした駒）のいるところから、少し敵の本陣のほうへ寄せる
## （駒が盤の端にいると、画面の半分が盤の外になるため）。駒がいなければ自分の本陣から。
func _camera_point(side: Unit.Side) -> Vector3:
	var focus := _phase_focus.unit_for(battle, side)
	var from := BoardView.cell_center(focus.cell if focus != null else battle.board.hq_cells[side])
	var toward := BoardView.cell_center(battle.board.hq_cells[1 - side]) - from
	return from + toward.limit_length(4.0)


func _view(unit_id: int) -> UnitView:
	return _views[unit_id]


# ---- 表示の作り直し ----


## いまの状態と選択から、塗るマス・メニュー・文字を作り直す。
func _refresh() -> void:
	var unit := selected_unit()
	_move_cells = Queries.move_cells(battle, unit)
	_targets = Queries.attack_targets(battle, unit)
	_barrel_targets = Queries.barrel_targets(battle, unit)
	_barricade_targets = Queries.barricade_targets(battle, unit)
	_heal_targets = Queries.heal_targets(battle, unit)
	_skill_cells = Queries.skill_cells(battle, unit)
	var cpu_turn := _ui.cpu_running or _is_cpu_turn()
	_ui.reconcile(
		unit != null, unit != null and battle.can_act(unit), inspected_unit() != null, battle.is_over(), cpu_turn,
		battle.can_apply(UseUltAction.new()), _can_attack(), not _heal_targets.is_empty(), not _skill_cells.is_empty()
	)
	var inspected := inspected_unit()

	_painted = {}
	if inspected != null:
		_paint_view(inspected)  # 見ている間は、見ている駒の範囲だけを塗る（選んでいる駒の範囲は、見終わると戻る）
	elif unit != null and not battle.is_over():
		if _ui.mode == Mode.SKILL:
			for cell in _skill_cells:
				_painted[cell] = COLOR_SKILL
		elif battle.can_act(unit):
			if _ui.mode == Mode.NONE:
				for cell: Vector2i in _move_cells:
					_painted[cell] = COLOR_CRUISE if _move_cells[cell] else COLOR_MOVE
			if _ui.mode != Mode.HEAL:
				for target in _targets:
					_painted[target.cell] = COLOR_TARGET
				for cell in _barrel_targets:
					_painted[cell] = COLOR_TARGET
				for cell in _barricade_targets:
					_painted[cell] = COLOR_TARGET
			if _ui.mode != Mode.ATTACK:
				for target in _heal_targets:
					_painted[target.cell] = COLOR_HEAL
		else:
			_paint_view(unit)
	if _ui.confirming_end and inspected == null:
		# ターン終了の確かめの理由（まだ行動していない駒）は、ボタンには書かず、その駒の足元を光らせて見せる。
		for unacted in Queries.unacted_units(battle):
			_painted[unacted.cell] = COLOR_UNACTED
	_show_painted()
	var threats: Array[Vector2i] = []
	if _threat_shown and not battle.is_over():
		threats = Threat.against(battle, _viewer_side()).cells()
	_board_view.show_danger(threats)
	_hud.set_threat_button(_threat_shown)

	_selection_ring.visible = unit != null
	if unit != null:
		_selection_ring.position = BoardView.cell_center(unit.cell) + Vector3(0.0, 0.04, 0.0)
	_inspect_ring.visible = inspected != null
	if inspected != null:
		_inspect_ring.position = BoardView.cell_center(inspected.cell) + Vector3(0.0, 0.04, 0.0)

	_board_view.set_marked(_ui.inspected_cell)
	# 状態（バリア、照準など）が付いている駒は、足元の輪で分かるようにする。
	for shown in battle.units:
		if _views.has(shown.id):
			_view(shown.id).set_status_mark(not Statuses.types_of(shown).is_empty())
	_refresh_status(battle.turn, battle.phase)
	_hud.set_hint(BattleTexts.hint(
		battle, unit, inspected_unit(), _ui.mode, cpu_turn, _ui.confirming_ult, _is_self_skill(unit),
		Queries.unacted_count(battle) if _ui.confirming_end else 0
	))
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
	elif _ui.confirming_end:
		_hud.set_end_turn(true, "もう一度押して終了")
	else:
		var can_end := not battle.is_over() and evolving == null
		_hud.set_end_turn(can_end, "ターン終了", can_end and unacted == 0)
	_hud.set_menu(
		BattleTexts.menu_items(battle, unit, _ui.mode, _can_attack(), not _heal_targets.is_empty(), not _skill_cells.is_empty())
		if not cpu_turn and evolving == null else []
	)
	_layout.mark_menu_dirty()
	_hud.set_ult_button(
		BattleTexts.ult_button_text(battle, _ult_side(), _ui.confirming_ult), not cpu_turn and battle.can_apply(UseUltAction.new()), _ult_summary(), _ui.confirming_ult
	)
	_update_info()


## 見るだけの駒（相手、中立、行動を終えた駒）の範囲を塗る。相手の駒（中立も）は、次の番に攻撃・スキルが届くマス
## （脅威範囲）を濃い赤で。その上に、動ける範囲を白で。
func _paint_view(unit: Unit) -> void:
	if unit.side != battle.phase:
		for cell in Queries.threat_cells(battle, unit):
			_painted[cell] = COLOR_THREAT
	for cell in Queries.inspect_cells(battle, unit):
		_painted[cell] = COLOR_INSPECT


## 盤を見ている人のプレイヤー。CPU と対戦するときは、いつも人のプレイヤー（CPU の番の間も）。
## 人どうしでは、いまの番のプレイヤー（中立の番では、プレイヤー1）。必殺技のボタンと、敵の全員の脅威範囲が、このプレイヤーのもの。
func _viewer_side() -> Unit.Side:
	if cpu_opponent:
		return _human_side()
	if battle.phase == Unit.Side.NEUTRAL:
		return Unit.Side.PLAYER1
	return battle.phase


## 選んでいる駒が、いまの位置から攻撃できるもの（相手・樽・盾）があるか。
func _can_attack() -> bool:
	return not (_targets.is_empty() and _barrel_targets.is_empty() and _barricade_targets.is_empty())


## 必殺技のボタンが、どのプレイヤーのものか（_viewer_side）。
func _ult_side() -> Unit.Side:
	return _viewer_side()


## 必殺技のボタンの上に出す説明。
func _ult_summary() -> String:
	var ult := Ults.of(battle, _ult_side())
	return ult.summary() if ult != null else ""


## 選べる対象が自分のマスだけのスキル（自分に使うスキル）を、選んでいるか。
func _is_self_skill(unit: Unit) -> bool:
	return unit != null and _skill_cells.size() == 1 and _skill_cells[0] == unit.cell


func _refresh_status(turn: int, phase: Unit.Side) -> void:
	var counts: Array[int] = [
		Queries.unit_count(battle, Unit.Side.PLAYER1), Queries.unit_count(battle, Unit.Side.PLAYER2),
	]
	var relics: Array[String] = []
	var relic_notes: Array[String] = []
	var held: Array = []
	for side: Unit.Side in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
		held.append(Relics.held(battle, side))
		var names: Array[String] = []
		var notes: Array[String] = []
		for relic in Relics.held(battle, side):
			names.append(Relics.display_name(relic).trim_suffix("の聖遺物"))
			notes.append("%s: %s" % [Relics.display_name(relic), Relics.summary(relic)])
		relics.append("・".join(names))
		relic_notes.append("
".join(notes))
	_hud.set_relics(relics, relic_notes, held)
	var shown: Array[bool] = []
	for side: Unit.Side in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
		shown.append(battle.wins_by(side, GameWonEvent.Reason.HQ_CAPTURED))
	_hud.set_status(
		WinText.turn_text(turn), phase, counts, battle.capture_turns, Battle.CAPTURE_TURNS_TO_WIN, shown,
		WinText.goal_tag(battle, turn, _viewer_side()), WinText.goal_note(battle, _viewer_side()),
	)
	var percents: Array[int] = []
	var names: Array[String] = []
	for side: Unit.Side in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
		var ult := Ults.of(battle, side)
		percents.append(Ults.percent(battle, side))
		names.append(ult.display_name() if ult != null else "")
	_hud.set_ult_gauges(percents, names)


## 塗ったマスに、マウスの下のマスまでの道か、マウスの下の樽の爆発が届くマスを重ねて出す。
func _show_painted() -> void:
	var colors := _painted
	var unit := selected_unit() if _ui.inspected_id == 0 else null  # 見ている間は、選んでいる駒の道や効果の及ぶマスを重ねない
	if unit != null and not _ui.busy and _ui.mode == Mode.SKILL:
		if _skill_cells.has(_hover_cell):
			colors = _painted.duplicate()
			for cell in Skills.of(unit).affected_cells(battle, unit, _hover_cell):
				colors[cell] = COLOR_SKILL_AREA
	elif unit != null and not _ui.busy and _barrel_targets.has(_hover_cell):
		colors = _painted.duplicate()
		for cell in MapObject.blast_cells(battle.board, _hover_cell):
			colors[cell] = BattlePlayback.COLOR_BLAST
	elif unit != null and not _ui.busy and _ui.mode == Mode.NONE and _move_cells.has(_hover_cell):
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
	_board_view.set_grid_emphasis(_ui.selected_id != 0 or _ui.inspected_id != 0 or not colors.is_empty())


## マウスを cell に乗せたことにする（検査用。NO_CELL で、マウスの位置に戻す）。
## いまマウスの下にある（ことにしている）マス。無ければ NO_CELL。検査用。
func hovered_cell() -> Vector2i:
	return _hover_cell


func hover(cell: Vector2i) -> void:
	_hover_forced = cell
	_update_hover()


func _update_hover() -> void:
	var cell := _cell_under_mouse() if not _hud.is_mouse_over_ui() else NO_CELL
	if _hover_forced != NO_CELL:
		cell = _hover_forced
	if not battle.board.in_bounds(cell):
		cell = NO_CELL
	if cell == _hover_cell:
		return
	_hover_cell = cell
	_board_view.set_cursor(cell)
	if not _ui.busy:
		_show_painted()
		_update_info()


## マウスの下の駒（いなければ見ている駒、選んでいる駒。それも無ければ、クリックしたマス）の情報を左下の枠に、
## マウスの下のマスの短い説明を下の帯に出す。行動の対象にマウスを乗せていれば、戦闘予測のパネルも出す（_update_forecast）。
func _update_info() -> void:
	if battle.is_over():
		# 決着のあとは、リザルトの画面が前に出る。後ろの盤の駒やマスの情報は出さない（左下の枠が、リザルトのボタンに重なる）。
		_hud.show_cell("")
		_hud.hide_forecast()
		_hud.show_unit(null, "", "")
		return
	var hovered: Unit = null
	if _hover_cell != NO_CELL:
		hovered = battle.unit_at(_hover_cell)
	_hud.show_cell(BattleTexts.cell_line(battle, _hover_cell) if _hover_cell != NO_CELL else "")
	_hud.viewer_side = _viewer_side()
	_hud.side_armies = battle.armies
	_update_forecast()

	var shown := hovered if hovered != null else inspected_unit()
	if shown == null:
		shown = selected_unit()
	if shown == null:
		if _ui.inspected_cell != NO_CELL:
			_hud.show_cell_info(BattleTexts.cell_title(battle, _ui.inspected_cell), BattleTexts.cell_body(battle, _ui.inspected_cell))
		else:
			_hud.show_unit(null, "", "")
		return
	if _ui.mode == Mode.SKILL and hovered == null and _ui.inspected_id == 0:
		# スキルの対象を選んでいる間は、使う駒と、スキルの説明を出す（見込みは、予測のパネル）。
		var user := selected_unit()
		var skill := Skills.of(user)
		_hud.show_unit(user, "%s の対象を選んでいる" % skill.display_name(), skill.summary(), false)
		return
	if _ui.menu_hover_id != &"" and selected_unit() != null and hovered == null and _hud.menu_ids().has(_ui.menu_hover_id):
		# メニューの項目にマウスを乗せている間は、その項目を押すと何が起きるかを出す。
		_hud.show_unit(selected_unit(), "", BattleTexts.menu_note(_ui.menu_hover_id, selected_unit()), _ui.menu_hover_id != MENU_SKILL)
		return
	_hud.show_unit(shown, BattleTexts.unit_state(battle, shown), "")


## いまマウスを乗せている対象への行動（攻撃・樽・盾・回復・スキル）と、予測のパネルの見出し。無ければ空の列。
## 自分に使うスキルは、対象が 1 つなので、マウスを乗せなくても出す。
func _hovered_action() -> Array:
	var actor := selected_unit()
	if actor == null or _ui.inspected_id != 0 or _ui.busy or battle.is_over() or _ui.menu_hover_id != &"":
		return []
	if _ui.mode == Mode.SKILL:
		var skill := Skills.of(actor)
		var target := _hover_cell if _skill_cells.has(_hover_cell) else (actor.cell if _is_self_skill(actor) else NO_CELL)
		if target == NO_CELL:
			return []
		return [UseSkillAction.new(actor.id, target), skill.display_name(), target]
	var hovered := battle.unit_at(_hover_cell) if _hover_cell != NO_CELL else null
	var aiming := _ui.mode == Mode.NONE or _ui.mode == Mode.ATTACK
	if hovered != null and aiming and _targets.has(hovered):
		return [AttackAction.new(actor.id, hovered.id), "攻撃", _hover_cell]
	if hovered != null and (_ui.mode == Mode.NONE or _ui.mode == Mode.HEAL) and _heal_targets.has(hovered):
		return [HealAction.new(actor.id, hovered.id), "回復", _hover_cell]
	if aiming and _barrel_targets.has(_hover_cell):
		return [AttackBarrelAction.new(actor.id, _hover_cell), "樽を撃つ（爆発 %d ダメージ）" % MapObject.BLAST_DAMAGE, _hover_cell]
	if aiming and _barricade_targets.has(_hover_cell):
		return [AttackBarricadeAction.new(actor.id, _hover_cell), "盾を攻撃", _hover_cell]
	return []


## 戦闘予測のパネルを、いまの対象で作り直す（中身は Forecast.of をそのまま読む）。対象が無ければ消す。
func _update_forecast() -> void:
	var found := _hovered_action()
	if found.is_empty():
		_hud.hide_forecast()
		_layout.clear_forecast()
		return
	var action: BattleAction = found[0]
	var actor := selected_unit()
	var summary := ForecastText.summarize(battle, Forecast.of(battle, action), actor)
	_hud.show_forecast(found[1], summary)
	# パネルで隠したくないマス: 何かが起きる駒と、効果の及ぶマス（スキルの範囲、樽の爆発）。
	var avoid: Array[Vector2i] = []
	for row in summary.rows:
		var unit := battle.unit_by_id(row.unit_id)
		if unit != null:
			avoid.append(unit.cell)
	if action is UseSkillAction:
		avoid.append_array(Skills.of(actor).affected_cells(battle, actor, found[2]))
	elif action is AttackBarrelAction:
		avoid.append_array(MapObject.blast_cells(battle.board, found[2]))
	_layout.set_forecast(battle, actor, found[2], avoid)


## 戦闘予測のパネルに出している中身（出していなければ空）と、画面に占める四角。検査用。
func forecast_text() -> String:
	return _hud.forecast_text()


func forecast_rect() -> Rect2:
	_layout.place_forecast(battle, selected_unit())
	return _hud.forecast_rect()


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


## 駒の足元の輪（選んでいる駒、見ている駒の印）。
func _build_ring(color: Color, inner: float, outer: float) -> MeshInstance3D:
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = inner
	ring_mesh.outer_radius = outer
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var ring := MeshInstance3D.new()
	ring.mesh = ring_mesh
	ring.material_override = material
	ring.scale = Vector3(1.0, 0.15, 1.0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.visible = false
	add_child(ring)
	return ring
