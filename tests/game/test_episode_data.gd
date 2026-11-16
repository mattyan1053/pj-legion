extends "res://tests/base_test.gd"
## 話と物語のファイル（game/story/。docs/story.md の「話のファイル」「物語のファイル」）の書き間違いを、起動する前に弾く。
## 読み込み（episode.gd、campaign.gd）が「ファイル:行: 何がおかしいか」を貯めるので、ここでは、それが空であることと、
## わざと壊した文（_broken）を、正しい行で弾くことを見る。

const Story := preload("res://game/story.gd")
const Episode := preload("res://game/episode.gd")
const Campaign := preload("res://game/campaign.gd")
const StoryBattle := preload("res://game/story_battle.gd")
## 欄の説明つきのひな形（docs/story.md の「話を 1 つ足す」）。どの物語にも並ばないが、そのまま読めること。
const TEMPLATE := "res://game/story/template.txt"


func test_every_story_file_reads_without_problems() -> void:
	assert_eq(Story.load_problems(), PackedStringArray(), "物語と話のファイルの書き間違い")
	assert_true(Story.is_ready(Story.campaigns()[0]), "最初の物語は遊べる")


func test_every_episode_file_is_in_a_campaign() -> void:
	var listed := {}
	for episode: Episode in Story.all_episodes():
		listed[String(episode.id)] = true
	for file: String in DirAccess.get_files_at(Episode.DIR):
		if file.ends_with(".txt"):
			assert_true(listed.has(file.get_basename()), "どの物語の [episodes] にも並んでいない話のファイル: %s" % file)


func test_the_template_reads_without_problems() -> void:
	var episode: Episode = Episode.load_file(TEMPLATE)
	assert_eq(episode.problems, PackedStringArray(), "ひな形")
	assert_ne(episode.title, "")
	assert_false(episode.before.is_empty())


func test_a_full_squad_is_placed_on_every_episode_map() -> void:
	for episode: Episode in Story.all_episodes():
		if episode.has_squad():
			continue  # 部隊が決まっている話は、下の test_fixed_squads_are_placed が見る
		var campaign := Story.campaign_of(episode)
		var deck := Deck.new(campaign.army, Story.rules_of(Story.starting(campaign)))
		for i in Deck.MAX_UNITS:
			deck.add(campaign.starting_kinds[i % campaign.starting_kinds.size()])
		var setup := StoryBattle.new(episode, deck).make_setup(3)
		setup.ignore_budget = true  # 数だけを見る（予算は出撃準備と編成の画面が見る）
		var battle := setup.create_battle()
		var placed := [0, 0]
		for unit in battle.units:
			if unit.side != Unit.Side.NEUTRAL:
				placed[unit.side] += 1
		assert_eq(placed, [Deck.MAX_UNITS + 1, episode.enemy.size() + 1], "%s: 両軍の全員が盤に置かれる" % episode.id)


func test_fixed_squads_are_placed() -> void:
	var fixed := 0
	for episode: Episode in Story.all_episodes():
		if not episode.has_squad():
			continue
		fixed += 1
		var battle := Story.first_battle(episode).make_setup(3).create_battle()
		var placed := battle.units.filter(func(unit: Unit) -> bool: return unit.side == Unit.Side.PLAYER1).size()
		assert_eq(placed, episode.squad.size() + 1, "%s: 決まっている部隊の全員（将を含む）が盤に置かれる" % episode.id)
	assert_true(fixed > 0, "部隊が決まっている話（チュートリアル）が無い")


