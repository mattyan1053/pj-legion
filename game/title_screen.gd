extends Node
## タイトルの場面。飾らない最小の形: 題名と、対戦・ストーリー・部隊の編成・設定・終える。背景は対戦と同じ景色（backdrop.gd）。
## 場面の決まりは scene_flow.gd。

const Palette := preload("res://game/ui_palette.gd")
const UiTheme := preload("res://game/ui_theme.gd")
const AppContext := preload("res://game/app_context.gd")
const Backdrop := preload("res://game/backdrop.gd")

## 「対戦」で &"start"、「ストーリー」で &"story"（話の一覧へ）、「部隊の編成」で &"decks"。
signal finished(outcome: StringName)

const COLOR_PANEL := Palette.OVERLAY
const COLOR_TEXT_DIM := Palette.TEXT_DIM

var context: AppContext
var _buttons := {}


func _ready() -> void:
	add_child(Backdrop.new())
	var layer := CanvasLayer.new()
	add_child(layer)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(UiTheme.vignette())
	layer.add_child(center)
	var style := UiTheme.box(COLOR_PANEL, Palette.BORDER, 2, 12, 28.0, 12)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)

	var title := _label("PROJECT LEGION", 46)
	title.theme_type_variation = UiTheme.LABEL_TITLE
	title.remove_theme_constant_override("outline_size")
	column.add_child(title)
	var subtitle := _label("プロジェクト・レギオン", 20)
	subtitle.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	column.add_child(subtitle)
	var gap := HSeparator.new()  # 題字とメニューを分ける線
	gap.custom_minimum_size = Vector2(0.0, 10.0)
	column.add_child(gap)
	_add_button(column, &"start", "対戦", press_start)
	(_buttons[&"start"] as Button).set_meta(&"sound", &"ui_confirm")  # 決める音（sound.gd）
	_add_button(column, &"story", story_label(), press_story)
	(_buttons[&"story"] as Button).set_meta(&"sound", &"ui_confirm")
	_add_button(column, &"decks", "部隊の編成", press_decks)
	_add_button(column, &"settings", "設定", press_settings)
	_add_button(column, &"quit", "終える", press_quit)


## 「対戦」: ステージ選択へ（そのあと対戦の設定）。
func press_start() -> void:
	finished.emit(&"start")


## 「ストーリー」: 話の一覧へ。
func press_story() -> void:
	finished.emit(&"story")


## 「ストーリー」のボタンの文字。全部の話をクリアしていたら、済みの印を付ける。
func story_label() -> String:
	return "ストーリー（クリア済み）" if context.story.all_cleared() else "ストーリー"


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
	label.add_theme_constant_override("outline_size", 6)
	return label
