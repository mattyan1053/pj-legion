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
##   --rival=REV     別の版の CPU（git のリビジョンか、スクリプトのパス）と対戦させる。先手・後手は、マップと軍の組み合わせを一巡するごとに入れ替わる
##   --list=1        1 局ごとに 1 行（GAME ...）も出す。シード、マップ、軍、勝ったプレイヤー、終わり方、ターン、必殺技の回数、
##                   倒れた中ボス（ターン:倒した陣営:中ボスの番号）、最初に当てた・倒したプレイヤーとターン（first_hit、first_kill。無ければ -1:0）。局を何本かに分けて並べて回し、あとで合わせるときに使う
##   --stage=KEY     このマップだけを回す。KEY は対戦モードの盤の鍵（game/versus_fields.gd。plain、ridge_path など。
##                   画面に出していない手で作ったマップも測れる）か、生成のマップの番号（1〜3）。
##                   配置を見るときに 1 つのマップの標本を増やす。手で作ったマップを対戦モードに出せるかも、これで測る
##   --relic=NAME    プレイヤー1 が、対戦の始めから聖遺物を 1 つ持つ（wisdom = 英知、courage = 勇気。ゲージは足さない）。
##                   聖遺物そのものの強さを、狩りの手間と切り離して測る（docs/relic-buff.md の「強さ」）
##   --no-reward=1   中ボスを倒しても、聖遺物の効果とゲージを取り消す（CPU は、もらえるつもりのまま狩る）。
##                   倒した側の勝率のうち、聖遺物のぶんと、もともと優勢な側が倒しているぶんを切り分ける（docs/relic-buff.md の「狩られ方」）
##   --episode=ID   ストーリーの話（game/story/<物語>/ のファイルの名前。ridge_hold など。ファイルのパスでもよい）の対戦を、
##                   両方とも CPU で回す（人の側も CPU が持つ）。物語の [episodes] に並んでいる話だけ。
##                   盤・部隊・初期位置はその話のもの（マップと軍の組み合わせは回さない。--decks、--pairings、--stage は見ない）。
##                   人の側は、その話を初めて遊ぶときの既定の編成（story.gd の first_battle）。
##                   話の敵の強さを、人の側の勝率で測る（docs/story.md の「敵の強さ」）
##   --squads=random  --episode のとき、人の側の部隊を、局ごとに変える（その話で雇える駒から、種で決まる組み合わせで、
##                   数の上限まで予算の中で雇う。装備は既定の編成と同じ決まり）。中立の駒の湧き直しが起きない話は、
##                   盤の上に乱数が無く、どの種でも同じ 1 局になるので、部隊の違いで勝率を測る。
##                   --episode でなければ、両軍の部隊を局ごとに変える（対戦の決まりのロスターから、種で決まる組み合わせで、
##                   数の上限まで予算の中で雇い、余った予算で装備を種で決まる駒に持たせる）。手で作ったマップは種を変えても
##                   盤が同じなので、標本が別々の局になるよう、部隊の違いで勝率を測る（--decks は見ない）
##   --squads=one    両軍のうち片方だけ、部隊を局ごとに変える（もう片方は CPU の編成）。変える側は、マップと軍の組み合わせを
##                   一巡するごとに入れ替わる（24 の倍数。mixed なら 12 の倍数）。人が自分で組んだ部隊で CPU と戦うときの見え方を測る。
##                   --episode とは一緒に使えない
##   --budget=M,F    予算を MILITARY M、FANTASY F に置き換える（測るためだけ。CPU の編成もランダムの部隊も、この予算で組む）
##   --without=KIND  両軍のロスターから、その種類の駒を抜く（UnitKind.Id の名前を小文字で。sniper,sorcerer のように並べられる）。
##                   その種類の駒が釣り合いを動かしているかを、抜いて確かめる（docs/hand-map.md の「マップを作るときのめやす」）
##   --trials=NAME   試しの決まり（TrialRules の名前。battery = 砲台。`,` で並べられる）を入にして回す（docs/match-setup.md の「試しの決まり」）
##   --map=PATH      手で作ったマップの形を、ファイルから読んで回す（試しの形を、game/maps/ に足さずに測る）。
##                   ファイルは、マップのファイルと同じ書式（[rows] の節。docs/hand-map.md）か、文字の格子の行だけを並べたテキスト。--stage より優先する
##   --hit=N --level=N   「当たりの経験値が N だったら」「1 レベルに要る経験値が N だったら」の見積もりに使う値（既定 15、80）
##
## マップ（3 種）と軍の組み合わせ（4 通り。mixed なら 2 通り）を順に回すので、12 の倍数にすると偏らない
## （--rival を付けたら、その倍の 24 の倍数。mixed なら 12 の倍数）。
## 同じ引数なら、いつも同じ結果になる（考える時間の欄を除く）。

