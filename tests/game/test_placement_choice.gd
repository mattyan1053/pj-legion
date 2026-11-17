extends "res://tests/base_test.gd"
## 人が決めた初期位置を、対戦設定（match_choice.gd）とストーリーの話（story_battle.gd）が対戦へ渡すこと。

const MatchChoice := preload("res://game/match_choice.gd")
const Story := preload("res://game/story.gd")


func _own(battle: Battle, side: Unit.Side) -> Array:
	return battle.units.filter(func(unit: Unit) -> bool: return unit.side == side and unit.kind != UnitKind.Id.KING)


func test_the_human_row_placement_goes_into_the_setup() -> void:
	var choice := MatchChoice.new()
	var preview: Array = choice.placement_preview(Unit.Side.PLAYER1, 3)
	var usual: Battle = preview[1]
	var hq := usual.board.hq_cells[0]
	var target: Vector2i = Deployment.zone(usual, Unit.Side.PLAYER1, [], 6).filter(func(cell: Vector2i) -> bool: return usual.unit_at(cell) == null)[0]
	var placement: Array[Vector2i] = []
	for unit: Unit in _own(usual, Unit.Side.PLAYER1):
		placement.append(unit.cell - hq)
	placement[0] = target - hq
	choice.placements[0] = placement
	assert_eq(_own(choice.to_setup(3).create_battle(), Unit.Side.PLAYER1)[0].cell, target)
	choice.choose_army(Unit.Side.PLAYER1, UnitKind.Army.FANTASY)
	assert_true(choice.placements[0].is_empty(), "軍を替えたら、おまかせに戻る")


func test_a_placement_is_flipped_when_the_row_plays_second() -> void:
	var choice := MatchChoice.new()
	var deck_size := MatchSetup.default_deck(UnitKind.Army.MILITARY).entries.size()
	var placement: Array[Vector2i] = []
	for i in deck_size:
		placement.append(Deployment.UNSET)
	placement[0] = Vector2i(2, -2)  # 先手として: 本陣から 2 行前、右 2
	choice.placements[0] = placement
	choice.random_side = true
	for battle_seed in range(1, 40):
		var setup := choice.to_setup(battle_seed)
		if choice.drawn_side == Unit.Side.PLAYER2:
			assert_eq(setup.placements[Unit.Side.PLAYER2][0], Vector2i(2, 2), "後手として対戦するときは、上下を返す")
			return
	assert_true(false, "後手を引く種が無い")


func test_a_story_battle_carries_the_placement_through_copies() -> void:
	var episode: RefCounted = Story.military().episodes[6]
	var source: RefCounted = Story.first_battle(episode)
	var usual: Battle = source.make_setup(1).create_battle()
	var hq := usual.board.hq_cells[0]
	var cells: Array[Vector2i] = source.scenario().deploy_cells_of(Unit.Side.PLAYER1)
	var free: Array = Deployment.zone(usual, Unit.Side.PLAYER1, cells, 6).filter(func(cell: Vector2i) -> bool: return usual.unit_at(cell) == null)
	var placement: Array[Vector2i] = [free[0] - hq]
	source.placement = placement
	assert_eq(_own(source.copy().make_setup(7).create_battle(), Unit.Side.PLAYER1)[0].cell, free[0], "同じマップで再戦（写し）でも、決めた位置")


func test_refreshing_an_unchanged_saved_deck_keeps_the_placement() -> void:
	var library := preload("res://game/deck_library.gd").new()
	var deck := MatchSetup.default_deck(UnitKind.Army.MILITARY)
	var item: RefCounted = library.add("取っておいた部隊", deck)
	var choice := MatchChoice.new()
	choice.choose_deck(Unit.Side.PLAYER1, item.id, item.deck)
	var placement: Array[Vector2i] = [Vector2i(1, -1)]
	choice.placements[0] = placement
	choice.refresh_decks(library)
	assert_eq(choice.placements[0], placement, "対戦設定を開き直しただけでは、初期位置を消さない")
	choice.choose_default(Unit.Side.PLAYER1)
	choice.choose_default(Unit.Side.PLAYER1)
	choice.placements[0] = placement
	choice.choose_default(Unit.Side.PLAYER1)
	assert_eq(choice.placements[0], placement, "既定の編成のまま選び直しても消さない")
	var changed := deck.copy()
	changed.add(UnitKind.Id.SNIPER)
	library.replace(item.id, "取っておいた部隊", changed)
	choice.choose_deck(Unit.Side.PLAYER1, item.id, item.deck)
	choice.refresh_decks(library)
	assert_true(choice.placements[0].is_empty(), "部隊の駒が変わったら、おまかせに戻す")
