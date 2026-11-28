extends "res://game/autoplay/title_checks.gd"
## 自動の対戦の道具: 話の場面の列（episode.gd の scenes）を、その話の形のとおりに画面で通す（docs/story.md の「場面の列」）。
## PR ごとの点検（story_checks.gd）と、長い検査の通しの点検（autoplay_sweeps.gd）が使う。決め打ちの順は持たない。
##
## - 会話・カットシーン・盤のカットシーン: 1 文ずつ送る（文と話し手が話のファイルのとおりか）。盤のカットシーンは、兵が動き終えるのを待つ。
## - 選択肢: 決めた答え（answers。無ければ最初の答え）を選び、覚えたことを確かめる。出す条件の行（(if 名前 = 鍵)）は、選んだ答えで拾う。
## - 名を問う行（(name)）: 検査の間は窓を出さない（talk_naming.gd）。既定の名前のまま通る。
## - 出撃準備・対戦: 呼ぶ側の手順（steps）で通す。手順が無ければ、出撃準備はそのまま「出撃」、対戦は通せない（失敗）。
## - 対戦のあとの場面をいくつでも。最後の場面で「次の話へ」「話の一覧へ」を選ぶ（カットシーンで終わる話は、知らせだけの会話の場面が後ろに付く）。

## 待つ上限（コマ）。
const WALK_WAIT_FRAMES := 3000


## 話 episode の場面の列を、いまの画面から順に通す。いまの画面は、列の from 番目の場面。
## steps（どれも無くてよい）:
## - "sortie": func(sortie: Node) -> void。出撃準備で、「出撃」を押す前に呼ぶ（画面を行き来してよいが、出撃準備に戻っておく）。
## - "talk": func(talk: Node, scene: RefCounted, last: bool) -> void。会話の場面の文を送る前に呼ぶ（文を進めてもよい。先は、進んだ所から送る）。
## - "battle": func(screen: Node) -> Node。対戦を決着させ、勝ったら決着の画面を返す（負けたら null。そのあとは呼ぶ側が抜ける）。
## - "choose": func(talk: Node) -> void。最後の場面の「次の話へ」「話の一覧へ」を選ぶ所で呼ぶ（既定は「話の一覧へ」）。
## answers: 選択肢の名前 -> 選ぶ答えの番号（0 から）。
## 返すのは、通し終えたか（途中で外れたら偽。外れたことは _expect で貯めてある）。
func _walk_scenes(app: Node, episode: RefCounted, steps := {}, answers := {}, from := 0) -> bool:
	for at: int in range(from, episode.scenes.size()):
		var scene: RefCounted = episode.scenes[at]
		await _settle_scene(app)
		var where := "%s の %d 番目の場面" % [episode.id, at + 1]
		if scene.kind == Episode.StoryScene.Kind.SORTIE:
			_expect(app.current_id() == SceneFlow.SORTIE, "%s（出撃準備）へ進まない（いまは %s）" % [where, app.current_id()])
			if app.current_id() != SceneFlow.SORTIE:
				return false
			if steps.has("sortie"):
				await steps["sortie"].call(app.current_scene())
				await _settle_scene(app)
				_expect(app.current_id() == SceneFlow.SORTIE, "%s: 出撃準備の手順のあと、出撃準備に戻っていない" % where)
			var sortie: Node = app.current_scene()
			sortie.press_sortie()
			await _leave(app, sortie)
		elif scene.is_battle():
			_expect(app.current_id() == SceneFlow.BATTLE, "%s（対戦）へ進まない（いまは %s）" % [where, app.current_id()])
			if app.current_id() != SceneFlow.BATTLE or not steps.has("battle"):
				_expect(steps.has("battle"), "%s: 対戦を通す手順が無い" % where)
				return false
			var result: Node = await steps["battle"].call(app.current_scene())
			if result == null:
				return false
			_expect(result.can_continue(), "%s: 勝った決着の画面に「次へ」が無い" % where)
			var screen: Node = app.current_scene()
			result.press_continue()
			await _leave(app, screen)
		else:
			_expect(app.current_id() == SceneFlow.TALK, "%s（%s）へ進まない（いまは %s）" % [where, _scene_title(scene), app.current_id()])
			if app.current_id() != SceneFlow.TALK:
				return false
			var last: bool = at == episode.scenes.size() - 1
			if steps.has("talk"):
				await steps["talk"].call(app.current_scene(), scene, last)
			if not await _read_scene(app, episode, scene, answers, last, steps.get("choose", Callable())):
				return false
	await _settle_scene(app)
	return true


## 場面の切り替え（幕が明ける）が済むまで待つ。
func _settle_scene(app: Node) -> void:
	while app.get(&"_changing"):
		await app.get_tree().process_frame


