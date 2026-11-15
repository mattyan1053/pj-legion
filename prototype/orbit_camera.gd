extends Node3D
## 盤面を斜めに見下ろすカメラ。
##
## このノード自身が「見ている地点」で、盤面の上を平行移動する。
## マウスのドラッグ（drag。呼ぶ側がドラッグを見分ける）で、横の動きで向きを、縦の動きで見下ろす角度を同時に変える。
## キーでは、Q / E で 90 度ずつ回し、R で見下ろす角度を決まった段（PITCH_PRESETS）へ移す。距離はホイールで変える。

## 見下ろす角度（度。水平から下へ）の範囲。浅いほうは、盤の外が見えすぎない深さ。深いほうは、ほぼ真上。
const MIN_PITCH := 30.0
const MAX_PITCH := 85.0
## R で順に移る角度（度。浅い順）。
const PITCH_PRESETS: Array[float] = [35.0, 50.0, 68.0]
## 始めの見下ろす角度（度）。
const DEFAULT_PITCH := 50.0
const MIN_DISTANCE := 8.0
const MAX_DISTANCE := 45.0
const PAN_SPEED := 14.0
const SMOOTHING := 10.0

## ドラッグの感度の既定の値（1 px あたりのラジアン）。設定の「マウスの感度」の 100% がこれ。
const DEFAULT_DRAG_SENSITIVITY := 0.008

## カメラが見てよい範囲（盤面の x / z）。
var bounds := Rect2(0.0, 0.0, 30.0, 30.0)
var camera: Camera3D
## ドラッグの感度（1 px あたりのラジアン）。横（向き）にも縦（見下ろす角度）にも同じ値を使う。
## 設定の画面（settings.gd の「マウスの感度」）から変える。
var drag_sensitivity := DEFAULT_DRAG_SENSITIVITY
## 縦のドラッグの向きを逆にするか（設定の「縦のドラッグを逆にする」）。真なら、上へ動かすと真上に近づく。
var invert_vertical := false
## キー（Q・E・R、WASD・矢印）とホイールを受け付けるか。システムメニューを開いている間は偽にする。
var controls_enabled := true

var _pivot: Node3D
var _target_yaw := 0.0
## 見下ろす角度の行き先（度）。
var _target_pitch := DEFAULT_PITCH
var _target_distance := 22.0
## 寄っていく先（focus_on で決める）。手で動かしたら、寄るのをやめる。
var _focus: Vector3
var _focusing := false
## 追いかけている相手（follow で決める）。いる間は、毎フレームそこへ寄り続ける。手で動かしたら、追うのをやめる。
var _followed: Node3D


func _ready() -> void:
	_pivot = Node3D.new()
	add_child(_pivot)
	_pivot.rotation_degrees.x = -_target_pitch

	camera = Camera3D.new()
	camera.fov = 35.0
	camera.far = 300.0
	camera.position.z = _target_distance
	_pivot.add_child(camera)
	camera.make_current()


func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_Q:
				_target_yaw -= PI / 2.0
			KEY_E:
				_target_yaw += PI / 2.0
			KEY_R:
				_target_pitch = next_pitch_preset(_target_pitch)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_target_distance = maxf(MIN_DISTANCE, _target_distance * 0.9)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_target_distance = minf(MAX_DISTANCE, _target_distance * 1.1)


## マウスのドラッグで relative（px）だけ動かした。盤を掴んで動かす向きに回す。
## 右へ動かすと盤が右へ回り（カメラは左へ回り込む）、下へ動かすと盤の奥がこちらへ倒れる（真上からの見下ろしに近づく）。
## invert_vertical が真なら、縦だけ逆（上へ動かすと真上に近づく）。
func drag(relative: Vector2) -> void:
	_target_yaw -= relative.x * drag_sensitivity
	var vertical := -relative.y if invert_vertical else relative.y
	_target_pitch = clampf(_target_pitch + rad_to_deg(vertical * drag_sensitivity), MIN_PITCH, MAX_PITCH)


## 回していく先の向き（ラジアン）。
func target_yaw() -> float:
	return _target_yaw


## 傾けていく先の見下ろす角度（度）。
func target_pitch() -> float:
	return _target_pitch


## いまの見下ろす角度（度。動いている途中の値）。
func current_pitch() -> float:
	return -_pivot.rotation_degrees.x


## 見下ろす角度を pitch（度）にする（範囲に収める）。スクリーンショットの道具用。
func set_pitch(pitch: float) -> void:
	_target_pitch = clampf(pitch, MIN_PITCH, MAX_PITCH)


## R で移る先: pitch より深い段のうち、いちばん浅いもの。いちばん深い段より深ければ、いちばん浅い段へ戻る。
## ドラッグで段の間にしていても、そこから次の段へ進む。
static func next_pitch_preset(pitch: float) -> float:
	for preset in PITCH_PRESETS:
		if preset > pitch + 0.5:
			return preset
	return PITCH_PRESETS[0]


## point が画面の中央に来るよう、なめらかに寄る。
func focus_on(point: Vector3) -> void:
	_focus = Vector3(point.x, 0.0, point.z)
	_focusing = true


## point が画面の中央に来るよう、すぐに移る（時間を止めている間にも使える。ログの行を選んだとき）。
func jump_to(point: Vector3) -> void:
	position.x = clampf(point.x, bounds.position.x, bounds.end.x)
	position.z = clampf(point.z, bounds.position.y, bounds.end.y)
	_focusing = false


## target を追いかける（動いている駒が画面の外へ出ていかないように）。null を渡すと、追うのをやめる（その場に止まる）。
func follow(target: Node3D) -> void:
	_followed = target


## 寄っていく先（追いかけている間は、相手のいるところ）。寄っていなければ、いまの位置。検査用。
func focus_point() -> Vector3:
	return _focus if _focusing else position


func _process(delta: float) -> void:
	_pan(delta)

	var weight := 1.0 - exp(-SMOOTHING * delta)
	if _followed != null:
		if is_instance_valid(_followed):
			focus_on(_followed.position)
		else:
			_followed = null
	if _focusing:
		position = position.lerp(_focus, weight * 0.6)
		if position.distance_to(_focus) < 0.02:
			_focusing = false
	rotation.y = lerpf(rotation.y, _target_yaw, weight)
	_pivot.rotation_degrees.x = lerpf(
		_pivot.rotation_degrees.x, -_target_pitch, weight
	)
	camera.position.z = lerpf(camera.position.z, _target_distance, weight)


func _pan(delta: float) -> void:
	if not controls_enabled:
		return
	var input := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		input.z -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		input.z += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		input.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		input.x += 1.0
	if input == Vector3.ZERO:
		return

	_focusing = false
	_followed = null
	# 画面の上下左右に合わせて動くよう、いまの向きで回す。
	var move := input.normalized().rotated(Vector3.UP, rotation.y)
	position += move * PAN_SPEED * delta
	position.x = clampf(position.x, bounds.position.x, bounds.end.x)
	position.z = clampf(position.z, bounds.position.y, bounds.end.y)
