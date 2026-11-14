extends RefCounted
## テスト用に、文字で書いた地図から盤面を作る。
##
##   . 平地   # 障害物   F 森   * 結晶泉
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
	for y in rows.size():
		assert(rows[y].length() == result.size.x, "行の長さがそろっていない")
		for x in rows[y].length():
			result.set_terrain(Vector2i(x, y), CHARS[rows[y][x]])
	return result


static func battle(rows: Array[String]) -> Battle:
	return Battle.new(board(rows))
