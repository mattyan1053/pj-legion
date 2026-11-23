extends "res://game/autoplay/board_checks.gd"
## 自動の対戦の場面: 駒のこと（中立の駒、中ボス、レベルアップ、進化、回復、閲覧と脅威範囲、必殺技）。


## 結晶泉にエナジー・コアが湧き、次の中立のフェーズで隣の駒を襲う。
func _queue_neutral_scene() -> void:
	var board := _small_board(Vector2i(8, 5))
	var font := Vector2i(3, 2)
	board.set_terrain(font, Terrain.Type.FONT)
	board.font_cells = [font]
	var battle := Battle.new(board)
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER1, Vector2i(0, 4))
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER2, Vector2i(7, 0))
	var bait := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, Unit.Side.PLAYER1, Vector2i(5, 2))

	_scripted.append(func() -> void:
		_scene.start_with(battle, StageLook.GRASSLAND, 1)
		_scene.camera_follows.clear()
		_scene.played.erase(BattlePlayback.NEUTRAL_PHASE_SHOWN))
	_scripted.append(_end_turn)
	_scripted.append(_end_turn)
	_scripted.append(func() -> void:
		var core := battle.unit_at(font)
		_expect(core != null and core.side == Unit.Side.NEUTRAL, "結晶泉にエナジー・コアが湧かなかった")
		_expect(_scene.played.get(BattlePlayback.NEUTRAL_PHASE_SHOWN, 0) == 1, "中立の駒が湧いた番の知らせを出さなかった")
		_expect(_scene.camera_follows.is_empty(), "湧いただけの中立の駒を、カメラが追った"))
	_scripted.append(_end_turn)
	_scripted.append(_end_turn)
	_scripted.append(func() -> void:
		_expect(bait.hp == bait.max_hp() - UnitKind.power(UnitKind.Id.MINION), "エナジー・コアが攻撃しなかった")
		# 攻撃しに歩いた中立の駒は、カメラが追いかける（湧いただけのときは、追わない）。
		var followed := false
		for unit in battle.units:
			followed = followed or (unit.side == Unit.Side.NEUTRAL and _scene.camera_follows.has(unit.id))
		_expect(followed, "攻撃しに歩いた中立の駒を、カメラが追わなかった"))


## 中ボスが現れ、弱った別の中ボスに止めを刺すと、倒した陣営が知らされ、その陣営が聖遺物を受け取る。
func _queue_mid_boss_scene() -> void:
	var board := _small_board(Vector2i(8, 5))
	board.mid_boss_cells = [Vector2i(2, 2), Vector2i(6, 2)]
	var battle := Battle.new(board)
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER1, Vector2i(0, 4))
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER2, Vector2i(7, 0))
	var weak := battle.add_unit(UnitKind.Id.ELITE_MINION, Unit.Side.NEUTRAL, board.mid_boss_cells[0])
	weak.home_cell = weak.cell
	weak.hp = 1
	var raider := battle.add_unit(UnitKind.Id.COMMANDO, Unit.Side.PLAYER1, Vector2i(2, 4))
	var raider_max_hp := raider.max_hp()

	_scripted.append(func() -> void: _scene.start_with(battle, StageLook.GRASSLAND, 1))
	_scripted.append(func() -> void: _scene.click_cell(raider.cell))
	_scripted.append(func() -> void: _scene.click_cell(Vector2i(2, 3)))
	_scripted.append(func() -> void: _scene.click_cell(weak.cell))
	_scripted.append(func() -> void:
		_expect(_scene.played.get(MidBossDefeatedEvent, 0) == 1, "中ボスを倒したことを再生しなかった")
		_expect(battle.mid_boss_slayers.get(0, -1) == Unit.Side.PLAYER1, "倒した陣営が控えられていない")
		_expect(_scene.played.get(RelicGainedEvent, 0) == 1, "聖遺物を受け取ったことを再生しなかった")
		_expect(_scene.relic_text(0) == "英知" and _scene.relic_text(1) == "", "上の帯に聖遺物が出ていない")
		_expect(raider.max_hp() == raider_max_hp + Relics.WISDOM_MAX_HP, "英知の聖遺物が効いていない")
		_expect(_scene.view_hps()[raider.id] == raider.hp, "聖遺物で増えた HP が、駒の札に出ていない"))
	_scripted.append(_end_turn)
	_scripted.append(_end_turn)
	_scripted.append(func() -> void:
		var boss := battle.unit_at(board.mid_boss_cells[1])
		_expect(boss != null and boss.kind == UnitKind.Id.ELITE_MINION, "中ボスが現れなかった")
		_expect(battle.unit_at(board.mid_boss_cells[0]) == null, "倒れた中ボスがまた現れた"))


