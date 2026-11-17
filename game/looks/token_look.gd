extends "res://game/looks/look_set.gd"
## 駒の見た目の組「盤の駒」: ボードゲームの駒のような、抽象的な形（素材を使わず、コードで組む）。
##
## 駒は「台座 + 胴 + 頭」の同じ形で、何の駒かは記号で読ませる。
## - 役割: 前衛 = 前に大きい盾、後衛 = 長い銃（MILITARY）/ 光る玉の杖（FANTASY）、奇襲 = 両手の短剣（MILITARY）/ 背中の大剣（FANTASY）、
##   回復 = 胸と頭の上の白い十字。
## - 軍: 台座と頭の飾りの色と形（MILITARY = 鉄色の台座とヘルメット、FANTASY = 真鍮の台座と尖った帽子）。
## - 陣営: 胴の色（と足元の円盤）。魔物は骨の胴に、陣営の色の外套。
## - 将: 大きく、金の台座と外套。足元の印・冠は、どの組とも同じ（unit_view.gd）。
## 動きは token_body.gd の簡単な変形（跳ねる・突き出す・傾く・倒れる）。

const TokenBody := preload("res://game/looks/token_body.gd")

const STEEL := Color("59626d")
const STEEL_DARK := Color("3b4149")
const BRASS := Color("c49a45")
const GOLD := Color("e6bf4f")
const BONE := Color("e6dcc4")
const BONE_DARK := Color("a8997a")
const WOOD := Color("6b4a2e")
const EYE := Color("1b1414")
const CROSS := Color("f4f1e8")

## 種類ごとの形: [軍（"military"・"fantasy"・"monster"・"king"）, 記号, 大きさ]。
const KINDS := {
	UnitKind.Id.KING: ["king", &"king", 1.18],
	UnitKind.Id.SHIELD_TROOPER: ["military", &"shield", 1.0],
	UnitKind.Id.SNIPER: ["military", &"rifle", 1.0],
	UnitKind.Id.COMMANDO: ["military", &"knives", 1.0],
	UnitKind.Id.MEDIC: ["military", &"cross", 1.0],
	UnitKind.Id.PALADIN: ["fantasy", &"shield", 1.0],
	UnitKind.Id.SORCERER: ["fantasy", &"staff", 1.0],
	UnitKind.Id.SPELLBLADE: ["fantasy", &"greatsword", 1.0],
	UnitKind.Id.PRIEST: ["fantasy", &"cross", 1.0],
	UnitKind.Id.SKELETON: ["monster", &"sword", 0.92],
	UnitKind.Id.SKELETON_ARCHER: ["monster", &"bow", 1.0],
	UnitKind.Id.SKELETON_BRUTE: ["monster", &"shield", 1.22],
}
## 将の別の姿（unit_looks.gd の KING_LOOKS の名前 -> KINDS と同じ形）。
const KING_LOOKS := {
	&"skeleton_mage": ["monster_king", &"staff", 1.18],
}

## 全体の大きさ（台座の縁が、足元の円盤（半径 0.4）に収まる大きさ）。
const SCALE := 1.15
## 胴と頭の高さ（大きさ 1 のとき）。
const PEDESTAL_TOP := 0.15
const BODY_HEIGHT := 0.5
const HEAD_RADIUS := 0.13


func _init() -> void:
	icon_dir = "res://assets/unit_icons/tokens"


func build(kind: UnitKind.Id, team_color: Color, look: StringName, at: Vector3) -> UnitBody:
	var shape: Array = []
	if kind == UnitKind.Id.KING and KING_LOOKS.has(look):
		shape = KING_LOOKS[look]
	elif KINDS.has(kind):
		shape = KINDS[kind]
	else:
		return super(kind, team_color, look, at)
	var body := TokenBody.new()
	body.set_phase(at)
	var army: String = shape[0]
	var size: float = shape[2] * SCALE
	body.figure.scale = Vector3.ONE * size
	_assemble(body, army, shape[1], team_color)
	body.body_height = 1.02 * size
	return body


