extends "res://game/episode/episode_talks.gd"
## 話（game/episode.gd）の、場面の列を組む（docs/story.md の「場面の列」）。話のファイルの書き方は 2 つ:
## - [before]・[after] の話: 出撃準備 → 会話（[before]）→ 対戦 → 会話（[after]）。
## - 場面の節の話: 「[talk 名前]」（会話）・[sortie]（出撃準備）・[battle]（対戦）を、書いた順に。会話はいくつでも。
##   [battle] を書かなければ、対戦の無い話（読み終えたらクリア）。[sortie] を書かなければ、出撃準備は話の最初。

## 会話の場面の頭に書ける設定（「キー = 値」。会話の行より前に書く）。
const TALK_KEYS := ["place", "look", "music"]
## カットシーンの頭に書ける設定（color は、景色のかわりの色の幕）。
const CUT_KEYS := ["place", "look", "music", "color"]


## 場面の節で書いた話か（_read の最初に決める。ほかの節の読み方が変わる）。
func _find_format(file: RefCounted) -> void:
	for section: String in file.sections:
		if section.begins_with(TALK_SECTION) or section.begins_with(CUT_SECTION) or SCENE_MARKS.has(section):
			written_as_scenes = true
	_fights = not written_as_scenes or file.has("battle")


## 節の名前が、この話に書いてよいものか（知らない節は書き間違い）。
func _check_sections(file: RefCounted) -> void:
	var listed: Array = SECTIONS + SCENE_MARKS + ["talk 名前", "cut 名前"]
	for section: String in file.sections:
		var is_talk := (section.begins_with(TALK_SECTION) and section.substr(TALK_SECTION.length()).strip_edges() != "") \
				or (section.begins_with(CUT_SECTION) and section.substr(CUT_SECTION.length()).strip_edges() != "")
		if not is_talk and not SECTIONS.has(section) and not SCENE_MARKS.has(section):
			file.problem(file.sections[section]["line"], "知らない節 [%s]（書けるのは %s）" % [section, ", ".join(listed.map(func(each: String) -> String: return "[%s]" % each))])


## 場面の列を組む。
func _build_scenes(file: RefCounted) -> void:
	if not written_as_scenes:
		var first := StoryScene.talk("before", before, before_talk_music(), true)
		first.music_written = before_music != &""
		var last := StoryScene.talk("after", after, after_talk_music())
		last.music_written = after_music != &""
		scenes = [StoryScene.sortie(), first, StoryScene.battle(), last]
		return
	for section: String in ["before", "after"]:
		if file.has(section):
			file.problem(file.line_of(section), "場面の節（[talk 名前]・[sortie]・[battle]）で書く話に、[%s] は書かない（[talk 名前] に書く）" % section)
	for key: String in ["before_music", "after_music"]:
		if get(key) != &"":
			file.problem(file.line_of("episode"), "場面の節で書く話に、%s は書かない（[talk 名前] の music に書く）" % key)
	scenes = []
	var sortie_at := -1
	var fought := false
	var talks := 0
	for section: String in file.sections:
		var at: int = file.line_of(section)
		if section == "sortie" or section == "battle":
			if not file.rows(section).is_empty():
				file.problem(at, "[%s] は場面の順の印（中には何も書かない）" % section)
			if section == "sortie":
				if fought or not _fights:
					file.problem(at, "[sortie] は [battle] より前に書く（対戦の無い話には書かない）")
				sortie_at = scenes.size()
				scenes.append(StoryScene.sortie())
			else:
				fought = true
				scenes.append(StoryScene.battle())
		elif section.begins_with(TALK_SECTION) or section.begins_with(CUT_SECTION):
			talks += 1
			scenes.append(_read_talk_scene(file, section, not fought and _fights))
	if not scenes.is_empty() and scenes.back().cut:
		file.problem(file.line_of(scenes.back().part), "カットシーンは、話の最後の場面にしない（最後は会話か対戦。クリアの知らせと「次の話へ」が、最後の会話に出る）")
	if _fights and sortie_at < 0:
		scenes.insert(0, StoryScene.sortie())
	if talks == 0:
		file.problem(1, "会話の場面（[talk 名前]）が 1 つも無い")
	elif talks > TALK_SCENES_MAX:
		file.problem(1, "会話の場面は %d つまで（いま %d）" % [TALK_SCENES_MAX, talks])
	if not _fights:
		for section: String in ["cues", "lost", "ally", "enemy"]:
			if file.has(section):
				file.problem(file.line_of(section), "対戦の無い話（[battle] を書かない話）に、[%s] は書かない" % section)


