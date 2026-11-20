class_name Deployment
extends RefCounted
## 編成（Deck）から、盤上の軍を作る（対戦の準備用）。
##
## 将を自分の本陣に置き、雇った駒を本陣の前へ並べる。
## - 「前」は、本陣から見て盤の中央の側（本陣が盤の下半分にあれば上、上半分にあれば下）
## - 本陣の 1 つ前の行から使う。1 行は本陣の列を中心に 5 マス
## - 行の中は、中央 → 左 → 右 → さらに左 → さらに右 の順（左右は盤面の座標で、列の小さいほうが左）
## - 盤の外・入れないマス・駒のいるマス・本陣（相手のものも）は飛ばす。行が埋まったら、その前の行へ送る
## - 編成の並びの順に置く
##
## 置くマスの列（cells）を渡すと、将でない駒は、編成の並びの順に、その列のマスへ置く（戦いの定義の初期位置）。
## 列のマスが盤の外・入れない・駒がいる・どちらかの本陣なら飛ばす。列が尽きたら、残りの駒はいつもの置き方（本陣の前の行）で置く。
##
## 置けるマス（zone）: 将でない駒を始めに置いてよいマス。置くマスの列（cells）が渡されていれば、そのうち置けるマス（話の deploy。
## 2 か所に分かれていてもよい）。無ければ、本陣の前の ZONE_ROWS 行（1 行は本陣の列を中心に 5 マス）。駒の数より置けるマスが少なければ、さらに前の行を足す。
## 人が決めた置き方（placement。本陣からのずれを、編成の並びの順に。決めていない駒は UNSET）を渡すと、
## 置けるマスの中で空いているずれの駒は、そこに置く。ほかの駒は、上のいつもの置き方で、残ったマスへ置く。
## 何も決めなければ（placement が空）、いつもの置き方と同じ（CPU の置き方）。
##
## 編成が対戦に出せる形か（Deck.is_valid）は、ここでは調べない。対戦を始める側が、渡す前に調べる。

## 1 行で、本陣の列から左右に使う幅。
const ROW_HALF_WIDTH := 2
## 置けるマスにする、本陣の前の行の数（置くマスの列が無いとき）。
const ZONE_ROWS := 2
const NO_CELL := Vector2i(-1, -1)
## 人が決めた置き方の「決めていない」（本陣からのずれ 0 = 本陣。将でない駒は置けないので、決めたずれと混ざらない）。
const UNSET := Vector2i.ZERO


## side の軍を盤に置き、置いた駒を返す（先頭が将、あとは編成の並びの順）。
## 本陣に将を置けなければ、何も置かずに空を返す。置くマスが見つからなかった駒と、
## 装備を持てる数を超えている駒は置かない（返す列に入らない）。
static func deploy(battle: Battle, side: Unit.Side, deck: Deck, cells: Array[Vector2i] = [], placement: Array[Vector2i] = []) -> Array[Unit]:
	var placed: Array[Unit] = []
	if side < 0 or side >= battle.board.hq_cells.size():
		return placed
	var hq := battle.board.hq_cells[side]
	# 人が決めた置き方のうち、置けるマスの中で空いているものを、先に取っておく。
	var chosen := {}  # 編成の並びの番号 -> マス
	var reserved := {}  # 取っておいたマス -> true
	if not placement.is_empty():
		var area := zone(battle, side, cells, deck.entries.size())
		for i in mini(placement.size(), deck.entries.size()):
			var cell := hq + placement[i] if placement[i] != UNSET else NO_CELL
			if cell != NO_CELL and area.has(cell) and _can_place(battle, cell) and not reserved.has(cell):
				chosen[i] = cell
				reserved[cell] = true
	var king := battle.add_unit(UnitKind.Id.KING, side, hq)
	if king == null:
		return placed
	placed.append(king)
	battle.armies[side] = deck.army
	var next_listed := 0
	for i in deck.entries.size():
		var entry := deck.entries[i]
		var cell: Vector2i = chosen.get(i, NO_CELL)
		while cell == NO_CELL and next_listed < cells.size():
			var listed := cells[next_listed]
			next_listed += 1
			if _can_place(battle, listed) and not reserved.has(listed):
				cell = listed
		if cell == NO_CELL:
			cell = _free_cell(battle, hq, reserved)
		if cell == NO_CELL:
			continue
		var unit := battle.add_unit(entry.kind, side, cell, entry.equipment)
		if unit != null:
			placed.append(unit)
	return placed


## side の将でない駒を始めに置いてよいマス（上の「置けるマス」）。count は置く駒の数（本陣の前の行を、足りるまで足す）。
## side の駒がもう置かれていても、そのマスは置けるマスに入れる（置いたあとの対戦でも、置き直す前と同じマスの列になる）。
static func zone(battle: Battle, side: Unit.Side, cells: Array[Vector2i] = [], count := 0) -> Array[Vector2i]:
	var area: Array[Vector2i] = []
	if side < 0 or side >= battle.board.hq_cells.size():
		return area
	if not cells.is_empty():
		for cell in cells:
			if _open_for(battle, side, cell) and not area.has(cell):
				area.append(cell)
		return area
	var hq := battle.board.hq_cells[side]
	var step := forward(battle.board, hq)
	var row := hq + step * (1 + int(RuleProbe.f("deploy_shift")))
	var rows := 0
	while row.y >= 0 and row.y < battle.board.size.y and (rows < ZONE_ROWS or area.size() < count):
		for offset in _row_offsets():
			var cell := row + Vector2i(offset, 0)
			if _open_for(battle, side, cell):
				area.append(cell)
		row += step
		rows += 1
	return area


