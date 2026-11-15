extends Node
## 検査用の自動対戦。`-- --autoplay` を付けて起動すると、人の代わりに画面を操作する。
##
## 人と同じ入口（マスを選ぶ・待機・戻す・ターン終了・進化先を選ぶ）だけを使い、対戦を最後まで進めてから、
## 小さな盤面で環境オブジェクトの場面（ポータルの転移、回復の泉、樽の爆発と引き分け）、盤の上の効果（盾・煙幕・聖域）、スキル（行動を終えないもの、行動済みの駒を戻すものも）、必殺技、中立の駒、レベルアップ、進化、
## 回復役の回復、CPU の番の場面を通す。
## 長い検査（`-- --autoplay --full`）では、そのあと盤面を作り直してほかのステージも少し動かす（そのうち 1 戦は、相手を CPU にする）。
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
## 長い検査（`--full`）のときだけ、ほかのステージも動かす。
var _full := OS.get_cmdline_user_args().has("--full")
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
	scene.set_time_scale_base(8.0)


func _process(_delta: float) -> void:
	if _finished or _scene.is_busy():
		return
	var battle: Battle = _scene.battle
	var problem := _mismatch(battle)
	if problem == "":
		problem = _menu_problem()
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
			var stats: BattleStats = _scene.stats
			_expect(stats.is_over() and stats.turns == battle.turn and stats.winner == battle.winner, "戦績が決着と食い違った")
			_expect(_scene.result_stats().contains("与えたダメージ"), "決着の画面に戦績が出ていない")
			print(_scene.result_stats())
			_scenes_done = true
			_queue_portal_and_spring_scene()
			_queue_capture_scene()
			_queue_barrel_draw_scene()
			_queue_field_effect_scene()
			_queue_skill_scene()
			_queue_status_scene()
			_queue_extra_action_scene()
			_queue_ult_scene()
			_queue_neutral_scene()
			_queue_mid_boss_scene()
			_queue_level_up_scene()
			_queue_evolution_scene()
			_queue_heal_scene()
			_queue_setup_scene()
			_queue_system_menu_scene()
			_queue_cpu_scene()
			return
		if _game == CPU_GAME and _scene.cpu_actions == _cpu_actions_before:
			_finish("autoplay: CPU の番を、CPU が進めなかった", 1)
			return
		_game += 1
		if _game >= STAGES.size() or not _full:
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


