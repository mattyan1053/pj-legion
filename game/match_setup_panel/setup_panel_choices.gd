extends "res://game/match_setup_panel/setup_panel_base.gd"
## 対戦設定のパネルの、選ぶこと（マップ・相手・手番・選べる決まり・軍・部隊）と、選んだものを行に映す（_show_choice）、
## 2 回押させる確かめ、編成確認・初期位置・部隊編成への寄り道。


## いま選んでいるもの（写しではない。検査用）。
func current_choice() -> RefCounted:
	return _choice


## マップを field（versus_fields.gd の鍵）にする。
func choose_field(field: StringName) -> void:
	_choice.field = field
	_show_choice()


func choose_opponent(cpu: bool) -> void:
	_choice.cpu_opponent = cpu
	_show_choice()


func choose_human_side(side: Unit.Side) -> void:
	_choice.human_side = side
	_choice.random_side = false
	_show_choice()


## 手番を「ランダム」にする（対戦を作るたびに、種から先手・後手を引く）。
func choose_random_side() -> void:
	_choice.random_side = true
	_show_choice()


## 選べる決まり id を入・切する。
## パネルが画面（窓）の中に収まっているか。検査用（決まりの行を足して、下のボタンが画面の外へ出ないように）。
func fits_screen() -> bool:
	return get_viewport().get_visible_rect().encloses(_panel.get_global_rect())


## パネルの四角（画面の座標）。検査用。
func panel_rect() -> Rect2:
	return _panel.get_global_rect()


func choose_rule(id: StringName, on: bool) -> void:
	_choice.set_rule(id, on)
	_show_choice()


## 選べる決まりの行の右の説明（検査用）。
func rule_note_text(id: StringName) -> String:
	return (_rule_notes[id] as Label).text


## 選べる決まりの、ひとことの説明。
static func rule_note(id: StringName) -> String:
	return Text.t("setup.rule.%s.note" % id, {"range": MapObject.BATTERY_RANGE, "holds": Stronghold.HOLDS_TO_WIN})


func choose_army(side: Unit.Side, army: UnitKind.Army) -> void:
	_choice.choose_army(side, army)
	_show_choice()


## side の部隊の選択肢を開く（スクリーンショットの道具用）。
func open_deck_picker(side: Unit.Side) -> void:
	_deck_pickers[side].show_popup()


## side の部隊を、取っておいた部隊 id にする（空なら既定の編成、MatchChoice.RANDOM ならランダム編成）。出せない部隊・知らない id なら何もせず false。
func choose_deck(side: Unit.Side, id: String) -> bool:
	if id == "":
		_choice.choose_default(side)
		_show_choice()
		return true
	if id == MatchChoice.RANDOM:
		_choice.choose_random(side)
		_show_choice()
		return true
	var item: Variant = _library.find(id) if _library != null else null
	if item == null or not item.playable() or item.deck.rules.id != DeckRules.VERSUS:
		return false
	_choice.choose_deck(side, id, item.deck)
	_show_choice()
	return true


## side の部隊の選択肢（[id, 文字, 選べるか] の列。並びは画面と同じ）。検査用。
func deck_options(side: Unit.Side) -> Array:
	return _deck_choices[side].duplicate(true)


func _on_deck_picked(side: Unit.Side, index: int) -> void:
	var options: Array = _deck_choices[side]
	if index < 0 or index >= options.size() or not choose_deck(side, options[index][0]):
		_show_choice()


## 「対戦を始める」のボタン。対戦の途中なら、1 回目は確かめるだけで、もう一度押すと始める（_press_or_confirm）。
func press_start() -> void:
	_press_or_confirm(_start_button, confirm)


## 対戦を始める（確かめずに）。画面を閉じて、選んだものの写しを知らせる。
func confirm() -> void:
	stop_confirm()
	visible = false
	start_pressed.emit(_choice.copy())


## 押すといまの対戦が終わるボタン。対戦の途中でなければ、すぐ do。対戦の途中なら、1 回目はボタンを「もう一度押す」にして
## 理由を下の文に出すだけ。同じボタンをもう一度押すと do。確かめに変わった直後（BattleUiState.CONFIRM_GUARD_MSEC）の
## 2 回目は受けない（ダブルクリックで確かめを飛ばさない）。ほかの操作、右クリック・Esc で確かめをやめる。
func _press_or_confirm(button: Button, do: Callable) -> void:
	if not _in_progress:
		do.call()
		return
	if _confirming != button:
		stop_confirm()
		_confirming = button
		_confirm_started_msec = Time.get_ticks_msec()
		button.text = Text.t(CONFIRM_MAP_BUTTON) if button == _map_button else Text.t(CONFIRM_START_BUTTON)
		button.theme_type_variation = UiTheme.BUTTON_DANGER
		_warning.text = Text.t(CONFIRM_MAP_TEXT) if button == _map_button else Text.t(CONFIRM_START_TEXT)
		return
	if Time.get_ticks_msec() - _confirm_started_msec < BattleUiState.CONFIRM_GUARD_MSEC:
		return
	do.call()


