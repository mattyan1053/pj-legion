extends Node3D
## タイトルの背景。世界（「空の縫い目」。docs/story.md）を 1 枚で見せる:
## 裂けた空（rift_sky.gdshader）の下の、結晶の森。裂け目の光を背にして、岩山と結晶と木立が影になる。
## 素材は足さない（盤と景色は対戦の画面の部品、空はシェーダー）。カメラは低く構えて、ゆっくり左右に振る。
##
## ストーリーの物語選択と話の一覧も、同じ景色を別の構え（view）で使う（同じ世界の続きに見せる）:
## - VIEW_TITLE: 縫い目を真ん中に、低く構える。
## - VIEW_STORY: 縫い目を真ん中に、少し高く、空を広く見上げる（左のカードが琥珀の空、右のカードが菫の空の下に来る）。
## - VIEW_BERG / VIEW_RUEL: その国の側の空（縫い目の左の琥珀 / 右の菫）へ向き、縫い目は画面の端に見える。
##
## 対戦モードのマップ選択と対戦設定も、同じ裂けた空の下に置く（VIEW_VERSUS）。地面と景色は、選んでいるマップのもの（show_scape で替える）。
## 高く構えて少し見下ろし、マップの地面と置物が、カードのまわりに見えるようにする。光は同じ裂け目の光で、霞にだけマップの空気の色を少し残す。

const RenderTone := preload("res://game/render_tone.gd")
const BattleScreen := preload("res://game/battle_screen.gd")
const BoardView := preload("res://game/board_view.gd")
const StageLook := preload("res://game/stage_look.gd")
const RIFT_SKY := preload("res://game/rift_sky.gdshader")

## 盤の種（いつも同じ景色にする）。
const LOOK_SEED := 7
## 霞と地平の色、裂け目から差す光、まわりの光。
const HAZE := Color("6f6aa0")
const RIFT_LIGHT := Color("c9f1ff")
const AMBIENT := Color("7a7fc4")
## カメラ: 盤の手前の端から、盤の向こう（-Z）の空を見る。高さ、盤の端からの距離、見上げる角度、画角（度）。
const CAMERA_HEIGHT := 3.4
const CAMERA_BACK := 5.0
const CAMERA_TILT := 9.0
const CAMERA_FOV := 52.0
## 左右に振る幅（度）と、1 往復の秒数。
const SWAY := 3.5
const SWAY_PERIOD := 46.0
## 空の球の半径。
const SKY_RADIUS := 1800.0
## 入ったときに、裂け目の光が差してくるまでの秒数。
const REVEAL_TIME := 1.4

## 構え: [向き（度。正で左 = 琥珀の空へ）, 見上げる角度（度）, カメラの高さ]。
const VIEW_TITLE := &"title"
const VIEW_STORY := &"story"
const VIEW_BERG := &"berg"
const VIEW_RUEL := &"ruel"
const VIEW_VERSUS := &"versus"
const VIEWS := {
	VIEW_VERSUS: [0.0, -7.0, 7.5],
	VIEW_TITLE: [0.0, CAMERA_TILT, CAMERA_HEIGHT],
	VIEW_STORY: [0.0, 15.0, 4.6],
	VIEW_BERG: [24.0, 13.0, 4.2],
	VIEW_RUEL: [-24.0, 13.0, 4.2],
}

## マップの景色を見せるとき（show_scape）に、霞とまわりの光へ残す、そのマップの空気の色の割合（残りは裂け目の夕闇）。
const SCAPE_AIR := 0.4
## マップの景色を見せるときの、まわりの光の強さ（裂け目の逆光で、地面の色が沈みきらないように、タイトルより上げる）。
const SCAPE_AMBIENT_ENERGY := 0.8

var _camera: Camera3D
var _sky: ShaderMaterial
var _sky_dome: MeshInstance3D
var _scape: BoardView
var _time := 0.0
var _view := VIEW_TITLE
var _board: Board
var _look := StageLook.CRYSTAL_FOREST
## マップの景色を見せているか（偽なら、いつもの結晶の森。空気は裂け目の夕闇だけ）。
var _own_air := false


## which は構え。board と look_name を渡すと、その盤と見た目の景色を見せる（対戦モードのマップ。渡さなければ、いつもの結晶の森）。
func _init(which := VIEW_TITLE, board: Board = null, look_name := StageLook.CRYSTAL_FOREST) -> void:
	_view = which if VIEWS.has(which) else VIEW_TITLE
	_board = board
	_look = look_name
	_own_air = board != null


