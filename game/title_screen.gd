extends Node
## タイトルの場面。題名と、ストーリー・対戦・オプション・終了。背景は、裂けた空の下の結晶の森（title_backdrop.gd）。
## 題字とメニューは、板に載せずに景色の上へ直に置く。
## 部隊編成は、各モードに入ったところから開く（対戦設定の「部隊編成」、出撃準備の「部隊編成」）。
## 場面の決まりは scene_flow.gd。

const Text := preload("res://game/text.gd")
const Palette := preload("res://game/ui_palette.gd")
const UiTheme := preload("res://game/ui_theme.gd")
const AppContext := preload("res://game/app_context.gd")
const Ornament := preload("res://game/ui_ornament.gd")
const TitleBackdrop := preload("res://game/title_backdrop.gd")

## 「対戦」で &"start"、「ストーリー」で &"story"（話の一覧へ）。
signal finished(outcome: StringName)

## 題字の大きさ。
const TITLE_SIZE := 68
## 入ったときの動きの長さ（題字が浮かぶまで）と、メニューが 1 つずつ現れる間隔（秒）。
const ENTER_TIME := 0.5
const ENTER_STEP := 0.07

var context: AppContext
var _buttons := {}


func _ready() -> void:
	add_child(TitleBackdrop.new())
	var layer := CanvasLayer.new()
	add_child(layer)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(UiTheme.vignette())
	layer.add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	center.add_child(column)

	# 題字: 景色（裂けた空）の上に直に置く。字の間を空け、下に飾りの線と読みを添える。
	var title := _label("PROJECT LEGION", TITLE_SIZE)
	title.theme_type_variation = UiTheme.LABEL_TITLE
	var spaced := FontVariation.new()
	spaced.base_font = UiTheme.FONT_HEADING
	spaced.spacing_glyph = 5
	title.add_theme_font_override("font", spaced)
	title.add_theme_constant_override("outline_size", 12)
	column.add_child(title)
	var ornament := Ornament.new(420.0, 16.0)
	column.add_child(ornament)
	var subtitle := _label(Text.t("title.subtitle"), 19)
	subtitle.add_theme_color_override("font_color", Palette.TEXT)
	column.add_child(subtitle)
	var gap := Control.new()  # 題字とメニューの間
	gap.custom_minimum_size = Vector2(0.0, 56.0)
	column.add_child(gap)
	_add_button(column, &"story", story_label(), press_story)
	(_buttons[&"story"] as Button).set_meta(&"sound", &"ui_confirm")  # 決める音（sound.gd）
	_add_button(column, &"start", Text.t("title.button.versus"), press_start)
	(_buttons[&"start"] as Button).set_meta(&"sound", &"ui_confirm")
	_add_button(column, &"settings", Text.t("title.button.options"), press_settings)
	_add_button(column, &"quit", Text.t("title.button.quit"), press_quit)
	_enter([title, subtitle], ornament)


## 入ったときの短い動き: 題字が浮かび、飾りの線が左右へ伸び、メニューが上から順に現れる。入力は止めない（すぐ押せる）。
func _enter(heading: Array, ornament: Ornament) -> void:
	var tween := create_tween().set_parallel()
	for node: Control in heading:
		node.modulate.a = 0.0
		tween.tween_property(node, "modulate:a", 1.0, ENTER_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	ornament.grow = 0.0
	tween.tween_property(ornament, "grow", 1.0, ENTER_TIME * 1.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var order := 0
	for id: StringName in _buttons:
		var button := _buttons[id] as Button
		button.modulate.a = 0.0
		tween.tween_property(button, "modulate:a", 1.0, ENTER_TIME * 0.7).set_delay(ENTER_TIME * 0.4 + ENTER_STEP * order)
		order += 1


## ボタンの文字の並び（上から。検査用）。
func button_texts() -> Array[String]:
	var texts: Array[String] = []
	for id: StringName in _buttons:
		texts.append((_buttons[id] as Button).text)
	return texts


## 「対戦」: マップ選択へ（そのあと対戦設定）。
func press_start() -> void:
	finished.emit(&"start")


## 「ストーリー」: 話の一覧へ。
func press_story() -> void:
	finished.emit(&"story")


## 「ストーリー」のボタンの文字。全部の話をクリアしていたら、済みの印を付ける。
func story_label() -> String:
	return Text.t("title.button.story_cleared") if context.story.all_cleared() else Text.t("title.button.story")


## 「オプション」: オプションの画面だけを開く（システムメニューと同じ画面）。
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
	button.theme_type_variation = UiTheme.BUTTON_MENU
	button.custom_minimum_size = Vector2(320.0, 52.0)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
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
