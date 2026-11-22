extends Node
## 検査用の自動対戦。`-- --autoplay` を付けて起動すると、人の代わりに画面を操作する。
##
## 人と同じ入口（マスを選ぶ・待機・戻す・ターン終了・進化先を選ぶ）だけを使う。回すのは SCENES の場面で、
## 対戦を最後まで進める場面（game）と、小さな盤面で決まった手順を通す場面（環境オブジェクト、盤の上の効果、スキル、必殺技、
## 中立の駒、レベルアップ、進化、回復、閲覧、対戦設定、システムメニュー、CPU の番）、最後にタイトルと部隊編成の場面を通す場面。
## 長い検査（`-- --autoplay --full`）では、game のあとに盤面を作り直して、ほかのマップも少し動かす（そのうち 1 戦は、相手を CPU にする）。
##
## `-- --autoplay --story-all` と `-- --autoplay --versus-all` は、場面のかわりに、通しの点検の長い道を通す（autoplay_sweeps.gd）。
## `-- --autoplay --only <名前,…>` で、選んだ場面だけを回す（名前は SCENES の名前か、GROUPS のまとまりの名前）。
## 場面の中で確かめたことが外れたら、その場面の残りを飛ばして次の場面へ進み、最後にまとめて失敗にする。
## イベントを再生する場面（GROUPS の events）を全部回したときは、どの種類のイベントも 1 回は再生したことを確かめる。
## 全部が通れば "autoplay: OK" を出して終わる（tools/check.sh がこの行を確かめる）。

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

## 場面の名前 -> 説明（回す順）。決まった手順の場面は、同じ名前の _queue_<名前>_scene() が手順を積む。
const BattleHud := preload("res://game/battle_hud.gd")
const BattleTexts := preload("res://game/battle_texts.gd")
const ResultSummary := preload("res://game/result_summary.gd")

const SCENES := {
	"game": "人の操作で、対戦を最後まで進める（決着と戦績とログ）",
	"result": "リザルトの画面（game の決着のあと）",
	"portal_and_spring": "ポータルに止まってメニューの「転移」、転移のあと続けて動く、取り消し、ふさがったポータル、回復の泉",
	"capture": "敵の本陣の占拠と、拠点の確保（試しの決まり）",
	"barrel_draw": "樽の爆発で両方の将が倒れて引き分け",
	"field_effect": "盤の上の効果（盾・煙幕・聖域）",
	"skill": "スキルのボタンと対象選び、クールダウン",
	"status": "自分に使うスキルと、駒に付く状態",
	"extra_action": "行動を終えないスキルと、行動済みの駒を戻すスキル",
	"ult": "必殺技",
	"tactic": "作戦（試しの決まり。手札の札を、確かめてから 1 回ずつ使う）",
	"neutral": "中立の駒（湧く、攻撃する、カメラが追う）",
	"mid_boss": "中ボスと聖遺物",
	"level_up": "レベルアップ",
	"evolution": "進化",
	"heal": "回復役の回復、マスの情報、クリックとドラッグ",
	"inspection": "閲覧（行動の途中に相手の駒を見る）と、敵の全員の脅威範囲、相手の駒の範囲を表示したまま（ピン留め）",
	"setup": "対戦設定画面（後手で CPU と対戦する）",
	"system_menu": "システムメニューとオプションの画面",
	"minimap": "ミニマップ（押す・ドラッグで視点が移る、設定で隠す）",
	"cpu": "CPU の番（止める、ログ、カメラが追う）",
	"auto_turn": "自分の番のおまかせ（1 回目は確かめるだけ。2 回目で、残りの駒を CPU が動かしてターンを終える）",
	"cpu_skip": "相手（CPU）の番の早送りとスキップ（中立のフェーズから。途中で決着したら、決着を見せる）",
	"title": "相手の番の途中でタイトルへ戻り、マップ選択と対戦設定を行き来する",
	"decks": "部隊編成",
	"story": "ストーリーの 1 話の通し（タイトル → 物語を選ぶ → 話の一覧 → 出撃準備 → 会話 → 対戦 → 勝って「部隊変更」（会話を飛ばす）→ 勝って「次へ」→ 会話 →「話の一覧へ」 → 物語を選ぶ → タイトル、クリアの記録）",
}
## まとめて選べる名前。tools/check.sh は、この 2 つを別のプロセスで並べて回す。
## events はイベントを再生する場面（全部を回すと、全種類のイベントを 1 回は再生したかを確かめる）。ui は操作の決まりを確かめる場面。
const GROUPS := {
	"events": ["game", "result", "portal_and_spring", "capture", "barrel_draw", "field_effect", "skill", "status", "extra_action",
		"ult", "tactic", "neutral", "mid_boss", "level_up", "evolution", "heal", "cpu_skip", "auto_turn"],
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
	var args := OS.get_cmdline_user_args()
	if args.has("--story-all") or args.has("--versus-all"):
		_sweep.call_deferred(args)
	elif _selected.is_empty():
		_finish("autoplay: --only に知らない名前がある（場面: %s、まとまり: %s）" % [", ".join(SCENES.keys()), ", ".join(GROUPS.keys())], 1)
	elif not _selected.has("game"):
		_queue_scenes()


## 通しの点検の長い道（autoplay_sweeps.gd）を通して終える。場面（SCENES）は回さない。
func _sweep(args: PackedStringArray) -> void:
	_leaving = true
	var app := _scene.get_parent()
	reparent(app)  # このノードは対戦の場面の子なので、場面が消える前にアプリの子へ移る
	await AutoplaySweeps.new(self).run(app, args)
	_scene = app  # 対戦の場面はもう無い。終えるときは、アプリの context で音を止める
	_finish("autoplay: OK" if _failures.is_empty() else "autoplay: 失敗した所がある（%d 件）:\n  %s" % [_failures.size(), "\n  ".join(_failures)],
		0 if _failures.is_empty() else 1)


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


## 場面を回し終えたあと: イベントの再生を確かめ、タイトルと部隊編成の場面を通して終える。
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
			await _visit_second_campaign(app)
			await _visit_item_rows(app)
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


## ポータルを通る移動（ポータルへ歩く → メニューの「転移」→ 残りで続けて歩く）と、その取り消し、回復の泉の回復。
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
		_expect(not _scene.menu_ids().has(BattleTexts.MENU_WARP), "転移したあとも「転移」が出ている")
		_expect(_scene.painted_color(far) == _scene.COLOR_MOVE, "転移のあと、残りの移動力で届くマスを塗っていない")
		_scene.played.erase(moved)
		_scene.click_cell(far))
	_scripted.append(func() -> void:
		_expect(walker.cell == far, "転移のあと、続けて動けなかった")
		_expect(_scene.played.get(moved, 0) == 1, "続きの移動を再生しなかった")
		var last: String = _scene.battle_log.entries[-1].text
		_expect(last.contains("(0, 1) → (10, 1)") and last.contains("ポータル経由"), "ログが、ポータル経由の移動 1 行になっていない: " + last)
		_scene.cancel())
	_scripted.append(func() -> void:
		_expect(walker.cell == Vector2i(0, 1), "転移を取り消して、動く前のマスへ戻らなかった")
		_expect(_scene.painted_color(far) != _scene.COLOR_MOVE, "動く前の範囲を、転移の先まで広げている")
		# 行き先がふさがっているポータル: 止まれるが、「転移」は出ない。
		_click(blocked_walker.cell))
	_scripted.append(func() -> void: _click(Vector2i(1, 3)))
	_scripted.append(func() -> void:
		_expect(blocked_walker.cell == Vector2i(1, 3), "ふさがっているポータルのマスに止まれなかった")
		_expect(not _scene.menu_ids().has(BattleTexts.MENU_WARP), "行き先がふさがっているのに「転移」が出た")
		_scene.cancel())
	_scripted.append(func() -> void: _scene.cancel())
	_scripted.append(func() -> void: _click(walker.cell))
	_scripted.append(func() -> void: _click(Vector2i(1, 1)))
	_scripted.append(func() -> void: _scene.press_menu(BattleTexts.MENU_WARP))
	_scripted.append(func() -> void: _scene.click_cell(far))
	_scripted.append(func() -> void:
		_scene.played.erase(BattlePlayback.NEUTRAL_PHASE_SHOWN)
		_scene.press_wait())
	_scripted.append(_end_turn)
	_scripted.append(_end_turn)
	_scripted.append(func() -> void:
		_expect(battle.turn == 2 and battle.phase == Unit.Side.PLAYER1, "ターンが進まなかった")
		_expect(_scene.played.get(BattlePlayback.NEUTRAL_PHASE_SHOWN, 0) == 0, "中立の駒のいない番の知らせを出した")
		_expect(bather.hp == bather.max_hp() - 20 + MapObject.SPRING_HEAL, "回復の泉で回復しなかった"))


