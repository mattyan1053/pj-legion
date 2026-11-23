extends "res://tests/base_test.gd"
## 拠点（docs/map-objects.md の「拠点」、docs/win-conditions.md の「拠点を確保し続ける」）:
## 置かれるのは入のときだけ、置く場所、確保の数え方、勝ち、CPU。

const Maps := preload("res://tests/support/maps.gd")
const VersusFields := preload("res://game/versus_fields.gd")

const P1 := Unit.Side.PLAYER1
const P2 := Unit.Side.PLAYER2
const CELL := Vector2i(2, 2)


func _setup(field: StringName, battle_seed: int, rules: Array[StringName] = []) -> MatchSetup:
	var setup := MatchSetup.versus_human(
		BoardGenerator.Stage.PLAIN, battle_seed, MatchSetup.default_deck(UnitKind.Army.MILITARY), MatchSetup.default_deck(UnitKind.Army.FANTASY)
	)
	setup.scenario = VersusFields.scenario_of(field)
	setup.rules = rules
	return setup


## 5 x 5 の盤の真ん中 (2,2) に拠点。本陣は上下の真ん中。両方とも拠点の確保で勝てる。
func _battle() -> Battle:
	var battle := Maps.battle([".....", ".....", ".....", ".....", "....."])
	battle.board.hq_cells = [Vector2i(2, 4), Vector2i(2, 0)]
	battle.board.stronghold_cell = CELL
	for side: Unit.Side in [P1, P2]:
		battle.win_conditions[side].append(GameWonEvent.Reason.STRONGHOLD_HELD)
	return battle


## いまのプレイヤーのフェーズを終える（プレイヤー2 のあとは、中立を通って次のターンのプレイヤー1 へ）。
func _end(battle: Battle) -> Array[BattleEvent]:
	return battle.apply(EndPhaseAction.new()).events


func _progress(events: Array[BattleEvent]) -> Array[Array]:
	var found: Array[Array] = []
	for event in events:
		var progress := event as StrongholdProgressEvent
		if progress != null:
			found.append([progress.player, progress.holds])
	return found


# --- 置く ---


func test_trial_is_off_by_default_and_nothing_is_placed() -> void:
	for field in VersusFields.all_ids():
		var battle := _setup(field, 1).create_battle()
		assert_eq(battle.board.stronghold_cell, Board.NO_CELL, String(field))
		assert_false(battle.wins_by(P1, GameWonEvent.Reason.STRONGHOLD_HELD))
		assert_eq(Stronghold.holds_left(battle, P1), -1)


## 置く場所は、手で作ったマップなら `H` のマス、生成のマップなら盤の種類ごとの寄せ（BoardGenerator.STRONGHOLD_LEAN）で道のりから選んだマス。
func test_trial_places_one_stronghold_where_the_board_says() -> void:
	for field in VersusFields.all_ids():
		for battle_seed: int in [1, 2, 3]:
			var battle := _setup(field, battle_seed, [OptionalRules.STRONGHOLD]).create_battle()
			var board := battle.board
			var cell := board.stronghold_cell
			var label := "%s 種 %d" % [field, battle_seed]
			assert_true(cell != Board.NO_CELL, label)
			assert_eq(board.object_at(cell), MapObject.Type.STRONGHOLD, label)
			assert_true(board.is_walkable(cell), label)
			assert_eq(board.hq_owner(cell), -1, label)
			if VersusFields.is_generated(field):
				assert_eq(board.stronghold_site, Board.NO_CELL, label)
				assert_eq(board.stronghold_lean, BoardGenerator.STRONGHOLD_LEAN[VersusFields.scenario_of(field).stage], label)
				var fresh := VersusFields.scenario_of(field).make_board(battle_seed)  # 拠点を置く前の、同じ盤
				assert_true(Stronghold.candidates(fresh).has(cell), label)
			else:
				assert_eq(cell, board.stronghold_site, "%s: 手で作ったマップは H のマス" % label)
			var near := Stronghold.distances(board, board.hq_cells[P1])
			var far := Stronghold.distances(board, board.hq_cells[P2])
			var i := cell.y * board.size.x + cell.x
			assert_true(near[i] > 0 and far[i] > 0, label)
			for home in board.mid_boss_cells:
				assert_true(Combat.distance(home, cell) > Stronghold.BOSS_CLEARANCE, label)
			for side: Unit.Side in [P1, P2]:
				assert_true(battle.wins_by(side, GameWonEvent.Reason.STRONGHOLD_HELD), label)
				assert_eq(Stronghold.holds_left(battle, side), Stronghold.HOLDS_TO_WIN, label)


