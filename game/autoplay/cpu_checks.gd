extends "res://game/autoplay/setup_checks.gd"
## 自動の対戦の場面: CPU の番（止める、ログ、カメラ）、自分の番のおまかせ、相手の番の早送りとスキップ。


## 相手を CPU にして、ターンを終える。CPU が自分の番を進め（回復役が回復し、戦う駒が攻撃する）、こちらの番に戻る。
func _queue_cpu_scene() -> void:
	var board := _small_board(Vector2i(8, 5))
	var battle := Battle.new(board)
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER1, Vector2i(0, 4))
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER2, Vector2i(7, 0))
	var bait := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, Unit.Side.PLAYER1, Vector2i(3, 2))
	var sorcerer := battle.add_unit(UnitKind.Id.SORCERER, Unit.Side.PLAYER2, Vector2i(6, 2))
	var priest := battle.add_unit(UnitKind.Id.PRIEST, Unit.Side.PLAYER2, Vector2i(7, 2))
	var wounded := battle.add_unit(UnitKind.Id.PALADIN, Unit.Side.PLAYER2, Vector2i(6, 1))
	wounded.hp = 10
	var seen := {"actions": 0}

	_scripted.append(func() -> void:
		_scene.set_opponent(true)
		_scene.start_with(battle, StageLook.GRASSLAND, 1))
	_scripted.append(func() -> void:
		seen["actions"] = _scene.cpu_actions
		_scene.camera_follows.clear()
		_end_turn()
		# CPU の番の間は、操作を受け付けない。
		_scene.click_cell(sorcerer.cell)
		_expect(_scene.selected_unit() == null, "CPU の番に駒を選べた")
		_scene.press_end_turn()
		# 相手の番の途中でもシステムメニューは開け、開いている間は止まる（閉じると続きから進む）。
		_scene.press_escape()
		_expect(_scene.system_menu().is_open() and Engine.time_scale == 0.0, "相手の番の途中に、システムメニューで止まらない")
		seen["paused"] = _scene.cpu_actions
		get_tree().create_timer(0.3, true, false, true).timeout.connect(func() -> void:
			_expect(_scene.cpu_actions == seen["paused"] and battle.phase != Unit.Side.PLAYER1, "システムメニューを開いている間に、相手の番が進んだ")
			_scene.system_menu().close()
			# ログも、相手の番の途中に開け、開いている間は止まる。
			_scene.open_log()
			var panel: Node = _scene.log_panel()
			_expect(panel.is_open() and Engine.time_scale == 0.0 and _scene.is_busy(), "相手の番の途中に、ログで止まらない")
			seen["paused"] = _scene.cpu_actions
			get_tree().create_timer(0.3, true, false, true).timeout.connect(func() -> void:
				_expect(_scene.cpu_actions == seen["paused"], "ログを開いている間に、相手の番が進んだ")
				panel.choose(panel.first_row() + panel.row_count() - 1)
				panel.close())))
	_scripted.append(func() -> void:
		_expect(battle.turn == 2 and battle.phase == Unit.Side.PLAYER1, "CPU が自分の番を終えなかった")
		_expect(_scene.cpu_actions > seen["actions"], "CPU が行動しなかった")
		_expect(wounded.hp == 10 + priest.power(), "CPU の回復役が回復しなかった")
		_expect(bait.hp < bait.max_hp(), "CPU の駒が攻撃しなかった")
		# CPU の駒が歩く間は、カメラが追いかける（自分で動かした駒は追わない）。
		var followed := 0
		for unit_id: int in _scene.camera_follows:
			var unit := battle.unit_by_id(unit_id)
			_expect(unit == null or unit.side == Unit.Side.PLAYER2, "CPU のものでない駒を、カメラが追った")
			followed += 1
		_expect(followed > 0, "CPU の駒が歩く間、カメラが追わなかった")
		# CPU がしたことは、ログで読める。
		var cpu_lines := 0
		for entry: RefCounted in _scene.battle_log.entries:
			if entry.side == Unit.Side.PLAYER2 and not entry.header:
				cpu_lines += 1
		_expect(cpu_lines >= 2, "CPU の番に起きたことが、ログに無い")
		_scene.open_log()
		var panel: Node = _scene.log_panel()
		_expect(panel.first_row() + panel.row_count() == _scene.battle_log.entries.size(), "ログの画面の行が、ログの最新まで並んでいない")
		_scene.log_panel().close()
		_scene.set_opponent(false))


