extends Node
## 自動の対戦（game/autoplay.gd）の土台: 読み込み、調整値、状態と、確かめる・操作する道具（_expect、マスを押す、マウスとキー、枠の見張り、終わり方）。
## 場面のファイル（*_checks.gd）は、これを継いで順に積み重なる（autoplay.gd が最後）。


const Names := preload("res://game/names.gd")
const SceneFlow := preload("res://game/scene_flow.gd")
const Queries := preload("res://game/battle_queries.gd")
const Story := preload("res://game/story.gd")
const StoryBattle := preload("res://game/story_battle.gd")
const BattleCues := preload("res://game/battle_cues.gd")
const Episode := preload("res://game/episode.gd")
const BattlePlayback := preload("res://game/battle_playback.gd")
const Palette := preload("res://game/ui_palette.gd")
const OrbitCamera := preload("res://game/orbit_camera.gd")
const StageLook := preload("res://game/stage_look.gd")
const VersusFields := preload("res://game/versus_fields.gd")
const MatchChoice := preload("res://game/match_choice.gd")
const RandomSquad := preload("res://game/random_squad.gd")
const AutoplaySweeps := preload("res://game/autoplay_sweeps.gd")
const NO_CELL := Vector2i(-1, -1)


const BattleHud := preload("res://game/battle_hud.gd")
const BattleTexts := preload("res://game/battle_texts.gd")
const ResultSummary := preload("res://game/result_summary.gd")


## これだけターンが進んでも決着しなければ、失敗にする。
const MAX_TURNS := 80
## 2 戦目からは、このターンまで動かしたら次へ進む。
const SHORT_GAME_TURNS := 2
## この番号の対戦は、相手（プレイヤー2）を CPU にする。
const CPU_GAME := 1
const STAGES: Array[StringName] = [VersusFields.PLAIN, VersusFields.TWIN_SPRINGS, VersusFields.LABYRINTH]


enum Phase { GAME, SCENES, STAGES, END }


var _scene: Node
## 長い検査（`--full`）のときだけ、ほかのマップも動かす。
var _full := OS.get_cmdline_user_args().has("--full")
## 回す場面の名前（SCENES の順）。
var _selected: Array[String] = []
var _phase := Phase.GAME
## いま回している場面の名前。
var _current := "game"
## 外れたこと（「場面: 何が」）。最後にまとめて出す。
var _failures: Array[String] = []
## 失敗した場面の名前（その場面の状態は、もう確かめない。次の場面が盤面を作り直す）。
var _failed_scenes: Array[String] = []
var _game := 0
var _undone := {}  # 移動の取り消しを試した駒の番号
var _confirm_tested := false
var _finished := false
## 決まった手順で進める場面の、残りの手（画面が操作を受け付けるたびに、先頭から 1 つずつ実行する）と、それぞれの場面の名前。
var _scripted: Array[Callable] = []
var _scripted_names: Array[String] = []
## CPU を相手にした対戦を始めたときの、CPU の行動の数。
var _cpu_actions_before := 0
## 最後に、対戦の場面を抜けて、タイトルと対戦設定の場面を通している途中か（_leave_battle）。
var _leaving := false


## 条件が偽なら、いまの場面の失敗にする（場面の残りの手は飛ばす）。
func _expect(condition: bool, what: String) -> void:
	if not condition and not _finished:
		_fail(what)


## いまの場面を失敗にして、その場面の残りの手を飛ばす。最初の対戦（game）なら、次のフレームで対戦をやめて場面へ進む。
func _fail(what: String) -> void:
	var line := "%s: %s" % [_current, what]
	if _failures.has(line):
		return
	_failures.append(line)
	if not _failed_scenes.has(_current):
		_failed_scenes.append(_current)
	printerr("autoplay: 失敗: %s" % line)
	while not _scripted_names.is_empty() and _scripted_names[0] == _current:
		_scripted_names.pop_front()
		_scripted.pop_front()
	if _phase == Phase.STAGES:
		_phase = Phase.END


## いまの場面の手として、次に step を行う（待ってからやり直すとき）。
func _push_front(step: Callable) -> void:
	_scripted.push_front(step)
	_scripted_names.push_front(_current)