const CpuMatch := preload("res://tools/cpu_match.gd")
const Story := preload("res://game/story.gd")
const StoryBattle := preload("res://game/story_battle.gd")
const Names := preload("res://game/names.gd")
const VersusFields := preload("res://game/versus_fields.gd")
const Maps := preload("res://game/maps.gd")
const RandomSquad := preload("res://game/random_squad.gd")  # --squads=random の、対戦の部隊（両軍）

const ARMIES: Array[UnitKind.Army] = [UnitKind.Army.MILITARY, UnitKind.Army.FANTASY]
const STAGE_NAMES := {
	BoardGenerator.Stage.PLAIN: "1 中央平原",
	BoardGenerator.Stage.LABYRINTH: "2 迷宮回廊",
	BoardGenerator.Stage.TWIN_SPRINGS: "3 双子結晶",
}
const ENDINGS := {"king": "将の撃破", "hq": "本陣の占拠", "held": "守り切り", "routed": "全滅", "boss": "中ボスの撃破", "point": "拠点の確保", "draw": "引き分け", "cutoff": "打ち切り"}
## --episode のときの、集計の「マップ」の欄の鍵（生成のマップと重ならない値）。名前は話の名前。
const EPISODE_STAGE := -1
var _episode_title := ""
## --stage に手で作ったマップを選んだときの、集計の「マップ」の欄の鍵。名前はマップの名前。
const MAP_STAGE := -2
var _map_title := ""
## 「両軍とも同じ役割」の編成（--decks=even）。Deck.roster の並び（前衛・後衛・奇襲・回復）の何番目を雇うか。
const EVEN_SLOTS: Array[int] = [0, 0, 1, 1, 2, 3]


