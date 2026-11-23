extends RefCounted
## 決着の画面に出す、戦績の要点の文（BattleStats から作る）。ノードに依存しない（テストから呼べる）。

const Names := preload("res://game/names.gd")
const Text := preload("res://game/text.gd")

## 終わり方の名前（鍵は stats.ending.<終わり方の名前の小文字>）。
static func ending(of: BattleStats.Ending) -> String:
	return Text.t("stats.ending." + String(BattleStats.Ending.find_key(of)).to_lower())


## 全体の 1 行、陣営ごとの 2 行（数と MVP）。side_names はプレイヤー番号ごとの名前。
static func text(stats: BattleStats, map_name: String, side_names: Array[String]) -> String:
	var lines: Array[String] = []
	var head := Text.t("stats.head", {"turns": stats.turns, "ending": ending(stats.ending)})
	if map_name != "":
		head = Text.t("stats.head_map", {"map": map_name, "turns": stats.turns, "ending": ending(stats.ending)})
	lines.append(head)
	for side: Unit.Side in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
		lines.append("")
		lines.append_array(side_lines(stats, side, side_names[side]))
	return "\n".join(lines)


static func side_lines(stats: BattleStats, side: Unit.Side, side_name: String) -> Array[String]:
	var record := stats.sides[side]
	var parts: Array[String] = [
		Text.t("stats.damage", {"count": record.damage}),
		Text.t("stats.kills", {"count": record.kills}),
		Text.t("stats.losses", {"count": record.losses}),
	]
	if record.neutral_kills > 0:
		if record.boss_kills > 0:
			parts.append(Text.t("stats.neutral_kills_boss", {"count": record.neutral_kills, "boss_count": record.boss_kills}))
		else:
			parts.append(Text.t("stats.neutral_kills", {"count": record.neutral_kills}))
	if record.healing > 0:
		parts.append(Text.t("stats.healing", {"count": record.healing}))
	parts.append(Text.t("stats.skill_uses", {"count": record.skill_uses}))
	parts.append(Text.t("stats.ult_uses", {"count": record.ult_uses}))
	if record.level_ups > 0:
		parts.append(Text.t("stats.level_ups", {"count": record.level_ups}))
	if record.evolutions > 0:
		parts.append(Text.t("stats.evolutions", {"count": record.evolutions}))
	if not record.relics.is_empty():
		parts.append(Text.t("stats.relics", {"relics": _relic_names(record)}))
	var lines: Array[String] = [Text.t("stats.side", {"side": side_name, "parts": Text.t("battle.hud.separator").join(parts)})]
	var best := stats.mvp(side)
	if best != null:
		lines.append(Text.t("stats.mvp", {"unit": unit_name(best), "numbers": mvp_numbers(best)}))
	return lines


## MVP の駒の数の 1 行。敵のプレイヤーの駒へのダメージか撃破があれば、それを出す。
## 無ければ（中ボスの撃破だけで勝った話など）、中立の駒へのダメージと撃破、回復を出す。
static func mvp_numbers(record: BattleStats.UnitRecord) -> String:
	if record.damage > 0 or record.kills > 0:
		return Text.t("result.mvp_numbers", {"damage": record.damage, "kills": record.kills})
	var parts: Array[String] = []
	if record.neutral_damage > 0 or record.neutral_kills > 0:
		parts.append(Text.t("result.mvp_neutral_numbers", {"damage": record.neutral_damage, "kills": record.neutral_kills}))
	if record.healing > 0:
		parts.append(Text.t("stats.healing", {"count": record.healing}))
	return Text.t("battle.hud.separator").join(parts)


## 詳しい戦績の表の列（[鍵, 見出しの表の鍵]）。行は駒（table_rows）。
const COLUMNS := [
	[&"damage", "stats.column.damage"],
	[&"damage_taken", "stats.column.damage_taken"],
	[&"kills", "stats.column.kills"],
	[&"neutral_kills", "stats.column.neutral_kills"],
	[&"healing", "stats.column.healing"],
	[&"skill_uses", "stats.column.skill_uses"],
]


## 陣営の 1 行の要点（表の上に出す。「敵軍撃破 3 体　倒された 2 体　必殺技 1 回」など）。
static func side_summary(stats: BattleStats, side: Unit.Side) -> String:
	var record := stats.sides[side]
	var parts: Array[String] = [Text.t("stats.kills", {"count": record.kills}), Text.t("stats.losses", {"count": record.losses})]
	if record.boss_kills > 0:
		parts.append(Text.t("stats.boss_kills", {"count": record.boss_kills}))
	parts.append(Text.t("stats.ult_uses", {"count": record.ult_uses}))
	if not record.relics.is_empty():
		parts.append(Text.t("stats.relics", {"relics": _relic_names(record)}))
	return Text.t("battle.hud.separator").join(parts)


## 持っている聖遺物の名前を「・」でつないだもの。
static func _relic_names(record: BattleStats.SideRecord) -> String:
	var names: Array[String] = []
	for relic in record.relics:
		names.append(Names.relic(relic))
	return Text.join_dot(names)


## 詳しい戦績の表の行（駒ごと。番号の小さい順 = 将から並びの順）。
## 1 行は {kind, side, evolved, name, defeated, mvp, damage, damage_taken, kills, neutral_kills, healing, skill_uses}。
static func table_rows(stats: BattleStats, side: Unit.Side) -> Array[Dictionary]:
	var best := stats.mvp(side)
	var rows: Array[Dictionary] = []
	for record in stats.records_of(side):
		rows.append({
			"kind": record.kind, "side": record.side, "evolved": record.evolution != Evolution.Id.NONE,
			"name": unit_name(record), "defeated": record.defeated, "mvp": record == best,
			"damage": record.damage, "damage_taken": record.damage_taken, "kills": record.kills, "neutral_kills": record.neutral_kills,
			"healing": record.healing, "skill_uses": record.skill_uses,
		})
	return rows


## 駒の名前。進化していれば、進化先の名前も付ける。レベルも付ける。
static func unit_name(record: BattleStats.UnitRecord) -> String:
	if record.evolution != Evolution.Id.NONE:
		return Text.t("stats.unit_evolved", {"kind": Names.kind(record.kind), "evolution": Names.evolution(record.evolution), "level": record.level})
	return Text.t("stats.unit", {"kind": Names.kind(record.kind), "level": record.level})
