extends Node3D
## 駒 1 体の見た目。
##
## 駒そのものの形と動き（体。unit_body.gd）は、いま使っている駒の見た目の組（unit_looks.gd）が作る。
## ここは、どの組でも同じに付けるもの（足元の円盤・HP の棒・進化と状態の輪・将の冠）と、行動済みの暗さ、倒れて消えるところを持つ。
## 陣営の色は、足元の円盤と、組が決める体の色の付け方で出す。
## 頭の上には、軍略の札（trait_mark.gd）のほかは何も出さない（駒の情報は、クリックかマウスを乗せて、画面の枠で確かめる）。
## 盤の上で分かるのは、足元だけ: 行動済みの駒は暗い。HP が減っている駒は、足元に小さい棒が出る（減っていなければ出ない）。
## 進化した駒は、足元の円盤を金の輪が囲む。状態（バリア、照準など）が付いている駒は、その外に水色の細い輪が出る。
##
## ルールは持たない。何を見せるかは、呼ぶ側（イベントを再生する側）が決める。

const UnitLooks := preload("res://game/unit_looks.gd")
const UnitBody := preload("res://game/unit_body.gd")
const PieceStyle := preload("res://game/piece_style.gd")
const GaugeSprite := preload("res://game/gauge_sprite.gd")
const TraitMark := preload("res://game/trait_mark.gd")

## 行動済みの駒は、この明るさまで暗くする。
const ACTED_SHADE := 0.42
const COLOR_GOLD := Color("f2c84b")
## 足元の円盤の半径と、縁の線の幅、外側の暗い線の色。
const BASE_RADIUS := 0.4
const BASE_EDGE := 0.035
const BASE_RIM_DARK := Color(0.06, 0.05, 0.08)
const BASE_EDGE_LIGHTEN := 0.55
const COLOR_STATUS := Color("7fe3ff")
## 軍略の輪（状態の輪の外。隣のマスの円盤には掛からない太さ）と、頭の上の札の高さ（頭の上から）。
const TRAIT_RING_INNER := 0.58
const TRAIT_RING_OUTER := 0.68
const TRAIT_TAG_LIFT := 0.12

var _body: UnitBody
var _kind: UnitKind.Id
var _team_color: Color
var _max_hp := 1
## いま持っている HP（減っていれば、足元の棒に出る）。検査用。
var shown_hp := 0
var _height := 1.3  # 駒の高さ（頭の上。将は冠まで）
var _acted := false
var _dying := false
var _base_material: StandardMaterial3D
## 足元の円盤の内側の明るい縁（行動済みで暗くする）。
var _base_edge: StandardMaterial3D
var _bar: Sprite3D
var _evolved_ring: MeshInstance3D
var _crowned := false
var _status_ring: MeshInstance3D
var _trait_ring: MeshInstance3D
var _trait_tag: TraitMark


## look は将の別の姿（unit_looks.gd の KING_LOOKS の名前。将でない駒には効かない）か、名前のある人物の形（PERSONS の名前。
## どの駒にも効く。組が形を持たなければ種類の形）。空か知らない名前なら、種類の形。
## look_set は駒の見た目の組の名前（空なら、いま使っている組。アイコンを写す道具が組を選ぶのに使う）。
func setup(kind: UnitKind.Id, team_color: Color, hp: int, max_hp: int, look := &"", look_set := &"") -> void:
	_kind = kind
	_team_color = team_color
	_max_hp = max_hp
	_add_base(team_color)
	var looks := UnitLooks.active() if look_set == &"" else UnitLooks.of(look_set)
	var shown_look := look if (kind == UnitKind.Id.KING and UnitLooks.KING_LOOKS.has(look)) or UnitLooks.PERSONS.has(look) else &""
	_body = looks.build(kind, team_color, shown_look, global_position if is_inside_tree() else position)
	_body.view = self
	add_child(_body)
	_height = _body.body_height
	PieceStyle.add_outline(_body)
	if kind == UnitKind.Id.KING:
		_add_crown()
	_add_bar()
	set_hp(hp)
	play_idle()


func play_idle() -> void:
	if not _dying:
		_body.play_idle()


