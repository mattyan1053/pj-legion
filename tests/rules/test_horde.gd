extends "res://tests/base_test.gd"
## 将のいない群れ（戦いの定義の kings。docs/scenario.md の「将のいない群れ」）。
## 将を置かずに対戦を作れて、勝ち方（全滅・中ボスの撃破・守り切る）で決着し、CPU が両方の側を動かせること。

const P1 := Unit.Side.PLAYER1
const P2 := Unit.Side.PLAYER2

## 11 x 12 の盤。中ボスは 2 体（中ボスの撃破の勝ち方のため）。
const ROWS := [
	".....2.....",
	"...........",
	"..F.....F..",
	"...........",
	"M...#.#....",
	"...........",
	"...........",
	"....#.#...M",
	"...........",
	"..F.....F..",
	"...........",
	".....1.....",
]


func _horde() -> Deck:
	var deck := Deck.new(UnitKind.Army.NONE)
	for kind: UnitKind.Id in [
		UnitKind.Id.SKELETON_BRUTE, UnitKind.Id.SKELETON_ARCHER, UnitKind.Id.SKELETON, UnitKind.Id.SKELETON, UnitKind.Id.SKELETON
	]:
		deck.entries.append(DeckEntry.new(kind))
	return deck


## プレイヤー1 は MILITARY の既定の編成で、勝ち方は wins。プレイヤー2 は将のいない魔物の群れで、勝ち方はいつもの 2 つ。
func _scenario(wins: Array[GameWonEvent.Reason]) -> Scenario:
	var scenario := Scenario.on_map(HandMap.new(PackedStringArray(ROWS)), "試し")
	scenario.fix_deck(P2, _horde())
	scenario.remove_king(P2)
	scenario.set_win_conditions(P1, wins)
	return scenario


func _battle(scenario: Scenario) -> Battle:
	var setup := MatchSetup.versus_cpu(BoardGenerator.Stage.PLAIN, 3, MatchSetup.default_deck(UnitKind.Army.MILITARY), UnitKind.Army.MILITARY)
	setup.scenario = scenario
	setup.controllers[P1] = MatchSetup.Controller.CPU
	return setup.create_battle()


func _units_of(battle: Battle, side: Unit.Side) -> Array[Unit]:
	var result: Array[Unit] = []
	for unit in battle.units:
		if unit.side == side:
			result.append(unit)
	return result


## CPU どうしで、決着するか max_turn を越えるまで回す。断られた行動があれば失敗。決着の理由を返す（決着しなければ -1）。
func _play(battle: Battle, max_turn: int) -> int:
	var cpu := CpuPlayer.new()
	var steps := 0
	while not battle.is_over() and battle.turn <= max_turn and steps < 6000:
		var action := cpu.next_action(battle)
		assert_true(action != null, "CPU が行動を返さない")
		if action == null:
			return -1
		var result := battle.apply(action)
		assert_true(result.accepted, "CPU の行動が断られた")
		if not result.accepted:
			return -1
		for event in result.events:
			if event is GameWonEvent:
				return (event as GameWonEvent).reason
		steps += 1
	return -1


func test_scenario_places_kings_by_default() -> void:
	var scenario := Scenario.new()
	assert_true(scenario.has_king(P1) and scenario.has_king(P2), "既定は、どちらも将を置く")
	scenario.remove_king(P2)
	assert_true(scenario.has_king(P1))
	assert_false(scenario.has_king(P2))


func test_kingless_side_is_placed_without_a_king_and_leaves_its_hq_empty() -> void:
	var battle := _battle(_scenario([GameWonEvent.Reason.ROUTED]))
	var horde := _units_of(battle, P2)
	assert_eq(horde.size(), 5, "書いた 5 体だけ")
	assert_false(horde.any(func(unit: Unit) -> bool: return unit.kind == UnitKind.Id.KING), "将はいない")
	assert_eq(battle.unit_at(battle.board.hq_cells[P2]), null, "群れの本陣は空")
	assert_eq(battle.armies[P2], UnitKind.Army.NONE)
	assert_true(_units_of(battle, P1).any(func(unit: Unit) -> bool: return unit.kind == UnitKind.Id.KING), "相手の側は、いつもどおり将がいる")


func test_routing_the_horde_wins() -> void:
	var battle := _battle(_scenario([GameWonEvent.Reason.ROUTED]))
	var events: Array[BattleEvent] = []
	var last: Unit = null
	for unit in _units_of(battle, P2):
		last = unit
		events.append_array(battle.remove_unit(unit))
	assert_true(last != null)
	var extra := battle.settle(events)
	assert_eq(battle.winner, P1, "群れを全滅させれば勝ち")
	assert_true(extra.any(func(event: BattleEvent) -> bool: return event is GameWonEvent and (event as GameWonEvent).reason == GameWonEvent.Reason.ROUTED))


func test_horde_can_still_win_against_the_king() -> void:
	var battle := _battle(_scenario([GameWonEvent.Reason.ROUTED]))
	var king: Unit = null
	for unit in _units_of(battle, P1):
		if unit.kind == UnitKind.Id.KING:
			king = unit
	battle.settle(battle.remove_unit(king))
	assert_eq(battle.winner, P2, "群れの側は、いつもどおり相手の将を倒して勝てる")


## CPU が、群れの側も、群れと戦う側も、断られる行動なしに最後まで動かせる（全滅の勝ち方）。
func test_cpu_plays_against_a_kingless_horde_to_the_end() -> void:
	_check_cpu_game([GameWonEvent.Reason.ROUTED], 0)


## 同じく、中ボスの撃破と守り切るの勝ち方で 1 局ずつ（長い検査）。
func test_long_cpu_plays_other_ways_against_a_kingless_horde() -> void:
	_check_cpu_game([GameWonEvent.Reason.BOSS_SLAIN], 0)
	_check_cpu_game([GameWonEvent.Reason.TURNS_HELD], 6)


func _check_cpu_game(wins: Array[GameWonEvent.Reason], hold_turns: int) -> void:
	var scenario := _scenario(wins)
	scenario.hold_turns = hold_turns
	var battle := _battle(scenario)
	var reason := _play(battle, 25)
	assert_true(battle.is_over(), "%s: 25 ターンまでに決着する" % [wins])
	if battle.winner == P1:
		assert_true(wins.has(reason), "%s: 人の側は、書いた勝ち方で勝つ（%s）" % [wins, reason])
