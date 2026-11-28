extends RefCounted
## 自動の対戦（autoplay.gd）の、通しの点検（playtest-sweep）のための長い道。PR ごとの検査（tools/check.sh）には、形の違う話の 3 つだけ（story_shapes）。
##
## - `-- --autoplay --story-all`: すべての物語（本編の 2 つと番外）の全部の話を、画面の道で通す（`--story-part=<k>/<n>` で、物語を n 組に分けた k 組目だけ）。
##   タイトル →「ストーリー」→ セーブデータ選択 → 物語を選ぶ → 話の一覧（確かめ用の解放 F5 で全部を開く）→ 話を選ぶ →
##   話の場面の列のとおりに（autoplay/scene_walk.gd。会話・カットシーンは 1 文ずつ送り、出撃準備は「出撃」）→ 対戦の途中の台詞（[cues]）を 1 つずつ出して送る →
##   小さな盤でわざと負けて、決着の画面の負けの台詞（[lost]）を見る →「話の一覧へ」で戻る →
##   もう一度選んで、勝って対戦のあとの場面を最後まで読む（選択肢と、答えで替わる行があれば、答えの番号ごとに 1 度ずつ）→ 次の話へ。
## - `-- --autoplay --versus-all`: 対戦モードの全部のマップを、選べる決まり（OptionalRules.choosable()。休眠の決まりは画面から入にできない）を全部切ったものと全部入れたもので、
##   タイトル →「対戦」→ マップ選択 → 対戦設定（相手は CPU）→ 対戦を VERSUS_TURNS ターンまで（自分の番は「おまかせ」）→ タイトル。
##   選べる決まりが増えても、OptionalRules.choosable() から取るので、ここは変えなくてよい。
##
## 確かめたことが外れたら autoplay.gd の _expect で貯め、最後にまとめて失敗にする（"autoplay: OK" が出なければ失敗）。
## 使い方は docs/README.md の「検査の分け方」と、.claude/skills/playtest-sweep/SKILL.md（手で回すときは tools/sweep.sh）。

const SceneFlow := preload("res://game/scene_flow.gd")
const Text := preload("res://game/text.gd")
const Story := preload("res://game/story.gd")
const BattleCues := preload("res://game/battle_cues.gd")
const BattleHud := preload("res://game/battle_hud.gd")
const VersusFields := preload("res://game/versus_fields.gd")

## 対戦モードの 1 局を、このターンまで進める。
const VERSUS_TURNS := 4
## 待つ上限（コマ）。
const WAIT_FRAMES := 3000

## 呼んだ自動の対戦（autoplay.gd。_expect と、キーを押す道具を借りる）。
var _autoplay: Node
## 選択肢を最初の答えだけで通すか（PR ごとの点検の story_shapes）。
var _first_answers_only := false


func _init(autoplay: Node) -> void:
	_autoplay = autoplay


## 引数で選んだ道を通す。
func run(app: Node, args: PackedStringArray) -> void:
	# 自動の対戦は、対戦の場面から始まる。場面の切り替え（幕が明ける）が済むのを待ってから、タイトルへ。
	while app.get(&"_changing"):
		await app.get_tree().process_frame
	await app.go(SceneFlow.TITLE)
	_expect(app.current_id() == SceneFlow.TITLE, "タイトルへ戻れない")
	if args.has("--story-all"):
		var part := _story_part(args)
		var campaigns := Story.campaigns().filter(func(campaign: RefCounted) -> bool: return Story.is_ready(campaign))
		for i: int in campaigns.size():
			if i % part.y == part.x - 1:
				await _story_campaign(app, campaigns[i])
	if args.has("--versus-all"):
		for field in VersusFields.ids():
			for rules: Array[StringName] in [[] as Array[StringName], OptionalRules.choosable()]:
				await _versus(app, field, rules)