## 話し始めの小さな身振り（会話の場面の話し手の姿。talk_figure.gd）。終われば立ち姿に戻る。
func play_gesture() -> void:
	_body.play_gesture()


func play_run() -> void:
	_body.play_run()


## 攻撃の動き。当たる瞬間までの秒数を返す（呼ぶ側がそこでダメージを見せる）。
func play_attack() -> float:
	return _body.play_attack()


func play_hit() -> void:
	_body.play_hit()


## 倒れる動きをして、自分を取り除く。終わるまで待てる。
func play_death() -> void:
	_dying = true
	_bar.visible = false
	if _trait_tag != null:
		_trait_tag.visible = false
	var wait := _body.play_death()
	if wait > 0.0:
		# 木の時計ではなく自分の子の Timer で待つ（場面を抜けてこの駒が消えたら、続きを走らない）。
		var timer := Timer.new()
		timer.one_shot = true
		timer.wait_time = wait
		add_child(timer)
		timer.start()
		await timer.timeout
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE * 0.01, 0.3)
	await tween.finished
	queue_free()


## 盤面上の向き（y は見ない）へ体を向ける。
func face(direction: Vector3) -> void:
	if Vector2(direction.x, direction.z).length() < 0.001:
		return
	rotation.y = atan2(direction.x, direction.z)


## 駒の種類（演出の当たり方を決める）。
func unit_kind() -> UnitKind.Id:
	return _kind


## 駒の高さ（頭の上まで）。画面に占める四角を出すのに使う。
func height() -> float:
	return _height


## HP を変える。減っていれば、足元に小さい棒を出す（満タンなら出さない）。
func set_hp(hp: int) -> void:
	shown_hp = hp
	_bar.visible = hp < _max_hp and not _dying
	if not _bar.visible:
		return
	GaugeSprite.fill(_bar, float(hp) / _max_hp)


## レベルと最大 HP を変える（レベルアップ）。棒は次の set_hp で描き直す。
func set_growth(_level: int, max_hp: int) -> void:
	_max_hp = max_hp


## 最大 HP だけを変える（聖遺物）。棒は次の set_hp で描き直す。
func set_max_hp(max_hp: int) -> void:
	_max_hp = max_hp


## 進化した駒の最大 HP を変え、足元に金の輪を付ける。棒は次の set_hp で描き直す（進化先の名前は、駒の情報に出る）。
func set_evolved(max_hp: int) -> void:
	_max_hp = max_hp
	if _evolved_ring == null:
		_evolved_ring = _add_ring(0.41, 0.49, COLOR_GOLD)


## 状態（バリア、照準など）が付いているかを、足元の水色の輪で見せる（何の状態かは、駒の情報に出る）。
func set_status_mark(marked: bool) -> void:
	if marked and _status_ring == null:
		_status_ring = _add_ring(0.52, 0.56, COLOR_STATUS)
	if _status_ring != null:
		_status_ring.visible = marked


## 軍略が効く駒を、頭の上の札（増える数。trait_mark.gd）と、足元の外側の輪で見せる（色は軍略の軍の色。
## docs/troop-traits.md の「対戦の画面」）。marked が偽なら消す。text は札の文（「+2」）、kind は札の役（TraitMark.Kind）。
## 足元の輪は、拠点の竿・盾・選択の輪に埋もれることがある。札は頭の上で、いつも手前に描く。
func set_trait_mark(marked: bool, color := Color.WHITE, text := "", kind := TraitMark.Kind.TARGET) -> void:
	if marked and _trait_ring == null:
		_trait_ring = _add_ring(TRAIT_RING_INNER, TRAIT_RING_OUTER, color)
		_trait_tag = TraitMark.new()
		_trait_tag.position.y = _height + TRAIT_TAG_LIFT
		add_child(_trait_tag)
	if _trait_ring != null:
		_trait_ring.visible = marked
		(_trait_ring.material_override as StandardMaterial3D).albedo_color = color
		_trait_tag.visible = marked and not _dying
		if marked:
			_trait_tag.show_mark(text, color, kind)


