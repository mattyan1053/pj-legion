extends "res://tests/base_test.gd"
## 手で作ったマップ（HandMap、rules/maps/）と、戦いの定義の初期位置（docs/hand-map.md）。

const CpuMatch := preload("res://tools/cpu_match.gd")
const RidgePath := preload("res://rules/maps/ridge_path.gd")
const MAPS_DIR := "res://rules/maps/"


func _map(rows: Array[String]) -> HandMap:
	return HandMap.new(PackedStringArray(rows))


## rules/maps/ のマップ（ファイル名 -> スクリプト）。
func _all_maps() -> Dictionary:
	var maps := {}
	for file in DirAccess.get_files_at(MAPS_DIR):
		if file.ends_with(".gd"):
			maps[file] = load(MAPS_DIR + file)
	return maps


func test_chars_make_the_board() -> void:
	var map := _map([
		"..2.a",
		"#F*MS",
		"B...M",
		"a.1..",
	])
	assert_eq(map.problems(), [] as Array[HandMap.Problem])
	var board := map.make_board()
	assert_eq(board.size, Vector2i(5, 4))
	assert_eq(board.hq_cells, [Vector2i(2, 3), Vector2i(2, 0)] as Array[Vector2i])
	assert_eq(board.terrain_at(Vector2i(0, 1)), Terrain.Type.OBSTACLE)
	assert_eq(board.terrain_at(Vector2i(1, 1)), Terrain.Type.FOREST)
	assert_eq(board.terrain_at(Vector2i(2, 1)), Terrain.Type.FONT)
	assert_eq(board.font_cells, [Vector2i(2, 1)] as Array[Vector2i])
	assert_eq(board.mid_boss_cells, [Vector2i(3, 1), Vector2i(4, 2)] as Array[Vector2i], "中ボスは読む順に番号が付く")
	assert_eq(board.barrel_cells, [Vector2i(0, 2)] as Array[Vector2i])
	assert_eq(board.spring_cells, [Vector2i(4, 1)] as Array[Vector2i])
	assert_eq(board.portal_exit(Vector2i(4, 0)), Vector2i(0, 3))
	assert_eq(board.portal_exit(Vector2i(0, 3)), Vector2i(4, 0))
	for cell: Vector2i in [Vector2i(2, 3), Vector2i(3, 1), Vector2i(0, 2), Vector2i(4, 0)]:
		assert_eq(board.terrain_at(cell), Terrain.Type.NORMAL, "本陣・中ボス・置く物の地形は平地")


func test_each_problem_is_found() -> void:
	var cases := {
		HandMap.Problem.EMPTY: [] as Array[String],
		HandMap.Problem.RAGGED: ["1..", "2."] as Array[String],
		HandMap.Problem.UNKNOWN_CHAR: ["1?2"] as Array[String],
		HandMap.Problem.HQ_COUNT: ["1.1"] as Array[String],
		HandMap.Problem.MID_BOSS_COUNT: ["1M2"] as Array[String],
		HandMap.Problem.PORTAL_PAIR: ["1a2"] as Array[String],
		HandMap.Problem.HQ_NOT_CONNECTED: ["1#2"] as Array[String],
		HandMap.Problem.MID_BOSS_UNREACHABLE: ["1.2#M", "...#M"] as Array[String],
	}
	for problem: HandMap.Problem in cases:
		var map := _map(cases[problem])
		assert_eq(map.problems(), [problem] as Array[HandMap.Problem], HandMap.Problem.keys()[problem])
		assert_eq(map.make_board(), null)


func test_barrels_block_the_way_between_hqs() -> void:
	assert_eq(_map(["1B2"]).problems(), [HandMap.Problem.HQ_NOT_CONNECTED] as Array[HandMap.Problem])


func test_every_map_makes_a_board_that_fits_both_armies() -> void:
	var maps := _all_maps()
	assert_true(maps.has("ridge_path.gd"))
	assert_true(maps.has("crystal_gorge.gd"))
	for file: String in maps:
		var script: GDScript = maps[file]
		var map: HandMap = script.call(&"map")
		assert_eq(map.problems(), [] as Array[HandMap.Problem], file)
		assert_ne(script.get(&"TITLE"), "", file)
		var setup := MatchSetup.versus_human(
			BoardGenerator.Stage.PLAIN, 1, MatchSetup.default_deck(UnitKind.Army.MILITARY), MatchSetup.default_deck(UnitKind.Army.FANTASY)
		)
		setup.scenario = Scenario.on_map(map, script.get(&"TITLE"))
		var battle := setup.create_battle()
		for side: Unit.Side in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
			var count := battle.units.filter(func(unit: Unit) -> bool: return unit.side == side).size()
			assert_eq(count, 1 + setup.deck_of(side).entries.size(), "%s: いつもの置き方で全員が置ける" % file)