## 場面 node を抜けて、次の場面の幕が明けるまで待つ（押したその場で替わり始めても、待ってから替わっても）。
func _leave(app: Node, node: Node) -> void:
	for i: int in WALK_WAIT_FRAMES:
		if app.get(&"_changing"):
			await app.scene_changed  # 幕が明けたその時（新しい場面の _process は、まだ回っていない）
		elif app.current_scene() != node:
			return
		else:
			await app.get_tree().process_frame
	_expect(false, "場面が替わらない（%s のまま）" % app.current_id())


## 会話の場面の呼び名（失敗の文に出す）。
static func _scene_title(scene: RefCounted) -> String:
	if scene.board_cut != null:
		return "盤のカットシーン「%s」" % scene.name
	if scene.cut:
		return "カットシーン「%s」" % scene.name
	return "会話「%s」" % (scene.name if scene.name != "" else scene.part)


## 会話の場面 scene（いまの画面）を、いまの文から 1 文ずつ送る（文と話し手が話のファイルのとおりか）。最後の文のあとで、次の場面へ進む。
## last（話の最後の場面）なら、後ろの知らせ（とカットシーンのあとの知らせだけの場面）も送り、「次の話へ」「話の一覧へ」を選ぶ所で choose を呼ぶ
## （無ければ「話の一覧へ」）。次の話が無ければ、そのまま話の一覧へ。
func _read_scene(app: Node, episode: RefCounted, scene: RefCounted, answers: Dictionary, last: bool, choose := Callable()) -> bool:
	var talk: Node = app.current_scene()
	var story: RefCounted = app.context.story
	var title := "%s の%s" % [episode.id, _scene_title(scene)]
	var at := 0  # 画面の行の番号（出す条件の合わない行は、数えない）
	for row: RefCounted in scene.lines:
		if not row.holds(story.answer_of):
			continue
		if at < talk.line_index():
			at += 1  # 呼ぶ側の手順が、先へ進めた
			continue
		for i: int in WALK_WAIT_FRAMES:  # 盤のカットシーン: 兵が動き終えるまで、文は出ない
			if not talk.is_beat_playing():
				break
			await app.get_tree().process_frame
		_expect(talk.line_index() == at and talk.line_text() == row.shown_text(), "%s の %d 文目が違う: %s" % [title, at + 1, talk.line_text()])
		_expect(talk.speaker() == row.speaker_in(episode.speakers), "%s の %d 文目の話し手が違う: %s" % [title, at + 1, talk.speaker()])
		talk.press_next()  # 1 回目は、文を出しきる（出しきっていれば、次の文へ）
		if row.asks():
			# 選ばせる行: 答えが出て、選ぶまで進まない。決めた答えを選ぶ。
			var pick: int = answers.get(row.choice, 0)
			_expect(talk.is_asking() and talk.option_texts().size() == row.options.size(), "%s: 選択肢「%s」の答えが出ない" % [title, row.choice])
			talk.press_next()
			_expect(talk.line_index() == at, "%s: 答えを選ぶ前に、次の文へ進んだ" % title)
			talk.press_option(pick)
			_expect(story.answer_of(row.choice) == String(row.options[pick]["key"]), "%s: 選んだ答えを覚えていない: %s" % [title, row.choice])
		elif talk.line_index() == at and app.current_scene() == talk and not talk.is_choosing():
			talk.press_next()
		at += 1
		await app.get_tree().process_frame
		if app.current_scene() != talk:
			break
	if not last:
		await _leave(app, talk)  # 盤のカットシーンは、最後の文のあとの動きを見せてから終える
		return app.current_scene() != talk
	return await _finish_episode(app, talk, choose)


## 話の最後の場面を読み終えた所から: 後ろの知らせを送り（カットシーンで終わる話は、知らせだけの会話の場面が後ろに付く）、
## 「次の話へ」「話の一覧へ」を選ぶ所で choose を呼ぶ（無ければ「話の一覧へ」）。次の話が無ければ、そのまま話の一覧へ。
func _finish_episode(app: Node, talk: Node, choose: Callable) -> bool:
	for i: int in WALK_WAIT_FRAMES:
		if app.current_scene() != talk and app.current_id() == SceneFlow.TALK and not app.get(&"_changing"):
			talk = app.current_scene()  # 知らせだけの会話の場面
		if app.current_id() != SceneFlow.TALK or talk.is_choosing():
			break
		if not app.get(&"_changing") and not talk.is_beat_playing():
			talk.press_next()
		await app.get_tree().process_frame
	if app.current_id() == SceneFlow.TALK and talk.is_choosing():
		if choose.is_valid():
			await choose.call(talk)
		else:
			talk.press_to_episodes()
	await _leave(app, talk)
	return app.current_scene() != talk
