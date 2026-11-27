extends "res://tests/base_test.gd"
## 話と物語のファイル（game/story/。docs/story.md の「話のファイル」「物語のファイル」）の書き間違いを、起動する前に弾く。
## 読み込み（episode.gd、campaign.gd）が「ファイル:行: 何がおかしいか」を貯めるので、ここでは、それが空であることと、
## わざと壊した文（_broken）を、正しい行で弾くことを見る。

const Story := preload("res://game/story.gd")
const Episode := preload("res://game/episode.gd")
const TalkLine := Episode.TalkLine
const Campaign := preload("res://game/campaign.gd")
const StoryBattle := preload("res://game/story_battle.gd")
const BattleSource := preload("res://game/battle_source.gd")
const BattleCues := preload("res://game/battle_cues.gd")
const Text := preload("res://game/text.gd")
const UnitIcons := preload("res://game/unit_icons.gd")
const CampaignListScreen := preload("res://game/campaign_list_screen.gd")
const EpisodeListScreen := preload("res://game/episode_list_screen.gd")
## 書き方の見本の物語（docs/story.md の「物語を 1 つ足す」。欄の説明つき）。物語の一覧には並ばないが、そのまま読めること。
const TEMPLATE := "res://game/story/_template/story.txt"
## 物語のファイルの見本を読むときに渡すパス（話は、物語と同じフォルダから読む）。
const PROBE_STORY := "res://game/story/military/story.txt"


func test_every_story_file_reads_without_problems() -> void:
	assert_eq(Story.load_problems(), PackedStringArray(), "物語と話のファイルの書き間違い")
	assert_true(Story.is_ready(Story.campaigns()[0]), "最初の物語は遊べる")


func test_every_episode_file_is_in_a_campaign() -> void:
	var listed := {}
	for episode: Episode in Story.all_episodes():
		listed[String(episode.id)] = true
	for campaign: Campaign in Story.campaigns():
		var folder := campaign.path.get_base_dir()
		for file: String in DirAccess.get_files_at(folder):
			if file.ends_with(".txt") and file != Campaign.STORY_FILE:
				assert_true(listed.has(file.get_basename()), "物語の [episodes] に並んでいない話のファイル: %s" % folder.path_join(file))


## 物語は、game/story/ のフォルダを置けば並ぶ（登録しない）。並びは物語のファイルの order の順。「_」で始まるフォルダは読まない。
func test_story_folders_are_found_in_order() -> void:
	var ids := Story.campaigns().map(func(each: Campaign) -> String: return String(each.id))
	assert_eq(ids, ["military", "fantasy", "berk_patrol"], "order の順")
	for folder: String in DirAccess.get_directories_at(Campaign.DIR):
		assert_true(folder.begins_with("_") or ids.has(folder), "読まれていない物語のフォルダ: %s" % folder)


## フォルダを 1 つ置くだけで、物語が増える。story.txt の無いフォルダは、何が足りないかを言う。
func test_a_dropped_folder_becomes_a_campaign() -> void:
	var dir := "user://test_story_%d" % randi()
	for folder: String in ["zeta", "alpha", "_draft", "empty"]:
		DirAccess.make_dir_recursive_absolute(dir.path_join(folder))
	var story := FileAccess.get_file_as_string(TEMPLATE)
	var episode := FileAccess.get_file_as_string(TEMPLATE.get_base_dir().path_join("first_battle.txt"))
	_write(dir.path_join("zeta/story.txt"), story.replace("rules = template", "rules = zeta").replace("order = 9", "order = 1"))
	_write(dir.path_join("zeta/first_battle.txt"), episode)
	var scenes := FileAccess.get_file_as_string(TEMPLATE.get_base_dir().path_join("scenes.txt"))
	_write(dir.path_join("zeta/scenes.txt"), scenes)
	_write(dir.path_join("alpha/more_scenes.txt"), scenes)
	_write(dir.path_join("alpha/story.txt"), story.replace("rules = template", "rules = alpha").replace("first_battle", "second_battle").replace("\nscenes", "\nmore_scenes"))
	_write(dir.path_join("alpha/second_battle.txt"), episode)
	_write(dir.path_join("_draft/story.txt"), "壊れた下書き")
	var found: Dictionary = Campaign.load_all(dir)
	var campaigns: Array = found["campaigns"]
	assert_eq(campaigns.map(func(each: Campaign) -> String: return String(each.id)), ["zeta", "alpha"], "order の小さい順。_ で始まるフォルダは読まない")
	for each: Campaign in campaigns:
		assert_eq(each.problems, PackedStringArray(), String(each.id))
		assert_eq(each.episodes.size(), 2)
	assert_eq(found["problems"].size(), 1, "story.txt の無いフォルダ: %s" % found["problems"])
	assert_true((found["problems"][0] as String).contains("empty"))
	for folder: String in ["zeta", "alpha", "_draft", "empty"]:
		for file: String in DirAccess.get_files_at(dir.path_join(folder)):
			DirAccess.remove_absolute(dir.path_join(folder).path_join(file))
		DirAccess.remove_absolute(dir.path_join(folder))
	DirAccess.remove_absolute(dir)


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func test_the_template_reads_without_problems() -> void:
	var campaign: Campaign = Campaign.load_file(TEMPLATE)
	assert_eq(campaign.problems, PackedStringArray(), "見本の物語")
	assert_eq(campaign.id, &"_template", "物語の id はフォルダの名前")
	assert_eq(campaign.episodes.size(), 2, "見本の話は 2 つ（[before]・[after] の書き方と、場面の節の書き方）")
	var episode: Episode = campaign.episodes[0]
	assert_ne(episode.title, "")
	assert_false(episode.before.is_empty())
	assert_false(episode.cues.is_empty())
	assert_eq(episode.speakers, PackedStringArray(["レオ", "敵将", "新兵"]))
	assert_true(episode.before_music != &"" and episode.after_music != &"", "見本を写した話も、会話の曲を選んである（test_sound.gd が、どの話にも求める）")
	# 見本の魔物の一覧に、話のファイルに書ける魔物が全部ある。
	var text := FileAccess.get_file_as_string(TEMPLATE.get_base_dir().path_join("first_battle.txt"))
	for kind: int in UnitKind.Id.values():
		if UnitKind.is_monster(kind as UnitKind.Id):
			assert_true(RegEx.create_from_string("#   魔物:.*\\b%s\\b" % String(UnitKind.Id.keys()[kind]).to_lower()).search(text) != null,
				"見本の魔物の一覧に %s が無い" % String(UnitKind.Id.keys()[kind]).to_lower())