func _assemble(body: TokenBody, army: String, mark: StringName, team: Color) -> void:
	var f := body.figure
	var monster := army.begins_with("monster")
	var trim: Color = {"military": STEEL, "fantasy": BRASS, "king": GOLD}.get(army, BONE_DARK)
	if army == "monster_king":
		trim = GOLD
	# 台座（2 段）。
	body.part(f, _cylinder(0.3, 0.33, 0.07), trim.darkened(0.25), Vector3(0.0, 0.075, 0.0))
	body.part(f, _cylinder(0.25, 0.28, 0.05), trim, Vector3(0.0, 0.135, 0.0))
	var top := PEDESTAL_TOP
	# 胴。魔物は骨の細い胴に、陣営の色の外套を羽織る。
	var torso := team if not monster else BONE
	var wide := 1.25 if mark == &"shield" and monster else 1.0
	body.part(f, _cylinder(0.11 * wide, 0.2 * wide, BODY_HEIGHT), torso, Vector3(0.0, top + BODY_HEIGHT / 2.0, 0.0))
	body.part(f, _sphere(0.13 * wide, 0.12), torso.darkened(0.1), Vector3(0.0, top + BODY_HEIGHT, 0.0))
	if monster or army == "king":
		# 外套（背中に、陣営の色の円錐を半分）。
		var cloak := body.part(f, _cylinder(0.12, 0.25, 0.5), team.darkened(0.15), Vector3(0.0, top + 0.26, -0.07))
		cloak.scale = Vector3(1.0, 1.0, 0.6)
	# 頭。
	var head_y := top + BODY_HEIGHT + 0.14
	if monster:
		body.part(f, _sphere(HEAD_RADIUS, HEAD_RADIUS * 2.0), BONE, Vector3(0.0, head_y, 0.0))
		for side: float in [-1.0, 1.0]:
			body.part(f, _sphere(0.03, 0.04), EYE, Vector3(0.045 * side, head_y + 0.01, 0.11))
	else:
		body.part(f, _sphere(HEAD_RADIUS, HEAD_RADIUS * 2.0), team.lightened(0.45), Vector3(0.0, head_y, 0.0))
	# 頭の飾り（軍）。
	match army:
		"military":
			body.part(f, _hemisphere(HEAD_RADIUS + 0.02), STEEL, Vector3(0.0, head_y + 0.01, 0.0))
			body.part(f, _cylinder(0.17, 0.17, 0.02), STEEL_DARK, Vector3(0.0, head_y + 0.01, 0.0))
		"fantasy":
			var tall := 0.34 if mark == &"staff" else 0.24
			body.part(f, _cylinder(0.0, 0.15, tall), BRASS.darkened(0.2), Vector3(0.0, head_y + 0.06 + tall / 2.0, 0.0))
			body.part(f, _cylinder(0.17, 0.17, 0.02), BRASS, Vector3(0.0, head_y + 0.06, 0.0))
		"monster_king":
			body.part(f, _cylinder(0.0, 0.15, 0.34), team.darkened(0.35), Vector3(0.0, head_y + 0.23, 0.0))
			body.part(f, _cylinder(0.18, 0.18, 0.02), GOLD, Vector3(0.0, head_y + 0.06, 0.0))
	_add_mark(body, mark, army, team)


