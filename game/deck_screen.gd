extends Node
## 部隊の編成の場面（docs/deck-screen.md）。取っておいた部隊の一覧と、1 つの部隊を組む画面の 2 つを、切り替えて出す。
## 背景は対戦と同じ景色（backdrop.gd）。場面の決まりは scene_flow.gd。取っておく先は context.decks（deck_library.gd）。
##
## - 一覧: 部隊を選び（中身は駒の札で出す）、編集・複製・名前変更・削除（確かめる）。「新しい部隊」で、軍を選んでから空の部隊を組む。
## - 組む画面: 雇える駒の札を押して部隊に足し、部隊の駒を選んで、その駒の札と持ち物の欄を出す。並べ替えで、置かれるところが変わる。
##   予算・駒の数・出せない理由はいつも出す。出せない部隊は「編成完了」できない。
## - 右クリックと Esc は「戻す」: 確かめ・名前の入力 → 駒の選択 → 組む画面（変えたところがあれば確かめる）・軍の選択 → 一覧 → 戻り先。
## - 一覧の上の切り替えで「対戦用」と「ストーリー用」を選ぶ。一覧と「新しい部隊」は、選んでいる方の決まりの部隊だけ（混ざらない）。
## 組む画面の決まり（雇える駒、予算、数の上限）は、切り替えで決まる（rules。対戦の決まりか、いまの進み具合のストーリーの決まり）。
## - 流れ（run.gd）の中で置かれたら（出撃の準備・対戦の設定の「部隊を編成する」）、渡された決まりの一覧だけを出し（切り替えは出さない）、
##   いちばん外の「戻る」は Run.NEXT（流れの次の場面 = 出撃の準備・対戦の設定へ戻る）。寄り道の間に取っておいた部隊を、戻った先で選ぶ。

const Names := preload("res://game/names.gd")
const Palette := preload("res://game/ui_palette.gd")
const UiTheme := preload("res://game/ui_theme.gd")
const AppContext := preload("res://game/app_context.gd")
const Backdrop := preload("res://game/backdrop.gd")
const ScreenSize := preload("res://game/screen_size.gd")
const DeckLibrary := preload("res://game/deck_library.gd")
const DeckText := preload("res://game/deck_text.gd")
const TextWrap := preload("res://game/text_wrap.gd")
const Story := preload("res://game/story.gd")
const Run := preload("res://game/run.gd")
const UnitCard := preload("res://game/unit_card.gd")
const UnitIcons := preload("res://game/unit_icons.gd")
const ItemIcon := preload("res://game/item_icon.gd")
## 雇える駒・部隊の駒の行に出す、駒のアイコンの大きさ（px）。
const ICON_SIZE := 44

## 「タイトルへ戻る」で &"back"（流れの中なら Run.NEXT）。
signal finished(outcome: StringName)

## 色は UI のテーマの役割の色（ui_palette.gd）を引く。枠と札の形は UI のテーマ（ui_theme.gd）が当たる。
const COLOR_TEXT := Palette.TEXT
const COLOR_DIM := Palette.TEXT_DIM
const COLOR_BAD := Palette.DANGER
const COLOR_ACCENT := Palette.ACCENT
## 画面の上に空ける高さ（px）。右上のシステムメニューのボタンを、ほかの場面と同じく背景の上に置く（枠に埋もれないように）。
const TOP_ROOM := 52.0
## 詳しい中身の欄の、文を折り返す幅（px）。
const DETAIL_WIDTH := 400.0
const ROSTER_WIDTH := 300.0
const TROOP_WIDTH := 420.0
## 一覧の右の、駒の札を並べる数（1 行）。
const LIST_CARD_COLUMNS := 3
## 画面の幅の上限（論理の px）。横長の画面では、これより広げずに真ん中に置く（docs/screen-size.md）。
const MAX_WIDTH := 1560.0

## 組む画面で使う決まり（雇える駒、予算、数の上限）。切り替え（set_mode）で変わる。
var rules: DeckRules = DeckRules.versus()
## 一覧の切り替え: 対戦用（DeckRules.VERSUS）か、物語ごとのストーリー用（物語の RULES_ID）。名前は modes() と mode_name()。
var context: AppContext

var _library: DeckLibrary
var _char_widths := {}

# ---- 一覧 ----
var _list_view: Control
var _list_rows: VBoxContainer
var _list_empty: Label
var _list_detail_title: Label
var _list_detail_body: Label
var _list_detail_cards: GridContainer
var _list_detail_card: Control
var _list_detail_issues: Label
var _list_actions: Array[Button] = []
var _list_selected := ""
var _mode_buttons := {}
var _back_button: Button
## 流れの中で置かれたときに渡されたもの（{"rules": 決まりの名前, "back_label": 戻るボタンの文字}）。流れの外なら空。
var _detour := {}
## 寄り道の間に、最後に取っておいた部隊の id。
var _saved_in_detour := ""

# ---- 軍の選択（新しい部隊） ----
var _army_view: Control
var _army_cards := {}

# ---- 組む画面 ----
var _edit_view: Control
## 組み直している部隊の id（新しく組んでいるなら空）。
var _editing_id := ""
var _deck: Deck
var _deck_name := ""
var _dirty := false
var _selected := -1
## マウスを乗せている雇える駒（無ければ -1）。
var _hover_kind := -1
var _name_label: Label
var _army_label: Label
var _budget_bar: ProgressBar
var _budget_label: Label
var _count_label: Label
var _issues_label: Label
var _roster_buttons := {}
var _ult_label: Label
var _troop_rows: VBoxContainer
var _slots: Control
var _detail_card: PanelContainer
var _detail_title: Label
var _detail_icon: TextureRect
var _detail_body: Label
var _equip_box: PanelContainer
var _equip_title: Label
var _equip_rows := {}
var _save_button: Button

