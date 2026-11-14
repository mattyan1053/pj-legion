extends "res://tests/base_test.gd"
## 試作の対戦の準備（仮の編成と配置）。

const TrialSetup := preload("res://prototype/trial_setup.gd")
const Queries := preload("res://prototype/battle_queries.gd")

const STAGES: Array[BoardGenerator.Stage] = [
	BoardGenerator.Stage.PLAIN, BoardGenerator.Stage.LABYRINTH, BoardGenerator.Stage.TWIN_SPRINGS,
]


func test_every_unit_is_placed_on_every_stage() -> void:
	for stage in STAGES:
		for map_seed in 20:
			var battle := TrialSetup.create(stage, map_seed)
			for side: Unit.Side in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
				var wanted: Array = TrialSetup.ARMIES[side]
				assert_eq(Queries.unit_count(battle, side), wanted.size(), "ステージ %d シード %d" % [stage, map_seed])


func test_king_stands_on_own_hq() -> void:
	for stage in STAGES:
		var battle := TrialSetup.create(stage, 1)
		for side: Unit.Side in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
			assert_eq(Queries.king_of(battle, side).cell, battle.board.hq_cells[side])


func test_armies_are_point_symmetric() -> void:
	for stage in STAGES:
		var battle := TrialSetup.create(stage, 1)
		var hqs := battle.board.hq_cells
		for unit in battle.units:
			if unit.side == Unit.Side.PLAYER1:
				var mirror := battle.unit_at(hqs[1] - (unit.cell - hqs[0]))
				assert_true(mirror != null and mirror.side == Unit.Side.PLAYER2, "ステージ %d の %s" % [stage, unit.cell])


func test_battle_starts_at_player1_and_every_unit_can_move() -> void:
	for stage in STAGES:
		var battle := TrialSetup.create(stage, 1)
		assert_eq(battle.turn, 1)
		assert_eq(battle.phase, Unit.Side.PLAYER1)
		for unit in battle.units:
			if unit.side == Unit.Side.PLAYER1:
				assert_false(Queries.move_cells(battle, unit).is_empty(), "ステージ %d の %s" % [stage, unit.cell])


func test_same_seed_makes_same_battle() -> void:
	var a := TrialSetup.create(BoardGenerator.Stage.PLAIN, 7)
	var b := TrialSetup.create(BoardGenerator.Stage.PLAIN, 7)
	for y in a.board.size.y:
		for x in a.board.size.x:
			assert_eq(a.board.terrain_at(Vector2i(x, y)), b.board.terrain_at(Vector2i(x, y)))
