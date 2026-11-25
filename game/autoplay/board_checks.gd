extends "res://game/autoplay/autoplay_base.gd"
## 自動の対戦の場面: 盤の上のこと（ポータルと泉、占拠と拠点、樽の引き分け、リザルト、盤の上の効果、スキル、状態、軍略、行動を終えないスキル）。


## ポータルを通る移動（ポータルへ歩く → メニューの「転移」→ 残りで続けて歩く）と、その取り消し、回復の泉の回復。
func _queue_portal_and_spring_scene() -> void:
	var board := _small_board(Vector2i(12, 6))
	board.add_portal_pair(Vector2i(1, 1), Vector2i(8, 1))
	board.add_spring(Vector2i(4, 4))
	var battle := Battle.new(board)
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER1, Vector2i(0, 5))
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER2, Vector2i(11, 0))
	var walker := battle.add_unit(UnitKind.Id.SNIPER, Unit.Side.PLAYER1, Vector2i(0, 1))
	var bather := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, Unit.Side.PLAYER1, Vector2i(4, 4))
	bather.hp -= 20
	board.add_portal_pair(Vector2i(1, 3), Vector2i(9, 3))
	var blocked_walker := battle.add_unit(UnitKind.Id.SNIPER, Unit.Side.PLAYER1, Vector2i(0, 3))
	battle.add_unit(UnitKind.Id.SNIPER, Unit.Side.PLAYER1, Vector2i(9, 3))  # 行き先のポータルをふさぐ
	var far := Vector2i(10, 1)  # 歩けば 10 マス。ポータルを通れば移動力 3 で届く。
	var warped: Script = UnitWarpedEvent
	var moved: Script = UnitMovedEvent

	_scripted.append(func() -> void: _scene.start_with(battle, StageLook.CRYSTAL_FOREST, 1))
	# 人の操作のとおり（マウスで駒を選び、ポータルのマスをクリック）: ポータルに止まり、メニューの「転移」で対のポータルへ移る。
	_scripted.append(func() -> void: _click(walker.cell))
	_scripted.append(func() -> void:
		_expect(not _scene.menu_covers_move(), "動く前のメニューが、届くマスを隠した（小さな盤で、外へ出せるのに）")
		var portal_color: Color = _scene.portal_paint_color(Vector2i(1, 1))
		_expect(_scene.painted_color(Vector2i(1, 1)) == portal_color and _scene.painted_color(Vector2i(8, 1)) == portal_color,
			"動ける範囲の塗りに、ポータルの対（入る・出る）が出ていない")
		_click(Vector2i(1, 1)))
	_scripted.append(func() -> void:
		_expect(walker.cell == Vector2i(1, 1), "ポータルのマスに止まらなかった")
		_expect(_scene.menu_ids().has(BattleTexts.MENU_WARP), "ポータルに止まっても、メニューに「転移」が出ない")
		_expect(_scene.painted_color(Vector2i(8, 1)) == _scene.portal_paint_color(Vector2i(1, 1)), "転移の行き先を塗っていない")
		_scene.played.erase(warped)
		_expect(_scene.press_menu(BattleTexts.MENU_WARP), "「転移」を押せない"))
	_scripted.append(func() -> void:
		_expect(walker.cell == Vector2i(8, 1) and _scene.selected_unit() == walker, "「転移」で対のポータルへ移らなかった")
		_expect(_scene.played.get(warped, 0) == 1, "転移を再生しなかった")
		_expect(not _scene.menu_ids().has(BattleTexts.MENU_WARP), "転移したあとも「転移」が出ている")
		_expect(_scene.painted_color(far) == _scene.COLOR_MOVE, "転移のあと、残りの移動力で届くマスを塗っていない")
		_scene.played.erase(moved)
		_scene.click_cell(far))
	_scripted.append(func() -> void:
		_expect(walker.cell == far, "転移のあと、続けて動けなかった")
		_expect(_scene.played.get(moved, 0) == 1, "続きの移動を再生しなかった")
		var last: String = _scene.battle_log.entries[-1].text
		_expect(last.contains("(0, 1) → (10, 1)") and last.contains("ポータル経由"), "ログが、ポータル経由の移動 1 行になっていない: " + last)
		_scene.cancel())
	_scripted.append(func() -> void:
		_expect(walker.cell == Vector2i(0, 1), "転移を取り消して、動く前のマスへ戻らなかった")
		_expect(_scene.painted_color(far) != _scene.COLOR_MOVE, "動く前の範囲を、転移の先まで広げている")
		# 行き先がふさがっているポータル: 止まれるが、「転移」は出ない。
		_click(blocked_walker.cell))
	_scripted.append(func() -> void: _click(Vector2i(1, 3)))
	_scripted.append(func() -> void:
		_expect(blocked_walker.cell == Vector2i(1, 3), "ふさがっているポータルのマスに止まれなかった")
		_expect(not _scene.menu_ids().has(BattleTexts.MENU_WARP), "行き先がふさがっているのに「転移」が出た")
		_scene.cancel())
	_scripted.append(func() -> void: _scene.cancel())
	_scripted.append(func() -> void: _click(walker.cell))
	_scripted.append(func() -> void: _click(Vector2i(1, 1)))
	_scripted.append(func() -> void: _scene.press_menu(BattleTexts.MENU_WARP))
	_scripted.append(func() -> void: _scene.click_cell(far))
	_scripted.append(func() -> void:
		_scene.played.erase(BattlePlayback.NEUTRAL_PHASE_SHOWN)
		_scene.press_wait())
	_scripted.append(_end_turn)
	_scripted.append(_end_turn)
	_scripted.append(func() -> void:
		_expect(battle.turn == 2 and battle.phase == Unit.Side.PLAYER1, "ターンが進まなかった")
		_expect(_scene.played.get(BattlePlayback.NEUTRAL_PHASE_SHOWN, 0) == 0, "中立の駒のいない番の知らせを出した")
		_expect(bather.hp == bather.max_hp() - 20 + MapObject.SPRING_HEAL, "回復の泉で回復しなかった"))


