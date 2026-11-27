extends "res://tests/base_test.gd"
## ストーリーのクリアの記録（game/story.gd）: 書いて読み戻す、壊れた・古い記録を読む、話を足す前のセーブの続き、確かめ用の解放。
## 話の流れと話の対戦は tests/game/test_story.gd。

const Names := preload("res://game/names.gd")
const Story := preload("res://game/story.gd")
const SaveStore := preload("res://game/save_store.gd")

var _dir := ""


func _store() -> RefCounted:
	if _dir == "":
		_dir = "user://test_story_records_%d" % (Time.get_ticks_usec() + randi())
	return SaveStore.new(_dir)


## _store() で作ったディレクトリを消す（user:// に test_story_records_* を残さない）。_store() を使うテストの最後に呼ぶ。
func _cleanup() -> void:
	if _dir != "":
		_store().remove(Story.STORE_NAME)
		DirAccess.remove_absolute(_dir)


## MILITARY の物語の、id の話。
func _episode(id: StringName) -> RefCounted:
	for campaign: RefCounted in Story.campaigns():
		for episode: RefCounted in campaign.episodes:
			if episode.id == id:
				return episode
	assert_true(false, "話が無い: %s" % id)
	return null


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
	story.load_data({"cleared": [], "squad": 4}, 1)
	assert_eq(story.squad_id, "", "形の違う部隊の記録は、既定の編成として読む")
	_cleanup()


func test_broken_or_unknown_records_do_not_stop_loading() -> void:
	var story := Story.new()
	story.load_data({"cleared": "ridge_path"}, 1)
	assert_eq(story.cleared_count(), 0)
	story.load_data({"cleared": [3, "", "future_episode", "future_episode"]}, 1)
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


## 2 つ目の物語の記録が無い古いセーブ（版 1 の形、版 2 で MILITARY の物語だけ）からも、2 つ目の物語を頭から遊べる。
func test_an_old_save_without_the_second_campaign_starts_it_from_the_top() -> void:
	var other: RefCounted = Story.campaigns()[1]
	for saved: Array in [[1, {"cleared": ["ridge_path"], "squad": "5"}], [2, {"campaigns": {"military": {"cleared": ["ridge_path"]}}}]]:
		var story := Story.new()
		story.load_data(saved[1], saved[0])
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


func test_a_saved_squad_with_a_kind_the_campaign_cannot_hire_does_not_stop_loading() -> void:
	# パラディン（FANTASY の駒）を解放していたころに取っておいた、ストーリー用の部隊。
	var context := preload("res://game/app_context.gd").new()
	context.story.load_data({"cleared": ["ridge_path", "ridge_ambush"], "squad": "1"}, 1)
	context.decks.load_data({"next_id": 2, "decks": [{"id": "1", "name": "パラディン入り", "rules": "story", "army": "MILITARY",
			"units": [{"kind": "PALADIN", "equipment": ["IRON_SHIELD"]}, {"kind": "SNIPER", "equipment": []}]}]})
	var saved: RefCounted = context.decks.items()[0]
	assert_eq(saved.deck.rules.id, Story.military().rules_id, "部隊は読める（消さない）")
	assert_false(saved.playable(), "雇えない駒がいるので、出せない（理由つきで一覧に残る）")
	assert_true(saved.issues().size() > 0)
	var sortie := preload("res://game/sortie_screen.gd").new()
	sortie.context = context
	context.run = context.story.run_now(_episode(&"ridge_hold"))
	context.scene = Story.SORTIE
	var root := Node.new()
	root.add_child(sortie)
	sortie._ready()  # 木に入れずに組み立てる（root は SceneTree の外）
	assert_false(sortie.is_option_enabled("1"), "出撃準備では押せない")
	assert_eq(sortie.chosen_id(), "", "覚えていた部隊が出せなければ、既定の編成")
	root.free()
	Names.set_boss("")  # 出撃準備が入れた話の中ボスの名前を戻す（ほかのテストの文に混ざらないように）


