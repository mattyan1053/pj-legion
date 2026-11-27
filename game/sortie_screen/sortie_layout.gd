extends "res://game/sortie_screen/sortie_choice.gd"
## 出撃準備の場面の、枠の組み立て（見出しの段、左の初期位置の欄、右の勝利条件・敵の部隊・出撃する部隊の欄、下のボタン）と、
## 枠の大きさ・勝利条件の札の検査用の入口。sortie_choice.gd を継ぐ。


## 見出しの段（題と飾りの線、右に「この話で覚えること」の札）を root に足す。
func _build_header(root: VBoxContainer) -> void:
	# 見出しの段: 左に題と飾りの線、右に「この話で覚えること」の札（演習だけ）。段の高さは、札の有る無しで変えない。
	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0.0, HEADER_HEIGHT)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(header)
	var title_column := VBoxContainer.new()
	title_column.add_theme_constant_override("separation", 6)
	title_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(title_column)
	var heading := _text(30, COLOR_TEXT)
	heading.theme_type_variation = UiTheme.LABEL_HEADING
	heading.add_theme_constant_override("outline_size", 10)  # 景色の上に直に置くので、縁取りを太くする
	heading.text = Text.t("sortie.heading", {"number": Story.number_of(episode), "title": episode.title})
	title_column.add_child(heading)
	# 見出しの下の飾りの線は、人の軍の国の色（話の一覧と同じ）。
	var heading_line := Ornament.new(520.0, 8.0)
	heading_line.color = NationDecor.color_of(context.story.campaign.army)
	heading_line.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	title_column.add_child(heading_line)
	if episode.lesson != "":
		header.add_child(_build_lesson(episode.lesson))
		# 右上のシステムメニューのボタンに掛からないよう、札の右を空けておく。
		var corner := Control.new()
		corner.custom_minimum_size = Vector2(SystemMenu.CORNER_BUTTON_SIZE.x + SystemMenu.CORNER_MARGIN - 40.0, 0.0)
		corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		header.add_child(corner)


## 左の欄: 初期位置の縮図と「おまかせ」、その下の駒の欄を body に足す。
func _build_map_panel(body: HBoxContainer) -> void:
	var left := _panel()
	Steady.mark(left, "sortie.map", Steady.RECT)
	body.add_child(left)
	var left_column := VBoxContainer.new()
	left_column.add_theme_constant_override("separation", 12)
	left.add_child(left_column)
	# 初期位置: 盤の縮図に置けるマスを縁取り、駒を押してからマスを押すと置く（deploy_map.gd）。「おまかせ」でいつもの置き方へ。
	var map_head := HBoxContainer.new()
	map_head.add_theme_constant_override("separation", 12)
	left_column.add_child(map_head)
	var map_caption := _caption(Text.t("sortie.map", {"map": episode.map_title}))
	map_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_head.add_child(map_caption)
	_auto_button = _button(Text.t("sortie.auto_place"), 15)
	_auto_button.custom_minimum_size = Vector2(120.0, 32.0)
	_auto_button.pressed.connect(press_auto_place)
	map_head.add_child(_auto_button)
	_deploy = DeployMap.new()
	var board_size := Vector2(episode.map.make_board().size)
	_deploy.custom_minimum_size = board_size * minf(MAP_CELL, MAP_MAX_HEIGHT / board_size.y)
	_deploy.read_only = is_placement_fixed()
	_deploy.changed.connect(func() -> void:
		battle_source.placement = _deploy.offsets()
		_auto_button.disabled = _deploy.is_default())
	left_column.add_child(_deploy)
	if _deploy.read_only:
		var map_hint := _text(14, COLOR_DIM)
		map_hint.text = Text.t("sortie.place_fixed")
		left_column.add_child(map_hint)
	# 選んでいる駒（マウスを乗せている駒）の名前・役割・能力値（deploy_note.gd）。欄の下の端に置く（マップの大きさで場所が変わらない）。
	var map_rest := Control.new()
	map_rest.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_rest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_column.add_child(map_rest)
	_deploy_note = DeployNote.new()
	Steady.mark(_deploy_note, "sortie.unit_note", Steady.RECT)
	left_column.add_child(_deploy_note)
	_deploy_note.watch(_deploy)


