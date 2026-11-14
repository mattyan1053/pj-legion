extends SceneTree
## CPU どうしの対戦を画面なしで何局も回して、集計を出す（docs/cpu-ai.md の「集計の道具」）。
## 手元で回すもの。CI では回さない。
##
##   godot --headless --path . -s res://tools/cpu_matches.gd -- --games=120 --seed=1
##
##   --games=N       局数（既定 60）
##   --seed=S        最初の局のシード（既定 1）。局ごとに 1 ずつ増える
##   --max-turns=T   このターンを超えたら打ち切る（既定 60）
##   --decks=auto    編成。auto = CPU の編成（CpuDeck。予算に収まる）、even = 両軍とも同じ役割の 6 体・装備なし（予算は見ない）
##   --pairings=all  軍の組み合わせ。all = 4 通りを順に、mixed = 軍の違う 2 通り（先手を入れ替える）だけ
##   --rival=PATH    別の版の CPU（スクリプトのパス）と対戦させる。先手・後手は、ステージと軍の組み合わせを一巡するごとに入れ替わる
##   --list=1        1 局ごとに 1 行（GAME ...）も出す。シード、ステージ、軍、勝ったプレイヤー、終わり方、ターン、必殺技の回数、
##                   倒れた中ボス（ターン:倒した陣営:中ボスの番号）。局を何本かに分けて並べて回し、あとで合わせるときに使う
##   --hit=N --level=N   「当たりの経験値が N だったら」「1 レベルに要る経験値が N だったら」の見積もりに使う値（既定 15、80）
##
## ステージ（3 種）と軍の組み合わせ（4 通り。mixed なら 2 通り）を順に回すので、12 の倍数にすると偏らない
## （--rival を付けたら、その倍の 24 の倍数。mixed なら 12 の倍数）。
## 同じ引数なら、いつも同じ結果になる（考える時間の欄を除く）。

const CpuMatch := preload("res://tools/cpu_match.gd")

const ARMIES: Array[UnitKind.Army] = [UnitKind.Army.MILITARY, UnitKind.Army.FANTASY]
const ARMY_NAMES := {UnitKind.Army.MILITARY: "MILITARY", UnitKind.Army.FANTASY: "FANTASY"}
const STAGE_NAMES := {
	BoardGenerator.Stage.PLAIN: "1 中央平原",
	BoardGenerator.Stage.LABYRINTH: "2 迷宮回廊",
	BoardGenerator.Stage.TWIN_SPRINGS: "3 双子結晶",
}
const ENDINGS := {"king": "将の撃破", "hq": "本陣の占拠", "draw": "引き分け", "cutoff": "打ち切り"}
## 「両軍とも同じ役割」の編成（--decks=even）。Deck.roster の並び（前衛・後衛・奇襲・回復）の何番目を雇うか。
const EVEN_SLOTS: Array[int] = [0, 0, 1, 1, 2, 3]


## 集計の 1 行ぶん（全体、ステージごと、軍の組み合わせごと）。
class Tally:
	extends RefCounted
	var games := 0
	var endings := {"king": 0, "hq": 0, "draw": 0, "cutoff": 0}
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
		if army_wins[0] + army_wins[1] > 0:
			text += "  M %d 勝 F %d 勝（M %.0f%%）" % [army_wins[0], army_wins[1], 100.0 * army_wins[0] / (army_wins[0] + army_wins[1])]
		return text


