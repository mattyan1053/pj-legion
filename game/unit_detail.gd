extends Control
## 駒 1 体の詳しい説明の重なる画面（docs/deck-screen.md の「駒の詳細」）。編成確認（deck_preview.gd）と出撃準備（sortie_screen.gd）で、
## 駒の札かアイコンを押すと開く。中身は部隊編成の画面の駒の札と同じ文（DeckText.detail_lines）に、持ち物の効果と特性を足したもの。
## 「閉じる」・右クリック・Esc・枠の外のクリックで閉じる。色や枠は UI のテーマ（ui_theme.gd。板は PANEL_SOLID）が当たる。

const Text := preload("res://game/text.gd")
const Names := preload("res://game/names.gd")
const DeckText := preload("res://game/deck_text.gd")
const UnitIcons := preload("res://game/unit_icons.gd")
const TextWrap := preload("res://game/text_wrap.gd")
const UiTheme := preload("res://game/ui_theme.gd")
const Palette := preload("res://game/ui_palette.gd")

## 文の幅と、文の欄の高さの上限（長い駒は欄の中で送る）。
const BODY_WIDTH := 460.0
const BODY_MAX_HEIGHT := 400.0

var _overlays: RefCounted
var _icon: TextureRect
var _title: Label
var _body: Label
var _scroll: ScrollContainer


## overlays は、開いている重なる画面の積み上げ（AppContext.overlays）。
func setup(overlays: RefCounted) -> void:
	_overlays = overlays
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	visibility_changed.connect(_track_overlay)
	var shade := ColorRect.new()
	shade.color = Color(Palette.SHADE, 0.5)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			close_detail())
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.theme_type_variation = UiTheme.PANEL_SOLID
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	column.add_child(head)
	_icon = UnitIcons.rect(UnitKind.Id.KING, 0, false, 64.0)
	head.add_child(_icon)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 22)
	_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_title)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)
	_body = Label.new()
	_body.add_theme_font_size_override("font_size", 15)
	_body.custom_minimum_size = Vector2(BODY_WIDTH, 0.0)
	_scroll.add_child(_body)
	var close := Button.new()
	close.text = Text.t("common.close")
	close.focus_mode = Control.FOCUS_NONE
	close.add_theme_font_size_override("font_size", 17)
	close.custom_minimum_size = Vector2(180.0, 44.0)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(close_detail)
	column.add_child(close)


## kind の駒（持ち物 equipment、始めのレベル level）の詳細を開く。side はアイコンの陣営の色、deck_army は部隊の軍（DeckText.detail_lines）。
## look は将の姿（unit_view.gd の KING_LOOKS。空ならいつもの将）。
func open(kind: UnitKind.Id, equipment: Array[Equipment.Id] = [], side := 0, deck_army := -1, level := 1, look := &"") -> void:
	_icon.texture = UnitIcons.texture(kind, side, false, look)
	_title.text = Names.kind(kind) if level <= 1 else Text.t("deck.detail.title_level", {"name": Names.kind(kind), "level": level})
	var font := _body.get_theme_font(&"font")
	var font_size := _body.get_theme_font_size(&"font_size")
	_body.text = TextWrap.fold("\n".join(DeckText.detail_lines(kind, equipment, deck_army)), BODY_WIDTH, func(character: String) -> float:
		return font.get_string_size(character, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	_scroll.custom_minimum_size = Vector2(BODY_WIDTH, minf(_body.get_combined_minimum_size().y, BODY_MAX_HEIGHT))
	_scroll.scroll_vertical = 0
	visible = true


func close_detail() -> void:
	visible = false


## いま出している駒の名前と文（検査用）。
func title_text() -> String:
	return _title.text


func body_text() -> String:
	return _body.text


func _track_overlay() -> void:
	if _overlays == null:
		return
	if visible and is_inside_tree():
		_overlays.open(self)
	else:
		_overlays.close(self)


func _exit_tree() -> void:
	if _overlays != null:
		_overlays.close(self)


func _input(event: InputEvent) -> void:
	if not visible or _overlays == null or not _overlays.is_top(self):
		return
	var right: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT
	var escape: bool = event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE
	if right or escape:
		get_viewport().set_input_as_handled()
		close_detail()
