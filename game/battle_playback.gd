extends Node3D
## 対戦のイベントの再生（docs/battle-view.md の「行動と再生」）。対戦の場面（battle_screen.gd）の子に置く。
## ルール（Battle.apply）が返した起きたこと（BattleEvent）の列を、起きた順に、駒の動き・光・文字・音・カメラで見せる。
## ここはルールを持たない。場面が持つもの（駒の見た目、カメラ、帯、演出の起点、盤）を受け取り、それを動かすだけ。
##
## 再生の待ち時間は、この場面の子の Timer で測る（after）。場面を抜けて（タイトルへ戻る）ノードが消えると、
## 待っている再生や CPU の番は続きを走らない（消えた場面に触れない）。

const UnitView := preload("res://game/unit_view.gd")
const BoardView := preload("res://game/board_view.gd")
const BattleHud := preload("res://game/battle_hud.gd")
const OrbitCamera := preload("res://game/orbit_camera.gd")
const BattleEffects := preload("res://game/battle_effects.gd")
const BattleLog := preload("res://game/battle_log.gd")
const BattleUiState := preload("res://game/battle_ui_state.gd")
const NeutralPlayback := preload("res://game/neutral_playback.gd")
const Names := preload("res://game/names.gd")

## 1 マス歩くのにかける秒数（巡航は速く走る）。中立の駒は、目で追えるよう、ゆっくり歩かせる。
const STEP_TIME := 0.16
const CRUISE_STEP_TIME := 0.1
const NEUTRAL_STEP_TIME := 0.26
## 中立のフェーズで、攻撃する駒へカメラを寄せてから動き出すまでの秒数と、その駒の場面が終わってから次までの間。
const NEUTRAL_FOCUS_TIME := 0.5
const NEUTRAL_PAUSE := 0.5
## 必殺技の効果を、全員にまとめて見せる時間（駒の数に依らない）。
const ULT_EFFECTS_TIME := 0.45

const COLOR_BLAST := Color(1.0, 0.55, 0.1, 0.6)
const COLOR_EXPERIENCE := Color("9fd8ff")
const COLOR_LEVEL_UP := Color("ffd34a")
const COLOR_EVOLUTION := Color("d9a6ff")
const COLOR_RELIC := Color("ffe08a")

const WIN_REASONS := {
	GameWonEvent.Reason.KING_DEFEATED: "敵の将を倒した",
	GameWonEvent.Reason.HQ_CAPTURED: "敵の本陣を占拠し続けた",
	GameWonEvent.Reason.TURNS_HELD: "最後まで守り切った",
	GameWonEvent.Reason.ROUTED: "敵を全滅させた",
}

const DRAW_REASONS := {
	GameDrawnEvent.Reason.BOTH_KINGS_DEFEATED: "両方の将が同時に倒れた",
}

# ---- 場面から受け取るもの（setup で入る。対戦ごとに変わるものは、場面が入れ替える） ----

## いまの対戦と、そのログ（再生したイベントを、再生した順に食わせる）と、盤。
var battle: Battle
var battle_log: BattleLog
var _board_view: BoardView
## 駒の番号 -> 駒の見た目（UnitView）。場面と同じ辞書を持つ（倒れた駒は消し、湧いた駒は足す）。
var _views: Dictionary
var _rig: OrbitCamera
var _hud: BattleHud
var _effects: BattleEffects
var _ui: BattleUiState
## 駒・光・文字を置くところ（場面）。
var _stage: Node3D
var team_colors: Array[Color] = []
## 場面に頼むこと: 上の帯を描き直す (turn, phase)、陣営の名前 (side) -> String、
## リザルトの画面に出すもの (draw, winner, reason) -> result_summary.gd、
## side の番にカメラが見る地点 (side) -> Vector3、CPU が動かす陣営 () -> Unit.Side、効果音を鳴らす (name)。
var refresh_status: Callable
var side_name: Callable
var result_summary: Callable
var camera_point: Callable
var cpu_side: Callable
var play_sound: Callable
## 見せずに済ませた（skipping）あとに、盤の見た目（駒・樽・盤の上の効果）を、いまの盤から作り直す () -> void。
var sync_views: Callable
## 毎フレームの終わりに出る signal（場面の frame_passed）。まとめて流す場面の終わりを待つのに使う。
var frame_passed: Signal

# ---- 再生の状態 ----

