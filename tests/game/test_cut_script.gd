extends "res://tests/base_test.gd"
## 盤のカットシーンの台本（game/cut_script.gd）と、対戦を作らずに組む再生の盤（replay_board.gd の of_pieces）。
## 再生して見せる確かめ（舞台 cut_stage.gd）は長い検査（test_long_）。docs/battle-view.md の「盤のカットシーン」。

const CutScript := preload("res://game/cut_script.gd")
const CutStage := preload("res://game/cut_stage.gd")
const ReplayBoard := preload("res://game/replay_board.gd")
const BattlePlayback := preload("res://game/battle_playback.gd")
const Maps := preload("res://game/maps.gd")
## 長い検査で再生を進める速さ（Engine.time_scale）。
const FAST := 200.0


## 盤（読むのに時間が掛かるので、1 度だけ作る。台本は盤を書き換えない）。
static var _made: Board


func _board() -> Board:
	if _made == null:
		_made = (Maps.find("ridge_path")["map"] as HandMap).make_board()
	return _made


func _rows(lines: Array) -> Array:
	var rows: Array = []
	for i in lines.size():
		rows.append({"line": i + 1, "text": lines[i]})
	return rows


const SCRIPT := [
	"unit 隊長 ally king 8,2",
	"unit 斥候 ally commando 9,1",
	"unit 骸骨 enemy skeleton 3,1",
	"camera 8,2",
	"pace slow",
	"move 斥候 5,1",
	"> 斥候が先へ走った。",
	"隊長: 待て。",
	"face 隊長 斥候",
	"attack 骸骨 斥候 3",
	"attack 斥候 骸骨 30",
	"status 隊長 バリア",
	"appear 骨 enemy skeleton 1,1",
	"put 伝令 ally medic 15,1",
	"wait 0.5",
	"leave 伝令 15,2 16,2",
	"camera 骨",
	"fall 骨",
	"斥候: 片付きました。",
]


func test_script_rows_become_events_cut_by_lines() -> void:
	var cut := CutScript.read(_board(), _rows(SCRIPT))
	assert_eq(cut.problems, [], "書き損じが無いのに、問題が出た")
	assert_eq(cut.camera_cell, Vector2i(8, 2), "台本の頭の camera で、始めのカメラが決まる")
	assert_eq(cut.start.pieces.size(), 3, "始めの盤に、unit の兵が立つ")
	var kinds: Array = []
	for step in cut.steps:
		kinds.append("row" if step.has("row") else "events")
	assert_eq(kinds, ["events", "row", "row", "events", "row"], "出来事の塊を、文の行で切る")
	var first: Array = cut.steps[0]["events"]
	assert_true(first[0] is CutPaceEvent and first[1] is UnitMovedEvent, "pace と move が、最初の塊")
	assert_eq((first[1] as UnitMovedEvent).path, [Vector2i(9, 1), Vector2i(8, 1), Vector2i(7, 1), Vector2i(6, 1), Vector2i(5, 1)], "間のマスを、近い道で埋める")
	var names: Array = []
	for event: BattleEvent in cut.steps[3]["events"]:
		names.append(event.get_script().get_global_name())
	assert_eq(names, [
		&"CutTurnedEvent", &"AttackDamagedEvent", &"AttackDamagedEvent", &"UnitDefeatedEvent", &"StatusAppliedEvent",
		&"UnitSpawnedEvent", &"CutPlacedEvent", &"CutWaitEvent", &"CutLeftEvent", &"CutCameraEvent", &"UnitDefeatedEvent",
	], "台本の行の順に、出来事にする（HP が 0 になったら倒れる）")


func test_feeding_the_events_reaches_the_end_board() -> void:
	var cut := CutScript.read(_board(), _rows(SCRIPT))
	var replay: ReplayBoard = cut.start
	for event in cut.all_events():
		replay.feed(event)
	var left: Array = []
	for id: int in replay.pieces:
		left.append(cut.names.find_key(id))
	left.sort()
	assert_eq(left, ["斥候", "隊長"], "倒れた兵と去った兵は、終わりの盤にいない")
	var scout: ReplayBoard.Piece = replay.piece(cut.names["斥候"])
	assert_eq([scout.cell, scout.hp], [Vector2i(5, 1), scout.max_hp - 3], "歩いた先のマスと、残りの HP")
	assert_true(replay.piece(cut.names["隊長"]).statuses.has(Status.Type.BARRIER), "状態が付く")


