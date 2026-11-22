extends CanvasLayer
## 保存の小さな印（docs/save-slots.md の「保存する所」）。オートセーブで書いたとき、画面の右下に「オートセーブ完了」を少しの間だけ出す。
## アプリ（app.gd）が 1 つ持つ。入力は受けない（クリックを通す）。

const Text := preload("res://game/text.gd")
const UiTheme := preload("res://game/ui_theme.gd")
const Palette := preload("res://game/ui_palette.gd")

## 出している長さと、消えるまでの長さ（秒）。
const SHOW_TIME := 1.6
const FADE_TIME := 0.4
const LAYER := 28
const MARGIN := 18.0

var _tag: PanelContainer
var _label: Label
var _tween: Tween
## 出した回数（検査用）。
var shown_count := 0


func _ready() -> void:
	layer = LAYER
	_tag = PanelContainer.new()
	_tag.theme_type_variation = UiTheme.PANEL_TAG
	_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tag.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_tag.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_tag.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_tag.offset_right = -MARGIN
	_tag.offset_bottom = -MARGIN
	_tag.modulate.a = 0.0
	add_child(_tag)
	_label = Label.new()
	_label.text = Text.t("menu.saved")
	_label.add_theme_font_size_override("font_size", 15)
	_label.add_theme_color_override("font_color", Palette.ACCENT)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tag.add_child(_label)


## 印を出す（出ていれば、出し直す）。
func flash() -> void:
	shown_count += 1
	if _tween != null:
		_tween.kill()
	_tag.modulate.a = 1.0
	_tween = create_tween()
	_tween.set_ignore_time_scale(true)
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_interval(SHOW_TIME)
	_tween.tween_property(_tag, "modulate:a", 0.0, FADE_TIME)


## 印が出ているか（検査用）。
func is_showing() -> bool:
	return _tag.modulate.a > 0.0
