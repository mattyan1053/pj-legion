extends "res://game/deck_screen/deck_list.gd"
## 部隊編成の、1 つの部隊を組む画面（雇う・並べ替える・外す、部隊の特徴と誓い、持ち物、予算と出せない理由、取っておく）。


func _open_editor(id: String, name: String, deck: Deck) -> void:
	_editing_id = id
	_deck_name = name
	_deck = deck
	_dirty = false
	_selected = -1
	_binding = -1
	_hover_kind = -1
	_hover_trait = Traits.NONE
	_list_view.visible = false
	_army_view.visible = false  # 軍を選んだあとの組む画面の後ろに、軍の札を透かして残さない
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
	return [main.get_meta(&"row_text", ""), main.tooltip_text]


## 部隊の index 番目の行のボタンの文（検査用）。
func troop_row_button_texts(index: int) -> Array[String]:
	var texts: Array[String] = []
	for child in _troop_rows.get_child(index).get_children():
		if child is Button:
			texts.append((child as Button).text)
	return texts


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
	_binding = -1
	_deck.remove(_deck.entries[index])
	if _selected == index:
		_selected = -1
	elif _selected > index:
		_selected -= 1
	_dirty = true
	_refresh_editor()


## 部隊の特徴を id にする（その軍の特徴だけ。docs/troop-traits.md）。誓いから替えても、結んだ組は残す（誓いに戻すと、また効く）。
func choose_trait(id: int) -> void:
	if not shows_traits() or not Traits.of_army(_deck.army).has(id) or _deck.trait_id == id:
		return
	_deck.trait_id = id
	_binding = -1
	_dirty = true
	_refresh_editor()


## 部隊の特徴の欄を出す部隊か（対戦用の部隊だけ。ストーリー用の部隊は、話のファイルが特徴を決める）。
func shows_traits() -> bool:
	return _deck != null and _deck.rules.id == DeckRules.VERSUS and not Traits.of_army(_deck.army).is_empty()


## 特徴の札の index 番目にマウスを乗せたことにする（-1 で離す。検査とスクリーンショットの道具用）。
func hover_trait_card(index: int) -> void:
	if index < 0:
		_on_trait_card(0, &"exit")
	else:
		_on_trait_card(index, &"enter")


## 部隊の特徴の欄の文（検査用。出ていなければ空）。
func trait_text() -> String:
	return _trait_label.text if _trait_box.visible else ""


## 誓いを結ぶ操作が出ているか（特徴が誓いの部隊だけ）。
func shows_oaths() -> bool:
	return shows_traits() and _deck.trait_id == Traits.Id.OATH


## 部隊の index 番目の駒の「誓い」を押した（特徴が誓いの、対戦用の部隊だけ。docs/troop-traits.md）。
## 結んでいれば、ほどく。結んでいなければ、結ぶ相手を選び始める。選んでいる間に、ほかの駒の「誓い」を押すと、2 体を結ぶ（同じ駒なら、やめる）。
func press_oath(index: int) -> void:
	if not shows_oaths() or index < 0 or index >= _deck.entries.size():
		return
	var entry := _deck.entries[index]
	if _binding == -1:
		if _deck.unbind(entry):
			_dirty = true
		elif _deck.oaths.size() < Traits.MAX_OATHS:
			_binding = index
	elif _binding == index:
		_binding = -1
	else:
		if _deck.bind(_deck.entries[_binding], entry):
			_dirty = true
		_binding = -1
	_refresh_editor()