## 場面の節の書き方（[talk 名前]・[sortie]・[battle]）: 書いた順が場面の順。会話の場面ごとに、背景の場所と曲。
func test_the_scenes_template_reads_as_a_list_of_scenes() -> void:
	var Kind := Episode.StoryScene.Kind
	var episode: Episode = Campaign.load_file(TEMPLATE).episodes[1]
	assert_true(episode.written_as_scenes and episode.has_battle())
	assert_eq(episode.scenes.map(func(scene: RefCounted) -> int: return scene.kind), [Kind.TALK, Kind.TALK, Kind.SORTIE, Kind.TALK, Kind.BATTLE, Kind.TALK])
	var talks := episode.talk_scenes()
	assert_eq(talks.map(func(scene: RefCounted) -> String: return scene.name), ["練兵場", "尾根の下", "盤の前", "勝ったあと"])
	assert_eq(talks.map(func(scene: RefCounted) -> bool: return scene.once), [true, true, true, false], "対戦より前の会話は 1 度だけ")
	assert_eq(talks.map(func(scene: RefCounted) -> StringName: return scene.music), [&"talk", &"talk_calm", &"talk", &"talk_bright"])
	assert_true(talks[0].place != null and talks[0].look == &"drill_yard", "place の場所の景色")
	assert_eq(talks[1].look, &"crystal_night", "look で景色を替える")
	assert_true(talks[2].place == null and talks[2].look == &"", "place が無ければ、話の盤")
	assert_true(talks[0].lines[0].is_narration())
	assert_eq(episode.all_lines().size(), 3 + 6 + 2 + 1 + 3 + 1, "会話の行、途中の台詞、負けの台詞")
	# 選択肢: 問いの行が、名前と答えを持つ。答えごとの行と (if …) の行は、出す条件を持つ。
	var asking: Episode.TalkLine = talks[1].lines[1]
	assert_true(asking.asks() and asking.choice == &"template_route")
	assert_eq(asking.options, [{"key": &"left", "text": "左の岩場から行く"}, {"key": &"right", "text": "右の坂を急ぐ"}] as Array[Dictionary])
	assert_eq(talks[1].lines.map(func(line: Episode.TalkLine) -> StringName: return line.when_answer), [&"", &"", &"left", &"right", &"right", &""])
	assert_eq(episode.choices, {&"template_route": [&"left", &"right"]})
	var answers := {&"template_route": "right"}
	var read := talks[1].lines.filter(func(line: Episode.TalkLine) -> bool: return line.holds(func(choice: StringName) -> String: return answers.get(choice, "")))
	assert_eq(read.size(), 5, "右を選ぶと、右の 2 行だけ")
	var later: Episode.TalkLine = talks[3].lines[1]
	assert_true(later.when_choice == &"template_route" and not later.holds(func(_choice: StringName) -> String: return ""), "選んでいなければ、(if 名前 = 鍵) の行は出ない")
	assert_eq(episode.conditions.size(), 1)


