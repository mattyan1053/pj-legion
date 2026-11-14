extends "res://tests/base_test.gd"
## 移動の行動を Battle に渡したときの状態の変化と、返ってくるイベント。

const Maps := preload("res://tests/support/maps.gd")


func _battle() -> Battle:
	return Maps.battle([
		"........",
		"........",
	])


func test_move_updates_the_unit_and_reports_the_path() -> void:
	var battle := _battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, Unit.Side.PLAYER1, Vector2i(0, 0))
	var events := battle.apply(MoveAction.new(sniper.id, Vector2i(2, 1))).events
	assert_eq(sniper.cell, Vector2i(2, 1))
	assert_eq(battle.unit_at(Vector2i(2, 1)), sniper)
	assert_eq(battle.unit_at(Vector2i(0, 0)), null)
	assert_eq(events.size(), 1)
	var moved := events[0] as UnitMovedEvent
	assert_true(moved != null)
	assert_eq(moved.unit_id, sniper.id)
	assert_eq(moved.path[0], Vector2i(0, 0))
	assert_eq(moved.path[-1], Vector2i(2, 1))
	assert_eq(moved.path.size(), 4)
	assert_false(moved.cruise)


func test_out_of_range_is_rejected() -> void:
	var battle := _battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, Unit.Side.PLAYER1, Vector2i(0, 0))
	var result := battle.apply(MoveAction.new(sniper.id, Vector2i(5, 0)))
	assert_false(result.accepted)
	assert_eq(result.events.size(), 0)
	assert_eq(sniper.cell, Vector2i(0, 0))


func test_cruise_reaches_twice_as_far() -> void:
	var battle := _battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, Unit.Side.PLAYER1, Vector2i(0, 0))
	var events := battle.apply(MoveAction.new(sniper.id, Vector2i(6, 0), true)).events
	assert_eq(events.size(), 1)
	assert_eq(sniper.cell, Vector2i(6, 0))
	assert_true((events[0] as UnitMovedEvent).cruise)


func test_moved_event_keeps_cruise_after_the_action_ends() -> void:
	# イベントは起きた時点の値を持つ。駒の状態（Unit.cruised）は行動を終えると消えるが、イベントは変わらない。
	var battle := _battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, Unit.Side.PLAYER1, Vector2i(0, 0))
	var moved := battle.apply(MoveAction.new(sniper.id, Vector2i(1, 0), true)).events[0] as UnitMovedEvent
	battle.apply(WaitAction.new(sniper.id))
	assert_false(sniper.cruised)
	assert_true(moved.cruise)


func test_occupied_destination_is_rejected() -> void:
	var battle := _battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, Unit.Side.PLAYER1, Vector2i(0, 0))
	battle.add_unit(UnitKind.Id.SNIPER, Unit.Side.PLAYER1, Vector2i(1, 1))
	assert_false(battle.apply(MoveAction.new(sniper.id, Vector2i(1, 1))).accepted)


func test_staying_put_is_allowed() -> void:
	var battle := _battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, Unit.Side.PLAYER1, Vector2i(3, 0))
	var events := battle.apply(MoveAction.new(sniper.id, Vector2i(3, 0))).events
	assert_eq(events.size(), 1)
	assert_eq((events[0] as UnitMovedEvent).path, [Vector2i(3, 0)] as Array[Vector2i])


func test_unknown_unit_is_rejected() -> void:
	var battle := _battle()
	assert_false(battle.apply(MoveAction.new(999, Vector2i(0, 0))).accepted)


func test_units_cannot_be_placed_on_obstacles_or_each_other() -> void:
	var battle := Maps.battle([".#."])
	assert_eq(battle.add_unit(UnitKind.Id.SNIPER, Unit.Side.PLAYER1, Vector2i(1, 0)), null)
	var first := battle.add_unit(UnitKind.Id.SNIPER, Unit.Side.PLAYER1, Vector2i(0, 0))
	assert_eq(battle.add_unit(UnitKind.Id.SNIPER, Unit.Side.PLAYER2, Vector2i(0, 0)), null)
	var second := battle.add_unit(UnitKind.Id.SNIPER, Unit.Side.PLAYER2, Vector2i(2, 0))
	assert_ne(first.id, second.id)
