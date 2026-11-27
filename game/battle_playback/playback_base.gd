extends Node3D
## イベントの再生（game/battle_playback.gd）の土台: 読み込み、調整値、場面から受け取るものと再生の状態、イベントの種類と再生するメソッドの表、1 つを再生する・見せずに済ませる入口、見せる道具（光・数字・音・待ち）。
## イベントの種類ごとのファイル（playback_*.gd）は、これを継いで順に積み重なる（battle_playback.gd が最後）。


const Text := preload("res://game/text.gd")
const UnitView := preload("res://game/unit_view.gd")
const BoardView := preload("res://game/board_view.gd")
const BattleHud := preload("res://game/battle_hud.gd")
const OrbitCamera := preload("res://game/orbit_camera.gd")
const BattleEffects := preload("res://game/battle_effects.gd")
const BattleLog := preload("res://game/battle_log.gd")
const BattleUiState := preload("res://game/battle_ui_state.gd")
const NeutralPlayback := preload("res://game/neutral_playback.gd")
const Names := preload("res://game/names.gd")
const Palette := preload("res://game/ui_palette.gd")
const ReplayBoard := preload("res://game/replay_board.gd")


## 1 マス歩くのにかける秒数（巡航は速く走る）。中立の駒は、目で追えるよう、ゆっくり歩かせる。
const STEP_TIME := 0.16
const CRUISE_STEP_TIME := 0.1
const NEUTRAL_STEP_TIME := 0.26
## 曲がり角で向きを替える秒数（1 マスの秒数より長くはしない）。
const TURN_TIME := 0.08
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


# ---- 場面から受け取るもの（setup で入る。対戦ごとに変わるものは、場面が入れ替える） ----


## 再生の盤（replay_board.gd）: 再生が見せている盤のいま。再生は対戦（Battle）を読まず、駒の陣営・種類、盤の形、
## 上の帯に渡すターンと番は、ここから読む。再生したイベントを、再生した順に食わせる（見せる前に）。
## 対戦の場面では、行動をルールに渡す前に、場面が対戦から写し直す（take）。リプレイでは、始めの写しのまま出来事だけで進める。
var replay: ReplayBoard
## 対戦のログ（再生したイベントを、再生した順に食わせる）。無ければ食わせない。
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
## リザルトの画面に出すもの (draw, winner, reason, reason_id) -> result_summary.gd（reason_id は GameWonEvent.Reason。引き分けは -1）、
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
## played の NEUTRAL_PHASE_SHOWN は、中立の番の知らせを出した回数（中立の駒のいない番は飛ばすので、数えない）。
var played := {}
var camera_follows := {}
const NEUTRAL_PHASE_SHOWN := &"neutral_phase_shown"
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
## カットシーン（docs/battle-view.md の「盤のカットシーン」）の、歩く 1 マスの秒数（台本の CutPaceEvent。0 ならいつもの速さ）。
var cut_step_time := 0.0
## 湧いた・置いた駒の、人物の形（駒の番号 -> unit_looks.gd の PERSONS の名前）。カットシーンの名前のある兵。無ければ空。
var unit_looks := {}


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


## 再生の盤を、battle のいまから写し直す（場面が、行動をルールに渡す前と、対戦を替えたときに呼ぶ）。
func take(battle: Battle) -> void:
	replay = ReplayBoard.of(battle)


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
	return _ui != null and _ui.cpu_running and side == cpu_side.call()


func _view(unit_id: int) -> UnitView:
	return _views[unit_id]


## 台本の出来事（カットシーンの台本だけが出す。対戦では起きない）を置く所。
const CUT_EVENTS_DIR := "res://game/cut_events/"


