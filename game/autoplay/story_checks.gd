extends "res://game/autoplay/title_checks.gd"
## 自動の対戦の場面: ストーリーの通し（物語とセーブデータの選択、話の一覧、出撃準備、会話、対戦、決着、解放）。


func _visit_story(app: Node) -> void:
	var story: RefCounted = app.context.story
	story.choose_campaign(Story.military())
	for each: RefCounted in Story.military().episodes:
		if each.squad_deck() == null:
			break
		story.clear(each.id)
	var episode: RefCounted = story.next_episode()
	var first := Story.military().episodes.find(episode)
	_expect(first > 0 and episode.squad_deck() == null, "部隊を選ぶ話が無い")
	_expect(not story.is_cleared(episode.id), "始める前から、話をクリアしている")
	_expect(app.current_scene().story_label() == "ストーリー", "クリア前のタイトルに、済みの印が付いている")
	app.current_scene().press_story()
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.SLOTS, "タイトルの「ストーリー」で、セーブデータ選択へ進まない")
	# セーブデータ選択: どのスロットもまだ空き（はじめから）。1 番を選ぶと、物語を選ぶ場面へ。
	var slots_screen: Node = app.current_scene()
	# （1 番は、前の場面の部隊編成でストーリー用の部隊を組んでいれば、もう書いてある）
	for number in range(1, 4):
		_expect(slots_screen.is_card_enabled(number) and (slots_screen.card_text(number).ends_with("はじめから") or number == 1), "空きのスロット %d が「はじめから」でない" % number)
	var saves_before: int = app.save_mark.shown_count
	slots_screen.choose(1)
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.CAMPAIGNS, "セーブデータ選択でスロットを選んでも、物語を選ぶ場面へ進まない")
	_expect(app.context.slots.is_started() and story.is_cleared(Story.military().episodes[0].id), "はじめからで始めたスロットに、前から持っていた進み具合が残っていない")
	var campaigns: Node = app.current_scene()
	_expect(campaigns.campaigns() == Story.campaigns(), "物語を選ぶ場面に、全部の物語が並んでいない")
	for each: RefCounted in Story.campaigns():
		_expect(campaigns.is_card_enabled(each) == Story.is_ready(each)
				and (campaigns.status_text(each) == "準備中") == not Story.is_ready(each), "話の無い物語を選べる（か、ある物語を選べない）: %s" % each.title)
	# 物語選択の「部隊編成」（物語ごと）: その物語のストーリー用の部隊編成へ。戻ると物語選択。
	campaigns.press_edit_decks(Story.campaigns()[1])
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.DECKS and app.current_scene().mode() == Story.campaigns()[1].rules_id and app.current_scene().back_label() == "物語選択へ戻る",
		"物語選択の「部隊編成」で、その物語のストーリー用の部隊編成へ進まない（か、戻り先の文字が違う）")
	app.current_scene().press_back()
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.CAMPAIGNS, "物語選択から開いた部隊編成の「物語選択へ戻る」で、物語選択へ戻らない")
	campaigns = app.current_scene()
	campaigns.choose(Story.military())
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.EPISODES and story.campaign == Story.military(), "物語を選んでも、その物語の話の一覧へ進まない")
	var list: Node = app.current_scene()
	# 話の一覧の「部隊編成」: この物語のストーリー用の部隊編成へ。戻ると話の一覧。
	list.press_edit_decks()
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.DECKS and app.current_scene().mode() == Story.military().rules_id and app.current_scene().back_label() == "話の一覧へ戻る",
		"話の一覧の「部隊編成」で、この物語のストーリー用の部隊編成へ進まない（か、戻り先の文字が違う）")
	app.current_scene().press_back()
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.EPISODES, "話の一覧から開いた部隊編成の「話の一覧へ戻る」で、話の一覧へ戻らない")
	list = app.current_scene()
	_expect(list.episodes().size() == Story.military().episodes.size(), "話の一覧に、全部の話が並んでいない")
	_expect(list.is_card_enabled(Story.military().episodes[0]) and list.card_status(Story.military().episodes[0]) == "クリア済み", "クリアした最初の話を選び直せない")
	_expect(list.is_card_enabled(episode) and list.card_status(episode) == "未クリア", "次の話を選べない")
	_expect(list.card_title(episode) == episode.title and list.is_card_revealed(episode), "次に遊ぶ話のカードの名前か縮図が伏せてある")
	# 背景は物語の景色: 次に遊ぶ話のマップで、空をその国の色へ寄せる。ほかの遊べる話を選ぶと、その話のマップに替わる。まだ遊べない話では替えない。
	var scape: Node = list.backdrop()
	_expect(scape.story_key() == episode.id and scape.sky_army() == Story.military().army and scape.shown_look() == episode.look,
		"話の一覧の背景が、次に遊ぶ話の景色でない: %s %s" % [scape.story_key(), scape.shown_look()])
	list.focus(Story.military().episodes[0])
	scape.swap_now()
	_expect(scape.story_key() == Story.military().episodes[0].id and scape.shown_look() == Story.military().episodes[0].look, "話を選んでも、背景がその話のマップに替わらない")
	list.focus(Story.military().episodes[-1])
	_expect(scape.story_key() == Story.military().episodes[0].id, "まだ遊べない話を選んだら、背景が替わった")
	list.focus(episode)
	scape.cancel_queued()
	_expect(scape.story_key() == Story.military().episodes[0].id, "とどまる前にカードから離れても、背景が替わる")
	for later: RefCounted in Story.military().episodes.slice(first + 1):
		_expect(not list.is_card_enabled(later), "前の話をクリアしていないのに、%s を選べる" % later.title)
		_expect(list.card_title(later) == "？？？" and not list.is_card_revealed(later), "まだ遊べない %s のカードの名前か縮図・顔が見えている" % later.title)
	# 確かめ用の解放（F5）: 話の一覧を作り直して、全部の話を開く。もう一度押すと元に戻る。記録は変わらない。
	var cleared_before: int = story.cleared_count()
	_push_key(app, KEY_F5)
	await app.scene_changed
	list = app.current_scene()
	_expect(app.current_id() == SceneFlow.EPISODES and story.open_all and app.open_all_key().is_marked(), "F5 で、全部の話を開かない（か、隅に印が無い）")
	_expect(list.is_card_enabled(Story.military().episodes[-1]) and list.card_title(Story.military().episodes[-1]) == Story.military().episodes[-1].title, "F5 で開いても、最後の話を選べない（か、伏せたまま）")
	_push_key(app, KEY_F5)
	await app.scene_changed
	list = app.current_scene()
	_expect(not story.open_all and not app.open_all_key().is_marked() and not list.is_card_enabled(Story.military().episodes[-1]),
		"もう一度 F5 を押しても、元に戻らない")
	_expect(story.cleared_count() == cleared_before, "F5 で、クリアの記録が変わった")
	# キーボードでは、左右の矢印で選んで Enter（数字キーの届かない 10 話目より先も選べる）。最初の矢印は、次に遊ぶ話を選ぶ。
	_push_key(app, KEY_RIGHT)
	_expect(list.key_choice() == episode, "話の一覧で矢印を押しても、次に遊ぶ話が選ばれない")
	_push_key(app, KEY_LEFT)
	_expect(list.key_choice() == Story.military().episodes[first - 1], "話の一覧で左の矢印を押しても、前の話へ移らない")
	_push_key(app, KEY_RIGHT)
	_push_key(app, KEY_RIGHT)
	_expect(list.key_choice() == episode, "話の一覧で、まだ遊べない話を矢印で選べる")
	_push_key(app, KEY_ENTER)
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.SORTIE, "話の一覧で話を選んで Enter を押しても、出撃準備へ進まない（会話は出撃のあと）")
	var sortie: Node = app.current_scene()
	# 「部隊編成」で編成（ストーリー用だけ）へ寄り道し、組んで取っておいた部隊を選んで戻る。
	var steps: int = app.context.run.size()
	sortie.press_edit_decks()
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.DECKS and app.context.run != null, "出撃準備の「部隊編成」で、流れを保ったまま編成へ進まない")
	var decks: Node = app.current_scene()
	_expect(decks.is_detour() and decks.mode() == Story.military().rules_id and decks.back_label() == "出撃準備へ戻る", "寄り道の編成が、ストーリー用でない（か、戻り先の文字が違う）")
	decks.press_new()
	for kind: UnitKind.Id in story.unlocked_kinds():
		decks.hire(kind)
	_expect(decks.can_save(), "寄り道の編成で、雇える駒で組んだ部隊を取っておけない")
	decks.press_save()
	var made: String = decks.list_selected()
	decks.press_back()
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.SORTIE, "編成の「出撃準備へ戻る」で、出撃準備へ戻らない")
	_expect(app.context.run.size() == steps, "寄り道を終えても、流れの列に編成の場面が残っている")
	sortie = app.current_scene()
	_expect(sortie.chosen_id() == made, "寄り道で取っておいた部隊が、出撃準備で選ばれていない")
	sortie.choose("")
	var options: Array[String] = sortie.option_ids()
	_expect(options[0] == "" and sortie.chosen_id() == "", "出撃準備で、既定の編成を選べない")
	var story_decks: Array = app.context.decks.for_rules(Story.military().rules_id)
	_expect(options.size() == 1 + story_decks.size(), "出撃準備に、ストーリー用の部隊が並ばない（か、対戦用が混ざった）")
	# 味方と敵の駒のアイコンを押すと、詳しい説明。持ち物を持たせた駒なら、持ち物の効果も出る。
	var own: Deck = sortie.chosen_deck()
	var detail: Control = sortie.press_face(Unit.Side.PLAYER1, 1)
	_expect(detail != null and detail.visible and detail.title_text() == Names.kind(own.entries[0].kind), "出撃準備で味方の駒のアイコンを押しても、詳しい説明が出ない")
	if detail != null and not own.entries[0].equipment.is_empty():
		_expect(detail.body_text().contains(Names.item(own.entries[0].equipment[0])), "出撃準備の駒の詳しい説明に、持ち物が出ない: %s" % detail.body_text())
	if detail != null:
		detail.close_detail()
	var enemy_deck: Deck = episode.enemy_deck()
	detail = sortie.press_face(Unit.Side.PLAYER2, enemy_deck.entries.size())
	_expect(detail != null and detail.visible and detail.title_text().begins_with(Names.kind(enemy_deck.entries[-1].kind)), "出撃準備で敵の駒のアイコンを押しても、詳しい説明が出ない")
	if detail != null:
		detail.close_detail()
	# 部隊を選び替えても（部隊の文の長さが違っても）、ほかの部品の位置と大きさが変わらない。
	var sortie_moves: Array = []
	for id: String in options:
		sortie_moves.append(sortie.choose.bind(id))
	await _expect_steady(sortie, [], sortie_moves, "出撃準備で部隊を選び替える")
	for item: RefCounted in story_decks:
		_expect(sortie.is_option_enabled(item.id) == item.playable(), "出せない部隊を選べる（か、出せる部隊を選べない）: %s" % item.name)
		if item.playable():
			sortie.choose(item.id)
	# 初期位置: 最初の駒を選んで、置けるマスの空いているところへ動かす。「おまかせ」で戻せる。右クリックで選ぶのをやめる。
	var deploy: Control = sortie.deploy_map()
	var own_cells: Array[Vector2i] = deploy.unit_cells()
	var free_cells: Array = deploy.zone().filter(func(cell: Vector2i) -> bool: return not own_cells.has(cell))
	_expect(not own_cells.is_empty() and not free_cells.is_empty() and deploy.is_default(), "出撃準備の初期位置に、駒か置けるマスが無い（か、始めからおまかせでない）")
	# 駒に次々マウスを乗せる（駒の欄の中身が替わっても、枠が動かないこと。枠の見張り steady_probe.gd が見る）。
	await _hover_each(deploy)
	deploy.press_cell(own_cells[0])
	_expect(deploy.selected() == 0, "初期位置で、駒を押しても選べない")
	_expect(sortie.deploy_note().shown_name() == Names.kind(deploy.focused_unit().kind), "出撃準備の初期位置で、選んだ駒の名前が欄に出ない")
	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.pressed = true
	app.get_viewport().push_input(right_click)
	_expect(deploy.selected() == -1 and app.current_id() == SceneFlow.SORTIE, "初期位置で駒を選んでいるときの右クリックで、選ぶのをやめない（か、出撃準備を抜けた）")
	deploy.press_cell(own_cells[0])
	deploy.press_cell(free_cells[0])
	_expect(deploy.unit_cells()[0] == free_cells[0] and not deploy.is_default(), "初期位置で、置けるマスへ駒を動かせない")
	sortie.press_auto_place()
	_expect(deploy.is_default(), "「おまかせ」で、いつもの置き方に戻らない")
	deploy.press_cell(own_cells[0])
	deploy.press_cell(free_cells[0])
	var result: Node = await _win_story_battle(app, sortie, episode, true, _check_talk_before.bind(episode), free_cells[0])
	_expect(result.leave_text() == "話の一覧へ" and not result.enabled_buttons().has("タイトルへ"), "話の決着の画面の行き先が「話の一覧へ」でない: %s" % result.leave_text())
	_expect(result.remark_texts().is_empty(), "勝った話の決着の画面に、負けたときの台詞が出る")
	# 「部隊を選び直す」で出撃準備へ戻り、同じ話をもう一度勝つ（対戦の前の会話は、もう出ない）。
	_expect(result.can_choose_squad(), "話の決着の画面に「部隊を選び直す」が無い")
	result.press_choose_squad()
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.SORTIE and app.context.run != null, "決着の画面の「部隊を選び直す」で、出撃準備へ戻らない")
	result = await _win_story_battle(app, app.current_scene(), episode)
	result.press_continue()
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.TALK, "決着の画面の「次へ」で、あとの会話へ進まない")
	var talk: Node = app.current_scene()
	_expect(talk.line_count() == episode.talk_after_battle().lines.size() + Story.unlocked_before(episode).news_of(episode).size(), "あとの会話の文の数が違う（最後に、増えたものの知らせ）")
	# 背景の盤に、勝ったときに生き残っていた駒が立つ。
	var ended: Battle = app.context.run.data()["battle"].ended_battle
	var survivors := ended.units.filter(func(unit: Unit) -> bool: return unit.side == Unit.Side.PLAYER1).size() if ended != null else -1
	_expect(talk.backdrop_units()[0] == survivors, "あとの会話の背景に、生き残った味方が立たない: %s / %d" % [talk.backdrop_units(), survivors])
	if not episode.unlock_kinds.is_empty():
		talk.press_skip()
		_expect(talk.line_index() == episode.talk_after_battle().lines.size() and talk.speaker() == Story.notice_name()
				and talk.line_text().contains(Names.kind(episode.unlock_kinds[0])), "「飛ばす」が、解放した駒の知らせまで飛ばしている")
	for i: int in talk.line_count() - talk.line_index():
		talk.press_next()
	_expect(talk.is_choosing() == (Story.episode_after(episode) != null), "あとの会話を送りきっても、「次の話へ」「話の一覧へ」を選ばせない")
	_expect(talk.is_skip_shown() != talk.is_choosing(), "「次の話へ」「話の一覧へ」を選ぶ間も「スキップ」が出ている")
	if talk.is_choosing():
		# 選ぶ枠の上で右クリックしても、選ぶのをやめて最後の文へ戻る（枠に食われない）。もう一度送ると、また選ぶ。
		# 画面なしの検査は、押した物を GUI で拾わないので、そこでマウスを止める部品（ボタンのほか）が無いことも確かめる。
		await get_tree().process_frame  # 枠の大きさが決まってから
		# 押すのは枠の上の余白（ボタンの上の右クリックは、ボタンが受ける。画面の真ん中はボタンの縁に当たることがある）。
		var at := app.get_viewport().get_visible_rect().get_center()
		for node: Node in talk.find_children("*", "PanelContainer", true, false):
			var frame := (node as Control).get_global_rect()
			if (node as Control).is_visible_in_tree() and frame.has_point(at):
				at = Vector2(frame.get_center().x, frame.position.y + 4.0)
		for node: Node in talk.find_children("*", "Control", true, false):
			var control := node as Control
			if control.is_visible_in_tree() and not control is BaseButton and control.mouse_filter == Control.MOUSE_FILTER_STOP and control.get_global_rect().has_point(at):
				_fail("選ぶ枠の上の右クリックを、%s が食う" % control.get_class())
		var right := InputEventMouseButton.new()
		right.button_index = MOUSE_BUTTON_RIGHT
		right.pressed = true
		right.position = at
		right.global_position = right.position
		app.get_viewport().push_input(right)
		_expect(not talk.is_choosing() and talk.is_skip_shown(), "選ぶ枠の上で右クリックしても、選ぶのをやめて最後の文へ戻らない")
		talk.press_next()
		_expect(talk.is_choosing(), "最後の文へ戻ったあと、送っても選ぶ枠が出ない")
		talk.press_to_episodes()
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.EPISODES and app.context.run == null, "あとの会話の「話の一覧へ」で、話の一覧へ戻らない")
	list = app.current_scene()
	# オートセーブ: 話の流れを終えて話の一覧へ戻った所で書き、保存の印を出す。最後にオートセーブした時刻が、話の一覧に出る。
	_expect(app.save_mark.shown_count > saves_before and not app.context.slots.has_unsaved(), "話をクリアして話の一覧へ戻っても、保存しない（か、保存の印が出ない）")
	_expect(list.saved_text() != "最後のオートセーブ: なし" and list.saved_text().begins_with("最後のオートセーブ: "), "話の一覧に、最後にオートセーブした時刻が出ない")
	# ウィンドウの ×: 保存したあとの話の一覧でも、確かめる（どの画面でも出す）。
	app.request_close()
	_expect(app.quit_window.is_open(), "話の一覧でウィンドウの × を押しても、確かめない")
	app.quit_window.cancel()
	_expect(list.card_status(episode) == "クリア済み", "クリアした話のカードに、済みの印が無い")
	if Story.military().episodes.size() > first + 1:
		_expect(list.is_card_enabled(Story.military().episodes[first + 1]), "前の話をクリアしたのに、次の話を選べない")
	_expect(list.roster_text().contains(Names.kind(episode.unlock_kinds[0])) if not episode.unlock_kinds.is_empty() else true, "話の一覧の、いま雇える駒が増えていない")
	list.press_back()
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.CAMPAIGNS, "話の一覧の「物語を選び直す」で、物語を選ぶ場面へ戻らない")
	_expect(app.current_scene().status_text(Story.military()) == "%d / %d 話クリア" % [first + 1, Story.military().episodes.size()], "物語のカードに、クリアした話の数が出ない")
	app.current_scene().press_back()
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.TITLE, "物語を選ぶ場面の「タイトルへ戻る」で、タイトルへ戻らない")
	_expect(app.current_scene().story_label() == "ストーリー（クリア済み）" or not story.all_cleared(), "クリアしたのに、タイトルに済みの印が無い")
	_expect(story.unlocked_kinds().has(episode.unlock_kinds[0]) if not episode.unlock_kinds.is_empty() else true, "クリアしても、駒が増えていない")