## 再生したイベントの数（イベントのスクリプト -> 回数）と、カメラが追いかけた駒の番号 -> 回数。検査用（場面と同じ辞書）。
var played := {}
var camera_follows := {}
var _players := event_players()
## 中立のフェーズの静かな場面（動いただけ、湧いただけ）をまとめて流している途中か。この間は、カメラを動かさない。
var _quiet_playback := false
## まとめて流している場面のうち、まだ終わっていないものの数。
var _beats_running := 0
## 最後の行動の終わり（UnitActedEvent）から、攻撃・回復・スキルを見せたか。見せていなければ、次の行動の終わりは待機のサインを出す。
var _acted_with_effect := false
## 必殺技の効果をまとめて見せている途中か。
var _in_ult_effects := false
## いま再生している行動で、スキルを使ったか（使ったなら、続く効果の名前（「盾」「バリア」など）は出さない。
## スキルの名前と、スキルごとの形が見せているので、文字を重ねない）。
var _after_skill := false
## 見せずに済ませる途中か（相手の番のスキップ）。真の間に再生するものは、見せずに数えてログに食わせるだけ（_settle）。
## 決着（GameWonEvent・GameDrawnEvent）だけは、盤の見た目を作り直してから、ふつうに見せる。場面が立て、場面が下ろす。
var skipping := false
## 見せずに済ませたものがあって、盤の見た目をまだ作り直していないか。
var _unsynced := false


## 場面が持つものを受け取る。views・played・follows は場面と同じ辞書を渡す。
func setup(
	stage: Node3D, views: Dictionary, rig: OrbitCamera, hud: BattleHud, effects: BattleEffects, ui: BattleUiState,
	colors: Array[Color], played_counts: Dictionary, follows: Dictionary
) -> void:
	_stage = stage
	_views = views
	_rig = rig
	_hud = hud
	_effects = effects
	_ui = ui
	team_colors = colors
	played = played_counts
	camera_follows = follows


## 新しい対戦の盤を受け取る（場面が対戦を始めるたび）。
func set_board_view(board_view: BoardView) -> void:
	_board_view = board_view


## seconds 秒（Engine.time_scale に従う）たったら出る signal。再生と CPU の番の間を置くのに使う。
## 木の時計（SceneTree.create_timer）ではなく、この子の Timer で測る（場面が消えると、待っている続きは走らない）。
func after(seconds: float) -> Signal:
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = maxf(seconds, 0.001)
	timer.timeout.connect(timer.queue_free)
	add_child(timer)
	timer.start()
	return timer.timeout


## CPU の番を進めている途中で、side が CPU の動かす陣営か（その駒は、自分で動かしていない駒として、カメラが追う）。
func _cpu_moving(side: Unit.Side) -> bool:
	return _ui.cpu_running and side == cpu_side.call()


func _view(unit_id: int) -> UnitView:
	return _views[unit_id]


## イベントの種類（スクリプト）-> 再生するメソッドの名前。
## rules/events/ のイベントは、すべてここに載せる（載っていない種類があると、テストが落ちる）。
static func event_players() -> Dictionary:
	return {
		UnitMovedEvent: &"_play_moved",
		UnitWarpedEvent: &"_play_warped",
		UnitTeleportedEvent: &"_play_teleported",
		UnitsSwappedEvent: &"_play_swapped",
		UnitReactivatedEvent: &"_play_reactivated",
		MoveUndoneEvent: &"_play_undone",
		AttackDamagedEvent: &"_play_attack_damaged",
		ExplosionDamagedEvent: &"_play_explosion_damaged",
		SkillDamagedEvent: &"_play_skill_damaged",
		HealerHealedEvent: &"_play_healer_healed",
		SpringHealedEvent: &"_play_spring_healed",
		RegenerationHealedEvent: &"_play_regeneration_healed",
		ExperienceGainedEvent: &"_play_experience_gained",
		LevelUpEvent: &"_play_level_up",
		EvolutionOfferedEvent: &"_play_evolution_offered",
		UnitEvolvedEvent: &"_play_evolved",
		UnitDefeatedEvent: &"_play_defeated",
		MidBossDefeatedEvent: &"_play_mid_boss_defeated",
		RelicGainedEvent: &"_play_relic_gained",
		UnitSpawnedEvent: &"_play_spawned",
		BarrelExplodedEvent: &"_play_barrel_exploded",
		BarricadePlacedEvent: &"_play_field_effect_placed",
		AreaEffectPlacedEvent: &"_play_field_effect_placed",
		FieldEffectTickedEvent: &"_play_field_effect_ticked",
		FieldEffectRemovedEvent: &"_play_field_effect_removed",
		BarricadeDamagedEvent: &"_play_barricade_damaged",
		SmokeBlockedEvent: &"_play_smoke_blocked",
		SanctuaryHealedEvent: &"_play_sanctuary_healed",
		SkillUsedEvent: &"_play_skill_used",
		SkillReadyEvent: &"_play_skill_ready",
		UltUsedEvent: &"_play_ult_used",
		UltReadyEvent: &"_play_ult_ready",
		StatusAppliedEvent: &"_play_status_applied",
		StatusRemovedEvent: &"_play_status_removed",
		UnitActedEvent: &"_play_acted",
		PhaseStartedEvent: &"_play_phase_started",
		CaptureProgressEvent: &"_play_capture",
		GameWonEvent: &"_play_won",
		GameDrawnEvent: &"_play_drawn",
	}


