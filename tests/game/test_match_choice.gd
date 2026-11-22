extends "res://tests/base_test.gd"
## 対戦設定画面で選ぶもの（match_choice.gd）から、ルールの対戦設定（MatchSetup）を作る。

const Names := preload("res://game/names.gd")
const MatchChoice := preload("res://game/match_choice.gd")
const BattleSource := preload("res://game/battle_source.gd")
const StageLook := preload("res://game/stage_look.gd")
const VersusFields := preload("res://game/versus_fields.gd")
const RandomSquad := preload("res://game/random_squad.gd")


func test_default_is_human_first_military_against_cpu_fantasy() -> void:
	var setup: MatchSetup = MatchChoice.new().to_setup(1)
	assert_eq(setup.scenario.stage, BoardGenerator.Stage.PLAIN)
	assert_eq(setup.controllers, [MatchSetup.Controller.HUMAN, MatchSetup.Controller.CPU] as Array[MatchSetup.Controller])
	assert_eq(setup.army_of(Unit.Side.PLAYER1), UnitKind.Army.MILITARY)
	assert_eq(setup.army_of(Unit.Side.PLAYER2), UnitKind.Army.FANTASY)
	assert_true(setup.is_valid())


func test_human_can_play_second() -> void:
	var choice := MatchChoice.new()
	choice.human_side = Unit.Side.PLAYER2
	choice.armies = [UnitKind.Army.FANTASY, UnitKind.Army.MILITARY] as Array[UnitKind.Army]
	assert_eq(choice.cpu_side(), Unit.Side.PLAYER1)
	var setup: MatchSetup = choice.to_setup(1)
	assert_eq(setup.cpu_sides(), [Unit.Side.PLAYER1] as Array[Unit.Side])
	assert_eq(setup.army_of(Unit.Side.PLAYER1), UnitKind.Army.FANTASY)
	assert_eq(setup.army_of(Unit.Side.PLAYER2), UnitKind.Army.MILITARY)
	var battle := setup.create_battle()
	assert_eq(battle.phase, Unit.Side.PLAYER1)
	assert_eq(battle.armies, [UnitKind.Army.FANTASY, UnitKind.Army.MILITARY] as Array[UnitKind.Army])


func test_random_side_draws_from_the_seed_and_keeps_your_deck() -> void:
	var choice := MatchChoice.new()
	choice.random_side = true
	choice.armies = [UnitKind.Army.FANTASY, UnitKind.Army.MILITARY] as Array[UnitKind.Army]
	var seen := {}
	for battle_seed in 20:
		var setup: MatchSetup = choice.to_setup(battle_seed)
		var human := choice.human_side_now()
		seen[human] = true
		assert_eq(human, MatchChoice.draw_side(battle_seed), "同じ種なら同じ手番")
		assert_eq(setup.cpu_sides(), [choice.cpu_side()] as Array[Unit.Side])
		assert_eq(setup.army_of(human), UnitKind.Army.FANTASY, "あなたの軍（先手の行）が、引いた側に付く")
		assert_eq(setup.army_of(choice.cpu_side()), UnitKind.Army.MILITARY, "CPU の軍（後手の行）が、もう一方に付く")
	assert_eq(seen.size(), 2, "先手も後手も出る")
	assert_true(choice.is_human(Unit.Side.PLAYER1) and not choice.is_human(Unit.Side.PLAYER2), "ランダムでは、先手の行があなたの部隊")
	var copied: RefCounted = choice.copy()
	assert_true(copied.random_side and copied.drawn_side == choice.drawn_side)


func test_two_humans_take_the_default_deck_of_each_army() -> void:
	for armies: Array[UnitKind.Army] in [
		[UnitKind.Army.MILITARY, UnitKind.Army.MILITARY] as Array[UnitKind.Army],
		[UnitKind.Army.FANTASY, UnitKind.Army.FANTASY] as Array[UnitKind.Army],
	]:
		var choice := MatchChoice.new()
		choice.cpu_opponent = false
		choice.human_side = Unit.Side.PLAYER2  # 人どうしでは見ない
		choice.armies = armies
		var setup: MatchSetup = choice.to_setup(1)
		assert_true(setup.cpu_sides().is_empty())
		for side: Unit.Side in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
			assert_eq(setup.decks[side].entries.size(), MatchSetup.default_deck(armies[side]).entries.size())
			assert_true(setup.decks[side].is_valid())


