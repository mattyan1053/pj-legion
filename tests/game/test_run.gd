extends "res://tests/base_test.gd"
## 流れ（game/run.gd）: 場面と渡すものの列を、順に進める。

const Run := preload("res://game/run.gd")


func test_goes_through_the_scenes_in_order_with_their_data() -> void:
	var run := Run.new()
	run.add(&"talk", "前")
	run.add(&"battle", 3)
	run.add(&"talk", "後")
	assert_eq(run.scene(), &"talk")
	assert_eq(run.data(), "前")
	assert_eq(run.advance(), &"battle")
	assert_eq(run.data(), 3)
	assert_eq(run.advance(), &"talk", "同じ場面を、違うものを渡して 2 回使える")
	assert_eq(run.data(), "後")
	assert_false(run.is_done())


func test_ends_at_the_exit() -> void:
	var run := Run.new()
	run.add(&"battle")
	run.exit = &"stage"
	assert_eq(run.advance(), &"stage")
	assert_true(run.is_done())
	assert_eq(run.scene(), &"")
	assert_eq(run.data(), null)
	assert_eq(run.advance(), &"stage", "終えたあとも、行き先は exit のまま")


func test_an_empty_run_is_done() -> void:
	assert_true(Run.new().is_done())