## 敵の本陣に乗ったままターンを終えて、占拠の数を進める。拠点にも駒を乗せておき、確保の数も進める。
func _queue_capture_scene() -> void:
	var board := _small_board(Vector2i(6, 4))
	board.stronghold_cell = Vector2i(2, 2)
	var battle := Battle.new(board)
	for side: Unit.Side in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
		battle.win_conditions[side].append(GameWonEvent.Reason.STRONGHOLD_HELD)
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER1, Vector2i(0, 3))
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER2, Vector2i(5, 3))
	var raider := battle.add_unit(UnitKind.Id.COMMANDO, Unit.Side.PLAYER1, Vector2i(3, 0))
	battle.add_unit(UnitKind.Id.SHIELD_TROOPER, Unit.Side.PLAYER1, board.stronghold_cell)

	_scripted.append(func() -> void: _scene.start_with(battle, StageLook.GRASSLAND, 1))
	_scripted.append(func() -> void: _scene.click_cell(raider.cell))
	_scripted.append(func() -> void: _scene.click_cell(board.hq_cells[Unit.Side.PLAYER2]))
	_scripted.append(func() -> void: _scene.press_wait())
	_scripted.append(_end_turn)
	_scripted.append(func() -> void: _expect(battle.capture_turns[Unit.Side.PLAYER1] == 1, "占拠の数が進まなかった"))
	_scripted.append(func() -> void: _expect(battle.stronghold_holds[Unit.Side.PLAYER1] == 1, "拠点の確保の数が進まなかった"))
	_scripted.append(func() -> void:
		_expect(_scene.stronghold_flag_color() == Palette.TEAM_BLUE, "拠点の旗が確保した陣営の色にならなかった")
		_expect(_scene.stronghold_mark() == "1 / %d" % Stronghold.HOLDS_TO_WIN, "拠点の竿の上の札が確保の数でない: %s" % _scene.stronghold_mark())
		_expect(_scene.stronghold_flag_rate() > 0.0, "確保が進んでも、旗が竿を上らない"))


## 樽を攻撃して爆発させ、両方の将を巻き込んで引き分けにする。
func _queue_barrel_draw_scene() -> void:
	var board := _small_board(Vector2i(7, 5))
	board.add_barrel(Vector2i(3, 2))
	board.add_barrel(Vector2i(0, 0))  # 射程の外。爆発のあとも残る
	var battle := Battle.new(board)
	var king1 := battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER1, Vector2i(2, 2))
	var king2 := battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER2, Vector2i(4, 2))
	king1.hp = 10
	king2.hp = 10
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, Unit.Side.PLAYER1, Vector2i(3, 4))
	var guard := battle.add_unit(UnitKind.Id.PALADIN, Unit.Side.PLAYER2, Vector2i(4, 1))
	# 爆発に 5 体を巻き込む（予測のパネルは、駒ごとに 1 行の詰めた形になり、画面に収まる）。
	battle.add_unit(UnitKind.Id.SHIELD_TROOPER, Unit.Side.PLAYER1, Vector2i(2, 3))
	battle.add_unit(UnitKind.Id.COMMANDO, Unit.Side.PLAYER2, Vector2i(4, 3))

	_scripted.append(func() -> void: _scene.start_with(battle, StageLook.GRASSLAND, 1))
	_scripted.append(func() -> void: _scene.click_cell(sniper.cell))
	_scripted.append(func() -> void:
		_expect(Queries.barrel_targets(battle, sniper) == ([Vector2i(3, 2)] as Array[Vector2i]), "狙える樽が違う")
		_scene.hover(Vector2i(3, 2))
		_expect_forecast(["樽を撃つ", "2 体を倒せる", "引き分け"], "樽")
		_scene.hover(NO_CELL)
		_scene.click_cell(Vector2i(3, 2)))
	_scripted.append(func() -> void:
		_expect(battle.is_draw(), "引き分けにならなかった")
		_expect(_scene.result_title() == "引き分け", "引き分けの結果が出ていない")
		_expect(guard.hp == guard.max_hp() - MapObject.BLAST_DAMAGE, "爆発に巻き込まれなかった")
		_expect(_scene.barrel_view_cells() == ([Vector2i(0, 0)] as Array[Vector2i]), "爆発した樽が画面に残っている"))