## 右の欄の勝利条件の札を right に足す。
func _build_goal_panel(right: VBoxContainer) -> void:
	# 勝利条件の欄は、対戦の上の帯の勝利条件の札と同じ色（金を混ぜた地と縁）。札の数で高さは変わらない（どの札も同じ大きさ）。
	var goal := _panel()
	goal.add_theme_stylebox_override("panel", _padded(UiTheme.box(Color(Palette.GOAL.lerp(Palette.PANEL, 0.55), 0.94), Palette.GOAL_BORDER, 1, 8, PANEL_PAD.x)))
	Steady.mark(goal, "sortie.goal", Steady.RECT)
	right.add_child(goal)
	var goal_column := VBoxContainer.new()
	goal_column.add_theme_constant_override("separation", 2)
	goal.add_child(goal_column)
	# 勝利条件の札（対戦の始めの「対戦ルール」と同じ札。rule_card.gd）。
	Names.set_boss(battle_source.boss_name())  # 札の中ボスの名前（話のファイルの boss）
	goal_column.add_child(_caption(Text.t("sortie.goal")))
	# 札は欄の真ん中に寄せる（対戦の始めの「対戦ルール」と同じ。1 枚でも 3 枚でも、左右の空きが同じ）。
	var goal_row := HBoxContainer.new()
	goal_row.alignment = BoxContainer.ALIGNMENT_CENTER
	goal_row.add_theme_constant_override("separation", int(GOAL_CARD_GAP))
	goal_column.add_child(goal_row)
	_goal_cards.clear()
	for card: Array in goal_cards():
		if _goal_cards.size() >= GOAL_CARDS:
			break
		var shown := RuleCard.new()
		shown.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		goal_row.add_child(shown)
		shown.show_goal(card[1], card[2], card[3])
		_goal_cards.append(shown)


## 右の欄の敵の部隊（駒の額）を right に足す。
func _build_enemy_panel(right: VBoxContainer) -> void:
	var enemy := _panel()
	Steady.mark(enemy, "sortie.enemy", Steady.RECT)
	right.add_child(enemy)
	_decorate(enemy, episode.enemy_army, Palette.TEAM_RED)
	var enemy_column := VBoxContainer.new()
	enemy_column.add_theme_constant_override("separation", 2)
	enemy.add_child(enemy_column)
	enemy_column.add_child(_army_caption(Text.t("sortie.enemy", {"army": DeckText.army_name(episode.enemy_army)}), episode.enemy_army))
	# 敵の駒の額（押すと詳しい説明。魔物も）。名前と持ち物は、額に乗せると出る。
	_enemy_faces = _faces_row(ENEMY_FACE_ROWS)
	enemy_column.add_child(_enemy_faces)
	_fill_faces(_enemy_faces, battle_source.scenario().fixed_decks[Unit.Side.PLAYER2], Unit.Side.PLAYER2, start_levels(Unit.Side.PLAYER2))

