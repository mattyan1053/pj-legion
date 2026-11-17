extends "res://tests/base_test.gd"
## ストーリーの台本（docs/story-script/。tools/story_script.gd）は、話のファイルから作った生成物。
## 置いてある台本が、いまの話のファイルから作り直したものと同じこと（話を直して、台本を作り直し忘れたら落ちる）。

const Story := preload("res://game/story.gd")
const Campaign := preload("res://game/campaign.gd")
const Episode := preload("res://game/episode.gd")
const StoryScript := preload("res://tools/story_script.gd")


func test_the_scripts_match_the_story_files() -> void:
	for campaign: Campaign in Story.campaigns():
		var path := StoryScript.path_of(campaign)
		assert_true(FileAccess.file_exists(path), "台本が無い: %s（tools/write_story_script.sh で作る）" % path)
		var same := FileAccess.get_file_as_string(path) == StoryScript.text_of(campaign)
		assert_true(same, "%s が話のファイルと食い違っている（tools/write_story_script.sh で作り直す）" % path)


## 台本は、話の全部の文（会話、途中の台詞、覚えること）を、話の順に持つ。
func test_a_script_holds_every_line_in_order() -> void:
	for campaign: Campaign in Story.campaigns():
		var text := StoryScript.text_of(campaign)
		var at := 0
		for episode: Episode in campaign.episodes:
			var texts: Array[String] = [episode.title]
			if episode.lesson != "":
				texts.append(episode.lesson)
			for row: Array in episode.before:
				texts.append(row[1])
			for cue: Array in episode.cues:
				texts.append(cue[3])
			for row: Array in episode.after:
				texts.append(row[1])
			for each in texts:
				var found := text.find(each, at)
				assert_true(found >= 0, "%s の台本に、%s の文が順に並んでいない: %s" % [campaign.id, episode.id, each])
				at = maxi(at, found)
