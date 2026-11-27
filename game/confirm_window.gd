extends "res://game/window_base.gd"
## 確かめの窓（窓の部品。docs/ui-theme.md の「窓」）。取り返しのつかないこと（削除、上書き）の前に挟む。
## 画面の全体を幕で沈め、真ん中に板を出す: 1 行目（何をするか）が窓の見出し、その下に危険の色の飾りの線、
## 失われるものの文（注意の色）、「キャンセル」と、するボタン（危険の色）。
## 右クリック・Esc は「キャンセル」。殻（幕・板・積み上げ・右クリックと Esc）は窓の土台（window_base.gd）が持つ。
##
##   var window := ConfirmWindow.new()
##   window.overlays = context.overlays
##   layer.add_child(window)
##   window.ask("データ 1 を削除しますか？", "削除したデータは元に戻せません。", "削除", func() -> void: ...)

const Text := preload("res://game/text.gd")

## 板の中の幅（px）。
const WIDTH := 440.0

## 重なる画面の積み上げ（無くてもよい。開く前に渡す）。
var overlays: RefCounted:
	set(value):
		_overlays = value
	get:
		return _overlays

var _title: Label
var _note: Label
var _ok: Button
var _action: Callable


func _init() -> void:
	var panel := build_window(null, "confirm.window")
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(WIDTH, 0.0)
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	_title = Label.new()
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTheme.style_window_title(_title, 20)
	column.add_child(_title)
	column.add_child(UiTheme.window_rule(Palette.DANGER))
	_note = Label.new()
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.add_theme_font_size_override("font_size", 16)
	_note.add_theme_color_override("font_color", Palette.WARN)
	column.add_child(_note)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	column.add_child(buttons)
	var keep := _button(Text.t("menu.confirm.cancel"))
	keep.set_meta(&"sound", &"ui_back")
	keep.pressed.connect(cancel)
	buttons.add_child(keep)
	_ok = _button("")
	_ok.theme_type_variation = UiTheme.BUTTON_DANGER
	_ok.pressed.connect(accept)
	buttons.add_child(_ok)


## 確かめる。title は何をするか、note は失われるもの（空なら出さない）、ok_label はするボタンの文字。
## 「するボタン」を押したら action を呼ぶ。
func ask(title: String, note: String, ok_label: String, action: Callable) -> void:
	_title.text = title
	_note.text = note
	_note.visible = note != ""
	_ok.text = ok_label
	_action = action
	visible = true


func is_open() -> bool:
	return visible


## 見出しと失われるものの文（検査用）。
func question() -> String:
	return "%s\n%s" % [_title.text, _note.text] if _note.visible else _title.text


## 「するボタン」の文字（検査用）。
func ok_text() -> String:
	return _ok.text


## するボタン: 閉じてから action を呼ぶ。
func accept() -> void:
	if not visible:
		return
	var action := _action
	close()
	if action.is_valid():
		action.call()


## 「キャンセル」: 何もせずに閉じる。
func cancel() -> void:
	close()


func close() -> void:
	visible = false
	_action = Callable()


func _on_back() -> void:
	cancel()


func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 18)
	button.custom_minimum_size = Vector2(180.0, 48.0)
	return button
