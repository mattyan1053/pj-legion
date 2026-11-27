extends "res://tests/base_test.gd"
## ストーリー（game/story.gd、game/story_battle.gd、game/story/）: 話の流れ、話の対戦、解放。
## クリアの記録（書いて読み戻す、古いセーブ）は tests/game/test_story_records.gd。

const Names := preload("res://game/names.gd")
const Text := preload("res://game/text.gd")
const DeckText := preload("res://game/deck_text.gd")
const Story := preload("res://game/story.gd")
const Episode := preload("res://game/episode.gd")
const StoryBattle := preload("res://game/story_battle.gd")
const SceneFlow := preload("res://game/scene_flow.gd")
const Run := preload("res://game/run.gd")
const Campaign := preload("res://game/campaign.gd")
const AppContext := preload("res://game/app_context.gd")
const TalkScreen := preload("res://game/talk_screen.gd")
const Catalog := preload("res://game/sound_catalog.gd")
const Scene := Episode.StoryScene


func test_every_episode_has_a_unique_id_and_short_talks() -> void:
	# 話のファイルの形（キーの名前、駒、初期位置、勝ち方、きっかけ）は test_episode_data.gd が見る。
	var ids: Array[StringName] = []
	for episode in Story.military().episodes:
		assert_false(ids.has(episode.id), "話の id が重なっている: %s" % episode.id)
		ids.append(episode.id)
		for scene: RefCounted in episode.talk_scenes():
			assert_between(scene.lines.size(), 1, Episode.TALK_MAX_LINES, "会話は短く（%d 行まで）: %s" % [Episode.TALK_MAX_LINES, episode.id])


func test_run_is_sortie_talk_battle_talk_then_the_episode_list() -> void:
	var episode: RefCounted = Story.military().episodes[1]  # [before]・[after] で書いた話
	var run := Story.run_of(episode, Story.default_deck(Story.starting()))
	assert_eq(run.scene(), Story.SORTIE, "出撃準備から始める（会話は出撃してから）")
	assert_eq(run.data()["episode"], episode)
	var battle: StoryBattle = run.data()["battle"]
	assert_eq(run.advance(), &"talk")
	assert_eq(run.data()["title"], episode.title)
	assert_eq(run.data()["lines"].size(), episode.before.size())
	assert_eq(run.data()["lines"][0]["name"], episode.before[0].speaker_in(episode.speakers))
	assert_eq(run.advance(), &"battle")
	assert_true(run.data() == battle, "出撃準備は、対戦に渡すものの部隊を選び直す")
	assert_eq(run.advance(), &"talk")
	assert_eq(run.data()["lines"].size(), episode.after.size())
	assert_eq(run.data()["next_episode"], Story.military().episodes[2], "あとの会話のあとに、次の話を選べる")
	assert_eq(run.advance(), Story.EPISODE_LIST, "話を終えたら、話の一覧へ戻る")
	for scene: StringName in [&"talk", Story.SORTIE, &"battle", Story.EPISODE_LIST, &"title"]:
		assert_true(SceneFlow.has(scene), "場面の表に無い: %s" % scene)
	assert_eq(run.menu_exits.map(func(exit: Array) -> StringName: return exit[0]), [Story.EPISODE_LIST], "システムメニューから話の一覧へ戻れる")


## 話は場面の列（episode.gd の scenes）で持つ。いまの話のファイルからは、どの話も 出撃準備 → 会話（[before]。1 度だけ）→ 対戦 → 会話（[after]）。
func test_every_episode_is_a_list_of_scenes_built_from_its_sections() -> void:
	var Kind := Episode.StoryScene.Kind
	for episode: Episode in Story.all_episodes():
		if episode.written_as_scenes:
			continue  # 場面の節で書いた話は、書いた順（test_episode_data.gd）
		assert_eq(episode.scenes.map(func(scene: RefCounted) -> int: return scene.kind), [Kind.SORTIE, Kind.TALK, Kind.BATTLE, Kind.TALK], episode.id)
		assert_true(episode.talk_before_battle().lines == episode.before and episode.talk_before_battle().once, episode.id)
		assert_eq(episode.talk_before_battle().music, episode.before_talk_music())
		assert_true(episode.talk_after_battle().lines == episode.after and not episode.talk_after_battle().once, episode.id)
		assert_eq(episode.talk_after_battle().music, episode.after_talk_music())
		assert_eq(episode.scene_after_battle(), episode.talk_after_battle())


