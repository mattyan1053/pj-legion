extends "res://tests/base_test.gd"
## ルールのイベント（rules/events/）のどの種類にも、画面の側に再生するメソッドがあること。
## イベントを足したのに画面が再生しない、という状態を、ここで気付けるようにする。

const EVENTS_DIR := "res://rules/events"
const SCENE_SCRIPT := "res://game/battle_playback.gd"


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




## 斜め上から見下ろすカメラの代わり: 盤の奥（z が小さい）ほど画面の上、高いほど画面の上。1 マス = 40 画素、高さ 1 = 50 画素。
func _project(point: Vector3) -> Vector2:
	return Vector2(point.x * 40.0, point.z * 40.0 - point.y * 50.0)


## 浮かぶ文字（ダメージの数、スキルの名前など）は、まだ浮かんでいる文字と画面の上で重ねずに、その下から出す。
func test_pop_labels_do_not_overlap_on_screen() -> void:
	var scene: GDScript = load(SCENE_SCRIPT)
	var start := Vector3(2.5, 1.5, 3.5)
	var project := _project
	assert_eq(scene.pop_start_height(start, 2, [], project), 1.5, "何も浮かんでいないのに、ずらした")
	assert_eq(scene.pop_start_height(start, 2, [[Vector3(12.5, 1.5, 3.5), 2]], project), 1.5, "画面の上で離れた文字のために、ずらした")
	# アドレナリン注射: 手前の行の駒の上のスキルの名前が昇っている間に、1 行奥の駒に「もう一度行動できる」を出す。
	# 盤の上の高さは違っても、画面の上では同じ行に来る（直す前は、ここで重なっていた）。
	var cases := [
		[Vector3(13.5, 1.8, 21.5), [[Vector3(13.5, 2.6, 22.5), 8]]],
		[start, [[Vector3(2.5, 1.5, 3.5), 3], [Vector3(2.5, 1.0, 3.5), 3]]],
	]
	var glyph: float = scene.POP_FONT_SIZE * scene.POP_PIXEL_SIZE
	for case: Array in cases:
		var at: Vector3 = case[0]
		var height: float = scene.pop_start_height(at, 9, case[1], project)
		assert_true(height <= at.y, "上へずらした")
		var screen := _project(Vector3(at.x, height, at.z))
		for entry: Array in case[1]:
			var other := _project(entry[0])
			assert_true(absf(other.y - screen.y) >= glyph * 50.0 - 0.01, "画面の上で重なる: %s と %s" % [screen, other])
