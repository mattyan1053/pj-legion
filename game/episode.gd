extends RefCounted
## ストーリーの話 1 つ（docs/story.md の「話のファイル」）。game/story/episodes/ の 1 ファイルを読んだもの。ノードに依存しない。
##
## 読むときに、書き間違い（知らないキー、無い駒・装備・マップ・見た目・曲、置けないマス、勝ち方の矛盾、会話の話し手、
## きっかけの値、文の長さ）を「ファイル:行: 何がおかしいか」で problems に貯める。problems が空でない話は遊べない（story.gd が外す）。
## 読む側（画面、道具、テスト）は、ここの値をそのまま使う（無い欄の値も、ここで決めてある）。

const StoryFile := preload("res://game/story_file.gd")
const StageLook := preload("res://game/stage_look.gd")
const SoundCatalog := preload("res://game/sound_catalog.gd")
const BattleCues := preload("res://game/battle_cues.gd")
const Maps := preload("res://game/maps.gd")
const UnitIcons := preload("res://game/unit_icons.gd")
const UnitLooks := preload("res://game/unit_looks.gd")

## 話のファイルを置く所（ファイルの名前が話の id）。
const DIR := "res://game/story/episodes/"
## 書ける節。
const SECTIONS := ["episode", "unlock", "ally", "enemy", "before", "after", "cues"]
## 会話（前と後）の行の数の上限、対戦の途中の台詞の数と文の長さの上限、出撃準備に出す覚えることの長さの上限。
const TALK_MAX_LINES := 10
## 会話（前と後）の 1 行の文の長さの上限（会話の場面の文の枠に 2 行で収まる）。
const TALK_MAX_CHARS := 60
const CUES_MAX := 3
const CUE_MAX_CHARS := 40
const LESSON_MAX_CHARS := 48
## 会話の行の話し手の陣営（0 = 人の軍、1 = 敵の軍）。きっかけの値の陣営も同じ言葉で書く。
const SIDE_WORDS := {"ally": 0, "enemy": 1}

