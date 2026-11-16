extends "res://tests/base_test.gd"
## 地面と、盤の外の景色（game/board_view.gd、game/scenery.gd）。画面を出さずに確かめられる、置き方の決まり。

const BoardView := preload("res://game/board_view.gd")
const StageLook := preload("res://game/stage_look.gd")
const Scenery := preload("res://game/scenery.gd")
const OrbitCamera := preload("res://game/orbit_camera.gd")
const Maps := preload("res://tests/support/maps.gd")

const SIZE := Vector2i(30, 30)
const TEAM_COLORS: Array[Color] = [Color.BLUE, Color.RED]


func test_scenery_keeps_clear_of_the_board() -> void:
	for stage: StringName in StageLook.THEMES:
		var items := Scenery.layout(SIZE, 1, _scenery(stage))
		assert_true(items.size() > 200, "景色が少なすぎる（見た目 %s: %d）" % [stage, items.size()])
		for item in items:
			var at: Vector3 = item.position
			var distance := Scenery.distance_outside(Vector2(at.x, at.z), Vector2(SIZE))
			assert_true(distance >= Scenery.CLEAR, "盤の端のそばに置いている: %s" % at)
			assert_true(distance <= Scenery.REACH, "霞の向こうに置いている: %s" % at)


func test_scenery_never_rises_into_the_view_of_the_board() -> void:
	# カメラがいちばん浅い角度で見下ろしても、盤の中を見る視線より低い。
	assert_true(Scenery.HEIGHT_PER_DISTANCE < tan(deg_to_rad(OrbitCamera.MIN_PITCH)), "高さの決まりが、カメラの角度より急")
	for stage: StringName in StageLook.THEMES:
		var scenery := _scenery(stage)
		for item in Scenery.layout(SIZE, 2, scenery):
			var limit: float = item.distance * Scenery.HEIGHT_PER_DISTANCE
			var prop: Dictionary = scenery[item.role][item.index]
			assert_true(float(prop.height) * float(item.scale) <= limit + 0.001, "高すぎる: %s" % item)


func test_scenery_is_the_same_for_the_same_seed() -> void:
	var scenery := _scenery(StageLook.GRASSLAND)
	assert_eq(Scenery.layout(SIZE, 5, scenery), Scenery.layout(SIZE, 5, scenery))
	assert_ne(Scenery.layout(SIZE, 5, scenery), Scenery.layout(SIZE, 6, scenery))


func test_scenery_stays_light() -> void:
	# 置く数が増えすぎると、描画が重くなる。
	for stage: StringName in StageLook.THEMES:
		for look_seed in 3:
			var count := Scenery.layout(SIZE, look_seed, _scenery(stage)).size()
			assert_true(count < 3000, "景色が多すぎる（見た目 %s、種 %d: %d）" % [stage, look_seed, count])


func test_each_theme_is_complete() -> void:
	# どのステージの見た目も、全部の項目を持つ（ステージを足すときに、書き忘れが分かる）。
	for stage: StringName in StageLook.THEMES:
		var look := StageLook.of(stage)
		for key: StringName in StageLook.KEYS:
			assert_true(look.has(key), "見た目 %s の見た目に %s が無い" % [stage, key])
		for key: StringName in [StageLook.OBSTACLE_PROPS, StageLook.FOREST_PROPS]:
			var spec: Dictionary = look[key]
			assert_true(spec.style in [StageLook.SINGLE, StageLook.WALL, StageLook.CRAG], "見た目 %s の %s の置き方" % [stage, key])
			if spec.style == StageLook.CRAG:
				# 岩山は形をコードで作る。面の色だけ持つ。
				for color: String in ["low", "cliff", "top"]:
					assert_true(spec.get(color) is Color, "見た目 %s の %s の岩山の色 %s" % [stage, key, color])
				continue
			assert_true(spec.props.size() >= (3 if spec.style == StageLook.WALL else 1), "見た目 %s の %s の素材" % [stage, key])
			assert_true(spec.has("scale" if spec.style == StageLook.SINGLE else "height"), "見た目 %s の %s の大きさ" % [stage, key])
		var scenery: Dictionary = look[StageLook.SCENERY]
		for role: StringName in [StageLook.BIG, StageLook.SMALL, StageLook.SCATTER, StageLook.TINT]:
			assert_true(scenery.has(role), "見た目 %s の景色に %s が無い" % [stage, role])


