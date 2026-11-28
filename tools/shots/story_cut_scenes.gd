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


## 話の会話の場面を、名前で撮る（SCENES には並べない。`scape.` と同じ）: `talk.<物語の id>.<話の id>.<場面の番号>[.<行の番号>]`。
## 場面の番号は、その話の会話の場面（会話・カットシーン・盤のカットシーン）を 0 から数えたもの。行の番号（0 から。書かなければ 0）まで送る。
## 選ばせる行は 1 つ目の答え。盤のカットシーンは、動きの再生が終わるのを待ってから送る。
## 前の場面は通らずに、その場面から始める（対戦のあとの会話の背景は、初期位置の味方だけ）。場面を足した話の絵を PR に貼るときに使う。
const TALK_SHOT := "talk."
const TALK_SHOT_USAGE := "talk.<物語の id>.<話の id>.<場面の番号>[.<行の番号>]"


func _talk_shot_parts(name: String) -> Array:
	var parts := name.trim_prefix(TALK_SHOT).split(".")
	if parts.size() < 3 or parts.size() > 4 or not parts[2].is_valid_int() or (parts.size() == 4 and not parts[3].is_valid_int()):
		return []
	var campaign := Story.campaign_by_id(StringName(parts[0]))
	var episode: RefCounted = campaign.find_episode(StringName(parts[1])) if campaign != null else null
	if episode == null:
		return []
	return [episode, int(parts[2]), int(parts[3]) if parts.size() == 4 else 0]


func _talk_shot_known(name: String) -> bool:
	return not _talk_shot_parts(name).is_empty()


func _talk_shot(name: String) -> bool:
	var parts := _talk_shot_parts(name)
	var run: Run = _app.context.story.run_now(parts[0])
	var seen := -1
	while not run.is_done():
		if run.scene() == SceneFlow.TALK:
			seen += 1
			if seen == parts[1]:
				break
		run.index += 1
	if run.is_done():
		return false
	_app.start_run(run)
	await _app.scene_changed
	var talk: Node = _app.current_scene()
	for i in 80:
		await _until_line(talk)
		if talk.line_index() >= parts[2]:
			break
		if talk.is_asking():
			talk.press_option(0)
		else:
			talk.press_next()  # 出しきるか、次の文へ（1 度に 1 つ。文が出きっていると、2 度押せば 2 行進む）
	await _until_line(talk)
	if not talk.is_line_shown():
		talk.press_next()  # 文を出しきる（選ばせる行なら、答えの枠も出る）
	if talk.line_index() != parts[2]:
		print("talk shot: 行 %d で止まった（%s / 全 %d 行）" % [talk.line_index(), _app.current_id(), talk.line_count()])
	return _app.current_id() == SceneFlow.TALK and talk.line_index() == parts[2]
