extends "res://tools/shots/title_scenes.gd"
## スクリーンショットの場面: 対戦設定（部隊・初期位置・手番）と、選べる決まり（砲台・組み方・縫い目の様子・拠点）。


func _scene_setup_ridge() -> bool:
	_app.context.match_choice = MatchChoice.new()
	_app.context.match_choice.field = VersusFields.RIDGE_PATH
	await _app.go(SceneFlow.SETUP)
	return _app.current_id() == SceneFlow.SETUP


func _scene_setup_deck() -> bool:
	_fill_decks()
	_app.context.match_choice = MatchChoice.new()
	await _app.go(SceneFlow.SETUP)
	if _app.current_id() != SceneFlow.SETUP:
		return false
	var panel: Node = _app.current_scene().setup_panel()
	if not panel.choose_deck(Unit.Side.PLAYER1, _app.context.decks.items()[0].id):
		return false
	_park_mouse()
	await get_tree().process_frame
	panel.open_deck_picker(Unit.Side.PLAYER1)
	return true


func _scene_setup_unit_detail() -> bool:
	if not await _scene_setup_preview():
		return false
	var preview: Control = _app.current_scene().setup_panel().preview()
	preview.press_card(1)
	return preview.detail().visible


func _scene_setup_placement() -> bool:
	_app.context.match_choice = MatchChoice.new()
	await _app.go(SceneFlow.SETUP)
	if _app.current_id() != SceneFlow.SETUP:
		return false
	var panel: Node = _app.current_scene().setup_panel()
	panel.open_placement(Unit.Side.PLAYER1)
	return _move_and_pick(panel.placement_dialog().deploy_map())


## 初期位置の縮図 deploy で、最初の駒を空いている置けるマスへ動かし、2 番目の駒を選んでおく。
func _move_and_pick(deploy: Control) -> bool:
	var own: Array[Vector2i] = deploy.unit_cells()
	var open: Array = deploy.zone().filter(func(cell: Vector2i) -> bool: return not own.has(cell))
	if own.size() < 2 or open.is_empty():
		return false
	deploy.press_cell(own[0])
	deploy.press_cell(open[open.size() - 1])
	deploy.press_cell(own[1])
	_park_mouse()
	return deploy.selected() == 1


func _scene_setup_preview() -> bool:
	_fill_decks()
	_app.context.match_choice = MatchChoice.new()
	await _app.go(SceneFlow.SETUP)
	if _app.current_id() != SceneFlow.SETUP:
		return false
	var panel: Node = _app.current_scene().setup_panel()
	panel.choose_deck(Unit.Side.PLAYER1, _app.context.decks.items()[0].id)
	panel.open_preview(Unit.Side.PLAYER2)
	_park_mouse()
	return panel.preview().visible


func _scene_setup_cpu_deck() -> bool:
	_fill_decks()
	_app.context.match_choice = MatchChoice.new()
	await _app.go(SceneFlow.SETUP)
	if _app.current_id() != SceneFlow.SETUP:
		return false
	var panel: Node = _app.current_scene().setup_panel()
	if not panel.choose_deck(Unit.Side.PLAYER2, MatchChoice.RANDOM):
		return false
	_park_mouse()
	await get_tree().process_frame
	panel.open_deck_picker(Unit.Side.PLAYER2)
	return true


func _scene_setup_cpu_random() -> bool:
	_app.context.match_choice = MatchChoice.new()
	await _app.go(SceneFlow.SETUP)
	if _app.current_id() != SceneFlow.SETUP:
		return false
	var panel: Node = _app.current_scene().setup_panel()
	panel.choose_deck(Unit.Side.PLAYER2, MatchChoice.RANDOM)
	panel.confirm()
	await _app.scene_changed
	if _app.current_id() != SceneFlow.BATTLE:
		return false
	_scene = _app.current_scene()
	var battle_scene: Node = _scene
	for i in 120:
		if not battle_scene.is_busy():
			break
		await get_tree().process_frame
	battle_scene.open_setup()
	var shown: Node = battle_scene.setup_panel()
	if not shown.visible or not shown.can_preview(Unit.Side.PLAYER2):
		return false
	shown.open_preview(Unit.Side.PLAYER2)
	_park_mouse()
	return shown.preview().visible


## 本物の入力で、手番ランダムの後手の初期位置を確かめる: 対戦設定の「初期位置」で最初の駒を端へ動かし、手番を「ランダム」にして始め、
## 後手を引く種まで「同じ設定のまま新しい種」で始め直す。後手の最初の駒が、点対称に返したマスにいなければ偽。
func _scene_setup_random_second() -> bool:
	var choice := MatchChoice.new()
	choice.field = VersusFields.TWIN_SPRINGS
	_app.context.match_choice = choice
	await _app.go(SceneFlow.SETUP)
	if _app.current_id() != SceneFlow.SETUP:
		return false
	var panel: Node = _app.current_scene().setup_panel()
	panel.open_placement(Unit.Side.PLAYER1)
	var dialog: Control = panel.placement_dialog()
	var deploy: Control = dialog.deploy_map()
	var own: Array[Vector2i] = deploy.unit_cells()
	var open: Array = deploy.zone().filter(func(cell: Vector2i) -> bool: return not own.has(cell))
	if own.is_empty() or open.is_empty():
		return false
	# 盤の端の側（本陣が左下なので、列の小さいほう）の、空いている置けるマスへ。
	open.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x)
	deploy.press_cell(own[0])
	deploy.press_cell(open[0])
	dialog.close_dialog()
	var offset: Vector2i = open[0] - panel.current_choice().placement_preview(Unit.Side.PLAYER1, panel.PLACEMENT_SEED)[1].board.hq_cells[0]
	panel.choose_random_side()
	panel.confirm()
	await _app.scene_changed
	if _app.current_id() != SceneFlow.BATTLE:
		return false
	_scene = _app.current_scene()
	for battle_seed in range(1, 60):
		if _scene.source.cpu_side() == Unit.Side.PLAYER1:
			break
		for i in 120:
			if not _scene.is_busy():
				break
			await get_tree().process_frame
		_scene.start_battle(battle_seed)
	if _scene.source.cpu_side() != Unit.Side.PLAYER1:
		return false
	var battle: Battle = _scene.battle
	var first: Array = battle.units.filter(func(unit: Unit) -> bool: return unit.side == Unit.Side.PLAYER2 and unit.kind != UnitKind.Id.KING)
	if first.is_empty() or first[0].cell != battle.board.hq_cells[Unit.Side.PLAYER2] - offset:
		push_error("screenshots: 後手の最初の駒が %s（点対称に返したマスは %s）" % [first[0].cell if not first.is_empty() else null, battle.board.hq_cells[1] - offset])
		return false
	for i in 600:
		if not _scene.is_busy():
			break
		await get_tree().process_frame
	_park_mouse()
	return true


