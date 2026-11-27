extends "res://tools/shots/stage_scenes.gd"
## スクリーンショットの場面: ストーリーの画面（物語とセーブデータの選択、話の一覧、出撃準備まで、会話）。

## 主人公に付ける、いちばん長い名前（全角 5 字。hero_name.gd の MAX_CHARS）。
const LONG_HERO := "アルベルト"


## タイトルの「ストーリー」で話の一覧へ進み、number 番目（0 から）の話を始める（出撃準備の場面に入る）。
## 前の話は、クリアしたことにする。number が負なら、部隊を選ぶ最初の話（チュートリアルのあとの本編の 1 話目）。
func _start_story(number := -1) -> bool:
	if number < 0:
		number = _main_episode()
	_app.context.story.choose_campaign(Story.military())  # クリアは、いま選んでいる物語の記録に書く（前の場面が FANTASY を選んでいても）
	for i in number:
		_app.context.story.clear(Story.military().episodes[i].id)
	if not await _scene_story_list():
		return false
	_app.current_scene().choose(Story.military().episodes[number])
	await _app.scene_changed
	return await _skip_to_sortie()


## 出撃準備より前の場面（場面の節で書いた話の、カットシーンや会話）を飛ばして、出撃準備へ。選ばせる行は、1 つ目の答えを選ぶ。
func _skip_to_sortie() -> bool:
	for i in 12:
		if _app.current_id() != SceneFlow.TALK:
			break
		var talk: Node = _app.current_scene()
		talk.press_skip()
		if talk.is_asking():
			talk.press_option(0)
			continue
		await _app.scene_changed
	return _app.current_id() == SceneFlow.SORTIE


## 連邦の第 1 話（場面の節で書いた厚い版）を始めて、会話の場面を index 個（0 から）送ったところ。選ばせる行は 1 つ目の答え。
## hero が空でなければ、主人公にその名前を付けておく（札と文の名前が替わる）。
func _first_episode_scene(index: int, hero := "") -> bool:
	_app.context.story.choose_campaign(Story.military())
	if hero != "":
		_app.context.story.name_hero(Story.military(), hero)
	if not await _scene_story_list():
		return false
	_app.current_scene().choose(Story.military().episodes[0])
	await _app.scene_changed
	for i in index:
		if _app.current_id() != SceneFlow.TALK:
			return false
		var talk: Node = _app.current_scene()
		talk.press_skip()
		if talk.is_asking():
			talk.press_option(0)
			talk.press_skip()
		await _app.scene_changed
	return _app.current_id() == SceneFlow.TALK


## 連邦の第 1 話の頭のカットシーン（色の幕の上に、地の文を真ん中に。上下に黒い帯）。
func _scene_story_cut() -> bool:
	return await _first_episode_scene(0) and _app.current_scene().is_cut()


## 連邦の第 1 話の、別の場所の会話（峠の駐屯地。背景はその場所の景色で、兵は立たない）。話し手は主人公。
func _scene_story_place_talk() -> bool:
	if not await _first_episode_scene(1):
		return false
	var talk: Node = _app.current_scene()
	while talk.line_index() < 2:
		talk.press_next()
	return not talk.is_cut()


## いちばん長い名前（全角 5 字）を付けた主人公が話している会話（名前の札と、文の中の名前）。
func _scene_story_long_name_talk() -> bool:
	if not await _first_episode_scene(1, LONG_HERO):
		return false
	var talk: Node = _app.current_scene()
	while talk.line_index() < 2:
		talk.press_next()
	return talk.speaker() == LONG_HERO


## いちばん長い名前を付けたときの、選んだあとの会話のログ（札と、文の中の名前）。
func _scene_story_long_name_log() -> bool:
	return await _scene_story_choice_log(LONG_HERO)


## いちばん長い名前を付けたときの、話の一覧の主な人物の欄。
func _scene_story_long_name_list() -> bool:
	_app.context.story.choose_campaign(Story.military())
	_app.context.story.name_hero(Story.military(), LONG_HERO)
	return await _scene_story_list() and _app.current_scene().hero_label_text() == LONG_HERO


## 連邦の第 1 話の選択肢（問いの行の上に、答えの枠）。
func _scene_story_choice(hero := "") -> bool:
	if not await _first_episode_scene(2, hero):
		return false
	_app.current_scene().press_next()
	return _app.current_scene().is_asking()


