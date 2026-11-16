extends Node
## 窓の扱い（docs/screen-size.md の「窓と全画面」）。設定の「全画面」を窓に効かせ、Alt+Enter で切り替え、窓の最小の大きさを決める。
## アプリ（app.gd）が 1 つ持つ。検査とスクリーンショットの道具では、窓に触らない（決めた大きさで回すため）。

const Settings := preload("res://game/settings.gd")

## 窓をこれより小さくできない（16:9。これより小さいと、文字が読めないほど小さくなる）。
const MIN_WINDOW_SIZE := Vector2i(960, 540)

## 全画面を Alt+Enter で切り替えた（設定を取っておく合図）。
signal toggled

var _settings: Settings
var _touch_window := true


## settings の「全画面」を窓に効かせる。touch_window が偽なら、窓に触らない（検査とスクリーンショット）。
func setup(settings: Settings, touch_window: bool) -> void:
	_settings = settings
	_touch_window = touch_window
	if _touch_window:
		get_window().min_size = MIN_WINDOW_SIZE
	settings.changed.connect(func(key: StringName) -> void:
		if key == Settings.FULLSCREEN:
			apply())
	apply()


## 設定の値に、窓を合わせる。
func apply() -> void:
	if not _touch_window or DisplayServer.get_name() == "headless":
		return
	var window := get_window()
	var fullscreen: bool = _settings.value(Settings.FULLSCREEN)
	var now_fullscreen := window.mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]
	if fullscreen and not now_fullscreen:
		window.mode = Window.MODE_FULLSCREEN
	elif not fullscreen and now_fullscreen:
		window.mode = Window.MODE_WINDOWED


## Alt+Enter で、全画面と窓を切り替える。ほかの何よりも先に受ける（app.gd がこのノードを子の最後に置く）。
func _input(event: InputEvent) -> void:
	if _settings != null and is_toggle_key(event):
		get_viewport().set_input_as_handled()
		_settings.set_value(Settings.FULLSCREEN, not _settings.value(Settings.FULLSCREEN))
		toggled.emit()


## 全画面を切り替えるキー（Alt+Enter。テンキーの Enter も）。
static func is_toggle_key(event: InputEvent) -> bool:
	var key := event as InputEventKey
	return key != null and key.pressed and not key.echo and key.alt_pressed \
		and key.keycode in [KEY_ENTER, KEY_KP_ENTER]
