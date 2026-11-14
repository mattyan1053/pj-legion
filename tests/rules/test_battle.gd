extends "res://tests/base_test.gd"
## Battle の土台: apply() の結果の形、複製（clone）、乱数、行動とイベントの型。

const Maps := preload("res://tests/support/maps.gd")

const P1 := Unit.Side.PLAYER1
const P2 := Unit.Side.PLAYER2
const P1_HQ := Vector2i(2, 4)
const P2_HQ := Vector2i(2, 0)


## 受け付けるが、何も起こさない行動（結果の形を確かめるためだけのもの）。
class NothingHappens:
	extends BattleAction

	func is_valid(_battle: Battle) -> bool:
		return true

	func execute(_battle: Battle) -> Array[BattleEvent]:
		return []


func _battle() -> Battle:
	var battle := Maps.battle([
		".....",
		"..F..",
		".....",
		".....",
		".....",
	])
	battle.board.hq_cells = [P1_HQ, P2_HQ]
	return battle


# --- apply() の結果 ---


func test_accepted_actions_report_their_events() -> void:
	var battle := _battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	var result := battle.apply(WaitAction.new(sniper.id))
	assert_true(result.accepted)
	assert_eq(result.events.size(), 1)
	assert_true(result.events[0] is UnitActedEvent)


func test_rejected_actions_are_told_apart_from_quiet_ones() -> void:
	var battle := _battle()
	var rejected := battle.apply(WaitAction.new(999))
	assert_false(rejected.accepted)
	assert_eq(rejected.events.size(), 0)
	var quiet := battle.apply(NothingHappens.new())
	assert_true(quiet.accepted)
	assert_eq(quiet.events.size(), 0)


func test_can_apply_checks_without_changing_anything() -> void:
	var battle := _battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	assert_true(battle.can_apply(MoveAction.new(sniper.id, Vector2i(1, 0))))
	assert_false(battle.can_apply(MoveAction.new(sniper.id, Vector2i(4, 4))))
	assert_eq(sniper.cell, Vector2i(0, 0))
	assert_false(sniper.has_moved)


func test_nothing_can_be_applied_after_the_game_ends() -> void:
	var battle := _battle()
	battle.winner = P1
	assert_false(battle.can_apply(NothingHappens.new()))
	assert_false(battle.apply(NothingHappens.new()).accepted)


# --- 複製 ---


func test_clone_starts_from_the_same_state() -> void:
	var battle := _battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(2, 2))
	var king := battle.add_unit(UnitKind.Id.KING, P2, Vector2i(4, 4))
	king.hp = 7
	battle.apply(MoveAction.new(sniper.id, P2_HQ))
	battle.apply(EndPhaseAction.new())
	battle.apply(EndPhaseAction.new())
	battle.apply(MoveAction.new(sniper.id, Vector2i(2, 1)))

	var copy := battle.clone()
	assert_eq(copy.turn, battle.turn)
	assert_eq(copy.phase, battle.phase)
	assert_eq(copy.acting_unit_id, sniper.id)
	assert_eq(copy.capture_turns, battle.capture_turns)
	assert_eq(copy.capture_turns_before_move, battle.capture_turns_before_move)
	assert_eq(copy.winner, battle.winner)
	assert_eq(copy.units.size(), 2)
	var copied := copy.unit_by_id(sniper.id)
	assert_true(copied != sniper)
	assert_eq(copied.cell, sniper.cell)
	assert_eq(copied.move_origin, sniper.move_origin)
	assert_true(copied.has_moved)
	assert_eq(copy.unit_by_id(king.id).hp, 7)
	assert_true(copy.board != battle.board)
	assert_eq(copy.board.terrain_at(Vector2i(2, 1)), Terrain.Type.FOREST)
	assert_eq(copy.board.hq_cells, battle.board.hq_cells)


func test_moving_in_a_clone_leaves_the_original_alone() -> void:
	var battle := _battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	var copy := battle.clone()
	assert_true(copy.apply(MoveAction.new(sniper.id, Vector2i(2, 0))).accepted)
	assert_eq(copy.unit_by_id(sniper.id).cell, Vector2i(2, 0))
	assert_eq(sniper.cell, Vector2i(0, 0))
	assert_false(sniper.has_moved)
	assert_eq(battle.acting_unit_id, 0)
	assert_eq(battle.unit_at(Vector2i(2, 0)), null)


