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
	assert_eq(WinText.of_scenario(scenario, P1).get_slice("\n", 0), "敵を全滅させれば勝ち。敵の将を倒しても、ほかの駒が残っていれば終わらない。")
	assert_eq(WinText.of_scenario(scenario, P2).get_slice("\n", 1), "全滅すると負け。")


## 将のいない群れ（docs/scenario.md）が相手なら、「将を倒しても終わらない」は言い添えない。
func test_no_king_note_against_a_kingless_horde() -> void:
	var scenario := Scenario.versus(BoardGenerator.Stage.PLAIN)
	scenario.remove_king(P2)
	scenario.set_win_conditions(P1, [GameWonEvent.Reason.ROUTED] as Array[GameWonEvent.Reason])
	assert_eq(WinText.of_scenario(scenario, P1).get_slice("\n", 0), "敵を全滅させれば勝ち。")
	scenario.set_win_conditions(P1, [GameWonEvent.Reason.BOSS_SLAIN] as Array[GameWonEvent.Reason])
	assert_eq(WinText.of_scenario(scenario, P1).get_slice("\n", 0), "中ボスを倒せば勝ち。")
	var battle := Maps.battle(["....", "...."])
	battle.add_unit(UnitKind.Id.KING, P1, Vector2i(0, 1))
	battle.add_unit(UnitKind.Id.SKELETON, P2, Vector2i(3, 0))
	battle.win_conditions[P1] = [GameWonEvent.Reason.ROUTED]
	assert_eq(WinText.goal_tag(battle, 1, P1), ["勝ち: 敵の全滅", false])
	assert_eq(WinText.goal_note(battle, P1).get_slice("\n", 0), "敵を全滅させれば勝ち。")
	battle.win_conditions[P1] = [GameWonEvent.Reason.BOSS_SLAIN]
	assert_eq(WinText.goal_tag(battle, 1, P1), ["勝ち: 中ボスの撃破", false])


func test_turn_text_is_only_the_turn() -> void:
	assert_eq(WinText.turn_text(3), "ターン 3")


func test_no_goal_tag_for_the_usual_ways() -> void:
	var battle := Maps.battle(["....."])
	assert_eq(WinText.goal_tag(battle, 3, P1), ["", false])
	assert_eq(WinText.goal_tag(battle, 3, P2), ["", false])


func test_goal_tag_counts_down_the_turns_to_hold_and_marks_the_last() -> void:
	var battle := Maps.battle(["....."])
	battle.win_conditions[P1].append(GameWonEvent.Reason.TURNS_HELD)
	battle.hold_turns = 10
	assert_eq(WinText.goal_tag(battle, 3, P1), ["あと 8 ターン守り切れば勝ち", false])
	assert_eq(WinText.goal_tag(battle, 9, P1), ["あと 2 ターン守り切れば勝ち", false])
	assert_eq(WinText.goal_tag(battle, 10, P1), ["最後のターン: 守り切れば勝ち", true])
	assert_eq(WinText.goal_tag(battle, 3, P2), ["あと 8 ターンで決着しなければ負け", false])
	assert_eq(WinText.goal_tag(battle, 10, P2), ["最後のターン: 決着しなければ負け", true])
	assert_true(WinText.goal_note(battle, P1).begins_with("10 ターン目の終わりまで守り切るか"))


func test_goal_tag_says_the_king_does_not_end_a_rout() -> void:
	var battle := Maps.battle(["....."])
	battle.add_unit(UnitKind.Id.KING, P2, Vector2i(4, 0))
	battle.win_conditions[P1] = [GameWonEvent.Reason.ROUTED]
	assert_eq(WinText.goal_tag(battle, 1, P1), ["勝ち: 敵の全滅（将を倒しても終わらない）", false])
	assert_eq(WinText.goal_tag(battle, 1, P2), ["全滅すると負け", false])
	assert_true(WinText.goal_note(battle, P1).contains("敵の将を倒しても"))


func test_boss_hunt_reads_as_a_boss_hunt() -> void:
	var battle := Maps.battle(["....."])
	battle.add_unit(UnitKind.Id.KING, P2, Vector2i(4, 0))
	battle.win_conditions[P1] = [GameWonEvent.Reason.BOSS_SLAIN]
	assert_eq(WinText.goal_tag(battle, 1, P1), ["勝ち: 中ボスの撃破（将を倒しても終わらない）", false])
	assert_eq(WinText.goal_note(battle, P1).get_slice("\n", 0), "中ボスを倒せば勝ち。敵の将を倒しても終わらない。")


func test_every_win_condition_has_a_place_in_the_text() -> void:
	for condition: GameWonEvent.Reason in GameWonEvent.Reason.values():
		assert_true(WinText.ORDER.has(condition), "ORDER に %d が無い" % condition)
		var conditions: Array[Array] = [[condition], [condition]]
		var text := WinText.goal(conditions, 5, P1)
		assert_eq(text.split("\n").size(), 2, "勝ち方と負け方の 2 行にならない: %s" % text)
