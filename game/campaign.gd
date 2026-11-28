extends RefCounted
## ストーリーの物語 1 つ（docs/story.md の「物語」）。game/story/ の 1 フォルダ（フォルダの名前が物語の id）を読んだもの。ノードに依存しない。
##
## 物語は、軍 1 つと話の列。フォルダの story.txt が物語のファイルで、話は [episodes] に id を並べ、同じフォルダの <id>.txt から読む（episode.gd）。
## フォルダを置けば、物語の一覧に並ぶ（どこかへ登録しない）。名前が「_」で始まるフォルダは読まない（書き方の見本の _template）。
## 読むときに、物語と話の書き間違い（知らない軍・駒・装備、ほかの軍の駒の解放、同じものの 2 度目の解放、話のファイルの書き間違い）を
## 「ファイル:行: 何がおかしいか」で problems に貯める。書き間違いのある話は、並びから外す（遊べない）。

const StoryFile := preload("res://game/story_file.gd")
const Episode := preload("res://game/episode.gd")
const HeroName := preload("res://game/hero_name.gd")

## 物語のフォルダを置く所（フォルダの名前が物語の id）と、フォルダの中の物語のファイルの名前。
const DIR := "res://game/story/"
const STORY_FILE := "story.txt"
## 物語の一覧での並びの順（[campaign] の order）を書かない物語の順（後ろに、id の順で並ぶ）。
const ORDER_LAST := 1000
const SECTIONS := ["campaign", "start", "cast", "episodes"]
## 物語の紹介の 1 行（[campaign] の intro。物語を選ぶ場面のカードに出す）の長さの上限。
const INTRO_MAX_CHARS := 40
## 主な人物（[cast]。話の一覧の頭に出す）の数と、立ち位置の長さの上限。
const CAST_MAX := 6
const ROLE_MAX_CHARS := 10

## 物語の id（クリアの記録に書く。変えると記録が外れる）。ファイルの名前と同じ。
var id := &""
## 物語を選ぶ場面と、話の一覧の見出しに出す名前。
var title := ""
## 物語の紹介の 1 行（無ければ空）。誰として、何をする物語か。
var intro := ""
## 主人公の既定の名前（[campaign] の hero。遊ぶ人が入る人物。話の [cast] の同じ名前の話し手が主人公）。空なら、名前を変えられる主人公はいない。
var hero := ""
## 主な人物（無ければ空）: {"name": 名前, "role": 立ち位置, "figure": 姿（episode.gd の figures と同じ形）} の列。書いた順。
var cast: Array[Dictionary] = []
## 人が使う軍。
var army := UnitKind.Army.NONE
## この物語の編成の決まりの名前（取っておく部隊に書く。物語ごとに違う）。
var rules_id := &""
## 最初から雇える駒・持たせられる装備・部隊のコストの上限（話のクリアで増える。docs/story.md の「解放」）。
var starting_kinds: Array[UnitKind.Id] = []
var starting_items: Array[Equipment.Id] = []
var starting_budget := 0
## 最初から選べる軍略（[start] の trait。Traits.Id）。
var starting_traits: Array[int] = []
## 物語の一覧での並びの順（小さいほうが先。[campaign] の order。書かなければ ORDER_LAST）。
var order := ORDER_LAST
## 話の並び（一本道）。
var episodes: Array[Episode] = []
var path := ""
var problems: PackedStringArray = []


