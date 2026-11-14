extends RefCounted
## テスト用に、文字で書いた地図から盤面を作る。
##
##   . 平地   # 障害物   F 森   * 結晶泉
##   B 起爆樽   S 回復の泉   1〜9 ポータル（同じ数字の 2 マスが対になる）。どれも地形は平地
##
##   var board := Maps.board([
##       "..#",
##       ".F.",
##   ])

const CHARS := {
	".": Terrain.Type.NORMAL,
	"#": Terrain.Type.OBSTACLE,
	"F": Terrain.Type.FOREST,
	"*": Terrain.Type.FONT,
}


static func board(rows: Array[String]) -> Board:
	var result := Board.new(Vector2i(rows[0].length(), rows.size()))
	var portals := {}  # 数字 -> 先に見つけたほうのマス
	for y in rows.size():
		assert(rows[y].length() == result.size.x, "行の長さがそろっていない")
		for x in rows[y].length():
			var cell := Vector2i(x, y)
			var c := rows[y][x]
			if CHARS.has(c):
				result.set_terrain(cell, CHARS[c])
			elif c == "B":
				result.add_barrel(cell)
			elif c == "S":
				result.add_spring(cell)
			elif portals.has(c):
				result.add_portal_pair(portals[c], cell)
			else:
				assert(c.is_valid_int(), "地図に使えない文字: %s" % c)
				portals[c] = cell
	return result


static func battle(rows: Array[String]) -> Battle:
	return Battle.new(board(rows))
