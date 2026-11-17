extends "res://tests/base_test.gd"
## 置けるマス（Deployment.zone）と、人が決めた置き方（Deployment.deploy の placement、MatchSetup.placements）。

const Maps := preload("res://tests/support/maps.gd")

const P1 := Unit.Side.PLAYER1
const P2 := Unit.Side.PLAYER2
const MILITARY := UnitKind.Army.MILITARY
const P1_HQ := Vector2i(3, 6)
const P2_HQ := Vector2i(3, 0)
const NO := Deployment.UNSET


func _battle() -> Battle:
	var rows: Array[String] = []
	for i in 7:
		rows.append(".......")
	var battle := Maps.battle(rows)
	battle.board.hq_cells = [P1_HQ, P2_HQ]
	return battle


func _deck(count: int) -> Deck:
	var deck := Deck.new(MILITARY)
	for i in count:
		deck.add(UnitKind.Id.SNIPER if i % 2 == 0 else UnitKind.Id.COMMANDO)
	return deck


func _cells(units: Array[Unit]) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for unit in units:
		cells.append(unit.cell)
	return cells


func test_the_zone_is_two_rows_in_front_of_the_hq() -> void:
	var area := Deployment.zone(_battle(), P1, [], 3)
	assert_eq(area.size(), 10, "5 マス × 2 行")
	for cell in area:
		assert_between(cell.y, 4, 5)
		assert_between(cell.x, 1, 5)


func test_the_zone_grows_when_the_rows_are_too_few() -> void:
	var area := Deployment.zone(_battle(), P1, [], 12)
	assert_eq(area.size(), 15, "足りなければ、もう 1 行")


func test_the_zone_is_the_listed_cells_when_given() -> void:
	var listed: Array[Vector2i] = [Vector2i(0, 2), Vector2i(6, 2), Vector2i(0, 3)]
	assert_eq(Deployment.zone(_battle(), P1, listed, 2), listed, "書いたマスだけ（離れていてよい）")


func test_the_zone_keeps_the_cells_of_its_own_placed_units() -> void:
	var battle := _battle()
	var before := Deployment.zone(battle, P1, [], 4)
	Deployment.deploy(battle, P1, _deck(4))
	assert_eq(Deployment.zone(battle, P1, [], 4), before, "置いたあとでも、置く前と同じマスの列")
	Deployment.deploy(battle, P2, _deck(4))
	assert_eq(Deployment.zone(battle, P1, [], 4), before, "相手を置いても変わらない")


func test_no_placement_is_the_usual_placement() -> void:
	var usual := _cells(Deployment.deploy(_battle(), P1, _deck(4)))
	var unset: Array[Vector2i] = [NO, NO, NO, NO]
	assert_eq(_cells(Deployment.deploy(_battle(), P1, _deck(4), [], unset)), usual)


func test_a_placement_puts_units_where_chosen_and_the_rest_as_usual() -> void:
	# 2 番目の駒を、本陣から 2 行前・右 2 へ。ほかの駒は、残ったマスにいつもの順で。
	var placement: Array[Vector2i] = [NO, Vector2i(2, -2)]
	var placed := Deployment.deploy(_battle(), P1, _deck(3), [], placement)
	assert_eq(_cells(placed), [P1_HQ, Vector2i(3, 5), Vector2i(5, 4), Vector2i(2, 5)] as Array[Vector2i])


func test_a_placement_can_swap_with_the_usual_cell() -> void:
	# 1 番目の駒を、いつもなら 2 番目の駒が置かれるマスへ。2 番目の駒は、残ったマスへ。
	var placement: Array[Vector2i] = [Vector2i(-1, -1)]
	var placed := Deployment.deploy(_battle(), P1, _deck(2), [], placement)
	assert_eq(_cells(placed), [P1_HQ, Vector2i(2, 5), Vector2i(3, 5)] as Array[Vector2i])


func test_a_placement_outside_the_zone_is_not_used() -> void:
	var usual := _cells(Deployment.deploy(_battle(), P1, _deck(2)))
	var far: Array[Vector2i] = [Vector2i(0, -5), Vector2i(0, -6)]
	assert_eq(_cells(Deployment.deploy(_battle(), P1, _deck(2), [], far)), usual, "置けるマスの外（相手の本陣、3 行より前）は使わない")


func test_a_placement_on_the_same_cell_twice_keeps_the_first() -> void:
	var twice: Array[Vector2i] = [Vector2i(0, -2), Vector2i(0, -2)]
	var placed := Deployment.deploy(_battle(), P1, _deck(2), [], twice)
	assert_eq(placed[1].cell, Vector2i(3, 4))
	assert_ne(placed[2].cell, Vector2i(3, 4))


