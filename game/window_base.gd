extends Control
## 窓の土台（docs/ui-theme.md の「窓」）。真ん中に板を出す重なる画面は、これを継ぐ。
## 持つもの:
## - 殻: 画面の全体を覆う幕（Palette.SHADE。後ろへ入力を通さない）、真ん中の入れ物、板（PANEL_SOLID か、渡した地）。
##   木の形は「子 0 が幕、子 1 が真ん中の入れ物、その子 0 が板」（検査が window_panel() で読む）。
## - 閉じ方: 右クリック・Esc は、いちばん上の重なる画面のときだけ受けて _on_back() を呼ぶ（既定は閉じる）。
##   幕のクリックで閉じるかは、窓ごとに選ぶ（outside_closes）。
## - 積み上げ: 見えている間だけ、重なる画面の積み上げ（overlay_stack.gd）に積む。開く・閉じるのどの道でも、見えなくなれば降ろし、
##   _on_hidden() を呼ぶ。木から抜けるときも降ろす。
## 中身（見出し・線・本文・ボタン）は、継ぐ側が板の中に組む。置き場所は真ん中で、大きさは size で決める（docs/ui-theme.md の「枠の大きさ」）。
##
##   extends "res://game/window_base.gd"
##   func setup(overlays: RefCounted) -> void:
##       var panel := build_window(overlays, "credits.window", SIZE, 0.5, true)
##       var column := VBoxContainer.new()
##       panel.add_child(column)
##
## システムメニュー（CanvasLayer）と部隊編成の中の窓は、殻だけを add_shell で作る。

const CardKeys := preload("res://game/card_keys.gd")
const UiTheme := preload("res://game/ui_theme.gd")
const Palette := preload("res://game/ui_palette.gd")
const Steady := preload("res://game/steady.gd")

## 開いている間、後ろの場面の時間を止めるか（overlay_stack.gd の pausing）。開く前に決める。
var pausing := false

## 開いている重なる画面の積み上げ（overlay_stack.gd。AppContext.overlays。無くてもよい）。
var _overlays: RefCounted
var _window_panel: PanelContainer
## 積み上げに積んでいるか（見えなくなったときに、一度だけ _on_hidden を呼ぶ）。
var _stacked := false


## host の全体に、幕と真ん中の入れ物を置き、入れ物を返す。shade は幕の不透明度（負なら Palette.SHADE のまま）。
## 幕を押して閉じる窓は、戻った幕（host の子 0）の mouse_filter を STOP にして gui_input を受ける。
static func add_shell(host: Control, shade := -1.0) -> CenterContainer:
	var curtain := ColorRect.new()
	curtain.color = Palette.SHADE if shade < 0.0 else Color(Palette.SHADE, shade)
	curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(curtain)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(center)
	return center


## 殻を作り、板を返す（中身は板の中に組む）。閉じた状態で始まる。
## what は枠の印の名前（`画面.枠`。空なら印を付けない。付けると置き場所と大きさを見張る）。
## size は板の大きさ（Vector2.ZERO なら中身に合わせる）。shade は幕の不透明度（負なら Palette.SHADE のまま）。outside_closes なら、板の外のクリックで閉じる。
## style を渡すと、板の地をそれにする（無ければ PANEL_SOLID）。
func build_window(overlays: RefCounted, what := "", size := Vector2.ZERO, shade := -1.0, outside_closes := false, style: StyleBox = null) -> PanelContainer:
	_overlays = overlays
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	if not visibility_changed.is_connected(_track_overlay):
		visibility_changed.connect(_track_overlay)
	var center := add_shell(self, shade)
	if outside_closes:
		var curtain := get_child(0) as Control
		curtain.mouse_filter = Control.MOUSE_FILTER_STOP
		curtain.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				close_window())
	_window_panel = PanelContainer.new()
	if style != null:
		_window_panel.add_theme_stylebox_override("panel", style)
	else:
		_window_panel.theme_type_variation = UiTheme.PANEL_SOLID
	_window_panel.custom_minimum_size = size
	if what != "":
		Steady.mark(_window_panel, what, Steady.RECT)
	center.add_child(_window_panel)
	return _window_panel


## 閉じる（見えなくするだけ。積み上げから降ろすのと _on_hidden は、見えなくなったことを受けて行う）。
func close_window() -> void:
	visible = false


## 板（検査用。大きさと、画面に収まるか）。
func window_panel() -> PanelContainer:
	return _window_panel


## 右クリック・Esc を受けた（いちばん上の重なる画面のとき）。既定は閉じる。
func _on_back() -> void:
	close_window()


## 見えなくなって、積み上げから降ろした。閉じたことを知らせる窓は、ここで知らせる。
func _on_hidden() -> void:
	pass


## 開いている間の入力（いちばん上の重なる画面のときだけ届く）。既定は、右クリック・Esc を _on_back に回す。
## 右クリックと Esc で違うことをする窓は、これを上書きする。
func _on_window_input(event: InputEvent) -> void:
	if CardKeys.is_back(event):
		get_viewport().set_input_as_handled()
		_on_back()


func _input(event: InputEvent) -> void:
	if not visible or (_overlays != null and not _overlays.is_top(self)):
		return
	_on_window_input(event)


func _track_overlay() -> void:
	if _overlays == null:
		return
	if visible and is_inside_tree():
		_overlays.open(self, pausing)
		_stacked = true
	else:
		_overlays.close(self)
		if _stacked:
			_stacked = false
			_on_hidden()


func _exit_tree() -> void:
	if _overlays != null:
		_overlays.close(self)
