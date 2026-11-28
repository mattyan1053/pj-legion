extends "res://game/battle_screen/screen_talk.gd"
## 対戦の場面の、誰が動かすか: 相手（CPU か人か）、おまかせ、CPU の番、行動を流して再生する（_do）、決着の戦績。


func _update_time_scale() -> void:
	var scale := time_scale_base
	if context.overlays.pauses():
		scale = 0.0
	else:
		if _cpu_fast:
			scale *= float(settings.value(Settings.CPU_PLAYBACK_SPEED))
		if fast_forward and _watching_other():
			scale *= FAST_FORWARD_SCALE
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
	_hud.set_opponent(Text.t("battle.hud.opponent.cpu") if cpu_opponent else Text.t("battle.hud.opponent.human"))


## 下の帯に「相手」のボタンが出ているか。検査用。
func opponent_switch_shown() -> bool:
	return _hud.opponent_shown()


## 相手を人と CPU で切り替える（F4、下の帯の「相手」のボタン）。切り替えられないなら何もしない。
func toggle_opponent() -> void:
	if source.can_switch_opponent():
		set_opponent(not cpu_opponent)


## 自分の番の残りを CPU に任せる（下の帯の「おまかせ」）。取り消せないので、1 回目は確かめるだけで、もう一度押すと任せる
## （確かめに変わった直後の 2 回目は受けない。ターン終了と同じ）。駒が行動の途中・進化先を選ぶ途中は押せない。
## 任せると、未行動の駒を CPU の考え（相手の CPU と同じもの）で動かし、ターンを終える。そのあいだは相手の番と同じに見るだけ
## （早送り・スキップも効く）。ただし、駒の進化先は人が選ぶ（_auto_running）。
func press_auto() -> void:
	if not _can_auto():
		return
	if not _ui.confirming_auto:
		_ui.start_confirming_auto(Time.get_ticks_msec())
		_refresh()
		return
	if _ui.confirm_guarded(Time.get_ticks_msec()):
		return
	_ui.confirming_auto = false
	_ui.select(0)
	_auto_side = battle.phase
	_run_cpu()


## 「おまかせ」を押せるか: 人の番で、駒が行動の途中でも進化先を選ぶ途中でもないとき。
func _can_auto() -> bool:
	return not is_busy() and not battle.is_over() and battle.phase != Unit.Side.NEUTRAL and not _is_cpu_turn() \
		and battle.acting_unit_id == 0 and battle.evolving_unit() == null


## おまかせを確かめている途中か、いま任されている陣営（無ければ -1）。検査用。
func is_confirming_auto() -> bool:
	return _ui.confirming_auto


func auto_side() -> int:
	return _auto_side


## 「おまかせ」の文字と、押せるか。検査用。
func auto_button_state() -> Array:
	return _hud.auto_button_state()


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
	return await _do_all([action])


## 行動の組を順にルールに渡し、起きたことをまとめて再生する。先頭が断られたら何もしない。途中で断られたら、そこまでを再生する。
## 受け付けられたかを返す（全部が受け付けられたとき真）。
func _do_all(actions: Array[BattleAction]) -> bool:
	var events: Array[BattleEvent] = []
	var accepted := true
	var was_watching := _watching_other()
	_playback.take(battle)  # 再生の盤を、ルールに渡す前の盤から写す（再生は、これと出来事だけで動く）
	for i in actions.size():
		var result := battle.apply(actions[i])
		if not result.accepted:
			if i == 0:
				return false
			push_error("行動の組の途中が断られた: %s" % actions[i])
			accepted = false
			break
		events.append_array(result.events)
	var action: BattleAction = actions[-1]
	_watch_playback = was_watching or _watching_other()
	if _auto_side >= 0 and battle.phase != _auto_side:
		_auto_side = -1  # 任されたターンが終わった
	_update_time_scale()  # 相手の番・中立のフェーズに入ったなら、早送りを効かせる
	stats.feed_all(events)
	_phase_focus.feed(battle, events)  # フェーズの始めにカメラが寄る駒（再生の中の PhaseStartedEvent より前に食わせる）
	_ui.busy = true
	_ui.clear_after_action()
	_board_view.show_cells({})
	_trait_links.clear()  # 駒を選んでいる間だけの印（誓いの線、動かす先の印）は、再生の間は出さない
	_board_view.show_danger([])
	_board_view.show_pinned([])
	_board_view.set_marked(NO_CELL)
	_selection_ring.visible = false
	_inspect_ring.visible = false
	_hud.set_menu([])
	_hud.hide_forecast()
	_hud.set_ult_button(_hud.ult_button_text(), false, _ult_summary())
	_hud.set_end_turn(false, _hud.end_turn_text())
	_hud.hide_evolution()
	if _watching_other():
		# 自分の番を終えた: 再生の間（中立のフェーズから）も、相手の番の表示にする。
		_hud.set_end_turn(false, Text.t("battle.end_turn.foe" if Names.story_sides else "battle.end_turn.cpu"))
		_hud.set_guide([])
	_show_watch_controls()
	await _playback.play_all(events)
	_watch_playback = false
	_ui.busy = false
	if _playback.skipping and not _watching_other():
		# 自分の番が来た（か、決着した）。番の知らせは見せずに済ませたので、ここで出し、カメラを番の始めの位置へ。
		# おまかせの途中で進化先を選ぶために止まったときは、番の途中なので知らせは出さず、進化する駒に寄る。
		_playback.skipping = false
		var waiting := battle.evolving_unit()
		if battle.is_over():
			pass
		elif battle.phase == _auto_side and waiting != null:
			_rig.focus_on(_view(waiting.id).position)
		else:
			_rig.focus_on(_camera_point(battle.phase))
			_hud.show_banner(Text.t("battle.banner.phase", {"turn": battle.turn, "side": _side_name(battle.phase)}), TEAM_COLORS[battle.phase])
	_update_time_scale()
	# 対戦の途中の会話: 起きたことを見せ終えてから出す（演出と重ねない）。決着した行動のあとは出さない（BattleCues が見る）。
	# 送られるまで待つ（その間、次の行動へ進まない）。
	await _say(_cues.on_events(battle, events))

	var evolving := battle.evolving_unit()
	_ui.settle_after_action(
		_is_cpu_turn(),
		evolving.id if evolving != null and not battle.is_over() else 0,
		battle.acting_unit_id,
		action is UndoMoveAction or action is UseUltAction,
	)
	_refresh()
	_run_cpu()
	return accepted


