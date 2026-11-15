extends "res://tests/base_test.gd"
## 戦闘予測のパネルと駒のそばのメニューの置き場所（game/menu_placement.gd を panel_layout.gd と同じに呼ぶ）。
## カメラの向き・盤面の位置（画面の端、帯のそば）・駒の位置を総当たりして、予測のパネルがメニューに重ならず、
## 画面（上下の帯の内側）からはみ出さず、対象の駒と行動する駒をなるべく隠さないこと。
## 画面への投影は、俯瞰のカメラを真似た簡単な式（ノードを使わない）。

const MenuPlacement := preload("res://game/menu_placement.gd")

## battle_hud.gd の menu_area() と同じ（1280×720、上の帯 50、下の帯 92）。
const AREA := Rect2(4, 54, 1272, 570)
const MENU_SIZE := Vector2(140, 170)
## 予測のパネル（幅は forecast_panel.gd の WIDTH に余白を足したもの）。低いもの、高いもの（帯の内側の 6 割）。
const FORECAST_SIZES: Array[Vector2] = [Vector2(266, 170), Vector2(266, 340)]
const BOARD := Vector2i(9, 5)
## 駒の高さ（マス 1 つを 1 として）。
const UNIT_HEIGHT := 1.2


## 盤面の上の点（マスの単位。h は高さ）が画面に出る位置。yaw はカメラの向き、scale は 1 マスの px、origin は盤の中央が出る位置。
static func _project(at: Vector2, h: float, yaw: float, scale: float, origin: Vector2) -> Vector2:
	var centered := at - Vector2(BOARD) / 2.0
	var turned := centered.rotated(yaw)
	return origin + Vector2(turned.x * scale, turned.y * scale * 0.6 - h * scale * 0.8)


## 駒が画面に占める四角（panel_layout.gd の screen_rect と同じく、半径 radius の柱）。
static func _unit_rect(cell: Vector2i, radius: float, yaw: float, scale: float, origin: Vector2) -> Rect2:
	var center := Vector2(cell) + Vector2(0.5, 0.5)
	var rect := Rect2(_project(center, 0.0, yaw, scale, origin), Vector2.ZERO)
	for corner: Vector2 in [Vector2(radius, 0), Vector2(-radius, 0), Vector2(0, radius), Vector2(0, -radius)]:
		rect = rect.expand(_project(center + corner, 0.0, yaw, scale, origin))
		rect = rect.expand(_project(center + corner, UNIT_HEIGHT, yaw, scale, origin))
	return rect


## PR ごとの検査: 盤の四隅・辺の中央・中央の駒と、隣の対象を、12 の向きで。
func test_forecast_never_covers_the_menu_nor_leaves_the_screen() -> void:
	var actors: Array[Vector2i] = []
	for y: int in [0, 2, 4]:
		for x: int in [0, 4, 8]:
			actors.append(Vector2i(x, y))
	_sweep(actors, 1, false)


## 長い検査: すべてのマスの駒と、2 マスまでの対象を、2 つの大きさのパネルで。
func test_long_forecast_never_covers_the_menu_nor_leaves_the_screen() -> void:
	_sweep(_cells(), 2, true)


