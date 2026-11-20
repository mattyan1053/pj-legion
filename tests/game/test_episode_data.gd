extends "res://tests/base_test.gd"
## 話と物語のファイル（game/story/。docs/story.md の「話のファイル」「物語のファイル」）の書き間違いを、起動する前に弾く。
## 読み込み（episode.gd、campaign.gd）が「ファイル:行: 何がおかしいか」を貯めるので、ここでは、それが空であることと、
## わざと壊した文（_broken）を、正しい行で弾くことを見る。

const Story := preload("res://game/story.gd")
const Episode := preload("res://game/episode.gd")
const Campaign := preload("res://game/campaign.gd")
const StoryBattle := preload("res://game/story_battle.gd")
const Text := preload("res://game/text.gd")
const UnitIcons := preload("res://game/unit_icons.gd")
const CampaignListScreen := preload("res://game/campaign_list_screen.gd")
const EpisodeListScreen := preload("res://game/episode_list_screen.gd")
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
		var enemy_king := 1 if episode.enemy_king else 0  # 将のいない群れ（king = none）は将なし
		assert_eq(placed, [Deck.MAX_UNITS + 1, episode.enemy.size() + enemy_king], "%s: 両軍の全員が盤に置かれる" % episode.id)


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
	assert_eq(episode.before, [[0, "いくぞ", 0], [1, "来い：ここだ", 1]], "全角の「：」でもよい。文の中の「：」はそのまま")
	assert_eq(episode.after, [[1, "退け", 1]])
	assert_eq(episode.cues, [[&"turn", 2, 0, "進め", 0], [&"king_half", 1, 1, "まだだ", 1]])
	assert_false(episode.has_squad())


## 姿の最後の crown は、将の姿でない将に、会話で将の印を付ける（鍵は、付けたときだけ入る）。
func test_figure_crown_reads() -> void:
	var episode: Episode = Episode.parse(PROBE.replace("name = 敵将", "name = 敵将\nfigure = paladin evolved crown"))
	assert_eq(episode.problems, PackedStringArray())
	assert_eq(episode.figures[1], {"kind": UnitKind.Id.PALADIN, "evolved": true, "look": &"", "crown": true})
	var plain: Episode = Episode.parse(PROBE.replace("name = 敵将", "name = 敵将\nfigure = paladin crown"))
	assert_eq(plain.figures[1], {"kind": UnitKind.Id.PALADIN, "evolved": false, "look": &"", "crown": true})
	var swapped: Episode = Episode.parse(PROBE.replace("name = 敵将", "name = 敵将\nfigure = paladin crown evolved"))
	assert_true(not swapped.problems.is_empty(), "順が逆の書き方を通した")


## 話し手の姿（figure）。書かなければ、どちらの陣営も将の姿。駒の種類と、進化後（evolved）を書ける。魔物も書ける。
func test_speaker_figures_read() -> void:
	var plain: Episode = Episode.parse(PROBE)
	assert_eq(plain.figures, [{"kind": UnitKind.Id.KING, "evolved": false, "look": &""}, {"kind": UnitKind.Id.KING, "evolved": false, "look": &""}] as Array[Dictionary], "既定は将")
	var text := PROBE.replace("name = 隊長", "name = 隊長\nfigure = sniper evolved").replace("name = 敵将", "name = 敵将\nfigure = skeleton_brute")
	var episode: Episode = Episode.parse(text)
	assert_eq(episode.problems, PackedStringArray())
	assert_eq(episode.figures[0], {"kind": UnitKind.Id.SNIPER, "evolved": true, "look": &""})
	assert_eq(episode.figures[1], {"kind": UnitKind.Id.SKELETON_BRUTE, "evolved": false, "look": &""})
	# 会話の場面と、対戦の途中の台詞へ渡る。
	var talk := Story.talk_of(episode, episode.before)
	assert_eq(talk["figures"], episode.figures)