## 戦闘予測のパネルが出ていて、words をどれも含み、画面（帯の内側）に収まり、駒のそばのメニューと重ならないこと。
func _expect_forecast(words: Array, what: String) -> void:
	var text: String = _scene.forecast_text()
	for word: String in words:
		_expect(text.contains(word), "%sの予測のパネルに「%s」が無い: %s" % [what, word, text.replace("\n", " / ")])
	# 画面と同じ順に置く: メニュー（中身が変わっていれば置き直す）→ 予測のパネル（メニューが動いていれば置き直す）。
	var menu: Rect2 = _scene.menu_rect()
	var rect: Rect2 = _scene.forecast_rect()
	var area: Rect2 = _scene.menu_area()
	_expect(area.grow(1.0).encloses(rect), "%sの予測のパネルが画面からはみ出した: %s" % [what, rect])
	_expect(rect.size.y <= area.size.y * 0.6, "%sの予測のパネルが高すぎる: %s" % [what, rect])
	_expect(not rect.intersects(menu), "%sの予測のパネルが、メニューに重なった: %s と %s" % [what, rect, menu])


func _small_board(size: Vector2i) -> Board:
	var board := Board.new(size)
	board.hq_cells = [Vector2i(0, size.y - 1), Vector2i(size.x - 1, 0)]
	return board


## ターンを終える（未行動の駒が残っていれば、間を置いて、確かめの 2 回目まで押す）。
func _end_turn() -> void:
	_scene.press_end_turn()
	_scene.pass_confirm_guard()
	_scene.press_end_turn()


func _next_unit(battle: Battle) -> Unit:
	for unit in battle.units:
		if battle.can_act(unit):
			return unit
	return null


## 将を優先し、次に HP の少ない相手。
func _pick_target(targets: Array[Unit]) -> Unit:
	var best := targets[0]
	for target in targets:
		if target.kind == UnitKind.Id.KING:
			return target
		if target.hp < best.hp:
			best = target
	return best


## 敵の将にいちばん近づけるマス。近づけなければ、いまのマス。
func _best_move(battle: Battle, unit: Unit) -> Vector2i:
	var king := Queries.king_of(battle, (1 - unit.side) as Unit.Side)
	var distance := _distances(battle.board, king.cell)
	var best := unit.cell
	var best_distance: int = distance.get(unit.cell, 9999)
	var cells := Queries.move_cells(battle, unit)
	for cell: Vector2i in cells:
		var d: int = distance.get(cell, 9999)
		if d < best_distance:
			best = cell
			best_distance = d
	return best


## from から各マスへの歩数（障害物を避けて上下左右）。
func _distances(board: Board, from: Vector2i) -> Dictionary:
	var result := {from: 0}
	var queue: Array[Vector2i] = [from]
	var head := 0
	while head < queue.size():
		var cell := queue[head]
		head += 1
		for direction in Board.DIRECTIONS:
			var next := cell + direction
			if board.is_walkable(next) and not result.has(next):
				result[next] = result[cell] + 1
				queue.append(next)
	return result


## 画面の駒が、対戦の状態と同じ数・同じマス・同じ HP で、樽も同じマスにあるか。食い違いがあれば、その説明を返す。
func _mismatch(battle: Battle) -> String:
	var cells: Dictionary = _scene.view_cells()
	if cells.size() != battle.units.size():
		return "駒の数（画面 %d、状態 %d）" % [cells.size(), battle.units.size()]
	for unit in battle.units:
		if cells.get(unit.id, Vector2i(-1, -1)) != unit.cell:
			return "駒 %d の位置（画面 %s、状態 %s）" % [unit.id, cells.get(unit.id), unit.cell]
	var hps: Dictionary = _scene.view_hps()
	for unit in battle.units:
		if hps.get(unit.id, -1) != unit.hp:
			return "駒 %d の HP（画面 %s、状態 %d）" % [unit.id, hps.get(unit.id), unit.hp]
	var barrels: Array[Vector2i] = _scene.barrel_view_cells()
	barrels.sort()
	var expected := battle.board.barrel_cells.duplicate()
	expected.sort()
	if barrels != expected:
		return "樽（画面 %s、状態 %s）" % [barrels, expected]
	var effect_ids: Array[int] = []
	for effect in battle.board.field_effects:
		effect_ids.append(effect.id)
	effect_ids.sort()
	if _scene.field_effect_view_ids() != effect_ids:
		return "盤の上の効果（画面 %s、状態 %s）" % [_scene.field_effect_view_ids(), effect_ids]
	return ""