## 見本の話を読んだ中身が、書いたとおりになる（欄の読み方）。
func test_the_probe_reads_every_field() -> void:
	var episode: Episode = Episode.parse(PROBE.replace("look = stone_walls", "look = stone_walls\nhold_turns = 5\nwins = king_defeated, turns_held\nmusic = battle_tense"))
	assert_eq(episode.problems, PackedStringArray())
	assert_eq(episode.id, &"probe")
	assert_eq(episode.title, "見本")
	assert_eq(episode.map_title, "尾根の小道")
	assert_eq(episode.hold_turns, 5)
	assert_eq(episode.wins, [GameWonEvent.Reason.KING_DEFEATED, GameWonEvent.Reason.TURNS_HELD] as Array[GameWonEvent.Reason])
	assert_eq(episode.music, &"battle_tense")
	assert_eq(episode.unlock_kinds, [UnitKind.Id.COMMANDO] as Array[UnitKind.Id])
	assert_eq(episode.unlock_items, [Equipment.Id.SPEED_BOOTS] as Array[Equipment.Id])
	assert_eq(episode.budget_up, 2)
	assert_eq(episode.speakers, PackedStringArray(["隊長", "敵将"]))
	assert_eq(episode.enemy_army, UnitKind.Army.FANTASY)
	assert_eq(episode.enemy, [[UnitKind.Id.PALADIN, [Equipment.Id.IRON_SHIELD, Equipment.Id.IRON_SHIELD]], [UnitKind.Id.PRIEST, []]])
	assert_eq(episode.deploy[1], [Vector2i(8, 9), Vector2i(5, 9)] as Array[Vector2i])
	assert_true(episode.deploy[0].is_empty())
	assert_eq(episode.before, [[0, "いくぞ"], [1, "来い：ここだ"]], "全角の「：」でもよい。文の中の「：」はそのまま")
	assert_eq(episode.after, [[1, "退け"]])
	assert_eq(episode.cues, [[&"turn", 2, 0, "進め"], [&"king_half", 1, 1, "まだだ"]])
	assert_false(episode.has_squad())


## 敵が軍に属さない話（魔物の群れ）: 軍は none と書き、部隊に魔物を並べられる。必殺技は無い。
func test_an_enemy_without_an_army_reads() -> void:
	var text := PROBE.replace("army = fantasy", "army = none").replace("unit = paladin + iron_shield + iron_shield", "unit = skeleton_brute").replace("unit = priest", "unit = skeleton_archer")
	var episode: Episode = Episode.parse(text)
	assert_eq(episode.problems, PackedStringArray())
	assert_eq(episode.enemy_army, UnitKind.Army.NONE)
	assert_eq(episode.enemy, [[UnitKind.Id.SKELETON_BRUTE, []], [UnitKind.Id.SKELETON_ARCHER, []]])
	var deck := episode.enemy_deck()
	assert_eq(deck.army, UnitKind.Army.NONE)
	# 軍の駒を混ぜると、置いたときにその軍の必殺技が付いてしまうので弾く。
	var mixed: Episode = Episode.parse(text.replace("unit = skeleton_archer", "unit = paladin"))
	assert_true(Array(mixed.problems).any(func(problem: String) -> bool: return problem.begins_with("probe.txt:19:")), "軍の無い敵に軍の駒: %s" % mixed.problems)


## 人の側（決まった部隊、解放）に魔物は書けない（物語の軍の駒だけ。campaign.gd が確かめる）。
func test_monsters_are_not_for_the_player() -> void:
	var good := "[campaign]\ntitle = 見本の物語\narmy = military\nrules = probe\nbudget = 20\n\n[start]\nunit = shield_trooper\n\n[episodes]\nridge_path\n"
	var campaign: Campaign = Campaign.parse(good.replace("unit = shield_trooper", "unit = skeleton"))
	assert_false(campaign.problems.is_empty(), "最初から雇える駒に魔物")