## ほかの話し手（speaker = 名前, 姿）。主な話し手（name）のあとに、書いた順に並ぶ（人の軍が先）。
## 会話と途中の台詞の行は、話し手の番号と陣営を持ち、会話の場面と途中の台詞へ、その人の名前と姿が渡る。
func test_more_speakers_read() -> void:
	var text := PROBE.replace("name = 隊長", "name = 隊長\nspeaker = 新兵, medic\nspeaker = 伝令\nunit = sniper").replace("name = 敵将", "name = 敵将\nspeaker = 副官, sorcerer evolved")
	text = text.replace("隊長: いくぞ", "新兵: いきます\n副官: 来ます").replace("(turn 2) 隊長: 進め", "(turn 1) 伝令: 進め")
	var episode: Episode = Episode.parse(text)
	assert_eq(episode.problems, PackedStringArray())
	assert_eq(episode.speakers, PackedStringArray(["隊長", "敵将", "新兵", "伝令", "副官"]))
	assert_eq(episode.speaker_sides, PackedInt32Array([0, 1, 0, 0, 1]))
	assert_eq(episode.figures[2], {"kind": UnitKind.Id.MEDIC, "evolved": false, "look": &""})
	assert_eq(episode.figures[3], {"kind": UnitKind.Id.KING, "evolved": false, "look": &""}, "姿を書かなければ将")
	assert_eq(episode.figures[4], {"kind": UnitKind.Id.SORCERER, "evolved": true, "look": &""})
	assert_eq(episode.before, [[0, "いきます", 2], [1, "来ます", 4], [1, "来い：ここだ", 1]])
	assert_eq(episode.cues[0], [&"turn", 1, 0, "進め", 3])
	var lines: Array = Story.talk_of(episode, episode.before)["lines"]
	assert_eq([lines[0]["side"], lines[0]["who"], lines[0]["name"]], [0, 2, "新兵"])
	assert_eq([lines[1]["side"], lines[1]["who"], lines[1]["name"]], [1, 4, "副官"])
	var source := StoryBattle.new(episode, null)
	var said: Array = source.talk_cues().on_start(source.make_setup(1).create_battle())
	assert_eq([said[0].side, said[0].name, said[0].figure], [0, "伝令", episode.figures[3]])


## 敵の将の姿（king_figure）は見た目だけ。話し手の姿が将なら、その姿で立つ。ルールの上では将のまま。
func test_enemy_king_figure_changes_only_the_look() -> void:
	var episode: Episode = Episode.parse(PROBE.replace("army = fantasy", "army = fantasy\nking_figure = skeleton_mage"))
	assert_eq(episode.problems, PackedStringArray())
	assert_eq(episode.king_looks, [&"", &"skeleton_mage"] as Array[StringName])
	assert_eq(episode.figures[1]["look"], &"skeleton_mage", "話し手の姿が将（既定）なら、骸骨の将で立つ")
	assert_eq(episode.figures[0]["look"], &"")
	var battle := StoryBattle.new(episode, MatchSetup.default_deck(UnitKind.Army.MILITARY))
	assert_eq(battle.king_looks(), episode.king_looks)
	var kings := battle.make_setup(1).create_battle().units.filter(func(unit: Unit) -> bool: return unit.kind == UnitKind.Id.KING)
	assert_eq(kings.size(), 2, "敵の将は、ルールの上では将のまま")
	var other: Episode = Episode.parse(PROBE.replace("army = fantasy", "army = fantasy\nking_figure = skeleton_mage").replace("name = 敵将", "name = 敵将\nfigure = priest"))
	assert_eq(other.figures[1]["look"], &"", "将でない話し手の姿には効かない")


## 物語を選ぶ場面と話の一覧のカードの顔（文字だけの札にしない）。
func test_story_cards_show_faces() -> void:
	var campaign := Story.military()
	var row := CampaignListScreen.faces_row(campaign)
	assert_eq(row.get_child_count(), campaign.starting_kinds.size() + 1, "将と、最初から雇える駒")
	assert_eq((row.get_child(0) as TextureRect).texture, UnitIcons.texture(UnitKind.Id.KING, 0))
	row.free()
	for episode: Episode in Story.all_episodes():
		var face := EpisodeListScreen.face_of(episode)
		var figure: Dictionary = episode.figures[1]
		assert_eq(face.texture, UnitIcons.texture(figure["kind"], 1, figure["evolved"], figure["look"]), "%s: 敵の話し手の姿" % episode.id)
		assert_true(face.texture != null)
		face.free()


## 魔物の話の敵の将は、骸骨の将の姿。
func test_monster_episodes_are_led_by_the_skeleton_king() -> void:
	for episode: Episode in Story.all_episodes():
		if episode.enemy_king and episode.enemy.any(func(row: Array) -> bool: return UnitKind.is_monster(row[0])):
			assert_eq(episode.king_looks[1], &"skeleton_mage", "%s: 魔物のいる話の敵の将" % episode.id)


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