## リザルトの画面。出そろう前は行き先を選べず、クリックは演出を飛ばすだけ。飛ばすと全部が出て、少しして行き先を選べる。
## 詳しい戦績は畳んであり、ボタンで開け閉めできる。
func _queue_result_scene() -> void:
	var screen: Node = _scene.result_screen()
	_expect(not screen.is_revealed() and screen.enabled_buttons().is_empty(), "出そろう前に、行き先を選べる")
	_expect(_scene.result_title() != "", "リザルトの見出しが出ていない")
	# 決着のあとは、後ろの盤の駒にマウスを乗せても、左下の枠（駒の情報）を出さない（リザルトのボタンに重なる）。
	var survivor: Unit = null
	for unit: Unit in _scene.battle.units:
		survivor = unit
	_scene.hover(survivor.cell)
	_expect(_scene.info_title() == "", "決着のあとに、駒の情報を出している: %s" % _scene.info_title())
	_scene.hover(NO_CELL)
	screen.skip()
	var waited := [0]
	var wait_revealed := func(again: Callable) -> void:
		waited[0] += 1
		if screen.enabled_buttons().is_empty():
			if waited[0] > 600:
				_fail("飛ばしても、リザルトの行き先を選べるようにならない")
				return
			_push_front(again.bind(again))
			return
		_expect(screen.is_revealed(), "行き先を選べるのに、出そろっていない")
		_expect(screen.enabled_buttons().has("マップ選択へ") and not screen.enabled_buttons().has("タイトルへ"), "対戦モードの行き先に「マップ選択へ」が無い（か、「タイトルへ」がある）")
		_expect(screen.stat_lines().size() >= 2 and screen.mvp_text() != "", "戦績か MVP が出ていない")
		_expect(not screen.is_detail_open(), "詳しい戦績が、始めから開いている")
		screen.toggle_detail()
		_expect(screen.is_detail_open(), "詳しい戦績が開かない")
		var shown_side: int = screen.table_side()
		_expect(screen.table_names().size() == _scene.stats.records_of(shown_side as Unit.Side).size(), "詳しい戦績の表に、駒の行が並ばない")
		screen.show_table(1 - shown_side)
		_expect(screen.table_side() == 1 - shown_side and not screen.table_names().is_empty(), "詳しい戦績の表を、もう一方の陣営に切り替えられない")
		screen.toggle_detail()
		_expect(screen.enter_destination() == "マップ選択へ", "対戦モードの決着の画面の Enter がマップ選択へでない: %s" % screen.enter_destination())
		# 戦績の行がいちばん多い（5 行）ときも、入力の案内が下の帯にかからない。
		var full := ResultSummary.new()
		full.headline = "VICTORY"
		full.reason = "プレイヤー1（青） の勝ち　敵の将を倒した"
		full.focus_name = "プレイヤー1（青）"
		full.lines = [["マップ", "結晶の岩山"], ["経過ターン", "23 ターン"], ["敵軍撃破", "5 体"], ["中立撃破", "3 体"], ["聖遺物", "英知の聖遺物・勇気の聖遺物"]]
		full.mvp_name = "シールドトルーパー Lv3"
		screen.present(full)
		# 負けた話の台詞（いちばん多い 3 行、いちばん長い文）も、戦績の左に収まる。
		var remark: Array[BattleCues.Line] = []
		for side: int in [0, 1, 0]:
			remark.append(BattleCues.Line.new(side, "ドーソン", "あ".repeat(Episode.LOST_MAX_CHARS), {"kind": UnitKind.Id.SHIELD_TROOPER, "evolved": true}))
		screen.set_remark(remark)
	var waited_full := [0]
	var wait_full := func(again: Callable) -> void:
		var screen_size: Vector2 = screen.get_viewport_rect().size
		waited_full[0] += 1
		if not screen.is_revealed():
			if waited_full[0] > 600:
				_fail("戦績が 5 行の決着の画面が、出そろわない")
				return
			screen.skip()
			_push_front(again.bind(again))
			return
		var rect: Rect2 = screen.prompt_rect()
		_expect(rect.end.y <= screen_size.y - BattleHud.BOTTOM_BAR_HEIGHT,
			"戦績が 5 行のとき、決着の画面の入力の案内が下の帯にかかる: %s" % rect)
		var said: Rect2 = screen.remark_rect()
		_expect(screen.remark_texts().size() == 3 and said.position.x >= 0.0 and said.end.x <= screen_size.x / 2.0 - 230.0
			and said.end.y <= screen_size.y - BattleHud.BOTTOM_BAR_HEIGHT,
			"負けたときの台詞の板が、画面からはみ出すか、戦績や下の帯にかかる: %s" % said)
		screen.toggle_detail()
		_expect(not screen.remark_rect().has_area(), "詳しい戦績を開いても、負けたときの台詞の板が表に重なって出ている")
		screen.toggle_detail()
		_expect(screen.remark_rect() == said, "詳しい戦績を閉じても、負けたときの台詞の板が戻らない")
	_scripted.append(wait_revealed.bind(wait_revealed))
	_scripted.append(wait_full.bind(wait_full))


