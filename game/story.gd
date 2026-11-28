extends "res://game/story_parts/story_unlocks.gd"
## ストーリー（docs/story.md）。物語と話の一覧・記録・解放は、継いだ 3 つ（game/story_parts/。継ぐ順は story_catalog.gd の頭）。
## ここは話の流れ: 話の場面の列から、流れ（run.gd）を組み、会話の場面に渡すもの（talk_scene.gd）を作る。ノードに依存しない。
## 外からは Story.xxx で呼ぶ（継いだものも、ここの名前で呼べる）。

## 会話の場面と、対戦の場面と、話の一覧の場面の名前（scene_flow.gd）。
const TALK := SceneFlow.TALK
const BATTLE := SceneFlow.BATTLE
const EPISODE_LIST := SceneFlow.EPISODES
const SORTIE := SceneFlow.SORTIE

## 会話の行の、知らせ（話し手の名前の札を金の縁にする。「飛ばす」でも飛ばさない。talk_screen.gd）。名前は notice_name()。
const NOTICE_SIDE := TalkScene.NOTICE_SIDE


## 知らせの行の話し手の名前。
static func notice_name() -> String:
	return Text.t("story.news.speaker")


## いま遊んでいる話の流れ（run_now が作ったもの。弱い参照）。話の途中で名乗ったとき、先の場面へ名前を入れ直す。
var _run: WeakRef


## 話 episode を、いまの進み具合で始める流れ（run_of。人の部隊は、出撃準備で選ぶまで、いま使えるもので組んだ既定の編成）。
## 話の物語を、いまの物語にする。初めてクリアする話なら、あとの会話の最後に、増えるものの知らせを出す。
func run_now(episode: Episode) -> Run:
	choose_campaign(campaign_of(episode))
	if open_all and not _reachable(episode.id) and not _opened_runs.has(String(episode.id)):
		_opened_runs.append(String(episode.id))
	var now := unlocked()
	var news: Array[TalkScene.Line] = []
	if not is_cleared(episode.id):
		# 知らせは記録どおりの進み具合から（確かめ用に開いていても、あとの会話の知らせを確かめられる）。
		news = _unlocked_in(campaign, true).news_of(episode)
	var run := run_of(episode, default_deck(now), news, hero_name())
	_run = weakref(run)
	return run


## 話 episode の流れ（run.gd）: 話の場面の列（episode.gd の scenes。[before]・[after] の話は 出撃準備 → 会話（前）→ 対戦 → 会話（後））を順に並べ、終えたら話の一覧。
## クリアの記録は、対戦のある話は対戦に勝ったとき（story_battle.gd の record_win）、対戦の無い話は最後の会話を読み終えたとき（会話に渡す clears）。
## 人の部隊は human_deck（出撃準備で選び直せる）。場面の種類ごとに、流れのどの場面にして何を渡すかは、ここだけで決める。
## 会話（前）は、出撃してから対戦の前に 1 度だけ出す（場面の once。決着の画面の「部隊変更」で出撃準備へ戻って出撃し直しても、もう出さない）。
## 対戦で負けたら、決着の画面から「同じマップで再戦」「部隊変更」（出撃準備へ）か「話の一覧へ」。勝ったら「次へ」で、あとの会話へ。
## あとの会話を読み終えたら「次の話へ」（物語の次の話の流れを始める）か「話の一覧へ」。次の話が無ければ、話の一覧へ。
## システムメニューからは、いつでも「話の一覧へ」（menu_exits）。
## news: この話のクリアで増えるものの知らせ（Unlocked.news_of）。最後の場面が会話なら、その最後に知らせの行で出し、「次の話へ」を選ばせる。
## 最後の場面がカットシーンなら、「次の話へ」はそこで選ばせ、知らせがあるときだけ、知らせだけの会話の場面をあとに足す。
## hero: 遊ぶ人の付けた主人公の名前（空なら既定の名前）。会話・途中の台詞・負けの台詞に差し込む。
static func run_of(episode: Episode, human_deck: Deck, news: Array[TalkScene.Line] = [], hero := "") -> Run:
	var run := Run.new()
	run.exit = EPISODE_LIST
	run.menu_exits = [[EPISODE_LIST, "story.episodes.resume", "menu.to_episodes.confirm"]]
	var battle := StoryBattle.new(episode, human_deck)
	battle.hero = hero
	var fought := false  # 対戦の場面を過ぎたか（会話の背景の盤に、決着したときの駒を立たせる）
	var last_talk: TalkScene = null
	var last_music := &""
	for scene in episode.scenes:
		last_talk = null
		match scene.kind:
			Episode.StoryScene.Kind.SORTIE:
				run.add(SORTIE, {"episode": episode, "battle": battle})  # 出撃準備で、battle の人の部隊を選び直す
			Episode.StoryScene.Kind.BATTLE:
				run.add(BATTLE, battle)
				fought = true
			Episode.StoryScene.Kind.TALK:
				var talk := talk_of(episode, scene.lines, scene.music, hero)
				talk.shape = scene.talk_shape()
				match talk.shape:
					TalkScene.Shape.MAP:
						if episode.has_battle():
							talk.battle = battle  # 背景の盤に、初期位置の駒か、決着したときの駒を立たせる（talk_screen.gd）
							talk.after = fought
					TalkScene.Shape.PLACE:
						# 別の場所の会話: 背景はその場所の景色（兵は立たせない）。
						talk.board = scene.place.make_board()
						talk.look = scene.look
					TalkScene.Shape.CUT:
						# カットシーン: 文の枠も話し手も出さず、背景（景色か、色の幕）の上に文を出す（talk_screen.gd）。
						talk.color = scene.color
						if scene.place != null:
							talk.board = scene.place.make_board()
							talk.look = scene.look
					TalkScene.Shape.BOARD_CUT:
						# 盤のカットシーン: 背景は台本の盤（place か話の盤）で、台本の兵だけが立って動く（talk_screen.gd）。
						talk.cut_board = scene.board_cut
						talk.beats = scene.beats
						talk.look = scene.look if scene.place != null else episode.look
						talk.looks = person_looks(episode)
				run.add(TALK, talk, scene.once)
				last_talk = talk
				last_music = scene.music
	if last_talk != null:
		if not last_talk.shows_speakers() and not news.is_empty():
			# カットシーンで終わる話: 知らせは、文の枠のある場面で出す（カットシーンには枠が無い）。知らせだけの会話の場面を、あとに 1 つ足す。
			# 背景は話の盤（対戦のある話なら、決着したときの兵）。曲は、カットシーンのものを続ける。
			last_talk = talk_of(episode, [], last_music, hero)
			if episode.has_battle():
				last_talk.battle = battle
				last_talk.after = fought
			run.add(TALK, last_talk)
		last_talk.lines.append_array(news)
		last_talk.closes = true
		last_talk.next_episode = episode_after(episode)
		if not episode.has_battle():
			last_talk.clears = episode.id  # 対戦の無い話は、最後の会話を読み終えたらクリア（talk_screen.gd の _end）
	return run


