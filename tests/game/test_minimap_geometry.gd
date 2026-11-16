extends "res://tests/base_test.gd"
## ミニマップの計算（game/minimap_geometry.gd）: 置き場所、盤とミニマップの座標、カメラが見ている範囲。

const Geometry := preload("res://game/minimap_geometry.gd")
const MenuPlacement := preload("res://game/menu_placement.gd")
const BattleHud := preload("res://game/battle_hud.gd")
const OrbitCamera := preload("res://game/orbit_camera.gd")
const Settings := preload("res://game/settings.gd")

const SCREEN := Vector2(1280, 720)
## 視点の案内の下の端（battle_hud.gd の上の帯の下に、1 行の案内）。
const GUIDE_BOTTOM := 80.0
const FOV := 35.0


## OrbitCamera と同じ組み方のカメラ: 見ている地点 look、向き yaw（度）、見下ろす角度 pitch（度）、距離 distance。
func _camera(look: Vector3, yaw: float, pitch: float, distance: float) -> Transform3D:
	var basis := Basis(Vector3.UP, deg_to_rad(yaw)) * Basis(Vector3.RIGHT, deg_to_rad(-pitch))
	return Transform3D(basis, look + basis * Vector3(0.0, 0.0, distance))


func _quad(camera: Transform3D) -> PackedVector2Array:
	return Geometry.view_quad(camera.origin, camera.basis, FOV, SCREEN.x / SCREEN.y)


func test_a_cell_is_a_whole_number_of_pixels_that_fits_the_largest_side() -> void:
	assert_eq(Geometry.cell_px(Vector2i(30, 30)), 5)
	assert_eq(Geometry.cell_px(Vector2i(22, 22)), 6)
	assert_eq(Geometry.cell_px(Vector2i(9, 5)), 16)
	for board_size: Vector2i in [Vector2i(30, 30), Vector2i(22, 22), Vector2i(30, 22)]:
		var size := Geometry.map_size(board_size)
		assert_true(maxf(size.x, size.y) <= Geometry.MAX_SIDE + Geometry.PADDING * 2.0, "%s" % board_size)


func test_it_sits_at_the_right_edge_below_the_guide_and_stays_on_screen() -> void:
	for board_size: Vector2i in [BoardGenerator.DEFAULT_SIZE, BoardGenerator.MIN_SIZE, Vector2i(9, 5)]:
		var rect := Geometry.place(SCREEN, board_size, GUIDE_BOTTOM)
		assert_true(Rect2(Vector2.ZERO, SCREEN).encloses(rect), "画面に収まる（%s）" % board_size)
		assert_true(is_equal_approx(rect.end.x, SCREEN.x - Geometry.MARGIN), "右の端に寄せる")
		assert_true(rect.position.y > GUIDE_BOTTOM, "視点の案内より下")
		# 上の帯・下の帯に重ならない。
		assert_true(rect.position.y >= BattleHud.TOP_BAR_HEIGHT)
		assert_true(rect.end.y <= SCREEN.y - BattleHud.BOTTOM_BAR_HEIGHT)


func test_board_and_map_points_go_both_ways() -> void:
	var board_size := Vector2i(30, 30)
	for point: Vector2 in [Vector2.ZERO, Vector2(15, 15), Vector2(30, 30), Vector2(3.5, 27.25)]:
		assert_true(Geometry.to_board(Geometry.to_map(point, board_size), board_size).is_equal_approx(point), "%s" % point)
	assert_true(Geometry.to_map(Vector2.ZERO, board_size).is_equal_approx(Vector2.ONE * Geometry.PADDING), "盤の左上は、縁の内側の角")
	# 縁や外を押しても、盤の中に収める。
	assert_eq(Geometry.to_board(Vector2(-20, -20), board_size), Vector2.ZERO)
	assert_eq(Geometry.to_board(Vector2(500, 500), board_size), Vector2(30, 30))


func test_from_straight_above_it_sees_a_screen_shaped_rectangle_around_the_look_point() -> void:
	var look := Vector3(10, 0, 12)
	var quad := _quad(_camera(look, 0.0, 90.0, 20.0))
	var half_height := 20.0 * tan(deg_to_rad(FOV / 2.0))
	var half_width := half_height * SCREEN.x / SCREEN.y
	# 左下・右下・右上・左上。向き 0 では、画面の上が盤の奥（z の小さいほう）。
	var expected := [Vector2(-half_width, half_height), Vector2(half_width, half_height),
		Vector2(half_width, -half_height), Vector2(-half_width, -half_height)]
	for i in 4:
		assert_true(quad[i].is_equal_approx(Vector2(look.x, look.z) + expected[i]), "隅 %d: %s" % [i, quad[i]])