## スキルのボタンから、対象を選んで使う（盾を置く、聖域を置く、ファイアボールで敵を焼く）。選ぶのをやめる操作と、クールダウンが明けるまで。
func _queue_skill_scene() -> void:
	var board := _small_board(Vector2i(7, 5))
	var battle := Battle.new(board)
	var king1 := battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER1, Vector2i(0, 4))
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER2, Vector2i(6, 0))
	var trooper := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, Unit.Side.PLAYER1, Vector2i(2, 2))
	var priest := battle.add_unit(UnitKind.Id.PRIEST, Unit.Side.PLAYER1, Vector2i(1, 3))
	var sorcerer := battle.add_unit(UnitKind.Id.SORCERER, Unit.Side.PLAYER1, Vector2i(1, 1))
	var burned := battle.add_unit(UnitKind.Id.PALADIN, Unit.Side.PLAYER2, Vector2i(4, 1))
	var damaged: Script = SkillDamagedEvent
	var wall := Vector2i(3, 2)
	var center := Vector2i(1, 4)
	var used: Script = SkillUsedEvent
	var ready: Script = SkillReadyEvent

	_scripted.append(func() -> void:
		_scene.set_opponent(false)
		_scene.start_with(battle, BoardGenerator.Stage.PLAIN, 1))
	_scripted.append(func() -> void:
		_scene.click_cell(king1.cell)
		_expect(not _scene.is_skill_enabled(), "スキルの無い駒で、スキルのボタンが押せる")
		_scene.press_skill()
		_expect(not _scene.is_choosing_skill_target(), "スキルの無い駒で、対象を選び始めた")
		_scene.click_cell(trooper.cell))
	_scripted.append(func() -> void:
		_expect(_scene.is_skill_enabled(), "スキルのボタンが押せない")
		_scene.press_skill()
		_expect(_scene.is_choosing_skill_target(), "スキルの対象を選び始めなかった")
		# 対象でないマスを選ぶと、選ぶのをやめる（駒は動かない）。
		_scene.click_cell(Vector2i(5, 2))
		_expect(not _scene.is_choosing_skill_target() and _scene.selected_unit() == trooper, "対象でないマスで、やめなかった")
		_expect(trooper.cell == Vector2i(2, 2) and not trooper.has_moved, "スキルの対象を選ぶ途中のクリックで、駒が動いた")
		_scene.press_skill()
		_scene.cancel()
		_expect(not _scene.is_choosing_skill_target() and _scene.selected_unit() == trooper, "戻す操作で、やめなかった")
		_scene.press_skill()
		_scene.played.erase(used)
		_scene.click_cell(wall))
	_scripted.append(func() -> void:
		_expect(battle.board.barricade_at(wall) != null, "盾を置けなかった")
		_expect(trooper.acted and trooper.skill_cooldown > 0, "スキルを使っても、行動が終わっていない")
		_expect(_scene.played.get(used, 0) == 1, "スキルを再生しなかった")
		_scene.click_cell(trooper.cell)
		_expect(_scene.menu_ids().is_empty(), "行動済みの駒に、メニューが出ている")
		# 動いたあとでも使える。
		_scene.click_cell(priest.cell))
	_scripted.append(func() -> void: _scene.click_cell(Vector2i(2, 3)))
	_scripted.append(func() -> void:
		_scene.press_skill()
		_expect(_scene.is_choosing_skill_target(), "動いたあとに、スキルの対象を選べない")
		_scene.click_cell(center))
	_scripted.append(func() -> void:
		_expect(battle.board.field_effects.size() == 2, "聖域を置けなかった")
		_expect(priest.acted and priest.cell == Vector2i(2, 3), "聖域を置いても、行動が終わっていない")
		_scene.click_cell(sorcerer.cell))
	_scripted.append(func() -> void:
		_scene.press_skill()
		_expect(_scene.is_choosing_skill_target(), "ファイアボールの対象を選び始めなかった")
		_scene.played.erase(damaged)
		_scene.click_cell(burned.cell))
	_scripted.append(func() -> void:
		_expect(burned.hp == burned.max_hp() - FireballSkill.DAMAGE, "ファイアボールが当たらなかった")
		_expect(_scene.played.get(damaged, 0) == 1, "スキルのダメージを再生しなかった")
		_scene.played.erase(ready))
	_scripted.append(_end_turn)
	_scripted.append(_end_turn)
	_scripted.append(func() -> void:
		# 次の自分の番。クールダウンの間は、メニューのスキルの項目が押せず、残りが出る。
		_scene.click_cell(trooper.cell)
		_expect(trooper.skill_cooldown > 0 and not _scene.is_skill_enabled(), "クールダウンの間に、スキルの項目が押せる")
		_expect(_scene.skill_button_text().contains("あと"), "クールダウンの残りが出ていない")
		_expect(_scene.menu_ids() == ([&"skill", &"wait"] as Array[StringName]), "動く前のメニューの項目が違う: %s" % [_scene.menu_ids()]))
	for i in TacticalBarricadeSkill.COOLDOWN * 2 - 2:
		_scripted.append(_end_turn)
	_scripted.append(func() -> void:
		_expect(trooper.skill_cooldown == 0, "クールダウンが明けなかった")
		_expect(_scene.played.get(ready, 0) >= 1, "クールダウンが明けたことを再生しなかった")
		_scene.click_cell(trooper.cell))
	_scripted.append(func() -> void:
		_expect(_scene.is_skill_enabled(), "クールダウンが明けても、スキルのボタンが押せない"))