## 話の流れ（run_of）は、場面の列を順に回すだけ。列を変えれば、流れも変わる（対戦の無い話、会話の場面がいくつもある話）。
func test_the_run_follows_the_list_of_scenes() -> void:
	var episode: Episode = Story.military().episodes[1]
	var kept := episode.scenes  # 読み込んだ話を借りるので、終わりに戻す
	var first := Scene.talk("before", episode.before, &"talk")
	var second := Scene.talk("after", episode.after, &"")
	episode.scenes = [first, second] as Array[Scene]
	var run := Story.run_of(episode, Story.default_deck(Story.starting()))
	assert_eq(run.scene(), &"talk", "出撃準備も対戦も無い話は、会話から始まる")
	assert_eq(run.data()["lines"].size(), episode.before.size())
	assert_eq(run.data()["music"], &"talk")
	assert_false(run.data().has("battle"), "対戦の無い話の会話は、背景に兵を立たせない")
	assert_false(run.data().has("next_episode") or run.data().has("clears"), "「次の話へ」と、読み終えたときのクリアは、最後の会話だけ")
	assert_eq(run.advance(), &"talk")
	assert_eq(run.data()["lines"].size(), episode.after.size())
	assert_eq(run.data()["next_episode"], Story.military().episodes[2])
	assert_eq(run.advance(), Story.EPISODE_LIST)
	assert_eq(StoryBattle.new(episode, null).after_result_music(), Catalog.AFTER_TALK_MUSIC, "対戦の無い話は、決着のあとの曲を会話から取らない")
	# 対戦で終わる話（あとの会話が無い）: 「次の話へ」を選ばせる会話が無いので、そのまま話の一覧へ。
	episode.scenes = [Scene.sortie(), first, Scene.battle()] as Array[Scene]
	run = Story.run_of(episode, Story.default_deck(Story.starting()))
	assert_eq([run.scene(), run.advance(), run.advance(), run.advance()], [Story.SORTIE, &"talk", &"battle", Story.EPISODE_LIST])
	assert_eq(StoryBattle.new(episode, null).after_result_music(), Catalog.AFTER_TALK_MUSIC)
	episode.scenes = kept


## 場面の節で書いた話の流れ: 別の場所の会話は、その場所の景色を背景にする（兵は立たせない）。話の盤の会話は、兵を立たせる。
func test_the_run_of_a_scenes_episode_gives_each_talk_its_place() -> void:
	var episode: Episode = Campaign.load_file("res://game/story/_template/story.txt").episodes[1]
	var run := Story.run_of(episode, Story.default_deck(Story.starting()))
	assert_eq(run.scene(), &"talk")
	assert_false(run.data().has("battle"), "別の場所の会話に、盤の兵は立たせない")
	assert_eq(run.data()["look"], &"drill_yard")
	assert_eq(run.data()["board"].size, episode.scenes[0].place.make_board().size)
	assert_false(run.data().has("cut"))
	assert_eq(run.advance(), &"talk")
	assert_true(run.data()["cut"] and run.data()["color"] == &"night" and not run.data().has("battle"), "カットシーンは、会話の場面に cut の印を付けて渡す")
	assert_eq([run.advance(), run.advance(), run.advance()], [&"talk", Story.SORTIE, &"talk"])
	assert_true(run.data().has("battle") and not run.data()["after"] and run.data()["look"] == episode.look, "話の盤の会話は、初期位置の兵")
	assert_eq([run.advance(), run.advance()], [&"battle", &"talk"])
	assert_true(run.data()["after"] and not run.data().has("clears"), "対戦のある話は、対戦に勝ったときにクリア")
	# 決着の画面の「部隊変更」で戻るのは出撃準備（対戦より前の会話は、もう出さない）。
	run.back()
	assert_eq(run.back(), Story.SORTIE)
	assert_eq(run.advance(), &"battle")


## 対戦の無い話: 最後の会話に、クリアにする話の id を渡す（talk_screen.gd が、読み終えたときにクリアと書く）。
func test_an_episode_without_a_battle_clears_at_the_end_of_its_last_talk() -> void:
	var episode: Episode = Episode.parse("[episode]\ntitle = 読むだけの話\nmap = ridge_path\n[cast]\n少尉 = ally\n[talk 夜]\nmusic = talk\n少尉: 静かだ。\n[talk 朝]\nmusic = talk_calm\n> 朝になった。\n", "res://probe/quiet_night.txt")
	var run := Story.run_of(episode, null)
	assert_eq(run.scene(), &"talk", "出撃準備は無い")
	assert_false(run.data().has("clears") or run.data().has("battle"))
	assert_eq(run.advance(), &"talk")
	assert_eq(run.data()["clears"], &"quiet_night")
	assert_eq(run.advance(), Story.EPISODE_LIST)
	# 会話の場面が、読み終えたときにクリアと書く。
	var context := AppContext.new()
	context.story = Story.new()
	var talk: Node = TalkScreen.new()
	talk.context = context
	talk.talk = {"title": "", "lines": [{"side": 0, "name": "少尉", "text": "静かだ。"}], "clears": &"quiet_night"}
	await settle(talk)
	assert_false(context.story.is_cleared(&"quiet_night"))
	talk.press_next()
	talk.press_next()
	assert_true(context.story.is_cleared(&"quiet_night"), "最後の文を送ると、クリア")
	talk.free()


