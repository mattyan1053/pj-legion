extends "res://tests/base_test.gd"
## 盤面を見下ろすカメラ（game/orbit_camera.gd）の、ドラッグと見下ろす角度。
## 木に入れずに組み立て、_process を手で進める。

const OrbitCamera := preload("res://game/orbit_camera.gd")

const FRAME := 1.0 / 60.0


func _make_rig() -> OrbitCamera:
	var rig := OrbitCamera.new()
	rig._pivot = Node3D.new()
	rig.add_child(rig._pivot)
	rig.camera = Camera3D.new()
	rig._pivot.add_child(rig.camera)
	rig._pivot.rotation_degrees.x = -rig.target_pitch()
	return rig


func _step(rig: OrbitCamera, frames: int) -> void:
	for i in frames:
		rig._process(FRAME)


func test_horizontal_drag_turns_and_vertical_drag_tilts() -> void:
	var rig := _make_rig()
	var pitch := rig.target_pitch()
	rig.drag(Vector2(50, 0))
	assert_eq(rig.target_yaw(), -50 * rig.drag_sensitivity, "右へのドラッグで、盤が右へ回る（カメラが左へ回り込む）向きになっていない")
	assert_eq(rig.target_pitch(), pitch, "横のドラッグで、見下ろす角度が変わった")
	rig.drag(Vector2(0, 50))
	assert_true(rig.target_pitch() > pitch, "下へのドラッグで、真上に近づかない")
	assert_eq(rig.target_yaw(), -50 * rig.drag_sensitivity, "縦のドラッグで、向きが変わった")
	rig.free()


func test_both_axes_share_the_sensitivity() -> void:
	var rig := _make_rig()
	rig.drag_sensitivity = 0.004
	var pitch := rig.target_pitch()
	rig.drag(Vector2(30, 30))
	assert_eq(rig.target_yaw(), -30 * 0.004)
	assert_true(is_equal_approx(rig.target_pitch() - pitch, rad_to_deg(30 * 0.004)), "縦の 1 px あたりの量が、横と違う")
	rig.free()


func test_pitch_stays_between_the_limits() -> void:
	var rig := _make_rig()
	rig.drag(Vector2(0, 5000))
	assert_eq(rig.target_pitch(), OrbitCamera.MAX_PITCH)
	_step(rig, 300)
	assert_between(rig.current_pitch(), OrbitCamera.MAX_PITCH - 0.1, OrbitCamera.MAX_PITCH)
	rig.drag(Vector2(0, -5000))
	assert_eq(rig.target_pitch(), OrbitCamera.MIN_PITCH)
	_step(rig, 300)
	assert_between(rig.current_pitch(), OrbitCamera.MIN_PITCH, OrbitCamera.MIN_PITCH + 0.1)
	assert_true(OrbitCamera.MIN_PITCH <= OrbitCamera.PITCH_PRESETS[0], "R の段が、ドラッグの範囲の外にある")
	assert_true(OrbitCamera.PITCH_PRESETS[-1] <= OrbitCamera.MAX_PITCH, "R の段が、ドラッグの範囲の外にある")
	rig.free()


func test_pitch_preset_continues_from_the_dragged_angle() -> void:
	var presets := OrbitCamera.PITCH_PRESETS
	assert_eq(OrbitCamera.next_pitch_preset(presets[0]), presets[1])
	assert_eq(OrbitCamera.next_pitch_preset(presets[1]), presets[2])
	assert_eq(OrbitCamera.next_pitch_preset(presets[2]), presets[0], "いちばん深い段のあと、浅い段へ戻らない")
	# ドラッグで段の間にしたら、そこより深い次の段へ。
	assert_eq(OrbitCamera.next_pitch_preset((presets[0] + presets[1]) / 2.0), presets[1])
	assert_eq(OrbitCamera.next_pitch_preset(OrbitCamera.MIN_PITCH), presets[0])
	assert_eq(OrbitCamera.next_pitch_preset(OrbitCamera.MAX_PITCH), presets[0])


func test_tilting_is_smooth() -> void:
	var rig := _make_rig()
	var before := rig.current_pitch()
	rig.drag(Vector2(0, 400))
	_step(rig, 1)
	var moved := rig.current_pitch() - before
	assert_true(moved > 0.0 and moved < (rig.target_pitch() - before) * 0.5, "1 フレームで角度が跳んだ（%s 度）" % moved)
	rig.free()


