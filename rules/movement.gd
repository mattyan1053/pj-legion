class_name Movement
extends RefCounted
## 駒の移動範囲と、そこまでの道。
##
## - 入るのに使う移動力は地形で決まる（平地・結晶泉 1、森 2）。合計が移動力以下のマスへ行ける。
##   森を歩く特性の駒は、森にも 1 で入る（Unit.move_cost）
## - 障害物、起爆樽、敵の駒のいるマスは通れない
## - 味方の駒のいるマスは通り抜けられるが、そこで止まることはできない
## - 敵の支配領域（ZOC）のマスには入れるが、そこで止まる（その先へは進めない）。
##   ただし、いま立っているマスが敵の ZOC でも、最初の 1 歩は踏み出せる。
##   ZOC で止まらない特性の駒（Unit.ignores_zoc）は、敵の ZOC を無いものとして進む
## - 巡航（攻撃を諦める移動）は移動力が 2 倍
## - ポータルのマスからは、対になるポータルへ移動力を使わずに移れる（行き先に駒がいなければ）。
##   道の中でポータルの対が続けて並んでいたら、そこは転移（Battle.portal_exit で見分ける）


## 移動に使える移動力。
static func budget(unit: Unit, cruise: bool) -> int:
	return unit.move_range() * (2 if cruise else 1)


## 止まれるマスと、そこまでに使う移動力の最小値。Vector2i -> int。いまのマス（0）も含む。
static func reachable(battle: Battle, unit: Unit, cruise := false) -> Dictionary:
	return _search(battle, unit, budget(unit, cruise)).stops()


## starts のどのマスからでも動き出せるとしたときに、止まれるマスと、そこまでに使う移動力の最小値（starts のマスは 0）。
## 「どこかで止まったあと、もう一度動く」ときの範囲を、1 回の探索で出す（脅威範囲。docs/threat-range.md）。
## starts のどのマスでも、いまのマスと同じに扱う（敵の ZOC でも最初の 1 歩は踏み出せる）。駒のいまのマスは空いているものとする。
static func reachable_from_any(battle: Battle, unit: Unit, starts: Array[Vector2i], cruise := false) -> Dictionary:
	return _search(battle, unit, budget(unit, cruise), starts).stops()


## いまのマスから to までの道（両端を含む）。行けなければ空。
## 同じ移動力で行ける道がいくつかあるときも、毎回同じ道を返す。
static func path_to(battle: Battle, unit: Unit, to: Vector2i, cruise := false) -> Array[Vector2i]:
	var found := _search(battle, unit, budget(unit, cruise))
	var path: Array[Vector2i] = []
	if not found.cost.has(to) or not found.can_stop(to):
		return path
	var cell := to
	path.append(cell)
	while cell != unit.cell:
		cell = found.parent[cell]
		path.append(cell)
	path.reverse()
	return path


## 移動範囲の探索の結果そのもの（止まれないマスと、道の親も含む）。
## 通常の移動と巡航の範囲を 1 回の探索で分けたいときに使う（UnitOptions）。
static func search(battle: Battle, unit: Unit, cruise := false) -> Search:
	return _search(battle, unit, budget(unit, cruise))


## 探索の結果。cost は通れるマス（味方のいるマスも含む）までの移動力の最小値、parent は道の 1 つ前のマス。
class Search:
	var cost: Dictionary[Vector2i, int] = {}
	var parent: Dictionary[Vector2i, Vector2i] = {}
	## ほかの駒のいるマス（通れても、止まれない）。
	var occupied: Dictionary[Vector2i, Unit] = {}

	func can_stop(cell: Vector2i) -> bool:
		return not occupied.has(cell)

	## 止まれるマスと、そこまでの移動力。
	func stops() -> Dictionary:
		var result := {}
		for cell in cost:
			if not occupied.has(cell):
				result[cell] = cost[cell]
		return result


## 通れるマスを、移動力の少ない順に広げる（ダイクストラ法）。味方のいるマスも通る。
## 同じ移動力のマスは見つけた順に広げるので、結果は毎回同じになる。
##
## 移動力は小さい整数なので、候補は移動力ごとの列に入れる。列の中は見つけた順に並ぶので、
## 「移動力の小さい順、同じなら見つけた順」に取り出すことになる。
## 駒の位置と敵の支配領域は、始めに 1 回だけ表にする（マスごとに全部の駒を調べない）。
static func _search(battle: Battle, unit: Unit, limit: int, from: Array[Vector2i] = []) -> Search:
	var found := Search.new()
	var board := battle.board
	var enemy_zoc: Dictionary[Vector2i, bool] = {}
	var stopped_by_zoc := not unit.ignores_zoc()
	for other in battle.units:
		if other == unit:
			continue
		found.occupied[other.cell] = other
		if stopped_by_zoc and other.side != unit.side and other.exerts_zoc():
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if dx != 0 or dy != 0:
						enemy_zoc[other.cell + Vector2i(dx, dy)] = true
	var occupied := found.occupied
	var cost := found.cost
	var parent := found.parent
	var starts: Dictionary[Vector2i, bool] = {}
	for cell in (from if not from.is_empty() else [unit.cell] as Array[Vector2i]):
		starts[cell] = true
	var done: Dictionary[Vector2i, bool] = {}
	var queues: Array[Array] = []
	for i in limit + 1:
		queues.append([] as Array[Vector2i])
	for cell in starts:
		cost[cell] = 0
		queues[0].append(cell)
	for spent in limit + 1:
		var queue: Array[Vector2i] = queues[spent]
		var head := 0
		# 転移（移動力 0）は、いま見ている列の後ろに足される。
		while head < queue.size():
			var cell := queue[head]
			head += 1
			if done.has(cell):
				continue
			done[cell] = true
			# 敵の ZOC に入ったマスからは先へ進めない（出発したマスだけは別）。
			if not starts.has(cell) and enemy_zoc.has(cell):
				continue
			# 行き先。ポータルの転移（移動力 0）を先に、そのあと上下左右。
			# 転移できるのは、行き先に駒（陣営を問わない。自分も含む）がいないときだけ（Battle.portal_exit と同じ）。
			var exit := board.portal_exit(cell)
			if starts.has(exit) or occupied.has(exit):
				exit = Board.NO_CELL
			for i in range(0 if exit != Board.NO_CELL else 1, 5):
				var next := exit if i == 0 else cell + Board.DIRECTIONS[i - 1]
				if done.has(next):
					continue  # もう広げたマス。これより安くは入れない
				var step := unit.move_cost(board, next)
				if step < 0:
					continue
				var occupant: Unit = occupied.get(next)
				if occupant != null and occupant.is_enemy_of(unit):
					continue
				var next_cost := spent if next == exit else spent + step
				if next_cost > limit or cost.get(next, limit + 1) <= next_cost:
					continue
				cost[next] = next_cost
				parent[next] = cell
				queues[next_cost].append(next)
	return found
