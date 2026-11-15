extends Node
## 試作の決まった場面を画像に撮る。`-- --shots <場面,…|all> --out <ディレクトリ>` を付けて起動すると、
## 試作（board_prototype.gd）がこのノードを足す。撮り終えたら終わる。使い方は docs/screenshots.md。
##
## 場面はどれも、種を決めた対戦（MatchSetup）を CPU どうしで進めて作る。人の操作と同じ入口で駒を選ぶので、
## 毎回同じ絵になる。場面を足すときは、SCENES に名前と説明を足し、同じ名前の _scene_<名前>() を書く
## （その場面まで状態を作るだけ。撮るのはこのノードがやる）。

const Queries := preload("res://prototype/battle_queries.gd")
const TrialSetup := preload("res://prototype/trial_setup.gd")
const OrbitCamera := preload("res://prototype/orbit_camera.gd")

## 場面の名前 -> 説明（撮る順）。
const SCENES := {
	"setup": "対戦の設定画面（起動した直後）",
	"setup_again": "対戦の途中で開いた、対戦の設定画面（閉じて戻れる）",
	"system_menu": "対戦の途中で開いたシステムメニュー（Esc か右上のボタン）",
	"system_quit": "システムメニューで「ゲームを終える」を押して、確かめている",
	"settings": "システムメニューから開いた設定の画面（感度を変えたところ）",
	"menu_note": "メニューの項目にマウスを乗せて、説明が出ている",
	"start": "対戦の始め（ターン 1、何も選んでいない）",
	"pitch_low": "ドラッグで見下ろす角度をいちばん浅くした（下限）",
	"pitch_high": "ドラッグで見下ろす角度をいちばん深くした（上限。ほぼ真上）",
	"move": "自分の駒を選んで、移動範囲と、駒のそばのメニューが出ている",
	"cell": "駒のいないマスをクリックして、マスの情報が出ている",
	"menu_moved": "動いたあとのメニュー（攻撃・待機・移動を取り消す）と、攻撃できる相手",
	"menu_attack": "メニューの「攻撃」を押して、相手を選んでいる",
	"menu_crowd": "駒が固まっているところで出したメニュー",
	"menu_edge": "盤の端・画面の隅にいる駒のメニュー",
	"threat": "相手の駒を選んで、脅威範囲が出ている",
	"skill": "スキルの対象を選んでいる",
	"ult": "必殺技のゲージが READY で、使うかを確かめている",
	"mid_boss": "中ボスを倒して、上の帯に聖遺物が出ている",
	"result": "決着の画面と戦績",
	"wide": "いちばん引いて、低い角度で、盤の全体とその向こうを見ている",
	"board_edge": "盤の角と、その外側（低い角度で、盤の外へ向いている）",
	"rotated": "カメラを斜めに回して、低い角度で見ている",
	"marks": "寄って見た、駒の足元の印（行動済み、HP の棒）と、移動範囲",
	"stage_labyrinth": "迷宮回廊の全景",
	"stage_twin_springs": "双子結晶の全景",
}
## 中ボスが倒れるまで続く対戦の種（CPU どうしで 29 ターン、プレイヤー1 がターン 20 に左の中ボスを倒す）。
const SEED := 1
## 撮る前に待つ時間（秒）。番の知らせが消え、カメラが寄り終わるまで。
const SETTLE := 1.8
## CPU どうしで進める行動の数の上限（場面が来なければ、撮らずに失敗にする）。
const MAX_ACTIONS := 3000
const JPEG_QUALITY := 0.82

var _scene: Node
var _out := ""
var _names: Array[String] = []
var _cpu := CpuPlayer.new()
var _battle: Battle
var _stats: BattleStats
var _stage := BoardGenerator.Stage.PLAIN


func _init(scene: Node) -> void:
	_scene = scene


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var shots := _arg(args, "--shots")
	_out = _arg(args, "--out")
	if shots == "" or _out == "":
		_quit("screenshots: --shots と --out を指定する（場面: %s）" % ", ".join(SCENES.keys()), 1)
		return
	for name: String in (SCENES.keys() if shots == "all" else Array(shots.split(","))):
		if not SCENES.has(name):
			_quit("screenshots: 知らない場面: %s（場面: %s）" % [name, ", ".join(SCENES.keys())], 1)
			return
		_names.append(name)
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	for name: String in _names:
		_scene.setup_panel().visible = false
		_scene.system_menu().close()
		_scene.settings.reset_all()
		_scene.set_opponent(false)  # 撮る間は CPU に番を進めさせない
		_stage = BoardGenerator.Stage.PLAIN
		_new_battle()
		_aim(22.0, 0.0, OrbitCamera.DEFAULT_PITCH)  # 前の場面で動かしたカメラを戻す（ほかの場面は、始めの向きと角度で撮る）
		var ok: bool = await call("_scene_" + name)
		if not ok:
			_quit("screenshots: 場面 %s を作れなかった" % name, 1)
			return
		while _scene.is_busy() and not _scene.setup_panel().visible and not _scene.system_menu().is_open():
			await get_tree().process_frame
		_park_mouse()
		# システムメニューを開いている間は時間が止まるので、待つのは時間の速さに依らない時計で測る。
		await get_tree().create_timer(SETTLE, true, false, true).timeout
		await RenderingServer.frame_post_draw
		var path := _out.path_join(name + ".jpg")
		var error := get_viewport().get_texture().get_image().save_jpg(path, JPEG_QUALITY)
		if error != OK:
			_quit("screenshots: %s を書けなかった（%s）" % [path, error_string(error)], 1)
			return
		print("screenshots: %s" % path)
	_quit("screenshots: OK", 0)