## 駒の行の「,」のあとに、始めのレベルと経験値を書ける（進化の選び方を教える話）。書かない駒は [1, 0]。
## 戦いの定義の start_growth へ写り、対戦の駒がそのレベルと経験値で始まる。
func test_unit_rows_can_start_grown() -> void:
	var text := PROBE.replace("name = 隊長", "name = 隊長\nunit = sorcerer, level 2, exp 110\nunit = paladin + iron_shield\nunit = priest, exp 30")
	text = text.replace("unit = priest\ndeploy", "unit = priest, level 2\ndeploy")
	var episode: Episode = Episode.parse(text)
	assert_eq(episode.problems, PackedStringArray())
	assert_eq(episode.squad, [[UnitKind.Id.SORCERER, []], [UnitKind.Id.PALADIN, [Equipment.Id.IRON_SHIELD]], [UnitKind.Id.PRIEST, []]], "「,」のあとは駒と持ち物に混ざらない")
	assert_eq(episode.growth[0], [[2, 110], [1, 0], [1, 30]])
	assert_eq(episode.growth[1], [[1, 0], [2, 0]])
	assert_true(episode.has_growth(0) and episode.has_growth(1))
	var battle := StoryBattle.new(episode, null).make_setup(1).create_battle()
	var grown := {}
	for unit in battle.units:
		if unit.kind != UnitKind.Id.KING:
			grown[[unit.side, unit.kind]] = [unit.level, unit.experience]
	assert_eq(grown[[Unit.Side.PLAYER1, UnitKind.Id.SORCERER]], [2, 110])
	assert_eq(grown[[Unit.Side.PLAYER1, UnitKind.Id.PALADIN]], [1, 0])
	assert_eq(grown[[Unit.Side.PLAYER1, UnitKind.Id.PRIEST]], [1, 30])
	assert_eq(grown[[Unit.Side.PLAYER2, UnitKind.Id.PRIEST]], [2, 0])
	# 書かない話は、戦いの定義も空のまま（いつもどおり）。
	var plain: Episode = Episode.parse(PROBE)
	assert_false(plain.has_growth(0) or plain.has_growth(1))
	assert_eq(StoryBattle.scenario_of(plain).start_growth, [[], []] as Array[Array])


## わざと壊した話を、書き間違いの行で弾くこと。[壊し方の名前] = [見本の中の文, 置き換える文, 弾く行]。
func test_broken_episodes_are_caught_on_their_line() -> void:
	var cases := {
		"知らない節": ["[unlock]", "[unlocks]", 7],
		"知らないキー": ["budget = 2", "budjet = 2", 10],
		"キーの重なり": ["title = 見本", "title = 見本\ntitle = 二つ目", 4],
		"= の無い行": ["budget = 2", "budget 2", 10],
		"知らないマップ": ["map = ridge_path", "map = ridge_paths", 4],
		"知らない見た目": ["look = stone_walls", "look = swamp", 5],
		"知らない曲": ["look = stone_walls", "look = stone_walls\nmusic = no_such_track", 6],
		"知らない駒": ["unit = priest", "unit = preist", 19],
		"将を書く": ["unit = priest", "unit = king", 19],
		"知らない育ち": ["unit = priest", "unit = priest, lv 2", 19],
		"育ちが数でない": ["unit = priest", "unit = priest, level two", 19],
		"進化のレベル": ["unit = priest", "unit = priest, level %d" % Growth.MAX_LEVEL, 19],
		"上がる経験値": ["unit = priest", "unit = priest, exp %d" % Growth.EXPERIENCE_PER_LEVEL, 19],
		"育たない駒": ["unit = priest", "unit = elite_minion, level 2", 19],
		"知らない持ち物": ["paladin + iron_shield + iron_shield", "paladin + iron_shild", 18],
		"魔物に持ち物": ["unit = priest", "unit = skeleton + iron_shield", 19],
		"知らない軍": ["army = fantasy", "army = elves", 17],
		"解放の駒": ["unit = commando", "unit = comando", 8],
		"上がらないコスト": ["budget = 2", "budget = 0", 10],
		"整数でない": ["budget = 2", "budget = two", 10],
		"置けないマス": ["deploy = 8,9  5,9", "deploy = -1,3  5,9", 20],
		"マスの書き方": ["deploy = 8,9  5,9", "deploy = 8.9  5,9", 20],
		"敵の初期位置が足りない": ["deploy = 8,9  5,9", "deploy = 8,9", 20],
		"知らない話し手": ["隊長: いくぞ", "団長: いくぞ", 23],
		"話し手の無い行": ["隊長: いくぞ", "いくぞ", 23],
		"空の文": ["隊長: いくぞ", "隊長:", 23],
		"会話が長い": ["隊長: いくぞ", "隊長: いくぞ\n".repeat(Episode.TALK_MAX_LINES + 1).strip_edges(), 22],
		"知らないきっかけ": ["(turn 2)", "(turn_end 2)", 30],
		"きっかけの陣営": ["(king_half enemy)", "(king_half 1)", 31],
		"ターン 0": ["(turn 2)", "(turn 0)", 30],
		"きっかけの書き方": ["(turn 2) 隊長: 進め", "turn 2 隊長: 進め", 30],
		"長い台詞": ["(turn 2) 隊長: 進め", "(turn 2) 隊長: " + "あ".repeat(Episode.CUE_MAX_CHARS + 1), 30],
		"長い覚えること": ["look = stone_walls", "look = stone_walls\nlesson = " + "あ".repeat(Episode.LESSON_MAX_CHARS + 1), 6],
		"知らない勝ち方": ["look = stone_walls", "look = stone_walls\nwins = rout", 6],
		"守り切るのに勝ち方が無い": ["look = stone_walls", "look = stone_walls\nhold_turns = 5\nwins = routed", 7],
		"勝ち方なのにターン数が無い": ["look = stone_walls", "look = stone_walls\nwins = turns_held", 6],
		"ゲージがあふれる": ["name = 隊長", "name = 隊長\nstart_gauge = 1001", 14],
		"決まった部隊が多い": ["name = 隊長", "name = 隊長\n" + "unit = sniper\n".repeat(Deck.MAX_UNITS + 1).strip_edges(), 12],
		"節より前の行": ["[episode]", "title = 前\n[episode]", 2],
		"節の重なり": ["[after]", "[before]\n隊長: また\n[after]", 26],
	}
	for name: String in cases:
		var case: Array = cases[name]
		var text := PROBE.replace(case[0], case[1])
		assert_ne(text, PROBE, "見本に「%s」が無い: %s" % [case[0], name])
		var problems: PackedStringArray = Episode.parse(text).problems
		assert_false(problems.is_empty(), "弾けない: %s" % name)
		var on_line := Array(problems).any(func(problem: String) -> bool: return problem.begins_with("probe.txt:%d:" % case[2]))
		assert_true(on_line, "%s: %d 行目で弾かない: %s" % [name, case[2], problems])
	assert_eq(Episode.parse(PROBE).problems, PackedStringArray(), "見本そのものは正しい")