## 何も無い広い盤で、編成の i 番目の駒が置かれるところ（本陣から見た位置）。count 体ぶんを、編成の並びの順に返す。
## x は本陣の列からのずれ（負が左）、y は本陣から何行前か（1 が本陣のすぐ前）。編成の画面の配置の図に使う。
## 実際の盤では、入れないマスと駒のいるマスを飛ばすので、ここからずれることがある。
static func open_field_slots(count: int) -> Array[Vector2i]:
	var slots: Array[Vector2i] = []
	var offsets := _row_offsets()
	for i in maxi(count, 0):
		slots.append(Vector2i(offsets[i % offsets.size()], 1 + i / offsets.size()))
	return slots


## 一方の陣営が決めた置き方（本陣からのずれの列。UNSET はそのまま）を、もう一方の陣営の置き方に返す。
## 盤の形に合わせて返す（facing_is_point_symmetric）: 点対称の盤なら上下と左右を、そうでなければ上下だけを返す。
## どちらでも、置いた意図（盤の端に寄せた、真ん中に寄せた、など）が、相手の側の地形に対して保たれる。
static func facing_placement(board: Board, placement: Array[Vector2i]) -> Array[Vector2i]:
	var point := facing_is_point_symmetric(board)
	var facing: Array[Vector2i] = []
	for offset in placement:
		if offset == UNSET:
			facing.append(offset)
		else:
			facing.append(-offset if point else Vector2i(offset.x, -offset.y))
	return facing


## 2 つの本陣を入れ替える形が、点対称（盤の中心で 180 度回す）か。偽なら上下の線対称（上下だけを返す）。
## まず本陣: その形で移して本陣どうしが入れ替わる形だけを候補にする（対角の本陣は点対称だけ）。
## どちらも候補なら（本陣が上下の中央）、中ボス・結晶泉・回復の泉・ポータルの重なる数、次に地形と環境オブジェクトの重なる数が多いほう。
## 同じなら上下の線対称（生成のマップは、結晶泉が 1 行ずれるなど、ぴったりの対称でないことがある）。
static func facing_is_point_symmetric(board: Board) -> bool:
	var corner := board.size - Vector2i.ONE
	var point := func(cell: Vector2i) -> Vector2i: return corner - cell
	var line := func(cell: Vector2i) -> Vector2i: return Vector2i(cell.x, corner.y - cell.y)
	var point_fits := _overlap([board.hq_cells], point) == board.hq_cells.size()
	var line_fits := _overlap([board.hq_cells], line) == board.hq_cells.size()
	if point_fits != line_fits:
		return point_fits
	var fixed := [board.mid_boss_cells, board.font_cells, board.spring_cells, board.portal_exits.keys()]
	var by_fixed := _overlap(fixed, point) - _overlap(fixed, line)
	if by_fixed != 0:
		return by_fixed > 0
	return _matching_cells(board, point) > _matching_cells(board, line)


## 列 groups のそれぞれで、移した先も同じ列にあるマスの数（の合計）。
static func _overlap(groups: Array, moved: Callable) -> int:
	var count := 0
	for cells: Array in groups:
		for cell: Vector2i in cells:
			if cells.has(moved.call(cell)):
				count += 1
	return count


## 盤の全部のマスのうち、移した先と地形・環境オブジェクトが同じマスの数。
static func _matching_cells(board: Board, moved: Callable) -> int:
	var count := 0
	for y in board.size.y:
		for x in board.size.x:
			var cell := Vector2i(x, y)
			var other: Vector2i = moved.call(cell)
			if board.terrain_at(cell) == board.terrain_at(other) and board.object_at(cell) == board.object_at(other):
				count += 1
	return count


## 本陣から見て前の向き（行の向き）。
static func forward(board: Board, hq: Vector2i) -> Vector2i:
	return Vector2i.DOWN if hq.y * 2 < board.size.y - 1 else Vector2i.UP


## 次に駒を置くマス。無ければ NO_CELL。
static func _free_cell(battle: Battle, hq: Vector2i, reserved := {}) -> Vector2i:
	var step := forward(battle.board, hq)
	var row := hq + step * (1 + int(RuleProbe.f("deploy_shift")))
	while row.y >= 0 and row.y < battle.board.size.y:
		for offset in _row_offsets():
			var cell := row + Vector2i(offset, 0)
			if _can_place(battle, cell) and not reserved.has(cell):
				return cell
		row += step
	return NO_CELL


## 将でない駒を置けるマスか（入れて、駒がいなくて、どちらの本陣でもない）。
## 本陣は将の場所なので、相手の将がまだ置かれていなくても使わない。
static func _can_place(battle: Battle, cell: Vector2i) -> bool:
	return battle.board.is_walkable(cell) and battle.unit_at(cell) == null and battle.board.hq_owner(cell) == -1


## side の駒を置けるマスか（入れて、どちらの本陣でもなく、ほかの陣営の駒がいない。side の駒がいるのはよい）。
static func _open_for(battle: Battle, side: Unit.Side, cell: Vector2i) -> bool:
	if not battle.board.is_walkable(cell) or battle.board.hq_owner(cell) != -1:
		return false
	var unit := battle.unit_at(cell)
	return unit == null or unit.side == side


## 行の中で試す列のずれ。0, -1, +1, -2, +2 …
static func _row_offsets() -> Array[int]:
	var offsets: Array[int] = [0]
	for distance in range(1, ROW_HALF_WIDTH + 1):
		offsets.append(-distance)
		offsets.append(distance)
	return offsets
