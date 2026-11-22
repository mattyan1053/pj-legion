extends "res://tests/base_test.gd"
## 横に並ぶカードをキーボードで選ぶ決まりと、1 つ戻る操作（game/card_keys.gd）。

const CardKeys := preload("res://game/card_keys.gd")


func _key(code: Key, pressed := true) -> InputEventKey:
	var key := InputEventKey.new()
	key.physical_keycode = code
	key.pressed = pressed
	return key


func test_left_and_right_arrows_give_a_direction() -> void:
	assert_eq(CardKeys.direction(_key(KEY_LEFT)), -1)
	assert_eq(CardKeys.direction(_key(KEY_RIGHT)), 1)
	assert_eq(CardKeys.direction(_key(KEY_RIGHT, false)), 0, "離したときは動かない")
	assert_eq(CardKeys.direction(_key(KEY_1)), 0)
	assert_true(CardKeys.is_accept(_key(KEY_ENTER)))
	assert_true(CardKeys.is_accept(_key(KEY_KP_ENTER)))
	assert_false(CardKeys.is_accept(_key(KEY_SPACE)))


func test_the_first_press_picks_the_start_card_and_skips_locked_ones() -> void:
	var open := func(i: int) -> bool: return i != 2 and i != 3
	assert_eq(CardKeys.next(-1, 1, 5, open, 1), 1, "まだ選んでいなければ、始めのカードを選ぶ")
	assert_eq(CardKeys.next(-1, 1, 5, open, 2), 4, "始めのカードが選べなければ、押した向きの先")
	assert_eq(CardKeys.next(-1, 1, 4, open, 3), 1, "押した向きに無ければ、反対の向き")
	assert_eq(CardKeys.next(1, 1, 5, open), 4, "選べないカードは飛ばす")
	assert_eq(CardKeys.next(4, 1, 5, open), 4, "端では止まる")
	assert_eq(CardKeys.next(0, -1, 5, open), 0)
	assert_eq(CardKeys.next(-1, 1, 3, func(_i: int) -> bool: return false), -1, "選べるカードが無ければ選ばない")


func test_reaches_cards_beyond_the_ninth() -> void:
	var index := -1
	for i in 12:
		index = CardKeys.next(index, 1, 12, func(_i: int) -> bool: return true)
	assert_eq(index, 11, "数字キーの届かない 10 枚目より先も選べる")


func test_only_a_real_pointer_move_counts_as_switching_to_the_mouse() -> void:
	var still := InputEventMouseMotion.new()
	assert_false(CardKeys.is_pointer_move(still), "動いていない（カードが下へ来ただけ）")
	var moved := InputEventMouseMotion.new()
	moved.relative = Vector2(3, 0)
	assert_true(CardKeys.is_pointer_move(moved))
	assert_false(CardKeys.is_pointer_move(_key(KEY_LEFT)))


## 1 つ戻る操作は、右クリックを押したときと Esc を押したとき（どの画面・窓も同じ決まり）。
func test_right_click_and_escape_go_back() -> void:
	var click := func(button: MouseButton, pressed: bool) -> InputEventMouseButton:
		var event := InputEventMouseButton.new()
		event.button_index = button
		event.pressed = pressed
		return event
	assert_true(CardKeys.is_back(click.call(MOUSE_BUTTON_RIGHT, true)))
	assert_false(CardKeys.is_back(click.call(MOUSE_BUTTON_RIGHT, false)), "離したときは戻らない")
	assert_false(CardKeys.is_back(click.call(MOUSE_BUTTON_LEFT, true)))
	assert_true(CardKeys.is_back(_key(KEY_ESCAPE)))
	assert_false(CardKeys.is_back(_key(KEY_ESCAPE, false)))
	var held := _key(KEY_ESCAPE)
	held.echo = true
	assert_false(CardKeys.is_back(held), "押しっぱなしの繰り返しは数えない")
	assert_false(CardKeys.is_back(_key(KEY_ENTER)))
