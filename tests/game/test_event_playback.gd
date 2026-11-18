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





## 見下ろすカメラの代わり。pitch は見下ろす角度（度）。盤の奥（z が小さい）ほど画面の上、高いほど画面の上。1 単位 = 50 画素。
## 返すのは [写し方, カメラの上の向き]。
func _camera(pitch: float) -> Array:
	var angle := deg_to_rad(pitch)
	var up := Vector3(0.0, cos(angle), -sin(angle))
	var project := func(point: Vector3) -> Vector2:
		# 画面の縦は、カメラの上の向きへの成分（上が小さい y）。
		return Vector2(point.x * 50.0, -point.dot(up) * 50.0)
	return [project, up]


## 浮かぶ文字（ダメージの数、スキルの名前など）は、まだ浮かんでいる文字と画面の上で重ねずに、その下から出す。
## 浅い角度でも、ほぼ真上から見下ろしても（文字はカメラへ向くので、縦の長さは角度で変わらない）。
func test_pop_labels_do_not_overlap_on_screen() -> void:
	var scene: GDScript = load(SCENE_SCRIPT)
	var glyph: float = scene.POP_FONT_SIZE * scene.POP_PIXEL_SIZE
	for pitch: float in [30.0, 55.0, 85.0]:
		var camera := _camera(pitch)
		var project: Callable = camera[0]
		var up: Vector3 = camera[1]
		var start := Vector3(2.5, 1.5, 3.5)
		assert_eq(scene.pop_start_position(start, 2, [], project, up), start, "何も浮かんでいないのに、ずらした")
		assert_eq(scene.pop_start_position(start, 2, [[Vector3(12.5, 1.5, 3.5), 2]], project, up), start, "画面の上で離れた文字のために、ずらした")
		# アドレナリン注射: 手前の行の駒の上のスキルの名前が昇っている間に、1 行奥の駒に「もう一度行動できる」を出す。
		# 同じマスに 2 つ浮かんでいるところにも出す。
		var cases := [
			[Vector3(13.5, 1.8, 21.5), [[Vector3(13.5, 2.6, 22.5), 8]]],
			[start, [[start, 3], [start - up * glyph * 1.3, 3]]],
			[start, [[start, 3]]],
		]
		for case: Array in cases:
			var at: Vector3 = scene.pop_start_position(case[0], 9, case[1], project, up)
			var screen: Vector2 = project.call(at)
			assert_true(screen.y >= (project.call(case[0]) as Vector2).y - 0.01, "%d 度: 上へずらした" % pitch)
			for entry: Array in case[1]:
				var other: Vector2 = project.call(entry[0])
				assert_true(absf(other.y - screen.y) >= glyph * 50.0 - 0.01, "%d 度: 画面の上で重なる: %s と %s" % [pitch, screen, other])


## 知らせの帯（必殺技など）が出ている間の浮かぶ文字は、昇りきるまで帯にかからない所から出す（帯の上の側なら上へ、下の側なら下へ）。
func test_pop_labels_keep_clear_of_the_banner() -> void:
	var scene: GDScript = load(SCENE_SCRIPT)
	var glyph: float = scene.POP_FONT_SIZE * scene.POP_PIXEL_SIZE
	for pitch: float in [30.0, 55.0, 85.0]:
		var camera := _camera(pitch)
		var project: Callable = camera[0]
		var up: Vector3 = camera[1]
		var start := Vector3(2.5, 1.5, 3.5)
		var middle: float = (project.call(start) as Vector2).y
		assert_eq(scene.pop_clear_of_band(start, Rect2(), project, up), start, "帯が出ていないのに、ずらした")
		var far := Rect2(-1000.0, middle - 400.0, 3000.0, 108.0)
		assert_eq(scene.pop_clear_of_band(start, far, project, up), start, "離れた帯のために、ずらした")
		for offset: float in [-60.0, -20.0, 0.0, 30.0, 70.0]:
			var band := Rect2(-1000.0, middle + offset - 54.0, 3000.0, 108.0)
			var at: Vector3 = scene.pop_clear_of_band(start, band, project, up)
			var from: Vector2 = project.call(at)
			var to: Vector2 = project.call(at + Vector3.UP * scene.POP_RISE)
			var line: float = ((project.call(at + up * glyph) as Vector2) - from).length()
			var half: float = line * scene.POP_LINE_SPACING / 2.0
			var top := minf(from.y, to.y) - half
			var bottom := maxf(from.y, to.y) + half
			assert_true(bottom <= band.position.y + 0.5 or top >= band.end.y - 0.5,
				"%d 度、帯との差 %d: 浮かぶ文字が帯にかかる（%.1f〜%.1f と %s）" % [pitch, offset, top, bottom, band])
			var went_up: bool = from.y < (project.call(start) as Vector2).y
			assert_eq(went_up, offset > 0.0, "%d 度、帯との差 %d: 近いほうの側へ逃がしていない" % [pitch, offset])