## 選択肢を選んだあとの会話のログ（問いのあとに、選んだ答えが 1 行）。
func _scene_story_choice_log(hero := "") -> bool:
	if not await _scene_story_choice(hero):
		return false
	var talk: Node = _app.current_scene()
	talk.press_option(1)
	talk.press_next()
	talk.press_next()
	talk.open_log()
	return talk.talk_log().is_open()


## タイトルの「ストーリー」のあとの、物語を選ぶ場面（話の無い物語は準備中）。セーブデータ選択は、いまのスロットで通る。
func _scene_story_campaigns() -> bool:
	await _app.go(SceneFlow.TITLE)
	_app.current_scene().press_story()
	await _app.scene_changed
	if _app.current_id() != SceneFlow.SLOTS:
		return false
	_app.current_scene().choose(_app.context.slots.current)
	await _app.scene_changed
	return _app.current_id() == SceneFlow.CAMPAIGNS


## 物語を選ぶ場面で、物語 index のカードを、キーで選んだところ（背景がその物語の景色に替わる）。
func _campaign_focused(index: int) -> bool:
	if not await _scene_story_campaigns():
		return false
	_app.current_scene().select_by_key(index)
	_app.current_scene().backdrop().swap_now()
	return true


## 物語を初めて選んだときの、主人公の名前の窓（既定の名前が入っている）。
func _scene_story_hero_name() -> bool:
	if not await _scene_story_campaigns():
		return false
	_app.current_scene().ask_hero_name(Story.campaigns()[0])
	return _app.current_scene().hero_window().is_open()


func _scene_story_campaigns_berg() -> bool:
	return await _campaign_focused(0)


func _scene_story_campaigns_ruel() -> bool:
	return await _campaign_focused(1)


func _scene_story_slots_fantasy() -> bool:
	if not await _scene_story_slots():
		return false
	_app.current_scene().select_by_key(1)
	_app.current_scene().backdrop().swap_now()
	return true


## セーブデータ選択: 1 番は MILITARY の物語を 7 話まで、2 番は FANTASY の物語を 3 話まで、3 番は空き。
func _scene_story_slots() -> bool:
	var context: RefCounted = _app.context
	var plans := [[Story.military(), 7, 9000], [_fantasy(), 3, 2700]]
	for i in plans.size():
		context.use_slot(i + 1)
		context.story.choose_campaign(plans[i][0])
		for episode: RefCounted in (plans[i][0].episodes as Array).slice(0, plans[i][1]):
			context.story.clear(episode.id)
		context.slots._played = float(plans[i][2])
		context.slots.flush()
	context.use_slot(1)
	await _app.go(SceneFlow.TITLE)
	_app.current_scene().press_story()
	await _app.scene_changed
	return _app.current_id() == SceneFlow.SLOTS


## セーブデータ選択で、コピー先を選んでいるところ。
func _scene_story_slots_copy() -> bool:
	if not await _scene_story_slots():
		return false
	_app.current_scene().press_copy(1)
	return _app.current_scene().is_copying()


## セーブデータ選択で、削除を確かめているところ。
func _scene_story_slots_delete() -> bool:
	if not await _scene_story_slots():
		return false
	_app.current_scene().press_delete(2)
	return _app.current_scene().confirm_window().is_open()


func _scene_story_list() -> bool:
	if not await _scene_story_campaigns():
		return false
	_app.current_scene().choose(Story.military())
	await _app.scene_changed
	return _app.current_id() == SceneFlow.EPISODES


func _scene_story_open_all() -> bool:
	if not await _scene_story_list():
		return false
	_app.open_all_key().toggle()
	await _app.scene_changed
	return _app.current_id() == SceneFlow.EPISODES and _app.context.story.open_all


## FANTASY の物語。
func _fantasy() -> RefCounted:
	return Story.campaign_of_army(UnitKind.Army.FANTASY)


## FANTASY の物語の話の一覧（何もクリアしていない。頭の演習）。
func _scene_story_fantasy_list() -> bool:
	if not await _scene_story_campaigns():
		return false
	_app.current_scene().choose(_fantasy())
	await _app.scene_changed
	return _app.current_id() == SceneFlow.EPISODES


## FANTASY の物語の演習（第 2 話）の出撃準備: この話で覚えること、決まっている部隊。
func _scene_story_fantasy_sortie() -> bool:
	_app.context.story.choose_campaign(_fantasy())  # クリアは、いま選んでいる物語の記録に書く
	_app.context.story.clear(_fantasy().episodes[0].id)
	if not await _scene_story_fantasy_list():
		return false
	_app.current_scene().choose(_fantasy().episodes[1])
	await _app.scene_changed
	if not _at_sortie():
		return false
	return _app.current_scene().is_squad_fixed()