## 選択肢の書き間違いを、行で弾く。物語の読み込みは、名前の重なりと、選ばせていない選択肢の条件を弾く。
func test_choices_are_checked() -> void:
	var text := FileAccess.get_file_as_string(TEMPLATE.get_base_dir().path_join("scenes.txt"))
	var cases := {
		"答えが 1 つ": [text.replace("(answer right) 右の坂を急ぐ", ""), "答えは 2 から 3 つ"],
		"長い答え": [text.replace("右の坂を急ぐ", "右の坂を急ぐ".repeat(5)), "答えの文は 1 から 22 字"],
		"閉じていない": [text.replace("(end)", ""), "(end) で閉じていない"],
		"問いが無い": [text.replace("新兵: {hero}少尉、どちらから登りますか。\n", "").replace("> 翌朝、隊は尾根の下に着いた。\n", ""), "問いになる行が要る"],
		"答えの前の行": [text.replace("(answer left) 左の岩場から行く", "レオ: ふむ。\n(answer left) 左の岩場から行く"), "(answer 鍵) の行から書く"],
		"名前の字": [text.replace("(choice template_route)", "(choice 道)"), "名前は英小文字"],
		"同じ答え": [text.replace("(answer right)", "(answer left)"), "答え「left」が 2 度"],
		"知らない指示": [text.replace("(end)", "(done)"), "知らない指示"],
		"条件の形": [text.replace("(if template_route = left)", "(if template_route left)"), "条件の行は"],
		"途中の台詞に選択肢": [text.replace("(turn 1) レオ: 前へ出すぎるな。", "(choice x) レオ: あ"), "知らないきっかけ"],
		"長い会話": [text.replace("レオ: 右だ。日が高くなる前に登りきる。", "レオ: 右だ。\n".repeat(8)), "会話は 10 行まで"],
	}
	for name: String in cases:
		var problems: PackedStringArray = Episode.parse(cases[name][0]).problems
		assert_true(problems.size() >= 1 and "\n".join(problems).contains(cases[name][1]), "%s: %s" % [name, problems])
	# 物語の中での決まり。
	var dir := "user://test_choices_%d" % randi()
	DirAccess.make_dir_recursive_absolute(dir)
	_write(dir.path_join("story.txt"), FileAccess.get_file_as_string(TEMPLATE))
	_write(dir.path_join("first_battle.txt"), FileAccess.get_file_as_string(TEMPLATE.get_base_dir().path_join("first_battle.txt"))
		.replace("レオ: 見本の話だ。ここに会話を書く。", "(if template_route = left) レオ: 見本の話だ。").replace("敵将: ……見事だ。", "敵将: ……見事だ。\n(choice template_route)\n(answer a) あ\n(answer b) い\n(end)"))
	_write(dir.path_join("scenes.txt"), text.replace("template_route = left", "template_route = up"))
	var joined := "\n".join(Campaign.load_file(dir.path_join("story.txt")).problems)
	assert_true(joined.contains("first_battle.txt:") and joined.contains("この行までに選ばせていない"), "あとの話の選択肢を、条件に書けない: %s" % joined)
	assert_true(joined.contains("は、前の話にもある"), "名前の重なり: %s" % joined)
	assert_true(joined.contains("答え「up」は無い"), "無い答え: %s" % joined)
	for file: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(file))
	DirAccess.remove_absolute(dir)


## 場面の節の書き方の書き間違いを、行で弾く。
func test_scene_sections_are_checked() -> void:
	var text := FileAccess.get_file_as_string(TEMPLATE.get_base_dir().path_join("scenes.txt"))
	var cases := {
		"[before] と混ぜる": [text + "\n[before]\nレオ: あ\n", "[before] は書かない"],
		"before_music": [text.replace("map = ridge_path", "map = ridge_path\nbefore_music = talk"), "before_music は書かない"],
		"知らない場所": [text.replace("place = drill_field", "place = nowhere"), "マップ「nowhere」"],
		"知らない設定": [text.replace("place = drill_field", "plase = drill_field"), "知らない設定「plase」"],
		"設定があと": [text.replace("レオ: ああ。今夜は早く寝ておけ。", "レオ: ああ。\nmusic = talk_calm"), "会話の行より前"],
		"place の無い look": [text.replace("[talk 盤の前]", "[talk 盤の前]\nlook = ridge"), "look は place と組"],
		"あとの会話に対戦の曲": [text.replace("music = talk_bright", "music = battle"), "対戦の曲"],
		"対戦のあとの出撃準備": [text.replace("[sortie]", "").replace("[cues]", "[sortie]\n[cues]"), "[sortie] は [battle] より前"],
		"印の中身": [text.replace("[battle]", "[battle]\nレオ: あ"), "場面の順の印"],
		"名前の無い会話": [text.replace("[talk 盤の前]", "[talk]"), "知らない節 [talk]"],
		"空の会話": [text.replace("[sortie]", "[talk 空]\nmusic = talk\n[sortie]"), "[talk 空] の会話が無い"],
		"対戦が無いのに敵": [text.replace("[battle]", "").replace("[sortie]", ""), "対戦の無い話"],
	}
	for name: String in cases:
		var problems: PackedStringArray = Episode.parse(cases[name][0]).problems
		assert_true(problems.size() >= 1 and "\n".join(problems).contains(cases[name][1]), "%s: %s" % [name, problems])


## 対戦の無い話: [battle] を書かない。敵の軍も、敵の話し手も要らない。
func test_an_episode_without_a_battle_reads() -> void:
	var episode: Episode = Episode.parse("[episode]\ntitle = 読むだけの話\nmap = ridge_path\n[cast]\n少尉 = ally\n[talk 夜]\nmusic = talk\n少尉: 静かだ。\n[talk 朝]\nplace = drill_field\nmusic = talk_calm\n> 朝になった。\n")
	assert_eq(episode.problems, PackedStringArray())
	assert_false(episode.has_battle())
	assert_eq(episode.scenes.size(), 2, "出撃準備も対戦も無い")
	assert_false(episode.scenes[0].once)


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
	assert_eq(_dicts(episode.before), [Episode.TalkLine.speech(0, "いくぞ", 0).as_dict(), Episode.TalkLine.speech(1, "来い：ここだ", 1).as_dict()], "全角の「：」でもよい。文の中の「：」はそのまま")
	assert_eq(_dicts(episode.after), [Episode.TalkLine.speech(1, "退け", 1).as_dict()])
	assert_eq(_dicts(episode.cues), [Episode.TalkCue.new(&"turn", 2, TalkLine.speech(0, "進め", 0)).as_dict(), Episode.TalkCue.new(&"king_half", 1, TalkLine.speech(1, "まだだ", 1)).as_dict()])
	assert_false(episode.has_squad())


## 中ボスの名前: 話のファイルの boss、無ければマップのファイルの boss（docs/neutral-mid-boss.md の「名前」）。
func test_boss_name_reads_from_the_episode_or_the_map() -> void:
	var plain: Episode = Episode.parse(PROBE)
	assert_eq(plain.boss, "尾根の番人", "マップ（尾根の小道）の名前")
	var named: Episode = Episode.parse(PROBE.replace("look = stone_walls", "look = stone_walls\nboss = 谷の主"))
	assert_eq(named.problems, PackedStringArray())
	assert_eq(named.boss, "谷の主")
	assert_eq(StoryBattle.new(named, MatchSetup.default_deck(UnitKind.Army.MILITARY)).boss_name(), "谷の主")
	var long: Episode = Episode.parse(PROBE.replace("look = stone_walls", "look = stone_walls\nboss = とても長い番人の名前"))
	assert_eq(long.problems.size(), 1)


