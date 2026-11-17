extends Control
## 初期位置を決める盤の縮図（docs/player-loadout.md の「置けるマス」、docs/story.md の「出撃準備」、docs/battle-view.md の「対戦設定」）。
## 出撃準備の左の縮図と、対戦設定の「初期位置」の窓が使う。
##
## - 盤（map_card.gd）に、置けるマス（Deployment.zone）を陣営の色で縁取り、駒を描く（決める側の駒はアイコン、ほかは点）。
## - 決める側の駒を押すと選ぶ（金の縁）。続けて置けるマスを押すと、そこへ置く（駒がいれば入れ替える）。もう一度押すか右クリックで選ぶのをやめる。
## - 置き方は、本陣からのずれを部隊の並びの順に持つ（MatchSetup.placements。offsets）。reset でいつもの置き方（おまかせ）へ戻す。
## - read_only なら、見せるだけ（部隊も位置も決まっている話）。

const MapCard := preload("res://game/map_card.gd")
const UnitIcons := preload("res://game/unit_icons.gd")
const Palette := preload("res://game/ui_palette.gd")

## 置き方が変わった（offsets() で読む）。
signal changed

## 1 マスの大きさ（縮図の絵の px。表示は control の大きさに合わせて拡げる）。
const IMAGE_CELL := 8

var read_only := false

var _battle: Battle
var _side := Unit.Side.PLAYER1
var _zone: Array[Vector2i] = []
var _defaults: Array[Vector2i] = []
var _cells: Array[Vector2i] = []
var _kinds: Array[UnitKind.Id] = []
var _team_colors: Array[Color] = []
var _texture: Texture2D
var _selected := -1


## battle: いまの置き方で作った、始まる前の対戦（MatchSetup.create_battle）。defaults: 人が決めない、いつもの置き方の駒のマス（部隊の並びの順）。
## side: 決める側。scenario_cells: 戦いの定義の初期位置（置けるマスのもと）。
func setup(battle: Battle, side: Unit.Side, defaults: Array[Vector2i], scenario_cells: Array[Vector2i], look: StringName, team_colors: Array[Color]) -> void:
	_battle = battle
	_side = side
	_team_colors = team_colors
	_kinds.clear()
	_cells.clear()
	for unit: Unit in battle.units:
		if unit.side == side and unit.kind != UnitKind.Id.KING:
			_kinds.append(unit.kind)
			_cells.append(unit.cell)
	_defaults = defaults.duplicate()
	_zone = Deployment.zone(battle, side, scenario_cells, _kinds.size())
	_texture = ImageTexture.create_from_image(MapCard.draw(battle.board, look, team_colors, IMAGE_CELL))
	_selected = -1
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


## 盤の大きさに合う、縮図の大きさ（1 マス cell_px）。
func size_for(cell_px: float) -> Vector2:
	return Vector2(_battle.board.size) * cell_px if _battle != null else Vector2.ZERO


## いまの置き方（本陣からのずれ。部隊の並びの順）。いつもの置き方と同じなら空（MatchSetup.placements に渡す）。
func offsets() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if _cells == _defaults:
		return result
	var hq := _battle.board.hq_cells[_side]
	for cell in _cells:
		result.append(cell - hq)
	return result


## いつもの置き方（おまかせ）へ戻す。
func reset() -> void:
	_cells = _defaults.duplicate()
	_selected = -1
	queue_redraw()
	changed.emit()


func is_default() -> bool:
	return _cells == _defaults


## 置けるマス・駒のマス（部隊の並びの順）・選んでいる駒（検査用）。
func zone() -> Array[Vector2i]:
	return _zone.duplicate()


func unit_cells() -> Array[Vector2i]:
	return _cells.duplicate()


func selected() -> int:
	return _selected