## 盤の上の効果。ルールの入口（FieldEffects.place_*）で盾・煙幕・聖域を置いて再生し、
## 盾越しには撃てないこと、盾を壊せること、煙幕が離れたところからの攻撃を防ぐこと、聖域の回復と期間の進みを通す。
func _queue_field_effect_scene() -> void:
	var board := _small_board(Vector2i(7, 5))
	var battle := Battle.new(board)
	var king1 := battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER1, Vector2i(0, 4))
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER2, Vector2i(6, 0))
	king1.hp -= 10
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, Unit.Side.PLAYER1, Vector2i(1, 2))
	var sorcerer := battle.add_unit(UnitKind.Id.SORCERER, Unit.Side.PLAYER1, Vector2i(2, 0))
	var guard := battle.add_unit(UnitKind.Id.PALADIN, Unit.Side.PLAYER2, Vector2i(5, 2))
	var hidden := battle.add_unit(UnitKind.Id.SNIPER, Unit.Side.PLAYER2, Vector2i(4, 0))
	var wall := Vector2i(3, 2)
	var blocked: Script = SmokeBlockedEvent
	var healed: Script = SanctuaryHealedEvent

	_scripted.append(func() -> void: _scene.start_with(battle, StageLook.GRASSLAND, 1))
	_scripted.append(func() -> void:
		var events := FieldEffects.place_barricade(battle, Unit.Side.PLAYER2, wall)
		events.append_array(FieldEffects.place_smoke(battle, Unit.Side.PLAYER2, Vector2i(4, 1)))
		events.append_array(FieldEffects.place_sanctuary(battle, Unit.Side.PLAYER1, Vector2i(1, 3)))
		_expect(events.size() == 3, "盤の上の効果を置けなかった")
		battle.board.barricade_at(wall).durability = 5  # 1 回の攻撃で壊れるように
		_scene.play_events(events))
	_scripted.append(func() -> void: _scene.click_cell(sniper.cell))
	_scripted.append(func() -> void:
		_expect(not Queries.attack_targets(battle, sniper).has(guard), "盾越しに撃てる")
		_expect(Queries.barricade_targets(battle, sniper) == ([wall] as Array[Vector2i]), "狙える盾が違う")
		# 盾の上の棒は、いまの残りの耐久（置いたあとに減らした 5）。
		var bar: int = _scene.barricade_bar_durability(battle.board.barricade_at(wall).id)
		_expect(bar == 5, "盾の耐久の棒が、残りの耐久と違う: %d" % bar)
		_scene.click_cell(wall))
	_scripted.append(func() -> void:
		_expect(battle.board.barricade_at(wall) == null, "盾が壊れなかった")
		_scene.click_cell(sorcerer.cell))
	_scripted.append(func() -> void:
		_scene.played.erase(blocked)
		_scene.click_cell(hidden.cell))
	_scripted.append(func() -> void:
		_expect(_scene.played.get(blocked, 0) == 1 and hidden.hp == hidden.max_hp(), "煙幕が攻撃を防がなかった")
		_scene.played.erase(healed))
	_scripted.append(_end_turn)
	_scripted.append(_end_turn)
	_scripted.append(func() -> void:
		_expect(battle.turn == 2 and battle.phase == Unit.Side.PLAYER1, "ターンが進まなかった")
		_expect(_scene.played.get(healed, 0) == 1, "聖域で回復しなかった")
		_expect(king1.hp == king1.max_hp() - 10 + FieldEffects.SANCTUARY_HEAL, "聖域の回復量が違う")
		_expect(battle.board.field_effects.size() == 2, "煙幕と聖域が残っていない"))