## 軍略（docs/troop-traits.md）: 話のファイルの trait と oath。書いた陣営だけが持ち、部隊編成で選んだ軍略は使わない。
func test_traits_read_and_reach_the_battle() -> void:
	var plain: Episode = Episode.parse(PROBE)
	var mine := MatchSetup.default_deck(UnitKind.Army.MILITARY).copy()
	mine.trait_id = Traits.Id.SUPPLY
	assert_eq(StoryBattle.new(plain, mine).make_setup(3).create_battle().traits, [Traits.NONE, Traits.NONE] as Array[int], "書かなければ、どちらも無い")
	var text := PROBE.replace("army = fantasy\n", "army = fantasy\ntrait = oath\noath = 1, 2\n")
	var episode: Episode = Episode.parse(text)
	assert_eq(episode.problems, PackedStringArray())
	assert_eq(episode.enemy_deck().oath_pairs(), [Vector2i(0, 1)] as Array[Vector2i])
	var battle := StoryBattle.new(episode, mine).make_setup(3).create_battle()
	assert_eq(battle.traits, [Traits.NONE, Traits.Id.OATH] as Array[int])
	assert_eq(battle.units.filter(func(unit: Unit) -> bool: return unit.oath_partner != 0).size(), 2, "誓いを駒に写す")
	for wrong: String in ["trait = focus", "trait = shout", "trait = oath\noath = 1, 3", "trait = guard\noath = 1, 2"]:
		var bad: Episode = Episode.parse(PROBE.replace("army = fantasy\n", "army = fantasy\n" + wrong + "\n"))
		assert_eq(bad.problems.size(), 1, "%s: %s" % [wrong, bad.problems])


func test_signs_read_and_reach_the_battle() -> void:
	var plain: Episode = Episode.parse(PROBE)
	assert_eq(plain.signs, [] as Array[int], "書かなければ付かない")
	var episode: Episode = Episode.parse(PROBE.replace("look = stone_walls", "look = stone_walls\nsigns = gale, taut"))
	assert_eq(episode.problems, PackedStringArray())
	assert_eq(episode.signs, [Seam.Sign.GALE, Seam.Sign.TAUT] as Array[int])
	var setup: MatchSetup = StoryBattle.new(episode, MatchSetup.default_deck(UnitKind.Army.MILITARY)).make_setup(3)
	assert_eq(setup.create_battle().signs, [Seam.Sign.GALE, Seam.Sign.TAUT] as Array[int], "話の様子は、その話にいつも付く")
	for wrong: String in ["signs = fog", "signs = loose, hush", "signs = gale, taut, brim"]:
		var bad: Episode = Episode.parse(PROBE.replace("look = stone_walls", "look = stone_walls\n" + wrong))
		assert_eq(bad.problems.size(), 1, "%s: %s" % [wrong, bad.problems])


## 地の文（話し手のいない行）は、頭に「>」（全角の「＞」でもよい）を付けて書く。話し手の番号は -1 で、会話の場面には名前の無い行で渡す。
func test_narration_lines_read() -> void:
	var episode: Episode = Episode.parse(PROBE.replace("隊長: いくぞ", "> 尾根に着いた。\n隊長: いくぞ").replace("敵将: 退け", "敵将: 退け\n＞ 日が暮れた。"))
	assert_eq(episode.problems, PackedStringArray())
	assert_eq(episode.before[0].as_dict(), TalkLine.narration("尾根に着いた。").as_dict())
	assert_true(episode.before[0].is_narration() and episode.before[0].side == Episode.NARRATION_SIDE and episode.before[0].who == -1)
	assert_eq(episode.after[1].as_dict(), TalkLine.narration("日が暮れた。").as_dict())
	var talk := Story.talk_of(episode, episode.before)
	assert_eq(talk["lines"][0]["name"], "", "地の文は名前の無い行")
	assert_eq(talk["lines"][0]["side"], Episode.NARRATION_SIDE)
	assert_eq(talk["lines"][1]["name"], "隊長")
	assert_eq(preload("res://game/talk_screen.gd").NARRATION_SIDE, Episode.NARRATION_SIDE, "会話の場面も、同じ陣営の番号で地の文と見る")
	assert_eq(preload("res://game/talk_log.gd").NARRATION_SIDE, Episode.NARRATION_SIDE, "会話のログも、同じ陣営の番号で地の文と見る")


## 負けたときの台詞（[lost]）は無くてよい。書けば、話し手と文を読み、話の対戦が決着の画面へ渡す（battle_source.gd の lost_lines）。
func test_lost_lines_read() -> void:
	var plain: Episode = Episode.parse(PROBE)
	assert_true(plain.lost.is_empty(), "書かなければ無し")
	assert_true(StoryBattle.new(plain, null).lost_lines().is_empty())
	var episode: Episode = Episode.parse(PROBE.replace("敵将: 退け", "敵将: 退け\n\n[lost]\n敵将: 甘い\n隊長：旗を空けすぎた"))
	assert_eq(episode.problems, PackedStringArray())
	assert_eq(_dicts(episode.lost), [Episode.TalkLine.speech(1, "甘い", 1).as_dict(), Episode.TalkLine.speech(0, "旗を空けすぎた", 0).as_dict()])
	var lines := StoryBattle.new(episode, null).lost_lines()
	assert_eq(lines.map(func(line: BattleCues.Line) -> Array: return [line.side, line.name, line.text]), [[1, "敵将", "甘い"], [0, "隊長", "旗を空けすぎた"]])
	assert_eq(lines[1].figure, episode.figures[0], "話し手の姿も渡す（決着の画面のアイコン）")
	assert_true(BattleSource.new().lost_lines().is_empty(), "対戦モードは無し")


