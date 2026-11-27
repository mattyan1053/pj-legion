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