## 集計の 1 行ぶん（全体、マップごと、軍の組み合わせごと）。
class Tally:
	extends RefCounted
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
	# 駒の種類 -> 倒された駒の倒され方（CpuMatch.Fall）の列。
	var falls: Dictionary[UnitKind.Id, Array] = {}
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
	var no_reward: bool = args.get("no-reward", "0") == "1"
	var rival: RefCounted = null
	if args.has("rival"):
		rival = CpuMatch.load_rival(args["rival"])
		if rival == null:
			printerr("--rival の CPU を読めない: %s" % args["rival"])
			quit(1)
			return
	# いまの CPU と別の版の対戦の [いまの CPU の勝ち, 別の版の勝ち, 決着しなかった局]。全体と、マップごと。
	var versus: Array[int] = [0, 0, 0]
	var versus_by_stage: Dictionary[int, Array] = {}
	# 駒の種類ごとの表を、[いまの CPU の駒, 別の版の駒] に分けたもの。局数も同じ並び（将の行に使う）。
	var versus_by_kind: Array[Dictionary] = [{}, {}]
	var episode: RefCounted = _find_episode(args["episode"]) if args.has("episode") else null
	if args.has("episode") and episode == null:
		printerr("--episode の話を読めない: %s" % args["episode"])
		quit(1)
		return
	# --stage: 生成のマップ（番号か鍵）なら fixed_stage、手で作ったマップの鍵なら map_field。
	var fixed_stage := 0
	var map_field: StringName = &""
	if args.has("stage"):
		var key := StringName(args["stage"])
		if args["stage"].is_valid_int():
			fixed_stage = args["stage"].to_int()
		elif not VersusFields.all_ids().has(key):
			printerr("--stage の盤を知らない: %s（%s か 1〜3）" % [key, ", ".join(VersusFields.all_ids())])
			quit(1)
			return
		elif VersusFields.is_generated(key):
			fixed_stage = VersusFields.scenario_of(key).stage
		else:
			fixed_stage = MAP_STAGE
			map_field = key
			_map_title = VersusFields.title_of(key)
	var trial_map: HandMap = null
	if args.has("map"):
		trial_map = HandMap.new(_map_rows(args["map"]))
		if not trial_map.is_valid():
			printerr("--map の形が盤にならない: %s %s" % [args["map"], trial_map.problems()])
			quit(1)
			return
		fixed_stage = MAP_STAGE
		_map_title = args["map"].get_file()
	var rules := _rules_without(args.get("without", ""), args.get("budget", ""))
	if rules == null:
		printerr("--without の駒か --budget の予算を読めない: %s %s" % [args.get("without", ""), args.get("budget", "")])
		quit(1)
		return
	var random_squads: bool = args.get("squads", "") == "random"
	var one_squad: bool = args.get("squads", "") == "one"
	if one_squad and episode != null:
		printerr("--squads=one は対戦モードだけ（--episode では、人の側を変える --squads=random を使う）")
		quit(1)
		return
	# 部隊の中身ごとの勝ち負け（--squads のとき。決着した局の、部隊 1 つずつ）。鍵 -> [部隊の数, 勝った数]。
	var squad_rows: Dictionary[String, Array] = {}
	# --squads=one の、[部隊を変えた側の勝ち, CPU の編成の勝ち, 決着なし]。軍の並び（変えた側 対 CPU の編成）ごとにも。
	var one_versus: Dictionary[String, Array] = {}
	# 作戦（試しの決まり）の札ごとの [手札にあった決着した局, うち勝ち, 手札にあった局, 使った局]。
	var tactic_rows: Dictionary[Tactics.Id, Array] = {}
	var started := Time.get_ticks_msec()

	for game in games:
		var stage := CpuMatch.STAGES[game % CpuMatch.STAGES.size()]
		if args.has("stage") or trial_map != null:
			stage = fixed_stage as BoardGenerator.Stage
		@warning_ignore("integer_division")
		var pairing := (game / CpuMatch.STAGES.size()) % 4
		if mixed_only:
			pairing %= 2
		var armies: Array[UnitKind.Army] = [ARMIES[pairing % 2], ARMIES[(pairing % 2) ^ (0 if pairing >= 2 else 1)]]
		var setup := MatchSetup.new()
		if trial_map != null:
			setup.scenario = Scenario.on_map(trial_map, _map_title)
		else:
			setup.scenario = Scenario.versus(stage) if map_field == &"" else VersusFields.scenario_of(map_field)
		setup.battle_seed = first_seed + game
		setup.ignore_budget = deck_mode == "even"
		@warning_ignore("integer_division")
		var squad_side := (game / (CpuMatch.STAGES.size() * (2 if mixed_only else 4))) % 2 if one_squad else -1
		for side: Unit.Side in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
			if random_squads or side == squad_side:
				setup.decks[side] = RandomSquad.build(armies[side], rules, (first_seed + game) * 2 + side)
			else:
				setup.decks[side] = _deck(armies[side], deck_mode, rules)
		if episode != null:
			stage = EPISODE_STAGE as BoardGenerator.Stage
			if random_squads:
				setup = StoryBattle.new(episode, _random_squad(episode, first_seed + game)).make_setup(first_seed + game)
			else:
				setup = Story.first_battle(episode).make_setup(first_seed + game)
			armies = [setup.army_of(Unit.Side.PLAYER1), setup.army_of(Unit.Side.PLAYER2)]
		for side: Unit.Side in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
			setup.controllers[side] = MatchSetup.Controller.CPU
		for trial in (args.get("trials", "") as String).split(",", false):
			setup.trials.append(StringName(trial))
		if random_squads and setup.trials.has(TrialRules.TACTICS):
			# 作戦の手札も、局ごとに変える（札ごとの勝ち負けを見る）。
			for side in 2:
				setup.tactics[side] = Tactics.random_hand((first_seed + game) * 2 + side)
		var battle := setup.create_battle()
		if args.has("relic"):
			var relic := Relics.Id.COURAGE if args["relic"] == "courage" else Relics.Id.WISDOM
			var gauge := battle.ult_gauge[Unit.Side.PLAYER1]
			Relics.grant(battle, Unit.Side.PLAYER1, relic, Relics.boss_of(relic))
			battle.ult_gauge[Unit.Side.PLAYER1] = gauge
		var outcome: CpuMatch.Outcome
		var rival_side := -1
		if rival == null:
			outcome = CpuMatch.play(battle, max_turns, cpu, null, no_reward)
		else:
			# 別の版が動かす側。マップと軍の組み合わせを一巡するごとに入れ替える。
			@warning_ignore("integer_division")
			rival_side = (game / (CpuMatch.STAGES.size() * (2 if mixed_only else 4))) % 2
			outcome = CpuMatch.play(battle, max_turns, cpu if rival_side == 1 else rival, rival if rival_side == 1 else cpu, no_reward)
			var slot := 2 if outcome.winner < 0 else (1 if outcome.winner == rival_side else 0)
			versus[slot] += 1
			versus_by_stage.get_or_add(stage, [0, 0, 0])[slot] += 1
			for side in 2:
				var table: Dictionary = versus_by_kind[1 if side == rival_side else 0]
				for kind: UnitKind.Id in outcome.by_side_kind[side]:
					var row: Array = table.get_or_add(kind, [0, 0, 0, 0, 0])
					for i in row.size():
						row[i] += outcome.by_side_kind[side][kind][i]

		for side: Unit.Side in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
			var names: Array[String] = []
			var used_names: Array[String] = []
			for id: Tactics.Id in Tactics.hand(battle, side):
				var used: bool = battle.tactics_used[side].has(id)
				var row: Array = tactic_rows.get_or_add(id, [0, 0, 0, 0])
				row[0] += 1 if outcome.winner >= 0 else 0
				row[1] += 1 if outcome.winner == side else 0
				row[2] += 1
				row[3] += 1 if used else 0
				names.append(Names.word(Tactics.Id, id))
				if used:
					used_names.append(Names.word(Tactics.Id, id))
			if not names.is_empty() and args.get("list", "0") == "1":
				print("TACTIC seed=%d side=%d hand=%s used=%s" % [first_seed + game, side, "+".join(names), "+".join(used_names)])
		if args.get("list", "0") == "1":
			var kills: Array[String] = []
			for kill: Array in outcome.mid_boss_kills:
				kills.append("%d:%d:%d" % [kill[0], kill[1], kill[2]])
			print("GAME seed=%d stage=%d p1=%s p2=%s winner=%d ending=%s turns=%d ults=%d,%d boss=%s rival=%d first_hit=%d:%d first_kill=%d:%d" % [
				first_seed + game, stage, Names.army(armies[0]), Names.army(armies[1]), outcome.winner, outcome.ending,
				outcome.turns, outcome.ult_uses[0], outcome.ult_uses[1], ",".join(kills), rival_side,
				outcome.first_hit_side, outcome.first_hit_turn, outcome.first_kill_side, outcome.first_kill_turn,
			])
			if random_squads or one_squad:
				for side: Unit.Side in ([Unit.Side.PLAYER1] if episode != null else [Unit.Side.PLAYER1, Unit.Side.PLAYER2]):
					print("SQUAD seed=%d side=%d cpu=%d %s" % [
						first_seed + game, side, 1 if one_squad and side != squad_side else 0, _deck_text(setup.deck_of(side)),
					])
			for kind: UnitKind.Id in outcome.by_kind:
				var row: Array = outcome.by_kind[kind]
				print("KIND seed=%d kind=%d hired=%d defeated=%d damage=%d kills=%d evolved=%d" % [
					first_seed + game, kind, row[0], row[1], row[2], row[3], row[4],
				])
			for fall in outcome.boss_falls:
				print("BOSS seed=%d stage=%d turn=%d index=%d side=%d units=%d rivals=%d near=%d dealt=%d rival_dealt=%d finish=%d hp=%d rival_hp=%d first_turn=%d first_hp=%d first_rival_hp=%d won=%d" % [
					first_seed + game, stage, fall.turn, fall.boss_index, fall.slayer_side, fall.slayer_units, fall.rival_units,
					fall.rivals_near, fall.slayer_damage, fall.rival_damage, fall.finish_damage, fall.slayer_hp, fall.rival_hp,
					fall.first_hit_turn, fall.first_slayer_hp, fall.first_rival_hp,
					-1 if outcome.winner < 0 or fall.slayer_side < 0 else (1 if outcome.winner == fall.slayer_side else 0),
				])
			for fall in outcome.falls:
				print("FALL seed=%d kind=%d turn=%d damage=%d hits=%d killer=%d killer_level=%d step=%d" % [
					first_seed + game, fall.kind, fall.turn, fall.damage, fall.hits_taken, fall.killer_kind, fall.killer_level,
					1 if fall.after_step else 0,
				])
		if (random_squads or one_squad) and episode == null and outcome.winner >= 0:
			for side: Unit.Side in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
				if one_squad and side != squad_side:
					continue
				var won := 1 if outcome.winner == side else 0
				for key in _squad_keys(setup.deck_of(side), armies[side], armies[1 - side]):
					var row: Array = squad_rows.get_or_add(key, [0, 0])
					row[0] += 1
					row[1] += won
		if one_squad:
			var pair := "%s（変えた側）対 %s（CPU の編成）" % [Names.army(armies[squad_side]), Names.army(armies[1 - squad_side])]
			var slot := 2 if outcome.winner < 0 else (0 if outcome.winner == squad_side else 1)
			one_versus.get_or_add("全体", [0, 0, 0])[slot] += 1
			one_versus.get_or_add(pair, [0, 0, 0])[slot] += 1
			one_versus.get_or_add(pair + "、変えた側が" + ("先手" if squad_side == 0 else "後手"), [0, 0, 0])[slot] += 1
		all.add(outcome)
		by_stage.get_or_add(stage, Tally.new()).add(outcome)
		var match_name := "%s 対 %s" % [Names.army(armies[0]), Names.army(armies[1])]
		by_match.get_or_add(match_name, Tally.new()).add(outcome)
		if armies[0] != armies[1]:
			mixed_games += 1
			if outcome.winner >= 0 and ARMIES.has(armies[outcome.winner]):  # 軍の無い敵（魔物の群れ）の勝ちは、軍ごとに数えない
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
		for fall in outcome.falls:
			falls.get_or_add(fall.kind, []).append(fall)
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
	if episode != null:
		var sample := Story.first_battle(episode).make_setup(first_seed)
		_episode_title = episode.title
		for side: Unit.Side in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
			print("  プレイヤー%d（%s）: %s" % [side + 1, "人の側" if side == Unit.Side.PLAYER1 else "敵", _deck_text(sample.deck_of(side))])
	elif random_squads:
		print("  編成: 両軍とも、局ごとに変える（--squads=random）")
	elif one_squad:
		print("  編成: 片方は局ごとに変える、もう片方は CPU の編成（--squads=one）")
		for army in ARMIES:
			print("  CPU の編成 %s: %s" % [Names.army(army), _deck_text(_deck(army, "auto", rules))])
	else:
		for army in ARMIES:
			print("  編成 %s: %s" % [Names.army(army), _deck_text(_deck(army, deck_mode, rules))])
	print("")
	print(all.line("全体"))
	for stage: int in by_stage:
		print(by_stage[stage].line("マップ " + _map_name(stage)))
	for match_name in by_match:
		print(by_match[match_name].line(match_name))
	print("")
	print("")
	print("中ボス（倒した側の勝ち負けは、決着した局だけ。倒した側は、その中ボスの聖遺物を受け取る）")
	print(all.boss_line("全体"))
	for stage: int in by_stage:
		print(by_stage[stage].boss_line("マップ " + _map_name(stage)))
	print("中ボスの取り合い（互角 = 倒れた時点の戦える駒の数の差が 1 以内。そば = 中ボスから %d マス以内に相手の戦える駒。横取り = 相手のほうが多く削っていた）" % CpuMatch.CONTEST_RADIUS)
	print(all.contest_line("全体"))
	for stage: int in by_stage:
		print(by_stage[stage].contest_line("マップ " + _map_name(stage)))
	print("倒した側の削った量の分け前（止めの一撃を含む。3 割未満 = %.1f より小さい。止めの一撃だけ = ほかに 1 も削っていない）" % CpuMatch.LOW_SHARE)
	print(all.share_line("全体"))
	for stage: int in by_stage:
		print(by_stage[stage].share_line("マップ " + _map_name(stage)))
	print("倒した側の戦力（将を除く駒の HP の合計）の分け前。互角 = 0.5 から %.2f 以内。狩り始め = プレイヤーが初めて削った時点" % CpuMatch.EVEN_SHARE)
	print(all.lead_line("全体"))
	for stage: int in by_stage:
		print(by_stage[stage].lead_line("マップ " + _map_name(stage)))
	print("")
	print("聖遺物（軍ごと。勝率は決着した局だけ。「相手だけ」は、自分は取らず、相手が取った局）")
	for army in ARMIES:
		var row: Array = relics.get(army, [0, 0, 0, 0, 0, 0, 0, 0])
		print("  %-9s 取った局 %3d / %3d（%3.0f%%）  英知 %3d  勇気 %3d  取った局の勝率 %3d 勝 / %3d（%3.0f%%）  相手だけが取った局の勝率 %3d 勝 / %3d（%3.0f%%）" % [
			Names.army(army), row[1], row[0], 100.0 * row[1] / maxi(1, row[0]), row[2], row[3],
			row[5], row[4], 100.0 * row[5] / maxi(1, row[4]), row[7], row[6], 100.0 * row[7] / maxi(1, row[6]),
		])
	print("")
	var decided := all.wins[0] + all.wins[1]
	print("先手（プレイヤー1）の勝率: %.1f%%（決着した %d 局のうち）" % [100.0 * all.wins[0] / maxi(1, decided), decided])
	print("最初に相手のプレイヤーの駒へ当てた側・倒した側（その側の勝ちは、決着した局だけ）")
	print(all.first_line("全体"))
	for stage in by_stage:
		print(by_stage[stage].first_line("マップ " + _map_name(stage)))
	var mixed_decided: int = army_wins[UnitKind.Army.MILITARY] + army_wins[UnitKind.Army.FANTASY]
	print("軍の違う対戦 %d 局: MILITARY %d 勝、FANTASY %d 勝（MILITARY の勝率 %.1f%%）" % [
		mixed_games, army_wins[UnitKind.Army.MILITARY], army_wins[UnitKind.Army.FANTASY],
		100.0 * army_wins[UnitKind.Army.MILITARY] / maxi(1, mixed_decided),
	])
	if one_squad:
		print("")
		print("部隊を変えた側 対 CPU の編成（変えた側の勝率は、決着した局だけ）")
		for key in one_versus:
			var row: Array = one_versus[key]
			print("  %s: 変えた側 %d 勝、CPU の編成 %d 勝、決着なし %d（変えた側の勝率 %.1f%%）" % [
				key, row[0], row[1], row[2], 100.0 * row[0] / maxi(1, row[0] + row[1]),
			])
	if not squad_rows.is_empty():
		print("")
		print("部隊の中身ごとの勝率（--squads。決着した局の、局ごとに変えた部隊 1 つずつ。軍の違う対戦と同じ軍の対戦を合わせる）")
		var keys := squad_rows.keys()
		keys.sort()
		for key: String in keys:
			var row: Array = squad_rows[key]
			print("  %-40s %4d 勝 / %4d（%5.1f%%）" % [key, row[1], row[0], 100.0 * row[1] / maxi(1, row[0])])
	if rival != null:
		print("")
		print("いまの CPU 対 別の版（%s）: いまの CPU %d 勝、別の版 %d 勝、決着なし %d（いまの CPU の勝率 %.1f%%）" % [
			args["rival"], versus[0], versus[1], versus[2], 100.0 * versus[0] / maxi(1, versus[0] + versus[1]),
		])
		for stage: int in versus_by_stage:
			var row: Array = versus_by_stage[stage]
			print("  マップ %s: いまの CPU %d 勝、別の版 %d 勝、決着なし %d" % [_map_name(stage), row[0], row[1], row[2]])
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
	print("倒され方（倒された駒のうち。攻撃する駒だけ）")
	_print_falls(falls)
	print("")
	print("スキルを使った回数（その駒を雇った 1 体あたり）")
	for skill in Skills.ALL:
		var row: Array = by_kind.get(skill.kind(), [0])
		print("  %-12s %5d 回（%4.2f）" % [Names.skill(skill), skill_uses.get(skill.id(), 0), float(skill_uses.get(skill.id(), 0)) / maxi(1, row[0])])
	print("")
	print("必殺技（軍ごと。1 局・1 軍あたり。勝率は決着した局だけ）")
	for army in ARMIES:
		var row: Array = ults.get(army, [0, 0, 0, 0, 0, 0, 0, 0])
		print("  %-9s %-6s 使った %4d 回（%4.2f。使った側は %3.0f%%）  最初に使ったターン 平均 %4.1f  使った側 %3d 勝 / %3d（%3.0f%%）  使わなかった側 %3d 勝 / %3d（%3.0f%%）" % [
			Names.army(army), Names.ult(Ults.of_army(army)), row[1], float(row[1]) / maxi(1, row[0]), 100.0 * row[7] / maxi(1, row[0]),
			float(row[6]) / maxi(1, row[7]), row[3], row[2], 100.0 * row[3] / maxi(1, row[2]),
			row[5], row[4], 100.0 * row[5] / maxi(1, row[4]),
		])
	if not tactic_rows.is_empty():
		print("")
		print("作戦（札ごと。手札にあった側の勝率は決着した局だけ）")
		for id in Tactics.ALL:
			var row: Array = tactic_rows.get(id, [0, 0, 0, 0])
			print("  %-6s 手札 %4d  使った %4d（%3.0f%%）  手札にあった側 %3d 勝 / %3d（%3.0f%%）" % [
				Names.tactic(id), row[2], row[3], 100.0 * row[3] / maxi(1, row[2]), row[1], row[0], 100.0 * row[1] / maxi(1, row[0]),
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
			Names.kind(kind), row[0], 100.0 * row[1] / count, float(row[2]) / count,
			float(row[3]) / count, 100.0 * row[4] / count,
		])