## イベントの種類（スクリプト）-> 再生するメソッドの名前。
## rules/events/ のイベントと、台本の出来事（game/cut_events/）は、すべてここに載せる（載っていない種類があると、テストが落ちる）。
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
		KnotPlacedEvent: &"_play_field_effect_placed",
		RallyEvent: &"_play_rally",
		BurstEvent: &"_play_burst",
		FieldEffectTickedEvent: &"_play_field_effect_ticked",
		FieldEffectRemovedEvent: &"_play_field_effect_removed",
		BarricadeDamagedEvent: &"_play_barricade_damaged",
		SmokeBlockedEvent: &"_play_smoke_blocked",
		SanctuaryHealedEvent: &"_play_sanctuary_healed",
		SkillUsedEvent: &"_play_skill_used",
		SkillReadyEvent: &"_play_skill_ready",
		UltUsedEvent: &"_play_ult_used",
		UltReadyEvent: &"_play_ult_ready",
		TraitTriggeredEvent: &"_play_trait_triggered",
		SupplyHealedEvent: &"_play_supply_healed",
		StatusAppliedEvent: &"_play_status_applied",
		StatusRemovedEvent: &"_play_status_removed",
		UnitActedEvent: &"_play_acted",
		PhaseStartedEvent: &"_play_phase_started",
		CaptureProgressEvent: &"_play_capture",
		StrongholdProgressEvent: &"_play_stronghold",
		GameWonEvent: &"_play_won",
		GameDrawnEvent: &"_play_drawn",
		# 台本の出来事（カットシーンの台本だけが出す。game/cut_events/。再生は playback_cut.gd）
		CutPlacedEvent: &"_play_cut_placed",
		CutLeftEvent: &"_play_cut_left",
		CutTurnedEvent: &"_play_cut_turned",
		CutCameraEvent: &"_play_cut_camera",
		CutPaceEvent: &"_play_cut_pace",
		CutWaitEvent: &"_play_cut_wait",
	}


func _play(event: BattleEvent) -> void:
	var kind: Script = event.get_script()
	if not _players.has(kind):
		push_error("再生できないイベント: %s" % kind.resource_path)
		return
	played[kind] = played.get(kind, 0) + 1
	_feed(event)
	await call(_players[kind], event)


## 再生の盤とログに、イベントを食わせる。
func _feed(event: BattleEvent) -> void:
	replay.feed(event)
	if battle_log != null:
		battle_log.feed(event)


## 見せずに済ませる（飛ばしている間など）。数えてログに食わせ、動いた駒は行き着いたマスへすぐ置く。
## そのほかの見た目（状態の印、上の帯）は、再生のあとの作り直しが今の盤から描く。
func _settle(event: BattleEvent) -> void:
	played[event.get_script()] = played.get(event.get_script(), 0) + 1
	_feed(event)
	if skipping:
		_unsynced = true  # 駒の見た目は、まとめて作り直す
		return
	var moved := event as UnitMovedEvent
	var undone := event as MoveUndoneEvent
	if moved != null and not moved.path.is_empty() and _views.has(moved.unit_id):
		_view(moved.unit_id).position = BoardView.cell_center(moved.path[-1])
	elif event is CutLeftEvent and _views.has(event.unit_id):
		(_views[event.unit_id] as Node).queue_free()
		_views.erase(event.unit_id)
	elif undone != null and _views.has(undone.unit_id):
		_view(undone.unit_id).position = BoardView.cell_center(undone.to)


## 駒 unit_id の種類（盤から消えていれば、見た目の種類）。
func _kind_of(unit_id: int) -> UnitKind.Id:
	var piece := replay.piece(unit_id)
	return piece.kind if piece != null else _view(unit_id).unit_kind()


## 陣営 side（盤にいない駒は -1）の駒が歩く間、カメラが追いかけるか。自分で動かしていない駒（CPU の番の駒、中立の駒）だけ。
## 中立のフェーズの静かな場面をまとめて流している間は、追わない（何体も同時に動く）。
func _camera_follows(side: int) -> bool:
	if side < 0 or _quiet_playback:
		return false
	return side == Unit.Side.NEUTRAL or _cpu_moving(side as Unit.Side)


