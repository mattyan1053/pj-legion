extends RefCounted
## 駒のそばに出すメニューの置き場所を決める。画面の座標だけの計算で、ノードにもルールにも依存しない。
##
## 駒の周りの候補（右・左・下・上と、その上下・左右へずらしたもの、斜め。近くと 1 つ離れたところ）を、画面に収まるようにずらしてから比べ、
## 隠してしまうもの（攻撃の相手、届くマス、ほかの駒、画面の帯）の重みがいちばん小さいところを選ぶ。
## 駒そのものには重ねない。カメラが動いても落ち着いて付いてくるよう、前に選んだ側を少しひいきする。

## 駒とメニューの間の隙間（px）。
const GAP := 10.0
## 候補の向き（駒から見て）。前のものほど、同じ重みなら選ばれやすい。
## 1 か -1 は、駒の四角の外のその側。0 は中央にそろえる。0.5 と -0.5 は、駒の四角の辺にそろえて、その側へ伸ばす
## （右隣で下へ伸びる、など。真横がふさがっていても、半分ずらせば空いていることが多い）。
const DIRECTIONS: Array[Vector2] = [
	Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1),
	Vector2(1, 0.5), Vector2(1, -0.5), Vector2(-1, 0.5), Vector2(-1, -0.5),
	Vector2(0.5, 1), Vector2(-0.5, 1), Vector2(0.5, -1), Vector2(-0.5, -1),
	Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1),
]
## 向きの並びが 1 つ後ろになるごとの重み（同点のときに、右、左、下、上…の順に選ぶため）。
const DIRECTION_COST := 0.05
## 1 つ離れた候補に足す重み（近くに置けるなら近くに置く）。
const FAR_COST := 0.6
## 画面に収めるためにずらした量（駒の大きさを 1 として）に掛ける重み。
const SHIFT_COST := 0.5
## 前に選んだ候補から引く重み（これより得にならなければ、動かさない）。
const STAY_BONUS := 1.5
## 駒に重なる候補に足す重み（ほかに置けるところがあれば選ばない）。
const ANCHOR_COST := 1000.0
## 重ねてはいけない四角（keep_clear）に重なる候補に足す重み。駒に重なるより重い（置けるところが無いときだけ選ぶ）。
const KEEP_CLEAR_COST := 1000000.0
## 重ねてはいけない四角の周りに足す候補の、もとの候補より後ろに回すための重み（駒の周りに置けないときだけ選ぶ）。
const AROUND_CLEAR_COST := 2.0

## 選んだ候補の番号（次に place() を呼ぶときに previous として渡す）。まだ選んでいなければ -1。
var choice := -1
## 選んだ置き場所（メニューの左上）。
var position := Vector2.ZERO


## anchor は駒が画面に占める四角、size はメニューの大きさ、area はメニューを置いてよい範囲（画面から帯を除いたところ）。
## obstacles は、隠したくないものの四角と重み（[Rect2, float] の列）。置き場所（左上）を返し、choice と position に残す。
## keep_clear は、重ねてはいけない四角（Rect2 の列。予測のパネルから見たメニュー）。駒の周りの候補がどれも重なるときは、
## その四角の上下左右に接する候補からも選ぶ（area に入る幅か高さが残っていれば、必ず重ならない）。
func place(anchor: Rect2, size: Vector2, area: Rect2, obstacles: Array, keep_clear: Array = []) -> Vector2:
	var best := -1
	var best_cost := INF
	var best_at := Vector2.ZERO
	var unit := maxf(anchor.size.x, 1.0)
	var wanted_list: Array[Vector2] = []
	var base_costs: Array[float] = []
	for index in DIRECTIONS.size() * 2:
		var far := index >= DIRECTIONS.size()
		var direction := DIRECTIONS[index % DIRECTIONS.size()]
		wanted_list.append(_candidate(anchor, size, direction, GAP + (unit if far else 0.0)))
		base_costs.append((index % DIRECTIONS.size()) * DIRECTION_COST + (FAR_COST if far else 0.0))
	var last_cost := DIRECTIONS.size() * DIRECTION_COST + FAR_COST
	for clear: Rect2 in keep_clear:
		for wanted in _around(clear, anchor, size):
			wanted_list.append(wanted)
			var center := Rect2(wanted, size).get_center()
			base_costs.append(last_cost + AROUND_CLEAR_COST + center.distance_to(anchor.get_center()) / unit * SHIFT_COST)
	for index in wanted_list.size():
		var wanted := wanted_list[index]
		var at := _clamp_into(wanted, size, area)
		var rect := Rect2(at, size)
		var cost := base_costs[index]
		cost += wanted.distance_to(at) / unit * SHIFT_COST
		if rect.intersects(anchor):
			cost += ANCHOR_COST
		for clear: Rect2 in keep_clear:
			if rect.intersects(clear):
				cost += KEEP_CLEAR_COST
		for obstacle: Array in obstacles:
			if rect.intersects(obstacle[0]):
				cost += float(obstacle[1])
		if index == choice:
			cost -= STAY_BONUS
		if cost < best_cost:
			best = index
			best_cost = cost
			best_at = at
	choice = best
	position = best_at
	return best_at


## 前に選んだ側を忘れる（別の駒を選んだとき）。
func reset() -> void:
	choice = -1


## 駒の四角の外、direction の側に、gap だけ離して置いたときの左上。横や縦だけの向きでは、駒の中央にそろえる。
static func _candidate(anchor: Rect2, size: Vector2, direction: Vector2, gap: float) -> Vector2:
	var center := anchor.get_center()
	var at := center - size / 2.0
	if direction.x >= 1.0:
		at.x = anchor.end.x + gap
	elif direction.x <= -1.0:
		at.x = anchor.position.x - gap - size.x
	elif direction.x > 0.0:
		at.x = anchor.position.x
	elif direction.x < 0.0:
		at.x = anchor.end.x - size.x
	if direction.y >= 1.0:
		at.y = anchor.end.y + gap
	elif direction.y <= -1.0:
		at.y = anchor.position.y - gap - size.y
	elif direction.y > 0.0:
		at.y = anchor.position.y
	elif direction.y < 0.0:
		at.y = anchor.end.y - size.y
	return at


## 重ねてはいけない四角（clear）の右・左・下・上に、GAP だけ離して接する候補（左上）。
## 横に接するときは、駒の高さ・四角の上の辺・下の辺にそろえたもの。縦に接するときは、駒の横の位置・四角の左の辺・右の辺にそろえたもの。
static func _around(clear: Rect2, anchor: Rect2, size: Vector2) -> Array[Vector2]:
	var center := anchor.get_center()
	var result: Array[Vector2] = []
	for x: float in [clear.end.x + GAP, clear.position.x - GAP - size.x]:
		for y: float in [center.y - size.y / 2.0, clear.position.y, clear.end.y - size.y]:
			result.append(Vector2(x, y))
	for y: float in [clear.end.y + GAP, clear.position.y - GAP - size.y]:
		for x: float in [center.x - size.x / 2.0, clear.position.x, clear.end.x - size.x]:
			result.append(Vector2(x, y))
	return result


## メニューの全体が area に入るよう、左上をずらす（area より大きければ、左上をそろえる）。
static func _clamp_into(at: Vector2, size: Vector2, area: Rect2) -> Vector2:
	return Vector2(
		clampf(at.x, area.position.x, maxf(area.position.x, area.end.x - size.x)),
		clampf(at.y, area.position.y, maxf(area.position.y, area.end.y - size.y)),
	)