## 倒された駒の倒され方（種類 -> CpuMatch.Fall の列）を、種類ごとに出す。
## 「何もできずに落ちた」の目安は、与えたダメージが 0 のままと、1 発ぶん（基本の攻撃力）以下のまま。
## 「一撃で」は、ダメージを受けたのが止めの 1 回だけ。止めを刺した駒は、役割ごと（奇襲は、同じフェーズにシャドウステップで跳んでいた数も）。
func _print_falls(falls: Dictionary) -> void:
	var kind_ids := falls.keys()
	kind_ids.sort()
	for kind: UnitKind.Id in kind_ids:
		if UnitKind.role(kind) == UnitKind.Role.HEALER:
			continue
		var total: int = falls[kind].size()
		var silent := 0
		var one_hit := 0
		var one_shot := 0
		var one_shot_by_fresh_raider := 0
		var by_raider := 0
		var by_rearguard := 0
		var by_vanguard := 0
		var after_step := 0
		var turns := 0
		for fall: CpuMatch.Fall in falls[kind]:
			silent += 1 if fall.damage == 0 else 0
			one_hit += 1 if fall.damage <= UnitKind.power(kind) else 0
			one_shot += 1 if fall.hits_taken <= 1 else 0
			turns += fall.turn
			if fall.killer_kind < 0:
				continue
			match UnitKind.role(fall.killer_kind as UnitKind.Id):
				UnitKind.Role.RAIDER:
					by_raider += 1
					after_step += 1 if fall.after_step else 0
					one_shot_by_fresh_raider += 1 if fall.hits_taken <= 1 and fall.killer_level == 1 else 0
				UnitKind.Role.REARGUARD:
					by_rearguard += 1
				UnitKind.Role.VANGUARD:
					by_vanguard += 1
		print("  %-12s 倒された %4d 体（平均ターン %4.1f）  与えたダメージ 0 のまま %3.0f%%  1 発ぶん以下 %3.0f%%  一撃で %3.0f%%（レベル 1 の奇襲の一撃 %3.0f%%）  止め: 奇襲 %3.0f%%（跳んだあと %3.0f%%） 後衛 %3.0f%% 前衛 %3.0f%%" % [
			Names.kind(kind), total, float(turns) / total, 100.0 * silent / total, 100.0 * one_hit / total,
			100.0 * one_shot / total, 100.0 * one_shot_by_fresh_raider / total,
			100.0 * by_raider / total, 100.0 * after_step / total, 100.0 * by_rearguard / total, 100.0 * by_vanguard / total,
		])


