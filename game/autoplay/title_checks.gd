extends "res://game/autoplay/cpu_checks.gd"
## 自動の対戦の場面: 対戦の場面を抜けてタイトル・マップ選択・対戦設定を行き来する道と、部隊編成。


## 最後に、相手（CPU）の番の途中で、システムメニューの「タイトルへ戻る」を確かめてから選ぶ。対戦の場面が消えても、
## 止まっていた再生や CPU の番が続きを走らない（エラーが出ない）こと。そのあと、タイトルの「対戦」で対戦設定の場面へ進み、
## 「タイトルへ戻る」でタイトルへ戻る。このノードは対戦の場面の子なので、先にアプリの子へ移っておく。
func _leave_battle(app: Node) -> void:
	var menu: Node = app.system_menu()
	_scene.set_opponent(false)
	_scene.start_on_field(VersusFields.PLAIN, _scene.map_seed + 1)
	_scene.hide_notice()
	_scene.set_opponent(true)
	_end_turn()
	_expect(_scene.is_busy(), "ターンを終えても、相手の番に入らない")
	# ウィンドウの ×: すぐには閉じずに確かめる（どの画面でも同じ文）。確かめている間は時間を止める。キャンセルで続く。
	app.request_close()
	var quit_window: Node = app.quit_window
	_expect(quit_window.is_open() and quit_window.question().contains("セーブしていない内容は失われます。"),
		"対戦の途中にウィンドウの × を押しても、確かめない: %s" % quit_window.question())
	_expect(app.context.overlays.pauses() and Engine.time_scale == 0.0, "閉じる確かめの間、対戦の時間（再生）が止まらない")
	quit_window.cancel()
	_expect(not quit_window.is_open() and _scene.in_progress() and not app.context.overlays.is_open() and Engine.time_scale > 0.0,
		"閉じる確かめのキャンセルで、対戦へ戻らない（か、時間が止まったまま）")
	_scene.press_escape()
	_expect(menu.is_open() and menu.item_ids().has(&"title"), "相手の番の途中に、タイトルへ戻る項目が出ない")
	menu.press(&"title")
	_expect(menu.confirming() == &"title", "対戦の途中なのに、タイトルへ戻る前に確かめない")
	menu.accept()
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.TITLE and not menu.is_open() and Engine.time_scale == 1.0, "タイトルへ戻らない（か、時間が止まったまま）")
	# 消えた対戦の場面の、止まっていた待ち時間が過ぎるのを待つ（続きを走れば、エラーが出て検査が落ちる）。
	await get_tree().create_timer(1.0).timeout
	app.current_scene().press_start()
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.MAP_SELECT, "タイトルの「対戦」で、マップ選択へ進まない")
	var stages: Node = app.current_scene()
	await get_tree().process_frame
	_expect(stages.card_fields() == VersusFields.ids(), "マップのカードが一覧と合わない")
	for field in VersusFields.ids():
		var card: Control = stages.card_of(field)
		_expect(card.get_global_rect().size.x > 0.0 and _on_screen(card), "マップのカードが画面からはみ出す: %s" % field)
	stages.hover(VersusFields.TWIN_SPRINGS)
	_expect(stages.note_text().contains(VersusFields.title_of(VersusFields.TWIN_SPRINGS)), "カードに乗せても、説明が出ない")
	# カードを通り過ぎただけ（乗せて、待たずに離れた）なら、背景の景色は替えない。
	stages.hover(&"")
	_expect(stages.scape_field() != VersusFields.TWIN_SPRINGS, "カードを通り過ぎただけで、背景の景色が替わろうとした")
	stages.hover(VersusFields.TWIN_SPRINGS)
	# 背景の景色は、乗せたマップのものに替わる（少し待ってから、幕を沈めて替える。ここでは待たずに替える）。
	_expect(stages.scape_field() == VersusFields.TWIN_SPRINGS, "カードに乗せても、背景の景色がそのマップに替わろうとしない")
	stages.show_scape_now()
	_expect(stages.backdrop_look() == VersusFields.look_of(VersusFields.TWIN_SPRINGS), "カードに乗せても、背景の景色がそのマップのものにならない: %s" % stages.backdrop_look())
	stages.hover(&"")
	# どのカードに乗せても、ほかの部品（説明の欄、カードの段、ボタン）の位置と大きさが変わらない（説明の長さで揺れない）。
	var cards: Array[Node] = []
	for field in VersusFields.ids():
		cards.append(stages.card_of(field))
	await _expect_steady(stages, cards, VersusFields.ids().map(func(field: StringName) -> Callable: return stages.hover.bind(field)),
		"マップ選択でカードに乗せる")
	stages.hover(&"")
	# キーボードでは、左右の矢印で選ぶ（選んだカードの説明が出る）。
	var fields := VersusFields.ids()
	_push_key(app, KEY_RIGHT)
	_expect(stages.hovered_field() == fields[0], "マップ選択で右の矢印を押しても、最初のカードが選ばれない")
	_push_key(app, KEY_RIGHT)
	_push_key(app, KEY_RIGHT)
	_push_key(app, KEY_LEFT)
	_expect(stages.hovered_field() == fields[1] and stages.note_text().contains(VersusFields.title_of(fields[1])),
		"マップ選択で左右の矢印で選んでも、そのカードが選ばれない（か、説明が出ない）")
	stages.hover(&"")
	# マップを選ぶ前にも、部隊編成（対戦用）へ寄り道できる。戻るとマップ選択。
	stages.press_edit_decks()
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.DECKS and app.current_scene().mode() == DeckRules.VERSUS and app.current_scene().back_label() == "マップ選択へ戻る",
		"マップ選択の「部隊編成」で、対戦用の部隊編成へ進まない（か、戻り先の文字が違う）")
	app.current_scene().press_back()
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.MAP_SELECT, "マップ選択から開いた部隊編成の「マップ選択へ戻る」で、マップ選択へ戻らない")
	stages = app.current_scene()
	stages.choose(VersusFields.LABYRINTH)
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.SETUP, "マップ選択のカードで、対戦設定へ進まない")
	_expect(app.current_scene().setup_panel().current_choice().field == VersusFields.LABYRINTH, "選んだマップが対戦設定に渡らない")
	_expect(app.current_scene().backdrop_look() == VersusFields.look_of(VersusFields.LABYRINTH), "対戦設定の背景が、選んだマップの景色でない: %s" % app.current_scene().backdrop_look())
	app.current_scene().setup_panel().cancel()
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.MAP_SELECT, "対戦設定の「マップ選択へ戻る」で、マップ選択へ戻らない")
	# カードの上での右クリックでも戻る（カードのボタンに食われない）。
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	right.position = app.current_scene().card_center(VersusFields.LABYRINTH)
	right.global_position = right.position
	app.get_viewport().push_input(right)
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.TITLE, "マップ選択のカードの上で右クリックしても、タイトルへ戻らない")


