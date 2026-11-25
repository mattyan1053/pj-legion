extends "res://game/deck_screen/deck_editor.gd"
## 部隊編成の一覧の組み立てと操作（新しい部隊・編集・複製・名前変更・削除）、新しい部隊の軍の選択。


## 一覧から抜ける: タイトルへ（流れの中なら、流れの次の場面 = 出撃準備へ。寄り道の間に取っておいた部隊を選ぶ）。
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
	_ask_name(Text.t("deck.name.title"), item.name, func(name: String) -> void: _library.rename(id, name))


## 「消す」。確かめてから消す。
func press_delete() -> void:
	var item := _library.find(_list_selected)
	if item == null:
		return
	var id := item.id
	_confirm(Text.t("deck.delete.confirm", {"name": item.name}), Text.t("deck.list.delete"), func() -> void:
		_library.remove(id)
		_list_selected = "")


func _build_list() -> Control:
	var root := _frame()
	var column := root.get_child(0).get_child(0) as VBoxContainer
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	column.add_child(header)
	header.add_child(_heading(Text.t("deck.title")))
	# どの決まりの一覧か（「対戦用」か物語の名前）は、見出しの横の小さな札。
	var mode_tag := PanelContainer.new()
	mode_tag.theme_type_variation = UiTheme.PANEL_TAG
	mode_tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(mode_tag)
	_mode_label = _text(15, COLOR_ACCENT)
	mode_tag.add_child(_mode_label)
	var header_line := Ornament.new(200.0, 12.0)
	header_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header_line.color = Palette.BORDER
	header.add_child(header_line)
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
	_list_empty.text = Text.t("deck.list.empty")
	_list_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_list_rows.add_child(_list_empty)
	var new_button := _button(Text.t("deck.list.new"), 20)
	new_button.custom_minimum_size = Vector2(0.0, 52.0)
	new_button.pressed.connect(press_new)
	left.add_child(new_button)

	var right := _card()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)
	_list_detail_card = right
	# 選んだ部隊の軍の色の帯と、右下の薄い紋。
	_list_detail_decor = NationDecor.new(UnitKind.Army.NONE, 190.0, 70.0)
	right.add_child(_list_detail_decor)
	var detail := VBoxContainer.new()
	detail.add_theme_constant_override("separation", 8)
	right.add_child(detail)
	var detail_head := HBoxContainer.new()
	detail_head.add_theme_constant_override("separation", 10)
	detail.add_child(detail_head)
	_list_detail_crest = Crest.new(UnitKind.Army.MILITARY, 40.0)
	_list_detail_crest.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	detail_head.add_child(_list_detail_crest)
	var detail_names := VBoxContainer.new()
	detail_names.add_theme_constant_override("separation", 0)
	detail_names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_head.add_child(detail_names)
	_list_detail_title = _text(24, COLOR_TEXT)
	_list_detail_title.add_theme_font_override("font", UiTheme.FONT_HEADING)
	_list_detail_title.clip_text = true
	_list_detail_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	detail_names.add_child(_list_detail_title)
	var detail_line := HBoxContainer.new()
	detail_line.add_theme_constant_override("separation", 12)
	detail_names.add_child(detail_line)
	# 軍・兵の数・コストの文は決まった幅の欄に入れ、ゲージと軍略の札の位置をどの部隊でもそろえる。
	_list_detail_body = _text(16, COLOR_DIM)
	_list_detail_body.custom_minimum_size = Vector2(LIST_DETAIL_BODY_WIDTH, 0.0)
	_list_detail_body.clip_text = true
	detail_line.add_child(_list_detail_body)
	_list_detail_gauge = CostGems.new(0, 1, 9.0, GAUGE_WIDTH)
	detail_line.add_child(_list_detail_gauge)
	_list_detail_trait = TraitTag.new(24.0, 15)
	detail_line.add_child(_list_detail_trait)
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
	_list_detail_issues.add_theme_stylebox_override("normal", UiTheme.danger_strip_box())
	detail.add_child(_list_detail_issues)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	detail.add_child(actions)
	for spec: Array in [["deck.list.edit", press_edit], ["deck.list.duplicate", press_duplicate], ["deck.list.rename", press_rename], ["deck.list.delete", press_delete]]:
		var button := _button(Text.t(spec[0]), 18)
		button.custom_minimum_size = Vector2(0.0, 46.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(spec[1])
		if spec[1] == press_delete:
			button.theme_type_variation = UiTheme.BUTTON_DANGER
		actions.add_child(button)
		_list_actions.append(button)

	var footer := HBoxContainer.new()
	column.add_child(footer)
	_back_button = _button(Text.t("menu.to_title"), 18)
	_back_button.custom_minimum_size = Vector2(220.0, 46.0)
	_back_button.pressed.connect(leave)
	footer.add_child(_back_button)
	return root


func _build_army_picker() -> Control:
	var root := _frame()
	root.visible = false
	var column := root.get_child(0).get_child(0) as VBoxContainer
	column.add_child(_heading(Text.t("deck.army.title")))
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
		# その国の色の帯と、薄く大きな紋（物語のカードと同じ向き）。
		var decor := NationDecor.new(army, 230.0, 120.0)
		decor.crest_alpha = 0.13
		decor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		card.add_child(decor)
		var inside := VBoxContainer.new()
		inside.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 20)
		inside.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inside.add_theme_constant_override("separation", 10)
		card.add_child(inside)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 12)
		inside.add_child(head)
		head.add_child(Crest.new(army, 52.0))
		var head_names := VBoxContainer.new()
		head_names.add_theme_constant_override("separation", 0)
		head.add_child(head_names)
		var army_name := _text(30, Crest.color_of(army).lightened(0.25))
		army_name.add_theme_font_override("font", UiTheme.FONT_HEADING)
		army_name.text = DeckText.army_name(army)
		head_names.add_child(army_name)
		var budget_row := HBoxContainer.new()
		budget_row.add_theme_constant_override("separation", 10)
		head_names.add_child(budget_row)
		var budget := _text(16, COLOR_DIM)
		budget.text = Text.t("deck.army.budget", {"budget": Deck.budget_of(army)})
		budget_row.add_child(budget)
		budget_row.add_child(CostGems.new(Deck.budget_of(army), Deck.budget_of(army), 6.0, 176.0))
		var faces := HBoxContainer.new()
		faces.add_theme_constant_override("separation", 6)
		inside.add_child(faces)
		faces.add_child(UnitFrame.new(UnitKind.Id.KING, 0, 60.0))
		for kind in Deck.roster(army):
			faces.add_child(UnitFrame.new(kind, 0, 60.0))
		# 雇える駒は、役割の印と名前で 1 行ずつ。
		var roster := VBoxContainer.new()
		roster.add_theme_constant_override("separation", 2)
		inside.add_child(roster)
		for kind in Deck.roster(army):
			var line := HBoxContainer.new()
			line.add_theme_constant_override("separation", 8)
			roster.add_child(line)
			line.add_child(RoleMark.new(UnitKind.role(kind), 20.0))
			var unit_name := _text(17, COLOR_TEXT)
			unit_name.text = Text.t("deck.army.unit", {"unit": Names.kind(kind), "role": DeckText.role_name(kind)})
			line.add_child(unit_name)
		var ult := Ults.of_army(army)
		if ult != null:
			inside.add_child(HSeparator.new())
			inside.add_child(_ult_lines(Text.t("deck.ult", {"name": Names.ult(ult), "summary": Names.ult_summary(ult)}), 356.0, 15))
		for label in inside.find_children("*", "Control", true, false):
			(label as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(card)
		_army_cards[army] = card
	var footer := HBoxContainer.new()
	column.add_child(footer)
	var back := _button(Text.t("common.back"), 18)
	back.custom_minimum_size = Vector2(200.0, 46.0)
	back.pressed.connect(func() -> void: show_list())
	footer.add_child(back)
	return root


# ==== 組む画面 ====
