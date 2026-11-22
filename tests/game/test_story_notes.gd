extends "res://tests/base_test.gd"
## 話のファイルの頭に、仕上げの書き手のための覚え書き（この話の背骨の 3 行）があり、筋の文書（docs/story-outline.md）と同じ文であること。
## 人間の言葉「最初からほかのモデルに任せるのであれば、今のベースのストーリーを書き直させればいい」（Issue #49、11/22）から:
## 台詞の仕上げを頼むとき、話のファイル 1 つを渡せば、その場面で何が起きるかが一緒に渡る。

const Story := preload("res://game/story.gd")
const Campaign := preload("res://game/campaign.gd")
const Episode := preload("res://game/episode.gd")

const OUTLINE := "res://docs/story-outline.md"
const KEYS := ["起きること", "伝わること", "知る・変わる"]


## 筋の文書から、話の名前 -> {見出し: 文}。続きの行（頭に空白 2 つ）は、前の文につなぐ。
func _outline() -> Dictionary:
	var notes := {}
	var title := ""
	var key := ""
	var head := RegEx.create_from_string("^\\*\\*\\d+\\. (.+?)\\*\\*")
	var row := RegEx.create_from_string("^- (起きること|伝わること|知る・変わる): (.*)$")
	for line: String in FileAccess.get_file_as_string(OUTLINE).split("\n"):
		var found := head.search(line)
		if found != null:
			title = found.get_string(1)
			notes[title] = {}
			key = ""
		elif line.begins_with("## ") or line.begins_with("（"):
			title = ""
		elif title != "":
			found = row.search(line)
			if found != null:
				key = found.get_string(1)
				notes[title][key] = found.get_string(2).strip_edges()
			elif line.begins_with("  ") and key != "":
				notes[title][key] += line.strip_edges()
			else:
				key = ""
	return notes


func test_every_episode_carries_its_outline() -> void:
	var notes := _outline()
	for campaign: Campaign in Story.campaigns():
		for episode: Episode in campaign.episodes:
			assert_true(notes.has(episode.title), "筋の文書に、話「%s」が無い" % episode.title)
			if not notes.has(episode.title):
				continue
			var path := "res://game/story/%s/%s.txt" % [campaign.id, episode.id]
			var head := FileAccess.get_file_as_string(path).get_slice("[episode]", 0)
			for key: String in KEYS:
				assert_true(notes[episode.title].has(key), "筋の文書の「%s」に「%s」が無い" % [episode.title, key])
				var want := "# %s: %s\n" % [key, notes[episode.title].get(key, "")]
				assert_true(head.contains(want), "%s の頭の「%s」が、筋の文書（docs/story-outline.md）と違う。同じ文に直す" % [path, key])