## 軍略の輪が出ているか（検査用）。
func has_trait_mark() -> bool:
	return _trait_ring != null and _trait_ring.visible


## 頭の上の軍略の札の文（出ていなければ空。検査用）。
func trait_mark_text() -> String:
	return _trait_tag.text if _trait_tag != null and _trait_tag.visible else ""


## 頭の上の軍略の札の役（TraitMark.Kind。出ていなければ -1。検査用）。
func trait_mark_kind() -> int:
	return _trait_tag.kind if _trait_tag != null and _trait_tag.visible else -1


## 足元の輪（平たい輪。光に左右されない色）。
func _add_ring(inner: float, outer: float, color: Color) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 32
	mesh.ring_segments = 6
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var ring := MeshInstance3D.new()
	ring.mesh = mesh
	ring.material_override = material
	ring.scale = Vector3(1.0, 0.25, 1.0)
	ring.position.y = 0.03
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	return ring


## 行動済みの駒を暗くする。
func set_acted(acted: bool) -> void:
	if _acted == acted:
		return
	_acted = acted
	var shade := ACTED_SHADE if acted else 1.0
	_base_material.albedo_color = _team_color.darkened(1.0 - shade) if acted else _team_color
	_base_material.emission_energy_multiplier = 0.05 if acted else 0.4
	_body.set_shade(shade)
	_base_edge.albedo_color = _team_color.lightened(BASE_EDGE_LIGHTEN).darkened(1.0 - shade)


func _add_base(team_color: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = BASE_RADIUS
	mesh.bottom_radius = BASE_RADIUS
	mesh.height = 0.04
	_base_material = StandardMaterial3D.new()
	_base_material.albedo_color = team_color
	_base_material.emission_enabled = true
	_base_material.emission = team_color
	_base_material.emission_energy_multiplier = 0.4
	var base := MeshInstance3D.new()
	base.mesh = mesh
	base.material_override = _base_material
	base.position.y = 0.02
	base.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(base)
	# 円盤の縁: 内側に明るい線、外側に暗い線。範囲の色（白・橙・赤）の上でも、暗い地面の上でも、円盤の形が切れて見える。
	_base_edge = _add_flat_ring(BASE_RADIUS - BASE_EDGE, BASE_RADIUS, team_color.lightened(BASE_EDGE_LIGHTEN), 0.041)
	_add_flat_ring(BASE_RADIUS, BASE_RADIUS + BASE_EDGE, BASE_RIM_DARK, 0.035)


## 地面に寝た平たい輪（足元の円盤の縁）。光に左右されない色。
func _add_flat_ring(inner: float, outer: float, color: Color, lift: float) -> StandardMaterial3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 40
	mesh.ring_segments = 4
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var ring := MeshInstance3D.new()
	ring.mesh = mesh
	ring.material_override = material
	ring.scale = Vector3(1.0, 0.08, 1.0)
	ring.position.y = lift
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	return material


## 将の姿でない駒にも、将の目印を付ける（会話の姿。話のファイルの figure の crown）。もう付いていれば何もしない。
func show_crown() -> void:
	if not _crowned:
		_add_crown()


## 将の目印。頭の上に浮かぶ金の輪。
func _add_crown() -> void:
	_crowned = true
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.13
	mesh.outer_radius = 0.19
	mesh.rings = 20
	mesh.ring_segments = 6
	var material := StandardMaterial3D.new()
	material.albedo_color = COLOR_GOLD
	material.emission_enabled = true
	material.emission = COLOR_GOLD
	material.emission_energy_multiplier = 0.5
	var crown := MeshInstance3D.new()
	crown.mesh = mesh
	crown.material_override = material
	crown.position.y = _height - 0.02
	crown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(crown)
	_height += 0.2


## 足元の HP の棒。いつもカメラを向き、木や岩に隠れない。駒の体には重ねず、マスの手前の縁に出す。
func _add_bar() -> void:
	_bar = GaugeSprite.make()
	_bar.offset = Vector2(0.0, -GaugeSprite.SIZE.y * 2.0)
	_bar.position.y = 0.0
	_bar.visible = false
	add_child(_bar)