## 自分に使うスキルと、駒に付く状態。バリアを張って攻撃を防ぎ、構えて、次の番に伸びた射程からクリティカルを当てる。
func _queue_status_scene() -> void:
	var board := _small_board(Vector2i(9, 3))
	var battle := Battle.new(board)
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER1, Vector2i(0, 2))
	var king2 := battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER2, Vector2i(8, 0))
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, Unit.Side.PLAYER1, Vector2i(2, 1))
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, Unit.Side.PLAYER1, Vector2i(1, 0))
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, Unit.Side.PLAYER2, Vector2i(3, 1))
	var applied: Script = StatusAppliedEvent
	var removed: Script = StatusRemovedEvent

	_scripted.append(func() -> void:
		_scene.set_opponent(false)
		_scene.start_with(battle, BoardGenerator.Stage.PLAIN, 1))
	_scripted.append(func() -> void: _scene.click_cell(paladin.cell))
	_scripted.append(func() -> void:
		_scene.press_skill()
		_expect(_scene.is_choosing_skill_target(), "自分に使うスキルの対象を選び始めなかった")
		_scene.played.erase(applied)
		_scene.click_cell(paladin.cell))
	_scripted.append(func() -> void:
		_expect(Statuses.has(paladin, Status.Type.BARRIER) and paladin.acted, "バリアを張れなかった")
		_expect(_scene.played.get(applied, 0) == 1, "状態が付いたことを再生しなかった")
		_scene.click_cell(sniper.cell))
	_scripted.append(func() -> void:
		_scene.press_skill()
		_scene.click_cell(sniper.cell))
	_scripted.append(func() -> void:
		_expect(Statuses.has(sniper, Status.Type.AIM), "構えられなかった")
		_end_turn())
	_scripted.append(func() -> void: _scene.click_cell(commando.cell))
	_scripted.append(func() -> void:
		_scene.played.erase(removed)
		_scene.click_cell(paladin.cell))
	_scripted.append(func() -> void:
		_expect(paladin.hp == paladin.max_hp(), "バリアが攻撃を防がなかった")
		_expect(not Statuses.has(paladin, Status.Type.BARRIER), "バリアが残っている")
		_expect(_scene.played.get(removed, 0) == 1, "状態が外れたことを再生しなかった")
		_end_turn())
	_scripted.append(func() -> void: _scene.click_cell(sniper.cell))
	_scripted.append(func() -> void: _scene.click_cell(king2.cell))
	_scripted.append(func() -> void:
		var doubled := sniper.power() * PrecisionAimSkill.CRITICAL_PERCENT / 100
		_expect(king2.hp == king2.max_hp() - doubled, "伸びた射程からのクリティカルが当たらなかった")
		_expect(not Statuses.has(sniper, Status.Type.AIM), "照準が残っている"))


