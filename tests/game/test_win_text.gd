extends "res://tests/base_test.gd"
## 勝ち方の文（game/win_text.gd）。

const WinText := preload("res://game/win_text.gd")
const Maps := preload("res://tests/support/maps.gd")

const P1 := Unit.Side.PLAYER1
const P2 := Unit.Side.PLAYER2


func test_versus_ways_read_as_before() -> void:
	var scenario := Scenario.versus(BoardGenerator.Stage.PLAIN)
	assert_eq(
		WinText.of_scenario(scenario, P1),
		"敵の将を倒すか、敵の本陣を 3 ターン占拠し続ければ勝ち。\n味方の将が倒されるか、味方の本陣を占拠され続けると負け。"
	)


func test_holding_side_and_attacking_side_read_their_own_ways() -> void:
	var scenario := Scenario.versus(BoardGenerator.Stage.PLAIN)
	scenario.hold_for(P1, 9)
	assert_eq(
		WinText.of_scenario(scenario, P1),
		"9 ターン目の終わりまで守り切るか、敵の将を倒すか、敵の本陣を 3 ターン占拠し続ければ勝ち。\n"
		+ "味方の将が倒されるか、味方の本陣を占拠され続けると負け。"
	)
	assert_eq(
		WinText.of_scenario(scenario, P2),
		"敵の将を倒すか、敵の本陣を 3 ターン占拠し続ければ勝ち。\n"
		+ "9 ターン目の終わりまで守り切られるか、味方の将が倒されるか、味方の本陣を占拠され続けると負け。"
	)


func test_rout_reads_as_rout() -> void:
	var scenario := Scenario.versus(BoardGenerator.Stage.PLAIN)
	var rout: Array[GameWonEvent.Reason] = [GameWonEvent.Reason.ROUTED]
	scenario.set_win_conditions(P1, rout)
	assert_eq(WinText.of_scenario(scenario, P1).get_slice("\n", 0), "敵を全滅させれば勝ち。")
	assert_eq(WinText.of_scenario(scenario, P2).get_slice("\n", 1), "全滅すると負け。")


func test_turn_text_shows_the_hold_turns_only_when_someone_holds() -> void:
	var battle := Maps.battle(["....."])
	assert_eq(WinText.turn_text(battle, 3), "ターン 3")
	assert_eq(WinText.turn_note(battle, 3), "")
	battle.win_conditions[P1].append(GameWonEvent.Reason.TURNS_HELD)
	battle.hold_turns = 9
	assert_eq(WinText.turn_text(battle, 3), "ターン 3 / 9")
	assert_true(WinText.turn_note(battle, 3).contains("残り 7 ターン"))


func test_every_win_condition_has_a_place_in_the_text() -> void:
	for condition: GameWonEvent.Reason in GameWonEvent.Reason.values():
		assert_true(WinText.ORDER.has(condition), "ORDER に %d が無い" % condition)
		var conditions: Array[Array] = [[condition], [condition]]
		var text := WinText.goal(conditions, 5, P1)
		assert_eq(text.split("\n").size(), 2, "勝ち方と負け方の 2 行にならない: %s" % text)