# ---- 確かめと名前の入力 ----
var _dialog: Control
var _dialog_text: Label
var _dialog_input: LineEdit
var _dialog_ok: Button
var _dialog_action: Callable


func _ready() -> void:
	if context == null:
		context = AppContext.new()
	_library = context.decks
	add_child(Backdrop.new())
	var layer := CanvasLayer.new()
	add_child(layer)
	var shade := ColorRect.new()
	shade.color = Color(Palette.SHADE, 0.45)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(shade)
	_list_view = _build_list()
	layer.add_child(_list_view)
	_army_view = _build_army_picker()
	layer.add_child(_army_view)
	_edit_view = _build_editor()
	layer.add_child(_edit_view)
	_dialog = _build_dialog()
	layer.add_child(_dialog)
	_library.changed.connect(_refresh_list)
	var given: Variant = context.run_data()
	if given is Dictionary:
		_detour = given
		_back_button.text = _detour.get("back_label", "戻る")
		for id: StringName in _mode_buttons:
			(_mode_buttons[id] as Button).visible = id == _detour.get("rules", DeckRules.VERSUS)
	set_mode(_detour.get("rules", DeckRules.VERSUS))
	if not _detour.is_empty():
		# 寄り道のもとで選んでいる部隊を、一覧で選んでおく（ストーリーは出撃の準備、対戦は対戦の設定の、その側の部隊）。
		var current: String = context.story.squad_id
		if _detour.get("rules") == DeckRules.VERSUS:
			current = context.match_choice.deck_ids[_detour.get("side", Unit.Side.PLAYER1)]
		if _library.find(current) != null and _library.find(current).deck.rules.id == rules.id:
			select_saved(current)


# ==== 場面の決まり ====


func resume_label() -> String:
	return "編成へ戻る"


## 組んでいる途中で、取っておいていない変更があるか（タイトルへ戻る・ゲームを終える前に確かめる）。
func in_progress() -> bool:
	return is_editing() and _dirty


## 抜ける前の確かめに書く、失われるもの（app.gd の leave_confirm）。
func losing_note() -> String:
	return "編成中の変更は失われる"


## 右クリックと Esc は「戻す」。重なる画面（システムメニュー）が開いている間は、そちらが受ける。
func _input(event: InputEvent) -> void:
	if context.overlays.is_open():
		return
	var right: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT
	var escape: bool = event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE
	if right or escape:
		get_viewport().set_input_as_handled()
		press_back()


## 1 つ戻す。確かめ・名前の入力 → 駒の選択 → 組む画面・軍の選択 → 一覧 → 戻り先 の順。
func press_back() -> void:
	if _dialog.visible:
		close_dialog()
	elif is_editing() and _selected != -1:
		select_entry(-1)
	elif is_editing():
		leave_editor()
	elif is_choosing_army():
		show_list()
	else:
		leave()


## 一覧から抜ける: タイトルへ（流れの中なら、流れの次の場面 = 出撃の準備へ。寄り道の間に取っておいた部隊を選ぶ）。
func leave() -> void:
	if _detour.is_empty():
		finished.emit(&"back")
		return
	var saved := _library.find(_saved_in_detour)
	if saved != null and saved.playable() and _detour.get("rules") == context.story.campaign.rules_id:
		context.story.choose_squad(_saved_in_detour)
	if saved != null and saved.playable() and _detour.get("rules") == DeckRules.VERSUS and context.match_choice != null:
		context.match_choice.choose_deck(_detour.get("side", Unit.Side.PLAYER1), saved.id, saved.deck)
	finished.emit(Run.NEXT)


## 流れの中（出撃の準備からの寄り道）で置かれたか。
func is_detour() -> bool:
	return not _detour.is_empty()


## 一覧の「戻る」のボタンの文字（検査用）。
func back_label() -> String:
	return _back_button.text


# ==== 一覧 ====


## 切り替えの並び: 対戦用と、物語ごとのストーリー用（物語の RULES_ID。物語の並びの順）。
static func modes() -> Array[StringName]:
	var ids: Array[StringName] = [DeckRules.VERSUS]
	for each in Story.campaigns():
		ids.append(each.rules_id)
	return ids


## 切り替えのボタンの文字: 対戦用は「対戦用」、ストーリー用は物語の名前。
static func mode_name(rules_id: StringName) -> String:
	for each in Story.campaigns():
		if each.rules_id == rules_id:
			return each.title
	return "対戦用"


## 一覧を、対戦用（DeckRules.VERSUS）か、ある物語のストーリー用（物語の RULES_ID）に切り替える。組む画面の決まりも替わる
## （ストーリー用は、その物語のいまの進み具合の決まり）。
func set_mode(rules_id: StringName) -> void:
	rules = context.rules_of(rules_id) if modes().has(rules_id) else DeckRules.versus()
	for id: StringName in _mode_buttons:
		(_mode_buttons[id] as Button).set_pressed_no_signal(id == rules.id)
	for army: UnitKind.Army in _army_cards:
		(_army_cards[army] as Button).visible = rules.armies().has(army)
	if _library.find(_list_selected) == null or _library.find(_list_selected).deck.rules.id != rules.id:
		_list_selected = ""
	show_list()


## いまの一覧の決まりの名前（DeckRules.VERSUS か、物語の RULES_ID）。
func mode() -> StringName:
	return rules.id


## いまの一覧に並ぶ部隊の id（検査用）。
func listed_ids() -> Array[String]:
	var ids: Array[String] = []
	for item in _library.for_rules(rules.id):
		ids.append(item.id)
	return ids


func show_list(select_id := "") -> void:
	_edit_view.visible = false
	_army_view.visible = false
	_list_view.visible = true
	if select_id != "":
		_list_selected = select_id
	_refresh_list()


func is_editing() -> bool:
	return _edit_view.visible


## 一覧で選んでいる部隊の id（無ければ空）。
func list_selected() -> String:
	return _list_selected


