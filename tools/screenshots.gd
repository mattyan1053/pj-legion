extends Node
## 試作の決まった場面を画像に撮る。`-- --shots <場面,…|all> --out <ディレクトリ>` を付けて起動すると、
## アプリ（app.gd）が、タイトル → 対戦の設定 → 対戦 と人と同じ道で対戦に入ったところで、このノードを足す。
## 撮り終えたら終わる。使い方は docs/screenshots.md。
## 対戦の場面は対戦の画面（board_prototype.gd）で撮り、タイトルと対戦の設定の場面は、アプリをその場面へ切り替えて撮る。
##
## 場面はどれも、種を決めた対戦（MatchSetup）を CPU どうしで進めて作る。人の操作と同じ入口で駒を選ぶので、
## 毎回同じ絵になる。場面を足すときは、SCENES に名前と説明を足し、同じ名前の _scene_<名前>() を書く
## （その場面まで状態を作るだけ。撮るのはこのノードがやる）。

const Queries := preload("res://prototype/battle_queries.gd")
const TrialSetup := preload("res://prototype/trial_setup.gd")
const BattleLog := preload("res://prototype/battle_log.gd")
const OrbitCamera := preload("res://prototype/orbit_camera.gd")
const BoardView := preload("res://prototype/board_view.gd")

## 場面の名前 -> 説明（撮る順）。
const SCENES := {
	"title": "タイトルの場面（起動した直後）",
	"title_menu": "タイトルで Esc を押して開いたシステムメニュー",
	"setup": "対戦の設定の場面（タイトルの「始める」のあと）",
	"setup_again": "対戦の途中で開いた、対戦の設定画面（閉じて戻れる）",
	"setup_deck": "対戦の設定で、取っておいた部隊を選ぶところ（選択肢を開いた）",
	"deck_list": "部隊の編成: 取っておいた部隊の一覧（出せない部隊も理由つきで並ぶ）",
	"deck_delete": "部隊の編成: 部隊を消す前の確かめ",
	"deck_empty": "部隊の編成: 新しく組み始めた、空の部隊",
	"deck_built": "部隊の編成: 組んだ部隊（雇える駒にマウスを乗せて、中身を読んでいる）",
	"deck_equip": "部隊の編成: 部隊の駒を選んで、装備を持たせている",
	"deck_over": "部隊の編成: 予算を超えて、取っておけない",
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
	"threat": "相手の駒をクリックして見ている（脅威範囲が出ている）",
	"inspect_moved": "自分の駒を動かしたあと（メニューが出たまま）に、相手の駒を見ている",
	"threat_all": "自分の駒を選んで、敵の全員の脅威範囲（赤い斜線）を重ねている",
	"skill": "スキルの対象を選んでいる",
	"forecast_attack": "動いたあと、攻撃の相手にマウスを乗せて、戦闘予測のパネルが出ている",
	"forecast_defeat": "倒せる相手にマウスを乗せている（予測のパネルに「倒せる！」）",
	"forecast_skill": "範囲のスキルの対象のマスにマウスを乗せている（巻き込む駒が並ぶ）",
	"forecast_heal": "回復役で、回復できる味方にマウスを乗せている",
	"info_status": "必殺技のあとの駒の情報（所属、状態と残りの期間、装備、スキル）",
	"ult": "必殺技のゲージが READY で、使うかを確かめている",
	"mid_boss": "中ボスを倒して、上の帯に聖遺物が出ている",
	"result": "決着の画面と戦績",
	"log_closed": "相手（CPU）の番のあと、ログを閉じている（上の帯の「ログ」のボタン）",
	"log_open": "相手（CPU）の番のあとに、ログを開いた",
	"log_chosen": "ログの行（相手の攻撃）を押して、その場所と駒を盤の上で示している",
	"log_long": "終盤のログ（長いログ。少しさかのぼったところ）",
	"wide": "いちばん引いて、低い角度で、盤の全体とその向こうを見ている",
	"board_edge": "盤の角と、その外側（低い角度で、盤の外へ向いている）",
	"rotated": "カメラを斜めに回して、低い角度で見ている",
	"hit_slam": "前衛の攻撃が当たった瞬間（相手の足元から衝撃の輪が広がる）",
	"hit_slash": "奇襲の攻撃が当たった瞬間（斜めの白い弧）",
	"hit_shot": "スナイパーの射撃が当たった瞬間（光の弾と、散る火花）",
	"hit_magic": "魔法の攻撃が飛んでいるところ（光る球）",
	"wait_sign": "駒が待機した瞬間（足元の輪が縮み、「待機」が出て消える）",
	"marks": "寄って見た、駒の足元の印（行動済み、HP の棒）と、移動範囲",
	"stage_labyrinth": "迷宮回廊の全景",
	"stage_twin_springs": "双子結晶の全景",
}
## 中ボスが倒れるまで続く対戦の種（CPU どうしで 29 ターン、プレイヤー1 がターン 20 に左の中ボスを倒す）。
const SEED := 1
## 撮る前に待つ時間（秒）。番の知らせが消え、カメラが寄り終わるまで。
const SETTLE := 1.8
## 番の知らせが消えるのを、SETTLE のあとさらに待つ上限（秒）。
const BANNER_WAIT := 3.0
## CPU どうしで進める行動の数の上限（場面が来なければ、撮らずに失敗にする）。
const MAX_ACTIONS := 3000
const JPEG_QUALITY := 0.82

