extends "res://tools/shots/effect_scenes.gd"
## スクリーンショットの場面: 盤と景色（カメラの構図、マップの見た目、泉・ポータル・砲台・拠点）と、景色の場面（scape.<マップ>.<構図>）。


func _scene_wide() -> bool:
	if not _advance(func() -> bool: return _battle.turn >= 3 and _battle.phase == Unit.Side.PLAYER1):
		return false
	_show()
	_look_at(Vector3(_battle.board.size.x / 2.0, 0.0, _battle.board.size.y / 2.0 + 6.0))
	_aim(45.0, 0.0, OrbitCamera.MIN_PITCH)
	return true


func _scene_board_edge() -> bool:
	_show()
	# 盤の左上の角の近くに立って、角の外へ向く。
	_look_at(Vector3(1.5, 0.0, 1.5))
	_aim(26.0, -40.0, 35.0)
	return true


func _scene_rotated() -> bool:
	if not _advance(func() -> bool: return _battle.turn >= 3 and _battle.phase == Unit.Side.PLAYER1):
		return false
	_show()
	_look_at(_scene.camera_center())
	_aim(30.0, 130.0, 35.0)
	return true


func _scene_marks() -> bool:
	# 行動済みの駒と、HP の減った駒が並ぶところ: 番の途中で、HP の減った自分の駒がまだ動けるとき。
	var hurt := func() -> Unit:
		for unit in _own_units():
			if unit.hp < unit.max_hp() and _battle.can_act(unit) and unit.kind != UnitKind.Id.KING:
				return unit
		return null
	var acted := func() -> bool:
		for unit in _own_units():
			if not _battle.can_act(unit):
				return true
		return false
	if not _advance(func() -> bool: return _battle.phase == Unit.Side.PLAYER1 and acted.call() and hurt.call() != null):
		return false
	_show()
	var unit: Unit = hurt.call()
	# カメラを寄せ終えてから選ぶ（寄る途中で選ぶと、メニューの置き場所が撮る時刻で 2 通りに変わる）。
	_look_at(Vector3(unit.cell.x + 0.5, 0.0, unit.cell.y + 0.5))
	_aim(11.0, 0.0, 50.0)
	await _camera_still()
	_scene.click_cell(unit.cell)
	return true


func _scene_stage_labyrinth() -> bool:
	return _stage_overview(BoardGenerator.Stage.LABYRINTH)


func _scene_stage_twin_springs() -> bool:
	return _stage_overview(BoardGenerator.Stage.TWIN_SPRINGS)


## マップの見た目を比べる 3 枚（始め・引いた・寄った）。どのマップも同じ構図で撮る。
func _stage_look(stage: BoardGenerator.Stage, view: StringName) -> bool:
	_field = VersusFields.field_of_stage(stage)
	_new_battle()
	_show()
	var middle := Vector3(_battle.board.size.x / 2.0, 0.0, _battle.board.size.y / 2.0)
	match view:
		&"wide":
			_look_at(middle + Vector3(0.0, 0.0, 6.0))
			_aim(45.0, 0.0, OrbitCamera.MIN_PITCH)
		&"close":
			_look_at(middle)
			_aim(12.0, 20.0, 45.0)
		&"crag":
			_look_at(middle)
			_aim(22.0, 140.0, 42.0)
		&"crag_low":
			_look_at(middle + Vector3(0.0, 0.0, 5.0))
			_aim(16.0, 0.0, OrbitCamera.MIN_PITCH)
	return true


func _scene_look_plain_start() -> bool:
	return _stage_look(BoardGenerator.Stage.PLAIN, &"start")


func _scene_look_plain_wide() -> bool:
	return _stage_look(BoardGenerator.Stage.PLAIN, &"wide")


func _scene_look_plain_close() -> bool:
	return _stage_look(BoardGenerator.Stage.PLAIN, &"close")


func _scene_look_labyrinth_start() -> bool:
	return _stage_look(BoardGenerator.Stage.LABYRINTH, &"start")


func _scene_look_labyrinth_wide() -> bool:
	return _stage_look(BoardGenerator.Stage.LABYRINTH, &"wide")


func _scene_look_labyrinth_close() -> bool:
	return _stage_look(BoardGenerator.Stage.LABYRINTH, &"close")


func _scene_look_twin_springs_start() -> bool:
	return _stage_look(BoardGenerator.Stage.TWIN_SPRINGS, &"start")


func _scene_look_twin_springs_wide() -> bool:
	return _stage_look(BoardGenerator.Stage.TWIN_SPRINGS, &"wide")


