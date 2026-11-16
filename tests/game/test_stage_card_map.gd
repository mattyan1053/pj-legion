extends "res://tests/base_test.gd"
## ステージ選択のカードの縮図（game/stage_card_map.gd）。

const StageCardMap := preload("res://game/stage_card_map.gd")
const StageLook := preload("res://game/stage_look.gd")

const COLORS: Array[Color] = [Color("3a7bd5"), Color("d53a3a")]


## マスの真ん中の色（市松の明るさの差は許す）。
func _near(image: Image, cell: Vector2i, color: Color) -> bool:
	var half := StageCardMap.CELL / 2
	var got := image.get_pixel(cell.x * StageCardMap.CELL + half, cell.y * StageCardMap.CELL + half)
	return absf(got.r - color.r) < 0.08 and absf(got.g - color.g) < 0.08 and absf(got.b - color.b) < 0.08


func test_every_stage_draws_its_board_cell_by_cell() -> void:
	for stage: BoardGenerator.Stage in MatchSetup.STAGE_NAMES:
		var board := BoardGenerator.generate(stage, 3)
		var image := StageCardMap.draw(board, StageLook.name_of_stage(stage), COLORS)
		assert_eq(image.get_size(), board.size * StageCardMap.CELL, "%d" % stage)
		for side in 2:
			assert_true(_near(image, board.hq_cells[side], COLORS[side]), "本陣は陣営の色（%d）" % stage)
		for cell in board.mid_boss_cells:
			assert_true(_near(image, cell, StageCardMap.COLOR_MID_BOSS), "中ボスの印（%d）" % stage)


func test_objects_are_dots_in_their_own_colors() -> void:
	var springs := BoardGenerator.generate(BoardGenerator.Stage.LABYRINTH, 3)
	var image := StageCardMap.draw(springs, StageLook.LABYRINTH, COLORS)
	assert_false(springs.spring_cells.is_empty())
	for cell in springs.spring_cells:
		assert_true(_near(image, cell, StageCardMap.COLOR_SPRING), "回復の泉")
	var portals := BoardGenerator.generate(BoardGenerator.Stage.TWIN_SPRINGS, 3)
	image = StageCardMap.draw(portals, StageLook.TWIN_SPRINGS, COLORS)
	for cell: Vector2i in portals.portal_exits:
		assert_true(_near(image, cell, StageCardMap.COLOR_PORTAL), "ポータル")


func test_ground_follows_the_stage_look() -> void:
	var board := Board.new(Vector2i(4, 4))
	board.hq_cells = [Vector2i(-9, -9), Vector2i(-9, -9)] as Array[Vector2i]
	board.set_terrain(Vector2i(1, 0), Terrain.Type.FOREST)
	for look_name: StringName in StageLook.THEMES:
		var look := StageLook.of(look_name)
		assert_eq(StageCardMap.cell_color(board, Vector2i(0, 0), look, COLORS), look[StageLook.NORMAL])
		assert_eq(StageCardMap.cell_color(board, Vector2i(1, 0), look, COLORS), look[StageLook.FOREST])
