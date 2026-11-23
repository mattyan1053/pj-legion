extends RefCounted
## CPU どうしの対戦の集計（tools/cpu_matches.gd）の 1 行ぶん（全体、マップごと、軍の組み合わせごと）。

const CpuMatch := preload("res://tools/cpu_match.gd")


var games := 0
var endings := {"king": 0, "hq": 0, "held": 0, "routed": 0, "boss": 0, "point": 0, "draw": 0, "cutoff": 0}
var wins: Array[int] = [0, 0]
var turns: Array[int] = []
var level_ups := 0
var evolutions := 0
var games_with_evolution := 0
var first_evolution_turns: Array[int] = []
## 軍の違う対戦で、[MILITARY の勝ち, FANTASY の勝ち]。
var army_wins: Array[int] = [0, 0]
var neutral_kills := 0
var losses := 0
## 中ボス: 1 体でも倒れた局の数、倒れた数、倒れたターン、倒した側が勝った数・負けた数（決着した局だけ）。
var boss_games := 0
var boss_kills := 0
var boss_turns: Array[int] = []
var boss_slayer_wins := 0
var boss_slayer_losses := 0
## 倒した陣営のいる中ボスの倒れ方: [数, 倒した側の勝ち, 負け] を、全部・互角のうち（戦える駒の差が 1 以内）・相手がそばにいた・
## 相手が多く削った止めの横取り、で。勝ち負けは決着した局だけ。
var boss_all: Array[int] = [0, 0, 0]
var boss_even: Array[int] = [0, 0, 0]
var boss_contested: Array[int] = [0, 0, 0]
var boss_steals: Array[int] = [0, 0, 0]
## 倒した側の削った量の分け前で分けた [数, 勝ち, 負け]: 3 割未満（CpuMatch.LOW_SHARE）、うち止めの一撃だけ、3 割以上。
var boss_low: Array[int] = [0, 0, 0]
var boss_finish_only: Array[int] = [0, 0, 0]
var boss_high: Array[int] = [0, 0, 0]
## 互角のうちに中ボスが倒れた局の数（1 局で 2 体倒れても 1 と数える）。
var boss_even_games := 0
## 両方のプレイヤーが削った中ボスの数。
var boss_shared := 0
## 中ボスの番号ごと、倒したプレイヤーごとの数。
var boss_by_index: Array[int] = [0, 0]
var boss_by_side: Array[int] = [0, 0]
## 倒した側の戦力（将を除く駒の HP の合計）の分け前で分けた [数, 勝ち, 負け]。0 = 劣勢、1 = 互角、2 = 優勢
## （互角 = 分け前が 0.5 から CpuMatch.EVEN_SHARE 以内）。倒れた時点と、狩りが始まった時点（初めて削られた時点）。
var boss_lead: Array[Array] = [[0, 0, 0], [0, 0, 0], [0, 0, 0]]
var boss_first_lead: Array[Array] = [[0, 0, 0], [0, 0, 0], [0, 0, 0]]
## 削られ始めてから倒れるまでのターンの合計。
var boss_hunt_turns := 0
## 最初に相手のプレイヤーの駒へ当てた・倒したプレイヤー（0 = 先手、1 = 後手）ごとの [局, そのプレイヤーが勝った局, 決着した局, ターンの合計]。
var first_hit: Array[Array] = [[0, 0, 0, 0], [0, 0, 0, 0]]
var first_kill: Array[Array] = [[0, 0, 0, 0], [0, 0, 0, 0]]