## 部隊編成の場面: 組む・並べ替える・装備を持たせる・取っておく・写す・名前を変える・消す（確かめる）。
## 出せない部隊は取っておけない。取っておいた部隊を、対戦設定で選べる（出せない部隊は選べない）。
func _visit_decks(app: Node) -> void:
	var library: RefCounted = app.context.decks
	_expect(app.current_scene().button_texts() == (["ストーリー", "対戦", "オプション", "終了"] as Array[String]),
		"タイトルのメニューの並びが違う: %s" % [app.current_scene().button_texts()])
	# 部隊編成は、対戦設定の「部隊編成」から開く（タイトルには無い）。
	app.current_scene().press_start()
	await app.scene_changed
	app.current_scene().choose(VersusFields.PLAIN)
	await app.scene_changed
	var setup_panel: Node = app.current_scene().setup_panel()
	# 相手・手番・軍を選び替えても、パネルの部品の位置と大きさが変わらない。
	var setup_moves: Array = []
	for side: Unit.Side in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
		for army: UnitKind.Army in UnitKind.Army.values():
			setup_moves.append(setup_panel.choose_army.bind(side, army))
	setup_moves.append(setup_panel.choose_human_side.bind(Unit.Side.PLAYER2))
	setup_moves.append(setup_panel.choose_random_side)
	setup_moves.append(setup_panel.choose_opponent.bind(false))
	setup_moves.append(setup_panel.choose_opponent.bind(true))
	await _expect_steady(app.current_scene(), [], setup_moves, "対戦設定で選び替える")
	_expect(setup_panel.fits_screen(), "対戦設定のパネルが画面からはみ出している")
	setup_panel.choose_opponent(true)
	setup_panel.choose_human_side(Unit.Side.PLAYER1)
	setup_panel.choose_army(Unit.Side.PLAYER1, UnitKind.Army.MILITARY)
	# 初期位置: 人の行の「初期位置」で窓を開き、駒を動かして閉じると、その置き方で対戦が作られる。
	setup_panel.open_placement(Unit.Side.PLAYER1)
	var dialog: Control = setup_panel.placement_dialog()
	var place_map: Control = dialog.deploy_map()
	var placed_cells: Array[Vector2i] = place_map.unit_cells()
	var open_cells: Array = place_map.zone().filter(func(cell: Vector2i) -> bool: return not placed_cells.has(cell))
	_expect(dialog.visible and not placed_cells.is_empty() and not open_cells.is_empty(), "対戦設定の「初期位置」で、駒と置けるマスの窓が開かない")
	var place_note: Control = dialog.deploy_note()
	_expect(place_note.shown_unit_id() == -1, "初期位置の窓で、駒を選ぶ前から駒の欄に駒が出ている")
	await _hover_each(place_map)
	place_map.hover_cell(placed_cells[1])
	var hovered_unit: Unit = place_map.focused_unit()
	_expect(hovered_unit != null and place_note.shown_name() == Names.kind(hovered_unit.kind), "初期位置の窓で、マウスを乗せた駒の名前が欄に出ない")
	place_map.press_cell(placed_cells[0])
	var picked_unit: Unit = place_map.focused_unit()
	_expect(picked_unit != hovered_unit and place_note.shown_unit_id() == picked_unit.id, "初期位置の窓で、選んだ駒が欄に出ない（マウスを乗せた駒より先に）")
	# 選んだ駒を、マウスを乗せた駒と入れ替えると、マウスの下には選んだ駒が来る（欄も、その駒を出す）。
	place_map.press_cell(placed_cells[1])
	_expect(place_map.selected() == -1 and place_map.focused_unit() == picked_unit and place_note.shown_unit_id() == picked_unit.id,
		"初期位置の窓で駒を入れ替えたあと、マウスの下の駒が古いまま")
	place_map.reset()
	_expect(place_map.focused_unit() == hovered_unit, "初期位置の窓で「おまかせ」に戻したあと、マウスの下の駒が古いまま")
	place_map.hover_cell(Deployment.NO_CELL)
	place_map.press_cell(placed_cells[0])
	place_map.press_cell(open_cells[0])
	dialog.close_dialog()
	var placed_choice: RefCounted = setup_panel.current_choice()
	_expect(not dialog.visible and not placed_choice.placements[Unit.Side.PLAYER1].is_empty(), "初期位置の窓を閉じても、決めた置き方が対戦設定に残らない")
	var placed_battle: Battle = placed_choice.to_setup(setup_panel.PLACEMENT_SEED).create_battle()
	var first_unit: Array = placed_battle.units.filter(func(unit: Unit) -> bool: return unit.side == Unit.Side.PLAYER1 and unit.kind != UnitKind.Id.KING)
	_expect(first_unit[0].cell == open_cells[0], "対戦設定で決めた初期位置から、対戦が始まらない")
	_expect(not setup_panel.placement_button_shown(Unit.Side.PLAYER2), "CPU の行に「初期位置」がある")
	setup_panel.choose_army(Unit.Side.PLAYER1, UnitKind.Army.FANTASY)
	_expect(placed_choice.placements[Unit.Side.PLAYER1].is_empty(), "軍（部隊）を替えても、初期位置がおまかせに戻らない")
	setup_panel.choose_army(Unit.Side.PLAYER1, UnitKind.Army.MILITARY)
	_expect(setup_panel.can_edit_decks(), "対戦設定に「部隊編成」が無い")
	setup_panel.press_edit_decks(Unit.Side.PLAYER1)
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.DECKS, "対戦設定の「部隊編成」で、編成の場面へ進まない")
	var screen: Node = app.current_scene()
	_expect(screen.is_detour() and screen.mode() == DeckRules.VERSUS and screen.back_label() == "対戦設定へ戻る", "対戦設定からの編成が、対戦用でない（か、戻り先の文字が違う）")
	_expect(screen.listed_ids().is_empty() and screen.list_card_kinds().is_empty(), "部隊が無いのに、一覧か札が出ている")
	screen.press_new()
	_expect(screen.is_choosing_army() and not screen.is_editing(), "「新しい部隊」で、まず軍を選ぶ画面が出ない")
	screen.press_back()
	_expect(not screen.is_choosing_army() and not screen.is_editing(), "軍を選ぶ画面から、右クリックで一覧へ戻らない")
	screen.press_new()
	screen.choose_new_army(UnitKind.Army.MILITARY)
	_expect(screen.is_editing() and screen.editing_deck().entries.is_empty() and screen.editing_deck().army == UnitKind.Army.MILITARY, "選んだ軍で、空の部隊を組めない")
	_expect(not screen.is_choosing_army(), "軍を選んで組む画面へ進んでも、軍を選ぶ画面が後ろに残っている")
	_expect(not screen.can_save(), "空の部隊を取っておけた")
	screen.hire(UnitKind.Id.SHIELD_TROOPER)
	screen.hire(UnitKind.Id.SNIPER)
	_expect(screen.selected_entry() == 1, "雇った駒が選ばれない")
	screen.select_entry(0)
	screen.equip(Equipment.Id.IRON_SHIELD)
	var deck: Deck = screen.editing_deck()
	_expect(deck.entries[0].kind == UnitKind.Id.SHIELD_TROOPER and deck.entries[0].equipment.size() == 1 and screen.selected_entry() == 0, "選んだ駒に、持ち物を持たせられない")
	_expect(screen.troop_row_button_texts(0).filter(func(text: String) -> bool: return text in ["▲", "▼"]).is_empty(), "部隊の行に、並べ替え（配置）のボタンが残っている")
	# 装備の文が行に収まらなくても、マウスを乗せれば全部読める。
	screen.equip(Equipment.Id.SPEED_BOOTS)
	var row_texts: Array[String] = screen.troop_row_texts(0)
	_expect(row_texts[1] == row_texts[0] and row_texts[1].contains("スピードブーツ") and row_texts[1].contains("アイアンシールド"),
		"部隊の行の装備の文を、マウスを乗せても読めない: %s" % [row_texts])
	screen.unequip(Equipment.Id.SPEED_BOOTS)
	# どの駒に乗せても、どの駒を選んでも、ほかの部品（列、見出し、ボタン）の位置と大きさが変わらない。
	# （選ぶ・選ぶのをやめるのはクリックなので、持ち物の欄が出入りしてよい。比べるのは、選んだまま乗せる・選び替える。）
	for selected: int in [-1, 0]:
		screen.select_entry(selected)
		var editor_moves: Array = []
		for kind: UnitKind.Id in screen.editing_deck().available_kinds():
			editor_moves.append(screen.hover_kind.bind(kind))
		editor_moves.append(screen.hover_kind.bind(-1))
		if selected != -1:
			editor_moves.append(screen.select_entry.bind(1))
			editor_moves.append(screen.select_entry.bind(0))
		await _expect_steady(screen, [], editor_moves, "部隊編成で駒に乗せる・選ぶ")
	screen.select_entry(0)
	for i in 4:
		screen.hire(UnitKind.Id.SHIELD_TROOPER)
	screen.equip(Equipment.Id.SPEED_BOOTS)  # 予算 24 を 1 超える
	_expect(screen.trait_text() == Names.troop_trait_text(Traits.Id.FOCUS), "軍略の欄に、連邦の既定の軍略の文が出ない: %s" % screen.trait_text())
	var trait_moves: Array[Callable] = [screen.choose_trait.bind(Traits.Id.SUPPLY), screen.choose_trait.bind(Traits.Id.RANKS), screen.choose_trait.bind(Traits.Id.FOCUS)]
	await _expect_steady(screen, [], trait_moves, "部隊編成で軍略を選ぶ")
	_expect(screen.trait_cut_texts().is_empty(), "部隊編成の軍略の欄の文が、切れているか札からはみ出している（連邦）: %s" % [screen.trait_cut_texts()])
	screen.choose_trait(Traits.Id.VENGEANCE)  # 騎士領の軍略は選べない
	_expect(deck.trait_id == Traits.Id.FOCUS, "連邦の部隊に、騎士領の軍略が付いた")
	_expect(not screen.can_save() and deck.problems() == ([Deck.Problem.OVER_BUDGET] as Array[Deck.Problem]), "予算を超えた部隊を取っておけた")
	await screen.get_tree().process_frame
	await screen.get_tree().process_frame
	_expect(screen.issues_shown_whole(), "出撃不可の理由が、途中で切れている")
	screen.press_save()
	_expect(screen.is_editing() and library.size() == 0, "出せない部隊が取っておかれた")
	screen.remove_entry(5)
	screen.press_back()  # 選択をやめる
	_expect(screen.selected_entry() == -1 and screen.is_editing(), "右クリックで、選択をやめない")
	screen.press_save()
	_expect(not screen.is_editing() and library.size() == 1, "出せる部隊を取っておけない")
	var id: String = screen.list_selected()
	# 対戦設定で選べる。
	screen.press_duplicate()
	_expect(library.size() == 2, "写せない")
	screen.press_rename()
	screen.set_dialog_input("写しの部隊")
	screen.accept_dialog()
	_expect(library.find(screen.list_selected()).name == "写しの部隊", "名前を変えられない")
	screen.press_delete()
	_expect(screen.is_dialog_open() and library.size() == 2, "消す前に確かめない")
	screen.press_back()
	_expect(not screen.is_dialog_open() and library.size() == 2, "確かめを、やめられない")
	screen.press_delete()
	screen.accept_dialog()
	_expect(library.size() == 1, "消せない")
	# 変えたところがあれば、取っておかずに戻る前に確かめる。
	screen.select_saved(id)
	_expect(screen.list_card_kinds().size() == library.find(id).deck.entries.size() + 1, "一覧の右に、選んだ部隊の駒の札が並ばない")
	await screen.get_tree().process_frame
	await screen.get_tree().process_frame
	_expect(screen.list_card_cut_texts().is_empty(), "一覧の右の駒の札の文が切れている: %s" % [screen.list_card_cut_texts()])
	screen.press_edit()
	screen.remove_entry(0)
	screen.press_back()
	_expect(screen.is_dialog_open(), "変えたところがあるのに、確かめずに一覧へ戻った")
	screen.accept_dialog()
	_expect(not screen.is_editing() and library.find(id).deck.entries.size() == 5, "取っておかずに戻ったのに、部隊が変わった")
	# 軍略（docs/troop-traits.md）: 騎士領の部隊は仇討ちから始まる。誓いを選んだときだけ、2 人を結ぶ操作が出る。
	screen.press_new()
	screen.choose_new_army(UnitKind.Army.FANTASY)
	for kind: UnitKind.Id in [UnitKind.Id.PALADIN, UnitKind.Id.SORCERER, UnitKind.Id.SPELLBLADE]:
		screen.hire(kind)
	screen.select_entry(-1)
	_expect(screen.editing_deck().trait_id == Traits.Id.VENGEANCE and not screen.shows_oaths(), "騎士領の既定の軍略が仇討ちでない")
	screen.press_oath(0)
	_expect(screen.binding_entry() == -1, "誓いを選んでいないのに、結ぶ相手を選び始めた")
	screen.choose_trait(Traits.Id.OATH)
	_expect(screen.shows_oaths() and screen.trait_text() == Names.troop_trait_text(Traits.Id.OATH), "誓いを選んでも、誓いの操作が出ない")
	screen.press_oath(0)
	screen.press_oath(1)
	_expect(screen.editing_deck().oath_pairs() == ([Vector2i(0, 1)] as Array[Vector2i]), "誓いを結べない")
	screen.choose_trait(Traits.Id.GUARD)
	_expect(not screen.shows_oaths() and screen.editing_deck().oath_pairs().size() == 1, "軍略を替えたら、結んだ組が消えた")
	await screen.get_tree().process_frame
	_expect(screen.trait_cut_texts().is_empty(), "部隊編成の軍略の欄の文が、切れているか札からはみ出している（騎士領）: %s" % [screen.trait_cut_texts()])
	screen.press_back()
	if screen.is_dialog_open():
		screen.accept_dialog()
	_expect(not screen.is_editing() and library.size() == 1, "騎士領を試した部隊を、取っておかずに戻れない")
	# ストーリー用の部隊: 切り替えると、対戦用の部隊は並ばない。雇える駒は、いま解放した駒だけ。
	_expect(screen.mode() == DeckRules.VERSUS and screen.listed_ids() == ([id] as Array[String]), "対戦用の一覧が違う")
	screen.set_mode(Story.military().rules_id)
	_expect(screen.listed_ids().is_empty(), "ストーリー用の一覧に、対戦用の部隊が混ざった")
	screen.press_new()
	_expect(screen.editing_deck().rules.id == Story.military().rules_id and screen.editing_deck().army == Story.military().army, "ストーリー用の部隊を、ストーリーの決まりで組めない")
	_expect(screen.editing_deck().available_kinds() == app.context.story.unlocked_kinds() or screen.editing_deck().available_kinds().size() == app.context.story.unlocked_kinds().size(), "ストーリー用の雇える駒が、いま解放した駒と違う")
	screen.hire(UnitKind.Id.COMMANDO)
	_expect(screen.editing_deck().entries.is_empty() or app.context.story.unlocked_kinds().has(UnitKind.Id.COMMANDO), "まだ解放していない駒を雇えた")
	screen.hire(UnitKind.Id.SNIPER)
	screen.hire(UnitKind.Id.SNIPER)
	screen.hire(UnitKind.Id.MEDIC)
	# まだ持たせられない持ち物（物語の解放の前）は、持たせられない。
	screen.select_entry(0)
	for item: Equipment.Id in Equipment.Id.values():
		if not screen.editing_deck().rules.allows_item(item):
			screen.equip(item)
			_expect(screen.editing_deck().entries[0].count(item) == 0, "まだ持たせられない持ち物を持たせられた")
	screen.select_entry(-1)
	screen.press_save()
	var story_id: String = screen.list_selected()
	_expect(not screen.is_editing() and screen.listed_ids() == ([story_id] as Array[String]), "ストーリー用の部隊を取っておけない")
	_expect(library.find(story_id).deck.rules.id == Story.military().rules_id, "ストーリー用の部隊が、ストーリーの決まりで取っておかれていない")
	# ストーリー用は物語ごと: ほかの物語の決まりでは、その物語の軍で組み、ほかの物語の部隊は並ばない。
	var other: RefCounted = Story.campaigns()[1]
	screen.set_mode(other.rules_id)
	_expect(screen.mode() == other.rules_id and screen.rules.armies() == ([other.army] as Array[UnitKind.Army]), "ほかの物語の、ストーリー用の決まりで組めない")
	_expect(screen.listed_ids().is_empty(), "ほかの物語のストーリー用の一覧に、別の物語の部隊が混ざった")
	screen.set_mode(DeckRules.VERSUS)
	_expect(screen.listed_ids() == ([id] as Array[String]), "対戦用の一覧に、ストーリー用の部隊が混ざった")
	var versus_ids: Array[String] = []
	for item: RefCounted in library.for_rules(DeckRules.VERSUS):
		versus_ids.append(item.id)
	_expect(not versus_ids.has(story_id), "対戦設定で選べる部隊に、ストーリー用の部隊が混ざった")
	screen.select_saved(id)
	screen.press_edit()
	screen.press_save()  # 寄り道の間に最後に取っておいた部隊が、戻った対戦設定で選ばれる
	screen.press_back()
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.SETUP, "編成の一覧から、対戦設定へ戻らない")
	var panel: Node = app.current_scene().setup_panel()
	_expect(panel.current_choice().deck_ids[0] == id, "寄り道で取っておいた部隊が、対戦設定で選ばれていない")
	var ids: Array = panel.deck_options(Unit.Side.PLAYER1).map(func(option: Array) -> String: return option[0])
	_expect(ids == ["", MatchChoice.RANDOM, id], "対戦設定に、取っておいた部隊が並ばない: %s" % [ids])
	_expect(panel.choose_deck(Unit.Side.PLAYER1, id), "取っておいた部隊を選べない")
	panel.open_preview(Unit.Side.PLAYER1)
	_expect(panel.preview().visible and panel.preview().shown_kinds().size() == 6, "「編成を確認」で、選んだ部隊が出ない")
	# 札を押すと、その駒の詳しい説明（役割・能力値・スキル・持ち物の効果・進化先）。将も。
	panel.preview().press_card(-1)
	_expect(panel.preview().detail().visible and panel.preview().detail().title_text() == Names.kind(UnitKind.Id.KING), "「編成確認」で将の札を押しても、詳しい説明が出ない")
	panel.preview().close_preview()
	_expect(not panel.preview().detail().visible, "編成確認を閉じても、詳しい説明が残る")
	# マップは対戦設定では選ばない。「マップ選択へ戻る」で戻って選び直す（選んだものは残る）。マップ選択へ行くボタンは 1 つ。
	_expect(not panel.map_button_shown(), "対戦設定に、マップ選択へ行くボタンが 2 つある")
	panel.choose_random_side()
	panel.cancel()
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.MAP_SELECT, "「マップ選択へ戻る」で、マップ選択へ戻らない")
	app.current_scene().choose(VersusFields.LABYRINTH)
	await app.scene_changed
	panel = app.current_scene().setup_panel()
	_expect(panel.current_choice().field == VersusFields.LABYRINTH and panel.current_choice().random_side and panel.current_choice().deck_ids[0] == id,
		"マップを選び直したら、ほかの選択が失われた")
	panel.choose_human_side(Unit.Side.PLAYER1)
	var setup: MatchSetup = panel.current_choice().to_setup(1)
	_expect(setup.is_valid() and setup.decks[0].entries.size() == 5 and setup.decks[0].entries[0].kind == UnitKind.Id.SHIELD_TROOPER, "選んだ部隊で対戦を作らない")
	_expect(setup.decks[1].entries.size() == CpuDeck.build(setup.army_of(Unit.Side.PLAYER2)).entries.size(), "CPU の編成が変わった")
	panel.cancel()
	await app.scene_changed


