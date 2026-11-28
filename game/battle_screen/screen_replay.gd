extends "res://game/battle_screen/screen_overlays.gd"
## 対戦の場面のリプレイ（docs/battle-view.md の「リプレイ」）: 決着の画面の「もう一度見る」で、いま終えた 1 局を頭から見せる。
## 対戦の記録（battle_record.gd。始めの写しと、受け付けられた行動の列）を、見えない対戦（battle を差し替える）へ 1 つずつ当て直し、
## 出た出来事をふだんの道（_do。再生・ログ・戦績・上の帯）で見せる。CPU は考えない（記録した行動を流すだけ）。途中の台詞と「対戦ルール」は出さない。
## ターンの頭へ飛ぶときは、記録を頭からそこまで見せずに当て直し、盤を作り直す。終わり（か「リザルトへ」）で、終えた対戦とリザルトの画面へ戻す。


## リプレイの帯を出してから、次の行動を見せるまでの間（秒）。番の知らせと盤を、先に見せる。
const REPLAY_OPEN_TIME := 0.6

## 終えた対戦（リプレイのあと戻す）: [battle, stats, battle_log]。リプレイの間だけ持つ。
var _ended := []
## 出していたリザルトの中身（result_summary.gd）。戻すときに、演出を飛ばして出し直す。
var _ended_summary: RefCounted
## 次に見せる行動の番号（頭から数えて、当て直した行動の数）。
var _replay_index := 0
var _replay_paused := false
## 飛ぶ先（行動の数）。行動を見せている途中に押されたら、その行動を見せずに済ませてから飛ぶ。無ければ -1。
var _replay_target := -1


func _unhandled_input(event: InputEvent) -> void:
	if _replaying and not context.overlays.is_open() and event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_SPACE:
		toggle_replay_pause()
		return
	super(event)


## 「もう一度見る」を押せるか: 記録を取った対戦が決着して、リザルトの画面が出ているとき。
func can_replay() -> bool:
	return _record != null and battle != null and battle.is_over() and not _replaying and not _ui.busy \
		and _hud.result_screen().shown_summary() != null


## リプレイを見せているか。検査用。
func is_replaying() -> bool:
	return _replaying


## リプレイを始める（決着の画面の「もう一度見る」）。
func start_replay() -> void:
	if not can_replay():
		return
	_ended = [battle, stats, battle_log]
	_ended_summary = _hud.result_screen().shown_summary()
	_hud.result_screen().hide_result()
	_replaying = true
	_replay_paused = false
	_playback.announce_result = false
	_hud.show_replay_bar(true)
	_seek(0)
	_replay_loop()


## リプレイの帯の「止める」「再生」（Space）。止めると、いま見せている行動を見せ終えたところで止まる。
func toggle_replay_pause() -> void:
	if not _replaying:
		return
	_replay_paused = not _replay_paused
	_show_replay_state()


## リプレイの速さ（1・2・4 倍）。
func set_replay_speed(speed: int) -> void:
	_replay_speed = speed
	_update_time_scale()
	_show_replay_state()


## 前のターン（step = -1）・次のターン（step = 1）の頭へ飛ぶ。始めのターンで前へ飛ぶと、始めのターンの頭へ戻る。
## 記録に無いターン（決着より先）へは飛ばない。
func replay_turn(step: int) -> void:
	var target := _turn_target(step)
	if not _replaying or target < 0:
		return
	if _ui.busy:
		_replay_target = target  # いまの行動を見せずに済ませてから飛ぶ（_replay_loop）
		_playback.skipping = true
	else:
		_seek(target)
		_replay_loop()


## step の向きに飛ぶ先（行動の数）。飛べなければ -1。
func _turn_target(step: int) -> int:
	var at := _replay_index if _replay_target < 0 else _replay_target
	var turn: int = _record.turn_at(at)
	if step > 0:
		return _record.head_of(turn + 1)
	if turn > _record.turn_at(0):
		return _record.head_of(turn - 1)
	return 0 if at > 0 else -1


## リプレイをやめて、終えた対戦とリザルトの画面へ戻る（リプレイの帯の「リザルトへ」、終わりまで見せたとき）。
func stop_replay() -> void:
	if not _replaying:
		return
	_stop_replay_state()
	battle = _ended[0]
	stats = _ended[1]
	battle_log = _ended[2]
	_ended = []
	_ui.busy = false
	_ui.clear_for_new_battle()
	_build_stage()
	_show_opponent()
	_refresh()
	if _ended_summary != null:
		_hud.result_screen().present(_ended_summary)
		_hud.result_screen().skip()
	_ended_summary = null