## 話の id（クリアの記録に書く。変えると記録が外れる）。ファイルの名前と同じ。
var id := &""
## 会話の見出しと、話の一覧のカードに出す名前。
var title := ""
## 盤（手で作ったマップ）と、その名前（戦いの定義の名前。決着の画面の「マップ」）。
var map: HandMap
var map_title := ""
## 盤の見た目（stage_look.gd の THEMES の鍵）。
var look := &""
## 対戦の曲（無ければ盤の見た目の曲）と、会話の曲（無ければ空 = 会話の場面の曲）。
var music := &""
var talk_music := &""
## 出撃準備に出す、この話で覚えること（チュートリアルだけ。無ければ空）。
var lesson := ""
## クリアで増えるもの: 雇える駒、持たせられる装備、部隊のコストの上限の上がり幅。
var unlock_kinds: Array[UnitKind.Id] = []
var unlock_items: Array[Equipment.Id] = []
var budget_up := 0
## 人（プレイヤー1）の勝ち方: 守り切るターン数（0 なら無し）と、勝ち方の列（空ならいつもの勝ち方）。
var hold_turns := 0
var wins: Array[GameWonEvent.Reason] = []
## 人の部隊が決まっている話の、その部隊（[駒の種類, [装備, …]] の列。空なら出撃準備で選ぶ）と、必殺技のゲージの始めの量。
var squad: Array = []
var start_gauge := 0
## 敵の軍と部隊（将を除く。[駒の種類, [装備, …]] の列。並びの順に初期位置へ置く）。
## 軍が none（Army.NONE）なら、敵は軍に属さない（必殺技もゲージも無い）。魔物の群れの話に使う（docs/story.md）。
var enemy_army := UnitKind.Army.FANTASY
var enemy: Array = []
## 初期位置: [プレイヤー1 のマスの列, プレイヤー2 のマスの列]。空の列は、いつもの「本陣の前」。
var deploy: Array = [[] as Array[Vector2i], [] as Array[Vector2i]]
## 駒の始めのレベルと経験値: [人の部隊の列, 敵の部隊の列]。どちらも [レベル, 経験値] の列で、部隊（squad、enemy）と同じ並び。
## 駒の行に書かなければ [1, 0]（いつもどおり）。戦いの定義の start_growth へ写す（story_battle.gd）。
var growth: Array = [[], []]
## 話し手の名前: [人の軍の主な話し手, 敵の軍の主な話し手, ほかの話し手（[ally]・[enemy] の speaker。書いた順）, …]。
## 会話と途中の台詞の行は、話し手をこの並びの番号で持つ。
var speakers: PackedStringArray = ["", ""]
## 話し手の陣営（0 = 人の軍、1 = 敵の軍）。speakers と同じ並び。
var speaker_sides: PackedInt32Array = [0, 1]
## 話し手の姿（会話の場面に立たせる駒の形と、対戦の途中の台詞のアイコン）。speakers と同じ並び。
## どれも {"kind": 駒の種類, "evolved": 進化後の形か, "look": 将の別の姿}。書かなければ、その陣営の将の姿。
## [1]（敵の主な話し手）は、話の一覧のカードの顔にも使う。
var figures: Array[Dictionary] = [{"kind": UnitKind.Id.KING, "evolved": false, "look": &""}, {"kind": UnitKind.Id.KING, "evolved": false, "look": &""}]
## 将の姿（見た目だけ。unit_looks.gd の KING_LOOKS の名前。空ならいつもの将）: [人の軍, 敵の軍]。敵の将だけ書ける（[enemy] の king_figure）。
## 盤の将、駒の情報・決着の画面のアイコン、話し手の姿が king のときの姿に使う。ルールの上では将のまま。
var king_looks: Array[StringName] = [&"", &""]
## 対戦の前と後の会話: [話し手の陣営（0 か 1）, 文, 話し手（speakers の番号）] の列。
var before: Array = []
var after: Array = []
## 対戦の途中の会話: [きっかけ, 値, 話し手の陣営, 文, 話し手（speakers の番号）] の列（battle_cues.gd）。
var cues: Array = []
## 読んだファイルのパスと、書き間違い（空なら正しい）。
var path := ""
var problems: PackedStringArray = []
## 初期位置を書いた行（陣営ごと。書き間違いの文に使う）。
var _deploy_lines := [0, 0]
## ほかの話し手の行（陣営ごと。両方の陣営の主な話し手を読んだあとに読む）。
var _speaker_entries := [[], []]


## 話 episode_id のファイル（DIR）を読む。
static func load_id(episode_id: String) -> RefCounted:
	return load_file(DIR + episode_id + ".txt")


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


## 部隊が決まっている話か。
func has_squad() -> bool:
	return not squad.is_empty()


## 決まっている人の部隊（無ければ null）。軍は、最初の駒の軍（話の物語の軍の駒で書く。story.gd の読み込みが確かめる）。
func squad_deck() -> Deck:
	return null if squad.is_empty() else _deck_of(UnitKind.army(squad[0][0]), squad)


## 敵の部隊（決め打ち。編成の決まりの検査は通さない。docs/scenario.md）。
func enemy_deck() -> Deck:
	return _deck_of(enemy_army, enemy)


## 対戦の曲（無ければ、盤の見た目の曲）。
func battle_music() -> StringName:
	return music if music != &"" else SoundCatalog.battle_music(look)


static func _deck_of(army: UnitKind.Army, rows: Array) -> Deck:
	var deck := Deck.new(army)
	for row: Array in rows:
		var entry := DeckEntry.new(row[0])
		for item: Equipment.Id in row[1]:
			entry.equip(item)
		deck.entries.append(entry)
	return deck


# ---- 読む ----


func _read(file: RefCounted) -> void:
	path = file.path
	id = StringName(path.get_file().get_basename())
	file.check_sections(SECTIONS)
	_read_episode(file)
	_read_unlock(file)
	_read_side(file, "ally", 0)
	_read_side(file, "enemy", 1)
	_read_more_speakers(file)
	_read_talks(file)
	_read_cues(file)
	_check_deploy(file)
	problems.append_array(file.problems)