## 起きたことを、起きた順に再生する。中立のフェーズの中身だけは、見せ方の単位（場面）に分けて再生する。
## quiet_until_warp_from がマスなら、そのポータルから出る転移（UnitWarpedEvent）より前のものは、見せずに済ませる
## （駒は行き着いた位置へすぐ置き、ログには残す）。画面がポータルへ動いたあとの転移を「移動の取り消し + 行き先への移動」として
## ルールに渡すときに使う（戻って歩き直すところは見せない。歩き直す道が別のポータルを通っていても、それも見せない）。
func play_all(events: Array[BattleEvent], quiet_until_warp_from := Vector2i(-1, -1)) -> void:
	_after_skill = false
	var i := 0
	if quiet_until_warp_from != Vector2i(-1, -1):
		while i < events.size() and not (events[i] is UnitWarpedEvent and (events[i] as UnitWarpedEvent).from == quiet_until_warp_from):
			_settle(events[i])
			i += 1
	while i < events.size():
		if skipping:
			await _finish_skipped(events.slice(i))
			return
		var event := events[i]
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


## スキップした: 残り（rest）を見せずに済ませ、盤の見た目を作り直してから、決着だけを見せる。
func _finish_skipped(rest: Array[BattleEvent]) -> void:
	var finals: Array[BattleEvent] = []
	for event in rest:
		if event is GameWonEvent or event is GameDrawnEvent:
			finals.append(event)
		else:
			_settle(event)
	_sync()
	for event in finals:
		await _play(event)


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


func _play(event: BattleEvent) -> void:
	var kind: Script = event.get_script()
	if not _players.has(kind):
		push_error("再生できないイベント: %s" % kind.resource_path)
		return
	played[kind] = played.get(kind, 0) + 1
	battle_log.feed(event)
	await call(_players[kind], event)


## 見せずに済ませる（play_all の quiet_until_warp_from）。数えてログに食わせ、動いた駒は行き着いたマスへすぐ置く。
## そのほかの見た目（状態の印、上の帯）は、再生のあとの作り直しが今の盤から描く。
func _settle(event: BattleEvent) -> void:
	played[event.get_script()] = played.get(event.get_script(), 0) + 1
	battle_log.feed(event)
	if skipping:
		_unsynced = true  # 駒の見た目は、まとめて作り直す
		return
	var moved := event as UnitMovedEvent
	var undone := event as MoveUndoneEvent
	if moved != null and not moved.path.is_empty() and _views.has(moved.unit_id):
		_view(moved.unit_id).position = BoardView.cell_center(moved.path[-1])
	elif undone != null and _views.has(undone.unit_id):
		_view(undone.unit_id).position = BoardView.cell_center(undone.to)


func _play_moved(event: UnitMovedEvent) -> void:
	if event.path.size() < 2:
		return
	var view := _view(event.unit_id)
	var unit := battle.unit_by_id(event.unit_id)
	var step_time := CRUISE_STEP_TIME if event.cruise else STEP_TIME
	if unit != null and unit.side == Unit.Side.NEUTRAL:
		step_time = NEUTRAL_STEP_TIME
	# 自分で動かしていない駒（CPU の駒、中立の駒）は、歩いている間、カメラが追いかける（長く歩いても、画面の外へ出ていかない）。
	var followed := _camera_follows(unit)
	if followed:
		camera_follows[event.unit_id] = camera_follows.get(event.unit_id, 0) + 1
		_rig.follow(view)
	view.play_run()
	for i in range(1, event.path.size()):
		var target := BoardView.cell_center(event.path[i])
		view.face(target - view.position)
		var tween := create_tween()
		tween.tween_property(view, "position", target, step_time)
		await tween.finished
	view.play_idle()
	if followed:
		_rig.follow(null)


func _play_undone(event: MoveUndoneEvent) -> void:
	var view := _view(event.unit_id)
	var tween := create_tween()
	tween.tween_property(view, "position", BoardView.cell_center(event.to), 0.15)
	await tween.finished


## 道順どおりに歩いたあとの、ポータルの転移。入ったポータルで縮んで消え、出たポータルに現れる。
func _play_warped(event: UnitWarpedEvent) -> void:
	var view := _view(event.unit_id)
	var color := BoardView.portal_color(battle.board, event.from)
	var to := BoardView.cell_center(event.to)
	_flash(BoardView.cell_center(event.from), color, 0.9)
	_sound(&"portal")
	var shrink := create_tween()
	shrink.tween_property(view, "scale", Vector3.ONE * 0.05, 0.16)
	await shrink.finished
	view.position = to
	if not _quiet_playback:
		_rig.focus_on(to)  # 行き先が画面の外でも、どこへ出たかが見えるようにする（静かな場面では、カメラを動かさない）。
	_flash(to, color, 0.9)
	var grow := create_tween()
	grow.tween_property(view, "scale", Vector3.ONE, 0.16)
	await grow.finished


