extends "res://tests/base_test.gd"
## ストーリーの台本（tools/story_script.gd）。会話の正は話のファイルで、コミットするのは目次（game/story/README.md）だけ。
## 置いてある目次が、いまの物語のファイルから作り直したものと同じこと（話を足して、目次を作り直し忘れたら落ちる）。
## 通しの台本（コミットしない）は、作れることと、全部の文を順に持つことを確かめる。

const Story := preload("res://game/story.gd")
const Campaign := preload("res://game/campaign.gd")
const Episode := preload("res://game/episode.gd")
const StoryScript := preload("res://tools/story_script.gd")


func test_the_index_matches_the_story_files() -> void:
	var path := StoryScript.INDEX
	assert_true(FileAccess.file_exists(path), "目次が無い: %s（tools/write_story_script.sh で作る）" % path)
	var same := FileAccess.get_file_as_string(path) == StoryScript.index_text()
	assert_true(same, "%s が物語のファイルと食い違っている（tools/write_story_script.sh で作り直す）" % path)


## 目次のリンクは、どれも実際にある話のファイルを、話の順に指す。
func test_the_index_links_every_episode_in_order() -> void:
	var text := StoryScript.index_text()
	var at := 0
	for campaign: Campaign in Story.campaigns():
		for episode: Episode in campaign.episodes:
			var link := "[%s](%s/%s.txt)" % [episode.title, campaign.id, episode.id]
			var found := text.find(link, at)
			assert_true(found >= 0, "目次に %s が順に並んでいない" % link)
			assert_true(FileAccess.file_exists("res://game/story/%s/%s.txt" % [campaign.id, episode.id]), "話のファイルが無い: %s" % episode.id)
			at = maxi(at, found)


## 台本は、話の全部の文（会話、途中の台詞、覚えること）を、話の順に持つ。
func test_a_script_holds_every_line_in_order() -> void:
	for campaign: Campaign in Story.campaigns():
		var text := StoryScript.text_of(campaign)
		var at := 0
		for episode: Episode in campaign.episodes:
			var texts: Array[String] = [episode.title]
			if episode.lesson != "":
				texts.append(episode.lesson)
			for row: Episode.TalkLine in episode.before:
				texts.append(row.text)
			for cue: Episode.TalkCue in episode.cues:
				texts.append(cue.line.text)
			for row: Episode.TalkLine in episode.after + episode.lost:
				texts.append(row.text)
			for each in texts:
				var found := text.find(each, at)
				assert_true(found >= 0, "%s の台本に、%s の文が順に並んでいない: %s" % [campaign.id, episode.id, each])
				at = maxi(at, found)
