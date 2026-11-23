extends Node3D
## 部隊の特徴の線（docs/troop-traits.md の「画面」）: 誓いの 2 人、隊列で隣り合う同じ兵種、補給線で隣り合う回復役の間に、盤の上で細い線を引く。
## 線の端は駒の見た目の位置を毎フレーム追う（再生で駒が歩いても、線がついて行く）。
## 線の組は、盤の状態が変わったあと（対戦の画面の _refresh）に set_links で置き直す。

## 線の太さと高さ（盤の上の m）。
const WIDTH := 0.12
const LIFT := 0.12
## 薄く引く線（補給線）の濃さ。
const FAR_ALPHA := 0.35

var _links: Array = []  # [見た目 a, 見た目 b, 線の MeshInstance3D]


## links は [見た目 a（Node3D）, 見た目 b, 色] の並び。前の線は消える。
func set_links(links: Array) -> void:
	for link: Array in _links:
		(link[2] as Node).queue_free()
	_links = []
	for link: Array in links:
		var line := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(WIDTH, 0.02, 1.0)
		line.mesh = mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = link[2]
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.no_depth_test = true  # マスの塗り（範囲の色）より上に見せる。駒の足元の輪と同じ高さ
		material.render_priority = 2
		line.material_override = material
		line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(line)
		_links.append([link[0], link[1], line])
	_place()


## いま引いている線の数（検査用）。
func link_count() -> int:
	return _links.size()


func _process(_delta: float) -> void:
	_place()


func _place() -> void:
	for link: Array in _links:
		var line := link[2] as MeshInstance3D
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
		line.basis = Basis.looking_at(to - from, Vector3.UP).scaled(Vector3(1.0, 1.0, length))