# ---- 場面 ----


func _scene_setup() -> bool:
	_show()
	_scene.set_opponent(true)  # 設定画面は、遊ぶときの始めと同じ（相手は CPU）で開く
	_scene.setup_panel().open(_scene.match_choice)
	return true


func _scene_setup_again() -> bool:
	if not _advance(func() -> bool: return _battle.turn >= 3 and _battle.phase == Unit.Side.PLAYER1):
		return false
	_show()
	_scene.open_setup()
	return _scene.setup_panel().is_cancellable()


## 対戦の途中の盤面を出し、カメラが落ち着いてからシステムメニューを開く（開くと時間が止まる）。
func _open_system_menu() -> bool:
	if not _advance(func() -> bool: return _battle.turn >= 3 and _battle.phase == Unit.Side.PLAYER1):
		return false
	_show()
	await get_tree().create_timer(SETTLE).timeout
	_scene.press_escape()
	return _scene.system_menu().is_open()


func _scene_system_menu() -> bool:
	return await _open_system_menu()


func _scene_system_quit() -> bool:
	if not await _open_system_menu():
		return false
	_scene.system_menu().press(&"quit")
	return _scene.system_menu().confirming() == &"quit"


func _scene_settings() -> bool:
	if not await _open_system_menu():
		return false
	_scene.system_menu().press(&"settings")
	_scene.settings.set_value(&"mouse_sensitivity", 150)
	return _scene.system_menu().is_settings_open()


func _scene_menu_note() -> bool:
	if not await _scene_skill():
		return false
	_scene.press_skill()  # 対象を選ぶのをやめて、メニューへ戻る
	_scene._on_menu_hovered(&"skill")
	return _scene.menu_ids().has(&"skill")


func _scene_start() -> bool:
	_show()
	return true


func _scene_pitch_low() -> bool:
	_show()
	_scene.set_camera_pitch(OrbitCamera.MIN_PITCH)
	return true


func _scene_pitch_high() -> bool:
	_show()
	_scene.set_camera_pitch(OrbitCamera.MAX_PITCH)
	return true


func _scene_move() -> bool:
	_show()
	# 動ける範囲のいちばん広い駒を選ぶ。
	var best: Unit = null
	var most := -1
	for unit in _own_units():
		var count := Queries.move_cells(_battle, unit).size()
		if count > most:
			best = unit
			most = count
	_scene.click_cell(best.cell)
	return true


func _scene_cell() -> bool:
	_show()
	# 樽（無ければ森）のマスをクリックする。
	var cell := Vector2i(-1, -1)
	if not _battle.board.barrel_cells.is_empty():
		cell = _battle.board.barrel_cells[0]
	else:
		for y in _battle.board.size.y:
			for x in _battle.board.size.x:
				if cell.x < 0 and _battle.board.terrain_at(Vector2i(x, y)) == Terrain.Type.FOREST:
					cell = Vector2i(x, y)
	_scene.click_cell(cell)
	_scene.focus_camera(cell)
	return _scene.info_title().begins_with("マス")


## 動けば攻撃できる相手がいる駒と、その行き先（[駒, マス]）。無ければ空。
func _move_then_attack() -> Array:
	for unit in _own_units():
		if not _battle.can_act(unit) or UnitKind.role(unit.kind) == UnitKind.Role.HEALER:
			continue
		for cell: Vector2i in _battle.options(unit.id).move_cells:
			if cell == unit.cell:
				continue
			var trial := _battle.clone()
			trial.apply(MoveAction.new(unit.id, cell, false))
			if not trial.options(unit.id).attack_target_ids.is_empty():
				return [unit, cell]
	return []


func _scene_menu_moved() -> bool:
	if not _advance(func() -> bool: return _battle.phase != Unit.Side.NEUTRAL and not _move_then_attack().is_empty()):
		return false
	var found := _move_then_attack()
	var unit: Unit = found[0]
	_show()
	_scene.click_cell(unit.cell)
	await _scene.act(MoveAction.new(unit.id, found[1], false))
	_scene.focus_camera(unit.cell)
	return _scene.menu_ids().has(&"attack") and _scene.menu_ids().has(&"undo")