## 駒の攻撃。攻撃の動きのあとに被弾。
func _play_attack_damaged(event: AttackDamagedEvent) -> void:
	var target := _view(event.unit_id)
	var attacker := _view(event.attacker_id)
	_show_strike(event.attacker_id, attacker, target)
	attacker.face(target.position - attacker.position)
	target.face(attacker.position - target.position)
	await _strike(attacker, target.position)
	await _play_hit(event, Color("ffe9a8"), 0.45)


## 爆発のダメージ（攻撃した駒がいない）は、被弾だけを続けて見せる。
func _play_explosion_damaged(event: ExplosionDamagedEvent) -> void:
	await _play_hit(event, Color("ffb14a"), 0.15)


## スキルのダメージ（使った駒の動きは SkillUsedEvent が見せた）は、被弾だけを続けて見せる。
func _play_skill_damaged(event: SkillDamagedEvent) -> void:
	await _play_hit(event, Color("ff7a4a"), 0.15)


func _play_hit(event: UnitDamagedEvent, color: Color, wait: float) -> void:
	var target := _view(event.unit_id)
	target.play_hit()
	target.set_hp(event.hp)
	if event.is_blocked():
		_sound(&"blocked")
		_pop_number(target.position, "%s が防いだ" % Names.status(event.blocked_by as Status.Type), Color("9fd8ff"))
	elif event.critical:
		_sound(&"critical")
		_pop_number(target.position, "クリティカル -%d" % event.amount, Color("ff5a4a"))
	else:
		_pop_number(target.position, "-%d" % event.amount, color)
	await after(wait)


## 回復役の回復。回復役が相手のほうを向いて手を振り、相手に光と数を出す。
func _play_healer_healed(event: HealerHealedEvent) -> void:
	var healer := _view(event.healer_id)
	var target := _view(event.unit_id)
	healer.face(target.position - healer.position)
	_acted_with_effect = true
	await after(healer.play_attack())
	await _play_heal(event, true)


## 回復の泉（フェーズの始め）は、光と数を出す。
func _play_spring_healed(event: SpringHealedEvent) -> void:
	await _play_heal(event, true)


## 再生（進化先の特性。フェーズの始め）も、光と数を出す。
func _play_regeneration_healed(event: RegenerationHealedEvent) -> void:
	await _play_heal(event, true)


func _play_heal(event: UnitHealedEvent, glow: bool) -> void:
	var view := _view(event.unit_id)
	view.set_hp(event.hp)
	_sound(&"heal")
	_pop_number(view.position, "+%d" % event.amount, Color("9cf09c"))
	if glow:
		_flash(view.position, BoardView.COLOR_SPRING_CROSS, 0.8)
	await after(0.35)


## 経験値が入った。数を小さく出すだけ（たまった量は左下の駒の情報に出る）。
func _play_experience_gained(event: ExperienceGainedEvent) -> void:
	var view := _view(event.unit_id)
	_pop_number(view.position + Vector3(0.0, 0.35, 0.0), "経験 +%d" % event.amount, COLOR_EXPERIENCE)
	await after(0.2)


## レベルが上がった。札のレベルと HP のバーを描き直し、光と知らせを出す。
func _play_level_up(event: LevelUpEvent) -> void:
	var view := _view(event.unit_id)
	view.set_growth(event.level, event.max_hp)
	view.set_hp(event.hp)
	_flash(view.position + Vector3(0.0, 0.5, 0.0), COLOR_LEVEL_UP, 1.4)
	_sound(&"level_up")
	_pop_number(view.position + Vector3(0.0, 0.6, 0.0), "レベル %d！" % event.level, COLOR_LEVEL_UP)
	await after(0.5)


## 進化先を選べるようになった。光と知らせだけ（選択肢は、再生が終わったあとに _refresh が出す）。
func _play_evolution_offered(event: EvolutionOfferedEvent) -> void:
	var view := _view(event.unit_id)
	_flash(view.position + Vector3(0.0, 0.5, 0.0), COLOR_EVOLUTION, 1.6)
	_pop_number(view.position + Vector3(0.0, 0.6, 0.0), "進化できる！", COLOR_EVOLUTION)
	await after(0.4)


## 進化した。札に印を付け、HP のバーを新しい最大 HP で描き直し、進化先の名前を出す。
func _play_evolved(event: UnitEvolvedEvent) -> void:
	var view := _view(event.unit_id)
	view.set_evolved(event.max_hp)
	view.set_hp(event.hp)
	_flash(view.position + Vector3(0.0, 0.5, 0.0), COLOR_EVOLUTION, 1.8)
	_sound(&"evolved")
	_pop_number(view.position + Vector3(0.0, 0.6, 0.0), Names.evolution(event.evolution), COLOR_EVOLUTION)
	await after(0.6)


