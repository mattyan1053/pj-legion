extends Control
## 編成の確認（対戦の設定の「編成を確認」）。1 つの部隊の駒を、札（unit_card.gd）にして並べる重なる画面。
## 自分の部隊も、CPU の部隊も、同じ見え方。「閉じる」・右クリック・Esc で閉じる。
## 色や枠は UI のテーマ（ui_theme.gd。板は PANEL_SOLID、札は PANEL_CARD）が当たる。

const UnitCard := preload("res://game/unit_card.gd")
const DeckText := preload("res://game/deck_text.gd")
const UiTheme := preload("res://game/ui_theme.gd")
const Palette := preload("res://game/ui_palette.gd")

## 1 行に並べる札の数。
const COLUMNS := 4

var _overlays: RefCounted
var _title: Label
var _cards: GridContainer


## overlays は、開いている重なる画面の積み上げ（AppContext.overlays）。
func setup(overlays: RefCounted) -> void:
	_overlays = overlays
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	visibility_changed.connect(_track_overlay)
	var shade := ColorRect.new()
	shade.color = Palette.SHADE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.theme_type_variation = UiTheme.PANEL_SOLID
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 22)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2((UnitCard.WIDTH + 8.0) * COLUMNS, 330.0)
	column.add_child(scroll)
	_cards = GridContainer.new()
	_cards.columns = COLUMNS
	_cards.add_theme_constant_override("h_separation", 8)
	_cards.add_theme_constant_override("v_separation", 8)
	scroll.add_child(_cards)
	var close := Button.new()
	close.text = "閉じる"
	close.focus_mode = Control.FOCUS_NONE
	close.add_theme_font_size_override("font_size", 17)
	close.custom_minimum_size = Vector2(180.0, 44.0)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(close_preview)
	column.add_child(close)


## who（「あなた」「CPU」など）の部隊 deck を出す。将を先頭に、雇った駒を並びの順に。side はアイコンの陣営の色。
func open(who: String, deck: Deck, side := 0) -> void:
	_title.text = "%s　%s　コスト %d / %d" % [who, DeckText.army_name(deck.army), deck.total_cost(), deck.budget()]
	for child in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	_cards.add_child(UnitCard.build(UnitKind.Id.KING, [], side))
	for entry in deck.entries:
		_cards.add_child(UnitCard.build(entry.kind, entry.equipment, side))
	visible = true


func close_preview() -> void:
	visible = false


## 並べた札の駒の種類（将を含む。検査用）。
func shown_kinds() -> Array[UnitKind.Id]:
	var kinds: Array[UnitKind.Id] = []
	for card in _cards.get_children():
		if not card.is_queued_for_deletion():
			kinds.append(card.get_meta(&"kind"))
	return kinds


func title_text() -> String:
	return _title.text


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
	if not visible or not _overlays.is_top(self):
		return
	var right: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT
	var escape: bool = event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE
	if right or escape:
		get_viewport().set_input_as_handled()
		close_preview()