## セーブデータ選択（_visit_story のあと。1 番に進み具合がある）: 1 番は「つづきから」で物語とクリアの数が出る。
## 1 番を 2 番へコピー → 2 番も同じ中身 → 2 番を 1 番へコピーは上書きを確かめる（キャンセル）→ 2 番を削除（確かめる）→ 空きに戻る。
## 最後に 1 番を「つづきから」で選び、物語を選ぶ場面へ（進み具合はそのまま）。
func _visit_slots(app: Node) -> void:
	_expect(app.current_id() == SceneFlow.SLOTS, "タイトルの「ストーリー」で、セーブデータ選択へ進まない")
	var screen: Node = app.current_scene()
	var first: String = screen.card_text(1)
	_expect(first.ends_with("つづきから") and first.contains(Story.military().title) and first.contains("話クリア"), "進み具合のあるスロットのカードに、物語とクリアの数が出ない: %s" % first.replace("\n", " / "))
	_expect(screen.card_text(2).ends_with("はじめから"), "空きのスロットが「はじめから」でない")
	# コピーは、元がいまのスロットなら先に書く（保存の時刻が、いまになる）。時刻を 1 分進めておき、
	# 元のカードの日時が変わっても、コピーが元と同じ中身（同じ日時）になることを見る（分の変わり目で、毎回は起きないため）。
	var slots: RefCounted = app.context.slots
	var real_now: Callable = slots.now
	slots.now = func() -> int: return real_now.call() + 60
	screen.press_copy(1)
	_expect(screen.is_copying() and not screen.is_card_enabled(1), "コピーの元のカードを、コピー先に選べる")
	screen.choose(2)
	slots.now = real_now
	# （プレイ時間は、いまのスロットだけ数えている途中のぶんが足されるので、比べない）
	var without_time := func(text: String) -> String: return "\n".join(Array(text.split("\n")).filter(func(line: String) -> bool: return not line.begins_with("プレイ時間")))
	var source: String = screen.card_text(1)
	var without_date := func(text: String) -> String: return "\n".join(Array(without_time.call(text).split("\n")).filter(func(line: String) -> bool: return not RegEx.create_from_string("^\\d{4}/\\d{2}/\\d{2} \\d{2}:\\d{2}$").search(line)))
	_expect(source != first and without_date.call(source) == without_date.call(first), "コピーの元を書き直したとき、日時のほかが変わった（か、日時が変わらない）: %s ／ 前: %s" % [source.replace("\n", " / "), first.replace("\n", " / ")])
	_expect(not screen.is_copying() and without_time.call(screen.card_text(2)) == without_time.call(source).replace("データ 1", "データ 2"), "コピーしたスロットの中身が、元と違う: %s ／ 元: %s" % [screen.card_text(2).replace("\n", " / "), source.replace("\n", " / ")])
	screen.press_copy(2)
	screen.choose(1)
	var confirm: Node = screen.confirm_window()
	_expect(confirm.is_open() and confirm.question().contains("上書き"), "中身のあるスロットへのコピーで、上書きを確かめない")
	confirm.cancel()
	screen.cancel_copy()
	screen.press_delete(2)
	_expect(confirm.is_open() and confirm.ok_text() == "削除", "削除を確かめない")
	confirm.accept()
	_expect(screen.card_text(2).ends_with("はじめから") and without_time.call(screen.card_text(1)) == without_time.call(source), "削除したスロットが空きに戻らない（か、ほかのスロットが変わった）")
	screen.choose(1)
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.CAMPAIGNS, "「つづきから」で、物語を選ぶ場面へ進まない")


