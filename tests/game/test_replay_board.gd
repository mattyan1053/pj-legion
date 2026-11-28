extends "res://tests/base_test.gd"
## 再生の盤（game/replay_board.gd）: 始めの盤の写しと出来事の列だけで、実際の対局と同じ盤の見え方になること。
## 控えた CPU どうしの 1 局（tests/support/cpu_game.gd）を使う。

const CpuGame := preload("res://tests/support/cpu_game.gd")
const ReplayBoard := preload("res://game/replay_board.gd")


## 再生の盤 replay が、対戦 battle の目に見えるところと同じか。違えば、違う所を返す（同じなら空）。
static func differences(replay: ReplayBoard, battle: Battle) -> Array[String]:
	var found: Array[String] = []
	var ids: Array[int] = []
	for unit in battle.units:
		ids.append(unit.id)
		var piece: ReplayBoard.Piece = replay.piece(unit.id)
		if piece == null:
			found.append("駒 %d が再生の盤にいない" % unit.id)
			continue
		var want := [unit.side, unit.kind, unit.cell, unit.hp, unit.max_hp(), unit.level, unit.evolution, unit.acted, Statuses.types_of(unit)]
		var got := [piece.side, piece.kind, piece.cell, piece.hp, piece.max_hp, piece.level, piece.evolution, piece.acted, piece.status_types()]
		if want != got:
			found.append("駒 %d: 実際 %s / 再生 %s" % [unit.id, want, got])
	ids.sort()
	var replayed: Array[int] = []
	replayed.assign(replay.pieces.keys())
	replayed.sort()
	if ids != replayed:
		found.append("駒の顔ぶれ: 実際 %s / 再生 %s" % [ids, replayed])
	var effects := {}
	for effect in battle.board.field_effects:
		effects[effect.id] = [effect.type, effect.side, effect.cells, effect.durability]
	var want_board := [battle.turn, battle.phase, battle.capture_turns, battle.stronghold_holds, battle.relics, battle.winner, battle.board.barrel_cells, effects]
	var got_board := [replay.turn, replay.phase, replay.capture_turns, replay.stronghold_holds, replay.relics, replay.winner, replay.barrels, replay.field_effects]
	if want_board != got_board:
		found.append("盤: 実際 %s / 再生 %s" % [want_board, got_board])
	return found


## 控えた 1 局の出来事を、ルールを動かさずに再生の盤へ流すと、どの行動のあとも、実際の対局と同じ見え方になる。
func test_replay_board_follows_a_recorded_game() -> void:
	var start := CpuGame.start()
	var replay := ReplayBoard.of(start)
	var battle := CpuGame.start()
	var seen := {"actions": 0, "events": 0, "first": [] as Array[String]}  # 関数の中から書き戻すので、辞書に置く
	CpuGame.replay(battle, func(result: ActionResult) -> void:
		seen.actions += 1
		for event in result.events:
			replay.feed(event)
			seen.events += 1
		if (seen.first as Array).is_empty():
			var found := differences(replay, battle)
			if not found.is_empty():
				found.push_front("%d 手目のあと" % seen.actions)
			seen.first = found
	)
	var actions: int = seen.actions
	var events: int = seen.events
	var first: Array[String] = seen.first
	assert_true(actions > 20, "控えた局が短すぎる: %d 手" % actions)
	assert_true(battle.is_over(), "控えた局が決着していない")
	assert_eq(first, [] as Array[String], "再生の盤が、実際の対局とずれた")
	assert_true(replay.is_over(), "再生の盤が決着していない")
	# 始めの盤の写しは、そのあとの対局で動かない（写しを取った盤から切れている）。
	assert_eq(differences(ReplayBoard.of(CpuGame.start()), start), [] as Array[String], "始めの盤の写しが、もとの盤と違う")
	assert_true(events > actions, "出来事が少なすぎる")


# ---- 再生の場面（game/battle_playback.gd）を、始めの盤の写しと出来事だけで回す ----

const BattlePlayback := preload("res://game/battle_playback.gd")
const BoardView := preload("res://game/board_view.gd")
const UnitView := preload("res://game/unit_view.gd")
const BattleHud := preload("res://game/battle_hud.gd")
const OrbitCamera := preload("res://game/orbit_camera.gd")
const BattleEffects := preload("res://game/battle_effects.gd")
const BattleUiState := preload("res://game/battle_ui_state.gd")
const ResultSummary := preload("res://game/result_summary.gd")
const COLORS: Array[Color] = [Color.ROYAL_BLUE, Color.FIREBRICK, Color.DARK_OLIVE_GREEN]
## 再生を早回しする倍率（待ち時間と動きを縮める。起きる順と最後の見え方は変わらない）。
const FAST := 200.0


