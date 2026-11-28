extends "res://tools/shots/battle_scenes.gd"
## スクリーンショットの場面: 対戦の見込みと情報（メニューの項目の説明、戦闘予測、回復役、駒の情報、スキルと必殺技、中ボス）、決着の画面（手で作ったマップの決着も）とログ、攻撃の当たり方のコマ。


func _scene_versus_hand_result() -> bool:
	_field = _first_hand_field()
	if _field == &"":
		return false
	_new_battle()
	return await _cpu_result(true)


func _scene_menu_note() -> bool:
	if not await _scene_skill():
		return false
	_scene.press_skill()  # 対象を選ぶのをやめて、メニューへ戻る
	_scene.hover_menu_item(&"skill")
	return _scene.menu_ids().has(&"skill")


func _scene_forecast_attack() -> bool:
	if not await _scene_menu_moved():
		return false
	var mover: Unit = _scene.selected_unit()
	var target := _battle.unit_by_id(_battle.options(mover.id).attack_target_ids[0])
	_scene.hover(target.cell)
	return _scene.forecast_text() != ""


## 行動できる自分の駒が、いまの位置から倒せる相手（[駒, 相手]）。無ければ空。
func _defeat_now() -> Array:
	for unit in _own_units():
		if not _battle.can_act(unit):
			continue
		for target_id in _battle.options(unit.id).attack_target_ids:
			if Forecast.of(_battle, AttackAction.new(unit.id, target_id)).defeated_ids().has(target_id):
				return [unit, _battle.unit_by_id(target_id)]
	return []


func _scene_forecast_defeat() -> bool:
	if not _advance(func() -> bool: return _battle.phase != Unit.Side.NEUTRAL and not _defeat_now().is_empty()):
		return false
	var found := _defeat_now()
	_show()
	_scene.click_cell(found[0].cell)
	_look_at(BoardView.cell_center(found[1].cell))
	_scene.hover(found[1].cell)
	return _scene.forecast_text().contains("倒せる")


## 行動できる自分の駒が、スキルで相手を 2 体以上巻き込めるマス（[駒, マス]）。無ければ空。
func _skill_hits() -> Array:
	for unit in _own_units():
		if not _battle.can_act(unit):
			continue
		for cell in _battle.options(unit.id).skill_cells:
			var forecast := Forecast.of(_battle, UseSkillAction.new(unit.id, cell))
			var hits := 0
			for outcome in forecast.units:
				if outcome.hits > 0:
					hits += 1
			if hits >= 2:
				return [unit, cell]
	return []


func _scene_forecast_skill() -> bool:
	if not _advance(func() -> bool: return _battle.phase != Unit.Side.NEUTRAL and not _skill_hits().is_empty()):
		return false
	var found := _skill_hits()
	_show()
	_scene.click_cell(found[0].cell)
	_scene.press_skill()
	_look_at(BoardView.cell_center(found[1]))
	_scene.hover(found[1])
	return _scene.is_choosing_skill_target() and _scene.forecast_text() != ""


## 1 コマ進めてから、再生が終わるまで待つ。
func _idle() -> void:
	await get_tree().process_frame
	while _scene.is_busy():
		await get_tree().process_frame


## 自動の対戦の場面 inspection と同じ盤と駒で、既定のカメラの向きのまま攻撃の予測を出す（メニューと予測のパネルが近くに並ぶ）。
func _scene_forecast_small() -> bool:
	var board := Board.new(Vector2i(9, 5))
	board.hq_cells = [Vector2i(0, 4), Vector2i(8, 0)]
	_battle = Battle.new(board)
	_battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER1, Vector2i(0, 4))
	_battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER2, Vector2i(8, 0))
	var trooper := _battle.add_unit(UnitKind.Id.SHIELD_TROOPER, Unit.Side.PLAYER1, Vector2i(1, 2))
	_battle.add_unit(UnitKind.Id.SNIPER, Unit.Side.PLAYER2, Vector2i(7, 2))
	var foe := _battle.add_unit(UnitKind.Id.COMMANDO, Unit.Side.PLAYER2, Vector2i(4, 2))
	_battle.add_unit(UnitKind.Id.MINION, Unit.Side.NEUTRAL, Vector2i(5, 4))
	_stats = BattleStats.new(_battle)
	_show()
	# 自動の対戦の inspection と同じ順に: 動いて取り消してから、相手の隣へ動き、メニューの「攻撃」で相手を選び始める。
	await _idle()
	_scene.click_cell(trooper.cell)
	_scene.click_cell(Vector2i(2, 2))
	await _idle()
	_scene.cancel()  # 移動を取り消す
	await _idle()
	_scene.click_cell(Vector2i(3, 2))
	await _idle()
	if trooper.cell != Vector2i(3, 2):
		return false
	# カメラが寄り終わってから、メニューの「攻撃」とマウスを乗せるのを同じコマで（メニューが縮んで動いても、カメラは止まっている）。
	for i in 120:
		await get_tree().process_frame
	if not _scene.press_menu(&"attack"):
		return false
	_scene.hover(foe.cell)
	return _scene.forecast_text() != ""