func add(outcome: CpuMatch.Outcome) -> void:
	games += 1
	endings[outcome.ending] += 1
	if outcome.winner >= 0:
		wins[outcome.winner] += 1
	turns.append(outcome.turns)
	level_ups += outcome.level_ups[0] + outcome.level_ups[1]
	var evolved := outcome.evolutions[0] + outcome.evolutions[1]
	evolutions += evolved
	if evolved > 0:
		games_with_evolution += 1
		first_evolution_turns.append(outcome.first_evolution_turn)
	neutral_kills += outcome.neutral_kills[0] + outcome.neutral_kills[1]
	losses += outcome.losses[0] + outcome.losses[1]
	if not outcome.mid_boss_kills.is_empty():
		boss_games += 1
	for kill: Array in outcome.mid_boss_kills:
		boss_kills += 1
		boss_turns.append(kill[0])
		if outcome.winner >= 0 and kill[1] >= 0:
			if kill[1] == outcome.winner:
				boss_slayer_wins += 1
			else:
				boss_slayer_losses += 1
	var even_game := false
	for fall in outcome.boss_falls:
		if fall.slayer_side < 0:
			continue
		even_game = even_game or fall.is_even()
		boss_by_index[fall.boss_index] += 1
		boss_by_side[fall.slayer_side] += 1
		boss_shared += 1 if fall.slayer_damage > 0 and fall.rival_damage > 0 else 0
		var won := 1 if outcome.winner == fall.slayer_side else (2 if outcome.winner >= 0 else 0)
		var rows: Array[Array] = [boss_all]
		if fall.is_even():
			rows.append(boss_even)
		if fall.is_contested():
			rows.append(boss_contested)
		if fall.is_steal():
			rows.append(boss_steals)
		rows.append(boss_low if fall.is_low_share() else boss_high)
		if fall.is_low_share() and fall.is_finish_only():
			rows.append(boss_finish_only)
		rows.append(boss_lead[_lead(fall.hp_share())])
		rows.append(boss_first_lead[_lead(fall.first_hp_share())])
		boss_hunt_turns += fall.turn - fall.first_hit_turn
		for row in rows:
			row[0] += 1
			if won > 0:
				row[won] += 1
	if even_game:
		boss_even_games += 1
	for pair: Array in [[first_hit, outcome.first_hit_side, outcome.first_hit_turn], [first_kill, outcome.first_kill_side, outcome.first_kill_turn]]:
		if pair[1] < 0:
			continue
		var row: Array = pair[0][pair[1]]
		row[0] += 1
		row[1] += 1 if outcome.winner == pair[1] else 0
		row[2] += 1 if outcome.winner >= 0 else 0
		row[3] += pair[2]

## 最初に当てた側・最初に倒した側の行（先に手を出した側が得をしているかを見る）。
func first_line(name: String) -> String:
	var parts: Array[String] = []
	for pair: Array in [["当てた", first_hit], ["倒した", first_kill]]:
		var rows: Array = pair[1]
		var count: int = rows[0][0] + rows[1][0]
		var won: int = rows[0][1] + rows[1][1]
		var decided: int = rows[0][2] + rows[1][2]
		var turn_total: int = rows[0][3] + rows[1][3]
		parts.append("最初に%s 先手 %3d 後手 %3d（後手 %3.0f%%。平均ターン %4.1f）その側の勝ち %3d / %3d（%3.0f%%）" % [
			pair[0], rows[0][0], rows[1][0], 100.0 * rows[1][0] / maxi(1, count), float(turn_total) / maxi(1, count),
			won, decided, 100.0 * won / maxi(1, decided),
		])
	return "%-22s %s" % [name, "  ".join(parts)]

## 中ボスの取り合いの行（互角のまま倒れたか、相手がそばにいたか、止めの横取りか）。
func contest_line(name: String) -> String:
	return "%-22s 倒れた %3d 体（左 %d 右 %d、先手 %d 後手 %d）  互角のうち %3d 体（%3.0f%%。局の %3.0f%%）倒した側 %s  相手がそばに %3d 体（%3.0f%%）倒した側 %s  両方が削った %3d 体  横取り %3d 体 倒した側 %s" % [
		name, boss_all[0], boss_by_index[0], boss_by_index[1], boss_by_side[0], boss_by_side[1],
		boss_even[0], 100.0 * boss_even[0] / maxi(1, boss_all[0]), 100.0 * boss_even_games / maxi(1, games), _record(boss_even),
		boss_contested[0], 100.0 * boss_contested[0] / maxi(1, boss_all[0]), _record(boss_contested),
		boss_shared, boss_steals[0], _record(boss_steals),
	]

## 削った量の少ない側が止めで取った中ボスの行（docs/relic-buff.md の「受け取る」）。
func share_line(name: String) -> String:
	return "%-22s 3 割未満 %3d 体（%3.0f%%）倒した側 %s  うち止めの一撃だけ %3d 体 倒した側 %s  3 割以上 %3d 体 倒した側 %s" % [
		name, boss_low[0], 100.0 * boss_low[0] / maxi(1, boss_all[0]), _record(boss_low),
		boss_finish_only[0], _record(boss_finish_only), boss_high[0], _record(boss_high),
	]

