extends RefCounted
## ミニマップ（minimap.gd）の計算。置き場所、盤の座標とミニマップの座標の行き来、カメラが見ている範囲。
## ノードに依存しない（テストから呼べる）。盤の座標は、盤面の x / z（BoardView.cell_center の x と z。1 マスが 1）。
##
## ミニマップは盤の向きのまま描く（カメラを回しても回さない）。上が盤の奥（行の番号の小さいほう）、右が列の番号の大きいほう。
## プレイヤー1 の始めの向き（カメラの向き 0）では、画面の上下左右とミニマップの上下左右がそろう。

## 縮図の長いほうの辺の、いちばん大きい長さ（px）。1 マスの大きさは、これに収まる整数（30 マスなら 5 px）。
const MAX_SIDE := 150
## 縮図の周りの縁（px）。枠の内側の余白。
const PADDING := 4.0
## 画面の右の端からの隙間と、上にあるもの（視点の案内）との隙間（px）。
const MARGIN := 6.0
## 視界の四角形を求めるとき、地面に届かない向き（水平より上）や、とても遠い交わりを、この距離（マス）で打ち切る。
const REACH := 200.0


## 1 マスの大きさ（px）。
static func cell_px(board_size: Vector2i) -> int:
	return maxi(1, MAX_SIDE / maxi(1, maxi(board_size.x, board_size.y)))


## ミニマップの全体（縁を含む）の大きさ（px）。
static func map_size(board_size: Vector2i) -> Vector2:
	return Vector2(board_size * cell_px(board_size)) + Vector2.ONE * PADDING * 2.0


## 画面の大きさ screen のとき、ミニマップの全体が画面に占める四角。右の端に寄せ、上の辺を top にそろえる。
static func place(screen: Vector2, board_size: Vector2i, top: float) -> Rect2:
	var size := map_size(board_size)
	return Rect2(Vector2(screen.x - MARGIN - size.x, top + MARGIN), size)


## 盤の座標 point（x / z）の、ミニマップの中の位置（ミニマップの左上からの px）。
static func to_map(point: Vector2, board_size: Vector2i) -> Vector2:
	return Vector2.ONE * PADDING + point * float(cell_px(board_size))


## ミニマップの中の位置 at（左上からの px）が指す、盤の座標（盤の中に収める）。
static func to_board(at: Vector2, board_size: Vector2i) -> Vector2:
	var point := (at - Vector2.ONE * PADDING) / float(cell_px(board_size))
	return point.clamp(Vector2.ZERO, Vector2(board_size))


## カメラ（位置 origin、向き basis、縦の画角 fov_degrees、横 / 縦の比 aspect）が見ている、地面（y = 0）の範囲。
## 画面の 4 隅を通る光線と地面の交わり（左下・右下・右上・左上の順。盤の座標 x / z）。傾いたカメラでは台形になり、
## 遠い辺（画面の上）ほど長い。地面に届かない光線は、水平に REACH まで伸ばしたところで打ち切る。
static func view_quad(origin: Vector3, basis: Basis, fov_degrees: float, aspect: float) -> PackedVector2Array:
	var half := tan(deg_to_rad(fov_degrees) / 2.0)
	var quad := PackedVector2Array()
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var direction := basis * Vector3(corner.x * half * aspect, corner.y * half, -1.0)
		quad.append(_ground_hit(origin, direction))
	return quad


## 見ている範囲 quad のうち、盤（0〜board_size）の中にある部分。盤から外れていれば空。
static func clip_to_board(quad: PackedVector2Array, board_size: Vector2i) -> PackedVector2Array:
	var board := PackedVector2Array([
		Vector2.ZERO, Vector2(board_size.x, 0.0), Vector2(board_size), Vector2(0.0, board_size.y),
	])
	var parts := Geometry2D.intersect_polygons(quad, board)
	return parts[0] if not parts.is_empty() else PackedVector2Array()


## origin から direction へ伸ばした光線が地面に当たるところ（x / z）。当たらない・遠すぎるなら、水平に REACH 先。
static func _ground_hit(origin: Vector3, direction: Vector3) -> Vector2:
	var flat := Vector2(direction.x, direction.z)
	var from := Vector2(origin.x, origin.z)
	if direction.y < 0.0 and origin.y > 0.0:
		var hit := from + flat * (origin.y / -direction.y)
		if hit.distance_to(from) <= REACH:
			return hit
	return from + (flat.normalized() if flat.length() > 0.0001 else Vector2.ZERO) * REACH