## FANTASY の物語の number 番目（0 から。負なら最後）の話を始める（出撃準備の場面に入る）。前の話は、クリアしたことにする。
func _start_fantasy(number: int) -> bool:
	var episodes: Array = _fantasy().episodes
	if number < 0:
		number = episodes.size() - 1
	_app.context.story.choose_campaign(_fantasy())  # クリアは、いま選んでいる物語の記録に書く
	for i: int in number:
		_app.context.story.clear(episodes[i].id)
	if not await _scene_story_fantasy_list():
		return false
	_app.current_scene().choose(episodes[number])
	await _app.scene_changed
	return _app.current_id() == SceneFlow.SORTIE


func _scene_story_fantasy_evolve_sortie() -> bool:
	var number := -1
	for i: int in _fantasy().episodes.size():
		if _fantasy().episodes[i].id == &"trial_evolution":
			number = i
	return number >= 0 and await _start_fantasy(number) and _at_sortie()


## FANTASY の物語の「峠の番人」を、CPU に人の側を持たせて、中ボスの撃破で勝つまで進める。
## 人の側の駒が敵のプレイヤーの駒にダメージを与えていない種だけ（MVP が中ボスへのダメージで決まるところを撮る）。
func _scene_story_boss_mvp() -> bool:
	var number := -1
	for i: int in _fantasy().episodes.size():
		if _fantasy().episodes[i].id == &"boulder_warden":
			number = i
	if number < 0 or not await _start_fantasy(number) or not _at_sortie():
		return false
	if not await _sortie_to_battle():
		return false
	_scene = _app.current_scene()
	var setup: MatchSetup = _scene.source.make_setup(_seed)
	_battle = setup.create_battle()
	_stats = BattleStats.new(_battle)
	_log = BattleLog.new(_battle, ["プレイヤー1（青）", "CPU（赤）"] as Array[String])
	if _advance(func() -> bool: return false):
		return false
	var action := _cpu.next_action(_battle)
	if _battle.phase != Unit.Side.PLAYER1 or _stats.sides[Unit.Side.PLAYER1].damage > 0:
		return false
	_scene.start_with(_battle, _scene.source.look(), _seed, setup.scenario.title)
	_scene.stats = _stats
	await _scene.act(action)
	if not _battle.is_over() or _battle.winner != Unit.Side.PLAYER1 or _stats.ending != BattleStats.Ending.BOSS_SLAIN:
		return false
	_scene.result_screen().skip()
	return true


## FANTASY の物語の演習「分かれ道」: あと 1 撃で進化するパラディンを盾役の隣へ動かして攻撃し、進化先の選択を出す。
func _scene_story_fantasy_evolve() -> bool:
	var number := -1
	for i: int in _fantasy().episodes.size():
		if _fantasy().episodes[i].id == &"trial_evolution":
			number = i
	if number < 0 or not await _start_fantasy(number) or not _at_sortie():
		return false
	if not await _sortie_to_battle():
		return false
	_scene = _app.current_scene()
	var paladin: Unit = null
	var guard: Unit = null
	for unit: Unit in _scene.battle.units:
		if unit.kind == UnitKind.Id.PALADIN and unit.side == Unit.Side.PLAYER1:
			paladin = unit
		elif unit.kind == UnitKind.Id.SHIELD_TROOPER:
			guard = unit
	if paladin == null or guard == null:
		return false
	_scene.click_cell(paladin.cell)
	_scene.click_cell(guard.cell + Vector2i(0, 1))
	while _scene.is_busy():
		await get_tree().process_frame
	_scene.press_menu(&"attack")
	_scene.click_cell(guard.cell)
	while _scene.is_busy():
		await get_tree().process_frame
	return _scene.is_choosing_evolution()


## 部隊を選ぶ最初の話（FANTASY の物語の本編の 1 話目）の番号（0 から）。
func _fantasy_main_episode() -> int:
	for i: int in _fantasy().episodes.size():
		if _fantasy().episodes[i].squad_deck() == null:
			return i
	return 0


## FANTASY の物語の本編の 1 話目をクリアしたあとの話の一覧。
func _scene_story_fantasy_main_list() -> bool:
	_app.context.story.choose_campaign(_fantasy())
	for i: int in _fantasy_main_episode() + 1:
		_app.context.story.clear(_fantasy().episodes[i].id)
	return await _scene_story_fantasy_list()