## 攻撃の動きのあと、樽を消して、爆発の届いたマスを塗る（続くダメージの再生の間も塗ったまま）。
func _play_barrel_exploded(event: BarrelExplodedEvent) -> void:
	var at := BoardView.cell_center(event.cell)
	if _views.has(event.attacker_id):
		var attacker := _view(event.attacker_id)
		attacker.face(at - attacker.position)
		await _strike(attacker, at)
	_board_view.remove_barrel(event.cell)
	var colors := {event.cell: COLOR_BLAST}
	for cell in event.blast_cells:
		colors[cell] = COLOR_BLAST
	_board_view.show_cells(colors)
	_flash(at + Vector3(0.0, 0.3, 0.0), Color("ff8a2a"), 2.6)
	_sound(&"explosion")
	_pop_number(at, "爆発", Color("ff8a2a"))
	await after(0.3)


## 盤の上に効果が置かれた。描いて、中心に光を出す。
func _play_field_effect_placed(event: FieldEffectPlacedEvent) -> void:
	_board_view.add_field_effect(event.effect_id, event.type, event.side, event.cells)
	var at := BoardView.cell_center(event.center)
	_flash(at + Vector3(0.0, 0.3, 0.0), team_colors[event.side], 1.2 if event.type == FieldEffect.Type.BARRICADE else 2.4)
	if not _after_skill:
		_pop_number(at, Names.field_effect(event.type), team_colors[event.side].lightened(0.4))
	await after(0.3)


## 煙幕・聖域の残りが減った。描き方は変えない（残りはマスの説明に出る）。
func _play_field_effect_ticked(_event: FieldEffectTickedEvent) -> void:
	pass


## 盤の上の効果が消えた（期間が尽きた・盾が壊れた）。
func _play_field_effect_removed(event: FieldEffectRemovedEvent) -> void:
	_board_view.remove_field_effect(event.effect_id)
	if event.reason == FieldEffectRemovedEvent.Reason.DESTROYED:
		var at := BoardView.cell_center(event.cells[0])
		_flash(at + Vector3(0.0, 0.3, 0.0), Color("d8d0c0"), 1.4)
		_pop_number(at, "盾が壊れた", Color("d8d0c0"))
		await after(0.3)


## 盾を攻撃した。攻撃の動きのあと、減った耐久を出す。
func _play_barricade_damaged(event: BarricadeDamagedEvent) -> void:
	var at := BoardView.cell_center(event.cell)
	var attacker := _view(event.attacker_id)
	attacker.face(at - attacker.position)
	await _strike(attacker, at)
	_pop_number(at, "耐久 -%d" % event.amount, Color("ffe9a8"))
	await after(0.3)


## 攻撃が煙幕に阻まれた。攻撃の動きのあと、相手に灰色の光と「防いだ」を出す（HP は変わらない）。
func _play_smoke_blocked(event: SmokeBlockedEvent) -> void:
	var target := _view(event.target_id)
	var attacker := _view(event.attacker_id)
	_show_strike(event.attacker_id, attacker, target)
	attacker.face(target.position - attacker.position)
	target.face(attacker.position - target.position)
	await _strike(attacker, target.position)
	_flash(target.position + Vector3(0.0, 0.3, 0.0), BoardView.COLOR_SMOKE, 1.2)
	_pop_number(target.position, "煙幕で防いだ", Color("d0d4da"))
	await after(0.4)


## スキルで跳んだ（シャドウステップ）。その場で縮んで消え、着いたマスに現れる。
func _play_teleported(event: UnitTeleportedEvent) -> void:
	await _blink([[_view(event.unit_id), event.to]])


## 2 体の位置が入れ替わった（シャドウステップ）。2 体とも同時に消えて、互いのマスに現れる。
func _play_swapped(event: UnitsSwappedEvent) -> void:
	await _blink([[_view(event.unit_id), event.other_from], [_view(event.other_id), event.from]])


## 駒を、間を通さずに別のマスへ移す。moves は [駒の見た目, 行き先のマス] の列（同時に移す）。
func _blink(moves: Array[Array]) -> void:
	var color := Color("b98cff")
	var shrink := create_tween().set_parallel()
	for move in moves:
		var view: UnitView = move[0]
		_flash(view.position, color, 0.9)
		shrink.tween_property(view, "scale", Vector3.ONE * 0.05, 0.14)
	await shrink.finished
	var grow := create_tween().set_parallel()
	for move in moves:
		var view: UnitView = move[0]
		view.position = BoardView.cell_center(move[1])
		_flash(view.position, color, 0.9)
		grow.tween_property(view, "scale", Vector3.ONE, 0.14)
	_rig.focus_on((moves[0][0] as UnitView).position)
	await grow.finished


## 行動済みの駒が、行動前に戻った（アドレナリン注射）。行動済みの見た目を戻し、光と知らせを出す。
func _play_reactivated(event: UnitReactivatedEvent) -> void:
	var view := _view(event.unit_id)
	view.set_acted(false)
	_flash(view.position, Color("ffd24a"), 0.9)
	_pop_number(view.position + Vector3(0.0, 0.3, 0.0), "もう一度行動できる", Color("ffd24a"))
	await after(0.25)