## 物語を全部読む（DIR の下の、story.txt のあるフォルダ。並びは order の小さい順、同じなら id の順）。
## 書き間違いは、どれかの物語の problems か、全体の problems に入る。
## 返すもの: {"campaigns": [物語, …], "problems": 全体の書き間違い}。
static func load_all(dir := DIR) -> Dictionary:
	var found_problems: PackedStringArray = []
	var found: Array = []
	var rules_ids := {DeckRules.VERSUS: 0}
	var episode_ids := {}
	var folders := Array(DirAccess.get_directories_at(dir))
	folders.sort()
	for folder: String in folders:
		if folder.begins_with("_") or folder.begins_with("."):
			continue
		var file_path := dir.path_join(folder).path_join(STORY_FILE)
		if not FileAccess.file_exists(file_path):
			found_problems.append("%s: 物語のフォルダに %s が無い" % [dir.path_join(folder), STORY_FILE])
			continue
		var campaign: RefCounted = load_file(file_path)
		if rules_ids.has(campaign.rules_id):
			campaign.problems.append("%s: 編成の決まりの名前「%s」が、ほかの物語か対戦と重なっている" % [campaign.path, campaign.rules_id])
		rules_ids[campaign.rules_id] = true
		for episode: RefCounted in campaign.episodes:
			if episode_ids.has(episode.id):
				campaign.problems.append("%s: 話「%s」は、物語「%s」にもある（話の id は、物語をまたいで重ねない）" % [campaign.path, episode.id, episode_ids[episode.id]])
			episode_ids[episode.id] = campaign.id
		found.append(campaign)
	found.sort_custom(func(a: RefCounted, b: RefCounted) -> bool:
		return a.order < b.order if a.order != b.order else String(a.id) < String(b.id))
	if found.is_empty():
		found_problems.append("%s: 物語が 1 つも無い（物語のフォルダに %s を置く）" % [dir, STORY_FILE])
	return {"campaigns": found, "problems": found_problems}


static func load_file(file_path: String) -> RefCounted:
	return read(StoryFile.open(file_path))


## 文 text を、ファイル file_path の中身として読む（テストは、わざと壊した文を渡す）。
static func parse(text: String, file_path := "probe.txt") -> RefCounted:
	return read(StoryFile.parse(text, file_path))


static func read(file: RefCounted) -> RefCounted:
	var campaign: RefCounted = new()
	campaign._read(file)
	return campaign


## 遊べるか（話が 1 つ以上ある）。話の無い物語は「準備中」。
func is_ready() -> bool:
	return not episodes.is_empty()


## 話 episode_id（無ければ null）。
func find_episode(episode_id: StringName) -> RefCounted:
	for each: RefCounted in episodes:
		if each.id == episode_id:
			return each
	return null


func _read(file: RefCounted) -> void:
	path = file.path
	# 物語の id は、フォルダの名前（story.txt を置いたフォルダ）。
	id = StringName(path.get_base_dir().get_file())
	file.check_sections(SECTIONS)
	if not file.has("campaign"):
		file.problem(1, "[campaign] の節が無い")
	var at: int = file.line_of("campaign")
	var values: Dictionary = file.values("campaign", ["title", "army", "rules", "budget", "order", "intro", "hero"])
	for key: String in ["title", "army", "rules", "budget"]:
		if file.has("campaign") and not values.has(key):
			file.problem(at, "[campaign] に「%s」が無い" % key)
	if values.has("title"):
		title = values["title"][0]["value"]
	if values.has("rules"):
		rules_id = StringName(values["rules"][0]["value"])
	if values.has("army"):
		var entry: Dictionary = values["army"][0]
		var found := StoryFile.enum_value(UnitKind.Army, entry["value"])
		if found < 0 or found == UnitKind.Army.NONE:
			file.problem(entry["line"], "知らない軍「%s」（書けるのは %s）" % [entry["value"], StoryFile.enum_words(UnitKind.Army, [UnitKind.Army.NONE])])
		else:
			army = found as UnitKind.Army
	if values.has("order"):
		order = file.integer(values["order"][0])
	if values.has("intro"):
		var entry: Dictionary = values["intro"][0]
		intro = entry["value"]
		if intro == "" or HeroName.longest_length(intro) > INTRO_MAX_CHARS:
			file.problem(entry["line"], "intro は 1 から %d 字（いま %d 字。{hero} は %d 字で数える）" % [INTRO_MAX_CHARS, HeroName.longest_length(intro), HeroName.MAX_CHARS])
	if values.has("hero"):
		var entry: Dictionary = values["hero"][0]
		hero = entry["value"]
		if not HeroName.is_valid(hero):
			file.problem(entry["line"], "hero（主人公の既定の名前）は、全角 %d 字ぶんまでの、画面の字にある文字: %s" % [HeroName.MAX_CHARS, hero])
			hero = ""
	if hero == "" and intro.contains(HeroName.MARK):
		file.problem(file.line_of("campaign"), "intro の {hero} は、hero（主人公の既定の名前）を書いた物語だけ")
	_read_cast(file)
	if values.has("budget"):
		starting_budget = file.integer(values["budget"][0])
		if starting_budget < 1:
			file.problem(values["budget"][0]["line"], "budget は 1 以上")
	var start: Dictionary = file.values("start", ["unit", "item", "trait"], ["unit", "item", "trait"])
	for entry: Dictionary in start.get("unit", []):
		var kind := StoryFile.enum_value(UnitKind.Id, entry["value"])
		if kind < 0 or UnitKind.army(kind as UnitKind.Id) != army:
			file.problem(entry["line"], "最初から雇える駒は、物語の軍（%s）の駒: %s" % [UnitKind.Army.keys()[army].to_lower(), entry["value"]])
		elif not starting_kinds.has(kind):
			starting_kinds.append(kind as UnitKind.Id)
	if starting_kinds.is_empty():
		file.problem(maxi(file.line_of("start"), 1), "最初から雇える駒（[start] の unit）が無い")
	for entry: Dictionary in start.get("item", []):
		var item := StoryFile.enum_value(Equipment.Id, entry["value"])
		if item < 0:
			file.problem(entry["line"], "知らない持ち物「%s」（書けるのは %s）" % [entry["value"], StoryFile.enum_words(Equipment.Id)])
		elif not starting_items.has(item):
			starting_items.append(item as Equipment.Id)
	for entry: Dictionary in start.get("trait", []):
		var chosen := Traits.from_key(entry["value"])
		if not Traits.of_army(army).has(chosen):
			file.problem(entry["line"], "最初から選べる軍略は、物語の軍の軍略: %s" % entry["value"])
		elif not starting_traits.has(chosen):
			starting_traits.append(chosen)
	problems.append_array(file.problems)
	_read_episodes(file)


