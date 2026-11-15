extends Node3D
## 盤面を斜めに見下ろすカメラ。
##
## このノード自身が「見ている地点」で、盤面の上を平行移動する。
## 向きはマウスのドラッグで好きなだけ回す（rotate_by。呼ぶ側がドラッグを見分ける）か、Q / E で 90 度ずつ回す。
## 角度は 3 段階、距離はホイールで変える。

const PITCH_PRESETS: Array[float] = [35.0, 50.0, 68.0]
const MIN_DISTANCE := 8.0
const MAX_DISTANCE := 45.0
const PAN_SPEED := 14.0
const SMOOTHING := 10.0

## カメラが見てよい範囲（盤面の x / z）。
var bounds := Rect2(0.0, 0.0, 30.0, 30.0)
var camera: Camera3D

var _pivot: Node3D
var _target_yaw := 0.0
var _pitch_index := 1
var _target_distance := 22.0
## 寄っていく先（focus_on で決める）。手で動かしたら、寄るのをやめる。
var _focus: Vector3
var _focusing := false


func _ready() -> void:
	_pivot = Node3D.new()
	add_child(_pivot)
	_pivot.rotation_degrees.x = -PITCH_PRESETS[_pitch_index]

	camera = Camera3D.new()
	camera.fov = 35.0
	camera.far = 300.0
	camera.position.z = _target_distance
	_pivot.add_child(camera)
	camera.make_current()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_Q:
				_target_yaw -= PI / 2.0
			KEY_E:
				_target_yaw += PI / 2.0
			KEY_R:
				_pitch_index = (_pitch_index + 1) % PITCH_PRESETS.size()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_target_distance = maxf(MIN_DISTANCE, _target_distance * 0.9)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_target_distance = minf(MAX_DISTANCE, _target_distance * 1.1)


## 向きを radians だけ回す（マウスのドラッグ）。
func rotate_by(radians: float) -> void:
	_target_yaw += radians


## 回していく先の向き（ラジアン）。
func target_yaw() -> float:
	return _target_yaw


## point が画面の中央に来るよう、なめらかに寄る。
func focus_on(point: Vector3) -> void:
	_focus = Vector3(point.x, 0.0, point.z)
	_focusing = true


func _process(delta: float) -> void:
	_pan(delta)

	var weight := 1.0 - exp(-SMOOTHING * delta)
	if _focusing:
		position = position.lerp(_focus, weight * 0.6)
		if position.distance_to(_focus) < 0.02:
			_focusing = false
	rotation.y = lerpf(rotation.y, _target_yaw, weight)
	_pivot.rotation_degrees.x = lerpf(
		_pivot.rotation_degrees.x, -PITCH_PRESETS[_pitch_index], weight
	)
	camera.position.z = lerpf(camera.position.z, _target_distance, weight)


func _pan(delta: float) -> void:
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
	# 画面の上下左右に合わせて動くよう、いまの向きで回す。
	var move := input.normalized().rotated(Vector3.UP, rotation.y)
	position += move * PAN_SPEED * delta
	position.x = clampf(position.x, bounds.position.x, bounds.end.x)
	position.z = clampf(position.z, bounds.position.y, bounds.end.y)