## 将のいない群れ（[enemy] の king = none）: 戦いの定義の敵に将を置かない。人の勝ち方を書き、将の撃破・本陣の占拠は書けない。
func test_a_kingless_horde_reads() -> void:
	var text := (KINGLESS_PROBE)
	var episode: Episode = Episode.parse(text)
	assert_eq(episode.problems, PackedStringArray())
	assert_false(episode.enemy_king)
	var scenario := StoryBattle.scenario_of(episode)
	assert_false(scenario.has_king(Unit.Side.PLAYER2))
	assert_true(scenario.has_king(Unit.Side.PLAYER1))
	assert_true(Episode.parse(PROBE).enemy_king, "書かなければ将がいる")
	var cases := {
		"none でない": ["king = none", "king = yes", 14],
		"勝ち方が無い": ["wins = routed\n", "", 9],
		"将の撃破": ["wins = routed", "wins = routed, king_defeated", 1],
		"本陣の占拠": ["wins = routed", "wins = hq_captured", 1],
		"将の姿": ["king = none", "king = none\nking_figure = skeleton_mage", 15],
		"話し手が将の姿": ["figure = skeleton_brute\n", "", 10],
		"敵の将のきっかけ": ["(turn 2) 隊長: 進め", "(king_half enemy) 墓守: まだだ", 24],
	}
	for name: String in cases:
		var case: Array = cases[name]
		var broken := text.replace(case[0].c_unescape(), case[1].c_unescape())
		assert_ne(broken, text, "見本に「%s」が無い: %s" % [case[0], name])
		var problems: PackedStringArray = Episode.parse(broken).problems
		var on_line := Array(problems).any(func(problem: String) -> bool: return problem.begins_with("probe.txt:%d:" % case[2]))
		assert_true(on_line, "%s: %d 行目で弾かない: %s" % [name, case[2], problems])


const KINGLESS_PROBE := """[episode]
title = 群れ
map = old_battlefield
look = stone_walls
wins = routed

[ally]
name = 隊長

[enemy]
name = 墓守
figure = skeleton_brute
army = none
king = none
unit = skeleton_brute
unit = skeleton

[before]
隊長: いくぞ

[after]
隊長: 片付いた

[cues]
(turn 2) 隊長: 進め
"""


## 人の側（決まった部隊、解放）に魔物は書けない（物語の軍の駒だけ。campaign.gd が確かめる）。
func test_monsters_are_not_for_the_player() -> void:
	var good := "[campaign]\ntitle = 見本の物語\narmy = military\nrules = probe\nbudget = 20\n\n[start]\nunit = shield_trooper\n\n[episodes]\nridge_path\n"
	var campaign: Campaign = Campaign.parse(good.replace("unit = shield_trooper", "unit = skeleton"))
	assert_false(campaign.problems.is_empty(), "最初から雇える駒に魔物")


