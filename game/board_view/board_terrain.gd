extends "res://game/board_view/board_base.gd"
## 盤面の地面と置物: 地面の塗りと模様、障害物（壁・岩山・結晶）と森の置物。


## マスの地面の色（本陣は陣営の色）。palette はマップの見た目（stage_look.gd。省けば中央平原）。
## mark_hq が偽なら、本陣も地形の色のまま（景色だけを見せる背景）。
static func ground_color(battle_board: Board, cell: Vector2i, team_colors: Array[Color], palette: Dictionary = {}, mark_hq := true) -> Color:
	if palette.is_empty():
		palette = StageLook.of(StageLook.DEFAULT)
	var hq_owner := battle_board.hq_owner(cell) if mark_hq else -1
	if hq_owner >= 0:
		return team_colors[hq_owner].lightened(0.3)
	match battle_board.terrain_at(cell):
		Terrain.Type.OBSTACLE:
			return palette[StageLook.OBSTACLE]
		Terrain.Type.FOREST:
			return palette[StageLook.FOREST]
		Terrain.Type.FONT:
			return palette[StageLook.FONT]
	return palette[StageLook.NORMAL]


## 地形の色の地図。1 マスが MAP_SCALE ピクセルで、周りに MAP_PAD マスぶんの平地が付く（盤の外は平地の色で続く）。
static func terrain_image(battle_board: Board, team_colors: Array[Color], palette: Dictionary = {}, mark_hq := true) -> Image:
	if palette.is_empty():
		palette = StageLook.of(StageLook.DEFAULT)
	var normal: Color = palette[StageLook.NORMAL]
	var cells := battle_board.size + Vector2i.ONE * 2 * MAP_PAD
	var image := Image.create(cells.x * MAP_SCALE, cells.y * MAP_SCALE, false, Image.FORMAT_RGB8)
	image.fill(normal)
	for y in battle_board.size.y:
		for x in battle_board.size.x:
			var color := ground_color(battle_board, Vector2i(x, y), team_colors, palette, mark_hq)
			if color != normal:
				image.fill_rect(Rect2i((Vector2i(x, y) + Vector2i.ONE * MAP_PAD) * MAP_SCALE, Vector2i.ONE * MAP_SCALE), color)
	return image


## 地面（盤の外まで続く 1 枚の板）と、その上のマス目の線。
func _add_ground() -> void:
	var size := Vector2(board.size)
	var center := Vector3(size.x / 2.0, 0.0, size.y / 2.0)

	var ground := ShaderMaterial.new()
	ground.shader = GROUND_SHADER
	ground.set_shader_parameter(&"terrain_map", ImageTexture.create_from_image(terrain_image(board, _team_colors, look, not scenery_only)))
	ground.set_shader_parameter(&"noise_map", _noise_texture())
	ground.set_shader_parameter(&"board_size", size)
	ground.set_shader_parameter(&"map_pad", float(MAP_PAD))
	ground.set_shader_parameter(&"paving", float(look[StageLook.PAVING]))
	ground.set_shader_parameter(&"dry", float(look[StageLook.DRY]))
	ground.set_shader_parameter(&"strata", float(look.get(StageLook.STRATA, 0.0)))
	if look.has(StageLook.CLOUD_SHADE):
		ground.set_shader_parameter(&"cloud_shade", float(look[StageLook.CLOUD_SHADE]))
	ground.set_shader_parameter(&"snow", float(look.get(StageLook.SNOW, 0.0)))
	ground.set_shader_parameter(&"cracks", float(look.get(StageLook.CRACKS, 0.0)))
	ground.set_shader_parameter(&"seam_glow", float(look.get(StageLook.SEAM_GLOW, 0.0)) * (StageLook.CRYSTAL_GLOW if StageLook.effects else 0.6))
	ground.set_shader_parameter(&"pattern_gain", RenderTone.pattern_gain())
	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = size + Vector2.ONE * 2.0 * GROUND_REACH
	_add_mesh(ground_mesh, ground, center).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_grid = ShaderMaterial.new()
	_grid.shader = GRID_SHADER
	_grid.set_shader_parameter(&"board_size", size)
	# 線の濃さ（ふだん・操作しているとき・盤の縁）。Forward+ では濃く出るぶん下げる。
	_grid.set_shader_parameter(&"line_color", GRID_LINE_COLOR)
	_grid.set_shader_parameter(&"idle_alpha", RenderTone.overlay_alpha(GRID_IDLE_ALPHA, _ground_tone(), GRID_LINE_COLOR.get_luminance()))
	_grid.set_shader_parameter(&"active_alpha", RenderTone.overlay_alpha(GRID_ACTIVE_ALPHA, _ground_tone(), GRID_LINE_COLOR.get_luminance()))
	_grid.set_shader_parameter(&"border_alpha", RenderTone.overlay_alpha(GRID_BORDER_ALPHA, _ground_tone(), GRID_LINE_COLOR.get_luminance()))
	# 塗ったマスや印より先に描く（線の上に色が乗る）。
	_grid.render_priority = -1
	var grid_mesh := PlaneMesh.new()
	grid_mesh.size = size + Vector2.ONE * 0.2
	_grid_instance = _add_mesh(grid_mesh, _grid, center + Vector3(0.0, 0.006, 0.0))
	_grid_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_grid_instance.visible = not scenery_only


