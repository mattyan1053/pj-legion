extends "res://tools/shots/story_battle_scenes.gd"
## スクリーンショットの場面: ストーリーの見回りの話（魔物の群れ）の対戦。魔物ごとの姿・技・範囲と、盤の決まり（胞子・谷・殻蟹）。


## 盤の上の、その種類の最初の駒。いなければ null。
## 番外の物語（berk_patrol）の number 番目の話の対戦を、画面に出す。
func _patrol_battle(number: int) -> bool:
	var patrol: RefCounted = null
	for campaign: RefCounted in Story.campaigns():
		if campaign.id == &"berk_patrol":
			patrol = campaign
	if patrol == null:
		return false
	_app.context.story.choose_campaign(patrol)  # クリアは、いま選んでいる物語の記録に書く
	for i: int in number:
		_app.context.story.clear(patrol.episodes[i].id)
	if not await _scene_story_campaigns():
		return false
	_app.current_scene().choose(patrol)
	await _app.scene_changed
	if _app.current_id() != SceneFlow.EPISODES:
		return false
	_app.current_scene().choose(patrol.episodes[number])
	await _app.scene_changed
	if not _at_sortie() or not await _sortie_to_battle():
		return false
	_scene = _app.current_scene()
	return true


func _scene_story_patrol_bats() -> bool:
	if not await _patrol_battle(0):
		return false
	var bat := _first_unit_of(UnitKind.Id.BAT)
	if bat == null:
		return false
	_scene.hide_notice()  # 対戦ルールの知らせを閉じて、盤を見せる
	_look_at(BoardView.cell_center(bat.cell))
	_aim(9.0, 0.0, 50.0)
	_scene.hover(bat.cell)
	return true


func _scene_story_patrol_knot() -> bool:
	if not await _patrol_battle(1):
		return false
	var setup: MatchSetup = _scene.source.make_setup(_seed)
	_battle = setup.create_battle()
	_stats = BattleStats.new(_battle)
	_log = BattleLog.new(_battle, ["プレイヤー1（青）", "CPU（赤）"] as Array[String])
	var knot_cell := func() -> Vector2i:
		for effect in _battle.board.field_effects:
			if effect.type == FieldEffect.Type.KNOT:
				return effect.center
		return Board.NO_CELL
	# 結び目が残ったあと、人の番の始めで止める。
	if not _advance(func() -> bool: return knot_cell.call() != Board.NO_CELL and _battle.phase == Unit.Side.PLAYER1):
		return false
	_scene.start_with(_battle, _scene.source.look(), _seed, setup.scenario.title)
	_scene.stats = _stats
	_scene.battle_log = _log
	_scene.hide_notice()
	var cell: Vector2i = knot_cell.call()
	_look_at(BoardView.cell_center(cell))
	_aim(9.0, 0.0, 50.0)
	_scene.hover(cell)
	return true


func _scene_story_patrol_needles() -> bool:
	if not await _patrol_battle(2):
		return false
	var needle := _first_unit_of(UnitKind.Id.NEEDLE)
	if needle == null:
		return false
	_scene.hide_notice()
	_look_at(BoardView.cell_center(needle.cell))
	_aim(9.0, 30.0, 50.0)
	_scene.hover(needle.cell)
	return true


func _scene_story_patrol_eaters() -> bool:
	if not await _patrol_battle(3):
		return false
	var eater := _first_unit_of(UnitKind.Id.EATER)
	if eater == null:
		return false
	_scene.hide_notice()
	_look_at(BoardView.cell_center(eater.cell))
	_aim(8.0, 20.0, 50.0)
	_scene.hover(eater.cell)
	return true


func _scene_story_patrol_spider() -> bool:
	if not await _patrol_battle(3):
		return false
	var spider := _first_unit_of(UnitKind.Id.SPIDER)
	if spider == null:
		return false
	_scene.hide_notice()
	_look_at(BoardView.cell_center(spider.cell))
	_aim(7.0, -20.0, 50.0)
	_scene.hover(spider.cell)
	return true