## 誓いで結ぶ相手を選んでいるか（その駒の番号。選んでいなければ -1）。検査用。
func binding_entry() -> int:
	return _binding


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
	_ask_name(Text.t("deck.name.title"), _deck_name, func(name: String) -> void:
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
	_confirm(Text.t("deck.leave.confirm"), Text.t("deck.leave.discard"), func() -> void:
		_dirty = false
		show_list(_editing_id))


func _build_editor() -> Control:
	var root := _frame()
	var column := root.get_child(0).get_child(0) as VBoxContainer

	# 見出し: 名前、軍、コスト、駒の数（いつも見える）
	_edit_decor = NationDecor.new(UnitKind.Army.NONE, 0.0, 64.0)
	(column.get_parent() as Control).add_child(_edit_decor)
	(column.get_parent() as Control).move_child(_edit_decor, 0)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	column.add_child(header)
	_army_crest = Crest.new(UnitKind.Army.MILITARY, 36.0)
	_army_crest.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_army_crest)
	_name_label = _text(24, COLOR_ACCENT)
	_name_label.add_theme_font_override("font", UiTheme.FONT_HEADING)
	_name_label.custom_minimum_size = Vector2(250.0, 0.0)
	_name_label.clip_text = true
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header.add_child(_name_label)
	var rename := _button(Text.t("deck.list.rename"), 15)
	rename.pressed.connect(press_rename_editing)
	header.add_child(rename)
	_army_label = _text(20, COLOR_TEXT)
	_army_label.add_theme_font_override("font", UiTheme.FONT_BOLD)
	_army_label.custom_minimum_size = Vector2(130.0, 0.0)
	_army_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(_army_label)
	_budget_label = _text(20, COLOR_TEXT)
	_budget_label.custom_minimum_size = Vector2(150.0, 0.0)
	_budget_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(_budget_label)
	# コストは、宝石の目盛りで見せる（上限ぶんの溝に、使ったぶんの金の宝石。超えたら危険の色）。
	_budget_gauge = CostGems.new(0, 1, 9.0, GAUGE_WIDTH)
	header.add_child(_budget_gauge)
	_count_label = _text(20, COLOR_TEXT)
	_count_label.custom_minimum_size = Vector2(110.0, 0.0)
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(_count_label)
	var header_fill := Control.new()
	header_fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_fill)

	# 3 つの列: 雇える駒、部隊、選んだ駒（札と持ち物）
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	column.add_child(body)

	var roster := VBoxContainer.new()
	roster.custom_minimum_size = Vector2(ROSTER_WIDTH, 0.0)
	roster.add_theme_constant_override("separation", 6)
	body.add_child(roster)
	roster.add_child(_caption(Text.t("deck.edit.roster")))
	for i in 4:
		var button := _card_button("", 15)
		button.custom_minimum_size = Vector2(ROSTER_WIDTH, 66.0)
		_fill_roster_button(button)
		button.pressed.connect(func() -> void: _on_roster(i, &"press"))
		button.mouse_entered.connect(func() -> void: _on_roster(i, &"enter"))
		button.mouse_exited.connect(func() -> void: _on_roster(i, &"exit"))
		roster.add_child(button)
		_roster_buttons[i] = button
	var ult_card := _card()
	roster.add_child(ult_card)
	_ult_box = VBoxContainer.new()
	ult_card.add_child(_ult_box)
	roster.add_child(_build_trait_box())

	var troop := VBoxContainer.new()
	troop.custom_minimum_size = Vector2(TROOP_WIDTH, 0.0)
	troop.add_theme_constant_override("separation", 6)
	body.add_child(troop)
	troop.add_child(_caption(Text.t("deck.edit.troop")))
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
	# 初期位置は部隊では決めない（マップを選んだあと、出撃準備・対戦設定で決める）。部隊は駒と持ち物の組だけ。

	# 右: 選んだ駒の札（上）と、その駒の持ち物の欄（下）。別々の枠に分ける。
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", RIGHT_GAP)
	body.add_child(right)
	_right = right
	right.resized.connect(_fit_equip)
	_detail_card = _card()
	_detail_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# 持ち物が多くても、駒の札はこの高さを割らない（持ち物の欄のほうを、欄の中で送る。_fit_equip）。
	_detail_card.custom_minimum_size = Vector2(0.0, DETAIL_MIN_HEIGHT)
	Steady.mark(_detail_card, "decks.unit_card", Steady.RECT)
	right.add_child(_detail_card)
	# 中身が長い駒でも、画面の下へはみ出さないよう、札の中で送れるようにする。
	var detail_scroll := ScrollContainer.new()
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail_card.add_child(detail_scroll)
	var detail_column := VBoxContainer.new()
	detail_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_column.add_theme_constant_override("separation", 6)
	detail_scroll.add_child(detail_column)
	# 札は、小さなステータス画面（unit_summary.gd。額、名前と役割の札、能力値の棒と粒、スキルと進化先の札）。
	_detail_summary = UnitSummary.new(DETAIL_WIDTH - 24.0)
	detail_column.add_child(_detail_summary)
	# 「詳細」: 選んでいる部隊の駒のステータスの窓（unit_detail.gd）。札の頭の下の、飾りの線の右（名前や札に重ならない所）。
	_detail_open = Button.new()
	_detail_open.text = Text.t("battle.hud.detail")
	_detail_open.theme_type_variation = UiTheme.BUTTON_GHOST
	_detail_open.focus_mode = Control.FOCUS_NONE
	_detail_open.add_theme_font_size_override("font_size", 14)
	_detail_open.custom_minimum_size = Vector2(72.0, 26.0)
	_detail_open.pressed.connect(press_unit_detail)
	_detail_summary.corner().add_child(_detail_open)
	_equip_box = _card()
	Steady.mark(_equip_box, "decks.items", Steady.RECT)
	right.add_child(_equip_box)
	var equip_column := VBoxContainer.new()
	equip_column.add_theme_constant_override("separation", 6)
	_equip_box.add_child(equip_column)
	_equip_title = _text(16, COLOR_ACCENT)
	_equip_title.add_theme_font_override("font", UiTheme.FONT_BOLD)
	equip_column.add_child(_equip_title)
	# 行は、欄の中で縦に送れる入れ物に並べる（多いときだけ送りの棒が出る）。
	_equip_scroll = ScrollContainer.new()
	_equip_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	equip_column.add_child(_equip_scroll)
	_equip_list = VBoxContainer.new()
	_equip_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_equip_list.add_theme_constant_override("separation", 4)
	_equip_scroll.add_child(_equip_list)
	for item: Equipment.Id in Equipment.Id.values():
		var row := HBoxContainer.new()
		row.visible = false  # 決まりが並べる持ち物だけを見せる（_show_detail）
		row.add_theme_constant_override("separation", 8)
		_equip_list.add_child(row)
		# 持ち物の印は、沈んだ小さな額に入れる（駒の額と同じ向き）。
		var slot := PanelContainer.new()
		slot.add_theme_stylebox_override("panel", UiTheme.box(Color(Palette.INK, 0.85), Palette.BORDER, 1, 6, 4.0))
		slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slot.add_child(ItemIcon.new(item, 28.0))
		row.add_child(slot)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 0)
		row.add_child(info)
		var name_row := HBoxContainer.new()
		name_row.add_theme_constant_override("separation", 6)
		info.add_child(name_row)
		var item_name := _text(16, COLOR_TEXT)
		item_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		item_name.clip_text = true
		item_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_row.add_child(item_name)
		var effect := _text(14, COLOR_DIM)
		effect.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS  # 長い効果で欄を広げない（全文は行のツールチップ）
		effect.clip_text = true
		info.add_child(effect)
		var minus := _button("−", 18)
		minus.custom_minimum_size = Vector2(36.0, 34.0)
		minus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		minus.pressed.connect(func() -> void: unequip(item))
		row.add_child(minus)
		var count := _text(18, COLOR_TEXT)
		count.add_theme_font_override("font", UiTheme.FONT_BOLD)
		count.custom_minimum_size = Vector2(24.0, 0.0)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(count)
		var plus := _button(Text.t("deck.edit.plus"), 18)
		plus.custom_minimum_size = Vector2(36.0, 34.0)
		plus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		plus.pressed.connect(func() -> void: equip(item))
		row.add_child(plus)
		_equip_rows[item] = [minus, count, plus, item_name, effect, row]

	# 下: 戻る、編成完了
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 14)
	column.add_child(footer)
	var back := _button(Text.t("common.back"), 18)
	back.custom_minimum_size = Vector2(200.0, 48.0)
	back.pressed.connect(leave_editor)
	footer.add_child(back)
	# 出撃不可の理由は、押せない「編成完了」の左に出す（見出しの行は、名前・軍・コスト・駒の数で埋まり、理由が切れるため）。
	_issues_label = _text(16, COLOR_BAD)
	_issues_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_issues_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_issues_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_issues_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_issues_label.clip_text = true
	_issues_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	footer.add_child(_issues_label)
	_save_button = _button(Text.t("deck.edit.save"), 20)
	_save_button.custom_minimum_size = Vector2(240.0, 48.0)
	_save_button.set_meta(&"sound", &"ui_confirm")
	_save_button.theme_type_variation = UiTheme.BUTTON_PRIMARY
	_save_button.pressed.connect(press_save)
	footer.add_child(_save_button)
	return root