## 行動の流れを変えるスキル。シャドウステップで敵と入れ替わってから攻撃し、アドレナリン注射で、行動済みの駒をもう一度動かす。
func _queue_extra_action_scene() -> void:
	var board := _small_board(Vector2i(9, 4))
	var battle := Battle.new(board)
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER1, Vector2i(0, 3))
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER2, Vector2i(8, 0))
	var blade := battle.add_unit(UnitKind.Id.SPELLBLADE, Unit.Side.PLAYER1, Vector2i(2, 1))
	# 衛生兵は、入れ替わったあとのパラディンの支配領域を通らずに、スペルブレードの隣へ行ける位置に置く。
	var medic := battle.add_unit(UnitKind.Id.MEDIC, Unit.Side.PLAYER1, Vector2i(3, 3))
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, Unit.Side.PLAYER2, Vector2i(4, 1))
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, Unit.Side.PLAYER2, Vector2i(5, 1))
	var swapped: Script = UnitsSwappedEvent
	var teleported: Script = UnitTeleportedEvent
	var reactivated: Script = UnitReactivatedEvent

	_scripted.append(func() -> void:
		_scene.set_opponent(false)
		_scene.start_with(battle, BoardGenerator.Stage.PLAIN, 1))
	_scripted.append(func() -> void: _scene.click_cell(blade.cell))
	_scripted.append(func() -> void:
		_scene.press_skill()
		_expect(_scene.is_choosing_skill_target(), "シャドウステップの対象を選び始めなかった")
		_scene.click_cell(paladin.cell))
	_scripted.append(func() -> void:
		_expect(_scene.played.get(swapped, 0) == 1, "入れ替わりを再生しなかった")
		_expect(blade.cell == Vector2i(4, 1) and paladin.cell == Vector2i(2, 1), "入れ替わらなかった")
		_expect(not blade.acted and _scene.selected_unit() == blade, "跳んだあとに、続けて行動できない")
		_expect(not _scene.is_skill_enabled(), "跳んだあとに、スキルのボタンが押せる")
		# 戻す操作では、跳ぶ前には戻れない。
		_scene.cancel()
		_expect(blade.cell == Vector2i(4, 1) and _scene.selected_unit() == blade, "跳んだあとに、取り消せた")
		_expect(not _scene.menu_ids().has(&"undo"), "跳んだあとのメニューに、取り消しが出ている")
		# メニューの「攻撃」から相手を選ぶ。選ぶ途中は「やめる」だけが出て、相手でないマスではやめる。
		_expect(_scene.press_menu(&"attack") and _scene.is_choosing_target(), "メニューの攻撃で、相手を選び始めなかった")
		_expect(_scene.menu_ids() == ([&"back"] as Array[StringName]), "相手を選ぶ途中のメニューが違う")
		_scene.click_cell(Vector2i(8, 3))
		_expect(not _scene.is_choosing_target() and _scene.selected_unit() == blade and not blade.acted, "相手でないマスで、やめなかった")
		_scene.press_menu(&"attack")
		_scene.click_cell(sniper.cell))
	_scripted.append(func() -> void:
		_expect(sniper.hp < sniper.max_hp() or battle.unit_by_id(sniper.id) == null, "跳んだあとに、攻撃できなかった")
		_expect(blade.acted, "攻撃しても、行動が終わっていない")
		_scene.click_cell(medic.cell))
	_scripted.append(func() -> void: _scene.click_cell(Vector2i(4, 2)))
	_scripted.append(func() -> void:
		_expect(_scene.skill_button_text().contains("あと %d 回" % AdrenalineShotSkill.MAX_USES), "残りの回数が出ていない")
		_scene.press_skill()
		_scene.click_cell(blade.cell))
	_scripted.append(func() -> void:
		_expect(_scene.played.get(reactivated, 0) == 1, "もう一度行動できることを再生しなかった")
		_expect(medic.acted and not blade.acted, "アドレナリン注射で、行動前に戻らなかった")
		_scene.click_cell(blade.cell))
	_scripted.append(func() -> void: _scene.click_cell(Vector2i(4, 0)))
	_scripted.append(func() -> void:
		_expect(blade.cell == Vector2i(4, 0), "もう一度の行動で、動けなかった")
		_scene.press_wait())
	_scripted.append(func() -> void:
		_expect(blade.acted, "もう一度の行動が終わらなかった")
		_end_turn())
	_scripted.append(_end_turn)
	for i in ShadowStepSkill.COOLDOWN * 2 - 2:
		_scripted.append(_end_turn)
	_scripted.append(func() -> void: _scene.click_cell(blade.cell))
	_scripted.append(func() -> void:
		_expect(blade.power() == UnitKind.power(UnitKind.Id.SPELLBLADE), "反動が消えていない")
		_scene.press_skill()
		_scene.click_cell(Vector2i(4, 3)))
	_scripted.append(func() -> void:
		_expect(_scene.played.get(teleported, 0) == 1, "跳んだことを再生しなかった")
		_expect(blade.cell == Vector2i(4, 3), "空いたマスへ跳べなかった"))


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

	_scripted.append(func() -> void:
		_scene.start_with(battle, BoardGenerator.Stage.PLAIN, 1)
		_scene.camera_follows.clear())
	_scripted.append(_end_turn)
	_scripted.append(_end_turn)
	_scripted.append(func() -> void:
		var core := battle.unit_at(font)
		_expect(core != null and core.side == Unit.Side.NEUTRAL, "結晶泉にエナジー・コアが湧かなかった")
		_expect(_scene.camera_follows.is_empty(), "湧いただけの中立の駒を、カメラが追った"))
	_scripted.append(_end_turn)
	_scripted.append(_end_turn)
	_scripted.append(func() -> void:
		_expect(bait.hp == bait.max_hp() - UnitKind.power(UnitKind.Id.MINION), "エナジー・コアが攻撃しなかった")
		# 攻撃しに歩いた中立の駒は、カメラが追いかける（湧いただけのときは、追わない）。
		var followed := false
		for unit in battle.units:
			followed = followed or (unit.side == Unit.Side.NEUTRAL and _scene.camera_follows.has(unit.id))
		_expect(followed, "攻撃しに歩いた中立の駒を、カメラが追わなかった"))