func select_saved(id: String) -> void:
	_list_selected = id if _library.find(id) != null else ""
	_refresh_list()


## 「新しい部隊」。まず軍を選ぶ（選べる軍が 1 つなら、選ばずにその軍で組む画面へ）。
func press_new() -> void:
	var armies := rules.armies()
	if armies.size() == 1:
		choose_new_army(armies[0])
		return
	if armies.is_empty():
		choose_new_army(UnitKind.Army.NONE)
		return
	_list_view.visible = false
	_edit_view.visible = false
	_army_view.visible = true


## 新しい部隊の軍を選ぶ画面を出しているか。
func is_choosing_army() -> bool:
	return _army_view.visible


## 新しい部隊の軍を army にして、空の部隊を組む画面へ。
func choose_new_army(army: UnitKind.Army) -> void:
	if army != UnitKind.Army.NONE and not rules.armies().has(army):
		return
	_open_editor("", _library.default_name(), Deck.new(army, rules))


## 一覧で選んでいる部隊を組み直す。
func press_edit() -> void:
	var item := _library.find(_list_selected)
	if item != null:
		_open_editor(item.id, item.name, item.deck.copy())


func press_duplicate() -> void:
	var item := _library.duplicate_deck(_list_selected)
	if item != null:
		select_saved(item.id)


func press_rename() -> void:
	var item := _library.find(_list_selected)
	if item == null:
		return
	var id := item.id
	_ask_name("部隊の名前", item.name, func(name: String) -> void: _library.rename(id, name))


## 「消す」。確かめてから消す。
func press_delete() -> void:
	var item := _library.find(_list_selected)
	if item == null:
		return
	var id := item.id
	_confirm("「%s」を削除しますか？" % item.name, "削除", func() -> void:
		_library.remove(id)
		_list_selected = "")


