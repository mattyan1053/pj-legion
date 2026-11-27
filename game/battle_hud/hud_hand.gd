extends "res://game/battle_hud/hud_info_panel.gd"
## 対戦の画面の手札の帯（試しの決まり OptionalRules.HAND。docs/hand-cards.md の「画面」）。下の帯のすぐ上、情報の枠の右。
## 札の欄は HAND_SLOTS 個で、枚数が変わっても帯の大きさは同じ（空の欄が残る）。札にマウスを乗せると、名前と効果の 1 文を帯の上に出す。

## 手札の札が押された（index は手札の何枚目か）。
signal card_pressed(index: int)

## 帯と、札 1 枚ぶんの欄と、説明の枠の大きさ（px）。枚数や文で変えない。
const HAND_SLOTS := Hand.HAND_LIMIT
const HAND_SLOT_SIZE := Vector2(92.0, 50.0)
const HAND_SIDE_WIDTH := 78.0
const HAND_SIZE := Vector2(HAND_SIDE_WIDTH * 2.0 + HAND_SLOT_SIZE.x * HAND_SLOTS + 6.0 * (HAND_SLOTS + 1) + 20.0, HAND_SLOT_SIZE.y + 14.0)
const HAND_NOTE_SIZE := Vector2(HAND_SIZE.x, 84.0)
const HAND_GAP := 6.0
const HAND_FONT := 16
const HAND_FONT_SMALL := 13

var _hand_panel: PanelContainer
var _hand_slots: Array[Button] = []
var _hand_stripes: Array[ColorRect] = []
var _hand_pile: Label
var _hand_foe: Label
var _hand_note: PanelContainer
var _hand_note_title: Label
var _hand_note_state: Label
var _hand_note_body: Label
## 欄ごとの札の中身（set_hand が受け取ったもの）。
var _hand_cards: Array[Dictionary] = []
var _hand_hover := -1


## 札の種類の色（欄の上の線）: 強める札は金、治す・守る札は緑、動かす札は水色、相手に使う札は赤。
static func card_color(card: int) -> Color:
	match card:
		Card.Id.MEND, Card.Id.RESUPPLY, Card.Id.WARD:
			return Palette.GOOD
		Card.Id.BLINK:
			return Palette.INFO
		Card.Id.SHOVE:
			return Palette.DANGER
	return Palette.ACCENT


func _build_hand() -> void:
	_hand_panel = _panel()
	_hand_panel.add_theme_stylebox_override("panel", UiTheme.box(Palette.OVERLAY, Palette.BORDER, 1, UiTheme.CORNER, 7.0))
	_hand_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_hand_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hand_panel.offset_left = INFO_WIDTH + 40.0
	_hand_panel.offset_right = INFO_WIDTH + 40.0
	_hand_panel.offset_top = -BOTTOM_BAR_HEIGHT - HAND_GAP
	_hand_panel.offset_bottom = -BOTTOM_BAR_HEIGHT - HAND_GAP
	_hand_panel.custom_minimum_size = HAND_SIZE
	_hand_panel.clip_contents = true
	_hand_panel.visible = false
	Steady.mark(_hand_panel, "battle.hand", Steady.RECT)
	add_child(_hand_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_hand_panel.add_child(row)
	_hand_pile = _hand_side_label(row, Text.t("battle.hand.title"))
	for index in HAND_SLOTS:
		var slot := Button.new()
		slot.custom_minimum_size = HAND_SLOT_SIZE
		slot.focus_mode = Control.FOCUS_NONE
		slot.clip_text = true
		slot.add_theme_font_override("font", UiTheme.FONT_BOLD)
		slot.add_theme_font_size_override("font_size", HAND_FONT)
		slot.pressed.connect(card_pressed.emit.bind(index))
		slot.mouse_entered.connect(_hover_hand.bind(index))
		slot.mouse_exited.connect(_hover_hand.bind(-1))
		row.add_child(slot)
		var stripe := ColorRect.new()
		stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stripe.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		stripe.offset_left = 4.0
		stripe.offset_right = -4.0
		stripe.offset_top = 3.0
		stripe.offset_bottom = 6.0
		slot.add_child(stripe)
		_hand_slots.append(slot)
		_hand_stripes.append(stripe)
	_hand_foe = _hand_side_label(row, "")

	_hand_note = _panel(COLOR_PANEL_SOLID)
	_hand_note.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_hand_note.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hand_note.offset_left = _hand_panel.offset_left
	_hand_note.offset_right = _hand_panel.offset_left
	_hand_note.offset_top = -BOTTOM_BAR_HEIGHT - HAND_GAP * 2.0 - HAND_SIZE.y
	_hand_note.offset_bottom = _hand_note.offset_top
	_hand_note.custom_minimum_size = HAND_NOTE_SIZE
	_hand_note.clip_contents = true
	_hand_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hand_note.visible = false
	Steady.mark(_hand_note, "battle.hand_note", Steady.RECT)
	add_child(_hand_note)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hand_note.add_child(column)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(head)
	_hand_note_title = _label(17)
	_hand_note_title.add_theme_font_override("font", UiTheme.FONT_BOLD)
	_hand_note_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_hand_note_title)
	_hand_note_state = _label(14)
	_hand_note_state.add_theme_color_override("font_color", Palette.WARN)
	head.add_child(_hand_note_state)
	_hand_note_body = _label(15)
	_hand_note_body.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_hand_note_body.max_lines_visible = 2
	_hand_note_body.custom_minimum_size = Vector2(HAND_NOTE_SIZE.x - 30.0, 0.0)
	column.add_child(_hand_note_body)