## 連邦の第 1 話は、場面の節で書いた厚い版: カットシーン → 会話 2 つ（2 つ目に選択肢）→ 出撃準備 → 盤の前の会話 → 対戦 → あとの会話。
func test_the_first_military_episode_runs_its_written_scenes() -> void:
	var episode: Episode = Story.military().episodes[0]
	var run := Story.run_of(episode, Story.default_deck(Story.starting()))
	var seen: Array[StringName] = [run.scene()]
	assert_true(run.data()["cut"] and run.data()["color"] == &"night", "頭はカットシーン")
	while not run.is_done():
		var next := run.advance()
		if not run.is_done():
			seen.append(next)
			if seen.size() == 3:
				assert_true(run.data()["lines"].any(func(line: Dictionary) -> bool: return line.has("choice")), "2 つ目の会話に選択肢")
				assert_false(run.data().has("battle"), "別の場所の会話")
	assert_eq(seen, [&"talk", &"talk", &"talk", Story.SORTIE, &"talk", &"battle", &"talk"] as Array[StringName])
	assert_eq(episode.choices.keys(), [&"military_first_wish"])
	# 決着の画面の「部隊変更」で戻る先は出撃準備（前の場面は読み直さない）。
	run = Story.run_of(episode, Story.default_deck(Story.starting()))
	for i in 5:
		run.advance()
	assert_eq([run.scene(), run.back(), run.advance()], [&"battle", Story.SORTIE, &"battle"])


func test_changing_the_squad_after_a_battle_skips_the_talk_before() -> void:
	var episode: RefCounted = Story.military().episodes[1]
	var run := Story.run_of(episode, Story.default_deck(Story.starting()))
	run.advance()  # 会話（前）
	run.advance()  # 対戦
	assert_eq(run.back(), Story.SORTIE, "決着の画面の「部隊変更」で、会話を飛ばして出撃準備へ戻る")
	assert_eq(run.advance(), &"battle", "出撃し直しても、対戦の前の会話はもう出さない")
	run.insert(SceneFlow.DECKS)
	assert_eq(run.advance(), &"battle", "寄り道から戻っても同じ")


func test_the_last_episode_has_no_next_episode() -> void:
	for campaign: RefCounted in Story.campaigns():
		if campaign.episodes.is_empty():
			continue
		var last: RefCounted = campaign.episodes[-1]
		assert_eq(Story.episode_after(last), null, "%s: 物語の最後の話の次は無い" % last.id)
		var run := Story.run_of(last, Story.default_deck(Story.starting(campaign)))
		for i in 3:
			run.advance()
		assert_eq(run.data()["next_episode"], null)


func test_episode_battle_is_the_hand_map_against_a_fixed_cpu_enemy() -> void:
	for episode in Story.military().episodes:
		var source := Story.first_battle(episode)
		var setup := source.make_setup(7)
		assert_true(setup.is_valid(), "%s の対戦を始められない: %s" % [episode.id, setup.problems()])
		assert_eq(setup.controllers, [MatchSetup.Controller.HUMAN, MatchSetup.Controller.CPU] as Array[MatchSetup.Controller])
		assert_eq(source.cpu_side(), Unit.Side.PLAYER2)
		assert_true(setup.scenario.is_fixed(Unit.Side.PLAYER2))
		assert_eq(setup.army_of(Unit.Side.PLAYER1), Story.military().army)
		assert_eq(setup.army_of(Unit.Side.PLAYER2), episode.enemy_army)
		if episode.squad_deck() != null:
			assert_true(setup.scenario.is_fixed(Unit.Side.PLAYER1), "%s: 部隊の決まっている話は、その部隊" % episode.id)
			assert_eq(setup.deck_of(Unit.Side.PLAYER1).entries.size(), episode.squad.size())
		else:
			assert_false(setup.scenario.is_fixed(Unit.Side.PLAYER1))
			assert_eq(setup.deck_of(Unit.Side.PLAYER1), source.human_deck, "人は渡された部隊")
			assert_eq(setup.deck_of(Unit.Side.PLAYER1).rules.id, Story.military().rules_id, "初めて遊ぶときの、ストーリーの既定の編成")
		assert_eq(setup.scenario.start_gauge[Unit.Side.PLAYER1], episode.start_gauge)
		assert_eq(setup.scenario.title, episode.map_title)
		var battle := setup.create_battle()
		var placed := [0, 0]
		for unit in battle.units:
			if unit.side != Unit.Side.NEUTRAL:
				placed[unit.side] += 1
		assert_eq(placed[1], episode.enemy.size() + (1 if episode.enemy_king else 0), "敵の全員（将を含む。将のいない群れは将なし）が盤に置かれていない")
		assert_eq(battle.board.size, episode.map.make_board().size)
		assert_eq(source.look(), episode.look)


func test_episode_battle_offers_nothing_to_choose_again() -> void:
	var source := Story.first_battle(Story.military().episodes[0])
	assert_false(source.can_switch_opponent())
	assert_false(source.can_open_setup())
	assert_true(source.new_board_fields().is_empty())
	assert_true(source.copy() is StoryBattle)
	assert_eq(source.copy().episode, source.episode)
	assert_eq(source.copy().human_deck, source.human_deck, "やり直しも同じ部隊")