## 控えた 1 局の出来事の全部を、対戦を渡さずに再生の場面へ流すと、終わりの駒の見た目（位置・HP・最大 HP・行動済み・状態の輪）が
## 実際の対局の終わりと同じになる。リプレイと、カットシーンで盤の上の駒を台本どおりに動かすことの土台。
## 再生はコマ数で掛かる（400 ほどの出来事で 2〜3 秒。早回ししても縮まない）ので、長い検査で回す。
func test_long_playback_runs_from_a_start_copy_and_events_only() -> void:
	var start := CpuGame.start()
	var events: Array[BattleEvent] = []
	var battle := CpuGame.start()
	CpuGame.replay(battle, func(result: ActionResult) -> void: events.append_array(result.events))

	var stage := Node3D.new()
	await settle(stage)
	var rig := OrbitCamera.new()
	stage.add_child(rig)
	var hud := BattleHud.new()
	stage.add_child(hud)
	hud.setup(COLORS)
	var effects := BattleEffects.new()
	effects.play_sound = func(_name: StringName) -> void: pass
	stage.add_child(effects)
	var board_view := BoardView.new()
	stage.add_child(board_view)
	board_view.setup(start.board, CpuGame.SEED, COLORS)
	var views := {}
	for unit in start.units:
		var view := UnitView.new()
		view.position = BoardView.cell_center(unit.cell)
		stage.add_child(view)
		view.setup(unit.kind, COLORS[unit.side], unit.hp, unit.max_hp())
		view.set_acted(unit.acted)
		views[unit.id] = view
	var playback := BattlePlayback.new()
	stage.add_child(playback)
	playback.setup(stage, views, rig, hud, effects, BattleUiState.new(), COLORS, {}, {})
	playback.set_board_view(board_view)
	playback.take(start)  # 対戦は渡さない。始めの盤の写しだけ
	var names: Array[String] = ["P1", "P2"]
	playback.refresh_status = func(_turn: int, _phase: Unit.Side) -> void: pass
	playback.side_name = func(side: Unit.Side) -> String: return names[side] if side < 2 else "N"
	playback.result_summary = func(draw: bool, winner: Unit.Side, reason: String, _reason_id: int) -> RefCounted:
		return ResultSummary.of(BattleStats.new(start), draw, winner, reason, true, Unit.Side.PLAYER1, names, "")
	playback.camera_point = func(_side: Unit.Side) -> Vector3: return Vector3.ZERO
	playback.cpu_side = func() -> Unit.Side: return Unit.Side.PLAYER2
	playback.play_sound = func(_name: StringName) -> void: pass
	playback.frame_passed = (Engine.get_main_loop() as SceneTree).process_frame

	var winners: Array[int] = []
	hud.result_shown.connect(func(_draw: bool, winner: Unit.Side) -> void: winners.append(winner))

	var scale := Engine.time_scale
	Engine.time_scale = FAST
	await playback.play_all(events)
	Engine.time_scale = scale

	var found: Array[String] = []
	var ids: Array[int] = []
	for unit in battle.units:
		ids.append(unit.id)
		if not views.has(unit.id):
			found.append("駒 %d の見た目が無い" % unit.id)
			continue
		var view: UnitView = views[unit.id]
		var want := [BoardView.cell_center(unit.cell), unit.hp, unit.max_hp(), unit.acted, not Statuses.types_of(unit).is_empty()]
		var got := [view.position, view.shown_hp, view._max_hp, view._acted, view.has_status_mark()]
		if want != got:
			found.append("駒 %d: 実際 %s / 見た目 %s" % [unit.id, want, got])
	var shown: Array[int] = []
	shown.assign(views.keys())
	shown.sort()
	ids.sort()
	if shown != ids:
		found.append("見た目の顔ぶれ: 実際 %s / 見た目 %s" % [ids, shown])
	assert_eq(found, [] as Array[String], "再生だけで回した終わりの盤が、実際の対局と違う")
	assert_eq(winners, [battle.winner] as Array[int], "決着を見せていない")
	stage.queue_free()
