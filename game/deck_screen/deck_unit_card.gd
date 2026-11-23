extends "res://game/deck_screen/deck_base.gd"
## 部隊編成の、駒の札（選んだ駒・マウスを乗せた雇える駒）と持ち物の欄、ステータスの窓。


## 雇える駒 kind にマウスを乗せたことにする（-1 で離す）。スクリーンショットの道具用。
func hover_kind(kind: int) -> void:
	_set_hover(kind)


## 右の札の「詳細」: 選んでいる部隊の駒のステータスの窓を開く。選んでいなければ何もしない。
func press_unit_detail() -> void:
	if _deck == null or _selected == -1 or context.overlays.is_open():
		return
	if _unit_detail == null:
		_unit_detail = UnitDetail.new()
		_layer.add_child(_unit_detail)
		_unit_detail.setup(context.overlays)
	var entry := _deck.entries[_selected]
	_unit_detail.open(entry.kind, entry.equipment, 0, _deck.army)


## 駒のステータスの窓（検査用。まだ開いていなければ null）。
func unit_detail() -> Control:
	return _unit_detail


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
	# 駒の札と持ち物の欄は、いつも同じ大きさで場所を取る（docs/ui-theme.md の「枠の大きさ」）。出すものが無い間は、中身を透かすだけ
	# （駒を選ぶ・雇える駒に乗せるたびに、札が出たり消えたり、伸び縮みしたりしない）。
	var chosen_entry: DeckEntry = _deck.entries[_selected] if _selected != -1 else null
	# 枠は出したまま、中身だけを透かす（空の枠が、そこに何が出るかの場所を示す）。
	(_equip_box.get_child(0) as Control).modulate.a = 1.0 if chosen_entry != null else 0.0
	(_detail_card.get_child(0) as Control).modulate.a = 1.0 if kind != -1 else 0.0
	if chosen_entry == null:
		# 持ち物の欄は、並ぶ行だけ決めて（高さを保つ）、押せなくする。
		var listed := _deck.rules.shown_items()
		for item: Equipment.Id in _equip_rows:
			var parts: Array = _equip_rows[item]
			(parts[5] as Control).visible = listed.has(item)
			(parts[0] as Button).disabled = true
			(parts[2] as Button).disabled = true
		_fit_equip()
	if kind == -1:
		return
	var unit_kind := kind as UnitKind.Id
	var held: Array[Equipment.Id] = []
	if entry != null:
		held = entry.equipment
	# 「詳細」は部隊の駒を出しているときだけ押せる（雇える駒は、マウスを離すと札が替わるので押せない。場所は保つ）。
	_detail_open.disabled = entry == null
	_detail_open.modulate.a = 1.0 if entry != null else 0.0
	var sheet: UnitSheet = UnitSheet.of_kind(unit_kind, held, 0, _deck.army if _deck != null else -1)
	_detail_summary.show_sheet(sheet, "%d. %s" % [_selected + 1, sheet.name] if entry != null else "")
	entry = chosen_entry
	if entry != null:
		_equip_title.text = Text.t("deck.edit.items", {"count": entry.equipment.size(), "max": Equipment.MAX_PER_UNIT})
		var shown := _deck.rules.shown_items()
		for item: Equipment.Id in _equip_rows:
			var parts: Array = _equip_rows[item]
			var allowed := _deck.rules.allows_item(item)
			(parts[5] as Control).visible = shown.has(item) or entry.count(item) > 0
			(parts[0] as Button).disabled = entry.count(item) == 0
			(parts[1] as Label).text = str(entry.count(item))
			(parts[2] as Button).disabled = not allowed or not Equipment.can_add(entry.kind, entry.equipment, item)
			# まだ持たせられない持ち物（ストーリーで未解放）は、灰色で「未解放」。持たせているものは「−」で外せる。
			# 選んでいる駒が持てない持ち物（役割の限り、重ねられない）は、灰色で理由（「後衛専用」「1 体 1 個まで」）。
			var refusal := DeckText.item_refusal(entry.kind, entry.equipment, item) if allowed else ""
			var usable := allowed and refusal == ""
			var item_name := parts[3] as Label
			item_name.text = Text.t("deck.edit.item", {"name": Names.item(item), "cost": Equipment.cost(item)})
			item_name.add_theme_color_override("font_color", COLOR_TEXT if usable else COLOR_DIM)
			# 持たせられない理由は、効果の行の頭に置く（名前の行の後ろに足すと、長い名前で「…」に切れて読めない）。
			# 役割の限り（「後衛専用」など）は、効果の文の括弧に、もう書いてある。
			(parts[4] as Label).text = DeckText.equipment_effect(item)
			var reason := Text.t("deck.edit.item_locked") if not allowed else ("" if refusal == DeckText.holders_text(item) else refusal)
			# 切れてはいけない文（検査用。item_row_cut_texts）: 理由を頭に置いたら理由、役割の限りなら効果の文の全部（理由が括弧で後ろにある）。
			(parts[4] as Label).set_meta(&"must_show", reason if reason != "" else ((parts[4] as Label).text if refusal != "" else ""))
			if reason != "":
				(parts[4] as Label).text = Text.t("deck.edit.item_refused", {"reason": reason, "effect": (parts[4] as Label).text})
			(parts[5] as Control).modulate = Color.WHITE if usable or entry.count(item) > 0 else Color(1, 1, 1, 0.55)
			var tips: Array[String] = [DeckText.equipment_effect(item)]
			if DeckText.equipment_traits_text(item) != "":
				tips.append(DeckText.equipment_traits_text(item))
			if not allowed:
				tips.append(Text.t("deck.edit.item_locked.tooltip"))
			(parts[5] as Control).tooltip_text = "\n".join(tips)
	_fit_equip()