## 聖域（フェーズの始め）も、光と数を出す。
func _play_sanctuary_healed(event: SanctuaryHealedEvent) -> void:
	await _play_heal(event, true)


## スキルを使った。対象のほうを向いて手を振り、スキルの名前をスキルの色で出す。足元にスキルの色の輪が広がり、
## スキルごとの形が対象に届く（battle_effects.gd の skill_flash）。届いてから、続くイベントが効果を見せる。
func _play_skill_used(event: SkillUsedEvent) -> void:
	var view := _view(event.unit_id)
	var at := BoardView.cell_center(event.target)
	if not at.is_equal_approx(view.position):
		view.face(at - view.position)
	_acted_with_effect = true
	_after_skill = true
	var color: Color = BattleEffects.SKILL_COLORS[event.skill]
	_pop_number(view.position + Vector3(0.0, 0.5, 0.0), Names.skill(Skills.by_id(event.skill)), color.lightened(0.45))
	_effects.skill_flash(event.skill, view.position, at)
	await after(maxf(view.play_attack(), BattleEffects.SKILL_TIME))


## スキルをまた使えるようになった。魔力解放のときだけ、駒の上に知らせる（クールダウンが明けただけのときは何も出さない。
## 残りは駒の情報とスキルのボタンに出る）。
func _play_skill_ready(event: SkillReadyEvent) -> void:
	if _in_ult_effects and _views.has(event.unit_id):
		_pop_number(_view(event.unit_id).position, "スキル使用可", BattleEffects.SKILL_COLORS[event.skill].lightened(0.45))


## 必殺技を使った。画面が必殺技の色に一瞬光り、必殺技の名前を大きく出す。
## 効果（駒ごとの状態など）は、続くイベントを _play_all がまとめて同時に見せる（_play_ult_effects）。
func _play_ult_used(event: UltUsedEvent) -> void:
	refresh_status.call(battle.turn, battle.phase)
	var color: Color = BattleHud.ULT_COLORS[event.ult]
	_hud.flash_screen(color)
	_sound(&"ult")  # 音の山が、続く光の柱（_play_ult_effects）に重なる
	_hud.show_banner("%s　必殺技: %s!!" % [side_name.call(event.side), Names.ult(Ults.by_id(event.ult))], color)
	await after(0.5)


## 必殺技の効果（必殺技のすぐあとに続く、状態が付いた・スキルが使えるようになった）を、駒ごとに順にではなく、全員に同時に見せる。
## 効果の掛かった駒に陣営の色の光の柱が立ち、それぞれの知らせが一度に出る。待つのは 1 回だけ。
func _play_ult_effects(side: Unit.Side, effects: Array[BattleEvent]) -> void:
	var points: Array[Vector3] = []
	_in_ult_effects = true
	for event in effects:
		var unit_id: int = event.get(&"unit_id")
		if _views.has(unit_id):
			points.append(_view(unit_id).position)
		_play(event)  # 待たずに始めて、同時に流す
	_in_ult_effects = false
	_effects.ult_burst(points, team_colors[side])
	await after(ULT_EFFECTS_TIME)


## 必殺技のゲージがいっぱいになった。上の帯のゲージを「READY」にする（ボタンは、自分の番に押せるようになる）。
func _play_ult_ready(_event: UltReadyEvent) -> void:
	refresh_status.call(battle.turn, battle.phase)
	_sound(&"ult_ready")


## 駒に状態が付いた。状態の名前を出す（付いている状態は、駒の情報に出る）。
func _play_status_applied(event: StatusAppliedEvent) -> void:
	if _after_skill and event.status != Status.Type.FATIGUE:
		return  # スキルの名前と形が見せている（反動は、スキルの形では分からないので出す）
	_pop_number(_view(event.unit_id).position, Names.status(event.status), Color("9fd8ff"))
	await after(0.25)


## 駒の状態が外れた。使い切ったときは、ダメージや攻撃の再生が見せているので、ここでは何も出さない。
func _play_status_removed(event: StatusRemovedEvent) -> void:
	if event.reason == StatusRemovedEvent.Reason.CONSUMED:
		return
	var why := "が解けた" if event.reason == StatusRemovedEvent.Reason.MOVED else "が消えた"
	_pop_number(_view(event.unit_id).position, Names.status(event.status) + why, Color("b8c4d0"))
	await after(0.2)


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
	_hud.show_result(result_summary.call(false, event.winner, WIN_REASONS[event.reason]))


func _play_drawn(event: GameDrawnEvent) -> void:
	await after(0.4)
	_hud.show_result(result_summary.call(true, Unit.Side.NEUTRAL, DRAW_REASONS[event.reason]))


func _play_defeated(event: UnitDefeatedEvent) -> void:
	var view := _view(event.unit_id)
	_views.erase(event.unit_id)
	_sound(&"defeated")
	await view.play_death()