func _scene_menu_attack() -> bool:
	if not await _scene_menu_moved():
		return false
	return _scene.press_menu(&"attack") and _scene.is_choosing_target()


func _scene_menu_crowd() -> bool:
	# 両軍がぶつかったあとの、周りに駒のいちばん多い自分の駒。
	if not _advance(func() -> bool: return _battle.turn >= 4 and _battle.phase == Unit.Side.PLAYER1):
		return false
	_show()
	var best: Unit = null
	var most := -1
	for unit in _own_units():
		if not _battle.can_act(unit):
			continue
		var near := 0
		for other in _battle.units:
			if other != unit and maxi(absi(other.cell.x - unit.cell.x), absi(other.cell.y - unit.cell.y)) <= 2:
				near += 1
		if near > most:
			best = unit
			most = near
	if best == null:
		return false
	_scene.click_cell(best.cell)
	_scene.focus_camera(best.cell)
	return not _scene.menu_ids().is_empty()


func _scene_menu_edge() -> bool:
	_show()
	# 盤の下の端にいちばん近い駒を選び、カメラをずらして、その駒を画面の右下の隅に寄せる。
	var best: Unit = null
	for unit in _own_units():
		if best == null or unit.cell.y > best.cell.y or (unit.cell.y == best.cell.y and unit.cell.x > best.cell.x):
			best = unit
	_scene.click_cell(best.cell)
	_scene.focus_camera(best.cell + Vector2i(-11, -4))
	return not _scene.menu_ids().is_empty()


func _scene_threat() -> bool:
	# 両軍が近づいた、ターン 3 のプレイヤー1 の番の始め。
	if not _advance(func() -> bool: return _battle.turn >= 3 and _battle.phase == Unit.Side.PLAYER1):
		return false
	_show()
	# 自分の駒にいちばん近い、相手の駒（将は除く）を選ぶ。
	var best: Unit = null
	var nearest := 1 << 30
	for foe in _battle.units:
		if foe.side != 1 - _battle.phase or foe.kind == UnitKind.Id.KING:
			continue
		for unit in _own_units():
			var distance := _distance(foe.cell, unit.cell)
			if distance < nearest:
				best = foe
				nearest = distance
	if best == null:
		return false
	_scene.click_cell(best.cell)
	_scene.focus_camera(best.cell)
	return true


func _scene_skill() -> bool:
	var ready := func() -> Unit:
		for unit in _own_units():
			if _battle.can_act(unit) and not Queries.skill_cells(_battle, unit).is_empty():
				return unit
		return null
	if not _advance(func() -> bool: return _battle.turn >= 2 and ready.call() != null):
		return false
	_show()
	var unit: Unit = ready.call()
	_scene.click_cell(unit.cell)
	_scene.press_skill()
	_scene.focus_camera(unit.cell)
	return _scene.is_choosing_skill_target()


func _scene_ult() -> bool:
	if not _advance(func() -> bool: return Ults.can_use(_battle)):
		return false
	_show()
	_scene.press_ult()
	return _scene.is_confirming_ult()


func _scene_mid_boss() -> bool:
	# 中ボスが倒れたあとの、倒した陣営の番の始め（上の帯に聖遺物が出る）。残っている中ボスを選んで寄せる。
	var slain: Array[MidBossDefeatedEvent] = []
	var watch := func(events: Array[BattleEvent]) -> void:
		for event in events:
			if event is MidBossDefeatedEvent and slain.is_empty():
				slain.append(event)
	if not _advance(func() -> bool: return not slain.is_empty() and _battle.phase == slain[0].slayer_side, watch):
		return false
	_show()
	var focus := slain[0].cell
	for cell in _battle.board.mid_boss_cells:
		var boss := _battle.unit_at(cell)
		if boss != null and boss.side == Unit.Side.NEUTRAL:
			_scene.click_cell(cell)
			focus = cell
	_scene.focus_camera(focus)
	return true


func _scene_result() -> bool:
	# 決着する行動の手前まで進め、その行動だけを画面に通す（決着の演出と戦績が出る）。
	if _advance(func() -> bool: return false):
		return false  # 決着しなかった
	var action := _cpu.next_action(_battle)
	_show()
	_scene.stats = _stats  # 始めからの戦績
	await _scene.act(action)
	return _battle.is_over()


func _scene_wide() -> bool:
	if not _advance(func() -> bool: return _battle.turn >= 3 and _battle.phase == Unit.Side.PLAYER1):
		return false
	_show()
	_look_at(Vector3(_battle.board.size.x / 2.0, 0.0, _battle.board.size.y / 2.0 + 6.0))
	_aim(45.0, 0.0, OrbitCamera.MIN_PITCH)
	return true