func test_drag_while_following_keeps_following_without_jumping() -> void:
	var rig := _make_rig()
	var walker := Node3D.new()
	walker.position = Vector3(12, 0, 9)
	rig.follow(walker)
	_step(rig, 5)
	var position := rig.position
	rig.drag(Vector2(80, -60))
	_step(rig, 1)
	assert_eq(rig.focus_point(), walker.position, "ドラッグで、追うのをやめた")
	assert_true(rig.position.distance_to(position) < position.distance_to(walker.position), "ドラッグで、位置が跳んだ")
	# ドラッグの途中から追い始めても、角度は行き先へ滑らかに移るだけ。
	var pitch := rig.target_pitch()
	walker.position = Vector3(3, 0, 20)
	rig.drag(Vector2(0, 20))
	_step(rig, 120)
	assert_true(rig.position.distance_to(walker.position) < 0.5, "追いかけた先へ寄っていない")
	assert_between(rig.current_pitch(), rig.target_pitch() - 0.1, rig.target_pitch() + 0.1)
	assert_true(rig.target_pitch() > pitch)
	walker.free()
	rig.free()


func test_inverted_vertical_drag_tilts_the_other_way() -> void:
	# 設定の「縦のドラッグを逆にする」。横の向きは変わらない。
	var rig := _make_rig()
	rig.invert_vertical = true
	var pitch := rig.target_pitch()
	rig.drag(Vector2(0, 50))
	assert_true(rig.target_pitch() < pitch, "逆にしても、下へのドラッグで真上に近づいた")
	rig.drag(Vector2(50, 0))
	assert_eq(rig.target_yaw(), -50 * rig.drag_sensitivity, "逆にすると、横の向きまで変わった")
	rig.free()


func test_disabled_controls_ignore_keys() -> void:
	# システムメニューを開いている間は、キーで視点が動かない。
	var rig := _make_rig()
	rig.controls_enabled = false
	var key := InputEventKey.new()
	key.pressed = true
	key.physical_keycode = KEY_E
	rig._unhandled_input(key)
	assert_eq(rig.target_yaw(), 0.0, "止めているのに、キーで回った")
	rig.controls_enabled = true
	rig._unhandled_input(key)
	assert_eq(rig.target_yaw(), PI / 2.0, "キーで回らない")
	rig.free()


func test_the_farthest_view_follows_the_board_size() -> void:
	assert_eq(OrbitCamera.max_distance_for(Vector2i(30, 30)), OrbitCamera.MAX_DISTANCE, "いつもの盤は、これまでと同じだけ引ける")
	assert_eq(OrbitCamera.max_distance_for(Vector2i(40, 36)), OrbitCamera.MAX_DISTANCE, "大きい盤でも、上限は超えない")
	assert_between(OrbitCamera.max_distance_for(Vector2i(17, 22)), 30.0, 36.0, "小さい盤は、盤の大きさに合わせて寄せる")
	assert_eq(OrbitCamera.max_distance_for(Vector2i(6, 4)), OrbitCamera.MIN_MAX_DISTANCE)
	var rig := _make_rig()
	rig.set_view(OrbitCamera.MAX_DISTANCE, 0.0)
	rig.fit_board(Vector2i(17, 22))
	assert_eq(rig.max_distance, OrbitCamera.max_distance_for(Vector2i(17, 22)))
	assert_eq(rig.bounds, Rect2(0.0, 0.0, 17.0, 22.0))
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	for i in 20:
		rig._unhandled_input(wheel)
	_step(rig, 600)
	assert_between(rig.camera.position.z, rig.max_distance - 0.05, rig.max_distance + 0.05, "ホイールで、盤に合わせた上限より引けた")
	rig.free()


## ずらし（view_shift）: 寄せた点の手前（画面の下の方向）を真ん中にする。寄せた先（focus_point）は、寄せた点のまま。
func test_view_shift_puts_the_focus_above_the_middle() -> void:
	var rig := _make_rig()
	rig.view_shift = 2.0
	rig.jump_to(Vector3(5.0, 0.0, 5.0))
	assert_eq(rig.position, Vector3(5.0, 0.0, 7.0), "すぐに移るときも、手前へずらした所が真ん中")
	assert_eq(rig.focus_point(), Vector3(5.0, 0.0, 5.0), "寄せた先は、寄せた点")
	rig.focus_on(Vector3(8.0, 0.0, 3.0))
	assert_eq(rig.focus_point(), Vector3(8.0, 0.0, 3.0), "寄っている途中も、寄せた先は寄せた点")
	_step(rig, 120)
	assert_true(rig.position.distance_to(Vector3(8.0, 0.0, 5.0)) < 0.05, "寄り終わると、手前へずらした所が真ん中: %s" % rig.position)
	rig.free()
