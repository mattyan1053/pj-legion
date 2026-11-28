extends RefCounted
## 一覧の画面（物語選択・話の一覧・マップ選択・セーブデータ選択）の、キーとマウスの受け方の土台（docs/ui-theme.md の「一覧の画面」）。
## ノードに依存しない。画面は 1 つ持ち、_input と _unhandled_input から渡すだけ。カードの見た目と、選んだあとのことは画面の側。
##
## - 右クリック・Esc: 戻る（back）。
## - 左右の矢印: 選べるカードを順に選ぶ（端で止まる。card_keys.gd の next）。Enter: 選んでいるカードで決める。
## - 1〜9 のキー（テンキーでも）: その番号のカードで決める（選べるカードだけ。number_keys が偽なら受けない）。
## - マウスを本当に動かしたら、キーでの選びをやめる（pointer_moved。既定は選ぶのをやめる）。
## - 重なる画面（overlay_stack.gd）が開いている間は、何も受けない。
##
##   _picker = CardPicker.new(context.overlays, context.play_sound)
##   _picker.count = func() -> int: return cards.size()
##   _picker.enabled = func(i: int) -> bool: return ...
##   _picker.selected = select_by_key     # (i) -> void。-1 で選ぶのをやめる。見た目を替え、index を覚えるのは画面の側
##   _picker.chosen = func(i: int) -> void: choose(...)
##   _picker.back = press_back
##   func _input(event): _picker.input(event, get_viewport())
##   func _unhandled_input(event): _picker.unhandled_input(event, get_viewport())

const CardKeys := preload("res://game/card_keys.gd")

## カードの数。() -> int。
var count: Callable
## index のカードを選べるか。(index) -> bool。無ければ、どれも選べる。
var enabled: Callable
## 何も選んでいないときに、矢印で選び始める所。() -> int。無ければ 0。
var start: Callable
## いま選んでいるカード（無ければ -1）。() -> int。
var current: Callable
## カードを選んだ（見た目を替える）。(index) -> void。-1 で選ぶのをやめる。
var selected: Callable
## カードで決めた。(index) -> void。
var chosen: Callable
## 戻る。() -> void。
var back: Callable
## マウスを本当に動かした（event は InputEventMouseMotion）。(event) -> void。無ければ、選んでいるときだけ選ぶのをやめる。
var pointer_moved: Callable
## 1〜9 のキーで決めるか。
var number_keys := true

var _overlays: RefCounted
var _play_sound: Callable


## overlays は重なる画面の積み上げ（AppContext.overlays）、play_sound は音を鳴らす入口（名前を受ける）。
func _init(overlays: RefCounted, play_sound: Callable) -> void:
	_overlays = overlays
	_play_sound = play_sound


## 画面の _input から渡す: 戻る操作と、マウスへの持ち替え。
func input(event: InputEvent, viewport: Viewport) -> void:
	if _overlays.is_open():
		return
	if CardKeys.is_pointer_move(event):
		if pointer_moved.is_valid():
			pointer_moved.call(event)
		elif current.call() >= 0:
			selected.call(-1)  # マウスに持ち替えた（キーで送ってカードがマウスの下へ来ただけでは、やめない）
	if CardKeys.is_back(event):
		viewport.set_input_as_handled()
		_play_sound.call(&"ui_back")
		back.call()


## 画面の _unhandled_input から渡す: 矢印・Enter・数字キー。
func unhandled_input(event: InputEvent, viewport: Viewport) -> void:
	if _overlays.is_open():
		return
	var total: int = count.call()
	var step := CardKeys.direction(event)
	if step != 0:
		viewport.set_input_as_handled()
		var from: int = start.call() if start.is_valid() else 0
		var index := CardKeys.next(current.call(), step, total, _is_enabled, from)
		if index >= 0:
			selected.call(index)
		return
	var index_now: int = current.call()
	if CardKeys.is_accept(event) and index_now >= 0:
		viewport.set_input_as_handled()
		_play_sound.call(&"ui_confirm")
		chosen.call(index_now)
		return
	if not number_keys or not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key := (event as InputEventKey).physical_keycode
	var number := -1
	if key >= KEY_1 and key <= KEY_9:
		number = key - KEY_1
	elif key >= KEY_KP_1 and key <= KEY_KP_9:
		number = key - KEY_KP_1
	if number >= 0 and number < total and _is_enabled(number):
		_play_sound.call(&"ui_confirm")
		chosen.call(number)


func _is_enabled(index: int) -> bool:
	return enabled.call(index) if enabled.is_valid() else true


## キーで選んだカード card を、マウスを乗せたときと同じ見た目にする（lit が偽なら戻す）。
static func light(card: Button, lit: bool) -> void:
	if lit:
		card.add_theme_stylebox_override("normal", card.get_theme_stylebox("hover"))
	else:
		card.remove_theme_stylebox_override("normal")