func test_a_tilted_camera_sees_a_trapezoid_wider_far_away_that_holds_the_look_point() -> void:
	var look := Vector3(15, 0, 15)
	for pitch: float in [OrbitCamera.MIN_PITCH, OrbitCamera.DEFAULT_PITCH, 68.0]:
		var quad := _quad(_camera(look, 0.0, pitch, 22.0))
		var near := quad[0].distance_to(quad[1])
		var far := quad[2].distance_to(quad[3])
		assert_true(far > near, "遠い辺ほど長い（%s 度）" % pitch)
		assert_true(quad[2].y < look.z and quad[0].y > look.z, "奥が上、手前が下（%s 度）" % pitch)
		assert_true(Geometry2D.is_point_in_polygon(Vector2(look.x, look.z), quad), "見ている地点を含む（%s 度）" % pitch)


func test_turning_the_camera_turns_the_seen_area() -> void:
	var look := Vector3(15, 0, 15)
	var straight := _quad(_camera(look, 0.0, 50.0, 22.0))
	var turned := _quad(_camera(look, 90.0, 50.0, 22.0))
	for i in 4:
		# 向きを 90 度回すと、見ている範囲も見ている地点の周りに 90 度回る。
		var expected := (straight[i] - Vector2(look.x, look.z)).rotated(-PI / 2.0) + Vector2(look.x, look.z)
		assert_true(turned[i].is_equal_approx(expected), "隅 %d: %s / %s" % [i, turned[i], expected])


func test_rays_that_miss_the_ground_stop_at_the_reach() -> void:
	# 水平より上を向いた光線（見下ろしていないカメラ）は、地面に当たらない。
	var level := Transform3D(Basis(), Vector3(5, 3, 5))
	var quad := Geometry.view_quad(level.origin, level.basis, FOV, SCREEN.x / SCREEN.y)
	for point in quad:
		assert_true(point.distance_to(Vector2(5, 5)) <= Geometry.REACH + 0.01, "%s" % point)


func test_the_drawn_area_is_cut_to_the_board() -> void:
	var board_size := Vector2i(30, 30)
	var board := Rect2(Vector2.ZERO, Vector2(board_size)).grow(0.001)
	# 盤の端を見ている（いちばん浅い角度）: 盤の外の部分は落とす。
	var clipped := Geometry.clip_to_board(_quad(_camera(Vector3(29, 0, 1), 0.0, OrbitCamera.MIN_PITCH, 30.0)), board_size)
	assert_true(clipped.size() >= 3)
	for point in clipped:
		assert_true(board.has_point(point), "%s" % point)
	# 盤から外れたところしか見ていなければ、描かない。
	assert_eq(Geometry.clip_to_board(_quad(_camera(Vector3(80, 0, 80), 0.0, 90.0, 10.0)), board_size).size(), 0)


func test_the_unit_menu_is_never_placed_over_the_minimap() -> void:
	# 右上の隅の駒（ミニマップのすぐそば）のメニュー。ミニマップを「重ねない四角」として渡す。
	var minimap := Geometry.place(SCREEN, BoardGenerator.DEFAULT_SIZE, GUIDE_BOTTOM)
	var area := Rect2(4.0, BattleHud.TOP_BAR_HEIGHT + 4.0, SCREEN.x - 8.0, SCREEN.y - BattleHud.TOP_BAR_HEIGHT - BattleHud.BOTTOM_BAR_HEIGHT - 8.0)
	var menu_size := Vector2(150, 140)
	for anchor: Rect2 in [Rect2(minimap.position.x - 50.0, minimap.get_center().y, 40, 60), Rect2(minimap.get_center().x, minimap.end.y + 4.0, 40, 60)]:
		var placement := MenuPlacement.new()
		var at := placement.place(anchor, menu_size, area, [], [minimap])
		assert_false(Rect2(at, menu_size).intersects(minimap), "メニューがミニマップに重なった: %s" % at)
		assert_true(area.encloses(Rect2(at, menu_size)), "メニューが画面に収まる")


func test_it_is_shown_unless_the_setting_turns_it_off() -> void:
	var settings := Settings.new()
	assert_eq(settings.value(Settings.SHOW_MINIMAP), true, "既定は出す")
	settings.set_value(Settings.SHOW_MINIMAP, false)
	var restored := Settings.new()
	restored.from_dict(settings.to_dict())
	assert_eq(restored.value(Settings.SHOW_MINIMAP), false, "取っておいた値を読める")
