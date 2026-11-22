class_name Stronghold
extends RefCounted
## 拠点（選べる決まり TrialRules.STRONGHOLD。docs/map-objects.md の「拠点」、docs/win-conditions.md の「拠点を確保し続ける」）。
##
## 盤の中央（両方の本陣から同じ道のり）のマス 1 つ。自分の駒が乗ったまま自分のフェーズを終えると、そのプレイヤーの「確保」が 1 進み、
## HOLDS_TO_WIN に届いたら勝ち（GameWonEvent.Reason.STRONGHOLD_HELD）。
## - 拠点の隣（CONTEST_RADIUS 以内）に相手の駒がいれば、確保は進まない（止まる。減りはしない）
## - 乗らずに終えても、確保は減らない
## - 相手が確保を進めると、自分の確保は 0 に戻る（相手が上書きする）
## - 将は乗っても確保を進めない

## 確保がこの数に届いたら勝ち。
const HOLDS_TO_WIN := 8
## 拠点からこの距離（マンハッタン距離）以内に相手の駒がいる間は、確保が進まない（1 = 上下左右の隣）。
const CONTEST_RADIUS := 1
## 中ボスの家からこの距離（マンハッタン距離）以内には置かない（中ボスの縄張り。拠点に乗った駒が中ボスに殴られ続けないように）。
const BOSS_CLEARANCE := Neutral.TERRITORY_RADIUS


## 盤 board の拠点のマスを決める。両方の本陣からの道のり（移動のコスト。ポータルは転移も使う）の差がいちばん小さいマスのうち、
## 両方の本陣の真ん中にいちばん近いもの。それが何マスかあれば（盤の真ん中をはさんだ対など）、種 battle_seed から引いた乱数で選ぶ。盤によっては、先手の陣地の側と後手の陣地の側に 1 つずつ候補ができ、
## どちらに置くかで先手・後手の有利がはっきり変わるので、決め打ちにせず、局ごとに替わるようにする。
## 置けるのは、どちらの本陣からも歩いて行ける、何も置かれていない（環境オブジェクトの無い）マスで、本陣・結晶泉・中ボスのマスでないもの。
## 置けるマスが無ければ Board.NO_CELL。
static func choose_cell(board: Board, battle_seed := 0) -> Vector2i:
	var ties := candidates(board)
	if ties.is_empty():
		return Board.NO_CELL
	# 種の偶奇は、集計の道具の軍の組み合わせの順と重なるので、種から乱数を引いて選ぶ。
	var rng := RandomNumberGenerator.new()
	rng.seed = battle_seed
	return ties[rng.randi_range(0, ties.size() - 1)]


## 拠点を置ける候補（道のりの差がいちばん小さく、真ん中にいちばん近いマス。上の行から、左の列から）。
static func candidates(board: Board) -> Array[Vector2i]:
	var ties: Array[Vector2i] = []
	if board.hq_cells.size() < 2:
		return ties
	var near := distances(board, board.hq_cells[0])
	var far := distances(board, board.hq_cells[1])
	var middle := Vector2(board.hq_cells[0] + board.hq_cells[1]) / 2.0
	var best_gap := 0
	var best_off := 0.0
	for y in board.size.y:
		for x in board.size.x:
			var cell := Vector2i(x, y)
			var i := y * board.size.x + x
			if near[i] < 0 or far[i] < 0 or not _can_hold(board, cell):
				continue
			var gap := absi(near[i] - far[i])
			var off := Vector2(cell).distance_squared_to(middle)
			if ties.is_empty() or gap < best_gap or (gap == best_gap and off < best_off - 0.001):
				ties = [cell]
				best_gap = gap
				best_off = off
			elif gap == best_gap and absf(off - best_off) <= 0.001:
				ties.append(cell)
	return ties


static func _can_hold(board: Board, cell: Vector2i) -> bool:
	if not board.can_place_object(cell) or board.hq_owner(cell) >= 0:
		return false
	if board.terrain_at(cell) == Terrain.Type.FONT:
		return false
	for home in board.mid_boss_cells:
		if Combat.distance(home, cell) <= BOSS_CLEARANCE:
			return false
	return true


## 拠点を置く（選べる決まりが入の対戦だけ。MatchSetup.create_battle が呼ぶ。battle_seed は対戦の種）。置けるマスが無ければ置かない。
## 拠点のマスが森なら平地にする（拠点が木立に隠れず、乗った駒が森の軽減で守られない）。
static func arm(board: Board, battle_seed := 0) -> void:
	var cell := choose_cell(board, battle_seed)
	if cell == Board.NO_CELL:
		return
	if board.terrain_at(cell) != Terrain.Type.NORMAL:
		board.set_terrain(cell, Terrain.Type.NORMAL)
	board.stronghold_cell = cell