## 右の欄の出撃する部隊（見出しと「部隊編成」、駒の額、選べる部隊の並び）を right に足す。
func _build_troops_panel(right: VBoxContainer) -> void:
	var troops := _panel()
	troops.size_flags_vertical = Control.SIZE_EXPAND_FILL
	Steady.mark(troops, "sortie.troops", Steady.RECT)
	right.add_child(troops)
	_decorate(troops, context.story.campaign.army, Palette.TEAM_BLUE)
	var troops_column := VBoxContainer.new()
	troops_column.add_theme_constant_override("separation", 4)
	troops.add_child(troops_column)
	var troops_head := HBoxContainer.new()
	troops_head.add_theme_constant_override("separation", 12)
	troops_head.custom_minimum_size = Vector2(0.0, 36.0)  # 「部隊編成」のボタンの無い話（部隊が決まっている話）でも、同じ高さ
	troops_column.add_child(troops_head)
	var troops_caption := _army_caption(Text.t("sortie.troops"), context.story.campaign.army)
	troops_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	troops_head.add_child(troops_caption)
	var edit := _button(Text.t("setup.edit_deck"), 16)
	edit.custom_minimum_size = Vector2(180.0, 36.0)
	edit.pressed.connect(press_edit_decks)
	# 流れの外から置いたとき（検査）は、戻る先が無いので出さない。部隊が決まっている話も出さない。
	edit.visible = context.run != null and not is_squad_fixed()
	troops_head.add_child(edit)
	# 選んだ部隊の駒の額（将から並びの順。unit_icons.gd）。見出しのすぐ下に置く（出撃する部隊が、まず目に入る）。
	# 中身は文で並べない。額の下に持ち物の印、名前と持ち物は額に乗せると出る。
	_deck_faces = _faces_row(DECK_FACE_ROWS)
	troops_column.add_child(_deck_faces)
	# 選べる部隊の並び（部隊が決まっている話は 1 行）。いつも OPTIONS_SHOWN 行ぶんが見える高さを取り、多ければ欄の中で送る。
	# ホイールは 1 目盛りで 1 行ぶん送る（そのままだと、欄の高さの 1/8 ずつしか動かない）。送りの棒は、つかみやすい太さにする。
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0.0, OPTIONS_HEIGHT)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.get_v_scroll_bar().custom_minimum_size.x = SCROLL_BAR_WIDTH
	scroll.gui_input.connect(func(event: InputEvent) -> void:
		var wheel := event as InputEventMouseButton
		if wheel != null and wheel.pressed and wheel.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			scroll_options(-1 if wheel.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
			scroll.accept_event())
	Steady.mark(scroll, "sortie.options", Steady.RECT)
	troops_column.add_child(scroll)
	_options_scroll = scroll
	_options = VBoxContainer.new()
	_options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_options.add_theme_constant_override("separation", int(OPTION_GAP))
	scroll.add_child(_options)


## 下のボタン（「話の一覧へ戻る」と「出撃」）を root に足す。
func _build_footer(root: VBoxContainer) -> void:
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 16)
	root.add_child(footer)
	# 「出撃」は、この画面の見せ場: 明朝の大きな字にして、左右へ飾りの線を伸ばす。
	footer.add_child(_footer_line())
	var back := _button(Text.t("story.episodes.resume"), 18)
	back.custom_minimum_size = Vector2(220.0, 48.0)
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(press_back)
	footer.add_child(back)
	_sortie = _button(Text.t("sortie.go"), 24)
	_sortie.custom_minimum_size = Vector2(300.0, 48.0)
	_sortie.set_meta(&"sound", &"ui_confirm")
	_sortie.theme_type_variation = UiTheme.BUTTON_PRIMARY
	_sortie.add_theme_font_override("font", UiTheme.FONT_HEADING)
	_sortie.pressed.connect(press_sortie)
	footer.add_child(_sortie)
	footer.add_child(_footer_line())


## 勝利条件の札（[&"goal", 勝ち方, 短い名前, 1 行]。話の戦いの定義の勝ちの条件から。人はプレイヤー1。BattleTexts.goal_cards）。
func goal_cards() -> Array[Array]:
	var scenario: Scenario = battle_source.scenario()
	var conditions: Array = [scenario.win_conditions_of(Unit.Side.PLAYER1), scenario.win_conditions_of(Unit.Side.PLAYER2)]
	return BattleTexts.goal_cards(conditions, scenario.hold_turns, Unit.Side.PLAYER1)


## 勝利条件の欄に出している札（検査用）。
func shown_goal_cards() -> Array:
	return _goal_cards


## 画面に収めるのに要る高さ（px。上下の余白を含む。検査用。いちばん低い画面の 720 を超えないこと）。
func needed_height() -> float:
	return _root.get_combined_minimum_size().y + MARGIN_Y * 2.0


## 枠の大きさ（勝利条件・敵の部隊・出撃する部隊・初期位置。検査用。どの話でも同じ）。
func frame_rects() -> Dictionary:
	var rects := {}
	for frame: Control in get_tree().get_nodes_in_group(Steady.GROUP):
		if is_ancestor_of(frame) and Steady.kind_of(frame) == Steady.RECT and Steady.name_of(frame) != "sortie.lesson":
			rects[Steady.name_of(frame)] = frame.get_global_rect()
	return rects