## 主な人物「名前 = 姿, 立ち位置」（姿の書き方は話のファイルの [cast] と同じ。立ち位置は短く）。
func _read_cast(file: RefCounted) -> void:
	var names := {}
	for row: Dictionary in file.rows("cast"):
		var text: String = row["text"]
		var at := text.find("=")
		var name := text.substr(0, maxi(at, 0)).strip_edges()
		var rest := text.substr(at + 1)
		var comma := rest.find(",")
		if at < 0 or name == "" or comma < 0:
			file.problem(row["line"], "主な人物は「名前 = 姿, 立ち位置」: %s" % text)
			continue
		var role := rest.substr(comma + 1).strip_edges()
		if role == "" or role.length() > ROLE_MAX_CHARS:
			file.problem(row["line"], "立ち位置は 1 から %d 字（いま %d 字）: %s" % [ROLE_MAX_CHARS, role.length(), role])
			continue
		if names.has(name):
			file.problem(row["line"], "人物「%s」が 2 度ある（%d 行目にもある）" % [name, names[name]])
			continue
		var figure: Dictionary = Episode.read_figure(file, row["line"], rest.substr(0, comma).strip_edges())
		if figure.is_empty():
			continue
		names[name] = row["line"]
		cast.append({"name": name, "role": role, "figure": figure})
	if cast.size() > CAST_MAX:
		file.problem(file.line_of("cast"), "主な人物は %d 人まで（いま %d 人）" % [CAST_MAX, cast.size()])