func test_only_a_win_shows_the_next_button() -> void:
	var source := Story.first_battle(Story.military().episodes[0])
	assert_true(source.can_continue(true))
	assert_false(source.can_continue(false))
	var versus := preload("res://game/match_choice.gd").new()
	assert_false(versus.can_continue(true), "対戦モードには「次へ」が無い")


func test_enter_retries_only_after_a_story_loss() -> void:
	var source := Story.first_battle(Story.military().episodes[0])
	assert_true(source.retries_on_enter(false), "負けたら Enter で同じマップで再戦")
	assert_false(source.retries_on_enter(true))
	var versus := preload("res://game/match_choice.gd").new()
	assert_false(versus.retries_on_enter(false), "対戦モードの Enter はタイトルへのまま")


func test_default_squad_hires_unlocked_kinds_evenly_with_at_most_one_item_each() -> void:
	var first := Story.default_deck(Story.unlocked_before(_episode(&"ridge_path")))  # 部隊を選ぶ最初の話
	assert_true(first.is_valid(), "既定の編成は、出撃できる")
	assert_eq(first.entries.size(), first.rules.max_units)
	for kind: UnitKind.Id in Story.kinds_before(_episode(&"ridge_path")):
		assert_eq(first.entries.filter(func(e: DeckEntry) -> bool: return e.kind == kind).size(), 2, "雇える駒を、まんべんなく雇う: %s" % Names.kind(kind))
	for episode: RefCounted in Story.military().episodes:
		var deck := Story.default_deck(Story.unlocked_before(episode))
		assert_true(deck.is_valid(), "%s の既定の編成は、出撃できる" % episode.title)
		var last_role := -1
		for entry: DeckEntry in deck.entries:
			assert_true(entry.equipment.size() <= 1, "装備は 1 体に 1 つまで")
			for item: Equipment.Id in entry.equipment:
				assert_true(Story.unlocked_before(episode).items.has(item), "持たせられる装備だけ")
			assert_true(UnitKind.role(entry.kind) >= last_role, "並びは役割の順（前衛が前）")
			last_role = UnitKind.role(entry.kind)
		for kind: UnitKind.Id in Story.kinds_before(episode):
			assert_true(deck.entries.any(func(e: DeckEntry) -> bool: return e.kind == kind), "雇える駒は、どれも 1 体は入る: %s" % Names.kind(kind))


func test_story_battles_offer_choosing_the_squad_again() -> void:
	assert_true(Story.first_battle(_episode(&"ridge_path")).can_choose_squad(), "決着の画面に「部隊を選び直す」を出す")
	assert_false(Story.first_battle(_episode(&"drill_first_steps")).can_choose_squad(), "部隊が決まっている話には出さない")
	assert_false(preload("res://game/match_choice.gd").new().can_choose_squad(), "対戦モードには出さない")


## どの物語も、話を並びの順にクリアすると、その物語の軍の駒・持ち物・コスト上限が増え、終わりには軍の駒が全部そろい、対戦のコスト上限を超える。
func test_every_campaign_unlocks_step_by_step_and_ends_with_every_kind() -> void:
	for campaign in Story.campaigns():
		if not Story.is_ready(campaign):
			continue
		var story := Story.new()
		story.choose_campaign(campaign)
		var budget: int = campaign.starting_budget
		var kinds := campaign.starting_kinds.duplicate()
		for episode: RefCounted in campaign.episodes:
			assert_eq(Story.unlocked_before(episode).budget, budget, "%s を初めて遊ぶときのコスト上限" % episode.id)
			assert_eq(Story.unlocked_before(episode).kinds, kinds, "%s を初めて遊ぶときの駒" % episode.id)
			story.clear(episode.id)
			budget += episode.budget_up
			kinds.append_array(episode.unlock_kinds)
		assert_eq(story.unlocked().budget, budget)
		assert_eq(kinds.size(), DeckRules.versus().roster(campaign.army).size(), "%s: 物語の終わりには、軍の駒が全部そろう" % campaign.title)
		assert_true(budget > DeckRules.versus().budget(campaign.army), "%s: 物語の終わりには、対戦のコスト上限を超える" % campaign.title)
		assert_true(campaign.starting_budget < DeckRules.versus().budget(campaign.army), "%s: 最初は、対戦のコスト上限より低い" % campaign.title)


