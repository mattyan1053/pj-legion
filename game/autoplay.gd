extends Node
## 検査用の自動対戦。`-- --autoplay` を付けて起動すると、人の代わりに画面を操作する。
##
## 人と同じ入口（マスを選ぶ・待機・戻す・ターン終了・進化先を選ぶ）だけを使う。回すのは SCENES の場面で、
## 対戦を最後まで進める場面（game）と、小さな盤面で決まった手順を通す場面（環境オブジェクト、盤の上の効果、スキル、必殺技、
## 中立の駒、レベルアップ、進化、回復、閲覧、対戦の設定、システムメニュー、CPU の番）、最後にタイトルと部隊の編成の場面を通す場面。
## 長い検査（`-- --autoplay --full`）では、game のあとに盤面を作り直して、ほかのステージも少し動かす（そのうち 1 戦は、相手を CPU にする）。
##
## `-- --autoplay --only <名前,…>` で、選んだ場面だけを回す（名前は SCENES の名前か、GROUPS のまとまりの名前）。
## 場面の中で確かめたことが外れたら、その場面の残りを飛ばして次の場面へ進み、最後にまとめて失敗にする。
## イベントを再生する場面（GROUPS の events）を全部回したときは、どの種類のイベントも 1 回は再生したことを確かめる。
## 全部が通れば "autoplay: OK" を出して終わる（tools/check.sh がこの行を確かめる）。

const SceneFlow := preload("res://game/scene_flow.gd")
const Queries := preload("res://game/battle_queries.gd")
const Story := preload("res://game/story.gd")
const BattleCues := preload("res://game/battle_cues.gd")
const BattlePlayback := preload("res://game/battle_playback.gd")
const OrbitCamera := preload("res://game/orbit_camera.gd")
const StageLook := preload("res://game/stage_look.gd")
const VersusFields := preload("res://game/versus_fields.gd")
const NO_CELL := Vector2i(-1, -1)

## 場面の名前 -> 説明（回す順）。決まった手順の場面は、同じ名前の _queue_<名前>_scene() が手順を積む。
const BattleHud := preload("res://game/battle_hud.gd")
const BattleTexts := preload("res://game/battle_texts.gd")
const ResultSummary := preload("res://game/result_summary.gd")

const SCENES := {
	"game": "人の操作で、対戦を最後まで進める（決着と戦績とログ）",
	"result": "リザルトの画面（game の決着のあと）",
	"portal_and_spring": "ポータルに止まってメニューの「転移」、ふさがったポータル、ポータルを通る移動と取り消し、回復の泉",
	"capture": "敵の本陣の占拠",
	"barrel_draw": "樽の爆発で両方の将が倒れて引き分け",
	"field_effect": "盤の上の効果（盾・煙幕・聖域）",
	"skill": "スキルのボタンと対象選び、クールダウン",
	"status": "自分に使うスキルと、駒に付く状態",
	"extra_action": "行動を終えないスキルと、行動済みの駒を戻すスキル",
	"ult": "必殺技",
	"neutral": "中立の駒（湧く、攻撃する、カメラが追う）",
	"mid_boss": "中ボスと聖遺物",
	"level_up": "レベルアップ",
	"evolution": "進化",
	"heal": "回復役の回復、マスの情報、クリックとドラッグ",
	"inspection": "閲覧（行動の途中に相手の駒を見る）と、敵の全員の脅威範囲、相手の駒の範囲を表示したまま（ピン留め）",
	"setup": "対戦の設定画面（後手で CPU と対戦する）",
	"system_menu": "システムメニューと設定の画面",
	"minimap": "ミニマップ（押す・ドラッグで視点が移る、設定で隠す）",
	"cpu": "CPU の番（止める、ログ、カメラが追う）",
	"auto_turn": "自分の番のおまかせ（1 回目は確かめるだけ。2 回目で、残りの駒を CPU が動かしてターンを終える）",
	"cpu_skip": "相手（CPU）の番の早送りとスキップ（中立のフェーズから。途中で決着したら、決着を見せる）",
	"title": "相手の番の途中でタイトルへ戻り、ステージ選択と対戦の設定を行き来する",
	"decks": "部隊の編成",
	"story": "ストーリーの 1 話の通し（タイトル → 物語を選ぶ → 話の一覧 → 会話 → 出撃の準備 → 対戦 → 勝って「次へ」「部隊を選び直す」→ 会話 → 話の一覧 → 物語を選ぶ → タイトル、クリアの記録）",
}
## まとめて選べる名前。tools/check.sh は、この 2 つを別のプロセスで並べて回す。
## events はイベントを再生する場面（全部を回すと、全種類のイベントを 1 回は再生したかを確かめる）。ui は操作の決まりを確かめる場面。
const GROUPS := {
	"events": ["game", "result", "portal_and_spring", "capture", "barrel_draw", "field_effect", "skill", "status", "extra_action",
		"ult", "neutral", "mid_boss", "level_up", "evolution", "heal", "cpu_skip", "auto_turn"],
	"ui": ["inspection", "setup", "system_menu", "minimap", "cpu", "title", "decks", "story"],
}

## これだけターンが進んでも決着しなければ、失敗にする。
const MAX_TURNS := 80
## 2 戦目からは、このターンまで動かしたら次へ進む。
const SHORT_GAME_TURNS := 2
## この番号の対戦は、相手（プレイヤー2）を CPU にする。
const CPU_GAME := 1
const STAGES: Array[StringName] = [VersusFields.PLAIN, VersusFields.TWIN_SPRINGS, VersusFields.LABYRINTH]

enum Phase { GAME, SCENES, STAGES, END }

var _scene: Node
## 長い検査（`--full`）のときだけ、ほかのステージも動かす。
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
## 最後に、対戦の場面を抜けて、タイトルと対戦の設定の場面を通している途中か（_leave_battle）。
var _leaving := false


func _init(scene: Node) -> void:
	_scene = scene
	# 再生の待ち時間を縮めて、検査を短く済ませる（CI は 1 分以内に収める）。
	scene.set_time_scale_base(8.0)
	_selected = _choose_scenes(OS.get_cmdline_user_args())


## 回す場面を、引数の `--only <名前,…>` から決める（無ければ全部）。知らない名前があれば空にして、_ready で失敗にする。
static func _choose_scenes(args: PackedStringArray) -> Array[String]:
	var at := args.find("--only")
	var wanted: Array = SCENES.keys()
	if at >= 0:
		wanted = []
		for name: String in (args[at + 1] if at + 1 < args.size() else "").split(",", false):
			if GROUPS.has(name):
				wanted.append_array(GROUPS[name])
			elif SCENES.has(name):
				wanted.append(name)
			else:
				return []
		if wanted.has("result") and not wanted.has("game"):
			wanted.append("game")  # リザルトは、対戦の決着のあと
	var result: Array[String] = []
	for name: String in SCENES:
		if wanted.has(name):
			result.append(name)
	return result


func _ready() -> void:
	var screen := get_viewport().get_visible_rect().size
	print("autoplay: 画面 %dx%d" % [screen.x, screen.y])
	if _selected.is_empty():
		_finish("autoplay: --only に知らない名前がある（場面: %s、まとまり: %s）" % [", ".join(SCENES.keys()), ", ".join(GROUPS.keys())], 1)
	elif not _selected.has("game"):
		_queue_scenes()


func _process(_delta: float) -> void:
	if _finished or _leaving or _scene.is_busy():
		return
	var battle: Battle = _scene.battle
	if _phase != Phase.END and (_phase != Phase.SCENES or not _scripted.is_empty()) and not _failed_scenes.has(_current):
		var problem := _mismatch(battle)
		if problem == "":
			problem = _menu_problem()
		if problem != "":
			_fail("画面と状態が食い違った: %s" % problem)
			return

	match _phase:
		Phase.GAME:
			if _failed_scenes.has("game"):
				_queue_scenes()  # 最初の対戦で外れたら、対戦はやめて場面へ進む
			elif battle.is_over():
				_end_game(battle)
			elif battle.turn > MAX_TURNS:
				_fail("%d ターンでも決着しなかった" % MAX_TURNS)
			else:
				_step(battle)
		Phase.SCENES:
			if not _scripted.is_empty():
				_current = _scripted_names.pop_front()
				var step: Callable = _scripted.pop_front()
				step.call()
				return
			_phase = Phase.STAGES if _full and _selected.has("game") and not _failed_scenes.has("game") else Phase.END
			_current = "stages"
		Phase.STAGES:
			if _game == 0 or battle.is_over() or battle.turn >= SHORT_GAME_TURNS:
				if _game == CPU_GAME and _scene.cpu_actions == _cpu_actions_before:
					_fail("CPU の番を、CPU が進めなかった")
				_game += 1
				if _game >= STAGES.size():
					_phase = Phase.END
					return
				_undone.clear()
				_cpu_actions_before = _scene.cpu_actions
				_scene.set_opponent(_game == CPU_GAME)
				_scene.start_on_field(STAGES[_game], _scene.map_seed + 1)
			elif battle.turn > MAX_TURNS:
				_fail("%d ターンでも決着しなかった" % MAX_TURNS)
				_phase = Phase.END
			else:
				_step(battle)
		Phase.END:
			_end()


## 最初の対戦（game）の決着を確かめ、決まった手順の場面を積む。
func _end_game(battle: Battle) -> void:
	if battle.is_over():
		print("autoplay: ターン %d で決着（勝者 %d）" % [battle.turn, battle.winner])
		var stats: BattleStats = _scene.stats
		_expect(stats.is_over() and stats.turns == battle.turn and stats.winner == battle.winner, "戦績が決着と食い違った")
		_expect(_scene.result_stats().contains("与えたダメージ"), "決着の画面に戦績が出ていない")
		var last: String = _scene.battle_log.entries[-1].text
		_expect(last.contains("の勝ち") or last.begins_with("引き分け"), "ログが決着の行で終わっていない: %s" % last)
		print(_scene.result_stats())
	_queue_scenes()