## PR ごとの点検（autoplay.gd の story）: 形の違う話を 1 つずつ（shape_episodes）、長い検査と同じ道で通して、タイトルへ戻る。
## 選択肢は最初の答えだけ（全部の答えは、長い検査）。
func story_shapes(app: Node) -> void:
	_first_answers_only = true
	var picked := shape_episodes()
	for campaign: RefCounted in Story.campaigns():
		var mine := picked.filter(func(episode: RefCounted) -> bool: return Story.campaign_of(episode) == campaign)
		if not mine.is_empty():
			await _story_campaign(app, campaign, mine)
	_first_answers_only = false
	await _go(app, SceneFlow.TITLE)


## 形の違う話（どれも対戦のある話。物語の並びで最初に見つかったもの）: [before]・[after] で書いた話 / 場面の節で書き、対戦のあとの場面が 2 つ以上ある話 /
## 盤のカットシーンのある話。話の形が変わっても、そのときの話から選び直す。
static func shape_episodes() -> Array:
	var picked: Array = [null, null, null]
	for episode: RefCounted in Story.all_episodes():
		if not episode.has_battle():
			continue
		var boards: bool = episode.scenes.any(func(scene: RefCounted) -> bool: return scene.board_cut != null)
		var after: int = episode.scenes.size() - 1 - episode.scenes.find(episode.scenes.filter(func(scene: RefCounted) -> bool: return scene.is_battle())[0])
		if picked[0] == null and not episode.written_as_scenes:
			picked[0] = episode
		elif picked[1] == null and episode.written_as_scenes and after >= 2 and not boards:
			picked[1] = episode
		elif picked[2] == null and boards:
			picked[2] = episode
	return picked.filter(func(episode: RefCounted) -> bool: return episode != null)


## 引数 `--story-part=<k>/<n>`: 遊べる物語を並びの順に n 組へ配り（k 組目は k, k + n, … 番目）、k 組目だけを通す。無ければ全部（1/1）。
static func _story_part(args: PackedStringArray) -> Vector2i:
	for arg: String in args:
		if arg.begins_with("--story-part="):
			var pair := arg.trim_prefix("--story-part=").split("/")
			if pair.size() == 2 and pair[0].is_valid_int() and pair[1].is_valid_int() and int(pair[0]) >= 1 and int(pair[0]) <= int(pair[1]):
				return Vector2i(int(pair[0]), int(pair[1]))
	return Vector2i(1, 1)


func _expect(ok: bool, message: String) -> void:
	_autoplay._expect(ok, message)


func _go(app: Node, id: StringName) -> void:
	if app.current_id() != id:
		await app.go(id)


## 物語 campaign の話を通す（only が空なら全部の話。空でなければ、その話だけ）。
func _story_campaign(app: Node, campaign: RefCounted, only: Array = []) -> void:
	_autoplay._current = "story-all %s" % campaign.title
	await _go(app, SceneFlow.TITLE)
	app.current_scene().press_story()
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.SLOTS, "タイトルの「ストーリー」で、セーブデータ選択へ進まない")
	if app.current_id() != SceneFlow.SLOTS:
		return
	app.current_scene().choose(1)
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.CAMPAIGNS, "セーブデータ選択でスロットを選んでも、物語を選ぶ場面へ進まない")
	if app.current_id() != SceneFlow.CAMPAIGNS:
		return
	app.current_scene().choose(campaign)
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.EPISODES, "物語を選んでも、話の一覧へ進まない: %s" % campaign.title)
	if app.current_id() != SceneFlow.EPISODES:
		return
	if not app.context.story.open_all:
		_autoplay._push_key(app, KEY_F5)
		await app.scene_changed
	_expect(app.context.story.open_all, "F5 で、全部の話を開かない")
	for i: int in campaign.episodes.size():
		var episode: RefCounted = campaign.episodes[i]
		if not only.is_empty() and not only.has(episode):
			continue
		_autoplay._current = "story-all %s 第 %d 話「%s」" % [campaign.title, i + 1, episode.title]
		print("autoplay: %s" % _autoplay._current)
		if app.current_id() != SceneFlow.EPISODES:
			_expect(false, "話の一覧に戻っていない")
			return
		await _story_episode(app, episode)
	if app.context.story.open_all:
		_autoplay._push_key(app, KEY_F5)
		await app.scene_changed


