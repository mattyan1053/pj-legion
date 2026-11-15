extends "res://tests/base_test.gd"
## フェーズの始めにカメラが寄る駒（prototype/phase_focus.gd）。

const PhaseFocus := preload("res://prototype/phase_focus.gd")
const Maps := preload("res://tests/support/maps.gd")

const P1 := Unit.Side.PLAYER1
const P2 := Unit.Side.PLAYER2


func _battle() -> Battle:
	return Maps.battle([
		"........",
		"........",
		"........",
		"........",
	])


func _act(battle: Battle, focus: RefCounted, action: BattleAction) -> void:
	var result := battle.apply(action)
	assert_true(result.accepted, "行動が通らない")
	focus.feed(battle, result.events)


func test_before_anyone_acts_it_is_the_unit_in_the_middle_of_the_army_not_the_king() -> void:
	var battle := _battle()
	battle.add_unit(UnitKind.Id.KING, P1, Vector2i(0, 3))
	var middle := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(3, 2))
	battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(6, 2))
	battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(7, 0))
	var focus := PhaseFocus.new()
	assert_eq(focus.unit_for(battle, P1), middle, "味方の真ん中にいちばん近い駒（将ではない）")


func test_it_is_the_last_unit_that_finished_acting() -> void:
	var battle := _battle()
	battle.add_unit(UnitKind.Id.KING, P1, Vector2i(0, 3))
	var first := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(2, 2))
	var second := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(4, 2))
	battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(7, 0))
	var focus := PhaseFocus.new()
	_act(battle, focus, WaitAction.new(second.id))
	_act(battle, focus, WaitAction.new(first.id))
	assert_eq(focus.unit_for(battle, P1), first, "最後に行動を確定した駒")
	assert_eq(focus.unit_for(battle, P2).kind, UnitKind.Id.PALADIN, "動いていない陣営は、生きている駒のどれか")


func test_moving_and_ending_the_phase_counts_as_the_last_action() -> void:
	var battle := _battle()
	battle.add_unit(UnitKind.Id.KING, P1, Vector2i(0, 3))
	var waited := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(2, 2))
	var moved := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(4, 2))
	battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(7, 0))
	var focus := PhaseFocus.new()
	_act(battle, focus, WaitAction.new(waited.id))
	_act(battle, focus, MoveAction.new(moved.id, Vector2i(5, 2)))
	_act(battle, focus, EndPhaseAction.new())
	assert_eq(focus.unit_for(battle, P1), moved, "動いたままターンを終えた駒")


func test_a_fallen_last_unit_falls_back_to_a_living_one() -> void:
	var battle := _battle()
	battle.add_unit(UnitKind.Id.KING, P1, Vector2i(0, 3))
	var fallen := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(2, 2))
	battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(7, 0))
	var focus := PhaseFocus.new()
	_act(battle, focus, WaitAction.new(fallen.id))
	battle.units.erase(fallen)
	var found: Unit = focus.unit_for(battle, P1)
	assert_true(found != null and found.side == P1 and found != fallen, "倒れていたら、ほかの生きている駒")
	focus.clear()
	assert_eq(focus.unit_for(battle, P1).kind, UnitKind.Id.KING, "残っているのが将だけなら将")


func test_no_living_unit_means_no_focus() -> void:
	var battle := _battle()
	battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(7, 0))
	assert_eq(PhaseFocus.new().unit_for(battle, P1), null)
