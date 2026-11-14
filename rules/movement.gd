class_name Movement
extends RefCounted
## 駒の移動範囲と、そこまでの道。
##
## - 入るのに使う移動力は地形で決まる（平地・結晶泉 1、森 2）。合計が移動力以下のマスへ行ける
## - 障害物、起爆樽、敵の駒のいるマスは通れない
## - 味方の駒のいるマスは通り抜けられるが、そこで止まることはできない
## - 敵の支配領域（ZOC）のマスには入れるが、そこで止まる（その先へは進めない）。
##   ただし、いま立っているマスが敵の ZOC でも、最初の 1 歩は踏み出せる
## - 巡航（攻撃を諦める移動）は移動力が 2 倍
## - ポータルのマスからは、対になるポータルへ移動力を使わずに移れる（行き先に駒がいなければ）。
##   道の中でポータルの対が続けて並んでいたら、そこは転移（Battle.portal_exit で見分ける）


## 移動に使える移動力。
static func budget(unit: Unit, cruise: bool) -> int:
	return unit.move_range() * (2 if cruise else 1)


## 止まれるマスと、そこまでに使う移動力の最小値。Vector2i -> int。いまのマス（0）も含む。
static func reachable(battle: Battle, unit: Unit, cruise := false) -> Dictionary:
	var cost: Dictionary = _search(battle, unit, budget(unit, cruise))["cost"]
	var result := {}
	for cell: Vector2i in cost:
		if _can_stop(battle, unit, cell):
			result[cell] = cost[cell]
	return result


## いまのマスから to までの道（両端を含む）。行けなければ空。
## 同じ移動力で行ける道がいくつかあるときも、毎回同じ道を返す。
static func path_to(battle: Battle, unit: Unit, to: Vector2i, cruise := false) -> Array[Vector2i]:
	var result := _search(battle, unit, budget(unit, cruise))
	var path: Array[Vector2i] = []
	if not result["cost"].has(to) or not _can_stop(battle, unit, to):
		return path
	var parent: Dictionary = result["parent"]
	var cell := to
	path.append(cell)
	while cell != unit.cell:
		cell = parent[cell]
		path.append(cell)
	path.reverse()
	return path


## そのマスで止まれるか（自分のいるマスか、誰もいないマス）。
static func _can_stop(battle: Battle, unit: Unit, cell: Vector2i) -> bool:
	var occupant := battle.unit_at(cell)
	return occupant == null or occupant == unit


## 通れるマスを、移動力の少ない順に広げる（ダイクストラ法）。味方のいるマスも通る。
## 同じ移動力のマスは見つけた順に広げるので、結果は毎回同じになる。
static func _search(battle: Battle, unit: Unit, limit: int) -> Dictionary:
	var cost := {unit.cell: 0}
	var parent := {}
	var done := {}
	# [移動力, 見つけた順, マス] を移動力・見つけた順の小さい順に取り出す。
	var frontier: Array = [[0, 0, unit.cell]]
	var order := 1
	while not frontier.is_empty():
		var best := 0
		for i in range(1, frontier.size()):
			if frontier[i][0] < frontier[best][0] or (
				frontier[i][0] == frontier[best][0] and frontier[i][1] < frontier[best][1]
			):
				best = i
		var entry: Array = frontier.pop_at(best)
		var cell: Vector2i = entry[2]
		if done.has(cell):
			continue
		done[cell] = true
		# 敵の ZOC に入ったマスからは先へ進めない（出発したマスだけは別）。
		if cell != unit.cell and battle.is_in_enemy_zoc(cell, unit.side):
			continue
		# 行き先。ポータルの転移（移動力 0）を先に、そのあと上下左右。
		var steps: Array[Vector2i] = []
		var exit := battle.portal_exit(cell)
		if exit != Board.NO_CELL:
			steps.append(exit)
		for direction in Board.DIRECTIONS:
			steps.append(cell + direction)
		for next in steps:
			if not battle.board.is_walkable(next):
				continue
			var occupant := battle.unit_at(next)
			if occupant != null and occupant.is_enemy_of(unit):
				continue
			var next_cost: int = cost[cell] + (0 if next == exit else battle.board.move_cost(next))
			if next_cost > limit or (cost.has(next) and cost[next] <= next_cost):
				continue
			cost[next] = next_cost
			parent[next] = cell
			frontier.append([next_cost, order, next])
			order += 1
	return {"cost": cost, "parent": parent}
