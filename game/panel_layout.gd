extends RefCounted
## 駒のそばのメニューと、戦闘予測のパネルの置き場所（docs/battle-view.md の「駒のそばのメニュー」「戦闘予測のパネル」）。
## 盤面の上のものを画面に投影し、隠したくないもの（相手、届くマス、ほかの駒、情報の枠）を避ける側を選ぶ（menu_placement.gd）。
## カメラが動いたら置き直すので、回しても動かしても付いてくる。対戦の場面（battle_screen.gd）が 1 つ持ち、毎フレーム place_* を呼ぶ。

const MenuPlacement := preload("res://game/menu_placement.gd")
const BoardView := preload("res://game/board_view.gd")
const BattleHud := preload("res://game/battle_hud.gd")
const OrbitCamera := preload("res://game/orbit_camera.gd")
const UnitView := preload("res://game/unit_view.gd")

const NO_CELL := Vector2i(-1, -1)

## メニューが隠したくないものの重み（menu_placement.gd）。攻撃・回復・スキルの相手、ほかの駒、届くマス、情報の枠。
const MENU_WEIGHT_TARGET := 12.0
const MENU_WEIGHT_UNIT := 4.0
const MENU_WEIGHT_MOVE := 1.0
const MENU_WEIGHT_CRUISE := 0.4
const MENU_WEIGHT_PANEL := 6.0

## 塗ったマスのうち、動ける（青）・巡航でだけ届く（黄）マスの色。メニューは、ほかの色（相手など）より、これを隠してよい。
var move_color: Color
var cruise_color: Color

var _rig: OrbitCamera
var _hud: BattleHud
## 駒の番号 -> 駒の見た目（UnitView）。場面と同じ辞書。
var _views: Dictionary

var _menu_placement := MenuPlacement.new()
## メニューを置いたときのカメラ（動いたら置き直す）。
var _menu_camera := Transform3D()
var _menu_dirty := true
## 戦闘予測のパネルの置き場所（対象のマスのそば）。
var _forecast_placement := MenuPlacement.new()
var _forecast_cell := NO_CELL
var _forecast_camera := Transform3D()
## 予測のパネルを置いたときの、メニューの四角（メニューが動いたら置き直す）。
var _forecast_menu := Rect2()
var _forecast_dirty := true
var _forecast_avoid: Array[Vector2i] = []


func _init(rig: OrbitCamera, hud: BattleHud, views: Dictionary, move: Color, cruise: Color) -> void:
	_rig = rig
	_hud = hud
	_views = views
	move_color = move
	cruise_color = cruise


# ---- 駒のそばのメニュー ----


## 選ぶ駒が変わった: 前の駒で選んだ側をひいきしない。
func reset_menu() -> void:
	_menu_placement.reset()


## メニューの中身が変わった: 次の place_menu で、カメラが動いていなくても置き直す。
func mark_menu_dirty() -> void:
	_menu_dirty = true


## メニューを、選んでいる駒（unit）のそばに置く。painted は塗っているマス -> 色（隠したくないもの）。
func place_menu(unit: Unit, painted: Dictionary) -> void:
	var size := _hud.menu_size()
	if size == Vector2.ZERO or unit == null or not _views.has(unit.id):
		return
	var camera: Camera3D = _rig.camera
	if not _menu_dirty and camera.global_transform.is_equal_approx(_menu_camera):
		return
	_menu_dirty = false
	_menu_camera = camera.global_transform
	var view: UnitView = _views[unit.id]
	var anchor := screen_rect(view.position, 0.45, view.height())
	var obstacles: Array = []
	for cell: Vector2i in painted:
		var color: Color = painted[cell]
		var weight := MENU_WEIGHT_TARGET
		if color == move_color:
			weight = MENU_WEIGHT_MOVE
		elif color == cruise_color:
			weight = MENU_WEIGHT_CRUISE
		if cell != unit.cell:
			obstacles.append([screen_rect(BoardView.cell_center(cell), 0.4, 0.0), weight])
	for other_id: int in _views:
		if other_id != unit.id:
			var other: UnitView = _views[other_id]
			obstacles.append([screen_rect(other.position, 0.35, other.height()), MENU_WEIGHT_UNIT])
	if _hud.info_rect().has_area():
		obstacles.append([_hud.info_rect(), MENU_WEIGHT_PANEL])
	_hud.place_menu(_menu_placement.place(anchor, size, _hud.menu_area(), obstacles), anchor.get_center())