## どの話にも、負けたときの台詞がある（負けたときに、次にどうするかの手掛かりを残す。docs/story.md の「会話の書き方」）。
func test_every_episode_has_lost_lines() -> void:
	for episode: Episode in Story.all_episodes():
		assert_between(episode.lost.size(), 1, Episode.LOST_MAX_LINES, "%s: [lost] が無い" % episode.id)


## 姿の最後の crown は、将の姿でない将に、会話で将の印を付ける（鍵は、付けたときだけ入る）。
func test_figure_crown_reads() -> void:
	var episode: Episode = Episode.parse(PROBE.replace("敵将 = enemy", "敵将 = enemy, paladin evolved crown"))
	assert_eq(episode.problems, PackedStringArray())
	assert_eq(episode.figures[1], {"kind": UnitKind.Id.PALADIN, "evolved": true, "look": &"", "crown": true})
	var plain: Episode = Episode.parse(PROBE.replace("敵将 = enemy", "敵将 = enemy, paladin crown"))
	assert_eq(plain.figures[1], {"kind": UnitKind.Id.PALADIN, "evolved": false, "look": &"", "crown": true})
	var swapped: Episode = Episode.parse(PROBE.replace("敵将 = enemy", "敵将 = enemy, paladin crown evolved"))
	assert_true(not swapped.problems.is_empty(), "順が逆の書き方を通した")


## 話し手の姿（figure）。書かなければ、どちらの陣営も将の姿。駒の種類と、進化後（evolved）を書ける。魔物も書ける。
func test_speaker_figures_read() -> void:
	var plain: Episode = Episode.parse(PROBE)
	assert_eq(plain.figures, [{"kind": UnitKind.Id.KING, "evolved": false, "look": &""}, {"kind": UnitKind.Id.KING, "evolved": false, "look": &""}] as Array[Dictionary], "既定は将")
	var text := PROBE.replace("隊長 = ally", "隊長 = ally, sniper evolved").replace("敵将 = enemy", "敵将 = enemy, skeleton_brute")
	var episode: Episode = Episode.parse(text)
	assert_eq(episode.problems, PackedStringArray())
	assert_eq(episode.figures[0], {"kind": UnitKind.Id.SNIPER, "evolved": true, "look": &""})
	assert_eq(episode.figures[1], {"kind": UnitKind.Id.SKELETON_BRUTE, "evolved": false, "look": &""})
	# 会話の場面と、対戦の途中の台詞へ渡る。
	var talk := Story.talk_of(episode, episode.before)
	assert_eq(talk["figures"], episode.figures)


## 話し手（[cast] の「名前 = 陣営, 姿」）。陣営ごとに最初の人が主な話し手で、ほかの人は、そのあとに書いた順に並ぶ。
## 会話と途中の台詞の行は、話し手の番号と陣営を持ち、会話の場面と途中の台詞へ、その人の名前と姿が渡る。
func test_more_speakers_read() -> void:
	var text := PROBE.replace("隊長 = ally", "隊長 = ally\n新兵 = ally, medic\n伝令 = ally").replace("敵将 = enemy", "敵将 = enemy\n副官 = enemy, sorcerer evolved").replace("[enemy]", "[ally]\nunit = sniper\n\n[enemy]")
	text = text.replace("隊長: いくぞ", "新兵: いきます\n副官: 来ます").replace("(turn 2) 隊長: 進め", "(turn 1) 伝令: 進め")
	var episode: Episode = Episode.parse(text)
	assert_eq(episode.problems, PackedStringArray())
	assert_eq(episode.speakers, PackedStringArray(["隊長", "敵将", "新兵", "伝令", "副官"]))
	assert_eq(episode.speaker_sides, PackedInt32Array([0, 1, 0, 0, 1]))
	assert_eq(episode.figures[2], {"kind": UnitKind.Id.MEDIC, "evolved": false, "look": &""})
	assert_eq(episode.figures[3], {"kind": UnitKind.Id.KING, "evolved": false, "look": &""}, "姿を書かなければ将")
	assert_eq(episode.figures[4], {"kind": UnitKind.Id.SORCERER, "evolved": true, "look": &""})
	assert_eq(_dicts(episode.before), [Episode.TalkLine.speech(0, "いきます", 2).as_dict(), Episode.TalkLine.speech(1, "来ます", 4).as_dict(), Episode.TalkLine.speech(1, "来い：ここだ", 1).as_dict()])
	assert_eq(episode.cues[0].as_dict(), Episode.TalkCue.new(&"turn", 1, TalkLine.speech(0, "進め", 3)).as_dict())
	var lines: Array = Story.talk_of(episode, episode.before)["lines"]
	assert_eq([lines[0]["side"], lines[0]["who"], lines[0]["name"]], [0, 2, "新兵"])
	assert_eq([lines[1]["side"], lines[1]["who"], lines[1]["name"]], [1, 4, "副官"])
	var source := StoryBattle.new(episode, null)
	var said: Array = source.talk_cues().on_start(source.make_setup(1).create_battle())
	assert_eq([said[0].side, said[0].name, said[0].figure], [0, "伝令", episode.figures[3]])


