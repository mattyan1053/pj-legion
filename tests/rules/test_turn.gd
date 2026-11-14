extends "res://tests/base_test.gd"
## ターンとフェーズ、駒 1 体ごとの行動の流れ（移動 → 待機 / 取り消し）。

const Maps := preload("res://tests/support/maps.gd")

const P1 := Unit.Side.PLAYER1
const P2 := Unit.Side.PLAYER2


func _battle() -> Battle:
	return Maps.battle([
		"........",
		"........",
		"........",
	])


func test_starts_at_turn_1_with_player1() -> void:
	var battle := _battle()
	assert_eq(battle.turn, 1)
	assert_eq(battle.phase, P1)


func test_phases_go_p1_p2_neutral_then_next_turn() -> void:
	var battle := _battle()
	var events := battle.apply(EndPhaseAction.new())
	assert_eq(events.size(), 1)
	assert_eq((events[0] as PhaseStartedEvent).side, P2)
	assert_eq(battle.phase, P2)
	assert_eq(battle.turn, 1)

	events = battle.apply(EndPhaseAction.new())
	assert_eq(events.size(), 2)
	assert_eq((events[0] as PhaseStartedEvent).side, Unit.Side.NEUTRAL)
	assert_eq((events[0] as PhaseStartedEvent).turn, 1)
	assert_eq((events[1] as PhaseStartedEvent).side, P1)
	assert_eq((events[1] as PhaseStartedEvent).turn, 2)
	assert_eq(battle.phase, P1)
	assert_eq(battle.turn, 2)


func test_only_the_current_side_can_act() -> void:
	var battle := _battle()
	var mine := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	var theirs := battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(7, 2))
	assert_eq(battle.apply(MoveAction.new(theirs.id, Vector2i(6, 2))), [])
	assert_eq(battle.apply(WaitAction.new(theirs.id)), [])
	assert_eq(battle.apply(MoveAction.new(mine.id, Vector2i(1, 0))).size(), 1)


func test_wait_marks_the_unit_as_acted() -> void:
	var battle := _battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	var events := battle.apply(WaitAction.new(sniper.id))
	assert_eq(events.size(), 1)
	assert_eq((events[0] as UnitActedEvent).unit_id, sniper.id)
	assert_true(sniper.acted)


func test_acted_units_cannot_act_again() -> void:
	var battle := _battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	battle.apply(MoveAction.new(sniper.id, Vector2i(1, 0)))
	battle.apply(WaitAction.new(sniper.id))
	assert_eq(battle.apply(MoveAction.new(sniper.id, Vector2i(2, 0))), [])
	assert_eq(battle.apply(WaitAction.new(sniper.id)), [])
	assert_eq(sniper.cell, Vector2i(1, 0))


func test_a_unit_moves_only_once_per_action() -> void:
	var battle := _battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	battle.apply(MoveAction.new(sniper.id, Vector2i(1, 0)))
	assert_eq(battle.apply(MoveAction.new(sniper.id, Vector2i(2, 0))), [])


func test_other_units_wait_while_one_is_mid_action() -> void:
	var battle := _battle()
	var first := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	var second := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 2))
	battle.apply(MoveAction.new(first.id, Vector2i(1, 0)))
	assert_eq(battle.apply(MoveAction.new(second.id, Vector2i(1, 2))), [])
	battle.apply(WaitAction.new(first.id))
	assert_eq(battle.apply(MoveAction.new(second.id, Vector2i(1, 2))).size(), 1)


func test_undo_move_returns_the_unit_and_lets_it_act_again() -> void:
	var battle := _battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	battle.apply(MoveAction.new(sniper.id, Vector2i(2, 1)))
	var events := battle.apply(UndoMoveAction.new(sniper.id))
	assert_eq(events.size(), 1)
	var undone := events[0] as MoveUndoneEvent
	assert_eq(undone.from, Vector2i(2, 1))
	assert_eq(undone.to, Vector2i(0, 0))
	assert_eq(sniper.cell, Vector2i(0, 0))
	assert_false(sniper.acted)
	assert_eq(battle.acting_unit_id, 0)
	assert_eq(battle.apply(MoveAction.new(sniper.id, Vector2i(3, 0))).size(), 1)


func test_undo_needs_a_move() -> void:
	var battle := _battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	assert_eq(battle.apply(UndoMoveAction.new(sniper.id)), [])
	battle.apply(MoveAction.new(sniper.id, Vector2i(1, 0)))
	battle.apply(WaitAction.new(sniper.id))
	assert_eq(battle.apply(UndoMoveAction.new(sniper.id)), [])


func test_phase_does_not_end_by_itself() -> void:
	var battle := _battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	var events := battle.apply(WaitAction.new(sniper.id))
	assert_eq(events.size(), 1)  # 行動済みになるだけ
	assert_eq(battle.phase, P1)


func test_phase_can_end_with_units_left() -> void:
	var battle := _battle()
	battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	assert_eq(battle.apply(EndPhaseAction.new()).size(), 1)
	assert_eq(battle.phase, P2)


func test_ending_the_phase_finishes_a_unit_mid_action() -> void:
	var battle := _battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	battle.apply(MoveAction.new(sniper.id, Vector2i(1, 0)))
	var events := battle.apply(EndPhaseAction.new())
	assert_eq(events.size(), 2)
	assert_eq((events[0] as UnitActedEvent).unit_id, sniper.id)
	assert_eq(sniper.cell, Vector2i(1, 0))
	assert_eq(battle.acting_unit_id, 0)


func test_units_are_ready_again_at_their_next_phase() -> void:
	var battle := _battle()
	var mine := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	var theirs := battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(7, 2))
	battle.apply(WaitAction.new(mine.id))
	battle.apply(EndPhaseAction.new())  # → P2
	assert_true(mine.acted)  # 相手のフェーズでは戻らない
	battle.apply(WaitAction.new(theirs.id))
	battle.apply(EndPhaseAction.new())  # → 中立 → 次のターンの P1
	assert_false(mine.acted)
	assert_true(theirs.acted)
	assert_eq(battle.apply(MoveAction.new(mine.id, Vector2i(1, 0))).size(), 1)


func test_neutral_units_never_act_in_player_phases() -> void:
	var battle := _battle()
	var minion := battle.add_unit(UnitKind.Id.MINION, Unit.Side.NEUTRAL, Vector2i(4, 1))
	assert_eq(battle.apply(WaitAction.new(minion.id)), [])
	battle.apply(EndPhaseAction.new())
	assert_eq(battle.apply(WaitAction.new(minion.id)), [])