func test_mistakes_are_reported_with_the_line() -> void:
	var cases := {
		"mvoe 斥候 5,1": "知らない台本の行",
		"move 誰か 5,1": "知らない兵",
		"move 斥候 0,0": "行けない",
		"attack 斥候 斥候": "自分",
		"status 斥候 元気": "知らない状態",
		"pace slower": "pace",
		"wait 9": "秒",
		"unit 兵 ally king 2,1": "台本の頭",
		"appear 斥候 enemy skeleton 1,1": "1 度だけ",
		"appear 骨 enemy dragon 1,1": "知らない種類",
		"camera 99,1": "盤の外",
	}
	for wrong: String in cases:
		var cut := CutScript.read(_board(), _rows(["unit 斥候 ally commando 9,1", "隊長: よし。", wrong]))
		assert_eq(cut.problems.size(), 1, "%s: 問題が 1 つ出る" % wrong)
		if cut.problems.size() == 1:
			assert_eq(cut.problems[0][0], 3, "%s: 行の番号" % wrong)
			assert_true(String(cut.problems[0][1]).contains(cases[wrong]), "%s: 「%s」の文 → %s" % [wrong, cases[wrong], cut.problems[0][1]])
	var gone := CutScript.read(_board(), _rows(["unit 斥候 ally commando 9,1", "fall 斥候", "move 斥候 5,1"]))
	assert_true(gone.problems.size() == 1 and String(gone.problems[0][1]).contains("もう盤にいない"), "倒れた兵は動かせない")


func test_text_rows_and_script_rows_are_told_apart() -> void:
	for text: String in ["> 夜が明けた。", "＞ 夜が明けた。", "隊長: 行くぞ。", "隊長：行くぞ。", "(if a = b) 隊長: 行くぞ。"]:
		assert_true(CutScript.is_text_row(text), "文の行: %s" % text)
	for text: String in ["move 斥候 5,1", "wait 1", "mvoe 斥候 5,1"]:
		assert_false(CutScript.is_text_row(text), "台本の行: %s" % text)


func test_normal_pace_is_the_battle_pace() -> void:
	assert_eq(CutScript.PACES["normal"], BattlePlayback.STEP_TIME, "pace normal は、対戦と同じ速さ")


## 舞台で、台本の全部の塊を順に再生すると、兵の見た目が終わりの盤と同じになる。スキップ（finish）でも同じになる。
func test_long_cut_stage_plays_to_the_end_board() -> void:
	for skip: bool in [false, true]:
		var cut := CutScript.read(_board(), _rows(SCRIPT))
		var stage := CutStage.new(cut, &"ridge", {"隊長": &"harden"})
		await settle(stage)
		var scale := Engine.time_scale
		Engine.time_scale = FAST
		var chunks: Array = []
		for step in cut.steps:
			if step.has("events"):
				chunks.append(step["events"])
		if skip:
			await stage.play(chunks[0])
			var rest: Array = []
			for chunk: Array in chunks.slice(1):
				rest.append_array(chunk)
			await stage.finish(rest)
		else:
			for chunk: Array in chunks:
				await stage.play(chunk)
		Engine.time_scale = scale
		await get_tree_frames(2)
		var replay: ReplayBoard = stage.replay()
		var views: Dictionary = stage.views()
		var shown: Array = views.keys()
		shown.sort()
		var want: Array = replay.pieces.keys()
		want.sort()
		assert_eq(shown, want, "見た目の兵と、終わりの盤の兵が同じ（スキップ: %s）" % skip)
		for id: int in want:
			if views.has(id):
				var view: Node3D = views[id]
				assert_eq(view.position, CutStage.BoardView.cell_center(replay.piece(id).cell), "兵 %d の位置（スキップ: %s）" % [id, skip])
				assert_eq(view.shown_hp, replay.piece(id).hp, "兵 %d の HP（スキップ: %s）" % [id, skip])
		stage.queue_free()


func get_tree_frames(count: int) -> void:
	for i in count:
		await (Engine.get_main_loop() as SceneTree).process_frame
