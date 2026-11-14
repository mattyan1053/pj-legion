extends Node
## 検査用の自動対戦。`-- --autoplay` を付けて起動すると、人の代わりに画面を操作する。
##
## 人と同じ入口（マスを選ぶ・待機・戻す・ターン終了・進化先を選ぶ）だけを使い、対戦を最後まで進めてから、
## 小さな盤面で環境オブジェクトの場面（ポータルの転移、回復の泉、樽の爆発と引き分け）、盤の上の効果（盾・煙幕・聖域）、中立の駒、レベルアップ、進化、
## 回復役の回復、CPU の番の場面を通し、盤面を作り直してほかのステージも少し動かす（そのうち 1 戦は、相手を CPU にする）。
## 途中で画面と対戦の状態が食い違ったら失敗にする。
## 最後に "autoplay: OK" を出して終わる（tools/check.sh がこの行を確かめる）。

const Queries := preload("res://prototype/battle_queries.gd")

## これだけターンが進んでも決着しなければ、失敗にする。
const MAX_TURNS := 80
## 2 戦目からは、このターンまで動かしたら次へ進む。
const SHORT_GAME_TURNS := 2
## この番号の対戦は、相手（プレイヤー2）を CPU にする。
const CPU_GAME := 1
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
## CPU を相手にした対戦を始めたときの、CPU の行動の数。
var _cpu_actions_before := 0


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
			_queue_field_effect_scene()
			_queue_neutral_scene()
			_queue_level_up_scene()
			_queue_evolution_scene()
			_queue_heal_scene()
			_queue_cpu_scene()
			return
		if _game == CPU_GAME and _scene.cpu_actions == _cpu_actions_before:
			_finish("autoplay: CPU の番を、CPU が進めなかった", 1)
			return
		_game += 1
		if _game >= STAGES.size():
			_finish_if_all_played()
			return
		_undone.clear()
		_cpu_actions_before = _scene.cpu_actions
		_scene.set_opponent(_game == CPU_GAME)
		_scene.start_battle(STAGES[_game], _scene.map_seed + 1)
		return
	if battle.turn > MAX_TURNS:
		_finish("autoplay: %d ターンでも決着しなかった" % MAX_TURNS, 1)
		return
	_step(battle)


func _step(battle: Battle) -> void:
	var evolving := battle.evolving_unit()
	if evolving != null:
		_scene.choose_evolution(evolving.id % 2)  # 駒によって A と B を選び分ける
		return
	var acting := battle.unit_by_id(battle.acting_unit_id)
	if acting != null:
		# 動いたあと: 攻撃・回復できればする、できなければ待機。駒ごとに 1 回、移動の取り消しも試す。
		var targets := Queries.attack_targets(battle, acting)
		var heals := Queries.heal_targets(battle, acting)
		if not targets.is_empty():
			_scene.click_cell(_pick_target(targets).cell)
		elif not heals.is_empty():
			_scene.click_cell(heals[0].cell)
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
	var heals := Queries.heal_targets(battle, unit)
	if not heals.is_empty():
		_scene.click_cell(heals[0].cell)
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


