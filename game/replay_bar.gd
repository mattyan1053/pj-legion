extends PanelContainer
## リプレイの帯（docs/battle-view.md の「リプレイ」）: 前のターン・止める / 再生・次のターン、速さ（等倍・2 倍・4 倍）、リザルトへ。
## 対戦の画面の下の帯のすぐ上、右に出す。大きさは決まっていて、中身（止めているか、速さ、押せるか）で変えない。
## ここはボタンを並べて、押されたことを signal で知らせるだけ（何をするかは対戦の画面。game/battle_screen/screen_replay.gd）。

const Text := preload("res://game/text.gd")
const Steady := preload("res://game/steady.gd")
const UiTheme := preload("res://game/ui_theme.gd")

## 前のターンへ（step = -1）、次のターンへ（step = 1）。
signal turn_pressed(step: int)
signal pause_pressed
signal speed_chosen(speed: int)
signal leave_pressed

## 帯の大きさ（px）と、選べる速さ。
const SIZE := Vector2(800.0, 60.0)
const SPEEDS: Array[int] = [1, 2, 4]
const SPEED_TEXTS := {1: "battle.replay.speed.1", 2: "battle.replay.speed.2", 4: "battle.replay.speed.4"}
const FONT := 17

var _prev: Button
var _next: Button
var _pause: Button
var _speeds: Array[Button] = []
var _leave: Button


func _ready() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP  # 帯の上のクリックを、後ろの盤へ通さない
	Steady.mark(self, "battle.replay_bar", Steady.RECT)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	_prev = _button(Text.t("battle.replay.prev"), 130.0)
	_prev.pressed.connect(func() -> void: turn_pressed.emit(-1))
	row.add_child(_prev)
	_pause = _button(Text.t("battle.replay.pause"), 100.0)
	_pause.theme_type_variation = UiTheme.BUTTON_PRIMARY
	_pause.pressed.connect(pause_pressed.emit)
	row.add_child(_pause)
	_next = _button(Text.t("battle.replay.next"), 130.0)
	_next.pressed.connect(func() -> void: turn_pressed.emit(1))
	row.add_child(_next)
	row.add_child(_gap())
	var group := ButtonGroup.new()
	for speed in SPEEDS:
		var button := _button(Text.t(SPEED_TEXTS[speed]), 66.0)
		button.toggle_mode = true
		button.button_group = group
		button.theme_type_variation = UiTheme.BUTTON_GHOST
		button.pressed.connect(func() -> void: speed_chosen.emit(speed))
		row.add_child(button)
		_speeds.append(button)
	row.add_child(_gap())
	_leave = _button(Text.t("battle.replay.leave"), 130.0)
	_leave.pressed.connect(leave_pressed.emit)
	row.add_child(_leave)
	show_state(false, 1, true, true)


func _button(text: String, width: float) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", FONT)
	button.custom_minimum_size = Vector2(width, 42.0)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return button


func _gap() -> Control:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(10.0, 0.0)
	return gap


## いまの状態を出す: 止めているか、速さ、前・次のターンへ飛べるか。
func show_state(paused: bool, speed: int, can_prev: bool, can_next: bool) -> void:
	_pause.text = Text.t("battle.replay.play") if paused else Text.t("battle.replay.pause")
	for i in SPEEDS.size():
		_speeds[i].set_pressed_no_signal(SPEEDS[i] == speed)
	_prev.disabled = not can_prev
	_next.disabled = not can_next


## 止める・再生のボタンの文字。検査用。
func pause_text() -> String:
	return _pause.text


## [前のターンへ飛べるか, 次のターンへ飛べるか]。検査用。
func turn_buttons() -> Array[bool]:
	return [not _prev.disabled, not _next.disabled]


## 選んでいる速さ。検査用。
func chosen_speed() -> int:
	for i in SPEEDS.size():
		if _speeds[i].button_pressed:
			return SPEEDS[i]
	return 0
