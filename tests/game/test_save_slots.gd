extends "res://tests/base_test.gd"
## セーブのスロット（game/save_slots.gd）: スロットの読み書き、オートセーブの区切り、前の置き方からの移し替え、
## 壊れた・新しい版のファイル、コピーと削除、対戦用とストーリー用の部隊の分け方。

const SaveSlots := preload("res://game/save_slots.gd")
const SaveStore := preload("res://game/save_store.gd")
const AppContext := preload("res://game/app_context.gd")
const Story := preload("res://game/story.gd")
const DeckLibrary := preload("res://game/deck_library.gd")

var _dir := ""
var _clock := 1000


func _store() -> SaveStore:
	if _dir == "":
		_dir = "user://test_slots_%d" % randi()
	return SaveStore.new(_dir)


## 遊ぶときと同じに組んだ AppContext（取っておく先は検査のディレクトリ）。起動の順も app.gd と同じ。
func _context() -> AppContext:
	var context := AppContext.new()
	context.slots.store = _store()
	context.slots.now = func() -> int:
		_clock += 10
		return _clock
	context.slots.migrate_old(func(rules: String) -> bool: return AppContext.is_story_rules(StringName(rules)))
	context.slots.open_latest()
	context.decks.store = _store()
	context.reload_slot()
	return context


