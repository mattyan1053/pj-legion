extends "res://tests/base_test.gd"
## 主人公の名前（docs/story.md の「主人公の名前」。game/hero_name.gd、game/hero_name_window.gd、story.gd の hero_name・name_hero）。

const HeroName := preload("res://game/hero_name.gd")
const HeroNameWindow := preload("res://game/hero_name_window.gd")
const Story := preload("res://game/story.gd")
const Episode := preload("res://game/episode.gd")
const SaveStore := preload("res://game/save_store.gd")
const UiTheme := preload("res://game/ui_theme.gd")
const TalkScreen := preload("res://game/talk_screen.gd")
const BattleTalk := preload("res://game/battle_talk.gd")
const TalkLog := preload("res://game/talk_log.gd")
const BattleCues := preload("res://game/battle_cues.gd")
const OverlayStack := preload("res://game/overlay_stack.gd")


func test_names_are_cleaned_to_what_the_frames_can_show() -> void:
	assert_eq(HeroName.clean("  ハーデン  "), "ハーデン", "前後の空白は落とす")
	assert_eq(HeroName.clean("ハー\n{デ}ン\t"), "ハーデン", "改行・タブ・波括弧は落とす")
	assert_eq(HeroName.clean("あいうえおかきく"), "あいうえお", "全角 5 字ぶんで切る")
	assert_eq(HeroName.clean("Alexander the Great"), HeroName.clean("Alexander the Great").substr(0, HeroName.MAX_LETTERS), "字の数の上限")
	assert_true(HeroName.clean("Harden") == "Harden" and HeroName.is_valid("Harden"), "半角の名前")
	assert_eq(HeroName.clean("😀ノエ😀"), "ノエ", "画面の字に無い文字（絵文字）は落とす")
	assert_eq(HeroName.clean("   "), "", "空白だけは空")
	assert_false(HeroName.is_valid("") or HeroName.is_valid(" ノエ") or HeroName.is_valid("あいうえおか"))
	assert_true(HeroName.is_valid(HeroName.widest()))
	assert_eq(HeroName.fill("{hero}少尉、前へ。{hero}！", "ノエ"), "ノエ少尉、前へ。ノエ！")
	assert_eq(HeroName.longest_length("{hero}少尉"), HeroName.MAX_CHARS + 2)


## いちばん幅の広い名前でも、名前の出る枠（会話の札、途中の台詞の札、ログの札）に入る。clean を通った名前は、それより広くならない。
func test_the_widest_name_fits_every_name_plate() -> void:
	for name: String in [HeroName.widest(), HeroName.clean("WWWWWWWWWWWW"), HeroName.clean("ＷＷＷＷＷＷＷＷ"), HeroName.clean("漢字漢字漢字漢字")]:
		assert_true(name != "", "名前が空になった")
		var talk := UiTheme.FONT_BODY.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + 40.0
		assert_true(talk <= TalkScreen.PLATE_WIDTH, "会話の名前の札に入らない: %s（要る幅 %d）" % [name, talk])
		var cue := UiTheme.FONT_BOLD.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 20.0
		assert_true(cue <= BattleTalk.PLATE_WIDTH, "途中の台詞の名前の札に入らない: %s（要る幅 %d）" % [name, cue])
		var logged := UiTheme.FONT_BOLD.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, TalkLog.NAME_FONT).x + 20.0
		assert_true(logged <= TalkLog.PLATE_WIDTH, "ログの名前の札に入らない: %s（要る幅 %d）" % [name, logged])