func test_hand_map_ignores_the_seed_and_the_board_size() -> void:
	var scenario := Scenario.on_map(RidgePath.map(), RidgePath.TITLE)
	scenario.board_size = Vector2i.ONE
	assert_true(scenario.can_make_board(), "大きさは生成だけのもの")
	var a := scenario.make_board(1)
	var b := scenario.make_board(99)
	assert_eq(a.size, Vector2i(17, 22))
	for y in a.size.y:
		for x in a.size.x:
			assert_eq(a.terrain_at(Vector2i(x, y)), b.terrain_at(Vector2i(x, y)))
	assert_true(a != b, "毎回、新しい盤")


func test_invalid_hand_map_is_refused_as_no_board() -> void:
	var setup := MatchSetup.versus_human(
		BoardGenerator.Stage.PLAIN, 1, MatchSetup.default_deck(UnitKind.Army.MILITARY), MatchSetup.default_deck(UnitKind.Army.FANTASY)
	)
	setup.scenario = Scenario.on_map(_map(["1#2"]), "")
	assert_eq(setup.problems(), [MatchSetup.Problem.NO_BOARD] as Array[MatchSetup.Problem])
	assert_eq(setup.create_battle(), null)


func test_deploy_cells_place_units_in_deck_order_then_fall_back() -> void:
	var scenario := Scenario.on_map(RidgePath.map(), RidgePath.TITLE)
	var cells: Array[Vector2i] = [
		Vector2i(0, 13),  # 壁: 飛ばす
		Vector2i(3, 18),
		Vector2i(8, 21),  # 本陣（将がいる）: 飛ばす
		Vector2i(8, 0),  # 相手の本陣（相手の将はまだ置かれていない）: 飛ばす
		Vector2i(13, 18),
	]
	scenario.set_deploy_cells(Unit.Side.PLAYER1, cells)
	var setup := MatchSetup.versus_human(
		BoardGenerator.Stage.PLAIN, 1, MatchSetup.default_deck(UnitKind.Army.MILITARY), MatchSetup.default_deck(UnitKind.Army.FANTASY)
	)
	setup.scenario = scenario
	var battle := setup.create_battle()
	var deck := setup.deck_of(Unit.Side.PLAYER1)
	assert_eq(battle.unit_at(Vector2i(8, 21)).kind, UnitKind.Id.KING, "将はいつも本陣")
	assert_eq(battle.unit_at(Vector2i(3, 18)).kind, deck.entries[0].kind)
	assert_eq(battle.unit_at(Vector2i(13, 18)).kind, deck.entries[1].kind)
	# 列が尽きたら、残りはいつもの置き方（本陣のすぐ前の行の中央から）。
	assert_eq(battle.unit_at(Vector2i(8, 20)).kind, deck.entries[2].kind)
	var mine := battle.units.filter(func(unit: Unit) -> bool: return unit.side == Unit.Side.PLAYER1)
	assert_eq(mine.size(), 1 + deck.entries.size())
	# 初期位置を決めていないプレイヤーは、いつもの置き方のまま。
	assert_eq(battle.unit_at(Vector2i(8, 0)).kind, UnitKind.Id.KING)
	assert_eq(battle.unit_at(Vector2i(8, 0)).side, Unit.Side.PLAYER2)
	assert_eq(battle.unit_at(Vector2i(8, 1)).side, Unit.Side.PLAYER2)


func _cpu_game(armies: Array, max_turns: int, map_script: GDScript = RidgePath) -> CpuMatch.Outcome:
	var setup := MatchSetup.new()
	setup.scenario = Scenario.on_map(map_script.call(&"map"), map_script.get(&"TITLE"))
	setup.battle_seed = 1
	for side: Unit.Side in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
		setup.set_cpu(side, armies[side])
	return CpuMatch.play(setup.create_battle(), max_turns)


## CPU が小さい盤でも手を指せる（断られる行動が無い）。1 局を最後まで読むのは長い検査（下）。
func test_cpu_plays_on_the_small_map() -> void:
	var outcome := _cpu_game([UnitKind.Army.MILITARY, UnitKind.Army.FANTASY], 6)
	assert_eq(outcome.rejected, 0)
	assert_true(outcome.turns > 6 or outcome.finished)


## rules/maps/ のどのマップでも、CPU どうしの対局が最後まで進む（先手と後手の軍を入れ替えて 2 局ずつ）。
func test_long_cpu_games_on_every_map_finish() -> void:
	var maps := _all_maps()
	for file: String in maps:
		for armies: Array in [[UnitKind.Army.MILITARY, UnitKind.Army.FANTASY], [UnitKind.Army.FANTASY, UnitKind.Army.MILITARY]]:
			var outcome := _cpu_game(armies, 60, maps[file])
			assert_true(outcome.finished, "%s: 60 ターンまでに決着する: %s" % [file, armies])
			assert_eq(outcome.rejected, 0, file)