func _queue_scenes() -> void:
	_phase = Phase.SCENES
	var current := _current
	for name in _selected:
		if name == "game" or name == "title" or name == "decks" or name == "story":
			continue
		if name == "result" and not _scene.battle.is_over():
			_failures.append("result: 対戦が決着しなかったので、リザルトを確かめられなかった")
			continue
		_current = name
		call("_queue_%s_scene" % name)
		while _scripted_names.size() < _scripted.size():
			_scripted_names.append(name)
	_current = current


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


## 場面を回し終えたあと: イベントの再生を確かめ、タイトルと部隊の編成の場面を通して終える。
func _end() -> void:
	_leaving = true
	var all_events := true
	for name: String in GROUPS["events"]:
		all_events = all_events and _selected.has(name)
	if all_events:
		_current = "events"
		var players: Dictionary = BattlePlayback.event_players()
		for kind: Script in players:
			if _scene.played.get(kind, 0) == 0:
				_fail("1 回も再生しなかったイベント: %s" % kind.resource_path)
	var app := _scene.get_parent()
	if (_selected.has("title") or _selected.has("decks") or _selected.has("story")) and app.has_method(&"go"):
		reparent(app)  # このノードは対戦の場面の子なので、場面が消える前にアプリの子へ移る
		if _selected.has("title"):
			_current = "title"
			await _leave_battle(app)
		if _selected.has("decks"):
			_current = "decks"
			if app.current_id() != SceneFlow.TITLE:
				await app.go(SceneFlow.TITLE)
			await _visit_decks(app)
		if _selected.has("story"):
			_current = "story"
			if app.current_id() != SceneFlow.TITLE:
				await app.go(SceneFlow.TITLE)
			await _visit_story(app)
		await _nudge_screen_size()
	if _failures.is_empty():
		_finish("autoplay: OK", 0)
	else:
		_finish("autoplay: 失敗した場面がある（%d 件）:\n  %s" % [_failures.size(), "\n  ".join(_failures)], 1)


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
		# 未行動の駒を残したままのターン終了は、1 回目では終わらない。素早い 2 回目（ダブルクリック・連打）でも終わらない。
		_confirm_tested = true
		_scene.press_end_turn()
		_scene.press_end_turn()
		if battle.turn != 2 or battle.phase != unit.side:
			_fail("確かめずにターンが終わった（素早い 2 回押しで、確かめを飛ばした）")
		elif not _scene.is_confirming_end():
			_fail("未行動の駒が残っているのに、ターン終了を確かめない")
		else:
			_scene.cancel()
			if _scene.is_confirming_end():
				_fail("戻す操作で、ターン終了の確かめをやめなかった")
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
	board.add_portal_pair(Vector2i(1, 3), Vector2i(9, 3))
	var blocked_walker := battle.add_unit(UnitKind.Id.SNIPER, Unit.Side.PLAYER1, Vector2i(0, 3))
	battle.add_unit(UnitKind.Id.SNIPER, Unit.Side.PLAYER1, Vector2i(9, 3))  # 行き先のポータルをふさぐ
	var far := Vector2i(10, 1)  # 歩けば 10 マス。ポータルを通れば移動力 3 で届く。
	var warped: Script = UnitWarpedEvent
	var moved: Script = UnitMovedEvent

	_scripted.append(func() -> void: _scene.start_with(battle, StageLook.CRYSTAL_FOREST, 1))
	# 人の操作のとおり（マウスで駒を選び、ポータルのマスをクリック）: ポータルに止まり、メニューの「転移」で対のポータルへ移る。
	_scripted.append(func() -> void: _click(walker.cell))
	_scripted.append(func() -> void:
		_expect(not _scene.menu_covers_move(), "動く前のメニューが、届くマスを隠した（小さな盤で、外へ出せるのに）")
		var portal_color: Color = _scene.portal_paint_color(Vector2i(1, 1))
		_expect(_scene.painted_color(Vector2i(1, 1)) == portal_color and _scene.painted_color(Vector2i(8, 1)) == portal_color,
			"動ける範囲の塗りに、ポータルの対（入る・出る）が出ていない")
		_click(Vector2i(1, 1)))
	_scripted.append(func() -> void:
		_expect(walker.cell == Vector2i(1, 1), "ポータルのマスに止まらなかった")
		_expect(_scene.menu_ids().has(BattleTexts.MENU_WARP), "ポータルに止まっても、メニューに「転移」が出ない")
		_expect(_scene.painted_color(Vector2i(8, 1)) == _scene.portal_paint_color(Vector2i(1, 1)), "転移の行き先を塗っていない")
		_scene.played.erase(warped)
		_expect(_scene.press_menu(BattleTexts.MENU_WARP), "「転移」を押せない"))
	_scripted.append(func() -> void:
		_expect(walker.cell == Vector2i(8, 1) and _scene.selected_unit() == walker, "「転移」で対のポータルへ移らなかった")
		_expect(_scene.played.get(warped, 0) == 1, "転移を再生しなかった")
		var last: String = _scene.battle_log.entries[-1].text
		_expect(last.contains("(0, 1) → (8, 1)") and last.contains("ポータル経由"), "ログが、ポータル経由の移動 1 行になっていない: " + last)
		_expect(not _scene.menu_ids().has(BattleTexts.MENU_WARP), "転移したあとも「転移」が出ている")
		_scene.cancel())
	_scripted.append(func() -> void:
		_expect(walker.cell == Vector2i(0, 1), "転移を取り消して、動く前のマスへ戻らなかった")
		# 行き先がふさがっているポータル: 止まれるが、「転移」は出ない。
		_click(blocked_walker.cell))
	_scripted.append(func() -> void: _click(Vector2i(1, 3)))
	_scripted.append(func() -> void:
		_expect(blocked_walker.cell == Vector2i(1, 3), "ふさがっているポータルのマスに止まれなかった")
		_expect(not _scene.menu_ids().has(BattleTexts.MENU_WARP), "行き先がふさがっているのに「転移」が出た")
		_scene.cancel())
	_scripted.append(func() -> void: _scene.cancel())
	_scripted.append(func() -> void: _click(walker.cell))
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

	_scripted.append(func() -> void: _scene.start_with(battle, StageLook.GRASSLAND, 1))
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
	# 爆発に 5 体を巻き込む（予測のパネルは、駒ごとに 1 行の詰めた形になり、画面に収まる）。
	battle.add_unit(UnitKind.Id.SHIELD_TROOPER, Unit.Side.PLAYER1, Vector2i(2, 3))
	battle.add_unit(UnitKind.Id.COMMANDO, Unit.Side.PLAYER2, Vector2i(4, 3))

	_scripted.append(func() -> void: _scene.start_with(battle, StageLook.GRASSLAND, 1))
	_scripted.append(func() -> void: _scene.click_cell(sniper.cell))
	_scripted.append(func() -> void:
		_expect(Queries.barrel_targets(battle, sniper) == ([Vector2i(3, 2)] as Array[Vector2i]), "狙える樽が違う")
		_scene.hover(Vector2i(3, 2))
		_expect_forecast(["樽を撃つ", "2 体を倒せる", "引き分け"], "樽")
		_scene.hover(NO_CELL)
		_scene.click_cell(Vector2i(3, 2)))
	_scripted.append(func() -> void:
		_expect(battle.is_draw(), "引き分けにならなかった")
		_expect(_scene.result_title() == "引き分け", "引き分けの結果が出ていない")
		_expect(guard.hp == guard.max_hp() - MapObject.BLAST_DAMAGE, "爆発に巻き込まれなかった")
		_expect(_scene.barrel_view_cells() == ([Vector2i(0, 0)] as Array[Vector2i]), "爆発した樽が画面に残っている"))