## 中ボスが現れ、弱った別の中ボスに止めを刺すと、倒した陣営が知らされ、その陣営が聖遺物を受け取る。
func _queue_mid_boss_scene() -> void:
	var board := _small_board(Vector2i(8, 5))
	board.mid_boss_cells = [Vector2i(2, 2), Vector2i(6, 2)]
	var battle := Battle.new(board)
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER1, Vector2i(0, 4))
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER2, Vector2i(7, 0))
	var weak := battle.add_unit(UnitKind.Id.ELITE_MINION, Unit.Side.NEUTRAL, board.mid_boss_cells[0])
	weak.home_cell = weak.cell
	weak.hp = 1
	var raider := battle.add_unit(UnitKind.Id.COMMANDO, Unit.Side.PLAYER1, Vector2i(2, 4))
	var raider_max_hp := raider.max_hp()

	_scripted.append(func() -> void: _scene.start_with(battle, BoardGenerator.Stage.PLAIN, 1))
	_scripted.append(func() -> void: _scene.click_cell(raider.cell))
	_scripted.append(func() -> void: _scene.click_cell(Vector2i(2, 3)))
	_scripted.append(func() -> void: _scene.click_cell(weak.cell))
	_scripted.append(func() -> void:
		_expect(_scene.played.get(MidBossDefeatedEvent, 0) == 1, "中ボスを倒したことを再生しなかった")
		_expect(battle.mid_boss_slayers.get(0, -1) == Unit.Side.PLAYER1, "倒した陣営が控えられていない")
		_expect(_scene.played.get(RelicGainedEvent, 0) == 1, "聖遺物を受け取ったことを再生しなかった")
		_expect(_scene.relic_text(0) == "英知" and _scene.relic_text(1) == "", "上の帯に聖遺物が出ていない")
		_expect(raider.max_hp() == raider_max_hp + Relics.WISDOM_MAX_HP, "英知の聖遺物が効いていない")
		_expect(_scene.view_hps()[raider.id] == raider.hp, "聖遺物で増えた HP が、駒の札に出ていない"))
	_scripted.append(_end_turn)
	_scripted.append(_end_turn)
	_scripted.append(func() -> void:
		var boss := battle.unit_at(board.mid_boss_cells[1])
		_expect(boss != null and boss.kind == UnitKind.Id.ELITE_MINION, "中ボスが現れなかった")
		_expect(battle.unit_at(board.mid_boss_cells[0]) == null, "倒れた中ボスがまた現れた"))


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
	_scripted.append(func() -> void:
		# 駒のいないマスをクリックすると、そのマスの情報が出る。戻す操作で消える。
		_scene.click_cell(Vector2i(5, 3))
		_expect(_scene.selected_unit() == null and _scene.info_title().begins_with("マス (5, 3)"), "マスの情報が出ていない")
		_scene.cancel()
		_expect(_scene.info_title() == "", "戻す操作で、マスの情報が消えなかった")
		_check_drag(Vector2i(5, 3))
		_scene.click_cell(medic.cell))
	_scripted.append(func() -> void:
		_expect(Queries.heal_targets(battle, medic).is_empty(), "届かない味方を回復できることになっている")
		_expect(not _scene.menu_ids().has(&"heal"), "回復できないのに、メニューに回復が出ている")
		_scene.click_cell(Vector2i(3, 1)))
	_scripted.append(func() -> void:
		_expect(Queries.heal_targets(battle, medic) == ([wounded] as Array[Unit]), "回復できる味方が違う")
		# 動いたあとに相手を切り替えても、その駒を選んだままで、続きができる。
		_scene.set_opponent(true)
		_expect(_scene.selected_unit() == medic, "相手を切り替えたら、動いたあとの駒の選択が外れた")
		_scene.set_opponent(false)
		_scene.played.erase(healed)
		_expect(_scene.menu_ids() == ([&"heal", &"skill", &"wait", &"undo"] as Array[StringName]), "動いたあとのメニューの項目が違う: %s" % [_scene.menu_ids()])
		# スキルの説明は、駒の情報にいつも出ている。メニューの項目にマウスを乗せると、押すと何が起きるかが出る。
		var skill := Skills.of(medic)
		_expect(_scene.info_text().replace("\n", "").contains(skill.summary()), "駒の情報に、スキルの説明が出ていない")
		_scene._on_menu_hovered(&"wait")
		_expect(_scene.info_text().contains("待機"), "メニューの項目の説明が出ていない")
		_scene._on_menu_hovered(&"")
		_expect(not _scene.info_text().contains("待機:"), "マウスが離れても、項目の説明が残っている")
		_expect(_scene.press_menu(&"heal") and _scene.is_choosing_target(), "メニューの回復で、相手を選び始めなかった")
		_scene.click_cell(wounded.cell))
	_scripted.append(func() -> void:
		_expect(wounded.hp == 10 + medic.power(), "回復しなかった")
		_expect(medic.acted, "回復しても行動が終わっていない")
		_expect(_scene.played.get(healed, 0) == 1, "回復を再生しなかった"))