func _scene_setup_random() -> bool:
	_app.context.match_choice = MatchChoice.new()
	await _app.go(SceneFlow.SETUP)
	if _app.current_id() != SceneFlow.SETUP:
		return false
	_app.current_scene().setup_panel().choose_random_side()
	_park_mouse()
	return true


func _scene_setup_seam() -> bool:
	_app.context.match_choice = MatchChoice.new()
	await _app.go(SceneFlow.SETUP)
	if _app.current_id() != SceneFlow.SETUP:
		return false
	_app.current_scene().setup_panel().choose_rule(OptionalRules.SEAM, true)
	_park_mouse()
	return _app.current_scene().setup_panel().current_choice().has_rule(OptionalRules.SEAM)


func _scene_signs() -> bool:
	var choice: RefCounted = MatchChoice.new()
	choice.field = VersusFields.PLAIN
	choice.set_rule(OptionalRules.SEAM, true)
	_scene.source = choice
	_scene.start_battle(_seed)
	_park_mouse()
	return _scene.signs_pending() and _scene.signs_window().card_texts().size() == Seam.DRAWN


func _scene_signs_start() -> bool:
	_field = VersusFields.PLAIN
	_new_battle([OptionalRules.STRONGHOLD, OptionalRules.SEAM])
	_show()
	return _scene.notice_text().contains("縫い目の様子") and _scene.signs_text() != ""


func _scene_formation_start() -> bool:
	_field = VersusFields.PLAIN
	_new_battle([OptionalRules.STRONGHOLD, OptionalRules.FORMATION])
	_show()
	return _scene.formation_link_count() > 0


## 誓いの相手を攻撃した敵（仇）が決まった、騎士領の誓いの駒。無ければ null。
func _oath_with_foe() -> Unit:
	for unit in _battle.units:
		if Formation.partner_of(_battle, unit) != null and Formation.foe_of_partner(_battle, unit) != null:
			return unit
	return null


func _scene_formation_oath() -> bool:
	_field = VersusFields.PLAIN
	_new_battle([OptionalRules.STRONGHOLD, OptionalRules.FORMATION])
	if not _advance(func() -> bool: return _battle.phase == Unit.Side.PLAYER1 and _oath_with_foe() != null):
		return false
	var unit := _oath_with_foe()
	_show()
	_scene.click_cell(unit.cell)
	_scene.focus_camera(unit.cell)
	return _scene.info_text().contains("誓い")


## 行動できる自分の駒が、組み方の効果の乗る攻撃をできる相手（[駒, 相手]）。無ければ空。
func _formation_attack() -> Array:
	for unit in _own_units():
		if not _battle.can_act(unit):
			continue
		for target_id in _battle.options(unit.id).attack_target_ids:
			var outcome := Forecast.of(_battle, AttackAction.new(unit.id, target_id)).outcome(target_id)
			if outcome != null and not outcome.formation.is_empty():
				return [unit, _battle.unit_by_id(target_id)]
	return []


func _scene_formation_forecast() -> bool:
	_field = VersusFields.PLAIN
	_new_battle([OptionalRules.STRONGHOLD, OptionalRules.FORMATION])
	if not _advance(func() -> bool: return _battle.phase != Unit.Side.NEUTRAL and not _formation_attack().is_empty()):
		return false
	var found := _formation_attack()
	_show()
	_scene.click_cell(found[0].cell)
	_look_at(BoardView.cell_center(found[1].cell))
	_scene.hover(found[1].cell)
	return true


func _scene_setup_stronghold() -> bool:
	_app.context.match_choice = MatchChoice.new()
	await _app.go(SceneFlow.SETUP)
	if _app.current_id() != SceneFlow.SETUP:
		return false
	_app.current_scene().setup_panel().choose_rule(OptionalRules.STRONGHOLD, true)
	_park_mouse()
	return _app.current_scene().setup_panel().current_choice().has_rule(OptionalRules.STRONGHOLD)


func _scene_setup() -> bool:
	_app.context.match_choice = MatchChoice.new()  # 遊ぶときの始めと同じ（相手は CPU）で開く
	await _app.go(SceneFlow.SETUP)
	return _app.current_id() == SceneFlow.SETUP


func _scene_setup_again() -> bool:
	if not _advance(func() -> bool: return _battle.turn >= 3 and _battle.phase == Unit.Side.PLAYER1):
		return false
	_show()
	_scene.open_setup()
	return _scene.setup_panel().is_cancellable()


func _scene_setup_confirm() -> bool:
	if not _scene_setup_again():
		return false
	_scene.setup_panel().press_map()
	return _scene.setup_panel().confirming_text() != ""