func _build_list() -> Control:
	var root := _frame()
	var column := root.get_child(0).get_child(0) as VBoxContainer
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	column.add_child(header)
	var title := _text(26, COLOR_TEXT)
	title.text = "部隊の編成"
	header.add_child(title)
	for id: StringName in modes():
		var button := _button(mode_name(id), 18)
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(150.0, 42.0)
		button.pressed.connect(func() -> void: set_mode(id))
		header.add_child(button)
		_mode_buttons[id] = button
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 20)
	column.add_child(body)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(400.0, 0.0)
	left.add_theme_constant_override("separation", 8)
	body.add_child(left)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	_list_rows = VBoxContainer.new()
	_list_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_rows.add_theme_constant_override("separation", 6)
	scroll.add_child(_list_rows)
	_list_empty = _text(20, COLOR_DIM)
	_list_empty.text = "編成なし"
	_list_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_list_rows.add_child(_list_empty)
	var new_button := _button("新しい部隊", 20)
	new_button.custom_minimum_size = Vector2(0.0, 52.0)
	new_button.pressed.connect(press_new)
	left.add_child(new_button)

	var right := _card()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)
	_list_detail_card = right
	var detail := VBoxContainer.new()
	detail.add_theme_constant_override("separation", 10)
	right.add_child(detail)
	_list_detail_title = _text(24, COLOR_TEXT)
	detail.add_child(_list_detail_title)
	_list_detail_body = _text(17, COLOR_TEXT)
	detail.add_child(_list_detail_body)
	# 駒の札（将と、雇った駒）。多ければ欄の中で送る。
	var cards_scroll := ScrollContainer.new()
	cards_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail.add_child(cards_scroll)
	_list_detail_cards = GridContainer.new()
	_list_detail_cards.columns = LIST_CARD_COLUMNS
	_list_detail_cards.add_theme_constant_override("h_separation", 8)
	_list_detail_cards.add_theme_constant_override("v_separation", 8)
	cards_scroll.add_child(_list_detail_cards)
	_list_detail_issues = _text(16, COLOR_BAD)
	detail.add_child(_list_detail_issues)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	detail.add_child(actions)
	for spec: Array in [["編集", press_edit], ["複製", press_duplicate], ["名前変更", press_rename], ["削除", press_delete]]:
		var button := _button(spec[0], 18)
		button.custom_minimum_size = Vector2(0.0, 46.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(spec[1])
		if spec[0] == "削除":
			button.theme_type_variation = UiTheme.BUTTON_DANGER
		actions.add_child(button)
		_list_actions.append(button)

	var footer := HBoxContainer.new()
	column.add_child(footer)
	_back_button = _button("タイトルへ戻る", 18)
	_back_button.custom_minimum_size = Vector2(220.0, 46.0)
	_back_button.pressed.connect(leave)
	footer.add_child(_back_button)
	return root


func _refresh_list() -> void:
	if _list_rows == null or not _list_view.visible:
		return
	for child in _list_rows.get_children():
		if child != _list_empty:
			_list_rows.remove_child(child)
			child.queue_free()
	var items := _library.for_rules(rules.id)
	if not items.any(func(item: DeckLibrary.Saved) -> bool: return item.id == _list_selected):
		_list_selected = items[0].id if not items.is_empty() else ""
	for item in items:
		var button := _card_button("", 16)
		button.toggle_mode = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0.0, 58.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.clip_text = true
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.text = "%s\n%s　%d 体　コスト %d / %d%s" % [
			item.name, DeckText.army_name(item.deck.army), item.deck.entries.size(),
			item.deck.total_cost(), item.deck.budget(), "" if item.playable() else "　出撃不可",
		]
		if not item.playable():
			button.add_theme_color_override("font_color", COLOR_BAD)
			button.add_theme_color_override("font_pressed_color", COLOR_BAD)
			button.add_theme_color_override("font_hover_color", COLOR_BAD.lightened(0.2))
		button.set_pressed_no_signal(item.id == _list_selected)
		var id := item.id
		button.pressed.connect(func() -> void: select_saved(id))
		_list_rows.add_child(button)
	_list_empty.visible = items.is_empty()
	var chosen := _library.find(_list_selected)
	_list_detail_card.modulate.a = 1.0 if chosen != null else 0.0  # 選んでいなければ、右の欄は空（場所は保つ）
	for button in _list_actions:
		button.disabled = chosen == null
	for child in _list_detail_cards.get_children():
		_list_detail_cards.remove_child(child)
		child.queue_free()
	if chosen == null:
		_list_detail_title.text = ""
		_list_detail_body.text = ""
		_list_detail_issues.text = ""
		return
	_list_detail_title.text = chosen.name
	_list_detail_body.text = "%s　%d 体　コスト %d / %d" % [
		DeckText.army_name(chosen.deck.army), chosen.deck.entries.size(), chosen.deck.total_cost(), chosen.deck.budget(),
	]
	_list_detail_cards.add_child(UnitCard.build(UnitKind.Id.KING))
	for entry in chosen.deck.entries:
		_list_detail_cards.add_child(UnitCard.build(entry.kind, entry.equipment))
	var issues := chosen.issues()
	_fold(_list_detail_issues, "" if issues.is_empty() else "出撃不可: " + "、".join(issues), DETAIL_WIDTH + 200.0)


## 一覧の右に出している駒の札の種類（将を含む。検査用）。
func list_card_kinds() -> Array[UnitKind.Id]:
	var kinds: Array[UnitKind.Id] = []
	for card in _list_detail_cards.get_children():
		kinds.append(card.get_meta(&"kind"))
	return kinds


# ==== 軍の選択 ====


func _build_army_picker() -> Control:
	var root := _frame()
	root.visible = false
	var column := root.get_child(0).get_child(0) as VBoxContainer
	var title := _text(26, COLOR_TEXT)
	title.text = "軍を選ぶ"
	column.add_child(title)
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(center)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	center.add_child(row)
	for army: UnitKind.Army in [UnitKind.Army.MILITARY, UnitKind.Army.FANTASY]:
		var card := _card_button("", 18)
		card.custom_minimum_size = Vector2(400.0, 380.0)
		card.pressed.connect(func() -> void: choose_new_army(army))
		var inside := VBoxContainer.new()
		inside.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 18)
		inside.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inside.add_theme_constant_override("separation", 8)
		card.add_child(inside)
		var army_name := _text(30, COLOR_TEXT)
		army_name.text = DeckText.army_name(army)
		inside.add_child(army_name)
		var budget := _text(17, COLOR_DIM)
		budget.text = "予算 %d" % Deck.budget_of(army)
		inside.add_child(budget)
		var faces := HBoxContainer.new()
		faces.add_theme_constant_override("separation", 4)
		inside.add_child(faces)
		faces.add_child(UnitIcons.rect(UnitKind.Id.KING, 0, false, 64.0))
		for kind in Deck.roster(army):
			faces.add_child(UnitIcons.rect(kind, 0, false, 64.0))
		var roster := _text(17, COLOR_TEXT)
		var names: Array[String] = []
		for kind in Deck.roster(army):
			names.append("%s（%s）" % [Names.kind(kind), DeckText.role_name(kind)])
		roster.text = "\n".join(names)
		inside.add_child(roster)
		var ult := Ults.of_army(army)
		if ult != null:
			var ult_label := _text(15, COLOR_DIM)
			_fold(ult_label, "必殺技: %s\n%s" % [Names.ult(ult), Names.ult_summary(ult)], 360.0)
			inside.add_child(ult_label)
		for label in inside.find_children("*", "Control", true, false):
			(label as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(card)
		_army_cards[army] = card
	var footer := HBoxContainer.new()
	column.add_child(footer)
	var back := _button("戻る", 18)
	back.custom_minimum_size = Vector2(200.0, 46.0)
	back.pressed.connect(func() -> void: show_list())
	footer.add_child(back)
	return root


# ==== 組む画面 ====


func _open_editor(id: String, name: String, deck: Deck) -> void:
	_editing_id = id
	_deck_name = name
	_deck = deck
	_dirty = false
	_selected = -1
	_hover_kind = -1
	_list_view.visible = false
	_edit_view.visible = true
	_refresh_editor()


## 組んでいる部隊（検査用。写しではない）。
func editing_deck() -> Deck:
	return _deck


func selected_entry() -> int:
	return _selected


## 部隊の index 番目の行のボタンが出している文と、マウスを乗せると出る文（検査用）。
func troop_row_texts(index: int) -> Array[String]:
	var main: Button = _troop_rows.get_child(index).get_child(1)
	return [main.text, main.tooltip_text]


## 雇える駒を押した: 部隊の最後に足して、その駒を選ぶ（装備をすぐ持たせられる）。
func hire(kind: UnitKind.Id) -> void:
	if _deck.add(kind) == null:
		return
	_selected = _deck.entries.size() - 1
	_dirty = true
	_refresh_editor()


## 部隊の i 番目の駒を選ぶ（-1 でやめる）。選んでいる駒をもう一度押すと、やめる。
func select_entry(index: int) -> void:
	_selected = index if index >= 0 and index < _deck.entries.size() else -1
	_refresh_editor()


func remove_entry(index: int) -> void:
	if index < 0 or index >= _deck.entries.size():
		return
	_deck.remove(_deck.entries[index])
	if _selected == index:
		_selected = -1
	elif _selected > index:
		_selected -= 1
	_dirty = true
	_refresh_editor()


## 部隊の i 番目の駒を、step（-1 で上、+1 で下）だけ動かす。選んでいれば、選んだまま動く。
func move_entry(index: int, step: int) -> void:
	if not _deck.move(index, index + step):
		return
	if _selected == index:
		_selected = index + step
	elif _selected == index + step:
		_selected = index
	_dirty = true
	_refresh_editor()


## 選んでいる駒に装備を 1 個持たせる。
## 持ち物 item を、選んでいる駒に持たせる。決まりが許さない持ち物（ストーリーで、まだ解放していない）は持たせない。
func equip(item: Equipment.Id) -> void:
	if _selected == -1 or not _deck.rules.allows_item(item) or not _deck.entries[_selected].equip(item):
		return
	_dirty = true
	_refresh_editor()


func unequip(item: Equipment.Id) -> void:
	if _selected == -1 or not _deck.entries[_selected].unequip(item):
		return
	_dirty = true
	_refresh_editor()


func press_rename_editing() -> void:
	_ask_name("部隊の名前", _deck_name, func(name: String) -> void:
		var cleaned := DeckLibrary.clean_name(name, _deck_name)
		if cleaned != _deck_name:
			_deck_name = cleaned
			_dirty = true
		_refresh_editor())


## 取っておけるか（出せる部隊だけ）。
func can_save() -> bool:
	return _deck != null and _deck.is_valid()


## 「編成完了」。出せない部隊なら何もしない（理由は出ている）。取っておいたら一覧へ戻り、その部隊を選ぶ。
func press_save() -> void:
	if not can_save():
		return
	var id := _editing_id
	if id == "" or _library.find(id) == null:
		id = _library.add(_deck_name, _deck).id
	else:
		_library.replace(id, _deck_name, _deck)
	_dirty = false
	_saved_in_detour = id
	show_list(id)


## 組む画面を抜けて一覧へ。取っておいていない変更があれば、確かめる。
func leave_editor() -> void:
	if not _dirty:
		show_list(_editing_id)
		return
	_confirm("変更を破棄して戻りますか？", "破棄", func() -> void:
		_dirty = false
		show_list(_editing_id))


func _build_editor() -> Control:
	var root := _frame()
	var column := root.get_child(0).get_child(0) as VBoxContainer

	# 見出し: 名前、軍、予算（いつも見える）
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	column.add_child(header)
	_name_label = _text(24, COLOR_ACCENT)
	_name_label.custom_minimum_size = Vector2(260.0, 0.0)
	_name_label.clip_text = true
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header.add_child(_name_label)
	var rename := _button("名前変更", 15)
	rename.pressed.connect(press_rename_editing)
	header.add_child(rename)
	_army_label = _text(22, COLOR_TEXT)
	_army_label.custom_minimum_size = Vector2(140.0, 0.0)
	_army_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(_army_label)
	_budget_label = _text(20, COLOR_TEXT)
	_budget_label.custom_minimum_size = Vector2(150.0, 0.0)
	_budget_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(_budget_label)
	_budget_bar = ProgressBar.new()
	_budget_bar.show_percentage = false
	_budget_bar.custom_minimum_size = Vector2(180.0, 16.0)
	_budget_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_budget_bar)
	_count_label = _text(20, COLOR_TEXT)
	_count_label.custom_minimum_size = Vector2(110.0, 0.0)
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(_count_label)
	_issues_label = _text(16, COLOR_BAD)
	_issues_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_issues_label.clip_text = true
	_issues_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header.add_child(_issues_label)

	# 3 つの列: 雇える駒、部隊、選んだ駒（札と持ち物）
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	column.add_child(body)

	var roster := VBoxContainer.new()
	roster.custom_minimum_size = Vector2(ROSTER_WIDTH, 0.0)
	roster.add_theme_constant_override("separation", 6)
	body.add_child(roster)
	roster.add_child(_caption("雇える駒"))
	for i in 4:
		var button := _card_button("", 15)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(ROSTER_WIDTH, 62.0)
		button.add_theme_constant_override("icon_max_width", ICON_SIZE)
		button.pressed.connect(func() -> void: _on_roster(i, &"press"))
		button.mouse_entered.connect(func() -> void: _on_roster(i, &"enter"))
		button.mouse_exited.connect(func() -> void: _on_roster(i, &"exit"))
		roster.add_child(button)
		_roster_buttons[i] = button
	var ult_card := _card()
	roster.add_child(ult_card)
	_ult_label = _text(14, COLOR_DIM)
	ult_card.add_child(_ult_label)

	var troop := VBoxContainer.new()
	troop.custom_minimum_size = Vector2(TROOP_WIDTH, 0.0)
	troop.add_theme_constant_override("separation", 6)
	body.add_child(troop)
	troop.add_child(_caption("部隊"))
	troop.add_child(_king_row())
	# 部隊の並びは、決まりの上限が大きくても画面の下へはみ出さないよう、列の残りの高さの中で送れるようにする。
	var troop_scroll := ScrollContainer.new()
	troop_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	troop_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	troop.add_child(troop_scroll)
	_troop_rows = VBoxContainer.new()
	_troop_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_troop_rows.add_theme_constant_override("separation", 4)
	troop_scroll.add_child(_troop_rows)
	_slots = SlotMap.new()
	_slots.custom_minimum_size = Vector2(TROOP_WIDTH, 100.0)
	troop.add_child(_slots)

	# 右: 選んだ駒の札（上）と、その駒の持ち物の欄（下）。別々の枠に分ける。
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	body.add_child(right)
	_detail_card = _card()
	_detail_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_detail_card)
	# 中身が長い駒でも、画面の下へはみ出さないよう、札の中で送れるようにする。
	var detail_scroll := ScrollContainer.new()
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail_card.add_child(detail_scroll)
	var detail_column := VBoxContainer.new()
	detail_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_column.add_theme_constant_override("separation", 6)
	detail_scroll.add_child(detail_column)
	var detail_head := HBoxContainer.new()
	detail_head.add_theme_constant_override("separation", 8)
	detail_column.add_child(detail_head)
	_detail_icon = UnitIcons.rect(UnitKind.Id.KING, 0, false, 64.0)
	detail_head.add_child(_detail_icon)
	_detail_title = _text(22, COLOR_TEXT)
	_detail_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	detail_head.add_child(_detail_title)
	_detail_body = _text(15, COLOR_TEXT)
	detail_column.add_child(_detail_body)
	_equip_box = _card()
	right.add_child(_equip_box)
	var equip_column := VBoxContainer.new()
	equip_column.add_theme_constant_override("separation", 6)
	_equip_box.add_child(equip_column)
	_equip_title = _text(17, COLOR_TEXT)
	equip_column.add_child(_equip_title)
	for item: Equipment.Id in Equipment.Id.values():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		equip_column.add_child(row)
		row.add_child(ItemIcon.new(item, 32.0))
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 0)
		row.add_child(info)
		var item_name := _text(16, COLOR_TEXT)
		info.add_child(item_name)
		var effect := _text(14, COLOR_DIM)
		effect.text = DeckText.equipment_effect(item)
		info.add_child(effect)
		var minus := _button("−", 18)
		minus.custom_minimum_size = Vector2(40.0, 36.0)
		minus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		minus.pressed.connect(func() -> void: unequip(item))
		row.add_child(minus)
		var count := _text(18, COLOR_TEXT)
		count.custom_minimum_size = Vector2(28.0, 0.0)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(count)
		var plus := _button("＋", 18)
		plus.custom_minimum_size = Vector2(40.0, 36.0)
		plus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		plus.pressed.connect(func() -> void: equip(item))
		row.add_child(plus)
		_equip_rows[item] = [minus, count, plus, item_name, effect, row]

	# 下: 戻る、編成完了
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 14)
	column.add_child(footer)
	var back := _button("戻る", 18)
	back.custom_minimum_size = Vector2(200.0, 48.0)
	back.pressed.connect(leave_editor)
	footer.add_child(back)
	var footer_fill := Control.new()
	footer_fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(footer_fill)
	_save_button = _button("編成完了", 20)
	_save_button.custom_minimum_size = Vector2(240.0, 48.0)
	_save_button.set_meta(&"sound", &"ui_confirm")
	_save_button.theme_type_variation = UiTheme.BUTTON_PRIMARY
	_save_button.pressed.connect(press_save)
	footer.add_child(_save_button)
	return root


