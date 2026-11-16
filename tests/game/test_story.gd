extends "res://tests/base_test.gd"
## ストーリー（game/story.gd、game/story_battle.gd、game/story/）: 話の流れ、話の対戦、クリアの記録。

const Names := preload("res://game/names.gd")
const Story := preload("res://game/story.gd")
const Episode := preload("res://game/episode.gd")
const StoryBattle := preload("res://game/story_battle.gd")
const SaveStore := preload("res://game/save_store.gd")
const SceneFlow := preload("res://game/scene_flow.gd")
const Run := preload("res://game/run.gd")

var _dir := ""


func _store() -> RefCounted:
	if _dir == "":
		_dir = "user://test_story_%d" % (Time.get_ticks_usec() + randi())
	return SaveStore.new(_dir)


## _store() で作ったディレクトリを消す（user:// に test_story_* を残さない）。_store() を使うテストの最後に呼ぶ。
func _cleanup() -> void:
	if _dir != "":
		_store().remove(Story.STORE_NAME)
		DirAccess.remove_absolute(_dir)


func test_every_episode_has_a_unique_id_and_short_talks() -> void:
	# 話のファイルの形（キーの名前、駒、初期位置、勝ち方、きっかけ）は test_episode_data.gd が見る。
	var ids: Array[StringName] = []
	for episode in Story.military().episodes:
		assert_false(ids.has(episode.id), "話の id が重なっている: %s" % episode.id)
		ids.append(episode.id)
		for rows: Array in [episode.before, episode.after]:
			assert_between(rows.size(), 1, 6, "会話は短く（6 行まで）: %s" % episode.id)


func test_run_is_talk_sortie_battle_talk_then_the_episode_list() -> void:
	var episode: RefCounted = Story.military().episodes[0]
	var run := Story.run_of(episode, Story.default_deck(Story.starting()))
	assert_eq(run.scene(), &"talk")
	assert_eq(run.data()["title"], episode.title)
	assert_eq(run.data()["lines"].size(), episode.before.size())
	assert_eq(run.data()["lines"][0]["name"], episode.speakers[episode.before[0][0]])
	assert_eq(run.advance(), Story.SORTIE)
	assert_eq(run.data()["episode"], episode)
	var battle: StoryBattle = run.data()["battle"]
	assert_eq(run.advance(), &"battle")
	assert_true(run.data() == battle, "出撃準備は、対戦に渡すものの部隊を選び直す")
	assert_eq(run.advance(), &"talk")
	assert_eq(run.data()["lines"].size(), episode.after.size())
	assert_eq(run.advance(), Story.EPISODE_LIST, "話を終えたら、話の一覧へ戻る")
	for scene: StringName in [&"talk", Story.SORTIE, &"battle", Story.EPISODE_LIST, &"title"]:
		assert_true(SceneFlow.has(scene), "場面の表に無い: %s" % scene)


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
		assert_eq(placed[1], episode.enemy.size() + 1, "敵の全員（将を含む）が盤に置かれていない")
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
	assert_true(source.retries_on_enter(false), "負けたら Enter で同じ盤面でもう一度")
	assert_false(source.retries_on_enter(true))
	var versus := preload("res://game/match_choice.gd").new()
	assert_false(versus.retries_on_enter(false), "対戦モードの Enter はタイトルへのまま")


func test_a_win_records_the_clear() -> void:
	var episode: RefCounted = Story.military().episodes[0]
	var context := preload("res://game/app_context.gd").new()
	assert_false(context.story.is_cleared(episode.id))
	Story.first_battle(episode).record_win(context)
	assert_true(context.story.is_cleared(episode.id))
	assert_eq(context.story.cleared_count(), 1)