## 対戦の設定画面で、後手を選んで CPU と対戦する（CPU が先手で動き出す）。軍とステージも選んだとおりになる。
## 最後に、既定の設定（人が先手）へ戻す。
func _queue_setup_scene() -> void:
	var seen := {"actions": 0}
	_scripted.append(func() -> void:
		_scene.set_opponent(false)
		_scene.open_setup()
		var panel: Node = _scene.setup_panel()
		_expect(panel.visible and _scene.is_busy(), "設定画面が開かない")
		panel.choose_opponent(true)
		panel.choose_human_side(Unit.Side.PLAYER2)
		panel.choose_army(Unit.Side.PLAYER1, UnitKind.Army.FANTASY)
		panel.choose_army(Unit.Side.PLAYER2, UnitKind.Army.MILITARY)
		panel.choose_stage(BoardGenerator.Stage.TWIN_SPRINGS)
		seen["actions"] = _scene.cpu_actions
		panel.confirm()
		# CPU（先手）の番の間も、必殺技のボタンは人（後手。MILITARY）のもの。
		_expect(_scene.ult_button_text().contains(Ults.of_army(UnitKind.Army.MILITARY).display_name()), "CPU の番に、必殺技のボタンが CPU のものになった: %s" % _scene.ult_button_text()))
	_scripted.append(func() -> void:
		var battle: Battle = _scene.battle
		_expect(not _scene.setup_panel().visible, "設定画面が閉じない")
		_expect(_scene.stage == BoardGenerator.Stage.TWIN_SPRINGS, "選んだステージで始まらない")
		_expect(battle.armies == ([UnitKind.Army.FANTASY, UnitKind.Army.MILITARY] as Array[UnitKind.Army]), "選んだ軍で始まらない")
		_expect(_scene.cpu_actions > seen["actions"], "先手の CPU が動かなかった")
		_expect(battle.phase == Unit.Side.PLAYER2 and battle.turn == 1, "先手の CPU が番を終えなかった")
		var panel: Node = _scene.setup_panel()
		# 設定画面を開いて、選び直してから閉じても、いまの対戦と設定はそのまま（始めるボタンを押すまで、何も変わらない）。
		_scene.open_setup()
		_expect(panel.visible and panel.is_cancellable(), "対戦の途中の設定画面を、閉じられない")
		panel.choose_stage(BoardGenerator.Stage.LABYRINTH)
		panel.choose_opponent(false)
		panel.cancel()
		_expect(not panel.visible and not _scene.is_busy(), "設定画面が閉じない")
		_expect(_scene.battle == battle and _scene.stage == BoardGenerator.Stage.TWIN_SPRINGS and _scene.cpu_opponent, "設定画面を閉じたら、対戦か設定が変わった")
		_scene.open_setup()
		panel.choose_opponent(false)
		panel.choose_human_side(Unit.Side.PLAYER1)
		panel.choose_army(Unit.Side.PLAYER1, UnitKind.Army.MILITARY)
		panel.choose_army(Unit.Side.PLAYER2, UnitKind.Army.FANTASY)
		panel.choose_stage(BoardGenerator.Stage.PLAIN)
		panel.confirm()
		_expect(not _scene.cpu_opponent and _scene.match_choice.cpu_side() == Unit.Side.PLAYER2, "既定の設定に戻らない"))