## 敵の本陣に乗ったままターンを終えて、占拠の数を進める。拠点（試しの決まり）にも駒を乗せておき、確保の数も進める。
func _queue_capture_scene() -> void:
	var board := _small_board(Vector2i(6, 4))
	board.stronghold_cell = Vector2i(2, 2)
	var battle := Battle.new(board)
	for side: Unit.Side in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
		battle.win_conditions[side].append(GameWonEvent.Reason.STRONGHOLD_HELD)
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER1, Vector2i(0, 3))
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER2, Vector2i(5, 3))
	var raider := battle.add_unit(UnitKind.Id.COMMANDO, Unit.Side.PLAYER1, Vector2i(3, 0))
	battle.add_unit(UnitKind.Id.SHIELD_TROOPER, Unit.Side.PLAYER1, board.stronghold_cell)

	_scripted.append(func() -> void: _scene.start_with(battle, StageLook.GRASSLAND, 1))
	_scripted.append(func() -> void: _scene.click_cell(raider.cell))
	_scripted.append(func() -> void: _scene.click_cell(board.hq_cells[Unit.Side.PLAYER2]))
	_scripted.append(func() -> void: _scene.press_wait())
	_scripted.append(_end_turn)
	_scripted.append(func() -> void: _expect(battle.capture_turns[Unit.Side.PLAYER1] == 1, "占拠の数が進まなかった"))
	_scripted.append(func() -> void: _expect(battle.stronghold_holds[Unit.Side.PLAYER1] == 1, "拠点の確保の数が進まなかった"))
	_scripted.append(func() -> void: _expect(_scene.stronghold_flag_color() == Palette.TEAM_BLUE, "拠点の旗が確保した陣営の色にならなかった"))


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
		_expect(screen.enabled_buttons().has("マップ選択へ") and not screen.enabled_buttons().has("タイトルへ"), "対戦モードの行き先に「マップ選択へ」が無い（か、「タイトルへ」がある）")
		_expect(screen.stat_lines().size() >= 2 and screen.mvp_text() != "", "戦績か MVP が出ていない")
		_expect(not screen.is_detail_open(), "詳しい戦績が、始めから開いている")
		screen.toggle_detail()
		_expect(screen.is_detail_open(), "詳しい戦績が開かない")
		var shown_side: int = screen.table_side()
		_expect(screen.table_names().size() == _scene.stats.records_of(shown_side as Unit.Side).size(), "詳しい戦績の表に、駒の行が並ばない")
		screen.show_table(1 - shown_side)
		_expect(screen.table_side() == 1 - shown_side and not screen.table_names().is_empty(), "詳しい戦績の表を、もう一方の陣営に切り替えられない")
		screen.toggle_detail()
		_expect(screen.enter_destination() == "マップ選択へ", "対戦モードの決着の画面の Enter がマップ選択へでない: %s" % screen.enter_destination())
		# 戦績の行がいちばん多い（5 行）ときも、入力の案内が下の帯にかからない。
		var full := ResultSummary.new()
		full.headline = "VICTORY"
		full.reason = "プレイヤー1（青） の勝ち　敵の将を倒した"
		full.focus_name = "プレイヤー1（青）"
		full.lines = [["マップ", "結晶の岩山"], ["経過ターン", "23 ターン"], ["敵軍撃破", "5 体"], ["中立撃破", "3 体"], ["聖遺物", "英知の聖遺物・勇気の聖遺物"]]
		full.mvp_name = "シールドトルーパー Lv3"
		screen.present(full)
		# 負けた話の台詞（いちばん多い 3 行、いちばん長い文）も、戦績の左に収まる。
		var remark: Array[BattleCues.Line] = []
		for side: int in [0, 1, 0]:
			remark.append(BattleCues.Line.new(side, "ドーソン", "あ".repeat(Episode.LOST_MAX_CHARS), {"kind": UnitKind.Id.SHIELD_TROOPER, "evolved": true}))
		screen.set_remark(remark)
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
		var said: Rect2 = screen.remark_rect()
		_expect(screen.remark_texts().size() == 3 and said.position.x >= 0.0 and said.end.x <= screen_size.x / 2.0 - 230.0
			and said.end.y <= screen_size.y - BattleHud.BOTTOM_BAR_HEIGHT,
			"負けたときの台詞の板が、画面からはみ出すか、戦績や下の帯にかかる: %s" % said)
		screen.toggle_detail()
		_expect(not screen.remark_rect().has_area(), "詳しい戦績を開いても、負けたときの台詞の板が表に重なって出ている")
		screen.toggle_detail()
		_expect(screen.remark_rect() == said, "詳しい戦績を閉じても、負けたときの台詞の板が戻らない")
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
		_expect_forecast([Names.skill(Skills.of(sorcerer)), Names.unit(burned), "ダメージ"], "ファイアボール")
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
		_scene.camera_follows.clear()
		_scene.played.erase(BattlePlayback.NEUTRAL_PHASE_SHOWN))
	_scripted.append(_end_turn)
	_scripted.append(_end_turn)
	_scripted.append(func() -> void:
		var core := battle.unit_at(font)
		_expect(core != null and core.side == Unit.Side.NEUTRAL, "結晶泉にエナジー・コアが湧かなかった")
		_expect(_scene.played.get(BattlePlayback.NEUTRAL_PHASE_SHOWN, 0) == 1, "中立の駒が湧いた番の知らせを出さなかった")
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
		# 進化先の選択肢と会話の札は、どちらも上の真ん中に出る。重なる間は、札を薄くする（文が選択肢の後ろから覗かない）。
		_scene.say_for_check([BattleCues.Line.new(1, "ウル", "あと 1 段で進化じゃ。いますぐ選ぶがよい。", {})] as Array[BattleCues.Line])
		_expect(not _scene.talk_card_rect().intersects(_scene.evolution_rect()) or _scene.is_talk_dimmed(),
			"進化先の選択肢に重なった会話の札が、薄くならない: %s と %s" % [_scene.talk_card_rect(), _scene.evolution_rect()])
		_scene.clear_talk_for_check()
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
		_expect(_scene.info_text().replace("\n", "").contains(Names.skill_summary(skill)), "駒の情報に、スキルの説明が出ていない")
		_scene.hover_menu_item(&"wait")
		_expect(_scene.info_text().contains("待機"), "メニューの項目の説明が出ていない")
		_scene.hover_menu_item(&"")
		_expect(not _scene.info_text().contains("待機:"), "マウスが離れても、項目の説明が残っている")
		_expect(_scene.press_menu(&"heal") and _scene.is_choosing_target(), "メニューの回復で、相手を選び始めなかった")
		_scene.hover(wounded.cell)
		_expect_forecast(["回復", Names.unit(wounded), "+%d" % medic.power()], "回復")
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
		_expect(not threat.is_empty() and painted.size() <= threat.size() and _scene.info_title().begins_with(Names.unit(unit)),
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
		_expect_forecast(["攻撃", Names.unit(foe), "ダメージ"], "攻撃")
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


## 対戦設定画面で、後手を選んで CPU と対戦する（CPU が先手で動き出す）。軍とマップも選んだとおりになる。
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
		_expect(_scene.ult_button_text().contains(Names.ult(Ults.of_army(UnitKind.Army.MILITARY))), "CPU の番に、必殺技のボタンが CPU のものになった: %s" % _scene.ult_button_text()))
	_scripted.append(func() -> void:
		var battle: Battle = _scene.battle
		_expect(not _scene.setup_panel().visible, "設定画面が閉じない")
		_expect(_scene.look == StageLook.CRYSTAL_FOREST, "選んだマップで始まらない")
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
		# 押すと対戦が終わるボタンは、2 回押させる（1 回目と、直後の 2 回目では終わらない。右クリックで確かめだけをやめる）。
		_scene.open_setup()
		for press: StringName in [&"press_map", &"press_start"]:
			panel.call(press)
			_expect(panel.visible and panel.confirming_text() != "", "%s の 1 回目で、確かめずに進んだ" % press)
			panel.call(press)
			_expect(panel.visible and _scene.battle == battle, "%s の確かめの直後の 2 回目で、対戦が終わった" % press)
			var right := InputEventMouseButton.new()
			right.button_index = MOUSE_BUTTON_RIGHT
			right.pressed = true
			panel._input(right)
			_expect(panel.visible and panel.confirming_text() == "", "右クリックで、%s の確かめがやめにならない" % press)
		panel.press_start()
		panel.press_map()  # ほかのボタンを押すと、そちらの確かめに変わる
		panel.pass_confirm_guard()
		panel.press_start()
		_expect(panel.visible and _scene.battle == battle, "別のボタンの確かめの間に、新しい対戦が始まった")
		panel.cancel()
		_expect(_scene.battle == battle and not panel.visible, "確かめの途中で閉じたら、対戦が変わった")
		# 手で作ったマップ（対戦モードで選べるもの）でも始まる。「新しいマップ」は生成のマップだけ（同じマップは形が変わらない）。
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
			_expect(_scene.source.new_board_fields() == VersusFields.generated_ids(), "手で作ったマップの対戦の「新しいマップ」が、生成のマップでない")
		# CPU の部隊を「ランダム編成」にすると、対戦の種から組んだ部隊で始まる。設定パネルの「編成確認」で、いまの部隊が見える。
		# 「同じマップで再戦」は同じ部隊、「新しいマップ」は新しい部隊（どちらも、ランダム編成のまま引き継ぐ）。
		_scene.open_setup()
		panel.choose_field(VersusFields.PLAIN)
		panel.choose_opponent(true)
		panel.choose_human_side(Unit.Side.PLAYER1)  # CPU は後手（始めてすぐには動かない）
		panel.choose_army(Unit.Side.PLAYER2, UnitKind.Army.FANTASY)
		_expect(panel.choose_deck(Unit.Side.PLAYER2, MatchChoice.RANDOM), "CPU の行で「ランダム編成」を選べない")
		panel.confirm()
		_expect(_cpu_kinds(Unit.Side.PLAYER2) == _squad_kinds(RandomSquad.for_battle(UnitKind.Army.FANTASY, _scene.map_seed, Unit.Side.PLAYER2)),
			"「ランダム編成」の CPU が、種から組んだ部隊で始まらない")
		var drawn := _cpu_kinds(Unit.Side.PLAYER2)
		_scene.open_setup()
		_expect(panel.current_choice().is_random(Unit.Side.PLAYER2) and panel.can_preview(Unit.Side.PLAYER2), "対戦の途中の設定パネルで、「ランダム編成」の部隊を確認できない")
		panel.open_preview(Unit.Side.PLAYER2)
		_expect(panel.preview().visible and panel.preview().shown_kinds().size() == drawn.size() + 1, "「編成確認」に、いまの対戦の「ランダム編成」の部隊が出ない")
		# 相手の部隊の札も、押すと詳しい説明が出る。右クリックで説明だけ閉じる。
		panel.preview().press_card(0)
		var detail: Control = panel.preview().detail()
		var first_kind: UnitKind.Id = panel.preview().shown_kinds()[1]
		_expect(detail.visible and detail.title_text() == Names.kind(first_kind) and detail.body_text().contains("スキル") == (Skills.of_kind(first_kind) != null),
			"対戦の途中の「編成確認」で、相手の駒の札を押しても詳しい説明が出ない: %s" % detail.title_text())
		var right := InputEventMouseButton.new()
		right.button_index = MOUSE_BUTTON_RIGHT
		right.pressed = true
		panel.get_viewport().push_input(right)
		_expect(not detail.visible and panel.preview().visible, "詳しい説明を右クリックで閉じると、編成確認まで閉じる（か、説明が閉じない）")
		panel.preview().close_preview()
		panel.cancel()
		_scene.start_battle(_scene.map_seed)  # 決着の画面の「同じマップで再戦」と同じ入口
		_expect(_cpu_kinds(Unit.Side.PLAYER2) == drawn, "「同じマップで再戦」で、「ランダム編成」の部隊が変わった")
		var changed := false
		for i in 3:  # 「新しいマップ」（種が替わる）。たまたま同じ部隊になることもあるので、何度か
			_scene.start_on_field(VersusFields.PLAIN, _scene.map_seed + 1)
			_expect(_scene.source.is_random(Unit.Side.PLAYER2), "「新しいマップ」で、「ランダム編成」が引き継がれない")
			_expect(_cpu_kinds(Unit.Side.PLAYER2) == _squad_kinds(RandomSquad.for_battle(UnitKind.Army.FANTASY, _scene.map_seed, Unit.Side.PLAYER2)),
				"「新しいマップ」の「ランダム編成」が、新しい種から組んだ部隊でない")
			changed = changed or _cpu_kinds(Unit.Side.PLAYER2) != drawn
		_expect(changed, "「新しいマップ」で、「ランダム編成」の部隊が変わらない")
		_scene.open_setup()
		panel.choose_deck(Unit.Side.PLAYER2, "")
		_scene.open_setup()
		panel.choose_opponent(false)
		panel.choose_human_side(Unit.Side.PLAYER1)
		panel.choose_army(Unit.Side.PLAYER1, UnitKind.Army.MILITARY)
		panel.choose_army(Unit.Side.PLAYER2, UnitKind.Army.FANTASY)
		panel.choose_field(VersusFields.PLAIN)
		var before: Battle = _scene.battle
		panel.press_start()  # 対戦の途中なので、確かめてから（間を置いた 2 回目で）始める
		_expect(_scene.battle == before, "「新しい対戦を始める」の 1 回目で、新しい対戦が始まった")
		panel.pass_confirm_guard()
		panel.press_start()
		_expect(_scene.battle != before and not panel.visible, "「新しい対戦を始める」の 2 回目で、新しい対戦が始まらない")
		_expect(not _scene.cpu_opponent and _scene.source.cpu_side() == Unit.Side.PLAYER2, "既定の設定に戻らない"))
	# 何も選び直せない対戦（battle_source.gd の既定の答え。ストーリーの 1 話も、マップ・相手・対戦設定は選び直せない）を渡すと、選び直す入口が出ない。
	var kept := {}
	_script_fixed_source(kept)


## いまの対戦の、side の駒（将を除く）の種類の並び（小さい順）。
func _cpu_kinds(side: Unit.Side) -> Array:
	var kinds: Array = _scene.battle.units.filter(func(unit: Unit) -> bool: return unit.side == side and unit.kind != UnitKind.Id.KING).map(func(unit: Unit) -> int: return unit.kind)
	kinds.sort()
	return kinds


## 部隊 deck の駒の種類の並び（小さい順）。
func _squad_kinds(deck: Deck) -> Array:
	var kinds: Array = deck.entries.map(func(entry: DeckEntry) -> int: return entry.kind)
	kinds.sort()
	return kinds


func _script_fixed_source(kept: Dictionary) -> void:
	_scripted.append(func() -> void:
		kept["source"] = _scene.source
		_scene.source = FixedSource.new()
		_scene.start_battle(_scene.map_seed + 1)
		var battle: Battle = _scene.battle
		_expect(_scene.look == StageLook.STONE_WALLS and battle.board.size == BoardGenerator.DEFAULT_SIZE, "渡したもので対戦が始まらない")
		_expect(not _scene.cpu_opponent, "渡した対戦設定の、誰が動かすかに従わない")
		_expect(not _scene.opponent_switch_shown(), "切り替えられない対戦に、相手のボタンが出た")
		_scene.toggle_opponent()
		_expect(not _scene.cpu_opponent, "切り替えられない対戦で、相手が切り替わった")
		_expect(_scene.menu_items().is_empty(), "対戦設定を開けない対戦に、システムメニューの「対戦設定へ」が出た")
		_scene.open_setup()
		_expect(not _scene.setup_panel().visible, "対戦設定を開けない対戦で、設定画面が開いた")
		_scene.start_on_field(VersusFields.PLAIN, _scene.map_seed + 1)
		_expect(_scene.battle == battle, "マップを選べない対戦で、マップを替えてやり直した")
		_expect(not _scene.result_screen().can_go_to_setup() and _scene.result_screen().new_board_fields().is_empty(),
			"選び直せない対戦の決着の画面に、対戦設定・新しいマップのボタンがある")
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
## オプションの画面で変えた値は、その場でカメラに効く。ゲームを終える項目は、対戦の途中なら確かめる（ここでは、やめる）。
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
		_expect(menu.item_ids() == ([&"resume", &"settings", &"match_setup", &"exit:map_select", &"title", &"quit"] as Array[StringName]), "メニューの項目が違う: %s" % [menu.item_ids()])
		_scene.click_cell(trooper.cell)
		_expect(_scene.selected_unit() == null, "メニューを開いている間に、駒を選べた")
		# 対戦が失われる項目は、確かめる。「やめる」で、メニューへ戻る。
		menu.press(&"quit")
		_expect(menu.confirming() == &"quit" and menu.confirm_text() != "", "ゲームを終える前に、確かめない")
		menu.back()
		_expect(menu.is_open() and menu.confirming() == &"", "確かめを、やめられない")
		# 設定の値は、その場で効く。
		menu.press(&"settings")
		_expect(menu.is_settings_open(), "オプションの画面が開かない")
		settings.set_value(&"mouse_sensitivity", 200)
		settings.set_value(&"invert_vertical_drag", true)
		var drag: Array = _scene.camera_drag_settings()
		_expect(is_equal_approx(drag[0], 2.0 * OrbitCamera.DEFAULT_DRAG_SENSITIVITY) and drag[1], "設定の値がカメラに効かない")
		settings.reset_all()
		drag = _scene.camera_drag_settings()
		_expect(is_equal_approx(drag[0], OrbitCamera.DEFAULT_DRAG_SENSITIVITY) and not drag[1], "既定に戻せない")
		menu.back()
		_expect(menu.is_open() and not menu.is_settings_open(), "オプションの画面から、メニューへ戻らない")
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
	# 軍を持たせて、上の帯に必殺技のゲージを出す（ゲージのぶん、陣営の欄が狭くなる）。
	battle.add_unit(UnitKind.Id.SNIPER, Unit.Side.PLAYER1, Vector2i(1, 9))
	battle.add_unit(UnitKind.Id.SORCERER, Unit.Side.PLAYER2, Vector2i(10, 0))
	battle.turn = 99  # 上の帯のターンの文がいちばん長いとき
	_scripted.append(func() -> void:
		_scene.set_opponent(true)  # 「相手: CPU」（「相手: 人」より幅を取る）。プレイヤー1 の番なので、CPU は動かない
		_scene.start_with(battle, StageLook.GRASSLAND, 1))
	_scripted.append(func() -> void:
		_expect(_scene.top_bar_cut_texts().is_empty(), "上の帯の陣営の欄（駒の数と占拠）が切れている: %s" % [_scene.top_bar_cut_texts()])
		_scene.set_opponent(false)
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

	# 任せた側の駒が上限のレベルに届いたら、CPU は止まり、進化先は人が選ぶ。選ぶと、残りを CPU が続けてターンを終える。
	var board2 := _small_board(Vector2i(6, 4))
	var battle2 := Battle.new(board2)
	battle2.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER1, Vector2i(0, 3))
	battle2.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER2, Vector2i(5, 0))
	var paladin := battle2.add_unit(UnitKind.Id.PALADIN, Unit.Side.PLAYER1, Vector2i(2, 2))
	paladin.level = Growth.MAX_LEVEL - 1
	paladin.experience = Growth.EXPERIENCE_PER_LEVEL - Growth.HIT_EXPERIENCE
	battle2.add_unit(UnitKind.Id.SHIELD_TROOPER, Unit.Side.PLAYER2, Vector2i(3, 2))
	_scripted.append(func() -> void: _scene.start_with(battle2, StageLook.GRASSLAND, 1))
	_scripted.append(func() -> void:
		_scene.press_auto()
		_scene.pass_confirm_guard()
		_scene.press_auto()
		_expect(_scene.auto_side() == Unit.Side.PLAYER1, "2 回目で任せなかった"))
	_scripted.append(func() -> void:
		_expect(battle2.phase == Unit.Side.PLAYER1 and battle2.evolving_unit() == paladin, "おまかせの途中で、進化先を選ぶ前に進んだ（か、上限に届かなかった）")
		_expect(paladin.evolution == Evolution.Id.NONE and _scene.is_choosing_evolution(), "おまかせの途中で、進化先を CPU が選んだ")
		_scene.choose_evolution(1))
	_scripted.append(func() -> void:
		_expect(paladin.evolution == Evolution.Id.CRUSADER, "選んだ進化先にならなかった")
		_expect(battle2.phase == Unit.Side.PLAYER2 and _scene.auto_side() == -1, "進化先を選んだあと、おまかせの続きを進めなかった"))


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


## 作戦（試しの決まり）。手札のボタンは、1 回目は確かめるだけで、もう一度押すと使う。使った札は、もう押せない。使っても駒の行動は残る。
func _queue_tactic_scene() -> void:
	var board := _small_board(Vector2i(7, 5))
	var battle := Battle.new(board)
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER1, Vector2i(0, 4))
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER2, Vector2i(6, 0))
	var trooper := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, Unit.Side.PLAYER1, Vector2i(1, 3))
	trooper.hp -= 20
	battle.tactics[Unit.Side.PLAYER1] = [Tactics.Id.SUPPLY, Tactics.Id.MARCH]
	var used: Script = TacticUsedEvent
	var move := trooper.move_range()

	_scripted.append(func() -> void:
		_scene.set_opponent(false)
		_scene.start_with(battle, StageLook.GRASSLAND, 1))
	_scripted.append(func() -> void:
		_expect(_scene.tactic_buttons() == [[Names.tactic(Tactics.Id.SUPPLY), true], [Names.tactic(Tactics.Id.MARCH), true]], "作戦のボタンが、手札の順に出ていない")
		_expect(_scene.notice_text().contains("作戦"), "対戦の始めに、作戦の知らせが出ていない")
		_expect(_scene.tactic_note_text() == "", "札に乗せる前から、札の説明が出ている")
		_scene.hover_tactic(1)
		_expect(_scene.tactic_note_text().contains(Names.tactic_summary(Tactics.Id.MARCH)), "札に乗せても、効果が出ない")
		_scene.hover_tactic(-1)
		_scene.press_tactic(0)
		_expect(battle.tactics_used[0].is_empty(), "1 回押しただけで、作戦を使った")
		_expect(_scene.tactic_note_text().contains(Names.tactic_summary(Tactics.Id.SUPPLY)), "使うかを確かめている間に、効果が出ていない")
		_scene.press_tactic(0)
		_expect(battle.tactics_used[0].is_empty(), "素早い 2 回押しで、作戦の確かめを飛ばした")
		_scene.pass_confirm_guard()
		_scene.press_tactic(0))
	_scripted.append(func() -> void:
		_expect(battle.tactics_used[0] == [Tactics.Id.SUPPLY], "補給を使えなかった")
		_expect(_scene.played.get(used, 0) == 1, "作戦を再生しなかった")
		_expect(trooper.hp == trooper.max_hp() - 20 + Tactics.SUPPLY_HEAL, "補給で回復しなかった")
		_expect(not _scene.tactic_buttons()[0][1], "使った札が、まだ押せる")
		_expect(_scene.tactic_note_text().contains(Names.tactic_summary(Tactics.Id.SUPPLY)), "使った札の効果を知らせていない")
		_expect(_scene.battle_log.entries.any(func(entry: RefCounted) -> bool: return (entry.text as String).contains(Names.tactic_summary(Tactics.Id.SUPPLY))),
			"ログに、使った札の効果が無い")
		_scene.press_tactic(1)
		_scene.pass_confirm_guard()
		_scene.press_tactic(1))
	_scripted.append(func() -> void:
		_expect(trooper.move_range() == move + Tactics.MARCH_MOVE and not trooper.acted, "強行軍が付いていない")
		# 確かめの途中で番を終えたら、次のプレイヤーへ持ち越さない（次のプレイヤーも、1 回目は確かめるだけ）。
		battle.tactics[Unit.Side.PLAYER1].append(Tactics.Id.WARD)
		battle.tactics[Unit.Side.PLAYER2] = [Tactics.Id.SUPPLY, Tactics.Id.MARCH, Tactics.Id.RALLY]
		_scene.press_tactic(2)
		_scene.pass_confirm_guard()
		_end_turn())
	_scripted.append(func() -> void:
		_scene.press_tactic(2)
		_expect(battle.tactics_used[Unit.Side.PLAYER2].is_empty(), "前のプレイヤーの確かめを引き継いで、作戦を使った"))


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
		_expect(_scene.hint_cut_lines().is_empty(), "必殺技のボタンが広がって、下の帯の案内が切れた: %s" % [_scene.hint_cut_lines()])
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
## 止まっていた再生や CPU の番が続きを走らない（エラーが出ない）こと。そのあと、タイトルの「対戦」で対戦設定の場面へ進み、
## 「タイトルへ戻る」でタイトルへ戻る。このノードは対戦の場面の子なので、先にアプリの子へ移っておく。
func _leave_battle(app: Node) -> void:
	var menu: Node = app.system_menu()
	_scene.set_opponent(false)
	_scene.start_on_field(VersusFields.PLAIN, _scene.map_seed + 1)
	_scene.set_opponent(true)
	_end_turn()
	_expect(_scene.is_busy(), "ターンを終えても、相手の番に入らない")
	# ウィンドウの ×: すぐには閉じずに確かめる（どの画面でも同じ文）。確かめている間は時間を止める。キャンセルで続く。
	app.request_close()
	var quit_window: Node = app.quit_window
	_expect(quit_window.is_open() and quit_window.question().contains("セーブしていない内容は失われます。"),
		"対戦の途中にウィンドウの × を押しても、確かめない: %s" % quit_window.question())
	_expect(app.context.overlays.pauses() and Engine.time_scale == 0.0, "閉じる確かめの間、対戦の時間（再生）が止まらない")
	quit_window.cancel()
	_expect(not quit_window.is_open() and _scene.in_progress() and not app.context.overlays.is_open() and Engine.time_scale > 0.0,
		"閉じる確かめのキャンセルで、対戦へ戻らない（か、時間が止まったまま）")
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
	_expect(app.current_id() == SceneFlow.MAP_SELECT, "タイトルの「対戦」で、マップ選択へ進まない")
	var stages: Node = app.current_scene()
	await get_tree().process_frame
	_expect(stages.card_fields() == VersusFields.ids(), "マップのカードが一覧と合わない")
	for field in VersusFields.ids():
		var card: Control = stages.card_of(field)
		_expect(card.get_global_rect().size.x > 0.0 and _on_screen(card), "マップのカードが画面からはみ出す: %s" % field)
	stages.hover(VersusFields.TWIN_SPRINGS)
	_expect(stages.note_text().contains(VersusFields.title_of(VersusFields.TWIN_SPRINGS)), "カードに乗せても、説明が出ない")
	# カードを通り過ぎただけ（乗せて、待たずに離れた）なら、背景の景色は替えない。
	stages.hover(&"")
	_expect(stages.scape_field() != VersusFields.TWIN_SPRINGS, "カードを通り過ぎただけで、背景の景色が替わろうとした")
	stages.hover(VersusFields.TWIN_SPRINGS)
	# 背景の景色は、乗せたマップのものに替わる（少し待ってから、幕を沈めて替える。ここでは待たずに替える）。
	_expect(stages.scape_field() == VersusFields.TWIN_SPRINGS, "カードに乗せても、背景の景色がそのマップに替わろうとしない")
	stages.show_scape_now()
	_expect(stages.backdrop_look() == VersusFields.look_of(VersusFields.TWIN_SPRINGS), "カードに乗せても、背景の景色がそのマップのものにならない: %s" % stages.backdrop_look())
	stages.hover(&"")
	# どのカードに乗せても、ほかの部品（説明の欄、カードの段、ボタン）の位置と大きさが変わらない（説明の長さで揺れない）。
	var cards: Array[Node] = []
	for field in VersusFields.ids():
		cards.append(stages.card_of(field))
	await _expect_steady(stages, cards, VersusFields.ids().map(func(field: StringName) -> Callable: return stages.hover.bind(field)),
		"マップ選択でカードに乗せる")
	stages.hover(&"")
	# キーボードでは、左右の矢印で選ぶ（選んだカードの説明が出る）。
	var fields := VersusFields.ids()
	_push_key(app, KEY_RIGHT)
	_expect(stages.hovered_field() == fields[0], "マップ選択で右の矢印を押しても、最初のカードが選ばれない")
	_push_key(app, KEY_RIGHT)
	_push_key(app, KEY_RIGHT)
	_push_key(app, KEY_LEFT)
	_expect(stages.hovered_field() == fields[1] and stages.note_text().contains(VersusFields.title_of(fields[1])),
		"マップ選択で左右の矢印で選んでも、そのカードが選ばれない（か、説明が出ない）")
	stages.hover(&"")
	# マップを選ぶ前にも、部隊編成（対戦用）へ寄り道できる。戻るとマップ選択。
	stages.press_edit_decks()
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.DECKS and app.current_scene().mode() == DeckRules.VERSUS and app.current_scene().back_label() == "マップ選択へ戻る",
		"マップ選択の「部隊編成」で、対戦用の部隊編成へ進まない（か、戻り先の文字が違う）")
	app.current_scene().press_back()
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.MAP_SELECT, "マップ選択から開いた部隊編成の「マップ選択へ戻る」で、マップ選択へ戻らない")
	stages = app.current_scene()
	stages.choose(VersusFields.LABYRINTH)
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.SETUP, "マップ選択のカードで、対戦設定へ進まない")
	_expect(app.current_scene().setup_panel().current_choice().field == VersusFields.LABYRINTH, "選んだマップが対戦設定に渡らない")
	_expect(app.current_scene().backdrop_look() == VersusFields.look_of(VersusFields.LABYRINTH), "対戦設定の背景が、選んだマップの景色でない: %s" % app.current_scene().backdrop_look())
	app.current_scene().setup_panel().cancel()
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.MAP_SELECT, "対戦設定の「マップ選択へ戻る」で、マップ選択へ戻らない")
	# カードの上での右クリックでも戻る（カードのボタンに食われない）。
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	right.position = app.current_scene().card_center(VersusFields.LABYRINTH)
	right.global_position = right.position
	app.get_viewport().push_input(right)
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.TITLE, "マップ選択のカードの上で右クリックしても、タイトルへ戻らない")


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


