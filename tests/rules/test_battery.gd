extends "res://tests/base_test.gd"
## 砲台（マップの物。docs/map-objects.md の「砲台」）: 置く盤、乗った後衛の射程、危険の読み、CPU。

const Maps := preload("res://tests/support/maps.gd")

const P1 := Unit.Side.PLAYER1
const P2 := Unit.Side.PLAYER2
const STAGES: Array[BoardGenerator.Stage] = [
	BoardGenerator.Stage.PLAIN, BoardGenerator.Stage.LABYRINTH, BoardGenerator.Stage.TWIN_SPRINGS,
]


func _setup(stage: BoardGenerator.Stage, battle_seed: int, rules: Array[StringName] = []) -> MatchSetup:
	var setup := MatchSetup.versus_human(
		stage, battle_seed, MatchSetup.default_deck(UnitKind.Army.MILITARY), MatchSetup.default_deck(UnitKind.Army.FANTASY)
	)
	setup.rules = rules
	return setup


## 1 行の盤。x = 2 に砲台。
func _lane() -> Battle:
	var board := Maps.board(["..............", ".............."])
	board.add_battery(Vector2i(2, 0))
	return Battle.new(board)


# --- 置く ---


func test_generated_boards_have_batteries_only_on_the_listed_stages() -> void:
	for stage in STAGES:
		for battle_seed: int in [1, 2, 3]:
			var battle := _setup(stage, battle_seed).create_battle()
			assert_eq(battle.board.battery_spots.size(), 2, "場所は、砲台を置かない盤も持つ")
			var expected := 2 if BoardGenerator.BATTERY_STAGES.has(stage) else 0
			assert_eq(battle.board.battery_cells.size(), expected, "マップ %d 種 %d" % [stage, battle_seed])
			if expected == 0:
				for unit in battle.units:
					assert_eq(unit.site_range, 0)


func test_the_battle_board_is_the_generated_board() -> void:
	# 砲台は盤を作るときに置く（MatchSetup は何も足さない）。拠点の無い設定なら、対戦の盤は生成の盤そのもの。
	for stage in STAGES:
		var plain := BoardGenerator.generate(stage, 7)
		var battle := _setup(stage, 7).create_battle()
		for y in plain.size.y:
			for x in plain.size.x:
				var cell := Vector2i(x, y)
				assert_eq(battle.board.terrain_at(cell), plain.terrain_at(cell))
				assert_eq(battle.board.object_at(cell), plain.object_at(cell))


func test_battery_spots_take_two_reachable_batteries() -> void:
	# どの生成の盤の場所も、置けば歩いて行ける 2 つの砲台になる（いま置かない盤も、置く盤に足せる）。
	for stage in STAGES:
		for battle_seed: int in [1, 2, 3, 4, 5]:
			var board := BoardGenerator.generate(stage, battle_seed)
			BoardGenerator.arm_batteries(board)
			assert_eq(board.battery_cells.size(), 2, "マップ %d 種 %d" % [stage, battle_seed])
			for cell in board.battery_cells:
				assert_eq(board.object_at(cell), MapObject.Type.BATTERY)
				assert_true(board.is_walkable(cell))
				assert_true(board.is_reachable(board.hq_cells[P1], cell))
				assert_true(board.is_reachable(board.hq_cells[P2], cell))
			# 本陣どうしを入れ替える点対称。
			assert_eq(board.battery_cells[0] + board.battery_cells[1], board.hq_cells[P1] + board.hq_cells[P2])


func test_a_hand_map_battery_is_always_there() -> void:
	var map := HandMap.new(["..2..", "..C..", ".....", "..C..", "..1.."] as Array[String])
	var board := map.make_board()
	assert_eq(board.battery_cells, [Vector2i(2, 1), Vector2i(2, 3)] as Array[Vector2i])
	assert_eq(board.object_at(Vector2i(2, 1)), MapObject.Type.BATTERY)


func test_batteries_sit_outside_the_reach_of_mid_bosses() -> void:
	var reach := Neutral.TERRITORY_RADIUS + UnitKind.attack_range(UnitKind.Id.ELITE_MINION)
	for stage in STAGES:
		var board := BoardGenerator.generate(stage, 1)
		for spot in board.battery_spots:
			for home in board.mid_boss_cells:
				assert_true(Combat.distance(spot, home) > reach, "マップ %d の %s" % [stage, spot])


func test_battery_is_not_placed_on_another_object() -> void:
	var board := Maps.board(["...S...", "1.....2"])
	board.hq_cells = [Vector2i(0, 1), Vector2i(6, 1)]
	board.battery_spots = [Vector2i(3, 0), Vector2i(5, 0)]
	BoardGenerator.arm_batteries(board)
	assert_eq(board.battery_cells, [Vector2i(5, 0)] as Array[Vector2i])
	assert_eq(board.object_at(Vector2i(3, 0)), MapObject.Type.SPRING)