func _read_episode(file: RefCounted) -> void:
	if not file.has("episode"):
		file.problem(1, "[episode] の節が無い")
		return
	var at: int = file.line_of("episode")
	var values: Dictionary = file.values("episode", ["title", "map", "look", "music", "talk_music", "lesson", "hold_turns", "wins"])
	for key: String in ["title", "map", "look"]:
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
	if values.has("look"):
		var entry: Dictionary = values["look"][0]
		look = StringName(entry["value"])
		if not StageLook.THEMES.has(look):
			file.problem(entry["line"], "知らない見た目「%s」（書けるのは %s）" % [look, ", ".join(StageLook.THEMES.keys())])
	for key: String in ["music", "talk_music"]:
		if values.has(key):
			var entry: Dictionary = values[key][0]
			var track := StringName(entry["value"])
			if not SoundCatalog.has_music(track):
				file.problem(entry["line"], "知らない曲「%s」（sound_catalog.gd の MUSIC）" % track)
			elif key == "music":
				music = track
			else:
				talk_music = track
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


## 陣営の節（[ally] = 人の軍、[enemy] = 敵の軍）。
func _read_side(file: RefCounted, section: String, side: int) -> void:
	if not file.has(section):
		file.problem(1, "[%s] の節が無い（話し手の name だけでも書く）" % section)
		return
	var keys := ["name", "figure", "speaker", "unit", "deploy"]
	keys.append_array(["start_gauge"] if side == 0 else ["army", "king_figure"])
	var values: Dictionary = file.values(section, keys, ["speaker", "unit", "deploy"])
	_speaker_entries[side] = values.get("speaker", [])
	if values.has("name"):
		speakers[side] = values["name"][0]["value"]
	if speakers[side] == "":
		file.problem(file.line_of(section), "[%s] に話し手の name が無い" % section)
	if values.has("king_figure"):
		var entry: Dictionary = values["king_figure"][0]
		var king_look := StringName(entry["value"])
		if UnitLooks.KING_LOOKS.has(king_look):
			king_looks[side] = king_look
		else:
			file.problem(entry["line"], "知らない将の姿「%s」（書けるのは %s）" % [king_look, ", ".join(UnitLooks.KING_LOOKS)])
	if values.has("figure"):
		var entry: Dictionary = values["figure"][0]
		var figure := _figure(file, entry["line"], entry["value"])
		if not figure.is_empty():
			figures[side] = figure
	if figures[side]["kind"] == UnitKind.Id.KING:
		figures[side]["look"] = king_looks[side]
	var rows: Array = []
	var grown: Array = []
	for entry: Dictionary in values.get("unit", []):
		var row := _unit_row(file, entry)
		if not row.is_empty():
			rows.append(row)
			grown.append(_growth_of(file, entry, row[0]))
	growth[side] = grown
	var cells: Array[Vector2i] = []
	for entry: Dictionary in values.get("deploy", []):
		cells.append_array(file.cells(entry))
	deploy[side] = cells
	_deploy_lines[side] = values["deploy"][0]["line"] if values.has("deploy") else file.line_of(section)
	if side == 0:
		squad = rows
		if rows.size() > Deck.MAX_UNITS:
			file.problem(file.line_of(section), "決まっている部隊は %d 体まで（いま %d 体）" % [Deck.MAX_UNITS, rows.size()])
		if values.has("start_gauge"):
			var entry: Dictionary = values["start_gauge"][0]
			start_gauge = file.integer(entry)
			if start_gauge < 1 or start_gauge > Ults.GAUGE_MAX:
				file.problem(entry["line"], "start_gauge は 1 から %d" % Ults.GAUGE_MAX)
				start_gauge = 0
		return
	enemy = rows
	if rows.is_empty():
		file.problem(file.line_of(section), "敵の部隊（unit）が無い")
	if not values.has("army"):
		file.problem(file.line_of(section), "[enemy] に army が無い")
	else:
		var entry: Dictionary = values["army"][0]
		var army := StoryFile.enum_value(UnitKind.Army, entry["value"])
		if army < 0:
			file.problem(entry["line"], "知らない軍「%s」（書けるのは %s）" % [entry["value"], StoryFile.enum_words(UnitKind.Army)])
		else:
			enemy_army = army as UnitKind.Army
			# 軍の無い敵に軍の駒を混ぜると、盤に置いたときにその駒の軍（と必殺技）が付く（Battle.add_unit）。混ぜさせない。
			if enemy_army == UnitKind.Army.NONE:
				for unit_entry: Dictionary in values.get("unit", []):
					var kind := StoryFile.enum_value(UnitKind.Id, (unit_entry["value"] as String).split(",")[0].split("+")[0])
					if kind >= 0 and UnitKind.army(kind as UnitKind.Id) != UnitKind.Army.NONE:
						file.problem(unit_entry["line"], "軍の無い敵（army = none）に、軍の駒は置けない: %s" % UnitKind.Id.keys()[kind].to_lower())


