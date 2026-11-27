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
	# 額（役割の印つき。縁は陣営の色）と、その下の持ち物の印。全体を押すと詳しい説明、乗せると名前と持ち物。
	var face := VBoxContainer.new()
	face.add_theme_constant_override("separation", 2)
	face.mouse_filter = Control.MOUSE_FILTER_STOP
	face.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	face.tooltip_text = _face_tip(kind, equipment, level)
	face.set_meta(&"detail", [kind, equipment, side, army, level, look])
	face.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_open_detail(face))
	var frame := UnitFrame.new(kind, side, FACE_SIZE, true, false, look)
	frame.edge = Color(BattleScreen.TEAM_COLORS[side], 0.85)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_child(frame)
	var items := HBoxContainer.new()
	items.alignment = BoxContainer.ALIGNMENT_CENTER
	items.add_theme_constant_override("separation", 1)
	items.custom_minimum_size = Vector2(FACE_SIZE, FACE_ITEM)
	items.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for item in equipment:
		var mark := ItemIcon.new(item, FACE_ITEM)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		items.add_child(mark)
	face.add_child(items)
	face.set_meta(&"items", items)
	if level > 1:
		# 始めのレベルが 1 でない駒（進化を教える話など）は、額の左上にレベル（右下は役割の印）。
		var tag := _text(13, COLOR_ACCENT)
		tag.text = Text.t("sortie.level", {"level": level})
		tag.add_theme_constant_override("outline_size", 4)
		tag.add_theme_color_override("font_outline_color", Palette.OUTLINE)
		tag.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE)
		tag.offset_left = 3.0
		frame.add_child(tag)
	return face


## 額に乗せると出る文: 名前（始めのレベルが 1 でなければレベルも）、持ち物、「クリック: 詳細」。
static func _face_tip(kind: UnitKind.Id, equipment: Array[Equipment.Id], level: int) -> String:
	var lines: Array[String] = [Names.kind(kind) if level <= 1 else Text.t("sortie.face.level", {"unit": Names.kind(kind), "level": level})]
	if not equipment.is_empty():
		lines.append(BattleHud.equipment_text(equipment))
	lines.append(Text.t("deck.detail.click"))
	return "\n".join(lines)

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
	_add_option(DEFAULT_ID, Text.t("sortie.option.default"), _deck_note(Story.default_deck(context.story.unlocked())), true)
	for item in context.decks.for_rules(context.story.campaign.rules_id, context.story.campaign.army):
		var issues: Array[String] = item.issues()
		_add_option(item.id, item.name, _deck_note(item.deck) if issues.is_empty() else Text.t("sortie.option.unplayable", {"issue": issues[0]}), issues.is_empty())


## 選択肢の行の右の文: 部隊の数とコスト。
func _deck_note(deck: Deck) -> String:
	return Text.t("sortie.option.saved.note", {"count": deck.entries.size(), "cost": deck.total_cost(), "budget": deck.budget()})


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


## 部隊の駒の額の並び（side の陣営）の、額に乗せると出る文（将から並びの順。検査用）。
func face_tips(side: Unit.Side) -> Array[String]:
	var tips: Array[String] = []
	for face in (_deck_faces if side == Unit.Side.PLAYER1 else _enemy_faces).get_children():
		if not face.is_queued_for_deletion():
			tips.append((face as Control).tooltip_text)
	return tips


## 部隊の駒の額の並び（side の陣営）の、持ち物の印の数（将から並びの順。検査用）。
func face_item_marks(side: Unit.Side) -> Array[int]:
	var counts: Array[int] = []
	for face in (_deck_faces if side == Unit.Side.PLAYER1 else _enemy_faces).get_children():
		if not face.is_queued_for_deletion():
			counts.append((face.get_meta(&"items") as Control).get_child_count())
	return counts