## スキルのボタンから、対象を選んで使う（盾を置く、聖域を置く、ファイアボールで敵を焼く）。選ぶのをやめる操作と、クールダウンが明けるまで。
func _queue_skill_scene() -> void:
	var board := _small_board(Vector2i(7, 5))
	var battle := Battle.new(board)
	var king1 := battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER1, Vector2i(0, 4))
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER2, Vector2i(6, 0))
	var trooper := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, Unit.Side.PLAYER1, Vector2i(2, 2))
	var priest := battle.add_unit(UnitKind.Id.PRIEST, Unit.Side.PLAYER1, Vector2i(1, 3))
	var sorcerer := battle.add_unit(UnitKind.Id.SORCERER, Unit.Side.PLAYER1, Vector2i(1, 1))
	var burned := battle.add_unit(UnitKind.Id.PALADIN, Unit.Side.PLAYER2, Vector2i(4, 1))
	var damaged: Script = SkillDamagedEvent
	var wall := Vector2i(3, 2)
	var center := Vector2i(1, 4)
	var used: Script = SkillUsedEvent
	var ready: Script = SkillReadyEvent

	_scripted.append(func() -> void:
		_scene.set_opponent(false)
		_scene.start_with(battle, StageLook.GRASSLAND, 1))
	_scripted.append(func() -> void:
		_scene.click_cell(king1.cell)
		_expect(not _scene.is_skill_enabled(), "スキルの無い駒で、スキルのボタンが押せる")
		_scene.press_skill()
		_expect(not _scene.is_choosing_skill_target(), "スキルの無い駒で、対象を選び始めた")
		_scene.click_cell(trooper.cell))
	_scripted.append(func() -> void:
		_expect(_scene.is_skill_enabled(), "スキルのボタンが押せない")
		_scene.press_skill()
		_expect(_scene.is_choosing_skill_target(), "スキルの対象を選び始めなかった")
		# 対象でないマスを選ぶと、選ぶのをやめる（駒は動かない）。
		_scene.click_cell(Vector2i(5, 2))
		_expect(not _scene.is_choosing_skill_target() and _scene.selected_unit() == trooper, "対象でないマスで、やめなかった")
		_expect(trooper.cell == Vector2i(2, 2) and not trooper.has_moved, "スキルの対象を選ぶ途中のクリックで、駒が動いた")
		_scene.press_skill()
		_scene.cancel()
		_expect(not _scene.is_choosing_skill_target() and _scene.selected_unit() == trooper, "戻す操作で、やめなかった")
		_scene.press_skill()
		_scene.played.erase(used)
		_scene.click_cell(wall))
	_scripted.append(func() -> void:
		_expect(battle.board.barricade_at(wall) != null, "盾を置けなかった")
		_expect(trooper.acted and trooper.skill_cooldown > 0, "スキルを使っても、行動が終わっていない")
		_expect(_scene.played.get(used, 0) == 1, "スキルを再生しなかった")
		_scene.click_cell(trooper.cell)
		_expect(_scene.menu_ids().is_empty(), "行動済みの駒に、メニューが出ている")
		# 動いたあとでも使える。
		_scene.click_cell(priest.cell))
	_scripted.append(func() -> void: _scene.click_cell(Vector2i(2, 3)))
	_scripted.append(func() -> void:
		_scene.press_skill()
		_expect(_scene.is_choosing_skill_target(), "動いたあとに、スキルの対象を選べない")
		_scene.click_cell(center))
	_scripted.append(func() -> void:
		_expect(battle.board.field_effects.size() == 2, "聖域を置けなかった")
		_expect(priest.acted and priest.cell == Vector2i(2, 3), "聖域を置いても、行動が終わっていない")
		_scene.click_cell(sorcerer.cell))
	_scripted.append(func() -> void:
		_scene.press_skill()
		_expect(_scene.is_choosing_skill_target(), "ファイアボールの対象を選び始めなかった")
		_scene.played.erase(damaged)
		_scene.hover(burned.cell)
		_expect_forecast([Names.skill(Skills.of(sorcerer)), Names.unit(burned), "▼ -"], "ファイアボール")
		_scene.hover(NO_CELL)
		_scene.click_cell(burned.cell))
	_scripted.append(func() -> void:
		_expect(burned.hp == burned.max_hp() - FireballSkill.DAMAGE, "ファイアボールが当たらなかった")
		_expect(_scene.played.get(damaged, 0) == 1, "スキルのダメージを再生しなかった")
		_scene.played.erase(ready))
	_scripted.append(_end_turn)
	_scripted.append(_end_turn)
	_scripted.append(func() -> void:
		# 次の自分の番。クールダウンの間は、メニューのスキルの項目が押せず、残りが出る。
		_scene.click_cell(trooper.cell)
		_expect(trooper.skill_cooldown > 0 and not _scene.is_skill_enabled(), "クールダウンの間に、スキルの項目が押せる")
		_expect(_scene.skill_button_text().contains("あと"), "クールダウンの残りが出ていない")
		_expect(_scene.menu_ids() == ([&"skill", &"wait"] as Array[StringName]), "動く前のメニューの項目が違う: %s" % [_scene.menu_ids()]))
	for i in TacticalBarricadeSkill.COOLDOWN * 2 - 2:
		_scripted.append(_end_turn)
	_scripted.append(func() -> void:
		_expect(trooper.skill_cooldown == 0, "クールダウンが明けなかった")
		_expect(_scene.played.get(ready, 0) >= 1, "クールダウンが明けたことを再生しなかった")
		_scene.click_cell(trooper.cell))
	_scripted.append(func() -> void:
		_expect(_scene.is_skill_enabled(), "クールダウンが明けても、スキルのボタンが押せない"))


