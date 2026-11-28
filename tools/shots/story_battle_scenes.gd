extends "res://tools/shots/story_menu_scenes.gd"
## スクリーンショットの場面: ストーリーの出撃準備と対戦（勝ち方、魔物、途中の会話、決着、解放）。


## 全部の話をクリアして、部隊編成の「ストーリー用」で、解放した駒（コマンドー）を雇う。
func _scene_story_unlocked_decks() -> bool:
	for episode in Story.military().episodes:
		_app.context.story.clear(episode.id)
	await _app.go(SceneFlow.DECKS)
	var screen: Node = _app.current_scene()
	screen.set_mode(Story.military().rules_id)
	screen.press_new()
	for kind: UnitKind.Id in [UnitKind.Id.SHIELD_TROOPER, UnitKind.Id.SNIPER, UnitKind.Id.COMMANDO, UnitKind.Id.MEDIC]:
		screen.hire(kind)
	screen.select_entry(2)
	screen.hover_kind(UnitKind.Id.COMMANDO)
	return screen.editing_deck().entries.size() == 4 and screen.editing_deck().budget() > DeckRules.versus().budget(Story.military().army)


## 第 2 話までクリアしたあとの話の一覧（持ち物が増え、コストの上限が上がった）。
func _scene_story_list_items() -> bool:
	for i in _main_episode() + 2:
		_app.context.story.clear(Story.military().episodes[i].id)
	return await _scene_story_list()


## 出撃準備で、既定の編成を選んでいるところ（取っておいた部隊は無い）。
func _scene_story_sortie_default() -> bool:
	_app.context.decks.load_data({"decks": []})
	if not await _start_story():
		return false
	if not _at_sortie():
		return false
	return _app.current_scene().chosen_id() == ""


## 守り切る話（(hold_turns を書いた最初の話)）の番号（0 から）。無ければ -1。
func _hold_episode() -> int:
	for i in Story.military().episodes.size():
		if Story.military().episodes[i].hold_turns > 0:
			return i
	return -1


func _scene_story_hold_sortie() -> bool:
	var number := _hold_episode()
	if number == -1 or not await _start_story(number):
		return false
	return _at_sortie()


## 守り切る話の対戦を、CPU どうしで until まで進めて画面に出す。until が無ければ、決着の手前まで進める。
func _hold_battle_until(until := Callable()) -> bool:
	var number := _hold_episode()
	if number == -1 or not await _story_battle(number):
		return false
	var setup: MatchSetup = _scene.source.make_setup(_seed)
	_battle = setup.create_battle()
	_stats = BattleStats.new(_battle)
	_log = BattleLog.new(_battle, ["プレイヤー1（青）", "CPU（赤）"] as Array[String])
	var reached := _advance(until if until.is_valid() else func() -> bool: return false)
	if reached != until.is_valid():
		return false
	_scene.start_with(_battle, _scene.source.look(), _seed, setup.scenario.title)
	_scene.stats = _stats
	_scene.battle_log = _log
	return true


func _scene_story_hold_battle() -> bool:
	return await _hold_battle_until(func() -> bool: return _battle.turn >= 3 and _battle.phase == Unit.Side.PLAYER1)


func _scene_story_hold_last() -> bool:
	return await _hold_battle_until(func() -> bool: return _battle.turn >= _battle.hold_turns and _battle.phase == Unit.Side.PLAYER1)


## 守り切る話で、最後のターンの終わりまで持ちこたえた決着の画面（守り切りで勝つ種だけ）。
## 最後の手は敵（CPU）のターン終了なので、画面に出すと、画面の CPU がそのまま指す。
func _scene_story_hold_result() -> bool:
	if not await _hold_battle_until():
		return false
	if not _battle.is_over():
		var action := _cpu.next_action(_battle)
		if action == null or not await _scene.act(action):
			return false
	while not _battle.is_over():
		await get_tree().process_frame
	var held := _battle.turn == _battle.hold_turns and _battle.capture_turns[Unit.Side.PLAYER1] < Battle.CAPTURE_TURNS_TO_WIN
	for unit in _battle.units:
		if unit.side == Unit.Side.PLAYER2 and unit.kind == UnitKind.Id.KING:
			held = held and _battle.winner == Unit.Side.PLAYER1
			_scene.result_screen().skip()
			return held
	return false