func _scene_look_twin_springs_close() -> bool:
	return _stage_look(BoardGenerator.Stage.TWIN_SPRINGS, &"close")


func _scene_look_boulder_crag() -> bool:
	_field = VersusFields.BOULDER_PASS
	_new_battle()
	_show()
	_look_at(Vector3(_battle.board.size.x / 2.0, 0.0, _battle.board.size.y / 2.0))
	_aim(20.0, 140.0, 42.0)
	return true


func _scene_look_twin_springs_crag() -> bool:
	return _stage_look(BoardGenerator.Stage.TWIN_SPRINGS, &"crag")


func _scene_look_twin_springs_crag_low() -> bool:
	return _stage_look(BoardGenerator.Stage.TWIN_SPRINGS, &"crag_low")


## stage の盤で、cells の最初のマスへ寄って見る（泉・ポータルの動き）。
func _close_look(stage: BoardGenerator.Stage, cells: Callable) -> bool:
	_field = VersusFields.field_of_stage(stage)
	_new_battle()
	_show()
	var found: Array = cells.call(_battle.board)
	if found.is_empty():
		return false
	_scene.focus_camera(found[0])
	_aim(7.0, 20.0, 48.0)
	return true


func _scene_spring() -> bool:
	return _close_look(BoardGenerator.Stage.LABYRINTH, func(board: Board) -> Array: return board.spring_cells)


func _scene_portal() -> bool:
	return _close_look(BoardGenerator.Stage.TWIN_SPRINGS, func(board: Board) -> Array: return board.portal_exits.keys())


## 砲台のある対戦モードのマップ（並びの先頭。無ければ中央平原）。
func _battery_field() -> StringName:
	for field in VersusFields.ids():
		var board := VersusFields.scenario_of(field).make_board(_seed)
		if board != null and not board.battery_cells.is_empty():
			return field
	return VersusFields.PLAIN


func _scene_battery_cell() -> bool:
	_field = _battery_field()
	_new_battle()
	_show()
	var batteries := _battle.board.battery_cells
	if batteries.is_empty():
		return false
	_scene.click_cell(batteries[0])
	_scene.focus_camera(batteries[0])
	return _scene.info_title().begins_with("マス")


## 砲台に後衛が乗っている番の始めまで進め、その駒を選ぶ（伸びた射程が、移動範囲の外の攻撃範囲に出る）。
func _scene_battery() -> bool:
	_field = _battery_field()
	_new_battle()
	var gunner: Array[Unit] = []
	if not _advance(func() -> bool:
		gunner.clear()
		for unit in _battle.units:
			if unit.site_range > 0 and unit.side == _battle.phase and _battle.can_act(unit):
				gunner.append(unit)
		return not gunner.is_empty()
	):
		return false
	_show()
	_scene.click_cell(gunner[0].cell)
	_scene.focus_camera(gunner[0].cell)
	return true


func _scene_stronghold_cell() -> bool:
	_field = VersusFields.PLAIN
	_new_battle([OptionalRules.STRONGHOLD])
	_show()
	var cell := _battle.board.stronghold_cell
	if cell == Board.NO_CELL:
		return false
	_scene.click_cell(cell)
	_scene.focus_camera(cell)
	return _scene.info_title().begins_with("マス")


func _scene_stronghold_hover() -> bool:
	_field = VersusFields.PLAIN
	_new_battle([OptionalRules.STRONGHOLD])
	_show()
	var cell := _battle.board.stronghold_cell
	if cell == Board.NO_CELL:
		return false
	_scene.focus_camera(cell)
	_scene.hover(cell)
	return true


## どちらかが、あと 1 回の確保で勝つところまで進める（拠点に駒が乗り、旗がその陣営の色。上の帯の札が目立つ）。
func _scene_stronghold() -> bool:
	_field = VersusFields.LABYRINTH
	_new_battle([OptionalRules.STRONGHOLD])
	if not _advance(func() -> bool:
		return Stronghold.holds_left(_battle, Unit.Side.PLAYER1) == 1 or Stronghold.holds_left(_battle, Unit.Side.PLAYER2) == 1
	):
		return false
	_show()
	_scene.focus_camera(_battle.board.stronghold_cell)
	return true


func _scene_portal_cell() -> bool:
	_field = VersusFields.TWIN_SPRINGS
	_new_battle()
	_show()
	var portals: Array = _battle.board.portal_exits.keys()
	if portals.is_empty():
		return false
	_scene.click_cell(portals[0])
	_scene.focus_camera(portals[0])
	return _scene.info_title().begins_with("マス")


