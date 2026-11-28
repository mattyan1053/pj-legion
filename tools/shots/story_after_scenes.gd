extends "res://tools/shots/story_cut_scenes.gd"
## スクリーンショットの場面: 話の対戦を勝ち切ったあとの場面（決着の画面 → 対戦のあとの場面）。名前で撮る（SCENES には並べない。`talk.` と同じ）:
## `after.<物語の id>.<話の id>.<場面の番号>[.<行の番号>]`。場面の番号は、-1 で決着の画面、0 から対戦のあとの会話の場面（会話・カットシーン・盤のカットシーン）。
## 行の番号（0 から。書かなければ 0）まで送る。選ばせる行は 1 つ目の答え。
##
## 話の流れを出撃準備から始め（前の会話は飛ばす）、話の対戦を、出撃準備の部隊・初期位置のまま CPU どうしで進める。
## 人の側が勝つ最後の 1 手の手前で画面に出し、その手を画面で指す（人の側が勝たない種なら、種を替えてやり直す）。
## 対戦のあとの、盤の前の会話の背景には、決着したときの生き残った兵が立つ（`talk.<…>` は前の場面を通らないので、初期位置の味方だけ）。

const AFTER_SHOT := "after."
const AFTER_SHOT_USAGE := "after.<物語の id>.<話の id>.<場面の番号（-1 で決着の画面）>[.<行の番号>]"


func _after_shot_parts(name: String) -> Array:
	var parts := name.trim_prefix(AFTER_SHOT).split(".")
	if parts.size() < 3 or parts.size() > 4 or not parts[2].is_valid_int() or (parts.size() == 4 and not parts[3].is_valid_int()):
		return []
	var campaign := Story.campaign_by_id(StringName(parts[0]))
	var episode: RefCounted = campaign.find_episode(StringName(parts[1])) if campaign != null else null
	if episode == null or not episode.has_battle():
		return []
	return [episode, int(parts[2]), int(parts[3]) if parts.size() == 4 else 0]


func _after_shot_known(name: String) -> bool:
	return not _after_shot_parts(name).is_empty()


func _after_shot(name: String) -> bool:
	var parts := _after_shot_parts(name)
	var episode: RefCounted = parts[0]
	_app.context.story.choose_campaign(Story.campaign_of(episode))  # クリアは、その物語の記録に書く
	var run: Run = _app.context.story.run_now(episode)
	while not run.is_done() and run.scene() != Story.SORTIE:
		run.index += 1  # 出撃準備より前の場面は通らない
	if run.is_done():
		return false
	_app.start_run(run)
	await _app.scene_changed
	if not _at_sortie() or not await _sortie_to_battle():
		return false
	_scene = _app.current_scene()
	if not await _win_to_last_move():
		return false
	var result: Node = _scene.result_screen()
	for i in 600:
		if result.visible and not _scene.is_busy():
			break
		await get_tree().process_frame
	result.skip()
	for i in 600:
		if result.can_continue():
			break
		await get_tree().process_frame
	if not result.can_continue():
		return false
	if parts[1] < 0:
		return true
	result.press_continue()
	await _app.scene_changed
	for seen: int in parts[1]:
		if not await _skip_talk_scene():
			return false
	if _app.current_id() != SceneFlow.TALK:
		return false
	var talk: Node = _app.current_scene()
	for i in 80:
		await _until_line(talk)
		if talk.line_index() >= parts[2]:
			break
		if talk.is_asking():
			talk.press_option(0)
		else:
			talk.press_next()
	await _until_line(talk)
	if not talk.is_line_shown():
		talk.press_next()  # 文を出しきる（選ばせる行なら、答えの枠も出る）
	return _app.current_id() == SceneFlow.TALK and talk.line_index() == parts[2]


## 話の対戦（いまの _scene）を CPU どうしで進め、人の側が勝つ最後の 1 手を、画面に出して指す。勝てない種なら偽。
func _win_to_last_move() -> bool:
	var setup: MatchSetup = _scene.source.make_setup(_seed)
	_battle = setup.create_battle()
	_stats = BattleStats.new(_battle)
	_log = BattleLog.new(_battle, ["プレイヤー1（青）", "CPU（赤）"] as Array[String])
	_advance(func() -> bool: return false)  # 決着する 1 手の手前で止まる
	var action := _cpu.next_action(_battle)
	if action == null:
		return false
	var trial := _battle.clone()
	trial.apply(action)
	if not trial.is_over() or trial.winner != Unit.Side.PLAYER1:
		return false
	_scene.start_with(_battle, _scene.source.look(), _seed, setup.scenario.title)
	_scene.stats = _stats
	_scene.battle_log = _log
	_scene.hide_notice()
	await _scene.act(action)  # 決着の 1 手（守り切る話なら、敵のターン終了）。受け付けたかは、決着したかで見る
	for i in 1200:
		if _battle.is_over():
			return _battle.winner == Unit.Side.PLAYER1
		await get_tree().process_frame
	return false


## いまの会話の場面を飛ばして、次の場面へ（選ばせる行は 1 つ目の答え）。次も会話の場面なら真。
func _skip_talk_scene() -> bool:
	if _app.current_id() != SceneFlow.TALK:
		return false
	var talk: Node = _app.current_scene()
	for i in 12:
		talk.press_skip()
		if talk.is_asking():
			talk.press_option(0)
			continue
		break
	await _app.scene_changed
	return _app.current_id() == SceneFlow.TALK
