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
const Taper := preload("res://game/ui_taper.gd")
const TITLE_GOLD := preload("res://game/title_gold.gdshader")

## 「対戦」で &"start"、「ストーリー」で &"story"（話の一覧へ）。
signal finished(outcome: StringName)

## 題字（ロゴ）: 主の語の大きさと字の間、上の小さな語の大きさと字の間、ロゴの幅（上の語を挟む線と、下の飾りの線の端）。
const TITLE_SIZE := 116
const TITLE_SPACING := 12
const TOP_SIZE := 26
const TOP_SPACING := 16
const LOGO_WIDTH := 560.0
## 入ったときの動きの長さ（題字が浮かぶまで）と、メニューが 1 つずつ現れる間隔（秒）。
const ENTER_TIME := 0.5
const ENTER_STEP := 0.05

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
	column.add_theme_constant_override("separation", 4)
	center.add_child(column)

	# 題字（ロゴ）: 景色（裂けた空）の上に直に置く。小さく字の間を広げた上の語を左右の線で挟み、その下に大きな金の主の語、飾りの線。
	var top_row := HBoxContainer.new()
	top_row.alignment = BoxContainer.ALIGNMENT_CENTER
	top_row.add_theme_constant_override("separation", 18)
	top_row.custom_minimum_size = Vector2(LOGO_WIDTH, 0.0)
	top_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(top_row)
	top_row.add_child(Taper.new(false, Palette.BORDER_BRIGHT, 60.0))
	var top := _label(Text.t("title.logo.top"), TOP_SIZE)
	top.theme_type_variation = UiTheme.LABEL_HEADING
	top.add_theme_font_override("font", _spaced(TOP_SPACING))
	top.add_theme_font_size_override("font_size", TOP_SIZE)
	top.add_theme_color_override("font_color", Palette.TEXT)
	top.add_theme_constant_override("outline_size", 8)
	top_row.add_child(top)
	top_row.add_child(Taper.new(true, Palette.BORDER_BRIGHT, 60.0))
	var title := _label(Text.t("title.logo.main"), TITLE_SIZE)
	title.theme_type_variation = UiTheme.LABEL_TITLE
	title.add_theme_font_override("font", _spaced(TITLE_SPACING))
	title.add_theme_color_override("font_color", Color.WHITE)  # 金は、字の上から下への移ろい（title_gold.gdshader）で付ける
	title.add_theme_constant_override("outline_size", 14)
	title.add_theme_constant_override("shadow_offset_y", 6)
	title.add_theme_constant_override("line_spacing", 0)
	var gold := ShaderMaterial.new()
	gold.shader = TITLE_GOLD
	gold.set_shader_parameter(&"top", Palette.ACCENT.lightened(0.45))
	gold.set_shader_parameter(&"bottom", Palette.GOLD.darkened(0.12))
	title.material = gold
	title.resized.connect(func() -> void: gold.set_shader_parameter(&"height", maxf(title.size.y, 1.0)))
	column.add_child(title)
	var ornament := Ornament.new(LOGO_WIDTH, 18.0)
	ornament.color = Palette.ACCENT
	ornament.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(ornament)
	var gap := Control.new()  # 題字とメニューの間
	gap.custom_minimum_size = Vector2(0.0, 44.0)
	column.add_child(gap)
	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 12)
	column.add_child(menu)
	_add_button(menu, &"story", story_label(), press_story)
	(_buttons[&"story"] as Button).set_meta(&"sound", &"ui_confirm")  # 決める音（sound.gd）
	_add_button(menu, &"start", Text.t("title.button.versus"), press_start)
	(_buttons[&"start"] as Button).set_meta(&"sound", &"ui_confirm")
	_add_button(menu, &"settings", Text.t("title.button.options"), press_settings)
	_add_button(menu, &"quit", Text.t("title.button.quit"), press_quit)
	_enter([top_row, title], ornament)


## 入ったときの短い動き: 題字が浮かび、飾りの線が左右へ伸び、メニューが上から順に現れる。入力は止めない（すぐ押せる）。
## 幕が明けるのと重ねて動き出す（アプリは幕が明けきるまで場面を止めておくが、この動きだけは止めない。明けてから動き出すと、空だけの間ができる）。
func _enter(heading: Array, ornament: Ornament) -> void:
	var tween := create_tween().set_parallel()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	for node: Control in heading:
		node.modulate.a = 0.0
		tween.tween_property(node, "modulate:a", 1.0, ENTER_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	ornament.grow = 0.0
	tween.tween_property(ornament, "grow", 1.0, ENTER_TIME * 1.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var order := 0
	for id: StringName in _buttons:
		var button := _buttons[id] as Button
		button.modulate.a = 0.0
		tween.tween_property(button, "modulate:a", 1.0, ENTER_TIME * 0.5).set_delay(ENTER_TIME * 0.2 + ENTER_STEP * order)
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


## 「終了」: ウィンドウの × と同じく、確かめてから終える。
func press_quit() -> void:
	context.ask_quit()


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


## 明朝の字の間を空けたもの。
func _spaced(spacing: int) -> FontVariation:
	var spaced := FontVariation.new()
	spaced.base_font = UiTheme.FONT_HEADING
	spaced.spacing_glyph = spacing
	return spaced


## 題字に出している語（上の語、主の語。検査用）。
func logo_texts() -> Array[String]:
	return [Text.t("title.logo.top"), Text.t("title.logo.main")]


func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", 6)
	return label