## 出撃不可の理由が、切れずに全部見えているか。検査用。
func issues_shown_whole() -> bool:
	var font := _issues_label.get_theme_font(&"font")
	var width := font.get_string_size(_issues_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, _issues_label.get_theme_font_size(&"font_size")).x
	return _issues_label.is_visible_in_tree() and width <= _issues_label.size.x + 0.5


func _refresh_editor() -> void:
	if _deck == null:
		return
	_name_label.text = _deck_name + ("*" if _dirty else "")
	_army_label.text = DeckText.army_name(_deck.army)
	_army_label.add_theme_color_override("font_color", COLOR_TEXT if _deck.army == UnitKind.Army.NONE else Crest.color_of(_deck.army).lightened(0.25))
	_army_crest.army = _deck.army
	_army_crest.modulate.a = 0.0 if _deck.army == UnitKind.Army.NONE else 1.0
	_army_crest.queue_redraw()
	_edit_decor.army = _deck.army

	var total := _deck.total_cost()
	var budget := _deck.budget()
	_budget_label.text = Text.t("deck.edit.cost", {"total": total, "budget": budget})
	_budget_label.add_theme_color_override("font_color", COLOR_BAD if total > budget else COLOR_TEXT)
	# コスト上限を超えたら、目盛りの宝石がみな危険の色になる。
	_budget_gauge.slots = maxi(budget, 1)
	_budget_gauge.count = total
	var count := _deck.entries.size()
	_count_label.text = Text.t("deck.edit.count", {"count": count, "max": _deck.rules.max_units})
	var issues := DeckText.problem_texts(_deck)
	_issues_label.text = "" if issues.is_empty() else Text.t("deck.unplayable", {"issues": Text.join_comma(issues)})
	_issues_label.tooltip_text = _issues_label.text
	# 出撃不可の理由は、危険の色の帯に載せる（理由が無ければ帯も出さない。場所は保つ）。
	if issues.is_empty():
		_issues_label.remove_theme_stylebox_override("normal")
	else:
		_issues_label.add_theme_stylebox_override("normal", UiTheme.danger_strip_box())

	var kinds := _deck.available_kinds()
	var full := count >= _deck.rules.max_units
	for i: int in _roster_buttons:
		var button: Button = _roster_buttons[i]
		button.visible = i < kinds.size()
		if i >= kinds.size():
			continue
		var kind := kinds[i]
		button.set_meta(&"kind", kind)
		_show_roster_unit(button, kind)
		button.disabled = full
		(button.get_meta(&"inside") as Control).modulate.a = 0.5 if full else 1.0
		button.tooltip_text = Text.t("deck.edit.full", {"max": _deck.rules.max_units}) if full else ""
	var ult := Ults.of_army(_deck.army) if _deck.army != UnitKind.Army.NONE else null
	var ult_text := "" if ult == null else Text.t("deck.ult", {"name": Names.ult(ult), "summary": Names.ult_summary(ult)})
	if _ult_box.get_meta(&"text", "") != ult_text:
		_ult_box.set_meta(&"text", ult_text)
		for child in _ult_box.get_children():
			_ult_box.remove_child(child)
			child.queue_free()
		if ult != null:
			_ult_box.add_child(_ult_lines(ult_text, ROSTER_WIDTH - 24.0, 14))
	_ult_box.get_parent().visible = ult != null

	for child in _troop_rows.get_children():
		_troop_rows.remove_child(child)
		child.queue_free()
	for i in count:
		_troop_rows.add_child(_troop_row(i))
	if count == 0:
		var empty := _text(16, COLOR_DIM)
		empty.text = Text.t("deck.edit.no_units")
		_troop_rows.add_child(empty)
	if shows_oaths() and count > 0:
		# 誓いの組（か、結ぶ相手を選んでいること）を、部隊の並びの下に 1 行。
		var oaths := _text(13, Palette.NATION_FANTASY.lightened(0.3))
		oaths.text = TraitText.oath_text(_deck, _binding)
		_troop_rows.add_child(oaths)

	_refresh_traits()
	_refresh_detail()
	_save_button.disabled = not can_save()