## 会話の場面の節「[talk 名前]」: 頭に設定（place・look・music）、そのあとに会話の行。
## before_battle: 対戦より前の会話か（1 度だけ出す。対戦の曲を書くなら、その話の対戦の曲）。
func _read_talk_scene(file: RefCounted, section: String, before_battle: bool) -> StoryScene:
	var cut := section.begins_with(CUT_SECTION)
	var keys := CUT_KEYS if cut else TALK_KEYS
	var settings := {}
	var talk_rows: Array = []
	for row: Dictionary in file.rows(section):
		var text: String = row["text"]
		if _is_setting(text):
			var key := text.substr(0, text.find("=")).strip_edges()
			var value := text.substr(text.find("=") + 1).strip_edges()
			if not keys.has(key):
				file.problem(row["line"], "[%s] の知らない設定「%s」（書けるのは %s）" % [section, key, ", ".join(keys)])
			elif not talk_rows.is_empty():
				file.problem(row["line"], "設定「%s」は、会話の行より前に書く" % key)
			elif settings.has(key):
				file.problem(row["line"], "「%s」が 2 度ある" % key)
			else:
				settings[key] = {"line": row["line"], "value": value}
			continue
		talk_rows.append(row)
	var rows := _cut_rows(file, section, talk_rows) if cut else _talk_rows(file, section, talk_rows)
	var scene := StoryScene.talk(section, rows, &"", before_battle)
	scene.name = section.substr((CUT_SECTION if cut else TALK_SECTION).length()).strip_edges()
	scene.cut = cut
	if settings.has("color"):
		var entry: Dictionary = settings["color"]
		if not StoryScene.COLORS.has(StringName(entry["value"])):
			file.problem(entry["line"], "知らない色「%s」（書けるのは %s）" % [entry["value"], ", ".join(StoryScene.COLORS)])
		elif settings.has("place"):
			file.problem(entry["line"], "color と place は、どちらかだけ（色の幕か、場所の景色）")
		else:
			scene.color = StringName(entry["value"])
	if settings.has("place"):
		var entry: Dictionary = settings["place"]
		var found: Dictionary = Maps.find(entry["value"])
		if found.is_empty() or not (found["problems"] as PackedStringArray).is_empty():
			file.problem(entry["line"], "知らないか、書き間違いのあるマップ「%s」（%s）" % [entry["value"], Maps.DIR])
		else:
			scene.place = found["map"]
			scene.look = found["look"]
	if settings.has("look"):
		var entry: Dictionary = settings["look"]
		if not StageLook.THEMES.has(StringName(entry["value"])):
			file.problem(entry["line"], "知らない見た目「%s」（書けるのは %s）" % [entry["value"], ", ".join(StageLook.THEMES.keys())])
		elif scene.place == null:
			file.problem(entry["line"], "look は place と組で書く（place が無ければ、背景は話の盤）")
		else:
			scene.look = StringName(entry["value"])
	if settings.has("music"):
		var entry: Dictionary = settings["music"]
		var track := StringName(entry["value"])
		if not SoundCatalog.has_music(track):
			file.problem(entry["line"], "知らない曲「%s」（sound_catalog.gd の MUSIC）" % track)
		elif SoundCatalog.is_battle_music(track) and (not before_battle or track != battle_music()):
			file.problem(entry["line"], "会話に対戦の曲を書けるのは、対戦より前の会話に、その話の対戦の曲「%s」だけ" % battle_music())
		else:
			scene.music = track
			scene.music_written = true
	if scene.music == &"":
		# 書かなければ: 対戦より前で、話の盤を前にした会話は対戦の曲（そのまま対戦へつながる）。ほかは落ち着いた曲。
		scene.music = battle_music() if before_battle and scene.place == null else SoundCatalog.AFTER_TALK_MUSIC
	return scene


## カットシーンの行: どの行も地の文（頭の「>」は、あっても無くてもよい）。台詞・選択肢・条件は書けない。
func _cut_rows(file: RefCounted, section: String, source: Array) -> Array[TalkLine]:
	var rows: Array[TalkLine] = []
	for row: Dictionary in source:
		var text: String = row["text"]
		if text.begins_with(NARRATION_MARK) or text.begins_with("＞"):
			text = text.substr(1).strip_edges()
		var colon := maxi(text.find(":"), text.find("："))
		if text.begins_with("(") or (colon > 0 and speakers.has(text.substr(0, colon).strip_edges())):
			file.problem(row["line"], "[%s] に書けるのは地の文だけ（台詞・選択肢・条件は [talk 名前] に書く）: %s" % [section, text])
			continue
		if text == "":
			file.problem(row["line"], "地の文が空")
			continue
		var line := TalkLine.narration(text)
		if line.longest() > TALK_MAX_CHARS:
			file.problem(row["line"], "[%s] の文は %d 字まで（いま %d 字）" % [section, TALK_MAX_CHARS, line.longest()])
		rows.append(line)
	if rows.is_empty():
		file.problem(file.line_of(section), "[%s] の文が無い" % section)
	elif rows.size() > CUT_MAX_LINES:
		file.problem(file.line_of(section), "[%s] の文は %d 行まで（いま %d 行）" % [section, CUT_MAX_LINES, rows.size()])
	return rows


## 会話の場面の行 text が、設定の行（「キー = 値」）か。会話の行（「話し手: 文」）と地の文（「> 文」）は、設定でない。
static func _is_setting(text: String) -> bool:
	var at := text.find("=")
	if at < 0 or text.begins_with(NARRATION_MARK) or text.begins_with("＞") or text.begins_with("("):
		return false
	var head := text.substr(0, at)
	return not head.contains(":") and not head.contains("：")