## 部隊編成の場面: 組む・並べ替える・装備を持たせる・取っておく・写す・名前を変える・消す（確かめる）。
## 出せない部隊は取っておけない。取っておいた部隊を、対戦設定で選べる（出せない部隊は選べない）。
func _visit_decks(app: Node) -> void:
	var library: RefCounted = app.context.decks
	_expect(app.current_scene().button_texts() == (["ストーリー", "対戦", "オプション", "終了"] as Array[String]),
		"タイトルのメニューの並びが違う: %s" % [app.current_scene().button_texts()])
	# 部隊編成は、対戦設定の「部隊編成」から開く（タイトルには無い）。
	app.current_scene().press_start()
	await app.scene_changed
	app.current_scene().choose(VersusFields.PLAIN)
	await app.scene_changed
	var setup_panel: Node = app.current_scene().setup_panel()
	# 相手・手番・軍を選び替えても、パネルの部品の位置と大きさが変わらない。
	var setup_moves: Array = []
	for side: Unit.Side in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
		for army: UnitKind.Army in UnitKind.Army.values():
			setup_moves.append(setup_panel.choose_army.bind(side, army))
	setup_moves.append(setup_panel.choose_human_side.bind(Unit.Side.PLAYER2))
	setup_moves.append(setup_panel.choose_random_side)
	setup_moves.append(setup_panel.choose_opponent.bind(false))
	setup_moves.append(setup_panel.choose_opponent.bind(true))
	await _expect_steady(app.current_scene(), [], setup_moves, "対戦設定で選び替える")
	setup_panel.choose_opponent(true)
	setup_panel.choose_human_side(Unit.Side.PLAYER1)
	setup_panel.choose_army(Unit.Side.PLAYER1, UnitKind.Army.MILITARY)
	# 初期位置: 人の行の「初期位置」で窓を開き、駒を動かして閉じると、その置き方で対戦が作られる。
	setup_panel.open_placement(Unit.Side.PLAYER1)
	var dialog: Control = setup_panel.placement_dialog()
	var place_map: Control = dialog.deploy_map()
	var placed_cells: Array[Vector2i] = place_map.unit_cells()
	var open_cells: Array = place_map.zone().filter(func(cell: Vector2i) -> bool: return not placed_cells.has(cell))
	_expect(dialog.visible and not placed_cells.is_empty() and not open_cells.is_empty(), "対戦設定の「初期位置」で、駒と置けるマスの窓が開かない")
	var place_note: Control = dialog.deploy_note()
	_expect(place_note.shown_unit_id() == -1, "初期位置の窓で、駒を選ぶ前から駒の欄に駒が出ている")
	await _hover_each(place_map)
	place_map.hover_cell(placed_cells[1])
	var hovered_unit: Unit = place_map.focused_unit()
	_expect(hovered_unit != null and place_note.shown_name() == Names.kind(hovered_unit.kind), "初期位置の窓で、マウスを乗せた駒の名前が欄に出ない")
	place_map.press_cell(placed_cells[0])
	var picked_unit: Unit = place_map.focused_unit()
	_expect(picked_unit != hovered_unit and place_note.shown_unit_id() == picked_unit.id, "初期位置の窓で、選んだ駒が欄に出ない（マウスを乗せた駒より先に）")
	# 選んだ駒を、マウスを乗せた駒と入れ替えると、マウスの下には選んだ駒が来る（欄も、その駒を出す）。
	place_map.press_cell(placed_cells[1])
	_expect(place_map.selected() == -1 and place_map.focused_unit() == picked_unit and place_note.shown_unit_id() == picked_unit.id,
		"初期位置の窓で駒を入れ替えたあと、マウスの下の駒が古いまま")
	place_map.reset()
	_expect(place_map.focused_unit() == hovered_unit, "初期位置の窓で「おまかせ」に戻したあと、マウスの下の駒が古いまま")
	place_map.hover_cell(Deployment.NO_CELL)
	place_map.press_cell(placed_cells[0])
	place_map.press_cell(open_cells[0])
	dialog.close_dialog()
	var placed_choice: RefCounted = setup_panel.current_choice()
	_expect(not dialog.visible and not placed_choice.placements[Unit.Side.PLAYER1].is_empty(), "初期位置の窓を閉じても、決めた置き方が対戦設定に残らない")
	var placed_battle: Battle = placed_choice.to_setup(setup_panel.PLACEMENT_SEED).create_battle()
	var first_unit: Array = placed_battle.units.filter(func(unit: Unit) -> bool: return unit.side == Unit.Side.PLAYER1 and unit.kind != UnitKind.Id.KING)
	_expect(first_unit[0].cell == open_cells[0], "対戦設定で決めた初期位置から、対戦が始まらない")
	_expect(not setup_panel.placement_button_shown(Unit.Side.PLAYER2), "CPU の行に「初期位置」がある")
	setup_panel.choose_army(Unit.Side.PLAYER1, UnitKind.Army.FANTASY)
	_expect(placed_choice.placements[Unit.Side.PLAYER1].is_empty(), "軍（部隊）を替えても、初期位置がおまかせに戻らない")
	setup_panel.choose_army(Unit.Side.PLAYER1, UnitKind.Army.MILITARY)
	_expect(setup_panel.can_edit_decks(), "対戦設定に「部隊編成」が無い")
	setup_panel.press_edit_decks(Unit.Side.PLAYER1)
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.DECKS, "対戦設定の「部隊編成」で、編成の場面へ進まない")
	var screen: Node = app.current_scene()
	_expect(screen.is_detour() and screen.mode() == DeckRules.VERSUS and screen.back_label() == "対戦設定へ戻る", "対戦設定からの編成が、対戦用でない（か、戻り先の文字が違う）")
	_expect(screen.listed_ids().is_empty() and screen.list_card_kinds().is_empty(), "部隊が無いのに、一覧か札が出ている")
	screen.press_new()
	_expect(screen.is_choosing_army() and not screen.is_editing(), "「新しい部隊」で、まず軍を選ぶ画面が出ない")
	screen.press_back()
	_expect(not screen.is_choosing_army() and not screen.is_editing(), "軍を選ぶ画面から、右クリックで一覧へ戻らない")
	screen.press_new()
	screen.choose_new_army(UnitKind.Army.MILITARY)
	_expect(screen.is_editing() and screen.editing_deck().entries.is_empty() and screen.editing_deck().army == UnitKind.Army.MILITARY, "選んだ軍で、空の部隊を組めない")
	_expect(not screen.is_choosing_army(), "軍を選んで組む画面へ進んでも、軍を選ぶ画面が後ろに残っている")
	_expect(not screen.can_save(), "空の部隊を取っておけた")
	screen.hire(UnitKind.Id.SHIELD_TROOPER)
	screen.hire(UnitKind.Id.SNIPER)
	_expect(screen.selected_entry() == 1, "雇った駒が選ばれない")
	screen.select_entry(0)
	screen.equip(Equipment.Id.IRON_SHIELD)
	var deck: Deck = screen.editing_deck()
	_expect(deck.entries[0].kind == UnitKind.Id.SHIELD_TROOPER and deck.entries[0].equipment.size() == 1 and screen.selected_entry() == 0, "選んだ駒に、持ち物を持たせられない")
	_expect(screen.troop_row_button_texts(0).filter(func(text: String) -> bool: return text in ["▲", "▼"]).is_empty(), "部隊の行に、並べ替え（配置）のボタンが残っている")
	# 装備の文が行に収まらなくても、マウスを乗せれば全部読める。
	screen.equip(Equipment.Id.SPEED_BOOTS)
	var row_texts: Array[String] = screen.troop_row_texts(0)
	_expect(row_texts[1] == row_texts[0] and row_texts[1].contains("スピードブーツ") and row_texts[1].contains("アイアンシールド"),
		"部隊の行の装備の文を、マウスを乗せても読めない: %s" % [row_texts])
	screen.unequip(Equipment.Id.SPEED_BOOTS)
	# どの駒に乗せても、どの駒を選んでも、ほかの部品（列、見出し、ボタン）の位置と大きさが変わらない。
	# （選ぶ・選ぶのをやめるのはクリックなので、持ち物の欄が出入りしてよい。比べるのは、選んだまま乗せる・選び替える。）
	for selected: int in [-1, 0]:
		screen.select_entry(selected)
		var editor_moves: Array = []
		for kind: UnitKind.Id in screen.editing_deck().available_kinds():
			editor_moves.append(screen.hover_kind.bind(kind))
		editor_moves.append(screen.hover_kind.bind(-1))
		if selected != -1:
			editor_moves.append(screen.select_entry.bind(1))
			editor_moves.append(screen.select_entry.bind(0))
		await _expect_steady(screen, [], editor_moves, "部隊編成で駒に乗せる・選ぶ")
	screen.select_entry(0)
	for i in 4:
		screen.hire(UnitKind.Id.SHIELD_TROOPER)
	screen.equip(Equipment.Id.SPEED_BOOTS)  # 予算 24 を 1 超える
	_expect(not screen.can_save() and deck.problems() == ([Deck.Problem.OVER_BUDGET] as Array[Deck.Problem]), "予算を超えた部隊を取っておけた")
	await screen.get_tree().process_frame
	await screen.get_tree().process_frame
	_expect(screen.issues_shown_whole(), "出撃不可の理由が、途中で切れている")
	screen.press_save()
	_expect(screen.is_editing() and library.size() == 0, "出せない部隊が取っておかれた")
	screen.remove_entry(5)
	screen.press_back()  # 選択をやめる
	_expect(screen.selected_entry() == -1 and screen.is_editing(), "右クリックで、選択をやめない")
	screen.press_save()
	_expect(not screen.is_editing() and library.size() == 1, "出せる部隊を取っておけない")
	var id: String = screen.list_selected()
	# 対戦設定で選べる。
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
	await screen.get_tree().process_frame
	await screen.get_tree().process_frame
	_expect(screen.list_card_cut_texts().is_empty(), "一覧の右の駒の札の文が切れている: %s" % [screen.list_card_cut_texts()])
	screen.press_edit()
	screen.remove_entry(0)
	screen.press_back()
	_expect(screen.is_dialog_open(), "変えたところがあるのに、確かめずに一覧へ戻った")
	screen.accept_dialog()
	_expect(not screen.is_editing() and library.find(id).deck.entries.size() == 5, "取っておかずに戻ったのに、部隊が変わった")
	# ストーリー用の部隊: 切り替えると、対戦用の部隊は並ばない。雇える駒は、いま解放した駒だけ。
	_expect(screen.mode() == DeckRules.VERSUS and screen.listed_ids() == ([id] as Array[String]), "対戦用の一覧が違う")
	screen.set_mode(Story.military().rules_id)
	_expect(screen.listed_ids().is_empty(), "ストーリー用の一覧に、対戦用の部隊が混ざった")
	screen.press_new()
	_expect(screen.editing_deck().rules.id == Story.military().rules_id and screen.editing_deck().army == Story.military().army, "ストーリー用の部隊を、ストーリーの決まりで組めない")
	_expect(screen.editing_deck().available_kinds() == app.context.story.unlocked_kinds() or screen.editing_deck().available_kinds().size() == app.context.story.unlocked_kinds().size(), "ストーリー用の雇える駒が、いま解放した駒と違う")
	screen.hire(UnitKind.Id.COMMANDO)
	_expect(screen.editing_deck().entries.is_empty() or app.context.story.unlocked_kinds().has(UnitKind.Id.COMMANDO), "まだ解放していない駒を雇えた")
	screen.hire(UnitKind.Id.SNIPER)
	screen.hire(UnitKind.Id.SNIPER)
	screen.hire(UnitKind.Id.MEDIC)
	# まだ持たせられない持ち物（物語の解放の前）は、持たせられない。
	screen.select_entry(0)
	for item: Equipment.Id in Equipment.Id.values():
		if not screen.editing_deck().rules.allows_item(item):
			screen.equip(item)
			_expect(screen.editing_deck().entries[0].count(item) == 0, "まだ持たせられない持ち物を持たせられた")
	screen.select_entry(-1)
	screen.press_save()
	var story_id: String = screen.list_selected()
	_expect(not screen.is_editing() and screen.listed_ids() == ([story_id] as Array[String]), "ストーリー用の部隊を取っておけない")
	_expect(library.find(story_id).deck.rules.id == Story.military().rules_id, "ストーリー用の部隊が、ストーリーの決まりで取っておかれていない")
	# ストーリー用は物語ごと: ほかの物語の決まりでは、その物語の軍で組み、ほかの物語の部隊は並ばない。
	var other: RefCounted = Story.campaigns()[1]
	screen.set_mode(other.rules_id)
	_expect(screen.mode() == other.rules_id and screen.rules.armies() == ([other.army] as Array[UnitKind.Army]), "ほかの物語の、ストーリー用の決まりで組めない")
	_expect(screen.listed_ids().is_empty(), "ほかの物語のストーリー用の一覧に、別の物語の部隊が混ざった")
	screen.set_mode(DeckRules.VERSUS)
	_expect(screen.listed_ids() == ([id] as Array[String]), "対戦用の一覧に、ストーリー用の部隊が混ざった")
	var versus_ids: Array[String] = []
	for item: RefCounted in library.for_rules(DeckRules.VERSUS):
		versus_ids.append(item.id)
	_expect(not versus_ids.has(story_id), "対戦設定で選べる部隊に、ストーリー用の部隊が混ざった")
	screen.select_saved(id)
	screen.press_edit()
	screen.press_save()  # 寄り道の間に最後に取っておいた部隊が、戻った対戦設定で選ばれる
	screen.press_back()
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.SETUP, "編成の一覧から、対戦設定へ戻らない")
	var panel: Node = app.current_scene().setup_panel()
	_expect(panel.current_choice().deck_ids[0] == id, "寄り道で取っておいた部隊が、対戦設定で選ばれていない")
	var ids: Array = panel.deck_options(Unit.Side.PLAYER1).map(func(option: Array) -> String: return option[0])
	_expect(ids == ["", MatchChoice.RANDOM, id], "対戦設定に、取っておいた部隊が並ばない: %s" % [ids])
	_expect(panel.choose_deck(Unit.Side.PLAYER1, id), "取っておいた部隊を選べない")
	panel.open_preview(Unit.Side.PLAYER1)
	_expect(panel.preview().visible and panel.preview().shown_kinds().size() == 6, "「編成を確認」で、選んだ部隊が出ない")
	# 札を押すと、その駒の詳しい説明（役割・能力値・スキル・持ち物の効果・進化先）。将も。
	panel.preview().press_card(-1)
	_expect(panel.preview().detail().visible and panel.preview().detail().title_text() == Names.kind(UnitKind.Id.KING), "「編成確認」で将の札を押しても、詳しい説明が出ない")
	panel.preview().close_preview()
	_expect(not panel.preview().detail().visible, "編成確認を閉じても、詳しい説明が残る")
	# マップは対戦設定では選ばない。「マップ選択へ戻る」で戻って選び直す（選んだものは残る）。マップ選択へ行くボタンは 1 つ。
	_expect(not panel.map_button_shown(), "対戦設定に、マップ選択へ行くボタンが 2 つある")
	panel.choose_random_side()
	panel.cancel()
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.MAP_SELECT, "「マップ選択へ戻る」で、マップ選択へ戻らない")
	app.current_scene().choose(VersusFields.LABYRINTH)
	await app.scene_changed
	panel = app.current_scene().setup_panel()
	_expect(panel.current_choice().field == VersusFields.LABYRINTH and panel.current_choice().random_side and panel.current_choice().deck_ids[0] == id,
		"マップを選び直したら、ほかの選択が失われた")
	panel.choose_human_side(Unit.Side.PLAYER1)
	var setup: MatchSetup = panel.current_choice().to_setup(1)
	_expect(setup.is_valid() and setup.decks[0].entries.size() == 5 and setup.decks[0].entries[0].kind == UnitKind.Id.SHIELD_TROOPER, "選んだ部隊で対戦を作らない")
	_expect(setup.decks[1].entries.size() == CpuDeck.build(setup.army_of(Unit.Side.PLAYER2)).entries.size(), "CPU の編成が変わった")
	panel.cancel()
	await app.scene_changed


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


