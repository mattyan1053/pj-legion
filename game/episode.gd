extends "res://game/episode/episode_talks.gd"
## ストーリーの話 1 つ（docs/story.md の「話のファイル」）。game/story/<物語>/ の 1 ファイルを読んだもの。ノードに依存しない。
##
## 読むときに、書き間違い（知らないキー、無い駒・装備・マップ・見た目・曲、置けないマス、勝ち方の矛盾、会話の話し手、
## きっかけの値、文の長さ）を「ファイル:行: 何がおかしいか」で problems に貯める。problems が空でない話は遊べない（story.gd が外す）。
## 読む側（画面、道具、テスト）は、ここの値をそのまま使う（無い欄の値も、ここで決めてある）。
##
## ここは、読む入口と、節 [episode]・[unlock]。話のファイルの節ごとのファイル（game/episode/）を、次の順に継ぐ:
## episode_base.gd（調整値・読んだ値・部隊と曲）→ episode_sides.gd（[ally]・[enemy]）→ episode_talks.gd（[cast]・[before]・[after]・[lost]・[cues]）→ ここ。


## ファイル file_path を読む。
static func load_file(file_path: String) -> RefCounted:
	return read(StoryFile.open(file_path))


## 文 text を、ファイル file_path の中身として読む（テストは、わざと壊した文を渡す）。
static func parse(text: String, file_path := "probe.txt") -> RefCounted:
	return read(StoryFile.parse(text, file_path))


static func read(file: RefCounted) -> RefCounted:
	var episode: RefCounted = new()
	episode._read(file)
	return episode


func _read(file: RefCounted) -> void:
	path = file.path
	id = StringName(path.get_file().get_basename())
	file.check_sections(SECTIONS)
	_read_episode(file)
	_read_unlock(file)
	_read_side(file, "ally", 0)
	_read_side(file, "enemy", 1)
	_check_traits(file)
	_read_cast(file)
	_read_talks(file)
	_read_cues(file)
	_check_kingless(file)
	_check_deploy(file)
	problems.append_array(file.problems)


