extends SceneTree
## ストーリーの台本の目次（game/story/README.md）を、物語のファイルから書き直す道具（tools/story_script.gd）。
## 話を足す・並べ替える・名前を変えたら回す。
## ついでに、通しの台本（build/story-script/。物語ごとに Markdown 1 つ。コミットしない）も書き出す。
##
##   tools/write_story_script.sh <godot>

const Story := preload("res://game/story.gd")
const Campaign := preload("res://game/campaign.gd")
const StoryScript := preload("res://tools/story_script.gd")


func _initialize() -> void:
	var problems := Story.load_problems()
	for problem in problems:
		printerr("story_script: %s" % problem)
	var index := FileAccess.open(StoryScript.INDEX, FileAccess.WRITE)
	index.store_string(StoryScript.index_text())
	index.close()
	print("story_script: %s（目次）" % StoryScript.INDEX)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(StoryScript.DIR))
	for campaign: Campaign in Story.campaigns():
		var path := StoryScript.path_of(campaign)
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(StoryScript.text_of(campaign))
		file.close()
		print("story_script: %s（%d 話）" % [path, campaign.episodes.size()])
	quit(0 if problems.is_empty() else 1)
