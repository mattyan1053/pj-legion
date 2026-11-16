extends "res://tests/base_test.gd"
## 場面の並び（game/scene_flow.gd）。

const SceneFlow := preload("res://game/scene_flow.gd")
const Story := preload("res://game/story.gd")
const MatchChoice := preload("res://game/match_choice.gd")


func test_starts_at_the_title() -> void:
	assert_eq(SceneFlow.FIRST, &"title")
	assert_true(SceneFlow.has(SceneFlow.FIRST))


func test_goes_title_stage_setup_battle_and_back() -> void:
	assert_eq(SceneFlow.next(&"title", &"start"), &"stage")
	assert_eq(SceneFlow.next(&"stage", &"pick"), &"setup")
	assert_eq(SceneFlow.next(&"stage", &"back"), &"title")
	assert_eq(SceneFlow.next(&"setup", &"start"), &"", "対戦は、表ではなく流れ（match_choice.gd の run）で始める")
	assert_eq(MatchChoice.new().run().scene(), &"battle")
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
	# 流れで入る場面（対戦の設定の「対戦を始める」の流れと、ストーリーの話の流れの場面）も、そこからたどる。
	var reached := {SceneFlow.FIRST: true}
	var queue: Array[StringName] = [SceneFlow.FIRST]
	var runs: Array = [MatchChoice.new().run(), Story.new().run_now(Story.EPISODES[0])]
	for run: RefCounted in runs:
		while not run.is_done():
			if not reached.has(run.scene()):
				reached[run.scene()] = true
				queue.append(run.scene())
			run.advance()
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


func test_every_scene_but_the_title_names_where_the_menu_returns() -> void:
	# システムメニューの「戻る」は、行き先を書く（「対戦へ戻る」「会話へ戻る」など）。タイトルの上で開いたときだけ「戻る」のまま。
	for scene: StringName in SceneFlow.SCENES:
		if scene == SceneFlow.FIRST:
			continue
		var script: Script = load(SceneFlow.SCENES[scene]["script"])
		var names: Array = script.get_script_method_list().map(func(method: Dictionary) -> String: return method["name"])
		assert_true(names.has("resume_label"), "%s の場面に resume_label が無い（メニューの閉じるボタンが「戻る」になる）" % scene)


func test_scene_names_are_written_only_in_the_scene_flow() -> void:
	# 場面の名前（&"battle" など）を文字で書くのは scene_flow.gd だけ。ほかは SceneFlow の定数を使う（書き漏らすと、流れが渡すものを受け取れない）。
	# 終わり方（finished の outcome）や曲の名前は場面の名前と同じ文字のことがあるので、場面を指す書き方（流れに足す・場面へ行く・流れが渡すもの）だけを探す。
	var patterns: Array[String] = []
	for scene: StringName in SceneFlow.SCENES:
		for call: String in ["run_data(&\"%s\")", ".add(&\"%s\"", ".insert(&\"%s\"", "go(&\"%s\")", "current_id() == &\"%s\"", "current_id() != &\"%s\""]:
			patterns.append(call % scene)
	var paths := _scripts("res://game")
	paths.append_array(_scripts("res://tools"))
	for path: String in paths:
		if path.ends_with("scene_flow.gd"):
			continue
		var text := FileAccess.get_file_as_string(path)
		for pattern in patterns:
			assert_false(text.contains(pattern), "%s に場面の名前の直書き: %s" % [path, pattern.strip_edges()])


func _scripts(dir: String) -> Array[String]:
	var found: Array[String] = []
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"):
			found.append(dir.path_join(file))
	for sub in DirAccess.get_directories_at(dir):
		found.append_array(_scripts(dir.path_join(sub)))
	return found