## 自分に使うスキルと、駒に付く状態。バリアを張って攻撃を防ぎ、構えて、次の番に伸びた射程からクリティカルを当てる。
func _queue_status_scene() -> void:
	var board := _small_board(Vector2i(9, 3))
	var battle := Battle.new(board)
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER1, Vector2i(0, 2))
	var king2 := battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER2, Vector2i(8, 0))
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, Unit.Side.PLAYER1, Vector2i(2, 1))
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, Unit.Side.PLAYER1, Vector2i(1, 0))
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, Unit.Side.PLAYER2, Vector2i(3, 1))
	var applied: Script = StatusAppliedEvent
	var removed: Script = StatusRemovedEvent

	_scripted.append(func() -> void:
		_scene.set_opponent(false)
		_scene.start_with(battle, StageLook.GRASSLAND, 1))
	_scripted.append(func() -> void: _scene.click_cell(paladin.cell))
	_scripted.append(func() -> void:
		_scene.press_skill()
		_expect(_scene.is_choosing_skill_target(), "自分に使うスキルの対象を選び始めなかった")
		_scene.played.erase(applied)
		_scene.click_cell(paladin.cell))
	_scripted.append(func() -> void:
		_expect(Statuses.has(paladin, Status.Type.BARRIER) and paladin.acted, "バリアを張れなかった")
		_expect(_scene.played.get(applied, 0) == 1, "状態が付いたことを再生しなかった")
		_scene.click_cell(sniper.cell))
	_scripted.append(func() -> void:
		_scene.press_skill()
		_scene.click_cell(sniper.cell))
	_scripted.append(func() -> void:
		_expect(Statuses.has(sniper, Status.Type.AIM), "構えられなかった")
		_end_turn())
	_scripted.append(func() -> void: _scene.click_cell(commando.cell))
	_scripted.append(func() -> void:
		_scene.played.erase(removed)
		_scene.click_cell(paladin.cell))
	_scripted.append(func() -> void:
		_expect(paladin.hp == paladin.max_hp(), "バリアが攻撃を防がなかった")
		_expect(not Statuses.has(paladin, Status.Type.BARRIER), "バリアが残っている")
		_expect(_scene.played.get(removed, 0) == 1, "状態が外れたことを再生しなかった")
		_end_turn())
	_scripted.append(func() -> void: _scene.click_cell(sniper.cell))
	_scripted.append(func() -> void: _scene.click_cell(king2.cell))
	_scripted.append(func() -> void:
		var doubled := sniper.power() * PrecisionAimSkill.CRITICAL_PERCENT / 100
		_expect(king2.hp == king2.max_hp() - doubled, "伸びた射程からのクリティカルが当たらなかった")
		_expect(not Statuses.has(sniper, Status.Type.AIM), "照準が残っている"))


## 軍略（docs/troop-traits.md）。集中砲火の連邦のスナイパーが 1 発当てると、敵の足元に輪が出て、2 人目のスナイパーの攻撃に集中砲火が乗る。
## ターンを終えると、補給線の相手の番の始めに、衛生兵と隣り合う兵が回復する。
func _queue_traits_scene() -> void:
	var board := _small_board(Vector2i(7, 3))
	var battle := Battle.new(board)
	battle.traits = [Traits.Id.FOCUS, Traits.Id.SUPPLY]
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER1, Vector2i(0, 1))
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER2, Vector2i(6, 0))
	var first := battle.add_unit(UnitKind.Id.SNIPER, Unit.Side.PLAYER1, Vector2i(0, 0))
	var second := battle.add_unit(UnitKind.Id.SNIPER, Unit.Side.PLAYER1, Vector2i(0, 2))
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, Unit.Side.PLAYER2, Vector2i(3, 1))
	paladin.hp = first.power() + Traits.FOCUS_BONUS + 1
	battle.add_unit(UnitKind.Id.MEDIC, Unit.Side.PLAYER2, Vector2i(6, 2))
	var trooper := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, Unit.Side.PLAYER2, Vector2i(5, 2))
	trooper.hp -= 10
	var triggered: Script = TraitTriggeredEvent
	var supplied: Script = SupplyHealedEvent

	_scripted.append(func() -> void:
		_scene.set_opponent(false)
		_scene.start_with(battle, StageLook.GRASSLAND, 1))
	_scripted.append(func() -> void:
		_expect(_scene.trait_mark_count() == 0, "まだ誰も攻撃していないのに、軍略の輪が出ている")
		_scene.click_cell(first.cell))
	_scripted.append(func() -> void: _scene.click_cell(paladin.cell))
	_scripted.append(func() -> void:
		_expect(paladin.hp == Traits.FOCUS_BONUS + 1, "1 発目が当たらなかった")
		_expect(_scene.trait_mark_count() == 1, "攻撃された敵の足元に、集中砲火の輪が出ない")
		_expect(_scene.trait_mark_texts() == ["+%d" % Traits.FOCUS_BONUS], "攻撃された敵の頭の上に、集中砲火の札（増える数）が出ない: %s" % [_scene.trait_mark_texts()])
		_expect(_scene.trait_name(0) == Names.troop_trait(Traits.Id.FOCUS) and _scene.trait_name(1) == Names.troop_trait(Traits.Id.SUPPLY), "上の帯に、軍略の名前が出ない")
		_scene.played.erase(triggered)
		_scene.click_cell(second.cell))
	_scripted.append(func() -> void: _scene.click_cell(paladin.cell))
	_scripted.append(func() -> void:
		_expect(not battle.units.has(paladin), "集中砲火で倒せなかった")
		_expect(_scene.played.get(triggered, 0) == 1, "集中砲火を再生しなかった"))
	_scripted.append(_end_turn)  # 後手（補給線）の番の始めに、衛生兵と隣り合う兵が回復する
	_scripted.append(func() -> void:
		_expect(trooper.hp == trooper.max_hp() - 10 + Traits.SUPPLY_HEAL, "補給線で回復しなかった")
		_expect(_scene.played.get(supplied, 0) == 1, "補給線の回復を再生しなかった"))