func test_clears_are_saved_and_read_back() -> void:
	var episode: RefCounted = Story.military().episodes[0]
	var story := Story.new()
	story.store = _store()
	story.load_saved()
	assert_eq(story.cleared_count(), 0, "記録が無ければ、何もクリアしていない")
	var changes := [0]
	story.changed.connect(func() -> void: changes[0] += 1)
	story.clear(episode.id)
	story.clear(episode.id)
	assert_eq(changes[0], 1, "2 回目は何も変わらない")
	var again := Story.new()
	again.store = _store()
	again.load_saved()
	assert_true(again.is_cleared(episode.id))
	assert_eq(again.cleared_count(), 1)
	assert_eq(_store().read(Story.STORE_NAME), {"version": Story.FORMAT_VERSION, "data": {"campaigns": {"military": {"cleared": [String(episode.id)]}}}})
	_cleanup()


func test_the_chosen_squad_is_saved_with_the_clears() -> void:
	var story := Story.new()
	story.store = _store()
	story.load_saved()
	assert_eq(story.squad_id, "", "記録が無ければ、既定の編成")
	story.choose_squad("3")
	var again := Story.new()
	again.store = _store()
	again.load_saved()
	assert_eq(again.squad_id, "3", "出撃準備で選んだ部隊は、次に起動しても選ばれている")
	assert_eq(_store().read(Story.STORE_NAME)["data"], {"campaigns": {"military": {"cleared": [], "squad": "3"}}})
	again.choose_squad("")
	assert_eq(_store().read(Story.STORE_NAME)["data"], {"campaigns": {}}, "既定の編成に戻したら、書かない")
	story.load_data({"cleared": [], "squad": 4})
	assert_eq(story.squad_id, "", "形の違う部隊の記録は、既定の編成として読む")
	_cleanup()


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


func test_broken_or_unknown_records_do_not_stop_loading() -> void:
	var story := Story.new()
	story.load_data({"cleared": "ridge_path"})
	assert_eq(story.cleared_count(), 0)
	story.load_data({"cleared": [3, "", "future_episode", "future_episode"]})
	assert_eq(story.cleared_count(), 0)
	assert_eq(story.to_data(), {"campaigns": {"military": {"cleared": ["future_episode"]}}}, "知らない話の記録は、消さずに残す")
	story.load_data({"campaigns": {"future": {"cleared": ["far"], "squad": "2"}, "": {"cleared": ["x"]}, "military": "broken"}})
	assert_eq(story.cleared_count(), 0)
	assert_eq(story.to_data(), {"campaigns": {"future": {"cleared": ["far"], "squad": "2"}}}, "知らない物語の記録は、消さずに残す")


func test_story_starts_from_the_first_episode_not_cleared() -> void:
	var story := Story.new()
	assert_eq(story.next_episode(), Story.military().episodes[0])
	for episode in Story.military().episodes:
		story.clear(episode.id)
	assert_eq(story.next_episode(), Story.military().episodes[0], "全部クリアしたら、最初の話をもう一度")


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


## 2 つ目の物語の記録が無い古いセーブ（版 1 の形、版 2 で MILITARY の物語だけ）からも、2 つ目の物語を頭から遊べる。
func test_an_old_save_without_the_second_campaign_starts_it_from_the_top() -> void:
	var other: RefCounted = Story.campaigns()[1]
	for data: Dictionary in [{"cleared": ["ridge_path"], "squad": "5"}, {"campaigns": {"military": {"cleared": ["ridge_path"]}}}]:
		var story := Story.new()
		story.load_data(data)
		assert_true(story.is_cleared(&"ridge_path"), "MILITARY の物語の記録は、そのまま読む")
		story.choose_campaign(other)
		assert_eq(story.cleared_count(), 0)
		assert_eq(story.squad_id, "")
		assert_eq(story.unlocked_kinds(), other.starting_kinds)
		assert_true(story.is_available(other.episodes[0]), "2 つ目の物語の最初の話を遊べる")
		for later: RefCounted in other.episodes.slice(1):
			assert_false(story.is_available(later), "%s: 前の話をクリアするまで遊べない" % later.id)
		assert_false(story.all_cleared())
		assert_false((story.to_data()["campaigns"] as Dictionary).has(String(other.id)), "遊んでいない物語は書かない")


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


