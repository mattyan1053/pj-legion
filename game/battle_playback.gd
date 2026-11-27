extends "res://game/battle_playback/playback_skills.gd"
## 対戦のイベントの再生（docs/battle-view.md の「行動と再生」）。対戦の場面（battle_screen.gd）の子に置く。
## ルール（Battle.apply）が返した起きたこと（BattleEvent）の列を、起きた順に、駒の動き・光・文字・音・カメラで見せる。
## ここはルールを持たない。場面が持つもの（駒の見た目、カメラ、帯、演出の起点、盤）を受け取り、それを動かすだけ。
##
## 再生の待ち時間は、この場面の子の Timer で測る（after）。場面を抜けて（タイトルへ戻る）ノードが消えると、
## 待っている再生や CPU の番は続きを走らない（消えた場面に触れない）。
##
## ここは、列を順に再生する流れ（play_all、飛ばす、中立のフェーズ）と、番・行動済み・決着のイベントだけ。
## イベントの種類ごとのファイル（game/battle_playback/playback_*.gd）: 駒（playback_units）、盤（playback_board）、スキルと必殺技・軍略・状態（playback_skills）。
## 読み込み・調整値・受け取るものと状態、イベントと再生するメソッドの表（event_players）、見せる道具は playback_base。
## ファイルは playback_base.gd からこの順に継いで積み重なり、このファイルが最後（前のファイルは、後のファイルの関数を呼べない）。
## イベントの種類を足すときは、event_players に載せ、_play_<名前> をその種類のファイルに書く。


## 起きたことを、起きた順に再生する。中立のフェーズの中身だけは、見せ方の単位（場面）に分けて再生する。
func play_all(events: Array[BattleEvent]) -> void:
	_after_skill = false
	var i := 0
	while i < events.size():
		if skipping:
			await _finish_skipped(events.slice(i))
			return
		var event := events[i]
		var started_here := event as PhaseStartedEvent
		if started_here != null and started_here.side == Unit.Side.NEUTRAL and not NeutralPlayback.phase_has_neutrals(events, i, _neutral_ids()):
			# 中立の駒のいない番: 知らせも上の帯も出さずに飛ばす（ログと数は、ほかと同じに数える）。
			_settle(event)
			i += 1
			continue
		await _play(event)
		i += 1
		var ult := event as UltUsedEvent
		if ult != null:
			var effects: Array[BattleEvent] = []
			while i < events.size() and (events[i] is StatusAppliedEvent or events[i] is SkillReadyEvent):
				effects.append(events[i])
				i += 1
			await _play_ult_effects(ult.side, effects)
			continue
		var started := event as PhaseStartedEvent
		if started == null or started.side != Unit.Side.NEUTRAL:
			continue
		# 中立のフェーズの中身は、次のフェーズの始まり（か決着）の手前まで。
		var phase: Array[BattleEvent] = []
		while i < events.size() and not (events[i] is PhaseStartedEvent or events[i] is GameWonEvent or events[i] is GameDrawnEvent):
			phase.append(events[i])
			i += 1
		await _play_neutral_phase(phase)
	if _unsynced:
		_sync()
	_show_status_marks()


## 状態の付いている駒の足元の輪を、再生の盤に合わせる（状態の名前は、付いた・外れたときに浮かぶ文字で見せた）。
func _show_status_marks() -> void:
	for unit_id: int in _views:
		var piece := replay.piece(unit_id)
		if piece != null:
			_view(unit_id).set_status_mark(not piece.statuses.is_empty())


## スキップした: 残り（rest）を見せずに済ませ、盤の見た目を作り直してから、決着だけを見せる。
func _finish_skipped(rest: Array[BattleEvent]) -> void:
	var finals: Array[BattleEvent] = []
	for event in rest:
		if event is GameWonEvent or event is GameDrawnEvent:
			finals.append(event)
		else:
			_settle(event)
	_sync()
	_show_status_marks()
	for event in finals:
		await _play(event)