## 話の一覧から、話 episode を通す（場面の列のとおりに。autoplay/scene_walk.gd）。対戦のある話は 2 度以上:
## 1. 途中の台詞を送ってから、わざと負けて負けの台詞を見る（対戦のあとの場面へは進まない）。
## 2. 勝って、対戦のあとの場面を最後まで読む。選択肢か、答えで替わる行（(if 名前 = 鍵)。前の話の選択肢を拾う行も）があれば、
##    答えの番号ごとに 1 度ずつ（どの選択肢も、その番号の答え。答えの少ない選択肢は最後の答え）。どの答えでも、行が読めて枠からはみ出さないこと。
func _story_episode(app: Node, episode: RefCounted) -> void:
	if episode.has_battle():
		await _walk_from_list(app, episode, {"battle": func(screen: Node) -> Node:
			await _start_battle(screen, episode)
			await _read_cues(app, screen, episode)
			await _lose(app, screen, episode)
			return null})
	var branches: Dictionary = _branches_of(episode)
	var ways := 1
	for keys: Array in branches.values():
		ways = maxi(ways, keys.size())
	for way: int in (1 if _first_answers_only else ways):
		if not branches.is_empty():
			print("autoplay:   答え %d（%s）" % [way + 1, ", ".join(branches.keys())])
		# 前の話の選択肢は、話を始める前に答えを置いておく（この話で選ぶものは、画面で選ぶ）。
		var answers := {}
		for choice: StringName in branches:
			var keys: Array = branches[choice]
			var pick := mini(way, keys.size() - 1)
			answers[choice] = pick
			app.context.story.choose_answer(choice, keys[pick])
		# 勝つのは、PR ごとの点検と同じ道（小さな盤で 1 手。対戦の画面の決まりも見る。story_checks.gd）。
		await _walk_from_list(app, episode, {"battle": func(screen: Node) -> Node:
			return await _autoplay._win_story_battle(app, screen, episode, screen.source.human_deck)}, answers)


## 話の一覧から話 episode を選び、場面の列を手順 steps・答え answers で通して、話の一覧へ戻る。
func _walk_from_list(app: Node, episode: RefCounted, steps: Dictionary, answers := {}) -> void:
	var list: Node = app.current_scene()
	_expect(list.is_card_enabled(episode), "話の一覧で選べない")
	list.choose(episode)
	await app.scene_changed
	await _autoplay._walk_scenes(app, episode, steps, answers)
	await _autoplay._settle_scene(app)
	# 最後の場面を読み終えるか、負けたら話の一覧へ。途中で外れたときも、話の一覧へ戻す。
	_expect(app.current_id() == SceneFlow.EPISODES, "話を終えても、話の一覧へ戻らない")
	await _go(app, SceneFlow.EPISODES)


## 話 episode の会話の行が答えで替わる選択肢: 名前 -> 答えの鍵の列（この話で選ぶものと、出す条件 (if 名前 = 鍵) に書いたもの。前の話の選択肢も）。
static func _branches_of(episode: RefCounted) -> Dictionary:
	var keys_of := {}  # 選択肢の名前 -> 答えの鍵（物語のどの話で選ぶものでも）
	for each: RefCounted in Story.campaign_of(episode).episodes:
		for scene: RefCounted in each.scenes:
			for row: RefCounted in scene.lines:
				if row.asks():
					keys_of[row.choice] = row.options.map(func(option: Dictionary) -> StringName: return StringName(option["key"]))
	var found := {}
	for scene: RefCounted in episode.scenes:
		for row: RefCounted in scene.lines:
			for choice: StringName in [row.choice if row.asks() else &"", row.when_choice]:
				if choice != &"" and keys_of.has(choice):
					found[choice] = keys_of[choice]
	return found


