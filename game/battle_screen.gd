extends "res://game/battle_screen/screen_overlays.gd"
## 対戦の場面（俯瞰 3D の盤面と、操作・演出）。ルール（rules/）につないで、1 人で CPU と、または 2 人が 1 台で交代しながら対戦する。
## 場面の決まり（context、finished、システムメニューの項目）は scene_flow.gd。
## 対戦は、渡された「対戦設定を作ってくれるもの」（battle_source.gd。流れ（run.gd）が渡す。無ければ context.match_choice）から作る。
## どのモードの対戦かは知らない。やり直し・マップの替え・相手の切り替え・対戦設定のパネルは、それに聞いてから出す。
##
## 相手（プレイヤー2）を CPU にすると、その番は CpuPlayer が返す行動を、人の操作と同じ入口（_do）に 1 つずつ流す。
## ここはルールを持たない。操作を行動（BattleAction）にして Battle.apply() に渡し、
## 返ってきたイベントを順に再生するだけ。選べることはルールの問い合わせ（Battle.options）で出す。
## 盤面・駒・ライト・カメラ・文字はすべてコードで組み立てる。
##
## ここは、組み立て（_ready）と、毎フレームのこと（_process）だけ。役割ごとのファイル（game/battle_screen/screen_*.gd）:
## 選べる決まりの見え方（screen_rules_view）、表示の作り直し（screen_refresh）、途中の会話（screen_talk）、
## 誰が動かすかと行動の再生（screen_sides）、対戦の始まり（screen_start）、操作（screen_input）、重なる画面（screen_overlays）。
## 読み込み・調整値・状態の変数と小さな道具は screen_base。ファイルは screen_base.gd からこの順に継いで積み重なり、
## このファイルが最後（前のファイルは、後のファイルの関数を呼べない。呼ばれる側を前に置く）。


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
	_hud.range_colors = {
		&"move": COLOR_MOVE, &"cruise": COLOR_CRUISE, &"attack": COLOR_TARGET, &"heal": COLOR_HEAL,
		&"reach": COLOR_INSPECT, &"threat": COLOR_THREAT, &"pin": BoardView.COLOR_PIN_EDGE,
	}
	_playback = BattlePlayback.new()
	add_child(_playback)
	_playback.setup(self, _views, _rig, _hud, _effects, _ui, TEAM_COLORS, played, camera_follows)
	if battle != null:
		_playback.take(battle)
	_playback.refresh_status = _refresh_status
	_playback.side_name = _side_name
	_playback.result_summary = _result_summary
	_playback.camera_point = _camera_point
	_playback.cpu_side = func() -> Unit.Side: return _auto_side if _auto_side >= 0 else source.cpu_side()
	_playback.play_sound = func(name: StringName) -> void: context.play_sound(name)
	_playback.frame_passed = frame_passed
	_playback.sync_views = _sync_views
	_layout = PanelLayout.new(_rig, _hud, _views, COLOR_MOVE, COLOR_CRUISE)
	_hud.menu_pressed.connect(_on_menu_pressed)
	_hud.menu_hovered.connect(_on_menu_hovered)
	_hud.ult_pressed.connect(press_ult)
	_hud.end_turn_pressed.connect(press_end_turn)
	_hud.restart_pressed.connect(_on_restart_pressed)
	_hud.evolution_chosen.connect(choose_evolution)
	_hud.opponent_pressed.connect(toggle_opponent)
	_hud.threat_toggled.connect(toggle_threat)
	_hud.fast_forward_toggled.connect(toggle_fast_forward)
	_hud.skip_pressed.connect(skip_watching)
	_hud.auto_pressed.connect(press_auto)
	_hud.pin_toggled.connect(func() -> void: toggle_pin(_ui.inspected_id))
	_hud.log_pressed.connect(open_log)
	_hud.detail_pressed.connect(open_unit_detail)
	_hud.setup_pressed.connect(func() -> void: finished.emit(&"setup"))
	_hud.title_pressed.connect(func() -> void: finished.emit(source.leave()[0]))  # 決着の画面の、流れの外への行き先
	_hud.result_screen().continue_pressed.connect(func() -> void: finished.emit(Run.NEXT))
	_hud.result_screen().squad_pressed.connect(func() -> void: finished.emit(Run.PREVIOUS))
	_hud.result_shown.connect(_on_result_shown)
	_hud.minimap().pointed.connect(_on_minimap_pointed)
	_hud.result_screen().overlays = context.overlays
	_hud.result_screen().play_sound = func(name: StringName) -> void: context.play_sound(name)
	_talk = BattleTalk.new()
	_talk.waiting = _hud.is_banner_shown
	# 遊ぶときは、台詞を送られるまで出したままにし、その間は盤を止める（検査とスクリーンショットは、数秒で消す）。
	_talk.hold = context.checking == &""
	_hud.add_talk_card(_talk)
	# 台詞を送られるのを待つ間、帯のボタンや盤へのクリックを受け止めて、台詞を送る（システムメニューのボタンは、上の層なので押せる）。
	_talk_catcher = Control.new()
	_talk_catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_talk_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_talk_catcher.visible = false
	_talk_catcher.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			advance_talk())
	_hud.add_child(_talk_catcher)
	_setup_panel = MatchSetupPanel.new()
	_hud.add_child(_setup_panel)
	_setup_panel.setup(TEAM_COLORS, context.decks, context.overlays)
	_setup_panel.visible = false
	_setup_panel.start_pressed.connect(_on_setup_chosen)
	_setup_panel.cancelled.connect(_refresh)
	_setup_panel.map_pressed.connect(func(choice: RefCounted) -> void:
		context.match_choice = choice
		finished.emit(&"map_select"))
	_log_panel = LogPanel.new()
	add_child(_log_panel)
	_log_panel.setup(TEAM_COLORS, context.overlays)
	_log_panel.opened.connect(_on_overlay_opened)
	_log_panel.closed.connect(_on_log_closed)
	_log_panel.entry_chosen.connect(_on_log_entry_chosen)
	_log_panel.opened.connect(func() -> void: context.play_sound(&"menu_open"))
	_log_panel.closed.connect(func() -> void: context.play_sound(&"menu_close"))
	_unit_detail = UnitDetail.new()
	_unit_detail.pausing = true
	_hud.add_child(_unit_detail)
	_unit_detail.setup(context.overlays)
	_unit_detail.closed.connect(_on_unit_detail_closed)

	settings = context.settings
	settings.changed.connect(_on_setting_changed)
	_apply_settings()
	_system_menu = context.system_menu
	_system_menu.opened.connect(_on_system_menu_opened)
	_system_menu.closed.connect(_on_system_menu_closed)
	# 時間を止める重なる画面（ウィンドウを閉じる前の確かめなど、この場面が開いたのでないものも）が開いた・閉じたら、止めるか見直す。
	context.overlays.changed.connect(_on_overlays_changed)

	# 流れが渡すもの。流れの外から置かれた（スクリーンショットの道具など）なら、対戦設定の場面で選んだもの。
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
	Names.story_sides = false
	Names.story_names = ["", ""]
	Names.story_shorts = ["", ""]


func _process(delta: float) -> void:
	# カメラが動くとマウスの下のマスも変わるので、マウスの動きではなく毎フレーム追う（メニューの後ろでは追わない）。
	if not context.overlays.pauses() and not _hud.notice_open():
		_update_hover()  # 「対戦ルール」の後ろでも追わない（札の下に予測やマスの説明を出さない）
	var focus_cells: Array[Vector2i] = []
	for view: UnitView in _views.values():
		focus_cells.append(BoardView.cell_of(view.position))
	if battle.board.in_bounds(_hover_cell):
		focus_cells.append(_hover_cell)
	_board_view.update_occlusion(_rig.camera, _rig.global_position, focus_cells, delta)
	_place_minimap()
	_layout.place_menu(selected_unit(), _painted)
	_layout.place_forecast(battle, selected_unit())
	frame_passed.emit()
