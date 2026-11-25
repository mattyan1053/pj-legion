extends Node3D
## 軍略の線（docs/troop-traits.md の「画面」）: 誓いの 2 人、隊列で隣り合う同じ兵種、補給線で隣り合う回復役の間に、盤の上で線を引く。
## 線は軍略の軍の色に暗い縁を付け（明るい地面でも範囲の塗りの上でも切れて見える）、真ん中に結び目を置く。
## 隣どうしの線は足元の円盤にほとんど隠れるので、円盤の間（マスの境）に来る結び目が目印になる。
## 結び目の形で見分ける: 隊列と誓いは菱形、補給線は十字（回復の印）。
## 線の端は駒の見た目の位置を毎フレーム追う（再生で駒が歩いても、線がついて行く）。
## 線の組は、盤の状態が変わったあと（対戦の画面の _refresh）に set_links で置き直す。

## 結び目の形。
enum Knot { DIAMOND, CROSS }

## 線の太さと高さ（盤の上の m）、暗い縁の幅。
const WIDTH := 0.1
const LIFT := 0.12
const RIM := 0.035
## 結び目の大きさ（菱形の辺、十字の腕の長さと太さ）。
const KNOT_SIDE := 0.2
const CROSS_ARM := 0.3
const CROSS_WIDTH := 0.1
const COLOR_RIM := Color(0.06, 0.05, 0.08)

var _links: Array = []  # [見た目 a, 見た目 b, 線の Node3D, 線の胴（長さに合わせて伸ばす）, 結び目の形]


## links は [見た目 a（Node3D）, 見た目 b, 色, 結び目の形（Knot。省けば菱形）] の並び。前の線は消える。
func set_links(links: Array) -> void:
	for link: Array in _links:
		(link[2] as Node).queue_free()
	_links = []
	for link: Array in links:
		var color: Color = link[2]
		var knot: Knot = link[3] if link.size() > 3 else Knot.DIAMOND
		var line := Node3D.new()
		var body := Node3D.new()
		line.add_child(body)
		_box(body, Vector3(WIDTH + RIM * 2.0, 0.02, 1.0), COLOR_RIM, 1)
		_box(body, Vector3(WIDTH, 0.02, 1.0), color, 2)
		if knot == Knot.CROSS:
			# 十字は、線に対して 45 度に置く（線と重なって棒に見えないように）。
			for turn: float in [PI / 4.0, -PI / 4.0]:
				_box(line, Vector3(CROSS_WIDTH + RIM * 2.0, 0.02, CROSS_ARM + RIM * 2.0), COLOR_RIM, 3).rotation.y = turn
			for turn: float in [PI / 4.0, -PI / 4.0]:
				_box(line, Vector3(CROSS_WIDTH, 0.02, CROSS_ARM), color.lightened(0.3), 4).rotation.y = turn
		else:
			_box(line, Vector3(KNOT_SIDE + RIM * 2.0, 0.02, KNOT_SIDE + RIM * 2.0), COLOR_RIM, 3).rotation.y = PI / 4.0
			_box(line, Vector3(KNOT_SIDE, 0.02, KNOT_SIDE), color.lightened(0.3), 4).rotation.y = PI / 4.0
		add_child(line)
		_links.append([link[0], link[1], line, body, knot])
	_place()


## いま引いている線の数（検査用）。
func link_count() -> int:
	return _links.size()


## いま引いている線の結び目の形（検査用）。
func knots() -> Array:
	return _links.map(func(link: Array) -> Knot: return link[4])


func _box(parent: Node3D, size: Vector3, color: Color, priority: int) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true  # マスの塗り（範囲の色）と足元の円盤より上に見せる
	material.render_priority = priority
	var box := MeshInstance3D.new()
	box.mesh = mesh
	box.material_override = material
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