## 中ボスが倒れた（駒が消えるのは UnitDefeatedEvent が見せた）。倒した陣営を、その色で知らせる。
func _play_mid_boss_defeated(event: MidBossDefeatedEvent) -> void:
	var at := BoardView.cell_center(event.cell)
	var side := BattleLog.mid_boss_place(battle.board, event.boss_index)
	if event.slayer_side < 0:
		_pop_number(at, "%sの中ボスが倒れた" % side)
		return
	var color: Color = team_colors[event.slayer_side]
	_flash(at + Vector3(0.0, 0.6, 0.0), color, 2.4)
	_pop_number(at, "%s が%sの中ボスを倒した" % [side_name.call(event.slayer_side as Unit.Side), side], color.lightened(0.4))
	await after(0.6)


## 陣営が聖遺物を受け取った。控えめに見せる: 上の帯に聖遺物の名前を出し、効果の掛かった駒の HP のバーを描き直し、
## 駒の上に小さい光と、効果（最大 HP +N など）を出す。画面を覆う演出はしない。
func _play_relic_gained(event: RelicGainedEvent) -> void:
	refresh_status.call(battle.turn, battle.phase)
	var color: Color = team_colors[event.side]
	var text := Names.relic_summary(event.relic).trim_prefix("軍の全員の")
	_sound(&"relic")
	for unit_id in event.unit_ids:
		if not _views.has(unit_id):
			continue
		var view := _view(unit_id)
		view.set_max_hp(event.max_hp[unit_id])
		view.set_hp(event.hp[unit_id])
		_flash(view.position + Vector3(0.0, 0.5, 0.0), COLOR_RELIC, 1.0)
		_pop_number(view.position + Vector3(0.0, 0.5, 0.0), text, COLOR_RELIC)
	_hud.show_banner("%s　%s を手に入れた（%s）" % [side_name.call(event.side), Names.relic(event.relic), Names.relic_summary(event.relic)], color)
	await after(0.7)


## 中立の駒が結晶泉に湧いた（中ボスが現れた）。光とともに、小さい形から大きくする。
func _play_spawned(event: UnitSpawnedEvent) -> void:
	var at := BoardView.cell_center(event.cell)
	var view: UnitView = UnitView.new()
	view.position = at
	_stage.add_child(view)
	view.setup(event.kind, team_colors[event.side], event.hp, event.max_hp)
	view.face(BoardView.cell_center(event.cell + Vector2i.DOWN) - at)
	_views[event.unit_id] = view
	if not _quiet_playback:
		_rig.focus_on(at)
	_flash(at + Vector3(0.0, 0.4, 0.0), team_colors[event.side], 1.6)
	if event.kind == Neutral.MID_BOSS_KIND:
		_sound(&"boss_roar")
	view.scale = Vector3.ONE * 0.05
	var grow := create_tween()
	grow.tween_property(view, "scale", Vector3.ONE, 0.3)
	await grow.finished


## 駒が歩く間、カメラが追いかけるか。自分で動かしていない駒（CPU の番の駒、中立の駒）だけ。
## 中立のフェーズの静かな場面をまとめて流している間は、追わない（何体も同時に動く）。
func _camera_follows(unit: Unit) -> bool:
	if unit == null or _quiet_playback:
		return false
	return unit.side == Unit.Side.NEUTRAL or _cpu_moving(unit.side)


## 攻撃の動きと、当たる形（駒の種類ごと。battle_effects.gd）を出し、当たる瞬間まで待つ。
func _strike(attacker: UnitView, at: Vector3) -> void:
	_acted_with_effect = true
	var hit_in := attacker.play_attack()
	_effects.strike(BattleEffects.hit_style(attacker.unit_kind()), attacker.position, at, hit_in)
	await after(hit_in)


## 自分で動かしていない駒（CPU の番の駒、中立の駒）の攻撃は、攻撃する駒と相手の間へカメラを寄せる（どちらも見えるように）。
func _show_strike(attacker_id: int, attacker: UnitView, target: UnitView) -> void:
	var unit := battle.unit_by_id(attacker_id)
	if unit != null and (unit.side == Unit.Side.NEUTRAL or _cpu_moving(unit.side)):
		_rig.focus_on((attacker.position + target.position) / 2.0)


func _play_phase_started(event: PhaseStartedEvent) -> void:
	refresh_status.call(event.turn, event.side)
	_acted_with_effect = false
	if event.side == Unit.Side.NEUTRAL:
		# 中立の駒は行動済みを持たないので、明るさは変えない。カメラは、攻撃する駒だけを追う（_play_neutral_phase）。
		_hud.show_banner("ターン %d　%s の番" % [event.turn, side_name.call(event.side)], team_colors[event.side])
		await after(0.5)
		return
	for unit in battle.units:
		if unit.side == event.side:
			_view(unit.id).set_acted(false)
	_sound(&"phase")
	_hud.show_banner("ターン %d　%s の番" % [event.turn, side_name.call(event.side)], team_colors[event.side])
	_rig.focus_on(camera_point.call(event.side))
	await after(0.5)