func _refresh_editor() -> void:
	if _deck == null:
		return
	_name_label.text = _deck_name + ("*" if _dirty else "")
	_army_label.text = DeckText.army_name(_deck.army)

	var total := _deck.total_cost()
	var budget := _deck.budget()
	_budget_label.text = "コスト %d / %d" % [total, budget]
	_budget_label.add_theme_color_override("font_color", COLOR_BAD if total > budget else COLOR_TEXT)
	_budget_bar.max_value = maxi(budget, 1)
	_budget_bar.value = mini(total, budget)
	# 予算を超えたら、棒を危険の色にする（超えていなければ、テーマの棒のまま）。
	if total > budget:
		_budget_bar.add_theme_stylebox_override("fill", UiTheme.box(Palette.DANGER, Palette.DANGER, 0))
	else:
		_budget_bar.remove_theme_stylebox_override("fill")
	var count := _deck.entries.size()
	_count_label.text = "駒 %d / %d" % [count, _deck.rules.max_units]
	var issues := DeckText.problem_texts(_deck)
	_issues_label.text = "" if issues.is_empty() else "出撃不可: " + "、".join(issues)
	_issues_label.tooltip_text = _issues_label.text

	var kinds := _deck.available_kinds()
	var full := count >= _deck.rules.max_units
	for i: int in _roster_buttons:
		var button: Button = _roster_buttons[i]
		button.visible = i < kinds.size()
		if i >= kinds.size():
			continue
		var kind := kinds[i]
		button.icon = UnitIcons.texture(kind)
		button.set_meta(&"kind", kind)
		button.text = "%s　%s　コスト %d\n%s" % [
			Names.kind(kind), DeckText.role_name(kind), UnitKind.cost(kind), DeckText.stats_line(kind),
		]
		button.disabled = full
		button.tooltip_text = "%d 体まで" % _deck.rules.max_units if full else ""
	var ult := Ults.of_army(_deck.army) if _deck.army != UnitKind.Army.NONE else null
	if ult != null:
		_fold(_ult_label, "必殺技: %s\n%s" % [Names.ult(ult), Names.ult_summary(ult)], ROSTER_WIDTH - 24.0)
	_ult_label.get_parent().visible = ult != null

	for child in _troop_rows.get_children():
		_troop_rows.remove_child(child)
		child.queue_free()
	for i in count:
		_troop_rows.add_child(_troop_row(i))
	if count == 0:
		var empty := _text(16, COLOR_DIM)
		empty.text = "駒なし"
		_troop_rows.add_child(empty)
	(_slots as SlotMap).show_slots(count, _selected)

	_refresh_detail()
	_save_button.disabled = not can_save()