func _visit_story(app: Node) -> void:
	var story: RefCounted = app.context.story
	story.choose_campaign(Story.military())
	for each: RefCounted in Story.military().episodes:
		if each.squad_deck() == null:
			break
		story.clear(each.id)
	var episode: RefCounted = story.next_episode()
	var first := Story.military().episodes.find(episode)
	_expect(first > 0 and episode.squad_deck() == null, "部隊を選ぶ話が無い")
	_expect(not story.is_cleared(episode.id), "始める前から、話をクリアしている")
	_expect(app.current_scene().story_label() == "ストーリー", "クリア前のタイトルに、済みの印が付いている")
	app.current_scene().press_story()
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.SLOTS, "タイトルの「ストーリー」で、セーブデータ選択へ進まない")
	# セーブデータ選択: どのスロットもまだ空き（はじめから）。1 番を選ぶと、物語を選ぶ場面へ。
	var slots_screen: Node = app.current_scene()
	# （1 番は、前の場面の部隊編成でストーリー用の部隊を組んでいれば、もう書いてある）
	for number in range(1, 4):
		_expect(slots_screen.is_card_enabled(number) and (slots_screen.card_text(number).ends_with("はじめから") or number == 1), "空きのスロット %d が「はじめから」でない" % number)
	var saves_before: int = app.save_mark.shown_count
	slots_screen.choose(1)
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.CAMPAIGNS, "セーブデータ選択でスロットを選んでも、物語を選ぶ場面へ進まない")
	_expect(app.context.slots.is_started() and story.is_cleared(Story.military().episodes[0].id), "はじめからで始めたスロットに、前から持っていた進み具合が残っていない")
	var campaigns: Node = app.current_scene()
	_expect(campaigns.campaigns() == Story.campaigns(), "物語を選ぶ場面に、全部の物語が並んでいない")
	for each: RefCounted in Story.campaigns():
		_expect(campaigns.is_card_enabled(each) == Story.is_ready(each)
				and (campaigns.status_text(each) == "準備中") == not Story.is_ready(each), "話の無い物語を選べる（か、ある物語を選べない）: %s" % each.title)
	# 物語選択の「部隊編成」（物語ごと）: その物語のストーリー用の部隊編成へ。戻ると物語選択。
	campaigns.press_edit_decks(Story.campaigns()[1])
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.DECKS and app.current_scene().mode() == Story.campaigns()[1].rules_id and app.current_scene().back_label() == "物語選択へ戻る",
		"物語選択の「部隊編成」で、その物語のストーリー用の部隊編成へ進まない（か、戻り先の文字が違う）")
	app.current_scene().press_back()
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.CAMPAIGNS, "物語選択から開いた部隊編成の「物語選択へ戻る」で、物語選択へ戻らない")
	campaigns = app.current_scene()
	campaigns.choose(Story.military())
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.EPISODES and story.campaign == Story.military(), "物語を選んでも、その物語の話の一覧へ進まない")
	var list: Node = app.current_scene()
	# 話の一覧の「部隊編成」: この物語のストーリー用の部隊編成へ。戻ると話の一覧。
	list.press_edit_decks()
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.DECKS and app.current_scene().mode() == Story.military().rules_id and app.current_scene().back_label() == "話の一覧へ戻る",
		"話の一覧の「部隊編成」で、この物語のストーリー用の部隊編成へ進まない（か、戻り先の文字が違う）")
	app.current_scene().press_back()
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.EPISODES, "話の一覧から開いた部隊編成の「話の一覧へ戻る」で、話の一覧へ戻らない")
	list = app.current_scene()
	_expect(list.episodes().size() == Story.military().episodes.size(), "話の一覧に、全部の話が並んでいない")
	_expect(list.is_card_enabled(Story.military().episodes[0]) and list.card_status(Story.military().episodes[0]) == "クリア済み", "クリアした最初の話を選び直せない")
	_expect(list.is_card_enabled(episode) and list.card_status(episode) == "未クリア", "次の話を選べない")
	_expect(list.card_title(episode) == episode.title and list.is_card_revealed(episode), "次に遊ぶ話のカードの名前か縮図が伏せてある")
	for later: RefCounted in Story.military().episodes.slice(first + 1):
		_expect(not list.is_card_enabled(later), "前の話をクリアしていないのに、%s を選べる" % later.title)
		_expect(list.card_title(later) == "？？？" and not list.is_card_revealed(later), "まだ遊べない %s のカードの名前か縮図・顔が見えている" % later.title)
	# 確かめ用の解放（F5）: 話の一覧を作り直して、全部の話を開く。もう一度押すと元に戻る。記録は変わらない。
	var cleared_before: int = story.cleared_count()
	_push_key(app, KEY_F5)
	await app.scene_changed
	list = app.current_scene()
	_expect(app.current_id() == SceneFlow.EPISODES and story.open_all and app.open_all_key().is_marked(), "F5 で、全部の話を開かない（か、隅に印が無い）")
	_expect(list.is_card_enabled(Story.military().episodes[-1]) and list.card_title(Story.military().episodes[-1]) == Story.military().episodes[-1].title, "F5 で開いても、最後の話を選べない（か、伏せたまま）")
	_push_key(app, KEY_F5)
	await app.scene_changed
	list = app.current_scene()
	_expect(not story.open_all and not app.open_all_key().is_marked() and not list.is_card_enabled(Story.military().episodes[-1]),
		"もう一度 F5 を押しても、元に戻らない")
	_expect(story.cleared_count() == cleared_before, "F5 で、クリアの記録が変わった")
	# キーボードでは、左右の矢印で選んで Enter（数字キーの届かない 10 話目より先も選べる）。最初の矢印は、次に遊ぶ話を選ぶ。
	_push_key(app, KEY_RIGHT)
	_expect(list.key_choice() == episode, "話の一覧で矢印を押しても、次に遊ぶ話が選ばれない")
	_push_key(app, KEY_LEFT)
	_expect(list.key_choice() == Story.military().episodes[first - 1], "話の一覧で左の矢印を押しても、前の話へ移らない")
	_push_key(app, KEY_RIGHT)
	_push_key(app, KEY_RIGHT)
	_expect(list.key_choice() == episode, "話の一覧で、まだ遊べない話を矢印で選べる")
	_push_key(app, KEY_ENTER)
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.SORTIE, "話の一覧で話を選んで Enter を押しても、出撃準備へ進まない（会話は出撃のあと）")
	var sortie: Node = app.current_scene()
	# 「部隊編成」で編成（ストーリー用だけ）へ寄り道し、組んで取っておいた部隊を選んで戻る。
	var steps: int = app.context.run.size()
	sortie.press_edit_decks()
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.DECKS and app.context.run != null, "出撃準備の「部隊編成」で、流れを保ったまま編成へ進まない")
	var decks: Node = app.current_scene()
	_expect(decks.is_detour() and decks.mode() == Story.military().rules_id and decks.back_label() == "出撃準備へ戻る", "寄り道の編成が、ストーリー用でない（か、戻り先の文字が違う）")
	decks.press_new()
	for kind: UnitKind.Id in story.unlocked_kinds():
		decks.hire(kind)
	_expect(decks.can_save(), "寄り道の編成で、雇える駒で組んだ部隊を取っておけない")
	decks.press_save()
	var made: String = decks.list_selected()
	decks.press_back()
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.SORTIE, "編成の「出撃準備へ戻る」で、出撃準備へ戻らない")
	_expect(app.context.run.size() == steps, "寄り道を終えても、流れの列に編成の場面が残っている")
	sortie = app.current_scene()
	_expect(sortie.chosen_id() == made, "寄り道で取っておいた部隊が、出撃準備で選ばれていない")
	sortie.choose("")
	var options: Array[String] = sortie.option_ids()
	_expect(options[0] == "" and sortie.chosen_id() == "", "出撃準備で、既定の編成を選べない")
	var story_decks: Array = app.context.decks.for_rules(Story.military().rules_id)
	_expect(options.size() == 1 + story_decks.size(), "出撃準備に、ストーリー用の部隊が並ばない（か、対戦用が混ざった）")
	# 味方と敵の駒のアイコンを押すと、詳しい説明。持ち物を持たせた駒なら、持ち物の効果も出る。
	var own: Deck = sortie.chosen_deck()
	var detail: Control = sortie.press_face(Unit.Side.PLAYER1, 1)
	_expect(detail != null and detail.visible and detail.title_text() == Names.kind(own.entries[0].kind), "出撃準備で味方の駒のアイコンを押しても、詳しい説明が出ない")
	if detail != null and not own.entries[0].equipment.is_empty():
		_expect(detail.body_text().contains(Names.item(own.entries[0].equipment[0])), "出撃準備の駒の詳しい説明に、持ち物が出ない: %s" % detail.body_text())
	if detail != null:
		detail.close_detail()
	var enemy_deck: Deck = episode.enemy_deck()
	detail = sortie.press_face(Unit.Side.PLAYER2, enemy_deck.entries.size())
	_expect(detail != null and detail.visible and detail.title_text().begins_with(Names.kind(enemy_deck.entries[-1].kind)), "出撃準備で敵の駒のアイコンを押しても、詳しい説明が出ない")
	if detail != null:
		detail.close_detail()
	# 部隊を選び替えても（部隊の文の長さが違っても）、ほかの部品の位置と大きさが変わらない。
	var sortie_moves: Array = []
	for id: String in options:
		sortie_moves.append(sortie.choose.bind(id))
	await _expect_steady(sortie, [], sortie_moves, "出撃準備で部隊を選び替える")
	for item: RefCounted in story_decks:
		_expect(sortie.is_option_enabled(item.id) == item.playable(), "出せない部隊を選べる（か、出せる部隊を選べない）: %s" % item.name)
		if item.playable():
			sortie.choose(item.id)
	# 初期位置: 最初の駒を選んで、置けるマスの空いているところへ動かす。「おまかせ」で戻せる。右クリックで選ぶのをやめる。
	var deploy: Control = sortie.deploy_map()
	var own_cells: Array[Vector2i] = deploy.unit_cells()
	var free_cells: Array = deploy.zone().filter(func(cell: Vector2i) -> bool: return not own_cells.has(cell))
	_expect(not own_cells.is_empty() and not free_cells.is_empty() and deploy.is_default(), "出撃準備の初期位置に、駒か置けるマスが無い（か、始めからおまかせでない）")
	# 駒に次々マウスを乗せる（駒の欄の中身が替わっても、枠が動かないこと。枠の見張り steady_probe.gd が見る）。
	await _hover_each(deploy)
	deploy.press_cell(own_cells[0])
	_expect(deploy.selected() == 0, "初期位置で、駒を押しても選べない")
	_expect(sortie.deploy_note().shown_name() == Names.kind(deploy.focused_unit().kind), "出撃準備の初期位置で、選んだ駒の名前が欄に出ない")
	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.pressed = true
	app.get_viewport().push_input(right_click)
	_expect(deploy.selected() == -1 and app.current_id() == SceneFlow.SORTIE, "初期位置で駒を選んでいるときの右クリックで、選ぶのをやめない（か、出撃準備を抜けた）")
	deploy.press_cell(own_cells[0])
	deploy.press_cell(free_cells[0])
	_expect(deploy.unit_cells()[0] == free_cells[0] and not deploy.is_default(), "初期位置で、置けるマスへ駒を動かせない")
	sortie.press_auto_place()
	_expect(deploy.is_default(), "「おまかせ」で、いつもの置き方に戻らない")
	deploy.press_cell(own_cells[0])
	deploy.press_cell(free_cells[0])
	var result: Node = await _win_story_battle(app, sortie, episode, true, _check_talk_before.bind(episode), free_cells[0])
	_expect(result.leave_text() == "話の一覧へ" and not result.enabled_buttons().has("タイトルへ"), "話の決着の画面の行き先が「話の一覧へ」でない: %s" % result.leave_text())
	_expect(result.remark_texts().is_empty(), "勝った話の決着の画面に、負けたときの台詞が出る")
	# 「部隊を選び直す」で出撃準備へ戻り、同じ話をもう一度勝つ（対戦の前の会話は、もう出ない）。
	_expect(result.can_choose_squad(), "話の決着の画面に「部隊を選び直す」が無い")
	result.press_choose_squad()
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.SORTIE and app.context.run != null, "決着の画面の「部隊を選び直す」で、出撃準備へ戻らない")
	result = await _win_story_battle(app, app.current_scene(), episode)
	result.press_continue()
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.TALK, "決着の画面の「次へ」で、あとの会話へ進まない")
	var talk: Node = app.current_scene()
	_expect(talk.line_count() == episode.after.size() + Story.unlocked_before(episode).news_of(episode).size(), "あとの会話の文の数が違う（最後に、増えたものの知らせ）")
	if not episode.unlock_kinds.is_empty():
		talk.press_skip()
		_expect(talk.line_index() == episode.after.size() and talk.speaker() == Story.notice_name()
				and talk.line_text().contains(Names.kind(episode.unlock_kinds[0])), "「飛ばす」が、解放した駒の知らせまで飛ばしている")
	for i: int in talk.line_count() - talk.line_index():
		talk.press_next()
	_expect(talk.is_choosing() == (Story.episode_after(episode) != null), "あとの会話を送りきっても、「次の話へ」「話の一覧へ」を選ばせない")
	_expect(talk.is_skip_shown() != talk.is_choosing(), "「次の話へ」「話の一覧へ」を選ぶ間も「スキップ」が出ている")
	if talk.is_choosing():
		# 選ぶ枠の上で右クリックしても、選ぶのをやめて最後の文へ戻る（枠に食われない）。もう一度送ると、また選ぶ。
		# 画面なしの検査は、押した物を GUI で拾わないので、そこでマウスを止める部品（ボタンのほか）が無いことも確かめる。
		await get_tree().process_frame  # 枠の大きさが決まってから
		# 押すのは枠の上の余白（ボタンの上の右クリックは、ボタンが受ける。画面の真ん中はボタンの縁に当たることがある）。
		var at := app.get_viewport().get_visible_rect().get_center()
		for node: Node in talk.find_children("*", "PanelContainer", true, false):
			var frame := (node as Control).get_global_rect()
			if (node as Control).is_visible_in_tree() and frame.has_point(at):
				at = Vector2(frame.get_center().x, frame.position.y + 4.0)
		for node: Node in talk.find_children("*", "Control", true, false):
			var control := node as Control
			if control.is_visible_in_tree() and not control is BaseButton and control.mouse_filter == Control.MOUSE_FILTER_STOP and control.get_global_rect().has_point(at):
				_fail("選ぶ枠の上の右クリックを、%s が食う" % control.get_class())
		var right := InputEventMouseButton.new()
		right.button_index = MOUSE_BUTTON_RIGHT
		right.pressed = true
		right.position = at
		right.global_position = right.position
		app.get_viewport().push_input(right)
		_expect(not talk.is_choosing() and talk.is_skip_shown(), "選ぶ枠の上で右クリックしても、選ぶのをやめて最後の文へ戻らない")
		talk.press_next()
		_expect(talk.is_choosing(), "最後の文へ戻ったあと、送っても選ぶ枠が出ない")
		talk.press_to_episodes()
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.EPISODES and app.context.run == null, "あとの会話の「話の一覧へ」で、話の一覧へ戻らない")
	list = app.current_scene()
	# オートセーブ: 話の流れを終えて話の一覧へ戻った所で書き、保存の印を出す。最後にオートセーブした時刻が、話の一覧に出る。
	_expect(app.save_mark.shown_count > saves_before and not app.context.slots.has_unsaved(), "話をクリアして話の一覧へ戻っても、保存しない（か、保存の印が出ない）")
	_expect(list.saved_text() != "最後のオートセーブ: なし" and list.saved_text().begins_with("最後のオートセーブ: "), "話の一覧に、最後にオートセーブした時刻が出ない")
	# ウィンドウの ×: 保存したあとの話の一覧でも、確かめる（どの画面でも出す）。
	app.request_close()
	_expect(app.quit_window.is_open(), "話の一覧でウィンドウの × を押しても、確かめない")
	app.quit_window.cancel()
	_expect(list.card_status(episode) == "クリア済み", "クリアした話のカードに、済みの印が無い")
	if Story.military().episodes.size() > first + 1:
		_expect(list.is_card_enabled(Story.military().episodes[first + 1]), "前の話をクリアしたのに、次の話を選べない")
	_expect(list.roster_text().contains(Names.kind(episode.unlock_kinds[0])) if not episode.unlock_kinds.is_empty() else true, "話の一覧の、いま雇える駒が増えていない")
	list.press_back()
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.CAMPAIGNS, "話の一覧の「物語を選び直す」で、物語を選ぶ場面へ戻らない")
	_expect(app.current_scene().status_text(Story.military()) == "%d / %d 話クリア" % [first + 1, Story.military().episodes.size()], "物語のカードに、クリアした話の数が出ない")
	app.current_scene().press_back()
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.TITLE, "物語を選ぶ場面の「タイトルへ戻る」で、タイトルへ戻らない")
	_expect(app.current_scene().story_label() == "ストーリー（クリア済み）" or not story.all_cleared(), "クリアしたのに、タイトルに済みの印が無い")
	_expect(story.unlocked_kinds().has(episode.unlock_kinds[0]) if not episode.unlock_kinds.is_empty() else true, "クリアしても、駒が増えていない")