## 倒れると何か起きる魔物（docs/monsters.md）。スナイパーが骸骨旗手を倒し（隣の骸骨兵が奮起）、もう 1 体がほつれを倒し（結び目が残る）、
## 3 体目が糸喰いを倒す（弾けて、隣の骸骨兵を巻き込む）。
func _queue_monster_falls_scene() -> void:
	var board := _small_board(Vector2i(8, 3))
	var battle := Battle.new(board)
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER1, Vector2i(0, 2))
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER2, Vector2i(7, 0))
	var first := battle.add_unit(UnitKind.Id.SNIPER, Unit.Side.PLAYER1, Vector2i(0, 0))
	var second := battle.add_unit(UnitKind.Id.SNIPER, Unit.Side.PLAYER1, Vector2i(0, 1))
	var banner := battle.add_unit(UnitKind.Id.SKELETON_BANNER, Unit.Side.PLAYER2, Vector2i(3, 0))
	var skeleton := battle.add_unit(UnitKind.Id.SKELETON, Unit.Side.PLAYER2, Vector2i(4, 0))
	var fray := battle.add_unit(UnitKind.Id.FRAY, Unit.Side.PLAYER2, Vector2i(3, 1))
	var third := battle.add_unit(UnitKind.Id.SNIPER, Unit.Side.PLAYER1, Vector2i(1, 2))
	var eater := battle.add_unit(UnitKind.Id.EATER, Unit.Side.PLAYER2, Vector2i(5, 2))
	var caught := battle.add_unit(UnitKind.Id.SKELETON, Unit.Side.PLAYER2, Vector2i(6, 1))
	banner.hp = 1
	fray.hp = 1
	eater.hp = 1
	var rally: Script = RallyEvent
	var knot: Script = KnotPlacedEvent
	var burst: Script = BurstEvent

	_scripted.append(func() -> void:
		_scene.set_opponent(false)
		_scene.start_with(battle, StageLook.GRASSLAND, 1))
	_scripted.append(func() -> void: _scene.click_cell(first.cell))
	_scripted.append(func() -> void: _scene.click_cell(banner.cell))
	_scripted.append(func() -> void:
		_expect(not battle.units.has(banner), "旗手を倒せなかった")
		_expect(_scene.played.get(rally, 0) == 1, "奮起を再生しなかった")
		_expect(Statuses.has(skeleton, Status.Type.RESOLVE), "隣の骸骨兵に奮起が付かなかった")
		_scene.click_cell(second.cell))
	_scripted.append(func() -> void: _scene.click_cell(fray.cell))
	_scripted.append(func() -> void:
		_expect(not battle.units.has(fray), "ほつれを倒せなかった")
		_expect(_scene.played.get(knot, 0) == 1, "結び目を再生しなかった")
		_expect(Monsters.knot_at(battle, Vector2i(3, 1)) != null, "結び目が残らなかった")
		_scene.click_cell(third.cell))
	_scripted.append(func() -> void: _scene.click_cell(eater.cell))
	_scripted.append(func() -> void:
		_expect(not battle.units.has(eater), "糸喰いを倒せなかった")
		_expect(_scene.played.get(burst, 0) == 1, "弾けたのを再生しなかった")
		_expect(caught.hp == UnitKind.max_hp(UnitKind.Id.SKELETON) - Monsters.BURST_DAMAGE, "隣の骸骨兵が巻き込まれなかった"))