## 役割の記号。
func _add_mark(body: TokenBody, mark: StringName, army: String, team: Color) -> void:
	var f := body.figure
	var metal := STEEL if army != "fantasy" else BRASS
	match mark:
		&"shield":
			# 前に大きい盾。真ん中に陣営の色の印。
			var shield := Node3D.new()
			shield.position = Vector3(0.05, 0.42, 0.22)
			shield.rotation_degrees = Vector3(-8.0, 0.0, 0.0)
			f.add_child(shield)
			body.part(shield, _box(Vector3(0.34, 0.4, 0.05)), metal.lightened(0.15), Vector3.ZERO)
			body.part(shield, _box(Vector3(0.28, 0.34, 0.03)), team.darkened(0.1), Vector3(0.0, 0.0, 0.02))
			body.part(shield, _sphere(0.05, 0.06), metal.lightened(0.3), Vector3(0.0, 0.0, 0.04))
			if army == "monster":
				_add_axe(body, Vector3(-0.27, 0.45, 0.04))
		&"rifle":
			var rifle := Node3D.new()
			rifle.position = Vector3(0.16, 0.48, 0.12)
			rifle.rotation_degrees = Vector3(0.0, 0.0, 35.0)
			f.add_child(rifle)
			body.part(rifle, _box(Vector3(0.05, 0.78, 0.06)), STEEL_DARK, Vector3.ZERO)
			body.part(rifle, _box(Vector3(0.06, 0.24, 0.08)), WOOD, Vector3(0.0, -0.28, 0.0))
			body.part(rifle, _cylinder(0.035, 0.035, 0.2), Color("222629"), Vector3(0.0, 0.12, 0.06))
		&"knives":
			for side: float in [-1.0, 1.0]:
				var knife := Node3D.new()
				knife.position = Vector3(0.22 * side, 0.38, 0.12)
				knife.rotation_degrees = Vector3(-35.0, 0.0, -20.0 * side)
				f.add_child(knife)
				body.part(knife, _box(Vector3(0.05, 0.28, 0.015)), Color("d9dee4"), Vector3(0.0, 0.14, 0.0))
				body.part(knife, _box(Vector3(0.1, 0.03, 0.03)), STEEL_DARK, Vector3.ZERO)
				body.part(knife, _box(Vector3(0.04, 0.09, 0.04)), WOOD, Vector3(0.0, -0.06, 0.0))
		&"staff":
			var orb := team.lightened(0.3) if army != "monster_king" else Color("b06cff")
			body.part(f, _cylinder(0.022, 0.022, 0.95), WOOD, Vector3(0.27, 0.55, 0.06))
			body.part(f, _sphere(0.085, 0.17), orb, Vector3(0.27, 1.06, 0.06), Vector3.ZERO, true)
			body.part(f, _torus(0.07, 0.1), BRASS if army != "monster_king" else GOLD, Vector3(0.27, 1.0, 0.06))
		&"greatsword":
			var sword := Node3D.new()
			sword.position = Vector3(0.0, 0.55, -0.16)
			sword.rotation_degrees = Vector3(0.0, 0.0, 40.0)
			f.add_child(sword)
			body.part(sword, _box(Vector3(0.11, 0.78, 0.03)), Color("cfd8e6"), Vector3(0.0, 0.12, 0.0))
			body.part(sword, _box(Vector3(0.3, 0.05, 0.06)), BRASS, Vector3(0.0, -0.28, 0.0))
			body.part(sword, _box(Vector3(0.05, 0.16, 0.05)), WOOD, Vector3(0.0, -0.38, 0.0))
		&"cross":
			# 胸の十字と、頭の上に浮かぶ光る十字。
			body.part(f, _box(Vector3(0.06, 0.2, 0.03)), CROSS, Vector3(0.0, 0.43, 0.165), Vector3(-17.0, 0.0, 0.0))
			body.part(f, _box(Vector3(0.18, 0.06, 0.03)), CROSS, Vector3(0.0, 0.46, 0.16), Vector3(-17.0, 0.0, 0.0))
			var halo := Node3D.new()
			halo.position = Vector3(0.0, 1.13 if army == "fantasy" else 1.0, 0.0)
			f.add_child(halo)
			var glow := Color("bff7d9") if army == "military" else Color("fff1b0")
			body.part(halo, _box(Vector3(0.05, 0.17, 0.05)), glow, Vector3.ZERO, Vector3.ZERO, true)
			body.part(halo, _box(Vector3(0.15, 0.05, 0.05)), glow, Vector3(0.0, 0.025, 0.0), Vector3.ZERO, true)
		&"sword":
			var blade := Node3D.new()
			blade.position = Vector3(0.22, 0.4, 0.12)
			blade.rotation_degrees = Vector3(-30.0, 0.0, -10.0)
			f.add_child(blade)
			body.part(blade, _box(Vector3(0.06, 0.4, 0.02)), Color("b7bcc4"), Vector3(0.0, 0.2, 0.0))
			body.part(blade, _box(Vector3(0.14, 0.035, 0.04)), BONE_DARK, Vector3.ZERO)
		&"bow":
			var bow := Node3D.new()
			bow.position = Vector3(0.24, 0.48, 0.1)
			bow.rotation_degrees = Vector3(0.0, 90.0, 0.0)
			f.add_child(bow)
			var arc := body.part(bow, _torus(0.26, 0.29), WOOD, Vector3.ZERO, Vector3(90.0, 0.0, 0.0))
			arc.scale = Vector3(0.75, 1.0, 1.0)
			body.part(bow, _box(Vector3(0.01, 0.42, 0.01)), BONE, Vector3(0.0, 0.0, -0.04))
		&"king":
			# 将: 前に立てた大きい剣。
			var sword := Node3D.new()
			sword.position = Vector3(0.0, 0.42, 0.25)
			f.add_child(sword)
			body.part(sword, _box(Vector3(0.09, 0.5, 0.025)), Color("dfe5ee"), Vector3(0.0, -0.08, 0.0))
			body.part(sword, _box(Vector3(0.28, 0.05, 0.05)), GOLD, Vector3(0.0, 0.18, 0.0))
			body.part(sword, _box(Vector3(0.05, 0.12, 0.05)), WOOD, Vector3(0.0, 0.27, 0.0))
			body.part(sword, _sphere(0.04, 0.08), GOLD, Vector3(0.0, 0.35, 0.0))