func _read_episode(file: RefCounted) -> void:
	if not file.has("episode"):
		file.problem(1, "[episode] の節が無い")
		return
	var at: int = file.line_of("episode")
	var values: Dictionary = file.values("episode", ["title", "map", "look", "music", "before_music", "after_music", "climax_music", "victory_mood", "lesson", "hold_turns", "wins", "signs", "boss"])
	for key: String in ["title", "map"]:
		if not values.has(key):
			file.problem(at, "[episode] に「%s」が無い" % key)
	if values.has("title"):
		title = values["title"][0]["value"]
		if title == "":
			file.problem(values["title"][0]["line"], "title が空")
	if values.has("map"):
		var entry: Dictionary = values["map"][0]
		var found: Dictionary = Maps.find(entry["value"])
		if found.is_empty():
			file.problem(entry["line"], "知らないマップ「%s」（%s）" % [entry["value"], Maps.DIR])
		elif not (found["problems"] as PackedStringArray).is_empty():
			file.problem(entry["line"], "マップ「%s」に書き間違いがある: %s" % [entry["value"], " / ".join(found["problems"])])
		else:
			map = found["map"]
			map_title = found["title"]
			boss = found.get("boss", "")
			look = found["look"]  # 見た目はマップが決める。話が look を書けば、その話だけ替える
	if values.has("look"):
		var entry: Dictionary = values["look"][0]
		look = StringName(entry["value"])
		if not StageLook.THEMES.has(look):
			file.problem(entry["line"], "知らない見た目「%s」（書けるのは %s）" % [look, ", ".join(StageLook.THEMES.keys())])
	for key: String in ["music", "before_music", "after_music", "climax_music"]:
		if values.has(key):
			var entry: Dictionary = values[key][0]
			var track := StringName(entry["value"])
			if not SoundCatalog.has_music(track):
				file.problem(entry["line"], "知らない曲「%s」（sound_catalog.gd の MUSIC）" % track)
			else:
				set(key, track)
	if values.has("victory_mood"):
		var entry: Dictionary = values["victory_mood"][0]
		var mood := StringName(entry["value"])
		if not SoundCatalog.MOODS.has(mood):
			file.problem(entry["line"], "知らない調子「%s」（書けるのは %s）" % [mood, ", ".join(SoundCatalog.MOODS)])
		else:
			victory_mood = mood
	# 前の会話に対戦の曲を書くなら、その話の対戦の曲（会話から対戦へ、同じ曲のままつなぐ。違う対戦の曲へ替わると、続けて鳴る戦いの曲が 2 つになる）。
	if SoundCatalog.is_battle_music(before_music) and before_music != battle_music():
		file.problem(values["before_music"][0]["line"], "before_music の対戦の曲「%s」が、この話の対戦の曲「%s」と違う" % [before_music, battle_music()])
	if values.has("lesson"):
		var entry: Dictionary = values["lesson"][0]
		lesson = entry["value"]
		if lesson == "" or lesson.length() > LESSON_MAX_CHARS:
			file.problem(entry["line"], "lesson は 1 から %d 字（いま %d 字）" % [LESSON_MAX_CHARS, lesson.length()])
	if values.has("hold_turns"):
		var entry: Dictionary = values["hold_turns"][0]
		hold_turns = file.integer(entry)
		if hold_turns < 1:
			file.problem(entry["line"], "hold_turns は 1 以上")
			hold_turns = 0
	if values.has("wins"):
		var entry: Dictionary = values["wins"][0]
		for word: String in (entry["value"] as String).split(",", false):
			var reason := StoryFile.enum_value(GameWonEvent.Reason, word)
			if reason < 0:
				file.problem(entry["line"], "知らない勝ち方「%s」（書けるのは %s）" % [word.strip_edges(), StoryFile.enum_words(GameWonEvent.Reason)])
			elif not wins.has(reason):
				wins.append(reason as GameWonEvent.Reason)
		if wins.is_empty():
			file.problem(entry["line"], "勝ち方が空（人が勝てない）")
		# 勝ち方の列は、いつもの勝ち方を置き換える。守り切るのに turns_held が無いと、守り切っても勝てない。
		if (hold_turns > 0) != wins.has(GameWonEvent.Reason.TURNS_HELD):
			file.problem(entry["line"], "hold_turns と、wins の turns_held は、両方書くか両方書かない")
	if values.has("boss"):
		var entry: Dictionary = values["boss"][0]
		boss = entry["value"]
		if boss == "" or boss.length() > Maps.BOSS_NAME_MAX:
			file.problem(entry["line"], "boss は 1 から %d 字" % Maps.BOSS_NAME_MAX)
			boss = ""
	if values.has("signs"):
		var entry: Dictionary = values["signs"][0]
		var wrong: Array[String] = []
		signs = Seam.from_keys((entry["value"] as String).split(",", false), wrong)
		for word in wrong:
			file.problem(entry["line"], "知らないか、並べられない縫い目の様子「%s」（書けるのは %s。重ねない。%s は並べない）" % [
				word, ", ".join(Seam.KEYS), " / ".join(Seam.CLASHES.map(func(pair: Array) -> String: return "%s と %s" % [Seam.key(pair[0]), Seam.key(pair[1])])),
			])
		if signs.size() > Seam.DRAWN:
			file.problem(entry["line"], "縫い目の様子は %d つまで" % Seam.DRAWN)
			signs.resize(Seam.DRAWN)


func _read_unlock(file: RefCounted) -> void:
	var values: Dictionary = file.values("unlock", ["unit", "item", "budget"], ["unit", "item"])
	for entry: Dictionary in values.get("unit", []):
		var kind := _kind(file, entry, entry["value"])
		if kind >= 0 and not unlock_kinds.has(kind):
			unlock_kinds.append(kind as UnitKind.Id)
	for entry: Dictionary in values.get("item", []):
		var item := _item(file, entry, entry["value"])
		if item >= 0 and not unlock_items.has(item):
			unlock_items.append(item as Equipment.Id)
	if values.has("budget"):
		var entry: Dictionary = values["budget"][0]
		budget_up = file.integer(entry)
		if budget_up < 1:
			file.problem(entry["line"], "budget は 1 以上（上がる量）")
			budget_up = 0
