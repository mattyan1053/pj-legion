extends CanvasLayer
## システムメニュー。画面の右上の「メニュー」のボタンと、開いたときのメニュー・確かめ・オプションの画面。
##
## どの画面の上にも重なる（layer が高い）。何を並べるかは開く側が open() に渡す。ここはルールを持たない。
## - 開いている間は、画面の全体を覆って、クリック・ドラッグ・ホイールを後ろへ通さない。
## - 右クリックと Esc は「戻す」: 確かめ → オプションの画面 → メニュー の順に閉じる。
## - 確かめの文（confirm）を持つ項目は、押すと「本当に？」を挟む（対戦が失われる項目）。
## - 「設定」（ITEM_SETTINGS）は、ここでオプションの画面（settings_panel.gd）に切り替える。閉じると settings_closed を出す。

const Text := preload("res://game/text.gd")
const Palette := preload("res://game/ui_palette.gd")
const UiTheme := preload("res://game/ui_theme.gd")
const Settings := preload("res://game/settings.gd")
const SettingsPanel := preload("res://game/settings_panel.gd")

## 右上のボタンが押された（開くかどうかと、何を並べるかは、呼ぶ側が決めて open() を呼ぶ）。
signal open_requested
## メニューを開いた（後ろの画面は、これを受けて止まる）。
signal opened
## 項目が選ばれた（確かめのある項目は、確かめたあと）。ITEM_RESUME と ITEM_SETTINGS は、ここで扱ってから知らせる。
signal item_chosen(id: StringName)
## メニューを閉じた（どの道で閉じても）。
signal closed
## オプションの画面を閉じた（値を取っておく合図）。
signal settings_closed
## 閉じずに 1 つ戻った（確かめ → メニュー、オプションの画面 → メニュー）。戻る音を鳴らす合図。
signal stepped_back

## 開いたメニューを閉じるだけの項目と、オプションの画面を開く項目（どちらも、ここで扱う）。
const ITEM_RESUME := &"resume"
const ITEM_SETTINGS := &"settings"

const LAYER := 20

const COLOR_WARNING := Palette.WARN
const BUTTON_WIDTH := 300.0
## 確かめの窓の幅の下限（見出しの下の飾りの線が、短い文でも伸びるように）。
const CONFIRM_WIDTH := 400.0
## 右上のボタンの大きさ。上の帯（battle_hud.gd）は、このぶんを右端に空けておく。
const CORNER_BUTTON_SIZE := Vector2(104.0, 34.0)
const CORNER_MARGIN := 8.0

var _corner: Button
var _overlay: Control
var _menu: PanelContainer
var _menu_column: VBoxContainer
var _confirm: PanelContainer
var _confirm_text: Label
var _confirm_note: Label
## 確かめの文の全体（1 行目が見出し、残りが失われるものの注意）。
var _confirm_full := ""
var _confirm_ok: Button
var _settings_panel: SettingsPanel
## いま並べている項目（[名前, 文字, 確かめの文] の列）と、確かめている項目の名前。
var _items: Array = []
var _confirming := &""
## オプションの画面だけを開いたか（タイトルの「オプション」）。そのときは、オプションの画面を閉じるとメニューごと閉じる。
var _settings_only := false
## 開いている重なる画面の積み上げ（overlay_stack.gd。AppContext.overlays）。
var _overlays: RefCounted