func test_old_versus_save_files_still_load_as_versus() -> void:
	var context := preload("res://game/app_context.gd").new()
	context.decks.load_data({"next_id": 2, "decks": [{"id": "1", "name": "古い部隊", "rules": "versus", "army": "MILITARY",
			"units": [{"kind": "SNIPER", "equipment": []}]}]})
	var saved: RefCounted = context.decks.items()[0]
	assert_eq(saved.deck.rules, DeckRules.versus())
	assert_true(saved.playable())
	assert_true(context.decks.for_rules(Story.military().rules_id).is_empty())


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
	assert_eq(written["version"], Story.FORMAT_VERSION)
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


## 物語の途中に演習を足した（FANTASY の「分かれ道」）: 足す前の記録で、その演習より後ろの話をクリアしていた人は、
## 足した演習もクリアしたものとして読み、本編の続きをそのまま遊べる。演習の手前までの人は、足した演習から続ける。
func test_a_save_from_before_an_inserted_trial_keeps_its_place() -> void:
	var fantasy: RefCounted = Story.campaigns()[1]
	var before_trial := ["trial_first_steps", "trial_fireball", "trial_ward", "trial_shadow_step", "trial_eruption"]
	var story := Story.new()
	story.load_data({"campaigns": {"fantasy": {"cleared": before_trial + ["gorge_crossing"]}}})
	story.choose_campaign(fantasy)
	assert_true(story.is_cleared(&"trial_evolution"), "後ろの話をクリアしていれば、足した演習もクリアしたもの")
	assert_true(story.is_available(Story.episode_after(_any_episode(&"gorge_crossing"))), "本編の続きを遊べる")
	assert_eq(story.cleared_count(fantasy), before_trial.size() + 2)
	var midway := Story.new()
	midway.load_data({"campaigns": {"fantasy": {"cleared": before_trial}}})
	midway.choose_campaign(fantasy)
	assert_false(midway.is_cleared(&"trial_evolution"))
	assert_eq(midway.next_episode().id, &"trial_evolution", "演習の手前までの人は、足した演習から")
	assert_false(midway.is_available(_any_episode(&"gorge_crossing")))


## 本編の間に話を足した（FANTASY の「岩山の合流」）: 足す前の記録で、それより後ろの話をクリアしていた人は、
## 足した話もクリアしたものとして読み、続きをそのまま遊べる。足した話の手前までの人は、足した話から続ける。
func test_a_save_from_before_the_inserted_rejoin_keeps_its_place() -> void:
	var fantasy: RefCounted = Story.campaigns()[1]
	var trials := ["trial_first_steps", "trial_fireball", "trial_ward", "trial_shadow_step", "trial_eruption", "trial_evolution"]
	var story := Story.new()
	story.load_data({"campaigns": {"fantasy": {"cleared": trials + ["gorge_crossing", "ridge_siege"]}}})
	story.choose_campaign(fantasy)
	assert_true(story.is_cleared(&"gorge_rejoin"), "後ろの話をクリアしていれば、足した話もクリアしたもの")
	assert_true(story.is_available(_any_episode(&"barrow_vigil")), "続きを遊べる")
	assert_true(story.is_available(_any_episode(&"ridge_siege")), "クリアした後ろの話を遊び直せる")
	var midway := Story.new()
	midway.load_data({"campaigns": {"fantasy": {"cleared": trials + ["gorge_crossing"]}}})
	midway.choose_campaign(fantasy)
	assert_eq(midway.next_episode().id, &"gorge_rejoin", "足した話の手前までの人は、足した話から")
	assert_false(midway.is_available(_any_episode(&"ridge_siege")))


func _any_episode(id: StringName) -> RefCounted:
	for episode: RefCounted in Story.all_episodes():
		if episode.id == id:
			return episode
	assert_true(false, "話が無い: %s" % id)
	return null


