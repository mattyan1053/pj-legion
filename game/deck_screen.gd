extends Node
## 部隊の編成の場面（docs/deck-screen.md）。取っておいた部隊の一覧と、1 つの部隊を組む画面の 2 つを、切り替えて出す。
## 背景は対戦と同じ景色（backdrop.gd）。場面の決まりは scene_flow.gd。取っておく先は context.decks（deck_library.gd）。
##
## - 一覧: 部隊を選び、組み直す・写す・名前を変える・消す（確かめる）。「新しく組む」で空の部隊を組む。
## - 組む画面: 軍を選び、雇える駒を押して部隊に足し、部隊の駒を選んで装備を持たせる。並べ替えで、置かれるところが変わる。
##   予算・合計・駒の数・出せない理由はいつも出す。出せない部隊は取っておけない。
## - 右クリックと Esc は「戻す」: 確かめ・名前の入力 → 駒の選択 → 組む画面（変えたところがあれば確かめる）→ 一覧 → タイトル。
## 組む画面の決まり（雇える駒、予算、数の上限）は、外から渡す（rules。いまは対戦の決まり）。

const AppContext := preload("res://game/app_context.gd")
const Backdrop := preload("res://game/backdrop.gd")
const DeckLibrary := preload("res://game/deck_library.gd")
const DeckText := preload("res://game/deck_text.gd")
const TextWrap := preload("res://game/text_wrap.gd")

## 「タイトルへ戻る」で &"back"。
signal finished(outcome: StringName)

const COLOR_PANEL := Color(0.07, 0.09, 0.12, 0.94)
const COLOR_CARD := Color(0.12, 0.15, 0.2, 1.0)
const COLOR_TEXT := Color(0.93, 0.94, 0.96)
const COLOR_DIM := Color(0.68, 0.72, 0.78)
const COLOR_GOOD := Color("7fdc8a")
const COLOR_BAD := Color("ff8a6b")
const COLOR_ACCENT := Color("8fc3ff")
const COLOR_BUDGET := Color("4f8fd8")
## 右上のシステムメニューのボタンのぶん、見出しの右を空ける。
const CORNER_ROOM := 120.0
## 詳しい中身の欄の、文を折り返す幅（px）。
const DETAIL_WIDTH := 440.0
const ROSTER_WIDTH := 300.0
const TROOP_WIDTH := 420.0

## 組む画面で使う決まり（雇える駒、予算、数の上限）。後で、ストーリーの決まりを渡せる（Issue #49）。
var rules: DeckRules = DeckRules.versus()
var context: AppContext

var _library: DeckLibrary
var _char_widths := {}

# ---- 一覧 ----
var _list_view: Control
var _list_rows: VBoxContainer
var _list_empty: Label
var _list_detail_title: Label
var _list_detail_body: Label
var _list_detail_issues: Label
var _list_actions: Array[Button] = []
var _list_selected := ""

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
var _army_buttons := {}
var _budget_bar: ProgressBar
var _budget_label: Label
var _count_label: Label
var _issues_label: Label
var _roster_buttons := {}
var _ult_label: Label
var _troop_rows: VBoxContainer
var _slots: Control
var _detail_title: Label
var _detail_body: Label
var _equip_box: VBoxContainer
var _equip_rows := {}
var _save_button: Button
var _save_note: Label

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
	shade.color = Color(0.0, 0.0, 0.0, 0.45)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(shade)
	_list_view = _build_list()
	layer.add_child(_list_view)
	_edit_view = _build_editor()
	layer.add_child(_edit_view)
	_dialog = _build_dialog()
	layer.add_child(_dialog)
	_library.changed.connect(_refresh_list)
	show_list()


# ==== 場面の決まり ====


func resume_label() -> String:
	return "編成へ戻る"


## 組んでいる途中で、取っておいていない変更があるか（タイトルへ戻る・ゲームを終える前に確かめる）。
func in_progress() -> bool:
	return is_editing() and _dirty


## 右クリックと Esc は「戻す」。重なる画面（システムメニュー）が開いている間は、そちらが受ける。
func _input(event: InputEvent) -> void:
	if context.overlays.is_open():
		return
	var right: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT
	var escape: bool = event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE
	if right or escape:
		get_viewport().set_input_as_handled()
		press_back()