func test_off_board_is_the_same_as_on_board_except_the_stronghold() -> void:
	for field in VersusFields.all_ids():
		var off := _setup(field, 5).create_battle().board
		var on := _setup(field, 5, [OptionalRules.STRONGHOLD]).create_battle().board
		for y in off.size.y:
			for x in off.size.x:
				var cell := Vector2i(x, y)
				if cell != on.stronghold_cell:
					assert_eq(on.terrain_at(cell), off.terrain_at(cell))
				if cell != on.stronghold_cell:
					assert_eq(on.object_at(cell), off.object_at(cell))
		assert_eq(on.terrain_at(on.stronghold_cell), Terrain.Type.NORMAL, "拠点のマスは平地")


func test_stronghold_is_not_placed_on_another_object_or_a_font() -> void:
	var board := Maps.board(["..S..", "..*..", "..B..", "....."])
	board.hq_cells = [Vector2i(0, 0), Vector2i(4, 0)]
	var cell := Stronghold.choose_cell(board)
	assert_true(cell != Vector2i(2, 0) and cell != Vector2i(2, 1) and cell != Vector2i(2, 2))
	assert_eq(cell, Vector2i(2, 3), "道のりの同じマス（真ん中の列）のうち、ほかの物の無いもの")


## 道のりのそろうマスが無い盤（本陣どうしの道のりが奇数）では、先手に 1 歩近いマスと後手に 1 歩近いマスが候補になり、
## どちらに置くかは種で替わる（決め打ちにすると、盤ごとに先手・後手のどちらかが勝ちやすくなる）。同じ種なら同じマス。
func test_ties_are_chosen_by_the_seed() -> void:
	var odd := Maps.board([".....", ".....", ".....", "....."])
	odd.hq_cells = [Vector2i(2, 3), Vector2i(2, 0)]
	var near := Stronghold.distances(odd, odd.hq_cells[P1])
	var far := Stronghold.distances(odd, odd.hq_cells[P2])
	var leans := {}
	for battle_seed in 20:
		var cell := Stronghold.choose_cell(odd, battle_seed)
		assert_eq(Stronghold.choose_cell(odd, battle_seed), cell, "同じ種で違うマス")
		var i := cell.y * odd.size.x + cell.x
		assert_eq(absi(near[i] - far[i]), 1)
		leans[signi(far[i] - near[i])] = true
	assert_eq(leans.size(), 2, "種を替えても、先手の側か後手の側の片方にしか置かない")


## 盤の寄せ（Board.stronghold_lean）: 先手の本陣からの道のり - 後手の本陣からの道のり が、その値にいちばん近いマスに置く。
func test_lean_moves_the_stronghold_toward_one_hq() -> void:
	var board := Maps.board([".....", ".....", ".....", ".....", "....."])
	board.hq_cells = [Vector2i(2, 4), Vector2i(2, 0)]
	assert_eq(Stronghold.candidates(board), [Vector2i(2, 2)] as Array[Vector2i], "寄せ 0 なら両方から同じ道のりの、真ん中")
	board.stronghold_lean = 2
	assert_eq(Stronghold.candidates(board), [Vector2i(2, 1)] as Array[Vector2i], "正の寄せは、後手の本陣に近い側")
	board.stronghold_lean = -2
	assert_eq(Stronghold.candidates(board), [Vector2i(2, 3)] as Array[Vector2i], "負の寄せは、先手の本陣に近い側")


## 盤の出どころが場所を決めていれば（Board.stronghold_site）、道のりによらずそこ。置けない場所なら置かない。
func test_site_overrides_the_distances() -> void:
	var board := Maps.board([".....", ".....", "..S..", ".....", "....."])
	board.hq_cells = [Vector2i(2, 4), Vector2i(2, 0)]
	board.stronghold_site = Vector2i(0, 1)
	for battle_seed in 5:
		assert_eq(Stronghold.choose_cell(board, battle_seed), Vector2i(0, 1))
	board.stronghold_site = Vector2i(2, 2)
	assert_eq(Stronghold.choose_cell(board), Board.NO_CELL, "泉の上には置かない")


