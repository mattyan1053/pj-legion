extends RefCounted
## 決着の画面に出す、戦績の要点の文（BattleStats から作る）。ノードに依存しない（テストから呼べる）。

const ENDINGS := {
	BattleStats.Ending.NONE: "決着していない",
	BattleStats.Ending.KING_DEFEATED: "将の撃破",
	BattleStats.Ending.HQ_CAPTURED: "本陣の占拠",
	BattleStats.Ending.TURNS_HELD: "守り切り",
	BattleStats.Ending.ROUTED: "全滅",
	BattleStats.Ending.DRAW: "引き分け",
}


## 全体の 1 行、陣営ごとの 2 行（数と MVP）。side_names はプレイヤー番号ごとの名前。
static func text(stats: BattleStats, stage_name: String, side_names: Array[String]) -> String:
	var lines: Array[String] = []
	var head := "ターン %d　%s" % [stats.turns, ENDINGS[stats.ending]]
	if stage_name != "":
		head = "作戦領域: %s　%s" % [stage_name, head]
	lines.append(head)
	for side: Unit.Side in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
		lines.append("")
		lines.append_array(side_lines(stats, side, side_names[side]))
	return "\n".join(lines)


static func side_lines(stats: BattleStats, side: Unit.Side, side_name: String) -> Array[String]:
	var record := stats.sides[side]
	var parts: Array[String] = [
		"与えたダメージ %d" % record.damage,
		"敵軍撃破 %d 体" % record.kills,
		"倒された %d 体" % record.losses,
	]
	if record.neutral_kills > 0:
		var boss := "（中ボス %d）" % record.boss_kills if record.boss_kills > 0 else ""
		parts.append("中立撃破 %d 体%s" % [record.neutral_kills, boss])
	if record.healing > 0:
		parts.append("回復 %d" % record.healing)
	parts.append("スキル %d 回" % record.skill_uses)
	parts.append("必殺技 %d 回" % record.ult_uses)
	if record.level_ups > 0:
		parts.append("レベルアップ %d 回" % record.level_ups)
	if record.evolutions > 0:
		parts.append("進化 %d 体" % record.evolutions)
	if not record.relics.is_empty():
		var names: Array[String] = []
		for relic in record.relics:
			names.append(Relics.display_name(relic))
		parts.append("聖遺物 %s" % "・".join(names))
	var lines: Array[String] = ["%s: %s" % [side_name, "　".join(parts)]]
	var best := stats.mvp(side)
	if best != null:
		lines.append("　MVP %s　与えたダメージ %d　撃破 %d" % [unit_name(best), best.damage, best.kills])
	return lines


## 詳しい戦績の表の列（[鍵, 見出し]）。行は駒（table_rows）。
const COLUMNS := [
	[&"damage", "与えたダメージ"],
	[&"kills", "撃破"],
	[&"neutral_kills", "中立撃破"],
	[&"healing", "回復"],
	[&"skill_uses", "スキル"],
]


## 陣営の 1 行の要点（表の上に出す。「敵軍撃破 3 体　倒された 2 体　必殺技 1 回」など）。
static func side_summary(stats: BattleStats, side: Unit.Side) -> String:
	var record := stats.sides[side]
	var parts: Array[String] = ["敵軍撃破 %d 体" % record.kills, "倒された %d 体" % record.losses]
	if record.boss_kills > 0:
		parts.append("中ボス撃破 %d" % record.boss_kills)
	parts.append("必殺技 %d 回" % record.ult_uses)
	if not record.relics.is_empty():
		var names: Array[String] = []
		for relic in record.relics:
			names.append(Relics.display_name(relic))
		parts.append("聖遺物 %s" % "・".join(names))
	return "　".join(parts)


## 詳しい戦績の表の行（駒ごと。番号の小さい順 = 将から並びの順）。
## 1 行は {kind, side, evolved, name, defeated, mvp, damage, kills, neutral_kills, healing, skill_uses}。
static func table_rows(stats: BattleStats, side: Unit.Side) -> Array[Dictionary]:
	var best := stats.mvp(side)
	var rows: Array[Dictionary] = []
	for record in stats.records_of(side):
		rows.append({
			"kind": record.kind, "side": record.side, "evolved": record.evolution != Evolution.Id.NONE,
			"name": unit_name(record), "defeated": record.defeated, "mvp": record == best,
			"damage": record.damage, "kills": record.kills, "neutral_kills": record.neutral_kills,
			"healing": record.healing, "skill_uses": record.skill_uses,
		})
	return rows


## 駒の名前。進化していれば、進化先の名前も付ける。レベルも付ける。
static func unit_name(record: BattleStats.UnitRecord) -> String:
	var kind_name := UnitKind.display_name(record.kind)
	if record.evolution != Evolution.Id.NONE:
		kind_name += "（%s）" % Evolution.display_name(record.evolution)
	return "%s Lv%d" % [kind_name, record.level]
