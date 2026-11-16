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


## 届くマス（菱形に並べた四角）。center のマスから半径 radius。マスの大きさは cell（px）。
func _move_cells(center: Vector2, radius: int, cell: float) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if (dx != 0 or dy != 0) and absi(dx) + absi(dy) <= radius:
				rects.append(Rect2(center + Vector2(dx, dy) * cell - Vector2(cell, cell) * 0.4, Vector2(cell, cell) * 0.8))
	return rects


func _region(rects: Array[Rect2]) -> Rect2:
	var region := rects[0]
	for rect in rects:
		region = region.merge(rect)
	return region


func _covered(rect: Rect2, cells: Array[Rect2]) -> int:
	var count := 0
	for cell in cells:
		if rect.intersects(cell):
			count += 1
	return count


func test_steps_outside_the_move_range_when_it_fills_the_neighborhood() -> void:
	# 動く前の駒。周りは届くマスで埋まっている。範囲の外に置けるなら、届くマスを 1 つも隠さない。
	var center := Vector2(640, 340)
	for radius: int in [3, 4, 5]:
		var cells := _move_cells(center, radius, 44.0)
		var obstacles: Array = []
		for cell in cells:
			obstacles.append([cell, 2.0])
		var placement := MenuPlacement.new()
		var anchor := _anchor(center)
		var rect := Rect2(placement.place(anchor, SIZE, AREA, obstacles, [], _region(cells)), SIZE)
		assert_eq(_covered(rect, cells), 0, "半径 %d の届くマスを隠した（%s）" % [radius, rect])
		assert_true(AREA.encloses(rect), "画面からはみ出した")


func test_hides_as_few_move_cells_as_it_can_when_the_range_fills_the_screen() -> void:
	# 範囲が画面いっぱいなら外へは出せない。それでも、駒の隣に置くより隠すマスを増やさない。
	var center := Vector2(640, 340)
	var cells := _move_cells(center, 16, 44.0)
	var obstacles: Array = []
	for cell in cells:
		obstacles.append([cell, 2.0])
	var near := Rect2(MenuPlacement.new().place(_anchor(center), SIZE, AREA, obstacles), SIZE)
	var rect := Rect2(MenuPlacement.new().place(_anchor(center), SIZE, AREA, obstacles, [], _region(cells)), SIZE)
	assert_true(_covered(rect, cells) <= _covered(near, cells), "範囲の外の候補を足して、隠すマスが増えた")
	assert_false(rect.intersects(_anchor(center)), "駒に重なった")
