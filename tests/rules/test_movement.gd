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


func test_can_pass_through_allies_but_not_stop_on_them() -> void:
	var battle := Maps.battle(["....."])
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(1, 0))
	var cells := Movement.reachable(battle, sniper)
	assert_false(cells.has(Vector2i(1, 0)))
	assert_eq(cells[Vector2i(2, 0)], 2)
	assert_eq(cells[Vector2i(3, 0)], 3)
	assert_eq(
		Movement.path_to(battle, sniper, Vector2i(3, 0)),
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)] as Array[Vector2i]
	)
	assert_eq(Movement.path_to(battle, sniper, Vector2i(1, 0)), [] as Array[Vector2i])


func test_neutrals_are_enemies_of_both_players() -> void:
	var battle := Maps.battle(["....."])
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	battle.add_unit(UnitKind.Id.MINION, Unit.Side.NEUTRAL, Vector2i(1, 0))
	assert_eq(Movement.reachable(battle, sniper).size(), 1)


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


func test_tied_paths_are_chosen_the_same_way_as_before() -> void:
	# 同じ移動力の道がいくつもある行き先。どれを選ぶかは決まっていて、探索の作り（速くする工夫）を変えても変わらない。
	# 先に見つけた道が残る。隣は 右・左・下・上 の順に見るので、開けた場所では「先に横、あとで縦」に寄った道になる。
	var battle := _open(7)
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(3, 3))  # 移動力 6
	assert_eq(_path_text(battle, commando, Vector2i(5, 5)), "3,3 4,3 5,3 5,4 5,5")
	assert_eq(_path_text(battle, commando, Vector2i(1, 1)), "3,3 2,3 1,3 1,2 1,1")
	assert_eq(_path_text(battle, commando, Vector2i(6, 0)), "3,3 4,3 5,3 6,3 6,2 6,1 6,0")
	# 森（移動力 2）と味方、ポータルが混ざっても同じ。
	var mixed := Maps.battle([
		"...F...",
		".F.1.F.",
		"...#...",
		".F...1.",
		".......",
	])
	var walker := mixed.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(0, 0))
	mixed.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(2, 0))
	assert_eq(_path_text(mixed, walker, Vector2i(4, 2)), "0,0 1,0 2,0 2,1 3,1 4,1 4,2")
	assert_eq(_path_text(mixed, walker, Vector2i(6, 4)), "0,0 1,0 2,0 2,1 3,1 5,3 6,3 6,4")
	assert_eq(_path_text(mixed, walker, Vector2i(2, 4)), "0,0 1,0 2,0 2,1 2,2 2,3 2,4")


func _path_text(battle: Battle, unit: Unit, to: Vector2i) -> String:
	var cells: Array[String] = []
	for cell in Movement.path_to(battle, unit, to):
		cells.append("%d,%d" % [cell.x, cell.y])
	return " ".join(cells)


func test_search_matches_the_plain_reference_search() -> void:
	# 速くした探索が、素朴な探索（候補を毎回ぜんぶ見て、いちばん小さいものを取る）と、
	# 届くマス・移動力・道の 1 つ前のマスのすべてで一致すること。生成した盤面に、駒をでたらめに置いて確かめる。
	for stage: BoardGenerator.Stage in BoardGenerator.Stage.values():
		var battle := Battle.new(BoardGenerator.generate(stage, 7))
		var rng := RandomNumberGenerator.new()
		rng.seed = stage
		var kinds: Array[UnitKind.Id] = [
			UnitKind.Id.COMMANDO, UnitKind.Id.PALADIN, UnitKind.Id.SNIPER, UnitKind.Id.SHIELD_TROOPER,
			UnitKind.Id.SPELLBLADE,
		]
		for i in 10:
			var cell := Vector2i(rng.randi_range(4, 25), rng.randi_range(4, 25))
			battle.add_unit(kinds[i % kinds.size()], (i % 2) as Unit.Side, cell)  # 置けないマスなら置かれないだけ
		for cell: Vector2i in battle.board.portal_exits.keys().slice(0, 2):
			battle.add_unit(UnitKind.Id.COMMANDO, P1, cell)  # ポータルの上から始まる駒と、ふさがった行き先
		assert_true(battle.units.size() >= 6, "ステージ %d に駒を置けていない" % stage)
		for unit in battle.units:
			for cruise: bool in [false, true]:
				var found := Movement.search(battle, unit, cruise)
				var expected := _reference_search(battle, unit, Movement.budget(unit, cruise))
				var message := "ステージ %d の %s（巡航 %s）" % [stage, unit.cell, cruise]
				assert_eq(found.cost.size(), expected["cost"].size(), message)
				assert_eq(found.parent.size(), expected["parent"].size(), message)
				for cell: Vector2i in expected["cost"]:
					assert_eq(found.cost.get(cell, -1), expected["cost"][cell], "%s の %s の移動力" % [message, cell])
				for cell: Vector2i in expected["parent"]:
					assert_eq(
						found.parent.get(cell, Board.NO_CELL), expected["parent"][cell],
						"%s の %s の 1 つ前" % [message, cell]
					)


## 比べる相手の、素朴な探索。Battle の問い合わせ（unit_at、is_in_enemy_zoc、portal_exit）だけで書いてある。
static func _reference_search(battle: Battle, unit: Unit, limit: int) -> Dictionary:
	var cost := {unit.cell: 0}
	var parent := {}
	var done := {}
	# [移動力, 見つけた順, マス] を移動力・見つけた順の小さい順に取り出す。
	var frontier: Array = [[0, 0, unit.cell]]
	var order := 1
	while not frontier.is_empty():
		var best := 0
		for i in range(1, frontier.size()):
			if frontier[i][0] < frontier[best][0] or (
				frontier[i][0] == frontier[best][0] and frontier[i][1] < frontier[best][1]
			):
				best = i
		var entry: Array = frontier.pop_at(best)
		var cell: Vector2i = entry[2]
		if done.has(cell):
			continue
		done[cell] = true
		if cell != unit.cell and battle.is_in_enemy_zoc(cell, unit.side):
			continue
		var steps: Array[Vector2i] = []
		var exit := battle.portal_exit(cell)
		if exit != Board.NO_CELL:
			steps.append(exit)
		for direction in Board.DIRECTIONS:
			steps.append(cell + direction)
		for next in steps:
			if not battle.board.is_walkable(next):
				continue
			var occupant := battle.unit_at(next)
			if occupant != null and occupant.is_enemy_of(unit):
				continue
			var next_cost: int = cost[cell] + (0 if next == exit else battle.board.move_cost(next))
			if next_cost > limit or (cost.has(next) and cost[next] <= next_cost):
				continue
			cost[next] = next_cost
			parent[next] = cell
			frontier.append([next_cost, order, next])
			order += 1
	return {"cost": cost, "parent": parent}