## 自分の番のおまかせ。人どうしの対戦で、プレイヤー1 の番を任せる。1 回目と、確かめた直後の 2 回目では任せず、
## 右クリックでやめられる。任せると、未行動の駒を CPU が動かしてターンを終え、プレイヤー2（人）の番で止まる。
func _queue_auto_turn_scene() -> void:
	var board := _small_board(Vector2i(8, 5))
	var battle := Battle.new(board)
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER1, Vector2i(0, 4))
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER2, Vector2i(7, 0))
	var mine := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, Unit.Side.PLAYER1, Vector2i(2, 3))
	var foe := battle.add_unit(UnitKind.Id.SORCERER, Unit.Side.PLAYER2, Vector2i(4, 2))

	_scripted.append(func() -> void:
		_scene.set_opponent(false)
		_scene.start_with(battle, StageLook.GRASSLAND, 1))
	_scripted.append(func() -> void:
		_expect(_scene.auto_button_state() == ["おまかせ", true], "自分の番に「おまかせ」が押せない")
		_scene.press_auto()
		_expect(_scene.is_confirming_auto() and _scene.auto_side() == -1, "1 回目で任せた（か、確かめにならない）")
		_scene.press_auto()
		_expect(_scene.auto_side() == -1, "確かめた直後の 2 回目で任せた")
		_scene.cancel()
		_expect(not _scene.is_confirming_auto(), "右クリックで、おまかせの確かめをやめない")
		_scene.press_auto()
		_scene.pass_confirm_guard()
		_scene.press_auto()
		_expect(_scene.auto_side() == Unit.Side.PLAYER1 and _scene.is_busy(), "2 回目で任せなかった")
		_expect(_scene.watch_controls_state()[0], "任せている間に、早送り・スキップが出ない"))
	_scripted.append(func() -> void:
		_expect(battle.phase == Unit.Side.PLAYER2 and _scene.auto_side() == -1, "任せたターンが終わらなかった（か、次の番も任せた）")
		_expect(mine.has_moved or mine.acted or foe.hp < foe.max_hp() or mine.cell != Vector2i(2, 3), "任せた駒が何もしなかった")
		_expect(not _scene.is_busy() and _scene.auto_button_state()[1], "人の番（プレイヤー2）で止まらなかった"))

	# 任せた側の駒が上限のレベルに届いたら、CPU は止まり、進化先は人が選ぶ。選ぶと、残りを CPU が続けてターンを終える。
	var board2 := _small_board(Vector2i(6, 4))
	var battle2 := Battle.new(board2)
	battle2.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER1, Vector2i(0, 3))
	battle2.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER2, Vector2i(5, 0))
	var paladin := battle2.add_unit(UnitKind.Id.PALADIN, Unit.Side.PLAYER1, Vector2i(2, 2))
	paladin.level = Growth.MAX_LEVEL - 1
	paladin.experience = Growth.EXPERIENCE_PER_LEVEL - Growth.HIT_EXPERIENCE
	battle2.add_unit(UnitKind.Id.SHIELD_TROOPER, Unit.Side.PLAYER2, Vector2i(3, 2))
	_scripted.append(func() -> void: _scene.start_with(battle2, StageLook.GRASSLAND, 1))
	_scripted.append(func() -> void:
		_scene.press_auto()
		_scene.pass_confirm_guard()
		_scene.press_auto()
		_expect(_scene.auto_side() == Unit.Side.PLAYER1, "2 回目で任せなかった"))
	_scripted.append(func() -> void:
		_expect(battle2.phase == Unit.Side.PLAYER1 and battle2.evolving_unit() == paladin, "おまかせの途中で、進化先を選ぶ前に進んだ（か、上限に届かなかった）")
		_expect(paladin.evolution == Evolution.Id.NONE and _scene.is_choosing_evolution(), "おまかせの途中で、進化先を CPU が選んだ")
		_scene.choose_evolution(1))
	_scripted.append(func() -> void:
		_expect(paladin.evolution == Evolution.Id.CRUSADER, "選んだ進化先にならなかった")
		_expect(battle2.phase == Unit.Side.PLAYER2 and _scene.auto_side() == -1, "進化先を選んだあと、おまかせの続きを進めなかった"))