var _app: Node
## いまの対戦の画面（board_prototype.gd）。アプリが対戦の場面にいる間だけ使う。
var _scene: Node
var _out := ""
var _names: Array[String] = []
var _cpu := CpuPlayer.new()
var _battle: Battle
var _stats: BattleStats
## _battle の始めからのログ（相手を CPU として書く）。
var _log: BattleLog
var _stage := BoardGenerator.Stage.PLAIN
## 場面が、演出の途中を撮る時刻まで自分で待ったか（真なら、再生の終わりも知らせが消えるのも待たずに、すぐ撮る）。
var _mid_animation := false
## 演出の途中を撮る場面は、時間をこの速さに落として進める（描画の遅い環境では 1 コマが長く、短い演出を飛び越えてしまうため）。
const SLOW_MOTION := 0.15


func _init(app: Node) -> void:
	_app = app


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
		_app.system_menu().close()
		_app.context.settings.reset_all()
		if _app.current_id() != &"battle":
			_app.context.match_choice.cpu_opponent = false
			await _app.go(&"battle")
		_scene = _app.current_scene()
		_scene.log_panel().close()
		_scene.setup_panel().visible = false
		_scene.set_opponent(false)  # 撮る間は CPU に番を進めさせない
		_scene.hover(Vector2i(-1, -1))  # 前の場面で乗せたことにしたマウスを戻す
		if _scene.is_threat_shown():
			_scene.toggle_threat()  # 前の場面で出した、敵の全員の脅威範囲を消す
		_stage = BoardGenerator.Stage.PLAIN
		_new_battle()
		_aim(22.0, 0.0, OrbitCamera.DEFAULT_PITCH)  # 前の場面で動かしたカメラを戻す（ほかの場面は、始めの向きと角度で撮る）
		_mid_animation = false
		var ok: bool = await call("_scene_" + name)
		if not ok:
			_quit("screenshots: 場面 %s を作れなかった" % name, 1)
			return
		if _mid_animation:
			if not await _capture(name):
				return
			_scene.set_time_scale_base(1.0)
			while _scene.is_busy():  # 次の場面を作る前に、再生を終わらせる
				await get_tree().process_frame
			continue
		while _app.current_id() == &"battle" and _scene.is_busy() and not _scene.setup_panel().visible and not _app.system_menu().is_open() and not _scene.log_panel().is_open():
			await get_tree().process_frame
		_park_mouse()
		# システムメニューを開いている間は時間が止まるので、待つのは時間の速さに依らない時計で測る。
		await get_tree().create_timer(SETTLE, true, false, true).timeout
		await _banner_gone()
		if not await _capture(name):
			return
	_quit("screenshots: OK", 0)