## 確かめをやめる（ボタンと下の文を戻す）。確かめていなければ何もしない。
func stop_confirm() -> void:
	_confirming = null
	_map_button.text = Text.t(MAP_TEXT)
	_map_button.theme_type_variation = &""
	_start_button.text = _start_text
	_start_button.theme_type_variation = UiTheme.BUTTON_PRIMARY
	_warning.text = Text.t(WARNING_TEXT)


## 確かめの途中なら、下に出している理由の文（確かめていなければ空）。検査用。
func confirming_text() -> String:
	return "" if _confirming == null else _warning.text


## 確かめを始めた直後の、2 回目を受けない間を、もう過ぎたことにする。検査用（人が間を置いてもう一度押すのと同じ）。
func pass_confirm_guard() -> void:
	_confirm_started_msec -= BattleUiState.CONFIRM_GUARD_MSEC


func _choose(key: StringName, value: Variant) -> void:
	match key:
		&"opponent":
			choose_opponent(value)
		&"human_side":
			if value == RANDOM_SIDE:
				choose_random_side()
			else:
				choose_human_side(value)
		&"army0":
			choose_army(Unit.Side.PLAYER1, value)
		&"army1":
			choose_army(Unit.Side.PLAYER2, value)
		_:
			if String(key).begins_with("rule_"):
				choose_rule(StringName(String(key).trim_prefix("rule_")), value)


func _show_choice() -> void:
	if _rows.is_empty():
		return
	stop_confirm()  # 選び直したら、確かめはやめる
	var side_value: int = RANDOM_SIDE if _choice.random_side else _choice.human_side
	var current := {
		&"opponent": _choice.cpu_opponent, &"human_side": side_value,
		&"army0": _choice.armies[0], &"army1": _choice.armies[1],
	}
	for rule: StringName in RULE_ROWS:
		current[StringName("rule_%s" % rule)] = _choice.has_rule(rule)
	for key: StringName in _rows:
		var buttons: Dictionary = _rows[key]
		for value: Variant in buttons:
			(buttons[value] as Button).set_pressed_no_signal(value == current[key])
	_map_name.text = "%d %s" % [VersusFields.number_of(_choice.field), VersusFields.title_of(_choice.field)]
	var banner_key := StringName("%s:%s" % [_choice.field, _choice.has_rule(OptionalRules.STRONGHOLD)])  # 拠点の入・切でも縮図を描き直す
	if _banner_field != banner_key:
		_banner_field = banner_key
		var board := VersusFields.card_board(_choice.field, PLACEMENT_SEED)
		if board != null and _choice.has_rule(OptionalRules.STRONGHOLD):
			Stronghold.arm(board, PLACEMENT_SEED)  # 拠点の印も縮図に描く
		_banner.show_map(null if board == null else ImageTexture.create_from_image(MapCard.draw(board, VersusFields.look_of(_choice.field), _team_colors)))
	# 人どうしなら、手番は選ばない（先手・後手の 2 人が交代する）。
	for button: Button in _rows[&"human_side"].values():
		button.disabled = not _choice.cpu_opponent
	_side_caption.modulate.a = 1.0 if _choice.cpu_opponent else 0.4
	for side in 2:
		var human: bool = _choice.is_human(side as Unit.Side)
		_who_labels[side].text = who_text(side as Unit.Side)
		_who_labels[side].remove_theme_color_override("font_color")
		# 手番がランダムの間は、陣営が決まっていないので、陣営の色を付けない。
		var sided: bool = not (_choice.cpu_opponent and _choice.random_side)
		if sided:
			_who_labels[side].add_theme_color_override("font_color", _team_colors[side].lightened(0.4))
		var tint: Color = _team_colors[side] if sided else Color(0, 0, 0, 0)
		_banner.show_side(side, who_text(side as Unit.Side), _choice.armies[side], Names.army(_choice.armies[side]), tint)
		_side_boxes[side].add_theme_stylebox_override("panel", _side_box(tint))
		_edit_buttons[side].visible = human and _can_edit_decks
		_fill_deck_picker(side as Unit.Side)
		# ランダム編成は対戦を作るときに組むので、まだ組んでいなければ見せるものが無い（対戦の途中なら、いまの対戦の部隊を見せる）。
		var shown := preview_deck(side as Unit.Side) != null
		_preview_buttons[side].disabled = not shown
		_preview_buttons[side].tooltip_text = "" if shown else Text.t("setup.deck.random_note")
		# 初期位置は人の行だけ（CPU はいつもの置き方）。ランダム編成は部隊が決まっていないので決められない。
		_placement_buttons[side].visible = human
		_placement_buttons[side].disabled = _choice.is_random(side as Unit.Side)
		_placement_buttons[side].tooltip_text = Text.t("setup.deck.random_note") if _choice.is_random(side as Unit.Side) else ""
		_placement_buttons[side].text = Text.t("setup.placement") if _choice.placements[side].is_empty() else Text.t("setup.placement_set")


