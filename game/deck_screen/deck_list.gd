extends "res://game/deck_screen/deck_unit_card.gd"
## 部隊編成の一覧の表示（取っておいた部隊の行と、選んだ部隊の札、どの決まりの一覧か）。


## 切り替えの並び: 対戦用と、物語ごとのストーリー用（物語の RULES_ID。物語の並びの順）。
static func modes() -> Array[StringName]:
	var ids: Array[StringName] = [DeckRules.VERSUS]
	for each in Story.campaigns():
		ids.append(each.rules_id)
	return ids


## 一覧の決まりの名前: 対戦用は「対戦用」、ストーリー用は物語の名前。
static func mode_name(rules_id: StringName) -> String:
	for each in Story.campaigns():
		if each.rules_id == rules_id:
			return each.title
	return Text.t("deck.mode.versus")


## 一覧を、対戦用（DeckRules.VERSUS）か、ある物語のストーリー用（物語の RULES_ID）に切り替える。組む画面の決まりも替わる
## （ストーリー用は、その物語のいまの進み具合の決まり）。
func set_mode(rules_id: StringName) -> void:
	rules = context.rules_of(rules_id) if modes().has(rules_id) else DeckRules.versus()
	_mode_label.text = mode_name(rules.id)
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
		_list_rows.add_child(_list_row(item))
	_list_empty.visible = items.is_empty()
	var chosen := _library.find(_list_selected)
	_list_detail_card.modulate.a = 1.0 if chosen != null else 0.0  # 選んでいなければ、右の欄は空（場所は保つ）
	for button in _list_actions:
		button.disabled = chosen == null
	for child in _list_detail_cards.get_children():
		_list_detail_cards.remove_child(child)
		child.queue_free()
	_list_detail_issues.visible = chosen != null and not chosen.playable()
	if chosen == null:
		_list_detail_title.text = ""
		_list_detail_body.text = ""
		_list_detail_issues.text = ""
		return
	_list_detail_decor.army = chosen.deck.army
	_list_detail_crest.army = chosen.deck.army
	_list_detail_crest.modulate.a = 0.0 if chosen.deck.army == UnitKind.Army.NONE else 1.0
	_list_detail_crest.queue_redraw()
	_list_detail_gauge.slots = maxi(chosen.deck.budget(), 1)
	_list_detail_gauge.count = chosen.deck.total_cost()
	_list_detail_body.add_theme_color_override("font_color", COLOR_DIM if chosen.deck.total_cost() <= chosen.deck.budget() else COLOR_BAD)
	_list_detail_title.text = chosen.name
	_list_detail_body.text = Text.t("deck.list.detail", {"army": DeckText.army_name(chosen.deck.army), "count": chosen.deck.entries.size(), "cost": chosen.deck.total_cost(), "budget": chosen.deck.budget()})
	var trait_id := TraitText.of_deck(chosen.deck)
	if trait_id != Traits.NONE:
		_list_detail_body.text = Text.t("deck.list.trait", {"detail": _list_detail_body.text, "trait": Names.troop_trait(trait_id)})
	_list_detail_cards.add_child(UnitCard.build(UnitKind.Id.KING))
	for entry in chosen.deck.entries:
		_list_detail_cards.add_child(UnitCard.build(entry.kind, entry.equipment))
	var issues := chosen.issues()
	_fold(_list_detail_issues, "" if issues.is_empty() else Text.t("deck.unplayable", {"issues": Text.join_comma(issues)}), DETAIL_WIDTH + 200.0)


## 一覧の 1 行（取っておいた部隊 1 つ）: 左の縁に軍の色、軍の紋、名前、軍・駒の数・コスト。出せない部隊は、危険の色。
func _list_row(item: DeckLibrary.Saved) -> Button:
	var playable := item.playable()
	var army := item.deck.army
	var tone := NationDecor.color_of(army) if playable else COLOR_BAD
	var button := _card_button("", 16)
	button.toggle_mode = true
	button.custom_minimum_size = Vector2(0.0, 62.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var text := Text.t("deck.list.row" if playable else "deck.list.row_unplayable", {
		"name": item.name, "army": DeckText.army_name(army), "count": item.deck.entries.size(),
		"cost": item.deck.total_cost(), "budget": item.deck.budget(),
	})
	button.set_meta(&"row_text", text)
	var strip := ColorRect.new()
	strip.color = Color(tone, 0.9)
	strip.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	strip.offset_left = 3.0
	strip.offset_right = 7.0
	strip.offset_top = 5.0
	strip.offset_bottom = -5.0
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(strip)
	var inside := HBoxContainer.new()
	inside.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inside.offset_left = 16.0
	inside.offset_right = -10.0
	inside.add_theme_constant_override("separation", 10)
	inside.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(inside)
	var crest := Crest.new(army, 34.0, Color(tone, 0.95))
	crest.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	crest.modulate.a = 0.0 if army == UnitKind.Army.NONE else 1.0
	inside.add_child(crest)
	var lines := VBoxContainer.new()
	lines.alignment = BoxContainer.ALIGNMENT_CENTER
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lines.add_theme_constant_override("separation", 0)
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inside.add_child(lines)
	var parts := text.split("\n", true, 1)
	var name_label := _text(17, COLOR_TEXT if playable else COLOR_BAD)
	name_label.add_theme_font_override("font", UiTheme.FONT_BOLD)
	name_label.text = parts[0]
	var info := _text(14, COLOR_DIM if playable else COLOR_BAD)
	info.text = parts[1] if parts.size() > 1 else ""
	for label: Label in [name_label, info]:
		label.clip_text = true
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lines.add_child(label)
	button.set_pressed_no_signal(item.id == _list_selected)
	var id := item.id
	button.pressed.connect(func() -> void: select_saved(id))
	return button


## 一覧の右に出している駒の札の種類（将を含む。検査用）。
func list_card_kinds() -> Array[UnitKind.Id]:
	var kinds: Array[UnitKind.Id] = []
	for card in _list_detail_cards.get_children():
		kinds.append(card.get_meta(&"kind"))
	return kinds


## 一覧の右の駒の札のうち、札に収まらずに切れている文（検査用）。
func list_card_cut_texts() -> Array[String]:
	var cut: Array[String] = []
	for card: Control in _list_detail_cards.get_children():
		cut.append_array(UnitCard.cut_texts(card))
	return cut


# ==== 軍の選択 ====