## いまの画面を撮って書く。書けなければ終わらせて偽を返す。
func _capture(name: String) -> bool:
	await RenderingServer.frame_post_draw
	var path := _out.path_join(name + ".jpg")
	var error := get_viewport().get_texture().get_image().save_jpg(path, JPEG_QUALITY)
	if error != OK:
		_quit("screenshots: %s を書けなかった（%s）" % [path, error_string(error)], 1)
		return false
	print("screenshots: %s" % path)
	return true


# ---- 場面 ----


func _scene_title() -> bool:
	await _app.go(&"title")
	return _app.current_id() == &"title"


func _scene_title_menu() -> bool:
	await _app.go(&"title")
	_app.open_menu()
	return _app.system_menu().is_open()


## 部隊の一覧に、見本の部隊を入れる（検査とスクリーンショットでは、取っておく先が無いので、毎回ここで作る）。
func _fill_decks() -> void:
	var library: RefCounted = _app.context.decks
	library.load_data({"decks": []})
	var first := Deck.new(UnitKind.Army.MILITARY)
	for kind: UnitKind.Id in [UnitKind.Id.SHIELD_TROOPER, UnitKind.Id.SNIPER, UnitKind.Id.SNIPER, UnitKind.Id.COMMANDO, UnitKind.Id.MEDIC]:
		first.add(kind)
	first.entries[0].equip(Equipment.Id.IRON_SHIELD)
	first.entries[0].equip(Equipment.Id.IRON_SHIELD)
	first.entries[3].equip(Equipment.Id.SPEED_BOOTS)
	library.add("狙撃の布陣", first)
	var second := Deck.new(UnitKind.Army.FANTASY)
	for kind: UnitKind.Id in [UnitKind.Id.PALADIN, UnitKind.Id.SPELLBLADE, UnitKind.Id.SPELLBLADE, UnitKind.Id.PRIEST]:
		second.add(kind)
	second.entries[1].equip(Equipment.Id.SPEED_BOOTS)
	library.add("速攻の騎士団", second)
	var third := Deck.new(UnitKind.Army.MILITARY)
	for i in 6:
		third.add(UnitKind.Id.SHIELD_TROOPER)
	third.entries[0].equip(Equipment.Id.IRON_SHIELD)
	library.add("盾の壁（予算の見直し前）", third)


func _deck_scene() -> Node:
	_fill_decks()
	await _app.go(&"decks")
	return _app.current_scene() if _app.current_id() == &"decks" else null


func _scene_deck_list() -> bool:
	var screen: Node = await _deck_scene()
	if screen == null:
		return false
	screen.select_saved(_app.context.decks.items()[2].id)
	return screen.list_selected() != ""


func _scene_deck_delete() -> bool:
	var screen: Node = await _deck_scene()
	if screen == null:
		return false
	screen.press_delete()
	return screen.is_dialog_open()


func _scene_deck_empty() -> bool:
	var screen: Node = await _deck_scene()
	if screen == null:
		return false
	screen.press_new()
	return screen.is_editing()


## 組み直す部隊（一覧の最初の部隊）を開く。
func _deck_editor() -> Node:
	var screen: Node = await _deck_scene()
	if screen == null:
		return null
	screen.select_saved(_app.context.decks.items()[0].id)
	screen.press_edit()
	return screen if screen.is_editing() else null


func _scene_deck_built() -> bool:
	var screen: Node = await _deck_editor()
	if screen == null:
		return false
	screen._set_hover(UnitKind.Id.SNIPER)
	return true


func _scene_deck_equip() -> bool:
	var screen: Node = await _deck_editor()
	if screen == null:
		return false
	screen.select_entry(3)
	screen.equip(Equipment.Id.SPEED_BOOTS)
	return screen.selected_entry() == 3