func test_copy_does_not_share_the_armies() -> void:
	var choice := MatchChoice.new()
	var other: RefCounted = choice.copy()
	other.armies[0] = UnitKind.Army.FANTASY
	other.field = VersusFields.LABYRINTH
	assert_eq(choice.armies[0], UnitKind.Army.MILITARY)
	assert_eq(choice.field, VersusFields.PLAIN)


# --- 取っておいた部隊を選ぶ ---


func _saved_fantasy(library: RefCounted) -> RefCounted:
	var deck := Deck.new(UnitKind.Army.FANTASY)
	deck.add(UnitKind.Id.SPELLBLADE).equip(Equipment.Id.SPEED_BOOTS)
	deck.add(UnitKind.Id.PRIEST)
	return library.add("速攻", deck)


func test_chosen_deck_goes_into_the_match() -> void:
	var library: RefCounted = preload("res://game/deck_library.gd").new()
	var item := _saved_fantasy(library)
	var choice := MatchChoice.new()
	choice.choose_deck(Unit.Side.PLAYER1, item.id, item.deck)
	assert_eq(choice.armies[0], UnitKind.Army.FANTASY, "軍は部隊の軍になる")
	var setup: MatchSetup = choice.to_setup(1)
	assert_true(setup.is_valid())
	assert_eq(setup.decks[0].entries.size(), 2)
	assert_eq(setup.decks[0].entries[0].equipment, [Equipment.Id.SPEED_BOOTS] as Array[Equipment.Id])
	assert_eq(setup.decks[1].entries.size(), CpuDeck.build(UnitKind.Army.FANTASY).entries.size(), "CPU の行が既定なら、CPU の編成")
	var battle := setup.create_battle()
	assert_eq(battle.units.filter(func(unit: Unit) -> bool: return unit.side == Unit.Side.PLAYER1).size(), 3, "将 + 2 体")


func test_both_humans_choose_their_own_decks() -> void:
	var library: RefCounted = preload("res://game/deck_library.gd").new()
	var item := _saved_fantasy(library)
	var choice := MatchChoice.new()
	choice.cpu_opponent = false
	choice.choose_deck(Unit.Side.PLAYER2, item.id, item.deck)
	var setup: MatchSetup = choice.to_setup(1)
	assert_eq(setup.decks[0].entries.size(), MatchSetup.default_deck(UnitKind.Army.MILITARY).entries.size(), "先手は既定の編成")
	assert_eq(setup.decks[1].entries.size(), 2, "後手は選んだ部隊")


## CPU の行も、人の行と同じに部隊を選べる（選択肢に出ているものが、そのまま対戦に出る）。
func test_cpu_side_takes_the_chosen_deck() -> void:
	var library: RefCounted = preload("res://game/deck_library.gd").new()
	var item := _saved_fantasy(library)
	var choice := MatchChoice.new()
	choice.choose_deck(Unit.Side.PLAYER2, item.id, item.deck)
	assert_false(choice.is_human(Unit.Side.PLAYER2))
	var setup: MatchSetup = choice.to_setup(1)
	assert_true(setup.is_cpu(Unit.Side.PLAYER2) and setup.is_valid())
	assert_eq(setup.decks[1].entries.size(), 2, "CPU が選んだ部隊で戦う")
	choice.choose_default(Unit.Side.PLAYER2)
	assert_eq(choice.to_setup(1).decks[1].entries.size(), CpuDeck.build(UnitKind.Army.FANTASY).entries.size(), "既定に戻せば CPU の編成")


func _kinds(deck: Deck) -> Array:
	return deck.entries.map(func(entry: DeckEntry) -> Array: return [entry.kind, entry.equipment])