func _scene_forecast_heal() -> bool:
	var healer := func() -> Unit:
		for unit in _own_units():
			if _battle.can_act(unit) and not Queries.heal_targets(_battle, unit).is_empty():
				return unit
		return null
	if not _advance(func() -> bool: return _battle.phase != Unit.Side.NEUTRAL and healer.call() != null):
		return false
	_show()
	var unit: Unit = healer.call()
	var target: Unit = Queries.heal_targets(_battle, unit)[0]
	_scene.click_cell(unit.cell)
	_look_at(BoardView.cell_center(target.cell))
	_scene.hover(target.cell)
	return _scene.forecast_text() != ""


## 行動できる自分の回復役と、動けば敵を攻撃できるマス（[回復役, マス]。その場でもよい）。回復もできるマスを先に選ぶ。無ければ空。
func _healer_strike() -> Array:
	var fallback := []
	for unit in _own_units():
		if not _battle.can_act(unit) or UnitKind.role(unit.kind) != UnitKind.Role.HEALER:
			continue
		for cell: Vector2i in _battle.options(unit.id).move_cells:
			var trial := _battle.clone()
			if cell != unit.cell:
				trial.apply(MoveAction.new(unit.id, cell, false))
			var options := trial.options(unit.id)
			if options.attack_target_ids.is_empty():
				continue
			if not options.heal_target_ids.is_empty():
				return [unit, cell]
			if fallback.is_empty():
				fallback = [unit, cell]
	return fallback


## 回復役を敵の届くマスへ動かし、メニュー（攻撃・回復）を出す。動かした回復役を返す（作れなければ null）。
func _healer_menu() -> Unit:
	if not _advance(func() -> bool: return _battle.phase != Unit.Side.NEUTRAL and not _healer_strike().is_empty()):
		return null
	var found := _healer_strike()
	var unit: Unit = found[0]
	_show()
	_scene.click_cell(unit.cell)
	if found[1] != unit.cell:
		await _scene.act(MoveAction.new(unit.id, found[1], false))
	_scene.focus_camera(unit.cell)
	return unit if _scene.menu_ids().has(&"attack") else null


func _scene_healer_menu() -> bool:
	return await _healer_menu() != null


func _scene_healer_attack() -> bool:
	var unit: Unit = await _healer_menu()
	if unit == null or not (_scene.press_menu(&"attack") and _scene.is_choosing_target()):
		return false
	var target: Unit = _battle.unit_by_id(_battle.options(unit.id).attack_target_ids[0])
	_look_at(BoardView.cell_center(target.cell))
	_scene.hover(target.cell)
	return _scene.forecast_text() != ""


func _scene_battle_unit_detail() -> bool:
	# 傷ついていて、経験値も入っている、人の軍の駒。
	var hurt := func() -> Unit:
		for unit in _own_units():
			if unit.hp < unit.max_hp() and unit.experience > 0 and Skills.of(unit) != null:
				return unit
		return null
	if not _advance(func() -> bool: return hurt.call() != null):
		return false
	_show()
	var unit: Unit = hurt.call()
	_look_at(BoardView.cell_center(unit.cell))
	_scene.click_cell(unit.cell)
	if not _scene.detail_button_shown():
		return false
	_scene.open_unit_detail()
	return _scene.unit_detail().visible


func _scene_info_status() -> bool:
	if not _advance(func() -> bool: return Ults.can_use(_battle)):
		return false
	_show()
	await _scene.act(UseUltAction.new())
	# 装備を持っている駒（無ければ、将でない駒）を見る。
	var best: Unit = null
	for unit in _battle.units:
		if unit.side == _battle.phase and unit.kind != UnitKind.Id.KING and (best == null or unit.equipment.size() > best.equipment.size()):
			best = unit
	if best == null:
		return false
	_look_at(BoardView.cell_center(best.cell))
	_scene.hover(best.cell)
	return not Statuses.types_of(best).is_empty()