## 2 つ目の物語（FANTASY の物語）の頭の話を通す: 物語を選ぶ場面で選べる → その物語の話の一覧（最初の話だけ選べる。演習の印）
## → 会話を飛ばす → 出撃準備（部隊が決まっている。その物語の軍の部隊）→ 勝つ（「部隊変更」は出ない）→ あとの会話 → 話の一覧（次の話が選べる）
## → 物語を選ぶ場面（クリアした話の数。最初の物語の記録はそのまま）→ タイトル。
## 前の物語の記録（_visit_story がクリアを書いた）があり、この物語の記録が無いところから始める（古いセーブから起動したときと同じ形）。
func _visit_second_campaign(app: Node) -> void:
	var story: RefCounted = app.context.story
	var campaign: RefCounted = Story.campaigns()[1]
	var episode: RefCounted = campaign.episodes[0] if not campaign.episodes.is_empty() else null
	_expect(episode != null and episode.squad_deck() != null, "2 つ目の物語の頭に、部隊が決まっている話（演習）が無い")
	if episode == null:
		return
	var military_cleared: int = story.cleared_count(Story.military())
	_expect(story.cleared_count(campaign) == 0, "2 つ目の物語を、始める前からクリアしている")
	app.current_scene().press_story()
	await app.scene_changed
	await _visit_slots(app)
	var campaigns: Node = app.current_scene()
	_expect(campaigns.is_card_enabled(campaign) and campaigns.status_text(campaign) == "全 %d 話" % campaign.episodes.size(), "2 つ目の物語を選べない（か、状態の文が違う）")
	campaigns.choose(campaign)
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.EPISODES and story.campaign == campaign, "2 つ目の物語を選んでも、その物語の話の一覧へ進まない")
	var list: Node = app.current_scene()
	_expect(list.episodes().size() == campaign.episodes.size(), "2 つ目の物語の話の一覧に、全部の話が並んでいない")
	_expect(list.is_card_enabled(episode) and list.card_status(episode) == "未クリア", "2 つ目の物語の最初の話を選べない")
	for later: RefCounted in campaign.episodes.slice(1):
		_expect(not list.is_card_enabled(later), "前の話をクリアしていないのに、%s を選べる" % later.title)
	for kind: UnitKind.Id in campaign.starting_kinds:
		_expect(list.roster_text().contains(Names.kind(kind)), "2 つ目の物語の話の一覧に、最初から雇える駒が出ていない: %s" % Names.kind(kind))
	list.choose(episode)
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.SORTIE, "2 つ目の物語の話を選んでも、出撃準備へ進まない")
	var sortie: Node = app.current_scene()
	_expect(sortie.is_squad_fixed() and sortie.option_ids().size() == 1, "演習の出撃準備で、部隊を選べる")
	_expect(sortie.chosen_deck().army == campaign.army and sortie.chosen_deck().entries.size() == episode.squad.size(), "演習の部隊が、物語の軍の決まった部隊でない")
	var result: Node = await _win_story_battle(app, sortie, episode, true)
	_expect(not result.can_choose_squad(), "部隊が決まっている話の決着の画面に「部隊変更」がある")
	result.press_continue()
	await app.scene_changed
	var talk: Node = app.current_scene()
	_expect(app.current_id() == SceneFlow.TALK and talk.line_count() == episode.talk_after_battle().lines.size() + Story.unlocked_before(episode).news_of(episode).size(), "2 つ目の物語の、あとの会話の文の数が違う")
	for i: int in talk.line_count() - talk.line_index():
		talk.press_next()
	# 「次の話へ」で、次の話の最初の場面へ（出撃準備か、その前の会話・カットシーン）。そこからシステムメニューの「話の一覧へ戻る」で、話の一覧へ。
	_expect(talk.is_choosing() and campaign.episodes.size() >= 2, "2 つ目の物語の、あとの会話のあとに「次の話へ」が無い")
	talk.press_next_episode()
	await app.scene_changed
	var opens_with_sortie: bool = campaign.episodes[1].scenes[0].kind == Episode.StoryScene.Kind.SORTIE
	_expect(app.context.run != null and app.current_id() == (SceneFlow.SORTIE if opens_with_sortie else SceneFlow.TALK)
			and (not opens_with_sortie or app.current_scene().episode == campaign.episodes[1]), "「次の話へ」で、次の話の最初の場面へ進まない")
	var menu: Node = app.system_menu()
	app.open_menu()
	_expect(menu.item_ids().has(&"exit:episodes"), "次の話の最初の場面のシステムメニューに「話の一覧へ戻る」が無い: %s" % [menu.item_ids()])
	menu.press(&"exit:episodes")
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.EPISODES and app.context.run == null, "システムメニューの「話の一覧へ戻る」で、話の一覧へ戻らない")
	list = app.current_scene()
	_expect(list.card_status(episode) == "クリア済み" and (campaign.episodes.size() < 2 or list.is_card_enabled(campaign.episodes[1])), "2 つ目の物語で、クリアした話の次の話を選べない")
	list.press_back()
	await app.scene_changed
	_expect(app.current_scene().status_text(campaign) == "1 / %d 話クリア" % campaign.episodes.size(), "2 つ目の物語のカードに、クリアした話の数が出ない")
	_expect(story.cleared_count(Story.military()) == military_cleared, "2 つ目の物語を遊ぶと、最初の物語の記録が変わる")
	app.current_scene().press_back()
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.TITLE, "物語を選ぶ場面の「タイトルへ戻る」で、タイトルへ戻らない")