## 帯の端の欄（左は「手札」と山の残り、右は相手の枚数）。2 行。幅は決まっている。
func _hand_side_label(row: HBoxContainer, text: String) -> Label:
	var label := _label(HAND_FONT_SMALL)
	label.text = text
	label.custom_minimum_size = Vector2(HAND_SIDE_WIDTH, 0.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	label.clip_text = true
	row.add_child(label)
	return label


## 手札の帯を出す。shown が偽なら隠す（手札の無い対戦）。cards は札ごとの辞書の列（引いた順。HAND_SLOTS 枚まで）:
## card（Card.Id）、usable（押せるか）、off（押せない理由の短い文。押せれば空）、chosen（相手を選んでいる途中の札か）、
## confirming（もう一度押すと使う札か）。pile は山の残り、foe は相手の手札の枚数。
func set_hand(shown: bool, cards: Array[Dictionary] = [], pile := 0, foe := 0) -> void:
	_hand_panel.visible = shown
	bottom_reserved = HAND_SIZE.y + HAND_GAP if shown else 0.0
	_ult_panel.offset_top = -BOTTOM_BAR_HEIGHT - 8.0 - bottom_reserved
	_ult_panel.offset_bottom = _ult_panel.offset_top
	_hand_cards = cards
	if not shown:
		_hand_note.visible = false
		return
	_hand_pile.text = "%s\n%s" % [Text.t("battle.hand.title"), Text.t("battle.hand.pile", {"count": pile})]
	_hand_foe.text = Text.t("battle.hand.foe", {"count": foe})
	for index in HAND_SLOTS:
		var slot := _hand_slots[index]
		var stripe := _hand_stripes[index]
		if index >= cards.size():
			slot.text = ""
			slot.disabled = true
			stripe.visible = false
			_style_hand_slot(slot, Palette.PANEL, Color(Palette.BORDER, 0.5), 1)
			continue
		var card: Dictionary = cards[index]
		var usable: bool = card["usable"]
		var chosen: bool = card["chosen"]
		slot.text = Text.t("battle.hand.confirm") if card["confirming"] else Names.card(card["card"])
		slot.add_theme_font_size_override("font_size", HAND_FONT_SMALL - 2 if card["confirming"] else HAND_FONT)
		slot.disabled = not usable
		stripe.visible = true
		stripe.color = card_color(card["card"]) if usable else Color(card_color(card["card"]), 0.3)
		if chosen:
			_style_hand_slot(slot, Palette.CHOSEN, Palette.ACCENT, 2)
		elif usable:
			_style_hand_slot(slot, Palette.RAISED, Palette.BORDER_BRIGHT, 1)
		else:
			_style_hand_slot(slot, Palette.PANEL, Palette.BORDER, 1)
	_show_hand_note()


func _style_hand_slot(slot: Button, fill: Color, border: Color, width: int) -> void:
	var box := UiTheme.box(fill, border, width, UiTheme.CORNER, 4.0)
	box.content_margin_top = 10.0
	slot.add_theme_stylebox_override("normal", box)
	slot.add_theme_stylebox_override("disabled", box)
	slot.add_theme_stylebox_override("pressed", box)
	var hover := box.duplicate() as StyleBoxFlat
	hover.bg_color = fill.lightened(0.12)
	slot.add_theme_stylebox_override("hover", hover)


func _hover_hand(index: int) -> void:
	_hand_hover = index
	_show_hand_note()


## 札の説明: マウスを乗せている間だけ出す（相手を選んでいる間は、盤と予測のパネルを隠さない）。
func _show_hand_note() -> void:
	var index := _hand_hover if _hand_hover < _hand_cards.size() else -1
	_hand_note.visible = _hand_panel.visible and index >= 0
	if index < 0:
		return
	var card: Dictionary = _hand_cards[index]
	_hand_note_title.text = Names.card(card["card"])
	_hand_note_title.add_theme_color_override("font_color", card_color(card["card"]))
	_hand_note_state.text = card["off"]
	_hand_note_body.text = Names.card_summary(card["card"])


## 手札の札にマウスを乗せたことにする（-1 で離す）。検査とスクリーンショットの道具用。
func hover_hand(index: int) -> void:
	_hover_hand(index)


## 手札の帯: 出ているか、帯の四角、欄ごとの文字（空の欄は空）、押せる欄、説明の枠の文（出ていなければ空）。検査用。
func hand_shown() -> bool:
	return _hand_panel.visible


func hand_rect() -> Rect2:
	return _hand_panel.get_global_rect()


func hand_texts() -> Array[String]:
	var texts: Array[String] = []
	for slot in _hand_slots:
		texts.append(slot.text)
	return texts


func hand_usable() -> Array[bool]:
	var usable: Array[bool] = []
	for slot in _hand_slots:
		usable.append(not slot.disabled)
	return usable


func hand_note_text() -> String:
	if not _hand_note.visible:
		return ""
	return "%s %s %s" % [_hand_note_title.text, _hand_note_state.text, _hand_note_body.text]


## 札の説明の文が、枠の行の数に収まらずに切れているか。検査用。
func hand_note_cut() -> bool:
	return _hand_note_body.get_line_count() > _hand_note_body.max_lines_visible


func hand_side_texts() -> Array[String]:
	return [_hand_pile.text, _hand_foe.text]


## 手札の札を押す（クリックと同じ道）。押せれば真。検査用。
func press_hand(index: int) -> bool:
	if not _hand_panel.visible or index < 0 or index >= HAND_SLOTS or _hand_slots[index].disabled:
		return false
	_hand_slots[index].pressed.emit()
	return true
