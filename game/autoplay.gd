extends "res://game/autoplay/story_checks.gd"
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
##
## ここは、場面の一覧と、回す流れ（場面を選ぶ、対戦を進める、場面の手順を積む、終える）だけ。場面の手順（_queue_<名前>_scene() など）は、
## 確かめる画面ごとのファイル（game/autoplay/*_checks.gd）に置き、確かめる・操作する道具は game/autoplay/autoplay_base.gd に置く。
## ファイルは autoplay_base.gd から順に継いで積み重なり、このファイルが最後（前のファイルは、後のファイルの関数を呼べない）。


## 場面の名前 -> 説明（回す順）。決まった手順の場面は、同じ名前の _queue_<名前>_scene() が手順を積む。
const SCENES := {
	"game": "人の操作で、対戦を最後まで進める（決着と戦績とログ）",
	"result": "リザルトの画面（game の決着のあと）",
	"portal_and_spring": "ポータルに止まってメニューの「転移」、転移のあと続けて動く、取り消し、ふさがったポータル、回復の泉",
	"capture": "敵の本陣の占拠と、拠点の確保（選べる決まり）",
	"barrel_draw": "樽の爆発で両方の将が倒れて引き分け",
	"field_effect": "盤の上の効果（盾・煙幕・聖域）",
	"skill": "スキルのボタンと対象選び、クールダウン",
	"status": "自分に使うスキルと、駒に付く状態",
	"traits": "軍略（集中砲火の輪と、効いたときの札）",
	"monster_falls": "倒れると何か起きる魔物（骸骨旗手の奮起、ほつれの結び目）",
	"extra_action": "行動を終えないスキルと、行動済みの駒を戻すスキル",
	"ult": "必殺技",
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
	"events": ["game", "result", "portal_and_spring", "capture", "barrel_draw", "field_effect", "skill", "status", "traits", "monster_falls", "extra_action",
		"ult", "neutral", "mid_boss", "level_up", "evolution", "heal", "cpu_skip", "auto_turn"],
	"ui": ["inspection", "setup", "system_menu", "minimap", "cpu", "title", "decks", "story"],
}


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
	if _scene.notice_text() != "":
		# 対戦の始めの「対戦ルール」は、閉じるまで手番が始まらない（人が閉じるもの）。自動の対戦は、ここで閉じる
		# （札を見る場面の手は、始めたその手の中で見終えている）。閉じると番の知らせ・台詞・CPU の番が始まるので、次のコマから進める。
		_scene.hide_notice()
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
