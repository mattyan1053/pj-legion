extends Control
## 決着の画面の、後ろの光と粒（result_screen.gd が、幕と見出しの間に置く）。絵は使わない。
## - 勝ち（play に lit = true）: 見出しの後ろから差す光（上の真ん中から広がる、見出しの色の光）と、ゆっくり降る紙吹雪のような粒。
## - 負け（lit = false）: 画面を冷たい藍へ沈め、灰のような粒を、まばらに、ゆっくり降らせる。
## - 引き分け（stop）: 何も出さない。
## 入力は通す。見えていない間は、粒を出さない。

const Palette := preload("res://game/ui_palette.gd")

## 光の濃さ（真ん中）と、負けのときに沈める濃さ。
const LIGHT_ALPHA := 0.34
const SUNK_ALPHA := 0.3
## 粒の数（勝ち・負け）。
const CONFETTI := 70
const ASH := 22

var _light: TextureRect
var _sunk: ColorRect
var _particles: CPUParticles2D
var _playing := false


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sunk = ColorRect.new()
	_sunk.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sunk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sunk.color = Color(Palette.INK.lerp(Palette.TEAM_BLUE, 0.18), SUNK_ALPHA)
	add_child(_sunk)
	_light = TextureRect.new()
	_light.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_light.stretch_mode = TextureRect.STRETCH_SCALE
	_light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_light)
	_particles = CPUParticles2D.new()
	_particles.emitting = false
	_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_particles.direction = Vector2.DOWN
	_particles.spread = 18.0
	_particles.angular_velocity_min = -160.0
	_particles.angular_velocity_max = 160.0
	_particles.scale_amount_min = 3.0
	_particles.scale_amount_max = 7.0
	add_child(_particles)
	resized.connect(_place)
	visibility_changed.connect(_sync)


## 光と粒を出す。lit は勝ち（光と紙吹雪）か、負け（沈めて灰）か。color は見出しの色。
func play(lit: bool, color: Color) -> void:
	_playing = true
	_light.visible = lit
	_sunk.visible = not lit
	if lit:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		gradient.colors = PackedColorArray([Color(color, LIGHT_ALPHA), Color(color, LIGHT_ALPHA * 0.3), Color(color, 0.0)])
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.08)
		texture.fill_to = Vector2(0.5, 0.95)
		texture.width = 128
		texture.height = 128
		_light.texture = texture
	var ramp := Gradient.new()
	if lit:
		# 紙吹雪: 見出しの色、白、真鍮。
		ramp.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		ramp.colors = PackedColorArray([color.lightened(0.2), Color.WHITE, Palette.GOLD])
		_particles.amount = CONFETTI
		_particles.lifetime = 6.0
		_particles.gravity = Vector2(0.0, 26.0)
		_particles.initial_velocity_min = 30.0
		_particles.initial_velocity_max = 90.0
	else:
		ramp.offsets = PackedFloat32Array([0.0, 1.0])
		ramp.colors = PackedColorArray([Color(Palette.TEXT_OFF, 0.7), Color(Palette.TEXT_DIM, 0.5)])
		_particles.amount = ASH
		_particles.lifetime = 9.0
		_particles.gravity = Vector2(0.0, 8.0)
		_particles.initial_velocity_min = 14.0
		_particles.initial_velocity_max = 34.0
	_particles.color_initial_ramp = ramp
	_particles.preprocess = 0.0
	_particles.restart()
	_place()
	_sync()


## 何も出さない（引き分け）。
func stop() -> void:
	_playing = false
	_light.visible = false
	_sunk.visible = false
	_sync()


func _place() -> void:
	_particles.position = Vector2(size.x / 2.0, -12.0)
	_particles.emission_rect_extents = Vector2(size.x / 2.0, 4.0)


func _sync() -> void:
	_particles.emitting = _playing and is_visible_in_tree()