## セーブデータ選択（_visit_story のあと。1 番に進み具合がある）: 1 番は「つづきから」で物語とクリアの数が出る。
## 1 番を 2 番へコピー → 2 番も同じ中身 → 2 番を 1 番へコピーは上書きを確かめる（キャンセル）→ 2 番を削除（確かめる）→ 空きに戻る。
## 最後に 1 番を「つづきから」で選び、物語を選ぶ場面へ（進み具合はそのまま）。
func _visit_slots(app: Node) -> void:
	_expect(app.current_id() == SceneFlow.SLOTS, "タイトルの「ストーリー」で、セーブデータ選択へ進まない")
	var screen: Node = app.current_scene()
	var first: String = screen.card_text(1)
	_expect(first.ends_with("つづきから") and first.contains(Story.military().title) and first.contains("話クリア"), "進み具合のあるスロットのカードに、物語とクリアの数が出ない: %s" % first.replace("\n", " / "))
	_expect(screen.card_text(2).ends_with("はじめから"), "空きのスロットが「はじめから」でない")
	# コピーは、元がいまのスロットなら先に書く（保存の時刻が、いまになる）。時刻を 1 分進めておき、
	# 元のカードの日時が変わっても、コピーが元と同じ中身（同じ日時）になることを見る（分の変わり目で、毎回は起きないため）。
	var slots: RefCounted = app.context.slots
	var real_now: Callable = slots.now
	slots.now = func() -> int: return real_now.call() + 60
	screen.press_copy(1)
	_expect(screen.is_copying() and not screen.is_card_enabled(1), "コピーの元のカードを、コピー先に選べる")
	screen.choose(2)
	slots.now = real_now
	# （プレイ時間は、いまのスロットだけ数えている途中のぶんが足されるので、比べない）
	var without_time := func(text: String) -> String: return "\n".join(Array(text.split("\n")).filter(func(line: String) -> bool: return not line.begins_with("プレイ時間")))
	var source: String = screen.card_text(1)
	var without_date := func(text: String) -> String: return "\n".join(Array(without_time.call(text).split("\n")).filter(func(line: String) -> bool: return not RegEx.create_from_string("^\\d{4}/\\d{2}/\\d{2} \\d{2}:\\d{2}$").search(line)))
	_expect(source != first and without_date.call(source) == without_date.call(first), "コピーの元を書き直したとき、日時のほかが変わった（か、日時が変わらない）: %s ／ 前: %s" % [source.replace("\n", " / "), first.replace("\n", " / ")])
	_expect(not screen.is_copying() and without_time.call(screen.card_text(2)) == without_time.call(source).replace("データ 1", "データ 2"), "コピーしたスロットの中身が、元と違う: %s ／ 元: %s" % [screen.card_text(2).replace("\n", " / "), source.replace("\n", " / ")])
	screen.press_copy(2)
	screen.choose(1)
	var confirm: Node = screen.confirm_window()
	_expect(confirm.is_open() and confirm.question().contains("上書き"), "中身のあるスロットへのコピーで、上書きを確かめない")
	confirm.cancel()
	screen.cancel_copy()
	screen.press_delete(2)
	_expect(confirm.is_open() and confirm.ok_text() == "削除", "削除を確かめない")
	confirm.accept()
	_expect(screen.card_text(2).ends_with("はじめから") and without_time.call(screen.card_text(1)) == without_time.call(source), "削除したスロットが空きに戻らない（か、ほかのスロットが変わった）")
	screen.choose(1)
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.CAMPAIGNS, "「つづきから」で、物語を選ぶ場面へ進まない")