## 戦力の分け前を、劣勢 0、互角 1、優勢 2 に分ける。
static func _lead(share: float) -> int:
	if share < 0.5 - CpuMatch.EVEN_SHARE:
		return 0
	return 2 if share > 0.5 + CpuMatch.EVEN_SHARE else 1

## 倒した側が、もともと優勢だったか（戦力の分け前で分けた勝ち負け）。残った中ボスの数も。
func lead_line(name: String) -> String:
	var parts: Array[String] = []
	for rows: Array[Array] in [boss_first_lead, boss_lead]:
		var cells: Array[String] = []
		for i in 3:
			cells.append("%s %3d 体 %s" % [["劣勢", "互角", "優勢"][i], rows[i][0], _record(rows[i])])
		parts.append("  ".join(cells))
	return "%-22s 狩り始め: %s ／ 倒れた時: %s  削られてから倒れるまで 平均 %.1f ターン  最後まで残った中ボス %d 体 / %d（%3.0f%%）" % [
		name, parts[0], parts[1], float(boss_hunt_turns) / maxi(1, boss_all[0]),
		games * 2 - boss_kills, games * 2, 100.0 * (games * 2 - boss_kills) / maxi(1, games * 2),
	]

func _record(row: Array) -> String:
	return "%d 勝 %d 敗（%.0f%%）" % [row[1], row[2], 100.0 * row[1] / maxi(1, row[1] + row[2])]

func boss_line(name: String) -> String:
	var sorted := boss_turns.duplicate()
	sorted.sort()
	var total := 0
	for value: int in sorted:
		total += value
	@warning_ignore("integer_division")
	var median: int = 0 if sorted.is_empty() else sorted[sorted.size() / 2]
	return "%-22s 倒れた局 %3.0f%%  1 局あたり %4.2f 体  倒れたターン 平均 %4.1f 中央 %2d  倒した側 %3d 勝 %3d 敗（%3.0f%%）" % [
		name, 100.0 * boss_games / maxi(1, games), float(boss_kills) / maxi(1, games),
		float(total) / maxi(1, sorted.size()), median,
		boss_slayer_wins, boss_slayer_losses, 100.0 * boss_slayer_wins / maxi(1, boss_slayer_wins + boss_slayer_losses),
	]

func line(name: String) -> String:
	var sorted := turns.duplicate()
	sorted.sort()
	var total := 0
	for value: int in sorted:
		total += value
	@warning_ignore("integer_division")
	var median: int = sorted[sorted.size() / 2]
	var first := first_evolution_turns.duplicate()
	first.sort()
	var first_total := 0
	for value: int in first:
		first_total += value
	@warning_ignore("integer_division")
	var first_median: int = 0 if first.is_empty() else first[first.size() / 2]
	var text := "%-22s %4d 局  ターン 平均 %5.1f 中央 %3d（%d〜%d）  将 %3d 本陣 %3d 引分 %2d 打切 %2d  先手 %3d 後手 %3d  Lv↑ %5.2f 進化 %5.2f（%3d%% の局。最初は平均ターン %4.1f、中央 %2d）  中立撃破 %5.2f  撃破 %5.2f" % [
		name, games, float(total) / games, median, sorted[0], sorted[-1],
		endings["king"], endings["hq"], endings["draw"], endings["cutoff"], wins[0], wins[1],
		float(level_ups) / games, float(evolutions) / games, roundi(100.0 * games_with_evolution / games),
		float(first_total) / maxi(1, first.size()), first_median,
		float(neutral_kills) / games, float(losses) / games,
	]
	if endings["held"] > 0:
		text += "  守り切り %d" % endings["held"]
	if endings["routed"] > 0:
		text += "  全滅 %d" % endings["routed"]
	if endings["boss"] > 0:
		text += "  中ボス %d" % endings["boss"]
	if endings["point"] > 0:
		text += "  拠点 %d" % endings["point"]
	if army_wins[0] + army_wins[1] > 0:
		text += "  M %d 勝 F %d 勝（M %.0f%%）" % [army_wins[0], army_wins[1], 100.0 * army_wins[0] / (army_wins[0] + army_wins[1])]
	return text