## ランダム編成: 対戦を作るたびに、対戦の種から決まりの中で組む（random_squad.gd。道具の --squads=random と同じ）。同じ種なら同じ部隊。
## 組んだ部隊は、写しにも残り、「編成確認」で見られる（drawn_deck）。
func test_random_squad_follows_the_battle_seed() -> void:
	var choice := MatchChoice.new()
	choice.choose_random(Unit.Side.PLAYER2)
	assert_true(choice.drawn_deck(Unit.Side.PLAYER2) == null, "対戦を作る前は、まだ組んでいない")
	var setup: MatchSetup = choice.to_setup(7)
	assert_true(setup.is_valid() and setup.is_cpu(Unit.Side.PLAYER2), "%s" % [setup.problems()])
	assert_eq(_kinds(setup.decks[1]), _kinds(RandomSquad.for_battle(UnitKind.Army.FANTASY, 7, Unit.Side.PLAYER2)))
	assert_eq(_kinds(choice.drawn_deck(Unit.Side.PLAYER2)), _kinds(setup.decks[1]), "組んだ部隊を覚える")
	assert_eq(_kinds(choice.copy().drawn_deck(Unit.Side.PLAYER2)), _kinds(setup.decks[1]), "写しにも残る（対戦の途中の設定パネル）")
	assert_eq(_kinds(choice.to_setup(7).decks[1]), _kinds(setup.decks[1]), "同じ種（同じマップで再戦）なら同じ部隊")
	var differs := false
	for other_seed in range(8, 16):
		differs = differs or _kinds(choice.to_setup(other_seed).decks[1]) != _kinds(setup.decks[1])
	assert_true(differs, "種を替える（新しい盤面）と、部隊も変わる")
	assert_true(setup.create_battle() != null)
	choice.choose_army(Unit.Side.PLAYER2, UnitKind.Army.MILITARY)
	assert_true(choice.is_random(Unit.Side.PLAYER2), "軍を替えても、ランダム編成のまま")
	assert_true(choice.drawn_deck(Unit.Side.PLAYER2) == null, "前の軍で組んだ部隊は見せない")


## 手番がランダムなら、ランダム編成の部隊は、引いた側（実際に動かすプレイヤー）として組む。人どうしなら、両方がランダム編成を選べる。
func test_random_squad_is_drawn_for_the_side_that_plays() -> void:
	var choice := MatchChoice.new()
	choice.random_side = true
	choice.choose_random(Unit.Side.PLAYER1)
	for battle_seed in range(1, 9):
		var setup: MatchSetup = choice.to_setup(battle_seed)
		var played := choice.human_side_now()
		assert_eq(_kinds(setup.decks[played]), _kinds(RandomSquad.for_battle(UnitKind.Army.MILITARY, battle_seed, played)))
		assert_eq(_kinds(choice.drawn_deck(Unit.Side.PLAYER1)), _kinds(setup.decks[played]))
	var humans := MatchChoice.new()
	humans.cpu_opponent = false
	humans.choose_random(Unit.Side.PLAYER1)
	humans.choose_random(Unit.Side.PLAYER2)
	var setup: MatchSetup = humans.to_setup(3)
	assert_true(setup.is_valid() and setup.cpu_sides().is_empty())
	assert_eq(_kinds(setup.decks[0]), _kinds(RandomSquad.for_battle(UnitKind.Army.MILITARY, 3, Unit.Side.PLAYER1)))
	assert_eq(_kinds(setup.decks[1]), _kinds(RandomSquad.for_battle(UnitKind.Army.FANTASY, 3, Unit.Side.PLAYER2)))


## ランダム編成の部隊は、どの種でも出せる部隊（決まりの検査を通る）。
func test_random_squads_are_always_playable() -> void:
	for army: UnitKind.Army in [UnitKind.Army.MILITARY, UnitKind.Army.FANTASY]:
		for battle_seed in 40:
			var deck := RandomSquad.for_battle(army, battle_seed, (battle_seed % 2) as Unit.Side)
			assert_true(deck.problems().is_empty() and deck.army == army and deck.rules.id == DeckRules.VERSUS, "%s %d: %s" % [army, battle_seed, deck.problems()])


func test_changing_the_army_drops_the_chosen_deck() -> void:
	var library: RefCounted = preload("res://game/deck_library.gd").new()
	var item := _saved_fantasy(library)
	var choice := MatchChoice.new()
	choice.choose_deck(Unit.Side.PLAYER1, item.id, item.deck)
	choice.choose_army(Unit.Side.PLAYER1, UnitKind.Army.FANTASY)
	assert_eq(choice.deck_ids[0], item.id, "同じ軍なら残る")
	choice.choose_army(Unit.Side.PLAYER1, UnitKind.Army.MILITARY)
	assert_eq(choice.deck_ids[0], "")
	assert_eq(choice.decks[0], null)