## 砲台の場所には置かない（砲台が入の対戦でも切の対戦でも、拠点が同じマスになるように）。
func test_stronghold_avoids_battery_spots() -> void:
	var board := Maps.board([".....", ".....", ".....", ".....", "....."])
	board.hq_cells = [Vector2i(2, 4), Vector2i(2, 0)]
	board.battery_spots = [Vector2i(2, 2)]
	var cell := Stronghold.choose_cell(board)
	assert_true(cell != Vector2i(2, 2) and cell != Board.NO_CELL)
	# 生成のマップは、砲台を置く盤でも置かない盤でも、拠点は砲台の場所を避けて同じマスに置く。
	for stage: BoardGenerator.Stage in [BoardGenerator.Stage.PLAIN, BoardGenerator.Stage.LABYRINTH, BoardGenerator.Stage.TWIN_SPRINGS]:
		var off := BoardGenerator.generate(stage, 3)
		off.battery_cells.clear()
		Stronghold.arm(off, 3)
		var on := BoardGenerator.generate(stage, 3)
		BoardGenerator.arm_batteries(on)
		Stronghold.arm(on, 3)
		assert_eq(on.stronghold_cell, off.stronghold_cell, "%d: 砲台の有無で拠点が動いた" % stage)


func test_distances_use_portals() -> void:
	var board := Maps.board(["1...#....", "....#...1"])
	var dist := Stronghold.distances(board, Vector2i(0, 0))
	assert_eq(dist[1 * board.size.x + 8], 0, "ポータルは移動力を使わずに移る")
	assert_eq(dist[0 * board.size.x + 5], 4)


func test_story_scenarios_never_place_a_stronghold() -> void:
	# 選べる決まりは対戦設定だけが入にする。戦いの定義の勝ちの条件にも、拠点は無い。
	for reason: GameWonEvent.Reason in Scenario.STANDARD_WIN_CONDITIONS:
		assert_true(reason != GameWonEvent.Reason.STRONGHOLD_HELD)


# --- 確保を数える ---


func test_standing_on_the_stronghold_at_phase_end_adds_a_hold() -> void:
	var battle := _battle()
	battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, CELL)
	var events := _end(battle)
	assert_eq(_progress(events), [[P1, 1]] as Array[Array])
	assert_eq(battle.stronghold_holds, [1, 0] as Array[int])
	assert_eq(Stronghold.holds_left(battle, P1), Stronghold.HOLDS_TO_WIN - 1)


func test_holds_count_only_at_the_end_of_the_own_phase() -> void:
	var battle := _battle()
	battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, CELL)
	_end(battle)
	var events := _end(battle)  # プレイヤー2 のフェーズの終わり: プレイヤー1 の確保は進まない
	assert_eq(_progress(events), [] as Array[Array])
	assert_eq(battle.stronghold_holds, [1, 0] as Array[int])


func test_the_king_does_not_hold_the_stronghold() -> void:
	var battle := _battle()
	battle.add_unit(UnitKind.Id.KING, P1, CELL)
	assert_eq(_progress(_end(battle)), [] as Array[Array])
	assert_eq(battle.stronghold_holds, [0, 0] as Array[int])


func test_leaving_the_stronghold_keeps_the_holds() -> void:
	var battle := _battle()
	var holder := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, CELL)
	_end(battle)
	_end(battle)
	battle.apply(MoveAction.new(holder.id, Vector2i(0, 2)))
	assert_eq(_progress(_end(battle)), [] as Array[Array])
	assert_eq(battle.stronghold_holds, [1, 0] as Array[int])


func test_a_foe_hold_resets_the_holds() -> void:
	var battle := _battle()
	var holder := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, CELL)
	var foe := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(4, 0))
	_end(battle)
	battle.units.erase(holder)  # 倒されたことにする
	foe.cell = CELL
	var events := _end(battle)
	assert_eq(_progress(events), [[P2, 1], [P1, 0]] as Array[Array])
	assert_eq(battle.stronghold_holds, [0, 1] as Array[int])


