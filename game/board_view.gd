extends Node3D
## 盤面の見た目。ルールの盤面（Board）を受け取って、地面・木立・岩山・結晶泉・本陣の旗と、
## 環境オブジェクト（起爆樽・回復の泉・ポータル）を組み立てる。盤の上の効果（盾・煙幕・聖域）も描く。
##
## 地面は、盤の外まで続く 1 枚の板（ground.gdshader）。マスごとの板は並べない。マス目は、その上に重ねる線（grid.gdshader）で、
## ふだんは薄く、操作しているときとマウスの周りだけ濃くする。盤の外の景色は scenery.gd。
##
## マスの色分け（移動範囲・攻撃できる相手など）と、マウスの下のマスの印もここで出す。
## 何を塗るかは呼ぶ側が決める（ここはルールを持たない）。

const CrystalMesh := preload("res://game/crystal_mesh.gd")
const StageLook := preload("res://game/stage_look.gd")
const Scenery := preload("res://game/scenery.gd")
const GROUND_SHADER := preload("res://game/ground.gdshader")
const GRID_SHADER := preload("res://game/grid.gdshader")
const FOREST_SCENES: Array[PackedScene] = [
	preload("res://assets/kaykit/medieval-hexagon/trees_A_small.gltf"),
	preload("res://assets/kaykit/medieval-hexagon/trees_B_small.gltf"),
]
const OBSTACLE_SCENE := preload("res://assets/kaykit/medieval-hexagon/mountain_A.gltf")
## 元は六角形のマス（差し渡し約 1.8）用なので、四角いマスに収まるよう縮める。
const FOREST_SCALE := 0.62
const OBSTACLE_SCALE := 0.56

## 塗ったマスどうしの隙間（マス目の線が見える）。
const TILE_GAP := 0.04
## 地面を盤の外へ広げる距離（マス）。霞で見えなくなるより、ずっと先まで。
const GROUND_REACH := 400.0
## 地形の色の地図の細かさ（1 マスのピクセル数）と、盤の周りに付ける平地の幅（マス）。
const MAP_SCALE := 8
const MAP_PAD := 2
## マス目の線の濃さが変わる速さ（1 秒あたり）。
const GRID_FADE_SPEED := 6.0
const NO_CELL := Vector2i(-1, -1)

## 手前の障害物をどこまで透かすか（0 = 不透明、1 = 見えない）と、その速さ。
const OCCLUDER_FADE := 0.75
const OCCLUDER_FADE_SPEED := 5.0

## 地面の色は、ステージの色合い（stage_look.gd）にある。
const COLOR_CRYSTAL := Color("4fd8f0")
const COLOR_BARREL := Color("8a5a2b")
const COLOR_BARREL_BAND := Color("3a3a3e")
const COLOR_BARREL_MARK := Color("e8452e")
const COLOR_SPRING_STONE := Color("b9bcc0")
const COLOR_SPRING_WATER := Color("2f8fe0")
const COLOR_SPRING_CROSS := Color("2fd66b")
## ポータルの色。対ごとに変える（同じ色の 2 つがつながっている）。
const PORTAL_COLORS: Array[Color] = [Color("b06cff"), Color("ff9a3c"), Color("ff5fa8"), Color("f2e85a")]
const COLOR_SMOKE := Color(0.62, 0.64, 0.68, 0.55)
## 泉の波紋（1 回の秒数、いちばん濃いときの濃さ、1 つの泉の波紋の数）。
const RIPPLE_PERIOD := 2.2
const RIPPLE_ALPHA := 0.75
const RIPPLES_PER_SPRING := 2
## ポータルの光の粒（昇りきるまでの秒数、昇る高さ、1 つのポータルの粒の数）と、面の脈の秒数。
const MOTE_PERIOD := 1.6
const MOTE_RISE := 0.9
const MOTES_PER_PORTAL := 4
const PORTAL_PULSE_PERIOD := 1.8
## 敵の全員の脅威範囲（show_danger）。塗りではなく、赤い斜線と、範囲の縁の線で描く。
## 移動の青・巡航の黄の塗りの上に重ねても、下の色が見えて、どちらも読める。
const COLOR_DANGER_STRIPE := Color(0.95, 0.12, 0.1, 0.55)
const COLOR_DANGER_EDGE := Color(1.0, 0.25, 0.18, 0.95)
## 斜線と縁の高さ。塗ったマス（駒の足元より上に塗るものも）より上。
const DANGER_LIFT := 0.07
## 縁の線の太さ（マス）。
const DANGER_EDGE_WIDTH := 0.07

