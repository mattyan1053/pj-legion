extends "res://game/board_view/board_marks.gd"
## 盤面の見た目。ルールの盤面（Board）を受け取って、地面・障害物と森の置物（マップの見た目のもの）・結晶泉・本陣の旗と、
## 環境オブジェクト（起爆樽・回復の泉・ポータル）を組み立てる。盤の上の効果（盾・煙幕・聖域）も描く。
##
## 地面は、盤の外まで続く 1 枚の板（ground.gdshader）。マスごとの板は並べない。マス目は、その上に重ねる線（grid.gdshader）で、
## ふだんは薄く、操作しているときとマウスの周りだけ濃くする。盤の外の景色は scenery.gd。
##
## マスの色分け（移動範囲・攻撃できる相手など）と、マウスの下のマスの印もここで出す。
## 何を塗るかは呼ぶ側が決める（ここはルールを持たない）。
##
## ここは、組み立て（setup）、マス目の濃さ、毎フレームの動きだけ。見た目の種類ごとのファイル（game/board_view/board_*.gd）:
## 地面と置物（board_terrain）、環境オブジェクトと盤の上の効果（board_objects）、マスの塗りと目印（board_marks）。
## 読み込み・調整値・状態と、形と材質を作る道具は board_base。ファイルは board_base.gd からこの順に継いで積み重なり、
## このファイルが最後（前のファイルは、後のファイルの関数を呼べない）。


## look_seed は見た目だけに使う（木の種類・向き・大きさ）。team_colors は本陣の色（添字がプレイヤー番号）。
## look_name は見た目（地面・置物・景色）の名前（stage_look.gd）。
func setup(battle_board: Board, look_seed: int, team_colors: Array[Color], look_name: StringName = StageLook.DEFAULT) -> void:
	board = battle_board
	look = StageLook.of(look_name)
	_team_colors = team_colors
	var rng := RandomNumberGenerator.new()
	rng.seed = look_seed

	_add_ground()
	var scenery := Scenery.new()
	add_child(scenery)
	scenery.setup(board.size, look_seed, look)

	var crystal_mesh := CrystalMesh.build()
	var crystal_material := StageLook.crystal_material(look[StageLook.CRYSTAL])
	var obstacle_spec: Dictionary = look[StageLook.OBSTACLE_PROPS]
	if obstacle_spec.style == StageLook.CRAG:
		_add_crags(obstacle_spec, look_seed)

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
					_occluders[cell] = _add_cell_props(look[StageLook.FOREST_PROPS], cell, rng)
				Terrain.Type.OBSTACLE:
					if obstacle_spec.style != StageLook.CRAG:
						_occluders[cell] = _add_cell_props(obstacle_spec, cell, rng)
				Terrain.Type.FONT:
					_add_crystals(crystal_mesh, crystal_material, center, rng)

	for cell in board.barrel_cells:
		_add_barrel(cell, rng)
	for cell in board.spring_cells:
		_add_spring(cell)
	for cell in board.battery_cells:
		_add_battery(cell)
	_stronghold_cloth = null
	_stronghold_flag.clear()
	_stronghold_label = null
	if board.stronghold_cell != Board.NO_CELL:
		_add_stronghold(board.stronghold_cell)
	for cell: Vector2i in board.portal_exits:
		_add_portal(cell, portal_color(board, cell))
	for effect in board.field_effects:
		add_field_effect(effect.id, effect.type, effect.side, effect.cells)

	_build_markers()


## マス目の線を濃くする（駒を選んでいる、範囲を見せているなど、操作している間）。ふだんは薄い。
func set_grid_emphasis(on: bool) -> void:
	_grid_emphasized = on


## マス目の線を出す・隠す（盤を景色として見せるだけの背景では隠す）。
func set_grid_visible(on: bool) -> void:
	_grid_instance.visible = on


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