func test_kinds_items_and_budget_are_unlocked_by_clearing_episodes() -> void:
	var story := Story.new()
	assert_eq(story.unlocked_kinds(), Story.military().starting_kinds, "最初は、最初から雇える駒だけ")
	assert_eq(story.unlocked().items, Story.military().starting_items)
	assert_eq(story.unlocked().budget, Story.military().starting_budget)
	var kinds := Story.military().starting_kinds.duplicate()
	var items := Story.military().starting_items.duplicate()
	var budget: int = Story.military().starting_budget
	for episode in Story.military().episodes:
		var before := Story.unlocked_before(episode)
		assert_eq(before.kinds, kinds, "%s を初めて遊ぶときの駒" % episode.id)
		assert_eq(before.items, items, "%s を初めて遊ぶときの持ち物" % episode.id)
		assert_eq(before.budget, budget, "%s を初めて遊ぶときのコストの上限" % episode.id)
		story.clear(episode.id)
		kinds.append_array(episode.unlock_kinds)
		items.append_array(episode.unlock_items)
		budget += episode.budget_up
		assert_eq(story.unlocked_kinds(), kinds)
		assert_eq(story.unlocked().items, items)
		assert_eq(story.unlocked().budget, budget)
	assert_true(budget > DeckRules.versus().budget(Story.military().army), "物語の終わりには、対戦の予算を超える")
	var reloaded := Story.new()
	reloaded.load_data(story.to_data())
	assert_eq(reloaded.unlocked_kinds(), kinds, "解放したものは記録に書かず、クリアした話から求め直す")
	assert_eq(reloaded.unlocked().budget, budget)
	assert_eq(story.to_data()["campaigns"].keys(), ["military"])
	assert_eq(story.to_data()["campaigns"]["military"].keys(), ["cleared"])


func test_story_rules_hire_only_unlocked_kinds_and_items_within_the_unlocked_budget() -> void:
	var start := Story.starting()
	var rules := Story.rules_of(start)
	assert_eq(rules.id, Story.military().rules_id)
	assert_ne(rules.id, DeckRules.VERSUS, "対戦用とストーリー用の部隊は、決まりの名前で分ける")
	assert_eq(rules.armies(), [Story.military().army] as Array[UnitKind.Army])
	assert_eq(rules.budget(Story.military().army), Story.military().starting_budget)
	assert_eq(rules.max_units, DeckRules.versus().max_units)
	assert_eq(rules.items(), Story.military().starting_items)
	for kind: UnitKind.Id in DeckRules.versus().roster(Story.military().army):
		assert_eq(rules.allows(Story.military().army, kind), Story.military().starting_kinds.has(kind), Names.kind(kind))
	var deck := Story.default_deck(start)
	assert_true(deck.is_valid(), str(deck.problems()))
	var everything := Story.starting()
	everything.kinds.assign([UnitKind.Id.COMMANDO, UnitKind.Id.MEDIC, UnitKind.Id.SNIPER, UnitKind.Id.SHIELD_TROOPER])
	assert_eq(Story.rules_of(everything).roster(Story.military().army), DeckRules.versus().roster(Story.military().army), "ロスターは役割の順")
	var booted := Deck.new(Story.military().army, rules)
	booted.add(UnitKind.Id.SNIPER).equip(Equipment.Id.SPEED_BOOTS)
	assert_eq(booted.problems(), [Deck.Problem.ITEM_NOT_ALLOWED] as Array[Deck.Problem], "まだ持たせられない持ち物は、出せない理由になる")


func test_story_rules_list_every_item_the_campaign_offers() -> void:
	for campaign: RefCounted in Story.campaigns():
		var offered := Story.offered_items(campaign)
		var shown := Story.rules_of(Story.starting(campaign)).shown_items()
		for item: Equipment.Id in Equipment.Id.values():
			assert_eq(shown.has(item), offered.has(item), "%s / %s" % [campaign.id, Names.item(item)])
		for episode: RefCounted in campaign.episodes:
			for item: Equipment.Id in episode.unlock_items:
				assert_true(offered.has(item), "解放する持ち物は、最初から並ぶ（未解放）")


func test_campaigns_unlock_only_their_own_army() -> void:
	for campaign in Story.campaigns():
		for episode: RefCounted in campaign.episodes:
			for kind: UnitKind.Id in episode.unlock_kinds:
				assert_eq(UnitKind.army(kind), campaign.army, "%s: ほかの軍の駒は解放しない" % episode.id)


func test_first_clear_tells_the_unlocked_kinds_at_the_end_of_the_talk() -> void:
	var episode: RefCounted = _episode(&"drill_medic")  # 衛生兵が増える
	var story := Story.new()
	var run := story.run_now(episode)
	run.advance()
	assert_eq(run.data()["lines"].size(), episode.before.size(), "前の会話には知らせを出さない")
	run.advance()
	assert_eq(run.data().human_deck.rules.id, Story.military().rules_id, "いま雇える駒で組んだ既定の編成")
	run.advance()
	var lines: Array = run.data()["lines"]
	assert_eq(lines.size(), episode.after.size() + Story.starting().news_of(episode).size())
	assert_eq(lines[-1]["side"], Story.NOTICE_SIDE)
	assert_true(lines[-1]["text"].contains(Names.kind(episode.unlock_kinds[0])), lines[-1]["text"])
	story.clear(episode.id)
	run = story.run_now(episode)
	for i in 3:
		run.advance()
	assert_eq(run.data()["lines"].size(), episode.after.size(), "クリア済みの話を遊び直しても、知らせは出さない")


