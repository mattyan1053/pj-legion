extends "res://tests/base_test.gd"
## ストーリー（game/story.gd、game/story_battle.gd、game/episodes/）: 話の流れ、話の対戦、クリアの記録。

const Story := preload("res://game/story.gd")
const StoryBattle := preload("res://game/story_battle.gd")
const SaveStore := preload("res://game/save_store.gd")
const SceneFlow := preload("res://game/scene_flow.gd")
const StageLook := preload("res://game/stage_look.gd")
const Run := preload("res://game/run.gd")

var _dir := ""


func _store() -> RefCounted:
	if _dir == "":
		_dir = "user://test_story_%d" % (Time.get_ticks_usec() + randi())
	return SaveStore.new(_dir)


func test_every_episode_has_an_id_a_title_and_short_talks() -> void:
	var ids: Array[StringName] = []
	for episode in Story.EPISODES:
		assert_false(ids.has(episode.ID), "話の id が重なっている: %s" % episode.ID)
		ids.append(episode.ID)
		assert_ne(episode.TITLE, "")
		assert_true(StageLook.THEMES.has(episode.LOOK), "知らない見た目: %s" % episode.LOOK)
		for rows: Array in [episode.BEFORE, episode.AFTER]:
			assert_between(rows.size(), 1, 6, "会話は短く（6 行まで）: %s" % episode.ID)
			for row: Array in rows:
				assert_true(row[0] in [0, 1], "話し手は 0 か 1")
				assert_ne(row[1], "")


func test_run_is_talk_then_battle_then_talk_then_title() -> void:
	var episode: Script = Story.EPISODES[0]
	var run := Story.run_of(episode, Story.default_deck(Story.STARTING_KINDS))
	assert_eq(run.scene(), &"talk")
	assert_eq(run.data()["title"], episode.TITLE)
	assert_eq(run.data()["lines"].size(), episode.BEFORE.size())
	assert_eq(run.data()["lines"][0]["name"], episode.SPEAKERS[episode.BEFORE[0][0]])
	assert_eq(run.advance(), &"battle")
	assert_true(run.data() is StoryBattle)
	assert_eq(run.advance(), &"talk")
	assert_eq(run.data()["lines"].size(), episode.AFTER.size())
	assert_eq(run.advance(), &"title")
	for scene: StringName in [&"talk", &"battle", &"title"]:
		assert_true(SceneFlow.has(scene), "場面の表に無い: %s" % scene)


func test_episode_battle_is_the_hand_map_against_a_fixed_cpu_enemy() -> void:
	for episode in Story.EPISODES:
		var source := Story.first_battle(episode)
		var setup := source.make_setup(7)
		assert_true(setup.is_valid(), "%s の対戦を始められない: %s" % [episode.ID, setup.problems()])
		assert_eq(setup.controllers, [MatchSetup.Controller.HUMAN, MatchSetup.Controller.CPU] as Array[MatchSetup.Controller])
		assert_eq(source.cpu_side(), Unit.Side.PLAYER2)
		assert_true(setup.scenario.is_fixed(Unit.Side.PLAYER2))
		assert_false(setup.scenario.is_fixed(Unit.Side.PLAYER1))
		assert_eq(setup.army_of(Unit.Side.PLAYER1), Story.ARMY)
		assert_eq(setup.army_of(Unit.Side.PLAYER2), episode.ENEMY_ARMY)
		assert_eq(setup.deck_of(Unit.Side.PLAYER1), source.human_deck, "人は渡された部隊")
		assert_eq(setup.deck_of(Unit.Side.PLAYER1).rules.id, Story.RULES_ID, "初めて遊ぶときの、ストーリーの既定の編成")
		assert_eq(setup.scenario.title, episode.MAP.TITLE)
		var battle := setup.create_battle()
		var placed := [0, 0]
		for unit in battle.units:
			if unit.side != Unit.Side.NEUTRAL:
				placed[unit.side] += 1
		assert_eq(placed[1], episode.ENEMY.size() + 1, "敵の全員（将を含む）が盤に置かれていない")
		assert_eq(battle.board.size, episode.MAP.map().make_board().size)
		assert_eq(source.look(), episode.LOOK)


func test_episode_battle_offers_nothing_to_choose_again() -> void:
	var source := Story.first_battle(Story.EPISODES[0])
	assert_false(source.can_switch_opponent())
	assert_false(source.can_open_setup())
	assert_true(source.stages().is_empty())
	assert_true(source.copy() is StoryBattle)
	assert_eq(source.copy().episode, source.episode)
	assert_eq(source.copy().human_deck, source.human_deck, "やり直しも同じ部隊")


func test_only_a_win_shows_the_next_button() -> void:
	var source := Story.first_battle(Story.EPISODES[0])
	assert_true(source.can_continue(true))
	assert_false(source.can_continue(false))
	var versus := preload("res://game/match_choice.gd").new()
	assert_false(versus.can_continue(true), "対戦モードには「次へ」が無い")


func test_a_win_records_the_clear() -> void:
	var episode: Script = Story.EPISODES[0]
	var context := preload("res://game/app_context.gd").new()
	assert_false(context.story.is_cleared(episode.ID))
	Story.first_battle(episode).record_win(context)
	assert_true(context.story.is_cleared(episode.ID))
	assert_eq(context.story.cleared_count(), 1)


