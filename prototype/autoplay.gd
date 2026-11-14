extends Node
## 検査用の自動対戦。`-- --autoplay` を付けて起動すると、人の代わりに画面を操作する。
##
## 人と同じ入口（マスを選ぶ・待機・戻す・ターン終了）だけを使い、対戦を最後まで進めてから、
## 小さな盤面で環境オブジェクトの場面（ポータルの転移、回復の泉、樽の爆発と引き分け）を通し、
## 盤面を作り直してほかのステージも少し動かす。途中で画面と対戦の状態が食い違ったら失敗にする。
## 最後に "autoplay: OK" を出して終わる（tools/check.sh がこの行を確かめる）。

const Queries := preload("res://prototype/battle_queries.gd")

## これだけターンが進んでも決着しなければ、失敗にする。
const MAX_TURNS := 80
## 2 戦目からは、このターンまで動かしたら次へ進む。
const SHORT_GAME_TURNS := 2
const STAGES: Array[BoardGenerator.Stage] = [
	BoardGenerator.Stage.PLAIN, BoardGenerator.Stage.TWIN_SPRINGS, BoardGenerator.Stage.LABYRINTH,
]

var _scene: Node
var _game := 0
var _undone := {}  # 移動の取り消しを試した駒の番号
var _confirm_tested := false
var _finished := false
## 決まった手順で進める場面の、残りの手（画面が操作を受け付けるたびに、先頭から 1 つずつ実行する）。
var _scripted: Array[Callable] = []
var _scenes_done := false


func _init(scene: Node) -> void:
	_scene = scene
	# 再生の待ち時間を縮めて、検査を短く済ませる（CI は 1 分以内に収める）。
	Engine.time_scale = 8.0


func _process(_delta: float) -> void:
	if _finished or _scene.is_busy():
		return
	var battle: Battle = _scene.battle
	var problem := _mismatch(battle)
	if problem != "":
		_finish("autoplay: 画面と状態が食い違った: %s" % problem, 1)
		return

	if not _scripted.is_empty():
		var step: Callable = _scripted.pop_front()
		step.call()
		return
	if battle.is_over() or (_game > 0 and battle.turn >= SHORT_GAME_TURNS):
		if _game == 0 and not _scenes_done:
			print("autoplay: ターン %d で決着（勝者 %d）" % [battle.turn, battle.winner])
			_scenes_done = true
			_queue_portal_and_spring_scene()
			_queue_capture_scene()
			_queue_barrel_draw_scene()
			return
		_game += 1
		if _game >= STAGES.size():
			_finish_if_all_played()
			return
		_undone.clear()
		_scene.start_battle(STAGES[_game], _scene.map_seed + 1)
		return
	if battle.turn > MAX_TURNS:
		_finish("autoplay: %d ターンでも決着しなかった" % MAX_TURNS, 1)
		return
	_step(battle)


func _step(battle: Battle) -> void:
	var acting := battle.unit_by_id(battle.acting_unit_id)
	if acting != null:
		# 動いたあと: 攻撃できれば攻撃、できなければ待機。駒ごとに 1 回、移動の取り消しも試す。
		var targets := Queries.attack_targets(battle, acting)
		if not targets.is_empty():
			_scene.click_cell(_pick_target(targets).cell)
		elif not _undone.has(acting.id) and acting.id % 3 == 0:
			_undone[acting.id] = true
			_scene.cancel()
		else:
			_scene.press_wait()
		return

	var unit := _next_unit(battle)
	if unit == null:
		_scene.press_end_turn()
		return
	if battle.turn == 2 and not _confirm_tested:
		# 未行動の駒を残したままのターン終了は、1 回目では終わらない。
		_confirm_tested = true
		_scene.press_end_turn()
		if battle.turn != 2 or battle.phase != unit.side:
			_finish("autoplay: 確かめずにターンが終わった", 1)
		return
	if _scene.selected_unit() != unit:
		_scene.click_cell(unit.cell)
		return

	var targets := Queries.attack_targets(battle, unit)
	if not targets.is_empty():
		_scene.click_cell(_pick_target(targets).cell)
		return
	var cell := _best_move(battle, unit)
	if cell == unit.cell:
		_scene.press_wait()
	else:
		_scene.click_cell(cell)


# ---- 決まった手順の場面 ----


## 条件が偽なら、検査を失敗で終える。
func _expect(condition: bool, what: String) -> void:
	if not condition and not _finished:
		_finish("autoplay: %s" % what, 1)


func _small_board(size: Vector2i) -> Board:
	var board := Board.new(size)
	board.hq_cells = [Vector2i(0, size.y - 1), Vector2i(size.x - 1, 0)]
	return board


## ターンを終える（未行動の駒が残っていれば、確かめの 2 回目まで押す）。
func _end_turn() -> void:
	_scene.press_end_turn()
	_scene.press_end_turn()