## あと 10 でレベルが上がる駒が敵を倒し、経験値が入ってレベルが上がる。
func _queue_level_up_scene() -> void:
	var board := _small_board(Vector2i(6, 4))
	var battle := Battle.new(board)
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER1, Vector2i(0, 3))
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER2, Vector2i(5, 0))
	var raider := battle.add_unit(UnitKind.Id.COMMANDO, Unit.Side.PLAYER1, Vector2i(2, 2))
	raider.experience = Growth.EXPERIENCE_PER_LEVEL - Growth.HIT_EXPERIENCE
	var victim := battle.add_unit(UnitKind.Id.SNIPER, Unit.Side.PLAYER2, Vector2i(3, 2))
	victim.hp = 1
	raider.hp -= 5

	_scripted.append(func() -> void: _scene.start_with(battle, StageLook.GRASSLAND, 1))
	_scripted.append(func() -> void: _scene.click_cell(raider.cell))
	_scripted.append(func() -> void: _scene.click_cell(victim.cell))
	_scripted.append(func() -> void:
		_expect(battle.unit_by_id(victim.id) == null, "敵を倒せなかった")
		_expect(raider.level == 2, "レベルが上がらなかった")
		_expect(raider.hp == raider.max_hp() - 5, "最大 HP が伸びたぶん HP が増えなかった")
		_expect(_scene.played.get(LevelUpEvent, 0) > 0, "レベルアップを再生しなかった"))


## あと 10 で上限のレベルに届く駒が攻撃を当て、進化先を選び、次の自分の番の始めに再生で回復する。
func _queue_evolution_scene() -> void:
	var board := _small_board(Vector2i(6, 4))
	var battle := Battle.new(board)
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER1, Vector2i(0, 3))
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER2, Vector2i(5, 0))
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, Unit.Side.PLAYER1, Vector2i(2, 2))
	paladin.level = Growth.MAX_LEVEL - 1
	paladin.experience = Growth.EXPERIENCE_PER_LEVEL - Growth.HIT_EXPERIENCE
	paladin.hp -= 20
	var wall := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, Unit.Side.PLAYER2, Vector2i(3, 2))
	var seen := {"hp": 0}  # 手順をまたいで覚えておく値（ラムダは外の変数を書き換えられない）

	_scripted.append(func() -> void: _scene.start_with(battle, StageLook.GRASSLAND, 1))
	_scripted.append(func() -> void: _scene.click_cell(paladin.cell))
	_scripted.append(func() -> void: _scene.click_cell(wall.cell))
	_scripted.append(func() -> void:
		_expect(paladin.level == Growth.MAX_LEVEL, "上限のレベルに届かなかった")
		_expect(battle.evolving_unit() == paladin, "進化先を選ぶのを待っていない")
		_expect(_scene.is_choosing_evolution(), "進化先の選択肢が出ていない")
		# 進化先の選択肢と会話の札は、どちらも上の真ん中に出る。重なる間は、札を薄くする（文が選択肢の後ろから覗かない）。
		_scene.say_for_check([BattleCues.Line.new(1, "ウル", "あと 1 段で進化じゃ。いますぐ選ぶがよい。", {})] as Array[BattleCues.Line])
		_expect(not _scene.talk_card_rect().intersects(_scene.evolution_rect()) or _scene.is_talk_dimmed(),
			"進化先の選択肢に重なった会話の札が、薄くならない: %s と %s" % [_scene.talk_card_rect(), _scene.evolution_rect()])
		_scene.clear_talk_for_check()
		_end_turn())
	_scripted.append(func() -> void:
		_expect(battle.phase == Unit.Side.PLAYER1, "進化先を選ぶ前にターンが終わった")
		seen["hp"] = paladin.hp
		_scene.choose_evolution(0))
	_scripted.append(func() -> void:
		_expect(paladin.evolution == Evolution.Id.SACRED, "進化しなかった")
		_expect(paladin.hp == seen["hp"] + Evolution.bonus(Evolution.Id.SACRED, Unit.Stat.MAX_HP), "最大 HP が伸びたぶん HP が増えなかった")
		_expect(not _scene.is_choosing_evolution(), "進化先の選択肢が残っている")
		seen["hp"] = paladin.hp
		_end_turn())
	_scripted.append(_end_turn)
	_scripted.append(func() -> void:
		_expect(battle.turn == 2 and battle.phase == Unit.Side.PLAYER1, "ターンが進まなかった")
		_expect(paladin.hp == seen["hp"] + Evolution.REGENERATION_HEAL, "再生で回復しなかった"))


