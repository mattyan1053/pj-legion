extends Node3D
## 盤面の見た目。ルールの盤面（Board）を受け取って、マス・木立・岩山・結晶泉・本陣の旗と、
## 環境オブジェクト（起爆樽・回復の泉・ポータル）を組み立てる。
##
## マスの色分け（移動範囲・攻撃できる相手など）と、マウスの下のマスの印もここで出す。
## 何を塗るかは呼ぶ側が決める（ここはルールを持たない）。

const CrystalMesh := preload("res://prototype/crystal_mesh.gd")
const FOREST_SCENES: Array[PackedScene] = [
	preload("res://assets/kaykit/medieval-hexagon/trees_A_small.gltf"),
	preload("res://assets/kaykit/medieval-hexagon/trees_B_small.gltf"),
]
const OBSTACLE_SCENE := preload("res://assets/kaykit/medieval-hexagon/mountain_A.gltf")
## 元は六角形のマス（差し渡し約 1.8）用なので、四角いマスに収まるよう縮める。
const FOREST_SCALE := 0.62
const OBSTACLE_SCALE := 0.56

const TILE_HEIGHT := 0.2
const TILE_GAP := 0.04
const NO_CELL := Vector2i(-1, -1)

## 手前の障害物をどこまで透かすか（0 = 不透明、1 = 見えない）と、その速さ。
const OCCLUDER_FADE := 0.75
const OCCLUDER_FADE_SPEED := 5.0

const COLOR_UNDERSIDE := Color("26331f")
const COLOR_NORMAL := Color("5f9f4e")
const COLOR_FOREST := Color("457a40")
const COLOR_OBSTACLE_GROUND := Color("767b84")
const COLOR_FONT := Color("3fa9bd")
const COLOR_CRYSTAL := Color("4fd8f0")
const COLOR_BARREL := Color("8a5a2b")
const COLOR_BARREL_BAND := Color("3a3a3e")
const COLOR_BARREL_MARK := Color("e8452e")
const COLOR_SPRING_STONE := Color("b9bcc0")
const COLOR_SPRING_WATER := Color("2f8fe0")
const COLOR_SPRING_CROSS := Color("2fd66b")
## ポータルの色。対ごとに変える（同じ色の 2 つがつながっている）。
const PORTAL_COLORS: Array[Color] = [Color("b06cff"), Color("ff9a3c"), Color("ff5fa8"), Color("f2e85a")]

var board: Board

var _barrels := {}  # Vector2i -> Node3D（爆発したら取り除く）
var _occluders := {}  # Vector2i -> Array[GeometryInstance3D]（岩山と木立。手前にあると駒を隠す）
var _cursor: MeshInstance3D
var _highlight: MultiMesh


## look_seed は見た目だけに使う（木の種類・向き・大きさ）。team_colors は本陣の色（添字がプレイヤー番号）。
func setup(battle_board: Board, look_seed: int, team_colors: Array[Color]) -> void:
	board = battle_board
	var rng := RandomNumberGenerator.new()
	rng.seed = look_seed

	var tile_mesh := BoxMesh.new()
	tile_mesh.size = Vector3(1.0 - TILE_GAP, TILE_HEIGHT, 1.0 - TILE_GAP)
	var ground_materials := {
		Terrain.Type.NORMAL: _material(COLOR_NORMAL),
		Terrain.Type.OBSTACLE: _material(COLOR_OBSTACLE_GROUND),
		Terrain.Type.FOREST: _material(COLOR_FOREST),
		Terrain.Type.FONT: _material(COLOR_FONT),
	}

	# マスの隙間から背景が透けて黒い線に見えないよう、盤面の下に板を敷く。
	var underside_mesh := BoxMesh.new()
	underside_mesh.size = Vector3(board.size.x, 0.1, board.size.y)
	_add_mesh(underside_mesh, _material(COLOR_UNDERSIDE), Vector3(board.size.x / 2.0, -0.2, board.size.y / 2.0))

	var crystal_mesh := CrystalMesh.build()
	var crystal_material := _material(COLOR_CRYSTAL)
	crystal_material.emission_enabled = true
	crystal_material.emission = COLOR_CRYSTAL
	crystal_material.emission_energy_multiplier = 0.35
	crystal_material.roughness = 0.25

	for y in board.size.y:
		for x in board.size.x:
			var cell := Vector2i(x, y)
			var terrain := board.terrain_at(cell)
			var center := cell_center(cell)
			var ground: Material = ground_materials[terrain]
			var hq_owner := board.hq_owner(cell)
			if hq_owner >= 0:
				ground = _material(team_colors[hq_owner].lightened(0.3))
				_add_flag(center, team_colors[hq_owner])
			_add_mesh(tile_mesh, ground, center + Vector3(0.0, -TILE_HEIGHT / 2.0, 0.0))

			match terrain:
				Terrain.Type.FOREST:
					var scene: PackedScene = FOREST_SCENES[rng.randi() % FOREST_SCENES.size()]
					_occluders[cell] = _add_prop(scene, center, FOREST_SCALE * rng.randf_range(0.9, 1.05), rng)
				Terrain.Type.OBSTACLE:
					_occluders[cell] = _add_prop(OBSTACLE_SCENE, center, OBSTACLE_SCALE, rng)
				Terrain.Type.FONT:
					_add_crystals(crystal_mesh, crystal_material, center, rng)

	for cell in board.barrel_cells:
		_add_barrel(cell, rng)
	for cell in board.spring_cells:
		_add_spring(cell)
	for cell: Vector2i in board.portal_exits:
		_add_portal(cell, portal_color(board, cell))

	_build_markers()