## 糸蜘蛛に絡められた人の駒がいる、人の番の始め。その駒にマウスを乗せる（状態の欄に絡み）。
func _scene_story_patrol_snare() -> bool:
	if not await _patrol_battle(3):
		return false
	var setup: MatchSetup = _scene.source.make_setup(_seed)
	_battle = setup.create_battle()
	_stats = BattleStats.new(_battle)
	_log = BattleLog.new(_battle, ["プレイヤー1（青）", "CPU（赤）"] as Array[String])
	var snared := func() -> Unit:
		for unit: Unit in _battle.units:
			if unit.side == Unit.Side.PLAYER1 and Statuses.has(unit, Status.Type.SNARE):
				return unit
		return null
	if not _advance(func() -> bool: return _battle.phase == Unit.Side.PLAYER1 and snared.call() != null):
		return false
	_scene.start_with(_battle, _scene.source.look(), _seed, setup.scenario.title)
	_scene.stats = _stats
	_scene.battle_log = _log
	_scene.hide_notice()
	var unit: Unit = snared.call()
	_look_at(BoardView.cell_center(unit.cell))
	_aim(8.0, 0.0, 50.0)
	_scene.hover(unit.cell)
	return true


func _scene_story_patrol_crab() -> bool:
	return await _patrol_hover(UnitKind.Id.CRAB, 20.0)


func _scene_story_patrol_shroom() -> bool:
	return await _patrol_hover(UnitKind.Id.SHROOM, -20.0)


## 番外の 5 話目の対戦の始めに、kind の最初の駒へ寄って、マウスを乗せる。
func _patrol_hover(kind: UnitKind.Id, yaw: float) -> bool:
	if not await _patrol_battle(4):
		return false
	var unit := _first_unit_of(kind)
	if unit == null:
		return false
	_scene.hide_notice()
	_look_at(BoardView.cell_center(unit.cell))
	_aim(6.0, yaw, 45.0)
	_scene.hover(unit.cell)
	return true


## 番外の 5 話目を CPU どうしで進め、until が真になった人の番の始めを画面に出す。
func _patrol_vale_until(until: Callable) -> bool:
	if not await _patrol_battle(4):
		return false
	var setup: MatchSetup = _scene.source.make_setup(_seed)
	_battle = setup.create_battle()
	_stats = BattleStats.new(_battle)
	_log = BattleLog.new(_battle, ["プレイヤー1（青）", "CPU（赤）"] as Array[String])
	if not _advance(func() -> bool: return _battle.phase == Unit.Side.PLAYER1 and until.call()):
		return false
	_scene.start_with(_battle, _scene.source.look(), _seed, setup.scenario.title)
	_scene.stats = _stats
	_scene.battle_log = _log
	_scene.hide_notice()
	return true


func _scene_story_patrol_vale() -> bool:
	if not await _patrol_vale_until(func() -> bool: return _battle.turn >= 4):
		return false
	var size := _battle.board.size
	_look_at(BoardView.cell_center(Vector2i(size.x / 2, size.y / 2 + 1)))
	_aim(19.0, 0.0, 62.0)
	return true


## 人の番で、糸茸の隣にいる行動できる人の駒と、その駒がいまの位置から胞子で弱まって攻撃できる相手（[駒, 相手]）。無ければ空。
func _spored_attack() -> Array:
	for unit: Unit in _battle.units:
		if unit.side != Unit.Side.PLAYER1 or not _battle.can_act(unit) or Monsters.spore_penalty(_battle, unit) == 0:
			continue
		for target in Combat.targets(_battle, unit):
			if Combat.hit(_battle, unit, target).spores:
				return [unit, target]
	return []


