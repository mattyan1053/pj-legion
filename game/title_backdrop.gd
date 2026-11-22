extends Node3D
## タイトルの背景。世界（docs/world.md）を 1 枚で見せる:
## 裂けた空（rift_sky.gdshader）の下の、結晶の森。裂け目の光を背にして、岩山と結晶と木立が影になる。
## 素材は足さない（盤と景色は対戦の画面の部品、空はシェーダー）。カメラは低く構えて、ゆっくり左右に振る。
##
## ストーリーの物語選択と話の一覧も、同じ景色を別の構え（view）で使う（同じ世界の続きに見せる）:
## - VIEW_TITLE: 縫い目を真ん中に、低く構える。
## - VIEW_STORY: 縫い目を真ん中に、少し高く、空を広く見上げる（左のカードが琥珀の空、右のカードが菫の空の下に来る）。
##
## 物語の景色（show_story / queue_story。物語選択・話の一覧・セーブデータ選択）: その物語の国の側の空へ向き（VIEW_BERG_MAP / VIEW_RUEL_MAP）、
## 空の色をその国の色へ寄せ（NATION_SKY）、地面は、その物語の話のマップの景色。物語ごとの違いが、空・地面・遠景で分かるようにする。
##
## 対戦モードのマップ選択と対戦設定も、同じ裂けた空の下に置く（VIEW_VERSUS）。地面と景色は、選んでいるマップのもの（show_scape で替える）。
## 高く構えて少し見下ろし、マップの地面と置物が、カードのまわりに見えるようにする。光は同じ裂け目の光で、霞にだけマップの空気の色を少し残す。

const RenderTone := preload("res://game/render_tone.gd")
const BattleScreen := preload("res://game/battle_screen.gd")
const BoardView := preload("res://game/board_view.gd")
const StageLook := preload("res://game/stage_look.gd")
const RIFT_SKY := preload("res://game/rift_sky.gdshader")
const Palette := preload("res://game/ui_palette.gd")

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
const VIEW_VERSUS := &"versus"
const VIEW_BERG_MAP := &"berg_map"
const VIEW_RUEL_MAP := &"ruel_map"
const VIEWS := {
	VIEW_VERSUS: [0.0, -7.0, 7.5],
	VIEW_BERG_MAP: [14.0, -4.0, 7.0],
	VIEW_RUEL_MAP: [-14.0, -4.0, 7.0],
	VIEW_TITLE: [0.0, CAMERA_TILT, CAMERA_HEIGHT],
	VIEW_STORY: [0.0, 15.0, 4.6],
}

## 国の空の色（裂けた空の左右の色。rift_sky.gdshader の left_tint / right_tint の既定と同じ）。物語の景色では、両側をその国の色へ寄せる。
const NATION_SKY := {UnitKind.Army.MILITARY: Color(0.80, 0.50, 0.28), UnitKind.Army.FANTASY: Color(0.50, 0.36, 0.86)}
const NATION_SKY_SHARE := 0.7
## 物語の景色を替えるとき（queue_story）: とどまってから替えるまで（秒）、幕を沈める・明ける長さ、幕の濃さ（マップ選択とそろえる）。
const SWAP_DELAY := 0.25
const SWAP_FADE_OUT := 0.12
const SWAP_FADE_IN := 0.35
const SWAP_CURTAIN := 0.75

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
## 空の色を寄せる国（UnitKind.Army。-1 なら寄せない）。
var _army := -1
## 物語の景色の名前（queue_story の key）。いま見せているものと、替えるのを待っているもの。
var _story_key: Variant = null
var _next_key: Variant = null
var _next: Array = []
var _swap_tween: Tween
## 景色を替えるときに、いちど沈める幕（替わる瞬間を見せない）。
var _curtain: ColorRect


## which は構え。board と look_name を渡すと、その盤と見た目の景色を見せる（対戦モードのマップ・物語の話のマップ。渡さなければ、いつもの結晶の森）。
## army を渡すと、空の色をその国へ寄せる（物語の景色）。
func _init(which := VIEW_TITLE, board: Board = null, look_name := StageLook.CRYSTAL_FOREST, army := -1) -> void:
	_view = which if VIEWS.has(which) else VIEW_TITLE
	_board = board
	_look = look_name
	_own_air = board != null
	_army = army


## 物語の景色の構え（軍 army の国の側の空へ向き、話のマップを見下ろす。MILITARY はベルク連邦の琥珀 = 縫い目の左、
## FANTASY はリュエル騎士領の菫 = 右。縫い目は画面の端に見える）。
static func map_view_of(army: UnitKind.Army) -> StringName:
	return VIEW_RUEL_MAP if army == UnitKind.Army.FANTASY else VIEW_BERG_MAP


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
	var layer := CanvasLayer.new()
	layer.layer = 0  # 景色の上、場面の文字（ふつうの CanvasLayer）の下
	add_child(layer)
	_curtain = ColorRect.new()
	_curtain.color = Color(Palette.INK, 0.0)
	_curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_curtain)
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


