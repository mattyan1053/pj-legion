extends "res://tests/base_test.gd"
## ステージごとの盤面の自動生成。
##
## 生成はシードで決まるので、いくつかのシードで決まりごとが守られているかを見る。

const STAGES: Array[BoardGenerator.Stage] = [
	BoardGenerator.Stage.PLAIN,
	BoardGenerator.Stage.LABYRINTH,
	BoardGenerator.Stage.TWIN_SPRINGS,
]
const SEEDS: Array[int] = [1, 2, 3, 42, 1234, 20261114, 987654321]


func test_default_size_is_30() -> void:
	var board := BoardGenerator.generate(BoardGenerator.Stage.PLAIN, 1)
	assert_eq(board.size, Vector2i(30, 30))


func test_other_sizes_work() -> void:
	for stage in STAGES:
		var board := BoardGenerator.generate(stage, 7, Vector2i(40, 40))
		assert_eq(board.size, Vector2i(40, 40))
		assert_true(board.is_reachable(board.hq_cells[0], board.hq_cells[1]), "stage %d" % stage)


func test_too_small_sizes_are_refused() -> void:
	for stage in STAGES:
		assert_eq(BoardGenerator.generate(stage, 1, Vector2i(4, 4)), null, "stage %d" % stage)
		assert_eq(BoardGenerator.generate(stage, 1, Vector2i(30, 19)), null, "stage %d" % stage)
		var smallest := BoardGenerator.generate(stage, 1, BoardGenerator.MIN_SIZE)
		assert_true(smallest != null, "stage %d" % stage)
		if smallest != null:
			for cell in smallest.font_cells:
				assert_true(smallest.is_reachable(smallest.hq_cells[0], cell), "stage %d %s" % [stage, cell])


func test_same_seed_gives_same_board() -> void:
	for stage in STAGES:
		var a := BoardGenerator.generate(stage, 99)
		var b := BoardGenerator.generate(stage, 99)
		assert_eq(_terrain_dump(a), _terrain_dump(b), "stage %d" % stage)


func test_different_seeds_give_different_boards() -> void:
	for stage in STAGES:
		var a := BoardGenerator.generate(stage, 1)
		var b := BoardGenerator.generate(stage, 2)
		assert_ne(_terrain_dump(a), _terrain_dump(b), "stage %d" % stage)


func test_hqs_at_top_and_bottom_center() -> void:
	for stage: BoardGenerator.Stage in [BoardGenerator.Stage.PLAIN, BoardGenerator.Stage.LABYRINTH]:
		var board := BoardGenerator.generate(stage, 1)
		assert_eq(board.hq_cells[0], Vector2i(14, 29), "stage %d の P1" % stage)
		assert_eq(board.hq_cells[1], Vector2i(14, 0), "stage %d の P2" % stage)


func test_twin_springs_hqs_on_the_diagonal() -> void:
	var board := BoardGenerator.generate(BoardGenerator.Stage.TWIN_SPRINGS, 1)
	assert_eq(board.hq_cells[0], Vector2i(4, 29))  # 左下
	assert_eq(board.hq_cells[1], Vector2i(25, 0))  # 右上


func test_four_fonts_around_the_center() -> void:
	for stage: BoardGenerator.Stage in [BoardGenerator.Stage.PLAIN, BoardGenerator.Stage.LABYRINTH]:
		var board := BoardGenerator.generate(stage, 1)
		assert_eq(board.font_cells.size(), 4)
		for cell in board.font_cells:
			assert_true((cell - Vector2i(15, 15)).length() < 4.0, "stage %d の %s" % [stage, cell])


func test_twin_springs_fonts_on_the_flanks() -> void:
	var board := BoardGenerator.generate(BoardGenerator.Stage.TWIN_SPRINGS, 1)
	assert_eq(board.font_cells.size(), 4)
	var left := 0
	var right := 0
	for cell in board.font_cells:
		if cell.x <= 9:
			left += 1
		elif cell.x >= 21:
			right += 1
	assert_eq(left, 2)
	assert_eq(right, 2)


func test_fonts_stay_fonts() -> void:
	for stage in STAGES:
		for map_seed in SEEDS:
			var board := BoardGenerator.generate(stage, map_seed)
			for cell in board.font_cells:
				assert_eq(board.terrain_at(cell), Terrain.Type.FONT, "stage %d seed %d" % [stage, map_seed])
			assert_eq(board.count_terrain(Terrain.Type.FONT), 4)