## 話の対戦の始め: 「対戦ルール」（その話の勝利条件）が出て、札の文は切れない。閉じると、対戦が始まる。
func _start_battle(screen: Node, episode: RefCounted) -> void:
	screen.set_time_scale_base(8.0)
	_expect(screen.notice_text() != "", "話の対戦の始めに「対戦ルール」が出ない: %s" % episode.id)
	_expect(screen.notice_cut_texts().is_empty(), "「対戦ルール」の札の文が切れている: %s" % [screen.notice_cut_texts()])
	screen.hide_notice()


## 対戦の途中の台詞を、1 つずつ出して送る（遊ぶときと同じに、送られるまで出したまま）。帯は 2 行の高さまでで、上の帯に重ならない。
func _read_cues(app: Node, screen: Node, episode: RefCounted) -> void:
	screen.clear_talk_for_check()
	screen.set_talk_hold(true)
	for cue: RefCounted in episode.cues:
		screen.say_for_check([BattleCues.line_of(cue.line, episode.speakers, episode.figures)] as Array[BattleCues.Line])
		await app.get_tree().process_frame
		await app.get_tree().process_frame
		var card: Rect2 = screen.talk_card_rect()
		_expect(card.has_area() and card.position.y >= BattleHud.TOP_BAR_HEIGHT and card.size.y <= 64.0,
			"途中の台詞の帯が出ないか、上の帯に重なるか、2 行を超える: %s（%s）" % [cue.line.text, card])
		for other: Rect2 in screen.talk_card_neighbors():
			_expect(not card.intersects(other), "途中の台詞の帯が、勝ち方の札・視点の案内・ミニマップに重なる: %s（%s と %s）" % [cue.line.text, card, other])
		for i: int in WAIT_FRAMES:
			if screen.advance_talk():
				break
			await app.get_tree().process_frame
		_expect(not screen.is_talk_holding(), "途中の台詞を送れない: %s" % cue.line.text)
	screen.set_talk_hold(false)
	screen.clear_talk_for_check()


## 小さな盤で、人の将の HP を 1 にしてターンを終え、敵（CPU）に倒させて負ける。決着の画面に、話の負けの台詞が出る。
## そのあと「話の一覧へ」で戻る。
func _lose(app: Node, screen: Node, episode: RefCounted) -> void:
	var board: Board = _autoplay._small_board(Vector2i(5, 4))
	var battle := Battle.new(board)
	var king := battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER1, board.hq_cells[0])
	king.hp = 1
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER2, board.hq_cells[1])
	battle.add_unit(UnitKind.Id.SNIPER, Unit.Side.PLAYER2, board.hq_cells[0] + Vector2i(2, 0))
	screen.start_with(battle, episode.look, 1, episode.map_title)
	screen.hide_notice()
	screen.press_end_turn()
	screen.pass_confirm_guard()
	screen.press_end_turn()
	var result: Node = screen.result_screen()
	for i: int in WAIT_FRAMES:
		if not screen.is_busy() and result.visible:
			break
		await app.get_tree().process_frame
	_expect(battle.is_over() and battle.winner == Unit.Side.PLAYER2, "わざと負けられなかった")
	result.skip()
	# ストーリーの決着は、遊ぶ人の側から書く（「CPU（赤）の勝ち」と書かない）。
	var reason: String = result.shown_summary().reason
	_expect(reason == "敗北　将が倒れた", "話で負けた決着の文が、遊ぶ人の側から書かれていない: %s" % reason)
	var lost: Array[String] = []
	for row: RefCounted in episode.lost:
		lost.append("%s: %s" % [row.speaker_in(episode.speakers), row.shown_text()])
	_expect(result.remark_texts() == lost, "負けの台詞が、話のファイルのとおりに出ない: %s" % [result.remark_texts()])
	if not lost.is_empty():
		var rect: Rect2 = result.remark_rect()
		_expect(rect.has_area() and app.get_viewport().get_visible_rect().encloses(rect), "負けの台詞の板が画面からはみ出す: %s" % rect)
	for i: int in WAIT_FRAMES:
		if result.can_leave():
			break
		await app.get_tree().process_frame
	_expect(result.can_leave(), "負けた話の決着の画面に「話の一覧へ」が無い")
	var leave: String = result.leave_text()
	result.press_leave()
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.EPISODES, "決着の画面の「%s」で、話の一覧へ戻らない" % leave)
	await _go(app, SceneFlow.EPISODES)