func test_attacking_in_a_clone_leaves_the_original_alone() -> void:
	var battle := _battle()
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(0, 0))
	var minion := battle.add_unit(UnitKind.Id.MINION, Unit.Side.NEUTRAL, Vector2i(1, 0))
	var copy := battle.clone()
	copy.apply(AttackAction.new(commando.id, minion.id))
	assert_eq(copy.unit_by_id(minion.id), null)
	assert_eq(battle.unit_by_id(minion.id), minion)
	assert_eq(minion.hp, 12)
	assert_false(commando.acted)


func test_ending_a_phase_in_a_clone_leaves_the_original_alone() -> void:
	var battle := _battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	battle.apply(WaitAction.new(sniper.id))
	var copy := battle.clone()
	copy.apply(EndPhaseAction.new())
	copy.apply(EndPhaseAction.new())
	assert_eq(copy.turn, 2)
	assert_false(copy.unit_by_id(sniper.id).acted)
	assert_eq(battle.turn, 1)
	assert_eq(battle.phase, P1)
	assert_true(sniper.acted)


func test_capturing_and_winning_in_a_clone_leaves_the_original_alone() -> void:
	var battle := _battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(2, 2))
	battle.apply(MoveAction.new(sniper.id, P2_HQ))
	var copy := battle.clone()
	for i in 3:
		copy.apply(EndPhaseAction.new())  # P1 の終わり
		copy.apply(EndPhaseAction.new())  # P2 の終わり
	assert_eq(copy.winner, P1)
	assert_eq(battle.winner, -1)
	assert_eq(battle.capture_turns, [0, 0] as Array[int])
	assert_eq(battle.acting_unit_id, sniper.id)


func test_undo_in_a_clone_leaves_the_original_mid_action() -> void:
	var battle := _battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	battle.apply(MoveAction.new(sniper.id, Vector2i(1, 0)))
	var copy := battle.clone()
	assert_true(copy.apply(UndoMoveAction.new(sniper.id)).accepted)
	assert_eq(copy.unit_by_id(sniper.id).cell, Vector2i(0, 0))
	assert_eq(sniper.cell, Vector2i(1, 0))
	assert_eq(battle.acting_unit_id, sniper.id)


func test_clone_numbers_new_units_like_the_original() -> void:
	var battle := _battle()
	battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	var copy := battle.clone()
	var in_copy := copy.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(4, 4))
	var in_original := battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(4, 4))
	assert_eq(in_copy.id, in_original.id)
	assert_eq(battle.units.size(), 2)


func test_board_changes_in_a_clone_stay_there() -> void:
	var battle := _battle()
	var copy := battle.clone()
	copy.board.set_terrain(Vector2i(0, 0), Terrain.Type.OBSTACLE)
	copy.board.hq_cells[0] = Vector2i(0, 4)
	assert_eq(battle.board.terrain_at(Vector2i(0, 0)), Terrain.Type.NORMAL)
	assert_eq(battle.board.hq_cells[0], P1_HQ)


# --- 乱数 ---


func _draws(battle: Battle, count: int) -> Array[int]:
	var result: Array[int] = []
	for i in count:
		result.append(battle.rng.randi())
	return result


func test_the_same_seed_gives_the_same_draws() -> void:
	var first := Battle.new(Maps.board(["."]), 42)
	var second := Battle.new(Maps.board(["."]), 42)
	var other := Battle.new(Maps.board(["."]), 43)
	var draws := _draws(first, 5)
	assert_eq(_draws(second, 5), draws)
	assert_ne(_draws(other, 5), draws)


func test_a_clone_draws_what_the_original_would_draw_next() -> void:
	var battle := Battle.new(Maps.board(["."]), 7)
	_draws(battle, 3)
	var copy := battle.clone()
	var from_copy := _draws(copy, 5)
	assert_eq(_draws(battle, 5), from_copy)  # 複製から引いても、元の続きは進まない


# --- 型 ---


func test_every_action_is_a_battle_action() -> void:
	for script in _scripts("res://rules/actions"):
		assert_true(_extends(script, BattleAction), "%s が BattleAction を継承していない" % script.resource_path)


func test_every_event_is_a_battle_event() -> void:
	for script in _scripts("res://rules/events"):
		assert_true(_extends(script, BattleEvent), "%s が BattleEvent を継承していない" % script.resource_path)


func _scripts(dir_path: String) -> Array[GDScript]:
	var found: Array[GDScript] = []
	for file in DirAccess.get_files_at(dir_path):
		if file.ends_with(".gd"):
			found.append(load(dir_path.path_join(file)))
	return found


func _extends(script: Script, base: Script) -> bool:
	while script != null:
		if script == base:
			return true
		script = script.get_base_script()
	return false
