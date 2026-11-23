extends "res://game/board_view/board_objects.gd"
## 盤面のマスの塗りと目印: 選べるマス、脅威範囲の斜線、範囲を表示したまま、カーソル、印、カメラの前の置物を薄くする。


## マスを色で塗る（マス -> Color）。前に塗ったものは消える。空を渡すと全部消える。
## raised に入っているマス（マス -> 何か）は、駒の足元の円盤より上に塗る（駒が乗っていても、色が隠れない。攻撃の相手など）。
func show_cells(colors: Dictionary, raised := {}) -> void:
	_highlight.instance_count = colors.size()
	var i := 0
	for cell: Vector2i in colors:
		var lift := 0.05 if raised.has(cell) else 0.012
		_highlight.set_instance_transform(i, Transform3D(Basis.IDENTITY, cell_center(cell) + Vector3(0.0, lift, 0.0)))
		_highlight.set_instance_color(i, RenderTone.fill_color(colors[cell], _ground_tone()))
		i += 1


## 敵の全員の脅威範囲を、赤い斜線（マスごと）と、範囲の縁の線で重ねて出す。前に出したものは消える。空を渡すと消える。
## 塗ったマス（show_cells）とは別の層なので、塗りを作り直しても残る。
func show_danger(cells: Array[Vector2i]) -> void:
	_danger_cells = cells.duplicate()
	var inside := {}
	for cell in cells:
		inside[cell] = true
	_danger_stripes.instance_count = cells.size()
	var edges: Array[Transform3D] = []
	var across := Basis(Vector3.UP, PI / 2.0)
	var half := 0.5 - DANGER_EDGE_WIDTH / 2.0
	for i in cells.size():
		var center := cell_center(cells[i]) + Vector3(0.0, DANGER_LIFT, 0.0)
		_danger_stripes.set_instance_transform(i, Transform3D(Basis.IDENTITY, center))
		# 隣が範囲の外なら、その辺に線を引く（範囲の内側に寄せて、どちらが内側か分かるようにする）。
		for side: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			if inside.has(cells[i] + side):
				continue
			var offset := Vector3(side.x, 0.001, side.y) * half
			edges.append(Transform3D(across if side.x != 0 else Basis.IDENTITY, center + offset))
	_danger_edges.instance_count = edges.size()
	for i in edges.size():
		_danger_edges.set_instance_transform(i, edges[i])


## 表示したままにしている駒の攻撃範囲を出す。sets は駒ごとのマスの列（Array[Vector2i] の列）。前に出したものは消える。
## 駒ごとに、範囲を薄く塗り（重なったところは濃くなる）、範囲の縁に線を引く。塗ったマス・敵の全員の脅威範囲とは別の層。
func show_pinned(sets: Array) -> void:
	_pinned_sets = sets.duplicate(true)
	var fills: Array[Vector3] = []
	var edges: Array[Transform3D] = []
	var across := Basis(Vector3.UP, PI / 2.0)
	var half := 0.5 - PIN_EDGE_INSET
	for cells: Array in sets:
		var inside := {}
		for cell: Vector2i in cells:
			inside[cell] = true
		for cell: Vector2i in cells:
			var center := cell_center(cell) + Vector3(0.0, PIN_LIFT, 0.0)
			fills.append(center)
			for side: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				if inside.has(cell + side):
					continue
				var offset := Vector3(side.x, 0.001, side.y) * half
				edges.append(Transform3D(across if side.x != 0 else Basis.IDENTITY, center + offset))
	_pin_fill.instance_count = fills.size()
	for i in fills.size():
		_pin_fill.set_instance_transform(i, Transform3D(Basis.IDENTITY, fills[i]))
	_pin_edges.instance_count = edges.size()
	for i in edges.size():
		_pin_edges.set_instance_transform(i, edges[i])


## 表示したままにしている範囲（駒ごとのマスの列）。検査用。
func pinned_sets() -> Array:
	return _pinned_sets.duplicate(true)


## 敵の全員の脅威範囲として出しているマス。検査用。
func danger_cells() -> Array[Vector2i]:
	return _danger_cells.duplicate()


## マウスの下のマスの印。盤の外なら消す。
func set_cursor(cell: Vector2i) -> void:
	_cursor.visible = board.in_bounds(cell)
	if _cursor.visible:
		_cursor.position = cell_center(cell) + Vector3(0.0, 0.03, 0.0)
	# マウスの周りは、マス目の線を濃くする。
	_grid.set_shader_parameter(&"cursor", Vector3(cell.x + 0.5, cell.y + 0.5, 1.0 if _cursor.visible else 0.0))


## クリックして情報を出しているマスの印（枠）。NO_CELL なら消す。
func set_marked(cell: Vector2i) -> void:
	_marked.visible = board.in_bounds(cell)
	if _marked.visible:
		_marked.position = cell_center(cell) + Vector3(0.0, 0.035, 0.0)


