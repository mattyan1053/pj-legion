extends "res://tests/base_test.gd"
## 手で作ったマップ（HandMap と、game/maps/ のマップのファイル）と、戦いの定義の初期位置（docs/hand-map.md）。
## マップのファイルを読むのは game/maps.gd（ルールはファイルを読まない）。ここでは、読んだ HandMap がルールの上で盤になることを見る。

const CpuMatch := preload("res://tools/cpu_match.gd")
const Maps := preload("res://game/maps.gd")


func _map(rows: Array[String]) -> HandMap:
	return HandMap.new(PackedStringArray(rows))


## game/maps/ のマップ（id -> Maps.find の返すもの: {"map", "title", "problems"}）。
func _all_maps() -> Dictionary:
	var maps := {}
	for id: String in Maps.ids():
		maps[id] = Maps.find(id)
	return maps


## 尾根の小道（初期位置と小さい盤の CPU を見る）。
func _ridge_path() -> Dictionary:
	return Maps.find("ridge_path")


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
		HandMap.Problem.STRONGHOLD_COUNT: ["1HH2"] as Array[String],
		HandMap.Problem.STRONGHOLD_UNUSABLE: ["1.2#H"] as Array[String],
	}
	for problem: HandMap.Problem in cases:
		var map := _map(cases[problem])
		assert_eq(map.problems(), [problem] as Array[HandMap.Problem], HandMap.Problem.keys()[problem])
		assert_eq(map.make_board(), null)


## 拠点の場所（H）: 地形は平地で、盤の stronghold_site になる（拠点が入の対戦でだけ拠点になる）。中ボスの縄張りの中には書けない。
func test_stronghold_site_is_read_and_checked() -> void:
	var map := _map(["..2..", "..H..", "..1.."])
	assert_eq(map.problems(), [] as Array[HandMap.Problem])
	var board := map.make_board()
	assert_eq(board.stronghold_site, Vector2i(2, 1))
	assert_eq(board.terrain_at(Vector2i(2, 1)), Terrain.Type.NORMAL)
	assert_eq(board.stronghold_cell, Board.NO_CELL, "置かれるのは、拠点が入の対戦だけ")
	assert_eq(_map(["..2..", "..1.."]).make_board().stronghold_site, Board.NO_CELL, "書かなければ、道のりから選ぶ")
	var near_boss := _map(["M.2.....", "..H.....", "..1....M"])
	assert_eq(near_boss.problems(), [HandMap.Problem.STRONGHOLD_UNUSABLE] as Array[HandMap.Problem], "中ボスの縄張りの中")


func test_barrels_block_the_way_between_hqs() -> void:
	assert_eq(_map(["1B2"]).problems(), [HandMap.Problem.HQ_NOT_CONNECTED] as Array[HandMap.Problem])


func test_every_map_makes_a_board_that_fits_both_armies() -> void:
	var maps := _all_maps()
	assert_true(maps.has("ridge_path"))
	assert_true(maps.has("crystal_gorge"))
	for file: String in maps:
		var map: HandMap = maps[file]["map"]
		assert_eq(maps[file]["problems"], PackedStringArray(), file)
		assert_eq(map.problems(), [] as Array[HandMap.Problem], file)
		assert_ne(maps[file]["title"], "", file)
		var setup := MatchSetup.versus_human(
			BoardGenerator.Stage.PLAIN, 1, MatchSetup.default_deck(UnitKind.Army.MILITARY), MatchSetup.default_deck(UnitKind.Army.FANTASY)
		)
		setup.scenario = Scenario.on_map(map, maps[file]["title"])
		var battle := setup.create_battle()
		for side: Unit.Side in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
			var count := battle.units.filter(func(unit: Unit) -> bool: return unit.side == side).size()
			assert_eq(count, 1 + setup.deck_of(side).entries.size(), "%s: いつもの置き方で全員が置ける" % file)


func test_hand_map_ignores_the_seed_and_the_board_size() -> void:
	var scenario := Scenario.on_map(_ridge_path()["map"], _ridge_path()["title"])
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
	var scenario := Scenario.on_map(_ridge_path()["map"], _ridge_path()["title"])
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


func _cpu_game(armies: Array, max_turns: int, found: Dictionary = {}) -> CpuMatch.Outcome:
	var map: Dictionary = _ridge_path() if found.is_empty() else found
	var setup := MatchSetup.new()
	setup.scenario = Scenario.on_map(map["map"], map["title"])
	setup.battle_seed = 1
	for side: Unit.Side in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
		setup.set_cpu(side, armies[side])
	return CpuMatch.play(setup.create_battle(), max_turns)