## ポータルを通る移動（歩く → 転移 → 歩く）と、その取り消し、回復の泉の回復。
func _queue_portal_and_spring_scene() -> void:
	var board := _small_board(Vector2i(12, 6))
	board.add_portal_pair(Vector2i(1, 1), Vector2i(8, 1))
	board.add_spring(Vector2i(4, 4))
	var battle := Battle.new(board)
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER1, Vector2i(0, 5))
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER2, Vector2i(11, 0))
	var walker := battle.add_unit(UnitKind.Id.SNIPER, Unit.Side.PLAYER1, Vector2i(0, 1))
	var bather := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, Unit.Side.PLAYER1, Vector2i(4, 4))
	bather.hp -= 20
	var far := Vector2i(10, 1)  # 歩けば 10 マス。ポータルを通れば移動力 3 で届く。
	var warped: Script = UnitWarpedEvent
	var moved: Script = UnitMovedEvent

	_scripted.append(func() -> void: _scene.start_with(battle, BoardGenerator.Stage.TWIN_SPRINGS, 1))
	_scripted.append(func() -> void: _scene.click_cell(walker.cell))
	_scripted.append(func() -> void:
		_scene.played.erase(warped)
		_scene.played.erase(moved)
		_scene.click_cell(far))
	_scripted.append(func() -> void:
		_expect(walker.cell == far, "ポータルの先へ動かなかった")
		_expect(_scene.played.get(moved, 0) == 2 and _scene.played.get(warped, 0) == 1, "歩く → 転移 → 歩く の順に再生しなかった")
		_scene.cancel())
	_scripted.append(func() -> void:
		_expect(walker.cell == Vector2i(0, 1), "転移した移動を取り消せなかった")
		_scene.click_cell(far))
	_scripted.append(func() -> void: _scene.press_wait())
	_scripted.append(_end_turn)
	_scripted.append(_end_turn)
	_scripted.append(func() -> void:
		_expect(battle.turn == 2 and battle.phase == Unit.Side.PLAYER1, "ターンが進まなかった")
		_expect(bather.hp == bather.max_hp() - 20 + MapObject.SPRING_HEAL, "回復の泉で回復しなかった"))


## 敵の本陣に乗ったままターンを終えて、占拠の数を進める。
func _queue_capture_scene() -> void:
	var board := _small_board(Vector2i(6, 4))
	var battle := Battle.new(board)
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER1, Vector2i(0, 3))
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER2, Vector2i(5, 3))
	var raider := battle.add_unit(UnitKind.Id.COMMANDO, Unit.Side.PLAYER1, Vector2i(3, 0))

	_scripted.append(func() -> void: _scene.start_with(battle, BoardGenerator.Stage.PLAIN, 1))
	_scripted.append(func() -> void: _scene.click_cell(raider.cell))
	_scripted.append(func() -> void: _scene.click_cell(board.hq_cells[Unit.Side.PLAYER2]))
	_scripted.append(func() -> void: _scene.press_wait())
	_scripted.append(_end_turn)
	_scripted.append(func() -> void: _expect(battle.capture_turns[Unit.Side.PLAYER1] == 1, "占拠の数が進まなかった"))


## 樽を攻撃して爆発させ、両方の将を巻き込んで引き分けにする。
func _queue_barrel_draw_scene() -> void:
	var board := _small_board(Vector2i(7, 5))
	board.add_barrel(Vector2i(3, 2))
	board.add_barrel(Vector2i(0, 0))  # 射程の外。爆発のあとも残る
	var battle := Battle.new(board)
	var king1 := battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER1, Vector2i(2, 2))
	var king2 := battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER2, Vector2i(4, 2))
	king1.hp = 10
	king2.hp = 10
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, Unit.Side.PLAYER1, Vector2i(3, 4))
	var guard := battle.add_unit(UnitKind.Id.PALADIN, Unit.Side.PLAYER2, Vector2i(4, 1))

	_scripted.append(func() -> void: _scene.start_with(battle, BoardGenerator.Stage.PLAIN, 1))
	_scripted.append(func() -> void: _scene.click_cell(sniper.cell))
	_scripted.append(func() -> void:
		_expect(Queries.barrel_targets(battle, sniper) == ([Vector2i(3, 2)] as Array[Vector2i]), "狙える樽が違う")
		_scene.click_cell(Vector2i(3, 2)))
	_scripted.append(func() -> void:
		_expect(battle.is_draw(), "引き分けにならなかった")
		_expect(_scene.result_title() == "引き分け", "引き分けの結果が出ていない")
		_expect(guard.hp == guard.max_hp() - MapObject.BLAST_DAMAGE, "爆発に巻き込まれなかった")
		_expect(_scene.barrel_view_cells() == ([Vector2i(0, 0)] as Array[Vector2i]), "爆発した樽が画面に残っている"))


## 対戦を通して、どの種類のイベントも 1 回は再生したことを確かめて終える。
func _finish_if_all_played() -> void:
	var players: Dictionary = _scene.event_players()
	for kind: Script in players:
		if kind == HealerHealedEvent:
			continue  # 回復役の回復の操作は、まだ画面に無い（docs/battle-view.md の「仮のもの」）
		if _scene.played.get(kind, 0) == 0:
			_finish("autoplay: 1 回も再生しなかったイベント: %s" % kind.resource_path, 1)
			return
	_finish("autoplay: OK", 0)


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
	return ""


func _finish(message: String, code: int) -> void:
	_finished = true
	print(message)
	get_tree().quit(code)