func _add_axe(body: TokenBody, at: Vector3) -> void:
	var axe := Node3D.new()
	axe.position = at
	axe.rotation_degrees = Vector3(-15.0, 0.0, 15.0)
	body.figure.add_child(axe)
	body.part(axe, _cylinder(0.025, 0.025, 0.7), WOOD, Vector3.ZERO)
	body.part(axe, _box(Vector3(0.2, 0.18, 0.03)), Color("8c939b"), Vector3(-0.1, 0.25, 0.0))


# --- 形（同じ形は使い回す） ---

static var _meshes := {}


static func _cached(key: String, make: Callable) -> Mesh:
	if not _meshes.has(key):
		_meshes[key] = make.call()
	return _meshes[key]


static func _cylinder(top: float, bottom: float, height: float) -> Mesh:
	return _cached("cyl:%s:%s:%s" % [top, bottom, height], func() -> Mesh:
		var mesh := CylinderMesh.new()
		mesh.top_radius = top
		mesh.bottom_radius = bottom
		mesh.height = height
		mesh.radial_segments = 20
		mesh.rings = 1
		return mesh)


static func _sphere(radius: float, height: float) -> Mesh:
	return _cached("sph:%s:%s" % [radius, height], func() -> Mesh:
		var mesh := SphereMesh.new()
		mesh.radius = radius
		mesh.height = height
		mesh.radial_segments = 16
		mesh.rings = 8
		return mesh)


static func _hemisphere(radius: float) -> Mesh:
	return _cached("hemi:%s" % radius, func() -> Mesh:
		var mesh := SphereMesh.new()
		mesh.radius = radius
		mesh.height = radius
		mesh.is_hemisphere = true
		mesh.radial_segments = 16
		mesh.rings = 6
		return mesh)


static func _box(size: Vector3) -> Mesh:
	return _cached("box:%s" % size, func() -> Mesh:
		var mesh := BoxMesh.new()
		mesh.size = size
		return mesh)


static func _torus(inner: float, outer: float) -> Mesh:
	return _cached("tor:%s:%s" % [inner, outer], func() -> Mesh:
		var mesh := TorusMesh.new()
		mesh.inner_radius = inner
		mesh.outer_radius = outer
		mesh.rings = 20
		mesh.ring_segments = 6
		return mesh)
