extends "res://game/sortie_screen/sortie_base.gd"
## 出撃準備の場面の、部隊の選択と操作: 選べる部隊の並び、選んだ部隊の駒のアイコンと中身の文、初期位置の縮図の作り直し、
## 駒の詳しい説明、「出撃」「部隊編成」「話の一覧へ戻る」。sortie_base.gd を継ぐ。


## 部隊 id（DEFAULT_ID なら既定の編成）を選ぶ。出せない部隊なら何もしない。
func choose(id: String) -> void:
	if not _option_buttons.has(id) or (_option_buttons[id] as Button).disabled:
		return
	_chosen = id
	for key: String in _option_buttons:
		(_option_buttons[key] as Button).set_pressed_no_signal(key == id)
	var deck := chosen_deck()
	var levels := start_levels(Unit.Side.PLAYER1)
	_fold_deck_line(DeckText.deck_summary(deck, levels))
	_fill_faces(_deck_faces, deck, Unit.Side.PLAYER1, levels)
	# 部隊を替えたら、初期位置はおまかせに戻す。
	battle_source.placement.clear()
	_refresh_deploy(deck)


## 初期位置の縮図を、部隊 deck と、いまの初期位置（battle_source.placement）で作り直す。
func _refresh_deploy(deck: Deck) -> void:
	var source: RefCounted = battle_source.copy()
	source.human_deck = deck
	var placed: Battle = source.make_setup(1).create_battle()
	source.placement.clear()
	var usual: Battle = source.make_setup(1).create_battle()
	var defaults: Array[Vector2i] = []
	for unit: Unit in usual.units:
		if unit.side == Unit.Side.PLAYER1 and unit.kind != UnitKind.Id.KING:
			defaults.append(unit.cell)
	_deploy.setup(placed, Unit.Side.PLAYER1, defaults, battle_source.scenario().deploy_cells_of(Unit.Side.PLAYER1), episode.look, BattleScreen.TEAM_COLORS)
	_auto_button.disabled = _deploy.is_default() or _deploy.read_only


## 「おまかせ」: 初期位置を、いつもの置き方へ戻す。
func press_auto_place() -> void:
	_deploy.reset()


## 初期位置を決められない話か（部隊も位置も決まっている演習）。
func is_placement_fixed() -> bool:
	return is_squad_fixed() and not episode.deploy[Unit.Side.PLAYER1].is_empty()


## 初期位置の縮図と、その下の駒の欄（検査用）。
func deploy_map() -> DeployMap:
	return _deploy


func deploy_note() -> DeployNote:
	return _deploy_note


## faces に、部隊 deck の駒のアイコン（将から並びの順。将のいない群れは将なし）を並べ直す。side は陣営、levels は始めのレベル（start_levels）。
## アイコンを押すと、その駒の詳しい説明（unit_detail.gd）を開く。始めのレベルが 1 でない駒は、アイコンの右下にレベル。
func _fill_faces(faces: Container, deck: Deck, side: Unit.Side, levels: Array) -> void:
	for face in faces.get_children():
		faces.remove_child(face)
		face.queue_free()
	var look: StringName = battle_source.king_looks()[side] if side < battle_source.king_looks().size() else &""
	if battle_source.scenario().has_king(side):  # 将のいない群れ（docs/scenario.md）は、将を並べない
		faces.add_child(_face(UnitKind.Id.KING, [], side, deck.army, 1, look))
	for i in deck.entries.size():
		var level: int = levels[i] if i < levels.size() else 1
		faces.add_child(_face(deck.entries[i].kind, deck.entries[i].equipment, side, deck.army, level))


func _face(kind: UnitKind.Id, equipment: Array[Equipment.Id], side: Unit.Side, army: UnitKind.Army, level: int, look := &"") -> Control:
	# 駒の額（役割の印つき）。縁は陣営の色。
	var face := UnitFrame.new(kind, side, FACE_SIZE, true, false, look)
	face.edge = Color(BattleScreen.TEAM_COLORS[side], 0.85)
	face.mouse_filter = Control.MOUSE_FILTER_STOP
	face.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	face.tooltip_text = Text.t("deck.detail.click")
	face.set_meta(&"detail", [kind, equipment, side, army, level, look])
	face.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_open_detail(face))
	if level > 1:
		# 始めのレベルが 1 でない駒（進化を教える話など）は、アイコンの右下にレベル。
		var tag := _text(13, COLOR_ACCENT)
		tag.text = Text.t("sortie.level", {"level": level})
		tag.add_theme_constant_override("outline_size", 4)
		tag.add_theme_color_override("font_outline_color", Palette.OUTLINE)
		# 右下は役割の印なので、レベルは左上に置く。
		tag.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE)
		tag.offset_left = 3.0
		face.add_child(tag)
	return face


func _open_detail(face: Control) -> void:
	if _detail == null:
		_detail = UnitDetail.new()
		_layer.add_child(_detail)
		_detail.setup(context.overlays)
	var given: Array = face.get_meta(&"detail")
	_detail.open(given[0], given[1], given[2], given[3], given[4], given[5])


## 部隊の駒のアイコン（side の陣営。将から並びの順）を押す（検査用）: その駒の詳しい説明を開き、それを返す。
func press_face(side: Unit.Side, index: int) -> Control:
	var faces: Array[Node] = (_deck_faces if side == Unit.Side.PLAYER1 else _enemy_faces).get_children().filter(
		func(face: Node) -> bool: return not face.is_queued_for_deletion())
	if index < 0 or index >= faces.size():
		return null
	_open_detail(faces[index])
	return _detail