## CPU が小さい盤でも手を指せる（断られる行動が無い）。1 局を最後まで読むのは長い検査（下）。
func test_cpu_plays_on_the_small_map() -> void:
	var outcome := _cpu_game([UnitKind.Army.MILITARY, UnitKind.Army.FANTASY], 4)
	assert_eq(outcome.rejected, 0)
	assert_true(outcome.turns > 4 or outcome.finished)


## game/maps/ のどのマップでも、CPU どうしの対局が最後まで進む（先手と後手の軍を入れ替えて 2 局ずつ）。
## 軍の並びごとに 2 つのテストに分けてある。長い検査（tools/check.sh --full）が、別々のプロセスで並べて回す。
func test_long_cpu_games_on_every_map_finish_military_first() -> void:
	_assert_cpu_games_finish_on_every_map([UnitKind.Army.MILITARY, UnitKind.Army.FANTASY])


func test_long_cpu_games_on_every_map_finish_fantasy_first() -> void:
	_assert_cpu_games_finish_on_every_map([UnitKind.Army.FANTASY, UnitKind.Army.MILITARY])


func _assert_cpu_games_finish_on_every_map(armies: Array) -> void:
	var maps := _all_maps()
	assert_true(maps.size() > 0)
	for file: String in maps:
		var outcome := _cpu_game(armies, 60, maps[file])
		assert_true(outcome.finished, "%s: 60 ターンまでに決着する: %s" % [file, armies])
		assert_eq(outcome.rejected, 0, file)


## マップのファイルの書式（game/maps.gd）: [rows] の中の # は障害物の文字。書き間違いは行で言う。
func test_map_files_read_rows_with_hash_and_report_lines() -> void:
	var found := Maps.parse("# 説明\n[map]\ntitle = 見本\n\n[rows]\n#.2.#\n#...#\n#.1.#\n")
	assert_eq(found["problems"], PackedStringArray())
	assert_eq(found["title"], "見本")
	assert_eq((found["map"] as HandMap).rows, PackedStringArray(["#.2.#", "#...#", "#.1.#"]), "# で始まる行も格子の行")
	var ragged := Maps.parse("[map]\ntitle = 見本\n[rows]\n..2..\n...\n..1..\n")
	assert_true(Array(ragged["problems"]).any(func(problem: String) -> bool: return problem.begins_with("probe.txt:5:")), "長さの違う行: %s" % [ragged["problems"]])
	var untitled := Maps.parse("[map]\n[rows]\n2\n1\n")
	assert_false((untitled["problems"] as PackedStringArray).is_empty(), "title が無い")
	var two_sites := Maps.parse("[map]\ntitle = 見本\n[rows]\n.2.\nH.H\n.1.\n")
	assert_eq(Array(two_sites["problems"]), ["probe.txt:5: 拠点の場所（H）が 2 つ以上ある（1 つだけ書ける）"])
	var walled := Maps.parse("[map]\ntitle = 見本\n[rows]\n.2.#.\n...#H\n.1.#.\n")
	assert_eq(Array(walled["problems"]).size(), 1)
	assert_true((walled["problems"][0] as String).begins_with("probe.txt:5: 拠点の場所（H。5 列目）に拠点を置けない"), "%s" % [walled["problems"]])
	var no_hq := Maps.parse("[map]\ntitle = 見本\n[rows]\n...\n.1.\n")
	assert_false((no_hq["problems"] as PackedStringArray).is_empty(), "本陣が 1 つ")


## 景色（見た目）は、マップのファイルが決める（[map] の look。docs/hand-map.md）。
func test_each_map_names_its_look() -> void:
	var looks: Dictionary = load("res://game/stage_look.gd").THEMES
	for id: String in Maps.ids():
		assert_true(looks.has(Maps.find(id)["look"]), "%s: 知らない見た目 %s" % [id, Maps.find(id)["look"]])
	var found := Maps.parse("[map]\ntitle = 見本\nlook = crystal_forest\n[rows]\n.2.\n.1.\n")
	assert_eq(found["look"], &"crystal_forest")
	assert_eq(Array(found["problems"]), [])
	var plain := Maps.parse("[map]\ntitle = 見本\n[rows]\n.2.\n.1.\n")
	assert_eq(plain["look"], &"grassland", "書かなければ草原")
	var unknown := Maps.parse("[map]\ntitle = 見本\nlook = swamp\n[rows]\n.2.\n.1.\n")
	assert_true(unknown["problems"][0].begins_with("probe.txt:3:"), "知らない見た目は、その行で弾く: %s" % [unknown["problems"]])