## 持ち物の欄の高さを決める: 並ぶ行がぜんぶ入る高さ。ただし、駒の札が DETAIL_MIN_HEIGHT を割るなら、そこまでにして欄の中で送る。
func _fit_equip() -> void:
	if _equip_scroll == null or _edit_view == null:
		return
	# 高さは、決まりが並べる持ち物の行の数で決める（選んでいる駒が持っているものでは変えない）。
	var natural := _equip_list.get_combined_minimum_size().y
	var chrome := _equip_box.get_combined_minimum_size().y - _equip_scroll.custom_minimum_size.y
	# 右の列に使える高さは、画面の高さから決める（右の列のいまの高さからは決めない。ここで決めた下限が右の列を支えるので、
	# 窓を縦に縮めても右の列が縮まず、欄が低くならないまま、下のボタンが画面の外へ出る）。
	# 組む画面の全体と右の列の高さの差（見出し・下のボタン・余白）は、支えられて伸びていても変わらない。
	var around := _edit_view.size.y - _right.size.y
	var budget := (_edit_view.get_viewport_rect().size.y if _edit_view.is_inside_tree() else _edit_view.size.y) - around
	var room := budget - DETAIL_MIN_HEIGHT - RIGHT_GAP - chrome
	_equip_scroll.custom_minimum_size.y = minf(natural, maxf(room, EQUIP_MIN_HEIGHT))


## 駒の札（右上）の中身が、札の幅からはみ出している量（px。0 以下なら収まっている）と、「詳細」のボタンが名前に重なっているか。検査用。
func detail_summary_overflow() -> float:
	return _detail_summary.overflow()


func detail_button_covers_summary_head() -> bool:
	var head: Control = _detail_summary.get_child(0)
	return _detail_open.get_global_rect().intersects(head.get_global_rect())


## 駒の札（右上）と、持ち物の欄の送れる部分の、画面の上の四角。検査用。
func detail_card_rect() -> Rect2:
	return _detail_card.get_global_rect()


## 持ち物の欄の、見えている行のうち、切れて読めない文（検査用。並べ終わったあとに呼ぶ）: 名前とコスト、持たせられない理由。
## 効果の文は欄の幅で「…」に切ってよい（全文は行のツールチップ）。
func item_row_cut_texts() -> Array[String]:
	var cut: Array[String] = []
	for item: Equipment.Id in _equip_rows:
		var parts: Array = _equip_rows[item]
		if not (parts[5] as Control).is_visible_in_tree():
			continue
		var name_label := parts[3] as Label
		var effect := parts[4] as Label
		if _text_width(name_label, name_label.text) > name_label.size.x + 0.5:
			cut.append(name_label.text)
		var must: String = effect.get_meta(&"must_show", "")
		if must != "" and _text_width(effect, must) > effect.size.x + 0.5:
			cut.append(effect.text)
	return cut


## 持ち物の欄の、見えている行の効果の行の文（検査用）。
func item_row_effects() -> Dictionary:
	var effects := {}
	for item: Equipment.Id in _equip_rows:
		var parts: Array = _equip_rows[item]
		if (parts[5] as Control).is_visible_in_tree():
			effects[item] = (parts[4] as Label).text
	return effects