## 回復役が動いて、減っている味方を回復する（人の操作で）。
func _queue_heal_scene() -> void:
	var board := _small_board(Vector2i(7, 4))
	var battle := Battle.new(board)
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER1, Vector2i(0, 3))
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER2, Vector2i(6, 0))
	var medic := battle.add_unit(UnitKind.Id.MEDIC, Unit.Side.PLAYER1, Vector2i(1, 1))
	var wounded := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, Unit.Side.PLAYER1, Vector2i(4, 1))
	wounded.hp = 10
	var healed: Script = HealerHealedEvent

	_scripted.append(func() -> void:
		_scene.set_opponent(false)
		_scene.start_with(battle, StageLook.GRASSLAND, 1))
	_scripted.append(func() -> void:
		# 駒のいないマスをクリックすると、そのマスの情報が出る。戻す操作で消える。
		_scene.click_cell(Vector2i(5, 3))
		_expect(_scene.selected_unit() == null and _scene.info_title().begins_with("マス (5, 3)"), "マスの情報が出ていない")
		_scene.cancel()
		_expect(_scene.info_title() == "", "戻す操作で、マスの情報が消えなかった")
		_check_drag(Vector2i(5, 3))
		_scene.click_cell(medic.cell))
	_scripted.append(func() -> void:
		_expect(Queries.heal_targets(battle, medic).is_empty(), "届かない味方を回復できることになっている")
		_expect(not _scene.menu_ids().has(&"heal"), "回復できないのに、メニューに回復が出ている")
		_scene.click_cell(Vector2i(3, 1)))
	_scripted.append(func() -> void:
		_expect(Queries.heal_targets(battle, medic) == ([wounded] as Array[Unit]), "回復できる味方が違う")
		# 動いたあとに相手を切り替えても、その駒を選んだままで、続きができる。
		_scene.set_opponent(true)
		_expect(_scene.selected_unit() == medic, "相手を切り替えたら、動いたあとの駒の選択が外れた")
		_scene.set_opponent(false)
		_scene.played.erase(healed)
		_expect(_scene.menu_ids() == ([&"heal", &"skill", &"wait", &"undo"] as Array[StringName]), "動いたあとのメニューの項目が違う: %s" % [_scene.menu_ids()])
		# スキルの説明は、駒の情報にいつも出ている。メニューの項目にマウスを乗せると、押すと何が起きるかが出る。
		var skill := Skills.of(medic)
		_expect(_scene.info_text().replace("\n", "").contains(Names.skill_summary(skill)), "駒の情報に、スキルの説明が出ていない: %s" % _scene.info_text())
		_scene.hover_menu_item(&"heal")
		_expect(_scene.info_text().contains("行動終了"), "メニューの項目の説明が出ていない: %s" % _scene.info_text())
		_scene.hover_menu_item(&"")
		_expect(not _scene.info_text().contains("行動終了"), "マウスが離れても、項目の説明が残っている")
		_expect(_scene.press_menu(&"heal") and _scene.is_choosing_target(), "メニューの回復で、相手を選び始めなかった")
		_scene.hover(wounded.cell)
		_expect_forecast(["回復", Names.unit(wounded), "+%d" % medic.power()], "回復")
		_scene.hover(NO_CELL)
		_scene.click_cell(wounded.cell))
	_scripted.append(func() -> void:
		_expect(wounded.hp == 10 + medic.power(), "回復しなかった")
		_expect(medic.acted, "回復しても行動が終わっていない")
		_expect(_scene.played.get(healed, 0) == 1, "回復を再生しなかった"))