func test_campaigns_unlock_only_their_own_army() -> void:
	for campaign in Story.campaigns():
		for episode: RefCounted in campaign.episodes:
			for kind: UnitKind.Id in episode.unlock_kinds:
				assert_eq(UnitKind.army(kind), campaign.army, "%s: ほかの軍の駒は解放しない" % episode.id)


func test_a_saved_squad_with_a_kind_the_campaign_cannot_hire_does_not_stop_loading() -> void:
	# パラディン（FANTASY の駒）を解放していたころに取っておいた、ストーリー用の部隊。
	var context := preload("res://game/app_context.gd").new()
	context.story.load_data({"cleared": ["ridge_path", "ridge_ambush"], "squad": "1"})
	context.decks.load_data({"next_id": 2, "decks": [{"id": "1", "name": "パラディン入り", "rules": "story", "army": "MILITARY",
			"units": [{"kind": "PALADIN", "equipment": ["IRON_SHIELD"]}, {"kind": "SNIPER", "equipment": []}]}]})
	var saved: RefCounted = context.decks.items()[0]
	assert_eq(saved.deck.rules.id, Story.military().rules_id, "部隊は読める（消さない）")
	assert_false(saved.playable(), "雇えない駒がいるので、出せない（理由つきで一覧に残る）")
	assert_true(saved.issues().size() > 0)
	var sortie := preload("res://game/sortie_screen.gd").new()
	sortie.context = context
	context.run = context.story.run_now(_episode(&"ridge_hold"))
	context.run.advance()  # 出撃準備
	context.scene = Story.SORTIE
	var root := Node.new()
	root.add_child(sortie)
	sortie._ready()  # 木に入れずに組み立てる（root は SceneTree の外）
	assert_false(sortie.is_option_enabled("1"), "出撃準備では押せない")
	assert_eq(sortie.chosen_id(), "", "覚えていた部隊が出せなければ、既定の編成")
	root.free()


func test_first_clear_tells_the_unlocked_kinds_at_the_end_of_the_talk() -> void:
	var episode: RefCounted = _episode(&"drill_medic")  # 衛生兵が増える
	var story := Story.new()
	var run := story.run_now(episode)
	assert_eq(run.data()["lines"].size(), episode.before.size(), "前の会話には知らせを出さない")
	run.advance()
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


func test_old_versus_save_files_still_load_as_versus() -> void:
	var context := preload("res://game/app_context.gd").new()
	context.decks.load_data({"next_id": 2, "decks": [{"id": "1", "name": "古い部隊", "rules": "versus", "army": "MILITARY",
			"units": [{"kind": "SNIPER", "equipment": []}]}]})
	var saved: RefCounted = context.decks.items()[0]
	assert_eq(saved.deck.rules, DeckRules.versus())
	assert_true(saved.playable())
	assert_true(context.decks.for_rules(Story.military().rules_id).is_empty())


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


func test_an_old_single_story_record_is_read_as_the_military_campaign() -> void:
	var story := Story.new()
	story.store = _store()
	_store().write(Story.STORE_NAME, 1, {"cleared": ["ridge_path", "ridge_ambush"], "squad": "5"})
	story.load_saved()
	story.choose_campaign(Story.military())
	assert_true(story.is_cleared(&"ridge_path") and story.is_cleared(&"ridge_ambush"), "物語が 1 つだったころの記録は、MILITARY の物語の記録")
	assert_eq(story.cleared_count(), Story.military().episodes.find(_episode(&"ridge_ambush")) + 1, "前の演習もクリアしたものとして読む")
	assert_eq(story.squad_id, "5")
	story.clear(&"ridge_hold")
	var written: Dictionary = _store().read(Story.STORE_NAME)
	assert_eq(written["version"], 2)
	assert_eq(written["data"]["campaigns"]["military"]["squad"], "5", "書くときは、物語ごとの形")
	assert_true((written["data"]["campaigns"]["military"]["cleared"] as Array).has("ridge_hold"))
	_cleanup()