## 自分の回復役にマウスを乗せた、駒の情報（名前の右に「攻撃 4」）。
func _scene_info_healer() -> bool:
	var healer := func() -> Unit:
		for unit in _own_units():
			if UnitKind.role(unit.kind) == UnitKind.Role.HEALER:
				return unit
		return null
	if not _advance(func() -> bool: return _battle.turn >= 2 and healer.call() != null):
		return false
	_show()
	var unit: Unit = healer.call()
	_look_at(BoardView.cell_center(unit.cell))
	_scene.hover(unit.cell)
	return true


func _scene_skill() -> bool:
	var ready := func() -> Unit:
		for unit in _own_units():
			if _battle.can_act(unit) and not Queries.skill_cells(_battle, unit).is_empty():
				return unit
		return null
	if not _advance(func() -> bool: return _battle.turn >= 2 and ready.call() != null):
		return false
	_show()
	var unit: Unit = ready.call()
	_scene.click_cell(unit.cell)
	_scene.press_skill()
	_scene.focus_camera(unit.cell)
	return _scene.is_choosing_skill_target()


func _scene_ult() -> bool:
	if not _advance(func() -> bool: return Ults.can_use(_battle)):
		return false
	_show()
	_scene.press_ult()
	return _scene.is_confirming_ult()


func _scene_end_confirm() -> bool:
	if not _advance(func() -> bool: return _battle.turn >= 3 and _battle.phase == Unit.Side.PLAYER1):
		return false
	_show()
	_scene.press_end_turn()
	return _scene.is_confirming_end()


func _scene_mid_boss() -> bool:
	# 中ボスが倒れたあとの、倒した陣営の番の始め（上の帯に聖遺物が出る）。残っている中ボスを選んで寄せる。
	var slain: Array[MidBossDefeatedEvent] = []
	var watch := func(events: Array[BattleEvent]) -> void:
		for event in events:
			if event is MidBossDefeatedEvent and slain.is_empty():
				slain.append(event)
	if not _advance(func() -> bool: return not slain.is_empty() and _battle.phase == slain[0].slayer_side, watch):
		return false
	_show()
	var focus := slain[0].cell
	for cell in _battle.board.mid_boss_cells:
		var boss := _battle.unit_at(cell)
		if boss != null and boss.side == Unit.Side.NEUTRAL:
			_scene.click_cell(cell)
			focus = cell
	_scene.focus_camera(focus)
	return true


## 決着する行動の手前まで進め、その行動だけを画面に通す（決着の演出と戦績が出る）。hold が 0 以上なら、リザルトの演出をその秒で止める。
## 負ならリザルトの演出を飛ばして、全部を出す。
func _finish_battle(hold: float) -> bool:
	if _advance(func() -> bool: return false):
		return false  # 決着しなかった
	var action := _cpu.next_action(_battle)
	_show()
	_scene.stats = _stats  # 始めからの戦績
	await _scene.act(action)
	if not _battle.is_over():
		return false
	var screen: Control = _scene.result_screen()
	if hold >= 0.0:
		await screen.hold_at(hold)
	else:
		screen.skip()
	return true


func _scene_result_headline() -> bool:
	return await _finish_battle(0.6)


func _scene_result_stats() -> bool:
	return await _finish_battle(1.95)


func _scene_result_mvp() -> bool:
	return await _finish_battle(2.55)


func _scene_result() -> bool:
	return await _finish_battle(-1.0)


func _scene_result_detail() -> bool:
	if not await _finish_battle(-1.0):
		return false
	_scene.result_screen().toggle_detail()
	return true


## CPU 戦のリザルト。won なら人が勝った側（VICTORY）、そうでなければ負けた側（DEFEAT）を人として出し直す。
func _cpu_result(won: bool) -> bool:
	if not await _finish_battle(-1.0):
		return false
	var screen: Control = _scene.result_screen()
	var human := _battle.winner as Unit.Side if won else (1 - _battle.winner) as Unit.Side
	var names: Array[String] = []
	for side: Unit.Side in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
		names.append(Names.side(side) if side == human else Text.t("battle.side_cpu", {"color": Names.side_word(side)}))
	var reason: String = screen.shown_summary().reason  # 人どうしの理由（決着の理由だけ）
	var summary: RefCounted = ResultSummary.of(_stats, false, _battle.winner, reason, true, human, names, VersusFields.title_of(_field))
	screen.present(summary)
	screen.skip()
	return true


func _scene_result_victory() -> bool:
	return await _cpu_result(true)