## 話を読み、物語の中での決まり（解放は物語の軍の駒・まだ使えないものだけ、決まっている部隊は物語の軍）を確かめる。
func _read_episodes(file: RefCounted) -> void:
	var kinds: Array = starting_kinds.duplicate()
	var items: Array = starting_items.duplicate()
	var asked := {}  # ここまでの話が選ばせた選択肢: 名前 -> 答えの鍵の列
	var traits: Array = starting_traits.duplicate()
	for row: Dictionary in file.rows("episodes"):
		var episode_id: String = row["text"]
		var where := "%s:%d" % [path, row["line"]]
		var episode_path := path.get_base_dir().path_join(episode_id + ".txt")
		if episode_id + ".txt" == STORY_FILE or not episode_id.is_valid_filename() or not FileAccess.file_exists(episode_path):
			problems.append("%s: 話のファイルが無い: %s（物語と同じフォルダに置く）" % [where, episode_path])
			continue
		var loaded: RefCounted = Episode.load_file(episode_path)
		if find_episode(loaded.id) != null:
			problems.append("%s: 話「%s」が 2 度ある" % [where, episode_id])
			continue
		# 選択肢（docs/story.md の「選択肢」）: 名前は物語の中で重ねない。条件の行は、この話までに選ばせた選択肢と答えを指す。
		loaded.set_hero(hero)
		if hero == "" and loaded.uses_hero_mark():
			loaded.problems.append("%s: 文の {hero} は、hero（主人公の既定の名前）を書いた物語の話だけ" % loaded.path)
		if hero == "" and loaded.asks_hero_name():
			loaded.problems.append("%s: (name) は、hero（主人公の既定の名前）を書いた物語の話だけ" % loaded.path)
		for condition: Dictionary in loaded.conditions:
			var answers: Variant = loaded.choices[condition["choice"]] if condition["here"] else asked.get(condition["choice"])
			if answers == null:
				loaded.problems.append("%s:%d: 条件の選択肢「%s」を、この行までに選ばせていない" % [loaded.path, condition["line"], condition["choice"]])
			elif not (answers as Array).has(condition["answer"]):
				loaded.problems.append("%s:%d: 選択肢「%s」に、答え「%s」は無い" % [loaded.path, condition["line"], condition["choice"], condition["answer"]])
		for choice: StringName in loaded.choices:
			if asked.has(choice):
				loaded.problems.append("%s: 選択肢「%s」は、前の話にもある（名前は、物語の中で重ねない）" % [loaded.path, choice])
			asked[choice] = loaded.choices[choice]
		for kind: UnitKind.Id in loaded.unlock_kinds:
			if UnitKind.army(kind) != army:
				loaded.problems.append("%s: 解放するのは、物語の軍（%s）の駒: %s" % [loaded.path, UnitKind.Army.keys()[army].to_lower(), UnitKind.Id.keys()[kind].to_lower()])
			elif kinds.has(kind):
				loaded.problems.append("%s: %s は、この話の前から雇える" % [loaded.path, UnitKind.Id.keys()[kind].to_lower()])
			kinds.append(kind)
		for item: Equipment.Id in loaded.unlock_items:
			if items.has(item):
				loaded.problems.append("%s: %s は、この話の前から持たせられる" % [loaded.path, Equipment.Id.keys()[item].to_lower()])
			items.append(item)
		for taught: int in loaded.unlock_traits:
			if not Traits.of_army(army).has(taught):
				loaded.problems.append("%s: 解放するのは、物語の軍の軍略: %s" % [loaded.path, Traits.key(taught)])
			elif traits.has(taught):
				loaded.problems.append("%s: 軍略 %s は、この話の前から選べる" % [loaded.path, Traits.key(taught)])
			traits.append(taught)
		for squad_row: Array in loaded.squad:
			if UnitKind.army(squad_row[0]) != army:
				loaded.problems.append("%s: 決まっている部隊は、物語の軍（%s）の駒" % [loaded.path, UnitKind.Army.keys()[army].to_lower()])
				break
		if not loaded.problems.is_empty():
			problems.append_array(loaded.problems)
			continue  # 書き間違いのある話は並べない（遊べない）
		episodes.append(loaded)


## 紹介の 1 行（主人公の名前 named を差し込んだもの。named が空なら既定の名前）。
func intro_for(named := "") -> String:
	return HeroName.fill(intro, named if named != "" else hero)


## 主な人物 person（cast の 1 人）の、画面に出す名前（主人公なら、遊ぶ人の付けた名前 named）。
func cast_name(person: Dictionary, named := "") -> String:
	return named if named != "" and hero != "" and person["name"] == hero else person["name"]


## 主人公の立ち位置の文（[cast] の、hero と同じ名前の人の立ち位置。いなければ空）。名前の窓に出す。
func hero_role() -> String:
	for person: Dictionary in cast:
		if person["name"] == hero:
			return person["role"]
	return ""