## 向き・1 マスの大きさ・盤の位置・駒・対象を総当たりする。対象は駒から reach マスまで。
## every_size なら、パネルの大きさを全部試す（でなければ、組み合わせごとに 1 つを順に）。
func _sweep(actors: Array[Vector2i], reach: int, every_size: bool) -> void:
	var origins: Array[Vector2] = [
		AREA.get_center(),
		Vector2(AREA.position.x + 120, AREA.get_center().y), Vector2(AREA.end.x - 120, AREA.get_center().y),
		Vector2(AREA.get_center().x, AREA.position.y + 60), Vector2(AREA.get_center().x, AREA.end.y - 20),
	]
	var placed := 0
	var covered_target := 0
	var covered_actor := 0
	for yaw_step in 12:
		var yaw := deg_to_rad(yaw_step * 30.0)
		for scale: float in [55.0, 85.0]:
			for origin in origins:
				for actor in actors:
					for target in _cells():
						var distance := absi(actor.x - target.x) + absi(actor.y - target.y)
						if distance < 1 or distance > reach:
							continue
						var sizes: Array[Vector2] = FORECAST_SIZES.duplicate()
						if not every_size:
							sizes = [FORECAST_SIZES[placed % FORECAST_SIZES.size()]]
						for forecast_size in sizes:
							var result := _place(actor, target, yaw, scale, origin, forecast_size)
							var menu: Rect2 = result[0]
							var forecast: Rect2 = result[1]
							var what := "向き %d 度、1 マス %d px、盤の中央 %s、駒 %s、対象 %s" % [yaw_step * 30, scale, origin, actor, target]
							placed += 1
							if forecast.intersects(menu):
								assert_false(true, "予測のパネルがメニューに重なった: " + what)
							if not AREA.encloses(forecast):
								assert_false(true, "予測のパネルが帯か画面の外へはみ出した: " + what)
							if not AREA.encloses(menu):
								assert_false(true, "メニューが帯か画面の外へはみ出した: " + what)
							if forecast.intersects(result[2]):
								covered_target += 1
							if forecast.intersects(result[3]):
								covered_actor += 1
	# 対象の駒は、置ける場所があるかぎり隠さない。行動する駒は、メニューのそばに逃がすときに隠すことがあるが、ごく一部に留める。
	assert_eq(covered_target, 0, "予測のパネルが対象の駒を隠した（%d 回中）" % placed)
	assert_true(covered_actor * 50 <= placed, "予測のパネルが行動する駒を隠しすぎる: %d / %d" % [covered_actor, placed])


## メニューが大きく駒を囲んでいて、駒の周りの候補がどれもメニューに重なるときも、メニューの周りへ逃がす。
func test_escapes_around_the_menu_when_every_side_is_taken() -> void:
	var placement := MenuPlacement.new()
	var anchor := Rect2(600, 300, 50, 80)
	var menu := Rect2(300, 100, 700, 450)
	var size := Vector2(266, 170)
	var rect := Rect2(placement.place(anchor, size, AREA, [], [menu]), size)
	assert_false(rect.intersects(menu), "メニューに重なった")
	assert_true(AREA.encloses(rect), "画面からはみ出した")


## 重ねてはいけない四角が無ければ、これまでと同じ置き方（メニューの出方は変わらない）。
func test_without_keep_clear_the_choice_is_unchanged() -> void:
	var anchor := Rect2(600, 300, 50, 80)
	var obstacles: Array = [[Rect2(660, 280, 50, 40), 12.0]]
	var plain := MenuPlacement.new()
	var with_empty := MenuPlacement.new()
	assert_eq(plain.place(anchor, MENU_SIZE, AREA, obstacles), with_empty.place(anchor, MENU_SIZE, AREA, obstacles, []))
	assert_eq(plain.choice, with_empty.choice)


func _cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in BOARD.y:
		for x in BOARD.x:
			cells.append(Vector2i(x, y))
	return cells


## panel_layout.gd と同じに、メニュー（行動する駒のそば）と予測のパネル（対象のそば）を置く。
## [メニュー, 予測のパネル, 対象の駒, 行動する駒] の四角を返す。
func _place(actor: Vector2i, target: Vector2i, yaw: float, scale: float, origin: Vector2, forecast_size: Vector2) -> Array:
	var actor_rect := _unit_rect(actor, 0.45, yaw, scale, origin)
	var target_rect := _unit_rect(target, 0.45, yaw, scale, origin)
	var menu_obstacles: Array = [[_unit_rect(target, 0.4, yaw, scale, origin), 12.0], [_unit_rect(target, 0.35, yaw, scale, origin), 4.0]]
	var menu := Rect2(MenuPlacement.new().place(actor_rect, MENU_SIZE, AREA, menu_obstacles), MENU_SIZE)
	var forecast_obstacles: Array = [[_unit_rect(actor, 0.4, yaw, scale, origin), 12.0], [_unit_rect(target, 0.35, yaw, scale, origin), 4.0]]
	var at := MenuPlacement.new().place(target_rect, forecast_size, AREA, forecast_obstacles, [menu])
	return [menu, Rect2(at.round(), forecast_size), target_rect, actor_rect]