func _write_raw(name: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(_store().dir)
	var file := FileAccess.open(_store().path_of(name), FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _raw(name: String) -> String:
	return FileAccess.get_file_as_string(_store().path_of(name))


func _story_deck() -> Deck:
	var deck := Story.default_deck(Story.starting(Story.military()))
	return deck


func _versus_deck() -> Deck:
	var deck := Deck.new(UnitKind.Army.MILITARY)
	deck.add(UnitKind.Id.SNIPER)
	return deck


func _cleanup() -> void:
	if _dir == "":
		return
	var dir := DirAccess.open(_dir)
	if dir != null:
		for file in dir.get_files():
			dir.remove(file)
	DirAccess.remove_absolute(_dir)


# --- スロットの選び方 ---


func test_without_any_file_every_slot_is_empty_and_nothing_is_written() -> void:
	var context := _context()
	for number in range(1, SaveSlots.COUNT + 1):
		assert_eq(context.slots.info(number)["state"], SaveSlots.EMPTY)
	assert_eq(context.slots.current, 1)
	assert_false(context.slots.is_started())
	assert_false(_store().exists(SaveSlots.store_name(1)), "選ぶまでファイルは作らない")
	_cleanup()


func test_saving_versus_squads_does_not_start_a_slot() -> void:
	var context := _context()
	context.decks.add("対戦の部隊", _versus_deck())
	var copy := context.decks.duplicate_deck(context.decks.items()[0].id)
	context.decks.remove(copy.id)
	assert_eq(context.slots.info(1)["state"], SaveSlots.EMPTY, "対戦用の部隊を取っておいただけでは、スロットを作らない")
	assert_false(_store().exists(SaveSlots.store_name(1)))
	assert_eq(_store().read(DeckLibrary.STORE_NAME)["data"]["next_id"], 3, "次に付ける id の番号は、対戦用のファイルが持つ")
	_cleanup()


func test_starting_an_empty_slot_writes_it_and_opening_again_reads_it() -> void:
	var context := _context()
	assert_true(context.use_slot(2))
	assert_eq(context.slots.info(2)["state"], SaveSlots.READY, "はじめからで、すぐ書く")
	context.story.clear(Story.military().episodes[0].id)
	context.slots.flush()
	var again := _context()
	assert_eq(again.slots.current, 2, "起動したら、最後に保存したスロットを開く")
	assert_true(again.story.is_cleared(Story.military().episodes[0].id))
	_cleanup()


func test_story_progress_is_written_only_at_save_points() -> void:
	var context := _context()
	context.use_slot(1)
	var before := _raw(SaveSlots.store_name(1))
	context.story.clear(Story.military().episodes[0].id)
	context.story.choose_squad("7")
	assert_eq(_raw(SaveSlots.store_name(1)), before, "クリアしただけでは書かない（区切りで書く）")
	assert_true(context.slots.has_unsaved())
	var marks := [0]
	context.slots.saved.connect(func() -> void: marks[0] += 1)
	context.slots.flush()
	assert_eq(marks[0], 1, "書いたら、保存の印を出す")
	assert_false(context.slots.has_unsaved())
	# 閉じた瞬間のもの（書く前の変わり）は残らない: 書いたあとにクリアして、そのまま読み直す。
	context.story.clear(Story.military().episodes[1].id)
	var reopened := _context()
	assert_true(reopened.story.is_cleared(Story.military().episodes[0].id))
	assert_false(reopened.story.is_cleared(Story.military().episodes[1].id), "最後に保存した所までが残る")
	_cleanup()


func test_choosing_the_current_slot_again_keeps_what_is_not_written_yet() -> void:
	var context := _context()
	context.use_slot(1)
	context.story.clear(Story.military().episodes[0].id)
	assert_true(context.use_slot(1))
	assert_true(context.story.is_cleared(Story.military().episodes[0].id), "選び直しても、覚えていた進み具合を捨てない")
	assert_false(context.slots.has_unsaved(), "選び直した所で書く")
	_cleanup()


func test_slots_keep_their_own_progress_and_story_squads_but_share_versus_squads() -> void:
	var context := _context()
	context.use_slot(1)
	context.story.clear(Story.military().episodes[0].id)
	var story_squad := context.decks.add("一番の部隊", _story_deck())
	var versus_squad := context.decks.add("対戦の部隊", _versus_deck())
	assert_true(story_squad.in_slot and not versus_squad.in_slot)
	context.use_slot(2)
	assert_false(context.story.is_cleared(Story.military().episodes[0].id), "ほかのスロットの進み具合は持ち越さない")
	assert_eq(context.decks.for_rules(Story.military().rules_id).size(), 0, "ストーリー用の部隊はスロットごと")
	assert_eq(context.decks.for_rules(DeckRules.VERSUS).size(), 1, "対戦用の部隊は、どのスロットでも同じ")
	var other := context.decks.add("二番の部隊", _story_deck())
	assert_ne(other.id, story_squad.id, "スロットを替えても、部隊の id は重ならない")
	context.use_slot(1)
	assert_eq(context.decks.for_rules(Story.military().rules_id).map(func(item: DeckLibrary.Saved) -> String: return item.name), ["一番の部隊"])
	assert_true(context.story.is_cleared(Story.military().episodes[0].id), "クリアのあと部隊を組んだ所（編成完了）で書いてある")
	var versus_file: Dictionary = _store().read(DeckLibrary.STORE_NAME)
	assert_eq((versus_file["data"]["decks"] as Array).map(func(record: Dictionary) -> String: return record["name"]), ["対戦の部隊"],
		"user://decks.json には対戦用の部隊だけ")
	_cleanup()


func test_the_latest_slot_is_opened_at_start() -> void:
	var context := _context()
	context.use_slot(3)
	context.use_slot(1)
	context.use_slot(3)
	context.story.clear(Story.military().episodes[0].id)
	context.slots.flush()
	assert_eq(_context().slots.current, 3)
	_cleanup()


# --- コピーと削除 ---


func test_copy_and_remove() -> void:
	var context := _context()
	context.use_slot(1)
	context.story.clear(Story.military().episodes[0].id)
	context.slots.flush()
	assert_true(context.slots.copy(1, 2))
	assert_eq(context.slots.info(2)["sections"], context.slots.info(1)["sections"], "コピーは中身が同じ")
	assert_false(context.slots.copy(3, 1), "空きからはコピーしない")
	context.slots.remove(1)
	assert_eq(context.slots.info(1)["state"], SaveSlots.EMPTY)
	context.reload_slot()
	assert_false(context.story.is_cleared(Story.military().episodes[0].id), "いまのスロットを消したら、いまの進み具合も空になる")
	assert_true(context.use_slot(2))
	assert_true(context.story.is_cleared(Story.military().episodes[0].id), "コピーした先は残る")
	_cleanup()


func test_copy_into_the_current_slot_becomes_the_current_progress() -> void:
	var context := _context()
	context.use_slot(2)
	context.story.clear(Story.military().episodes[0].id)
	context.slots.flush()
	context.use_slot(1)
	assert_true(context.slots.copy(2, 1))
	context.reload_slot()
	assert_true(context.story.is_cleared(Story.military().episodes[0].id))
	_cleanup()


# --- 壊れたファイルと版 ---


func test_a_broken_slot_is_not_read_not_chosen_and_not_overwritten() -> void:
	_write_raw(SaveSlots.store_name(1), "{ これは JSON でない")
	var context := _context()
	assert_eq(context.slots.info(1)["state"], SaveSlots.BROKEN)
	assert_false(context.use_slot(1), "壊れたスロットは選べない")
	assert_ne(context.slots.current, 1, "起動したとき、壊れたスロットを開かない")
	context.use_slot(context.slots.current)
	context.story.clear(Story.military().episodes[0].id)
	context.slots.flush()
	assert_eq(_raw(SaveSlots.store_name(1)), "{ これは JSON でない", "壊れたファイルは、消すまでそのまま")
	context.slots.remove(1)
	assert_eq(context.slots.info(1)["state"], SaveSlots.EMPTY, "壊れたスロットも消せる")
	_cleanup()


func test_a_slot_of_a_newer_version_is_kept_as_it_is() -> void:
	_write_raw(SaveSlots.store_name(2), JSON.stringify({"name": "slot_2", "version": SaveSlots.FORMAT_VERSION + 1, "data": {"sections": {}}}))
	var context := _context()
	assert_eq(context.slots.info(2)["state"], SaveSlots.NEWER)
	assert_false(context.use_slot(2))
	assert_false(context.slots.copy(2, 3), "新しい版のスロットからはコピーしない")
	_cleanup()


## 新しい exe が欄を足して版を上げたまとまりを、古い exe（いまの exe）で開いて保存しても、知らない欄と版を落とさない（save_format.gd）。
## 版を上げた新しい exe も、それをそのまま読める（スロットごと読み直して、足した欄が残っている）。
func test_a_newer_section_keeps_its_unknown_fields_and_version_when_saved_again() -> void:
	var episodes: Array = Story.military().episodes
	var first := String(episodes[0].id)
	var story_data := {"campaigns": {"military": {"cleared": [first], "choices": {first: "左"}}}, "hero": "ノア"}
	var deck_data := {"next_id": 2, "shelf": "上の段", "decks": [{"id": "1", "name": "新しい部隊", "rules": "story", "army": "MILITARY",
		"units": [{"kind": "SNIPER", "equipment": []}], "badge": "gold"}]}
	_store().write(SaveSlots.store_name(1), SaveSlots.FORMAT_VERSION, {"saved_at": 5, "played_seconds": 0, "sections": {
		"story": {"version": Story.FORMAT_VERSION + 1, "data": story_data},
		"decks": {"version": DeckLibrary.FORMAT_VERSION + 1, "data": deck_data},
		"later": {"version": 1, "data": {"x": "y"}}}})
	var context := _context()
	assert_eq(context.slots.current, 1)
	assert_true(context.story.is_cleared(episodes[0].id), "知っている欄は読む")
	assert_eq(context.decks.items()[0].name, "新しい部隊")
	context.story.clear(episodes[1].id)
	context.decks.rename(context.decks.items()[0].id, "名前を替えた")
	context.slots.flush()
	var sections: Dictionary = _store().read(SaveSlots.store_name(1))["data"]["sections"]
	assert_eq(sections["story"]["version"], Story.FORMAT_VERSION + 1, "話の記録の版を下げない")
	assert_eq(sections["story"]["data"]["hero"], "ノア", "話の記録の知らない欄を落とさない")
	assert_eq(sections["story"]["data"]["campaigns"]["military"]["choices"], {first: "左"}, "物語ごとの記録の知らない欄を落とさない")
	assert_true((sections["story"]["data"]["campaigns"]["military"]["cleared"] as Array).has(String(episodes[1].id)), "知っている欄は書く")
	assert_eq(sections["decks"]["version"], DeckLibrary.FORMAT_VERSION + 1, "部隊の版を下げない")
	assert_eq(sections["decks"]["data"]["shelf"], "上の段", "部隊の一覧の知らない欄を落とさない")
	assert_eq(sections["decks"]["data"]["decks"][0]["badge"], "gold", "部隊 1 つの知らない欄を落とさない")
	assert_eq(sections["decks"]["data"]["decks"][0]["name"], "名前を替えた")
	assert_eq(sections["later"]["data"], {"x": "y"}, "知らないまとまりも落とさない")
	_cleanup()


## 古い版のまとまり（物語が 1 つだったころの話の記録。版 1）は、版の番号で読み替え、書くときはいまの版と形にする。
func test_an_old_story_section_is_read_by_its_version() -> void:
	var first := String(Story.military().episodes[0].id)
	_store().write(SaveSlots.store_name(1), SaveSlots.FORMAT_VERSION, {"saved_at": 5, "played_seconds": 0, "sections": {
		"story": {"version": 1, "data": {"cleared": [first], "squad": "5"}}}})
	var context := _context()
	assert_true(context.story.is_cleared(Story.military().episodes[0].id))
	assert_eq(context.story.squad_id, "5")
	assert_eq(Story.summary_of({"cleared": [first]}, 1)["cleared"], 1, "スロットの札も、版で読み替える")
	context.story.clear(Story.military().episodes[1].id)
	context.slots.flush()
	var section: Dictionary = _store().read(SaveSlots.store_name(1))["data"]["sections"]["story"]
	assert_eq(section["version"], Story.FORMAT_VERSION)
	assert_eq(section["data"]["campaigns"]["military"]["squad"], "5")
	_cleanup()


func test_odd_values_in_a_slot_do_not_stop_loading() -> void:
	_write_raw(SaveSlots.store_name(1), JSON.stringify({"name": "slot_1", "version": 1, "data": {"sections": {"story": "x", "decks": {"version": "a"}}, "saved_at": "?", "played_seconds": -5}}))
	var context := _context()
	var info := context.slots.info(1)
	assert_eq(info["state"], SaveSlots.READY)
	assert_eq(info["saved_at"], 0)
	assert_eq(info["played_seconds"], 0)
	assert_true(context.use_slot(1))
	assert_eq(context.story.cleared_count(), 0, "読めないまとまりは、無いものとして読む")
	_write_raw(SaveSlots.store_name(3), JSON.stringify({"name": "slot_3", "version": 1, "data": {"sections": []}}))
	assert_eq(context.slots.info(3)["state"], SaveSlots.BROKEN, "形の違うスロットは、壊れたものとして扱う")
	_cleanup()


# --- 前の置き方からの移し替え ---


func test_the_old_story_and_story_squads_move_into_the_first_slot_without_losing_the_old_files() -> void:
	var episode: RefCounted = Story.military().episodes[0]
	_store().write(Story.STORE_NAME, Story.FORMAT_VERSION, {"campaigns": {"military": {"cleared": [String(episode.id)], "squad": "2"}}})
	var old_decks := {"next_id": 3, "decks": [
		{"id": "1", "name": "対戦の部隊", "rules": "versus", "army": "MILITARY", "units": [{"kind": "SNIPER", "equipment": []}]},
		{"id": "2", "name": "物語の部隊", "rules": String(Story.military().rules_id), "army": "MILITARY", "units": []},
	]}
	_store().write(DeckLibrary.STORE_NAME, DeckLibrary.FORMAT_VERSION, old_decks)
	var context := _context()
	assert_eq(context.slots.current, 1)
	assert_true(context.story.is_cleared(episode.id), "前の進み具合は 1 番のスロットへ")
	assert_eq(context.story.squad_id, "2")
	assert_eq(context.decks.for_rules(Story.military().rules_id).size(), 1, "前のストーリー用の部隊も 1 番のスロットへ")
	assert_eq(context.decks.find("2").name, "物語の部隊", "部隊の id は変えない（出撃準備で選んだ部隊のまま）")
	assert_eq(context.decks.for_rules(DeckRules.VERSUS).size(), 1)
	assert_false(_store().exists(Story.STORE_NAME), "前のファイルは名前を変えて残す")
	assert_true(_store().exists(Story.STORE_NAME + SaveSlots.BEFORE_SLOTS))
	assert_eq((_store().read(DeckLibrary.STORE_NAME + SaveSlots.BEFORE_SLOTS)["data"]["decks"] as Array).size(), 2, "前の部隊のファイルの写しを残す")
	assert_eq((_store().read(DeckLibrary.STORE_NAME)["data"]["decks"] as Array).size(), 1, "user://decks.json には対戦用の部隊だけが残る")
	# 2 度目の起動では移し替えない。1 番を消しても、前のファイルから戻らない。
	context.slots.remove(1)
	var again := _context()
	assert_eq(again.slots.info(1)["state"], SaveSlots.EMPTY)
	assert_eq(again.decks.for_rules(DeckRules.VERSUS).size(), 1)
	_cleanup()


func test_nothing_moves_when_there_was_nothing_or_only_a_broken_story_file() -> void:
	_write_raw(Story.STORE_NAME, "壊れている")
	var context := _context()
	assert_eq(context.slots.info(1)["state"], SaveSlots.EMPTY)
	assert_eq(_raw(Story.STORE_NAME), "壊れている", "壊れた前のファイルは、そのまま")
	_cleanup()


func test_story_squads_left_in_the_versus_file_move_into_the_current_slot() -> void:
	_store().write(SaveSlots.store_name(1), SaveSlots.FORMAT_VERSION, {"saved_at": 5, "played_seconds": 0, "sections": {}})
	_store().write(DeckLibrary.STORE_NAME, DeckLibrary.FORMAT_VERSION, {"next_id": 2, "decks": [
		{"id": "1", "name": "物語の部隊", "rules": String(Story.military().rules_id), "army": "MILITARY", "units": []}]})
	var context := _context()
	assert_eq(context.decks.for_rules(Story.military().rules_id).size(), 1)
	assert_eq((_store().read(DeckLibrary.STORE_NAME)["data"]["decks"] as Array).size(), 0, "対戦用のファイルから外す")
	var slot_decks: Dictionary = context.slots.info(1)["sections"][DeckLibrary.STORE_NAME]
	assert_eq((slot_decks["data"]["decks"] as Array).size(), 1, "いまのスロットへ書く")
	_cleanup()


# --- 遊んだ時間 ---


func test_play_time_is_kept_and_copied() -> void:
	var context := _context()
	context.use_slot(1)
	context.slots._played = 3725.0
	context.slots.flush()
	assert_eq(context.slots.info(1)["played_seconds"], 3725)
	context.slots.copy(1, 2)
	assert_eq(context.slots.info(2)["played_seconds"], 3725)
	assert_eq(preload("res://game/slot_screen.gd").played_text(3725), "プレイ時間 1:02")
	_cleanup()


func test_the_slot_card_tells_the_campaign_progress_and_the_last_cleared_episode() -> void:
	var SlotScreen := preload("res://game/slot_screen.gd")
	var campaign: RefCounted = Story.military()
	var data := {"campaign": String(campaign.id), "campaigns": {String(campaign.id): {"cleared": [String(campaign.episodes[0].id), String(campaign.episodes[1].id)]}}}
	var lines: PackedStringArray = SlotScreen.card_lines({"state": SaveSlots.READY, "saved_at": 0, "played_seconds": 60,
		"sections": {"story": {"version": Story.FORMAT_VERSION, "data": data}}}, 2)
	assert_eq(lines[0], "データ 2")
	assert_eq(lines[1], campaign.title)
	assert_eq(lines[2], "2 / %d 話クリア" % campaign.episodes.size())
	assert_eq(lines[3], "第 2 話「%s」までクリア" % campaign.episodes[1].title)
	assert_eq(lines[5], "プレイ時間 0:01")
	assert_eq(lines[6], "つづきから")
	assert_eq(SlotScreen.card_lines({"state": SaveSlots.EMPTY}, 1), PackedStringArray(["データ 1", "空き", "はじめから"]))
	assert_eq(SlotScreen.card_lines({"state": SaveSlots.BROKEN}, 3)[1], "読み込めないデータ")