## 姿の最後に人物の名前（unit_looks.gd の PERSONS）を書くと、その人の形（"look"）。駒の種類は、その人の種類と同じにする。
func test_figure_person_reads() -> void:
	var episode: Episode = Episode.parse(PROBE.replace("敵将 = enemy", "敵将 = enemy, paladin evolved crown yelda\n副官 = enemy, priest evolved ul"))
	assert_eq(episode.problems, PackedStringArray())
	assert_eq(episode.figures[1], {"kind": UnitKind.Id.PALADIN, "evolved": true, "look": &"yelda", "crown": true})
	assert_eq(episode.figures[2], {"kind": UnitKind.Id.PRIEST, "evolved": true, "look": &"ul"})
	for wrong: String in ["sniper ul", "paladin nobody", "paladin yelda evolved"]:
		var bad: Episode = Episode.parse(PROBE.replace("敵将 = enemy", "敵将 = enemy, " + wrong))
		assert_true(not bad.problems.is_empty(), "通した: %s" % wrong)
	var skeleton: Episode = Episode.parse(PROBE.replace("army = fantasy", "army = fantasy\nking_figure = skeleton_mage").replace("敵将 = enemy", "敵将 = enemy, king harden"))
	assert_true(not skeleton.problems.is_empty(), "骸骨の将の陣営の将に、人物の形を通した")


## 人物の形は、盤でその人が乗る駒に付く: 将の印（crown）か将の姿なら将、ほかは同じ陣営の同じ種類の、いちばん前の駒。
func test_people_ride_their_pieces() -> void:
	var text := PROBE.replace("隊長 = ally", "隊長 = ally\n衛生兵 = ally, medic marta").replace("敵将 = enemy", "敵将 = enemy, paladin evolved crown yelda\n副官 = enemy, priest evolved ul")
	var episode: Episode = Episode.parse(text.replace("[enemy]", "[ally]\nunit = medic\nunit = medic\n\n[enemy]"))
	assert_eq(episode.problems, PackedStringArray())
	var source := StoryBattle.new(episode, null)
	var battle: Battle = source.make_setup(1).create_battle()
	var people: Dictionary = preload("res://game/unit_looks.gd").assign_people(battle.units, source.cast_looks())
	var by_look := {}
	for unit: Unit in battle.units:
		if people.has(unit.id):
			by_look[people[unit.id]] = unit
	assert_eq(by_look.size(), 3, "%s" % [people])
	assert_eq([by_look[&"yelda"].kind, by_look[&"yelda"].side], [UnitKind.Id.KING, Unit.Side.PLAYER2], "将の印の人は将に")
	assert_eq([by_look[&"ul"].kind, by_look[&"ul"].side], [UnitKind.Id.PRIEST, Unit.Side.PLAYER2])
	var medics := battle.units.filter(func(unit: Unit) -> bool: return unit.kind == UnitKind.Id.MEDIC and unit.side == Unit.Side.PLAYER1)
	assert_eq(medics.size(), 2)
	assert_eq(by_look[&"marta"], medics.reduce(func(a: Unit, b: Unit) -> Unit: return a if a.id < b.id else b), "同じ種類の駒が何体いても、付くのは 1 体だけ")
	assert_eq(BattleSource.new().cast_looks(), [[], []], "話の外（対戦モード）は人物なし")


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
	var other: Episode = Episode.parse(PROBE.replace("army = fantasy", "army = fantasy\nking_figure = skeleton_mage").replace("敵将 = enemy", "敵将 = enemy, priest"))
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
		"勝ち方が無い": ["wins = routed\n", "", 10],
		"将の撃破": ["wins = routed", "wins = routed, king_defeated", 1],
		"本陣の占拠": ["wins = routed", "wins = hq_captured", 1],
		"将の姿": ["king = none", "king = none\nking_figure = skeleton_mage", 15],
		"話し手が将の姿": ["墓守 = enemy, skeleton_brute", "墓守 = enemy", 11],
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

[cast]
隊長 = ally
墓守 = enemy, skeleton_brute

[enemy]
# 群れ
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
	var campaign: Campaign = Campaign.parse(good.replace("unit = shield_trooper", "unit = skeleton"), PROBE_STORY)
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
		for line: TalkLine in episode.all_lines():
			texts.append(line.text)
		for text in texts:
			for found in quoted.search_all(text):
				assert_true(shown.has(found.get_string(1)), "%s: 画面に無い呼び方「%s」: %s" % [episode.id, found.get_string(1), text])