## 話の一覧（と物語選択）の「部隊編成」で始める流れ（run.gd）: 部隊編成（of_campaign のストーリー用）→ 戻り先 back_to。
## 寄り道で取っておいた部隊は、その物語の出撃準備で選ばれる（deck_screen.gd の leave。物語を、いまの物語にしてから始める）。
## back_label は編成の「戻る」の文字の鍵。
static func deck_run(of_campaign: Campaign, back_to: StringName, back_label: String) -> Run:
	var detour := Run.new()
	detour.add(SceneFlow.DECKS, {"rules": of_campaign.rules_id, "back_label": back_label})
	detour.add(back_to)
	return detour


## 話し手の名前 -> 人物の形（unit_looks.gd の PERSONS の名前。[cast] の姿に人物の形があるか、将の姿のある陣営の将）。
## 盤のカットシーンで、話し手と同じ名前の兵を、その人の形で立たせる。
static func person_looks(episode: Episode) -> Dictionary:
	var looks := {}
	for i in mini(episode.speakers.size(), episode.figures.size()):
		var look: StringName = (episode.figures[i] as Dictionary).get("look", &"")
		if look != &"":
			looks[episode.speakers[i]] = look
	return looks


## 会話の場面（talk_screen.gd）に渡すもの（talk_scene.gd。型は MAP）: 話 episode の行 rows を、曲 track で。背景は話の盤。
## 主人公の名前 hero（空なら既定の名前）を、文と札に入れる。話の流れ（run_of）が、場面の型と、型ごとの欄を足す。
static func talk_of(episode: Episode, rows: Array[Episode.TalkLine], track := &"", hero := "") -> TalkScene:
	var talk := TalkScene.make(TalkScene.Shape.MAP, episode.title)
	for row in rows:
		# 地の文（話し手が -1）は、名前の無い行（talk_screen.gd が、札を出さずに真ん中へ出す）。
		var line := TalkScene.Line.new(row.side, row.speaker_in(episode.speakers, hero), row.shown_text(hero), row.who)
		# 主人公の名前が話の途中で決まったら、入れ直せるように（rename_talk）: 印のある文は書いたままの文も、主人公の行は印を持つ。
		if row.text.contains(HeroName.MARK):
			line.raw = row.text
		line.hero_line = row.hero != "" and row.speaker_in(episode.speakers) == row.hero
		line.naming = row.asks_name  # この行のあとで、名前を聞く（まだ名乗っていなければ。talk_screen/talk_naming.gd）
		# 選択肢（docs/story.md の「選択肢」）: この行のあとに選ばせるものと、この行を出す条件。
		if row.asks():
			var options: Array[TalkScene.Option] = []
			for option: Dictionary in row.options:
				options.append(TalkScene.Option.new(option["key"], HeroName.fill(option["text"], hero if hero != "" else row.hero), option["text"]))
			line.choice = TalkScene.Choice.new(row.choice, options)
		if row.when_choice != &"":
			line.when = TalkScene.When.new(row.when_choice, row.when_answer, row.when_not)
		talk.lines.append(line)
	talk.board = episode.map.make_board()
	talk.look = episode.look
	talk.track = track
	talk.figures = episode.figures
	talk.hero = episode.hero
	return talk


## 話の途中で名乗ったとき（会話の「(name)」）: いまの流れの、先の場面の文と札にも入れる。
func _renamed(default_name: String, named: String) -> void:
	var run: Run = _run.get_ref() if _run != null else null
	if run != null:
		rename_run(run, default_name, named)


## 流れ run の場面（会話、話の対戦）に、主人公（既定の名前 default_name）の名前 named を入れ直す。
static func rename_run(run: Run, default_name: String, named: String) -> void:
	for data: Variant in run.all_data():
		if data is StoryBattle:
			if (data as StoryBattle).episode.hero == default_name:
				(data as StoryBattle).hero = named
		elif data is TalkScene:
			rename_talk(data, default_name, named)


## 会話 talk の文と札に、主人公（既定の名前 default_name）の名前 named を入れ直す（書いたままの文から作り直す）。
static func rename_talk(talk: TalkScene, default_name: String, named: String) -> void:
	if talk.hero != default_name or default_name == "":
		return
	for line in talk.lines:
		if line.raw != "":
			line.text = HeroName.fill(line.raw, named)
		if line.hero_line:
			line.name = named
		if line.choice != null:
			for option in line.choice.options:
				option.text = HeroName.fill(option.raw, named)