## 駒のそばのメニューが、置いてよい範囲（画面から上下の帯を除いたところ）からはみ出していれば、その説明を返す。
func _menu_problem() -> String:
	if _scene.menu_ids().is_empty():
		return ""
	var rect: Rect2 = _scene.menu_rect()
	var area: Rect2 = _scene.menu_area()
	if not area.grow(0.5).encloses(rect):
		return "メニューが画面からはみ出した（%s が %s の外）" % [rect, area]
	return ""


## マウスの入口（押す・動かす・離す）で、クリックとドラッグが見分けられること。cell は駒のいないマス。
## 動かさずに離せばそのマスのクリック（情報が出る）、動かして離せば視点を回す・傾けるだけ（何も選ばない）。
## 横の動きで向き、縦の動きで見下ろす角度が変わる。
func _check_drag(cell: Vector2i) -> void:
	var at: Vector2 = _scene.cell_screen_position(cell)
	_mouse_button(at, true)
	_mouse_button(at, false)
	_expect(_scene.info_title().begins_with("マス (%d, %d)" % [cell.x, cell.y]), "クリックで、マスの情報が出なかった")
	_scene.cancel()
	var yaw: float = _scene.camera_yaw()
	_mouse_button(at, true)
	_mouse_motion(at + Vector2(60, 0), true)
	_mouse_button(at + Vector2(60, 0), false)
	_expect(not is_equal_approx(_scene.camera_yaw(), yaw), "ドラッグで、視点が回らなかった")
	_expect(_scene.info_title() == "" and _scene.selected_unit() == null, "ドラッグが、クリックとして扱われた")
	# 帯やメニューの上で離すと、離したことが盤面へ届かない。ボタンを押していない動きでは、回さない。
	yaw = _scene.camera_yaw()
	_mouse_button(at, true)
	_mouse_motion(at + Vector2(60, 0), true)
	var dragged: float = _scene.camera_yaw()
	_mouse_motion(at + Vector2(120, 0), false)
	_mouse_motion(at + Vector2(180, 0), false)
	_expect(not is_equal_approx(dragged, yaw) and is_equal_approx(_scene.camera_yaw(), dragged), "ボタンを離したあとも、視点が回り続けた")
	# 縦のドラッグ: 下へ動かすと真上からの見下ろしに近づき、上へ動かすと浅くなる。向きは変わらない。
	yaw = _scene.camera_yaw()
	var pitch: float = _scene.camera_pitch()
	_mouse_button(at, true)
	_mouse_motion(at + Vector2(0, 40), true, Vector2(0, 40))
	_expect(_scene.camera_pitch() > pitch and is_equal_approx(_scene.camera_yaw(), yaw), "下へのドラッグで、見下ろす角度が深くならなかった")
	_mouse_motion(at + Vector2(0, -40), true, Vector2(0, -80))
	_expect(_scene.camera_pitch() < pitch, "上へのドラッグで、見下ろす角度が浅くならなかった")
	# 斜めに動かすと、向きと角度が同時に変わる。
	pitch = _scene.camera_pitch()
	_mouse_motion(at + Vector2(30, 0), true, Vector2(30, 40))
	_mouse_button(at + Vector2(30, 0), false)
	_expect(not is_equal_approx(_scene.camera_yaw(), yaw) and _scene.camera_pitch() > pitch, "斜めのドラッグで、向きと角度が同時に変わらなかった")
	_expect(_scene.info_title() == "" and _scene.selected_unit() == null, "縦のドラッグが、クリックとして扱われた")


func _mouse_motion(at: Vector2, held: bool, relative := Vector2(60, 0)) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.relative = relative
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	_scene.feed_input(motion)


## マスを、マウスの左ボタンで押して離す（人がクリックするのと同じ入口）。
func _click(cell: Vector2i) -> void:
	var at: Vector2 = _scene.cell_screen_position(cell)
	_mouse_button(at, true)
	_mouse_button(at, false)


