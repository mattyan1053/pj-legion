extends "res://tests/base_test.gd"
## 駒のそばのメニューの置き場所（game/menu_placement.gd）。画面の座標だけの計算。

const MenuPlacement := preload("res://game/menu_placement.gd")

const AREA := Rect2(0, 50, 1280, 590)
const SIZE := Vector2(130, 120)


func _anchor(center: Vector2) -> Rect2:
	return Rect2(center - Vector2(26, 40), Vector2(52, 80))


func test_default_is_right_of_the_unit() -> void:
	var placement := MenuPlacement.new()
	var anchor := _anchor(Vector2(600, 300))
	var at := placement.place(anchor, SIZE, AREA, [])
	assert_eq(at.x, anchor.end.x + MenuPlacement.GAP, "右隣に出ていない")
	assert_eq(at.y + SIZE.y / 2.0, anchor.get_center().y, "駒の高さにそろっていない")


func test_flips_at_the_right_edge() -> void:
	var placement := MenuPlacement.new()
	var anchor := _anchor(Vector2(1250, 300))
	var rect := Rect2(placement.place(anchor, SIZE, AREA, []), SIZE)
	assert_true(rect.end.x <= anchor.position.x, "右端で、左へ反転していない")


func test_never_leaves_the_area_and_never_covers_the_unit() -> void:
	# 四隅、辺の上、画面の外の駒。
	for center: Vector2 in [
		Vector2(10, 60), Vector2(1270, 60), Vector2(10, 630), Vector2(1270, 630),
		Vector2(640, 55), Vector2(640, 635), Vector2(-200, 300), Vector2(1500, 900),
	]:
		var placement := MenuPlacement.new()
		var anchor := _anchor(center)
		var rect := Rect2(placement.place(anchor, SIZE, AREA, []), SIZE)
		assert_true(AREA.encloses(rect), "画面からはみ出した: %s" % center)
		assert_false(rect.intersects(anchor), "駒に重なった: %s" % center)


func test_avoids_what_must_not_be_hidden() -> void:
	var placement := MenuPlacement.new()
	var anchor := _anchor(Vector2(600, 300))
	# 右隣に攻撃の相手、左隣に届くマス。どちらも隠さない下へ出る。
	var target := Rect2(660, 280, 50, 40)
	var move := Rect2(500, 280, 50, 40)
	var rect := Rect2(placement.place(anchor, SIZE, AREA, [[target, 10.0], [move, 1.0]]), SIZE)
	assert_false(rect.intersects(target), "攻撃の相手を隠した")
	assert_false(rect.intersects(move), "届くマスを隠した")
	assert_false(rect.intersects(anchor), "駒に重なった")


func test_prefers_hiding_a_move_cell_over_a_target() -> void:
	var placement := MenuPlacement.new()
	var anchor := _anchor(Vector2(600, 300))
	# 周りがすべて塞がっているなら、重みの小さいほう（届くマス）を隠す。
	var obstacles: Array = [[Rect2(0, 0, 1280, 720), 1.0], [Rect2(636, 0, 644, 720), 10.0]]
	var rect := Rect2(placement.place(anchor, SIZE, AREA, obstacles), SIZE)
	assert_true(rect.end.x <= 636.0, "重い側に出た")


func test_stays_on_the_same_side_for_a_small_gain() -> void:
	var placement := MenuPlacement.new()
	var anchor := _anchor(Vector2(600, 300))
	placement.place(anchor, SIZE, AREA, [[Rect2(660, 280, 50, 40), 10.0]])
	var side := placement.choice
	assert_ne(side, 0, "相手のいる右隣に出た")
	# 右隣が空いても、得が小さければ動かさない（カメラを回す間に、ちらつかないように）。
	placement.place(anchor, SIZE, AREA, [])
	assert_eq(placement.choice, side, "得が小さいのに、側を変えた")
	# 大きく損になれば動く。
	var now := Rect2(placement.position, SIZE)
	placement.place(anchor, SIZE, AREA, [[now, 10.0]])
	assert_ne(placement.choice, side, "隠してはいけないものの上に居座った")


func test_reset_forgets_the_side() -> void:
	var placement := MenuPlacement.new()
	var anchor := _anchor(Vector2(600, 300))
	placement.place(anchor, SIZE, AREA, [[Rect2(660, 280, 50, 40), 10.0]])
	placement.reset()
	placement.place(anchor, SIZE, AREA, [])
	assert_eq(placement.choice, 0, "忘れていない")


func test_slides_along_the_side_when_the_middle_is_taken() -> void:
	var placement := MenuPlacement.new()
	var anchor := _anchor(Vector2(600, 300))
	# 右隣の真横と、左・上・下がふさがっている。右隣のまま、下へずらして出る。
	var obstacles: Array = [[Rect2(640, 200, 200, 105), 10.0], [Rect2(300, 100, 330, 500), 10.0]]
	var rect := Rect2(placement.place(anchor, SIZE, AREA, obstacles), SIZE)
	assert_eq(rect.position.x, anchor.end.x + MenuPlacement.GAP, "右隣から離れた")
	for obstacle: Array in obstacles:
		assert_false(rect.intersects(obstacle[0]), "隠してはいけないものを隠した")