## 全滅させる話（wins に全滅を書いた最初の話）の番号（0 から）。無ければ -1。
func _rout_episode() -> int:
	for i in Story.military().episodes.size():
		if Story.military().episodes[i].wins.has(GameWonEvent.Reason.ROUTED):
			return i
	return -1


## 勝ち方が中ボスの撃破の話（「結晶の番人」）の番号（0 から）。無ければ -1。
func _boss_episode() -> int:
	for i in Story.military().episodes.size():
		if Story.military().episodes[i].wins.has(GameWonEvent.Reason.BOSS_SLAIN):
			return i
	return -1


func _scene_story_boss_sortie() -> bool:
	var number := _boss_episode()
	if number == -1 or not await _start_story(number):
		return false
	return _at_sortie()


func _scene_story_boss_start() -> bool:
	var number := _boss_episode()
	return number != -1 and await _story_battle(number)


func _scene_story_rout_sortie() -> bool:
	var number := _rout_episode()
	if number == -1 or not await _start_story(number):
		return false
	return _at_sortie()


func _scene_story_rout_start() -> bool:
	var number := _rout_episode()
	return number != -1 and await _story_battle(number)


func _scene_story_rout_wide() -> bool:
	if not await _scene_story_rout_start():
		return false
	var size: Vector2i = _scene.battle.board.size
	_look_at(Vector3(size.x / 2.0, 0.0, size.y / 2.0))
	_aim(OrbitCamera.max_distance_for(size), 0.0, OrbitCamera.MIN_PITCH)
	return true


## 魔物の群れの話（敵の軍が無い最初の話）の番号（0 から）。無ければ -1。
## with_king なら、将のいる群れの最初の話。
func _monster_episode(with_king := false) -> int:
	for i in Story.military().episodes.size():
		var episode: RefCounted = Story.military().episodes[i]
		if episode.enemy_army == UnitKind.Army.NONE and (episode.enemy_king or not with_king):
			return i
	return -1


## 話の対戦を、CPU どうしで、敵（プレイヤー2）が skill を使ったあとの人の番の始めまで進めて画面に出す。fantasy なら FANTASY の物語の話。
## 使った駒の id を返す（使わないまま決着しそうなら -1）。
func _battle_until_enemy_skill(episode_id: StringName, skill: Skill.Id, fantasy := false) -> int:
	if fantasy:
		var at: int = _fantasy().episodes.map(func(episode: RefCounted) -> StringName: return episode.id).find(episode_id)
		if at < 0 or not await _start_fantasy(at) or not await _sortie_to_battle():
			return -1
		_scene = _app.current_scene()
	elif not await _story_battle(_military_index(episode_id)):
		return -1
	var setup: MatchSetup = _scene.source.make_setup(_seed)
	_battle = setup.create_battle()
	_stats = BattleStats.new(_battle)
	_log = BattleLog.new(_battle, ["プレイヤー1（青）", "CPU（赤）"] as Array[String])
	var used := [-1]
	var watch := func(events: Array[BattleEvent]) -> void:
		for event in events:
			var skill_used := event as SkillUsedEvent
			if skill_used != null and skill_used.skill == skill and used[0] == -1:
				used[0] = skill_used.unit_id
	# 使ったあと、人の番の始めで止める（敵の番の途中で画面に出すと、画面の CPU が続きを指し、カメラがそちらへ寄る）。
	if not _advance(func() -> bool: return used[0] != -1 and _battle.phase == Unit.Side.PLAYER1, watch):
		return -1
	if _battle.unit_by_id(used[0]) == null:
		return -1
	_scene.start_with(_battle, _scene.source.look(), _seed, setup.scenario.title)
	_scene.stats = _stats
	_scene.battle_log = _log
	return used[0]