## 駒を見る（閲覧）のは、選択と別。行動の途中（選んだあと、動いたあと、相手を選ぶ途中）に相手の駒を見て、
## 脅威範囲が出て、見終わると元の行動の途中へそのまま戻る。敵の全員の脅威範囲を出し入れする。
func _queue_inspection_scene() -> void:
	var board := _small_board(Vector2i(9, 5))
	var battle := Battle.new(board)
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER1, Vector2i(0, 4))
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER2, Vector2i(8, 0))
	var trooper := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, Unit.Side.PLAYER1, Vector2i(1, 2))
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, Unit.Side.PLAYER2, Vector2i(7, 2))
	var foe := battle.add_unit(UnitKind.Id.COMMANDO, Unit.Side.PLAYER2, Vector2i(4, 2))
	var neutral := battle.add_unit(UnitKind.Id.MINION, Unit.Side.NEUTRAL, Vector2i(5, 4))
	var looks := func(unit: Unit, what: String) -> void:
		_expect(_scene.inspected_unit() == unit and _scene.selected_unit() == trooper, "%s: 見る駒か、選んでいる駒が違う" % what)
		var threat: Array[Vector2i] = Threat.of(battle, unit.id).cells()
		threat.sort()
		var painted: Array[Vector2i] = _scene.threat_painted_cells()
		painted.sort()
		_expect(not threat.is_empty() and painted.size() <= threat.size() and _scene.info_title().begins_with(Names.unit(unit)),
			"%s: 見ている駒の脅威範囲か情報が出ていない" % what)

	# 前の対戦（もっと大きな盤）でマウスを乗せていたマスが、この小さな盤の外でも、始め直すときに持ち越さない（盤の外を読まない）。
	# 前の場面の盤の大きさに頼らないよう、大きな盤の対戦をここで始めてから、その隅にマウスを乗せる。
	var larger := Battle.new(_small_board(Vector2i(13, 9)))
	larger.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER1, Vector2i(0, 8))
	larger.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER2, Vector2i(12, 0))
	var outside := Vector2i(12, 8)
	_scripted.append(func() -> void:
		_scene.set_opponent(false)
		_scene.start_with(larger, StageLook.GRASSLAND, 1))
	_scripted.append(func() -> void:
		_expect(_scene.battle == larger and not board.in_bounds(outside), "大きな盤の対戦を始められなかった")
		_scene.hover(outside)
		_scene.start_with(battle, StageLook.GRASSLAND, 1)
		_expect(_scene.hovered_cell() == NO_CELL, "始め直したのに、前の対戦のマウスの下のマスが残っている: %s" % _scene.hovered_cell()))
	_scripted.append(func() -> void:
		_scene.click_cell(trooper.cell)
		# 選んだあと: 相手の駒をクリックすると、選んだまま見る。右クリックで、見るのをやめて選んだ駒へ戻る。
		_scene.click_cell(sniper.cell)
		looks.call(sniper, "選んだあと")
		_scene.click_cell(neutral.cell)
		looks.call(neutral, "見る駒を替えた")
		_scene.cancel()
		_expect(_scene.inspected_unit() == null and _scene.selected_unit() == trooper and _scene.threat_painted_cells().is_empty(),
			"右クリックで、選んだ駒へ戻らなかった")
		# 敵の全員の脅威範囲は、出したままでも、移動のマスを選べる。
		_scene.toggle_threat()
		var all: Array[Vector2i] = Threat.against(battle, Unit.Side.PLAYER1).cells()
		_expect(_scene.is_threat_shown() and _scene.threat_overlay_cells() == all and not all.is_empty(), "敵の全員の脅威範囲が出ていない")
		_scene.click_cell(Vector2i(2, 2)))
	_scripted.append(func() -> void:
		_expect(trooper.cell == Vector2i(2, 2) and trooper.has_moved, "脅威範囲を出したまま、動けなかった")
		_expect(_scene.threat_overlay_cells() == Threat.against(battle, Unit.Side.PLAYER1).cells(), "動いたあとに、敵の全員の脅威範囲を作り直していない")
		# 動いたあと: 相手を見ても、移動は失われない。駒のいないマスのクリックで戻る（動かない）。
		_scene.click_cell(foe.cell)
		looks.call(foe, "動いたあと")
		_scene.click_cell(Vector2i(2, 0))
		_expect(_scene.inspected_unit() == null and trooper.cell == Vector2i(2, 2) and trooper.has_moved and _scene.menu_ids().has(&"undo"),
			"見終わったあとに、動いたあとの状態へ戻らなかった")
		_scene.toggle_threat()
		_expect(not _scene.is_threat_shown() and _scene.threat_overlay_cells().is_empty(), "敵の全員の脅威範囲が消えない")
		_scene.cancel())  # 移動を取り消す
	_scripted.append(func() -> void: _scene.click_cell(Vector2i(3, 2)))
	_scripted.append(func() -> void:
		# 相手を選ぶ途中: 相手でない駒を見ても、選ぶ途中のまま。見終わると、続けて攻撃できる。
		_expect(_scene.press_menu(&"attack") and _scene.is_choosing_target(), "メニューの攻撃で、相手を選び始めなかった")
		_scene.click_cell(sniper.cell)
		looks.call(sniper, "相手を選ぶ途中")
		_scene.cancel()
		_expect(_scene.is_choosing_target() and _scene.inspected_unit() == null, "見終わったあとに、相手を選ぶ途中へ戻らなかった")
		# 相手にマウスを乗せると、そのそばに戦闘予測のパネルが出る（メニューと重ならず、画面に収まる）。離すと消える。
		_scene.hover(foe.cell)
		_expect_forecast(["攻撃", Names.unit(foe), "ダメージ"], "攻撃")
		_scene.hover(Vector2i(0, 0))
		_expect(_scene.forecast_text() == "", "相手からマウスを離しても、予測のパネルが残っている")
		_scene.hover(NO_CELL)
		_scene.click_cell(foe.cell))
	_scripted.append(func() -> void:
		_expect(trooper.acted and foe.hp < foe.max_hp(), "見終わったあとに、攻撃できなかった")
		# 相手の駒の範囲を、表示したままにする（ピン留め）。何も選んでいないときにクリックして、情報の枠のスイッチで留める。
		_scene.click_cell(sniper.cell)
		_expect(_scene.pin_switch_state() == ([true, false] as Array[bool]), "相手の駒を見ても、「範囲を表示したまま」が出ない")
		_expect(_scene.press_pin_switch() and _scene.pinned_ids() == ([sniper.id] as Array[int]), "スイッチで留められなかった")
		_scene.click_cell(neutral.cell)
		_scene.press_pin_switch()
		_scene.cancel()  # 見るのをやめる（ピンは残る）
		_expect(_scene.pinned_ids() == ([sniper.id, neutral.id] as Array[int]) and _scene.pinned_sets().size() == 2, "2 体の範囲を表示したままにできない")
		_expect(_scene.pinned_sets()[0] == Threat.of(battle, sniper.id).cells(), "留めた範囲が、その駒の脅威範囲でない")
		# 全体のスイッチと両立する。
		_scene.toggle_threat()
		_expect(not _scene.threat_overlay_cells().is_empty() and _scene.pinned_sets().size() == 2, "全体の範囲と、留めた範囲が両立しない")
		_scene.toggle_threat()
		# 自分の駒には出さない。
		_scene.click_cell(trooper.cell)
		_expect(not _scene.pin_switch_state()[0], "自分の駒に「範囲を表示したまま」が出た")
		_scene.cancel())
	_scripted.append(_end_turn)
	_scripted.append(func() -> void:
		# 留めた駒が動くと、範囲も付いていく。
		_expect(battle.phase == Unit.Side.PLAYER2, "相手の番にならなかった")
		_scene.click_cell(sniper.cell))
	_scripted.append(func() -> void: _scene.click_cell(Vector2i(7, 4)))
	_scripted.append(func() -> void: _scene.press_wait())
	_scripted.append(func() -> void:
		_expect(sniper.cell == Vector2i(7, 4), "留めた駒が動かなかった")
		_expect(not _scene.pinned_sets().is_empty() and _scene.pinned_sets()[0] == Threat.of(battle, sniper.id).cells(), "留めた駒が動いても、範囲が付いていかない")
		# 右クリックで、ほかに戻すものが無ければ、全部外す。
		_expect(_scene.cancel() and _scene.pinned_ids().is_empty() and _scene.pinned_sets().is_empty(), "右クリックで、留めた範囲を全部外せない"))


