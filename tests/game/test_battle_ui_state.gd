extends "res://tests/base_test.gd"
## 対戦の画面の操作の状態（game/battle_ui_state.gd）。消す単位と、組み合わせの決まり。

const BattleUiState := preload("res://game/battle_ui_state.gd")
const Mode := BattleUiState.Mode
const Back := BattleUiState.Back


## 選んで、見て、対象を選び始め、確かめも始めた状態（消す単位を確かめる元）。
func _busy_state() -> BattleUiState:
	var ui := BattleUiState.new()
	ui.select(3)
	ui.inspect(5)
	ui.inspected_cell = Vector2i(2, 2)
	ui.mode = Mode.ATTACK
	ui.confirming_end = true
	ui.confirming_ult = true
	ui.press(Vector2(10, 10), false)
	ui.drag(Vector2(40, 10))
	return ui


func test_new_battle_forgets_everything_of_the_last_battle() -> void:
	var ui := _busy_state()
	ui.clear_for_new_battle()
	assert_eq(ui.selected_id, 0)
	assert_eq(ui.inspected_id, 0, "新しい対戦で、前の対戦の見ている駒を持ち越した")
	assert_eq(ui.inspected_cell, BattleUiState.NO_CELL)
	assert_eq(ui.mode, Mode.NONE)
	assert_false(ui.confirming_end or ui.confirming_ult)
	assert_false(ui.pressing or ui.dragging, "押している途中を持ち越した")


func test_action_keeps_the_selection_until_playback_ends() -> void:
	var ui := _busy_state()
	ui.clear_after_action()
	assert_eq(ui.selected_id, 3, "再生の前に選択を外した（再生のあとに決める）")
	assert_eq(ui.inspected_id, 0)
	assert_eq(ui.inspected_cell, BattleUiState.NO_CELL)
	assert_eq(ui.mode, Mode.NONE)
	assert_false(ui.confirming_end or ui.confirming_ult)


func test_selection_after_action() -> void:
	var ui := BattleUiState.new()
	ui.select(3)
	ui.settle_after_action(true, 4, 3, true)
	assert_eq(ui.selected_id, 0, "CPU の番なのに、選んだままにした")
	ui.select(3)
	ui.settle_after_action(false, 4, 3, false)
	assert_eq(ui.selected_id, 4, "進化先を選ぶ駒を見せない")
	ui.settle_after_action(false, 0, 6, false)
	assert_eq(ui.selected_id, 6, "動いたあとの駒を選ばない")
	ui.settle_after_action(false, 0, 0, true)
	assert_eq(ui.selected_id, 6, "取り消し・必殺技のあとに、選んでいた駒を外した")
	ui.settle_after_action(false, 0, 0, false)
	assert_eq(ui.selected_id, 0, "行動を終えた駒を選んだままにした")


func test_select_reports_a_change_and_clears_the_rest() -> void:
	var ui := _busy_state()
	assert_false(ui.select(3), "同じ駒を選び直したのに、変わったとした")
	assert_eq(ui.inspected_id, 0)
	assert_eq(ui.mode, Mode.NONE)
	assert_false(ui.confirming_end or ui.confirming_ult)
	assert_true(ui.select(0))


func test_inspecting_keeps_the_selection_and_the_mode() -> void:
	var ui := BattleUiState.new()
	ui.select(3)
	ui.mode = Mode.SKILL
	ui.confirming_end = true
	ui.inspect(5)
	assert_eq(ui.selected_id, 3, "見ると、選択が外れた")
	assert_eq(ui.mode, Mode.SKILL, "見ると、対象を選ぶ途中をやめた")
	assert_false(ui.confirming_end, "見ても、ターン終了の確かめをやめない")


func test_back_steps_one_thing_at_a_time() -> void:
	var ui := _busy_state()
	assert_eq(ui.back(true), Back.DONE)
	assert_false(ui.confirming_ult, "まず必殺技の確かめをやめる")
	assert_eq(ui.inspected_id, 5)
	assert_eq(ui.back(true), Back.DONE)
	assert_eq(ui.inspected_id, 0, "次に、見るのをやめる")
	assert_eq(ui.mode, Mode.ATTACK)
	assert_eq(ui.back(true), Back.DONE)
	assert_eq(ui.mode, Mode.NONE, "次に、対象を選ぶのをやめる")
	assert_eq(ui.back(true), Back.UNDO_MOVE, "動いたあとなら、移動を取り消す")
	assert_eq(ui.back(false), Back.DESELECT)
	ui.select(0)
	assert_eq(ui.back(false), Back.NOTHING, "戻すものが無いのに、戻した")
	ui.inspected_cell = Vector2i(1, 1)
	assert_eq(ui.back(false), Back.DESELECT, "マスの情報を消さない")


