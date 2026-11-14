extends Node3D
## 見た目の試作。ルールは入っていない。
##
## 盤面・駒・ライト・カメラをすべてコードで組み立てる。
## 「斜め見下ろしの 3D にしたらどう見えるか」を確かめるためのもので、
## 本実装が始まったら捨てる。

const OrbitCamera := preload("res://prototype/orbit_camera.gd")
const UnitView := preload("res://prototype/unit_view.gd")

enum Terrain { NORMAL, OBSTACLE, FOREST, FONT }

const MAP_SIZE := Vector2i(30, 30)
const TILE_HEIGHT := 0.2
const TILE_GAP := 0.04
const TERRAIN_SEED := 20261114
const SQUAD: Array[String] = ["knight", "barbarian", "mage", "rogue", "knight"]
const SQUAD_OFFSETS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(0, -1), Vector2i(1, -1), Vector2i(2, -1), Vector2i(1, -2),
]

## 手前の障害物をどこまで透かすか（0 = 不透明、1 = 見えない）と、その速さ。
const OCCLUDER_FADE := 0.75
const OCCLUDER_FADE_SPEED := 5.0

const COLOR_UNDERSIDE := Color("26331f")
const COLOR_NORMAL := Color("5f9f4e")
const COLOR_FOREST := Color("457a40")
const COLOR_OBSTACLE_GROUND := Color("767b84")
const COLOR_FONT := Color("3fa9bd")
const COLOR_TREE := Color("2f6b3a")
const COLOR_ROCK := Color("6b7078")
const COLOR_CRYSTAL := Color("9ff3ff")
const COLOR_P1 := Color("3a7bd5")
const COLOR_P2 := Color("d64545")
const COLOR_NEUTRAL := Color("e0b83a")

var _terrain: Array[int] = []
var _units := {}  # Vector2i -> UnitView
var _occluders := {}  # Vector2i -> MeshInstance3D（岩と木。手前にあると駒を隠す）
var _hover_cell := Vector2i(-1, -1)
var _selected_cell := Vector2i(-1, -1)
var _moving := false

var _rig: OrbitCamera
var _cursor: MeshInstance3D
var _selection_ring: MeshInstance3D


func _ready() -> void:
	_build_environment()
	_build_terrain()
	_build_units()
	_build_markers()
	_build_camera()
	_build_help()