func _scene_story_horde_raise() -> bool:
	var caller_id := await _battle_until_enemy_skill(&"barrow_rout", Skill.Id.BONE_RAISE)
	if caller_id == -1:
		return false
	var caller := _battle.unit_by_id(caller_id)
	_look_at(BoardView.cell_center(caller.cell))
	_aim(9.0, 0.0, 50.0)
	return true


func _scene_story_drums_talk() -> bool:
	var at: int = _fantasy().episodes.map(func(episode: RefCounted) -> StringName: return episode.id).find(&"crag_drums")
	if at < 0 or not await _start_fantasy(at) or not await _talk_from_sortie():
		return false
	var talk: Node = _app.current_scene()
	while talk.line_index() < talk.line_count() and talk.speaker() != "亡者の鼓手":
		talk.press_next()
	return talk.speaker() == "亡者の鼓手"


func _scene_story_drums_battle() -> bool:
	var drummer_id := await _battle_until_enemy_skill(&"crag_drums", Skill.Id.WAR_DRUM, true)
	if drummer_id == -1:
		return false
	var drummer := _battle.unit_by_id(drummer_id)
	var charged: Unit = null
	for unit in _battle.units:
		if unit.side == Unit.Side.PLAYER2 and Statuses.has(unit, Status.Type.ASSAULT):
			charged = unit
	if charged == null:
		return false
	_look_at(BoardView.cell_center(drummer.cell))
	_aim(10.0, 0.0, 50.0)
	_scene.hover(charged.cell)
	return true


func _scene_story_monster_talk() -> bool:
	var number := _monster_episode()
	if number == -1 or not await _start_story(number) or not await _talk_from_sortie():
		return false
	for i in 2:
		_app.current_scene().press_next()  # 3 行目（敵の話し手の札）
	return true


func _scene_story_monster_sortie() -> bool:
	var number := _monster_episode()
	if number == -1 or not await _start_story(number):
		return false
	return _at_sortie()


func _scene_story_monster_detail() -> bool:
	if not await _scene_story_monster_sortie():
		return false
	var detail: Control = _app.current_scene().press_face(Unit.Side.PLAYER2, 2)
	return detail != null and detail.visible


func _scene_story_sortie_hover() -> bool:
	if not await _scene_story_sortie():
		return false
	var deploy: Control = _app.current_scene().deploy_map()
	var longest := Vector2i(-1, -1)
	var length := 0
	for cell: Vector2i in deploy.unit_cells():
		deploy.hover_cell(cell)
		var name: String = _app.current_scene().deploy_note().shown_name()
		if name.length() > length:
			length = name.length()
			longest = cell
	deploy.hover_cell(longest)
	return length > 0


func _scene_story_sortie_placed() -> bool:
	if not await _scene_story_sortie():
		return false
	return _move_and_pick(_app.current_scene().deploy_map())


func _scene_story_sortie_detail() -> bool:
	if not await _scene_story_sortie():
		return false
	# 持ち物を持っている駒を探して開く（無ければ、最初の雇った駒）。
	var detail: Control = null
	for index in range(1, 12):
		var opened: Control = _app.current_scene().press_face(Unit.Side.PLAYER1, index)
		if opened == null:
			break
		detail = opened
		if not detail.shown_sheet().items.is_empty():
			break
	if detail != null and detail.shown_sheet().items.is_empty():
		detail = _app.current_scene().press_face(Unit.Side.PLAYER1, 1)
	return detail != null and detail.visible


func _scene_story_monster_start() -> bool:
	var number := _monster_episode()
	if number == -1 or not await _story_battle(number):
		return false
	var brute := _first_unit_of(UnitKind.Id.SKELETON_BRUTE)
	if brute == null:
		return false
	_look_at(BoardView.cell_center(brute.cell))
	_aim(9.0, 0.0, 50.0)
	return true


func _scene_story_monster_info() -> bool:
	if not await _scene_story_monster_start():
		return false
	var brute := _first_unit_of(UnitKind.Id.SKELETON_BRUTE)
	_scene.hover(brute.cell)
	return true