## 1 つ戻す。確かめ・名前の入力 → 駒の選択 → 組む画面 → 一覧 → タイトル の順。
func press_back() -> void:
	if _dialog.visible:
		close_dialog()
	elif is_editing() and _selected != -1:
		select_entry(-1)
	elif is_editing():
		leave_editor()
	else:
		finished.emit(&"back")


# ==== 一覧 ====


func show_list(select_id := "") -> void:
	_edit_view.visible = false
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


## 「新しく組む」。空の部隊（いまの決まりの最初の軍）を組む画面へ。
func press_new() -> void:
	var armies := rules.armies()
	_open_editor("", _library.default_name(), Deck.new(armies[0] if not armies.is_empty() else UnitKind.Army.NONE, rules))


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
	_confirm("「%s」を消しますか？\n消した部隊は元に戻せない" % item.name, "消す", func() -> void:
		_library.remove(id)
		_list_selected = "")


func _build_list() -> Control:
	var root := _frame()
	var column := root.get_child(0).get_child(0) as VBoxContainer
	column.add_child(_header("部隊の編成", "取っておいた部隊。対戦の設定で、ここから選んで出撃する"))
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 20)
	column.add_child(body)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(560.0, 0.0)
	left.add_theme_constant_override("separation", 8)
	body.add_child(left)
	left.add_child(_caption("部隊（押して選ぶ）"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	_list_rows = VBoxContainer.new()
	_list_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_rows.add_theme_constant_override("separation", 6)
	scroll.add_child(_list_rows)
	_list_empty = _text(17, COLOR_DIM)
	_list_empty.text = "まだ部隊が無い。「新しく組む」で組む"
	left.add_child(_list_empty)
	var new_button := _button("新しく組む", 20)
	new_button.custom_minimum_size = Vector2(0.0, 52.0)
	new_button.pressed.connect(press_new)
	left.add_child(new_button)

	var right := _card()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)
	var detail := VBoxContainer.new()
	detail.add_theme_constant_override("separation", 10)
	right.add_child(detail)
	_list_detail_title = _text(24, COLOR_TEXT)
	detail.add_child(_list_detail_title)
	_list_detail_body = _text(16, COLOR_TEXT)
	detail.add_child(_list_detail_body)
	_list_detail_issues = _text(16, COLOR_BAD)
	detail.add_child(_list_detail_issues)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_child(spacer)
	var actions := GridContainer.new()
	actions.columns = 2
	actions.add_theme_constant_override("h_separation", 10)
	actions.add_theme_constant_override("v_separation", 10)
	detail.add_child(actions)
	for spec: Array in [["組み直す", press_edit], ["写す", press_duplicate], ["名前を変える", press_rename], ["消す", press_delete]]:
		var button := _button(spec[0], 18)
		button.custom_minimum_size = Vector2(200.0, 46.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(spec[1])
		actions.add_child(button)
		_list_actions.append(button)

	var footer := HBoxContainer.new()
	column.add_child(footer)
	var back := _button("タイトルへ戻る", 18)
	back.custom_minimum_size = Vector2(220.0, 46.0)
	back.pressed.connect(func() -> void: finished.emit(&"back"))
	footer.add_child(back)
	return root


func _refresh_list() -> void:
	if _list_rows == null or not _list_view.visible:
		return
	for child in _list_rows.get_children():
		_list_rows.remove_child(child)
		child.queue_free()
	var items := _library.items()
	if _library.find(_list_selected) == null:
		_list_selected = items[0].id if not items.is_empty() else ""
	for item in items:
		var button := _button("", 16)
		button.toggle_mode = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0.0, 58.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var state := "出撃できる" if item.playable() else "出せない: " + item.issues()[0]
		button.text = "%s\n%s・%d 体・コスト %d / %d　%s" % [
			item.name, DeckText.army_name(item.deck.army), item.deck.entries.size(),
			item.deck.total_cost(), item.deck.budget(), state,
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
	for button in _list_actions:
		button.disabled = chosen == null
	if chosen == null:
		_list_detail_title.text = "部隊を選ぶと、中身がここに出る"
		_list_detail_title.add_theme_color_override("font_color", COLOR_DIM)
		_list_detail_body.text = ""
		_list_detail_issues.text = ""
		return
	_list_detail_title.text = chosen.name
	_list_detail_title.add_theme_color_override("font_color", COLOR_TEXT)
	var lines: Array[String] = [
		"%s（決まり: %s）　コスト %d / 予算 %d" % [
			DeckText.army_name(chosen.deck.army), chosen.deck.rules.display_name, chosen.deck.total_cost(), chosen.deck.budget(),
		],
		"",
		"将（自動で加わる）",
	]
	for i in chosen.deck.entries.size():
		var entry := chosen.deck.entries[i]
		var equipment := DeckText.equipment_short(entry.equipment)
		lines.append("%d. %s%s" % [i + 1, UnitKind.display_name(entry.kind), "（%s）" % equipment if equipment != "" else ""])
	_fold(_list_detail_body, "\n".join(lines), DETAIL_WIDTH + 100.0)
	var issues := chosen.issues()
	_fold(_list_detail_issues, "出撃できる" if issues.is_empty() else "出せない:\n・" + "\n・".join(issues), DETAIL_WIDTH + 100.0)
	_list_detail_issues.add_theme_color_override("font_color", COLOR_GOOD if issues.is_empty() else COLOR_BAD)


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


## 軍を選ぶ。駒がいれば、外れることを確かめてから変える。
func choose_army(army: UnitKind.Army) -> void:
	if army == _deck.army or not rules.armies().has(army):
		_refresh_editor()
		return
	if _deck.entries.is_empty():
		_set_army(army)
		return
	_refresh_editor()  # 確かめている間、ボタンは元の軍のまま
	_confirm("軍を %s に変えますか？\nいまの駒は外れる（雇える駒が違うため）" % DeckText.army_name(army), "変える", func() -> void: _set_army(army))


func _set_army(army: UnitKind.Army) -> void:
	_deck = Deck.new(army, rules)
	_selected = -1
	_dirty = true
	_refresh_editor()


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
func equip(item: Equipment.Id) -> void:
	if _selected == -1 or not _deck.entries[_selected].equip(item):
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


## 「取っておく」。出せない部隊なら何もしない（理由は出ている）。取っておいたら一覧へ戻り、その部隊を選ぶ。
func press_save() -> void:
	if not can_save():
		return
	var id := _editing_id
	if id == "" or _library.find(id) == null:
		id = _library.add(_deck_name, _deck).id
	else:
		_library.replace(id, _deck_name, _deck)
	_dirty = false
	show_list(id)


## 組む画面を抜けて一覧へ。取っておいていない変更があれば、確かめる。
func leave_editor() -> void:
	if not _dirty:
		show_list(_editing_id)
		return
	_confirm("取っておかずに一覧へ戻りますか？\n変えたところは失われる", "戻る", func() -> void:
		_dirty = false
		show_list(_editing_id))


func _build_editor() -> Control:
	var root := _frame()
	var column := root.get_child(0).get_child(0) as VBoxContainer

	# 見出し: 名前、軍
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	column.add_child(header)
	var title := _text(26, COLOR_TEXT)
	title.text = "部隊を組む"
	header.add_child(title)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(10.0, 0.0)
	header.add_child(gap)
	_name_label = _text(22, COLOR_ACCENT)
	header.add_child(_name_label)
	var rename := _button("名前を変える", 15)
	rename.pressed.connect(press_rename_editing)
	header.add_child(rename)
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(fill)
	header.add_child(_caption("軍"))
	for army in rules.armies():
		var button := _button(DeckText.army_name(army), 17)
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(130.0, 40.0)
		button.pressed.connect(func() -> void: choose_army(army))
		header.add_child(button)
		_army_buttons[army] = button
	var corner := Control.new()
	corner.custom_minimum_size = Vector2(CORNER_ROOM, 0.0)
	header.add_child(corner)

	# 予算と数と理由
	var status := _card()
	column.add_child(status)
	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 18)
	status.add_child(status_row)
	_budget_label = _text(19, COLOR_TEXT)
	_budget_label.custom_minimum_size = Vector2(190.0, 0.0)
	status_row.add_child(_budget_label)
	_budget_bar = ProgressBar.new()
	_budget_bar.show_percentage = false
	_budget_bar.custom_minimum_size = Vector2(220.0, 16.0)
	_budget_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	status_row.add_child(_budget_bar)
	_count_label = _text(19, COLOR_TEXT)
	_count_label.custom_minimum_size = Vector2(250.0, 0.0)
	status_row.add_child(_count_label)
	_issues_label = _text(17, COLOR_BAD)
	_issues_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_row.add_child(_issues_label)

	# 3 つの列: 雇える駒、部隊、中身
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	column.add_child(body)

	var roster := VBoxContainer.new()
	roster.custom_minimum_size = Vector2(ROSTER_WIDTH, 0.0)
	roster.add_theme_constant_override("separation", 8)
	body.add_child(roster)
	roster.add_child(_caption("雇える駒（押すと部隊の最後に入る）"))
	for i in 4:
		var button := _button("", 15)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(ROSTER_WIDTH, 62.0)
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
	troop.add_child(_caption("部隊（押して選ぶ。上から順に本陣の前へ置く）"))
	troop.add_child(_king_row())
	# 部隊の並びは、決まりの上限が大きくても画面の下へはみ出さないよう、列の残りの高さの中で送れるようにする。
	var troop_scroll := ScrollContainer.new()
	troop_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	troop_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	troop.add_child(troop_scroll)
	_troop_rows = VBoxContainer.new()
	_troop_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_troop_rows.add_theme_constant_override("separation", 3)
	troop_scroll.add_child(_troop_rows)
	_slots = SlotMap.new()
	_slots.custom_minimum_size = Vector2(TROOP_WIDTH, 106.0)
	troop.add_child(_slots)

	var detail := _card()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(detail)
	# 中身が長い駒でも、画面の下へはみ出さないよう、欄の中で送れるようにする。
	var detail_scroll := ScrollContainer.new()
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail.add_child(detail_scroll)
	var detail_column := VBoxContainer.new()
	detail_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_column.add_theme_constant_override("separation", 8)
	detail_scroll.add_child(detail_column)
	_detail_title = _text(22, COLOR_TEXT)
	detail_column.add_child(_detail_title)
	_detail_body = _text(15, COLOR_TEXT)
	detail_column.add_child(_detail_body)
	_equip_box = VBoxContainer.new()
	_equip_box.add_theme_constant_override("separation", 6)
	detail_column.add_child(_equip_box)
	_equip_box.add_child(_caption("装備（1 体 %d 個まで。同じものを重ねて持てる）" % Equipment.MAX_PER_UNIT))
	for item: Equipment.Id in Equipment.Id.values():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_equip_box.add_child(row)
		var label := _text(15, COLOR_TEXT)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.text = "%s（コスト %d）　%s" % [Equipment.display_name(item), Equipment.cost(item), DeckText.equipment_effect(item)]
		row.add_child(label)
		var minus := _button("−", 18)
		minus.custom_minimum_size = Vector2(40.0, 36.0)
		minus.pressed.connect(func() -> void: unequip(item))
		row.add_child(minus)
		var count := _text(18, COLOR_TEXT)
		count.custom_minimum_size = Vector2(28.0, 0.0)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(count)
		var plus := _button("＋", 18)
		plus.custom_minimum_size = Vector2(40.0, 36.0)
		plus.pressed.connect(func() -> void: equip(item))
		row.add_child(plus)
		_equip_rows[item] = [minus, count, plus]

	# 下: 戻る、取っておく
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 14)
	column.add_child(footer)
	var back := _button("一覧へ戻る", 18)
	back.custom_minimum_size = Vector2(200.0, 48.0)
	back.pressed.connect(leave_editor)
	footer.add_child(back)
	var footer_fill := Control.new()
	footer_fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(footer_fill)
	_save_note = _text(16, COLOR_BAD)
	_save_note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(_save_note)
	_save_button = _button("取っておく", 20)
	_save_button.custom_minimum_size = Vector2(240.0, 48.0)
	_save_button.pressed.connect(press_save)
	footer.add_child(_save_button)
	return root


func _refresh_editor() -> void:
	if _deck == null:
		return
	_name_label.text = _deck_name + ("（変更あり）" if _dirty else "")
	for army: UnitKind.Army in _army_buttons:
		(_army_buttons[army] as Button).set_pressed_no_signal(army == _deck.army)

	var total := _deck.total_cost()
	var budget := _deck.budget()
	_budget_label.text = "コスト %d / 予算 %d" % [total, budget]
	_budget_label.add_theme_color_override("font_color", COLOR_BAD if total > budget else COLOR_TEXT)
	_budget_bar.max_value = maxi(budget, 1)
	_budget_bar.value = mini(total, budget)
	var fill := StyleBoxFlat.new()
	fill.bg_color = COLOR_BAD if total > budget else COLOR_BUDGET
	_budget_bar.add_theme_stylebox_override("fill", fill)
	var count := _deck.entries.size()
	_count_label.text = "駒 %d / %d 体（将は自動で加わる）" % [count, _deck.rules.max_units]
	var issues := DeckText.problem_texts(_deck)
	_issues_label.text = "出撃できる" if issues.is_empty() else "出せない: " + "、".join(issues)
	_issues_label.add_theme_color_override("font_color", COLOR_GOOD if issues.is_empty() else COLOR_BAD)

	var kinds := _deck.available_kinds()
	var full := count >= _deck.rules.max_units
	for i: int in _roster_buttons:
		var button: Button = _roster_buttons[i]
		button.visible = i < kinds.size()
		if i >= kinds.size():
			continue
		var kind := kinds[i]
		button.text = "%s　%s　コスト %d\n%s" % [
			UnitKind.display_name(kind), DeckText.role_name(kind), UnitKind.cost(kind), DeckText.stats_line(kind),
		]
		button.disabled = full
		button.tooltip_text = "%d 体まで" % _deck.rules.max_units if full else ""
	var ult := Ults.of_army(_deck.army) if _deck.army != UnitKind.Army.NONE else null
	if ult != null:
		_fold(_ult_label, "この軍の必殺技: %s\n%s" % [ult.display_name(), ult.summary()], ROSTER_WIDTH - 24.0)
	_ult_label.get_parent().visible = ult != null

	for child in _troop_rows.get_children():
		_troop_rows.remove_child(child)
		child.queue_free()
	for i in count:
		_troop_rows.add_child(_troop_row(i))
	if count == 0:
		var empty := _text(15, COLOR_DIM)
		empty.text = "左の駒を押して雇う"
		_troop_rows.add_child(empty)
	(_slots as SlotMap).show_slots(count, _selected)

	_refresh_detail()
	_save_button.disabled = not can_save()
	_save_note.text = "" if can_save() else "出せない部隊は取っておけない"


func _king_row() -> Control:
	var row := HBoxContainer.new()
	var label := _text(15, COLOR_DIM)
	label.text = "　　将（本陣に置く。自動で加わる。コスト 0）"
	label.custom_minimum_size = Vector2(0.0, 24.0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	return row


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
	var main := _button("", 14)
	main.toggle_mode = true
	main.alignment = HORIZONTAL_ALIGNMENT_LEFT
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.custom_minimum_size = Vector2(0.0, 42.0)
	# 装備の文が長くても、列の幅を広げない。収まらないぶんは「…」にして、全文はマウスを乗せると出す。
	main.clip_text = true
	main.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var equipment := DeckText.equipment_short(entry.equipment)
	main.text = "%s　コスト %d\n%s" % [
		UnitKind.display_name(entry.kind), entry.cost(), equipment if equipment != "" else "装備なし",
	]
	main.tooltip_text = main.text
	main.set_pressed_no_signal(index == _selected)
	main.pressed.connect(func() -> void: select_entry(-1 if _selected == index else index))
	row.add_child(main)
	for spec: Array in [["▲", -1, index > 0], ["▼", 1, index < _deck.entries.size() - 1]]:
		var step: int = spec[1]
		var move := _button(spec[0], 14)
		move.custom_minimum_size = Vector2(36.0, 42.0)
		move.disabled = not spec[2]
		move.tooltip_text = "上へ（先に置く）" if step < 0 else "下へ（後に置く）"
		move.pressed.connect(func() -> void: move_entry(index, step))
		row.add_child(move)
	var remove := _button("外す", 14)
	remove.custom_minimum_size = Vector2(52.0, 42.0)
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


## 中身の欄。マウスを乗せている雇える駒 → 選んでいる部隊の駒 の順に出す。どちらも無ければ案内。
func _refresh_detail() -> void:
	var entry: DeckEntry = _deck.entries[_selected] if _selected != -1 else null
	var kind := -1
	if _hover_kind != -1:
		kind = _hover_kind
		entry = null
	elif entry != null:
		kind = entry.kind
	_equip_box.visible = entry != null
	if kind == -1:
		_detail_title.text = "駒の中身"
		_detail_title.add_theme_color_override("font_color", COLOR_DIM)
		_fold(_detail_body, "雇える駒にマウスを乗せるか、部隊の駒を押すと、ここに中身が出る。\n部隊の駒を選ぶと、装備を持たせられる。", DETAIL_WIDTH)
		return
	_detail_title.add_theme_color_override("font_color", COLOR_TEXT)
	var unit_kind := kind as UnitKind.Id
	var title := UnitKind.display_name(unit_kind)
	if entry != null:
		title = "%d. %s" % [_selected + 1, title]
	_detail_title.text = title
	var role := UnitKind.role(unit_kind)
	var lines: Array[String] = [
		"%s　コスト %d　%s" % [DeckText.role_name(unit_kind), UnitKind.cost(unit_kind), DeckText.ROLE_NOTES.get(role, "")],
		DeckText.stats_line(unit_kind),
	]
	if entry != null and not entry.equipment.is_empty():
		lines.append("装備込み: " + DeckText.stats_line(unit_kind, DeckText.equipment_bonus(entry.equipment)))
	var skill := DeckText.skill_text(unit_kind)
	if skill != "":
		lines.append("")
		lines.append("スキル: " + skill)
	var evolutions := DeckText.evolution_lines(unit_kind)
	if not evolutions.is_empty():
		lines.append("")
		lines.append("進化先（レベル %d で、どちらかを選ぶ）" % Growth.MAX_LEVEL)
		for line in evolutions:
			lines.append("・" + line)
	_fold(_detail_body, "\n".join(lines), DETAIL_WIDTH)
	if entry != null:
		var full := entry.equipment.size() >= Equipment.MAX_PER_UNIT
		for item: Equipment.Id in _equip_rows:
			var parts: Array = _equip_rows[item]
			(parts[0] as Button).disabled = entry.count(item) == 0
			(parts[1] as Label).text = str(entry.count(item))
			(parts[2] as Button).disabled = full
			(parts[2] as Button).tooltip_text = "1 体 %d 個まで" % Equipment.MAX_PER_UNIT if full else ""


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
	_dialog_input.visible = false
	_dialog_action = action
	_dialog.visible = true


func _ask_name(title: String, current: String, action: Callable) -> void:
	_dialog_text.text = "%s（%d 文字まで）" % [title, DeckLibrary.MAX_NAME_LENGTH]
	_dialog_ok.text = "決める"
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
	shade.color = Color(0.0, 0.0, 0.0, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := _card(Color(0.09, 0.11, 0.15, 0.98), 24.0)
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
	for side: String in ["left", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	margin.add_theme_constant_override("margin_top", 8)
	var panel := _card(COLOR_PANEL, 14.0)
	margin.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	return margin


func _header(title: String, note: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	var label := _text(26, COLOR_TEXT)
	label.text = title
	row.add_child(label)
	var sub := _text(16, COLOR_DIM)
	sub.text = note
	sub.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(sub)
	return row


func _card(color := COLOR_CARD, margin := 12.0) -> PanelContainer:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(6)
	style.set_content_margin_all(margin)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
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
		var caption := "置かれるところ（本陣の前。入れないマスは飛ばす）"
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
		draw_string(font, origin + Vector2(-58.0, 18.0), "敵の側 ↑", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.68, 0.72, 0.78))
		for i in slots.size():
			var slot := slots[i]
			if slot.y > ROWS:
				continue
			var cell := Vector2(MIDDLE + slot.x, ROWS - slot.y)
			var rect := Rect2(origin + cell * CELL, Vector2(CELL - 3.0, CELL - 3.0))
			draw_rect(rect, Color("4f8fd8") if i == _selected else Color(0.32, 0.4, 0.52))
			var text := str(i + 1)
			draw_string(font, rect.position + Vector2(8.0 if text.length() == 1 else 3.0, 19.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