## focus_cells（駒やカーソルのマス）の手前（カメラ側）にある岩と木を透かす。
func update_occlusion(camera: Camera3D, looking_at: Vector3, focus_cells: Array[Vector2i], delta: float) -> void:
	var toward_camera := camera.global_position - looking_at
	toward_camera.y = 0.0

	var faded := {}
	if toward_camera.length() > 0.01:
		var step := toward_camera.normalized()
		# 見下ろす角度が浅いほど、遠くの障害物まで駒に重なる。
		var forward_y := -camera.global_transform.basis.z.y  # 真下を向くほど -1 に近い
		var reach := 1
		if forward_y > -0.65:
			reach = 3
		elif forward_y > -0.85:
			reach = 2
		for cell in focus_cells:
			# k = 0 は自分のマス（森に立つ駒、岩の上のカーソル）。
			var from := cell_center(cell)
			for k in range(0, reach + 1):
				faded[cell_of(from + step * float(k))] = true

	for cell: Vector2i in _occluders:
		var target := OCCLUDER_FADE if faded.has(cell) else 0.0
		for part: GeometryInstance3D in _occluders[cell]:
			part.transparency = move_toward(part.transparency, target, OCCLUDER_FADE_SPEED * delta)


func _build_markers() -> void:
	var cell_mesh := BoxMesh.new()
	cell_mesh.size = Vector3(1.0 - TILE_GAP, 0.02, 1.0 - TILE_GAP)

	# 塗りの色と濃さは、マスごとの色（show_cells）が決める。材質は不透明の白のまま（濃さの直しを 2 度掛けない）。
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	paint.vertex_color_use_as_albedo = true
	_highlight = MultiMesh.new()
	_highlight.transform_format = MultiMesh.TRANSFORM_3D
	_highlight.use_colors = true
	_highlight.mesh = cell_mesh
	var highlight_instance := MultiMeshInstance3D.new()
	highlight_instance.multimesh = _highlight
	highlight_instance.material_override = paint
	highlight_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# 塗ったマスは盤のどこにでも出るので、見えている範囲の判定で消されないようにする。
	highlight_instance.custom_aabb = AABB(Vector3.ZERO, Vector3(board.size.x, 1.0, board.size.y))
	add_child(highlight_instance)

	_danger_stripes = _overlay_layer(_stripe_mesh(), _stripe_material(_ground_tone()))
	var edge_mesh := BoxMesh.new()
	edge_mesh.size = Vector3(1.0, 0.004, DANGER_EDGE_WIDTH)
	_danger_edges = _overlay_layer(edge_mesh, _overlay_material(COLOR_DANGER_EDGE))

	_pin_fill = _overlay_layer(_stripe_mesh(), _overlay_material(COLOR_PIN_FILL))
	var pin_edge_mesh := BoxMesh.new()
	pin_edge_mesh.size = Vector3(1.0 - PIN_EDGE_INSET * 2.0, 0.004, DANGER_EDGE_WIDTH)
	_pin_edges = _overlay_layer(pin_edge_mesh, _overlay_material(COLOR_PIN_EDGE))

	_cursor = _add_mesh(cell_mesh, _overlay_material(Color(1.0, 1.0, 1.0, 0.4)), Vector3.ZERO)
	_cursor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cursor.visible = false

	# クリックしたマスの印は、四角い枠（角の少ない輪を 45 度回して、マスに合わせる）。
	var frame := TorusMesh.new()
	frame.inner_radius = 0.6
	frame.outer_radius = 0.68
	frame.rings = 4
	frame.ring_segments = 4
	_marked = _add_mesh(frame, _overlay_material(Color(1.0, 1.0, 1.0, 0.9)), Vector3.ZERO)
	_marked.rotation.y = PI / 4.0
	_marked.scale = Vector3(1.0, 0.1, 1.0)
	_marked.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marked.visible = false


## 盤の上に重ねる層（同じ形をマスごとに並べる）。
func _overlay_layer(mesh: Mesh, material: Material) -> MultiMesh:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.custom_aabb = AABB(Vector3.ZERO, Vector3(board.size.x, 1.0, board.size.y))
	add_child(instance)
	return multimesh


## 1 マスぶんの、上を向いた板（斜線の絵を 1 回貼る）。
static func _stripe_mesh() -> Mesh:
	var plane := PlaneMesh.new()
	plane.size = Vector2(1.0, 1.0)
	return plane


## 赤い斜線の絵。マスごとに同じ絵を貼っても、隣のマスと線がつながる（周期がマスの幅を割り切る）。
static func _stripe_material(ground: float) -> StandardMaterial3D:
	const SIZE := 64
	const PERIOD := 16
	const WIDTH := 5
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in SIZE:
		for x in SIZE:
			image.set_pixel(x, y, Color.WHITE if (x + y) % PERIOD < WIDTH else Color(1.0, 1.0, 1.0, 0.0))
	image.generate_mipmaps()
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.albedo_color = RenderTone.overlay_color(COLOR_DANGER_STRIPE, ground)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