## つなぎ目の無い白黒のノイズ（地面のむらと、地形の境目の揺れに使う）。作るのは 1 回だけ。
static func _noise_texture() -> ImageTexture:
	if _noise == null:
		var noise := FastNoiseLite.new()
		noise.seed = 7
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = 0.03
		noise.fractal_octaves = 3
		var image := noise.get_seamless_image(256, 256)
		image.generate_mipmaps()
		_noise = ImageTexture.create_from_image(image)
	return _noise


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


## 障害物か森のマスに、マップの見た目の置き方（StageLook.OBSTACLE_PROPS・FOREST_PROPS）で置く。
## 手前にあると駒を隠すので、透かすときに使う形をすべて返す。
func _add_cell_props(spec: Dictionary, cell: Vector2i, rng: RandomNumberGenerator) -> Array[GeometryInstance3D]:
	var props: Array = spec.props
	var tint: Color = spec.tint
	var center := cell_center(cell)
	var parts: Array[GeometryInstance3D] = []
	var top := 0.0
	match spec.style:
		StageLook.WALL:
			parts.append_array(_add_wall(props, tint, cell, float(spec.height), rng, bool(spec.get("lone_wall", false))))
			top = float(spec.height)
		_:
			# 元は六角形のマス用なので、向きを 60 度刻みでばらす。
			var prop: Dictionary = props[rng.randi() % props.size()]
			var size := float(spec.scale) * rng.randf_range(0.9, 1.05)
			var turned := Basis(Vector3.UP, deg_to_rad(60.0 * rng.randi_range(0, 5))).scaled(Vector3.ONE * size)
			parts.append(_add_prop(prop, tint, Transform3D(turned, center)))
			top = float(prop.height) * size
	if spec.has("crystals"):
		# 置いたものの上から、光る結晶の群れが生える。
		var crystal := {"crystal": spec.crystals, "height": 1.0}
		var turned := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(0.62, rng.randf_range(0.85, 1.05), 0.62))
		var at := center + Vector3(rng.randf_range(-0.08, 0.08), top * 0.4, rng.randf_range(-0.08, 0.08))
		var part := _add_prop(crystal, Color.WHITE, Transform3D(turned, at))
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parts.append(part)
	return parts