func _play_capture(event: CaptureProgressEvent) -> void:
	refresh_status.call(battle.turn, battle.phase)
	var hq := battle.board.hq_cells[1 - event.player]
	var text := "占拠 %d / %d" % [event.turns, Battle.CAPTURE_TURNS_TO_WIN] if event.turns > 0 else "占拠が途切れた"
	if event.turns > 0:
		_sound(&"capture")
	_pop_number(BoardView.cell_center(hq), text, team_colors[event.player].lightened(0.4))


## 対戦の中の効果音（sound_catalog.gd の名前。docs/sound.md の「対戦の音」）。演出に合わせて鳴らすだけで、待ち時間は変えない。
func _sound(name: StringName) -> void:
	play_sound.call(name)


## 広がって消える光の球（爆発、転移、泉の回復）。size は広がりきったときの直径。
func _flash(at: Vector3, color: Color, size: float) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color, 0.7)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var ball := MeshInstance3D.new()
	ball.mesh = SphereMesh.new()
	ball.material_override = material
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ball.position = at
	ball.scale = Vector3.ONE * size * 0.2
	_stage.add_child(ball)
	var tween := create_tween()
	tween.tween_property(ball, "scale", Vector3.ONE * size, 0.35).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(material, "albedo_color:a", 0.0, 0.35)
	tween.tween_callback(ball.queue_free)


## 浮かぶ文字の出始めの高さ（足元から）と、消えるまでに昇る高さ・時間。
const POP_HEIGHT := 1.5
const POP_RISE := 0.9
const POP_TIME := 0.8
const POP_FONT_SIZE := 64
const POP_PIXEL_SIZE := 0.008
## 浮かぶ文字どうしの、画面の上での行の間隔（文字の高さに対する割合。縁取りのぶんを足す）。
const POP_LINE_SPACING := 1.3
## いま浮かんでいる文字。
var _pops: Array[Label3D] = []


## 盤面の上に、浮かんで消える文字を出す（ダメージの数など）。まだ浮かんでいる文字と画面の上で重なるなら、その下から出す
## （スキルの名前と効果の知らせのように、近い駒に続けて出しても重ならない）。
func _pop_number(at: Vector3, text: String, color := Color("ffe9a8")) -> void:
	var label := Label3D.new()
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = POP_PIXEL_SIZE
	label.font_size = POP_FONT_SIZE
	label.outline_size = 16
	label.modulate = color
	label.render_priority = 5
	label.outline_render_priority = 4
	var still: Array[Label3D] = []
	var live: Array = []
	for other: Variant in _pops:
		if is_instance_valid(other):  # 消えた文字は、配列に残っていても参照が切れている
			still.append(other)
			live.append([(other as Label3D).position, (other as Label3D).text.length()])
	_pops = still
	var camera := _rig.camera if _rig != null else null
	label.position = Vector3(at.x, at.y + POP_HEIGHT, at.z)
	if camera != null and camera.is_inside_tree():
		label.position = pop_start_position(label.position, text.length(), live, camera.unproject_position, camera.global_basis.y)
	_stage.add_child(label)
	_pops.append(label)
	var tween := create_tween()
	tween.tween_property(label, "position:y", label.position.y + POP_RISE, POP_TIME)
	tween.parallel().tween_property(label, "modulate:a", 0.0, POP_TIME).set_ease(Tween.EASE_IN)
	tween.tween_callback(label.queue_free)


## start に出したい length 文字の浮かぶ文字の、重ならない位置（start か、そこから画面の下へずらしたところ）。
## live は、いま浮かんでいる文字の [位置, 文字数] の列。project は盤の上の点を画面の点にする（カメラの unproject_position）。
## up はカメラの上の向き（浮かぶ文字は、いつもカメラへ向くので、文字の縦はこの向き。真上から見下ろしても、画面の縦と合う）。
## 画面の上で横に重なり、縦にも行の間隔より近い文字があれば、その 1 行下まで up の逆へずらす（下げるだけなので、必ず止まる）。
## 文字の幅は、1 文字を文字の高さと同じとみなす（全角の目安）。
static func pop_start_position(start: Vector3, length: int, live: Array, project: Callable, up: Vector3) -> Vector3:
	var glyph := POP_FONT_SIZE * POP_PIXEL_SIZE
	var at := start
	for attempt in live.size() + 1:
		var screen: Vector2 = project.call(at)
		var line: float = ((project.call(at + up * glyph) as Vector2) - screen).length()
		if line <= 0.0:
			return at
		var lowest := screen.y
		for entry: Array in live:
			var other: Vector2 = project.call(entry[0])
			var half_widths := (length + int(entry[1])) * line / 2.0
			if absf(other.x - screen.x) < half_widths and absf(other.y - screen.y) < line * POP_LINE_SPACING:
				lowest = maxf(lowest, other.y + line * POP_LINE_SPACING)  # 画面の y は下へ増える
		if lowest <= screen.y:
			return at
		at -= up * ((lowest - screen.y) / line * glyph)
	return at