## いまの番の駒のうち、歩いてポータルに止まれて、そこから転移できる駒と、そのポータル（[駒, マス]）。無ければ空。
func _portal_walker() -> Array:
	for unit in _own_units():
		if not _battle.can_act(unit):
			continue
		var portals := Queries.reachable_portals(_battle, unit)
		for portal: Vector2i in portals:
			if portal != unit.cell and not Queries.move_cells(_battle, unit)[portal]:
				return [unit, portal]
	return []


func _scene_portal_range() -> bool:
	_field = VersusFields.TWIN_SPRINGS
	_new_battle()
	if not _advance(func() -> bool: return _battle.phase == Unit.Side.PLAYER1 and not _portal_walker().is_empty()):
		return false
	_show()
	var found := _portal_walker()
	var unit: Unit = found[0]
	var portal: Vector2i = found[1]
	_scene.click_cell(unit.cell)
	_look_at(BoardView.cell_center(portal) + (BoardView.cell_center(_battle.portal_exit(portal)) - BoardView.cell_center(portal)) * 0.4)
	_aim(44.0, 0.0, 72.0)
	_scene.hover(portal)
	return _scene.painted_color(_battle.portal_exit(portal)) == _scene.portal_paint_color(portal)


func _scene_portal_menu() -> bool:
	_field = VersusFields.TWIN_SPRINGS
	_new_battle()
	if not _advance(func() -> bool: return _battle.phase == Unit.Side.PLAYER1 and not _portal_walker().is_empty()):
		return false
	_show()
	var found := _portal_walker()
	var unit: Unit = found[0]
	var portal: Vector2i = found[1]
	await _idle()
	_scene.click_cell(unit.cell)
	_scene.click_cell(portal)
	await _idle()
	_look_at(BoardView.cell_center(portal) + (BoardView.cell_center(_battle.portal_exit(portal)) - BoardView.cell_center(portal)) * 0.4)
	_aim(44.0, 0.0, 72.0)
	return unit.cell == portal and _scene.menu_ids().has(&"warp")


func _scene_portal_warped() -> bool:
	_field = VersusFields.TWIN_SPRINGS
	_new_battle()
	if not _advance(func() -> bool: return _battle.phase == Unit.Side.PLAYER1 and not _portal_walker().is_empty()):
		return false
	_show()
	var found := _portal_walker()
	var unit: Unit = found[0]
	var portal: Vector2i = found[1]
	var exit := _battle.portal_exit(portal)
	await _idle()
	_scene.click_cell(unit.cell)
	_scene.click_cell(portal)
	await _idle()
	_scene.press_warp()
	await _idle()
	_look_at(BoardView.cell_center(exit))
	_aim(44.0, 0.0, 60.0)
	return unit.cell == exit and not Queries.move_cells(_battle, unit).is_empty()


func _stage_overview(stage: BoardGenerator.Stage) -> bool:
	_field = VersusFields.field_of_stage(stage)
	_new_battle()
	_show()
	_look_at(Vector3(_battle.board.size.x / 2.0, 0.0, _battle.board.size.y / 2.0 + 1.0))
	_aim(45.0, 0.0, 68.0)
	return true


## 景色の場面の名前を、[マップ, 見た目, 構図] に分ける（見た目を書かなければ、マップの見た目）。読めなければ空。
func _scape_parts(name: String) -> Array:
	var parts := name.trim_prefix(SCAPE).split(".")
	if parts.size() == 2:
		parts.insert(1, "")
	if parts.size() != 3:
		return []
	var look := StringName(parts[1])
	if VersusFields.has(StringName(parts[0])) and VersusFields.is_generated(StringName(parts[0])):
		look = look if look != &"" else VersusFields.look_of(StringName(parts[0]))
	elif not Maps.find(parts[0]).is_empty():
		look = look if look != &"" else StringName(Maps.find(parts[0])["look"])
	else:
		return []
	return [parts[0], look, parts[2]]


func _scape_known(name: String) -> bool:
	var parts := _scape_parts(name)
	return not parts.is_empty() and StageLook.THEMES.has(parts[1]) and SCAPE_VIEWS.has(parts[2])


