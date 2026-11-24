extends "res://tests/base_test.gd"
## 兵が道順を歩く再生（game/battle_playback/playback_units.gd の walk）: 道順の全部を 1 つの Tween につなぎ、
## 曲がり角では向きを近いほうへ短く回す。人間の「スナイパーの動きだけカクついていないか」（Issue #46 の 11/23）から。
## マスごとに Tween を作って終わりを待つと、マスの境目ごとに 1 コマ止まり、曲がり角では向きが一瞬で替わっていた。

const Playback := preload("res://game/battle_playback.gd")
const BoardView := preload("res://game/board_view.gd")

const STEP := 0.05


func _walk(path: Array[Vector2i]) -> Dictionary:
	var view := Node3D.new()
	view.position = BoardView.cell_center(path[0])
	await settle(view)
	var tween := view.create_tween()
	Playback.walk(tween, view, path, STEP)
	var headings: Array[float] = [view.rotation.y]
	var still := 0
	var last := view.position
	var frames := 0
	while tween.is_running():
		await view.get_tree().process_frame
		frames += 1
		headings.append(view.rotation.y)
		if tween.is_running() and view.position.is_equal_approx(last):
			still += 1
		last = view.position
	var result := {"end": view.position, "heading": view.rotation.y, "headings": headings, "still": still, "frames": frames,
		"elapsed": tween.get_total_elapsed_time()}
	view.free()
	return result


func test_walks_the_whole_path_in_one_go() -> void:
	var path: Array[Vector2i] = [Vector2i(1, 3), Vector2i(1, 2), Vector2i(1, 1), Vector2i(0, 1), Vector2i(0, 0)]
	var walked: Dictionary = await _walk(path)
	assert_true((walked["end"] as Vector3).is_equal_approx(BoardView.cell_center(path[-1])), "道順の終わりに着いていない: %s" % walked["end"])
	assert_true(absf(float(walked["elapsed"]) - STEP * (path.size() - 1)) < 0.02,
		"1 マスの秒数 × マスの数で歩いていない（%.3f 秒）" % walked["elapsed"])
	assert_eq(walked["still"], 0, "歩いている途中で止まったコマがある")


## 曲がり角は、近いほうへ回る（北向きから西向きへは 90 度。反対回りの 270 度ではない）。最後は進んだ向きを向く。
func test_turns_the_short_way_at_corners() -> void:
	var path: Array[Vector2i] = [Vector2i(1, 2), Vector2i(1, 1), Vector2i(0, 1)]
	var walked: Dictionary = await _walk(path)
	var headings: Array = walked["headings"]
	var first: float = headings[0]
	var turned := 0.0
	for heading: float in headings:
		turned = maxf(turned, absf(heading - first))
	assert_true(turned <= PI / 2.0 + 0.01, "曲がり角で遠回りした（%.0f 度）" % rad_to_deg(turned))
	var step := BoardView.cell_center(path[2]) - BoardView.cell_center(path[1])
	assert_true(is_zero_approx(wrapf(float(walked["heading"]) - atan2(step.x, step.z), -PI, PI)), "最後の向きが、進んだ向きでない")