## 部隊編成の持ち物の欄: どの物語でも、解放の前と全部の解放のあとで、どの駒を選んでも、持ち物を持たせても、
## 名前・コスト・持たせられない理由（「未解放」「1 体 1 個まで」「後衛専用」など）が切れずに読める。ストーリーの記録は、終わったら戻す。
func _visit_item_rows(app: Node) -> void:
	var story: RefCounted = app.context.story
	var kept: Dictionary = story.to_data()
	for campaign: RefCounted in Story.campaigns():
		for unlock_all: bool in [false, true]:
			story.load_data({})
			story.choose_campaign(campaign)
			if unlock_all:
				for episode: RefCounted in campaign.episodes:
					story.clear(episode.id)
			await app.go(SceneFlow.DECKS)
			var screen: Node = app.current_scene()
			screen.set_mode(campaign.rules_id)
			screen.press_new()
			for kind: UnitKind.Id in screen.editing_deck().available_kinds():
				screen.hire(kind)
			for index: int in screen.editing_deck().entries.size():
				screen.select_entry(index)
				await app.get_tree().process_frame
				await app.get_tree().process_frame
				_expect(screen.item_row_cut_texts().is_empty(), "持ち物の欄の文が切れている（%s、%s）: %s" % [campaign.title, Names.kind(screen.editing_deck().entries[index].kind), screen.item_row_cut_texts()])
				_expect(screen.detail_card_rect().size.y >= screen.DETAIL_MIN_HEIGHT - 0.5, "持ち物の欄に押されて、駒の札が縮んだ（%s）: 高さ %.0f" % [campaign.title, screen.detail_card_rect().size.y])
				_expect(screen.detail_summary_overflow() <= 0.5, "駒の札の中身が、札の幅からはみ出した（%s、%s）: %.0f px" % [campaign.title, Names.kind(screen.editing_deck().entries[index].kind), screen.detail_summary_overflow()])
				_expect(not screen.detail_button_covers_summary_head(), "駒の札の「詳細」が、名前の行に重なった（%s、%s）" % [campaign.title, Names.kind(screen.editing_deck().entries[index].kind)])
				for item: Equipment.Id in screen.editing_deck().rules.items():
					screen.equip(item)
					await app.get_tree().process_frame
					await app.get_tree().process_frame
					_expect(screen.item_row_cut_texts().is_empty(), "持ち物を持たせたら、持ち物の欄の文が切れた（%s、%s、%s）: %s" % [campaign.title, Names.kind(screen.editing_deck().entries[index].kind), Names.item(item), screen.item_row_cut_texts()])
					screen.unequip(item)
			if unlock_all:
				await _resize_deck_screen(screen, campaign)
			if not unlock_all:
				screen.select_entry(0)
				var effects: Dictionary = screen.item_row_effects()
				for item: Equipment.Id in effects:
					_expect(screen.editing_deck().rules.allows_item(item) or (effects[item] as String).begins_with("未解放"), "まだ持たせられない持ち物に「未解放」が出ない: %s" % effects[item])
	story.load_data(kept)
	await app.go(SceneFlow.TITLE)