## どの物語も、主人公の既定の名前を持ち、話の文の中では差し込みの印で書いてある（名前を変えたときに、前の名前が残らない）。
func test_story_files_write_the_hero_with_the_mark() -> void:
	for campaign in Story.campaigns():
		assert_true(HeroName.is_valid(campaign.hero), "%s: 主人公の既定の名前（story.txt の hero）" % campaign.id)
		assert_false(campaign.intro.contains(campaign.hero), "%s: intro は {hero} で書く" % campaign.id)
		assert_ne(campaign.hero_role(), "", "%s: 主人公は [cast] にいる" % campaign.id)
		for episode: Episode in campaign.episodes:
			assert_eq(episode.hero, campaign.hero)
			for line in episode.all_lines():
				assert_false(line.text.contains(campaign.hero), "%s: 文の中の主人公の名前は {hero} で書く: %s" % [episode.id, line.text])
				assert_eq(line.hero, campaign.hero)
				for option: Dictionary in line.options:
					assert_false((option["text"] as String).contains(campaign.hero), "%s: 答えの文も {hero} で: %s" % [episode.id, option["text"]])


## 付けた名前は、会話の話し手の札・文・途中の台詞・負けの台詞に入る。付けなければ、既定の名前。
func test_the_name_reaches_talk_lines_cues_and_lost_lines() -> void:
	var episode: Episode = Story.military().episodes[0]
	var with_default := Story.run_of(episode, Story.default_deck(Story.starting()))
	var named := Story.run_of(episode, Story.default_deck(Story.starting()), [], "ノエル")
	with_default.advance()
	named.advance()
	var before: Array = with_default.data()["lines"]
	var after: Array = named.data()["lines"]
	var swapped := 0
	for i in before.size():
		assert_false((after[i]["text"] as String).contains("{hero}") or (before[i]["text"] as String).contains("{hero}"), "印が残った")
		assert_eq(after[i]["text"], (before[i]["text"] as String).replace("ハーデン", "ノエル"))
		assert_eq(after[i]["name"], (before[i]["name"] as String).replace("ハーデン", "ノエル"))
		swapped += 1 if after[i] != before[i] else 0
	assert_true(swapped >= 3, "第 1 話の前の会話で、名前が替わる行が少ない（%d）" % swapped)
	named.advance()
	var battle: RefCounted = named.data()
	assert_eq(battle.hero, "ノエル")
	assert_eq(battle.copy().hero, "ノエル", "再戦でも同じ名前")
	var said: Array = battle.talk_cues().on_start(battle.make_setup(1).create_battle())
	assert_true(said.all(func(line: RefCounted) -> bool: return not line.name.contains("ハーデン") and not line.text.contains("{hero}")))
	var cue_names := episode.cues.map(func(cue: RefCounted) -> String: return BattleCues.line_of(cue.line, episode.speakers, episode.figures, "ノエル").name)
	assert_true(cue_names.has("ノエル") and not cue_names.has("ハーデン"), "途中の台詞の札: %s" % [cue_names])


## 名前は、既定の名前ごとに 1 つ覚える（本編と番外は同じ主人公）。書いて読み戻せる。使えない名前の記録は読み飛ばす。
func test_the_name_is_saved_and_shared_by_campaigns_of_the_same_hero() -> void:
	var dir := "user://test_hero_name_%d" % (Time.get_ticks_usec() + randi())
	var store := SaveStore.new(dir)
	var story := Story.new()
	story.store = store
	var military := Story.military()
	var patrol := Story.campaign_by_id(&"berk_patrol")
	var fantasy := Story.campaign_by_id(&"fantasy")
	assert_true(story.hero_name(military) == "ハーデン" and not story.is_hero_named(military), "付けるまでは既定の名前")
	assert_eq(story.name_hero(military, "  ノエル{}\n"), "ノエル")
	assert_true(story.is_hero_named(military) and story.is_hero_named(patrol) and not story.is_hero_named(fantasy))
	assert_eq([story.hero_name(military), story.hero_name(patrol), story.hero_name(fantasy)], ["ノエル", "ノエル", "イェルダ"])
	assert_eq(story.name_hero(fantasy, ""), "イェルダ", "空で決めると既定の名前（決めたことは覚える）")
	assert_true(story.is_hero_named(fantasy))
	var written: Dictionary = store.read(Story.STORE_NAME)
	assert_eq(written["version"], 4)
	assert_eq(written["data"]["heroes"], {"ハーデン": "ノエル", "イェルダ": "イェルダ"})
	var again := Story.new()
	again.store = store
	again.load_saved()
	assert_eq(again.hero_name(patrol), "ノエル")
	again.load_data({"heroes": {"ハーデン": "ながすぎるなまえです", "イェルダ": 3}}, 4)
	assert_true(again.hero_name(military) == "ハーデン" and not again.is_hero_named(fantasy), "使えない名前の記録は読み飛ばす")
	assert_eq(military.intro_for("ノエル").count("ノエル"), 1)
	store.remove(Story.STORE_NAME)
	DirAccess.remove_absolute(dir)