## 相手（CPU）の番の早送りとスキップ。人がターンを終えると、中立のフェーズから相手の番が見ているだけの番になり、
## 下の帯に「早送り」「スキップ」が出る。スキップすると、自分の番が来るまで見せずに進み、盤の見た目は状態と同じになる。
## 2 局目は、スキップの途中で CPU が人の将を倒して決着し、決着の画面が出る。
func _queue_cpu_skip_scene() -> void:
	var board := _small_board(Vector2i(8, 5))
	var battle := Battle.new(board)
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER1, Vector2i(0, 4))
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER2, Vector2i(7, 0))
	var bait := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, Unit.Side.PLAYER1, Vector2i(3, 2))
	battle.add_unit(UnitKind.Id.SORCERER, Unit.Side.PLAYER2, Vector2i(6, 2))
	battle.add_unit(UnitKind.Id.COMMANDO, Unit.Side.PLAYER2, Vector2i(6, 3))
	battle.add_unit(UnitKind.Id.MINION, Unit.Side.NEUTRAL, Vector2i(3, 4))
	var lost := Battle.new(_small_board(Vector2i(8, 5)))
	var doomed := lost.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER1, Vector2i(3, 2))
	doomed.hp = 1
	lost.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER2, Vector2i(7, 0))
	lost.add_unit(UnitKind.Id.COMMANDO, Unit.Side.PLAYER2, Vector2i(5, 2))
	var seen_lines := {}

	_scripted.append(func() -> void:
		# 前の場面が相手の番で終わっていても、CPU に引き取らせないよう、先に始め直してから相手を CPU にする。
		_scene.start_with(battle, StageLook.GRASSLAND, 1)
		_scene.set_opponent(true))
	_scripted.append(func() -> void:
		_expect(not _scene.watch_controls_state()[0], "自分の番に、早送り・スキップが出ている")
		var lines_before: int = _scene.battle_log.entries.size()
		_end_turn()  # 中立のフェーズを再生している途中
		_expect(_scene.watch_controls_state()[0], "相手の番（中立のフェーズ）に、早送り・スキップが出ない")
		var normal := Engine.time_scale
		_scene.toggle_fast_forward()
		_expect(Engine.time_scale > normal * 2.0 and _scene.watch_controls_state()[1], "早送りで、速くならない")
		_expect(_scene.press_skip() and _scene.is_skipping(), "スキップを押せない")
		seen_lines["before"] = lines_before
		seen_lines["base"] = _scene.cpu_actions
		# スキップの途中でも、ログを開いている間は止まる（CPU が 1 つ行動したところで開く）。
		var open_once := func() -> void:
			if seen_lines.has("paused") or _scene.cpu_actions == seen_lines["base"] or not _scene.is_skipping():
				return
			_scene.open_log()
			seen_lines["paused"] = _scene.cpu_actions
			get_tree().create_timer(0.5, true, false, true).timeout.connect(func() -> void:
				_expect(_scene.cpu_actions <= seen_lines["paused"] + 1 and battle.phase != Unit.Side.PLAYER1,
					"スキップの途中に、ログを開いている間も相手の番が進んだ")
				_scene.log_panel().close())
		_scene.frame_passed.connect(open_once))
	_scripted.append(func() -> void:
		_expect(seen_lines.has("paused"), "スキップの途中に、ログを開けなかった")
		_expect(battle.turn == 2 and battle.phase == Unit.Side.PLAYER1 and not _scene.is_skipping(), "スキップのあと、自分の番で止まらなかった")
		_expect(_scene.cpu_actions > seen_lines["base"] and bait.hp < bait.max_hp(), "スキップしても、CPU が行動していない")
		var problem := _mismatch(battle)
		_expect(problem == "", "スキップのあと、盤の見た目が状態と違う: " + problem)
		_expect(_scene.battle_log.entries.size() > seen_lines["before"] + 2, "スキップした番のことが、ログに残っていない")
		_expect(not _scene.watch_controls_state()[0] and Engine.time_scale == _scene.time_scale_base, "自分の番に、早送りが効いている")
		# 早送りは入れたまま（次の相手の番も速い）。2 局目: スキップの途中で決着する。
		_scene.start_with(lost, StageLook.GRASSLAND, 1))
	_scripted.append(func() -> void:
		_end_turn()
		_scene.press_skip())
	# 3 局目: スキップせずに見る。CPU が番を終えたあとの中立のフェーズ（ルールの上では、もう人の番）の再生の間も、ボタンが出ている。
	var watch := Battle.new(_small_board(Vector2i(8, 5)))
	watch.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER1, Vector2i(0, 4))
	watch.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER2, Vector2i(7, 0))
	watch.add_unit(UnitKind.Id.MINION, Unit.Side.NEUTRAL, Vector2i(3, 2))
	var neutral_seen := {}
	_scripted.append(func() -> void:
		_expect(lost.is_over() and _scene.result_screen().visible, "スキップの途中の決着で、決着の画面が出ない")
		_scene.toggle_fast_forward()
		_scene.set_opponent(false)
		_scene.start_with(watch, StageLook.GRASSLAND, 1)
		_scene.set_opponent(true))
	_scripted.append(func() -> void:
		var look := func() -> void:
			if _scene.battle == watch and watch.turn == 2 and watch.phase == Unit.Side.PLAYER1 and _scene.is_busy():
				neutral_seen["busy"] = true
				neutral_seen["shown"] = neutral_seen.get("shown", true) and _scene.watch_controls_state()[0]
		_scene.frame_passed.connect(look)
		_end_turn())
	_scripted.append(func() -> void:
		_expect(watch.turn == 2 and watch.phase == Unit.Side.PLAYER1, "3 局目で、自分の番に戻らなかった")
		_expect(neutral_seen.get("busy", false) and neutral_seen.get("shown", false),
			"CPU が番を終えたあとの中立のフェーズの再生の間に、早送り・スキップが出ていない")
		_expect(not _scene.watch_controls_state()[0], "自分の番に戻っても、早送り・スキップが出ている")
		_scene.set_opponent(false))