func _initialize() -> void:
	var args := _arguments()
	var games: int = args.get("games", "60").to_int()
	var first_seed: int = args.get("seed", "1").to_int()
	var max_turns: int = args.get("max-turns", "60").to_int()
	var deck_mode: String = args.get("decks", "auto")
	var mixed_only: bool = args.get("pairings", "all") == "mixed"
	var what_if_hit: int = args.get("hit", "15").to_int()
	var what_if_level: int = args.get("level", "80").to_int()

	var all := Tally.new()
	var by_stage: Dictionary[int, Tally] = {}
	var by_match: Dictionary[String, Tally] = {}
	var army_wins := {UnitKind.Army.MILITARY: 0, UnitKind.Army.FANTASY: 0}
	var mixed_games := 0
	var hired := 0
	var gains: Array[int] = [0, 0, 0, 0, 0]  # 当てた、倒した、中立を倒した、回復した、中ボスを倒した 回数
	var by_kind: Dictionary[UnitKind.Id, Array] = {}
	var skill_uses: Dictionary[Skill.Id, int] = {}
	# 軍 -> [出た回数, 必殺技を使った回数, 使った側の数, そのうち勝った数, 使わなかった側の数, そのうち勝った数, 最初に使ったターンの合計, 1 回でも使った側の数]。
	# 勝ちの数は、決着した局だけ（使った側・使わなかった側の数も同じ）。
	var ults: Dictionary[UnitKind.Army, Array] = {}
	# 軍 -> [出た回数, 聖遺物を取った局, 英知の数, 勇気の数, 取った局のうち決着した数, そのうち勝った数, 相手だけが取った局のうち決着した数, そのうち勝った数]。
	var relics: Dictionary[UnitKind.Army, Array] = {}
	var reached := {"lv2": 0, "lv3": 0, "lv3_hit": 0, "lv3_level": 0, "lv3_both": 0}
	var actions := 0
	var think := 0.0
	var slowest := 0.0
	var rejected := 0
	var cpu := CpuPlayer.new()
	var rival: RefCounted = null
	if args.has("rival"):
		var script: GDScript = load(args["rival"])
		if script == null:
			printerr("--rival のスクリプトを読めない: %s" % args["rival"])
			quit(1)
			return
		rival = script.new()
	# いまの CPU と別の版の対戦の [いまの CPU の勝ち, 別の版の勝ち, 決着しなかった局]。全体と、ステージごと。
	var versus: Array[int] = [0, 0, 0]
	var versus_by_stage: Dictionary[int, Array] = {}
	# 駒の種類ごとの表を、[いまの CPU の駒, 別の版の駒] に分けたもの。局数も同じ並び（将の行に使う）。
	var versus_by_kind: Array[Dictionary] = [{}, {}]
	var started := Time.get_ticks_msec()

	for game in games:
		var stage := CpuMatch.STAGES[game % CpuMatch.STAGES.size()]
		@warning_ignore("integer_division")
		var pairing := (game / CpuMatch.STAGES.size()) % 4
		if mixed_only:
			pairing %= 2
		var armies: Array[UnitKind.Army] = [ARMIES[pairing % 2], ARMIES[(pairing % 2) ^ (0 if pairing >= 2 else 1)]]
		var decks: Array[Deck] = [_deck(armies[0], deck_mode), _deck(armies[1], deck_mode)]
		var battle := CpuMatch.create(stage, first_seed + game, decks)
		var outcome: CpuMatch.Outcome
		if rival == null:
			outcome = CpuMatch.play(battle, max_turns, cpu)
		else:
			# 別の版が動かす側。ステージと軍の組み合わせを一巡するごとに入れ替える。
			@warning_ignore("integer_division")
			var rival_side := (game / (CpuMatch.STAGES.size() * (2 if mixed_only else 4))) % 2
			outcome = CpuMatch.play(battle, max_turns, cpu if rival_side == 1 else rival, rival if rival_side == 1 else cpu)
			var slot := 2 if outcome.winner < 0 else (1 if outcome.winner == rival_side else 0)
			versus[slot] += 1
			versus_by_stage.get_or_add(stage, [0, 0, 0])[slot] += 1
			for side in 2:
				var table: Dictionary = versus_by_kind[1 if side == rival_side else 0]
				for kind: UnitKind.Id in outcome.by_side_kind[side]:
					var row: Array = table.get_or_add(kind, [0, 0, 0, 0, 0])
					for i in row.size():
						row[i] += outcome.by_side_kind[side][kind][i]

		if args.get("list", "0") == "1":
			var kills: Array[String] = []
			for kill: Array in outcome.mid_boss_kills:
				kills.append("%d:%d:%d" % [kill[0], kill[1], kill[2]])
			print("GAME seed=%d stage=%d p1=%s p2=%s winner=%d ending=%s turns=%d ults=%d,%d boss=%s" % [
				first_seed + game, stage, ARMY_NAMES[armies[0]], ARMY_NAMES[armies[1]], outcome.winner, outcome.ending,
				outcome.turns, outcome.ult_uses[0], outcome.ult_uses[1], ",".join(kills),
			])
		all.add(outcome)
		by_stage.get_or_add(stage, Tally.new()).add(outcome)
		var match_name := "%s 対 %s" % [ARMY_NAMES[armies[0]], ARMY_NAMES[armies[1]]]
		by_match.get_or_add(match_name, Tally.new()).add(outcome)
		if armies[0] != armies[1]:
			mixed_games += 1
			if outcome.winner >= 0:
				army_wins[armies[outcome.winner]] += 1
				by_stage[stage].army_wins[ARMIES.find(armies[outcome.winner])] += 1
		for kind in outcome.by_kind:
			var row: Array = by_kind.get_or_add(kind, [0, 0, 0, 0, 0])
			for i in row.size():
				row[i] += outcome.by_kind[kind][i]
		for side in 2:
			var row: Array = ults.get_or_add(armies[side], [0, 0, 0, 0, 0, 0, 0, 0])
			row[0] += 1
			row[1] += outcome.ult_uses[side]
			row[6] += outcome.first_ult_turn[side]
			row[7] += 1 if outcome.ult_uses[side] > 0 else 0
			if outcome.winner >= 0:
				var used := 2 if outcome.ult_uses[side] > 0 else 4
				row[used] += 1
				row[used + 1] += 1 if outcome.winner == side else 0
		for side in 2:
			var row: Array = relics.get_or_add(armies[side], [0, 0, 0, 0, 0, 0, 0, 0])
			var mine := 0
			var theirs := 0
			for kill: Array in outcome.mid_boss_kills:
				if kill[1] == side:
					mine += 1
					row[2 + (1 if Relics.of_boss(kill[2]) == Relics.Id.COURAGE else 0)] += 1
				elif kill[1] >= 0:
					theirs += 1
			row[0] += 1
			row[1] += 1 if mine > 0 else 0
			if outcome.winner >= 0 and mine > 0:
				row[4] += 1
				row[5] += 1 if outcome.winner == side else 0
			elif outcome.winner >= 0 and theirs > 0:
				row[6] += 1
				row[7] += 1 if outcome.winner == side else 0
		for skill in outcome.skill_uses:
			skill_uses[skill] = skill_uses.get(skill, 0) + outcome.skill_uses[skill]
		hired += outcome.hired[0] + outcome.hired[1]
		for unit_id in outcome.gains:
			var tally: Array = outcome.gains[unit_id]
			for i in 5:
				gains[i] += tally[i]
			var need := Growth.EXPERIENCE_PER_LEVEL
			if _experience(tally, Growth.HIT_EXPERIENCE) >= need:
				reached["lv2"] += 1
			if _experience(tally, Growth.HIT_EXPERIENCE) >= need * (Growth.MAX_LEVEL - 1):
				reached["lv3"] += 1
			if _experience(tally, what_if_hit) >= need * (Growth.MAX_LEVEL - 1):
				reached["lv3_hit"] += 1
			if _experience(tally, Growth.HIT_EXPERIENCE) >= what_if_level * (Growth.MAX_LEVEL - 1):
				reached["lv3_level"] += 1
			if _experience(tally, what_if_hit) >= what_if_level * (Growth.MAX_LEVEL - 1):
				reached["lv3_both"] += 1
		actions += outcome.actions
		think += outcome.think_msec
		slowest = maxf(slowest, outcome.slowest_msec)
		rejected += outcome.rejected

	print("CPU どうしの対戦 %d 局（シード %d〜%d、編成 %s、打ち切り %d ターン）" % [
		games, first_seed, first_seed + games - 1, deck_mode, max_turns,
	])
	for army in ARMIES:
		print("  編成 %s: %s" % [ARMY_NAMES[army], _deck_text(_deck(army, deck_mode))])
	print("")
	print(all.line("全体"))
	for stage: int in by_stage:
		print(by_stage[stage].line("ステージ " + STAGE_NAMES[stage]))
	for match_name in by_match:
		print(by_match[match_name].line(match_name))
	print("")
	print("")
	print("中ボス（倒した側の勝ち負けは、決着した局だけ。倒した側は、その中ボスの聖遺物を受け取る）")
	print(all.boss_line("全体"))
	for stage: int in by_stage:
		print(by_stage[stage].boss_line("ステージ " + STAGE_NAMES[stage]))
	print("")
	print("聖遺物（軍ごと。勝率は決着した局だけ。「相手だけ」は、自分は取らず、相手が取った局）")
	for army in ARMIES:
		var row: Array = relics.get(army, [0, 0, 0, 0, 0, 0, 0, 0])
		print("  %-9s 取った局 %3d / %3d（%3.0f%%）  英知 %3d  勇気 %3d  取った局の勝率 %3d 勝 / %3d（%3.0f%%）  相手だけが取った局の勝率 %3d 勝 / %3d（%3.0f%%）" % [
			ARMY_NAMES[army], row[1], row[0], 100.0 * row[1] / maxi(1, row[0]), row[2], row[3],
			row[5], row[4], 100.0 * row[5] / maxi(1, row[4]), row[7], row[6], 100.0 * row[7] / maxi(1, row[6]),
		])
	print("")
	var decided := all.wins[0] + all.wins[1]
	print("先手（プレイヤー1）の勝率: %.1f%%（決着した %d 局のうち）" % [100.0 * all.wins[0] / maxi(1, decided), decided])
	var mixed_decided: int = army_wins[UnitKind.Army.MILITARY] + army_wins[UnitKind.Army.FANTASY]
	print("軍の違う対戦 %d 局: MILITARY %d 勝、FANTASY %d 勝（MILITARY の勝率 %.1f%%）" % [
		mixed_games, army_wins[UnitKind.Army.MILITARY], army_wins[UnitKind.Army.FANTASY],
		100.0 * army_wins[UnitKind.Army.MILITARY] / maxi(1, mixed_decided),
	])
	if rival != null:
		print("")
		print("いまの CPU 対 別の版（%s）: いまの CPU %d 勝、別の版 %d 勝、決着なし %d（いまの CPU の勝率 %.1f%%）" % [
			args["rival"], versus[0], versus[1], versus[2], 100.0 * versus[0] / maxi(1, versus[0] + versus[1]),
		])
		for stage: int in versus_by_stage:
			var row: Array = versus_by_stage[stage]
			print("  ステージ %s: いまの CPU %d 勝、別の版 %d 勝、決着なし %d" % [STAGE_NAMES[stage], row[0], row[1], row[2]])
	print("")
	print("雇った駒 %d 体（1 局あたり %.1f 体）のうち" % [hired, float(hired) / games])
	print("  レベル 2 以上に届いた: %5.1f%%" % (100.0 * reached["lv2"] / hired))
	print("  レベル 3（進化）に届いた: %5.1f%%" % (100.0 * reached["lv3"] / hired))
	print("  同じ対局で、当たりの経験値が %d だったら: %5.1f%%" % [what_if_hit, 100.0 * reached["lv3_hit"] / hired])
	print("  同じ対局で、1 レベルに要る経験値が %d だったら: %5.1f%%" % [what_if_level, 100.0 * reached["lv3_level"] / hired])
	print("  その両方だったら: %5.1f%%" % (100.0 * reached["lv3_both"] / hired))
	print("  （「だったら」は、同じ手順の対局で経験値だけを数え直した見積もり。数値が変われば CPU の手も変わるので、目安）")
	var sources: Array[int] = [
		gains[0] * Growth.HIT_EXPERIENCE, gains[1] * Growth.DEFEAT_EXPERIENCE,
		gains[2] * Growth.NEUTRAL_DEFEAT_EXPERIENCE, gains[3] * Growth.HEAL_EXPERIENCE,
		gains[4] * Growth.MID_BOSS_DEFEAT_EXPERIENCE,
	]
	var earned := sources[0] + sources[1] + sources[2] + sources[3] + sources[4]
	print("入った経験値: 1 局あたり %.0f（雇った駒 1 体あたり %.0f）" % [float(earned) / games, float(earned) / hired])
	print("  内訳: 当たり %.0f%%（%.1f 回）、撃破 %.0f%%（%.1f 回）、中立の撃破 %.0f%%（%.1f 回）、回復 %.0f%%（%.1f 回）、中ボスの撃破 %.0f%%（%.2f 回）。回数は 1 局あたり" % [
		100.0 * sources[0] / maxi(1, earned), float(gains[0]) / games, 100.0 * sources[1] / maxi(1, earned), float(gains[1]) / games,
		100.0 * sources[2] / maxi(1, earned), float(gains[2]) / games, 100.0 * sources[3] / maxi(1, earned), float(gains[3]) / games,
		100.0 * sources[4] / maxi(1, earned), float(gains[4]) / games,
	])
	print("")
	print("駒の種類ごと（1 体あたり。将は 1 局・1 体あたり）")
	_print_kinds(by_kind, games * 2)
	if rival != null:
		print("  うち、いまの CPU の駒")
		_print_kinds(versus_by_kind[0], games)
		print("  うち、別の版の駒")
		_print_kinds(versus_by_kind[1], games)
	print("")
	print("スキルを使った回数（その駒を雇った 1 体あたり）")
	for skill in Skills.ALL:
		var row: Array = by_kind.get(skill.kind(), [0])
		print("  %-12s %5d 回（%4.2f）" % [skill.display_name(), skill_uses.get(skill.id(), 0), float(skill_uses.get(skill.id(), 0)) / maxi(1, row[0])])
	print("")
	print("必殺技（軍ごと。1 局・1 軍あたり。勝率は決着した局だけ）")
	for army in ARMIES:
		var row: Array = ults.get(army, [0, 0, 0, 0, 0, 0, 0, 0])
		print("  %-9s %-6s 使った %4d 回（%4.2f。使った側は %3.0f%%）  最初に使ったターン 平均 %4.1f  使った側 %3d 勝 / %3d（%3.0f%%）  使わなかった側 %3d 勝 / %3d（%3.0f%%）" % [
			ARMY_NAMES[army], Ults.of_army(army).display_name(), row[1], float(row[1]) / maxi(1, row[0]), 100.0 * row[7] / maxi(1, row[0]),
			float(row[6]) / maxi(1, row[7]), row[3], row[2], 100.0 * row[3] / maxi(1, row[2]),
			row[5], row[4], 100.0 * row[5] / maxi(1, row[4]),
		])
	print("")
	print("行動 %d 回。考える時間: 1 手の平均 %.1f ms、最長 %.1f ms。全体で %.1f 秒" % [
		actions, think / maxi(1, actions), slowest, (Time.get_ticks_msec() - started) / 1000.0,
	])
	if rejected > 0:
		printerr("断られた行動が %d 回あった（CPU の不具合）" % rejected)
	quit(1 if rejected > 0 else 0)