## 会話・台詞・覚えることで「」に括った言葉は、いまの画面に出る名前（駒・スキル・必殺技・持ち物・進化先の名前、
## 駒のそばのメニューの項目、必殺技のボタン）のどれか。言葉を直したあとに、演習の台詞が古い呼び方のまま残らないように。
## （メニューのスキルの項目は、スキルの名前で出る。「スキル」という項目は無い）
func test_quoted_words_in_story_lines_are_on_the_screen() -> void:
	var shown := {Text.t("battle.hud.ult"): true}
	for key: String in ["battle.menu.attack", "battle.menu.heal", "battle.menu.wait", "battle.menu.undo", "battle.menu.warp", "battle.menu.back"]:
		shown[Text.t(key)] = true
	var names := FileAccess.get_file_as_string("res://game/text/names.csv")
	for row: String in names.split("\n"):
		var cells := row.split(",", true, 1)
		if cells.size() == 2 and cells[0].get_slice_count(".") == 2 and cells[0].get_slice(".", 0) in ["unit", "skill", "ult", "item", "evolution"]:
			shown[cells[1].strip_edges()] = true
	var quoted := RegEx.create_from_string("「([^」]*)」")
	for episode: Episode in Story.all_episodes():
		var texts: Array[String] = [episode.lesson]
		for line: Array in episode.before + episode.after:
			texts.append(line[1])
		for cue: Array in episode.cues:
			texts.append(cue[3])
		for text in texts:
			for found in quoted.search_all(text):
				assert_true(shown.has(found.get_string(1)), "%s: 画面に無い呼び方「%s」: %s" % [episode.id, found.get_string(1), text])


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
		"会話の文が長い": ["隊長: いくぞ", "隊長: " + "あ".repeat(Episode.TALK_MAX_CHARS + 1), 23],
		"話し手の重なり": ["name = 隊長", "name = 隊長\nspeaker = 敵将, sniper", 14],
		"話し手の姿": ["name = 隊長", "name = 隊長\nspeaker = 新兵, knight", 14],
		"話し手の書き方": ["name = 隊長", "name = 隊長\nspeaker = 新兵, sniper, evolved", 14],
		"名前の無い話し手": ["name = 隊長", "name = 隊長\nspeaker = , sniper", 14],
		"知らないきっかけ": ["(turn 2)", "(turn_end 2)", 30],
		"きっかけの陣営": ["(king_half enemy)", "(king_half 1)", 31],
		"ターン 0": ["(turn 2)", "(turn 0)", 30],
		"きっかけの書き方": ["(turn 2) 隊長: 進め", "turn 2 隊長: 進め", 30],
		"長い台詞": ["(turn 2) 隊長: 進め", "(turn 2) 隊長: " + "あ".repeat(Episode.CUE_MAX_CHARS + 1), 30],
		"長い覚えること": ["look = stone_walls", "look = stone_walls\nlesson = " + "あ".repeat(Episode.LESSON_MAX_CHARS + 1), 6],
		"知らない勝ち方": ["look = stone_walls", "look = stone_walls\nwins = rout", 6],
		"守り切るのに勝ち方が無い": ["look = stone_walls", "look = stone_walls\nhold_turns = 5\nwins = routed", 7],
		"勝ち方なのにターン数が無い": ["look = stone_walls", "look = stone_walls\nwins = turns_held", 6],
		"知らない姿": ["name = 隊長", "name = 隊長\nfigure = knight", 14],
		"中立の駒の姿": ["name = 隊長", "name = 隊長\nfigure = minion", 14],
		"進化しない駒の進化後": ["name = 隊長", "name = 隊長\nfigure = king evolved", 14],
		"姿の書き方": ["name = 隊長", "name = 隊長\nfigure = sniper grown", 14],
		"知らない将の姿": ["army = fantasy", "army = fantasy\nking_figure = dragon", 18],
		"人の将の姿": ["name = 隊長", "name = 隊長\nking_figure = skeleton_mage", 14],
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


## 置けるマスは、x の範囲（「4-8,20」）でも書ける。2 か所に分けてもよい。
func test_deploy_cells_read_ranges() -> void:
	var file: RefCounted = preload("res://game/story_file.gd").parse("[x]\ndeploy = 4-6,20  2,12\n")
	var got: Array[Vector2i] = file.cells(file.values("x", ["deploy"], ["deploy"])["deploy"][0])
	assert_eq(got, [Vector2i(4, 20), Vector2i(5, 20), Vector2i(6, 20), Vector2i(2, 12)] as Array[Vector2i])
	assert_true(file.problems.is_empty(), "%s" % [file.problems])
	file.cells({"value": "6-4,1  a,1", "line": 3})
	assert_eq(file.problems.size(), 2, "逆の範囲と、数でない x は弾く")


## 話の一覧の下の欄（いま雇える駒・持ち物・コスト上限）は、持ち物が増えても、欄の幅で、語の切れ目で折り返す
## （Label の自動の折り返しは「コスト上限:」と数の間で切る）。どの物語も、全部の話をクリアしたところ（持ち物がいちばん多い）で見る。
func test_the_roster_note_folds_within_its_width() -> void:
	preload("res://game/ui_theme.gd").install()  # 遊ぶときの字（幅を測る）
	for campaign: RefCounted in Story.campaigns():
		var context := preload("res://game/app_context.gd").new()
		context.story.choose_campaign(campaign)
		for episode: Episode in campaign.episodes:
			context.story.clear(episode.id)
		var screen := EpisodeListScreen.new()
		screen.context = context
		var root := Node.new()
		root.add_child(screen)
		screen._ready()  # 木に入れずに組み立てる（root は SceneTree の外）
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 17)
		var font := label.get_theme_font("font")
		var shown: String = screen.roster_shown()
		for line: String in shown.split("\n"):
			var width := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
			assert_true(width <= EpisodeListScreen.ROSTER_WIDTH + 1.0, "%s: 欄の幅を超える行（%d px）: %s" % [campaign.title, width, line])
		assert_true(shown.contains("コスト上限: %d" % context.story.unlocked().budget), "%s: コスト上限と数が離れた: %s" % [campaign.title, shown])
		label.free()
		root.free()