## その駒に入った経験値の合計（当たりの経験値が hit のとき）。
func _experience(tally: Array, hit: int) -> int:
	return (
		tally[0] * hit + tally[1] * Growth.DEFEAT_EXPERIENCE
		+ tally[2] * Growth.NEUTRAL_DEFEAT_EXPERIENCE + tally[3] * Growth.HEAL_EXPERIENCE
		+ tally[4] * Growth.MID_BOSS_DEFEAT_EXPERIENCE
	)


func _deck(army: UnitKind.Army, mode: String, rules: DeckRules) -> Deck:
	if mode != "even":
		return CpuDeck.build(army, rules)
	var deck := Deck.new(army, rules)
	var roster := Deck.roster(army)
	for slot in EVEN_SLOTS:
		if rules.allows(army, roster[slot]):
			deck.add(roster[slot])
	return deck


## 部隊の中身を分ける鍵（--squads の「部隊の中身ごとの勝率」）。軍の並びを頭に付ける。
## 駒の種類（入っている部隊）、駒の種類の数、駒の数、装備の数、役割の組み合わせ（前衛・後衛・奇襲・回復の数）、CPU の編成と同じか。
static func _squad_keys(deck: Deck, army: UnitKind.Army, rival_army: UnitKind.Army) -> Array[String]:
	var head := "%s 対 %s " % [Names.army(army), Names.army(rival_army)]
	var keys: Array[String] = []
	var counts := {}
	var roles: Array[int] = [0, 0, 0, 0, 0]
	var items := 0
	for entry in deck.entries:
		counts[entry.kind] = counts.get(entry.kind, 0) + 1
		roles[UnitKind.role(entry.kind)] += 1
		items += entry.equipment.size()
	for kind: UnitKind.Id in counts:
		keys.append(head + "駒 %s あり" % Names.kind(kind))
		keys.append(head + "駒 %s %d 体" % [Names.kind(kind), counts[kind]])
	for kind in Deck.roster(army):
		if not counts.has(kind):
			keys.append(head + "駒 %s 0 体" % Names.kind(kind))
	keys.append(head + "数 %d 体" % deck.entries.size())
	keys.append(head + "装備 %d 個" % items)
	keys.append(head + "役割 前%d 後%d 奇%d 回%d" % roles.slice(1))
	if _deck_text(deck) == _deck_text(CpuDeck.build(army, deck.rules)):
		keys.append(head + "CPU の編成と同じ")
	return keys