## 2 つ目の物語（FANTASY の物語）の頭の話を通す: 物語を選ぶ場面で選べる → その物語の話の一覧（最初の話だけ選べる。演習の印）
## → 会話を飛ばす → 出撃準備（部隊が決まっている。その物語の軍の部隊）→ 勝つ（「部隊変更」は出ない）→ あとの会話 → 話の一覧（次の話が選べる）
## → 物語を選ぶ場面（クリアした話の数。最初の物語の記録はそのまま）→ タイトル。
## 前の物語の記録（_visit_story がクリアを書いた）があり、この物語の記録が無いところから始める（古いセーブから起動したときと同じ形）。
func _visit_second_campaign(app: Node) -> void:
	var story: RefCounted = app.context.story
	var campaign: RefCounted = Story.campaigns()[1]
	var episode: RefCounted = campaign.episodes[0] if not campaign.episodes.is_empty() else null
	_expect(episode != null and episode.squad_deck() != null, "2 つ目の物語の頭に、部隊が決まっている話（演習）が無い")
	if episode == null:
		return
	var military_cleared: int = story.cleared_count(Story.military())
	_expect(story.cleared_count(campaign) == 0, "2 つ目の物語を、始める前からクリアしている")
	app.current_scene().press_story()
	await app.scene_changed
	await _visit_slots(app)
	var campaigns: Node = app.current_scene()
	_expect(campaigns.is_card_enabled(campaign) and campaigns.status_text(campaign) == "全 %d 話" % campaign.episodes.size(), "2 つ目の物語を選べない（か、状態の文が違う）")
	campaigns.choose(campaign)
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.EPISODES and story.campaign == campaign, "2 つ目の物語を選んでも、その物語の話の一覧へ進まない")
	var list: Node = app.current_scene()
	_expect(list.episodes().size() == campaign.episodes.size(), "2 つ目の物語の話の一覧に、全部の話が並んでいない")
	_expect(list.is_card_enabled(episode) and list.card_status(episode) == "未クリア", "2 つ目の物語の最初の話を選べない")
	for later: RefCounted in campaign.episodes.slice(1):
		_expect(not list.is_card_enabled(later), "前の話をクリアしていないのに、%s を選べる" % later.title)
	for kind: UnitKind.Id in campaign.starting_kinds:
		_expect(list.roster_text().contains(Names.kind(kind)), "2 つ目の物語の話の一覧に、最初から雇える駒が出ていない: %s" % Names.kind(kind))
	list.choose(episode)
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.SORTIE, "2 つ目の物語の話を選んでも、出撃準備へ進まない")
	var sortie: Node = app.current_scene()
	_expect(sortie.is_squad_fixed() and sortie.option_ids().size() == 1, "演習の出撃準備で、部隊を選べる")
	_expect(sortie.chosen_deck().army == campaign.army and sortie.chosen_deck().entries.size() == episode.squad.size(), "演習の部隊が、物語の軍の決まった部隊でない")
	var result: Node = await _win_story_battle(app, sortie, episode, true)
	_expect(not result.can_choose_squad(), "部隊が決まっている話の決着の画面に「部隊変更」がある")
	result.press_continue()
	await app.scene_changed
	var talk: Node = app.current_scene()
	_expect(app.current_id() == SceneFlow.TALK and talk.line_count() == episode.after.size() + Story.unlocked_before(episode).news_of(episode).size(), "2 つ目の物語の、あとの会話の文の数が違う")
	for i: int in talk.line_count() - talk.line_index():
		talk.press_next()
	# 「次の話へ」で、次の話の出撃準備へ。そこからシステムメニューの「話の一覧へ戻る」で、話の一覧へ。
	_expect(talk.is_choosing() and campaign.episodes.size() >= 2, "2 つ目の物語の、あとの会話のあとに「次の話へ」が無い")
	talk.press_next_episode()
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.SORTIE and app.current_scene().episode == campaign.episodes[1], "「次の話へ」で、次の話の出撃準備へ進まない")
	var menu: Node = app.system_menu()
	app.open_menu()
	_expect(menu.item_ids().has(&"exit:episodes"), "出撃準備のシステムメニューに「話の一覧へ戻る」が無い: %s" % [menu.item_ids()])
	menu.press(&"exit:episodes")
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.EPISODES and app.context.run == null, "システムメニューの「話の一覧へ戻る」で、話の一覧へ戻らない")
	list = app.current_scene()
	_expect(list.card_status(episode) == "クリア済み" and (campaign.episodes.size() < 2 or list.is_card_enabled(campaign.episodes[1])), "2 つ目の物語で、クリアした話の次の話を選べない")
	list.press_back()
	await app.scene_changed
	_expect(app.current_scene().status_text(campaign) == "1 / %d 話クリア" % campaign.episodes.size(), "2 つ目の物語のカードに、クリアした話の数が出ない")
	_expect(story.cleared_count(Story.military()) == military_cleared, "2 つ目の物語を遊ぶと、最初の物語の記録が変わる")
	app.current_scene().press_back()
	await app.scene_changed
	_expect(app.current_id() == SceneFlow.TITLE, "物語を選ぶ場面の「タイトルへ戻る」で、タイトルへ戻らない")