## side の部隊の並びの順の、駒の始めのレベル（話の戦いの定義の start_growth。決めていなければ空）。
## 人の側は、部隊が決まっている話だけ（選んだ部隊には当てない）。
func start_levels(side: Unit.Side) -> Array:
	var levels: Array = []
	if side == Unit.Side.PLAYER1 and _chosen != FIXED_ID:
		return levels
	for row: Array in battle_source.scenario().start_growth[side]:
		levels.append(row[0])
	return levels


## 選んでいる部隊の id（DEFAULT_ID なら既定の編成）と、その部隊（写し）。
func chosen_id() -> String:
	return _chosen


func chosen_deck() -> Deck:
	if _chosen == FIXED_ID:
		return episode.squad_deck()
	if _chosen != DEFAULT_ID:
		var saved: RefCounted = context.decks.find(_chosen)
		if saved != null:
			return saved.deck.copy()
	return Story.default_deck(context.story.unlocked())


## 選択肢の id の並び（既定の編成が先頭）と、押せるか（検査用）。
func option_ids() -> Array[String]:
	var ids: Array[String] = []
	for key: String in _option_buttons:
		ids.append(key)
	return ids


func is_option_enabled(id: String) -> bool:
	return _option_buttons.has(id) and not (_option_buttons[id] as Button).disabled


## 部隊が決まっている話か（話の [ally] に unit がある）。
func is_squad_fixed() -> bool:
	return episode.squad_deck() != null


## 「出撃」: 選んだ部隊を話の対戦に持たせて、対戦へ。部隊が決まっている話では、覚えている部隊を変えない。
func press_sortie() -> void:
	battle_source.human_deck = chosen_deck()
	if not is_squad_fixed():
		context.story.choose_squad(_chosen)
	finished.emit(Run.NEXT)


## 「部隊編成」: 部隊編成（ストーリー用）へ寄り道する。編成の「出撃準備へ戻る」で、ここへ戻る（選んでいた部隊は覚えておく）。
func press_edit_decks() -> void:
	if context.run == null or is_squad_fixed():
		return
	context.story.choose_squad(_chosen)
	context.run.insert(DECKS, {"rules": context.story.campaign.rules_id, "back_label": "sortie.back"})
	context.start_run(context.run)


## 「話の一覧へ戻る」。
func press_back() -> void:
	finished.emit(&"back")


func _build_options() -> void:
	if is_squad_fixed():
		_add_option(FIXED_ID, Text.t("sortie.option.fixed"), Text.t("sortie.option.fixed.note"), true)
		return
	_add_option(DEFAULT_ID, Text.t("sortie.option.default"), Text.t("sortie.option.default.note"), true)
	for item in context.decks.for_rules(context.story.campaign.rules_id, context.story.campaign.army):
		var issues: Array[String] = item.issues()
		var note := Text.t("sortie.option.saved.note", {"count": item.deck.entries.size(), "cost": item.deck.total_cost(), "budget": item.deck.budget()})
		_add_option(item.id, item.name, note if issues.is_empty() else Text.t("sortie.option.unplayable", {"issue": issues[0]}), issues.is_empty())


func _add_option(id: String, name: String, note: String, enabled: bool) -> void:
	var button := _button(Text.t("sortie.option", {"name": name, "note": note}), 16)
	button.toggle_mode = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0.0, OPTION_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.disabled = not enabled
	if not enabled:
		button.add_theme_color_override("font_disabled_color", COLOR_BAD)
	button.pressed.connect(func() -> void: choose(id))
	_options.add_child(button)
	_option_buttons[id] = button


## 選べる部隊の並びを、行の数 rows だけ送る（負で上へ。ホイールの 1 目盛りが 1 行）。
func scroll_options(rows: int) -> void:
	_options_scroll.scroll_vertical += int((OPTION_HEIGHT + OPTION_GAP) * rows)


## 選べる部隊の並びの欄（検査用）と、その中でいま丸ごと見えている行の数。
func options_scroll() -> ScrollContainer:
	return _options_scroll


func options_fully_shown() -> int:
	var view := _options_scroll.get_global_rect()
	var shown := 0
	for id: String in _option_buttons:
		if view.grow(0.5).encloses((_option_buttons[id] as Button).get_global_rect()):
			shown += 1
	return shown


## 選んだ部隊の中身の文を、DECK_LINES 行に収める（収まらなければ、字を DECK_FONT_MIN まで小さくする）。欄の高さは変えない。
func _fold_deck_line(text: String) -> void:
	var font := _deck_line.get_theme_font("font")
	for font_size in range(DECK_FONT, DECK_FONT_MIN - 1, -1):
		_deck_line.add_theme_font_size_override("font_size", font_size)
		_deck_line.text = TextWrap.fold(text, WRAP_WIDTH, func(character: String) -> float:
			return font.get_string_size(character, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
		if _deck_line.text.count("\n") < DECK_LINES:
			_deck_line.tooltip_text = ""
			return
	# いちばん小さい字でも収まらない部隊（持ち物の多い大きな部隊）: DECK_LINES 行で切って「…」を付け、全部はマウスを乗せると出す。
	var lines := _deck_line.text.split("\n").slice(0, DECK_LINES)
	lines[DECK_LINES - 1] = lines[DECK_LINES - 1].left(-1) + "…"
	_deck_line.text = "\n".join(lines)
	_deck_line.tooltip_text = text


## 選んだ部隊の中身の文（折り返したもの。検査用）。
func deck_line_text() -> String:
	return _deck_line.text


## 選んだ部隊の中身の文にマウスを乗せると出る文（切れた文の全部。切れていなければ空。検査用）。
func deck_line_tooltip() -> String:
	return _deck_line.tooltip_text