func setup(settings: Settings, overlays: RefCounted) -> void:
	_overlays = overlays
	layer = LAYER
	_corner = Button.new()
	_corner.text = Text.t("menu.corner")
	_corner.focus_mode = Control.FOCUS_NONE
	_corner.add_theme_font_size_override("font_size", 16)
	_corner.tooltip_text = Text.t("menu.corner.tooltip")
	_corner.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_corner.offset_left = -CORNER_BUTTON_SIZE.x - CORNER_MARGIN
	_corner.offset_right = -CORNER_MARGIN
	_corner.offset_top = (50.0 - CORNER_BUTTON_SIZE.y) / 2.0
	_corner.offset_bottom = _corner.offset_top + CORNER_BUTTON_SIZE.y
	_corner.pressed.connect(open_requested.emit)
	add_child(_corner)

	# 開いている間、画面の全体を覆って、後ろへ入力を通さない。
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visible = false
	add_child(_overlay)
	var shade := ColorRect.new()
	shade.color = Palette.SHADE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(center)

	_menu = _panel()
	center.add_child(_menu)
	_menu_column = VBoxContainer.new()
	_menu_column.add_theme_constant_override("separation", 10)
	_menu.add_child(_menu_column)

	_confirm = _panel()
	_confirm.visible = false
	center.add_child(_confirm)
	var confirm_column := VBoxContainer.new()
	confirm_column.add_theme_constant_override("separation", 14)
	_confirm.add_child(confirm_column)
	confirm_column.custom_minimum_size = Vector2(CONFIRM_WIDTH, 0.0)
	# 1 行目（何をするか）は窓の見出し、その下に危険の色の飾りの線、残り（失われるもの）は注意の色。
	_confirm_text = _label(20)
	UiTheme.style_window_title(_confirm_text, 20)
	confirm_column.add_child(_confirm_text)
	confirm_column.add_child(UiTheme.window_rule(Palette.DANGER))
	_confirm_note = _label(16)
	_confirm_note.add_theme_color_override("font_color", COLOR_WARNING)
	_confirm_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirm_column.add_child(_confirm_note)
	var confirm_buttons := HBoxContainer.new()
	confirm_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	confirm_buttons.add_theme_constant_override("separation", 16)
	confirm_column.add_child(confirm_buttons)
	var keep := _button(Text.t("menu.confirm.cancel"))
	keep.custom_minimum_size = Vector2(180.0, 48.0)
	keep.pressed.connect(back)
	confirm_buttons.add_child(keep)
	_confirm_ok = _button("")
	_confirm_ok.theme_type_variation = UiTheme.BUTTON_DANGER  # 確かめるのは、対戦の状態が失われる行き先だけ
	_confirm_ok.custom_minimum_size = Vector2(180.0, 48.0)
	_confirm_ok.pressed.connect(func() -> void: _choose(_confirming))
	confirm_buttons.add_child(_confirm_ok)

	_settings_panel = SettingsPanel.new()
	_settings_panel.setup(settings)
	_settings_panel.visible = false
	_settings_panel.closed.connect(back)
	center.add_child(_settings_panel)


## メニューを開く。items は [名前, 文字, 確かめの文（要らなければ空）] の列（上から）。
## 名前が ITEM_RESUME の項目は閉じるだけ、ITEM_SETTINGS の項目はオプションの画面を開く。ほかは item_chosen で知らせる。
## settings_only が真なら、メニューを出さずにオプションの画面だけを開く（閉じると、メニューへは戻らずに閉じる）。
## note は見出しの下に小さく出す文（ストーリーの「最後に保存: …」。空なら出さない）。
func open(items: Array, settings_only := false, note := "") -> void:
	_settings_only = settings_only
	_items = items.duplicate(true)
	for child in _menu_column.get_children():
		_menu_column.remove_child(child)
		child.queue_free()
	var title := _label(24)
	UiTheme.style_window_title(title)
	title.text = Text.t("menu.title")
	_menu_column.add_child(title)
	_menu_column.add_child(UiTheme.window_rule())
	if note != "":
		var saved := _label(14)
		saved.text = note
		saved.name = "Note"
		saved.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		saved.add_theme_color_override("font_color", Palette.TEXT_DIM)
		_menu_column.add_child(saved)
	# 項目はタイトルのメニューと同じ札。抜けると失われるものがある行き先（確かめを挟む項目）の前に、区切りの線を 1 本。
	var parted := false
	for item: Array in _items:
		var id: StringName = item[0]
		if not parted and item.size() > 2 and item[2] != "" and _menu_column.get_child_count() > (3 if note != "" else 2):
			parted = true
			_menu_column.add_child(HSeparator.new())
		var button := _button(item[1])
		button.theme_type_variation = UiTheme.BUTTON_MENU
		button.name = String(id)
		button.pressed.connect(func() -> void: press(id))
		_menu_column.add_child(button)
	_confirming = &""
	_show(_menu)
	_overlay.visible = true
	_overlays.open(self, true)
	if settings_only:
		open_settings()
	opened.emit()


func is_open() -> bool:
	return _overlay.visible


func is_settings_open() -> bool:
	return is_open() and _settings_panel.visible