var board: Board
## ステージの色合い（stage_look.gd）。
var look: Dictionary = StageLook.of(BoardGenerator.Stage.PLAIN)

var _barrels := {}  # Vector2i -> Node3D（爆発したら取り除く）
var _field_effects := {}  # 効果の番号 -> Node3D（消えたら取り除く）
var _team_colors: Array[Color] = []
var _occluders := {}  # Vector2i -> Array[GeometryInstance3D]（岩山と木立。手前にあると駒を隠す）
var _cursor: MeshInstance3D
var _marked: MeshInstance3D
var _highlight: MultiMesh
var _danger_stripes: MultiMesh
var _danger_edges: MultiMesh
var _danger_cells: Array[Vector2i] = []
var _grid: ShaderMaterial
var _grid_emphasis := 0.0
var _grid_emphasized := false
## 泉とポータルの動き。泉: 水面に広がる波紋（[輪, マテリアル, 位相]）。ポータル: 渦を巻いて昇る光の粒（[粒, 中心, 位相]）と、
## 脈打つ面（[マテリアル, 色]）。
var _ripples: Array = []
var _motes: Array = []
var _portal_discs: Array = []
var _motion_time := 0.0
static var _noise: ImageTexture


## look_seed は見た目だけに使う（木の種類・向き・大きさ）。team_colors は本陣の色（添字がプレイヤー番号）。
## stage は色合いを決める（stage_look.gd）。
func setup(battle_board: Board, look_seed: int, team_colors: Array[Color], stage: int = BoardGenerator.Stage.PLAIN) -> void:
	board = battle_board
	look = StageLook.of(stage)
	_team_colors = team_colors
	var rng := RandomNumberGenerator.new()
	rng.seed = look_seed

	_add_ground()
	var scenery := Scenery.new()
	add_child(scenery)
	scenery.setup(board.size, look_seed)

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
			var hq_owner := board.hq_owner(cell)
			if hq_owner >= 0:
				_add_flag(center, team_colors[hq_owner])

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
	for effect in board.field_effects:
		add_field_effect(effect.id, effect.type, effect.side, effect.cells)

	_build_markers()


## マスの地面の色（本陣は陣営の色）。palette はステージの色合い（stage_look.gd。省けば中央平原）。
static func ground_color(battle_board: Board, cell: Vector2i, team_colors: Array[Color], palette: Dictionary = {}) -> Color:
	if palette.is_empty():
		palette = StageLook.of(BoardGenerator.Stage.PLAIN)
	var hq_owner := battle_board.hq_owner(cell)
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
static func terrain_image(battle_board: Board, team_colors: Array[Color], palette: Dictionary = {}) -> Image:
	if palette.is_empty():
		palette = StageLook.of(BoardGenerator.Stage.PLAIN)
	var normal: Color = palette[StageLook.NORMAL]
	var cells := battle_board.size + Vector2i.ONE * 2 * MAP_PAD
	var image := Image.create(cells.x * MAP_SCALE, cells.y * MAP_SCALE, false, Image.FORMAT_RGB8)
	image.fill(normal)
	for y in battle_board.size.y:
		for x in battle_board.size.x:
			var color := ground_color(battle_board, Vector2i(x, y), team_colors, palette)
			if color != normal:
				image.fill_rect(Rect2i((Vector2i(x, y) + Vector2i.ONE * MAP_PAD) * MAP_SCALE, Vector2i.ONE * MAP_SCALE), color)
	return image


## マス目の線を濃くする（駒を選んでいる、範囲を見せているなど、操作している間）。ふだんは薄い。
func set_grid_emphasis(on: bool) -> void:
	_grid_emphasized = on


func _process(delta: float) -> void:
	_motion_time += delta
	_animate(_motion_time)
	var target := 1.0 if _grid_emphasized else 0.0
	if _grid_emphasis != target:
		_grid_emphasis = move_toward(_grid_emphasis, target, GRID_FADE_SPEED * delta)
		_grid.set_shader_parameter(&"emphasis", _grid_emphasis)