func _process(delta: float) -> void:
	# カメラが動くとマウスの下のマスも変わるので、マウスの動きではなく毎フレーム追う。
	_update_cursor()
	_update_occlusion(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_click(_cell_under_mouse())
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_select(Vector2i(-1, -1))


# ---- 盤面 ----


func _build_terrain() -> void:
	_terrain.resize(MAP_SIZE.x * MAP_SIZE.y)
	_terrain.fill(Terrain.NORMAL)

	# 点対称に置く（両陣営から見て同じ地形になる）。
	var rng := RandomNumberGenerator.new()
	rng.seed = TERRAIN_SEED
	for y in MAP_SIZE.y:
		for x in MAP_SIZE.x:
			var cell := Vector2i(x, y)
			var mirror := MAP_SIZE - Vector2i.ONE - cell
			if _index(cell) > _index(mirror) or _near_hq(cell):
				continue
			var roll := rng.randf()
			var terrain := Terrain.NORMAL
			if roll < 0.10:
				terrain = Terrain.OBSTACLE
			elif roll < 0.28:
				terrain = Terrain.FOREST
			elif roll < 0.30:
				terrain = Terrain.FONT
			_terrain[_index(cell)] = terrain
			_terrain[_index(mirror)] = terrain

	var tile_mesh := BoxMesh.new()
	tile_mesh.size = Vector3(1.0 - TILE_GAP, TILE_HEIGHT, 1.0 - TILE_GAP)
	var ground_materials := {
		Terrain.NORMAL: _material(COLOR_NORMAL),
		Terrain.OBSTACLE: _material(COLOR_OBSTACLE_GROUND),
		Terrain.FOREST: _material(COLOR_FOREST),
		Terrain.FONT: _material(COLOR_FONT),
	}
	var hq_materials := [_material(COLOR_P1.lightened(0.3)), _material(COLOR_P2.lightened(0.3))]

	var tree_mesh := CylinderMesh.new()
	tree_mesh.top_radius = 0.0
	tree_mesh.bottom_radius = 0.32
	tree_mesh.height = 0.9
	tree_mesh.radial_segments = 6
	var tree_material := _material(COLOR_TREE)

	var rock_mesh := BoxMesh.new()
	rock_mesh.size = Vector3(0.86, 0.9, 0.86)
	var rock_material := _material(COLOR_ROCK)

	var crystal_mesh := CylinderMesh.new()
	crystal_mesh.top_radius = 0.0
	crystal_mesh.bottom_radius = 0.1
	crystal_mesh.height = 0.4
	crystal_mesh.radial_segments = 4
	var crystal_material := _material(COLOR_CRYSTAL)
	crystal_material.emission_enabled = true
	crystal_material.emission = COLOR_CRYSTAL
	crystal_material.emission_energy_multiplier = 1.5

	# マスの隙間から背景が透けて黒い線に見えないよう、盤面の下に板を敷く。
	var underside_mesh := BoxMesh.new()
	underside_mesh.size = Vector3(MAP_SIZE.x, 0.1, MAP_SIZE.y)
	_add_mesh(underside_mesh, _material(COLOR_UNDERSIDE), Vector3(MAP_SIZE.x / 2.0, -0.2, MAP_SIZE.y / 2.0))

	for y in MAP_SIZE.y:
		for x in MAP_SIZE.x:
			var cell := Vector2i(x, y)
			var terrain: int = _terrain[_index(cell)]
			var center := _cell_center(cell)

			var ground: Material = ground_materials[terrain]
			if cell == _hq_cell(0):
				ground = hq_materials[0]
			elif cell == _hq_cell(1):
				ground = hq_materials[1]
			_add_mesh(tile_mesh, ground, center + Vector3(0.0, -TILE_HEIGHT / 2.0, 0.0))

			match terrain:
				Terrain.FOREST:
					var jitter := Vector3(rng.randf_range(-0.12, 0.12), 0.0, rng.randf_range(-0.12, 0.12))
					var tree := _add_mesh(tree_mesh, tree_material, center + jitter + Vector3(0.0, 0.45, 0.0))
					tree.scale = Vector3.ONE * rng.randf_range(0.85, 1.15)
					_occluders[cell] = tree
				Terrain.OBSTACLE:
					_occluders[cell] = _add_mesh(rock_mesh, rock_material, center + Vector3(0.0, 0.45, 0.0))
				Terrain.FONT:
					# 駒が上に立っても結晶泉だと分かるよう、結晶はマスの四隅に置く。
					for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
						var at := center + Vector3(corner.x * 0.36, 0.2, corner.y * 0.36)
						var crystal := _add_mesh(crystal_mesh, crystal_material, at)
						crystal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_units() -> void:
	var toward_enemy := _cell_center(_hq_cell(1)) - _cell_center(_hq_cell(0))
	for i in SQUAD.size():
		_add_unit(SQUAD[i], COLOR_P1, _hq_cell(0) + SQUAD_OFFSETS[i], toward_enemy)
		_add_unit(SQUAD[i], COLOR_P2, _hq_cell(1) - SQUAD_OFFSETS[i], -toward_enemy)

	# 結晶泉の上には中立の駒を置く（まだ仮の形）。
	for y in MAP_SIZE.y:
		for x in MAP_SIZE.x:
			var cell := Vector2i(x, y)
			if _terrain[_index(cell)] == Terrain.FONT:
				_add_unit("neutral", COLOR_NEUTRAL, cell, Vector3.BACK)


func _add_unit(kind: String, team_color: Color, cell: Vector2i, facing: Vector3) -> void:
	if _units.has(cell):
		return
	var unit: UnitView = UnitView.new()
	unit.position = _cell_center(cell)
	add_child(unit)
	unit.setup(kind, team_color)
	unit.face(facing)
	_units[cell] = unit


# ---- 光・カメラ・目印 ----


func _build_environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("1b2430")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b8c4d6")
	environment.ambient_light_energy = 0.45
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.ssao_enabled = true

	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -35.0, 0.0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	add_child(sun)


func _build_camera() -> void:
	_rig = OrbitCamera.new()
	_rig.bounds = Rect2(Vector2.ZERO, Vector2(MAP_SIZE))
	_rig.position = _cell_center(_hq_cell(0))
	add_child(_rig)


func _build_markers() -> void:
	var cursor_mesh := BoxMesh.new()
	cursor_mesh.size = Vector3(1.0 - TILE_GAP, 0.02, 1.0 - TILE_GAP)
	_cursor = _add_mesh(cursor_mesh, _overlay_material(Color(1.0, 1.0, 1.0, 0.35)), Vector3.ZERO)
	_cursor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cursor.visible = false

	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.34
	ring_mesh.outer_radius = 0.44
	_selection_ring = _add_mesh(ring_mesh, _overlay_material(Color(1.0, 0.9, 0.3, 0.9)), Vector3.ZERO)
	_selection_ring.scale = Vector3(1.0, 0.15, 1.0)
	_selection_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_selection_ring.visible = false


func _build_help() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var label := Label.new()
	label.text = "WASD: pan   Q/E: rotate   R: angle   Wheel: zoom   Click: select / move   Right click: cancel"
	label.position = Vector2(12.0, 8.0)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	layer.add_child(label)


# ---- 操作 ----


func _click(cell: Vector2i) -> void:
	if _moving or not _in_bounds(cell):
		return
	if _units.has(cell):
		_select(cell)
	elif _units.has(_selected_cell) and _terrain[_index(cell)] != Terrain.OBSTACLE:
		_move_selected_to(cell)


func _select(cell: Vector2i) -> void:
	_selected_cell = cell
	_selection_ring.visible = _units.has(cell)
	if _selection_ring.visible:
		_selection_ring.position = _cell_center(cell) + Vector3(0.0, 0.03, 0.0)


func _move_selected_to(cell: Vector2i) -> void:
	var unit: UnitView = _units[_selected_cell]
	_units.erase(_selected_cell)
	_units[cell] = unit
	_select(Vector2i(-1, -1))

	var target := _cell_center(cell)
	var duration := clampf(unit.position.distance_to(target) * 0.12, 0.25, 1.2)
	_moving = true
	unit.face(target - unit.position)
	unit.play_run()
	var tween := create_tween()
	tween.tween_property(unit, "position", target, duration)
	await tween.finished
	unit.play_idle()
	_moving = false
	_select(cell)


func _update_cursor() -> void:
	_hover_cell = _cell_under_mouse()
	_cursor.visible = _in_bounds(_hover_cell)
	if _cursor.visible:
		_cursor.position = _cell_center(_hover_cell) + Vector3(0.0, 0.015, 0.0)


## 駒やカーソルの手前（カメラ側）にある岩と木を透かす。
func _update_occlusion(delta: float) -> void:
	var camera: Camera3D = _rig.camera
	var toward_camera := camera.global_position - _rig.global_position
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

		var targets: Array = _units.keys()
		if _in_bounds(_hover_cell):
			targets.append(_hover_cell)
		for cell: Vector2i in targets:
			var from := _cell_center(cell)
			for k in range(1, reach + 1):
				var p := from + step * float(k)
				faded[Vector2i(floori(p.x), floori(p.z))] = true

	for cell: Vector2i in _occluders:
		var occluder: MeshInstance3D = _occluders[cell]
		var target := OCCLUDER_FADE if faded.has(cell) else 0.0
		occluder.transparency = move_toward(occluder.transparency, target, OCCLUDER_FADE_SPEED * delta)


func _cell_under_mouse() -> Vector2i:
	var camera: Camera3D = _rig.camera
	var mouse := get_viewport().get_mouse_position()
	var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(
		camera.project_ray_origin(mouse), camera.project_ray_normal(mouse)
	)
	if hit == null:
		return Vector2i(-1, -1)
	var point: Vector3 = hit
	return Vector2i(floori(point.x), floori(point.z))


# ---- 小物 ----


func _index(cell: Vector2i) -> int:
	return cell.y * MAP_SIZE.x + cell.x


func _in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < MAP_SIZE.x and cell.y < MAP_SIZE.y


func _hq_cell(player: int) -> Vector2i:
	var p1 := Vector2i(2, MAP_SIZE.y - 3)
	return p1 if player == 0 else MAP_SIZE - Vector2i.ONE - p1


func _near_hq(cell: Vector2i) -> bool:
	for player in 2:
		var d := (cell - _hq_cell(player)).abs()
		if maxi(d.x, d.y) <= 3:
			return true
	return false


func _cell_center(cell: Vector2i) -> Vector3:
	return Vector3(cell.x + 0.5, 0.0, cell.y + 0.5)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material


func _overlay_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


func _add_mesh(mesh: Mesh, material: Material, at: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	add_child(instance)
	return instance