## リザルトの画面。出そろう前は行き先を選べず、クリックは演出を飛ばすだけ。飛ばすと全部が出て、少しして行き先を選べる。
## 詳しい戦績は畳んであり、ボタンで開け閉めできる。
func _queue_result_scene() -> void:
	var screen: Node = _scene.result_screen()
	_expect(not screen.is_revealed() and screen.enabled_buttons().is_empty(), "出そろう前に、行き先を選べる")
	_expect(_scene.result_title() != "", "リザルトの見出しが出ていない")
	# 決着のあとは、後ろの盤の駒にマウスを乗せても、左下の枠（駒の情報）を出さない（リザルトのボタンに重なる）。
	var survivor: Unit = null
	for unit: Unit in _scene.battle.units:
		survivor = unit
	_scene.hover(survivor.cell)
	_expect(_scene.info_title() == "", "決着のあとに、駒の情報を出している: %s" % _scene.info_title())
	_scene.hover(NO_CELL)
	screen.skip()
	var waited := [0]
	var wait_revealed := func(again: Callable) -> void:
		waited[0] += 1
		if screen.enabled_buttons().is_empty():
			if waited[0] > 600:
				_fail("飛ばしても、リザルトの行き先を選べるようにならない")
				return
			_push_front(again.bind(again))
			return
		_expect(screen.is_revealed(), "行き先を選べるのに、出そろっていない")
		_expect(screen.enabled_buttons().has("タイトルへ"), "行き先に「タイトルへ」が無い")
		_expect(screen.stat_lines().size() >= 2 and screen.mvp_text() != "", "戦績か MVP が出ていない")
		_expect(not screen.is_detail_open(), "詳しい戦績が、始めから開いている")
		screen.toggle_detail()
		_expect(screen.is_detail_open(), "詳しい戦績が開かない")
		var shown_side: int = screen.table_side()
		_expect(screen.table_names().size() == _scene.stats.records_of(shown_side as Unit.Side).size(), "詳しい戦績の表に、駒の行が並ばない")
		screen.show_table(1 - shown_side)
		_expect(screen.table_side() == 1 - shown_side and not screen.table_names().is_empty(), "詳しい戦績の表を、もう一方の陣営に切り替えられない")
		screen.toggle_detail()
		_expect(screen.enter_destination() == "タイトルへ", "対戦モードの決着の画面の Enter がタイトルへでない: %s" % screen.enter_destination())
		# 戦績の行がいちばん多い（5 行）ときも、入力の案内が下の帯にかからない。
		var full := ResultSummary.new()
		full.headline = "VICTORY"
		full.reason = "プレイヤー1（青） の勝ち　敵の将を倒した"
		full.focus_name = "プレイヤー1（青）"
		full.lines = [["作戦領域", "結晶の渓谷"], ["経過ターン", "23 ターン"], ["敵軍撃破", "5 体"], ["中立撃破", "3 体"], ["聖遺物", "英知の聖遺物・勇気の聖遺物"]]
		full.mvp_name = "シールドトルーパー Lv3"
		screen.present(full)
	var waited_full := [0]
	var wait_full := func(again: Callable) -> void:
		var screen_size: Vector2 = screen.get_viewport_rect().size
		waited_full[0] += 1
		if not screen.is_revealed():
			if waited_full[0] > 600:
				_fail("戦績が 5 行の決着の画面が、出そろわない")
				return
			screen.skip()
			_push_front(again.bind(again))
			return
		var rect: Rect2 = screen.prompt_rect()
		_expect(rect.end.y <= screen_size.y - BattleHud.BOTTOM_BAR_HEIGHT,
			"戦績が 5 行のとき、決着の画面の入力の案内が下の帯にかかる: %s" % rect)
	_scripted.append(wait_revealed.bind(wait_revealed))
	_scripted.append(wait_full.bind(wait_full))


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

	_scripted.append(func() -> void: _scene.start_with(battle, StageLook.GRASSLAND, 1))
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
		_scene.start_with(battle, StageLook.GRASSLAND, 1))
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
		_scene.hover(burned.cell)
		_expect_forecast([Skills.of(sorcerer).display_name(), burned.display_name(), "ダメージ"], "ファイアボール")
		_scene.hover(NO_CELL)
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
		_scene.start_with(battle, StageLook.GRASSLAND, 1))
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
		_scene.start_with(battle, StageLook.GRASSLAND, 1))
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
		_scene.start_with(battle, StageLook.GRASSLAND, 1)
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

	_scripted.append(func() -> void: _scene.start_with(battle, StageLook.GRASSLAND, 1))
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

	_scripted.append(func() -> void: _scene.start_with(battle, StageLook.GRASSLAND, 1))
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

	_scripted.append(func() -> void: _scene.start_with(battle, StageLook.GRASSLAND, 1))
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
		_scene.start_with(battle, StageLook.GRASSLAND, 1))
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
		_scene.hover_menu_item(&"wait")
		_expect(_scene.info_text().contains("待機"), "メニューの項目の説明が出ていない")
		_scene.hover_menu_item(&"")
		_expect(not _scene.info_text().contains("待機:"), "マウスが離れても、項目の説明が残っている")
		_expect(_scene.press_menu(&"heal") and _scene.is_choosing_target(), "メニューの回復で、相手を選び始めなかった")
		_scene.hover(wounded.cell)
		_expect_forecast(["回復", wounded.display_name(), "+%d" % medic.power()], "回復")
		_scene.hover(NO_CELL)
		_scene.click_cell(wounded.cell))
	_scripted.append(func() -> void:
		_expect(wounded.hp == 10 + medic.power(), "回復しなかった")
		_expect(medic.acted, "回復しても行動が終わっていない")
		_expect(_scene.played.get(healed, 0) == 1, "回復を再生しなかった"))