## 部隊編成の持ち物の欄: どの物語でも、解放の前と全部の解放のあとで、どの駒を選んでも、持ち物を持たせても、
## 名前・コスト・持たせられない理由（「未解放」「1 体 1 個まで」「後衛専用」など）が切れずに読める。ストーリーの記録は、終わったら戻す。
func _visit_item_rows(app: Node) -> void:
	var story: RefCounted = app.context.story
	var kept: Dictionary = story.to_data()
	for campaign: RefCounted in Story.campaigns():
		for unlock_all: bool in [false, true]:
			story.load_data({})
			story.choose_campaign(campaign)
			if unlock_all:
				for episode: RefCounted in campaign.episodes:
					story.clear(episode.id)
			await app.go(SceneFlow.DECKS)
			var screen: Node = app.current_scene()
			screen.set_mode(campaign.rules_id)
			screen.press_new()
			for kind: UnitKind.Id in screen.editing_deck().available_kinds():
				screen.hire(kind)
			for index: int in screen.editing_deck().entries.size():
				screen.select_entry(index)
				await app.get_tree().process_frame
				await app.get_tree().process_frame
				_expect(screen.item_row_cut_texts().is_empty(), "持ち物の欄の文が切れている（%s、%s）: %s" % [campaign.title, Names.kind(screen.editing_deck().entries[index].kind), screen.item_row_cut_texts()])
				_expect(screen.detail_card_rect().size.y >= screen.DETAIL_MIN_HEIGHT - 0.5, "持ち物の欄に押されて、駒の札が縮んだ（%s）: 高さ %.0f" % [campaign.title, screen.detail_card_rect().size.y])
				_expect(screen.detail_summary_overflow() <= 0.5, "駒の札の中身が、札の幅からはみ出した（%s、%s）: %.0f px" % [campaign.title, Names.kind(screen.editing_deck().entries[index].kind), screen.detail_summary_overflow()])
				_expect(not screen.detail_button_covers_summary_head(), "駒の札の「詳細」が、名前の行に重なった（%s、%s）" % [campaign.title, Names.kind(screen.editing_deck().entries[index].kind)])
				for item: Equipment.Id in screen.editing_deck().rules.items():
					screen.equip(item)
					await app.get_tree().process_frame
					await app.get_tree().process_frame
					_expect(screen.item_row_cut_texts().is_empty(), "持ち物を持たせたら、持ち物の欄の文が切れた（%s、%s、%s）: %s" % [campaign.title, Names.kind(screen.editing_deck().entries[index].kind), Names.item(item), screen.item_row_cut_texts()])
					screen.unequip(item)
			if unlock_all:
				await _resize_deck_screen(screen, campaign)
			if not unlock_all:
				screen.select_entry(0)
				var effects: Dictionary = screen.item_row_effects()
				for item: Equipment.Id in effects:
					_expect(screen.editing_deck().rules.allows_item(item) or (effects[item] as String).begins_with("未解放"), "まだ持たせられない持ち物に「未解放」が出ない: %s" % effects[item])
	story.load_data(kept)
	await app.go(SceneFlow.TITLE)


## 会話の行 row（episode.gd の before・after の 1 行）の話し手の名前（地の文なら空）。
static func _speaker_of(episode: RefCounted, row: Array) -> String:
	return episode.speakers[row[2]] if row[2] >= 0 else ""


## 対戦の前の会話の場面 talk（話 episode）: 文の数、最初の文、話し手の姿、送りと戻り。
func _check_talk_before(talk: Node, episode: RefCounted) -> void:
	_expect(talk.line_count() == episode.before.size() and talk.line_index() == 0, "前の会話の文の数が違う")
	_expect(talk.speaker() == _speaker_of(episode, episode.before[0]) and talk.line_text() == episode.before[0][1], "最初の文が出ていない")
	_expect(not talk.has_method(&"next_episode") or talk.next_episode() == null, "対戦の前の会話に「次の話へ」がある")
	await get_tree().process_frame
	# 立つ所は左右に 1 つずつ。両軍が出てくるか、同じ軍の話し手が 2 人以上いれば、両方に立つ。
	var talkers := {}
	for row: Array in episode.before:
		if row[2] >= 0:  # 地の文は、話し手がいない
			talkers[row[2]] = true
	_expect(talk.figures().size() == mini(talkers.size(), 2), "会話に出てくる話し手の姿が立っていない")
	var screen_rect := Rect2(Vector2.ZERO, talk.get_viewport().get_visible_rect().size)
	for figure: Control in talk.figures():
		var rect: Rect2 = figure.get_global_rect()
		_expect(rect.has_area() and screen_rect.encloses(rect), "話し手の姿が画面からはみ出す: %s" % rect)
		_expect(not rect.intersects(talk.bottom_rect()), "話し手の姿が、名前の札・文の枠・「飛ばす」に重なる: %s と %s" % [rect, talk.bottom_rect()])
		_expect(figure.is_speaking() == (figure.who == episode.before[0][2]), "話している人の姿だけが明るく大きくなっていない")
	talk.press_next()
	_expect(talk.line_index() == 1, "クリックで、次の文へ進まない")
	talk.press_back()
	_expect(talk.line_index() == 0, "右クリックで、前の文へ戻らない")
	await _check_talk_log(talk, episode)