## 攻撃の動きと、当たる形（駒の種類ごと。battle_effects.gd）を出し、当たる瞬間まで待つ。
func _strike(attacker: UnitView, at: Vector3) -> void:
	_acted_with_effect = true
	var hit_in := attacker.play_attack()
	_effects.strike(BattleEffects.hit_style(attacker.unit_kind()), attacker.position, at, hit_in)
	await after(hit_in)


## 自分で動かしていない駒（CPU の番の駒、中立の駒）の攻撃は、攻撃する駒と相手の間へカメラを寄せる（どちらも見えるように）。
func _show_strike(attacker_id: int, attacker: UnitView, target: UnitView) -> void:
	var side := replay.side_of(attacker_id)
	if side == Unit.Side.NEUTRAL or (side >= 0 and _cpu_moving(side as Unit.Side)):
		_rig.focus_on((attacker.position + target.position) / 2.0)


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
		var band := _hud.banner_rect() if _hud != null else Rect2()  # カットシーンには上の帯も知らせも無い
		label.position = pop_place(label.position, text.length(), live, band, camera.unproject_position, camera.global_basis.y)
	_stage.add_child(label)
	_pops.append(label)
	var tween := create_tween()
	tween.tween_property(label, "position:y", label.position.y + POP_RISE, POP_TIME)
	tween.parallel().tween_property(label, "modulate:a", 0.0, POP_TIME).set_ease(Tween.EASE_IN)
	# 縁取りは modulate では薄くならない。一緒に消さないと、消える間際に黒い縁取りだけが字の形に残る。
	tween.parallel().tween_property(label, "outline_modulate:a", 0.0, POP_TIME).set_ease(Tween.EASE_IN)
	tween.tween_callback(label.queue_free)


## 浮かぶ文字の出る位置: まだ浮かんでいる文字と重ならず（pop_start_position）、画面の中央の知らせの帯（必殺技など）が出ている間は、
## 昇りきるまで帯にかからない（pop_clear_of_band）位置。帯から逃がすと別の文字に重なることがあるので、両方を満たすまで繰り返す
## （同時に出る文字が、どれも帯の同じ縁へ寄せられて重ならないように）。
static func pop_place(start: Vector3, length: int, live: Array, band: Rect2, project: Callable, up: Vector3) -> Vector3:
	var at := start
	for attempt in live.size() + 3:
		var placed := pop_clear_of_band(pop_start_position(at, length, live, project, up), band, project, up)
		if placed.is_equal_approx(at):
			return at
		at = placed
	return at


## 浮かぶ文字を at から出すとき、昇りきるまで（POP_RISE）画面の上で帯 band（画面の座標。空なら何もしない）にかからない位置。
## 帯の真ん中より上から出る文字は帯の上へ、下から出る文字は帯の下へ、カメラの上の向き up に沿ってずらす。
static func pop_clear_of_band(at: Vector3, band: Rect2, project: Callable, up: Vector3) -> Vector3:
	if not band.has_area():
		return at
	var glyph := POP_FONT_SIZE * POP_PIXEL_SIZE
	for attempt in 3:  # 透視でずれる量が少し変わるので、何度か詰める
		var start: Vector2 = project.call(at)
		var line: float = ((project.call(at + up * glyph) as Vector2) - start).length()
		if line <= 0.0:
			return at
		var end: Vector2 = project.call(at + Vector3.UP * POP_RISE)
		var half := line * POP_LINE_SPACING / 2.0  # 字の半分の高さと、縁取りのぶん
		var top := minf(start.y, end.y) - half
		var bottom := maxf(start.y, end.y) + half
		if bottom <= band.position.y or top >= band.end.y:
			return at
		if start.y < band.get_center().y:
			at += up * ((bottom - band.position.y + 1.0) / line * glyph)
		else:
			at -= up * ((band.end.y - top + 1.0) / line * glyph)
	return at


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
