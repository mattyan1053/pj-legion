extends "res://tools/shots/setup_scenes.gd"
## スクリーンショットの場面: 対戦の操作（選ぶ、メニュー、脅威範囲、カメラ、ミニマップ）と、手で作ったマップの対戦の始め。
## 見込みと情報・決着・ログは、次の battle_info_scenes.gd。


## 一覧の最初の手で作ったマップ（画面に出していないものも）。無ければ空。
func _first_hand_field() -> StringName:
	for field in VersusFields.all_ids():
		if not VersusFields.is_generated(field):
			return field
	return &""


func _scene_versus_hand_start() -> bool:
	_field = _first_hand_field()
	if _field == &"":
		return false
	_new_battle()
	_show()
	return true


## 一覧の最後の手で作ったマップ（画面に出していないものも）。無ければ空。
func _last_hand_field() -> StringName:
	var last: StringName = &""
	for field in VersusFields.all_ids():
		if not VersusFields.is_generated(field):
			last = field
	return last


func _scene_versus_hand_last_start() -> bool:
	_field = _last_hand_field()
	if _field == &"":
		return false
	_new_battle()
	_show()
	return true


func _scene_start() -> bool:
	_show()
	return true


func _scene_minimap_pointed() -> bool:
	if not _advance(func() -> bool: return _battle.turn >= 3 and _battle.phase == Unit.Side.PLAYER1):
		return false
	_show()
	var hq: Vector2i = _battle.board.hq_cells[Unit.Side.PLAYER2]
	_scene.point_minimap(Vector2(hq) + Vector2(0.5, 3.5))
	return _scene.minimap_rect().has_area()


func _scene_minimap_hidden() -> bool:
	_show()
	_scene.settings.set_value(&"show_minimap", false)
	return true


func _scene_phase_camera() -> bool:
	# 相手（プレイヤー2）の番の終わりの手前まで進め、その番の終わりだけを画面に通す（中立の番のあと、自分の番の始めにカメラが寄る）。
	# CPU は将を最後に動かすので、そのままでは将に寄るのと見分けが付かない。撮る番だけ、自分の番の始めに将を先に待機させる。
	var events: Array[BattleEvent] = []
	var watch := func(happened: Array[BattleEvent]) -> void: events.append_array(happened)
	if not _advance(func() -> bool: return _battle.turn >= 4 and _battle.phase == Unit.Side.PLAYER1, watch):
		return false
	var king := Queries.king_of(_battle, Unit.Side.PLAYER1)
	if king != null and _battle.can_apply(WaitAction.new(king.id)):
		var result := _battle.apply(WaitAction.new(king.id))
		_stats.feed_all(result.events)
		_log.feed_all(result.events)
		events.append_array(result.events)
	if not _advance(func() -> bool: return _battle.phase == Unit.Side.PLAYER2 and _cpu.next_action(_battle) is EndPhaseAction, watch):
		return false
	_show()
	var focus: Unit = _scene.phase_focus_after(events, Unit.Side.PLAYER1)
	await _scene.act(EndPhaseAction.new())
	if focus == null or _battle.phase != Unit.Side.PLAYER1:
		return false
	_scene.mark_cell(focus.cell)  # 寄った駒を示す（撮るためだけ）
	print("screenshots: フェーズの始めに寄った駒 %s %s" % [Names.kind(focus.kind), focus.cell])
	return true


func _scene_pitch_low() -> bool:
	_show()
	_scene.set_camera_pitch(OrbitCamera.MIN_PITCH)
	return true


func _scene_pitch_high() -> bool:
	_show()
	_scene.set_camera_pitch(OrbitCamera.MAX_PITCH)
	return true


func _scene_move() -> bool:
	_show()
	# 動ける範囲のいちばん広い駒を選ぶ。
	var best: Unit = null
	var most := -1
	for unit in _own_units():
		var count := Queries.move_cells(_battle, unit).size()
		if count > most:
			best = unit
			most = count
	_scene.click_cell(best.cell)
	return true


func _scene_cell() -> bool:
	_show()
	# 樽（無ければ森）のマスをクリックする。
	var cell := Vector2i(-1, -1)
	if not _battle.board.barrel_cells.is_empty():
		cell = _battle.board.barrel_cells[0]
	else:
		for y in _battle.board.size.y:
			for x in _battle.board.size.x:
				if cell.x < 0 and _battle.board.terrain_at(Vector2i(x, y)) == Terrain.Type.FOREST:
					cell = Vector2i(x, y)
	_scene.click_cell(cell)
	_scene.focus_camera(cell)
	return _scene.info_title().begins_with("マス")


## 動けば攻撃できる相手がいる駒と、その行き先（[駒, マス]）。無ければ空。
func _move_then_attack() -> Array:
	for unit in _own_units():
		if not _battle.can_act(unit) or UnitKind.role(unit.kind) == UnitKind.Role.HEALER:
			continue
		for cell: Vector2i in _battle.options(unit.id).move_cells:
			if cell == unit.cell:
				continue
			var trial := _battle.clone()
			trial.apply(MoveAction.new(unit.id, cell, false))
			if not trial.options(unit.id).attack_target_ids.is_empty():
				return [unit, cell]
	return []


func _scene_menu_moved() -> bool:
	if not _advance(func() -> bool: return _battle.phase != Unit.Side.NEUTRAL and not _move_then_attack().is_empty()):
		return false
	var found := _move_then_attack()
	var unit: Unit = found[0]
	_show()
	_scene.click_cell(unit.cell)
	await _scene.act(MoveAction.new(unit.id, found[1], false))
	_scene.focus_camera(unit.cell)
	return _scene.menu_ids().has(&"attack") and _scene.menu_ids().has(&"undo")


