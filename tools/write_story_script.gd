extends SceneTree
## ストーリーの台本（docs/story-script/。物語ごとに Markdown 1 つ）を、話のファイルから書き直す道具（tools/story_script.gd）。
## 話のファイル（game/story/）を直したら回す。
##
##   tools/write_story_script.sh <godot>

const Story := preload("res://game/story.gd")
const Campaign := preload("res://game/campaign.gd")
const StoryScript := preload("res://tools/story_script.gd")


func _initialize() -> void:
	var problems := Story.load_problems()
	for problem in problems:
		printerr("story_script: %s" % problem)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(StoryScript.DIR))
	for campaign: Campaign in Story.campaigns():
		var path := StoryScript.path_of(campaign)
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(StoryScript.text_of(campaign))
		file.close()
		print("story_script: %s（%d 話）" % [path, campaign.episodes.size()])
	quit(0 if problems.is_empty() else 1)
