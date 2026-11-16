extends "res://tests/base_test.gd"
## 窓の扱い（game/window_mode.gd）と、設定の「全画面」。

const WindowMode := preload("res://game/window_mode.gd")
const Settings := preload("res://game/settings.gd")


func _key(keycode: Key, alt: bool, pressed := true, echo := false) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.alt_pressed = alt
	event.pressed = pressed
	event.echo = echo
	return event


func test_alt_enter_toggles_and_nothing_else_does() -> void:
	assert_true(WindowMode.is_toggle_key(_key(KEY_ENTER, true)))
	assert_true(WindowMode.is_toggle_key(_key(KEY_KP_ENTER, true)))
	assert_false(WindowMode.is_toggle_key(_key(KEY_ENTER, false)), "Alt の無い Enter")
	assert_false(WindowMode.is_toggle_key(_key(KEY_ENTER, true, false)), "離したとき")
	assert_false(WindowMode.is_toggle_key(_key(KEY_ENTER, true, true, true)), "押しっぱなしの繰り返し")
	assert_false(WindowMode.is_toggle_key(_key(KEY_SPACE, true)))
	assert_false(WindowMode.is_toggle_key(InputEventMouseButton.new()))


func test_fullscreen_is_a_screen_setting_that_starts_windowed() -> void:
	var entry := Settings.item(Settings.FULLSCREEN)
	assert_eq(entry.get("section"), "画面")
	assert_eq(entry.get("kind"), Settings.Kind.TOGGLE)
	assert_eq(Settings.new().value(Settings.FULLSCREEN), false, "初めは窓で開く")


func test_minimum_window_is_sixteen_by_nine() -> void:
	assert_eq(WindowMode.MIN_WINDOW_SIZE.x * 9, WindowMode.MIN_WINDOW_SIZE.y * 16)