## 物語の軍の側の空を見る構え（MILITARY はベルク連邦の琥珀、FANTASY はリュエル騎士領の菫）。
static func view_of(army: UnitKind.Army) -> StringName:
	return VIEW_RUEL if army == UnitKind.Army.FANTASY else VIEW_BERG


## いまの構え（検査用）。
func shown_view() -> StringName:
	return _view


func _ready() -> void:
	StageLook.build_environment(self)
	var board_sky := get_node(StageLook.SKY_NODE)  # 盤の空は使わない（裂けた空を描く）
	remove_child(board_sky)
	board_sky.free()
	if _board == null:
		_board = BoardGenerator.generate(BoardGenerator.Stage.TWIN_SPRINGS, LOOK_SEED)

	_camera = Camera3D.new()
	_camera.fov = CAMERA_FOV
	_camera.far = SKY_RADIUS * 1.5
	add_child(_camera)

	_sky = ShaderMaterial.new()
	_sky.shader = RIFT_SKY
	_sky.set_shader_parameter(&"horizon", HAZE)
	_sky.set_shader_parameter(&"reveal", 0.0)
	_sky.set_shader_parameter(&"brightness", RenderTone.title_sky_brightness())
	var dome := SphereMesh.new()
	dome.radius = SKY_RADIUS
	dome.height = SKY_RADIUS * 2.0
	dome.radial_segments = 48
	dome.rings = 24
	_sky_dome = MeshInstance3D.new()
	_sky_dome.mesh = dome
	_sky_dome.material_override = _sky
	_sky_dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_sky_dome)
	_build_scape()
	create_tween().tween_method(func(value: float) -> void: _sky.set_shader_parameter(&"reveal", value), 0.0, 1.0, REVEAL_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_aim()


## 盤 board を見た目 look_name の景色で見せる（マップ選択で、選んでいるマップを替えたとき）。同じ見た目と大きさなら、何もしない。
func show_scape(board: Board, look_name: StringName) -> void:
	if look_name == _look and _own_air and _board != null and board.size == _board.size:
		return
	_board = board
	_look = look_name
	_own_air = true
	if is_inside_tree():
		_build_scape()


## いま見せている景色の見た目の名前（検査用）。
func shown_look() -> StringName:
	return _look


## 盤と景色を作り直し、空気（霞と光）を当て、カメラと空を盤の手前の端に置く。
func _build_scape() -> void:
	if _scape != null:
		remove_child(_scape)
		_scape.queue_free()
	_scape = BoardView.new()
	add_child(_scape)
	_scape.setup(_board, LOOK_SEED, BattleScreen.TEAM_COLORS, _look)
	_scape.set_grid_visible(false)
	# 空気は、マップのものから、裂け目の光の夕闇に替える（光は、裂け目のある -Z の空から、低く手前へ差す）。
	# マップの景色を見せるときは、霞とまわりの光に、そのマップの空気の色を少し残す。
	var look := _scape.look.duplicate()
	var air := SCAPE_AIR if _own_air else 0.0
	var haze := HAZE.lerp(look[StageLook.HAZE], air)
	look[StageLook.HAZE] = haze
	look[StageLook.SUN] = RIFT_LIGHT
	look[StageLook.AMBIENT] = AMBIENT.lerp(look[StageLook.AMBIENT], air)
	look[StageLook.SUN_PITCH] = -16.0
	look[StageLook.SUN_YAW] = 172.0
	look[StageLook.SUN_ENERGY] = 1.5
	look[StageLook.AMBIENT_ENERGY] = SCAPE_AMBIENT_ENERGY if _own_air else 0.5
	look.erase(StageLook.MIST)  # 霞の距離は、どのマップでも同じ（遠くの空と地平がつながるように）
	StageLook.apply(self, look)
	_sky.set_shader_parameter(&"horizon", haze)
	_camera.position = Vector3(_board.size.x / 2.0, VIEWS[_view][2], _board.size.y + CAMERA_BACK)
	_sky_dome.position = _camera.position


func _process(delta: float) -> void:
	_time += delta
	_aim()


func _aim() -> void:
	var yaw := deg_to_rad(SWAY) * sin(_time * TAU / SWAY_PERIOD)
	_camera.rotation = Vector3(deg_to_rad(VIEWS[_view][1]), deg_to_rad(VIEWS[_view][0]) + yaw, 0.0)
