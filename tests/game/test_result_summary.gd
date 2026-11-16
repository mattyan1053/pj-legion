extends "res://tests/base_test.gd"
## リザルトの画面に出すもの（game/result_summary.gd）。

const ResultSummary := preload("res://game/result_summary.gd")
const Maps := preload("res://tests/support/maps.gd")

const NAMES: Array[String] = ["青", "赤"]
const P1 := Unit.Side.PLAYER1
const P2 := Unit.Side.PLAYER2


func _stats() -> BattleStats:
	var battle := Maps.battle(["......"])
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(5, 0))
	var stats := BattleStats.new(battle)
	stats.units[sniper.id].damage = 42
	stats.units[sniper.id].kills = 2
	stats.units[paladin.id].damage = 7
	stats.sides[0].kills = 2
	stats.sides[0].neutral_kills = 3
	stats.sides[0].relics = [Relics.Id.WISDOM] as Array[Relics.Id]
	stats.sides[1].kills = 1
	stats.ending = BattleStats.Ending.KING_DEFEATED
	stats.turns = 14
	return stats


func test_cpu_match_says_victory_or_defeat_for_the_human() -> void:
	var won: RefCounted = ResultSummary.of(_stats(), false, P1, "敵の将を倒した", true, P1, NAMES, "中央平原")
	assert_eq(won.headline, "VICTORY")
	assert_eq(won.tone, ResultSummary.Tone.VICTORY)
	assert_eq(won.focus_side, P1)
	var lost: RefCounted = ResultSummary.of(_stats(), false, P1, "敵の将を倒した", true, P2, NAMES, "中央平原")
	assert_eq(lost.headline, "DEFEAT", "人が後手で、先手（CPU）が勝った")
	assert_eq(lost.focus_side, P2, "戦績は人の側")
	assert_true(lost.reason.begins_with("青 の勝ち"), lost.reason)
	var draw: RefCounted = ResultSummary.of(_stats(), true, Unit.Side.NEUTRAL, "両方の将", true, P1, NAMES, "")
	assert_eq(draw.headline, "DRAW")
	assert_eq(draw.winner, Unit.Side.NEUTRAL)


func test_local_match_names_the_winner_and_shows_the_winners_record() -> void:
	var summary: RefCounted = ResultSummary.of(_stats(), false, P2, "敵の本陣を占拠し続けた", false, P1, NAMES, "迷宮回廊")
	assert_eq(summary.headline, "赤 の勝ち")
	assert_eq(summary.tone, ResultSummary.Tone.SIDE)
	assert_eq(summary.focus_side, P2, "人どうしは勝った側の戦績")
	assert_eq(summary.lines[2], ["敵軍撃破", "1 体"])
	assert_eq(summary.mvp_damage, 7, "MVP も勝った側から")
	var draw: RefCounted = ResultSummary.of(_stats(), true, Unit.Side.NEUTRAL, "両方の将", false, P1, NAMES, "")
	assert_eq(draw.headline, "引き分け")
	assert_eq(draw.focus_side, P1, "引き分けはプレイヤー1")


func test_lines_have_the_stage_turns_kills_and_relics() -> void:
	var summary: RefCounted = ResultSummary.of(_stats(), false, P1, "", true, P1, NAMES, "双子結晶")
	assert_eq(summary.lines, [
		["作戦領域", "双子結晶"],
		["経過ターン", "14 ターン"],
		["敵軍撃破", "2 体"],
		["中立撃破", "3 体"],
		["聖遺物", Relics.display_name(Relics.Id.WISDOM)],
	], "撃破は、敵のプレイヤーの駒と中立の駒（中ボスを含む）を分けて出す")
	assert_eq(summary.mvp_name, "%s Lv1" % UnitKind.display_name(UnitKind.Id.SNIPER))
	assert_eq([summary.mvp_damage, summary.mvp_kills], [42, 2])
	assert_true(summary.detail.contains("赤: 与えたダメージ"), "詳しい戦績は両方の陣営")


func test_no_relics_and_no_mvp_are_left_out() -> void:
	var battle := Maps.battle(["......"])
	battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	var summary: RefCounted = ResultSummary.of(BattleStats.new(battle), false, P1, "", true, P1, NAMES, "")
	assert_eq(summary.lines.size(), 2, "作戦領域・中立撃破・聖遺物は、無ければ出さない")
	assert_eq(summary.mvp_name, "")