## 駒を見る（閲覧）のは、選択と別。行動の途中（選んだあと、動いたあと、相手を選ぶ途中）に相手の駒を見て、
## 脅威範囲が出て、見終わると元の行動の途中へそのまま戻る。敵の全員の脅威範囲を出し入れする。
func _queue_inspection_scene() -> void:
	var board := _small_board(Vector2i(9, 5))
	var battle := Battle.new(board)
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER1, Vector2i(0, 4))
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER2, Vector2i(8, 0))
	var trooper := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, Unit.Side.PLAYER1, Vector2i(1, 2))
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, Unit.Side.PLAYER2, Vector2i(7, 2))
	var foe := battle.add_unit(UnitKind.Id.COMMANDO, Unit.Side.PLAYER2, Vector2i(4, 2))
	var neutral := battle.add_unit(UnitKind.Id.MINION, Unit.Side.NEUTRAL, Vector2i(5, 4))
	var looks := func(unit: Unit, what: String) -> void:
		_expect(_scene.inspected_unit() == unit and _scene.selected_unit() == trooper, "%s: 見る駒か、選んでいる駒が違う" % what)
		var threat: Array[Vector2i] = Threat.of(battle, unit.id).cells()
		threat.sort()
		var painted: Array[Vector2i] = _scene.threat_painted_cells()
		painted.sort()
		_expect(not threat.is_empty() and painted.size() <= threat.size() and _scene.info_title().begins_with(unit.display_name()),
			"%s: 見ている駒の脅威範囲か情報が出ていない" % what)

	# 前の対戦（もっと大きな盤）でマウスを乗せていたマスが、この小さな盤の外でも、始め直すときに持ち越さない（盤の外を読まない）。
	# 前の場面の盤の大きさに頼らないよう、大きな盤の対戦をここで始めてから、その隅にマウスを乗せる。
	var larger := Battle.new(_small_board(Vector2i(13, 9)))
	larger.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER1, Vector2i(0, 8))
	larger.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER2, Vector2i(12, 0))
	var outside := Vector2i(12, 8)
	_scripted.append(func() -> void:
		_scene.set_opponent(false)
		_scene.start_with(larger, StageLook.GRASSLAND, 1))
	_scripted.append(func() -> void:
		_expect(_scene.battle == larger and not board.in_bounds(outside), "大きな盤の対戦を始められなかった")
		_scene.hover(outside)
		_scene.start_with(battle, StageLook.GRASSLAND, 1)
		_expect(_scene.hovered_cell() == NO_CELL, "始め直したのに、前の対戦のマウスの下のマスが残っている: %s" % _scene.hovered_cell()))
	_scripted.append(func() -> void:
		_scene.click_cell(trooper.cell)
		# 選んだあと: 相手の駒をクリックすると、選んだまま見る。右クリックで、見るのをやめて選んだ駒へ戻る。
		_scene.click_cell(sniper.cell)
		looks.call(sniper, "選んだあと")
		_scene.click_cell(neutral.cell)
		looks.call(neutral, "見る駒を替えた")
		_scene.cancel()
		_expect(_scene.inspected_unit() == null and _scene.selected_unit() == trooper and _scene.threat_painted_cells().is_empty(),
			"右クリックで、選んだ駒へ戻らなかった")
		# 敵の全員の脅威範囲は、出したままでも、移動のマスを選べる。
		_scene.toggle_threat()
		var all: Array[Vector2i] = Threat.against(battle, Unit.Side.PLAYER1).cells()
		_expect(_scene.is_threat_shown() and _scene.threat_overlay_cells() == all and not all.is_empty(), "敵の全員の脅威範囲が出ていない")
		_scene.click_cell(Vector2i(2, 2)))
	_scripted.append(func() -> void:
		_expect(trooper.cell == Vector2i(2, 2) and trooper.has_moved, "脅威範囲を出したまま、動けなかった")
		_expect(_scene.threat_overlay_cells() == Threat.against(battle, Unit.Side.PLAYER1).cells(), "動いたあとに、敵の全員の脅威範囲を作り直していない")
		# 動いたあと: 相手を見ても、移動は失われない。駒のいないマスのクリックで戻る（動かない）。
		_scene.click_cell(foe.cell)
		looks.call(foe, "動いたあと")
		_scene.click_cell(Vector2i(2, 0))
		_expect(_scene.inspected_unit() == null and trooper.cell == Vector2i(2, 2) and trooper.has_moved and _scene.menu_ids().has(&"undo"),
			"見終わったあとに、動いたあとの状態へ戻らなかった")
		_scene.toggle_threat()
		_expect(not _scene.is_threat_shown() and _scene.threat_overlay_cells().is_empty(), "敵の全員の脅威範囲が消えない")
		_scene.cancel())  # 移動を取り消す
	_scripted.append(func() -> void: _scene.click_cell(Vector2i(3, 2)))
	_scripted.append(func() -> void:
		# 相手を選ぶ途中: 相手でない駒を見ても、選ぶ途中のまま。見終わると、続けて攻撃できる。
		_expect(_scene.press_menu(&"attack") and _scene.is_choosing_target(), "メニューの攻撃で、相手を選び始めなかった")
		_scene.click_cell(sniper.cell)
		looks.call(sniper, "相手を選ぶ途中")
		_scene.cancel()
		_expect(_scene.is_choosing_target() and _scene.inspected_unit() == null, "見終わったあとに、相手を選ぶ途中へ戻らなかった")
		# 相手にマウスを乗せると、そのそばに戦闘予測のパネルが出る（メニューと重ならず、画面に収まる）。離すと消える。
		_scene.hover(foe.cell)
		_expect_forecast(["攻撃", foe.display_name(), "ダメージ"], "攻撃")
		_scene.hover(Vector2i(0, 0))
		_expect(_scene.forecast_text() == "", "相手からマウスを離しても、予測のパネルが残っている")
		_scene.hover(NO_CELL)
		_scene.click_cell(foe.cell))
	_scripted.append(func() -> void:
		_expect(trooper.acted and foe.hp < foe.max_hp(), "見終わったあとに、攻撃できなかった")
		# 相手の駒の範囲を、表示したままにする（ピン留め）。何も選んでいないときにクリックして、情報の枠のスイッチで留める。
		_scene.click_cell(sniper.cell)
		_expect(_scene.pin_switch_state() == ([true, false] as Array[bool]), "相手の駒を見ても、「範囲を表示したまま」が出ない")
		_expect(_scene.press_pin_switch() and _scene.pinned_ids() == ([sniper.id] as Array[int]), "スイッチで留められなかった")
		_scene.click_cell(neutral.cell)
		_scene.press_pin_switch()
		_scene.cancel()  # 見るのをやめる（ピンは残る）
		_expect(_scene.pinned_ids() == ([sniper.id, neutral.id] as Array[int]) and _scene.pinned_sets().size() == 2, "2 体の範囲を表示したままにできない")
		_expect(_scene.pinned_sets()[0] == Threat.of(battle, sniper.id).cells(), "留めた範囲が、その駒の脅威範囲でない")
		# 全体のスイッチと両立する。
		_scene.toggle_threat()
		_expect(not _scene.threat_overlay_cells().is_empty() and _scene.pinned_sets().size() == 2, "全体の範囲と、留めた範囲が両立しない")
		_scene.toggle_threat()
		# 自分の駒には出さない。
		_scene.click_cell(trooper.cell)
		_expect(not _scene.pin_switch_state()[0], "自分の駒に「範囲を表示したまま」が出た")
		_scene.cancel())
	_scripted.append(_end_turn)
	_scripted.append(func() -> void:
		# 留めた駒が動くと、範囲も付いていく。
		_expect(battle.phase == Unit.Side.PLAYER2, "相手の番にならなかった")
		_scene.click_cell(sniper.cell))
	_scripted.append(func() -> void: _scene.click_cell(Vector2i(7, 4)))
	_scripted.append(func() -> void: _scene.press_wait())
	_scripted.append(func() -> void:
		_expect(sniper.cell == Vector2i(7, 4), "留めた駒が動かなかった")
		_expect(not _scene.pinned_sets().is_empty() and _scene.pinned_sets()[0] == Threat.of(battle, sniper.id).cells(), "留めた駒が動いても、範囲が付いていかない")
		# 右クリックで、ほかに戻すものが無ければ、全部外す。
		_expect(_scene.cancel() and _scene.pinned_ids().is_empty() and _scene.pinned_sets().is_empty(), "右クリックで、留めた範囲を全部外せない"))


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
		panel.choose_field(VersusFields.TWIN_SPRINGS)
		seen["actions"] = _scene.cpu_actions
		panel.confirm()
		# CPU（先手）の番の間も、必殺技のボタンは人（後手。MILITARY）のもの。
		_expect(_scene.ult_button_text().contains(Ults.of_army(UnitKind.Army.MILITARY).display_name()), "CPU の番に、必殺技のボタンが CPU のものになった: %s" % _scene.ult_button_text()))
	_scripted.append(func() -> void:
		var battle: Battle = _scene.battle
		_expect(not _scene.setup_panel().visible, "設定画面が閉じない")
		_expect(_scene.look == StageLook.CRYSTAL_FOREST, "選んだステージで始まらない")
		_expect(battle.armies == ([UnitKind.Army.FANTASY, UnitKind.Army.MILITARY] as Array[UnitKind.Army]), "選んだ軍で始まらない")
		_expect(_scene.cpu_actions > seen["actions"], "先手の CPU が動かなかった")
		_expect(battle.phase == Unit.Side.PLAYER2 and battle.turn == 1, "先手の CPU が番を終えなかった")
		var panel: Node = _scene.setup_panel()
		# 設定画面を開いて、選び直してから閉じても、いまの対戦と設定はそのまま（始めるボタンを押すまで、何も変わらない）。
		_scene.open_setup()
		_expect(panel.visible and panel.is_cancellable(), "対戦の途中の設定画面を、閉じられない")
		panel.choose_field(VersusFields.LABYRINTH)
		panel.choose_opponent(false)
		panel.cancel()
		_expect(not panel.visible and not _scene.is_busy(), "設定画面が閉じない")
		_expect(_scene.battle == battle and _scene.look == StageLook.CRYSTAL_FOREST and _scene.cpu_opponent, "設定画面を閉じたら、対戦か設定が変わった")
		# 手で作ったマップ（対戦モードで選べるもの）でも始まる。「新しい盤面」は生成のステージだけ（同じマップは形が変わらない）。
		# 画面に出していない（釣り合いがめやすを外れる）マップでも、入口は同じ。
		for field in VersusFields.all_ids():
			if VersusFields.is_generated(field):
				continue
			_scene.open_setup()
			panel.choose_field(field)
			panel.choose_opponent(false)  # 先手の CPU が動き出すと、次の設定画面が開けない
			panel.confirm()
			var expected := VersusFields.card_board(field, 0)
			_expect(_scene.battle.board.size == expected.size and _scene.battle.board.hq_cells == expected.hq_cells, "手で作ったマップで始まらない: %s" % field)
			_expect(_scene.look == VersusFields.look_of(field), "手で作ったマップの見た目にならない: %s" % field)
			_expect(_scene.source.new_board_fields() == VersusFields.generated_ids(), "手で作ったマップの対戦の「新しい盤面」が、生成のステージでない")
		_scene.open_setup()
		panel.choose_opponent(false)
		panel.choose_human_side(Unit.Side.PLAYER1)
		panel.choose_army(Unit.Side.PLAYER1, UnitKind.Army.MILITARY)
		panel.choose_army(Unit.Side.PLAYER2, UnitKind.Army.FANTASY)
		panel.choose_field(VersusFields.PLAIN)
		panel.confirm()
		_expect(not _scene.cpu_opponent and _scene.source.cpu_side() == Unit.Side.PLAYER2, "既定の設定に戻らない"))
	# 何も選び直せない対戦（battle_source.gd の既定の答え。ストーリーの 1 話も、ステージ・相手・対戦の設定は選び直せない）を渡すと、選び直す入口が出ない。
	var kept := {}
	_script_fixed_source(kept)


func _script_fixed_source(kept: Dictionary) -> void:
	_scripted.append(func() -> void:
		kept["source"] = _scene.source
		_scene.source = FixedSource.new()
		_scene.start_battle(_scene.map_seed + 1)
		var battle: Battle = _scene.battle
		_expect(_scene.look == StageLook.STONE_WALLS and battle.board.size == BoardGenerator.DEFAULT_SIZE, "渡したもので対戦が始まらない")
		_expect(not _scene.cpu_opponent, "渡した対戦の設定の、誰が動かすかに従わない")
		_expect(not _scene.opponent_switch_shown(), "切り替えられない対戦に、相手のボタンが出た")
		_scene.toggle_opponent()
		_expect(not _scene.cpu_opponent, "切り替えられない対戦で、相手が切り替わった")
		_expect(_scene.menu_items().is_empty(), "対戦の設定を開けない対戦に、システムメニューの「対戦の設定へ」が出た")
		_scene.open_setup()
		_expect(not _scene.setup_panel().visible, "対戦の設定を開けない対戦で、設定画面が開いた")
		_scene.start_on_field(VersusFields.PLAIN, _scene.map_seed + 1)
		_expect(_scene.battle == battle, "ステージを選べない対戦で、ステージを替えてやり直した")
		_expect(not _scene.result_screen().can_go_to_setup() and _scene.result_screen().new_board_fields().is_empty(),
			"選び直せない対戦の決着の画面に、対戦の設定・新しい盤面のボタンがある")
		_scene.source = kept["source"]
		_scene.start_battle(_scene.map_seed + 1)
		_expect(_scene.opponent_switch_shown() and _scene.result_screen().can_go_to_setup()
			and _scene.result_screen().new_board_fields() == VersusFields.generated_ids(), "対戦モードに戻すと、選び直す入口が戻らない"))


## 何も選び直せない対戦を渡すもの（_script_fixed_source）。迷宮回廊の人どうし。
class FixedSource extends "res://game/battle_source.gd":
	func make_setup(battle_seed: int) -> MatchSetup:
		var deck := MatchSetup.default_deck(UnitKind.Army.MILITARY)
		return MatchSetup.versus_human(BoardGenerator.Stage.LABYRINTH, battle_seed, deck, deck.copy())

	func look() -> StringName:
		return StageLook.STONE_WALLS


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
		_scene.start_with(battle, StageLook.GRASSLAND, 1))
	_scripted.append(func() -> void:
		var menu: Node = _scene.system_menu()
		var settings: RefCounted = _scene.settings
		var base := Engine.time_scale
		_scene.click_cell(trooper.cell)
		_scene.press_escape()
		_expect(not menu.is_open() and _scene.selected_unit() == null, "選んでいる駒があるのに、Esc で選択をやめずにメニューを開いた")
		_scene.press_escape()
		_expect(menu.is_open() and _scene.is_busy() and Engine.time_scale == 0.0, "戻すものが無いのに、Esc でメニューが開かない（か、止まらない）")
		_expect(menu.item_ids() == ([&"resume", &"settings", &"match_setup", &"title", &"quit"] as Array[StringName]), "メニューの項目が違う: %s" % [menu.item_ids()])
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
		var drag: Array = _scene.camera_drag_settings()
		_expect(is_equal_approx(drag[0], 2.0 * OrbitCamera.DEFAULT_DRAG_SENSITIVITY) and drag[1], "設定の値がカメラに効かない")
		settings.reset_all()
		drag = _scene.camera_drag_settings()
		_expect(is_equal_approx(drag[0], OrbitCamera.DEFAULT_DRAG_SENSITIVITY) and not drag[1], "既定に戻せない")
		menu.back()
		_expect(menu.is_open() and not menu.is_settings_open(), "設定の画面から、メニューへ戻らない")
		menu.back()
		_expect(not menu.is_open() and not _scene.is_busy() and Engine.time_scale == base, "メニューを閉じても、元の速さに戻らない")
		# CPU の駒の行動を再生する間だけ、設定の速さを掛ける。
		settings.set_value(&"cpu_playback_speed", 3)
		_scene.set_cpu_fast(true)
		_expect(is_equal_approx(Engine.time_scale, base * 3.0), "CPU の番の速さが効かない")
		_scene.set_cpu_fast(false)
		settings.reset_all()
		_expect(Engine.time_scale == base, "CPU の番の速さが残った"))