## 名前の窓: いまの名前を入れて開く。使えない文字は打った所で落ちる。「決定」で決めた名前、右クリック・Esc で開いたときの名前。板の大きさは変わらない。
func test_the_window_cleans_what_is_typed_and_reports_the_name() -> void:
	var window := HeroNameWindow.new()
	window.setup(OverlayStack.new())
	await settle(window)
	var got: Array[String] = []
	window.ask("ハーデン", "ハーデン", "偵察隊の新任少尉", func(named: String) -> void: got.append(named))
	await settle(window)
	var size: Vector2 = window.window_panel().size
	assert_eq(window.typed(), "ハーデン")
	window.type("あいうえおかきくけこ{}")
	assert_eq(window.typed(), "あいうえお")
	await settle(window)
	assert_eq(window.window_panel().size, size, "名前の長さで、板の大きさが変わる")
	assert_eq(size, HeroNameWindow.SIZE, "板は決まった大きさ（中身がはみ出して伸びていない）")
	window.accept()
	assert_eq(got, ["あいうえお"] as Array[String])
	window.ask("ノエル", "ハーデン", "", func(named: String) -> void: got.append(named))
	window.type("べつ")
	window.close_window()
	assert_eq(got.back(), "ノエル", "変えずに閉じたら、開いたときの名前")
	window.ask("ノエル", "ハーデン", "", func(named: String) -> void: got.append(named))
	window.type("  ")
	window.accept()
	assert_eq(got.back(), "ハーデン", "空で決めると、既定の名前")
	window.free()


## 物語を初めて選ぶと、名前の窓が出る。決めると、話の一覧へ進む。2 度目は出ない。
func test_choosing_a_campaign_for_the_first_time_asks_the_name() -> void:
	var context := preload("res://game/app_context.gd").new()
	var screen: Node = preload("res://game/campaign_list_screen.gd").new()
	screen.context = context
	await settle(screen)
	var outcomes: Array[StringName] = []
	screen.finished.connect(func(outcome: StringName) -> void: outcomes.append(outcome))
	var military := Story.military()
	screen.choose(military)
	assert_true(screen.hero_window().is_open() and outcomes.is_empty(), "名前を決めるまで、進まない")
	assert_eq(screen.hero_window().typed(), "ハーデン", "既定の名前が入っている")
	screen.hero_window().type("ノエル")
	screen.hero_window().accept()
	assert_eq(outcomes, [&"open"] as Array[StringName])
	assert_true(context.story.hero_name(military) == "ノエル" and context.story.campaign == military)
	screen.choose(military)
	assert_true(not screen.hero_window().is_open() and outcomes.size() == 2, "2 度目は訊かない")
	screen.free()
	# 話の一覧の「名前を変える」で、あとから変えられる。主な人物の欄の名前が替わる。
	var list: Node = preload("res://game/episode_list_screen.gd").new()
	list.context = context
	await settle(list)
	assert_eq(list.hero_label_text(), "ノエル")
	list.press_rename()
	assert_eq(list.hero_window().typed(), "ノエル")
	list.hero_window().type("リタ")
	list.hero_window().accept()
	assert_eq([list.hero_label_text(), context.story.hero_name()], ["リタ", "リタ"])
	list.free()