## 会話のログ: ホイールを上へ回すと開き、これまでの文（いまの文まで）を話し手と文で並べる。開いている間、会話は送らない。
## 右クリックで閉じる（会話の文は戻らない）。L で開いて、Esc で閉じる。
func _check_talk_log(talk: Node, episode: RefCounted) -> void:
	talk.press_next()
	talk.press_next()
	var at: int = talk.line_index()
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = talk.get_viewport().get_visible_rect().get_center()
	talk.get_viewport().push_input(wheel)
	var log: CanvasLayer = talk.talk_log()
	_expect(log.is_open(), "会話の画面でホイールを上へ回しても、会話のログが開かない")
	var expected := []
	for i in at + 1:
		expected.append([_speaker_of(episode, episode.before[i]), episode.before[i][1]])
	_expect(log.row_texts() == expected, "会話のログに、これまでの文が並んでいない: %s" % [log.row_texts()])
	var enter := InputEventKey.new()
	enter.physical_keycode = KEY_ENTER
	enter.pressed = true
	talk.get_viewport().push_input(enter)
	_expect(talk.line_index() == at and log.is_open(), "会話のログを開いている間に、会話が送られた")
	var screen_rect := Rect2(Vector2.ZERO, talk.get_viewport().get_visible_rect().size)
	_expect(screen_rect.encloses(log.panel_rect()), "会話のログの窓が画面からはみ出す: %s" % log.panel_rect())
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	right.position = wheel.position
	talk.get_viewport().push_input(right)
	_expect(not log.is_open() and talk.line_index() == at, "会話のログの右クリックで、閉じない（か、会話の文が戻った）")
	var l_key := InputEventKey.new()
	l_key.physical_keycode = KEY_L
	l_key.pressed = true
	talk.get_viewport().push_input(l_key)
	_expect(log.is_open(), "L で会話のログが開かない")
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	talk.get_viewport().push_input(escape)
	_expect(not log.is_open() and not talk.context.system_menu.is_open(), "会話のログの Esc で、閉じない（か、システムメニューが開いた）")
	await get_tree().process_frame
	for i in at:
		talk.press_back()


## 出撃準備 sortie で「出撃」し、話 episode の対戦に入ったことを確かめて、小さな盤で 1 手で勝つ。決着の画面を返す。
## talk_first なら、出撃のあとに対戦の前の会話が出ることを確かめ（on_talk があれば、会話の場面を渡して呼ぶ）、飛ばして対戦へ。
## 偽なら、会話を出さずに対戦へ進むことを確かめる（「部隊変更」のあと）。
## first_at が盤の中なら、部隊の最初の駒がそのマスから始まることも確かめる（出撃準備で決めた初期位置）。
func _win_story_battle(app: Node, sortie: Node, episode: RefCounted, talk_first := false, on_talk := Callable(), first_at := Vector2i(-1, -1)) -> Node:
	var story: RefCounted = app.context.story
	var chosen: Deck = sortie.chosen_deck()
	sortie.press_sortie()
	await app.scene_changed
	if talk_first:
		_expect(app.current_id() == SceneFlow.TALK, "出撃しても、対戦の前の会話へ進まない")
		if app.current_id() == SceneFlow.TALK:
			if on_talk.is_valid():
				await on_talk.call(app.current_scene())
			app.current_scene().press_skip()
			await app.scene_changed
	_expect(app.current_id() == SceneFlow.BATTLE, "出撃準備の「出撃」で、対戦へ進まない")
	var screen: Node = app.current_scene()
	# 幕が明けた時点（場面の _process がまだ回っていない）で、ミニマップはもう右上にある（左上に出てから跳ばない）。
	var minimap: Rect2 = screen.minimap_rect()
	_expect(minimap.has_area() and minimap.position.x > screen.get_viewport().get_visible_rect().size.x / 2.0,
		"対戦に入った幕が明けたとき、ミニマップが右上に置かれていない: %s" % minimap)
	screen.set_time_scale_base(8.0)
	var source: RefCounted = screen.source
	_expect(source.new_board_fields().is_empty() and not source.can_open_setup() and screen.menu_items().is_empty(), "話の対戦に、選び直す入口がある")
	# ストーリーの間は、陣営を「味方」「敵」と呼ぶ（「CPU（赤）」「プレイヤー1」と呼ばない）。
	_expect(Names.side(Unit.Side.PLAYER2) == "敵" and Names.side_word(Unit.Side.PLAYER1) == "味方", "話の対戦で、陣営が「味方」「敵」と呼ばれない")
	_expect(screen.battle.board.size == episode.map.make_board().size, "話の対戦が、話のマップで始まらない")
	var placed := 0
	for unit: Unit in screen.battle.units:
		if unit.side == Unit.Side.PLAYER1 and unit.kind != UnitKind.Id.KING:
			placed += 1
	_expect(placed == chosen.entries.size() and source.human_deck.entries.size() == chosen.entries.size(), "出撃準備で選んだ部隊で、対戦が始まらない")
	if first_at != Vector2i(-1, -1):
		var first: Array = screen.battle.units.filter(func(unit: Unit) -> bool: return unit.side == Unit.Side.PLAYER1 and unit.kind != UnitKind.Id.KING)
		_expect(not first.is_empty() and first[0].cell == first_at, "出撃準備で決めた初期位置から始まらない: %s（決めたのは %s）" % [first[0].cell if not first.is_empty() else null, first_at])
	_expect(screen.cpu_opponent and screen.battle.armies[Unit.Side.PLAYER2] == episode.enemy_army, "話の敵を CPU が動かしていない")
	# 対戦の途中の会話の札は、上の帯のすぐ下で、勝ち方の札・視点の案内・ミニマップと重ならない（いちばん長い台詞で確かめる）。
	var longest := ""
	for each: RefCounted in Story.all_episodes():
		for cue: Array in each.cues:
			if (cue[3] as String).length() > longest.length():
				longest = cue[3]
	screen.say_for_check([BattleCues.Line.new(1, episode.speakers[1], longest, episode.figures[1])] as Array[BattleCues.Line])
	await get_tree().process_frame
	await get_tree().process_frame
	var card: Rect2 = screen.talk_card_rect()
	_expect(card.has_area() and card.position.y >= BattleHud.TOP_BAR_HEIGHT, "対戦の途中の会話の札が出ないか、上の帯に重なる: %s" % card)
	_expect(card.size.y <= 64.0, "対戦の途中の会話の札が、細い帯でない（2 行を超える高さ）: %s" % card)
	for other: Rect2 in screen.talk_card_neighbors():
		_expect(not card.intersects(other), "対戦の途中の会話の札が、勝ち方の札・視点の案内・ミニマップに重なる: %s と %s" % [card, other])
	# 遊ぶときは、台詞を送られるまで出したままにし、その間は盤を止める。Enter で送る（ターン終了にならない）。
	screen.clear_talk_for_check()
	screen.set_talk_hold(true)
	screen.say_for_check([BattleCues.Line.new(1, episode.speakers[1], longest, episode.figures[1])] as Array[BattleCues.Line])
	_expect(screen.is_talk_holding() and screen.is_busy(), "遊ぶときの対戦の途中の台詞で、盤が止まらない")
	var turn_before: int = screen.battle.turn
	var phase_before: int = screen.battle.phase
	for i in 600:
		if screen.advance_talk():
			break
		await get_tree().process_frame
	_expect(not screen.is_talk_holding(), "対戦の途中の台詞を送れない")
	screen.say_for_check([BattleCues.Line.new(1, episode.speakers[1], longest, episode.figures[1])] as Array[BattleCues.Line])
	for i in 600:
		if screen.talk_line() != null and app.get_viewport().get_visible_rect().size.x > 0 and screen.is_talk_holding():
			var enter := InputEventKey.new()
			enter.physical_keycode = KEY_ENTER
			enter.pressed = true
			app.get_viewport().push_input(enter)
			if not screen.is_talk_holding():
				break
		await get_tree().process_frame
	_expect(not screen.is_talk_holding() and screen.battle.turn == turn_before and screen.battle.phase == phase_before,
		"対戦の途中の台詞を Enter で送れない（か、Enter でターンが終わった）")
	screen.set_talk_hold(false)
	# 小さな盤で、1 手で将を倒して勝つ。
	var board := _small_board(Vector2i(5, 4))
	var battle := Battle.new(board)
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER1, board.hq_cells[0])
	var foe := battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER2, board.hq_cells[1])
	foe.hp = 1
	var raider := UnitKind.Id.SPELLBLADE if Story.campaign_of(episode).army == UnitKind.Army.FANTASY else UnitKind.Id.COMMANDO
	var striker := battle.add_unit(raider, Unit.Side.PLAYER1, board.hq_cells[1] + Vector2i(-1, 0))
	screen.start_with(battle, episode.look, 1, episode.map_title)
	screen.click_cell(striker.cell)
	screen.click_cell(foe.cell)
	var result: Node = screen.result_screen()
	for i in 1200:
		if not screen.is_busy() and result.visible:
			break
		await get_tree().process_frame
	_expect(battle.is_over() and battle.winner == Unit.Side.PLAYER1, "話の対戦で、勝てなかった")
	_expect(story.is_cleared(episode.id), "話の対戦に勝っても、クリアを書かない")
	result.skip()
	for i in 600:
		if not result.enabled_buttons().is_empty():
			break
		await get_tree().process_frame
	_expect(result.can_continue() and result.new_board_fields().is_empty() and not result.can_go_to_setup(), "勝った話の決着の画面の行き先が違う（「次へ」が無い、か、選び直す行き先がある）")
	_expect(not result.can_leave(), "勝った話の決着の画面に「話の一覧へ」がある（あとの会話を読まずに抜けられる）")
	return result


## 画面の大きさを少し変えて戻す。抜けた場面の部品が、画面の大きさの合図につながったまま残っていれば、ここでエラーになる。
## 部隊編成の持ち物が多いとき、窓を縦に広げてから元へ縮めても、駒の札が縮まず、元の大きさと置き場所に戻る
## （持ち物の欄の高さは画面の高さから決め直す。deck_screen.gd の _fit_equip）。広げたままでも、札は下限を割らない。
func _resize_deck_screen(screen: Node, campaign: RefCounted) -> void:
	var window := get_window()
	var size := window.content_scale_size
	screen.select_entry(0)
	await get_tree().process_frame
	await get_tree().process_frame
	var before: Rect2 = screen.detail_card_rect()
	for bigger: Vector2i in [size + Vector2i(0, 280), size + Vector2i(440, 0), size + Vector2i(0, 600)]:
		window.content_scale_size = bigger
		await get_tree().process_frame
		await get_tree().process_frame
		_expect(screen.detail_card_rect().size.y >= screen.DETAIL_MIN_HEIGHT - 0.5, "部隊編成の窓を %s に広げたら、駒の札が縮んだ（%s）: %s" % [bigger, campaign.title, screen.detail_card_rect()])
		window.content_scale_size = size
		await get_tree().process_frame
		await get_tree().process_frame
		_expect(screen.detail_card_rect().is_equal_approx(before), "部隊編成の窓を %s に広げてから縮めたら、駒の札が元に戻らない（%s）: %s（前は %s）" % [bigger, campaign.title, screen.detail_card_rect(), before])
		_expect(screen.item_row_cut_texts().is_empty(), "部隊編成の窓を広げてから縮めたら、持ち物の欄の文が切れた（%s）: %s" % [campaign.title, screen.item_row_cut_texts()])


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