## 物語の景色にする（いますぐ。幕は沈めない）。army が -1 なら、いつもの構え（VIEW_STORY の結晶の森、空の色も寄せない）。
## army があれば、その国の側の空へ向き、空の色をその国へ寄せ、地面は board・look_name の景色。key は景色の名前（同じなら替えない）。
## view を渡すと、その構えのまま景色だけを替える（タイトル。空の色も寄せない）。
func show_story(army: int, board: Board, look_name: StringName, key: Variant = null, view := &"") -> void:
	_story_key = key
	_army = army
	if view != &"" and board != null:
		_view = view
		_board = board
		_look = look_name
		_own_air = true
	elif army < 0 or board == null:
		_view = VIEW_STORY
		_board = BoardGenerator.generate(BoardGenerator.Stage.TWIN_SPRINGS, LOOK_SEED)
		_look = StageLook.CRYSTAL_FOREST
		_own_air = false
	else:
		_view = map_view_of(army as UnitKind.Army)
		_board = board
		_look = look_name
		_own_air = true
	if is_inside_tree():
		_build_scape()
		_aim()


## 物語の景色を替える。カードの上を通り過ぎるだけでは替えない（SWAP_DELAY 秒とどまったら、幕を沈めて替える）。
## いま見せている（か、替えるのを待っている）景色と key が同じなら、何もしない。
func queue_story(army: int, board: Board, look_name: StringName, key: Variant) -> void:
	if key == _next_key or (_next_key == null and key == _story_key):
		return
	_next_key = key
	_next = [army, board, look_name, &""]
	if _swap_tween != null:
		_swap_tween.kill()
	_swap_tween = create_tween()
	_swap_tween.tween_interval(SWAP_DELAY)
	_swap_tween.tween_property(_curtain, "color:a", SWAP_CURTAIN, SWAP_FADE_OUT)
	_swap_tween.tween_callback(_swap_story)
	_swap_tween.tween_property(_curtain, "color:a", 0.0, SWAP_FADE_IN)


## カードから離れた: まだ待っている間（幕を沈め始める前）なら、景色を替えるのをやめる（通り過ぎただけでは替えない）。
## 幕がもう沈み始めていたら、そのまま替える（途中で戻すと、ちらつく）。
func cancel_queued() -> void:
	if _next_key == null or _curtain == null or _curtain.color.a > 0.0:
		return
	_next_key = null
	_next = []
	if _swap_tween != null:
		_swap_tween.kill()
		_swap_tween = null


func _swap_story() -> void:
	if _next.is_empty():
		return
	var key: Variant = _next_key
	var next := _next
	_next_key = null
	_next = []
	show_story(next[0], next[1], next[2], key, next[3])


## 景色を、いまの構えのまま board・look_name のものに替える（幕を沈めて。タイトルの、時間ごとの入れ替え）。
func queue_scape(board: Board, look_name: StringName, key: Variant) -> void:
	queue_story(-1, board, look_name, key)
	if not _next.is_empty():
		_next[3] = _view


## 待っている景色へ、待たずに替える（スクリーンショットの道具と検査用）。
func swap_now() -> void:
	if _swap_tween != null:
		_swap_tween.kill()
	_curtain.color.a = 0.0
	_swap_story()


## 物語の景色の名前（いま見せているもの。替えるのを待っていれば、これから見せるもの。検査用）。
func story_key() -> Variant:
	return _next_key if _next_key != null else _story_key


## 空の色を寄せている国（-1 なら寄せていない。検査用）。
func sky_army() -> int:
	return _army


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
	_tint_sky()
	_camera.position = Vector3(_board.size.x / 2.0, VIEWS[_view][2], _board.size.y + CAMERA_BACK)
	_sky_dome.position = _camera.position


## 空の左右の色を、国（_army）の色へ寄せる（寄せないなら、もとの琥珀と菫）。
func _tint_sky() -> void:
	var left: Color = NATION_SKY[UnitKind.Army.MILITARY]
	var right: Color = NATION_SKY[UnitKind.Army.FANTASY]
	if NATION_SKY.has(_army):
		left = left.lerp(NATION_SKY[_army], NATION_SKY_SHARE)
		right = right.lerp(NATION_SKY[_army], NATION_SKY_SHARE)
	_sky.set_shader_parameter(&"left_tint", left)
	_sky.set_shader_parameter(&"right_tint", right)


func _process(delta: float) -> void:
	_time += delta
	_aim()


func _aim() -> void:
	var yaw := deg_to_rad(SWAY) * sin(_time * TAU / SWAY_PERIOD)
	_camera.rotation = Vector3(deg_to_rad(VIEWS[_view][1]), deg_to_rad(VIEWS[_view][0]) + yaw, 0.0)
