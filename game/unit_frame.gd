extends Control
## 駒のアイコンの額。沈んだ地に真鍮の縁の小さな額へ、駒のアイコン（unit_icons.gd）を入れる。
## 右下の隅に、役割の印（role_mark.gd）を重ねられる。選ばれているときは、縁を金にする。
## 大きさは渡した辺の長さで決まり、中身では変わらない。

const Palette := preload("res://game/ui_palette.gd")
const UiTheme := preload("res://game/ui_theme.gd")
const UnitIcons := preload("res://game/unit_icons.gd")
const RoleMark := preload("res://game/role_mark.gd")

var _icon: TextureRect
var _mark: RoleMark
var _show_role: bool
## 縁の色（透明なら、ふつうの枠の色）。国や陣営の色にするときに渡す。
var edge := Color(0, 0, 0, 0):
	set(value):
		edge = value
		queue_redraw()
var chosen := false:
	set(value):
		chosen = value
		queue_redraw()


func _init(kind: UnitKind.Id = UnitKind.Id.KING, side := 0, frame_size := 48.0, show_role := true, evolved := false) -> void:
	custom_minimum_size = Vector2(frame_size, frame_size)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_show_role = show_role
	_icon = UnitIcons.rect(kind, side, evolved, frame_size)
	_icon.custom_minimum_size = Vector2.ZERO
	_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 2)
	add_child(_icon)
	var mark_size := clampf(frame_size * 0.4, 14.0, 22.0)
	_mark = RoleMark.new(UnitKind.Role.NONE, mark_size)
	_mark.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_mark.offset_left = -mark_size + 3.0
	_mark.offset_top = -mark_size + 3.0
	_mark.offset_right = 3.0
	_mark.offset_bottom = 3.0
	add_child(_mark)
	set_kind(kind, side, evolved)


## 入れる駒を替える（大きさは変わらない）。
func set_kind(kind: UnitKind.Id, side := 0, evolved := false) -> void:
	_icon.texture = UnitIcons.texture(kind, side, evolved)
	_icon.set_meta(&"icon_kind", kind)
	_mark.role = UnitKind.role(kind) if _show_role else UnitKind.Role.NONE


func _draw() -> void:
	var rim := Palette.ACCENT if chosen else (edge if edge.a > 0.0 else Palette.BORDER)
	var plate := UiTheme.box(Color(Palette.INK, 0.85), rim, 2 if chosen else 1, 6, 0.0)
	draw_style_box(plate, Rect2(Vector2.ZERO, size))
	# 足元の淡い光（駒が額の底に立って見える）。
	var glow := Color(rim, 0.16)
	draw_polygon(
		PackedVector2Array([Vector2(3.0, size.y * 0.55), Vector2(size.x - 3.0, size.y * 0.55), Vector2(size.x - 3.0, size.y - 3.0), Vector2(3.0, size.y - 3.0)]),
		PackedColorArray([Color(glow, 0.0), Color(glow, 0.0), glow, glow]))
