extends Control
## 駒の姿の額（駒の詳細の窓。unit_detail.gd）。盤の駒の 3D の形（unit_view.gd）を、小さい 3D の枠に立たせて大きく見せる
## （会話の話し手の姿 talk_figure.gd と同じやり方。絵は描かない）。
## 額は沈んだ地に陣営の色の縁。後ろに、軍の国の紋を薄く大きく、足元に陣営の色の淡い光。
## 大きさは渡した大きさで決まり、中身では変わらない。

const RenderTone := preload("res://game/render_tone.gd")
const UnitView := preload("res://game/unit_view.gd")
const Palette := preload("res://game/ui_palette.gd")
const UiTheme := preload("res://game/ui_theme.gd")
const Crest := preload("res://game/crest.gd")

## 陣営（Unit.Side の値）の色。盤の駒と同じ。
const TEAM_COLORS: Array[Color] = [Palette.TEAM_BLUE, Palette.TEAM_RED, Palette.TEAM_NEUTRAL]
## カメラ: 縦の画角（度）、高さ、駒からの距離、見る高さ（talk_figure.gd と同じ。将の冠まで収まる）。
const FOV := 30.0
const CAMERA_HEIGHT := 1.05
const CAMERA_DISTANCE := 3.8
const LOOK_HEIGHT := 0.84
## 少し斜めを向かせる角度（ラジアン）。
const TURN := 0.38

var _holder: SubViewportContainer
var _crest: Crest
var _side := 0
var _shown: Array = []


func _init(frame_size := Vector2(220.0, 260.0)) -> void:
	custom_minimum_size = frame_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_crest = Crest.new(UnitKind.Army.NONE, frame_size.x * 0.95)
	_crest.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	_crest.visible = false
	add_child(_crest)


## kind の駒（evolved なら進化後の形。look は将の別の姿）を、陣営 side の色で立たせる。army は後ろの紋の国（NONE なら紋なし）。
func show_unit(kind: UnitKind.Id, side := 0, army := UnitKind.Army.NONE, evolved := false, look := &"") -> void:
	var key := [kind, side, army, evolved, look]
	if key == _shown:
		return
	_shown = key
	_side = clampi(side, 0, TEAM_COLORS.size() - 1)
	if UnitKind.is_neutral(kind):
		_side = Unit.Side.NEUTRAL
	_crest.visible = army != UnitKind.Army.NONE
	_crest.army = army
	_crest.tint = Color(Crest.color_of(army), 0.13)
	_crest.queue_redraw()
	if _holder != null:
		remove_child(_holder)
		_holder.queue_free()
	_holder = SubViewportContainer.new()
	_holder.stretch = true
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 3)
	add_child(_holder)
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	_holder.add_child(viewport)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.75, 0.78, 0.9)
	environment.ambient_light_energy = 0.6 * RenderTone.ambient_scale()
	var world := WorldEnvironment.new()
	world.environment = environment
	viewport.add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(deg_to_rad(-38.0), deg_to_rad(28.0), 0.0)
	light.light_energy = 1.2
	viewport.add_child(light)
	var camera := Camera3D.new()
	camera.fov = FOV
	camera.position = Vector3(0.0, CAMERA_HEIGHT, CAMERA_DISTANCE)
	viewport.add_child(camera)
	camera.look_at_from_position(camera.position, Vector3(0.0, LOOK_HEIGHT, 0.0))
	var view := UnitView.new()
	viewport.add_child(view)
	var hp := UnitKind.max_hp(kind)
	view.setup(kind, TEAM_COLORS[_side], hp, hp, look)
	if evolved:
		view.set_evolved(hp)
	view.rotation.y = TURN
	queue_redraw()


## いま立たせている駒（[種類, 陣営, 軍, 進化したか, 将の姿]。検査用）。
func shown() -> Array:
	return _shown


func _draw() -> void:
	var team := TEAM_COLORS[_side]
	var plate := UiTheme.box(Color(Palette.INK, 0.9), Color(team.lightened(0.15), 0.9), 2, 8, 0.0)
	draw_style_box(plate, Rect2(Vector2.ZERO, size))
	# 上から差す淡い光と、足元の陣営の色の光（駒が額の底に立って見える）。
	var top := Color(Palette.RAISED_HOVER, 0.5)
	draw_polygon(
		PackedVector2Array([Vector2(3.0, 3.0), Vector2(size.x - 3.0, 3.0), Vector2(size.x - 3.0, size.y * 0.45), Vector2(3.0, size.y * 0.45)]),
		PackedColorArray([top, top, Color(top, 0.0), Color(top, 0.0)]))
	var glow := Color(team, 0.3)
	draw_polygon(
		PackedVector2Array([Vector2(3.0, size.y * 0.6), Vector2(size.x - 3.0, size.y * 0.6), Vector2(size.x - 3.0, size.y - 3.0), Vector2(3.0, size.y - 3.0)]),
		PackedColorArray([Color(glow, 0.0), Color(glow, 0.0), glow, glow]))