func test_a_placement_inside_listed_cells() -> void:
	var listed: Array[Vector2i] = [Vector2i(0, 2), Vector2i(6, 2), Vector2i(0, 3)]
	var placement: Array[Vector2i] = [Vector2i(0, 2) - P1_HQ + Vector2i(0, 1)]  # (0, 3)
	var placed := Deployment.deploy(_battle(), P1, _deck(2), listed, placement)
	assert_eq(_cells(placed), [P1_HQ, Vector2i(0, 3), Vector2i(0, 2)] as Array[Vector2i], "書いたマスの中で、人が決めたマスと、残りの書いた順")


func test_match_setup_uses_the_placements() -> void:
	var setup := MatchSetup.versus_cpu(BoardGenerator.Stage.PLAIN, 5, MatchSetup.default_deck(MILITARY), UnitKind.Army.FANTASY)
	var usual := setup.create_battle()
	var mine := usual.units.filter(func(unit: Unit) -> bool: return unit.side == P1 and unit.kind != UnitKind.Id.KING)
	var hq := usual.board.hq_cells[P1]
	var area := Deployment.zone(usual, P1, [], mine.size())
	var target: Vector2i = area.filter(func(cell: Vector2i) -> bool: return usual.unit_at(cell) == null)[0]
	setup.placements[P1] = [target - hq] as Array[Vector2i]
	var moved := setup.create_battle()
	var first: Unit = moved.units.filter(func(unit: Unit) -> bool: return unit.side == P1 and unit.kind != UnitKind.Id.KING)[0]
	assert_eq(first.cell, target, "人が決めたマスから始まる")
	for unit: Unit in moved.units:
		if unit.side == P2:
			assert_true(usual.unit_at(unit.cell) != null and usual.unit_at(unit.cell).side == P2, "相手の置き方は変わらない")


## 相手の側へ返す（facing_placement）: 盤の形に合わせる。7 x 7 の盤で、置き方のずれ (2, -2)（本陣から 2 行前、右へ 2）を返す。
func _facing(rows: Array[String], hqs: Array[Vector2i]) -> Vector2i:
	var board := Maps.board(rows)
	board.hq_cells = hqs
	var placement: Array[Vector2i] = [Vector2i(2, -2), NO]
	var facing := Deployment.facing_placement(board, placement)
	assert_eq(facing[1], NO, "決めていない駒は、決めていないまま")
	return facing[0]


func test_facing_on_diagonal_hqs_turns_the_placement_around() -> void:
	var open: Array[String] = [".......", ".......", ".......", ".......", ".......", ".......", "......."]
	assert_eq(_facing(open, [Vector2i(1, 6), Vector2i(5, 0)]), Vector2i(-2, 2), "本陣が対角なら点対称: 上下と左右を返す")


func test_facing_on_a_point_symmetric_board_turns_the_placement_around() -> void:
	var rows: Array[String] = [".......", ".......", ".#.....", ".......", ".....#.", ".......", "......."]
	assert_eq(_facing(rows, [P1_HQ, P2_HQ]), Vector2i(-2, 2), "地形が点対称なら、端に寄せた駒は相手の側でも端に（左右も返す）")


func test_facing_on_a_mirrored_board_flips_only_up_and_down() -> void:
	var rows: Array[String] = [".......", ".......", ".#.....", ".......", ".#.....", ".......", "......."]
	assert_eq(_facing(rows, [P1_HQ, P2_HQ]), Vector2i(2, 2), "地形が上下の線対称なら、上下だけを返す")


func test_facing_on_a_fully_symmetric_board_flips_only_up_and_down() -> void:
	var open: Array[String] = [".......", ".......", ".......", ".......", ".......", ".......", "......."]
	assert_eq(_facing(open, [P1_HQ, P2_HQ]), Vector2i(2, 2), "どちらの形でも重なるなら、上下だけ（いままでと同じ）")


func test_facing_follows_the_fixed_things_before_the_terrain() -> void:
	# 結晶泉は点対称でだけ重なる（地形は上下の線対称のほうが多く重なる）。
	var rows: Array[String] = [".......", ".....*.", ".#.....", ".......", ".#.....", ".*.....", "......."]
	assert_eq(_facing(rows, [P1_HQ, P2_HQ]), Vector2i(-2, 2), "本陣・中立の駒の場所を先に見る")
