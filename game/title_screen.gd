extends Node
## タイトルの場面。飾らない最小の形: 題名と、始める・部隊の編成・設定・終える。背景は対戦と同じ景色（backdrop.gd）。
## 場面の決まりは scene_flow.gd。

const AppContext := preload("res://game/app_context.gd")
const Backdrop := preload("res://game/backdrop.gd")

## 「始める」で &"start"、「部隊の編成」で &"decks"。
signal finished(outcome: StringName)

const COLOR_PANEL := Color(0.07, 0.09, 0.12, 0.82)
const COLOR_TEXT_DIM := Color(0.85, 0.88, 0.92)

var context: AppContext
var _buttons := {}


func _ready() -> void:
	add_child(Backdrop.new())
	var layer := CanvasLayer.new()
	add_child(layer)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL
	style.set_corner_radius_all(8)
	style.set_content_margin_all(28.0)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)

	var title := _label("PROJECT LEGION", 46)
	column.add_child(title)
	var subtitle := _label("プロジェクト・レギオン", 20)
	subtitle.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	column.add_child(subtitle)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0.0, 10.0)
	column.add_child(gap)
	_add_button(column, &"start", "始める", press_start)
	(_buttons[&"start"] as Button).set_meta(&"sound", &"ui_confirm")  # 決める音（sound.gd）
	_add_button(column, &"decks", "部隊の編成", press_decks)
	_add_button(column, &"settings", "設定", press_settings)
	_add_button(column, &"quit", "終える", press_quit)


## 「始める」: 対戦の設定へ。
func press_start() -> void:
	finished.emit(&"start")


## 「部隊の編成」: 取っておく部隊を組む。
func press_decks() -> void:
	finished.emit(&"decks")


## 「設定」: 設定の画面だけを開く（システムメニューと同じ画面）。
func press_settings() -> void:
	context.open_settings()


func press_quit() -> void:
	context.quit()


## Esc は、戻すものが無いので、システムメニューを開く（ほかの場面と同じ）。
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		context.open_menu()


func _add_button(column: VBoxContainer, id: StringName, text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 22)
	button.custom_minimum_size = Vector2(320.0, 56.0)
	button.pressed.connect(action)
	column.add_child(button)
	_buttons[id] = button


func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	return label