## FANTASY の物語の最後の話の出撃準備（既定の編成）。
## FANTASY の物語の、味方が 2 か所に分かれて始まる話（岩山の合流）の出撃準備。
func _scene_story_split_sortie() -> bool:
	_app.context.decks.load_data({"decks": []})
	var at: int = _fantasy().episodes.map(func(episode: RefCounted) -> StringName: return episode.id).find(&"gorge_rejoin")
	if at < 0 or not await _start_fantasy(at):
		return false
	return _at_sortie()


## 南の置けるマス（盤の下半分）にいる最初の駒を、北の置けるマスの空いているところへ移す。
func _scene_story_split_placed() -> bool:
	if not await _scene_story_split_sortie():
		return false
	var deploy: Control = _app.current_scene().deploy_map()
	var own: Array[Vector2i] = deploy.unit_cells()
	var south: Array = own.filter(func(cell: Vector2i) -> bool: return cell.y > 10)
	var open: Array = deploy.zone().filter(func(cell: Vector2i) -> bool: return cell.y < 10 and not own.has(cell))
	if south.is_empty() or open.is_empty():
		return false
	deploy.press_cell(south[0])
	deploy.press_cell(open[0])
	_park_mouse()
	return deploy.unit_cells().has(open[0])


func _scene_story_split_talk() -> bool:
	if not await _scene_story_split_sortie() or not await _talk_from_sortie():
		return false
	var talk: Node = _app.current_scene()
	return talk.speaker() == "セリス" and talk.figures().size() >= 1


func _scene_story_split_start() -> bool:
	if not await _scene_story_split_sortie() or not await _sortie_to_battle():
		return false
	_scene = _app.current_scene()
	var size: Vector2i = _scene.battle.board.size
	_look_at(Vector3(size.x / 2.0, 0.0, size.y / 2.0))
	_aim(OrbitCamera.max_distance_for(size), 0.0, (OrbitCamera.MIN_PITCH + OrbitCamera.MAX_PITCH) / 2.0)
	_park_mouse()
	return true


## MILITARY の物語の「縫い目の発破」（結晶の採掘場。味方が正面と西の脇に分かれて始まる）の対戦の始めを、いちばん引いて見る。
func _scene_story_quarry_start() -> bool:
	_app.context.decks.load_data({"decks": []})
	if not await _start_story(_military_index(&"quarry_blast")) or not await _sortie_to_battle():
		return false
	_scene = _app.current_scene()
	var size: Vector2i = _scene.battle.board.size
	_look_at(Vector3(size.x / 2.0, 0.0, size.y / 2.0))
	_aim(OrbitCamera.max_distance_for(size), 0.0, (OrbitCamera.MIN_PITCH + OrbitCamera.MAX_PITCH) / 2.0)
	_park_mouse()
	return true


func _scene_story_fantasy_forest_sortie() -> bool:
	_app.context.decks.load_data({"decks": []})
	if not await _start_fantasy(_fantasy_index(&"mist_forest")):
		return false
	return _at_sortie()


## FANTASY の物語の話の番号（0 から）。無ければ最後の話。
func _fantasy_index(id: StringName) -> int:
	var episodes: Array = _fantasy().episodes
	var at := episodes.map(func(episode: RefCounted) -> StringName: return episode.id).find(id)
	return at if at >= 0 else episodes.size() - 1


## FANTASY の物語の最後の話「墓守の眠り」（縫い目の谷）の対戦の始めを、いちばん引いて見る。
func _scene_story_vale_start() -> bool:
	_app.context.decks.load_data({"decks": []})
	if not await _start_fantasy(_fantasy_index(&"vale_keeper")) or not await _sortie_to_battle():
		return false
	_scene = _app.current_scene()
	var size: Vector2i = _scene.battle.board.size
	_look_at(Vector3(size.x / 2.0, 0.0, size.y / 2.0))
	_aim(OrbitCamera.max_distance_for(size), 0.0, (OrbitCamera.MIN_PITCH + OrbitCamera.MAX_PITCH) / 2.0)
	_park_mouse()
	return true


## FANTASY の物語の最後の話の対戦の始めを、いちばん引いて見る。
func _scene_story_fantasy_forest_wide() -> bool:
	if not await _scene_story_fantasy_forest_sortie():
		return false
	if not await _sortie_to_battle():
		return false
	_scene = _app.current_scene()
	var size: Vector2i = _scene.battle.board.size
	_look_at(Vector3(size.x / 2.0, 0.0, size.y / 2.0))
	_aim(OrbitCamera.max_distance_for(size), 0.0, OrbitCamera.MIN_PITCH)
	return true


