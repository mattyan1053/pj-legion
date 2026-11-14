extends "res://tests/base_test.gd"
## 盤面のデータと、地形の問い合わせ。


func test_new_board_is_all_normal() -> void:
	var board := Board.new(Vector2i(30, 30))
	assert_eq(board.size, Vector2i(30, 30))
	assert_eq(board.count_terrain(Terrain.Type.NORMAL), 900)


func test_size_is_not_fixed() -> void:
	var board := Board.new(Vector2i(40, 25))
	assert_true(board.in_bounds(Vector2i(39, 24)))
	assert_false(board.in_bounds(Vector2i(40, 0)))
	assert_false(board.in_bounds(Vector2i(0, 25)))
	assert_false(board.in_bounds(Vector2i(-1, 0)))


func test_set_and_read_terrain() -> void:
	var board := Board.new(Vector2i(5, 5))
	board.set_terrain(Vector2i(3, 1), Terrain.Type.FOREST)
	assert_eq(board.terrain_at(Vector2i(3, 1)), Terrain.Type.FOREST)
	assert_eq(board.terrain_at(Vector2i(1, 3)), Terrain.Type.NORMAL)


func test_normal_costs_one() -> void:
	var board := Board.new(Vector2i(3, 3))
	assert_true(board.is_walkable(Vector2i(1, 1)))
	assert_eq(board.move_cost(Vector2i(1, 1)), 1)
	assert_false(board.blocks_range(Vector2i(1, 1)))


func test_obstacle_blocks_walking_but_not_range() -> void:
	var board := Board.new(Vector2i(3, 3))
	board.set_terrain(Vector2i(1, 1), Terrain.Type.OBSTACLE)
	assert_false(board.is_walkable(Vector2i(1, 1)))
	assert_eq(board.move_cost(Vector2i(1, 1)), -1)
	assert_false(board.blocks_range(Vector2i(1, 1)))


func test_forest_is_walkable_and_costs_two() -> void:
	var board := Board.new(Vector2i(3, 3))
	board.set_terrain(Vector2i(1, 1), Terrain.Type.FOREST)
	assert_true(board.is_walkable(Vector2i(1, 1)))
	assert_eq(board.move_cost(Vector2i(1, 1)), 2)
	assert_false(board.blocks_range(Vector2i(1, 1)))


func test_font_is_walkable_and_costs_one() -> void:
	var board := Board.new(Vector2i(3, 3))
	board.set_terrain(Vector2i(1, 1), Terrain.Type.FONT)
	assert_true(board.is_walkable(Vector2i(1, 1)))
	assert_eq(board.move_cost(Vector2i(1, 1)), 1)


func test_outside_is_not_walkable() -> void:
	var board := Board.new(Vector2i(3, 3))
	assert_false(board.is_walkable(Vector2i(3, 0)))
	assert_eq(board.move_cost(Vector2i(-1, 0)), -1)


func test_hq_owner() -> void:
	var board := Board.new(Vector2i(5, 5))
	board.hq_cells = [Vector2i(2, 4), Vector2i(2, 0)]
	assert_eq(board.hq_owner(Vector2i(2, 4)), 0)
	assert_eq(board.hq_owner(Vector2i(2, 0)), 1)
	assert_eq(board.hq_owner(Vector2i(2, 2)), -1)


func test_reachable_goes_around_walls_and_through_forest() -> void:
	# . # .
	# . # .
	# F F .   F = 森。壁の下を森づたいに回り込める。
	var board := Board.new(Vector2i(3, 3))
	board.set_terrain(Vector2i(1, 0), Terrain.Type.OBSTACLE)
	board.set_terrain(Vector2i(1, 1), Terrain.Type.OBSTACLE)
	board.set_terrain(Vector2i(0, 2), Terrain.Type.FOREST)
	board.set_terrain(Vector2i(1, 2), Terrain.Type.FOREST)
	assert_true(board.is_reachable(Vector2i(0, 0), Vector2i(2, 0)))


func test_unreachable_across_a_full_wall() -> void:
	var board := Board.new(Vector2i(3, 3))
	for y in 3:
		board.set_terrain(Vector2i(1, y), Terrain.Type.OBSTACLE)
	assert_false(board.is_reachable(Vector2i(0, 0), Vector2i(2, 2)))