## 盤の上の効果。ルールの入口（FieldEffects.place_*）で盾・煙幕・聖域を置いて再生し、
## 盾越しには撃てないこと、盾を壊せること、煙幕が離れたところからの攻撃を防ぐこと、聖域の回復と期間の進みを通す。
func _queue_field_effect_scene() -> void:
	var board := _small_board(Vector2i(7, 5))
	var battle := Battle.new(board)
	var king1 := battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER1, Vector2i(0, 4))
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER2, Vector2i(6, 0))
	king1.hp -= 10
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, Unit.Side.PLAYER1, Vector2i(1, 2))
	var sorcerer := battle.add_unit(UnitKind.Id.SORCERER, Unit.Side.PLAYER1, Vector2i(2, 0))
	var guard := battle.add_unit(UnitKind.Id.PALADIN, Unit.Side.PLAYER2, Vector2i(5, 2))
	var hidden := battle.add_unit(UnitKind.Id.SNIPER, Unit.Side.PLAYER2, Vector2i(4, 0))
	var wall := Vector2i(3, 2)
	var blocked: Script = SmokeBlockedEvent
	var healed: Script = SanctuaryHealedEvent

	_scripted.append(func() -> void: _scene.start_with(battle, BoardGenerator.Stage.PLAIN, 1))
	_scripted.append(func() -> void:
		var events := FieldEffects.place_barricade(battle, Unit.Side.PLAYER2, wall)
		events.append_array(FieldEffects.place_smoke(battle, Unit.Side.PLAYER2, Vector2i(4, 1)))
		events.append_array(FieldEffects.place_sanctuary(battle, Unit.Side.PLAYER1, Vector2i(1, 3)))
		_expect(events.size() == 3, "盤の上の効果を置けなかった")
		battle.board.barricade_at(wall).durability = 5  # 1 回の攻撃で壊れるように
		_scene.play_events(events))
	_scripted.append(func() -> void: _scene.click_cell(sniper.cell))
	_scripted.append(func() -> void:
		_expect(not Queries.attack_targets(battle, sniper).has(guard), "盾越しに撃てる")
		_expect(Queries.barricade_targets(battle, sniper) == ([wall] as Array[Vector2i]), "狙える盾が違う")
		_scene.click_cell(wall))
	_scripted.append(func() -> void:
		_expect(battle.board.barricade_at(wall) == null, "盾が壊れなかった")
		_scene.click_cell(sorcerer.cell))
	_scripted.append(func() -> void:
		_scene.played.erase(blocked)
		_scene.click_cell(hidden.cell))
	_scripted.append(func() -> void:
		_expect(_scene.played.get(blocked, 0) == 1 and hidden.hp == hidden.max_hp(), "煙幕が攻撃を防がなかった")
		_scene.played.erase(healed))
	_scripted.append(_end_turn)
	_scripted.append(_end_turn)
	_scripted.append(func() -> void:
		_expect(battle.turn == 2 and battle.phase == Unit.Side.PLAYER1, "ターンが進まなかった")
		_expect(_scene.played.get(healed, 0) == 1, "聖域で回復しなかった")
		_expect(king1.hp == king1.max_hp() - 10 + FieldEffects.SANCTUARY_HEAL, "聖域の回復量が違う")
		_expect(battle.board.field_effects.size() == 2, "煙幕と聖域が残っていない"))


## 結晶泉にエナジー・コアが湧き、次の中立のフェーズで隣の駒を襲う。
func _queue_neutral_scene() -> void:
	var board := _small_board(Vector2i(8, 5))
	var font := Vector2i(3, 2)
	board.set_terrain(font, Terrain.Type.FONT)
	board.font_cells = [font]
	var battle := Battle.new(board)
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER1, Vector2i(0, 4))
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER2, Vector2i(7, 0))
	var bait := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, Unit.Side.PLAYER1, Vector2i(5, 2))

	_scripted.append(func() -> void: _scene.start_with(battle, BoardGenerator.Stage.PLAIN, 1))
	_scripted.append(_end_turn)
	_scripted.append(_end_turn)
	_scripted.append(func() -> void:
		var core := battle.unit_at(font)
		_expect(core != null and core.side == Unit.Side.NEUTRAL, "結晶泉にエナジー・コアが湧かなかった"))
	_scripted.append(_end_turn)
	_scripted.append(_end_turn)
	_scripted.append(func() -> void:
		_expect(bait.hp == bait.max_hp() - UnitKind.power(UnitKind.Id.MINION), "エナジー・コアが攻撃しなかった"))