func _scene_result_defeat() -> bool:
	return await _cpu_result(false)


## 終えた 1 局のリプレイ。CPU どうしで決着まで進めて（行動を控える）、決着の画面の「もう一度見る」から、ターン 4 の頭まで飛んで止める。
func _scene_replay() -> bool:
	var start := _battle.clone()
	var actions: Array[BattleAction] = []
	for i in MAX_ACTIONS:
		var action := _cpu.next_action(_battle)
		if action == null:
			return false
		var trial := _battle.clone()
		trial.apply(action)
		actions.append(action)
		if trial.is_over():
			break
		var result := _battle.apply(action)
		_stats.feed_all(result.events)
		_log.feed_all(result.events)
	if not await _finish_battle(-1.0):
		return false
	_scene.use_record(start, actions)
	_scene.start_replay()
	_scene.toggle_replay_pause()
	for i in 3:
		_scene.replay_turn(1)
		await get_tree().process_frame
	if _scene.battle.turn != 4:
		return false
	_scene.toggle_threat()
	for unit: Unit in _scene.battle.units:
		if unit.side == Unit.Side.PLAYER2 and unit.kind != UnitKind.Id.KING:
			_scene.hover(unit.cell)
			break
	await _camera_still()
	return _scene.is_replaying()


## 相手（CPU）の番と中立のフェーズのあと（ターン 5 の自分の番の始め）。始めからのログを画面に渡す。
func _after_cpu_turn() -> bool:
	if not _advance(func() -> bool: return _battle.turn >= 5 and _battle.phase == Unit.Side.PLAYER1):
		return false
	_show()
	_scene.battle_log = _log
	return true


func _scene_log_closed() -> bool:
	return _after_cpu_turn()


func _scene_log_open() -> bool:
	if not _after_cpu_turn():
		return false
	_scene.open_log()
	return true


func _scene_log_chosen() -> bool:
	if not _after_cpu_turn():
		return false
	_scene.open_log()
	# 相手の番の、いちばん最後の攻撃の行を押す。
	for i in range(_log.entries.size() - 1, -1, -1):
		var entry: BattleLog.Entry = _log.entries[i]
		if entry.phase == Unit.Side.PLAYER2 and entry.text.contains("を攻撃"):
			_scene.log_panel().choose(i)
			return true
	return false


func _scene_log_long() -> bool:
	if _advance(func() -> bool: return false):
		return false  # 決着しなかった
	_show()
	_scene.battle_log = _log
	var started := Time.get_ticks_usec()
	_scene.open_log()
	print("screenshots: ログ %d 行（ターン %d）を %.1f ms で並べた" % [_log.entries.size(), _battle.turn, (Time.get_ticks_usec() - started) / 1000.0])
	await get_tree().process_frame
	await get_tree().process_frame
	var panel: Node = _scene.log_panel()
	panel.scroll_to(panel.scroll_max() - 1500)
	return true


## kinds のどれかの駒が、動かずに攻撃できる場面まで進め、その攻撃を始めて、当たる瞬間から after 秒あとに撮る
## （負なら、当たる前）。カメラは寄せて、相手を真ん中に置く。
func _attack_frame(kinds: Array, after: float) -> bool:
	var find := func() -> Array:
		if _battle.phase == Unit.Side.NEUTRAL:
			return []
		for unit in _own_units():
			if kinds.has(unit.kind) and _battle.can_act(unit):
				var targets := _battle.options(unit.id).attack_target_ids
				if not targets.is_empty():
					return [unit, _battle.unit_by_id(targets[0])]
		return []
	if not _advance(func() -> bool: return not find.call().is_empty()):
		return false
	var found: Array = find.call()
	var unit: Unit = found[0]
	var target: Unit = found[1]
	_show()
	await _settle_camera(target.cell)
	_park_mouse()
	_scene.set_time_scale_base(SLOW_MOTION)
	_scene.act(AttackAction.new(unit.id, target.id))
	await get_tree().create_timer(0.4 + after).timeout  # 0.4 は、攻撃の動きを始めてから当たるまで（unit_view.gd の play_attack）
	_mid_animation = true
	return true


## 番の知らせが消え、カメラが cell に寄り終わるまで待つ（演出の途中を撮る場面の下ごしらえ）。
func _settle_camera(cell: Vector2i) -> void:
	_aim(13.0, 20.0, OrbitCamera.DEFAULT_PITCH)
	_scene.focus_camera(cell)
	await get_tree().create_timer(SETTLE).timeout
	await _banner_gone()