## 頭から count 個の行動を当て直した対戦に差し替え、盤・上の帯・ログ・戦績を作り直す（見せずに）。
func _seek(count: int) -> void:
	_replay_serial += 1
	_replay_target = -1
	_playback.skipping = false
	var names: Array[String] = []
	for side: Unit.Side in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
		names.append(_side_name(side))
	var fresh: Battle = _record.battle_at(0)
	var new_stats := BattleStats.new(fresh)
	var new_log := BattleLog.new(fresh, names)
	_phase_focus.clear()
	for i in count:
		var result: ActionResult = fresh.apply(_record.actions[i])
		new_stats.feed_all(result.events)
		new_log.feed_all(result.events)
		_phase_focus.feed(fresh, result.events)
	battle = fresh
	stats = new_stats
	battle_log = new_log
	_replay_index = count
	_ui.clear_for_new_battle()
	_build_stage()
	_refresh()
	_rig.focus_on(_camera_point(battle.phase))
	_hud.show_banner(Text.t("battle.banner.phase", {"turn": battle.turn, "side": _side_name(battle.phase)}), TEAM_COLORS[battle.phase])
	_update_time_scale()
	_show_replay_state()


## 記録した行動を 1 つずつ見せる。止めている間と、時間を止める画面（メニュー・ログ）を開いている間は待つ。
## 飛んだら（_seek）、古い続きは止まり、新しい続きが走る。終わりまで見せたら、少し置いてリザルトへ戻す。
func _replay_loop() -> void:
	var serial := _replay_serial
	await _playback.after(REPLAY_OPEN_TIME)
	while _replaying and serial == _replay_serial and is_inside_tree():
		if _replay_paused or context.overlays.pauses():
			await get_tree().process_frame
			continue
		if _replay_index >= _record.size():
			await _playback.after(CPU_PAUSE)
			if serial == _replay_serial and not _replay_paused:
				stop_replay()
			return
		var action: BattleAction = _record.actions[_replay_index]
		var unit: Unit = battle.unit_by_id(action.get(&"unit_id")) if &"unit_id" in action else null
		var idle := action is WaitAction and unit != null and not unit.has_moved
		if unit != null and not unit.has_moved and not idle and not action is EvolveAction:
			_rig.focus_on(_view(unit.id).position)
			await _playback.after(CPU_FOCUS_TIME)
			if serial != _replay_serial:
				return
		_replay_index += 1
		_show_replay_state()
		await _do(action)
		if serial != _replay_serial or not _replaying:
			return
		if _replay_target >= 0:
			_seek(_replay_target)  # 見せている途中に飛ぶと決めた
			serial = _replay_serial
			await _playback.after(REPLAY_OPEN_TIME)
			continue
		if not (action is MoveAction or action is EndPhaseAction or idle or battle.is_over()):
			await _playback.after(CPU_PAUSE)


func _show_replay_state() -> void:
	if not _replaying:
		return
	_hud.replay_bar().show_state(_replay_paused, _replay_speed, _turn_target(-1) >= 0, _turn_target(1) >= 0)


## リプレイで、次に見せる行動の番号（当て直した行動の数）と、記録の行動の数。検査用。
func replay_position() -> Array[int]:
	return [_replay_index, _record.size() if _record != null else 0]


## いまの対戦の記録（battle_record.gd。取っていなければ null）。検査用。
func battle_record() -> RefCounted:
	return _record


## リプレイの帯: [出ているか, 止める・再生の文字, 前のターンへ飛べるか, 次のターンへ飛べるか, 選んでいる速さ, ターン終了のボタンが出ているか]。検査用。
func replay_controls() -> Array:
	var bar := _hud.replay_bar()
	var turns := bar.turn_buttons()
	return [_hud.replay_bar_shown(), bar.pause_text(), turns[0], turns[1], bar.chosen_speed(), _hud.end_turn_shown()]


## 記録を、始めの対戦 start と行動の列 actions に差し替える（スクリーンショットの道具用。決着のあとに「もう一度見る」の元を渡す）。
func use_record(start: Battle, actions: Array[BattleAction]) -> void:
	_record = BattleRecord.of(start)
	for action in actions:
		_record.add(action)