## マス cell を押す（マウスと同じ。検査用にも）。
func press_cell(cell: Vector2i) -> void:
	if read_only or _battle == null:
		return
	var index := _cells.find(cell)
	if _selected == -1:
		if index != -1:
			_selected = index
	elif index == _selected:
		_selected = -1
	elif index != -1:
		# ほかの駒と入れ替える。
		_cells[index] = _cells[_selected]
		_cells[_selected] = cell
		_selected = -1
		changed.emit()
	elif _zone.has(cell) and _is_free(cell):
		_cells[_selected] = cell
		_selected = -1
		changed.emit()
	else:
		_selected = -1
	queue_redraw()


## 選ぶのをやめる（やめるものがあれば真）。
func cancel() -> bool:
	if _selected == -1:
		return false
	_selected = -1
	queue_redraw()
	return true


## 画面の座標 at（この control の中）のマス。盤の外なら NO_CELL。
func cell_at(at: Vector2) -> Vector2i:
	var rect := _board_rect()
	if not rect.has_point(at) or _battle == null:
		return Deployment.NO_CELL
	var cell_px := rect.size.x / _battle.board.size.x
	return Vector2i(((at - rect.position) / cell_px).floor())


## マス cell の真ん中（この control の中の座標）。検査用。
func cell_center(cell: Vector2i) -> Vector2:
	var rect := _board_rect()
	var cell_px := rect.size.x / _battle.board.size.x
	return rect.position + (Vector2(cell) + Vector2(0.5, 0.5)) * cell_px


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		# 押せるマス（決める側の駒、選んでいる駒の行き先）の上では、指の形のカーソル。
		var at := cell_at(event.position)
		var pressable := not read_only and _battle != null and (_cells.has(at) or (_selected != -1 and _zone.has(at) and _is_free(at)))
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if pressable else Control.CURSOR_ARROW
		return
	if not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index == MOUSE_BUTTON_LEFT and not read_only:
		var cell := cell_at(event.position)
		if cell != Deployment.NO_CELL:
			press_cell(cell)
			accept_event()
	elif event.button_index == MOUSE_BUTTON_RIGHT and cancel():
		accept_event()


## 空いているマスか（決める側の駒は、いまの置き方の位置で見る。ほかの駒は対戦のまま）。
func _is_free(cell: Vector2i) -> bool:
	if _cells.has(cell):
		return false
	var unit := _battle.unit_at(cell)
	return unit == null or (unit.side == _side and unit.kind != UnitKind.Id.KING)


func _board_rect() -> Rect2:
	if _battle == null:
		return Rect2()
	var board := Vector2(_battle.board.size)
	var cell_px := minf(size.x / board.x, size.y / board.y)
	var drawn := board * cell_px
	return Rect2((size - drawn) / 2.0, drawn)


func _draw() -> void:
	if _battle == null:
		return
	var rect := _board_rect()
	var cell_px := rect.size.x / _battle.board.size.x
	draw_texture_rect(_texture, rect, false)
	var color: Color = _team_colors[_side]
	var choosing := _selected != -1
	for cell in _zone:
		var box := Rect2(rect.position + Vector2(cell) * cell_px, Vector2.ONE * cell_px)
		draw_rect(box, Color(color, 0.32 if choosing else 0.2))
		draw_rect(box.grow(-1.0), Color(color.lightened(0.4), 0.9), false, 2.0)
	# ほかの駒（相手、中立）は点。
	for unit: Unit in _battle.units:
		if unit.side == _side or unit.kind == UnitKind.Id.KING:
			continue
		var at := rect.position + (Vector2(unit.cell) + Vector2(0.5, 0.5)) * cell_px
		var dot_color: Color = _team_colors[unit.side] if unit.side < _team_colors.size() else Palette.TEXT_DIM
		draw_circle(at, cell_px * 0.3, Palette.OUTLINE)
		draw_circle(at, cell_px * 0.24, dot_color.lightened(0.2))
	# 決める側の駒は、アイコン。
	for i in _cells.size():
		var box := Rect2(rect.position + Vector2(_cells[i]) * cell_px, Vector2.ONE * cell_px).grow(cell_px * 0.15)
		draw_texture_rect(UnitIcons.texture(_kinds[i], _side), box, false)
		if i == _selected:
			draw_rect(box, Palette.ACCENT, false, 3.0)