## 行動の流れを変えるスキル。シャドウステップで敵と入れ替わってから攻撃し、アドレナリン注射で、行動済みの駒をもう一度動かす。
func _queue_extra_action_scene() -> void:
	var board := _small_board(Vector2i(9, 4))
	var battle := Battle.new(board)
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER1, Vector2i(0, 3))
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER2, Vector2i(8, 0))
	var blade := battle.add_unit(UnitKind.Id.SPELLBLADE, Unit.Side.PLAYER1, Vector2i(2, 1))
	# 衛生兵は、入れ替わったあとのパラディンの支配領域を通らずに、スペルブレードの隣へ行ける位置に置く。
	var medic := battle.add_unit(UnitKind.Id.MEDIC, Unit.Side.PLAYER1, Vector2i(3, 3))
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, Unit.Side.PLAYER2, Vector2i(4, 1))
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, Unit.Side.PLAYER2, Vector2i(5, 1))
	var swapped: Script = UnitsSwappedEvent
	var teleported: Script = UnitTeleportedEvent
	var reactivated: Script = UnitReactivatedEvent

	_scripted.append(func() -> void:
		_scene.set_opponent(false)
		_scene.start_with(battle, StageLook.GRASSLAND, 1))
	_scripted.append(func() -> void: _scene.click_cell(blade.cell))
	_scripted.append(func() -> void:
		_scene.press_skill()
		_expect(_scene.is_choosing_skill_target(), "シャドウステップの対象を選び始めなかった")
		_scene.click_cell(paladin.cell))
	_scripted.append(func() -> void:
		_expect(_scene.played.get(swapped, 0) == 1, "入れ替わりを再生しなかった")
		_expect(blade.cell == Vector2i(4, 1) and paladin.cell == Vector2i(2, 1), "入れ替わらなかった")
		_expect(not blade.acted and _scene.selected_unit() == blade, "跳んだあとに、続けて行動できない")
		_expect(not _scene.is_skill_enabled(), "跳んだあとに、スキルのボタンが押せる")
		# 戻す操作では、跳ぶ前には戻れない。
		_scene.cancel()
		_expect(blade.cell == Vector2i(4, 1) and _scene.selected_unit() == blade, "跳んだあとに、取り消せた")
		_expect(not _scene.menu_ids().has(&"undo"), "跳んだあとのメニューに、取り消しが出ている")
		# メニューの「攻撃」から相手を選ぶ。選ぶ途中は「やめる」だけが出て、相手でないマスではやめる。
		_expect(_scene.press_menu(&"attack") and _scene.is_choosing_target(), "メニューの攻撃で、相手を選び始めなかった")
		_expect(_scene.menu_ids() == ([&"back"] as Array[StringName]), "相手を選ぶ途中のメニューが違う")
		_scene.click_cell(Vector2i(8, 3))
		_expect(not _scene.is_choosing_target() and _scene.selected_unit() == blade and not blade.acted, "相手でないマスで、やめなかった")
		_scene.press_menu(&"attack")
		_scene.click_cell(sniper.cell))
	_scripted.append(func() -> void:
		_expect(sniper.hp < sniper.max_hp() or battle.unit_by_id(sniper.id) == null, "跳んだあとに、攻撃できなかった")
		_expect(blade.acted, "攻撃しても、行動が終わっていない")
		_scene.click_cell(medic.cell))
	_scripted.append(func() -> void: _scene.click_cell(Vector2i(4, 2)))
	_scripted.append(func() -> void:
		_expect(_scene.skill_button_text().contains("あと %d 回" % AdrenalineShotSkill.MAX_USES), "残りの回数が出ていない")
		_scene.press_skill()
		_scene.click_cell(blade.cell))
	_scripted.append(func() -> void:
		_expect(_scene.played.get(reactivated, 0) == 1, "もう一度行動できることを再生しなかった")
		_expect(medic.acted and not blade.acted, "アドレナリン注射で、行動前に戻らなかった")
		_scene.click_cell(blade.cell))
	_scripted.append(func() -> void: _scene.click_cell(Vector2i(4, 0)))
	_scripted.append(func() -> void:
		_expect(blade.cell == Vector2i(4, 0), "もう一度の行動で、動けなかった")
		_scene.press_wait())
	_scripted.append(func() -> void:
		_expect(blade.acted, "もう一度の行動が終わらなかった")
		_end_turn())
	_scripted.append(_end_turn)
	for i in ShadowStepSkill.COOLDOWN * 2 - 2:
		_scripted.append(_end_turn)
	_scripted.append(func() -> void: _scene.click_cell(blade.cell))
	_scripted.append(func() -> void:
		_expect(blade.power() == UnitKind.power(UnitKind.Id.SPELLBLADE), "反動が消えていない")
		_scene.press_skill()
		_scene.click_cell(Vector2i(4, 3)))
	_scripted.append(func() -> void:
		_expect(_scene.played.get(teleported, 0) == 1, "跳んだことを再生しなかった")
		_expect(blade.cell == Vector2i(4, 3), "空いたマスへ跳べなかった"))
