extends "res://tests/base_test.gd"
## 開いている重なる画面の積み上げ（game/overlay_stack.gd）。

const OverlayStack := preload("res://game/overlay_stack.gd")


func test_empty_stack_covers_nothing() -> void:
	var stack := OverlayStack.new()
	assert_false(stack.is_open())
	assert_false(stack.pauses())
	assert_eq(stack.top(), null)


func test_only_the_top_takes_escape() -> void:
	var stack := OverlayStack.new()
	var setup := RefCounted.new()
	var menu := RefCounted.new()
	stack.open(setup)
	stack.open(menu, true)
	assert_true(stack.is_top(menu), "あとから開いたものが上に来ない")
	assert_false(stack.is_top(setup), "下の重なる画面も Esc を受ける")
	stack.close(menu)
	assert_true(stack.is_top(setup), "上を閉じても、下が Esc を受けない")


func test_pausing_follows_what_is_open() -> void:
	var stack := OverlayStack.new()
	var setup := RefCounted.new()
	var log_panel := RefCounted.new()
	stack.open(setup)
	assert_true(stack.is_open())
	assert_false(stack.pauses(), "対戦の設定は時間を止めない")
	stack.open(log_panel, true)
	assert_true(stack.pauses())
	stack.close(log_panel)
	assert_false(stack.pauses(), "ログを閉じても、時間を止めたまま")
	stack.close(setup)
	assert_false(stack.is_open())


func test_opening_twice_keeps_one_entry_in_place() -> void:
	var stack := OverlayStack.new()
	var setup := RefCounted.new()
	var menu := RefCounted.new()
	stack.open(setup)
	stack.open(menu, true)
	stack.open(setup)
	assert_true(stack.is_top(menu), "開き直しで、下のものが上へ来た")
	stack.close(setup)
	assert_false(stack.has(setup), "2 回開いたものが、1 回閉じても残る")
	stack.close(setup)  # 積んでいないものを閉じても何もしない
	assert_true(stack.is_top(menu))