## あと 10 でレベルが上がる駒が敵を倒し、経験値が入ってレベルが上がる。
func _queue_level_up_scene() -> void:
	var board := _small_board(Vector2i(6, 4))
	var battle := Battle.new(board)
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER1, Vector2i(0, 3))
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER2, Vector2i(5, 0))
	var raider := battle.add_unit(UnitKind.Id.COMMANDO, Unit.Side.PLAYER1, Vector2i(2, 2))
	raider.experience = Growth.EXPERIENCE_PER_LEVEL - Growth.HIT_EXPERIENCE
	var victim := battle.add_unit(UnitKind.Id.SNIPER, Unit.Side.PLAYER2, Vector2i(3, 2))
	victim.hp = 1
	raider.hp -= 5

	_scripted.append(func() -> void: _scene.start_with(battle, BoardGenerator.Stage.PLAIN, 1))
	_scripted.append(func() -> void: _scene.click_cell(raider.cell))
	_scripted.append(func() -> void: _scene.click_cell(victim.cell))
	_scripted.append(func() -> void:
		_expect(battle.unit_by_id(victim.id) == null, "敵を倒せなかった")
		_expect(raider.level == 2, "レベルが上がらなかった")
		_expect(raider.hp == raider.max_hp() - 5, "最大 HP が伸びたぶん HP が増えなかった")
		_expect(_scene.played.get(LevelUpEvent, 0) > 0, "レベルアップを再生しなかった"))


## あと 10 で上限のレベルに届く駒が攻撃を当て、進化先を選び、次の自分の番の始めに再生で回復する。
func _queue_evolution_scene() -> void:
	var board := _small_board(Vector2i(6, 4))
	var battle := Battle.new(board)
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER1, Vector2i(0, 3))
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER2, Vector2i(5, 0))
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, Unit.Side.PLAYER1, Vector2i(2, 2))
	paladin.level = Growth.MAX_LEVEL - 1
	paladin.experience = Growth.EXPERIENCE_PER_LEVEL - Growth.HIT_EXPERIENCE
	paladin.hp -= 20
	var wall := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, Unit.Side.PLAYER2, Vector2i(3, 2))
	var seen := {"hp": 0}  # 手順をまたいで覚えておく値（ラムダは外の変数を書き換えられない）

	_scripted.append(func() -> void: _scene.start_with(battle, BoardGenerator.Stage.PLAIN, 1))
	_scripted.append(func() -> void: _scene.click_cell(paladin.cell))
	_scripted.append(func() -> void: _scene.click_cell(wall.cell))
	_scripted.append(func() -> void:
		_expect(paladin.level == Growth.MAX_LEVEL, "上限のレベルに届かなかった")
		_expect(battle.evolving_unit() == paladin, "進化先を選ぶのを待っていない")
		_expect(_scene.is_choosing_evolution(), "進化先の選択肢が出ていない")
		_end_turn())
	_scripted.append(func() -> void:
		_expect(battle.phase == Unit.Side.PLAYER1, "進化先を選ぶ前にターンが終わった")
		seen["hp"] = paladin.hp
		_scene.choose_evolution(0))
	_scripted.append(func() -> void:
		_expect(paladin.evolution == Evolution.Id.SACRED, "進化しなかった")
		_expect(paladin.hp == seen["hp"] + Evolution.bonus(Evolution.Id.SACRED, Unit.Stat.MAX_HP), "最大 HP が伸びたぶん HP が増えなかった")
		_expect(not _scene.is_choosing_evolution(), "進化先の選択肢が残っている")
		seen["hp"] = paladin.hp
		_end_turn())
	_scripted.append(_end_turn)
	_scripted.append(func() -> void:
		_expect(battle.turn == 2 and battle.phase == Unit.Side.PLAYER1, "ターンが進まなかった")
		_expect(paladin.hp == seen["hp"] + Evolution.REGENERATION_HEAL, "再生で回復しなかった"))


