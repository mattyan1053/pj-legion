extends "res://game/battle_screen/screen_input.gd"
## 対戦の場面に重なるもの: システムメニューと設定、ログ、駒の詳細、ミニマップ、時間の速さ、相手の番の早送りとスキップ。


func _on_system_menu_opened() -> void:
	_log_panel.close()  # ログの上にメニューを重ねない
	_on_overlay_opened()


## システムメニューかログを開いた: 押している途中の操作をやめ、視点の操作と時間を止める。
func _on_overlay_opened() -> void:
	_ui.cancel_press()
	_rig.controls_enabled = false
	_update_time_scale()


## ログを開く（上の帯の「ログ」）。いつでも開ける（CPU の番や再生の途中でも）。システムメニューと同じく、開いている間は時間を止める。
## 対戦設定画面の上では開かない。
func open_log() -> void:
	if context.overlays.is_open() or battle_log == null:
		return
	_hud.hide_banner()
	_log_panel.open(battle_log)


## 駒の情報の枠の「詳細」: 見ている（クリックした）駒か、選んでいる駒のステータスの窓を開く。開いている間は時間を止める。
func open_unit_detail() -> void:
	var unit := _detail_unit()
	if context.overlays.is_open() or unit == null:
		return
	var army: UnitKind.Army = battle.armies[unit.side] if unit.side < battle.armies.size() else UnitKind.Army.NONE
	var sheet: UnitSheet = UnitSheet.of_unit(unit, army, BattleHud.skill_state_text(unit, battle), _look_of(unit))
	sheet.effects = UnitEffects.of(battle, unit)
	_unit_detail.open_sheet(sheet)
	context.play_sound(&"menu_open")
	_on_overlay_opened()


## 駒の情報の枠に「詳細」が出ているか（検査とスクリーンショットの道具用）。
func detail_button_shown() -> bool:
	return _hud.detail_button_shown()


## 駒の詳細の窓（検査とスクリーンショットの道具用）。
func unit_detail() -> UnitDetail:
	return _unit_detail


func _on_unit_detail_closed() -> void:
	if not is_inside_tree():
		return
	_rig.controls_enabled = not context.overlays.pauses()
	_update_time_scale()


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


## ミニマップの上で押した・ドラッグした（point は盤の座標 x / z）: そこを画面の中央にする（すぐに移る。駒を追うのもやめる）。
## 重なる画面（システムメニュー・ログ・対戦設定画面）を開いている間は動かさない（どれもミニマップを覆う）。
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


## ミニマップに描いている、カメラが見ている範囲（ミニマップの中の位置）。検査用。
func minimap_view() -> PackedVector2Array:
	return _hud.minimap().view_on_map()


## システムメニュー（検査とスクリーンショットの道具用）。
func system_menu() -> SystemMenu:
	return _system_menu


## システムメニューの「戻る」の文字（scene_flow.gd の場面の決まり）。
func resume_label() -> String:
	return Text.t("battle.menu_resume.setup") if _setup_panel.visible else Text.t("battle.menu_resume.battle")


## システムメニューに足す項目。対戦設定画面の上で開いたら、「対戦設定へ」は出さない（もう開いている）。
## 渡されたものが対戦設定のパネルを開けないなら、出さない。
func menu_items() -> Array:
	if _setup_panel.visible or not source.can_open_setup():
		return []
	return [[SYSTEM_MATCH_SETUP, Text.t("battle.system.setup"), ""]]


## 抜けると失われるもの（決着していない対戦）があるか。あれば、タイトルへ戻る・ゲームを終える前に確かめる。
func in_progress() -> bool:
	return battle != null and not battle.is_over()


func on_menu_item(id: StringName) -> void:
	if id == SYSTEM_MATCH_SETUP:
		_open_setup_when_ready()


## 重なる画面の積み上げが変わった: 時間を止める画面が開いたら、押している途中の操作と視点の操作をやめて時間を止め、
## 閉じて何も止めていなければ戻す（システムメニュー・ログ・駒の詳細は、それぞれの開く・閉じるでも同じことをする）。
var _overlay_paused := false


func _on_overlays_changed() -> void:
	if not is_inside_tree():
		return
	var paused: bool = context.overlays.pauses()
	if paused != _overlay_paused:
		_overlay_paused = paused
		if paused:
			_ui.cancel_press()
			_rig.controls_enabled = false
		elif not context.overlays.is_open():
			_rig.controls_enabled = true
	_update_time_scale()


func _on_system_menu_closed() -> void:
	_rig.controls_enabled = not context.overlays.pauses()
	_update_time_scale()


## 対戦設定画面を開く。CPU の番や再生の途中なら、それが終わってから開く（対戦の途中で盤面を差し替えないため）。
func _open_setup_when_ready() -> void:
	var played_battle := battle
	if is_busy():
		_hud.show_banner(Text.t("battle.banner.setup_after_cpu") if _ui.cpu_running else Text.t("battle.banner.setup_after_moves"), Color.WHITE)
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


## 早送りを入れる・切る（相手の番の下の帯の「早送り」）。
func toggle_fast_forward() -> void:
	fast_forward = not fast_forward
	_update_time_scale()
	_show_watch_controls()


## 相手の番（と中立のフェーズ）の残りを、見せずに済ませる（下の帯の「スキップ」）。自分の番が来るまで続く。
## 起きたことはログに残る。対戦の途中の台詞が出たら、そこで止まって送られるのを待つ（検査では、ログにだけ残す）。途中で決着したら、決着を見せる。
func skip_watching() -> void:
	if not _watching_other() or not (_ui.busy or _ui.cpu_running) or _playback.skipping:
		return
	_playback.skipping = true
	_talk.clear()
	_show_watch_controls()


## 下の帯の「スキップ」を押す（クリックと同じ道）。押せたかを返す。検査用。
func press_skip() -> bool:
	return _hud.press_skip()


## スキップしている途中か。検査用。
func is_skipping() -> bool:
	return _playback.skipping


## 下の帯の早送り・スキップのボタン: [出ているか, 早送りが入っているか]。検査用。
func watch_controls_state() -> Array[bool]:
	return _hud.watch_controls_state()
