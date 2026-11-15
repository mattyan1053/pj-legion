extends "res://tests/base_test.gd"
## 地面と、盤の外の景色（prototype/board_view.gd、prototype/scenery.gd）。画面を出さずに確かめられる、置き方の決まり。

const BoardView := preload("res://prototype/board_view.gd")
const Scenery := preload("res://prototype/scenery.gd")
const OrbitCamera := preload("res://prototype/orbit_camera.gd")
const Maps := preload("res://tests/support/maps.gd")

const SIZE := Vector2i(30, 30)
const TEAM_COLORS: Array[Color] = [Color.BLUE, Color.RED]


func test_scenery_keeps_clear_of_the_board() -> void:
	var items := Scenery.layout(SIZE, 1)
	assert_true(items.size() > 200, "景色が少なすぎる（%d）" % items.size())
	for item in items:
		var at: Vector3 = item.position
		var distance := Scenery.distance_outside(Vector2(at.x, at.z), Vector2(SIZE))
		assert_true(distance >= Scenery.CLEAR, "盤の端のそばに置いている: %s" % at)
		assert_true(distance <= Scenery.REACH, "霞の向こうに置いている: %s" % at)


func test_scenery_never_rises_into_the_view_of_the_board() -> void:
	# カメラがいちばん浅い角度で見下ろしても、盤の中を見る視線より低い。
	var lowest: float = OrbitCamera.PITCH_PRESETS.min()
	assert_true(Scenery.HEIGHT_PER_DISTANCE < tan(deg_to_rad(lowest)), "高さの決まりが、カメラの角度より急")
	for item in Scenery.layout(SIZE, 2):
		var limit: float = item.distance * Scenery.HEIGHT_PER_DISTANCE
		assert_true(Scenery.height_of(item) <= limit + 0.001, "高すぎる: %s" % item)


func test_scenery_is_the_same_for_the_same_seed() -> void:
	assert_eq(Scenery.layout(SIZE, 5), Scenery.layout(SIZE, 5))
	assert_ne(Scenery.layout(SIZE, 5), Scenery.layout(SIZE, 6))


func test_scenery_stays_light() -> void:
	# 置く数が増えすぎると、描画が重くなる。
	for look_seed in 5:
		assert_true(Scenery.layout(SIZE, look_seed).size() < 3000, "景色が多すぎる（種 %d）" % look_seed)


func test_terrain_image_follows_the_board() -> void:
	var board := Maps.board([
		".#.",
		"F*.",
	])
	var image := BoardView.terrain_image(board, TEAM_COLORS)
	var pad := BoardView.MAP_PAD * BoardView.MAP_SCALE
	assert_eq(image.get_size(), (board.size + Vector2i.ONE * 2 * BoardView.MAP_PAD) * BoardView.MAP_SCALE)
	for y in board.size.y:
		for x in board.size.x:
			var cell := Vector2i(x, y)
			var pixel := Vector2i(pad, pad) + cell * BoardView.MAP_SCALE + Vector2i.ONE * (BoardView.MAP_SCALE / 2)
			var expected := BoardView.ground_color(board, cell, TEAM_COLORS)
			assert_true(image.get_pixelv(pixel).is_equal_approx(_as_stored(expected)), "マス %s の色が違う" % cell)
	# 盤の外は、平地の色で続く。
	assert_true(image.get_pixel(0, 0).is_equal_approx(_as_stored(BoardView.COLOR_NORMAL)))


## 8 ビットに丸めた色。
func _as_stored(color: Color) -> Color:
	return Color8(color.r8, color.g8, color.b8)
