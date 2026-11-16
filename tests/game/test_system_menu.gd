extends "res://tests/base_test.gd"
## システムメニュー（game/system_menu.gd）。

const SystemMenu := preload("res://game/system_menu.gd")
const Settings := preload("res://game/settings.gd")
const OverlayStack := preload("res://game/overlay_stack.gd")


func _menu() -> SystemMenu:
	var menu := SystemMenu.new()
	menu.setup(Settings.new(), OverlayStack.new())
	return menu


func _items() -> Array:
	return [[SystemMenu.ITEM_RESUME, "戻る", ""], [SystemMenu.ITEM_SETTINGS, "設定", ""]]


## 設定の画面を開いたままウィンドウを閉じても、変えた設定を取っておく（取っておく合図を出す）。
func test_closing_the_window_on_the_settings_keeps_them() -> void:
	var menu := _menu()
	var saved := [0]
	menu.settings_closed.connect(func() -> void: saved[0] += 1)
	menu.open(_items(), true)
	menu.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	assert_eq(saved[0], 1, "設定の画面を開いたまま閉じると、取っておかない")
	menu.free()


func test_closing_the_window_elsewhere_saves_nothing() -> void:
	var menu := _menu()
	var saved := [0]
	menu.settings_closed.connect(func() -> void: saved[0] += 1)
	menu.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	menu.open(_items())
	menu.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	assert_eq(saved[0], 0, "設定の画面を開いていないのに、取っておく合図を出した")
	menu.free()
