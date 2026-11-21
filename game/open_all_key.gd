extends CanvasLayer
## 確かめ用の解放（docs/story.md の「確かめ用の解放」）。F5 で、ストーリーの全部の話と解放を開く・元に戻す。
## 動作の確かめで、クリアの記録を進めずに先の話を遊ぶためのもの。画面には入口を出さない（対戦の F1〜F4 と同じく、鍵だけ）。
## 記録には書かない（Story.open_all。その起動のあいだだけ）。開いている間は、画面の左下の隅に小さく出す。
## アプリ（app.gd）が 1 つ持つ。物語選択・話の一覧・タイトルにいるときに押したら、その場面を作り直して、カードに効かせる。

const Text := preload("res://game/text.gd")
const Palette := preload("res://game/ui_palette.gd")
const SceneFlow := preload("res://game/scene_flow.gd")

## 押したときに作り直す場面（流れの外で、話の並びを見せるもの）。
const REFRESHED: Array[StringName] = [SceneFlow.TITLE, SceneFlow.CAMPAIGNS, SceneFlow.EPISODES]
## 幕（app.gd の FADE_LAYER = 30）の下、システムメニュー（20）の上。
const LAYER := 25

var _app: Node
var _mark: Label


func setup(app: Node) -> void:
	_app = app
	layer = LAYER
	_mark = Label.new()
	_mark.text = Text.t("story.open_all.mark")
	_mark.add_theme_font_size_override("font_size", 14)
	_mark.add_theme_color_override("font_color", Palette.WARN)
	_mark.add_theme_constant_override("outline_size", 4)
	_mark.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_mark.offset_left = 8.0
	_mark.offset_top = -24.0
	_mark.offset_bottom = -4.0
	_mark.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_mark)
	_refresh_mark()


## 開く・元に戻す。
func toggle() -> void:
	var story: RefCounted = _app.context.story
	story.open_all = not story.open_all
	_refresh_mark()
	_app.context.play_sound(&"ui_confirm" if story.open_all else &"ui_back")
	if REFRESHED.has(_app.current_id()):
		_app.go(_app.current_id())


## 隅の印を出しているか（検査用）。
func is_marked() -> bool:
	return _mark.visible


func _refresh_mark() -> void:
	_mark.visible = _app.context.story.open_all


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F5:
		get_viewport().set_input_as_handled()
		toggle()
