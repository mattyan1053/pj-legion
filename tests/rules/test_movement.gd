extends "res://tests/base_test.gd"
## 移動範囲（地形・ほかの駒・支配領域・巡航）と、道の選び方。

const Maps := preload("res://tests/support/maps.gd")

const P1 := Unit.Side.PLAYER1
const P2 := Unit.Side.PLAYER2


func _open(size: int) -> Battle:
	var rows: Array[String] = []
	for y in size:
		rows.append(".".repeat(size))
	return Maps.battle(rows)


func test_range_on_open_ground_is_a_diamond() -> void:
	var battle := _open(9)
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(4, 4))  # 移動力 3
	var cells := Movement.reachable(battle, sniper)
	assert_eq(cells.size(), 25)  # 1 + 4 + 8 + 12
	assert_eq(cells[Vector2i(4, 4)], 0)
	assert_eq(cells[Vector2i(7, 4)], 3)
	assert_eq(cells[Vector2i(5, 6)], 3)
	assert_false(cells.has(Vector2i(6, 6)))  # 4 歩かかる


func test_forest_costs_two() -> void:
	var battle := Maps.battle([".F..."])
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	var cells := Movement.reachable(battle, sniper)
	assert_eq(cells[Vector2i(1, 0)], 2)
	assert_eq(cells[Vector2i(2, 0)], 3)
	assert_false(cells.has(Vector2i(3, 0)))


func test_obstacles_cannot_be_entered() -> void:
	var battle := Maps.battle([
		".#.",
		"...",
	])
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(0, 0))
	var cells := Movement.reachable(battle, commando)
	assert_false(cells.has(Vector2i(1, 0)))
	assert_eq(cells[Vector2i(2, 0)], 4)  # 下を回る


func test_cannot_pass_through_enemies() -> void:
	var battle := Maps.battle(["....."])
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(1, 0))
	var cells := Movement.reachable(battle, sniper)
	assert_eq(cells.size(), 1)


func test_cannot_pass_through_allies_either() -> void:
	var battle := Maps.battle(["....."])
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(1, 0))
	var cells := Movement.reachable(battle, sniper)
	assert_eq(cells.size(), 1)


func test_enemy_zoc_stops_movement() -> void:
	# 敵の前衛を真ん中の行に置くと、列 2〜4 が上から下まで ZOC になる。横切ろうとすると列 2 で止まる。
	var battle := Maps.battle([
		".......",
		".......",
		".......",
	])
	battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(3, 1))
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(0, 0))  # 移動力 6
	var cells := Movement.reachable(battle, commando)
	assert_true(cells.has(Vector2i(2, 0)))  # ZOC のマスには入れる
	assert_true(cells.has(Vector2i(2, 2)))
	assert_false(cells.has(Vector2i(3, 0)))  # ZOC のマスから先へは行けない
	assert_false(cells.has(Vector2i(5, 0)))
	assert_false(cells.has(Vector2i(6, 2)))


func test_ally_zoc_does_not_stop_movement() -> void:
	var battle := Maps.battle([
		".......",
		".......",
		".......",
	])
	battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(3, 1))
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(0, 0))
	var cells := Movement.reachable(battle, commando)
	assert_true(cells.has(Vector2i(6, 0)))


func test_non_vanguard_enemies_have_no_zoc() -> void:
	var battle := Maps.battle([
		".......",
		".......",
		".......",
	])
	battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(3, 1))
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(0, 0))
	var cells := Movement.reachable(battle, commando)
	assert_true(cells.has(Vector2i(6, 0)))


func test_first_step_out_of_enemy_zoc_is_allowed() -> void:
	var battle := Maps.battle([
		".......",
		".......",
		".......",
	])
	battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(3, 1))
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(2, 0))  # すでに ZOC の中
	var cells := Movement.reachable(battle, commando)
	assert_true(cells.has(Vector2i(0, 2)))  # ZOC の外へは出られて、そのまま進める
	assert_true(cells.has(Vector2i(3, 0)))  # 隣の ZOC のマスへの 1 歩も踏める
	assert_false(cells.has(Vector2i(4, 0)))  # が、そこで止まる
	assert_false(cells.has(Vector2i(6, 0)))


func test_cruise_doubles_the_range() -> void:
	var battle := Maps.battle([".........."])
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	assert_false(Movement.reachable(battle, sniper).has(Vector2i(6, 0)))
	assert_eq(Movement.reachable(battle, sniper, true)[Vector2i(6, 0)], 6)
	assert_false(Movement.reachable(battle, sniper, true).has(Vector2i(7, 0)))


func test_path_takes_the_cheaper_way_through_forest() -> void:
	# 森を抜ける（2 + 1 = 3）方が、回り道（4）より安い。
	var battle := Maps.battle([
		"...",
		".F.",
		"...",
	])
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, Unit.Side.PLAYER1, Vector2i(1, 0))
	var path := Movement.path_to(battle, commando, Vector2i(1, 2))
	assert_eq(path, [Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2)] as Array[Vector2i])


func test_path_goes_around_forest_when_cheaper() -> void:
	# 森を 3 マス抜ける（2 + 2 + 2 + 1 = 7）より、脇を回る（6）方が安い。
	var battle := Maps.battle([
		"...",
		".F.",
		".F.",
		".F.",
		"...",
	])
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, Unit.Side.PLAYER1, Vector2i(1, 0))
	var path := Movement.path_to(battle, commando, Vector2i(1, 4))
	assert_eq(path.size(), 7)
	for cell in path:
		assert_ne(battle.board.terrain_at(cell), Terrain.Type.FOREST, "%s は森" % cell)


func test_path_is_connected_and_matches_cost() -> void:
	var battle := Maps.battle([
		"..F..",
		".#F#.",
		".....",
	])
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(0, 0))
	var cells := Movement.reachable(battle, commando)
	for target: Vector2i in cells:
		var path := Movement.path_to(battle, commando, target)
		assert_eq(path[0], commando.cell)
		assert_eq(path[-1], target)
		var spent := 0
		for i in range(1, path.size()):
			var step := (path[i] - path[i - 1]).abs()
			assert_eq(step.x + step.y, 1, "%s への道が飛んでいる" % target)
			spent += battle.board.move_cost(path[i])
		assert_eq(spent, cells[target], "%s への道の移動力" % target)


func test_path_is_the_same_every_time() -> void:
	var battle := _open(7)
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(0, 0))
	var first := Movement.path_to(battle, commando, Vector2i(3, 3))
	for i in 5:
		assert_eq(Movement.path_to(battle, commando, Vector2i(3, 3)), first)


func test_no_path_when_unreachable() -> void:
	var battle := Maps.battle([".#."])
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	assert_eq(Movement.path_to(battle, sniper, Vector2i(2, 0)), [] as Array[Vector2i])