## 確かめている途中の項目（無ければ空の名前）。検査用。
func confirming() -> StringName:
	return _confirming if is_open() and _confirm.visible else &""


## 確かめの文（出ていなければ空）。検査用。
func confirm_text() -> String:
	return _confirm_full if confirming() != &"" else ""


## 並べている項目の名前（上から）。開いていなければ空。検査用。
func item_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	if is_open():
		for item: Array in _items:
			ids.append(item[0])
	return ids


## 項目を押す（ボタンと同じ道）。確かめの文があれば、まず確かめる。並べていない項目なら偽を返す。
func press(id: StringName) -> bool:
	if not is_open():
		return false
	for item: Array in _items:
		if item[0] != id:
			continue
		var confirm: String = item[2] if item.size() > 2 else ""
		if confirm != "":
			_confirming = id
			_confirm_full = confirm
			var lines := confirm.split("\n", true, 1)
			_confirm_text.text = lines[0]
			_confirm_note.text = lines[1] if lines.size() > 1 else ""
			_confirm_note.visible = _confirm_note.text != ""
			_confirm_ok.text = item[1]
			_show(_confirm)
		else:
			_choose(id)
		return true
	return false


## 確かめている項目を、そのまま選ぶ（「確かめ」のボタンと同じ道）。検査用。
func accept() -> bool:
	if confirming() == &"":
		return false
	_choose(_confirming)
	return true


## 1 つ戻す（右クリック・Esc・「やめる」・設定の「戻る」）: 確かめ → オプションの画面 → メニュー の順に閉じる。
func back() -> void:
	if not is_open():
		return
	if _confirm.visible:
		_confirming = &""
		_show(_menu)
		stepped_back.emit()
	elif _settings_panel.visible and _settings_only:
		close()
	elif _settings_panel.visible:
		_show(_menu)
		settings_closed.emit()
		stepped_back.emit()
	else:
		close()


## メニューを閉じる（オプションの画面を開いていれば、それも閉じて取っておく合図を出す）。
func close() -> void:
	if not is_open():
		return
	if _settings_panel.visible:
		settings_closed.emit()
	_overlay.visible = false
	_settings_panel.visible = false
	_confirming = &""
	_overlays.close(self)
	closed.emit()


## オプションの画面を開く（メニューの「設定」と同じ）。
func open_settings() -> void:
	if is_open():
		_show(_settings_panel)
		_settings_panel.refresh()


## オプションの画面（検査とスクリーンショットの道具用）。
func settings_panel() -> SettingsPanel:
	return _settings_panel


func _choose(id: StringName) -> void:
	_confirming = &""
	match id:
		ITEM_RESUME:
			close()
		ITEM_SETTINGS:
			open_settings()
		_:
			close()
			item_chosen.emit(id)


func _show(panel: Control) -> void:
	for each: Control in [_menu, _confirm, _settings_panel]:
		each.visible = each == panel


## 開いている間の右クリックと Esc は「戻す」。後ろ（盤面）へは通さない。ほかの重なる画面が上にあれば、そちらが受ける。
func _input(event: InputEvent) -> void:
	if not is_open() or not _overlays.is_top(self):
		return
	var right: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT
	var escape: bool = event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE
	if right or escape:
		get_viewport().set_input_as_handled()
		back()
	elif event is InputEventKey:
		# キーは盤面の操作（待機、視点、ターン終了…）に使われているので、開いている間は後ろへ通さない。
		get_viewport().set_input_as_handled()


## オプションの画面を開いたままウィンドウを閉じても、変えた設定を取っておく（閉じたときと同じ合図を出す）。
## 設定は動かしたときに効くが、取っておくのはオプションの画面を閉じたときなので、ここで閉じずに終わると、次の起動で戻ってしまう。
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_settings_open():
		settings_closed.emit()


## 場面を抜けるなどで木から抜けたら、積み上げから降ろす（開いたまま消えても、後ろの場面を止めたままにしない）。
func _exit_tree() -> void:
	if _overlays != null:
		_overlays.close(self)


func _panel() -> PanelContainer:
	var style := UiTheme.solid_box(20.0)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _label(font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", 4)
	return label


func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 19)
	button.custom_minimum_size = Vector2(BUTTON_WIDTH, 50.0)
	button.focus_mode = Control.FOCUS_NONE
	return button