func test_episode_deploy_cells_place_the_enemy_there() -> void:
	for episode in Story.military().episodes:
		var cells: Array = episode.deploy[Unit.Side.PLAYER2]
		if cells.is_empty():
			continue
		var battle := Story.first_battle(episode).make_setup(1).create_battle()
		var placed: Array[Vector2i] = []
		for unit in battle.units:
			if unit.side == Unit.Side.PLAYER2 and unit.kind != UnitKind.Id.KING:
				placed.append(unit.cell)
		var expected: Array[Vector2i] = []
		expected.assign(cells.slice(0, episode.enemy.size()))
		assert_eq(placed, expected, "%s の敵が、初期位置の順に置かれていない" % episode.id)


func test_the_same_map_is_reused_with_other_deploy_cells_enemies_squads_or_wins() -> void:
	var maps := {}
	for episode in Story.military().episodes:
		var key := [episode.map_title, str(episode.deploy), str(episode.enemy), str(episode.wins), episode.hold_turns, str(episode.squad)]
		assert_false(maps.has(key), "%s は、前の話と同じマップと初期位置" % episode.id)
		maps[key] = true


func test_episodes_open_one_by_one() -> void:
	var story := Story.new()
	assert_true(story.is_available(Story.military().episodes[0]))
	for i in range(1, Story.military().episodes.size()):
		assert_false(story.is_available(Story.military().episodes[i]), "前の話をクリアするまで遊べない")
	for i in Story.military().episodes.size():
		assert_eq(Story.number_of(Story.military().episodes[i]), i + 1)
		story.clear(Story.military().episodes[i].id)
		if i + 1 < Story.military().episodes.size():
			assert_true(story.is_available(Story.military().episodes[i + 1]))
	for episode in Story.military().episodes:
		assert_true(story.is_available(episode), "クリアした話は遊び直せる")


func test_story_decks_are_read_with_the_current_progress_and_never_mix_with_versus() -> void:
	var context := preload("res://game/app_context.gd").new()
	var deck := Deck.new(Story.military().army, context.story.deck_rules())
	deck.add(UnitKind.Id.SHIELD_TROOPER)
	deck.entries.append(DeckEntry.new(UnitKind.Id.COMMANDO))  # まだ解放していない駒（読み込んだ部隊と同じく、検査で分かる形）
	context.decks.add("先走った部隊", deck)
	var data: Dictionary = context.decks.to_data()
	assert_eq(data["decks"][0]["rules"], String(Story.military().rules_id))
	var again := preload("res://game/app_context.gd").new()
	again.decks.load_data(data)
	var saved: RefCounted = again.decks.items()[0]
	assert_eq(saved.deck.rules.id, Story.military().rules_id, "ストーリーの決まりとして読む（知らない決まりにしない）")
	assert_true(saved.load_issues.is_empty(), str(saved.load_issues))
	assert_false(saved.playable(), "まだ解放していない駒がいる")
	assert_true(again.decks.for_rules(DeckRules.VERSUS).is_empty(), "対戦用に混ざらない")
	assert_eq(again.decks.for_rules(Story.military().rules_id).size(), 1)
	again.story.clear(&"ridge_path")  # コマンドーが増える
	assert_true(saved.playable(), "進み具合が変わったら、決まりを引き直す: %s" % [saved.issues()])
	var plain := preload("res://game/deck_library.gd").new()
	plain.load_data(data)
	assert_false(plain.items()[0].load_issues.is_empty(), "ストーリーを知らない一覧では、知らない決まり")


func test_missing_optional_constants_read_as_their_defaults() -> void:
	var plain: RefCounted = Story.military().episodes[0]  # 1 話: hold_turns も wins も書いていない
	assert_eq(plain.hold_turns, 0)
	assert_true(plain.wins.is_empty())
	var setup := Story.first_battle(plain).make_setup(4)
	assert_eq(setup.scenario.win_conditions_of(Unit.Side.PLAYER1), Scenario.STANDARD_WIN_CONDITIONS)


func test_the_sortie_reads_the_same_scenario_as_the_battle() -> void:
	for episode: RefCounted in Story.military().episodes:
		var source := Story.first_battle(episode)
		var defined: Scenario = source.scenario()
		var made := source.make_setup(9).scenario
		assert_eq(defined.win_conditions, made.win_conditions, episode.id)
		assert_eq(defined.hold_turns, made.hold_turns, episode.id)
		assert_eq(defined.fixed_decks[Unit.Side.PLAYER2].entries.size(), episode.enemy.size(), episode.id)


func test_hold_turns_make_the_human_side_hold_out() -> void:
	var holding := 0
	for episode in Story.military().episodes:
		var battle := Story.first_battle(episode).make_setup(1).create_battle()
		if episode.hold_turns > 0:
			holding += 1
			assert_eq(battle.hold_turns, episode.hold_turns)
			assert_true(battle.wins_by(Unit.Side.PLAYER1, GameWonEvent.Reason.TURNS_HELD))
			assert_eq(battle.win_conditions[Unit.Side.PLAYER2], Scenario.STANDARD_WIN_CONDITIONS, "敵はいつもの勝ち方で攻める")
		else:
			assert_eq(battle.turns_left(), -1, "%s は守り切るの話でない" % episode.id)
			if episode.wins.is_empty():
				assert_eq(battle.win_conditions[Unit.Side.PLAYER1], Scenario.STANDARD_WIN_CONDITIONS)
	assert_true(holding > 0, "守り切るの話が無い")


