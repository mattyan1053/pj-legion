extends RefCounted
## 自動の対戦（autoplay.gd）の、通しの点検（playtest-sweep）のための長い道。PR ごとの検査（tools/check.sh）には入れない。
##
## - `-- --autoplay --story-all`: すべての物語（本編の 2 つと番外）を、第 1〜STORY_EPISODES 話まで、画面の道で通す。
##   タイトル →「ストーリー」→ セーブデータ選択 → 物語を選ぶ → 話の一覧（確かめ用の解放 F5 で全部を開く）→ 話を選ぶ →
##   出撃準備 →「出撃」→ 対戦の前の会話を 1 文ずつ送る → 対戦の途中の台詞（[cues]）を 1 つずつ出して送る →
##   小さな盤でわざと負けて、決着の画面の負けの台詞（[lost]）を見る →「話の一覧へ」で戻り、次の話へ。
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

## 物語ごとに通す話の数（頭から）。
const STORY_EPISODES := 15
## 対戦モードの 1 局を、このターンまで進める。
const VERSUS_TURNS := 4
## 待つ上限（コマ）。
const WAIT_FRAMES := 3000

## 呼んだ自動の対戦（autoplay.gd。_expect と、キーを押す道具を借りる）。
var _autoplay: Node


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
		for campaign in Story.campaigns():
			if Story.is_ready(campaign):
				await _story_campaign(app, campaign)
	if args.has("--versus-all"):
		for field in VersusFields.ids():
			for rules: Array[StringName] in [[] as Array[StringName], OptionalRules.choosable()]:
				await _versus(app, field, rules)


func _expect(ok: bool, message: String) -> void:
	_autoplay._expect(ok, message)


func _go(app: Node, id: StringName) -> void:
	if app.current_id() != id:
		await app.go(id)


## 物語 campaign の頭の STORY_EPISODES 話を通す。
func _story_campaign(app: Node, campaign: RefCounted) -> void:
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
	for i: int in mini(STORY_EPISODES, campaign.episodes.size()):
		var episode: RefCounted = campaign.episodes[i]
		_autoplay._current = "story-all %s 第 %d 話「%s」" % [campaign.title, i + 1, episode.title]
		print("autoplay: %s" % _autoplay._current)
		if app.current_id() != SceneFlow.EPISODES:
			_expect(false, "話の一覧に戻っていない")
			return
		await _story_episode(app, episode)
	if app.context.story.open_all:
		_autoplay._push_key(app, KEY_F5)
		await app.scene_changed


## 話の一覧から、話 episode を選んで、会話・途中の台詞・負けの台詞を通し、話の一覧へ戻る。
func _story_episode(app: Node, episode: RefCounted) -> void:
	var list: Node = app.current_scene()
	_expect(list.is_card_enabled(episode), "話の一覧で選べない")
	list.choose(episode)
	await app.scene_changed
	# 話の場面の列（episode.gd の scenes）を順に通す。対戦はわざと負けるので、対戦のあとの会話へは進まない。
	for scene: RefCounted in episode.scenes:
		if scene.is_battle():
			_expect(app.current_id() == SceneFlow.BATTLE, "対戦へ進まない")
			if app.current_id() != SceneFlow.BATTLE:
				break
			var screen: Node = app.current_scene()
			screen.set_time_scale_base(8.0)
			# 対戦の始めに「対戦ルール」（その話の勝利条件）が出て、札の文は切れない。
			_expect(screen.notice_text() != "", "話の対戦の始めに「対戦ルール」が出ない: %s" % episode.id)
			_expect(screen.notice_cut_texts().is_empty(), "「対戦ルール」の札の文が切れている: %s" % [screen.notice_cut_texts()])
			screen.hide_notice()  # 閉じると、対戦が始まる
			await _read_cues(app, screen, episode)
			await _lose(app, screen, episode)
			return
		elif scene.is_talk():
			_expect(app.current_id() == SceneFlow.TALK, "会話の場面「%s」へ進まない" % scene.part)
			if app.current_id() != SceneFlow.TALK:
				break
			await _read_talk(app, episode, scene)
		else:
			_expect(app.current_id() == SceneFlow.SORTIE, "出撃準備へ進まない")
			if app.current_id() != SceneFlow.SORTIE:
				break
			app.current_scene().press_sortie()
			await app.scene_changed
	# 対戦の無い話は、最後の会話を読み終えたら話の一覧へ。途中で外れたときも、話の一覧へ戻す。
	_expect(app.current_id() == SceneFlow.EPISODES, "話を終えても、話の一覧へ戻らない")
	await _go(app, SceneFlow.EPISODES)


## 会話の場面 scene を、1 文ずつ送る（文と話し手が話のファイルのとおりか）。最後の文のあとで、次の場面へ進む。
## 話の最後の会話なら、「次の話へ」「話の一覧へ」を選ぶ所で「話の一覧へ」。
func _read_talk(app: Node, episode: RefCounted, scene: RefCounted) -> void:
	var talk: Node = app.current_scene()
	var last: bool = episode.scenes.back() == scene
	_expect(last or talk.line_count() == scene.lines.size(), "会話の文の数が違う: %s" % scene.part)
	for i: int in scene.lines.size():
		var row: RefCounted = scene.lines[i]
		_expect(talk.line_index() == i and talk.line_text() == row.shown_text(), "会話の %d 文目が違う: %s" % [i + 1, talk.line_text()])
		_expect(talk.speaker() == row.speaker_in(episode.speakers), "会話の %d 文目の話し手が違う: %s" % [i + 1, talk.speaker()])
		talk.press_next()  # 1 回目は、文を出しきる（出しきっていれば、次の文へ）
		if talk.line_index() == i and app.current_id() == SceneFlow.TALK and not talk.is_choosing():
			talk.press_next()
		await app.get_tree().process_frame
		if app.current_id() != SceneFlow.TALK:
			return
	# 最後の会話の後ろの知らせ（クリアで増えるもの）を送る。
	while last and not talk.is_choosing() and talk.line_index() < talk.line_count() - 1:
		talk.press_next()
	if last and not talk.is_choosing():
		talk.press_next()
		await app.get_tree().process_frame
	if app.current_id() != SceneFlow.TALK:
		return
	if talk.is_choosing():
		talk.press_to_episodes()
	await app.scene_changed


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