## 確かめ用の解放（F5）: 開いている間は、どの話も遊べ、全部の解放を使える。記録には書かない。戻すと元の進み具合。
func test_opening_everything_for_checks_never_touches_the_record() -> void:
	var story := Story.new()
	story.store = _store()
	story.load_saved()
	var episodes: Array = Story.military().episodes
	story.clear(episodes[0].id)
	var saved: Dictionary = _store().read(Story.STORE_NAME)
	var real_kinds := story.unlocked_kinds().duplicate()
	story.open_all = true
	for episode: RefCounted in episodes:
		assert_true(story.is_available(episode), "開いても、%s を遊べない" % episode.title)
	var all := Story.starting(Story.military())
	for episode: RefCounted in episodes:
		all.add(episode)
	assert_eq(story.unlocked().kinds, all.kinds, "開いても、全部の駒を雇えない")
	assert_eq(story.unlocked().budget, all.budget, "開いても、コストの上限が全部の解放のぶん上がらない")
	# 開いている間に勝った話は、その起動のあいだだけクリアになる（記録は変わらない）。
	var last: RefCounted = episodes[-1]
	assert_true(story.run_now(last).size() > 0)
	story.clear(last.id)
	assert_true(story.is_cleared(last.id))
	assert_eq(_store().read(Story.STORE_NAME), saved, "開いている間のクリアを、記録に書いた")
	story.open_all = false
	assert_false(story.is_cleared(last.id), "戻しても、開いている間のクリアが残る")
	assert_false(story.is_available(episodes[2]), "戻しても、先の話が遊べる")
	assert_eq(story.unlocked_kinds(), real_kinds, "戻しても、解放が残る")
	# 開いて始めた先の話（上の run_now）に、戻してから勝っても、記録に書かない（一本道の読み方で、前の話が全部クリアになるので）。
	story.clear(last.id)
	assert_false(story.is_cleared(last.id), "戻してから勝った先の話を、クリアにした")
	assert_eq(_store().read(Story.STORE_NAME), saved, "戻してから勝った先の話を、記録に書いた")
	story.clear(episodes[1].id)
	assert_true(story.is_cleared(episodes[1].id), "記録どおりに遊べる次の話は、クリアを書く")
	# 別のスロット（最後の話の 1 つ前までクリアした記録）を読めば、そこでは最後の話に勝てばクリアを書く（開いて始めたことを持ち越さない）。
	var further := {"campaigns": {String(Story.military().id): {"cleared": [String(episodes[-2].id)], "squad": ""}}}
	story.load_data(further)
	assert_true(story.is_available(last), "読んだスロットで、最後の話が遊べない")
	story.clear(last.id)
	assert_true(story.is_cleared(last.id), "前のスロットで開いて始めた話を、別のスロットで勝ってもクリアにしない")
	_cleanup()


## 選択肢で選んだ答えは、物語ごとに覚えて、書いて読み戻せる（版 3 の欄 answers）。版 2 の記録は、答えが無いだけ。
func test_answers_are_kept_per_campaign_and_read_back() -> void:
	var story := Story.new()
	story.store = _store()
	story.choose_campaign(Story.military())
	assert_eq(story.answer_of(&"greeting"), "", "まだ選んでいない")
	story.choose_answer(&"greeting", &"warm")
	story.choose_answer(&"greeting", &"cool")
	story.choose_campaign(Story.campaigns()[1])
	assert_eq(story.answer_of(&"greeting"), "", "ほかの物語の答えは見えない")
	var written: Dictionary = _store().read(Story.STORE_NAME)
	assert_eq(written["version"], 3)
	assert_eq(written["data"]["campaigns"]["military"]["answers"], {"greeting": "cool"})
	var again := Story.new()
	again.store = _store()
	again.load_saved()
	again.choose_campaign(Story.military())
	assert_eq(again.answer_of(&"greeting"), "cool")
	again.load_data({"campaigns": {"military": {"cleared": ["ridge_path"], "answers": {"a": 3, "": "x", "ok": "yes"}}}}, 2)
	assert_eq([again.answer_of(&"a"), again.answer_of(&"ok")], ["", "yes"], "形の違う答えは読み飛ばす")
