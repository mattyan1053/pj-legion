class_name CenterPoint
extends RefCounted
## SCRATCH（main に入れない）: 中央の拠点の試し（Issue #47「先制攻撃が不利で、待ち有利」）。決まりは環境変数で切り替える（RuleProbe）。
##
## - PROBE_POINT: 拠点の数（0 = 無し、1 = 両方の本陣から同じ道のりの真ん中、2 = その左右に 1 つずつ）
## - PROBE_POINT_RADIUS: 拠点の広さ（マンハッタン距離。0 = そのマスだけ）
## - 取り合い: 自分のフェーズの始めに、拠点の範囲に自分の駒がいて、相手のプレイヤーの駒がいなければ、その拠点はそのプレイヤーのもの
## - 得（拠点 1 つにつき、自分のフェーズの始めに）:
##   PROBE_POINT_GAUGE（必殺技のゲージ。1000 がいっぱい）、PROBE_POINT_HEAL（範囲の自分の駒の回復）、
##   PROBE_POINT_POWER（次の自分のフェーズの始めまで、自分の駒の攻撃のダメージ +N）、
##   PROBE_POINT_WIN（持ったフェーズの数の合計がこれに届いたら勝ち。0 = 無し）


static func count() -> int:
	return int(RuleProbe.f("point"))


static func radius() -> int:
	return int(RuleProbe.f("point_radius"))


## 拠点のマス（中心）。初めて聞かれたときに盤から決めて、盤に控える（盤の複製にも写る）。
static func cells(battle: Battle) -> Array[Vector2i]:
	var board := battle.board
	if not board.point_ready:
		board.point_ready = true
		board.point_cells = _choose(board)
	return board.point_cells


## cell が、どれかの拠点の範囲か。
static func covers(battle: Battle, cell: Vector2i) -> bool:
	for point in cells(battle):
		if Combat.distance(point, cell) <= radius():
			return true
	return false


## 拠点 point をいま持っているプレイヤー。だれも持っていなければ -1。
static func holder(battle: Battle, point: Vector2i) -> int:
	var present := [false, false]
	for unit in battle.units:
		if unit.side != Unit.Side.NEUTRAL and Combat.distance(unit.cell, point) <= radius():
			present[unit.side] = true
	if present[0] == present[1]:
		return -1
	return 0 if present[0] else 1


## side のフェーズの始めの得（EndPhaseAction が呼ぶ）。
static func start_phase(battle: Battle, side: Unit.Side) -> void:
	if count() == 0 or side == Unit.Side.NEUTRAL:
		return
	var held := 0
	for point in cells(battle):
		if holder(battle, point) != side:
			continue
		held += 1
		var heal := int(RuleProbe.f("point_heal"))
		if heal > 0:
			for unit in battle.units:
				if unit.side == side and Combat.distance(unit.cell, point) <= radius():
					unit.hp = mini(unit.max_hp(), unit.hp + heal)
	Ults.charge(battle, side, held * int(RuleProbe.f("point_gauge")))
	battle.point_power[side] = held * int(RuleProbe.f("point_power"))
	battle.point_score[side] += held
	var win := int(RuleProbe.f("point_win"))
	if win > 0 and battle.point_score[side] >= win and battle.winner < 0:
		battle.winner = side


## 攻撃のダメージに足す量。
static func power_bonus(battle: Battle, attacker: Unit) -> int:
	if attacker.side == Unit.Side.NEUTRAL:
		return 0
	return battle.point_power[attacker.side]


static func _choose(board: Board) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if count() == 0 or board.hq_cells.size() < 2:
		return result
	var d0 := _distances(board, board.hq_cells[0])
	var d1 := _distances(board, board.hq_cells[1])
	var center := Vector2(board.hq_cells[0] + board.hq_cells[1]) / 2.0
	var targets: Array[Vector2] = [center]
	if count() >= 2:
		var side := Vector2(board.size.x * float(RuleProbe.f("point_spread", 0.25)), 0)
		targets = [center - side, center + side]
	for target in targets:
		var best := Board.NO_CELL
		var best_key := INF
		for y in board.size.y:
			for x in board.size.x:
				var cell := Vector2i(x, y)
				var i := y * board.size.x + x
				if d0[i] < 0 or d1[i] < 0 or board.object_at(cell) != MapObject.Type.NONE or board.hq_owner(cell) >= 0:
					continue
				if board.mid_boss_cells.has(cell):
					continue
				# 道のりの差を重く、狙いの場所からの離れを軽く見る。
				var key := 100.0 * absi(d0[i] - d1[i]) + Vector2(cell).distance_to(target)
				if key < best_key:
					best_key = key
					best = cell
		if best != Board.NO_CELL and not result.has(best):
			result.append(best)
	if RuleProbe.f("point_debug") > 0:
		var info := []
		for cell in result:
			info.append("%s d=%d,%d" % [cell, d0[cell.y * board.size.x + cell.x], d1[cell.y * board.size.x + cell.x]])
		print("POINT size=%s hq=%s %s" % [board.size, board.hq_cells, info])
	return result


## from からの道のり（移動のコスト。入れないマスは -1）。
static func _distances(board: Board, from: Vector2i) -> PackedInt32Array:
	var dist := PackedInt32Array()
	dist.resize(board.size.x * board.size.y)
	dist.fill(-1)
	dist[from.y * board.size.x + from.x] = 0
	var frontier: Array[Vector2i] = [from]
	while not frontier.is_empty():
		# 小さい盤なので、素朴なダイクストラ（毎回いちばん近いものを探す）で足りる。
		var best_index := 0
		for k in frontier.size():
			var c := frontier[k]
			if dist[c.y * board.size.x + c.x] < dist[frontier[best_index].y * board.size.x + frontier[best_index].x]:
				best_index = k
		var cell := frontier[best_index]
		frontier.remove_at(best_index)
		var base := dist[cell.y * board.size.x + cell.x]
		for direction in Board.DIRECTIONS:
			var next := cell + direction
			if not board.in_bounds(next):
				continue
			var cost := board.move_cost(next)
			if cost < 0:
				continue
			var i := next.y * board.size.x + next.x
			if dist[i] < 0 or dist[i] > base + cost:
				if dist[i] < 0:
					frontier.append(next)
				dist[i] = base + cost
	return dist