## 駒の行の「,」のあとに、始めのレベルと経験値を書ける（進化の選び方を教える話）。書かない駒は [1, 0]。
## 戦いの定義の start_growth へ写り、対戦の駒がそのレベルと経験値で始まる。
func test_unit_rows_can_start_grown() -> void:
	var text := PROBE.replace("[enemy]", "[ally]\nunit = sorcerer, level 2, exp 110\nunit = paladin + iron_shield\nunit = priest, exp 30\n\n[enemy]")
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
		"話し手の重なり": ["敵将 = enemy", "敵将 = enemy\n敵将 = ally, sniper", 15],
		"話し手の姿": ["敵将 = enemy", "敵将 = enemy\n新兵 = ally, knight", 15],
		"話し手の書き方": ["敵将 = enemy", "敵将 = enemy\n新兵 = ally, sniper, evolved", 15],
		"名前の無い話し手": ["敵将 = enemy", "敵将 = enemy\n = ally, sniper", 15],
		"話し手の陣営": ["敵将 = enemy", "敵将 = enemy\n新兵 = friend", 15],
		"= の無い話し手": ["敵将 = enemy", "敵将 = enemy\n新兵", 15],
		"敵の話し手がいない": ["敵将 = enemy", "副長 = ally", 12],
		"話し手の節が無い": ["[cast]\n隊長 = ally\n敵将 = enemy\n", "", 1],
		"呼び名が長い": ["army = fantasy", "army = fantasy\nname = " + "あ".repeat(Episode.Names.STORY_NAME_MAX + 1), 18],
		"知らないきっかけ": ["(turn 2)", "(turn_end 2)", 30],
		"きっかけの陣営": ["(king_half enemy)", "(king_half 1)", 31],
		"ターン 0": ["(turn 2)", "(turn 0)", 30],
		"きっかけの書き方": ["(turn 2) 隊長: 進め", "turn 2 隊長: 進め", 30],
		"途中の台詞に地の文": ["(turn 2) 隊長: 進め", "(turn 2) > 日が暮れた", 30],
		"長い台詞": ["(turn 2) 隊長: 進め", "(turn 2) 隊長: " + "あ".repeat(Episode.CUE_MAX_CHARS + 1), 30],
		"長い覚えること": ["look = stone_walls", "look = stone_walls\nlesson = " + "あ".repeat(Episode.LESSON_MAX_CHARS + 1), 6],
		"知らない勝ち方": ["look = stone_walls", "look = stone_walls\nwins = rout", 6],
		"守り切るのに勝ち方が無い": ["look = stone_walls", "look = stone_walls\nhold_turns = 5\nwins = routed", 7],
		"勝ち方なのにターン数が無い": ["look = stone_walls", "look = stone_walls\nwins = turns_held", 6],
		"知らない姿": ["隊長 = ally", "隊長 = ally, knight", 13],
		"中立の駒の姿": ["隊長 = ally", "隊長 = ally, minion", 13],
		"進化しない駒の進化後": ["隊長 = ally", "隊長 = ally, king evolved", 13],
		"姿の書き方": ["隊長 = ally", "隊長 = ally, sniper grown", 13],
		"知らない将の姿": ["army = fantasy", "army = fantasy\nking_figure = dragon", 18],
		"人の将の姿": ["[enemy]", "[ally]\nking_figure = skeleton_mage\n\n[enemy]", 17],
		"ゲージがあふれる": ["[enemy]", "[ally]\nstart_gauge = 1001\n\n[enemy]", 17],
		"決まった部隊が多い": ["[enemy]", "[ally]\n" + "unit = sniper\n".repeat(Deck.MAX_UNITS + 1) + "\n[enemy]", 16],
		"敵の節が無い": ["[enemy]\narmy = fantasy\nunit = paladin + iron_shield + iron_shield\nunit = priest\ndeploy = 8,9  5,9\n", "", 1],
		"節より前の行": ["[episode]", "title = 前\n[episode]", 2],
		"節の重なり": ["[after]", "[before]\n隊長: また\n[after]", 26],
		"空の地の文": ["隊長: いくぞ", "＞", 23],
		"負けの台詞に地の文": ["敵将: 退け", "敵将: 退け\n[lost]\n> 日が暮れた", 29],
		"負けの台詞が多い": ["敵将: 退け", "敵将: 退け\n[lost]\n" + "隊長: また\n".repeat(Episode.LOST_MAX_LINES + 1).strip_edges(), 28],
		"負けの台詞が長い": ["敵将: 退け", "敵将: 退け\n[lost]\n隊長: " + "あ".repeat(Episode.LOST_MAX_CHARS + 1), 29],
		"負けの台詞が空": ["敵将: 退け", "敵将: 退け\n[lost]", 28],
		"負けの台詞の話し手": ["敵将: 退け", "敵将: 退け\n[lost]\n団長: また", 29],
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
	assert_eq(Campaign.parse(good, PROBE_STORY).problems, PackedStringArray(), "見本そのものは正しい")
	assert_eq(Campaign.parse(good, PROBE_STORY).episodes.size(), 1)
	var cases := {
		"ほかの軍の駒から始める": ["unit = shield_trooper", "unit = paladin"],
		"知らない軍": ["army = military", "army = elves"],
		"上限が無い": ["budget = 20", "budget = 0"],
		"無い話": ["ridge_path\n", "no_such_episode\n"],
		"話の重なり": ["ridge_path\n", "ridge_path\nridge_path\n"],
		"解放済みの駒をまた解放": ["unit = shield_trooper", "unit = shield_trooper\nunit = commando"],
		"ほかの軍の部隊で決まっている話": ["ridge_path\n", "drill_first_steps\n"],
		"長い紹介": ["budget = 20", "budget = 20\nintro = " + "あ".repeat(Campaign.INTRO_MAX_CHARS + 1)],
		"空の紹介": ["budget = 20", "budget = 20\nintro ="],
		"人物の書き方": ["[episodes]", "[cast]\n隊長 = king\n\n[episodes]"],
		"人物の姿": ["[episodes]", "[cast]\n隊長 = knight, 隊長\n\n[episodes]"],
		"長い立ち位置": ["[episodes]", "[cast]\n隊長 = king, " + "あ".repeat(Campaign.ROLE_MAX_CHARS + 1) + "\n\n[episodes]"],
		"人物の重なり": ["[episodes]", "[cast]\n隊長 = king, 隊長\n隊長 = sniper, 新兵\n\n[episodes]"],
		"人物が多い": ["[episodes]", "[cast]\n" + "".join(range(Campaign.CAST_MAX + 1).map(func(i: int) -> String: return "人%d = sniper, 兵\n" % i)) + "\n[episodes]"],
	}
	for name: String in cases:
		var text := good.replace(cases[name][0], cases[name][1])
		if name == "ほかの軍の部隊で決まっている話":
			text = text.replace("army = military", "army = fantasy").replace("unit = shield_trooper", "unit = paladin")
		assert_ne(text, good, name)
		assert_false(Campaign.parse(text, PROBE_STORY).problems.is_empty(), "弾けない: %s" % name)