# ---- 戦闘予測のパネル ----


## 予測のパネルの対象のマスと、パネルで隠したくないマス（何かが起きる駒と、効果の及ぶマス）を決めて、置き直す。
## 対象のマスが変わったら、前のマスで選んだ側をひいきしない。
func set_forecast(battle: Battle, actor: Unit, cell: Vector2i, avoid: Array[Vector2i]) -> void:
	_forecast_avoid = avoid
	if cell != _forecast_cell:
		_forecast_placement.reset()
	_forecast_cell = cell
	_forecast_dirty = true
	place_forecast(battle, actor)


## 予測のパネルを出していない。
func clear_forecast() -> void:
	_forecast_cell = NO_CELL


## 予測のパネルを、対象のマスのそばに置く。駒のそばのメニューには重ねない。行動する駒（actor）、効果の及ぶ駒、情報の枠を隠さない側を選ぶ。
func place_forecast(battle: Battle, actor: Unit) -> void:
	var size := _hud.forecast_size()
	if size == Vector2.ZERO or _forecast_cell == NO_CELL:
		return
	var camera: Camera3D = _rig.camera
	var menu := _hud.menu_rect()
	if not _forecast_dirty and camera.global_transform.is_equal_approx(_forecast_camera) and menu == _forecast_menu:
		return
	_forecast_dirty = false
	_forecast_camera = camera.global_transform
	_forecast_menu = menu
	var on := battle.unit_at(_forecast_cell)
	var height: float = (_views[on.id] as UnitView).height() if on != null and _views.has(on.id) else 0.3
	var anchor := screen_rect(BoardView.cell_center(_forecast_cell), 0.45, height)
	var obstacles: Array = []
	# メニューには重ねない（重みでなく、決まり。メニューの周りに逃がしてでも避ける）。
	var keep_clear: Array = [menu] if menu.has_area() else []
	if _hud.info_rect().has_area():
		obstacles.append([_hud.info_rect(), MENU_WEIGHT_PANEL])
	if actor != null and _views.has(actor.id):
		var view: UnitView = _views[actor.id]
		obstacles.append([screen_rect(view.position, 0.4, view.height()), MENU_WEIGHT_TARGET])
	for unit_id: int in _views:
		if actor == null or unit_id != actor.id:
			var other: UnitView = _views[unit_id]
			obstacles.append([screen_rect(other.position, 0.35, other.height()), MENU_WEIGHT_UNIT])
	for cell in _forecast_avoid:
		if cell != _forecast_cell:
			obstacles.append([screen_rect(BoardView.cell_center(cell), 0.45, 0.8), MENU_WEIGHT_TARGET])
	_hud.place_forecast(_forecast_placement.place(anchor, size, _hud.menu_area(), obstacles, keep_clear))


## 盤面の上の、at を中心に半径 radius・高さ height の柱が、画面に占める四角。カメラの後ろなら、画面の外の四角。
func screen_rect(at: Vector3, radius: float, height: float) -> Rect2:
	var camera: Camera3D = _rig.camera
	if camera.is_position_behind(at):
		return Rect2(-10000.0, -10000.0, 1.0, 1.0)
	var rect := Rect2(camera.unproject_position(at), Vector2.ZERO)
	var right := camera.global_transform.basis.x
	var forward := right.cross(Vector3.UP)
	for corner: Vector3 in [right, -right, forward, -forward]:
		rect = rect.expand(camera.unproject_position(at + corner * radius))
		if height > 0.0:
			rect = rect.expand(camera.unproject_position(at + corner * radius + Vector3.UP * height))
	return rect