## 会話の行 row（episode.gd の before・after の 1 行）の話し手の名前（地の文なら空）。
static func _speaker_of(episode: RefCounted, row: RefCounted) -> String:
	return row.speaker_in(episode.speakers)


## 対戦の前の会話の場面 talk（話 episode）: 文の数、最初の文、話し手の姿、送りと戻り。
func _check_talk_before(talk: Node, episode: RefCounted) -> void:
	_expect(talk.line_count() == episode.talk_before_battle().lines.size() and talk.line_index() == 0, "前の会話の文の数が違う")
	_expect(talk.speaker() == _speaker_of(episode, episode.talk_before_battle().lines[0]) and talk.line_text() == episode.talk_before_battle().lines[0].shown_text(), "最初の文が出ていない")
	_expect(not talk.has_method(&"next_episode") or talk.next_episode() == null, "対戦の前の会話に「次の話へ」がある")
	await get_tree().process_frame
	# 立つ所は左右に 1 つずつ。両軍が出てくるか、同じ軍の話し手が 2 人以上いれば、両方に立つ。
	var talkers := {}
	for row: RefCounted in episode.talk_before_battle().lines:
		if not row.is_narration():  # 地の文は、話し手がいない
			talkers[row.who] = true
	_expect(talk.figures().size() == mini(talkers.size(), 2), "会話に出てくる話し手の姿が立っていない")
	var screen_rect := Rect2(Vector2.ZERO, talk.get_viewport().get_visible_rect().size)
	for figure: Control in talk.figures():
		var rect: Rect2 = figure.get_global_rect()
		_expect(rect.has_area() and screen_rect.encloses(rect), "話し手の姿が画面からはみ出す: %s" % rect)
		_expect(not rect.intersects(talk.bottom_rect()), "話し手の姿が、名前の札・文の枠・「飛ばす」に重なる: %s と %s" % [rect, talk.bottom_rect()])
		_expect(figure.is_speaking() == (figure.who == episode.talk_before_battle().lines[0].who), "話している人の姿だけが明るく大きくなっていない")
	talk.press_next()
	_expect(talk.line_index() == 1, "クリックで、次の文へ進まない")
	talk.press_back()
	_expect(talk.line_index() == 0, "右クリックで、前の文へ戻らない")
	await _check_talk_log(talk, episode)


