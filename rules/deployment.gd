class_name Deployment
extends RefCounted
## 編成（Deck）から、盤上の軍を作る（対戦の準備用）。
##
## 将を自分の本陣に置き、雇った駒を本陣の前へ並べる。
## - 「前」は、本陣から見て盤の中央の側（本陣が盤の下半分にあれば上、上半分にあれば下）
## - 本陣の 1 つ前の行から使う。1 行は本陣の列を中心に 5 マス
## - 行の中は、中央 → 左 → 右 → さらに左 → さらに右 の順（左右は盤面の座標で、列の小さいほうが左）
## - 盤の外・入れないマス・駒のいるマスは飛ばす。行が埋まったら、その前の行へ送る
## - 編成の並びの順に置く
##
## 置くマスの列（cells）を渡すと、将でない駒は、編成の並びの順に、その列のマスへ置く（戦いの定義の初期位置）。
## 列のマスが盤の外・入れない・駒がいるなら飛ばす。列が尽きたら、残りの駒はいつもの置き方（本陣の前の行）で置く。
##
## 編成が対戦に出せる形か（Deck.is_valid）は、ここでは調べない。対戦を始める側が、渡す前に調べる。

## 1 行で、本陣の列から左右に使う幅。
const ROW_HALF_WIDTH := 2
const NO_CELL := Vector2i(-1, -1)


## side の軍を盤に置き、置いた駒を返す（先頭が将、あとは編成の並びの順）。
## 本陣に将を置けなければ、何も置かずに空を返す。置くマスが見つからなかった駒と、
## 装備を持てる数を超えている駒は置かない（返す列に入らない）。
static func deploy(battle: Battle, side: Unit.Side, deck: Deck, cells: Array[Vector2i] = []) -> Array[Unit]:
	var placed: Array[Unit] = []
	if side < 0 or side >= battle.board.hq_cells.size():
		return placed
	var hq := battle.board.hq_cells[side]
	var king := battle.add_unit(UnitKind.Id.KING, side, hq)
	if king == null:
		return placed
	placed.append(king)
	battle.armies[side] = deck.army
	var next_listed := 0
	for entry in deck.entries:
		var cell := NO_CELL
		while cell == NO_CELL and next_listed < cells.size():
			var listed := cells[next_listed]
			next_listed += 1
			if battle.board.is_walkable(listed) and battle.unit_at(listed) == null:
				cell = listed
		if cell == NO_CELL:
			cell = _free_cell(battle, hq)
		if cell == NO_CELL:
			continue
		var unit := battle.add_unit(entry.kind, side, cell, entry.equipment)
		if unit != null:
			placed.append(unit)
	return placed


## 何も無い広い盤で、編成の i 番目の駒が置かれるところ（本陣から見た位置）。count 体ぶんを、編成の並びの順に返す。
## x は本陣の列からのずれ（負が左）、y は本陣から何行前か（1 が本陣のすぐ前）。編成の画面の配置の図に使う。
## 実際の盤では、入れないマスと駒のいるマスを飛ばすので、ここからずれることがある。
static func open_field_slots(count: int) -> Array[Vector2i]:
	var slots: Array[Vector2i] = []
	var offsets := _row_offsets()
	for i in maxi(count, 0):
		slots.append(Vector2i(offsets[i % offsets.size()], 1 + i / offsets.size()))
	return slots


## 本陣から見て前の向き（行の向き）。
static func forward(board: Board, hq: Vector2i) -> Vector2i:
	return Vector2i.DOWN if hq.y * 2 < board.size.y - 1 else Vector2i.UP


## 次に駒を置くマス。無ければ NO_CELL。
static func _free_cell(battle: Battle, hq: Vector2i) -> Vector2i:
	var step := forward(battle.board, hq)
	var row := hq + step
	while row.y >= 0 and row.y < battle.board.size.y:
		for offset in _row_offsets():
			var cell := row + Vector2i(offset, 0)
			if battle.board.is_walkable(cell) and battle.unit_at(cell) == null:
				return cell
		row += step
	return NO_CELL


## 行の中で試す列のずれ。0, -1, +1, -2, +2 …
static func _row_offsets() -> Array[int]:
	var offsets: Array[int] = [0]
	for distance in range(1, ROW_HALF_WIDTH + 1):
		offsets.append(-distance)
		offsets.append(distance)
	return offsets
