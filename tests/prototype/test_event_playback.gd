extends "res://tests/base_test.gd"
## ルールのイベント（rules/events/）のどの種類にも、画面の側に再生するメソッドがあること。
## イベントを足したのに画面が再生しない、という状態を、ここで気付けるようにする。

const EVENTS_DIR := "res://rules/events"
const SCENE_SCRIPT := "res://prototype/battle_playback.gd"


func _event_scripts() -> Array[Script]:
	var scripts: Array[Script] = []
	for file in DirAccess.get_files_at(EVENTS_DIR):
		if file.ends_with(".gd"):
			var script: Script = load(EVENTS_DIR.path_join(file))
			if not script.is_abstract():
				scripts.append(script)
	return scripts


func test_every_event_has_a_player() -> void:
	var scene: GDScript = load(SCENE_SCRIPT)
	var players: Dictionary = scene.event_players()
	var methods := {}
	for method in scene.get_script_method_list():
		methods[method["name"]] = true
	var events := _event_scripts()
	assert_true(events.size() >= 12, "イベントのスクリプトを見つけられていない")
	for script in events:
		assert_true(players.has(script), "再生するメソッドが無い: %s" % script.resource_path)
		if players.has(script):
			assert_true(methods.has(String(players[script])), "メソッドが無い: %s" % players[script])
	assert_eq(players.size(), events.size(), "イベントでないものが載っている")
