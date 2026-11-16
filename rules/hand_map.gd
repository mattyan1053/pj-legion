class_name HandMap
extends RefCounted
## 手で作ったマップ（docs/hand-map.md）。文字の格子（1 文字 1 マス、1 行が盤の 1 行）から盤面（Board）を作る。
##
## マップは盤の形だけを持つ（地形、本陣、結晶泉、中ボス、置く物）。初期位置と部隊は戦いの定義（Scenario）が持つ。
## 同じマップを、初期位置を変えて使い回せるようにするため。

## 文字の格子が盤にできない理由（problems() の並び）。
enum Problem {
	EMPTY,  ## 行が無い、または空の行がある
	RAGGED,  ## 行の長さがそろっていない
	UNKNOWN_CHAR,  ## 決まっていない文字がある
	HQ_COUNT,  ## 本陣（1 と 2）が 1 つずつでない
	MID_BOSS_COUNT,  ## 中ボスが 0 か 2 でない
	PORTAL_PAIR,  ## ポータルの文字が、ちょうど 2 マスずつでない
	HQ_NOT_CONNECTED,  ## 本陣どうしが歩いてつながっていない
	MID_BOSS_UNREACHABLE,  ## 本陣から歩いて行けない中ボスがいる
}

const PLAIN := "."
const OBSTACLE := "#"
const FOREST := "F"
const FONT := "*"
const HQ_PLAYER1 := "1"
const HQ_PLAYER2 := "2"
const MID_BOSS := "M"
const BARREL := "B"
const SPRING := "S"
## 中ボスは、関わりのある聖遺物が番号で決まる（Relics.OF_BOSS）ので、0 か 2 体だけ（docs/neutral-mid-boss.md）。
const MID_BOSS_COUNTS: Array[int] = [0, 2]

var rows: PackedStringArray
var size := Vector2i.ZERO


## rows（上の行から）のマップ。盤にできるかは problems() で調べる。
func _init(map_rows: PackedStringArray) -> void:
	rows = map_rows
	if not rows.is_empty():
		size = Vector2i(rows[0].length(), rows.size())


## 盤にできない理由の一覧。空なら make_board() が盤を返す。並びは Problem の順で、同じ理由は 1 回だけ。
## 形の理由（EMPTY〜PORTAL_PAIR）があれば、つながりは調べない。
func problems() -> Array[Problem]:
	var found: Array[Problem] = []
	if rows.is_empty() or Array(rows).any(func(row: String) -> bool: return row.is_empty()):
		return [Problem.EMPTY]
	if Array(rows).any(func(row: String) -> bool: return row.length() != size.x):
		return [Problem.RAGGED]
	var counts := {}
	for row in rows:
		for c in row:
			counts[c] = counts.get(c, 0) + 1
	for c: String in counts:
		if not _is_known(c):
			found.append(Problem.UNKNOWN_CHAR)
			break
	if counts.get(HQ_PLAYER1, 0) != 1 or counts.get(HQ_PLAYER2, 0) != 1:
		found.append(Problem.HQ_COUNT)
	if not MID_BOSS_COUNTS.has(counts.get(MID_BOSS, 0)):
		found.append(Problem.MID_BOSS_COUNT)
	for c: String in counts:
		if _is_portal(c) and counts[c] != 2:
			found.append(Problem.PORTAL_PAIR)
			break
	if not found.is_empty():
		return found
	var board := _build()
	if not board.is_reachable(board.hq_cells[0], board.hq_cells[1]):
		found.append(Problem.HQ_NOT_CONNECTED)
	for cell in board.mid_boss_cells:
		if not board.is_reachable(board.hq_cells[0], cell):
			found.append(Problem.MID_BOSS_UNREACHABLE)
			break
	return found


func is_valid() -> bool:
	return problems().is_empty()


## マップの盤面。盤にできなければ null。毎回、新しい盤を作る。
func make_board() -> Board:
	return _build() if is_valid() else null


func _build() -> Board:
	var board := Board.new(size)
	board.hq_cells = [Board.NO_CELL, Board.NO_CELL]
	var portals := {}
	for y in size.y:
		for x in size.x:
			var cell := Vector2i(x, y)
			var c := rows[y][x]
			match c:
				OBSTACLE:
					board.set_terrain(cell, Terrain.Type.OBSTACLE)
				FOREST:
					board.set_terrain(cell, Terrain.Type.FOREST)
				FONT:
					board.set_terrain(cell, Terrain.Type.FONT)
					board.font_cells.append(cell)
				HQ_PLAYER1:
					board.hq_cells[Unit.Side.PLAYER1] = cell
				HQ_PLAYER2:
					board.hq_cells[Unit.Side.PLAYER2] = cell
				MID_BOSS:
					board.mid_boss_cells.append(cell)
				BARREL:
					board.add_barrel(cell)
				SPRING:
					board.add_spring(cell)
				_:
					if _is_portal(c):
						if portals.has(c):
							board.add_portal_pair(portals[c], cell)
						else:
							portals[c] = cell
	return board


static func _is_portal(c: String) -> bool:
	return c >= "a" and c <= "z"


static func _is_known(c: String) -> bool:
	return _is_portal(c) or [
		PLAIN, OBSTACLE, FOREST, FONT, HQ_PLAYER1, HQ_PLAYER2, MID_BOSS, BARREL, SPRING,
	].has(c)