## player の駒が、拠点の確保を進められる形で乗っているか（将は数えない）。
static func holds(battle: Battle, player: Unit.Side) -> bool:
	var cell := battle.board.stronghold_cell
	if cell == Board.NO_CELL:
		return false
	var occupant := battle.unit_at(cell)
	return occupant != null and occupant.side == player and counts(occupant)


## 拠点の周り（マンハッタン距離 CONTEST_RADIUS 以内）に、player の相手の駒がいるか（いれば確保は進まない）。
static func contested(battle: Battle, player: Unit.Side) -> bool:
	var cell := battle.board.stronghold_cell
	for unit in battle.units:
		if unit.side == (1 - player) and Combat.distance(unit.cell, cell) <= CONTEST_RADIUS:
			return true
	return false


## その駒が乗っていれば、確保を進めるか（将でない、プレイヤーの駒）。
static func counts(unit: Unit) -> bool:
	return unit.side != Unit.Side.NEUTRAL and unit.kind != UnitKind.Id.KING


## player のフェーズの終わりに、拠点の確保を数える（EndPhaseAction が、敵の本陣の占拠のあとに呼ぶ）。
## 乗っていて、周りに相手の駒がいなければ 1 進め、相手の確保を 0 に戻す。そうでなければ、どちらも変えない。数が変わった分だけ StrongholdProgressEvent を出す。
## HOLDS_TO_WIN に届いたら勝ち。拠点の無い盤と、拠点の確保が勝ちの条件に無いプレイヤーでは何もしない。
static func count(battle: Battle, player: Unit.Side) -> Array[BattleEvent]:
	var events: Array[BattleEvent] = []
	if battle.is_over() or not battle.wins_by(player, GameWonEvent.Reason.STRONGHOLD_HELD):
		return events
	if not holds(battle, player) or contested(battle, player):
		return events
	battle.stronghold_holds[player] += 1
	events.append(StrongholdProgressEvent.new(player, battle.stronghold_holds[player]))
	var foe := (1 - player) as Unit.Side
	if battle.stronghold_holds[foe] > 0:
		battle.stronghold_holds[foe] = 0
		events.append(StrongholdProgressEvent.new(foe, 0))
	if battle.stronghold_holds[player] >= HOLDS_TO_WIN:
		battle.winner = player
		events.append(GameWonEvent.new(player, GameWonEvent.Reason.STRONGHOLD_HELD))
	return events


## あと何回の確保で勝つか（拠点の確保が勝ちの条件に無ければ -1）。
static func holds_left(battle: Battle, player: Unit.Side) -> int:
	if battle.board.stronghold_cell == Board.NO_CELL or not battle.wins_by(player, GameWonEvent.Reason.STRONGHOLD_HELD):
		return -1
	return maxi(0, HOLDS_TO_WIN - battle.stronghold_holds[player])


## from からの道のり（移動のコスト。入れないマスは -1）。ポータルは、対になるポータルへ移動力を使わずに移る。添字は 行 x 幅 + 列。
static func distances(board: Board, from: Vector2i) -> PackedInt32Array:
	var dist := PackedInt32Array()
	dist.resize(board.size.x * board.size.y)
	dist.fill(-1)
	if not board.in_bounds(from):
		return dist
	dist[from.y * board.size.x + from.x] = 0
	var open: Array[Vector2i] = [from]
	while not open.is_empty():
		var pick := 0
		for k in open.size():
			if dist[_i(board, open[k])] < dist[_i(board, open[pick])]:
				pick = k
		var cell := open[pick]
		open.remove_at(pick)
		var base := dist[_i(board, cell)]
		var steps: Array[Array] = []
		for direction in Board.DIRECTIONS:
			var next := cell + direction
			if board.in_bounds(next) and board.move_cost(next) >= 0:
				steps.append([next, board.move_cost(next)])
		var exit := board.portal_exit(cell)
		if exit != Board.NO_CELL:
			steps.append([exit, 0])
		for step in steps:
			var next: Vector2i = step[0]
			var i := _i(board, next)
			if dist[i] < 0 or dist[i] > base + int(step[1]):
				if dist[i] < 0:
					open.append(next)
				dist[i] = base + int(step[1])
	return dist


static func _i(board: Board, cell: Vector2i) -> int:
	return cell.y * board.size.x + cell.x