## システムメニュー。Esc は、戻すもの（選択）があれば戻し、無ければメニューを開く。開いている間は盤面を操作できず、時間が止まる。
## 設定の画面で変えた値は、その場でカメラに効く。ゲームを終える項目は、対戦の途中なら確かめる（ここでは、やめる）。
func _queue_system_menu_scene() -> void:
	var board := _small_board(Vector2i(6, 5))
	var battle := Battle.new(board)
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER1, Vector2i(0, 4))
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER2, Vector2i(5, 0))
	var trooper := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, Unit.Side.PLAYER1, Vector2i(2, 2))
	_scripted.append(func() -> void:
		_scene.set_opponent(false)
		_scene.start_with(battle, BoardGenerator.Stage.PLAIN, 1))
	_scripted.append(func() -> void:
		var menu: Node = _scene.system_menu()
		var settings: RefCounted = _scene.settings
		var base := Engine.time_scale
		_scene.click_cell(trooper.cell)
		_scene.press_escape()
		_expect(not menu.is_open() and _scene.selected_unit() == null, "選んでいる駒があるのに、Esc で選択をやめずにメニューを開いた")
		_scene.press_escape()
		_expect(menu.is_open() and _scene.is_busy() and Engine.time_scale == 0.0, "戻すものが無いのに、Esc でメニューが開かない（か、止まらない）")
		_expect(menu.item_ids() == ([&"resume", &"settings", &"match_setup", &"quit"] as Array[StringName]), "メニューの項目が違う: %s" % [menu.item_ids()])
		_scene.click_cell(trooper.cell)
		_expect(_scene.selected_unit() == null, "メニューを開いている間に、駒を選べた")
		# 対戦が失われる項目は、確かめる。「やめる」で、メニューへ戻る。
		menu.press(&"quit")
		_expect(menu.confirming() == &"quit" and menu.confirm_text() != "", "ゲームを終える前に、確かめない")
		menu.back()
		_expect(menu.is_open() and menu.confirming() == &"", "確かめを、やめられない")
		# 設定の値は、その場で効く。
		menu.press(&"settings")
		_expect(menu.is_settings_open(), "設定の画面が開かない")
		settings.set_value(&"mouse_sensitivity", 200)
		settings.set_value(&"invert_vertical_drag", true)
		var rig: Node = _scene._rig
		_expect(is_equal_approx(rig.drag_sensitivity, 2.0 * rig.DEFAULT_DRAG_SENSITIVITY) and rig.invert_vertical, "設定の値がカメラに効かない")
		settings.reset_all()
		_expect(is_equal_approx(rig.drag_sensitivity, rig.DEFAULT_DRAG_SENSITIVITY) and not rig.invert_vertical, "既定に戻せない")
		menu.back()
		_expect(menu.is_open() and not menu.is_settings_open(), "設定の画面から、メニューへ戻らない")
		menu.back()
		_expect(not menu.is_open() and not _scene.is_busy() and Engine.time_scale == base, "メニューを閉じても、元の速さに戻らない")
		# CPU の駒の行動を再生する間だけ、設定の速さを掛ける。
		settings.set_value(&"cpu_playback_speed", 3)
		_scene._set_cpu_fast(true)
		_expect(is_equal_approx(Engine.time_scale, base * 3.0), "CPU の番の速さが効かない")
		_scene._set_cpu_fast(false)
		settings.reset_all()
		_expect(Engine.time_scale == base, "CPU の番の速さが残った"))


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
		_scene.camera_follows.clear()
		_end_turn()
		# CPU の番の間は、操作を受け付けない。
		_scene.click_cell(sorcerer.cell)
		_expect(_scene.selected_unit() == null, "CPU の番に駒を選べた")
		_scene.press_end_turn()
		# 相手の番の途中でもシステムメニューは開け、開いている間は止まる（閉じると続きから進む）。
		_scene.press_escape()
		_expect(_scene.system_menu().is_open() and Engine.time_scale == 0.0, "相手の番の途中に、システムメニューで止まらない")
		seen["paused"] = _scene.cpu_actions
		get_tree().create_timer(0.3, true, false, true).timeout.connect(func() -> void:
			_expect(_scene.cpu_actions == seen["paused"] and battle.phase != Unit.Side.PLAYER1, "システムメニューを開いている間に、相手の番が進んだ")
			_scene.system_menu().close()))
	_scripted.append(func() -> void:
		_expect(battle.turn == 2 and battle.phase == Unit.Side.PLAYER1, "CPU が自分の番を終えなかった")
		_expect(_scene.cpu_actions > seen["actions"], "CPU が行動しなかった")
		_expect(wounded.hp == 10 + priest.power(), "CPU の回復役が回復しなかった")
		_expect(bait.hp < bait.max_hp(), "CPU の駒が攻撃しなかった")
		# CPU の駒が歩く間は、カメラが追いかける（自分で動かした駒は追わない）。
		var followed := 0
		for unit_id: int in _scene.camera_follows:
			var unit := battle.unit_by_id(unit_id)
			_expect(unit == null or unit.side == Unit.Side.PLAYER2, "CPU のものでない駒を、カメラが追った")
			followed += 1
		_expect(followed > 0, "CPU の駒が歩く間、カメラが追わなかった")
		_scene.set_opponent(false))


