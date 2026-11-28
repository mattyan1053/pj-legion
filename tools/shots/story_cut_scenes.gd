extends "res://tools/shots/story_patrol_scenes.gd"
## スクリーンショットの場面: ストーリーの盤のカットシーン（盤の上で兵が台本どおりに動く。docs/story.md の「盤のカットシーン」）。
## 連邦の「尾根の待ち伏せ」の、出撃のあとの [board 尾根の中ほど]。動きの途中のコマは、決めた時刻で撮る。


## 連邦の「尾根の待ち伏せ」の、盤のカットシーンに入ったところ（始めの動きの再生が始まった）。
func _ridge_ambush_board() -> bool:
	var at := -1
	for i in Story.military().episodes.size():
		if Story.military().episodes[i].id == &"ridge_ambush":
			at = i
	if at < 0 or not await _start_story(at):
		return false
	_app.current_scene().press_sortie()
	await _app.scene_changed
	return _app.current_id() == SceneFlow.TALK and _app.current_scene().is_board_cut()


## 次の文を出せるまで（動きの再生が終わるまで）待つ。
func _until_line(talk: Node) -> void:
	while talk.is_beat_playing():
		await get_tree().process_frame


## 偵察のピップが、尾根の中ほどの敵の前まで歩いた途中（文の枠は消えている）。
func _scene_story_board_walk() -> bool:
	if not await _ridge_ambush_board():
		return false
	await get_tree().create_timer(2.6).timeout
	_mid_animation = true
	return _app.current_scene().is_beat_playing()


## ピップが戻って、最初の台詞（盤は止まっている）。
func _scene_story_board_line() -> bool:
	if not await _ridge_ambush_board():
		return false
	var talk: Node = _app.current_scene()
	await _until_line(talk)
	return talk.line_index() == 0 and talk.speaker() == "ピップ"


## イェルダが前へ出て、台詞（盤は止まっている）。
func _scene_story_board_reply() -> bool:
	if not await _ridge_ambush_board():
		return false
	var talk: Node = _app.current_scene()
	await _until_line(talk)
	talk.press_next()
	talk.press_next()
	await _until_line(talk)
	return talk.line_index() == 1 and talk.speaker() == "イェルダ"


## 話の会話の場面（SCENES に並べない。話と場面を、名前で作る）:
##   talk.<話の id>.<場面>.<行>
## 場面は、その話の会話の場面（[talk 名前]・[cut 名前]・[board 名前]。[before]・[after] も）の番号（0 から、書いた順）。
## 行は、その場面で送る回数（0 なら最初の文。選ばせる行は 1 つ目の答えを選び、盤のカットシーンは動きの終わりを待ってから送る）。
## 対戦は通さない（対戦のあとの、話の盤を前にした会話には、始めの配置の兵が立つ）。
const TALK_SHOT := "talk."
const TALK_SHOT_USAGE := "talk.<話の id>.<場面の番号>.<送る回数>"


## 会話の場面の名前 name を [話, 場面の番号, 送る回数] に分ける（書き間違いなら空）。
func _talk_shot_parts(name: String) -> Array:
	var parts := name.substr(TALK_SHOT.length()).split(".")
	if parts.size() != 3 or not parts[1].is_valid_int() or not parts[2].is_valid_int():
		return []
	for episode: RefCounted in Story.all_episodes():
		if String(episode.id) == parts[0] and int(parts[1]) >= 0 and int(parts[1]) < episode.talk_scenes().size():
			return [episode, int(parts[1]), int(parts[2])]
	return []


func _talk_shot_known(name: String) -> bool:
	return not _talk_shot_parts(name).is_empty()


## 話の会話の場面を、流れ（Story.run_now）のその場面から始めて、決めた回数だけ送ったところ。
func _talk_shot(name: String) -> bool:
	var parts := _talk_shot_parts(name)
	var episode: RefCounted = parts[0]
	var story: RefCounted = _app.context.story
	story.choose_campaign(Story.campaign_of(episode))
	var run: RefCounted = story.run_now(episode)
	var seen := -1
	while run.scene() != &"":
		if run.scene() == SceneFlow.TALK:
			seen += 1
			if seen == parts[1]:
				break
		run.index += 1
	if run.scene() != SceneFlow.TALK:
		return false
	_app.context.run = run
	await _app.go(SceneFlow.TALK)
	var talk: Node = _app.current_scene()
	await _until_line(talk)
	for i: int in parts[2]:
		talk.press_next()
		if talk.is_asking():
			talk.press_option(0)
		await _until_line(talk)
	return _app.current_id() == SceneFlow.TALK
