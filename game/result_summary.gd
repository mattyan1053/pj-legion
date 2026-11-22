extends RefCounted
## リザルトの画面（result_screen.gd）に出すもの。BattleStats と対戦設定から作る。ノードに依存しない（テストから呼べる）。
##
## 段階ごとに出すもの: 勝敗の見出し → 戦績（マップ・経過ターン・敵軍撃破・中立撃破・聖遺物） → MVP → 行き先。
## 誰の戦績を出すか（focus_side）は対戦の種類で決める: CPU 戦は人の側、人どうしは勝った側（引き分けならプレイヤー1）。

const Names := preload("res://game/names.gd")
const Text := preload("res://game/text.gd")
const StatsText := preload("res://game/stats_text.gd")

## 見出しの色の種類。
enum Tone { VICTORY, DEFEAT, SIDE, DRAW }

## 勝敗の見出し（VICTORY / DEFEAT / DRAW、人どうしは「<勝った側> の勝ち」「引き分け」）。
var headline := ""
var tone := Tone.DRAW
## 見出しの下の 1 行（決着の理由。CPU 戦は、どちらが勝ったかも添える。ストーリーは遊ぶ人の側から「敗北　将が倒れた」）。
var reason := ""
## 勝った陣営（引き分けなら NEUTRAL）。見出しの色（Tone.SIDE）に使う。
var winner := Unit.Side.NEUTRAL
## 戦績と MVP を出す陣営と、その名前。
var focus_side := Unit.Side.PLAYER1
var focus_name := ""
## 戦績の行（[項目, 値] の列。上から順に出す）。
var lines: Array = []
## MVP（いなければ mvp_name が空）。
var mvp_name := ""
var mvp_damage := 0
var mvp_kills := 0
## MVP の数の 1 行（StatsText.mvp_numbers）。
var mvp_numbers := ""
## MVP の駒の種類・陣営・進化したか（アイコンに使う。mvp_name が空なら見ない）。
var mvp_kind := UnitKind.Id.KING
var mvp_side := Unit.Side.PLAYER1
var mvp_evolved := false
## 両方の陣営の詳しい戦績（stats_text.gd。畳んでおき、ボタンで開く）。detail は文、tables は表（画面に出すのは表）。
var detail := ""
## 全体の 1 行（マップ・ターン・決着の仕方）。
var detail_head := ""
## プレイヤー番号ごとの {name: 陣営の名前, summary: 陣営の 1 行, rows: 駒ごとの行（StatsText.table_rows）}。
var tables: Array[Dictionary] = []


## ストーリーで負けたときの理由（遊ぶ人の側から。勝ったときは battle_log.gd の WIN_TEXTS が、もう遊ぶ人の側から書いてある）。
const LOSS_TEXTS := {
	GameWonEvent.Reason.KING_DEFEATED: "result.lost.king_defeated",
	GameWonEvent.Reason.HQ_CAPTURED: "result.lost.hq_captured",
	GameWonEvent.Reason.TURNS_HELD: "result.lost.turns_held",
	GameWonEvent.Reason.ROUTED: "result.lost.routed",
	GameWonEvent.Reason.BOSS_SLAIN: "result.lost.boss_slain",
	GameWonEvent.Reason.STRONGHOLD_HELD: "result.lost.stronghold_held",
}


## ストーリーの決着の 1 行（遊ぶ人 human_side の側から）: 「勝利　敵の将を倒した」「敗北　将が倒れた」。
## why は決着の理由（GameWonEvent.Reason）、win_text は勝った側から書いた理由の文。
static func story_reason(won: bool, why: GameWonEvent.Reason, win_text: String) -> String:
	if won:
		return Text.t("result.story.won", {"reason": win_text})
	return Text.t("result.story.lost", {"reason": Text.t(LOSS_TEXTS[why])})


## stats: 決着した対戦の戦績。draw なら引き分けで winner は見ない。reason: 決着の理由の文。
## against_cpu: CPU との対戦か。human_side: CPU 戦で人が動かす側。side_names: プレイヤー番号ごとの名前。
## story_reason_text: ストーリーなら、遊ぶ人の側から書いた決着の 1 行（story_reason）。空なら、CPU 戦は「<勝った側>の勝ち　理由」。
static func of(stats: BattleStats, draw: bool, winner_side: Unit.Side, reason_text: String, against_cpu: bool,
		human_side: Unit.Side, side_names: Array[String], map_name: String, story_reason_text := "") -> RefCounted:
	var summary := new()
	summary.winner = Unit.Side.NEUTRAL if draw else winner_side
	if against_cpu:
		summary.focus_side = human_side
		if draw:
			summary.headline = "DRAW"
			summary.tone = Tone.DRAW
		elif winner_side == human_side:
			summary.headline = "VICTORY"
			summary.tone = Tone.VICTORY
		else:
			summary.headline = "DEFEAT"
			summary.tone = Tone.DEFEAT
	else:
		summary.focus_side = Unit.Side.PLAYER1 if draw else winner_side
		summary.headline = Text.t("stats.ending.draw") if draw else Text.t("result.won", {"side": side_names[winner_side]})
		summary.tone = Tone.DRAW if draw else Tone.SIDE
	summary.reason = reason_text
	if story_reason_text != "":
		summary.reason = story_reason_text
	elif against_cpu and not draw:
		summary.reason = Text.t("result.won_reason", {"side": side_names[winner_side], "reason": reason_text})
	summary.focus_name = side_names[summary.focus_side]

	var record: BattleStats.SideRecord = stats.sides[summary.focus_side]
	if map_name != "":
		summary.lines.append([Text.t("result.line.map"), map_name])
	summary.lines.append([Text.t("result.line.turns"), Text.t("result.line.turns.value", {"count": stats.turns})])
	summary.lines.append([Text.t("result.line.kills"), Text.t("result.line.units", {"count": record.kills})])
	if record.neutral_kills > 0:
		summary.lines.append([Text.t("result.line.neutral_kills"), Text.t("result.line.units", {"count": record.neutral_kills})])
	if not record.relics.is_empty():
		var names: Array[String] = []
		for relic in record.relics:
			names.append(Names.relic(relic))
		summary.lines.append([Text.t("result.line.relics"), Text.join_dot(names)])

	var best := stats.mvp(summary.focus_side)
	if best != null:
		summary.mvp_name = StatsText.unit_name(best)
		summary.mvp_damage = best.damage
		summary.mvp_kills = best.kills
		summary.mvp_numbers = StatsText.mvp_numbers(best)
		summary.mvp_kind = best.kind
		summary.mvp_side = best.side
		summary.mvp_evolved = best.evolution != Evolution.Id.NONE
	summary.detail = StatsText.text(stats, map_name, side_names)
	summary.detail_head = summary.detail.get_slice("\n", 0)
	for side: Unit.Side in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
		summary.tables.append({
			"name": side_names[side], "summary": StatsText.side_summary(stats, side), "rows": StatsText.table_rows(stats, side),
		})
	return summary
