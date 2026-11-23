extends Node
## スクリーンショットの道具（tools/screenshots.gd）の土台: 読み込み、調整値、状態と、場面を作るための道具（対戦を用意する、CPU で進める、カメラを向ける）。
## 場面のファイルは、これを継いで順に積み重なる（screenshots.gd が最後）。


const UnitLooks := preload("res://game/unit_looks.gd")
const SceneFlow := preload("res://game/scene_flow.gd")
const Queries := preload("res://game/battle_queries.gd")
const MatchChoice := preload("res://game/match_choice.gd")
const BattleLog := preload("res://game/battle_log.gd")
const OrbitCamera := preload("res://game/orbit_camera.gd")
const BoardView := preload("res://game/board_view.gd")
const Names := preload("res://game/names.gd")
const Text := preload("res://game/text.gd")
const ResultSummary := preload("res://game/result_summary.gd")
const StageLook := preload("res://game/stage_look.gd")
const VersusFields := preload("res://game/versus_fields.gd")
const Maps := preload("res://game/maps.gd")


## 景色の場面（SCENES に並べない。マップと見た目の組み合わせを、名前で作る）:
##   scape.<マップ>.<構図> か scape.<マップ>.<見た目>.<構図>
## マップは game/maps/ の id か、生成のマップの鍵（versus_fields.gd）。見た目は stage_look.gd の名前（書かなければ、マップの見た目）。
const SCAPE := "scape."
const SCAPE_VIEWS := ["wide", "side", "close", "out", "range", "paint"]
const SCAPE_USAGE := "scape.<マップ>.<構図> か scape.<マップ>.<見た目>.<構図>。構図: wide, side, close, out, range"


## 場面を作る対戦の最初の種。
const SEED := 1
## SEED の対戦で場面を作れなかったときに、続けて試す種の数（ルールや数値が変わると、同じ種でも場面が来なくなるため。_run）。
## どの種でも作れなかった場面は飛ばし、ほかの場面を撮ってから、まとめて失敗にする。
const MORE_SEEDS := 8
## 撮る前に待つ時間（秒）。番の知らせが消え、カメラが寄り終わるまで。
const SETTLE := 1.8
## 番の知らせが消えるのを、SETTLE のあとさらに待つ上限（秒）。
const BANNER_WAIT := 3.0
## カメラが寄り終わるのを待つ上限（秒。_camera_still）。
const CAMERA_WAIT := 4.0
## CPU どうしで進める行動の数の上限（場面が来なければ、撮らずに失敗にする）。
const MAX_ACTIONS := 3000
const JPEG_QUALITY := 0.82
## `--frame-time` で測るコマの数。
const FRAME_TIME_FRAMES := 40


var _app: Node
## いまの対戦の画面（battle_screen.gd）。アプリが対戦の場面にいる間だけ使う。
var _scene: Node
var _out := ""
## 場面を作るだけで撮らない（`--dry-run`。画面なしの長い検査で、場面が作れることだけを確かめる）。
var _dry_run := false
## 撮る前に、その場面の 1 コマの時間を測って出す（`--frame-time`。見た目を変えた前後の重さを比べる）。
var _frame_time := false
var _names: Array[String] = []
var _cpu := CpuPlayer.new()
var _battle: Battle
var _stats: BattleStats
## _battle の始めからのログ（相手を CPU として書く）。
var _log: BattleLog
## いまの対戦のマップ（versus_fields.gd の鍵）。
var _field: StringName = VersusFields.PLAIN
## いまの対戦の種（SEED から。場面を作れなければ _run が替える）。
var _seed := SEED
## 場面が、演出の途中を撮る時刻まで自分で待ったか（真なら、再生の終わりも知らせが消えるのも待たずに、すぐ撮る）。
var _mid_animation := false
## 演出の途中を撮る場面は、時間をこの速さに落として進める（描画の遅い環境では 1 コマが長く、短い演出を飛び越えてしまうため）。
const SLOW_MOTION := 0.15


func _init(app: Node) -> void:
	_app = app


const Story := preload("res://game/story.gd")
const Run := preload("res://game/run.gd")
const StoryBattle := preload("res://game/story_battle.gd")
const BattleCues := preload("res://game/battle_cues.gd")


func _new_battle(rules: Array[StringName] = []) -> void:
	var choice: RefCounted = MatchChoice.new()
	choice.field = _field
	choice.cpu_opponent = false
	choice.set_rule(OptionalRules.SEAM, false)  # 撮る場面がいつも同じになるよう、縫い目の様子は名指ししたときだけ
	for rule in rules:
		choice.set_rule(rule, true)
	_scene.source = choice
	var setup: MatchSetup = choice.to_setup(_seed)
	# 休眠の決まり（OptionalRules.DORMANT。組み方）は、画面からは入にできない（choice が受け付けない）。
	# 集計の道具の --rules= と同じく、道具の入口から直に入にする（作り直すときの見比べ用）。
	for rule in rules:
		if OptionalRules.DORMANT.has(rule) and not setup.rules.has(rule):
			setup.rules.append(rule)
	_battle = setup.create_battle()
	_stats = BattleStats.new(_battle)
	_log = BattleLog.new(_battle, ["プレイヤー1（青）", "CPU（赤）"] as Array[String])


## いまの _battle を画面に出す（駒の見た目は、いまの状態から作る）。
## 対戦の画面の中央の知らせ（番の知らせなど）が消えるまで待つ。描画の遅い環境では SETTLE のうちに消えないことがある。
## 知らせを撮る場面のために、待つのは BANNER_WAIT 秒まで。
func _banner_gone() -> void:
	if _app.current_id() != SceneFlow.BATTLE or _scene.setup_panel().visible or _app.system_menu().is_open() or _scene.log_panel().is_open() or _scene.unit_detail().visible:
		return  # 時間が止まっている（知らせは消えない）
	var waited := 0.0
	while _scene.is_banner_shown() and waited < BANNER_WAIT:
		await get_tree().process_frame
		waited += get_process_delta_time()


func _show() -> void:
	_scene.start_with(_battle, VersusFields.look_of(_field), _seed, VersusFields.title_of(_field))


## カメラの見ている地点を point にする（寄る動きは待たない）。
func _look_at(point: Vector3) -> void:
	_scene.place_camera(point)


## カメラの距離、向き（度）、見下ろす角度（度）を決める。
func _aim(distance: float, yaw_degrees: float, pitch: float) -> void:
	_scene.set_camera_view(distance, yaw_degrees)
	_scene.set_camera_pitch(pitch)


## カメラが寄り終わるまで待つ（見ている地点・距離・角度がコマの間で動かなくなるまで。上限 CAMERA_WAIT 秒）。
## 駒のそばのメニューと予測のパネルは、カメラが動く間、前に選んだ側をひいきして置き直すので、
## 動いている途中で駒を選ぶと、撮る時刻（コマの長さ）しだいで置き場所が変わる。カメラを決めてから選ぶ場面で使う。
func _camera_still() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var last := camera.global_transform
	var still := 0
	var waited := 0.0
	while still < 3 and waited < CAMERA_WAIT:
		await get_tree().process_frame
		waited += get_process_delta_time()
		var now := camera.global_transform
		still = still + 1 if now.is_equal_approx(last) else 0
		last = now


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