func _king_row() -> Control:
	var row := _card()
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	row.add_child(line)
	line.add_child(UnitIcons.rect(UnitKind.Id.KING, 0, false, 32.0))
	var label := _text(16, COLOR_DIM)
	label.text = "将　%s" % DeckText.stats_line(UnitKind.Id.KING)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(label)
	return row


## 部隊の index 番目の駒の行: 番号、駒の札（名前・役割・コストと持ち物。押して選ぶ）、並べ替え、外す。
func _troop_row(index: int) -> Control:
	var entry := _deck.entries[index]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var number := _text(17, COLOR_ACCENT)
	number.text = str(index + 1)
	number.custom_minimum_size = Vector2(24.0, 0.0)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(number)
	var main := _card_button("", 14)
	main.toggle_mode = true
	main.alignment = HORIZONTAL_ALIGNMENT_LEFT
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.custom_minimum_size = Vector2(0.0, 46.0)
	main.icon = UnitIcons.texture(entry.kind)
	main.add_theme_constant_override("icon_max_width", 28)
	# 持ち物の文が長くても、列の幅を広げない。収まらないぶんは「…」にして、全文はマウスを乗せると出す。
	main.clip_text = true
	main.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var equipment := "、".join(UnitCard.equipment_lines(entry.equipment))
	main.text = "%s　コスト %d\n%s" % [
		Names.kind(entry.kind), entry.cost(), equipment if equipment != "" else "持ち物なし",
	]
	main.tooltip_text = main.text
	main.set_pressed_no_signal(index == _selected)
	main.pressed.connect(func() -> void: select_entry(-1 if _selected == index else index))
	row.add_child(main)
	for spec: Array in [["▲", -1, index > 0], ["▼", 1, index < _deck.entries.size() - 1]]:
		var step: int = spec[1]
		var move := _button(spec[0], 14)
		move.custom_minimum_size = Vector2(36.0, 46.0)
		move.disabled = not spec[2]
		move.pressed.connect(func() -> void: move_entry(index, step))
		row.add_child(move)
	var remove := _button("外す", 14)
	remove.custom_minimum_size = Vector2(52.0, 46.0)
	remove.pressed.connect(func() -> void: remove_entry(index))
	row.add_child(remove)
	return row