## マップの景色を、決まった構図で撮る（どのマップも同じ構図。並べて見比べるため）。部隊は対戦モードのいつもの編成。
func _scape(name: String) -> bool:
	var parts := _scape_parts(name)
	var defined: Scenario
	if VersusFields.has(StringName(parts[0])) and VersusFields.is_generated(StringName(parts[0])):
		defined = VersusFields.scenario_of(StringName(parts[0]))
	else:
		var found: Dictionary = Maps.find(parts[0])
		defined = Scenario.on_map(found["map"], found["title"])
	var armies: Array[UnitKind.Army] = [UnitKind.Army.MILITARY, UnitKind.Army.FANTASY]
	var setup := MatchSetup.humans_on(defined, _seed, MatchSetup.default_deck(armies[0]), MatchSetup.default_deck(armies[1]))
	_battle = setup.create_battle()
	if parts[2] == "paint" and VersusFields.has(StringName(parts[0])) and VersusFields.is_generated(StringName(parts[0])):
		BoardGenerator.arm_batteries(_battle.board)  # 砲台を置かない盤でも、砲台のマスも並べる
	_stats = BattleStats.new(_battle)
	_log = BattleLog.new(_battle, ["プレイヤー1（青）", "プレイヤー2（赤）"] as Array[String])
	_scene.start_with(_battle, parts[1], _seed, defined.title)
	var size: Vector2i = _battle.board.size
	var middle := Vector3(size.x / 2.0, 0.0, size.y / 2.0)
	match parts[2]:
		"wide":  # いちばん引いて、低い角度で。盤の全体と、その向こうの景色と空
			_look_at(middle)
			_aim(OrbitCamera.max_distance_for(size), 0.0, OrbitCamera.MIN_PITCH)
		"side":  # 横から、いちばん引いて低い角度で。別の向きの景色と空
			_look_at(middle)
			_aim(OrbitCamera.max_distance_for(size), 115.0, OrbitCamera.MIN_PITCH)
		"close":  # 盤の真ん中に寄って。障害物・森・平地の見分け
			_look_at(middle)
			_aim(13.0, 25.0, 45.0)
		"out":  # 盤の左の外を、近くから。盤のすぐ外に置いたものの形と大きさ
			_look_at(Vector3(-7.0, 0.0, size.y / 2.0))
			_aim(15.0, -50.0, 38.0)
		"range":
			return _scape_range(parts[1], defined.title)
		"paint":
			return _scape_paint()
	return true


## 景色の場面の「paint」: 盤の真ん中の平地に、範囲の色を帯にして並べ（上から移動・攻撃の相手・回復・スキル・ポータルの対・道）、
## 右に敵の全員の脅威範囲の斜線を重ねる。砲台（選べる決まり）とポータルのあるマップなら、その上にも移動の色を塗る。
## どの景色でも同じ並びなので、景色ごとに並べて、どの色が地面に沈むかを見比べる。
func _scape_paint() -> bool:
	var board := _battle.board
	var size: Vector2i = board.size
	var origin := Vector2i(size.x / 2 - 3, size.y / 2 - 3)
	var bands: Array[StringName] = [&"move", &"target", &"heal", &"skill", &"portal", &"path"]
	var samples := {}
	for kind in bands:
		samples[kind] = [] as Array[Vector2i]
	samples[&"threat"] = [] as Array[Vector2i]
	for row in bands.size():
		for column in 6:
			var cell := origin + Vector2i(column, row)
			if not board.in_bounds(cell):
				continue
			samples[bands[row]].append(cell)
			if column >= 4:
				samples[&"threat"].append(cell)
	for cell: Vector2i in board.battery_cells + board.portal_exits.keys():
		samples[&"move"].append(cell)
	_scene.show_paint_samples(samples)
	_look_at(BoardView.cell_center(origin + Vector2i(3, 3)))
	_aim(14.0, 20.0, 50.0)
	return true


## 景色の場面の「range」: 両軍が近づいたターン 3 の先手の番で、駒を 1 つ選び（移動範囲）、敵の全員の脅威範囲も出す。
## 範囲の色と駒が、その景色の地面に沈まないかを見る。
func _scape_range(look: StringName, title: String) -> bool:
	if not _advance(func() -> bool: return _battle.turn >= 3 and _battle.phase == Unit.Side.PLAYER1):
		return false
	_scene.start_with(_battle, look, _seed, title)
	var unit := _own_units()[0]
	for own in _own_units():
		if own.kind != UnitKind.Id.KING and _battle.can_act(own):
			unit = own
			break
	_scene.click_cell(unit.cell)
	_scene.toggle_threat()
	_scene.focus_camera(unit.cell)
	return _scene.is_threat_shown()