## 泉の波紋とポータルの渦を、時刻 t（秒）の形にする。泉とポータルを、止まった絵でなく動きで見分けられるようにする。
## ゆっくり繰り返すだけで、目を引きすぎない（駒や塗ったマスより目立たせない）。
func _animate(t: float) -> void:
	for ripple: Array in _ripples:
		var phase := fposmod(t / RIPPLE_PERIOD + float(ripple[2]), 1.0)
		var node: MeshInstance3D = ripple[0]
		node.scale = Vector3(lerpf(0.25, 1.0, phase), 0.4, lerpf(0.25, 1.0, phase))
		(ripple[1] as StandardMaterial3D).albedo_color.a = RIPPLE_ALPHA * sin(phase * PI)
	for mote: Array in _motes:
		var phase := fposmod(t / MOTE_PERIOD + float(mote[2]), 1.0)
		var angle := TAU * (phase * 1.3 + float(mote[2]))
		var radius := lerpf(0.34, 0.1, phase)
		var node: MeshInstance3D = mote[0]
		node.position = (mote[1] as Vector3) + Vector3(cos(angle) * radius, 0.05 + phase * MOTE_RISE, sin(angle) * radius)
		node.scale = Vector3.ONE * lerpf(1.0, 0.3, phase)
	var pulse := 0.5 + 0.5 * sin(t * TAU / PORTAL_PULSE_PERIOD)
	for disc: Array in _portal_discs:
		(disc[0] as StandardMaterial3D).albedo_color.a = lerpf(0.3, 0.6, pulse)


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


## 盤の上の効果を描く。盾は持ち主の色の堅い板、煙幕は灰色の靄、聖域は持ち主の色の淡い光の床。
## どれもマスの上、駒の下（聖域と煙幕の床は駒の足元より低く、煙幕の靄は駒を包む高さで薄く）。
func add_field_effect(effect_id: int, type: FieldEffect.Type, side: Unit.Side, cells: Array[Vector2i]) -> void:
	remove_field_effect(effect_id)
	var root := Node3D.new()
	add_child(root)
	_field_effects[effect_id] = root
	var color: Color = _team_colors[side] if side < _team_colors.size() else Color.WHITE
	match type:
		FieldEffect.Type.BARRICADE:
			var wall := BoxMesh.new()
			wall.size = Vector3(0.86, 0.7, 0.86)
			var post := BoxMesh.new()
			post.size = Vector3(0.94, 0.08, 0.94)
			for cell in cells:
				_add_part(root, wall, _material(color.darkened(0.15)), cell_center(cell) + Vector3(0.0, 0.35, 0.0))
				_add_part(root, post, _material(color.lightened(0.35)), cell_center(cell) + Vector3(0.0, 0.72, 0.0))
		FieldEffect.Type.SMOKE:
			var floor_mesh := BoxMesh.new()
			floor_mesh.size = Vector3(1.0, 0.02, 1.0)
			var puff := SphereMesh.new()
			puff.radius = 0.42
			puff.height = 0.5
			var haze := _overlay_material(COLOR_SMOKE)
			var thin := _overlay_material(Color(COLOR_SMOKE, 0.25))
			for cell in cells:
				_add_part(root, floor_mesh, haze, cell_center(cell) + Vector3(0.0, 0.02, 0.0))
				_add_part(root, puff, thin, cell_center(cell) + Vector3(0.0, 0.35, 0.0))
		FieldEffect.Type.SANCTUARY:
			var floor_mesh := BoxMesh.new()
			floor_mesh.size = Vector3(1.0, 0.02, 1.0)
			var glow := _overlay_material(Color(color.lightened(0.5), 0.35))
			glow.emission_enabled = true
			glow.emission = color.lightened(0.5)
			for cell in cells:
				_add_part(root, floor_mesh, glow, cell_center(cell) + Vector3(0.0, 0.015, 0.0))
	if type != FieldEffect.Type.BARRICADE:
		for part: GeometryInstance3D in root.get_children():
			part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## 消えた効果を取り除く。
func remove_field_effect(effect_id: int) -> void:
	if _field_effects.has(effect_id):
		_field_effects[effect_id].queue_free()
		_field_effects.erase(effect_id)


