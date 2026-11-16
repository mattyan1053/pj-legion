extends RefCounted
## CPU どうしの短い 1 局を、テストの間で 1 回だけ回して控える（検査の時間を抑えるため）。
##
## 時間が掛かるのは CPU が考えるところで、行動を当て直すのは速い。だから、1 局を自動の対戦の道具
## （tools/cpu_match.gd）で 1 回だけ回して、受け付けられた行動の列を控えておく。
## 同じ局を読みたいテスト（戦績、ログ、道具、CPU の判断）は、replay で、作りたての対戦に同じ行動を当て直す。
##
##   var battle := CpuGame.start()
##   var book := BattleLog.new(battle)
##   CpuGame.replay(battle, func(result: ActionResult) -> void: book.feed_all(result.events))

const CpuMatch := preload("res://tools/cpu_match.gd")
const Maps := preload("res://tests/support/maps.gd")

## 控える局の種とターンの上限（この種で、上限より前に決着する）。
const SEED := 1
const MAX_TURNS := 60

static var _outcome: CpuMatch.Outcome
static var _actions: Array[BattleAction] = []


## CPU の考えた行動を控える。プレイヤー1 は CpuPlayer。プレイヤー2 は、同じ rules/cpu_player.gd を
## 別の版の入口（CpuMatch.load_rival。docs/cpu-ai.md の「別の版と比べる」）で読んだもの。
## 中身は同じなので同じ手を指し、その入口が黙って壊れていないことも、この 1 局で確かめる。
class Recorder:
	extends RefCounted

	var cpu := CpuPlayer.new()
	var rival := CpuMatch.load_rival("res://rules/cpu_player.gd")
	var actions: Array[BattleAction] = []

	func next_action(battle: Battle) -> BattleAction:
		var thinker: RefCounted = rival if battle.phase == Unit.Side.PLAYER2 else cpu
		var action: BattleAction = thinker.call(&"next_action", battle)
		if action != null:
			actions.append(action)
		return action


## 壁と森と結晶泉のある 12 x 8 の盤面に、両方の軍（CPU の編成）を置いた対戦。
static func small_battle(battle_seed: int) -> Battle:
	var board := Maps.board([
		"............",
		"............",
		"....F..#....",
		"..#.....*...",
		"...*.....#..",
		"....#..F....",
		"............",
		"............",
	])
	board.hq_cells = [Vector2i(2, 7), Vector2i(9, 0)]
	var battle := Battle.new(board, battle_seed)
	Deployment.deploy(battle, Unit.Side.PLAYER1, CpuDeck.build(UnitKind.Army.MILITARY))
	Deployment.deploy(battle, Unit.Side.PLAYER2, CpuDeck.build(UnitKind.Army.FANTASY))
	return battle


## 控えた局の結果（CpuMatch.play が返したもの）。初めて呼んだときに 1 局を回す。
static func outcome() -> CpuMatch.Outcome:
	if _outcome == null:
		var recorder := Recorder.new()
		_outcome = CpuMatch.play(small_battle(SEED), MAX_TURNS, recorder)
		_actions = recorder.actions
	return _outcome


## 控えた局で、受け付けられた行動の列（考えた順）。
static func actions() -> Array[BattleAction]:
	outcome()
	return _actions


## 控えた局の、最初の行動の前の対戦（作りたて）。
static func start() -> Battle:
	return small_battle(SEED)


## start() で作った対戦に、控えた行動を順に当て直す。当てるたびに on_result(result) を呼ぶ。
## 当てる前の状態を見たいときは before(action) を渡す。断られたら、そこで止める。
static func replay(battle: Battle, on_result: Callable = Callable(), before: Callable = Callable()) -> void:
	for action in actions():
		if before.is_valid():
			before.call(action)
		var result := battle.apply(action)
		if not result.accepted:
			push_error("cpu_game: 控えた行動が、当て直すと断られた")
			return
		if on_result.is_valid():
			on_result.call(result)