## ミニマップ: 画面に収まって帯と重ならない、押すとその場所へ視点が移る（ドラッグは付いてきて、盤の外へは出ない）、
## 設定で隠すと消え、戻すと出る。
func _queue_minimap_scene() -> void:
	var board := _small_board(Vector2i(12, 10))
	var battle := Battle.new(board)
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER1, Vector2i(0, 9))
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER2, Vector2i(11, 0))
	_scripted.append(func() -> void:
		_scene.set_opponent(false)
		_scene.start_with(battle, StageLook.GRASSLAND, 1))
	_scripted.append(func() -> void:
		var rect: Rect2 = _scene.minimap_rect()
		var screen: Rect2 = _scene.get_viewport().get_visible_rect()
		_expect(rect.has_area() and screen.encloses(rect), "ミニマップが出ていないか、画面からはみ出した: %s" % rect)
		_expect(rect.position.y >= BattleHud.TOP_BAR_HEIGHT and rect.end.y <= screen.size.y - BattleHud.BOTTOM_BAR_HEIGHT, "ミニマップが上か下の帯に重なった: %s" % rect)
		_expect(_scene.minimap_view().size() >= 3, "ミニマップに、見ている範囲が描かれていない")
		# 真ん中を押すと、盤の真ん中を見る。
		_minimap_button(rect.get_center(), true)
		_minimap_button(rect.get_center(), false)
		var center: Vector3 = _scene.camera_center()
		_expect(Vector2(center.x, center.z).distance_to(Vector2(6.0, 5.0)) < 0.6, "ミニマップの真ん中を押しても、盤の真ん中へ移らない: %s" % center)
		# 押したまま右下の外までドラッグすると、付いてきて、盤の端で止まる。離したあとの動きでは動かない。
		_minimap_button(rect.get_center(), true)
		_minimap_motion(rect.end + Vector2(40, 40), true)
		_minimap_button(rect.end + Vector2(40, 40), false)
		center = _scene.camera_center()
		_expect(is_equal_approx(center.x, 12.0) and is_equal_approx(center.z, 10.0), "ミニマップのドラッグが盤の端で止まらない: %s" % center)
		_minimap_motion(rect.position + Vector2(10, 10), false)
		_expect(_scene.camera_center().is_equal_approx(center), "ミニマップで、押していないのに視点が動いた")
		# 設定で隠すと消え、押せない。戻すと出る。
		_scene.settings.set_value(&"show_minimap", false))
	_scripted.append(func() -> void:
		_expect(not _scene.minimap_rect().has_area(), "設定で隠しても、ミニマップが消えない")
		_scene.settings.reset_all())
	_scripted.append(func() -> void:
		_expect(_scene.minimap_rect().has_area(), "設定を戻しても、ミニマップが出ない"))


## ミニマップに、画面の位置 at でのマウスのボタンを入れる（ミニマップが受けるのと同じ道）。
func _minimap_button(at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = at
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	_scene.feed_minimap_input(event)


func _minimap_motion(at: Vector2, held: bool) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	_scene.feed_minimap_input(event)


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
		_scene.start_with(battle, StageLook.GRASSLAND, 1))
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
			_scene.system_menu().close()
			# ログも、相手の番の途中に開け、開いている間は止まる。
			_scene.open_log()
			var panel: Node = _scene.log_panel()
			_expect(panel.is_open() and Engine.time_scale == 0.0 and _scene.is_busy(), "相手の番の途中に、ログで止まらない")
			seen["paused"] = _scene.cpu_actions
			get_tree().create_timer(0.3, true, false, true).timeout.connect(func() -> void:
				_expect(_scene.cpu_actions == seen["paused"], "ログを開いている間に、相手の番が進んだ")
				panel.choose(panel.first_row() + panel.row_count() - 1)
				panel.close())))
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
		# CPU がしたことは、ログで読める。
		var cpu_lines := 0
		for entry: RefCounted in _scene.battle_log.entries:
			if entry.side == Unit.Side.PLAYER2 and not entry.header:
				cpu_lines += 1
		_expect(cpu_lines >= 2, "CPU の番に起きたことが、ログに無い")
		_scene.open_log()
		var panel: Node = _scene.log_panel()
		_expect(panel.first_row() + panel.row_count() == _scene.battle_log.entries.size(), "ログの画面の行が、ログの最新まで並んでいない")
		_scene.log_panel().close()
		_scene.set_opponent(false))


## 自分の番のおまかせ。人どうしの対戦で、プレイヤー1 の番を任せる。1 回目と、確かめた直後の 2 回目では任せず、
## 右クリックでやめられる。任せると、未行動の駒を CPU が動かしてターンを終え、プレイヤー2（人）の番で止まる。
func _queue_auto_turn_scene() -> void:
	var board := _small_board(Vector2i(8, 5))
	var battle := Battle.new(board)
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER1, Vector2i(0, 4))
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER2, Vector2i(7, 0))
	var mine := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, Unit.Side.PLAYER1, Vector2i(2, 3))
	var foe := battle.add_unit(UnitKind.Id.SORCERER, Unit.Side.PLAYER2, Vector2i(4, 2))

	_scripted.append(func() -> void:
		_scene.set_opponent(false)
		_scene.start_with(battle, StageLook.GRASSLAND, 1))
	_scripted.append(func() -> void:
		_expect(_scene.auto_button_state() == ["おまかせ", true], "自分の番に「おまかせ」が押せない")
		_scene.press_auto()
		_expect(_scene.is_confirming_auto() and _scene.auto_side() == -1, "1 回目で任せた（か、確かめにならない）")
		_scene.press_auto()
		_expect(_scene.auto_side() == -1, "確かめた直後の 2 回目で任せた")
		_scene.cancel()
		_expect(not _scene.is_confirming_auto(), "右クリックで、おまかせの確かめをやめない")
		_scene.press_auto()
		_scene.pass_confirm_guard()
		_scene.press_auto()
		_expect(_scene.auto_side() == Unit.Side.PLAYER1 and _scene.is_busy(), "2 回目で任せなかった")
		_expect(_scene.watch_controls_state()[0], "任せている間に、早送り・スキップが出ない"))
	_scripted.append(func() -> void:
		_expect(battle.phase == Unit.Side.PLAYER2 and _scene.auto_side() == -1, "任せたターンが終わらなかった（か、次の番も任せた）")
		_expect(mine.has_moved or mine.acted or foe.hp < foe.max_hp() or mine.cell != Vector2i(2, 3), "任せた駒が何もしなかった")
		_expect(not _scene.is_busy() and _scene.auto_button_state()[1], "人の番（プレイヤー2）で止まらなかった"))