func _scene_deck_over() -> bool:
	var screen: Node = await _deck_editor()
	if screen == null:
		return false
	screen.hire(UnitKind.Id.SHIELD_TROOPER)
	screen.equip(Equipment.Id.IRON_SHIELD)
	screen.equip(Equipment.Id.IRON_SHIELD)
	screen.equip(Equipment.Id.SPEED_BOOTS)
	return not screen.can_save()


func _scene_setup_deck() -> bool:
	_fill_decks()
	_app.context.match_choice = TrialSetup.new()
	await _app.go(&"setup")
	if _app.current_id() != &"setup":
		return false
	var panel: Node = _app.current_scene().setup_panel()
	if not panel.choose_deck(Unit.Side.PLAYER1, _app.context.decks.items()[0].id):
		return false
	_park_mouse()
	await get_tree().process_frame
	var picker: OptionButton = panel._deck_pickers[0]
	picker.show_popup()
	return true


func _scene_setup() -> bool:
	_app.context.match_choice = TrialSetup.new()  # 遊ぶときの始めと同じ（相手は CPU）で開く
	await _app.go(&"setup")
	return _app.current_id() == &"setup"


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
	return _app.system_menu().is_open()


func _scene_system_menu() -> bool:
	return await _open_system_menu()


func _scene_system_quit() -> bool:
	if not await _open_system_menu():
		return false
	_app.system_menu().press(&"quit")
	return _app.system_menu().confirming() == &"quit"


func _scene_settings() -> bool:
	if not await _open_system_menu():
		return false
	_app.system_menu().press(&"settings")
	_scene.settings.set_value(&"mouse_sensitivity", 150)
	return _app.system_menu().is_settings_open()


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


func _scene_inspect_moved() -> bool:
	if not await _scene_menu_moved():
		return false
	# 動いた駒にいちばん近い、攻撃の相手でない相手の駒（将と回復役は除く。相手の駒はクリックで攻撃してしまい、回復役には脅威範囲が無い）。
	var mover: Unit = _scene.selected_unit()
	var targets := _battle.options(mover.id).attack_target_ids
	var best: Unit = null
	var nearest := 1 << 30
	for foe in _battle.units:
		if foe.side != 1 - _battle.phase or foe.kind == UnitKind.Id.KING or targets.has(foe.id):
			continue
		if UnitKind.role(foe.kind) == UnitKind.Role.HEALER:
			continue
		if _distance(foe.cell, mover.cell) < nearest:
			best = foe
			nearest = _distance(foe.cell, mover.cell)
	if best == null:
		return false
	_scene.click_cell(best.cell)
	_look_at((BoardView.cell_center(best.cell) + BoardView.cell_center(mover.cell)) / 2.0)
	_aim(26.0, 0.0, OrbitCamera.DEFAULT_PITCH)
	return _scene.inspected_unit() == best and _scene.selected_unit() == mover


func _scene_threat_all() -> bool:
	if not _advance(func() -> bool: return _battle.turn >= 3 and _battle.phase == Unit.Side.PLAYER1):
		return false
	_show()
	var unit := _own_units()[0]
	for own in _own_units():
		if own.kind != UnitKind.Id.KING and _battle.can_act(own):
			unit = own
			break
	_scene.click_cell(unit.cell)
	_scene.toggle_threat()
	_scene.focus_camera(unit.cell)
	return _scene.is_threat_shown()


func _scene_forecast_attack() -> bool:
	if not await _scene_menu_moved():
		return false
	var mover: Unit = _scene.selected_unit()
	var target := _battle.unit_by_id(_battle.options(mover.id).attack_target_ids[0])
	_scene.hover(target.cell)
	return _scene.forecast_text() != ""


## 行動できる自分の駒が、いまの位置から倒せる相手（[駒, 相手]）。無ければ空。
func _defeat_now() -> Array:
	for unit in _own_units():
		if not _battle.can_act(unit):
			continue
		for target_id in _battle.options(unit.id).attack_target_ids:
			if Forecast.of(_battle, AttackAction.new(unit.id, target_id)).defeated_ids().has(target_id):
				return [unit, _battle.unit_by_id(target_id)]
	return []


