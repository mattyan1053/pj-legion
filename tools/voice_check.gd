extends RefCounted
## 台詞を、呼び方と一人称の表（game/story/voices.txt。docs/story.md の「口調の見本」）に掛ける道具。ノードに依存しない。
##
## 見るもの（話し手ごと。地の文は見ない）:
## - 一人称: [pronouns] の言葉が台詞にあれば、話し手の self に書いてあること。
## - 呼び方: 表のどこかに出てくる呼び方・[watch] の二人称・[people] の名前が台詞にあれば、話し手の節（相手ごとの行か you）に書いてあること。
##   長い言い方から先に当てる（「少佐どの」は「少佐」より先）。敬称（さん、さま、どの…）が続けば、それも込みで見る。自分の名前と肩書き（名乗り）は見ない。
## - 言わないこと: 話し手の avoid の言葉が台詞に無いこと。
## - 肩書き: [titles] の肩書きは、同じ物語の中で、その人の名前と同じ行に 1 度出たあとでだけ、名前なしで使える（地の文も数える）。
## 敬語の段や、声に出して読めるかは見られない（読んで確かめる。docs/story.md の「会話の書き方」）。

const StoryFile := preload("res://game/story_file.gd")
const Story := preload("res://game/story.gd")
const Campaign := preload("res://game/campaign.gd")
const Episode := preload("res://game/episode.gd")

const TABLE := "res://game/story/voices.txt"
const RESERVED := ["pronouns", "watch", "people", "titles"]
## 一人称と同じ字を持つ別の言葉を、一人称と数えないための形（言葉 -> 正規表現）。
const PRONOUN_SHAPES := {
	"我": "(?<!怪)我(?![慢々])",
	"わし": "(?<![かくま交回])わし",
	"おれ": "(?<![ぁ-ん])おれ",
}

## 呼び方のあとに付く敬称（長い順）。表に無い組み合わせは落とす。
const SUFFIXES := ["ねえさん", "ちゃん", "さん", "さま", "どの", "くん", "様", "殿"]

## 一人称として見張る言葉、二人称として見張る言葉、名前を見張る人。
var pronouns: PackedStringArray = []
var watch: PackedStringArray = []
var people: PackedStringArray = []
## 肩書き -> 人の名前。
var titles := {}
## 話し手 -> {"self": [...], "allowed": {言い方: true}, "avoid": [...]}。
var speakers := {}
## 見張る呼び方（長い順）。
var terms: PackedStringArray = []
## 表の書き間違い。
var problems: PackedStringArray = []


## 置いてある表を読む。
static func load_table() -> RefCounted:
	return parse(FileAccess.get_file_as_string(TABLE), TABLE)


## 表の文 text を読む（テストは、小さな表を渡す）。
static func parse(text: String, file_path := "voices.txt") -> RefCounted:
	var table := new()
	var file := StoryFile.parse(text, file_path)
	table.problems.append_array(file.problems)
	var seen := {}
	for section: String in file.sections:
		var entry := {"self": [], "allowed": {}, "avoid": []}
		for row: Dictionary in file.sections[section]["rows"]:
			var line: String = row["text"]
			var cut := line.find("=")
			if cut < 0:
				file.problem(row["line"], "「キー = 言い方, …」で書く: %s" % line)
				continue
			var key := line.substr(0, cut).strip_edges()
			var values := PackedStringArray()
			for value: String in line.substr(cut + 1).split(",", false):
				values.append(value.strip_edges())
			match section:
				"pronouns":
					table.pronouns.append_array(values)
				"watch":
					table.watch.append_array(values)
				"people":
					table.people.append_array(values)
				"titles":
					table.titles[key] = values[0] if values.size() > 0 else ""
				_:
					if key == "self":
						entry["self"].append_array(values)
					elif key == "avoid":
						entry["avoid"].append_array(values)
					else:
						for value: String in values:
							entry["allowed"][value] = true
							if key != "you":
								seen[value] = true
		if not RESERVED.has(section):
			table.speakers[section] = entry
	table.problems = file.problems
	for word: String in table.watch:
		seen[word] = true
	for word: String in table.people:
		seen[word] = true
	for word: String in table.titles:
		seen[word] = true
	var sorted := seen.keys()
	sorted.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length() if a.length() != b.length() else a < b)
	table.terms = PackedStringArray(sorted)
	return table