## ほかの話し手（[ally]・[enemy] の「speaker = 名前, 姿」。姿は無くてよく、無ければその陣営の将）。
## 両方の陣営の主な話し手（name）を読んだあとに読む（speakers の [0] と [1] が主な話し手）。
func _read_more_speakers(file: RefCounted) -> void:
	for side: int in [0, 1]:
		for entry: Dictionary in _speaker_entries[side]:
			var parts := (entry["value"] as String).split(",")
			var name := parts[0].strip_edges()
			if name == "" or parts.size() > 2:
				file.problem(entry["line"], "話し手は「speaker = 名前, 姿」（姿は無くてよい）: %s" % entry["value"])
				continue
			if speakers.has(name):
				file.problem(entry["line"], "話し手「%s」が 2 度ある" % name)
				continue
			var figure := {"kind": UnitKind.Id.KING, "evolved": false, "look": &""}
			if parts.size() == 2:
				figure = _figure(file, entry["line"], parts[1].strip_edges())
				if figure.is_empty():
					continue
			if figure["kind"] == UnitKind.Id.KING:
				figure["look"] = king_looks[side]
			speakers.append(name)
			speaker_sides.append(side)
			figures.append(figure)


## 話し手の姿「駒の種類」か「駒の種類 evolved」（king も書ける。中立の駒は書けない。進化後は進化する駒だけ）。読めなければ空。
func _figure(file: RefCounted, line: int, value: String) -> Dictionary:
	var words := value.split(" ", false)
	var kind := StoryFile.enum_value(UnitKind.Id, words[0] if not words.is_empty() else "")
	if kind < 0 or UnitKind.is_neutral(kind as UnitKind.Id):
		var neutral := UnitKind.Id.values().filter(func(each: int) -> bool: return UnitKind.is_neutral(each as UnitKind.Id))
		file.problem(line, "知らない姿「%s」（書けるのは %s）" % [value, StoryFile.enum_words(UnitKind.Id, neutral)])
		return {}
	var evolved := words.size() == 2 and words[1] == "evolved"
	if words.size() > 2 or (words.size() == 2 and not evolved):
		file.problem(line, "姿は「駒の種類」か「駒の種類 evolved」: %s" % value)
		return {}
	if evolved and not UnitIcons.evolves(kind as UnitKind.Id):
		file.problem(line, "%s に進化後の姿は無い" % words[0])
		return {}
	return {"kind": kind, "evolved": evolved, "look": &""}


## side の部隊に、始めのレベルか経験値を決めた駒がいるか。
func has_growth(side: int) -> bool:
	return growth[side].any(func(row: Array) -> bool: return row != [1, 0])


## 駒の行（「paladin + iron_shield + iron_shield」）を [駒の種類, [装備, …]] に。読めなければ空。
## 「,」のあとの始めのレベルと経験値（「sorcerer, level 2, exp 100」）は _growth_of が読む。
func _unit_row(file: RefCounted, entry: Dictionary) -> Array:
	var words := (entry["value"] as String).split(",")[0].split("+")
	var kind := _kind(file, entry, words[0])
	var items: Array[Equipment.Id] = []
	for i in range(1, words.size()):
		var item := _item(file, entry, words[i])
		if item >= 0:
			items.append(item as Equipment.Id)
	if kind < 0:
		return []
	if not items.is_empty() and not Equipment.can_equip(kind as UnitKind.Id):
		file.problem(entry["line"], "%s は持ち物を持てない（軍に属する駒だけが持てる）" % words[0].strip_edges())
		return []
	if not Equipment.is_valid_for(kind as UnitKind.Id, items):
		file.problem(entry["line"], "%s はこの持ち物の組を持てない（役割の限り、1 体の数、重ねられない持ち物）" % words[0].strip_edges())
		return []
	return [kind, items]