## 相手（CPU）の番の早送りとスキップ。人がターンを終えると、中立のフェーズから相手の番が見ているだけの番になり、
## 下の帯に「早送り」「スキップ」が出る。スキップすると、自分の番が来るまで見せずに進み、盤の見た目は状態と同じになる。
## 2 局目は、スキップの途中で CPU が人の将を倒して決着し、決着の画面が出る。
func _queue_cpu_skip_scene() -> void:
	var board := _small_board(Vector2i(8, 5))
	var battle := Battle.new(board)
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER1, Vector2i(0, 4))
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER2, Vector2i(7, 0))
	var bait := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, Unit.Side.PLAYER1, Vector2i(3, 2))
	battle.add_unit(UnitKind.Id.SORCERER, Unit.Side.PLAYER2, Vector2i(6, 2))
	battle.add_unit(UnitKind.Id.COMMANDO, Unit.Side.PLAYER2, Vector2i(6, 3))
	battle.add_unit(UnitKind.Id.MINION, Unit.Side.NEUTRAL, Vector2i(3, 4))
	var lost := Battle.new(_small_board(Vector2i(8, 5)))
	var doomed := lost.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER1, Vector2i(3, 2))
	doomed.hp = 1
	lost.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER2, Vector2i(7, 0))
	lost.add_unit(UnitKind.Id.COMMANDO, Unit.Side.PLAYER2, Vector2i(5, 2))
	var seen_lines := {}

	_scripted.append(func() -> void:
		# 前の場面が相手の番で終わっていても、CPU に引き取らせないよう、先に始め直してから相手を CPU にする。
		_scene.start_with(battle, StageLook.GRASSLAND, 1)
		_scene.set_opponent(true))
	_scripted.append(func() -> void:
		_expect(not _scene.watch_controls_state()[0], "自分の番に、早送り・スキップが出ている")
		var lines_before: int = _scene.battle_log.entries.size()
		_end_turn()  # 中立のフェーズを再生している途中
		_expect(_scene.watch_controls_state()[0], "相手の番（中立のフェーズ）に、早送り・スキップが出ない")
		var normal := Engine.time_scale
		_scene.toggle_fast_forward()
		_expect(Engine.time_scale > normal * 2.0 and _scene.watch_controls_state()[1], "早送りで、速くならない")
		_expect(_scene.press_skip() and _scene.is_skipping(), "スキップを押せない")
		seen_lines["before"] = lines_before
		seen_lines["base"] = _scene.cpu_actions
		# スキップの途中でも、ログを開いている間は止まる（CPU が 1 つ行動したところで開く）。
		var open_once := func() -> void:
			if seen_lines.has("paused") or _scene.cpu_actions == seen_lines["base"] or not _scene.is_skipping():
				return
			_scene.open_log()
			seen_lines["paused"] = _scene.cpu_actions
			get_tree().create_timer(0.5, true, false, true).timeout.connect(func() -> void:
				_expect(_scene.cpu_actions <= seen_lines["paused"] + 1 and battle.phase != Unit.Side.PLAYER1,
					"スキップの途中に、ログを開いている間も相手の番が進んだ")
				_scene.log_panel().close())
		_scene.frame_passed.connect(open_once))
	_scripted.append(func() -> void:
		_expect(seen_lines.has("paused"), "スキップの途中に、ログを開けなかった")
		_expect(battle.turn == 2 and battle.phase == Unit.Side.PLAYER1 and not _scene.is_skipping(), "スキップのあと、自分の番で止まらなかった")
		_expect(_scene.cpu_actions > seen_lines["base"] and bait.hp < bait.max_hp(), "スキップしても、CPU が行動していない")
		var problem := _mismatch(battle)
		_expect(problem == "", "スキップのあと、盤の見た目が状態と違う: " + problem)
		_expect(_scene.battle_log.entries.size() > seen_lines["before"] + 2, "スキップした番のことが、ログに残っていない")
		_expect(not _scene.watch_controls_state()[0] and Engine.time_scale == _scene.time_scale_base, "自分の番に、早送りが効いている")
		# 早送りは入れたまま（次の相手の番も速い）。2 局目: スキップの途中で決着する。
		_scene.start_with(lost, StageLook.GRASSLAND, 1))
	_scripted.append(func() -> void:
		_end_turn()
		_scene.press_skip())
	# 3 局目: スキップせずに見る。CPU が番を終えたあとの中立のフェーズ（ルールの上では、もう人の番）の再生の間も、ボタンが出ている。
	var watch := Battle.new(_small_board(Vector2i(8, 5)))
	watch.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER1, Vector2i(0, 4))
	watch.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER2, Vector2i(7, 0))
	watch.add_unit(UnitKind.Id.MINION, Unit.Side.NEUTRAL, Vector2i(3, 2))
	var neutral_seen := {}
	_scripted.append(func() -> void:
		_expect(lost.is_over() and _scene.result_screen().visible, "スキップの途中の決着で、決着の画面が出ない")
		_scene.toggle_fast_forward()
		_scene.set_opponent(false)
		_scene.start_with(watch, StageLook.GRASSLAND, 1)
		_scene.set_opponent(true))
	_scripted.append(func() -> void:
		var look := func() -> void:
			if _scene.battle == watch and watch.turn == 2 and watch.phase == Unit.Side.PLAYER1 and _scene.is_busy():
				neutral_seen["busy"] = true
				neutral_seen["shown"] = neutral_seen.get("shown", true) and _scene.watch_controls_state()[0]
		_scene.frame_passed.connect(look)
		_end_turn())
	_scripted.append(func() -> void:
		_expect(watch.turn == 2 and watch.phase == Unit.Side.PLAYER1, "3 局目で、自分の番に戻らなかった")
		_expect(neutral_seen.get("busy", false) and neutral_seen.get("shown", false),
			"CPU が番を終えたあとの中立のフェーズの再生の間に、早送り・スキップが出ていない")
		_expect(not _scene.watch_controls_state()[0], "自分の番に戻っても、早送り・スキップが出ている")
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
		_scene.start_with(battle, StageLook.GRASSLAND, 1))
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
		# 確かめに変わった直後の 2 回目（ダブルクリック・連打）では使わない。間を置いてから押すと使う。
		_scene.press_ult()
		_expect(_scene.is_confirming_ult() and battle.ult_uses[0] == 0, "素早い 2 回押しで、必殺技の確かめを飛ばした")
		_scene.pass_confirm_guard()
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
		_scene.pass_confirm_guard()
		_scene.press_ult())
	_scripted.append(func() -> void:
		_expect(sorcerer.skill_cooldown == 0, "魔力解放でクールダウンが 0 にならなかった"))


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


## 最後に、相手（CPU）の番の途中で、システムメニューの「タイトルへ戻る」を確かめてから選ぶ。対戦の場面が消えても、
## 止まっていた再生や CPU の番が続きを走らない（エラーが出ない）こと。そのあと、タイトルの「対戦」で対戦の設定の場面へ進み、
## 「タイトルへ戻る」でタイトルへ戻る。このノードは対戦の場面の子なので、先にアプリの子へ移っておく。
func _leave_battle(app: Node) -> void:
	var menu: Node = app.system_menu()
	_scene.set_opponent(false)
	_scene.start_on_field(VersusFields.PLAIN, _scene.map_seed + 1)
	_scene.set_opponent(true)
	_end_turn()
	_expect(_scene.is_busy(), "ターンを終えても、相手の番に入らない")
	_scene.press_escape()
	_expect(menu.is_open() and menu.item_ids().has(&"title"), "相手の番の途中に、タイトルへ戻る項目が出ない")
	menu.press(&"title")
	_expect(menu.confirming() == &"title", "対戦の途中なのに、タイトルへ戻る前に確かめない")
	menu.accept()
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.TITLE and not menu.is_open() and Engine.time_scale == 1.0, "タイトルへ戻らない（か、時間が止まったまま）")
	# 消えた対戦の場面の、止まっていた待ち時間が過ぎるのを待つ（続きを走れば、エラーが出て検査が落ちる）。
	await get_tree().create_timer(1.0).timeout
	app.current_scene().press_start()
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.STAGE, "タイトルの「対戦」で、ステージ選択へ進まない")
	var stages: Node = app.current_scene()
	await get_tree().process_frame
	_expect(stages.card_fields() == VersusFields.ids(), "ステージのカードが一覧と合わない")
	for field in VersusFields.ids():
		var card: Control = stages.card_of(field)
		_expect(card.get_global_rect().size.x > 0.0 and _on_screen(card), "ステージのカードが画面からはみ出す: %s" % field)
	stages.hover(VersusFields.TWIN_SPRINGS)
	_expect(stages.note_text().contains(VersusFields.title_of(VersusFields.TWIN_SPRINGS)), "カードに乗せても、説明が出ない")
	stages.hover(&"")
	stages.choose(VersusFields.LABYRINTH)
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.SETUP, "ステージ選択のカードで、対戦の設定へ進まない")
	_expect(app.current_scene().setup_panel().current_choice().field == VersusFields.LABYRINTH, "選んだステージが対戦の設定に渡らない")
	app.current_scene().setup_panel().cancel()
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.STAGE, "対戦の設定の「ステージ選択へ戻る」で、ステージ選択へ戻らない")
	# カードの上での右クリックでも戻る（カードのボタンに食われない）。
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	right.position = app.current_scene().card_center(VersusFields.LABYRINTH)
	right.global_position = right.position
	app.get_viewport().push_input(right)
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.TITLE, "ステージ選択のカードの上で右クリックしても、タイトルへ戻らない")


## control が画面（論理の大きさ）の中に収まっているか。
func _on_screen(control: Control) -> bool:
	return control.get_viewport().get_visible_rect().encloses(control.get_global_rect())