## 会話のログ: ホイールを上へ回すと開き、これまでの文（いまの文まで）を話し手と文で並べる。開いている間、会話は送らない。
## 右クリックで閉じる（会話の文は戻らない）。L で開いて、Esc で閉じる。
func _check_talk_log(talk: Node, episode: RefCounted) -> void:
	talk.press_next()
	talk.press_next()
	var at: int = talk.line_index()
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = talk.get_viewport().get_visible_rect().get_center()
	talk.get_viewport().push_input(wheel)
	var log: CanvasLayer = talk.talk_log()
	_expect(log.is_open(), "会話の画面でホイールを上へ回しても、会話のログが開かない")
	var expected := []
	for i in at + 1:
		expected.append([_speaker_of(episode, episode.talk_before_battle().lines[i]), episode.talk_before_battle().lines[i].shown_text()])
	_expect(log.row_texts() == expected, "会話のログに、これまでの文が並んでいない: %s" % [log.row_texts()])
	var enter := InputEventKey.new()
	enter.physical_keycode = KEY_ENTER
	enter.pressed = true
	talk.get_viewport().push_input(enter)
	_expect(talk.line_index() == at and log.is_open(), "会話のログを開いている間に、会話が送られた")
	var screen_rect := Rect2(Vector2.ZERO, talk.get_viewport().get_visible_rect().size)
	_expect(screen_rect.encloses(log.panel_rect()), "会話のログの窓が画面からはみ出す: %s" % log.panel_rect())
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	right.position = wheel.position
	talk.get_viewport().push_input(right)
	_expect(not log.is_open() and talk.line_index() == at, "会話のログの右クリックで、閉じない（か、会話の文が戻った）")
	var l_key := InputEventKey.new()
	l_key.physical_keycode = KEY_L
	l_key.pressed = true
	talk.get_viewport().push_input(l_key)
	_expect(log.is_open(), "L で会話のログが開かない")
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	talk.get_viewport().push_input(escape)
	_expect(not log.is_open() and not talk.context.system_menu.is_open(), "会話のログの Esc で、閉じない（か、システムメニューが開いた）")
	await get_tree().process_frame
	for i in at:
		talk.press_back()