func _scene_board_edge() -> bool:
	_show()
	# 盤の左上の角の近くに立って、角の外へ向く。
	_look_at(Vector3(1.5, 0.0, 1.5))
	_aim(26.0, -40.0, 35.0)
	return true


func _scene_rotated() -> bool:
	if not _advance(func() -> bool: return _battle.turn >= 3 and _battle.phase == Unit.Side.PLAYER1):
		return false
	_show()
	_look_at(_scene._rig.position)
	_aim(30.0, 130.0, 35.0)
	return true


func _scene_marks() -> bool:
	# 行動済みの駒と、HP の減った駒が並ぶところ: 番の途中で、HP の減った自分の駒がまだ動けるとき。
	var hurt := func() -> Unit:
		for unit in _own_units():
			if unit.hp < unit.max_hp() and _battle.can_act(unit) and unit.kind != UnitKind.Id.KING:
				return unit
		return null
	var acted := func() -> bool:
		for unit in _own_units():
			if not _battle.can_act(unit):
				return true
		return false
	if not _advance(func() -> bool: return _battle.phase == Unit.Side.PLAYER1 and acted.call() and hurt.call() != null):
		return false
	_show()
	var unit: Unit = hurt.call()
	_scene.click_cell(unit.cell)
	_look_at(Vector3(unit.cell.x + 0.5, 0.0, unit.cell.y + 0.5))
	_aim(11.0, 0.0, 50.0)
	return true


func _scene_stage_labyrinth() -> bool:
	return _stage_overview(BoardGenerator.Stage.LABYRINTH)


func _scene_stage_twin_springs() -> bool:
	return _stage_overview(BoardGenerator.Stage.TWIN_SPRINGS)


func _stage_overview(stage: BoardGenerator.Stage) -> bool:
	_stage = stage
	_new_battle()
	_show()
	_look_at(Vector3(_battle.board.size.x / 2.0, 0.0, _battle.board.size.y / 2.0 + 1.0))
	_aim(45.0, 0.0, 68.0)
	return true


# ---- 場面を作る道具 ----


func _new_battle() -> void:
	var choice: RefCounted = TrialSetup.new()
	choice.stage = _stage
	choice.cpu_opponent = false
	_scene.match_choice = choice
	_battle = choice.to_setup(SEED).create_battle()
	_stats = BattleStats.new(_battle)


## いまの _battle を画面に出す（駒の見た目は、いまの状態から作る）。
func _show() -> void:
	_scene.start_with(_battle, _stage, SEED)


## カメラの見ている地点を point にする（寄る動きは待たない）。
func _look_at(point: Vector3) -> void:
	_scene._rig.follow(null)
	_scene._rig.focus_on(point)
	_scene._rig.position = Vector3(point.x, 0.0, point.z)


## カメラの距離、向き（度）、見下ろす角度（度）を決める。
func _aim(distance: float, yaw_degrees: float, pitch: float) -> void:
	_scene._rig._target_distance = distance
	_scene._rig._target_yaw = deg_to_rad(yaw_degrees)
	_scene.set_camera_pitch(pitch)


## CPU どうしで行動を 1 つずつ進め、行動と行動の間で until が真になったら止めて真を返す。
## 止めるのは、選んでいる駒も進化の途中も無いときだけ。決着する行動は進めずに偽を返す（_battle は決着の手前で止まる）。
## watch には、行動ごとに起きたことを渡す。
func _advance(until: Callable, watch := Callable()) -> bool:
	for i in MAX_ACTIONS:
		if _battle.acting_unit_id == 0 and _battle.evolving_unit() == null and until.call():
			return true
		var action := _cpu.next_action(_battle)
		if action == null:
			return false
		var trial := _battle.clone()
		trial.apply(action)
		if trial.is_over():
			return false
		var result := _battle.apply(action)
		_stats.feed_all(result.events)
		if watch.is_valid():
			watch.call(result.events)
	return false


## マウスの下のマスが塗られたり、マスの説明が出たりしないよう、マウスを下の帯の左（操作の説明の上）に置く。
func _park_mouse() -> void:
	var at := Vector2(100, get_viewport().get_visible_rect().size.y - 10)
	get_viewport().warp_mouse(at)
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	Input.parse_input_event(motion)


func _own_units() -> Array[Unit]:
	var result: Array[Unit] = []
	for unit in _battle.units:
		if unit.side == _battle.phase:
			result.append(unit)
	return result


static func _distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


static func _arg(args: PackedStringArray, key: String) -> String:
	var at := args.find(key)
	return args[at + 1] if at >= 0 and at + 1 < args.size() else ""


func _quit(message: String, code: int) -> void:
	if code == 0:
		print(message)
	else:
		printerr(message)
	get_tree().quit(code)