func _scene_menu_attack() -> bool:
	if not await _scene_menu_moved():
		return false
	return _scene.press_menu(&"attack") and _scene.is_choosing_target()


func _scene_menu_crowd() -> bool:
	# 両軍がぶつかったあとの、周りに駒のいちばん多い自分の駒。
	if not _advance(func() -> bool: return _battle.turn >= 4 and _battle.phase == Unit.Side.PLAYER1):
		return false
	_show()
	var best: Unit = null
	var most := -1
	for unit in _own_units():
		if not _battle.can_act(unit):
			continue
		var near := 0
		for other in _battle.units:
			if other != unit and maxi(absi(other.cell.x - unit.cell.x), absi(other.cell.y - unit.cell.y)) <= 2:
				near += 1
		if near > most:
			best = unit
			most = near
	if best == null:
		return false
	_scene.click_cell(best.cell)
	_scene.focus_camera(best.cell)
	return not _scene.menu_ids().is_empty()


func _scene_menu_edge() -> bool:
	_show()
	# 盤の下の端にいちばん近い駒を選び、カメラをずらして、その駒を画面の右下の隅に寄せる。
	var best: Unit = null
	for unit in _own_units():
		if best == null or unit.cell.y > best.cell.y or (unit.cell.y == best.cell.y and unit.cell.x > best.cell.x):
			best = unit
	_scene.click_cell(best.cell)
	_scene.focus_camera(best.cell + Vector2i(-11, -4))
	return not _scene.menu_ids().is_empty()


func _scene_threat() -> bool:
	# 両軍が近づいた、ターン 3 のプレイヤー1 の番の始め。
	if not _advance(func() -> bool: return _battle.turn >= 3 and _battle.phase == Unit.Side.PLAYER1):
		return false
	_show()
	# 自分の駒にいちばん近い、相手の駒（将は除く）を選ぶ。
	var best: Unit = null
	var nearest := 1 << 30
	for foe in _battle.units:
		if foe.side != 1 - _battle.phase or foe.kind == UnitKind.Id.KING:
			continue
		for unit in _own_units():
			var distance := _distance(foe.cell, unit.cell)
			if distance < nearest:
				best = foe
				nearest = distance
	if best == null:
		return false
	_scene.click_cell(best.cell)
	_scene.focus_camera(best.cell)
	return true


func _scene_inspect_moved() -> bool:
	if not await _scene_menu_moved():
		return false
	# 動いた駒にいちばん近い、攻撃の相手でない相手の駒（将と回復役は除く。相手の駒はクリックで攻撃してしまい、回復役には脅威範囲が無い）。
	var mover: Unit = _scene.selected_unit()
	var targets := _battle.options(mover.id).attack_target_ids
	var best: Unit = null
	var nearest := 1 << 30
	for foe in _battle.units:
		if foe.side != 1 - _battle.phase or foe.kind == UnitKind.Id.KING or targets.has(foe.id):
			continue
		if UnitKind.role(foe.kind) == UnitKind.Role.HEALER:
			continue
		if _distance(foe.cell, mover.cell) < nearest:
			best = foe
			nearest = _distance(foe.cell, mover.cell)
	if best == null:
		return false
	_scene.click_cell(best.cell)
	_look_at((BoardView.cell_center(best.cell) + BoardView.cell_center(mover.cell)) / 2.0)
	_aim(26.0, 0.0, OrbitCamera.DEFAULT_PITCH)
	return _scene.inspected_unit() == best and _scene.selected_unit() == mover


func _scene_threat_all() -> bool:
	if not _advance(func() -> bool: return _battle.turn >= 3 and _battle.phase == Unit.Side.PLAYER1):
		return false
	_show()
	var unit := _own_units()[0]
	for own in _own_units():
		if own.kind != UnitKind.Id.KING and _battle.can_act(own):
			unit = own
			break
	_scene.click_cell(unit.cell)
	_scene.toggle_threat()
	_scene.focus_camera(unit.cell)
	return _scene.is_threat_shown()


func _scene_threat_pin_switch() -> bool:
	if not await _scene_threat():
		return false
	var shown: Array[bool] = _scene.pin_switch_state()
	return shown[0] and _scene.press_pin_switch() and _scene.pin_switch_state()[1]


func _scene_threat_pinned() -> bool:
	if not await _scene_threat_pin_switch():
		return false
	var first: Unit = _scene.inspected_unit()
	# もう 1 体: 留めた駒にいちばん近い、ほかの相手の駒（将は除く）。
	var second: Unit = null
	for foe in _battle.units:
		if foe.side == first.side and foe != first and foe.kind != UnitKind.Id.KING:
			if second == null or _distance(foe.cell, first.cell) < _distance(second.cell, first.cell):
				second = foe
	if second == null:
		return false
	_scene.click_cell(second.cell)
	_scene.press_pin_switch()
	_scene.cancel()  # 見るのをやめる（範囲は残る）
	_scene.toggle_threat()
	return _scene.pinned_ids().size() == 2 and _scene.is_threat_shown()


## field のマップで、敵の全員の脅威範囲を出し、自分の駒の近くの相手の駒を見る（斜線と、見ている駒の赤い塗りが重なる）。
func _threat_mix(field: StringName) -> bool:
	_field = field
	_new_battle()
	if not await _scene_threat():
		return false
	_scene.toggle_threat()
	return _scene.is_threat_shown() and not _scene.threat_painted_cells().is_empty()


func _scene_threat_mix_plain() -> bool:
	return await _threat_mix(VersusFields.PLAIN)


func _scene_threat_mix_labyrinth() -> bool:
	return await _threat_mix(VersusFields.LABYRINTH)


func _scene_threat_mix_twin_springs() -> bool:
	return await _threat_mix(VersusFields.TWIN_SPRINGS)


