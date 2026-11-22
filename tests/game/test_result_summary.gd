extends "res://tests/base_test.gd"
## リザルトの画面に出すもの（game/result_summary.gd）。

const Names := preload("res://game/names.gd")
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
	assert_true(lost.reason.begins_with("青の勝ち"), lost.reason)
	var draw: RefCounted = ResultSummary.of(_stats(), true, Unit.Side.NEUTRAL, "両方の将", true, P1, NAMES, "")
	assert_eq(draw.headline, "DRAW")
	assert_eq(draw.winner, Unit.Side.NEUTRAL)


func test_local_match_names_the_winner_and_shows_the_winners_record() -> void:
	var summary: RefCounted = ResultSummary.of(_stats(), false, P2, "敵の本陣を占拠し続けた", false, P1, NAMES, "迷宮回廊")
	assert_eq(summary.headline, "赤の勝ち")
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
		["マップ", "双子結晶"],
		["経過ターン", "14 ターン"],
		["敵軍撃破", "2 体"],
		["中立撃破", "3 体"],
		["聖遺物", Names.relic(Relics.Id.WISDOM)],
	], "撃破は、敵のプレイヤーの駒と中立の駒（中ボスを含む）を分けて出す")
	assert_eq(summary.lines.size(), ResultSummary.MAX_LINES, "全部の行が出る戦績が、画面の取る行の数（MAX_LINES）")
	assert_eq(summary.mvp_name, "%s Lv1" % Names.kind(UnitKind.Id.SNIPER))
	assert_eq([summary.mvp_damage, summary.mvp_kills], [42, 2])
	assert_true(summary.detail.contains("赤: 与えたダメージ"), "詳しい戦績は両方の陣営")


func test_no_relics_and_no_mvp_are_left_out() -> void:
	var battle := Maps.battle(["......"])
	battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	var summary: RefCounted = ResultSummary.of(BattleStats.new(battle), false, P1, "", true, P1, NAMES, "")
	assert_eq(summary.lines.size(), 2, "マップ・中立撃破・聖遺物は、無ければ出さない")
	assert_eq(summary.mvp_name, "")


func test_tables_have_a_row_per_unit_and_mark_the_mvp() -> void:
	var battle := Maps.battle(["......"])
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	var medic := battle.add_unit(UnitKind.Id.MEDIC, P1, Vector2i(1, 0))
	battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(5, 0))
	var stats := BattleStats.new(battle)
	stats.units[sniper.id].damage = 30
	stats.units[medic.id].healing = 12
	stats.units[medic.id].defeated = true
	var summary: RefCounted = ResultSummary.of(stats, false, P1, "", false, P1, NAMES, "")
	assert_eq(summary.tables.size(), 2, "両方の陣営の表")
	var rows: Array = summary.tables[0]["rows"]
	assert_eq(rows.size(), 2, "駒ごとに 1 行")
	assert_true(rows[0]["mvp"] and not rows[1]["mvp"], "MVP の行に印")
	assert_eq(rows[0]["damage"], 30)
	assert_eq(rows[1]["healing"], 12)
	assert_true(rows[1]["defeated"])
	assert_eq(summary.tables[1]["rows"].size(), 1)
	assert_eq(summary.tables[1]["name"], "赤")


func test_story_says_what_happened_from_the_players_side() -> void:
	var lost_line := ResultSummary.story_reason(false, GameWonEvent.Reason.KING_DEFEATED, "敵の将を倒した")
	assert_eq(lost_line, "敗北　将が倒れた", "負けは、遊ぶ人の側から何が起きたか")
	assert_eq(ResultSummary.story_reason(false, GameWonEvent.Reason.HQ_CAPTURED, ""), "敗北　本陣を取られた")
	assert_eq(ResultSummary.story_reason(true, GameWonEvent.Reason.TURNS_HELD, "最後まで守り切った"), "勝利　最後まで守り切った")
	for reason: GameWonEvent.Reason in GameWonEvent.Reason.values():
		assert_true(ResultSummary.LOSS_TEXTS.has(reason), "負けの理由の文が無い: %s" % GameWonEvent.Reason.find_key(reason))
	var lost: RefCounted = ResultSummary.of(_stats(), false, P2, "敵の将を倒した", true, P1, NAMES, "", lost_line)
	assert_eq(lost.reason, lost_line, "「CPU（赤）の勝ち」と書かない")
	assert_eq(lost.headline, "DEFEAT")


func test_story_calls_the_sides_friend_and_foe() -> void:
	Names.story_sides = true
	var friend := Names.side(P1)
	var foe := Names.side_word(P2)
	var neutral := Names.side(Unit.Side.NEUTRAL)
	Names.story_sides = false
	assert_eq([friend, foe, neutral], ["味方", "敵", "中立"])
	assert_eq(Names.side_word(P2), "赤", "対戦モードは色で呼ぶ")