## 部隊の編成の場面: 組む・並べ替える・装備を持たせる・取っておく・写す・名前を変える・消す（確かめる）。
## 出せない部隊は取っておけない。取っておいた部隊を、対戦の設定で選べる（出せない部隊は選べない）。
func _visit_decks(app: Node) -> void:
	var library: RefCounted = app.context.decks
	_expect(app.current_scene().button_texts() == (["ストーリー", "対戦", "オプション", "終了"] as Array[String]),
		"タイトルのメニューの並びが違う: %s" % [app.current_scene().button_texts()])
	# 部隊の編成は、対戦の設定の「部隊を編成する」から開く（タイトルには無い）。
	app.current_scene().press_start()
	await app.scene_changed
	app.current_scene().choose(VersusFields.PLAIN)
	await app.scene_changed
	var setup_panel: Node = app.current_scene().setup_panel()
	setup_panel.choose_opponent(true)
	setup_panel.choose_human_side(Unit.Side.PLAYER1)
	setup_panel.choose_army(Unit.Side.PLAYER1, UnitKind.Army.MILITARY)
	_expect(setup_panel.can_edit_decks(), "対戦の設定に「部隊を編成する」が無い")
	setup_panel.press_edit_decks(Unit.Side.PLAYER1)
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.DECKS, "対戦の設定の「部隊を編成する」で、編成の場面へ進まない")
	var screen: Node = app.current_scene()
	_expect(screen.is_detour() and screen.mode() == DeckRules.VERSUS and screen.back_label() == "対戦の設定へ戻る", "対戦の設定からの編成が、対戦用でない（か、戻り先の文字が違う）")
	_expect(screen.listed_ids().is_empty() and screen.list_card_kinds().is_empty(), "部隊が無いのに、一覧か札が出ている")
	screen.press_new()
	_expect(screen.is_choosing_army() and not screen.is_editing(), "「新しい部隊」で、まず軍を選ぶ画面が出ない")
	screen.press_back()
	_expect(not screen.is_choosing_army() and not screen.is_editing(), "軍を選ぶ画面から、右クリックで一覧へ戻らない")
	screen.press_new()
	screen.choose_new_army(UnitKind.Army.MILITARY)
	_expect(screen.is_editing() and screen.editing_deck().entries.is_empty() and screen.editing_deck().army == UnitKind.Army.MILITARY, "選んだ軍で、空の部隊を組めない")
	_expect(not screen.can_save(), "空の部隊を取っておけた")
	screen.hire(UnitKind.Id.SNIPER)
	screen.hire(UnitKind.Id.SHIELD_TROOPER)
	_expect(screen.selected_entry() == 1, "雇った駒が選ばれない")
	screen.equip(Equipment.Id.IRON_SHIELD)
	screen.move_entry(1, -1)
	var deck: Deck = screen.editing_deck()
	_expect(deck.entries[0].kind == UnitKind.Id.SHIELD_TROOPER and deck.entries[0].equipment.size() == 1 and screen.selected_entry() == 0, "並べ替えで、装備か選択がずれた")
	# 装備の文が行に収まらなくても、マウスを乗せれば全部読める。
	screen.equip(Equipment.Id.SPEED_BOOTS)
	var row_texts: Array[String] = screen.troop_row_texts(0)
	_expect(row_texts[1] == row_texts[0] and row_texts[1].contains("スピードブーツ") and row_texts[1].contains("アイアンシールド"),
		"部隊の行の装備の文を、マウスを乗せても読めない: %s" % [row_texts])
	screen.unequip(Equipment.Id.SPEED_BOOTS)
	for i in 4:
		screen.hire(UnitKind.Id.SHIELD_TROOPER)
	screen.equip(Equipment.Id.SPEED_BOOTS)  # 予算 24 を 1 超える
	_expect(not screen.can_save() and deck.problems() == ([Deck.Problem.OVER_BUDGET] as Array[Deck.Problem]), "予算を超えた部隊を取っておけた")
	screen.press_save()
	_expect(screen.is_editing() and library.size() == 0, "出せない部隊が取っておかれた")
	screen.remove_entry(5)
	screen.press_back()  # 選択をやめる
	_expect(screen.selected_entry() == -1 and screen.is_editing(), "右クリックで、選択をやめない")
	screen.press_save()
	_expect(not screen.is_editing() and library.size() == 1, "出せる部隊を取っておけない")
	var id: String = screen.list_selected()
	# 対戦の設定で選べる。
	screen.press_duplicate()
	_expect(library.size() == 2, "写せない")
	screen.press_rename()
	screen.set_dialog_input("写しの部隊")
	screen.accept_dialog()
	_expect(library.find(screen.list_selected()).name == "写しの部隊", "名前を変えられない")
	screen.press_delete()
	_expect(screen.is_dialog_open() and library.size() == 2, "消す前に確かめない")
	screen.press_back()
	_expect(not screen.is_dialog_open() and library.size() == 2, "確かめを、やめられない")
	screen.press_delete()
	screen.accept_dialog()
	_expect(library.size() == 1, "消せない")
	# 変えたところがあれば、取っておかずに戻る前に確かめる。
	screen.select_saved(id)
	_expect(screen.list_card_kinds().size() == library.find(id).deck.entries.size() + 1, "一覧の右に、選んだ部隊の駒の札が並ばない")
	screen.press_edit()
	screen.remove_entry(0)
	screen.press_back()
	_expect(screen.is_dialog_open(), "変えたところがあるのに、確かめずに一覧へ戻った")
	screen.accept_dialog()
	_expect(not screen.is_editing() and library.find(id).deck.entries.size() == 5, "取っておかずに戻ったのに、部隊が変わった")
	# ストーリー用の部隊: 切り替えると、対戦用の部隊は並ばない。雇える駒は、いま解放した駒だけ。
	_expect(screen.mode() == DeckRules.VERSUS and screen.listed_ids() == ([id] as Array[String]), "対戦用の一覧が違う")
	screen.set_mode(Story.RULES_ID)
	_expect(screen.listed_ids().is_empty(), "ストーリー用の一覧に、対戦用の部隊が混ざった")
	screen.press_new()
	_expect(screen.editing_deck().rules.id == Story.RULES_ID and screen.editing_deck().army == Story.ARMY, "ストーリー用の部隊を、ストーリーの決まりで組めない")
	_expect(screen.editing_deck().available_kinds() == app.context.story.unlocked_kinds() or screen.editing_deck().available_kinds().size() == app.context.story.unlocked_kinds().size(), "ストーリー用の雇える駒が、いま解放した駒と違う")
	screen.hire(UnitKind.Id.COMMANDO)
	_expect(screen.editing_deck().entries.is_empty() or app.context.story.unlocked_kinds().has(UnitKind.Id.COMMANDO), "まだ解放していない駒を雇えた")
	screen.hire(UnitKind.Id.SNIPER)
	screen.hire(UnitKind.Id.SNIPER)
	screen.hire(UnitKind.Id.MEDIC)
	screen.press_save()
	var story_id: String = screen.list_selected()
	_expect(not screen.is_editing() and screen.listed_ids() == ([story_id] as Array[String]), "ストーリー用の部隊を取っておけない")
	_expect(library.find(story_id).deck.rules.id == Story.RULES_ID, "ストーリー用の部隊が、ストーリーの決まりで取っておかれていない")
	screen.set_mode(DeckRules.VERSUS)
	_expect(screen.listed_ids() == ([id] as Array[String]), "対戦用の一覧に、ストーリー用の部隊が混ざった")
	var versus_ids: Array[String] = []
	for item: RefCounted in library.for_rules(DeckRules.VERSUS):
		versus_ids.append(item.id)
	_expect(not versus_ids.has(story_id), "対戦の設定で選べる部隊に、ストーリー用の部隊が混ざった")
	screen.select_saved(id)
	screen.press_edit()
	screen.press_save()  # 寄り道の間に最後に取っておいた部隊が、戻った対戦の設定で選ばれる
	screen.press_back()
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.SETUP, "編成の一覧から、対戦の設定へ戻らない")
	var panel: Node = app.current_scene().setup_panel()
	_expect(panel.current_choice().deck_ids[0] == id, "寄り道で取っておいた部隊が、対戦の設定で選ばれていない")
	var ids: Array = panel.deck_options(Unit.Side.PLAYER1).map(func(option: Array) -> String: return option[0])
	_expect(ids == ["", id], "対戦の設定に、取っておいた部隊が並ばない: %s" % [ids])
	_expect(panel.choose_deck(Unit.Side.PLAYER1, id), "取っておいた部隊を選べない")
	panel.open_preview(Unit.Side.PLAYER1)
	_expect(panel.preview().visible and panel.preview().shown_kinds().size() == 6, "「編成を確認」で、選んだ部隊が出ない")
	panel.preview().close_preview()
	# ステージは対戦の設定では選ばない。「ステージを選び直す」でステージ選択へ戻る（選んだものは残る）。
	panel.choose_random_side()
	panel.press_stage()
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.STAGE, "「ステージを選び直す」で、ステージ選択へ戻らない")
	app.current_scene().choose(VersusFields.LABYRINTH)
	await app.scene_changed
	panel = app.current_scene().setup_panel()
	_expect(panel.current_choice().field == VersusFields.LABYRINTH and panel.current_choice().random_side and panel.current_choice().deck_ids[0] == id,
		"ステージを選び直したら、ほかの選択が失われた")
	panel.choose_human_side(Unit.Side.PLAYER1)
	var setup: MatchSetup = panel.current_choice().to_setup(1)
	_expect(setup.is_valid() and setup.decks[0].entries.size() == 5 and setup.decks[0].entries[0].kind == UnitKind.Id.SHIELD_TROOPER, "選んだ部隊で対戦を作らない")
	_expect(setup.decks[1].entries.size() == CpuDeck.build(setup.army_of(Unit.Side.PLAYER2)).entries.size(), "CPU の編成が変わった")
	panel.cancel()
	await app.scene_changed