func test_refresh_follows_the_library() -> void:
	var library: RefCounted = preload("res://game/deck_library.gd").new()
	var item := _saved_fantasy(library)
	var choice := MatchChoice.new()
	choice.choose_deck(Unit.Side.PLAYER1, item.id, item.deck)
	var rebuilt: Deck = item.deck.copy()
	rebuilt.add(UnitKind.Id.PALADIN)
	library.replace(item.id, item.name, rebuilt)
	choice.refresh_decks(library)
	assert_eq(choice.decks[0].entries.size(), 3, "組み直した中身になる")
	var over: Deck = rebuilt.copy()
	for i in 3:
		over.add(UnitKind.Id.PALADIN)
	library.replace(item.id, item.name, over)
	choice.refresh_decks(library)
	assert_eq(choice.deck_ids[0], "", "出せなくなったら既定の編成に戻す")
	choice.choose_deck(Unit.Side.PLAYER1, item.id, rebuilt)
	library.remove(item.id)
	choice.refresh_decks(library)
	assert_eq(choice.deck_ids[0], "", "消えたら既定の編成に戻す")


func test_copy_does_not_share_the_chosen_deck() -> void:
	var library: RefCounted = preload("res://game/deck_library.gd").new()
	var item := _saved_fantasy(library)
	var choice := MatchChoice.new()
	choice.choose_deck(Unit.Side.PLAYER1, item.id, item.deck)
	var other: RefCounted = choice.copy()
	other.decks[0].add(UnitKind.Id.PALADIN)
	assert_eq(choice.decks[0].entries.size(), 2)
	assert_eq(other.deck_ids[0], item.id)


# ---- 対戦の画面に渡すもの（battle_source.gd）として ----


func test_as_battle_source_makes_the_same_setup_and_names_the_look() -> void:
	var choice := MatchChoice.new()
	choice.field = VersusFields.LABYRINTH
	var setup: MatchSetup = choice.make_setup(7)
	assert_eq(setup.scenario.stage, BoardGenerator.Stage.LABYRINTH)
	assert_eq(setup.battle_seed, 7)
	assert_eq(setup.scenario.title, Names.stage(BoardGenerator.Stage.LABYRINTH), "マップは戦いの定義の名前")
	assert_eq(choice.look(), StageLook.STONE_WALLS)
	assert_true(setup.is_cpu(choice.cpu_side()))


func test_as_battle_source_lets_the_battle_screen_change_stage_and_opponent() -> void:
	var choice := MatchChoice.new()
	assert_true(choice.can_switch_opponent())
	assert_true(choice.can_open_setup())
	assert_eq(choice.new_board_fields(), [VersusFields.PLAIN, VersusFields.LABYRINTH, VersusFields.TWIN_SPRINGS] as Array[StringName])
	choice.choose_field(VersusFields.TWIN_SPRINGS)
	assert_eq(choice.make_setup(1).scenario.stage, BoardGenerator.Stage.TWIN_SPRINGS)
	choice.set_cpu_opponent(false)
	assert_true(choice.make_setup(1).cpu_sides().is_empty(), "相手を人にしたら、次の対戦も人どうし")


func test_the_base_source_offers_nothing_to_choose() -> void:
	# 既定（battle_source.gd）は、何も選び直せない対戦（ストーリーの 1 話はこちらから始める）。
	var base := BattleSource.new()
	assert_false(base.can_switch_opponent())
	assert_false(base.can_open_setup())
	assert_true(base.new_board_fields().is_empty())
	assert_eq(base.look(), StageLook.DEFAULT)


func test_starting_a_versus_battle_is_a_run_of_one_battle_with_a_copy() -> void:
	var choice := MatchChoice.new()
	var run := choice.run()
	assert_eq(run.scene(), &"battle")
	var given: RefCounted = run.data()
	assert_true(given != choice, "対戦の場面に渡すのは写し")
	given.choose_field(VersusFields.LABYRINTH)
	assert_eq(choice.field, VersusFields.PLAIN, "対戦の途中でマップを替えても、選んだものは変わらない")
	assert_eq(run.advance(), run.exit)
	assert_true(run.is_done())