func _scene_forecast_defeat() -> bool:
	if not _advance(func() -> bool: return _battle.phase != Unit.Side.NEUTRAL and not _defeat_now().is_empty()):
		return false
	var found := _defeat_now()
	_show()
	_scene.click_cell(found[0].cell)
	_look_at(BoardView.cell_center(found[1].cell))
	_scene.hover(found[1].cell)
	return _scene.forecast_text().contains("倒せる")


## 行動できる自分の駒が、スキルで相手を 2 体以上巻き込めるマス（[駒, マス]）。無ければ空。
func _skill_hits() -> Array:
	for unit in _own_units():
		if not _battle.can_act(unit):
			continue
		for cell in _battle.options(unit.id).skill_cells:
			var forecast := Forecast.of(_battle, UseSkillAction.new(unit.id, cell))
			var hits := 0
			for outcome in forecast.units:
				if outcome.hits > 0:
					hits += 1
			if hits >= 2:
				return [unit, cell]
	return []


func _scene_forecast_skill() -> bool:
	if not _advance(func() -> bool: return _battle.phase != Unit.Side.NEUTRAL and not _skill_hits().is_empty()):
		return false
	var found := _skill_hits()
	_show()
	_scene.click_cell(found[0].cell)
	_scene.press_skill()
	_look_at(BoardView.cell_center(found[1]))
	_scene.hover(found[1])
	return _scene.is_choosing_skill_target() and _scene.forecast_text() != ""


func _scene_forecast_heal() -> bool:
	var healer := func() -> Unit:
		for unit in _own_units():
			if _battle.can_act(unit) and not Queries.heal_targets(_battle, unit).is_empty():
				return unit
		return null
	if not _advance(func() -> bool: return _battle.phase != Unit.Side.NEUTRAL and healer.call() != null):
		return false
	_show()
	var unit: Unit = healer.call()
	var target: Unit = Queries.heal_targets(_battle, unit)[0]
	_scene.click_cell(unit.cell)
	_look_at(BoardView.cell_center(target.cell))
	_scene.hover(target.cell)
	return _scene.forecast_text() != ""


func _scene_info_status() -> bool:
	if not _advance(func() -> bool: return Ults.can_use(_battle)):
		return false
	_show()
	await _scene.act(UseUltAction.new())
	# 装備を持っている駒（無ければ、将でない駒）を見る。
	var best: Unit = null
	for unit in _battle.units:
		if unit.side == _battle.phase and unit.kind != UnitKind.Id.KING and (best == null or unit.equipment.size() > best.equipment.size()):
			best = unit
	if best == null:
		return false
	_look_at(BoardView.cell_center(best.cell))
	_scene.hover(best.cell)
	return not Statuses.types_of(best).is_empty()


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


## 相手（CPU）の番と中立のフェーズのあと（ターン 5 の自分の番の始め）。始めからのログを画面に渡す。
func _after_cpu_turn() -> bool:
	if not _advance(func() -> bool: return _battle.turn >= 5 and _battle.phase == Unit.Side.PLAYER1):
		return false
	_show()
	_scene.battle_log = _log
	return true


func _scene_log_closed() -> bool:
	return _after_cpu_turn()


func _scene_log_open() -> bool:
	if not _after_cpu_turn():
		return false
	_scene.open_log()
	return true


func _scene_log_chosen() -> bool:
	if not _after_cpu_turn():
		return false
	_scene.open_log()
	# 相手の番の、いちばん最後の攻撃の行を押す。
	for i in range(_log.entries.size() - 1, -1, -1):
		var entry: BattleLog.Entry = _log.entries[i]
		if entry.phase == Unit.Side.PLAYER2 and entry.text.contains("を攻撃"):
			_scene.log_panel().choose(i)
			return true
	return false


func _scene_log_long() -> bool:
	if _advance(func() -> bool: return false):
		return false  # 決着しなかった
	_show()
	_scene.battle_log = _log
	var started := Time.get_ticks_usec()
	_scene.open_log()
	print("screenshots: ログ %d 行（ターン %d）を %.1f ms で並べた" % [_log.entries.size(), _battle.turn, (Time.get_ticks_usec() - started) / 1000.0])
	await get_tree().process_frame
	await get_tree().process_frame
	var panel: Node = _scene.log_panel()
	panel.scroll_to(int(panel._scroll.get_v_scroll_bar().max_value) - 1500)
	return true