## 必殺技。ゲージがいっぱいになるまでボタンは押せず、1 回目は確かめるだけで、もう一度押すと使う。使っても駒の行動は残る。
func _queue_ult_scene() -> void:
	var board := _small_board(Vector2i(7, 5))
	var battle := Battle.new(board)
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER1, Vector2i(0, 4))
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER2, Vector2i(6, 0))
	var trooper := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, Unit.Side.PLAYER1, Vector2i(1, 3))
	var sorcerer := battle.add_unit(UnitKind.Id.SORCERER, Unit.Side.PLAYER2, Vector2i(5, 1))
	sorcerer.skill_cooldown = 4
	var used: Script = UltUsedEvent
	var ready: Script = UltReadyEvent
	var power := trooper.power()

	_scripted.append(func() -> void:
		_scene.set_opponent(false)
		_scene.start_with(battle, BoardGenerator.Stage.PLAIN, 1))
	_scripted.append(func() -> void:
		_expect(not _scene.is_ult_enabled(), "ゲージが空なのに、必殺技のボタンが押せる")
		_expect(_scene.ult_gauge_text(0) == "0%", "ゲージの数字が出ていない")
		_scene.press_ult()
		_expect(not _scene.is_confirming_ult(), "ゲージが空なのに、必殺技を確かめ始めた")
		battle.ult_gauge[Unit.Side.PLAYER1] = Ults.GAUGE_MAX
		_scene.click_cell(trooper.cell))
	_scripted.append(func() -> void:
		_expect(_scene.is_ult_enabled(), "ゲージがいっぱいなのに、必殺技のボタンが押せない")
		_expect(_scene.ult_gauge_text(0) == "READY", "ゲージが READY になっていない")
		_scene.press_ult()
		_expect(_scene.is_confirming_ult() and battle.ult_uses[0] == 0, "1 回押しただけで、必殺技を使った")
		_scene.cancel()
		_expect(not _scene.is_confirming_ult() and _scene.selected_unit() == trooper, "戻す操作で、確かめるのをやめなかった")
		# 盤面のクリックでやめると、やめるだけ（そのクリックで動かない）。
		_scene.press_ult()
		_scene.click_cell(trooper.cell + Vector2i(1, 0))
		_expect(not _scene.is_confirming_ult(), "盤面のクリックで、確かめるのをやめなかった")
		_expect(trooper.cell == Vector2i(1, 3) and not trooper.has_moved, "確かめるのをやめるクリックで、駒が動いた")
		_expect(_scene.selected_unit() == trooper, "確かめるのをやめるクリックで、選択が変わった")
		_scene.press_ult()
		_scene.played.erase(used)
		_scene.press_ult())
	_scripted.append(func() -> void:
		_expect(battle.ult_uses[0] == 1 and battle.ult_gauge[0] == 0, "必殺技を使えなかった")
		_expect(_scene.played.get(used, 0) == 1, "必殺技を再生しなかった")
		_expect(trooper.power() == power + AllOutAssaultUlt.POWER_BONUS, "総員突撃が付いていない")
		_expect(not _scene.is_ult_enabled() and _scene.ult_gauge_text(0) == "0%", "使ったあとに、ゲージが空になっていない")
		_expect(_scene.selected_unit() == trooper and not trooper.acted, "必殺技で、駒の行動を使った")
		# 伸びた移動力（3 + 2）で動ける。
		_scene.click_cell(Vector2i(6, 3)))
	_scripted.append(func() -> void:
		_expect(trooper.cell == Vector2i(6, 3), "伸びた移動力で動けなかった")
		_scene.press_wait())
	_scripted.append(func() -> void:
		battle.ult_gauge[Unit.Side.PLAYER2] = Ults.GAUGE_MAX - 1
		_scene.played.erase(ready)
		_end_turn())
	_scripted.append(func() -> void:
		_expect(_scene.played.get(ready, 0) == 1, "ゲージがいっぱいになったことを再生しなかった")
		_expect(_scene.ult_gauge_text(1) == "READY" and _scene.is_ult_enabled(), "プレイヤー2 の番に、必殺技のボタンが押せない")
		_scene.press_ult()
		_scene.press_ult())
	_scripted.append(func() -> void:
		_expect(sorcerer.skill_cooldown == 0, "魔力解放でクールダウンが 0 にならなかった"))


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
	_scene._unhandled_input(motion)


func _mouse_button(at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = at
	_scene._unhandled_input(event)


func _finish(message: String, code: int) -> void:
	_finished = true
	print(message)
	get_tree().quit(code)