func test_prop_heights_match_the_assets() -> void:
	# 素材の定義に書いた高さは、素材の形の高さと合う（景色の高さの決まりは、これで守る）。
	for prop in _all_props():
		var top := StageLook.mesh_of(prop).get_aabb().end.y
		assert_true(absf(top - float(prop.height)) < 0.03, "%s の高さ: 定義 %.2f、形 %.2f" % [prop.get("scene", "結晶"), prop.height, top])


func test_each_stage_tells_the_kinds_of_cells_apart() -> void:
	# 平地・森・障害物の地面の色は、どのステージでも、はっきり違う（置物に加えて、地面でも見分けられる）。
	for stage: StringName in StageLook.THEMES:
		var look := StageLook.of(stage)
		var colors: Array[Color] = [look[StageLook.NORMAL], look[StageLook.FOREST], look[StageLook.OBSTACLE]]
		for i in colors.size():
			for j in range(i + 1, colors.size()):
				var a := colors[i]
				var b := colors[j]
				var apart := Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()
				assert_true(apart > 0.15, "見た目 %s の地面の色 %d と %d が近い（%.2f）" % [stage, i, j, apart])


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
	assert_true(image.get_pixel(0, 0).is_equal_approx(_as_stored(StageLook.of(StageLook.DEFAULT)[StageLook.NORMAL])))


func test_each_stage_has_its_own_ground() -> void:
	# どのステージも、平地の色と霞の色がほかのステージと違う（一目で見分けられる）。
	var board := Maps.board([".F#*"])
	var normals := {}
	var hazes := {}
	for stage: StringName in StageLook.THEMES:
		var look := StageLook.of(stage)
		normals[look[StageLook.NORMAL]] = true
		hazes[look[StageLook.HAZE]] = true
		var image := BoardView.terrain_image(board, TEAM_COLORS, look)
		assert_true(image.get_pixel(0, 0).is_equal_approx(_as_stored(look[StageLook.NORMAL])), "見た目 %s の盤の外の色" % stage)
	assert_eq(normals.size(), StageLook.THEMES.size(), "平地の色が同じ見た目がある")
	assert_eq(hazes.size(), StageLook.THEMES.size(), "霞の色が同じ見た目がある")


func test_looks_are_named_and_every_versus_stage_has_one() -> void:
	# 見た目は名前で引く。対戦モードの生成のステージは、どれも自分の見た目を持つ（OF_STAGE）。
	for stage: BoardGenerator.Stage in BoardGenerator.Stage.values():
		assert_true(StageLook.THEMES.has(StageLook.name_of_stage(stage)), "ステージ %d の見た目が無い" % stage)
	assert_eq(StageLook.OF_STAGE.size(), BoardGenerator.Stage.size())
	assert_eq(StageLook.name_of_stage(-1), StageLook.DEFAULT, "知らないステージは既定の見た目")
	assert_eq(StageLook.of(&"no_such_look"), StageLook.of(StageLook.DEFAULT), "知らない名前は既定の見た目")


func _scenery(stage: StringName) -> Dictionary:
	return StageLook.of(stage)[StageLook.SCENERY]


## どのステージの見た目にも出てくる素材の全部。
func _all_props() -> Array[Dictionary]:
	var props: Array[Dictionary] = []
	for stage: StringName in StageLook.THEMES:
		var look := StageLook.of(stage)
		for key: StringName in [StageLook.OBSTACLE_PROPS, StageLook.FOREST_PROPS]:
			props.append_array(look[key].props)
		var scenery: Dictionary = look[StageLook.SCENERY]
		for role: StringName in [StageLook.BIG, StageLook.SMALL, StageLook.SCATTER]:
			props.append_array(scenery[role])
	return props


## 8 ビットに丸めた色。
func _as_stored(color: Color) -> Color:
	return Color8(color.r8, color.g8, color.b8)