## ストーリーの 1 話の通し: タイトルの「ストーリー」→ 会話（送る・戻る・飛ばす）→ 話の対戦（選び直す入口が無い、手で作ったマップ、
## 決め打ちの敵）→ 勝って、決着の画面の「次へ」→ あとの会話（最後まで送る）→ タイトル。勝った時点でクリアを書き、タイトルに済みの印。
## 対戦は、話の対戦の画面に小さな盤を渡して、1 手で勝って終える（話の盤を最後まで進めると、検査が長くなる）。
func _visit_story(app: Node) -> void:
	var story: RefCounted = app.context.story
	var episode: Script = story.next_episode()
	_expect(not story.is_cleared(episode.ID), "始める前から、話をクリアしている")
	_expect(app.current_scene().story_label() == "ストーリー", "クリア前のタイトルに、済みの印が付いている")
	app.current_scene().press_story()
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.CAMPAIGNS, "タイトルの「ストーリー」で、物語を選ぶ場面へ進まない")
	var campaigns: Node = app.current_scene()
	_expect(campaigns.campaigns() == Story.CAMPAIGNS, "物語を選ぶ場面に、全部の物語が並んでいない")
	for each: Script in Story.CAMPAIGNS:
		_expect(campaigns.is_card_enabled(each) == Story.is_ready(each)
				and (campaigns.status_text(each) == "準備中") == not Story.is_ready(each), "話の無い物語を選べる（か、ある物語を選べない）: %s" % each.TITLE)
	campaigns.choose(Story.MILITARY)
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.EPISODES and story.campaign == Story.MILITARY, "物語を選んでも、その物語の話の一覧へ進まない")
	var list: Node = app.current_scene()
	_expect(list.episodes().size() == Story.MILITARY.EPISODES.size(), "話の一覧に、全部の話が並んでいない")
	_expect(list.is_card_enabled(Story.MILITARY.EPISODES[0]) and list.card_status(Story.MILITARY.EPISODES[0]) == "未クリア", "最初の話を選べない")
	for later: Script in Story.MILITARY.EPISODES.slice(1):
		_expect(not list.is_card_enabled(later), "前の話をクリアしていないのに、%s を選べる" % later.TITLE)
	list.choose(episode)
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.TALK, "話の一覧で話を選んでも、会話の場面へ進まない")
	var talk: Node = app.current_scene()
	_expect(talk.line_count() == episode.BEFORE.size() and talk.line_index() == 0, "前の会話の文の数が違う")
	_expect(talk.speaker() == episode.SPEAKERS[episode.BEFORE[0][0]] and talk.line_text() == episode.BEFORE[0][1], "最初の文が出ていない")
	talk.press_next()
	_expect(talk.line_index() == 1, "クリックで、次の文へ進まない")
	talk.press_back()
	_expect(talk.line_index() == 0, "右クリックで、前の文へ戻らない")
	talk.press_skip()
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.SORTIE, "会話を飛ばしても、出撃の準備へ進まない")
	var sortie: Node = app.current_scene()
	# 「部隊を編成する」で編成（ストーリー用だけ）へ寄り道し、組んで取っておいた部隊を選んで戻る。
	sortie.press_edit_decks()
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.DECKS and app.context.run != null, "出撃の準備の「部隊を編成する」で、流れを保ったまま編成へ進まない")
	var decks: Node = app.current_scene()
	_expect(decks.is_detour() and decks.mode() == Story.RULES_ID and decks.back_label() == "出撃の準備へ戻る", "寄り道の編成が、ストーリー用でない（か、戻り先の文字が違う）")
	decks.press_new()
	for kind: UnitKind.Id in story.unlocked_kinds():
		decks.hire(kind)
	_expect(decks.can_save(), "寄り道の編成で、雇える駒で組んだ部隊を取っておけない")
	decks.press_save()
	var made: String = decks.list_selected()
	decks.press_back()
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.SORTIE, "編成の「出撃の準備へ戻る」で、出撃の準備へ戻らない")
	sortie = app.current_scene()
	_expect(sortie.chosen_id() == made, "寄り道で取っておいた部隊が、出撃の準備で選ばれていない")
	sortie.choose("")
	var options: Array[String] = sortie.option_ids()
	_expect(options[0] == "" and sortie.chosen_id() == "", "出撃の準備で、既定の編成を選べない")
	var story_decks: Array = app.context.decks.for_rules(Story.RULES_ID)
	_expect(options.size() == 1 + story_decks.size(), "出撃の準備に、ストーリー用の部隊が並ばない（か、対戦用が混ざった）")
	for item: RefCounted in story_decks:
		_expect(sortie.is_option_enabled(item.id) == item.playable(), "出せない部隊を選べる（か、出せる部隊を選べない）: %s" % item.name)
		if item.playable():
			sortie.choose(item.id)
	var result: Node = await _win_story_battle(app, sortie, episode)
	# 「部隊を選び直す」で出撃の準備へ戻り、同じ話をもう一度勝つ。
	_expect(result.can_choose_squad(), "話の決着の画面に「部隊を選び直す」が無い")
	result.press_choose_squad()
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.SORTIE and app.context.run != null, "決着の画面の「部隊を選び直す」で、出撃の準備へ戻らない")
	result = await _win_story_battle(app, app.current_scene(), episode)
	result.press_continue()
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.TALK, "決着の画面の「次へ」で、あとの会話へ進まない")
	talk = app.current_scene()
	_expect(talk.line_count() == episode.AFTER.size() + episode.UNLOCKS.size(), "あとの会話の文の数が違う（最後に、解放した駒の知らせ）")
	if not episode.UNLOCKS.is_empty():
		talk.press_skip()
		_expect(talk.line_index() == episode.AFTER.size() and talk.speaker() == "知らせ"
				and talk.line_text().contains(UnitKind.display_name(episode.UNLOCKS[0])), "「飛ばす」が、解放した駒の知らせまで飛ばしている")
	for i: int in talk.line_count() - talk.line_index():
		talk.press_next()
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.EPISODES and app.context.run == null, "あとの会話を送りきっても、話の一覧へ戻らない")
	list = app.current_scene()
	_expect(list.card_status(episode) == "クリア済み", "クリアした話のカードに、済みの印が無い")
	if Story.MILITARY.EPISODES.size() > 1:
		_expect(list.is_card_enabled(Story.MILITARY.EPISODES[1]), "前の話をクリアしたのに、次の話を選べない")
	_expect(list.roster_text().contains(UnitKind.display_name(episode.UNLOCKS[0])) if not episode.UNLOCKS.is_empty() else true, "話の一覧の、いま雇える駒が増えていない")
	list.press_back()
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.CAMPAIGNS, "話の一覧の「物語を選び直す」で、物語を選ぶ場面へ戻らない")
	_expect(app.current_scene().status_text(Story.MILITARY) == "1 / %d 話クリア" % Story.MILITARY.EPISODES.size(), "物語のカードに、クリアした話の数が出ない")
	app.current_scene().press_back()
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.TITLE, "物語を選ぶ場面の「タイトルへ戻る」で、タイトルへ戻らない")
	_expect(app.current_scene().story_label() == "ストーリー（クリア済み）" or not story.all_cleared(), "クリアしたのに、タイトルに済みの印が無い")
	_expect(story.unlocked_kinds().has(episode.UNLOCKS[0]) if not episode.UNLOCKS.is_empty() else true, "クリアしても、駒が増えていない")


## 出撃の準備 sortie で「出撃」し、話 episode の対戦に入ったことを確かめて、小さな盤で 1 手で勝つ。決着の画面を返す。
func _win_story_battle(app: Node, sortie: Node, episode: Script) -> Node:
	var story: RefCounted = app.context.story
	var chosen: Deck = sortie.chosen_deck()
	sortie.press_sortie()
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.BATTLE, "出撃の準備の「出撃」で、対戦へ進まない")
	var screen: Node = app.current_scene()
	screen.set_time_scale_base(8.0)
	var source: RefCounted = screen.source
	_expect(source.new_board_fields().is_empty() and not source.can_open_setup() and screen.menu_items().is_empty(), "話の対戦に、選び直す入口がある")
	_expect(screen.battle.board.size == episode.MAP.map().make_board().size, "話の対戦が、話のマップで始まらない")
	var placed := 0
	for unit: Unit in screen.battle.units:
		if unit.side == Unit.Side.PLAYER1 and unit.kind != UnitKind.Id.KING:
			placed += 1
	_expect(placed == chosen.entries.size() and source.human_deck.entries.size() == chosen.entries.size(), "出撃の準備で選んだ部隊で、対戦が始まらない")
	_expect(screen.cpu_opponent and screen.battle.armies[Unit.Side.PLAYER2] == episode.ENEMY_ARMY, "話の敵を CPU が動かしていない")
	# 対戦の途中の会話の札は、上の帯のすぐ下で、勝ち方の札・視点の案内・ミニマップと重ならない（いちばん長い台詞で確かめる）。
	var longest := ""
	for each: Script in Story.MILITARY.EPISODES:
		var constants: Dictionary = each.get_script_constant_map()
		for cue: Array in constants.get("CUES", []):
			if (cue[3] as String).length() > longest.length():
				longest = cue[3]
	screen.say_for_check([BattleCues.Line.new(1, episode.ENEMY_LEADER, longest)] as Array[BattleCues.Line])
	await get_tree().process_frame
	await get_tree().process_frame
	var card: Rect2 = screen.talk_card_rect()
	_expect(card.has_area() and card.position.y >= BattleHud.TOP_BAR_HEIGHT, "対戦の途中の会話の札が出ないか、上の帯に重なる: %s" % card)
	_expect(card.size.y <= 64.0, "対戦の途中の会話の札が、細い帯でない（2 行を超える高さ）: %s" % card)
	for other: Rect2 in screen.talk_card_neighbors():
		_expect(not card.intersects(other), "対戦の途中の会話の札が、勝ち方の札・視点の案内・ミニマップに重なる: %s と %s" % [card, other])
	# 小さな盤で、1 手で将を倒して勝つ。
	var board := _small_board(Vector2i(5, 4))
	var battle := Battle.new(board)
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER1, board.hq_cells[0])
	var foe := battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER2, board.hq_cells[1])
	foe.hp = 1
	var striker := battle.add_unit(UnitKind.Id.COMMANDO, Unit.Side.PLAYER1, board.hq_cells[1] + Vector2i(-1, 0))
	screen.start_with(battle, episode.LOOK, 1, episode.MAP.TITLE)
	screen.click_cell(striker.cell)
	screen.click_cell(foe.cell)
	var result: Node = screen.result_screen()
	for i in 1200:
		if not screen.is_busy() and result.visible:
			break
		await get_tree().process_frame
	_expect(battle.is_over() and battle.winner == Unit.Side.PLAYER1, "話の対戦で、勝てなかった")
	_expect(story.is_cleared(episode.ID), "話の対戦に勝っても、クリアを書かない")
	result.skip()
	for i in 600:
		if not result.enabled_buttons().is_empty():
			break
		await get_tree().process_frame
	_expect(result.can_continue() and result.new_board_fields().is_empty() and not result.can_go_to_setup(), "勝った話の決着の画面の行き先が違う（「次へ」が無い、か、選び直す行き先がある）")
	return result


## 画面の大きさを少し変えて戻す。抜けた場面の部品が、画面の大きさの合図につながったまま残っていれば、ここでエラーになる。
func _nudge_screen_size() -> void:
	var window := get_window()
	var size := window.content_scale_size
	window.content_scale_size = size + Vector2i(40, 0)
	await get_tree().process_frame
	window.content_scale_size = size
	await get_tree().process_frame


func _finish(message: String, code: int) -> void:
	_finished = true
	print(message)
	# 音を止めて手放してから終える（鳴らしたまま終えると、終わるときにエラーが出る）。
	var context: Variant = _scene.get(&"context") if is_instance_valid(_scene) else null
	if context != null:
		context.quit(code)
	else:
		get_tree().quit(code)
