extends Control
## 初期位置の窓（対戦設定の「初期位置」。docs/battle-view.md の「対戦設定」）。盤の縮図（deploy_map.gd）で、1 つの行の初期位置を決める。
## 生成のマップは対戦ごとに形が変わるので、代表の形（マップ選択のカードと同じ種）で見せ、本陣からのずれで覚える。
## 「おまかせ」でいつもの置き方へ戻す。「決定」・右クリック・Esc で閉じる（右クリックは、駒を選んでいれば選ぶのをやめるだけ）。

const Text := preload("res://game/text.gd")
const CardKeys := preload("res://game/card_keys.gd")
const UiTheme := preload("res://game/ui_theme.gd")
const Palette := preload("res://game/ui_palette.gd")
const DeployMap := preload("res://game/deploy_map.gd")
const DeployNote := preload("res://game/deploy_note.gd")
const Steady := preload("res://game/steady.gd")

## 閉じた（決めた置き方は offsets()）。
signal closed

## 縮図の 1 マスの大きさの上限と、縮図の大きさの上限（大きい盤は小さく描く）。
const CELL_PX := 22.0
const MAP_MAX := Vector2(560.0, 440.0)

var _overlays: RefCounted
var _title: Label
var _map: DeployMap
var _note: DeployNote
var _auto: Button


func setup(overlays: RefCounted) -> void:
	_overlays = overlays
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	visibility_changed.connect(_track_overlay)
	var shade := ColorRect.new()
	shade.color = Palette.SHADE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.theme_type_variation = UiTheme.PANEL_SOLID
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	_title = Label.new()
	UiTheme.style_window_title(_title)
	column.add_child(_title)
	column.add_child(UiTheme.window_rule())
	# 作戦図の額（目盛りと鉤）は縮図の外に描くので、そのぶんの余白を取る。
	var map_room := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		map_room.add_theme_constant_override("margin_" + side, int(DeployMap.TICK_LONG) + 2)
	map_room.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	map_room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(map_room)
	_map = DeployMap.new()
	_map.changed.connect(func() -> void: _auto.disabled = _map.is_default())
	map_room.add_child(_map)
	# 選んでいる駒（マウスを乗せている駒）の名前・役割・能力値（deploy_note.gd）。
	_note = DeployNote.new()
	# 欄は、マップの広さに依らず同じ大きさで真ん中に置く（docs/ui-theme.md の「枠の大きさ」）。
	_note.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	Steady.mark(_note, "placement.unit_note")
	column.add_child(_note)
	_note.watch(_map)
	var note := Label.new()
	note.name = "Note"
	note.add_theme_font_size_override("font_size", 14)
	note.add_theme_color_override("font_color", Palette.TEXT_DIM)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(note)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	column.add_child(buttons)
	_auto = Button.new()
	_auto.text = Text.t("sortie.auto_place")
	_auto.focus_mode = Control.FOCUS_NONE
	_auto.custom_minimum_size = Vector2(160.0, 44.0)
	_auto.pressed.connect(func() -> void: _map.reset())
	buttons.add_child(_auto)
	var done := Button.new()
	done.text = Text.t("common.ok")
	done.focus_mode = Control.FOCUS_NONE
	done.theme_type_variation = UiTheme.BUTTON_PRIMARY
	done.custom_minimum_size = Vector2(180.0, 44.0)
	done.pressed.connect(close_dialog)
	buttons.add_child(done)


## 行の見出し who の初期位置を開く。preview は MatchChoice.placement_preview の結果。generated なら、代表の形だと書く。
func open(who: String, preview: Array, scenario_cells: Array[Vector2i], look: StringName, team_colors: Array[Color], generated: bool) -> void:
	_title.text = Text.t("setup.placement.title", {"who": who})
	var usual: Battle = preview[1]
	var side: Unit.Side = preview[2]
	var defaults: Array[Vector2i] = []
	for unit: Unit in usual.units:
		if unit.side == side and unit.kind != UnitKind.Id.KING:
			defaults.append(unit.cell)
	_map.setup(preview[0], side, defaults, scenario_cells, look, team_colors)
	var board := Vector2(usual.board.size)
	var cell_px := minf(CELL_PX, minf(MAP_MAX.x / board.x, MAP_MAX.y / board.y))
	_map.custom_minimum_size = board * cell_px
	_auto.disabled = _map.is_default()
	(find_child("Note", true, false) as Label).text = Text.t("setup.placement.generated") if generated else ""
	visible = true


func close_dialog() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


## 決めた置き方（DeployMap.offsets）と、縮図（検査用）。
func offsets() -> Array[Vector2i]:
	return _map.offsets()


func deploy_map() -> DeployMap:
	return _map


## 駒の欄（検査用）。
func deploy_note() -> DeployNote:
	return _note


func _track_overlay() -> void:
	if _overlays == null:
		return
	if visible and is_inside_tree():
		_overlays.open(self)
	else:
		_overlays.close(self)


func _exit_tree() -> void:
	if _overlays != null:
		_overlays.close(self)


func _input(event: InputEvent) -> void:
	if not visible or _overlays == null or not _overlays.is_top(self):
		return
	if CardKeys.is_back(event):
		get_viewport().set_input_as_handled()
		if not _map.cancel():
			close_dialog()