func _scene_story_patrol_spores() -> bool:
	if not await _patrol_vale_until(func() -> bool: return not _spored_attack().is_empty()):
		return false
	var found := _spored_attack()
	var unit: Unit = found[0]
	var target: Unit = found[1]
	_look_at(BoardView.cell_center(unit.cell))
	_aim(8.0, 0.0, 50.0)
	for i in 3:
		await get_tree().process_frame
	_scene.click_cell(unit.cell)
	_scene.click_cell(unit.cell)  # 動かずに、その場で行動のメニューを出す
	for i in 120:
		await get_tree().process_frame
	if not _scene.press_menu(&"attack"):
		return false
	_scene.hover(target.cell)
	return _scene.forecast_text().contains(Text.t("battle.log.note.spores"))


## 番外の 4 話目（全滅させる）と 5 話目（守り切る 8 ターン）の対戦の始めの、対戦ルールの札と上の帯。
func _scene_story_patrol_rules_eaters() -> bool:
	return await _patrol_battle(3) and _scene.notice_text() != ""


func _scene_story_patrol_rules_vale() -> bool:
	return await _patrol_battle(4) and _scene.notice_text() != ""


## 番外の 5 話目で、離れて攻撃する人の駒を選び、攻撃の相手を選ぶところ。届く距離に殻蟹がいるが、離れているので狙えない。
## 殻蟹にマウスを乗せる（範囲の色と、駒の情報の札の言葉）。
func _scene_story_patrol_crab_far() -> bool:
	var found := func() -> Array:
		for unit: Unit in _battle.units:
			if unit.side != Unit.Side.PLAYER1 or not _battle.can_act(unit) or Combat.targets(_battle, unit).is_empty():
				continue
			for crab: Unit in _battle.units:
				if crab.kind == UnitKind.Id.CRAB and Monsters.shell_turns_away(unit.cell, crab) \
						and Combat.reaches(_battle, unit.cell, crab.cell, unit.attack_range()):
					return [unit, crab]
		return []
	if not await _patrol_vale_until(func() -> bool: return not found.call().is_empty()):
		return false
	var pair: Array = found.call()
	var unit: Unit = pair[0]
	var crab: Unit = pair[1]
	_look_at((BoardView.cell_center(unit.cell) + BoardView.cell_center(crab.cell)) * 0.5)
	_aim(10.0, 0.0, 55.0)
	for i in 3:
		await get_tree().process_frame
	_scene.click_cell(unit.cell)
	_scene.click_cell(unit.cell)  # 動かずに、その場で行動のメニューを出す
	for i in 120:
		await get_tree().process_frame
	if not _scene.press_menu(&"attack"):
		return false
	_scene.hover(crab.cell)
	return true


## 番外の 4 話目で、人の駒が糸喰いを倒し、腹の糸が弾けた瞬間（届いたマスの色と「弾けた」）。演出の途中を撮る。
func _scene_story_patrol_burst() -> bool:
	if not await _patrol_battle(3):
		return false
	var setup: MatchSetup = _scene.source.make_setup(_seed)
	_battle = setup.create_battle()
	_stats = BattleStats.new(_battle)
	_log = BattleLog.new(_battle, ["プレイヤー1（青）", "CPU（赤）"] as Array[String])
	var finisher := func() -> Array:
		if _battle.phase != Unit.Side.PLAYER1:
			return []
		for unit: Unit in _battle.units:
			if unit.side != Unit.Side.PLAYER1 or not _battle.can_act(unit):
				continue
			for target: Unit in Combat.targets(_battle, unit):
				if target.kind == UnitKind.Id.EATER and Combat.damage(_battle, unit, target) >= target.hp:
					return [unit, target]
		return []
	if not _advance(func() -> bool: return not finisher.call().is_empty()):
		return false
	_scene.start_with(_battle, _scene.source.look(), _seed, setup.scenario.title)
	_scene.stats = _stats
	_scene.battle_log = _log
	_scene.hide_notice()
	var pair: Array = finisher.call()
	var unit: Unit = pair[0]
	var target: Unit = pair[1]
	await _settle_camera(target.cell)
	_park_mouse()
	_scene.set_time_scale_base(SLOW_MOTION)
	_scene.act(AttackAction.new(unit.id, target.id))
	await get_tree().create_timer(BURST_AFTER).timeout
	_mid_animation = true
	return true