func test_reconcile_drops_what_the_board_no_longer_allows() -> void:
	var ui := BattleUiState.new()
	ui.select(3)
	ui.inspect(3)
	ui.inspected_cell = Vector2i(1, 1)
	ui.mode = Mode.HEAL
	ui.confirming_ult = true
	ui.reconcile(true, true, true, false, false, false, true, false, true)
	assert_false(ui.confirming_ult, "必殺技を使えないのに、確かめたままにした")
	assert_eq(ui.mode, Mode.NONE, "回復の相手がいないのに、相手を選ぶ途中のままにした")
	assert_eq(ui.inspected_id, 0, "選んでいる駒を、見ている駒として残した")
	assert_eq(ui.inspected_cell, BattleUiState.NO_CELL, "駒を選んでいるのに、マスの情報を残した")

	ui.mode = Mode.SKILL
	ui.inspect(5)
	ui.confirming_ult = true
	ui.reconcile(true, true, true, false, false, true, false, false, true)
	assert_eq(ui.mode, Mode.SKILL, "スキルの対象があるのに、選ぶ途中をやめた")
	assert_eq(ui.inspected_id, 5, "見ている駒がいるのに、見るのをやめた")
	assert_true(ui.confirming_ult)

	ui.cpu_running = true
	ui.reconcile(false, false, true, false, true, true, true, true, true)
	assert_false(ui.confirming_ult, "CPU の番に、必殺技の確かめを残した")
	assert_eq(ui.selected_id, 0, "いなくなった駒を選んだままにした")
	assert_eq(ui.mode, Mode.NONE)

	ui.cpu_running = false
	ui.inspect(5)
	ui.reconcile(false, false, true, true, false, true, true, true, true)
	assert_eq(ui.inspected_id, 0, "決着したのに、見たままにした")


func test_press_becomes_a_click_or_a_drag() -> void:
	var ui := BattleUiState.new()
	assert_false(ui.release(), "押していないのに、クリックになった")
	ui.press(Vector2(100, 100), false)
	assert_false(ui.drag(Vector2(100 + BattleUiState.DRAG_THRESHOLD, 100)), "少し動いただけで、ドラッグになった")
	assert_true(ui.release(), "動かさずに離したのに、クリックにならない")
	ui.press(Vector2(100, 100), false)
	assert_true(ui.drag(Vector2(130, 100)))
	assert_true(ui.drag(Vector2(100, 100)), "戻ってきても、ドラッグのまま")
	assert_false(ui.release(), "ドラッグのあとに、クリックになった")
	ui.press(Vector2(100, 100), true)
	assert_false(ui.drag(Vector2(300, 100)), "駒の上で押したのに、視点が動いた")
	assert_true(ui.release(), "駒の上で押したら、いつもクリック")
	ui.press(Vector2(100, 100), false)
	ui.cancel_press()
	assert_false(ui.release(), "やめたのに、クリックになった")


func test_a_quick_second_press_does_not_pass_the_confirmation() -> void:
	# 確かめに変わった直後の 2 回目（ダブルクリック・キーの連打）は受けない。間を置けば受ける。
	var ui := BattleUiState.new()
	ui.start_confirming_end(1000)
	assert_true(ui.confirming_end)
	assert_true(ui.confirm_guarded(1000), "1 回目と同時の 2 回目を受けた")
	assert_true(ui.confirm_guarded(1000 + BattleUiState.CONFIRM_GUARD_MSEC - 1), "直後の 2 回目を受けた")
	assert_false(ui.confirm_guarded(1000 + BattleUiState.CONFIRM_GUARD_MSEC), "間を置いても、2 回目を受けない")
	ui.start_confirming_ult(5000)
	assert_true(ui.confirming_ult and ui.confirm_guarded(5100), "必殺技の確かめの直後の 2 回目を受けた")
	assert_true(BattleUiState.CONFIRM_GUARD_MSEC >= 300 and BattleUiState.CONFIRM_GUARD_MSEC <= 500, "受けない間は 0.3〜0.5 秒")