## 雇える駒の i 番目のボタンが押された・マウスが乗った・離れた。
func _on_roster(index: int, what: StringName) -> void:
	var kinds := _deck.available_kinds()
	if index >= kinds.size():
		return
	match what:
		&"press":
			hire(kinds[index])
		&"enter":
			_set_hover(kinds[index])
		&"exit":
			_set_hover(-1)


## 雇える駒 kind にマウスを乗せたことにする（-1 で離す）。スクリーンショットの道具用。
func hover_kind(kind: int) -> void:
	_set_hover(kind)


func _set_hover(kind: int) -> void:
	_hover_kind = kind
	_refresh_detail()


## 右の欄。マウスを乗せている雇える駒 → 選んでいる部隊の駒 の順に、駒の札を出す。部隊の駒なら、下に持ち物の欄も出す。
func _refresh_detail() -> void:
	var entry: DeckEntry = _deck.entries[_selected] if _selected != -1 else null
	var kind := -1
	if _hover_kind != -1:
		kind = _hover_kind
		entry = null
	elif entry != null:
		kind = entry.kind
	_equip_box.visible = entry != null
	_detail_card.visible = kind != -1
	if kind == -1:
		return
	var unit_kind := kind as UnitKind.Id
	var title := Names.kind(unit_kind)
	if entry != null:
		title = "%d. %s" % [_selected + 1, title]
	_detail_title.text = title
	_detail_icon.texture = UnitIcons.texture(unit_kind)
	var role := UnitKind.role(unit_kind)
	var lines: Array[String] = [
		"%s　コスト %d" % [DeckText.role_name(unit_kind), UnitKind.cost(unit_kind)],
		DeckText.ROLE_NOTES.get(role, ""),
		"",
		DeckText.stats_line(unit_kind),
	]
	if _deck != null and UnitKind.army(unit_kind) != _deck.army:
		# ストーリーで解放した、ほかの軍の駒（必殺技は部隊の軍のもの）。
		lines.insert(0, "%s の駒（この部隊では %s として戦う）" % [DeckText.army_name(UnitKind.army(unit_kind)), DeckText.army_name(_deck.army)])
	if entry != null and not entry.equipment.is_empty():
		lines.append("持ち物込み: " + DeckText.stats_line(unit_kind, DeckText.equipment_bonus(entry.equipment)))
	var skill := DeckText.skill_text(unit_kind)
	if skill != "":
		lines.append("")
		lines.append("スキル: " + skill)
	var evolutions := DeckText.evolution_lines(unit_kind)
	if not evolutions.is_empty():
		lines.append("")
		lines.append("進化（レベル %d）" % Growth.MAX_LEVEL)
		for line in evolutions:
			lines.append("・" + line)
	_fold(_detail_body, "\n".join(lines), DETAIL_WIDTH)
	if entry != null:
		_equip_title.text = "持ち物　%d / %d" % [entry.equipment.size(), Equipment.MAX_PER_UNIT]
		var full := entry.equipment.size() >= Equipment.MAX_PER_UNIT
		for item: Equipment.Id in _equip_rows:
			var parts: Array = _equip_rows[item]
			var allowed := _deck.rules.allows_item(item)
			(parts[0] as Button).disabled = entry.count(item) == 0
			(parts[1] as Label).text = str(entry.count(item))
			(parts[2] as Button).disabled = full or not allowed
			# まだ持たせられない持ち物（ストーリーで未解放）は、灰色で「未解放」。持たせているものは「−」で外せる。
			var item_name := parts[3] as Label
			item_name.text = "%s　コスト %d" % [Names.item(item), Equipment.cost(item)]
			if not allowed:
				item_name.text += "　未解放"
			item_name.add_theme_color_override("font_color", COLOR_TEXT if allowed else COLOR_DIM)
			(parts[5] as Control).modulate = Color.WHITE if allowed else Color(1, 1, 1, 0.55)
			(parts[5] as Control).tooltip_text = "" if allowed else "ストーリーを進めると持たせられる"


# ==== 確かめと名前の入力 ====


func is_dialog_open() -> bool:
	return _dialog.visible


## 確かめ・名前の入力の「決める」。
func accept_dialog() -> void:
	if not _dialog.visible:
		return
	var action := _dialog_action
	var input := _dialog_input.text
	var asking_name := _dialog_input.visible
	close_dialog()
	if asking_name:
		action.call(input)
	else:
		action.call()


func close_dialog() -> void:
	_dialog.visible = false
	_dialog_input.release_focus()


## 名前の入力に入っている文字（検査用に、書き換えもできる）。
func set_dialog_input(text: String) -> void:
	_dialog_input.text = text