## 必殺技。ゲージがいっぱいになるまでボタンは押せず、1 回目は確かめるだけで、もう一度押すと使う。使っても駒の行動は残る。
func _queue_ult_scene() -> void:
	var board := _small_board(Vector2i(7, 5))
	var battle := Battle.new(board)
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER1, Vector2i(0, 4))
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER2, Vector2i(6, 0))
	var trooper := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, Unit.Side.PLAYER1, Vector2i(1, 3))
	var sorcerer := battle.add_unit(UnitKind.Id.SORCERER, Unit.Side.PLAYER2, Vector2i(5, 1))
	sorcerer.skill_cooldown = 4
	var used: Script = UltUsedEvent
	var ready: Script = UltReadyEvent
	var power := trooper.power()

	_scripted.append(func() -> void:
		_scene.set_opponent(false)
		_scene.start_with(battle, StageLook.GRASSLAND, 1))
	_scripted.append(func() -> void:
		_expect(not _scene.is_ult_enabled(), "ゲージが空なのに、必殺技のボタンが押せる")
		_expect(_scene.ult_gauge_text(0) == "0%", "ゲージの数字が出ていない")
		_scene.press_ult()
		_expect(not _scene.is_confirming_ult(), "ゲージが空なのに、必殺技を確かめ始めた")
		battle.ult_gauge[Unit.Side.PLAYER1] = Ults.GAUGE_MAX
		_scene.click_cell(trooper.cell))
	_scripted.append(func() -> void:
		_expect(_scene.is_ult_enabled(), "ゲージがいっぱいなのに、必殺技のボタンが押せない")
		_expect(_scene.ult_gauge_text(0) == "READY", "ゲージが READY になっていない")
		_scene.press_ult()
		_expect(_scene.is_confirming_ult() and battle.ult_uses[0] == 0, "1 回押しただけで、必殺技を使った")
		_scene.cancel()
		_expect(not _scene.is_confirming_ult() and _scene.selected_unit() == trooper, "戻す操作で、確かめるのをやめなかった")
		# 盤面のクリックでやめると、やめるだけ（そのクリックで動かない）。
		_scene.press_ult()
		_scene.click_cell(trooper.cell + Vector2i(1, 0))
		_expect(not _scene.is_confirming_ult(), "盤面のクリックで、確かめるのをやめなかった")
		_expect(trooper.cell == Vector2i(1, 3) and not trooper.has_moved, "確かめるのをやめるクリックで、駒が動いた")
		_expect(_scene.selected_unit() == trooper, "確かめるのをやめるクリックで、選択が変わった")
		_scene.press_ult()
		_scene.played.erase(used)
		# 確かめに変わった直後の 2 回目（ダブルクリック・連打）では使わない。間を置いてから押すと使う。
		_scene.press_ult()
		_expect(_scene.is_confirming_ult() and battle.ult_uses[0] == 0, "素早い 2 回押しで、必殺技の確かめを飛ばした")
		_scene.pass_confirm_guard()
		_scene.press_ult())
	_scripted.append(func() -> void:
		_expect(battle.ult_uses[0] == 1 and battle.ult_gauge[0] == 0, "必殺技を使えなかった")
		_expect(_scene.played.get(used, 0) == 1, "必殺技を再生しなかった")
		_expect(trooper.power() == power + AllOutAssaultUlt.POWER_BONUS, "総員突撃が付いていない")
		_expect(not _scene.is_ult_enabled() and _scene.ult_gauge_text(0) == "0%", "使ったあとに、ゲージが空になっていない")
		_expect(_scene.selected_unit() == trooper and not trooper.acted, "必殺技で、駒の行動を使った")
		# 伸びた移動力（3 + 2）で動ける。
		_scene.click_cell(Vector2i(6, 3)))
	_scripted.append(func() -> void:
		_expect(trooper.cell == Vector2i(6, 3), "伸びた移動力で動けなかった")
		_scene.press_wait())
	_scripted.append(func() -> void:
		battle.ult_gauge[Unit.Side.PLAYER2] = Ults.GAUGE_MAX - 1
		_scene.played.erase(ready)
		_end_turn())
	_scripted.append(func() -> void:
		_expect(_scene.played.get(ready, 0) == 1, "ゲージがいっぱいになったことを再生しなかった")
		_expect(_scene.ult_gauge_text(1) == "READY" and _scene.is_ult_enabled(), "プレイヤー2 の番に、必殺技のボタンが押せない")
		_expect(not _scene.guide_overflows(), "必殺技のボタンが広がって、下の帯の案内がはみ出した: %s" % _scene.guide_text())
		_scene.press_ult()
		_scene.pass_confirm_guard()
		_scene.press_ult())
	_scripted.append(func() -> void:
		_expect(sorcerer.skill_cooldown == 0, "魔力解放でクールダウンが 0 にならなかった"))