## CPU の番なら、CPU の行動を 1 つずつ、人の操作と同じ入口（_do）に流す。番が終わるか、決着するか、相手を人に切り替えるまで続ける。
## 何をしたか追えるように、駒が動き出す前にカメラを寄せ、1 体の行動が終わるたびに間を置く。
## 動かずに待機するだけの駒は、見せるものが無いので間を置かない。
func _run_cpu() -> void:
	if _ui.cpu_running or _ui.busy or not _is_cpu_turn() or _hud.notice_open():
		return  # 「対戦ルール」を閉じるまでは動かない（閉じたら _open_battle が呼ぶ）
	_ui.cpu_running = true
	_refresh()
	var played_battle := battle
	while battle == played_battle and _is_cpu_turn():
		var action := (_auto_cpu if battle.phase == _auto_side else _cpu).next_action(battle)
		if action == null:
			break
		var unit: Unit = battle.unit_by_id(action.get(&"unit_id")) if &"unit_id" in action else null
		var idle := action is WaitAction and unit != null and not unit.has_moved
		# 設定の「CPU の番の速さ」は、CPU の駒の行動にだけ効かせる（番を終えたあとの中立の番は、ふだんの速さで見せる）。
		set_cpu_fast(not action is EndPhaseAction)
		if unit != null and not unit.has_moved and not idle and not action is EvolveAction and not _playback.skipping:
			_rig.focus_on(_view(unit.id).position)
			await _playback.after(CPU_FOCUS_TIME)
		if not await _do(action):
			break  # CPU の行動は必ず受け付けられるはず。そうでなければ、同じ行動を繰り返さずに手を止める。
		cpu_actions += 1
		if not (action is MoveAction or action is EndPhaseAction or idle or battle.is_over() or _playback.skipping):
			await _playback.after(CPU_PAUSE)
		elif _playback.skipping:
			await get_tree().process_frame  # スキップの途中も、画面（「スキップ中」）が固まらないよう、1 コマずつ進める
		# メニューやログを開いている間は止まる（ふだんは再生の時計が止まって待つ。スキップの途中は待つものが無いので、ここで待つ）。
		while context.overlays.pauses() and is_inside_tree():
			await get_tree().process_frame
	set_cpu_fast(false)
	_ui.cpu_running = false
	if not _watching_other():
		_playback.skipping = false
	# 番の途中で相手を人に切り替えたら、動いたあとの駒を選んだ状態で引き渡す。
	_ui.selected_id = battle.acting_unit_id
	_refresh()


## リザルトの画面に出すもの（result_summary.gd）。draw なら引き分けで、winner は見ない。
## reason_id は決着の理由（GameWonEvent.Reason。引き分けは -1）。ストーリーなら、遊ぶ人の側から書く（「敗北　将が倒れた」）。
func _result_summary(draw: bool, winner: Unit.Side, reason: String, reason_id := -1) -> RefCounted:
	var names: Array[String] = []
	for side: Unit.Side in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
		names.append(_side_name(side))
	var story_line := ""
	if Names.story_sides and not draw and reason_id >= 0:
		story_line = ResultSummary.story_reason(winner == _human_side(), reason_id as GameWonEvent.Reason, reason)
	return ResultSummary.of(stats, draw, winner, reason, cpu_opponent, _human_side(), names, area_name, story_line)