## 出撃準備 sortie で「出撃」し、話 episode の対戦に入ったことを確かめて、小さな盤で 1 手で勝つ。決着の画面を返す。
## talk_first なら、出撃のあとに対戦の前の会話が出ることを確かめ（on_talk があれば、会話の場面を渡して呼ぶ）、飛ばして対戦へ。
## 偽なら、会話を出さずに対戦へ進むことを確かめる（「部隊変更」のあと）。
## first_at が盤の中なら、部隊の最初の駒がそのマスから始まることも確かめる（出撃準備で決めた初期位置）。
func _win_story_battle(app: Node, sortie: Node, episode: RefCounted, talk_first := false, on_talk := Callable(), first_at := Vector2i(-1, -1)) -> Node:
	var story: RefCounted = app.context.story
	var chosen: Deck = sortie.chosen_deck()
	sortie.press_sortie()
	await app.scene_changed
	if talk_first:
		_expect(app.current_id() == SceneFlow.TALK, "出撃しても、対戦の前の会話へ進まない")
		if app.current_id() == SceneFlow.TALK:
			# 背景の盤に、初期位置の味方と、話の並びの敵が立つ。
			var standing: Array[int] = app.current_scene().backdrop_units()
			_expect(standing[0] == chosen.entries.size() + 1 and standing[1] > 0, "対戦の前の会話の背景に、初期位置の駒が立たない: %s" % [standing])
			if on_talk.is_valid():
				await on_talk.call(app.current_scene())
			app.current_scene().press_skip()
			await app.scene_changed
	_expect(app.current_id() == SceneFlow.BATTLE, "出撃準備の「出撃」で、対戦へ進まない")
	var screen: Node = app.current_scene()
	# 幕が明けた時点（場面の _process がまだ回っていない）で、ミニマップはもう右上にある（左上に出てから跳ばない）。
	var minimap: Rect2 = screen.minimap_rect()
	_expect(minimap.has_area() and minimap.position.x > screen.get_viewport().get_visible_rect().size.x / 2.0,
		"対戦に入った幕が明けたとき、ミニマップが右上に置かれていない: %s" % minimap)
	screen.set_time_scale_base(8.0)
	var source: RefCounted = screen.source
	_expect(source.new_board_fields().is_empty() and not source.can_open_setup() and screen.menu_items().is_empty(), "話の対戦に、選び直す入口がある")
	# ストーリーの間は、陣営を話の呼び名で呼ぶ（「CPU（赤）」「プレイヤー1」と呼ばない）。駒の所属の札は「味方」「敵」。
	var names: Array[String] = source.side_names()
	_expect(Names.side(Unit.Side.PLAYER2) == names[1] and Names.side_word(Unit.Side.PLAYER1) == source.side_shorts()[0] and names[1] != "",
		"話の対戦で、陣営が話の呼び名で呼ばれない: %s" % [names])
	_expect(Names.side_relation(Unit.Side.PLAYER2) == "敵", "駒の所属の札が「敵」でない")
	_expect(screen.battle.board.size == episode.map.make_board().size, "話の対戦が、話のマップで始まらない")
	var placed := 0
	for unit: Unit in screen.battle.units:
		if unit.side == Unit.Side.PLAYER1 and unit.kind != UnitKind.Id.KING:
			placed += 1
	_expect(placed == chosen.entries.size() and source.human_deck.entries.size() == chosen.entries.size(), "出撃準備で選んだ部隊で、対戦が始まらない")
	if first_at != Vector2i(-1, -1):
		var first: Array = screen.battle.units.filter(func(unit: Unit) -> bool: return unit.side == Unit.Side.PLAYER1 and unit.kind != UnitKind.Id.KING)
		_expect(not first.is_empty() and first[0].cell == first_at, "出撃準備で決めた初期位置から始まらない: %s（決めたのは %s）" % [first[0].cell if not first.is_empty() else null, first_at])
	_expect(screen.cpu_opponent and screen.battle.armies[Unit.Side.PLAYER2] == episode.enemy_army, "話の敵を CPU が動かしていない")
	# 始まりは 1 つずつ: 「対戦ルール」が出ている間は、番の知らせも始めの台詞も出ない。閉じると番の知らせから始まる。
	_expect(screen.notice_text() != "" and not screen.is_banner_shown() and screen.talk_line() == null,
		"「対戦ルール」と、番の知らせか始めの台詞が同時に出ている")
	screen.hide_notice()
	_expect(screen.is_banner_shown(), "「対戦ルール」を閉じても、番の知らせが出ない")
	# 対戦の途中の会話の札は、上の帯のすぐ下で、勝ち方の札・視点の案内・ミニマップと重ならない（いちばん長い台詞で確かめる）。
	var longest := ""
	for each: RefCounted in Story.all_episodes():
		for cue: RefCounted in each.cues:
			if cue.line.text.length() > longest.length():
				longest = cue.line.shown_text()
	screen.say_for_check([BattleCues.Line.new(1, episode.speakers[1], longest, episode.figures[1])] as Array[BattleCues.Line])
	await get_tree().process_frame
	await get_tree().process_frame
	var card: Rect2 = screen.talk_card_rect()
	_expect(card.has_area() and card.position.y >= BattleHud.TOP_BAR_HEIGHT, "対戦の途中の会話の札が出ないか、上の帯に重なる: %s" % card)
	_expect(card.size.y <= 64.0, "対戦の途中の会話の札が、細い帯でない（2 行を超える高さ）: %s" % card)
	for other: Rect2 in screen.talk_card_neighbors():
		_expect(not card.intersects(other), "対戦の途中の会話の札が、勝ち方の札・視点の案内・ミニマップに重なる: %s と %s" % [card, other])
	# 遊ぶときは、台詞を送られるまで出したままにし、その間は盤を止める。Enter で送る（ターン終了にならない）。
	screen.clear_talk_for_check()
	screen.set_talk_hold(true)
	screen.say_for_check([BattleCues.Line.new(1, episode.speakers[1], longest, episode.figures[1])] as Array[BattleCues.Line])
	_expect(screen.is_talk_holding() and screen.is_busy(), "遊ぶときの対戦の途中の台詞で、盤が止まらない")
	var turn_before: int = screen.battle.turn
	var phase_before: int = screen.battle.phase
	for i in 600:
		if screen.advance_talk():
			break
		await get_tree().process_frame
	_expect(not screen.is_talk_holding(), "対戦の途中の台詞を送れない")
	screen.say_for_check([BattleCues.Line.new(1, episode.speakers[1], longest, episode.figures[1])] as Array[BattleCues.Line])
	for i in 600:
		if screen.talk_line() != null and app.get_viewport().get_visible_rect().size.x > 0 and screen.is_talk_holding():
			var enter := InputEventKey.new()
			enter.physical_keycode = KEY_ENTER
			enter.pressed = true
			app.get_viewport().push_input(enter)
			if not screen.is_talk_holding():
				break
		await get_tree().process_frame
	_expect(not screen.is_talk_holding() and screen.battle.turn == turn_before and screen.battle.phase == phase_before,
		"対戦の途中の台詞を Enter で送れない（か、Enter でターンが終わった）")
	screen.set_talk_hold(false)
	# 小さな盤で、1 手で将を倒して勝つ。
	var board := _small_board(Vector2i(5, 4))
	var battle := Battle.new(board)
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER1, board.hq_cells[0])
	var foe := battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER2, board.hq_cells[1])
	foe.hp = 1
	var raider := UnitKind.Id.SPELLBLADE if Story.campaign_of(episode).army == UnitKind.Army.FANTASY else UnitKind.Id.COMMANDO
	var striker := battle.add_unit(raider, Unit.Side.PLAYER1, board.hq_cells[1] + Vector2i(-1, 0))
	screen.start_with(battle, episode.look, 1, episode.map_title)
	screen.click_cell(striker.cell)
	screen.click_cell(foe.cell)
	var result: Node = screen.result_screen()
	for i in 1200:
		if not screen.is_busy() and result.visible:
			break
		await get_tree().process_frame
	_expect(battle.is_over() and battle.winner == Unit.Side.PLAYER1, "話の対戦で、勝てなかった")
	_expect(story.is_cleared(episode.id), "話の対戦に勝っても、クリアを書かない")
	result.skip()
	for i in 600:
		if not result.enabled_buttons().is_empty():
			break
		await get_tree().process_frame
	_expect(result.can_continue() and result.new_board_fields().is_empty() and not result.can_go_to_setup(), "勝った話の決着の画面の行き先が違う（「次へ」が無い、か、選び直す行き先がある）")
	_expect(not result.can_leave(), "勝った話の決着の画面に「話の一覧へ」がある（あとの会話を読まずに抜けられる）")
	return result