func _confirm(text: String, ok_text: String, action: Callable) -> void:
	_dialog_text.text = text
	_dialog_ok.text = ok_text
	_dialog_ok.theme_type_variation = UiTheme.BUTTON_DANGER  # 確かめるのは、元に戻せないこと（消す）
	_dialog_input.visible = false
	_dialog_action = action
	_dialog.visible = true


func _ask_name(title: String, current: String, action: Callable) -> void:
	_dialog_text.text = "%s（%d 文字まで）" % [title, DeckLibrary.MAX_NAME_LENGTH]
	_dialog_ok.text = "決める"
	_dialog_ok.theme_type_variation = &""
	_dialog_input.visible = true
	_dialog_input.text = current
	_dialog_action = action
	_dialog.visible = true
	_dialog_input.grab_focus()
	_dialog_input.select_all()


func _build_dialog() -> Control:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	var shade := ColorRect.new()
	shade.color = Palette.SHADE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.theme_type_variation = UiTheme.PANEL_SOLID
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	column.custom_minimum_size = Vector2(460.0, 0.0)
	panel.add_child(column)
	_dialog_text = _text(19, COLOR_TEXT)
	_dialog_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_dialog_text)
	_dialog_input = LineEdit.new()
	_dialog_input.max_length = DeckLibrary.MAX_NAME_LENGTH
	_dialog_input.add_theme_font_size_override("font_size", 20)
	_dialog_input.custom_minimum_size = Vector2(0.0, 44.0)
	_dialog_input.context_menu_enabled = false
	_dialog_input.text_submitted.connect(func(_submitted: String) -> void: accept_dialog())
	column.add_child(_dialog_input)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	column.add_child(buttons)
	var cancel := _button("やめる", 18)
	cancel.custom_minimum_size = Vector2(180.0, 46.0)
	cancel.pressed.connect(close_dialog)
	buttons.add_child(cancel)
	_dialog_ok = _button("決める", 18)
	_dialog_ok.custom_minimum_size = Vector2(180.0, 46.0)
	_dialog_ok.pressed.connect(accept_dialog)
	buttons.add_child(_dialog_ok)
	return overlay


# ==== 部品 ====


## 画面いっぱいの枠（外側の余白 + 中の縦の並び）。root.get_child(0).get_child(0) が縦の並び。
func _frame() -> Control:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 横長の画面では、横に広げすぎない（項目と説明が離れて読みにくくなる。docs/screen-size.md）。
	ScreenSize.cap(margin, Vector2(MAX_WIDTH, INF))
	for side: String in ["left", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	margin.add_theme_constant_override("margin_top", int(TOP_ROOM))
	var panel := PanelContainer.new()
	panel.theme_type_variation = UiTheme.PANEL_SOLID
	margin.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	return margin


## 枠の中の区切り（UI のテーマの札）。
func _card() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = UiTheme.PANEL_CARD
	return panel


func _caption(text: String) -> Label:
	var label := _text(15, COLOR_DIM)
	label.text = text
	return label


func _text(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


## 札の形のボタン（雇える駒、部隊の駒、一覧の部隊、軍）。UI のテーマのカード（乗ると金の縁）。
func _card_button(text: String, font_size: int) -> Button:
	var button := _button(text, font_size)
	button.theme_type_variation = UiTheme.BUTTON_CARD
	return button


func _button(text: String, font_size: int) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", font_size)
	return button


func _fold(label: Label, text: String, width: float) -> void:
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	label.text = TextWrap.fold(text, width, func(character: String) -> float:
		var key := "%d:%s" % [font_size, character]
		if not _char_widths.has(key):
			_char_widths[key] = font.get_string_size(character, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		return _char_widths[key])


## 小さな配置の図。本陣（将）と、その前の 2 行に、部隊の並びの番号を描く（何も無い盤のとき。Deployment.open_field_slots）。
class SlotMap:
	extends Control

	const CELL := 28.0
	const COLUMNS := 5
	const ROWS := 2
	const MIDDLE := 2  ## 本陣の列（COLUMNS の真ん中）
	var _count := 0
	var _selected := -1

	func show_slots(count: int, selected: int) -> void:
		_count = count
		_selected = selected
		queue_redraw()

	func _draw() -> void:
		var font := get_theme_default_font()
		var caption := "配置"
		draw_string(font, Vector2(0.0, 14.0), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.68, 0.72, 0.78))
		var origin := Vector2((size.x - CELL * COLUMNS) * 0.5, 21.0)
		var slots := Deployment.open_field_slots(_count)
		for row in ROWS + 1:
			for column in COLUMNS:
				var is_hq_row := row == ROWS
				if is_hq_row and column != MIDDLE:
					continue
				var rect := Rect2(origin + Vector2(column * CELL, row * CELL), Vector2(CELL - 3.0, CELL - 3.0))
				draw_rect(rect, Color(0.2, 0.24, 0.3) if not is_hq_row else Color(0.3, 0.27, 0.18))
		var hq := Rect2(origin + Vector2((MIDDLE) * CELL, ROWS * CELL), Vector2(CELL - 3.0, CELL - 3.0))
		draw_string(font, hq.position + Vector2(5.0, 19.0), "将", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("ffd479"))
		draw_string(font, hq.position + Vector2(CELL + 4.0, 20.0), "本陣", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.68, 0.72, 0.78))
		draw_string(font, origin + Vector2(-44.0, 18.0), "前 ↑", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.68, 0.72, 0.78))
		for i in slots.size():
			var slot := slots[i]
			if slot.y > ROWS:
				continue
			var cell := Vector2(MIDDLE + slot.x, ROWS - slot.y)
			var rect := Rect2(origin + cell * CELL, Vector2(CELL - 3.0, CELL - 3.0))
			draw_rect(rect, Color("4f8fd8") if i == _selected else Color(0.32, 0.4, 0.52))
			var text := str(i + 1)
			draw_string(font, rect.position + Vector2(8.0 if text.length() == 1 else 3.0, 19.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
