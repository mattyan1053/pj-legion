extends "res://tests/base_test.gd"
## 場面の並び（game/scene_flow.gd）。

const SceneFlow := preload("res://game/scene_flow.gd")


func test_starts_at_the_title() -> void:
	assert_eq(SceneFlow.FIRST, &"title")
	assert_true(SceneFlow.has(SceneFlow.FIRST))


func test_goes_title_stage_setup_battle_and_back() -> void:
	assert_eq(SceneFlow.next(&"title", &"start"), &"stage")
	assert_eq(SceneFlow.next(&"stage", &"pick"), &"setup")
	assert_eq(SceneFlow.next(&"stage", &"back"), &"title")
	assert_eq(SceneFlow.next(&"setup", &"start"), &"battle")
	assert_eq(SceneFlow.next(&"setup", &"back"), &"stage", "対戦の設定から 1 つ戻ると、ステージ選択")
	assert_eq(SceneFlow.next(&"battle", &"setup"), &"setup")
	assert_eq(SceneFlow.next(&"battle", &"title"), &"title", "どの場面からもタイトルへ戻れる")
	assert_eq(SceneFlow.next(&"setup", &"title"), &"title")


func test_title_opens_the_deck_screen_and_comes_back() -> void:
	assert_eq(SceneFlow.next(&"title", &"decks"), &"decks")
	assert_eq(SceneFlow.next(&"decks", &"back"), &"title")
	assert_eq(SceneFlow.next(&"decks", &"title"), &"title")


func test_undefined_transitions_go_nowhere() -> void:
	assert_eq(SceneFlow.next(&"title", &"back"), &"")
	assert_eq(SceneFlow.next(&"nowhere", &"start"), &"")
	assert_eq(SceneFlow.script_path(&"nowhere"), "")


func test_every_scene_is_reachable_and_loadable() -> void:
	# 行き先はどれも表にあり、スクリプトは場面の決まり（context と finished）を守る。
	var reached := {SceneFlow.FIRST: true}
	var queue: Array[StringName] = [SceneFlow.FIRST]
	while not queue.is_empty():
		var scene: StringName = queue.pop_front()
		var table: Dictionary = SceneFlow.SCENES[scene]["next"].merged(SceneFlow.COMMON)
		for outcome: StringName in table:
			var target: StringName = table[outcome]
			assert_true(SceneFlow.has(target), "%s の %s の行き先 %s が無い" % [scene, outcome, target])
			if SceneFlow.has(target) and not reached.has(target):
				reached[target] = true
				queue.append(target)
	for scene: StringName in SceneFlow.SCENES:
		assert_true(reached.has(scene), "%s へ行く道が無い" % scene)
		var script: Script = load(SceneFlow.script_path(scene))
		assert_true(script != null and script.can_instantiate(), "%s のスクリプトが読めない" % scene)
		if script == null:
			continue
		var names: Array[String] = []
		for signal_info: Dictionary in script.get_script_signal_list():
			names.append(signal_info["name"])
		assert_true(names.has("finished"), "%s に finished が無い" % scene)
		var properties: Array[String] = []
		for property: Dictionary in script.get_script_property_list():
			properties.append(property["name"])
		assert_true(properties.has("context"), "%s に context が無い" % scene)