func test_around_hqs_stays_normal() -> void:
	for stage in STAGES:
		for map_seed in SEEDS:
			var board := BoardGenerator.generate(stage, map_seed)
			for hq in board.hq_cells:
				for dy in range(-3, 4):
					for dx in range(-3, 4):
						var cell := hq + Vector2i(dx, dy)
						if board.in_bounds(cell):
							assert_eq(
								board.terrain_at(cell), Terrain.Type.NORMAL,
								"stage %d seed %d %s" % [stage, map_seed, cell]
							)


func test_hqs_always_connected() -> void:
	for stage in STAGES:
		for map_seed in range(1, 41):
			var board := BoardGenerator.generate(stage, map_seed)
			assert_true(
				board.is_reachable(board.hq_cells[0], board.hq_cells[1]),
				"stage %d seed %d" % [stage, map_seed]
			)


func test_fonts_always_reachable() -> void:
	for stage in STAGES:
		for map_seed in SEEDS:
			var board := BoardGenerator.generate(stage, map_seed)
			for cell in board.font_cells:
				assert_true(
					board.is_reachable(board.hq_cells[0], cell),
					"stage %d seed %d %s" % [stage, map_seed, cell]
				)


func test_plain_has_few_walls_and_an_open_center() -> void:
	for map_seed in SEEDS:
		var board := BoardGenerator.generate(BoardGenerator.Stage.PLAIN, map_seed)
		var ratio := board.count_terrain(Terrain.Type.OBSTACLE) / 900.0
		assert_between(ratio, 0.04, 0.12, "seed %d" % map_seed)
		for y in range(12, 18):
			for x in range(12, 18):
				assert_ne(board.terrain_at(Vector2i(x, y)), Terrain.Type.OBSTACLE, "seed %d (%d, %d)" % [map_seed, x, y])


func test_labyrinth_is_a_grid_maze() -> void:
	for map_seed in SEEDS:
		var board := BoardGenerator.generate(BoardGenerator.Stage.LABYRINTH, map_seed)
		var ratio := board.count_terrain(Terrain.Type.OBSTACLE) / 900.0
		assert_between(ratio, 0.25, 0.40, "seed %d" % map_seed)
		# 壁は偶数の列か行にしか立たない（奇数 x 奇数はいつも通路）。
		for y in range(1, 30, 2):
			for x in range(1, 30, 2):
				assert_ne(board.terrain_at(Vector2i(x, y)), Terrain.Type.OBSTACLE, "seed %d (%d, %d)" % [map_seed, x, y])


func test_twin_springs_center_is_walled() -> void:
	for map_seed in SEEDS:
		var board := BoardGenerator.generate(BoardGenerator.Stage.TWIN_SPRINGS, map_seed)
		for y in range(12, 19):
			for x in range(10, 21):
				assert_eq(board.terrain_at(Vector2i(x, y)), Terrain.Type.OBSTACLE, "seed %d (%d, %d)" % [map_seed, x, y])


func test_carve_corridor_opens_a_path() -> void:
	var board := Board.new(Vector2i(9, 9))
	board.hq_cells = [Vector2i(4, 8), Vector2i(4, 0)]
	for x in 9:
		board.set_terrain(Vector2i(x, 4), Terrain.Type.OBSTACLE)
	assert_false(board.is_reachable(board.hq_cells[0], board.hq_cells[1]))
	BoardGenerator.carve_corridor(board)
	assert_true(board.is_reachable(board.hq_cells[0], board.hq_cells[1]))
	# 開けるのは最短の道の 1 マスだけ。
	assert_eq(board.count_terrain(Terrain.Type.OBSTACLE), 8)


func _terrain_dump(board: Board) -> String:
	var rows: Array[String] = []
	for y in board.size.y:
		var row := ""
		for x in board.size.x:
			row += str(board.terrain_at(Vector2i(x, y)))
		rows.append(row)
	return "\n".join(rows)


# --- 環境オブジェクトの配置 ---

const OBJECT_SEEDS := 30


func test_plain_gets_four_to_six_barrels_in_the_side_bands() -> void:
	for map_seed in range(1, OBJECT_SEEDS + 1):
		var board := BoardGenerator.generate(BoardGenerator.Stage.PLAIN, map_seed)
		assert_between(board.barrel_cells.size(), 4, 6, "seed %d" % map_seed)
		assert_eq(board.spring_cells.size(), 0)
		assert_eq(board.portal_exits.size(), 0)
		for cell in board.barrel_cells:
			assert_true((cell.x >= 8 and cell.x <= 10) or (cell.x >= 20 and cell.x <= 22), "seed %d %s" % [map_seed, cell])
			assert_between(cell.y, 10, 20, "seed %d %s" % [map_seed, cell])