func _mouse_button(at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = at
	_scene.feed_input(event)


## 場面 scene の部品の位置と大きさが、moves（マウスを乗せる、などの関数の列）のどれをしても変わらないことを確かめる。
## 乗せた物が大きくなるのはよいので、moving（とその中身）は比べない。
func _expect_steady(scene: Node, moving: Array[Node], moves: Array, what: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var before := _layout_of(scene, moving)
	for move: Callable in moves:
		move.call()
		await get_tree().process_frame
		await get_tree().process_frame
		var after := _layout_of(scene, moving)
		var shifted: Array[String] = []
		for path: NodePath in before:
			if after.has(path) and after[path] != before[path]:
				shifted.append("%s %s -> %s" % [path, before[path], after[path]])
		_expect(shifted.is_empty(), "%sと、ほかの部品が動く（%s）: %s" % [what, move.get_bound_arguments(), shifted.slice(0, 3)])


## 初期位置の縮図（deploy_map.gd）の駒に、次々マウスを乗せて、最後に外す。枠の見張り（steady_probe.gd）が、その間の枠を見る。
func _hover_each(deploy: Control) -> void:
	for cell: Vector2i in deploy.unit_cells():
		deploy.hover_cell(cell)
		for i in 3:
			await get_tree().process_frame
	deploy.hover_cell(NO_CELL)
	for i in 3:
		await get_tree().process_frame


## 見えている部品（Control）の、画面の上の位置と大きさ（パス -> Rect2）。skip とその中身は除く。
## 文字（Label）と、送れる枠（ScrollContainer）の中身は、中身に合わせて伸び縮みしてよい（枠と、ほかの部品が動かなければよい）ので、比べない。
func _layout_of(node: Node, skip: Array[Node], into := {}) -> Dictionary:
	for child: Node in node.get_children():
		if skip.has(child):
			continue
		if child is Control:
			var control := child as Control
			if not control.is_visible_in_tree():
				continue
			if control is Label:
				continue
			into[control.get_path()] = Rect2(control.global_position, control.size)
			if control is ScrollContainer:
				continue  # 送れる枠の中身は、中身の量で伸び縮みしてよい（枠が動かなければよい）
		_layout_of(child, skip, into)
	return into


## control が画面（論理の大きさ）の中に収まっているか。
func _on_screen(control: Control) -> bool:
	return control.get_viewport().get_visible_rect().encloses(control.get_global_rect())


## ストーリーの 1 話の通し: タイトルの「ストーリー」→ 会話（送る・戻る・飛ばす）→ 話の対戦（選び直す入口が無い、手で作ったマップ、
## 決め打ちの敵）→ 勝って、決着の画面の「次へ」→ あとの会話（最後まで送る）→ タイトル。勝った時点でクリアを書き、タイトルに済みの印。
## 対戦は、話の対戦の画面に小さな盤を渡して、1 手で勝って終える（話の盤を最後まで進めると、検査が長くなる）。
## 部隊を選んで出撃する流れを通すので、部隊の決まっている頭の話（チュートリアル）は、クリアしたことにしてから始める。
## キーを 1 回押して離したことにする（本物の入力と同じ道を通す）。
func _push_key(app: Node, code: Key) -> void:
	for pressed: bool in [true, false]:
		var key := InputEventKey.new()
		key.physical_keycode = code
		key.keycode = code
		key.pressed = pressed
		app.get_viewport().push_input(key)


func _nudge_screen_size() -> void:
	var window := get_window()
	var size := window.content_scale_size
	window.content_scale_size = size + Vector2i(40, 0)
	await get_tree().process_frame
	window.content_scale_size = size
	await get_tree().process_frame


func _finish(message: String, code: int) -> void:
	_finished = true
	# 枠の見張り（game/steady_probe.gd）: 印の付いた枠が、出ている間に動いていたら失敗にする。
	var probe: Node = get_tree().root.find_child("SteadyProbe", true, false)
	if probe != null:
		if probe.found_report() != "":
			print("frames: 大きさが変わった板（印なし）:\n%s" % probe.found_report())
		if probe.report() != "":
			message = "autoplay: %s" % probe.report() if code == 0 else "%s\n  %s" % [message, probe.report()]
			code = 1
	print(message)
	# 音を止めて手放してから終える（鳴らしたまま終えると、終わるときにエラーが出る）。
	var context: Variant = _scene.get(&"context") if is_instance_valid(_scene) else null
	if context != null:
		context.quit(code)
	else:
		get_tree().quit(code)