## 手番の行の注記（先手の必殺技のゲージ。始めが 0 なら空）。
static func first_gauge_note() -> String:
	if Ults.FIRST_PLAYER_START_GAUGE <= 0:
		return ""
	return Text.t("setup.side.first_gauge", {"percent": Ults.FIRST_PLAYER_START_GAUGE * 100 / Ults.GAUGE_MAX})


## side の行の見出し。CPU 戦なら「あなた」「CPU」と手番、人どうしなら手番だけ。
func who_text(side: Unit.Side) -> String:
	var turn: String = [Text.t("setup.side.first"), Text.t("setup.side.second")][side]
	if not _choice.cpu_opponent:
		return turn
	var who := Text.t("setup.who.you") if _choice.is_human(side) else "CPU"
	return who if _choice.random_side else Text.t("setup.who_side", {"who": who, "turn": turn})


## side の部隊（「編成確認」で出すもの）。選んだ部隊か既定の編成（CPU の行なら CPU の編成。中身は既定の編成と同じ）。
## ランダム編成なら、最後に作った対戦で組んだ部隊（まだ組んでいなければ null）。
func preview_deck(side: Unit.Side) -> Deck:
	if _choice.is_random(side):
		return _choice.drawn_deck(side)
	if not _choice.is_human(side) and _choice.deck_ids[side] == "":
		return CpuDeck.build(_choice.armies[side])
	return _choice.deck_for(side)


## 「編成を確認」: side の部隊を札にして出す。
func open_preview(side: Unit.Side) -> void:
	stop_confirm()
	var deck := preview_deck(side)
	if deck == null:
		return
	# ランダムの間は陣営が決まっていないので、あなたは青、CPU は赤で見せる。
	_preview.open(who_text(side), deck, side)


## 「初期位置」: 行 side の初期位置を、盤の縮図で決める窓を開く（人の行で、ランダム編成でないときだけ）。
func open_placement(side: Unit.Side) -> void:
	stop_confirm()
	if not _choice.is_human(side) or _choice.is_random(side):
		return
	_placing_row = side
	var shown: Array = _choice.placement_preview(side, PLACEMENT_SEED)
	var defined := VersusFields.scenario_of(_choice.field)
	_placement.open(who_text(side), shown, defined.deploy_cells_of(shown[2]), VersusFields.look_of(_choice.field), _team_colors, VersusFields.is_generated(_choice.field))


## side の行に「初期位置」を出しているか（検査用）。
func placement_button_shown(side: Unit.Side) -> bool:
	return _placement_buttons[side].visible


## 初期位置の窓（検査用）。
func placement_dialog() -> DeployDialog:
	return _placement


## side の「編成確認」を押せるか（検査用）。
func can_preview(side: Unit.Side) -> bool:
	return not _preview_buttons[side].disabled


## 編成の確認の画面（検査用）。
func preview() -> DeckPreview:
	return _preview


## 「部隊編成」（side の部隊を組む）。
func press_edit_decks(side: Unit.Side) -> void:
	visible = false
	decks_pressed.emit(_choice.copy(), side)


## 「部隊編成」が出ているか（検査用）。
func can_edit_decks() -> bool:
	return _can_edit_decks


## side の部隊の選択肢を並べ直す: 既定の編成（CPU の行では「CPU の編成」）、ランダム編成、その軍の取っておいた部隊（出せないものは理由つきで、選べない）。
func _fill_deck_picker(side: Unit.Side) -> void:
	var army: UnitKind.Army = _choice.armies[side]
	var default_deck := MatchSetup.default_deck(army)
	var default_key := "setup.deck.default" if _choice.is_human(side) else "setup.deck.cpu"
	var options: Array = [
		["", Text.t(default_key, {"cost": default_deck.total_cost(), "budget": default_deck.budget()}), true],
		[MatchChoice.RANDOM, Text.t("setup.deck.random"), true],
	]
	if _library != null:
		for item: RefCounted in _library.for_rules(DeckRules.VERSUS, army):
			var playable: bool = item.playable()
			var text := Text.t("setup.deck.saved", {"name": item.name, "cost": item.deck.total_cost(), "budget": item.deck.budget()})
			if not playable:
				text = Text.t("setup.deck.unplayable", {"name": item.name, "issue": item.issues()[0]})
			options.append([item.id, text, playable])
	_deck_choices[side] = options
	var picker := _deck_pickers[side]
	picker.clear()
	var chosen := 0
	for i in options.size():
		picker.add_item(options[i][1], i)
		picker.set_item_disabled(i, not options[i][2])
		if options[i][0] == _choice.deck_ids[side]:
			chosen = i
	picker.select(chosen)