## 駒の種類ごとの表（種類 -> [雇った数, 倒された数, 与えたダメージ, 倒した数, 進化した数]）を、1 体あたりで出す。
## kings は、将の行を割る数（将は雇った数が 0 なので、出た局の数で割る）。
func _print_kinds(by_kind: Dictionary, kings: int) -> void:
	var kind_ids := by_kind.keys()
	kind_ids.sort()
	for kind: UnitKind.Id in kind_ids:
		var row: Array = by_kind[kind]
		var count: int = row[0] if row[0] > 0 else kings
		print("  %-12s 雇った %4d 体  倒された %3.0f%%  与えたダメージ %5.1f  倒した %4.2f  進化した %3.0f%%" % [
			UnitKind.display_name(kind), row[0], 100.0 * row[1] / count, float(row[2]) / count,
			float(row[3]) / count, 100.0 * row[4] / count,
		])


## その駒に入った経験値の合計（当たりの経験値が hit のとき）。
func _experience(tally: Array, hit: int) -> int:
	return (
		tally[0] * hit + tally[1] * Growth.DEFEAT_EXPERIENCE
		+ tally[2] * Growth.NEUTRAL_DEFEAT_EXPERIENCE + tally[3] * Growth.HEAL_EXPERIENCE
		+ tally[4] * Growth.MID_BOSS_DEFEAT_EXPERIENCE
	)


func _deck(army: UnitKind.Army, mode: String) -> Deck:
	if mode != "even":
		return CpuDeck.build(army)
	var deck := Deck.new(army)
	var roster := Deck.roster(army)
	for slot in EVEN_SLOTS:
		deck.add(roster[slot])
	return deck


func _deck_text(deck: Deck) -> String:
	var parts: Array[String] = []
	for entry in deck.entries:
		var text := UnitKind.display_name(entry.kind)
		for item in entry.equipment:
			text += " + " + Equipment.display_name(item)
		parts.append(text)
	return "%s（コスト %d / %d）" % ["、".join(parts), deck.total_cost(), deck.budget()]


## `--名前=値` の引数（`--` のあとに書いたもの）。
func _arguments() -> Dictionary[String, String]:
	var result: Dictionary[String, String] = {}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--") and argument.contains("="):
			var parts := argument.trim_prefix("--").split("=", true, 1)
			result[parts[0]] = parts[1]
	return result