# --- 射程 ---


func test_rearguard_on_a_battery_shoots_farther() -> void:
	var battle := _lane()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(1, 0))
	var foe := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(2 + 4 + MapObject.BATTERY_RANGE, 0))
	var base := sniper.attack_range()
	assert_false(battle.can_apply(AttackAction.new(sniper.id, foe.id)))
	assert_true(battle.apply(MoveAction.new(sniper.id, Vector2i(2, 0))).accepted)
	assert_eq(sniper.attack_range(), base + MapObject.BATTERY_RANGE)
	assert_true(battle.options(sniper.id).attack_target_ids.has(foe.id))
	assert_true(battle.apply(AttackAction.new(sniper.id, foe.id)).accepted)
	assert_true(foe.hp < foe.max_hp())


func test_bonus_goes_away_when_the_unit_leaves() -> void:
	var battle := _lane()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(2, 0))
	var base := UnitKind.attack_range(UnitKind.Id.SNIPER)
	assert_eq(sniper.attack_range(), base + MapObject.BATTERY_RANGE, "置いたときから")
	battle.apply(MoveAction.new(sniper.id, Vector2i(3, 0)))
	assert_eq(sniper.attack_range(), base)
	battle.apply(UndoMoveAction.new(sniper.id))
	assert_eq(sniper.attack_range(), base + MapObject.BATTERY_RANGE, "取り消して戻れば、戻る")


func test_only_rearguards_get_the_bonus() -> void:
	for kind: UnitKind.Id in [UnitKind.Id.KING, UnitKind.Id.SHIELD_TROOPER, UnitKind.Id.COMMANDO, UnitKind.Id.MEDIC, UnitKind.Id.PRIEST]:
		var battle := _lane()
		var unit := battle.add_unit(kind, P1, Vector2i(2, 0))
		assert_eq(unit.attack_range(), UnitKind.attack_range(kind), "種類 %d" % kind)
	var battle := _lane()
	var sorcerer := battle.add_unit(UnitKind.Id.SORCERER, P1, Vector2i(2, 0))
	assert_eq(sorcerer.attack_range(), UnitKind.attack_range(UnitKind.Id.SORCERER) + MapObject.BATTERY_RANGE)


func test_clone_keeps_the_bonus() -> void:
	var battle := _lane()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(2, 0))
	var copy := battle.clone()
	assert_eq(copy.unit_by_id(sniper.id).attack_range(), sniper.attack_range())
	assert_eq(copy.board.battery_cells, battle.board.battery_cells)


# --- 危険の読みと CPU ---


func test_threat_counts_the_longer_reach_from_a_battery() -> void:
	var battle := _lane()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(1, 0))
	var far := Vector2i(2 + UnitKind.attack_range(UnitKind.Id.SNIPER) + MapObject.BATTERY_RANGE, 0)
	var map := Threat.of(battle, sniper.id)
	assert_true(map.hits.has(far), "砲台に乗れば届くマス")
	assert_false(map.hits.has(far + Vector2i(1, 0)))
	battle.board.battery_cells.clear()
	assert_false(Threat.of(battle, sniper.id).hits.has(far), "砲台が無ければ届かない")


func test_threat_counts_barrels_within_the_longer_reach() -> void:
	var battle := _lane()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(1, 0))
	var barrel := Vector2i(2 + UnitKind.attack_range(UnitKind.Id.SNIPER) + MapObject.BATTERY_RANGE, 0)
	battle.board.add_barrel(barrel)
	assert_true(Threat.of(battle, sniper.id).hits.has(barrel + Vector2i(1, 0)), "砲台から撃てる樽の爆発")
	battle.board.battery_cells.clear()
	assert_false(Threat.of(battle, sniper.id).hits.has(barrel + Vector2i(1, 0)))


func test_cpu_steps_onto_a_battery_to_shoot() -> void:
	var battle := _lane()
	battle.add_unit(UnitKind.Id.KING, P1, Vector2i(0, 1))
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(1, 0))
	battle.add_unit(UnitKind.Id.KING, P2, Vector2i(13, 1))
	var foe := battle.add_unit(UnitKind.Id.SORCERER, P2, Vector2i(2 + 4 + MapObject.BATTERY_RANGE, 0))
	var cpu := CpuPlayer.new()
	var attacked := false
	for step in 8:
		var action := cpu.next_action(battle)
		if action is EndPhaseAction:
			break
		if action is AttackAction and (action as AttackAction).unit_id == sniper.id:
			attacked = true
			assert_eq(sniper.cell, Vector2i(2, 0))
		battle.apply(action)
	assert_true(attacked, "砲台に乗って撃つ")
	assert_true(foe.hp < foe.max_hp())