## kinds のどれかの駒が、動かずに攻撃できる場面まで進め、その攻撃を始めて、当たる瞬間から after 秒あとに撮る
## （負なら、当たる前）。カメラは寄せて、相手を真ん中に置く。
func _attack_frame(kinds: Array, after: float) -> bool:
	var find := func() -> Array:
		if _battle.phase == Unit.Side.NEUTRAL:
			return []
		for unit in _own_units():
			if kinds.has(unit.kind) and _battle.can_act(unit):
				var targets := _battle.options(unit.id).attack_target_ids
				if not targets.is_empty():
					return [unit, _battle.unit_by_id(targets[0])]
		return []
	if not _advance(func() -> bool: return not find.call().is_empty()):
		return false
	var found: Array = find.call()
	var unit: Unit = found[0]
	var target: Unit = found[1]
	_show()
	await _settle_camera(target.cell)
	_scene.set_time_scale_base(SLOW_MOTION)
	_scene.act(AttackAction.new(unit.id, target.id))
	await get_tree().create_timer(0.4 + after).timeout  # 0.4 は、攻撃の動きを始めてから当たるまで（unit_view.gd の play_attack）
	_mid_animation = true
	return true


## 番の知らせが消え、カメラが cell に寄り終わるまで待つ（演出の途中を撮る場面の下ごしらえ）。
func _settle_camera(cell: Vector2i) -> void:
	_aim(13.0, 20.0, OrbitCamera.DEFAULT_PITCH)
	_scene.focus_camera(cell)
	await get_tree().create_timer(SETTLE).timeout
	await _banner_gone()


func _scene_hit_slam() -> bool:
	return await _attack_frame([UnitKind.Id.SHIELD_TROOPER, UnitKind.Id.PALADIN], 0.08)


func _scene_hit_slash() -> bool:
	return await _attack_frame([UnitKind.Id.COMMANDO, UnitKind.Id.SPELLBLADE], 0.08)


func _scene_hit_shot() -> bool:
	return await _attack_frame([UnitKind.Id.SNIPER], 0.06)


func _scene_hit_magic() -> bool:
	return await _attack_frame([UnitKind.Id.SORCERER], -0.07)


func _scene_wait_sign() -> bool:
	if not _advance(func() -> bool: return _battle.turn >= 2 and _battle.phase == Unit.Side.PLAYER1):
		return false
	_show()
	var unit: Unit = null
	for candidate in _own_units():
		if _battle.can_act(candidate) and candidate.kind != UnitKind.Id.KING:
			unit = candidate
			break
	if unit == null:
		return false
	await _settle_camera(unit.cell)
	_scene.set_time_scale_base(SLOW_MOTION)
	_scene.act(WaitAction.new(unit.id))
	await get_tree().create_timer(0.15).timeout
	_mid_animation = true
	return true


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
	_log = BattleLog.new(_battle, ["プレイヤー1（青）", "プレイヤー2（赤） CPU"] as Array[String])


## いまの _battle を画面に出す（駒の見た目は、いまの状態から作る）。
## 対戦の画面の中央の知らせ（番の知らせなど）が消えるまで待つ。描画の遅い環境では SETTLE のうちに消えないことがある。
## 知らせを撮る場面のために、待つのは BANNER_WAIT 秒まで。
func _banner_gone() -> void:
	if _app.current_id() != &"battle" or _scene.setup_panel().visible or _app.system_menu().is_open() or _scene.log_panel().is_open():
		return  # 時間が止まっている（知らせは消えない）
	var waited := 0.0
	while _scene._hud.is_banner_shown() and waited < BANNER_WAIT:
		await get_tree().process_frame
		waited += get_process_delta_time()


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
		_log.feed_all(result.events)
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