# ---- 手で作ったマップ（versus_fields.gd） ----


func test_a_hand_map_makes_the_same_board_on_any_seed_with_the_versus_rules() -> void:
	for field in VersusFields.all_ids():
		if VersusFields.is_generated(field):
			continue
		var choice := MatchChoice.new()
		choice.field = field
		var setup: MatchSetup = choice.make_setup(1)
		assert_true(setup.is_valid(), str(field))
		assert_eq(setup.scenario.title, VersusFields.title_of(field), "マップはマップの名前")
		assert_eq(setup.scenario.win_conditions_of(Unit.Side.PLAYER1), Scenario.STANDARD_WIN_CONDITIONS, "勝ち方は対戦モードのいつもの 2 つ")
		assert_false(setup.scenario.is_fixed(Unit.Side.PLAYER2), "部隊は対戦設定で選ぶ（決め打ちにしない）")
		assert_true(setup.decks[Unit.Side.PLAYER2].is_valid(), "CPU の編成は予算どおり")
		var first := setup.create_battle()
		var other := choice.make_setup(99).create_battle()
		assert_eq(first.board.size, other.board.size)
		assert_eq(first.board.hq_cells, other.board.hq_cells, "種を変えても同じ形")
		assert_eq(choice.look(), VersusFields.look_of(field))
		assert_false(choice.new_board_fields().has(field), "同じ形にしかならないマップは「新しいマップ」に入れない")
		choice.cpu_opponent = false
		assert_true(choice.make_setup(1).cpu_sides().is_empty(), "人どうしでも遊べる")
		assert_true(choice.make_setup(1).is_valid())


# --- 選べる決まり ---


## 既定は拠点あり・砲台なし（OptionalRules.DEFAULTS）。選んだものが対戦の設定に届く。
func test_rules_start_from_the_defaults_and_reach_the_setup() -> void:
	var choice := MatchChoice.new()
	assert_eq(choice.to_setup(1).rules, [OptionalRules.STRONGHOLD] as Array[StringName])
	assert_true(choice.to_setup(1).create_battle().board.stronghold_cell != Board.NO_CELL, "既定の対戦に拠点がある")
	choice.set_rule(OptionalRules.BATTERY, true)
	choice.set_rule(OptionalRules.BATTERY, true)
	assert_true(choice.has_rule(OptionalRules.BATTERY))
	assert_eq(choice.to_setup(1).rules, [OptionalRules.STRONGHOLD, OptionalRules.BATTERY] as Array[StringName])
	assert_eq(choice.copy().rules, [OptionalRules.STRONGHOLD, OptionalRules.BATTERY] as Array[StringName])
	assert_eq(choice.to_setup(1).create_battle().board.battery_cells.size(), 2)
	choice.set_rule(OptionalRules.BATTERY, false)
	choice.set_rule(OptionalRules.STRONGHOLD, false)
	assert_false(choice.has_rule(OptionalRules.BATTERY))
	choice.set_rule(&"unknown", true)
	assert_eq(choice.rules, [] as Array[StringName])
	var battle := choice.to_setup(1).create_battle()
	assert_eq(battle.board.battery_cells.size(), 0)
	assert_eq(battle.board.stronghold_cell, Board.NO_CELL, "拠点をなしにすれば置かない")


func test_every_versus_field_has_two_fair_battery_spots() -> void:
	var reach := Neutral.TERRITORY_RADIUS + UnitKind.attack_range(UnitKind.Id.ELITE_MINION)
	for field in VersusFields.ids():
		var choice := MatchChoice.new()
		choice.choose_field(field)
		choice.set_rule(OptionalRules.BATTERY, true)
		var board: Board = choice.to_setup(3).create_battle().board
		assert_eq(board.battery_cells.size(), 2, field)
		assert_eq(board.battery_cells[0] + board.battery_cells[1], board.hq_cells[0] + board.hq_cells[1], "点対称: %s" % field)
		for cell in board.battery_cells:
			for home in board.mid_boss_cells:
				assert_true(Combat.distance(cell, home) > reach, "中ボスが届かない: %s" % field)
