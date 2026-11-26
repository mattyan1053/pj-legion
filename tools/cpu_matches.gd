extends "res://tools/cpu_matches_base.gd"
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
##   --traits=X     軍略（docs/troop-traits.md）を置き換える（測るためだけ）。none = 両軍とも無し、random = 局ごとに種で決まる 1 つ（その軍の 3 つから）、
##                   鍵を並べる（focus,vengeance のように）= その軍の鍵の軍略。付けなければ、部隊が選んだ軍略（CPU の編成もランダムの部隊も CpuDeck.choose_trait）。
##                   --episode では army だけを使える（軍の陣営に、その軍の既定の軍略を持たせる。話に軍略を入れたら、を測る）。
##                   軍略ごとの勝率・選ばれた数・効いた回数と、--list=1 の TRAIT の行も出す
##   --rules=NAME   選べる決まり（OptionalRules の名前。stronghold = 拠点、seam = 縫い目の様子のランダム。`,` で並べられる）をそれだけ入にして回す。none で全部切。
##                   縫い目の様子のある局があれば、札ごと・札の組ごとの集計と、--list=1 の SIGNS の行（めくった札）も出す
##                   付けなければ、対戦モードの既定（OptionalRules.DEFAULTS = 拠点あり・縫い目の様子はランダム）。話（--episode）は、付けなければ切（docs/match-setup.md の「選べる決まり」）
##   --stronghold=X,Y  拠点を、マス (X, Y) に置いて回す（測るためだけ。拠点が入の対戦だけ）。lean:K なら、道のりの寄せ K（Board.stronghold_lean。
##                   先手の本陣からの道のり - 後手の本陣からの道のり の、ねらう値）で選ぶ
##   --signs=KEYS    縫い目の様子を、めくらずにこの札（Seam.KEYS の鍵。haze,brim のように 2 つまで）に決めて回す（測るためだけ。
##                   様子ごとの片寄りを見る）。none なら様子を付けない。盤で効かない札でも付ける
##   --map=PATH      手で作ったマップの形を、ファイルから読んで回す（試しの形を、game/maps/ に足さずに測る）。
##                   ファイルは、マップのファイルと同じ書式（[rows] の節。docs/hand-map.md）か、文字の格子の行だけを並べたテキスト。--stage より優先する
##   --hit=N --level=N   「当たりの経験値が N だったら」「1 レベルに要る経験値が N だったら」の見積もりに使う値（既定 15、80）
##
## マップ（3 種）と軍の組み合わせ（4 通り。mixed なら 2 通り）を順に回すので、12 の倍数にすると偏らない
## （--rival を付けたら、その倍の 24 の倍数。mixed なら 12 の倍数）。
## 同じ引数なら、いつも同じ結果になる（考える時間の欄を除く）。
##
## ここは集計の流れ（_initialize）だけ。集計の 1 行ぶん（Tally）は tools/cpu_tally.gd、引数・部隊・盤の道具と表の出し方は tools/cpu_matches_base.gd。

