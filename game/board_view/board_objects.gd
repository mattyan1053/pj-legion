extends "res://game/board_view/board_terrain.gd"
## 盤面の環境オブジェクト（起爆樽・回復の泉・砲台・拠点・ポータル）と、盤の上の効果（盾・煙幕・聖域）。


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
	var rim_instance := _add_mesh(rim, _material(look[StageLook.SPRING_STONE]), center + Vector3(0.0, 0.02, 0.0))
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
	_add_mesh(post, _material(look[StageLook.SPRING_STONE]), foot + Vector3(0.0, 0.5, 0.0))
	var bar := BoxMesh.new()
	bar.size = Vector3(0.3, 0.1, 0.05)
	var cross := _flat_material(COLOR_SPRING_CROSS)
	_add_mesh(bar, cross, foot + Vector3(0.0, 1.1, 0.0))
	_add_mesh(bar, cross, foot + Vector3(0.0, 1.1, 0.0)).rotation.z = PI / 2.0


## 砲台（選べる決まり）。駒が上に立つので平たく作る（石の台と、橙の縁）。駒が乗っていても分かるよう、隅に砲身と橙の札を立てる。
func _add_battery(cell: Vector2i) -> void:
	var center := cell_center(cell)
	var base := CylinderMesh.new()
	base.top_radius = 0.44
	base.bottom_radius = 0.47
	base.height = 0.05
	base.radial_segments = 8
	_add_mesh(base, _material(COLOR_BATTERY_BASE), center + Vector3(0.0, 0.025, 0.0))
	var ring := TorusMesh.new()
	ring.inner_radius = 0.40
	ring.outer_radius = 0.45
	ring.rings = 16
	ring.ring_segments = 4
	_add_mesh(ring, _flat_material(COLOR_BATTERY_MARK), center + Vector3(0.0, 0.055, 0.0)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var foot := center + Vector3(0.4, 0.0, -0.4)
	var mount := BoxMesh.new()
	mount.size = Vector3(0.16, 0.3, 0.16)
	_add_mesh(mount, _material(COLOR_BATTERY_GUN), foot + Vector3(0.0, 0.15, 0.0))
	var gun := CylinderMesh.new()
	gun.top_radius = 0.045
	gun.bottom_radius = 0.06
	gun.height = 0.5
	var barrel := _add_mesh(gun, _material(COLOR_BATTERY_GUN), foot + Vector3(-0.08, 0.42, 0.08))
	barrel.rotation = Vector3(deg_to_rad(55.0), deg_to_rad(-45.0), 0.0)
	var post := CylinderMesh.new()
	post.top_radius = 0.025
	post.bottom_radius = 0.025
	post.height = 1.0
	var flag_foot := center + Vector3(-0.4, 0.0, -0.4)
	_add_mesh(post, _material(COLOR_BATTERY_GUN), flag_foot + Vector3(0.0, 0.5, 0.0))
	var plate := BoxMesh.new()
	plate.size = Vector3(0.26, 0.16, 0.05)
	_add_mesh(plate, _flat_material(COLOR_BATTERY_MARK), flag_foot + Vector3(0.0, 1.08, 0.0))


## 拠点。駒が上に立つので、床は平たく（黒い縁取りの輪と黄の輪、四隅の杭）。
## 駒が乗っていても分かるよう、奥の隅に高い旗竿を立てる。旗は白で、確保を進めた陣営の色に変わる（set_stronghold_side）。
func _add_stronghold(cell: Vector2i) -> void:
	var center := cell_center(cell)
	for ring_spec: Array in [[0.36, 0.49, COLOR_STRONGHOLD_EDGE, 0.03], [0.39, 0.46, COLOR_STRONGHOLD_MARK, 0.045]]:
		var ring := TorusMesh.new()
		ring.inner_radius = ring_spec[0]
		ring.outer_radius = ring_spec[1]
		ring.rings = 24
		ring.ring_segments = 4
		var instance := _add_mesh(ring, _flat_material(ring_spec[2]), center + Vector3(0.0, ring_spec[3], 0.0))
		instance.scale = Vector3(1.0, 0.35, 1.0)
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var stake := BoxMesh.new()
	stake.size = Vector3(0.09, 0.22, 0.09)
	var cap := BoxMesh.new()
	cap.size = Vector3(0.11, 0.05, 0.11)
	for corner: Vector2 in [Vector2(-1, 1), Vector2(1, 1), Vector2(1, -1)]:
		var foot := center + Vector3(corner.x, 0.0, corner.y) * 0.43
		_add_mesh(stake, _flat_material(COLOR_STRONGHOLD_EDGE), foot + Vector3(0.0, 0.11, 0.0))
		_add_mesh(cap, _flat_material(COLOR_STRONGHOLD_MARK), foot + Vector3(0.0, 0.245, 0.0))
	var pole := CylinderMesh.new()
	pole.top_radius = 0.03
	pole.bottom_radius = 0.035
	pole.height = 2.6
	var pole_foot := center + Vector3(-0.43, 0.0, -0.43)
	_add_mesh(pole, _flat_material(COLOR_STRONGHOLD_EDGE), pole_foot + Vector3(0.0, 1.3, 0.0))
	var knob := SphereMesh.new()
	knob.radius = 0.06
	knob.height = 0.12
	_add_mesh(knob, _flat_material(COLOR_STRONGHOLD_MARK), pole_foot + Vector3(0.0, 2.63, 0.0))
	var cloth_mesh := BoxMesh.new()
	cloth_mesh.size = Vector3(0.84, 0.5, 0.03)
	_stronghold_cloth = _flat_material(COLOR_STRONGHOLD_FLAG)
	_stronghold_pole_foot = pole_foot
	var cloth := _add_mesh(cloth_mesh, _stronghold_cloth, pole_foot + Vector3(0.44, STRONGHOLD_FLAG_LOW, 0.0))
	var border_mesh := BoxMesh.new()
	border_mesh.size = Vector3(0.9, 0.56, 0.02)
	var border := _add_mesh(border_mesh, _flat_material(COLOR_STRONGHOLD_EDGE), cloth.position)
	_stronghold_flag.assign([cloth, border])
	# 竿の上の数の札。駒や木に隠れないよう、いつも手前に描く。
	_stronghold_label = Label3D.new()
	_stronghold_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_stronghold_label.no_depth_test = true
	_stronghold_label.fixed_size = true
	_stronghold_label.pixel_size = STRONGHOLD_LABEL_PIXEL
	_stronghold_label.font_size = 40
	_stronghold_label.outline_size = 14
	_stronghold_label.outline_modulate = COLOR_STRONGHOLD_EDGE
	_stronghold_label.render_priority = 3
	_stronghold_label.outline_render_priority = 2
	_stronghold_label.position = pole_foot + Vector3(0.0, 3.05, 0.0)
	add_child(_stronghold_label)


## 拠点の確保の進み具合を見せる（拠点の無い盤では何もしない）: 旗を color にし、holds / needed の高さまで竿を上げ、
## 竿の上の札に「holds / needed」を出す（blocked なら、乗っている駒の確保が隣の敵で止まっていることを添える）。だれも確保していなければ（holds が 0）、旗は白で竿の下、札は「0 / needed」。
func set_stronghold_progress(holds: int, needed: int, color: Color, blocked := false) -> void:
	if _stronghold_cloth == null:
		return
	_stronghold_cloth.albedo_color = color
	var rate := clampf(float(holds) / maxf(needed, 1.0), 0.0, 1.0)
	for part in _stronghold_flag:
		part.position.y = _stronghold_pole_foot.y + lerpf(STRONGHOLD_FLAG_LOW, STRONGHOLD_FLAG_HIGH, rate)
	_stronghold_label.text = Text.t("battle.stronghold.mark_blocked" if blocked else "battle.stronghold.mark", {"holds": holds, "needed": needed})
	_stronghold_label.modulate = color.lightened(0.25) if holds > 0 else COLOR_STRONGHOLD_FLAG


## 拠点の竿の上の札の文（検査用。拠点が無ければ空）。
func stronghold_mark() -> String:
	return _stronghold_label.text if _stronghold_label != null else ""


## 拠点の旗の、竿の上での高さ（0 = いちばん下、1 = いちばん上。検査用。拠点が無ければ -1）。
func stronghold_flag_rate() -> float:
	if _stronghold_flag.is_empty():
		return -1.0
	return inverse_lerp(STRONGHOLD_FLAG_LOW, STRONGHOLD_FLAG_HIGH, _stronghold_flag[0].position.y - _stronghold_pole_foot.y)


## 拠点の旗の色（検査用。拠点が無ければ透明）。
func stronghold_flag_color() -> Color:
	return _stronghold_cloth.albedo_color if _stronghold_cloth != null else Color.TRANSPARENT


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