## 全部の物語の全部の台詞を表に掛けて、外れた所を「物語/話 [節] 話し手: 文 — 何が」で返す。
func check_all() -> PackedStringArray:
	var found := PackedStringArray()
	for campaign: Campaign in Story.campaigns():
		found.append_array(check_campaign(campaign))
	return found


func check_campaign(campaign: Campaign) -> PackedStringArray:
	var found := PackedStringArray()
	var introduced := {}
	for episode: Episode in campaign.episodes:
		var where := "%s/%s" % [campaign.id, episode.id]
		var lines: Array[Dictionary] = []  # {"part": 節, "line": 会話の行}。場面の列の順（episode.gd の all_lines と同じ順）
		for scene: Episode.StoryScene in episode.scenes:
			if scene.is_talk():
				for row: Episode.TalkLine in scene.lines:
					lines.append({"part": scene.part, "line": row})
			elif scene.is_battle():
				for cue: Episode.TalkCue in episode.cues:
					lines.append({"part": "cues", "line": cue.line})
		for row: Episode.TalkLine in episode.lost:
			lines.append({"part": "lost", "line": row})
		# 話の中で名乗る話（「(name)」。docs/story.md の「主人公の名前」）は、名を問う行までは、主人公を肩書きだけで呼ぶ（まだ名前が無い）。
		var unnamed := campaign.hero if episode.asks_hero_name() else ""
		for each: Dictionary in lines:
			var line: Episode.TalkLine = each["line"]
			var speaker := line.speaker_in(episode.speakers)
			for what: String in check_line(speaker, line.shown_text(), introduced, unnamed):
				found.append("%s [%s] %s: %s — %s" % [where, each["part"], speaker if speaker != "" else ">", line.text, what])
			# 選択肢の答えは、主人公の言うこと（会話の場面の答えの枠に出る）。主人公の台詞として見る。
			for option: Dictionary in line.options:
				for what: String in check_line(campaign.hero, String(option["text"]), introduced, unnamed):
					found.append("%s [%s] %s（答え）: %s — %s" % [where, each["part"], campaign.hero, option["text"], what])
			if line.asks_name:
				unnamed = ""
	return found


## 話し手 speaker の台詞 text を見る（speaker が "" なら地の文）。introduced は、名前と結びついた肩書き（物語ごとに 1 つ渡し、続けて使う）。
## unnamed は、まだ名乗っていない人の名前（その人の肩書きは、名前と結びつく前でも出てよい）。
func check_line(speaker: String, text: String, introduced: Dictionary, unnamed := "") -> PackedStringArray:
	var found := PackedStringArray()
	for title: String in titles:
		if not text.contains(title):
			continue
		if text.contains(titles[title]):
			introduced[title] = true
		elif not introduced.has(title) and titles[title] != unnamed:
			found.append("「%s」が、%s の名前と結びつく前に出ている（初めは名前と一緒に）" % [title, titles[title]])
	if not speakers.has(speaker):
		return found
	var entry: Dictionary = speakers[speaker]
	for word: String in pronouns:
		if entry["self"].has(word):
			continue
		var shape := RegEx.create_from_string(PRONOUN_SHAPES.get(word, word))
		if shape.search(text) != null:
			found.append("一人称「%s」（表は %s）" % [word, "・".join(entry["self"])])
	for word: String in entry["avoid"]:
		if text.contains(word):
			found.append("言わないことにした「%s」" % word)
	var at := 0
	while at < text.length():
		var hit := ""
		for term: String in terms:
			if text.substr(at, term.length()) == term:
				hit = term
				break
		if hit == "":
			at += 1
			continue
		at += hit.length()
		# 表に無い敬称が続いていれば、それも呼び方のうち（「騎士長さま」）。
		for suffix: String in SUFFIXES:
			if text.substr(at, suffix.length()) == suffix:
				hit += suffix
				at += suffix.length()
				break
		# 自分の名前と肩書き（名乗り）は見ない。
		if hit.contains(speaker) or titles.get(hit, "") == speaker:
			continue
		if not entry["allowed"].has(hit):
			found.append("呼び方「%s」が %s の表に無い" % [hit, speaker])
	return found