func _king_row() -> Control:
	var row := _card()
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	row.add_child(line)
	line.add_child(UnitFrame.new(UnitKind.Id.KING, 0, 36.0, false))
	# 「将　HP 30　攻撃 8 …」を、名前と能力値の欄に分けて出す。
	var parts := Text.t("deck.edit.king", {"stats": DeckText.stats_line(UnitKind.Id.KING)}).split(char(0x3000), true, 1)
	var label := _text(16, COLOR_TEXT)
	label.add_theme_font_override("font", UiTheme.FONT_BOLD)
	label.text = parts[0]
	label.custom_minimum_size = Vector2(36.0, 0.0)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(label)
	if parts.size() > 1:
		var stats := StatsRow.new(parts[1], 14, 76.0)
		stats.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(stats)
	return row


## 部隊の index 番目の駒の行: 番号、駒の札（名前・役割・コストと持ち物。押して選ぶ）、並べ替え、外す。
func _troop_row(index: int) -> Control:
	var entry := _deck.entries[index]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var chosen := index == _selected
	var number := _text(14, COLOR_ACCENT if chosen else COLOR_DIM)
	number.add_theme_font_override("font", UiTheme.FONT_BOLD)
	number.text = str(index + 1)
	number.custom_minimum_size = Vector2(24.0, 24.0)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	number.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var badge := UiTheme.number_box()
	if chosen:
		badge.border_color = Palette.ACCENT
	number.add_theme_stylebox_override("normal", badge)
	row.add_child(number)
	var main := _card_button("", 14)
	main.toggle_mode = true
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.custom_minimum_size = Vector2(0.0, 50.0)
	var equipment := Text.join_comma(UnitCard.equipment_lines(entry.equipment))
	var text := Text.t("deck.edit.troop_unit", {
		"unit": Names.kind(entry.kind), "cost": entry.cost(), "items": equipment if equipment != "" else Text.t("deck.edit.no_items"),
	})
	main.set_meta(&"row_text", text)
	main.tooltip_text = text
	# 札の中身: 駒の額、名前とコスト、持ち物（印つき。収まらないぶんは「…」。全文はマウスを乗せると出る）、右にコストの宝石。
	var inside := HBoxContainer.new()
	inside.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inside.offset_left = 8.0
	inside.offset_right = -10.0
	inside.add_theme_constant_override("separation", 8)
	inside.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main.add_child(inside)
	var frame := UnitFrame.new(entry.kind, 0, 38.0)
	frame.chosen = chosen
	inside.add_child(frame)
	var lines := VBoxContainer.new()
	lines.alignment = BoxContainer.ALIGNMENT_CENTER
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lines.add_theme_constant_override("separation", 0)
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inside.add_child(lines)
	var parts := text.split("\n", true, 1)
	var name_label := _text(15, COLOR_ACCENT if chosen else COLOR_TEXT)
	name_label.add_theme_font_override("font", UiTheme.FONT_BOLD)
	name_label.text = parts[0]
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_child(name_label)
	var items_row := HBoxContainer.new()
	items_row.add_theme_constant_override("separation", 4)
	items_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_child(items_row)
	for group: Array in UnitCard.grouped_equipment(entry.equipment):
		items_row.add_child(ItemIcon.new(group[0], 16.0))
	var items_label := _text(13, COLOR_DIM)
	items_label.text = parts[1] if parts.size() > 1 else ""
	items_label.clip_text = true
	items_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	items_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	items_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	items_row.add_child(items_label)
	items_row.add_child(CostGems.new(entry.cost(), 0, 7.0))
	main.set_pressed_no_signal(chosen)
	main.pressed.connect(func() -> void: select_entry(-1 if _selected == index else index))
	row.add_child(main)
	if shows_oaths():
		row.add_child(_oath_tag(index))
	var remove := _button(Text.t("deck.edit.remove"), 14)
	remove.custom_minimum_size = Vector2(52.0, 50.0)
	remove.theme_type_variation = UiTheme.BUTTON_ROW  # 札より軽く見せる（枠の無い行のボタン。乗ると薄く塗る）
	remove.add_theme_color_override("font_color", COLOR_DIM)
	remove.pressed.connect(func() -> void: remove_entry(index))
	row.add_child(remove)
	return row