## 場面 story_monster_king の構図: カメラの距離、向き（度）、見る点を将からずらす量（向きが 0 度のときのもの）。
## 糸喰いを倒す攻撃を始めてから、弾けた瞬間を撮るまでの時間（遊びの時間の秒。SLOW_MOTION で遅くして待つ）。
const BURST_AFTER := 2.4
const KING_FRAME_DISTANCE := 8.0
const KING_FRAME_YAW := 70.0
const KING_FRAME_SHIFT := Vector3(0.0, 0.0, -0.8)


func _scene_story_monster_king() -> bool:
	var number := _monster_episode(true)
	if number == -1 or not await _story_battle(number):
		return false
	var king: Unit = null
	for unit: Unit in _scene.battle.units:
		if unit.kind == UnitKind.Id.KING and unit.side == Unit.Side.PLAYER2:
			king = unit
	if king == null:
		return false
	# 骸骨の将は背が高い（kaykit_look.gd の KING_LOOKS の scale）。頭が上の帯と途中の台詞の帯に隠れないよう、
	# 少し引いて、見る点を将の向こう側（カメラから遠い側）へずらし、将を画面の真ん中より下に置く。
	_look_at(BoardView.cell_center(king.cell) + KING_FRAME_SHIFT.rotated(Vector3.UP, deg_to_rad(KING_FRAME_YAW)))
	_aim(KING_FRAME_DISTANCE, KING_FRAME_YAW, 38.0)
	_scene.hover(king.cell)
	var episode: RefCounted = Story.military().episodes[number]
	_scene.clear_talk_for_check()
	_scene.say_for_check([BattleCues.Line.new(1, episode.speakers[1], "眠れぬ者らよ、生きた者を通すな。", episode.figures[1])] as Array[BattleCues.Line])
	return episode.king_looks[1] != &""


func _first_unit_of(kind: UnitKind.Id) -> Unit:
	for unit: Unit in _scene.battle.units:
		if unit.kind == kind:
			return unit
	return null


## 対戦の途中の会話の札（ターン 1 の台詞を持つ最初の話の、対戦の始め）。
func _scene_story_battle_talk() -> bool:
	for i in Story.military().episodes.size():
		if Story.military().episodes[i].cues.any(func(cue: RefCounted) -> bool: return cue.trigger == BattleCues.TURN and cue.value == 1):
			if not await _story_battle(i):
				return false
			_scene.hide_notice()  # 始めの台詞は、対戦ルールの知らせを閉じてから出る
			return _scene.talk_line() != null
	return false


func _scene_story_battle_talk_hold() -> bool:
	if not await _scene_story_battle_talk():
		return false
	var line: BattleCues.Line = _scene.talk_line()
	_scene.clear_talk_for_check()
	_scene.set_talk_hold(true)
	_scene.say_for_check([line] as Array[BattleCues.Line])
	for i in 120:
		if _scene.talk_line() != null and not _scene.is_banner_shown():
			break
		await get_tree().process_frame
	await get_tree().create_timer(0.6).timeout
	return _scene.is_talk_holding()


## 部隊編成の「ストーリー用」の一覧と、組む画面（いま雇える駒だけ）。
func _scene_decks_story() -> bool:
	await _app.go(SceneFlow.DECKS)
	var screen: Node = _app.current_scene()
	screen.set_mode(Story.military().rules_id)
	screen.press_new()
	for kind: UnitKind.Id in [UnitKind.Id.SHIELD_TROOPER, UnitKind.Id.SNIPER, UnitKind.Id.MEDIC]:
		screen.hire(kind)
	screen.select_entry(0)  # 持ち物の欄（まだ持たせられない持ち物は、灰色の「未解放」）
	return screen.is_editing() and screen.editing_deck().rules.id == Story.military().rules_id


func _scene_story_start() -> bool:
	return await _story_battle()


func _scene_story_wide() -> bool:
	if not await _story_battle():
		return false
	var size: Vector2i = _scene.battle.board.size
	_look_at(Vector3(size.x / 2.0, 0.0, size.y / 2.0))
	_aim(OrbitCamera.max_distance_for(size), 0.0, OrbitCamera.MIN_PITCH)
	return true