func test_labyrinth_gets_two_or_three_springs() -> void:
	var counts := {}
	for map_seed in range(1, OBJECT_SEEDS + 1):
		var board := BoardGenerator.generate(BoardGenerator.Stage.LABYRINTH, map_seed)
		assert_between(board.spring_cells.size(), 2, 3, "seed %d" % map_seed)
		assert_eq(board.barrel_cells.size(), 0)
		assert_eq(board.portal_exits.size(), 0)
		counts[board.spring_cells.size()] = true
	assert_eq(counts.size(), 2, "2 つの盤面も 3 つの盤面もある")


func test_twin_springs_gets_a_portal_pair_on_each_flank() -> void:
	for map_seed in range(1, OBJECT_SEEDS + 1):
		var board := BoardGenerator.generate(BoardGenerator.Stage.TWIN_SPRINGS, map_seed)
		assert_eq(board.portal_exits.size(), 4, "seed %d" % map_seed)
		assert_eq(board.barrel_cells.size(), 0)
		assert_eq(board.spring_cells.size(), 0)
		var flanks := {"left": 0, "right": 0}
		for cell: Vector2i in board.portal_exits:
			var exit := board.portal_exit(cell)
			assert_eq(board.portal_exit(exit), cell, "seed %d %s" % [map_seed, cell])
			assert_true(cell.x <= 9 or cell.x >= 21, "seed %d %s" % [map_seed, cell])
			assert_eq(cell.x <= 9, exit.x <= 9, "対は同じ側の道にある（seed %d %s）" % [map_seed, cell])
			assert_true(absi(cell.y - exit.y) >= 15, "対は上下の端寄りを結ぶ（seed %d %s）" % [map_seed, cell])
			flanks["left" if cell.x <= 9 else "right"] += 1
		assert_eq(flanks, {"left": 2, "right": 2}, "seed %d" % map_seed)


func test_objects_keep_off_protected_cells_and_rough_terrain() -> void:
	for stage in STAGES:
		for map_seed in range(1, OBJECT_SEEDS + 1):
			var board := BoardGenerator.generate(stage, map_seed)
			var protected := BoardGenerator.protected_cells(board)
			var cells: Array[Vector2i] = []
			cells.append_array(board.barrel_cells)
			cells.append_array(board.spring_cells)
			cells.append_array(board.portal_exits.keys())
			for cell in cells:
				var where := "stage %d seed %d %s" % [stage, map_seed, cell]
				assert_false(protected.has(cell), where)
				assert_eq(board.terrain_at(cell), Terrain.Type.NORMAL, where)
				assert_ne(board.object_at(cell), MapObject.Type.NONE, where)


func test_springs_and_portals_can_be_reached() -> void:
	for stage: BoardGenerator.Stage in [BoardGenerator.Stage.LABYRINTH, BoardGenerator.Stage.TWIN_SPRINGS]:
		for map_seed in range(1, OBJECT_SEEDS + 1):
			var board := BoardGenerator.generate(stage, map_seed)
			var cells: Array[Vector2i] = board.spring_cells.duplicate()
			cells.append_array(board.portal_exits.keys())
			for cell in cells:
				assert_true(board.is_reachable(board.hq_cells[0], cell), "stage %d seed %d %s" % [stage, map_seed, cell])


func test_barrels_do_not_cut_the_board() -> void:
	for map_seed in range(1, OBJECT_SEEDS + 1):
		var board := BoardGenerator.generate(BoardGenerator.Stage.PLAIN, map_seed)
		assert_true(board.is_reachable(board.hq_cells[0], board.hq_cells[1]), "seed %d" % map_seed)
		var with_barrels := BoardGenerator._reachable_count(board)
		var barrels := board.barrel_cells.size()
		board.barrel_cells.clear()
		assert_eq(BoardGenerator._reachable_count(board), with_barrels + barrels, "seed %d" % map_seed)


func test_same_seed_gives_same_objects() -> void:
	for stage in STAGES:
		var a := BoardGenerator.generate(stage, 99)
		var b := BoardGenerator.generate(stage, 99)
		assert_eq(a.barrel_cells, b.barrel_cells, "stage %d" % stage)
		assert_eq(a.spring_cells, b.spring_cells, "stage %d" % stage)
		assert_eq(a.portal_exits, b.portal_exits, "stage %d" % stage)


func test_other_sizes_get_objects_too() -> void:
	for size: Vector2i in [BoardGenerator.MIN_SIZE, Vector2i(40, 40)]:
		assert_between(BoardGenerator.generate(BoardGenerator.Stage.PLAIN, 7, size).barrel_cells.size(), 4, 6, str(size))
		assert_between(BoardGenerator.generate(BoardGenerator.Stage.LABYRINTH, 7, size).spring_cells.size(), 2, 3, str(size))
		assert_eq(BoardGenerator.generate(BoardGenerator.Stage.TWIN_SPRINGS, 7, size).portal_exits.size(), 4, str(size))