## --without の駒を抜き、--budget の予算に置き換えた、対戦の決まり。どちらも空なら対戦の決まりそのもの。
## 知らない名前や読めない予算があれば null。
static func _rules_without(names: String, budget_text: String = "") -> DeckRules:
	if names.is_empty() and budget_text.is_empty():
		return DeckRules.versus()
	var removed: Array[UnitKind.Id] = []
	for name in (names.split(",") if not names.is_empty() else PackedStringArray()):
		var index := UnitKind.Id.keys().find(name.to_upper())
		if index == -1:
			return null
		removed.append(UnitKind.Id.values()[index])
	var versus := DeckRules.versus()
	var rosters := {}
	var budgets := {}
	for army in versus.armies():
		rosters[army] = versus.roster(army).filter(func(kind: UnitKind.Id) -> bool: return not removed.has(kind))
		budgets[army] = versus.budget(army)
	if not budget_text.is_empty():
		var parts := budget_text.split(",")
		if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
			return null
		budgets[UnitKind.Army.MILITARY] = parts[0].to_int()
		budgets[UnitKind.Army.FANTASY] = parts[1].to_int()
	return DeckRules.new(&"without", versus.max_units, rosters, budgets, versus.items())


## --map のファイルの、文字の格子の行（空の行は飛ばす）。マップのファイルの書式（[rows] の節がある）なら、その節の行。
func _map_rows(path: String) -> PackedStringArray:
	if FileAccess.get_file_as_string(path).contains("[rows]"):
		return (Maps.load_file(path)["map"] as HandMap).rows
	var rows := PackedStringArray()
	for line in FileAccess.get_file_as_string(path).split("\n"):
		if not line.strip_edges().is_empty():
			rows.append(line.strip_edges())
	return rows


