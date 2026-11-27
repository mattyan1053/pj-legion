extends "res://tests/base_test.gd"
## 取っておく部隊（game/deck_library.gd）: 一覧の操作、ファイルの読み書き、壊れた・古いファイル。

const DeckLibrary := preload("res://game/deck_library.gd")
const SaveStore := preload("res://game/save_store.gd")

const MILITARY := UnitKind.Army.MILITARY
const FANTASY := UnitKind.Army.FANTASY

var _dir := ""


func _store() -> SaveStore:
	if _dir == "":
		_dir = "user://test_decks_%d" % randi()
	return SaveStore.new(_dir)


func _library() -> DeckLibrary:
	var library := DeckLibrary.new()
	library.store = _store()
	return library


func _deck() -> Deck:
	var deck := Deck.new(MILITARY)
	deck.add(UnitKind.Id.SHIELD_TROOPER).equip(Equipment.Id.IRON_SHIELD)
	deck.add(UnitKind.Id.SNIPER)
	deck.add(UnitKind.Id.MEDIC).equip(Equipment.Id.SPEED_BOOTS)
	return deck


func _write_raw(text: String) -> void:
	var store := _store()
	DirAccess.make_dir_recursive_absolute(store.dir)
	var file := FileAccess.open(store.path_of(DeckLibrary.STORE_NAME), FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _loaded() -> DeckLibrary:
	var library := _library()
	library.load_saved()
	return library


func _cleanup() -> void:
	if _dir != "":
		_store().remove(DeckLibrary.STORE_NAME)
		DirAccess.remove_absolute(_dir)


# --- 一覧の操作 ---


func test_add_keeps_a_copy_and_names_it() -> void:
	var library := DeckLibrary.new()
	var deck := _deck()
	var item := library.add("", deck)
	assert_eq(item.name, "部隊 1", "空の名前なら「部隊 N」")
	deck.add(UnitKind.Id.COMMANDO)
	assert_eq(item.deck.entries.size(), 3, "渡した編成を変えても、取っておいたものは変わらない")
	assert_true(item.playable())
	assert_eq(library.default_name(), "部隊 2")


func test_duplicate_rename_and_remove() -> void:
	var library := DeckLibrary.new()
	var first := library.add("先鋒", _deck())
	var second := library.add("本隊", _deck())
	var twin := library.duplicate_deck(first.id)
	assert_eq(twin.name, "先鋒 の写し")
	assert_ne(twin.id, first.id)
	var ids: Array[String] = []
	for item in library.items():
		ids.append(item.id)
	assert_eq(ids, [first.id, twin.id, second.id] as Array[String], "写しは元のすぐ後ろ")
	twin.deck.entries[0].equip(Equipment.Id.SPEED_BOOTS)
	assert_eq(first.deck.entries[0].equipment.size(), 1, "写しを変えても元は変わらない")
	assert_true(library.rename(second.id, "  主力\n  "))
	assert_eq(library.find(second.id).name, "主力", "前後の空白と改行は落とす")
	assert_true(library.rename(second.id, "   "))
	assert_eq(library.find(second.id).name, "主力", "空の名前には変えない")
	library.rename(second.id, "あ".repeat(40))
	assert_eq(library.find(second.id).name.length(), DeckLibrary.MAX_NAME_LENGTH)
	assert_true(library.remove(first.id))
	assert_false(library.remove(first.id))
	assert_eq(library.size(), 2)


func test_replace_clears_load_issues() -> void:
	var library := DeckLibrary.new()
	library.load_data({"decks": [{"id": "1", "name": "古い", "rules": "versus", "army": "MILITARY", "units": [{"kind": "LASER_TANK"}]}]})
	var item := library.find("1")
	assert_false(item.playable())
	assert_true(library.replace("1", "古い", _deck()))
	assert_true(library.find("1").playable())


func test_for_rules_filters_by_army() -> void:
	var library := DeckLibrary.new()
	library.add("A", _deck())
	var fantasy := Deck.new(FANTASY)
	fantasy.add(UnitKind.Id.PALADIN)
	library.add("B", fantasy)
	assert_eq(library.for_rules(DeckRules.VERSUS).size(), 2)
	assert_eq(library.for_rules(DeckRules.VERSUS, FANTASY)[0].name, "B")
	assert_true(library.for_rules(&"story").is_empty())


# --- 読み書き ---


func test_written_decks_read_back_the_same() -> void:
	var library := _library()
	library.add("先鋒", _deck())
	var fantasy := Deck.new(FANTASY)
	fantasy.add(UnitKind.Id.SPELLBLADE).equip(Equipment.Id.SPEED_BOOTS)
	fantasy.entries[0].equip(Equipment.Id.SPEED_BOOTS)
	library.add("速攻", fantasy)
	var loaded := _loaded()
	assert_eq(loaded.size(), 2)
	var items := loaded.items()
	assert_eq(items[0].name, "先鋒")
	assert_eq(items[0].deck.rules, DeckRules.versus())
	assert_eq(items[0].deck.army, MILITARY)
	assert_eq(items[0].deck.entries.size(), 3)
	assert_eq(items[0].deck.entries[2].kind, UnitKind.Id.MEDIC)
	assert_eq(items[0].deck.entries[2].equipment, [Equipment.Id.SPEED_BOOTS] as Array[Equipment.Id])
	assert_eq(items[1].deck.entries[0].equipment.size(), 2)
	assert_true(items[0].playable() and items[1].playable())
	# 新しく足す id は、読んだものと重ならない。
	var added := loaded.add("三番", _deck())
	assert_false(added.id in [items[0].id, items[1].id])
	_cleanup()


func test_file_names_kinds_by_name() -> void:
	var record := DeckLibrary.deck_to_record(_deck())
	assert_eq(record["rules"], "versus")
	assert_eq(record["army"], "MILITARY")
	assert_eq(record["units"][0], {"kind": "SHIELD_TROOPER", "equipment": ["IRON_SHIELD"]})


func test_missing_or_broken_file_gives_an_empty_list() -> void:
	assert_eq(_loaded().size(), 0, "ファイルが無い")
	_write_raw("{ これは JSON ではない")
	assert_eq(_loaded().size(), 0, "JSON でない")
	_write_raw('{"name": "decks", "version": 1, "data": {"decks": "なにか"}}')
	assert_eq(_loaded().size(), 0, "decks が列でない")
	_cleanup()


func test_odd_records_are_kept_with_reasons() -> void:
	_write_raw(JSON.stringify({"name": "decks", "version": 1, "data": {"decks": [
		"部隊でない",
		{"id": "4", "name": "知らない駒", "rules": "versus", "army": "MILITARY",
			"units": [{"kind": "SNIPER", "equipment": ["JETPACK"]}, {"kind": "LASER_TANK", "equipment": []}, 7]},
		{"id": "4", "name": "id が重なる", "rules": "story_3", "army": "FANTASY", "units": [{"kind": "PALADIN"}]},
		{"name": 12, "army": "ROBOTS"},
	]}}))
	var library := _loaded()
	assert_eq(library.size(), 3, "部隊の形でないものだけ読み飛ばす")
	var items := library.items()
	assert_eq(items[0].deck.entries.size(), 1, "知らない駒は外して読む")
	assert_eq(items[0].deck.entries[0].equipment.size(), 0, "知らない装備は外して読む")
	assert_false(items[0].playable())
	assert_eq(items[0].issues().size(), 3, str(items[0].issues()))
	assert_ne(items[1].id, items[0].id, "重なった id は付け直す")
	assert_true(items[1].issues()[0].contains("story_3"), "知らない決まり")
	assert_eq(items[2].name, "名前の無い部隊")
	assert_eq(items[2].deck.army, UnitKind.Army.NONE)
	assert_false(items[2].playable())
	_cleanup()


func test_load_issues_survive_rewriting_the_file() -> void:
	# 知らない駒を外して読んだ部隊は、ほかの部隊を変えて書き直しても、組み直して取っておくまで出せないまま。
	_write_raw(JSON.stringify({"name": "decks", "version": 1, "data": {"decks": [
		{"id": "1", "name": "古い", "rules": "versus", "army": "MILITARY", "units": [{"kind": "SNIPER"}, {"kind": "LASER_TANK"}]},
		{"id": "2", "name": "ふつう", "rules": "versus", "army": "MILITARY", "units": [{"kind": "SNIPER"}]},
	]}}))
	var library := _loaded()
	library.rename("2", "改名")
	library.duplicate_deck("1")
	var reloaded := _loaded()
	assert_false(reloaded.find("1").playable(), "書き直しで出せるようになった")
	assert_eq(reloaded.find("1").load_issues.size(), 1, "理由が重ならない")
	assert_false(reloaded.items()[1].playable(), "写しも出せないまま")
	reloaded.replace("1", "古い", reloaded.find("1").deck)
	assert_true(_loaded().find("1").playable(), "組み直して取っておけば出せる")
	_cleanup()


func test_decks_the_rules_no_longer_allow_stay_with_reasons() -> void:
	# 予算を超えた・雇えない駒がいる・多すぎる（決まりが変わった、手で書き換えた）部隊も、一覧に残る。
	var units: Array = []
	for i in 7:
		units.append({"kind": "SHIELD_TROOPER", "equipment": ["IRON_SHIELD"]})
	units.append({"kind": "PALADIN", "equipment": ["IRON_SHIELD", "IRON_SHIELD", "IRON_SHIELD", "SPEED_BOOTS"]})
	_write_raw(JSON.stringify({"name": "decks", "version": 1, "data": {"decks": [
		{"id": "1", "name": "盛りすぎ", "rules": "versus", "army": "MILITARY", "units": units},
	]}}))
	var item := _loaded().items()[0]
	assert_eq(item.deck.entries.size(), 8)
	assert_eq(item.deck.problems(), [
		Deck.Problem.TOO_MANY_UNITS, Deck.Problem.OVER_BUDGET, Deck.Problem.TOO_MUCH_EQUIPMENT, Deck.Problem.NOT_IN_ROSTER,
	] as Array[Deck.Problem])
	assert_eq(item.issues().size(), 4)
	assert_false(item.playable())
	_cleanup()


func test_newer_version_is_read_as_far_as_possible() -> void:
	_write_raw(JSON.stringify({"name": "decks", "version": 9, "data": {"decks": [
		{"id": "1", "name": "未来", "rules": "versus", "army": "FANTASY", "units": [{"kind": "PRIEST", "equipment": []}], "icon": "star"},
	]}}))
	var library := _loaded()
	assert_eq(library.size(), 1)
	assert_true(library.items()[0].playable())
	_cleanup()


func test_without_a_store_nothing_is_written() -> void:
	var library := DeckLibrary.new()
	library.add("A", _deck())
	assert_false(library.save())
	library.load_saved()
	assert_eq(library.size(), 0, "書く先が無ければ、読んでも空")


## 初期位置は部隊では決めない。前の版が書いたかもしれない配置の欄（駒の位置、並べ方）は、読めて、無視する。
func test_placement_fields_from_older_files_are_ignored() -> void:
	var library := _library()
	library.load_data({"decks": [{"id": "1", "name": "配置つき", "rules": "versus", "army": "MILITARY", "placement": [[0, 1], [1, 1]],
		"units": [{"kind": "SNIPER", "equipment": [], "slot": [0, 1]}, {"kind": "MEDIC", "equipment": [], "row": "back"}]}]})
	assert_eq(library.size(), 1)
	assert_true(library.items()[0].playable(), "%s" % [library.items()[0].issues()])
	assert_eq(library.items()[0].deck.entries.size(), 2)
	assert_false(JSON.stringify(library.to_data()).contains("placement"), "書き直すときは、配置の欄を残さない")


func test_trait_and_oaths_read_back_the_same() -> void:
	var library := _library()
	var knights := Deck.new(FANTASY)
	var a := knights.add(UnitKind.Id.PALADIN)
	var b := knights.add(UnitKind.Id.SPELLBLADE)
	knights.add(UnitKind.Id.PRIEST)
	knights.trait_id = Traits.Id.OATH
	assert_true(knights.bind(a, b))
	library.add("誓いの隊", knights)
	var ranks := _deck()
	ranks.trait_id = Traits.Id.RANKS
	library.add("隊列の隊", ranks)
	var items := _loaded().items()
	assert_eq(items[0].deck.trait_id, Traits.Id.OATH)
	assert_eq(items[0].deck.oath_pairs(), [Vector2i(0, 1)] as Array[Vector2i])
	assert_eq(items[1].deck.trait_id, Traits.Id.RANKS)
	_cleanup()


## 軍略の前の形（組み方の頃。軍略の鍵が無く、騎士領の部隊に誓いの組だけがある）と、読めない軍略の鍵。
## どれも落ちずに読め、軍略は軍の既定になり、出撃できる。誓いの組は残る（誓いを選べば、また効く）。
func test_decks_from_before_troop_traits_load_with_the_army_default() -> void:
	var library := _library()
	var units := [{"kind": "PALADIN", "equipment": []}, {"kind": "SPELLBLADE", "equipment": []}, {"kind": "PRIEST", "equipment": []}]
	library.load_data({"decks": [
		{"id": "1", "name": "前の誓い", "rules": "versus", "army": "FANTASY", "units": units, "oaths": [[0, 1]]},
		{"id": "2", "name": "組み方の鍵", "rules": "versus", "army": "FANTASY", "units": units, "trait": "formation"},
		{"id": "3", "name": "よその軍の軍略", "rules": "versus", "army": "MILITARY", "units": [{"kind": "SNIPER", "equipment": []}], "trait": "vengeance"},
		{"id": "4", "name": "数の軍略", "rules": "versus", "army": "MILITARY", "units": [{"kind": "SNIPER", "equipment": []}], "trait": 3, "oaths": "broken"},
		{"id": "5", "name": "単騎（差し替えた軍略）", "rules": "versus", "army": "FANTASY", "units": units, "trait": "lone"},
	]})
	var items := library.items()
	assert_eq(items.size(), 5)
	assert_eq(items[0].deck.trait_id, Traits.Id.VENGEANCE)
	assert_eq(items[0].deck.oath_pairs(), [Vector2i(0, 1)] as Array[Vector2i], "誓いの組は残る")
	assert_eq(items[1].deck.trait_id, Traits.Id.VENGEANCE)
	assert_eq(items[2].deck.trait_id, Traits.Id.FOCUS)
	assert_eq(items[3].deck.trait_id, Traits.Id.FOCUS)
	assert_true(items[3].deck.oaths.is_empty())
	assert_eq(items[4].deck.trait_id, Traits.Id.VENGEANCE, "単騎を選んでいた部隊は、軍の既定")
	for item in items:
		assert_true(item.playable(), "%s: %s" % [item.name, item.issues()])