## 岩山（StageLook.CRAG）: 辺で接する障害物のかたまりごとに 1 つの岩山（crag_mesh.gd）。形はマスごとに分かれている（透かすため）。
func _add_crags(spec: Dictionary, look_seed: int) -> void:
	var blocked: Array[Vector2i] = []
	for y in board.size.y:
		for x in board.size.x:
			if board.terrain_at(Vector2i(x, y)) == Terrain.Type.OBSTACLE:
				blocked.append(Vector2i(x, y))
	var colors := {CragMesh.LOW: spec.low, CragMesh.CLIFF: spec.cliff, CragMesh.TOP: spec.top}
	if spec.has("crystals"):
		colors[CragMesh.CRYSTAL] = spec.crystals
	var rock := StandardMaterial3D.new()
	rock.vertex_color_use_as_albedo = true
	rock.vertex_color_is_srgb = true
	rock.albedo_color = spec.tint
	rock.roughness = 0.95
	var crystal: Material = StageLook.crystal_material(spec.crystals) if spec.has("crystals") else null
	var meshes := CragMesh.new(blocked, board.size, look_seed).build(colors)
	for cell: Vector2i in meshes:
		var mesh: ArrayMesh = meshes[cell]
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		instance.set_surface_override_material(0, rock)
		if mesh.get_surface_count() > 1:
			instance.set_surface_override_material(1, crystal)
		add_child(instance)
		_occluders[cell] = [instance] as Array[GeometryInstance3D]


## 石の壁（StageLook.WALL）: マスの真ん中の柱と、右・下の障害物のマスへつなぐ壁。
## 素材の柱（幅 1.5・高さ 4）と壁（長さ 4・厚さ 1・高さ 4）を、マスに合わせて伸び縮みさせる。
func _add_wall(props: Array, tint: Color, cell: Vector2i, height: float, rng: RandomNumberGenerator, lone_wall := false) -> Array[GeometryInstance3D]:
	var parts: Array[GeometryInstance3D] = []
	var pillar: Dictionary = props[0]
	var center := cell_center(cell)
	if lone_wall and _is_lone_obstacle(cell):
		# 隣に障害物の無い 1 マスは、柱ではなく、短い壁（両軍の間を遮る向き）と、その両端の細い柱。
		var slab: Dictionary = props[1]
		var slab_basis := Basis.from_scale(Vector3(LONE_WALL_WIDTH / 4.0, height * WALL_HEIGHT / float(slab.height), WALL_THICKNESS))
		parts.append(_add_prop(slab, tint, Transform3D(slab_basis, center)))
		for end: float in [-1.0, 1.0]:
			var post_basis := Basis.from_scale(Vector3(LONE_WALL_POST, height * rng.randf_range(0.94, 1.02) / float(pillar.height), LONE_WALL_POST))
			parts.append(_add_prop(pillar, tint, Transform3D(post_basis, center + Vector3(end * LONE_WALL_WIDTH * 0.5, 0.0, 0.0))))
		return parts
	var pillar_height := height * rng.randf_range(0.94, 1.06)
	var width := WALL_PILLAR_WIDTH / 1.5
	var pillar_basis := Basis.from_scale(Vector3(width, pillar_height / float(pillar.height), width))
	parts.append(_add_prop(pillar, tint, Transform3D(pillar_basis, center)))
	for side: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
		if not board.in_bounds(cell + side) or board.terrain_at(cell + side) != Terrain.Type.OBSTACLE:
			continue
		var wall: Dictionary = props[1]
		if props.size() > 2 and rng.randf() < WALL_BROKEN_SHARE:
			wall = props[2]
		var along := Basis(Vector3.UP, 0.0 if side.x != 0 else PI / 2.0)
		var stretched := along * Basis.from_scale(Vector3(0.25, height * WALL_HEIGHT / float(wall.height), WALL_THICKNESS))
		var at := center + Vector3(side.x, 0.0, side.y) * 0.5
		parts.append(_add_prop(wall, tint, Transform3D(stretched, at)))
	return parts


## cell の障害物が、辺で接する障害物を持たないか。
func _is_lone_obstacle(cell: Vector2i) -> bool:
	for side: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
		if board.in_bounds(cell + side) and board.terrain_at(cell + side) == Terrain.Type.OBSTACLE:
			return false
	return true


## 素材を 1 つ、place に置く。
func _add_prop(prop: Dictionary, tint: Color, place: Transform3D) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = StageLook.mesh_of(prop)
	instance.material_override = StageLook.material_of(prop, tint)
	instance.transform = place
	add_child(instance)
	return instance