## ポータルの色。対の 2 つは同じ色になる（対を、上の行・左の列にあるほうの順に数えて色を割り当てる）。
static func portal_color(battle_board: Board, cell: Vector2i) -> Color:
	var firsts: Array[Vector2i] = []
	for portal: Vector2i in battle_board.portal_exits:
		if Board.in_reading_order(portal, battle_board.portal_exits[portal]):
			firsts.append(portal)
	firsts.sort_custom(Board.in_reading_order)
	var exit := battle_board.portal_exit(cell)
	var index := firsts.find(cell if Board.in_reading_order(cell, exit) else exit)
	return PORTAL_COLORS[maxi(index, 0) % PORTAL_COLORS.size()]


## 樽が描かれているマス。検査用。
func barrel_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	cells.assign(_barrels.keys())
	return cells


## 爆発した樽を取り除く。
func remove_barrel(cell: Vector2i) -> void:
	if _barrels.has(cell):
		_barrels[cell].queue_free()
		_barrels.erase(cell)


static func cell_center(cell: Vector2i) -> Vector3:
	return Vector3(cell.x + 0.5, 0.0, cell.y + 0.5)


static func cell_of(point: Vector3) -> Vector2i:
	return Vector2i(floori(point.x), floori(point.z))


## マスを色で塗る（マス -> Color）。前に塗ったものは消える。空を渡すと全部消える。
func show_cells(colors: Dictionary) -> void:
	_highlight.instance_count = colors.size()
	var i := 0
	for cell: Vector2i in colors:
		_highlight.set_instance_transform(i, Transform3D(Basis.IDENTITY, cell_center(cell) + Vector3(0.0, 0.012, 0.0)))
		_highlight.set_instance_color(i, colors[cell])
		i += 1


## マウスの下のマスの印。盤の外なら消す。
func set_cursor(cell: Vector2i) -> void:
	_cursor.visible = board.in_bounds(cell)
	if _cursor.visible:
		_cursor.position = cell_center(cell) + Vector3(0.0, 0.03, 0.0)


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

	var paint := _overlay_material(Color.WHITE)
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

	_cursor = _add_mesh(cell_mesh, _overlay_material(Color(1.0, 1.0, 1.0, 0.4)), Vector3.ZERO)
	_cursor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cursor.visible = false


## 起爆樽。入れないマスなので、マスの中央に立てる。ふたの赤い印で、ただの樽でないと分かるようにする。
func _add_barrel(cell: Vector2i, rng: RandomNumberGenerator) -> void:
	var root := Node3D.new()
	root.position = cell_center(cell)
	root.rotation.y = rng.randf_range(0.0, TAU)
	add_child(root)
	_barrels[cell] = root

	var body := CylinderMesh.new()
	body.top_radius = 0.24
	body.bottom_radius = 0.24
	body.height = 0.6
	body.radial_segments = 12
	_add_part(root, body, _material(COLOR_BARREL), Vector3(0.0, 0.3, 0.0))
	var band := CylinderMesh.new()
	band.top_radius = 0.255
	band.bottom_radius = 0.255
	band.height = 0.05
	band.radial_segments = 12
	for y: float in [0.1, 0.5]:
		_add_part(root, band, _material(COLOR_BARREL_BAND), Vector3(0.0, y, 0.0))
	var mark := CylinderMesh.new()
	mark.top_radius = 0.15
	mark.bottom_radius = 0.15
	mark.height = 0.03
	mark.radial_segments = 12
	var mark_material := _flat_material(COLOR_BARREL_MARK)
	_add_part(root, mark, mark_material, Vector3(0.0, 0.61, 0.0))
	_add_part(root, band, mark_material, Vector3(0.0, 0.3, 0.0))