## 部隊の行の「誓い」のボタン（特徴が誓いの部隊だけ。結んでいれば何組目か。結ぶ相手を選んでいる駒は明るく）。
func _oath_tag(index: int) -> Control:
	var entry := _deck.entries[index]
	var button := _button(TraitText.oath_tag(_deck, entry), 13)
	button.custom_minimum_size = Vector2(OATH_TAG_WIDTH, 50.0)
	button.theme_type_variation = UiTheme.BUTTON_ROW
	var bound := _deck.partner_of(entry) != null
	button.add_theme_color_override("font_color", Palette.NATION_FANTASY.lightened(0.3) if bound or _binding == index else COLOR_DIM)
	button.toggle_mode = true
	button.set_pressed_no_signal(_binding == index)
	button.tooltip_text = TraitText.oath_tooltip(_deck, entry)
	button.pressed.connect(func() -> void: press_oath(index))
	return button


## 部隊の特徴の欄（必殺技の欄の下。決まった大きさ）: 見出し「特徴」と札 3 枚（印と名前）、下に選んだ特徴の文（札に乗せている間は、その札の文）。
func _build_trait_box() -> Control:
	_trait_box = _card()
	_trait_box.custom_minimum_size = Vector2(ROSTER_WIDTH, TRAIT_BOX_HEIGHT)
	_trait_box.clip_contents = true
	Steady.mark(_trait_box, "decks.trait", Steady.RECT)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	_trait_box.add_child(column)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	column.add_child(row)
	var head := _text(14, COLOR_ACCENT)
	head.add_theme_font_override("font", UiTheme.FONT_BOLD)
	head.text = Text.t("deck.trait.title")
	head.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(head)
	_trait_buttons.clear()
	for i in 3:
		var button := _card_button("", 13)
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(0.0, TRAIT_CARD_HEIGHT)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var inside := HBoxContainer.new()
		inside.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inside.offset_left = 4.0
		inside.add_theme_constant_override("separation", 4)
		inside.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(inside)
		var mark := TraitIcon.new(Traits.NONE, TRAIT_MARK_SIDE)
		inside.add_child(mark)
		var name := _text(13, COLOR_TEXT)
		name.add_theme_font_override("font", UiTheme.FONT_BOLD)
		name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name.size_flags_vertical = Control.SIZE_FILL
		inside.add_child(name)
		button.set_meta(&"mark", mark)
		button.set_meta(&"name", name)
		button.pressed.connect(func() -> void: _on_trait_card(i, &"press"))
		button.mouse_entered.connect(func() -> void: _on_trait_card(i, &"enter"))
		button.mouse_exited.connect(func() -> void: _on_trait_card(i, &"exit"))
		row.add_child(button)
		_trait_buttons.append(button)
	_trait_label = _text(12, COLOR_DIM)
	_trait_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_trait_label.max_lines_visible = TRAIT_LINES
	_trait_label.custom_minimum_size = Vector2(ROSTER_WIDTH - 24.0, 0.0)
	column.add_child(_trait_label)
	return _trait_box