func test_clears_are_saved_and_read_back() -> void:
	var episode: Script = Story.EPISODES[0]
	var story := Story.new()
	story.store = _store()
	story.load_saved()
	assert_eq(story.cleared_count(), 0, "記録が無ければ、何もクリアしていない")
	var changes := [0]
	story.changed.connect(func() -> void: changes[0] += 1)
	story.clear(episode.ID)
	story.clear(episode.ID)
	assert_eq(changes[0], 1, "2 回目は何も変わらない")
	var again := Story.new()
	again.store = _store()
	again.load_saved()
	assert_true(again.is_cleared(episode.ID))
	assert_true(again.all_cleared())
	assert_eq(_store().read(Story.STORE_NAME)["data"], {"cleared": [String(episode.ID)]})


func test_broken_or_unknown_records_do_not_stop_loading() -> void:
	var story := Story.new()
	story.load_data({"cleared": "ridge_path"})
	assert_eq(story.cleared_count(), 0)
	story.load_data({"cleared": [3, "", "future_episode", "future_episode"]})
	assert_eq(story.cleared_count(), 0)
	assert_eq(story.to_data(), {"cleared": ["future_episode"]}, "知らない話の記録は、消さずに残す")


func test_story_starts_from_the_first_episode_not_cleared() -> void:
	var story := Story.new()
	assert_eq(story.next_episode(), Story.EPISODES[0])
	for episode in Story.EPISODES:
		story.clear(episode.ID)
	assert_eq(story.next_episode(), Story.EPISODES[0], "全部クリアしたら、最初の話をもう一度")


func test_kinds_are_unlocked_by_clearing_episodes() -> void:
	var story := Story.new()
	assert_eq(story.unlocked_kinds(), Story.STARTING_KINDS, "最初は、最初から雇える駒だけ")
	var expected := Story.STARTING_KINDS.duplicate()
	for episode in Story.EPISODES:
		assert_eq(Story.kinds_before(episode), expected, "%s を初めて遊ぶときの駒" % episode.ID)
		for kind: UnitKind.Id in episode.UNLOCKS:
			assert_false(expected.has(kind), "%s は、もう雇える駒を解放する" % episode.ID)
		story.clear(episode.ID)
		expected.append_array(episode.UNLOCKS)
		assert_eq(story.unlocked_kinds(), expected)
	var reloaded := Story.new()
	reloaded.load_data(story.to_data())
	assert_eq(reloaded.unlocked_kinds(), expected, "解放した駒は記録に書かず、クリアした話から求め直す")
	assert_eq(story.to_data().keys(), ["cleared"])


func test_story_rules_hire_only_unlocked_kinds_on_the_versus_budget() -> void:
	var rules := Story.rules_of(Story.STARTING_KINDS)
	assert_eq(rules.id, Story.RULES_ID)
	assert_ne(rules.id, DeckRules.VERSUS, "対戦用とストーリー用の部隊は、決まりの名前で分ける")
	assert_eq(rules.armies(), [Story.ARMY] as Array[UnitKind.Army])
	assert_eq(rules.budget(Story.ARMY), DeckRules.versus().budget(Story.ARMY))
	assert_eq(rules.max_units, DeckRules.versus().max_units)
	for kind: UnitKind.Id in DeckRules.versus().roster(Story.ARMY):
		assert_eq(rules.allows(Story.ARMY, kind), Story.STARTING_KINDS.has(kind), UnitKind.display_name(kind))
	var deck := Story.default_deck(Story.STARTING_KINDS)
	assert_true(deck.is_valid(), str(deck.problems()))
	var everything := Story.rules_of([UnitKind.Id.COMMANDO, UnitKind.Id.MEDIC, UnitKind.Id.SNIPER, UnitKind.Id.SHIELD_TROOPER])
	assert_eq(everything.roster(Story.ARMY), DeckRules.versus().roster(Story.ARMY), "ロスターは役割の順")


func test_first_clear_tells_the_unlocked_kinds_at_the_end_of_the_talk() -> void:
	var episode: Script = Story.EPISODES[0]
	var story := Story.new()
	var run := story.run_now(episode)
	assert_eq(run.data()["lines"].size(), episode.BEFORE.size(), "前の会話には知らせを出さない")
	run.advance()
	assert_eq(run.data().human_deck.rules.id, Story.RULES_ID, "いま雇える駒で組んだ既定の編成")
	run.advance()
	var lines: Array = run.data()["lines"]
	assert_eq(lines.size(), episode.AFTER.size() + episode.UNLOCKS.size())
	assert_eq(lines[-1]["side"], Story.NOTICE_SIDE)
	assert_true(lines[-1]["text"].contains(UnitKind.display_name(episode.UNLOCKS[0])), lines[-1]["text"])
	story.clear(episode.ID)
	run = story.run_now(episode)
	run.advance()
	run.advance()
	assert_eq(run.data()["lines"].size(), episode.AFTER.size(), "クリア済みの話を遊び直しても、知らせは出さない")