## 対戦モードの 1 局: マップ field、選べる決まり rules で、CPU を相手に VERSUS_TURNS ターンまで進める。
func _versus(app: Node, field: StringName, rules: Array[StringName]) -> void:
	_autoplay._current = "versus-all %s（選べる決まり: %s）" % [field, ", ".join(rules) if not rules.is_empty() else "なし"]
	print("autoplay: %s" % _autoplay._current)
	await _go(app, SceneFlow.TITLE)
	app.current_scene().press_start()
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.MAP_SELECT, "タイトルの「対戦」で、マップ選択へ進まない")
	if app.current_id() != SceneFlow.MAP_SELECT:
		return
	app.current_scene().choose(field)
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.SETUP, "マップのカードで、対戦設定へ進まない")
	if app.current_id() != SceneFlow.SETUP:
		return
	var panel: Node = app.current_scene().setup_panel()
	panel.choose_opponent(true)
	for rule in OptionalRules.choosable():
		panel.choose_rule(rule, rules.has(rule))
	panel.confirm()
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.BATTLE, "対戦設定の「対戦開始」で、対戦へ進まない")
	if app.current_id() != SceneFlow.BATTLE:
		return
	var screen: Node = app.current_scene()
	screen.set_time_scale_base(8.0)
	# 対戦の始めに「対戦ルール」（勝利条件と、あれば縫い目の様子）が出て、札の文は切れない。
	_expect(screen.notice_text().contains(Text.t("battle.goal.name.king_defeated")), "対戦の始めに「対戦ルール」が出ない")
	_expect(screen.notice_cut_texts().is_empty(), "「対戦ルール」の札の文が切れている: %s" % [screen.notice_cut_texts()])
	screen.hide_notice()  # 閉じると、対戦が始まる
	# 縫い目の様子は、対戦設定の「ランダム」なら種で 0〜2 つ（窓は出さず、そのまま始まる）。「なし」なら付かない。
	var signs: Array[int] = screen.battle.signs
	_expect(signs.size() <= Seam.DRAWN and (rules.has(OptionalRules.SEAM) or signs.is_empty()), "縫い目の様子が、決まりの入・切どおりでない: %s" % [signs])
	_expect(screen.signs_text() == "" if signs.is_empty() else screen.signs_text() != "", "上の帯の縫い目の様子の札が、対戦の様子と合わない")
	var battle: Battle = screen.battle
	for rule in OptionalRules.choosable():
		_expect(screen.source.has_rule(rule) == rules.has(rule), "選んだ選べる決まりで、対戦が始まらない: %s" % rule)
	for i: int in WAIT_FRAMES * 4:
		battle = screen.battle
		if battle.is_over() or battle.turn > VERSUS_TURNS:
			break
		if screen.is_busy() or battle.phase != screen.source.human_side_now():
			await app.get_tree().process_frame
			continue
		screen.press_auto()
		screen.pass_confirm_guard()
		screen.press_auto()
		await app.get_tree().process_frame
	_expect(battle.is_over() or battle.turn > VERSUS_TURNS, "%d ターンまで進まなかった（ターン %d）" % [VERSUS_TURNS, battle.turn])
	print("autoplay:   ターン %d まで（%s）" % [battle.turn, "決着" if battle.is_over() else "途中"])
	await app.go(SceneFlow.TITLE)