## 特徴の札の i 番目が押された・マウスが乗った・離れた。
func _on_trait_card(index: int, what: StringName) -> void:
	var choices := Traits.of_army(_deck.army) if _deck != null else ([] as Array[Traits.Id])
	if index >= choices.size():
		return
	match what:
		&"press":
			choose_trait(choices[index])
			_refresh_traits()  # 同じ札をもう一度押しても、押した形のまま
		&"enter":
			_hover_trait = choices[index]
			_refresh_traits()
		&"exit":
			_hover_trait = Traits.NONE
			_refresh_traits()


## 部隊の特徴の欄を、いまの部隊から直す（札の印と名前、選んだ札、文）。
func _refresh_traits() -> void:
	_trait_box.visible = shows_traits()
	if not shows_traits():
		return
	var choices := Traits.of_army(_deck.army)
	for i in _trait_buttons.size():
		var button := _trait_buttons[i]
		var id: int = choices[i] if i < choices.size() else Traits.NONE
		var chosen := id == _deck.trait_id
		(button.get_meta(&"mark") as Control).set(&"trait_id", id)
		(button.get_meta(&"mark") as Control).set(&"dim", not chosen)
		(button.get_meta(&"name") as Label).text = Names.troop_trait(id)
		(button.get_meta(&"name") as Label).add_theme_color_override("font_color", COLOR_TEXT if chosen else COLOR_DIM)
		button.set_pressed_no_signal(chosen)
		button.tooltip_text = Names.troop_trait_text(id)
	var shown := _hover_trait if choices.has(_hover_trait) else _deck.trait_id
	_trait_label.text = Names.troop_trait_text(shown)


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