func test_a_foe_near_the_stronghold_stops_the_hold() -> void:
	var battle := _battle()
	battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, CELL)
	var foe := battle.add_unit(UnitKind.Id.PALADIN, P2, CELL + Vector2i(Stronghold.CONTEST_RADIUS, 0))
	assert_true(Stronghold.contested(battle, P1))
	assert_eq(_progress(_end(battle)), [] as Array[Array])
	assert_eq(battle.stronghold_holds, [0, 0] as Array[int])
	foe.cell = CELL + Vector2i(Stronghold.CONTEST_RADIUS, 1)  # マンハッタン距離で 1 つ外
	_end(battle)
	assert_eq(_progress(_end(battle)), [[P1, 1]] as Array[Array])


func test_neutral_units_do_not_stop_the_hold() -> void:
	var battle := _battle()
	battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, CELL)
	battle.add_unit(UnitKind.Id.MINION, Unit.Side.NEUTRAL, CELL + Vector2i(1, 0))
	assert_eq(_progress(_end(battle)), [[P1, 1]] as Array[Array])


func test_reaching_the_holds_to_win_wins() -> void:
	var battle := _battle()
	battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, CELL)
	battle.add_unit(UnitKind.Id.KING, P1, Vector2i(0, 4))
	battle.add_unit(UnitKind.Id.KING, P2, Vector2i(4, 0))
	battle.stronghold_holds[P1] = Stronghold.HOLDS_TO_WIN - 1
	var events := _end(battle)
	var won := events[-1] as GameWonEvent
	assert_true(won != null)
	assert_eq(won.winner, P1)
	assert_eq(won.reason, GameWonEvent.Reason.STRONGHOLD_HELD)
	assert_true(battle.is_over())
	assert_eq(battle.phase, P1, "決着したら次のフェーズへ進まない")


func test_without_the_condition_nothing_is_counted() -> void:
	var battle := _battle()
	battle.win_conditions[P1].erase(GameWonEvent.Reason.STRONGHOLD_HELD)
	battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, CELL)
	assert_eq(_progress(_end(battle)), [] as Array[Array])
	assert_eq(Stronghold.holds_left(battle, P1), -1)


func test_clone_copies_the_holds() -> void:
	var battle := _battle()
	battle.stronghold_holds[P2] = 2
	var copy := battle.clone()
	assert_eq(copy.stronghold_holds, [0, 2] as Array[int])
	assert_eq(copy.board.stronghold_cell, CELL)
	copy.stronghold_holds[P2] = 3
	assert_eq(battle.stronghold_holds[P2], 2)


# --- CPU ---


func test_cpu_walks_a_fighter_onto_the_stronghold() -> void:
	var battle := _battle()
	battle.add_unit(UnitKind.Id.KING, P1, Vector2i(2, 4))
	var trooper := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(0, 4))
	battle.add_unit(UnitKind.Id.KING, P2, Vector2i(2, 0))
	var cpu := CpuPlayer.new()
	for step in 8:
		var action := cpu.next_action(battle)
		if action == null or action is EndPhaseAction:
			break
		battle.apply(action)
	assert_eq(trooper.cell, CELL)


func test_cpu_attacks_a_foe_holding_the_stronghold() -> void:
	var battle := Maps.battle(["...........", "...........", "...........", "...........", "...........", "..........."])
	battle.board.hq_cells = [Vector2i(5, 5), Vector2i(5, 0)]
	battle.board.stronghold_cell = Vector2i(5, 2)
	for side: Unit.Side in [P1, P2]:
		battle.win_conditions[side].append(GameWonEvent.Reason.STRONGHOLD_HELD)
	battle.add_unit(UnitKind.Id.KING, P1, Vector2i(5, 5))
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(9, 5))
	battle.add_unit(UnitKind.Id.KING, P2, Vector2i(5, 0))
	var holder := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(5, 2))
	battle.stronghold_holds[P2] = Stronghold.HOLDS_TO_WIN - 1
	var cpu := CpuPlayer.new()
	for step in 8:
		var action := cpu.next_action(battle)
		if action == null or action is EndPhaseAction:
			break
		battle.apply(action)
	assert_true(holder.hp < holder.max_hp() or Combat.distance(commando.cell, holder.cell) <= 1, "拠点の上の駒を叩くか、隣に立って確保を止める")