## 駒の行の「,」のあと（「level 2」「exp 100」。どちらも無くてよい）を [レベル, 経験値] に。無ければ [1, 0]。
## レベルは 1 から Growth.MAX_LEVEL - 1（進化は対戦の中で選ぶ）、経験値は 0 から Growth.EXPERIENCE_PER_LEVEL - 1。
func _growth_of(file: RefCounted, entry: Dictionary, kind: int) -> Array:
	var result := [1, 0]
	var parts := (entry["value"] as String).split(",")
	for i in range(1, parts.size()):
		var words := parts[i].strip_edges().split(" ", false)
		var at := ["level", "exp"].find(words[0] if words.size() == 2 else "")
		if at < 0 or not words[1].is_valid_int():
			file.problem(entry["line"], "駒の行の「,」のあとは「level 数」か「exp 数」: %s" % parts[i].strip_edges())
			continue
		result[at] = words[1].to_int()
	if result == [1, 0]:
		return result
	if not Growth.GAINS.has(UnitKind.role(kind as UnitKind.Id)):
		file.problem(entry["line"], "%s は育たない（レベルと経験値は書けない）" % parts[0].strip_edges())
		return [1, 0]
	if result[0] != Growth.start_level(result[0]):
		file.problem(entry["line"], "level は 1 から %d（進化は対戦の中で選ぶ）" % (Growth.MAX_LEVEL - 1))
	if result[1] != Growth.start_experience(result[1]):
		file.problem(entry["line"], "exp は 0 から %d" % (Growth.EXPERIENCE_PER_LEVEL - 1))
	return [Growth.start_level(result[0]), Growth.start_experience(result[1])]


## 駒の種類（将は書けない）。読めなければ -1。
func _kind(file: RefCounted, entry: Dictionary, word: String) -> int:
	var kind := StoryFile.enum_value(UnitKind.Id, word)
	if kind < 0 or kind == UnitKind.Id.KING:
		file.problem(entry["line"], "知らない駒「%s」（書けるのは %s）" % [word.strip_edges(), StoryFile.enum_words(UnitKind.Id, [UnitKind.Id.KING])])
		return -1
	return kind


func _item(file: RefCounted, entry: Dictionary, word: String) -> int:
	var item := StoryFile.enum_value(Equipment.Id, word)
	if item < 0:
		file.problem(entry["line"], "知らない持ち物「%s」（書けるのは %s）" % [word.strip_edges(), StoryFile.enum_words(Equipment.Id)])
	return item


func _read_talks(file: RefCounted) -> void:
	for section: String in ["before", "after"]:
		var rows: Array = []
		for row: Dictionary in file.rows(section):
			var line := _speech(file, row["line"], row["text"])
			if not line.is_empty():
				rows.append(line)
				if (line[1] as String).length() > TALK_MAX_CHARS:
					file.problem(row["line"], "会話の文は %d 字まで（いま %d 字）" % [TALK_MAX_CHARS, (line[1] as String).length()])
		if rows.is_empty():
			file.problem(maxi(file.line_of(section), 1), "[%s] の会話が無い" % section)
		elif rows.size() > TALK_MAX_LINES:
			file.problem(file.line_of(section), "[%s] の会話は %d 行まで（いま %d 行）" % [section, TALK_MAX_LINES, rows.size()])
		if section == "before":
			before = rows
		else:
			after = rows