## 回復役が動いて、減っている味方を回復する（人の操作で）。
func _queue_heal_scene() -> void:
	var board := _small_board(Vector2i(7, 4))
	var battle := Battle.new(board)
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER1, Vector2i(0, 3))
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER2, Vector2i(6, 0))
	var medic := battle.add_unit(UnitKind.Id.MEDIC, Unit.Side.PLAYER1, Vector2i(1, 1))
	var wounded := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, Unit.Side.PLAYER1, Vector2i(4, 1))
	wounded.hp = 10
	var healed: Script = HealerHealedEvent

	_scripted.append(func() -> void:
		_scene.set_opponent(false)
		_scene.start_with(battle, BoardGenerator.Stage.PLAIN, 1))
	_scripted.append(func() -> void: _scene.click_cell(medic.cell))
	_scripted.append(func() -> void:
		_expect(Queries.heal_targets(battle, medic).is_empty(), "届かない味方を回復できることになっている")
		_scene.click_cell(Vector2i(3, 1)))
	_scripted.append(func() -> void:
		_expect(Queries.heal_targets(battle, medic) == ([wounded] as Array[Unit]), "回復できる味方が違う")
		# 動いたあとに相手を切り替えても、その駒を選んだままで、続きができる。
		_scene.set_opponent(true)
		_expect(_scene.selected_unit() == medic, "相手を切り替えたら、動いたあとの駒の選択が外れた")
		_scene.set_opponent(false)
		_scene.played.erase(healed)
		_scene.click_cell(wounded.cell))
	_scripted.append(func() -> void:
		_expect(wounded.hp == 10 + medic.power(), "回復しなかった")
		_expect(medic.acted, "回復しても行動が終わっていない")
		_expect(_scene.played.get(healed, 0) == 1, "回復を再生しなかった"))


## 相手を CPU にして、ターンを終える。CPU が自分の番を進め（回復役が回復し、戦う駒が攻撃する）、こちらの番に戻る。
func _queue_cpu_scene() -> void:
	var board := _small_board(Vector2i(8, 5))
	var battle := Battle.new(board)
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER1, Vector2i(0, 4))
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER2, Vector2i(7, 0))
	var bait := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, Unit.Side.PLAYER1, Vector2i(3, 2))
	var sorcerer := battle.add_unit(UnitKind.Id.SORCERER, Unit.Side.PLAYER2, Vector2i(6, 2))
	var priest := battle.add_unit(UnitKind.Id.PRIEST, Unit.Side.PLAYER2, Vector2i(7, 2))
	var wounded := battle.add_unit(UnitKind.Id.PALADIN, Unit.Side.PLAYER2, Vector2i(6, 1))
	wounded.hp = 10
	var seen := {"actions": 0}

	_scripted.append(func() -> void:
		_scene.set_opponent(true)
		_scene.start_with(battle, BoardGenerator.Stage.PLAIN, 1))
	_scripted.append(func() -> void:
		seen["actions"] = _scene.cpu_actions
		_end_turn()
		# CPU の番の間は、操作を受け付けない。
		_scene.click_cell(sorcerer.cell)
		_expect(_scene.selected_unit() == null, "CPU の番に駒を選べた")
		_scene.press_end_turn())
	_scripted.append(func() -> void:
		_expect(battle.turn == 2 and battle.phase == Unit.Side.PLAYER1, "CPU が自分の番を終えなかった")
		_expect(_scene.cpu_actions > seen["actions"], "CPU が行動しなかった")
		_expect(wounded.hp == 10 + priest.power(), "CPU の回復役が回復しなかった")
		_expect(bait.hp < bait.max_hp(), "CPU の駒が攻撃しなかった")
		_scene.set_opponent(false))


## 対戦を通して、どの種類のイベントも 1 回は再生したことを確かめて終える。
func _finish_if_all_played() -> void:
	var players: Dictionary = _scene.event_players()
	for kind: Script in players:
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
	var effect_ids: Array[int] = []
	for effect in battle.board.field_effects:
		effect_ids.append(effect.id)
	effect_ids.sort()
	if _scene.field_effect_view_ids() != effect_ids:
		return "盤の上の効果（画面 %s、状態 %s）" % [_scene.field_effect_view_ids(), effect_ids]
	return ""


func _finish(message: String, code: int) -> void:
	_finished = true
	print(message)
	get_tree().quit(code)