## 出撃準備の「部隊編成」で、編成（ストーリー用）へ寄り道したところ。
func _scene_story_decks_detour() -> bool:
	if not await _scene_story_sortie():
		return false
	_app.current_scene().press_edit_decks()
	await _app.scene_changed
	return _app.current_id() == SceneFlow.DECKS and _app.current_scene().is_detour()


## 話の対戦を、CPU どうしで決着の手前まで進め、最後の手を画面で指して負ける（敵 = プレイヤー2 が勝つ種だけ）。
func _scene_story_defeat() -> bool:
	if not await _story_battle():
		return false
	# 既定の編成では人の側（CPU が持つ）がほぼ勝つので、負ける局を作るため、人の部隊をスナイパー 1 体にする。
	var weak := Deck.new(Story.military().army, _app.context.story.deck_rules())
	weak.add(UnitKind.Id.SNIPER)
	_scene.source.human_deck = weak
	var setup: MatchSetup = _scene.source.make_setup(_seed)
	_battle = setup.create_battle()
	_stats = BattleStats.new(_battle)
	_log = BattleLog.new(_battle, ["プレイヤー1（青）", "CPU（赤）"] as Array[String])
	if _advance(func() -> bool: return false):
		return false
	var action := _cpu.next_action(_battle)
	if _battle.phase != Unit.Side.PLAYER2:
		return false  # 人の側の手で決着する種
	_scene.start_with(_battle, _scene.source.look(), _seed, setup.scenario.title)
	_scene.stats = _stats
	await _scene.act(action)
	if not _battle.is_over() or _battle.winner != Unit.Side.PLAYER2:
		return false
	_scene.result_screen().skip()
	return true


## 話の対戦を、CPU どうしで決着の手前まで進め、最後の手を画面で指して勝つ（人の側 = プレイヤー1 が勝つ種だけ）。
func _story_win(number := -1) -> bool:
	if not await _story_battle(number):
		return false
	var setup: MatchSetup = _scene.source.make_setup(_seed)
	_battle = setup.create_battle()
	_stats = BattleStats.new(_battle)
	_log = BattleLog.new(_battle, ["プレイヤー1（青）", "CPU（赤）"] as Array[String])
	if _advance(func() -> bool: return false):
		return false
	var action := _cpu.next_action(_battle)
	if _battle.phase != Unit.Side.PLAYER1:
		return false  # 敵の手で決着する（人の側が負ける）種
	_scene.start_with(_battle, _scene.source.look(), _seed, setup.scenario.title)
	_scene.stats = _stats
	await _scene.act(action)
	if not _battle.is_over() or _battle.winner != Unit.Side.PLAYER1:
		return false
	_scene.result_screen().skip()
	return true


func _scene_story_result() -> bool:
	return await _story_win()


func _scene_story_after() -> bool:
	if not await _story_win():
		return false
	var screen: Control = _scene.result_screen()
	while screen.enabled_buttons().is_empty():
		await get_tree().process_frame
	screen.press_continue()
	await _app.scene_changed
	return _app.current_id() == SceneFlow.TALK


## 連邦の第 1 話に勝って、決着の画面の「次へ」で、戦闘のあとの 1 つ目の場面（盤の前の会話）へ。
func _first_episode_after() -> bool:
	if not await _story_win(0):
		return false
	var screen: Control = _scene.result_screen()
	while screen.enabled_buttons().is_empty():
		await get_tree().process_frame
	screen.press_continue()
	await _app.scene_changed
	return _app.current_id() == SceneFlow.TALK


## 戦闘のあとの 1 つ目の場面: 盤の前の会話（生き残った兵が立つ）。
func _scene_story_after_board() -> bool:
	return await _first_episode_after() and _app.current_scene().backdrop_units()[0] > 0


## 戦闘のあとの 2 つ目の場面: 別の場所（峠の駐屯地）の会話。頭の地の文。
func _scene_story_after_place() -> bool:
	if not await _first_episode_after():
		return false
	_app.current_scene().press_skip()
	await _app.scene_changed
	return _app.current_id() == SceneFlow.TALK and _app.current_scene().is_scenery_only() and _app.current_scene().is_narrating()