## 部隊編成の「ストーリー用」を FANTASY の物語に切り替えて、最初から雇える駒で組む。
func _scene_story_fantasy_decks() -> bool:
	await _app.go(SceneFlow.DECKS)
	var screen: Node = _app.current_scene()
	screen.set_mode(_fantasy().rules_id)
	screen.press_new()
	for kind: UnitKind.Id in _fantasy().starting_kinds:
		screen.hire(kind)
	return screen.editing_deck().army == _fantasy().army and not screen.editing_deck().entries.is_empty()


## 部隊を選ぶ最初の話（部隊が決まっていない最初の話。チュートリアルのあとの本編の 1 話目）の番号（0 から）。
func _main_episode() -> int:
	for i in Story.military().episodes.size():
		if Story.military().episodes[i].squad_deck() == null:
			return i
	return 0


## 本編の 1 話目をクリアしたあとの話の一覧（次の話が選べる。いま雇える駒が増えた）。
func _scene_story_list_cleared() -> bool:
	for i in _main_episode() + 1:
		_app.context.story.clear(Story.military().episodes[i].id)
	return await _scene_story_list()


## 何もクリアしていない話の一覧（頭のチュートリアルの話。番号に「（演習）」）。
func _scene_story_tutorial_list() -> bool:
	return await _scene_story_list()


## チュートリアルの話（第 2 話「撃ち合い」）の出撃準備: この話で覚えること、決まっている部隊。
func _scene_story_tutorial_sortie() -> bool:
	if not await _start_story(1):
		return false
	if not _at_sortie():
		return false
	return _app.current_scene().is_squad_fixed()


func _scene_story_talk_log() -> bool:
	if not await _start_story() or not await _talk_from_sortie():
		return false
	var talk: Node = _app.current_scene()
	while talk.line_index() < talk.line_count() - 1:
		talk.press_next()
	talk.open_log()
	await get_tree().process_frame
	await get_tree().process_frame
	return talk.talk_log().is_open()


func _scene_story_talk() -> bool:
	if not await _start_story() or not await _talk_from_sortie():
		return false
	return _talk_until(1)


## いまの会話を、陣営 side の、at 人目（0 から。同じ人は 1 度だけ数える）の話し手が話す文まで送る。その人が出てこなければ偽。
func _talk_until(side: int, at := 0) -> bool:
	var talk: Node = _app.current_scene()
	var lines: Array = talk.talk["lines"]
	var seen := []
	for index in lines.size():
		var who: int = lines[index].get("who", -1)
		if int(lines[index]["side"]) != side or seen.has(who):
			continue
		seen.append(who)
		if seen.size() == at + 1:
			while talk.line_index() < index:
				talk.press_next()
			return true
	return false


## 話 id の、MILITARY の物語の中の番号（0 から）。
func _military_index(id: StringName) -> int:
	var episodes: Array = Story.military().episodes
	for index in episodes.size():
		if episodes[index].id == id:
			return index
	return -1


## 地の文（話し手のいない行）。「尾根の小道」の前の会話は、地の文から始まる。
func _scene_story_talk_narration() -> bool:
	if not await _start_story(_military_index(&"ridge_path")) or not await _talk_from_sortie():
		return false
	return _app.current_scene().is_narrating()


## ハーデンとイェルダが向き合う会話（MILITARY の物語）。ハーデンが話していて、右にイェルダ。
func _scene_story_rivals_ridge() -> bool:
	if not await _start_story(_military_index(&"ridge_path")) or not await _talk_from_sortie():
		return false
	return _talk_until(0) and _app.current_scene().figures().size() == 2


## ハーデンとイェルダが向き合う会話（FANTASY の物語の「森の守り」）。イェルダが話していて、右にハーデン。
func _scene_story_rivals_forest() -> bool:
	var episodes: Array = _fantasy().episodes
	var at := episodes.map(func(episode: RefCounted) -> StringName: return episode.id).find(&"mist_forest")
	if at < 0 or not await _start_fantasy(at) or not await _talk_from_sortie():
		return false
	var talk: Node = _app.current_scene()
	while talk.line_index() < talk.line_count() and talk.speaker() != "イェルダ":
		talk.press_next()
	return talk.speaker() == "イェルダ" and talk.figures().size() == 2