## 画面の大きさを少し変えて戻す。抜けた場面の部品が、画面の大きさの合図につながったまま残っていれば、ここでエラーになる。
## 部隊編成の持ち物が多いとき、窓を縦に広げてから元へ縮めても、駒の札が縮まず、元の大きさと置き場所に戻る
## （持ち物の欄の高さは画面の高さから決め直す。deck_screen/deck_unit_card.gd の _fit_equip）。広げたままでも、札は下限を割らない。
func _resize_deck_screen(screen: Node, campaign: RefCounted) -> void:
	var window := get_window()
	var size := window.content_scale_size
	screen.select_entry(0)
	await get_tree().process_frame
	await get_tree().process_frame
	var before: Rect2 = screen.detail_card_rect()
	for bigger: Vector2i in [size + Vector2i(0, 280), size + Vector2i(440, 0), size + Vector2i(0, 600)]:
		window.content_scale_size = bigger
		await get_tree().process_frame
		await get_tree().process_frame
		_expect(screen.detail_card_rect().size.y >= screen.DETAIL_MIN_HEIGHT - 0.5, "部隊編成の窓を %s に広げたら、駒の札が縮んだ（%s）: %s" % [bigger, campaign.title, screen.detail_card_rect()])
		window.content_scale_size = size
		await get_tree().process_frame
		await get_tree().process_frame
		_expect(screen.detail_card_rect().is_equal_approx(before), "部隊編成の窓を %s に広げてから縮めたら、駒の札が元に戻らない（%s）: %s（前は %s）" % [bigger, campaign.title, screen.detail_card_rect(), before])
		_expect(screen.item_row_cut_texts().is_empty(), "部隊編成の窓を広げてから縮めたら、持ち物の欄の文が切れた（%s）: %s" % [campaign.title, screen.item_row_cut_texts()])