func test_wins_replace_the_human_side_win_conditions() -> void:
	var routing := 0
	for episode in Story.military().episodes:
		if episode.wins.is_empty():
			continue
		var battle := Story.first_battle(episode).make_setup(1).create_battle()
		assert_eq(battle.win_conditions[Unit.Side.PLAYER1], episode.wins, "人の勝ち方は wins だけ")
		assert_eq(battle.win_conditions[Unit.Side.PLAYER2], Scenario.STANDARD_WIN_CONDITIONS, "敵はいつもの勝ち方で攻める")
		if episode.wins.has(GameWonEvent.Reason.ROUTED):
			routing += 1
			assert_false(battle.wins_by(Unit.Side.PLAYER1, GameWonEvent.Reason.KING_DEFEATED), "全滅の話は、敵の将を倒しても終わらない")
	assert_true(routing > 0, "全滅させる話が無い")


func test_a_campaign_without_episodes_is_not_ready_and_does_not_block_all_cleared() -> void:
	var story := Story.new()
	for campaign in Story.campaigns():
		assert_eq(Story.is_ready(campaign), not campaign.episodes.is_empty())
		for episode: RefCounted in campaign.episodes:
			assert_eq(Story.campaign_of(episode), campaign)
	assert_false(story.all_cleared())
	for campaign in Story.campaigns():
		story.choose_campaign(campaign)
		for episode: RefCounted in campaign.episodes:
			story.clear(episode.id)
	assert_true(story.all_cleared(), "準備中の物語は、全部クリアの邪魔をしない")


func test_news_tell_each_new_kind_item_and_the_new_budget() -> void:
	var episode := Episode.new()
	episode.unlock_kinds.assign([UnitKind.Id.COMMANDO, UnitKind.Id.SNIPER])
	episode.unlock_items.assign([Equipment.Id.SPEED_BOOTS, Equipment.Id.IRON_SHIELD])
	episode.budget_up = 3
	var given := Story.starting()
	given.items.assign([Equipment.Id.IRON_SHIELD])
	var news := given.news_of(episode)
	assert_eq(news, [
		{"text": "新しい兵種「コマンドー」を雇えるようになりました。", "kind": UnitKind.Id.COMMANDO},
		{"text": "新しい持ち物「スピードブーツ」を持たせられるようになりました。効果: 移動 +2", "item": Equipment.Id.SPEED_BOOTS},
		{"text": "コスト上限が %d に上がりました。" % (Story.military().starting_budget + 3)},
	] as Array[Dictionary], "もう使えるもの（スナイパー、アイアンシールド）は知らせない。駒・持ち物の知らせはアイコンを出す（kind、item）。持ち物は効果も")


## 軍略の解放（[unlock] の trait）: 知らせ（印つき）を出し、足したあとは選べる。まだ教わっていなければ、既定の編成は軍略を持たない。
func test_taught_traits_are_told_and_then_chosen() -> void:
	var episode := Episode.new()
	episode.unlock_traits.assign([Traits.Id.SUPPLY])
	var given := Story.starting()
	assert_eq(given.traits, [] as Array[int])
	assert_eq(Story.default_deck(given).trait_id, Traits.NONE, "教わる前は、軍略を持たない")
	var news := given.news_of(episode)
	assert_eq(news.size(), 1)
	assert_eq(news[0]["trait"], Traits.Id.SUPPLY)
	given.add(episode)
	assert_eq(given.traits, [Traits.Id.SUPPLY] as Array[int])
	assert_true(given.news_of(episode).is_empty(), "教わった軍略は、もう知らせない")
	assert_eq(StoryBattle.trait_of_deck(Story.default_deck(given)), Traits.Id.SUPPLY)


## MILITARY の物語の、id の話。
func _episode(id: StringName) -> RefCounted:
	for campaign: RefCounted in Story.campaigns():
		for episode: RefCounted in campaign.episodes:
			if episode.id == id:
				return episode
	assert_true(false, "話が無い: %s" % id)
	return null


func test_a_fixed_squad_episode_shows_only_its_squad_and_the_lesson_at_the_sortie() -> void:
	var context := preload("res://game/app_context.gd").new()
	context.story.choose_squad("9")
	context.run = context.story.run_now(_episode(&"drill_sniper"))
	context.scene = Story.SORTIE
	var sortie := preload("res://game/sortie_screen.gd").new()
	sortie.context = context
	var root := Node.new()
	root.add_child(sortie)
	sortie._ready()  # 木に入れずに組み立てる（root は SceneTree の外）
	assert_true(sortie.is_squad_fixed())
	assert_eq(sortie.option_ids(), ["fixed"] as Array[String], "選べるのは、この話の部隊だけ")
	assert_eq(sortie.chosen_deck().entries.size(), _episode(&"drill_sniper").squad.size())
	sortie.press_edit_decks()
	assert_eq(context.run.scene(), Story.SORTIE, "部隊が決まっている話は、編成へ寄り道しない")
	sortie.press_sortie()
	assert_eq(context.story.squad_id, "9", "決まっている部隊で出撃しても、覚えている部隊は変えない")
	root.free()