## 会話の行「話し手: 文」（全角の「：」でもよい）を [陣営, 文, 話し手（speakers の番号）] に。
## 話し手は [ally] か [enemy] の name か speaker。読めなければ空。
func _speech(file: RefCounted, line: int, text: String) -> Array:
	var at := text.find(":")
	var wide := text.find("：")
	if at < 0 or (wide >= 0 and wide < at):
		at = wide
	if at < 0:
		file.problem(line, "会話の行は「話し手: 文」: %s" % text)
		return []
	var name := text.substr(0, at).strip_edges()
	var said := text.substr(at + 1).strip_edges()
	var who := speakers.find(name)
	if name == "" or who < 0:
		file.problem(line, "知らない話し手「%s」（[ally] か [enemy] の name か speaker: %s）" % [name, " / ".join(speakers)])
		return []
	if said == "":
		file.problem(line, "文が空")
		return []
	return [speaker_sides[who], said, who]


## 対戦の途中の会話の行「(きっかけ 値) 話し手: 文」。
func _read_cues(file: RefCounted) -> void:
	for row: Dictionary in file.rows("cues"):
		var text: String = row["text"]
		var close := text.find(")")
		if not text.begins_with("(") or close < 0:
			file.problem(row["line"], "途中の台詞の行は「(きっかけ 値) 話し手: 文」: %s" % text)
			continue
		var words := text.substr(1, close - 1).split(" ", false)
		var speech := _speech(file, row["line"], text.substr(close + 1))
		if speech.is_empty():
			continue
		if words.size() != 2 or not BattleCues.KINDS.has(StringName(words[0])):
			file.problem(row["line"], "知らないきっかけ「%s」（書けるのは %s。値と 2 語で書く）" % [" ".join(words), ", ".join(BattleCues.KINDS)])
			continue
		var kind := StringName(words[0])
		var value := -1
		if kind == BattleCues.TURN:
			value = words[1].to_int() if words[1].is_valid_int() else 0
			if value < 1:
				file.problem(row["line"], "ターンは 1 から: %s" % words[1])
				continue
			if hold_turns > 0 and value > hold_turns:
				file.problem(row["line"], "守り切るターン（%d）の外なので出ない: turn %d" % [hold_turns, value])
				continue
		else:
			value = SIDE_WORDS.get(words[1], -1)
			if value < 0:
				file.problem(row["line"], "陣営は ally か enemy: %s" % words[1])
				continue
		if (speech[1] as String).length() > CUE_MAX_CHARS:
			file.problem(row["line"], "途中の台詞は %d 字まで（いま %d 字）" % [CUE_MAX_CHARS, (speech[1] as String).length()])
		cues.append([kind, value, speech[0], speech[1], speech[2]])
	if cues.size() > CUES_MAX:
		file.problem(file.line_of("cues"), "途中の台詞は %d つまで（いま %d）" % [CUES_MAX, cues.size()])


## 初期位置: 歩けて、物が無く、本陣でなく、重ならず、数が足りる。
func _check_deploy(file: RefCounted) -> void:
	if map == null:
		return
	var board := map.make_board()
	var seen := {}
	for side: int in [0, 1]:
		var section := "ally" if side == 0 else "enemy"
		var at: int = _deploy_lines[side]
		for cell: Vector2i in deploy[side]:
			if not board.is_walkable(cell) or board.object_at(cell) != MapObject.Type.NONE or board.hq_cells.has(cell):
				file.problem(at, "[%s] の初期位置 %d,%d に置けない（歩けないマス、物、本陣、盤の外）" % [section, cell.x, cell.y])
			elif seen.has(cell):
				file.problem(at, "初期位置 %d,%d が重なっている" % [cell.x, cell.y])
			seen[cell] = true
	var enemy_cells: Array = deploy[1]
	if not enemy_cells.is_empty() and enemy_cells.size() < enemy.size():
		file.problem(_deploy_lines[1], "敵の初期位置（%d）が、敵の部隊の数（%d）より少ない" % [enemy_cells.size(), enemy.size()])
	var ally_cells: Array = deploy[0]
	var needed := squad.size() if has_squad() else Deck.MAX_UNITS
	if not ally_cells.is_empty() and ally_cells.size() < needed:
		file.problem(_deploy_lines[0], "人の初期位置（%d）が、部隊の数の上限（%d）より少ない" % [ally_cells.size(), needed])