func test_progress_is_kept_per_campaign() -> void:
	var story := Story.new()
	var other: RefCounted = Story.campaigns()[1]
	assert_ne(other, Story.military())
	story.clear(Story.military().episodes[0].id)
	story.choose_squad("7")
	story.choose_campaign(other)
	assert_eq(story.campaign, other)
	assert_eq(story.cleared_count(), 0, "ほかの物語のクリアは数えない")
	assert_false(story.is_cleared(Story.military().episodes[0].id))
	assert_eq(story.squad_id, "", "選んだ部隊も物語ごと")
	assert_eq(story.unlocked_kinds(), other.starting_kinds)
	assert_eq(story.deck_rules().id, other.rules_id)
	assert_eq(story.deck_rules().armies(), [other.army] as Array[UnitKind.Army])
	assert_eq(story.rules_by_id(Story.military().rules_id).roster(Story.military().army).size(), Story.military().starting_kinds.size() + Story.military().episodes[0].unlock_kinds.size(),
			"取っておいた部隊は、選んでいない物語の決まりでも、その物語の進み具合で引ける")
	assert_true(story.rules_by_id(DeckRules.VERSUS) == null)
	story.run_now(Story.military().episodes[1])
	assert_eq(story.campaign, Story.military(), "話を始めると、その話の物語になる")
	assert_eq(story.squad_id, "7")


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
		{"text": "新しい駒「コマンドー」を雇えるようになりました。", "kind": UnitKind.Id.COMMANDO},
		{"text": "新しい持ち物「スピードブーツ」を持たせられるようになりました。"},
		{"text": "コスト上限が %d に上がりました。" % (Story.military().starting_budget + 3)},
	] as Array[Dictionary], "もう使えるもの（スナイパー、アイアンシールド）は知らせない。駒の知らせはアイコンを出す（kind）")



## MILITARY の物語の、id の話。
func _episode(id: StringName) -> RefCounted:
	for episode: RefCounted in Story.military().episodes:
		if episode.id == id:
			return episode
	assert_true(false, "話が無い: %s" % id)
	return null


func test_a_fixed_squad_episode_shows_only_its_squad_and_the_lesson_at_the_sortie() -> void:
	var context := preload("res://game/app_context.gd").new()
	context.story.choose_squad("9")
	context.run = context.story.run_now(_episode(&"drill_sniper"))
	context.run.advance()  # 出撃準備
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


func test_a_save_from_before_the_tutorial_keeps_its_unlocks_and_its_place() -> void:
	# 演習（頭の 6 話）が入る前の記録: 本編の 1・2 話目だけをクリアしていた。
	var story := Story.new()
	story.load_data({"campaigns": {"military": {"cleared": ["ridge_path", "ridge_ambush"]}}})
	for episode: RefCounted in Story.military().episodes:
		if episode.squad_deck() != null:
			assert_true(story.is_cleared(episode.id), "%s: 先の話をクリアしていれば、前の話もクリアしたもの" % episode.id)
	assert_true(story.unlocked_kinds().has(UnitKind.Id.MEDIC), "演習で増える衛生兵を失わない")
	assert_true(story.unlocked().items.has(Equipment.Id.IRON_SHIELD), "演習で増える盾を失わない")
	assert_true(story.is_available(_episode(&"ridge_hold")), "本編の続きを遊べる")
	var fresh := Story.new()
	fresh.load_data({"campaigns": {"military": {"cleared": ["drill_first_steps"]}}})
	assert_eq(fresh.cleared_count(), 1, "クリアした話より後ろは、クリアにしない")