## 話 id（ファイルのパスなら、その名前）の話。物語に並んでいなければ null。
func _find_episode(given: String) -> RefCounted:
	var id := StringName(given.get_file().get_basename())
	for each: RefCounted in Story.all_episodes():
		if each.id == id:
			return each
	return null


## --squads=random の、人の側の部隊。その話を初めて遊ぶときに雇える駒から、種で決まる順に、数の上限まで予算の中で雇う。
## 予算と持たせられる装備も、その話を初めて遊ぶときのもの（story.gd の unlocked_before）。
## 並びは役割の順（既定の編成と同じく、前衛が前に置かれる）。装備は既定の編成の決まり（Story.equip_defaults）。
func _random_squad(episode: RefCounted, squad_seed: int) -> Deck:
	var rng := RandomNumberGenerator.new()
	rng.seed = squad_seed
	var given := Story.unlocked_before(episode)
	var kinds := given.kinds
	var deck := Deck.new(given.campaign.army, Story.rules_of(given))
	var hired: Array[UnitKind.Id] = []
	var cost := 0
	while hired.size() < deck.rules.max_units:
		var affordable := kinds.filter(func(kind: UnitKind.Id) -> bool: return cost + UnitKind.cost(kind) <= deck.budget())
		if affordable.is_empty():
			break
		var kind: UnitKind.Id = affordable[rng.randi_range(0, affordable.size() - 1)]
		hired.append(kind)
		cost += UnitKind.cost(kind)
	hired.sort_custom(func(a: UnitKind.Id, b: UnitKind.Id) -> bool: return UnitKind.role(a) < UnitKind.role(b))
	for kind in hired:
		deck.add(kind)
	Story.equip_defaults(deck)
	return deck


func _map_name(stage: int) -> String:
	if stage == EPISODE_STAGE:
		return "話 " + _episode_title
	if stage == MAP_STAGE:
		return _map_title
	return STAGE_NAMES[stage]


static func _deck_text(deck: Deck) -> String:
	var parts: Array[String] = []
	for entry in deck.entries:
		var text := Names.kind(entry.kind)
		for item in entry.equipment:
			text += " + " + Names.item(item)
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