## 物語の紹介の 1 行（intro）と主な人物（[cast]）は無くてよい。書けば、そのまま読む（姿の書き方は話の [cast] と同じ）。
func test_campaign_intro_and_cast_read() -> void:
	var good := "[campaign]\ntitle = 見本の物語\narmy = military\nrules = probe\nbudget = 20\n\n[start]\nunit = shield_trooper\n\n[episodes]\nridge_path\n"
	var plain: Campaign = Campaign.parse(good, PROBE_STORY)
	assert_eq(plain.intro, "")
	assert_true(plain.cast.is_empty())
	var full: Campaign = Campaign.parse(good.replace("budget = 20", "budget = 20\nintro = 尾根を越える。").replace("[episodes]", "[cast]\n隊長 = king, 新任の隊長\n曹長 = shield_trooper evolved, 曹長。教官\n\n[episodes]"), PROBE_STORY)
	assert_eq(full.problems, PackedStringArray())
	assert_eq(full.intro, "尾根を越える。")
	assert_eq(full.cast.map(func(person: Dictionary) -> Array: return [person["name"], person["role"], person["figure"]["kind"], person["figure"]["evolved"]]),
		[["隊長", "新任の隊長", UnitKind.Id.KING, false], ["曹長", "曹長。教官", UnitKind.Id.SHIELD_TROOPER, true]])


## 遊べる物語は、紹介の 1 行と主な人物を書く（人間の言葉「誰がどういう立ち位置なんだ」。docs/story.md の「物語のファイル」）。
## 主な人物は、その物語の話に、人の軍の話し手として同じ名前と姿で出てくる。
func test_campaigns_introduce_their_cast() -> void:
	for campaign: Campaign in Story.campaigns():
		if campaign.episodes.is_empty():
			continue
		assert_ne(campaign.intro, "", "%s: intro が無い" % campaign.id)
		assert_false(campaign.cast.is_empty(), "%s: [cast] が無い" % campaign.id)
		for person: Dictionary in campaign.cast:
			var found := false
			for episode: Episode in campaign.episodes:
				var at := episode.speakers.find(person["name"])
				if at >= 0 and episode.speaker_sides[at] == 0:
					found = true
					assert_eq(episode.figures[at]["kind"], person["figure"]["kind"], "%s の %s: 主な人物と話の姿が違う" % [episode.id, person["name"]])
			assert_true(found, "%s: 主な人物「%s」が、どの話にも人の軍の話し手で出てこない" % [campaign.id, person["name"]])


# ---- 見本 ----

## 正しい話の見本（行の番号を、上の壊し方の表が使う。行を足したら表も直す）。
## 会話の行・途中の台詞の列を、比べられる形に。
static func _dicts(rows: Array) -> Array:
	return rows.map(func(row: RefCounted) -> Dictionary: return row.as_dict())


const PROBE := """# 見本
[episode]
title = 見本
map = ridge_path
look = stone_walls

[unlock]
unit = commando
item = speed_boots
budget = 2

[cast]
隊長 = ally
敵将 = enemy

[enemy]
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


## 景色はマップが決める。話が look を書けば、その話だけ替える（docs/story.md）。
func test_the_map_decides_the_look_unless_the_episode_names_one() -> void:
	var Maps := load("res://game/maps.gd")
	var named: Episode = Episode.parse(KINGLESS_PROBE.replace("look = stone_walls", "look = crystal_forest"))
	assert_eq(named.look, &"crystal_forest")
	var unnamed: Episode = Episode.parse(KINGLESS_PROBE.replace("look = stone_walls\n", ""))
	assert_eq(Array(unnamed.problems), [])
	assert_eq(unnamed.look, Maps.find("old_battlefield")["look"])


## 敵の側は番人を狙わない（[enemy] の spare_boss = yes。docs/story.md の「話のファイル」）。書いた話だけ、対戦へ写る。
func test_spare_boss_reads_and_reaches_the_battle() -> void:
	var mine := MatchSetup.default_deck(UnitKind.Army.MILITARY)
	var plain: Episode = Episode.parse(KINGLESS_PROBE)
	assert_false(plain.enemy_spares_boss)
	assert_eq(StoryBattle.new(plain, mine).make_setup(3).create_battle().spares_bosses, [false, false] as Array[bool])
	var sparing: Episode = Episode.parse(KINGLESS_PROBE.replace("king = none\n", "king = none\nspare_boss = yes\n"))
	assert_eq(sparing.problems, PackedStringArray())
	assert_true(sparing.enemy_spares_boss)
	assert_eq(StoryBattle.new(sparing, mine).make_setup(3).create_battle().spares_bosses, [false, true] as Array[bool])
	var wrong: Episode = Episode.parse(KINGLESS_PROBE.replace("king = none\n", "king = none\nspare_boss = no\n"))
	assert_eq(wrong.problems.size(), 1, "%s" % [wrong.problems])
	var on_ally: Episode = Episode.parse(PROBE.replace("[enemy]\n", "[ally]\nspare_boss = yes\n\n[enemy]\n"))
	assert_eq(on_ally.problems.size(), 1, "人の側には書けない: %s" % [on_ally.problems])