## 描かれている効果の番号（小さい順）。検査用。
func field_effect_ids() -> Array[int]:
	var ids: Array[int] = []
	ids.assign(_field_effects.keys())
	ids.sort()
	return ids


static func cell_center(cell: Vector2i) -> Vector3:
	return Vector3(cell.x + 0.5, 0.0, cell.y + 0.5)


static func cell_of(point: Vector3) -> Vector2i:
	return Vector2i(floori(point.x), floori(point.z))


## マスを色で塗る（マス -> Color）。前に塗ったものは消える。空を渡すと全部消える。
## raised に入っているマス（マス -> 何か）は、駒の足元の円盤より上に塗る（駒が乗っていても、色が隠れない。攻撃の相手など）。
func show_cells(colors: Dictionary, raised := {}) -> void:
	_highlight.instance_count = colors.size()
	var i := 0
	for cell: Vector2i in colors:
		var lift := 0.05 if raised.has(cell) else 0.012
		_highlight.set_instance_transform(i, Transform3D(Basis.IDENTITY, cell_center(cell) + Vector3(0.0, lift, 0.0)))
		_highlight.set_instance_color(i, colors[cell])
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


## 地面（盤の外まで続く 1 枚の板）と、その上のマス目の線。
func _add_ground() -> void:
	var size := Vector2(board.size)
	var center := Vector3(size.x / 2.0, 0.0, size.y / 2.0)

	var ground := ShaderMaterial.new()
	ground.shader = GROUND_SHADER
	ground.set_shader_parameter(&"terrain_map", ImageTexture.create_from_image(terrain_image(board, _team_colors, look)))
	ground.set_shader_parameter(&"noise_map", _noise_texture())
	ground.set_shader_parameter(&"board_size", size)
	ground.set_shader_parameter(&"map_pad", float(MAP_PAD))
	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = size + Vector2.ONE * 2.0 * GROUND_REACH
	_add_mesh(ground_mesh, ground, center).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_grid = ShaderMaterial.new()
	_grid.shader = GRID_SHADER
	_grid.set_shader_parameter(&"board_size", size)
	# 塗ったマスや印より先に描く（線の上に色が乗る）。
	_grid.render_priority = -1
	var grid_mesh := PlaneMesh.new()
	grid_mesh.size = size + Vector2.ONE * 0.2
	_add_mesh(grid_mesh, _grid, center + Vector3(0.0, 0.006, 0.0)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


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

	_danger_stripes = _overlay_layer(_stripe_mesh(), _stripe_material())
	var edge_mesh := BoxMesh.new()
	edge_mesh.size = Vector3(1.0, 0.004, DANGER_EDGE_WIDTH)
	_danger_edges = _overlay_layer(edge_mesh, _overlay_material(COLOR_DANGER_EDGE))

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
static func _stripe_material() -> StandardMaterial3D:
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
	material.albedo_color = COLOR_DANGER_STRIPE
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


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
	# 水面に広がる波紋（白い細い輪。ずらして重ねる）。
	var ripple_mesh := TorusMesh.new()
	ripple_mesh.inner_radius = 0.33
	ripple_mesh.outer_radius = 0.36
	ripple_mesh.rings = 24
	ripple_mesh.ring_segments = 4
	for i in RIPPLES_PER_SPRING:
		var ripple_material := _overlay_material(Color(0.85, 0.95, 1.0, 0.0))
		var ripple := _add_mesh(ripple_mesh, ripple_material, center + Vector3(0.0, 0.035, 0.0))
		ripple.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_ripples.append([ripple, ripple_material, float(i) / RIPPLES_PER_SPRING])

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
	var disc_material := _overlay_material(Color(color, 0.45))
	_add_mesh(disc, disc_material, center + Vector3(0.0, 0.015, 0.0)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_portal_discs.append([disc_material, color])
	# 渦を巻いて昇る光の粒。
	var mote_mesh := BoxMesh.new()
	mote_mesh.size = Vector3.ONE * 0.07
	var mote_material := _flat_material(color.lightened(0.35))
	for i in MOTES_PER_PORTAL:
		var mote := _add_mesh(mote_mesh, mote_material, center)
		mote.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_motes.append([mote, center, float(i) / MOTES_PER_PORTAL])
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