## 部隊の中の人（人の軍の 3 人目の話し手）が話している、対戦の前の会話。右に敵の話し手。
func _scene_story_talk_squad() -> bool:
	if not await _start_story(_military_index(&"gorge_rout")) or not await _talk_from_sortie():
		return false
	return _talk_until(0, 2) and _app.current_scene().figures().size() == 2


## 敵の軍が出てこない会話。人の軍の 2 人目の話し手が、右に立って話している。
func _scene_story_talk_allies() -> bool:
	if not await _start_story(_military_index(&"drill_medic")) or not await _talk_from_sortie():
		return false
	var talk: Node = _app.current_scene()
	return _talk_until(0, 1) and talk.figures().size() == 2 and talk.figures().all(func(view: Control) -> bool: return view.side == 0)


func _scene_story_talk_drill() -> bool:
	return await _start_story(0) and await _talk_from_sortie()


func _scene_story_fantasy_talk() -> bool:
	return await _start_fantasy(0) and await _talk_from_sortie()


func _scene_story_talk_menu() -> bool:
	if not await _scene_story_talk():
		return false
	_app.open_menu()
	return _app.system_menu().is_open()


## 出撃して、前の会話を飛ばして、話の対戦の場面に入る。
func _story_battle(number := -1) -> bool:
	if not await _start_story(number):
		return false
	if not _at_sortie():
		return false
	if not await _sortie_to_battle():
		return false
	_scene = _app.current_scene()
	return true


## 話を始めて、出撃準備の場面に入る。
func _at_sortie() -> bool:
	return _app.current_id() == SceneFlow.SORTIE


## 出撃準備の「出撃」で、対戦の前の会話の場面に入る。
func _talk_from_sortie() -> bool:
	if not _at_sortie():
		return false
	_app.current_scene().press_sortie()
	await _app.scene_changed
	return _app.current_id() == SceneFlow.TALK


## 出撃準備の「出撃」のあと、対戦の前の会話を飛ばして、話の対戦の場面に入る（会話を通り過ぎていれば、そのまま対戦へ）。
func _sortie_to_battle() -> bool:
	_app.current_scene().press_sortie()
	await _app.scene_changed
	if _app.current_id() == SceneFlow.TALK:
		_app.current_scene().press_skip()
		await _app.scene_changed
	return _app.current_id() == SceneFlow.BATTLE


## 出撃準備（ストーリー用の部隊を 5 つ取っておいて、2 つ目を選んだところ。選べる部隊の並びに 3 部隊ぶんが見え、続きは欄の中で送る）。
func _scene_story_sortie_squads() -> bool:
	_app.context.decks.load_data({"decks": []})
	var chosen: RefCounted = null
	var lineups := {
		"狙撃の小隊": [UnitKind.Id.SHIELD_TROOPER, UnitKind.Id.SNIPER, UnitKind.Id.SNIPER],
		"盾の壁": [UnitKind.Id.SHIELD_TROOPER, UnitKind.Id.SHIELD_TROOPER, UnitKind.Id.SNIPER],
		"速攻": [UnitKind.Id.SNIPER, UnitKind.Id.SNIPER],
		"守りの小隊": [UnitKind.Id.SHIELD_TROOPER, UnitKind.Id.SHIELD_TROOPER],
		"試し": [UnitKind.Id.SNIPER],
	}
	for name: String in lineups:
		var deck := Deck.new(Story.military().army, _app.context.story.deck_rules())
		for kind: UnitKind.Id in lineups[name]:
			deck.add(kind)
		var saved: RefCounted = _app.context.decks.add(name, deck)
		if name == "盾の壁":
			chosen = saved
	if not await _start_story():
		return false
	if not _at_sortie():
		return false
	_app.current_scene().choose(chosen.id)
	return _app.current_scene().chosen_id() == chosen.id and _app.current_scene().options_fully_shown() >= 3


## 出撃準備（ストーリー用の部隊を 1 つ取っておいて、それを選んだところ）。
func _scene_story_sortie() -> bool:
	_app.context.decks.load_data({"decks": []})
	var deck := Deck.new(Story.military().army, _app.context.story.deck_rules())
	for kind: UnitKind.Id in [UnitKind.Id.SHIELD_TROOPER, UnitKind.Id.SNIPER, UnitKind.Id.SNIPER, UnitKind.Id.MEDIC]:
		deck.add(kind)
	var saved: RefCounted = _app.context.decks.add("狙撃の小隊", deck)
	if not await _start_story():
		return false
	if not _at_sortie():
		return false
	_app.current_scene().choose(saved.id)
	return _app.current_scene().chosen_id() == saved.id