const Tally := preload("res://tools/cpu_tally.gd")


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
	## 縫い目の様子（--rules=seam）の、札ごと・札の組ごとの集計。鍵は札の名前、組は「名前+名前」（Seam.Sign の順）。
	var by_sign: Dictionary[String, Tally] = {}
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
	var trait_arg := args.get("traits", "") as String
	# 軍略ごと: 鍵（Traits.Id）-> [部隊の数, 決着した局, 勝った数, 効いた回数, 軍の違う対戦の決着した局, その勝った数]。
	var trait_rows: Dictionary[int, Array] = {}
	# --squads=one の、[部隊を変えた側の勝ち, CPU の編成の勝ち, 決着なし]。軍の並び（変えた側 対 CPU の編成）ごとにも。
	var one_versus: Dictionary[String, Array] = {}
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
			setup.scenario = Scenario.on_map(trial_map, _map_title, true)
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
		if episode != null and trait_arg == "army":
			# 話に軍の既定の軍略を入れたら、を測る（話のファイルは書いていない。軍でない魔物の群れは軍略を持たない）。
			for side: Unit.Side in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
				setup.scenario.traits[side] = Traits.default_of(setup.army_of(side))
		if episode == null and trait_arg != "":
			_override_traits(setup, trait_arg, first_seed + game)
		# 対戦モードは、対戦設定の既定の決まり（拠点あり）で回す。--rules=none で全部切、--rules=名前,… でそれだけ入。
		var rule_arg := args.get("rules", "default") as String
		if episode == null and rule_arg == "default":
			setup.rules.append_array(OptionalRules.DEFAULTS)
		elif rule_arg != "default" and rule_arg != "none":
			for rule in rule_arg.split(",", false):
				setup.rules.append(StringName(rule))
		var trial_stronghold := args.has("stronghold") and setup.rules.has(OptionalRules.STRONGHOLD)
		if trial_stronghold:
			setup.rules.erase(OptionalRules.STRONGHOLD)
		if args.has("signs"):
			_fix_signs(setup, args["signs"])
		var battle := setup.create_battle()
		var traits: Array[int] = battle.traits.duplicate()
		var signs: Array[int] = battle.signs.duplicate()  # この局の縫い目の様子（札ごとの集計と SIGNS の行）
		if trial_stronghold:
			if not _arm_trial_stronghold(battle, args["stronghold"], setup.battle_seed):
				# 置けない局を拠点なしのまま数えると、違う決まりの局が混ざるので、集計ごと止める。
				printerr("--stronghold の場所に拠点を置けない（種 %d）: %s" % [setup.battle_seed, args["stronghold"]])
				quit(1)
				return
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

		if args.get("list", "0") == "1":
			var kills: Array[String] = []
			for kill: Array in outcome.mid_boss_kills:
				kills.append("%d:%d:%d" % [kill[0], kill[1], kill[2]])
			print("GAME seed=%d stage=%d p1=%s p2=%s winner=%d ending=%s turns=%d ults=%d,%d boss=%s rival=%d first_hit=%d:%d first_kill=%d:%d" % [
				first_seed + game, stage, Names.army(armies[0]), Names.army(armies[1]), outcome.winner, outcome.ending,
				outcome.turns, outcome.ult_uses[0], outcome.ult_uses[1], ",".join(kills), rival_side,
				outcome.first_hit_side, outcome.first_hit_turn, outcome.first_kill_side, outcome.first_kill_turn,
			])
			if traits != [Traits.NONE, Traits.NONE]:
				print("TRAIT seed=%d p1=%s p2=%s hits=%d,%d" % [
					first_seed + game, Traits.key(traits[0]), Traits.key(traits[1]), outcome.trait_hits[0], outcome.trait_hits[1],
				])
			if not signs.is_empty():
				print("SIGNS seed=%d signs=%s" % [first_seed + game, ",".join(signs.map(func(sign: int) -> String: return Seam.key(sign)))])
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
		for side in 2:
			if traits[side] == Traits.NONE:
				continue
			var row: Array = trait_rows.get_or_add(traits[side], [0, 0, 0, 0, 0, 0])
			row[0] += 1
			row[3] += outcome.trait_hits[side]
			if outcome.winner >= 0:
				row[1] += 1
				row[2] += 1 if outcome.winner == side else 0
				if armies[0] != armies[1]:
					row[4] += 1
					row[5] += 1 if outcome.winner == side else 0
		if (random_squads or one_squad) and episode == null and outcome.winner >= 0:
			for side: Unit.Side in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
				if one_squad and side != squad_side:
					continue
				var won := 1 if outcome.winner == side else 0
				for key in _squad_keys(setup.deck_of(side), armies[side], armies[1 - side], traits[side]):
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
		if not signs.is_empty():
			var sorted_signs := signs.duplicate()
			sorted_signs.sort()
			var sign_keys: Array[String] = ["+".join(sorted_signs.map(func(sign: int) -> String: return Seam.key(sign)))]
			for sign in signs:
				sign_keys.append(Seam.key(sign))
			for sign_key in sign_keys:
				var sign_tally: Tally = by_sign.get_or_add(sign_key, Tally.new())
				sign_tally.add(outcome)
				if armies[0] != armies[1] and outcome.winner >= 0 and ARMIES.has(armies[outcome.winner]):
					sign_tally.army_wins[ARMIES.find(armies[outcome.winner])] += 1
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
	if not trait_rows.is_empty():
		print("軍略（部隊 1 つずつ。勝率は決着した局だけ。効いた回数は、その軍略の部隊 1 つ・1 局あたり。補給線は回復した回数）")
		for id: int in Traits.Id.values():
			if not trait_rows.has(id):
				continue
			var row: Array = trait_rows[id]
			var army := Traits.army_of(id)
			var of_army := 0
			for other: int in trait_rows:
				if Traits.army_of(other) == army:
					of_army += trait_rows[other][0]
			print("  %-9s %-6s 選ばれた %4d（軍の %3.0f%%）  勝率 %4d / %4d（%5.1f%%）  軍の違う対戦 %4d / %4d（%5.1f%%）  効いた回数 %5.2f" % [
				Names.army(army), Names.troop_trait(id), row[0], 100.0 * row[0] / maxi(1, of_army),
				row[2], row[1], 100.0 * row[2] / maxi(1, row[1]), row[5], row[4], 100.0 * row[5] / maxi(1, row[4]),
				float(row[3]) / maxi(1, row[0]),
			])
		print("")
	if not by_sign.is_empty():
		print("縫い目の様子（札ごと、札の組ごと。先手と MILITARY の勝率は決着した局だけ。MILITARY は軍の違う対戦だけ）")
		var sign_names := by_sign.keys()
		sign_names.sort_custom(func(a: String, b: String) -> bool: return (a.contains("+")) == (b.contains("+")) and a < b or (not a.contains("+") and b.contains("+")))
		for sign_key: String in sign_names:
			var tally: Tally = by_sign[sign_key]
			var sorted_turns := tally.turns.duplicate()
			var turn_total := 0
			for value: int in sorted_turns:
				turn_total += value
			print("  %-16s %3d 局  先手 %5.1f%%  MILITARY %5.1f%%  ターン 平均 %4.1f  打切 %2d" % [
				sign_key, tally.games, 100.0 * tally.wins[0] / maxi(1, tally.wins[0] + tally.wins[1]),
				100.0 * tally.army_wins[0] / maxi(1, tally.army_wins[0] + tally.army_wins[1]),
				float(turn_total) / maxi(1, tally.games), tally.endings["cutoff"],
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
	print("")
	print("行動 %d 回。考える時間: 1 手の平均 %.1f ms、最長 %.1f ms。全体で %.1f 秒" % [
		actions, think / maxi(1, actions), slowest, (Time.get_ticks_msec() - started) / 1000.0,
	])
	if rejected > 0:
		printerr("断られた行動が %d 回あった（CPU の不具合）" % rejected)
	quit(1 if rejected > 0 else 0)


## --traits の置き換え（測るためだけ）。none = 両軍とも無し、random = 種で決まる 1 つ、鍵の並び = その軍の鍵の軍略。
## 誓いになった部隊は、CPU の決め方で誓いを結ぶ。部隊は写して替える（ほかの局と共有しない）。
static func _override_traits(setup: MatchSetup, how: String, game_seed: int) -> void:
	if how == "none":
		setup.scenario.deck_traits = false
		return
	var rng := RandomNumberGenerator.new()
	# 近い種で同じ並びにならないよう、種を混ぜる（そのままだと、軍どうしの軍略の組み合わせが片寄る）。
	rng.seed = hash(game_seed * 7919 + 13)
	for side: Unit.Side in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
		var deck := setup.deck_of(side).copy()
		var choices := Traits.of_army(deck.army)
		if how == "random":
			deck.trait_id = choices[rng.randi_range(0, choices.size() - 1)]
		else:
			for word in how.split(",", false):
				var id := Traits.from_key(word)
				if choices.has(id):
					deck.trait_id = id
		if deck.trait_id == Traits.Id.OATH:
			CpuDeck.bind_oaths(deck)
		setup.decks[side] = deck