## 回復の泉。駒が上に立つので平たく作る（石の縁と水面）。駒が乗っていても分かるよう、隅に緑の十字の札を立てる。
func _add_spring(cell: Vector2i) -> void:
	var center := cell_center(cell)
	var rim := TorusMesh.new()
	rim.inner_radius = 0.36
	rim.outer_radius = 0.46
	rim.rings = 20
	rim.ring_segments = 8
	var rim_instance := _add_mesh(rim, _material(COLOR_SPRING_STONE), center + Vector3(0.0, 0.02, 0.0))
	rim_instance.scale = Vector3(1.0, 0.7, 1.0)
	var water := CylinderMesh.new()
	water.top_radius = 0.38
	water.bottom_radius = 0.38
	water.height = 0.02
	_add_mesh(water, _flat_material(COLOR_SPRING_WATER), center + Vector3(0.0, 0.02, 0.0)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var foot := center + Vector3(-0.4, 0.0, -0.4)
	var post := CylinderMesh.new()
	post.top_radius = 0.025
	post.bottom_radius = 0.025
	post.height = 1.0
	_add_mesh(post, _material(COLOR_SPRING_STONE), foot + Vector3(0.0, 0.5, 0.0))
	var bar := BoxMesh.new()
	bar.size = Vector3(0.3, 0.1, 0.05)
	var cross := _flat_material(COLOR_SPRING_CROSS)
	_add_mesh(bar, cross, foot + Vector3(0.0, 1.1, 0.0))
	_add_mesh(bar, cross, foot + Vector3(0.0, 1.1, 0.0)).rotation.z = PI / 2.0


## ポータル。駒が上に立つので平たく作る（色の輪と薄い面）。駒が乗っていても分かるよう、両脇に柱を立てる。
## 色は対ごとに変える。
func _add_portal(cell: Vector2i, color: Color) -> void:
	var center := cell_center(cell)
	var glow := _flat_material(color)
	for radius: float in [0.42, 0.26]:
		var ring := TorusMesh.new()
		ring.inner_radius = radius - 0.035
		ring.outer_radius = radius + 0.035
		ring.rings = 24
		ring.ring_segments = 6
		var instance := _add_mesh(ring, glow, center + Vector3(0.0, 0.025, 0.0))
		instance.scale = Vector3(1.0, 0.4, 1.0)
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var disc := CylinderMesh.new()
	disc.top_radius = 0.4
	disc.bottom_radius = 0.4
	disc.height = 0.01
	_add_mesh(disc, _overlay_material(Color(color, 0.45)), center + Vector3(0.0, 0.015, 0.0)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pillar := CylinderMesh.new()
	pillar.top_radius = 0.02
	pillar.bottom_radius = 0.05
	pillar.height = 0.9
	pillar.radial_segments = 6
	for side: float in [-0.44, 0.44]:
		_add_mesh(pillar, glow, center + Vector3(side, 0.45, 0.0))


func _add_part(parent: Node3D, mesh: Mesh, material: Material, at: Vector3) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)


## 本陣の旗。駒が乗っても見えるよう、マスの隅に立てる。
func _add_flag(center: Vector3, color: Color) -> void:
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.025
	pole_mesh.bottom_radius = 0.025
	pole_mesh.height = 1.5
	var foot := center + Vector3(-0.4, 0.0, -0.4)
	_add_mesh(pole_mesh, _material(Color("d8d2c0")), foot + Vector3(0.0, 0.75, 0.0))
	var cloth_mesh := BoxMesh.new()
	cloth_mesh.size = Vector3(0.42, 0.26, 0.03)
	var cloth := _material(color)
	cloth.emission_enabled = true
	cloth.emission = color
	cloth.emission_energy_multiplier = 0.25
	_add_mesh(cloth_mesh, cloth, foot + Vector3(0.22, 1.36, 0.0))


## 駒が上に立っても結晶泉だと分かるよう、結晶はマスの四隅に、外へ傾けて置く。
func _add_crystals(mesh: Mesh, material: Material, center: Vector3, rng: RandomNumberGenerator) -> void:
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var outward := Vector3(corner.x, 0.0, corner.y).normalized()
		var base := center + outward * 0.47
		for k in 2:
			var crystal := _add_mesh(mesh, material, base)
			var height := 0.32 if k == 0 else 0.18
			crystal.scale = Vector3(0.065, height, 0.065) * (1.0 if k == 0 else 0.8)
			# 傾ける軸は「外向き」と直交する水平の軸。
			var axis := outward.cross(Vector3.UP).normalized()
			crystal.rotate(axis, -deg_to_rad(18.0 + 22.0 * k))
			crystal.rotate_y(rng.randf_range(0.0, TAU))
			if k == 1:
				crystal.position += outward.rotated(Vector3.UP, 0.9) * 0.1
			crystal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material


## 光に左右されない、決まった色（どの描画方式でも同じ色に見える）。
func _flat_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


func _overlay_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


## 素材のシーンをマスの中央に置き、向きを 60 度刻みでばらす（元が六角形のマス用のため）。
## 透かすときに使うので、中の形（GeometryInstance3D）をすべて返す。
func _add_prop(scene: PackedScene, at: Vector3, size: float, rng: RandomNumberGenerator) -> Array[GeometryInstance3D]:
	var prop: Node3D = scene.instantiate()
	prop.position = at
	prop.scale = Vector3.ONE * size
	prop.rotation.y = deg_to_rad(60.0 * rng.randi_range(0, 5))
	add_child(prop)
	var parts: Array[GeometryInstance3D] = []
	for node in prop.find_children("*", "GeometryInstance3D", true, false):
		parts.append(node)
	return parts


func _add_mesh(mesh: Mesh, material: Material, at: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	add_child(instance)
	return instance