## わざと壊した物語を弾くこと。
func test_broken_campaigns_are_caught() -> void:
	var good := "[campaign]\ntitle = 見本の物語\narmy = military\nrules = probe\nbudget = 20\n\n[start]\nunit = shield_trooper\n\n[episodes]\nridge_path\n"
	assert_eq(Campaign.parse(good).problems, PackedStringArray(), "見本そのものは正しい")
	assert_eq(Campaign.parse(good).episodes.size(), 1)
	var cases := {
		"ほかの軍の駒から始める": ["unit = shield_trooper", "unit = paladin"],
		"知らない軍": ["army = military", "army = elves"],
		"上限が無い": ["budget = 20", "budget = 0"],
		"無い話": ["ridge_path\n", "no_such_episode\n"],
		"話の重なり": ["ridge_path\n", "ridge_path\nridge_path\n"],
		"解放済みの駒をまた解放": ["unit = shield_trooper", "unit = shield_trooper\nunit = commando"],
		"ほかの軍の部隊で決まっている話": ["ridge_path\n", "drill_first_steps\n"],
	}
	for name: String in cases:
		var text := good.replace(cases[name][0], cases[name][1])
		if name == "ほかの軍の部隊で決まっている話":
			text = text.replace("army = military", "army = fantasy").replace("unit = shield_trooper", "unit = paladin")
		assert_ne(text, good, name)
		assert_false(Campaign.parse(text).problems.is_empty(), "弾けない: %s" % name)


# ---- 見本 ----

## 正しい話の見本（行の番号を、上の壊し方の表が使う。行を足したら表も直す）。
const PROBE := """# 見本
[episode]
title = 見本
map = ridge_path
look = stone_walls

[unlock]
unit = commando
item = speed_boots
budget = 2

[ally]
name = 隊長

[enemy]
name = 敵将
army = fantasy
unit = paladin + iron_shield + iron_shield
unit = priest
deploy = 8,9  5,9

[before]
隊長: いくぞ
敵将：来い：ここだ

[after]
敵将: 退け

[cues]
(turn 2) 隊長: 進め
(king_half enemy) 敵将: まだだ
"""