## いま（再生の盤で）盤にいる中立の駒の番号。
func _neutral_ids() -> Array[int]:
	return replay.ids_of(Unit.Side.NEUTRAL)


func _sync() -> void:
	_unsynced = false
	if sync_views.is_valid():
		sync_views.call()


## 中立のフェーズを、目で追える形で再生する（neutral_playback.gd）。
## - 動いただけ・湧いただけの駒（静かな場面）は、カメラを動かさずに、続いているものをまとめて同時に流す。
## - 攻撃した駒（見せる場面）は、カメラを寄せてから、1 体ずつ、ゆっくり歩かせて追いかけ、攻撃を見せて、間を置く。
## 起きた順は変えない。
func _play_neutral_phase(events: Array[BattleEvent]) -> void:
	var shown := {}  # 見せた（見せ始めた）イベント
	for group: Array in NeutralPlayback.groups(NeutralPlayback.beats(events)):
		if skipping:
			# 残りは見せずに済ませる（起きた順に）。盤の見た目は、play_all の終わりで作り直す。
			for event in events:
				if not shown.has(event):
					_settle(event)
			return
		for beat: NeutralPlayback.Beat in group:
			for event in beat.events:
				shown[event] = true
		var first: NeutralPlayback.Beat = group[0]
		if first.quiet:
			_quiet_playback = true
			for beat: NeutralPlayback.Beat in group:
				_beats_running += 1
				_play_beat(beat)  # 待たずに始めて、同時に流す
			while _beats_running > 0:
				await frame_passed
			_quiet_playback = false
			continue
		if _views.has(first.actor_id):
			_rig.focus_on(_view(first.actor_id).position)
			await after(NEUTRAL_FOCUS_TIME)
		for event in first.events:
			await _play(event)
		await after(NEUTRAL_PAUSE)


func _play_beat(beat: NeutralPlayback.Beat) -> void:
	for event in beat.events:
		await _play(event)
	_beats_running -= 1


## 駒が行動を終えた。暗くする。攻撃・回復・スキルを見せずに終えた（待機した）なら、その瞬間に待機のサインを出す
## （動いてから待機、巡航のあと、動いたままターンを終えたときも）。
func _play_acted(event: UnitActedEvent) -> void:
	var view := _view(event.unit_id)
	view.set_acted(true)
	if not _acted_with_effect:
		_effects.wait_sign(view.position)
	_acted_with_effect = false


func _play_won(event: GameWonEvent) -> void:
	await after(0.4)
	_hud.show_result(result_summary.call(false, event.winner, Text.t(BattleLog.WIN_TEXTS[event.reason]), event.reason))


func _play_drawn(event: GameDrawnEvent) -> void:
	await after(0.4)
	_hud.show_result(result_summary.call(true, Unit.Side.NEUTRAL, Text.t(BattleLog.DRAW_TEXTS[event.reason]), -1))


func _play_phase_started(event: PhaseStartedEvent) -> void:
	refresh_status.call(event.turn, event.side)
	_acted_with_effect = false
	if event.side == Unit.Side.NEUTRAL:
		# 中立の駒は行動済みを持たないので、明るさは変えない。カメラは、攻撃する駒だけを追う（_play_neutral_phase）。
		played[NEUTRAL_PHASE_SHOWN] = played.get(NEUTRAL_PHASE_SHOWN, 0) + 1
		_hud.show_banner(Text.t("battle.banner.phase", {"turn": event.turn, "side": side_name.call(event.side)}), team_colors[event.side])
		await after(0.5)
		return
	for unit_id in replay.ids_of(event.side):
		if _views.has(unit_id):
			_view(unit_id).set_acted(false)
	_sound(&"phase")
	_hud.show_banner(Text.t("battle.banner.phase", {"turn": event.turn, "side": side_name.call(event.side)}), team_colors[event.side])
	_rig.focus_on(camera_point.call(event.side))
	await after(0.5)