## 出撃準備の敵の部隊の見出しは、話の呼び名（「敵の部隊　ベルク連邦 教導隊」）。話のファイルに軍略を書いた陣営は、見出しの後ろに軍略の札。
func test_the_sortie_names_the_enemy_and_shows_episode_traits() -> void:
	var context := preload("res://game/app_context.gd").new()
	context.story.choose_campaign(Story.campaigns()[0])
	var episode: RefCounted = _episode(&"drill_sniper")
	var before: Array[int] = episode.traits.duplicate()
	episode.traits[1] = Traits.Id.FOCUS
	context.run = context.story.run_now(episode)
	context.scene = Story.SORTIE
	var sortie := preload("res://game/sortie_screen.gd").new()
	sortie.context = context
	var root := Node.new()
	root.add_child(sortie)
	sortie._ready()  # 木に入れずに組み立てる（root は SceneTree の外）
	assert_eq(sortie.battle_source.side_names()[1], "ベルク連邦 教導隊")
	assert_eq(sortie.battle_source.side_shorts()[1], "教導隊")
	assert_eq(sortie.trait_tag_text(1), Names.troop_trait(Traits.Id.FOCUS), "敵の軍略の札")
	assert_eq(sortie.trait_tag_text(0), "", "軍略の無い陣営は、札を見せない")
	episode.traits.assign(before)
	root.free()


## 始めのレベルが 1 でない駒（「分かれ道」のパラディンとソーサラー）は、出撃準備の部隊の並びにレベルが出る。
func test_the_sortie_shows_start_levels_above_one() -> void:
	var context := preload("res://game/app_context.gd").new()
	context.story.choose_campaign(Story.campaigns()[1])
	context.run = context.story.run_now(_episode(&"trial_evolution"))
	context.scene = Story.SORTIE
	var sortie := preload("res://game/sortie_screen.gd").new()
	sortie.context = context
	var root := Node.new()
	root.add_child(sortie)
	sortie._ready()  # 木に入れずに組み立てる（root は SceneTree の外）
	assert_eq(sortie.start_levels(Unit.Side.PLAYER1), [2, 2, 1])
	assert_eq(sortie.start_levels(Unit.Side.PLAYER2), [], "敵は始めのレベルを決めていない")
	sortie.choose(sortie.chosen_id())
	var tips := "\n".join(sortie.face_tips(Unit.Side.PLAYER1))
	assert_true(tips.contains("%s Lv2" % Names.kind(UnitKind.Id.PALADIN)), tips)
	assert_false(tips.contains("Lv1"), "レベル 1 の駒には出さない: %s" % tips)
	root.free()


## 出撃準備の勝利条件の欄は、対戦の始めの「対戦ルール」と同じ札（rule_card.gd）を、話の勝ちの条件の数だけ 1 列に並べる。
## 守り切る話は、守り切る・将の撃破・本陣の占拠の 3 枚。どの話も札は GOAL_CARDS 枚までで、右の欄の幅に収まる。
func test_the_sortie_shows_the_goals_as_rule_cards() -> void:
	var SortieScreen := preload("res://game/sortie_screen.gd")
	var context := preload("res://game/app_context.gd").new()
	context.run = context.story.run_now(_episode(&"ridge_hold"))
	context.scene = Story.SORTIE
	var sortie := SortieScreen.new()
	sortie.context = context
	await settle(sortie)
	var cards: Array = sortie.shown_goal_cards()
	assert_eq(cards.size(), 3)
	assert_true(cards[0].shown_text().begins_with(Text.t("battle.goal.name.turns_held")), cards[0].shown_text())
	assert_true(cards[1].shown_text().begins_with(Text.t("battle.goal.name.king_defeated")), cards[1].shown_text())
	for card: Control in cards:
		assert_eq(card.size, preload("res://game/rule_card.gd").SIZE)
		assert_true(card.fits(), card.shown_text())
	sortie.free()
	Names.set_boss("")  # 出撃準備が入れた話の中ボスの名前を戻す（ほかのテストの文に混ざらないように）
	for campaign in Story.campaigns():
		for episode: Episode in campaign.episodes:
			var scenario: Scenario = StoryBattle.scenario_of(episode)
			var conditions: Array = [scenario.win_conditions_of(Unit.Side.PLAYER1), scenario.win_conditions_of(Unit.Side.PLAYER2)]
			var shown := preload("res://game/battle_texts.gd").goal_cards(conditions, scenario.hold_turns, Unit.Side.PLAYER1)
			assert_true(shown.size() >= 1 and shown.size() <= SortieScreen.GOAL_CARDS, "%s: 勝利条件の札が %d 枚" % [episode.id, shown.size()])
