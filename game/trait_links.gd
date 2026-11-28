extends Node3D
## 軍略の、盤の上の控えめな印（docs/troop-traits.md の「対戦の画面」）。どちらも、駒を選んでいる間だけ出す。
## - 線: 誓いの 2 人を結ぶ（離れた相手が誰かは、線でないと分からない）。細く、暗く、動かない。駒の後ろに隠れる（駒の上に被せない）。
##   真ん中の小さな菱形が結び目（隣どうしの線は足元の円盤に隠れるので、マスの境に来る結び目が目印）。
## - マスの印: 選んだ兵が、そこへ動けば軍略が効くマス（隊列・守護の盾、補給線の十字。trait_pip.gd の印を薄くしたもの）。
## 隣り合うことで効く軍略（隊列・補給線・守護）は、兵どうしを線で結ばない（効いている兵の足元の印で見せる。unit_view.gd の set_trait_pip）。
## 線の端は駒の見た目の位置を毎フレーム追う。線とマスの印は、盤の状態が変わったあと（対戦の画面の _refresh）に置き直す。

const TraitPip := preload("res://game/trait_pip.gd")
const BoardView := preload("res://game/board_view.gd")

## 線の太さと高さ（盤の上の m）、暗い縁の幅、結び目の菱形の辺。
const WIDTH := 0.045
const LIFT := 0.09
const RIM := 0.02
const KNOT_SIDE := 0.13
const COLOR_RIM := Color(0.06, 0.05, 0.08)
## マスの印の高さと濃さ。
const SPOT_LIFT := 0.16
const SPOT_ALPHA := 0.6

var _links: Array = []  # [見た目 a, 見た目 b, 線の Node3D, 線の胴（長さに合わせて伸ばす）]
var _spots: Array[Sprite3D] = []
var _spot_cells: Array[Vector2i] = []


## links は [見た目 a（Node3D）, 見た目 b, 色] の並び。前の線は消える。
func set_links(links: Array) -> void:
	for link: Array in _links:
		(link[2] as Node).queue_free()
	_links = []
	for link: Array in links:
		var color: Color = link[2]
		var line := Node3D.new()
		var body := Node3D.new()
		line.add_child(body)
		# 縁 → 線 → 結び目の順に、少しずつ高くする（同じ高さに重ねると、ちらつく）。
		_box(body, Vector3(WIDTH + RIM * 2.0, 0.01, 1.0), COLOR_RIM, 0.0)
		_box(body, Vector3(WIDTH, 0.01, 1.0), color.darkened(0.1), 0.006)
		_box(line, Vector3(KNOT_SIDE + RIM * 2.0, 0.01, KNOT_SIDE + RIM * 2.0), COLOR_RIM, 0.012).rotation.y = PI / 4.0
		_box(line, Vector3(KNOT_SIDE, 0.01, KNOT_SIDE), color.lightened(0.2), 0.018).rotation.y = PI / 4.0
		add_child(line)
		_links.append([link[0], link[1], line, body])
	_place()


## いま引いている線の数（検査用）。
func link_count() -> int:
	return _links.size()


## 動けば軍略が効くマスに、印を置く（前の印は消える）。kind は TraitPip.Kind、color は軍略の軍の色。
func set_spots(cells: Array[Vector2i], kind: int, color: Color) -> void:
	_spot_cells = cells
	while _spots.size() < cells.size():
		var spot := TraitPip.make()
		spot.modulate.a = SPOT_ALPHA
		add_child(spot)
		_spots.append(spot)
	for index in _spots.size():
		_spots[index].visible = index < cells.size()
		if index < cells.size():
			_spots[index].texture = TraitPip.texture(kind, color)
			_spots[index].position = BoardView.cell_center(cells[index]) + Vector3(0.0, SPOT_LIFT, 0.0)


## 線とマスの印を、どちらも消す（行動の再生が始まるとき。選択が外れるので）。
func clear() -> void:
	set_links([])
	set_spots([] as Array[Vector2i], TraitPip.Kind.NONE, Color.WHITE)


## いま印を置いているマス（検査用）。
func spot_cells() -> Array[Vector2i]:
	return _spot_cells


func _box(parent: Node3D, size: Vector3, color: Color, lift: float) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var box := MeshInstance3D.new()
	box.mesh = mesh
	box.material_override = material
	box.position.y = lift
	box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(box)
	return box


func _process(_delta: float) -> void:
	_place()


func _place() -> void:
	for link: Array in _links:
		var line := link[2] as Node3D
		if not is_instance_valid(link[0]) or not is_instance_valid(link[1]):
			line.visible = false  # 倒れた駒の見た目は消える（次の置き直しまで、線も消しておく）
			continue
		var a := link[0] as Node3D
		var b := link[1] as Node3D
		if not a.is_inside_tree() or not b.is_inside_tree():
			line.visible = false
			continue
		var from := Vector3(a.position.x, LIFT, a.position.z)
		var to := Vector3(b.position.x, LIFT, b.position.z)
		var length := from.distance_to(to)
		line.visible = length > 0.01
		if not line.visible:
			continue
		line.position = (from + to) / 2.0
		line.basis = Basis.looking_at(to - from, Vector3.UP)
		(link[3] as Node3D).scale = Vector3(1.0, 1.0, length)