func _scene_story_next_choice() -> bool:
	if not await _scene_story_after():
		return false
	var talk: Node = _app.current_scene()
	for i: int in talk.line_count() + 1:
		if talk.is_choosing():
			break
		talk.press_skip()
		talk.press_next()
	return talk.is_choosing()


func _scene_story_battle_menu() -> bool:
	if not await _story_battle():
		return false
	_app.open_menu()
	return _app.system_menu().is_open() and _app.system_menu().item_ids().has(&"exit:episodes")


func _scene_story_unlock() -> bool:
	if not await _scene_story_after():
		return false
	var talk: Node = _app.current_scene()
	talk.press_skip()
	return talk.speaker() == Story.notice_name()


## 知らせのある最後の話（ストーリー専用の持ち物が手に入る）の、あとの会話の知らせの行。対戦はせず、会話の場面だけを流れで始める。
func _scene_story_item_unlock() -> bool:
	var campaign: RefCounted = Story.military()
	var episode: RefCounted = null
	for each: RefCounted in campaign.episodes:
		if not Story.unlocked_before(each).news_of(each).is_empty():
			episode = each  # 知らせのある最後の話（話が増えても、知らせの無い話を選ばない）
	if episode == null:
		return false
	var talk := Story.talk_of(episode, [])
	for news: Dictionary in Story.unlocked_before(episode).news_of(episode):
		var line := {"side": Story.NOTICE_SIDE, "name": Story.notice_name()}
		line.merge(news)
		talk["lines"].append(line)
	var run := Run.new()
	run.exit = SceneFlow.TITLE
	run.add(Story.TALK, talk)
	_app.context.start_run(run)
	await _app.scene_changed
	var screen: Node = _app.current_scene()
	return _app.current_id() == SceneFlow.TALK and screen.speaker() == Story.notice_name()


## FANTASY の物語を全部クリアしたあとの部隊編成。パラディン（前衛）を選び、持ち物を持たせたところ。
func _scene_story_items_decks() -> bool:
	return await _items_decks(_fantasy(), [UnitKind.Id.PALADIN, UnitKind.Id.SORCERER, UnitKind.Id.SPELLBLADE, UnitKind.Id.PRIEST], 0,
			[Equipment.Id.DRAGON_SCALE, Equipment.Id.TRAIL_MAP])


## MILITARY の物語を全部クリアしたあとの部隊編成。コマンドー（奇襲）を選び、ジェットパックを持たせたところ。
func _scene_story_items_military() -> bool:
	return await _items_decks(Story.military(), [UnitKind.Id.SHIELD_TROOPER, UnitKind.Id.SNIPER, UnitKind.Id.COMMANDO, UnitKind.Id.MEDIC], 2,
			[Equipment.Id.JET_PACK])


## 物語 campaign を全部クリアして、部隊編成のストーリー用で kinds を雇い、selected 番目の駒に items を持たせる。
func _items_decks(campaign: RefCounted, kinds: Array[UnitKind.Id], selected: int, items: Array[Equipment.Id]) -> bool:
	_app.context.story.choose_campaign(campaign)
	for episode: RefCounted in campaign.episodes:
		_app.context.story.clear(episode.id)
	await _app.go(SceneFlow.DECKS)
	var screen: Node = _app.current_scene()
	screen.set_mode(campaign.rules_id)
	screen.press_new()
	for kind in kinds:
		screen.hire(kind)
	screen.select_entry(selected)
	for item in items:
		screen.equip(item)
	return screen.editing_deck().entries[selected].equipment == items


func _scene_story_cleared() -> bool:
	# 「クリア済み」の印は、遊べる物語の全部の話をクリアしたとき。クリアは、いま選んでいる物語の記録に書く。
	for campaign: RefCounted in Story.campaigns():
		_app.context.story.choose_campaign(campaign)
		for episode: RefCounted in campaign.episodes:
			_app.context.story.clear(episode.id)
	await _app.go(SceneFlow.TITLE)
	return _app.current_scene().story_label().contains("クリア済み")
