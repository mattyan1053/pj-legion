extends "res://game/battle_playback/playback_skills.gd"
## 台本の出来事（カットシーンの台本だけが出す。game/cut_events/。docs/battle-view.md の「盤のカットシーン」）の再生:
## 光を出さずに置く、倒れずに去る、向きを変える、カメラを寄せる、歩く速さ、待つ。

## 去る兵が薄れて消えるまでの秒数、向きを変える秒数、カメラを寄せてから次へ進むまでの秒数。
const CUT_FADE_TIME := 0.35
const CUT_TURN_TIME := 0.2
const CUT_CAMERA_TIME := 0.6


func _play_cut_placed(event: CutPlacedEvent) -> void:
	var at := BoardView.cell_center(event.cell)
	var view: UnitView = UnitView.new()
	view.position = at
	_stage.add_child(view)
	view.setup(event.kind, team_colors[event.side], event.hp, event.max_hp, unit_looks.get(event.unit_id, &""))
	view.face(BoardView.cell_center(event.cell + Vector2i.DOWN) - at)
	_views[event.unit_id] = view


## 道順を歩いてから（道順が 1 マスなら、その場で）、薄れて消える。
func _play_cut_left(event: CutLeftEvent) -> void:
	var view := _view(event.unit_id)
	_views.erase(event.unit_id)
	if event.path.size() >= 2:
		view.play_run()
		var walking := create_tween()
		walk(walking, view, event.path, cut_step_time if cut_step_time > 0.0 else STEP_TIME)
		await walking.finished
		view.play_idle()
	var fade := create_tween()
	fade.tween_property(view, "scale", Vector3(0.6, 0.0, 0.6), CUT_FADE_TIME).set_ease(Tween.EASE_IN)
	await fade.finished
	view.queue_free()


func _play_cut_turned(event: CutTurnedEvent) -> void:
	var view := _view(event.unit_id)
	var step := BoardView.cell_center(event.toward) - view.position
	if Vector2(step.x, step.z).length() < 0.001:
		return
	var want := view.rotation.y + wrapf(atan2(step.x, step.z) - view.rotation.y, -PI, PI)
	var turn := create_tween()
	turn.tween_property(view, "rotation:y", want, CUT_TURN_TIME)
	await turn.finished


func _play_cut_camera(event: CutCameraEvent) -> void:
	_rig.focus_on(BoardView.cell_center(event.cell))
	await after(CUT_CAMERA_TIME)


func _play_cut_pace(event: CutPaceEvent) -> void:
	cut_step_time = event.step_time


func _play_cut_wait(event: CutWaitEvent) -> void:
	await after(event.seconds)
