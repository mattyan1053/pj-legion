extends "res://tests/base_test.gd"
## 拠点（試しの決まり。docs/map-objects.md の「拠点」、docs/win-conditions.md の「拠点を確保し続ける」）:
## 置かれるのは入のときだけ、置く場所、確保の数え方、勝ち、CPU。

const Maps := preload("res://tests/support/maps.gd")
const VersusFields := preload("res://game/versus_fields.gd")

const P1 := Unit.Side.PLAYER1
const P2 := Unit.Side.PLAYER2
const CELL := Vector2i(2, 2)


func _setup(field: StringName, battle_seed: int, trials: Array[StringName] = []) -> MatchSetup:
	var setup := MatchSetup.versus_human(
		BoardGenerator.Stage.PLAIN, battle_seed, MatchSetup.default_deck(UnitKind.Army.MILITARY), MatchSetup.default_deck(UnitKind.Army.FANTASY)
	)
	setup.scenario = VersusFields.scenario_of(field)
	setup.trials = trials
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


func test_trial_places_one_stronghold_at_the_same_distance_from_both_hqs() -> void:
	for field in VersusFields.all_ids():
		for battle_seed: int in [1, 2, 3]:
			var battle := _setup(field, battle_seed, [TrialRules.STRONGHOLD]).create_battle()
			var board := battle.board
			var cell := board.stronghold_cell
			var label := "%s 種 %d" % [field, battle_seed]
			assert_true(cell != Board.NO_CELL, label)
			assert_eq(board.object_at(cell), MapObject.Type.STRONGHOLD, label)
			assert_true(board.is_walkable(cell), label)
			assert_eq(board.hq_owner(cell), -1, label)
			var near := Stronghold.distances(board, board.hq_cells[P1])
			var far := Stronghold.distances(board, board.hq_cells[P2])
			var i := cell.y * board.size.x + cell.x
			assert_true(near[i] > 0 and far[i] > 0, label)
			assert_true(absi(near[i] - far[i]) <= 1, "%s: 道のり %d と %d" % [label, near[i], far[i]])
			for home in board.mid_boss_cells:
				assert_true(Combat.distance(home, cell) > Stronghold.BOSS_CLEARANCE, label)
			for side: Unit.Side in [P1, P2]:
				assert_true(battle.wins_by(side, GameWonEvent.Reason.STRONGHOLD_HELD), label)
				assert_eq(Stronghold.holds_left(battle, side), Stronghold.HOLDS_TO_WIN, label)


func test_off_board_is_the_same_as_on_board_except_the_stronghold() -> void:
	for field in VersusFields.all_ids():
		var off := _setup(field, 5).create_battle().board
		var on := _setup(field, 5, [TrialRules.STRONGHOLD]).create_battle().board
		for y in off.size.y:
			for x in off.size.x:
				var cell := Vector2i(x, y)
				assert_eq(on.terrain_at(cell), off.terrain_at(cell))
				if cell != on.stronghold_cell:
					assert_eq(on.object_at(cell), off.object_at(cell))


func test_stronghold_is_not_placed_on_another_object_or_a_font() -> void:
	var board := Maps.board(["..S..", "..*..", "..B..", "....."])
	board.hq_cells = [Vector2i(0, 0), Vector2i(4, 0)]
	var cell := Stronghold.choose_cell(board)
	assert_true(cell != Vector2i(2, 0) and cell != Vector2i(2, 1) and cell != Vector2i(2, 2))
	assert_eq(cell, Vector2i(2, 3), "道のりの同じマス（真ん中の列）のうち、ほかの物の無いもの")


func test_distances_use_portals() -> void:
	var board := Maps.board(["1...#....", "....#...1"])
	var dist := Stronghold.distances(board, Vector2i(0, 0))
	assert_eq(dist[1 * board.size.x + 8], 0, "ポータルは移動力を使わずに移る")
	assert_eq(dist[0 * board.size.x + 5], 4)


func test_story_scenarios_never_place_a_stronghold() -> void:
	# 試しの決まりは対戦設定だけが入にする。戦いの定義の勝ちの条件にも、拠点は無い。
	for reason: GameWonEvent.Reason in Scenario.STANDARD_WIN_CONDITIONS:
		assert_true(reason != GameWonEvent.Reason.STRONGHOLD_HELD)
