extends CanvasLayer
## 対戦の画面の文字とボタン（ターン、番、駒の情報、行動のメニュー、決着）。
##
## 何を出すかは呼ぶ側が決める。ここはルールを持たず、押されたことを signal で知らせるだけ。

signal wait_pressed
## 「移動を取り消す」と「選択をやめる」は同じボタン（どちらになるかは呼ぶ側が決める）。
signal cancel_pressed
signal end_turn_pressed
## 進化先を選んだ。index は、出している選択肢の何番目か（0 が A、1 が B）。
signal evolution_chosen(index: int)
## 相手（プレイヤー2）を人にするか CPU にするかの切り替えが押された。
signal opponent_pressed
## stage は BoardGenerator.Stage の値。new_board が偽なら、いまと同じ盤面でやり直す（stage は見ない）。
signal restart_pressed(stage: int, new_board: bool)

const SIDE_NAMES := {
	Unit.Side.PLAYER1: "プレイヤー1（青）",
	Unit.Side.PLAYER2: "プレイヤー2（赤）",
	Unit.Side.NEUTRAL: "中立",
}
const ROLE_NAMES := {
	UnitKind.Role.VANGUARD: "前衛",
	UnitKind.Role.REARGUARD: "後衛",
	UnitKind.Role.RAIDER: "奇襲",
	UnitKind.Role.HEALER: "回復",
}
const TERRAIN_NAMES := {
	Terrain.Type.NORMAL: "平地",
	Terrain.Type.OBSTACLE: "障害物（入れない）",
	Terrain.Type.FOREST: "森（移動 2・受けるダメージ 0.8 倍）",
	Terrain.Type.FONT: "結晶泉",
}
const OBJECT_NAMES := {
	MapObject.Type.BARREL: "起爆樽（入れない。攻撃すると爆発し、周り 8 マスの駒すべてに %d ダメージ）" % MapObject.BLAST_DAMAGE,
	MapObject.Type.SPRING: "回復の泉（自分の番の始めに、乗っている駒が %d 回復）" % MapObject.SPRING_HEAL,
	MapObject.Type.PORTAL: "ポータル",
}
const STAT_NAMES := {
	Unit.Stat.MAX_HP: "最大 HP",
	Unit.Stat.POWER: "攻撃",
	Unit.Stat.MOVE_RANGE: "移動",
	Unit.Stat.ATTACK_RANGE: "射程",
}
const TRAIT_TEXTS := {
	Evolution.Trait.EXERTS_ZOC: "周り 8 マスに支配領域を作る（敵はそこで止まる）",
	Evolution.Trait.IGNORES_ZOC: "敵の支配領域で止まらない",
	Evolution.Trait.FOREST_WALK: "森を平地と同じ移動力で歩く",
	Evolution.Trait.REGENERATION: "自分の番の始めに %d 回復" % Evolution.REGENERATION_HEAL,
}
const STAGE_NAMES := {
	BoardGenerator.Stage.PLAIN: "1 中央平原",
	BoardGenerator.Stage.LABYRINTH: "2 迷宮回廊",
	BoardGenerator.Stage.TWIN_SPRINGS: "3 双子結晶",
}
const COLOR_PANEL := Color(0.07, 0.09, 0.12, 0.82)
const COLOR_TEXT_DIM := Color(0.75, 0.78, 0.82)
const COLOR_FORECAST := Color("ffd76a")

var _team_colors: Array[Color] = []

var _turn_label: Label
var _phase_label: Label
var _side_labels: Array[Label] = []
var _info_panel: PanelContainer
var _info_name: Label
var _info_side: Label
var _info_stats: Label
var _info_state: Label
var _info_forecast: Label
var _cell_label: Label
var _hint_label: Label
var _end_turn_button: Button
var _opponent_button: Button
var _wait_button: Button
var _cancel_button: Button
var _banner: Label
var _banner_tween: Tween
var _result: Control
var _evolution: Control
var _evolution_title: Label
var _evolution_buttons: Array[Button] = []
var _result_title: Label
var _result_reason: Label


func setup(team_colors: Array[Color]) -> void:
	_team_colors = team_colors
	_build_top_bar()
	_build_info_panel()
	_build_bottom()
	_build_banner()
	_build_result()
	_build_evolution()


## counts は陣営ごとの駒の数、captures は本陣の占拠の数（どちらも添字がプレイヤー番号）。
func set_status(turn: int, phase: Unit.Side, counts: Array[int], captures: Array[int], capture_goal: int) -> void:
	_turn_label.text = "ターン %d" % turn
	_phase_label.text = "%s の番" % SIDE_NAMES[phase]
	_phase_label.add_theme_color_override("font_color", _side_color(phase))
	for player in 2:
		var pips := "●".repeat(captures[player]) + "○".repeat(capture_goal - captures[player])
		_side_labels[player].text = "%s  駒 %d  占拠 %s" % [("青" if player == 0 else "赤"), counts[player], pips]


## 駒の情報を出す。unit が null なら消す。forecast は攻撃の見込み（無ければ空）。
func show_unit(unit: Unit, state: String, forecast: String) -> void:
	_info_panel.visible = unit != null
	if unit == null:
		return
	var role: String = ROLE_NAMES.get(UnitKind.role(unit.kind), "")
	_info_name.text = unit.display_name() + ("（%s）" % role if role else "")
	_info_name.add_theme_color_override("font_color", _side_color(unit.side).lightened(0.35))
	_info_side.text = SIDE_NAMES[unit.side]
	var power_name := "回復" if UnitKind.role(unit.kind) == UnitKind.Role.HEALER else "攻撃"
	_info_stats.text = "HP %d / %d\n%s %d   移動 %d   射程 %d" % [
		unit.hp, unit.max_hp(), power_name, unit.power(), unit.move_range(), unit.attack_range(),
	]
	if Growth.can_grow(unit):
		if unit.level >= Growth.MAX_LEVEL:
			_info_stats.text += "\nレベル %d（最大）" % unit.level
			for which in Evolution.traits(unit.evolution):
				_info_stats.text += "\n★ %s" % TRAIT_TEXTS[which]
		else:
			_info_stats.text += "\nレベル %d   経験 %d / %d" % [unit.level, unit.experience, Growth.EXPERIENCE_PER_LEVEL]
	_info_state.text = state
	_info_forecast.text = forecast
	_info_forecast.visible = forecast != ""


## マウスの下のマスの説明。盤の外なら空を渡す。
func show_cell(text: String) -> void:
	_cell_label.text = text


func set_hint(text: String) -> void:
	_hint_label.text = text


func set_end_turn(enabled: bool, text: String) -> void:
	_end_turn_button.disabled = not enabled
	_end_turn_button.text = text


## 相手を切り替えるボタンの文字（いまの相手を書く）。
func set_opponent(text: String) -> void:
	_opponent_button.text = text


## 選んでいる駒の行動のボタン。can_wait は待機できるか、can_cancel は戻せるか、
## moved は駒がもう動いたか（戻すボタンが「移動を取り消す」になる）。
func set_actions(can_wait: bool, can_cancel: bool, moved: bool) -> void:
	_wait_button.disabled = not can_wait
	_cancel_button.disabled = not can_cancel
	_cancel_button.text = "移動を取り消す" if moved else "選択をやめる"


## 画面の中央に、しばらくだけ大きな文字を出す。
func show_banner(text: String, color: Color) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color.lightened(0.4))
	_banner.modulate.a = 1.0
	_banner.visible = true
	if _banner_tween != null:
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_interval(0.9)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.5)
	_banner_tween.tween_callback(_banner.hide)


func show_result(winner: Unit.Side, reason: String) -> void:
	_result_title.text = "%s の勝ち" % SIDE_NAMES[winner]
	_result_title.add_theme_color_override("font_color", _side_color(winner).lightened(0.4))
	_result_reason.text = reason
	_result.visible = true


## 引き分けの結果を出す。
func show_draw(reason: String) -> void:
	_result_title.text = "引き分け"
	_result_title.add_theme_color_override("font_color", Color("e6e6e6"))
	_result_reason.text = reason
	_result.visible = true


## いま出ている結果の見出し（出ていなければ空）。検査用。
func result_title() -> String:
	return _result_title.text if _result.visible else ""


func hide_result() -> void:
	_result.visible = false


## 進化先の説明（名前、能力値の増減、特性）。healer なら、攻撃の欄を「回復」と書く。
static func evolution_text(id: Evolution.Id, healer: bool) -> String:
	var parts: Array[String] = []
	var bonuses := Evolution.bonuses(id)
	for which: Unit.Stat in STAT_NAMES:
		if bonuses.has(which):
			var stat_name: String = "回復" if healer and which == Unit.Stat.POWER else STAT_NAMES[which]
			parts.append("%s %+d" % [stat_name, bonuses[which]])
	var text := "%s\n%s" % [Evolution.display_name(id), "　".join(parts)]
	for which in Evolution.traits(id):
		text += "\n★ %s" % TRAIT_TEXTS[which]
	return text


## 進化先の選択肢を出す。texts は選択肢ごとの説明（evolution_text）。
func show_evolution(title: String, texts: Array[String]) -> void:
	_evolution_title.text = title
	for i in _evolution_buttons.size():
		_evolution_buttons[i].visible = i < texts.size()
		if i < texts.size():
			_evolution_buttons[i].text = "[%d] %s" % [i + 1, texts[i]]
	_evolution.visible = true


func hide_evolution() -> void:
	_evolution.visible = false


## 進化先の選択肢を出しているか。検査用。
func is_evolution_shown() -> bool:
	return _evolution.visible


## マウスがボタンやパネルの上にあるか（盤面のクリックと取り違えないため）。
func is_mouse_over_ui() -> bool:
	return get_viewport().gui_get_hovered_control() != null


func _side_color(side: Unit.Side) -> Color:
	return _team_colors[side] if side < _team_colors.size() else Color.WHITE


# ---- 組み立て ----


func _build_top_bar() -> void:
	var panel := _panel()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	panel.add_child(row)
	_turn_label = _label(22)
	row.add_child(_turn_label)
	_phase_label = _label(22)
	row.add_child(_phase_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	for player in 2:
		var label := _label(18)
		label.add_theme_color_override("font_color", _team_colors[player].lightened(0.4))
		row.add_child(label)
		_side_labels.append(label)
	_opponent_button = _button("", opponent_pressed)
	_opponent_button.custom_minimum_size = Vector2(170.0, 34.0)
	_opponent_button.add_theme_font_size_override("font_size", 15)
	row.add_child(_opponent_button)


func _build_info_panel() -> void:
	_info_panel = _panel()
	_info_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_info_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_info_panel.offset_left = 12.0
	_info_panel.offset_right = 12.0
	_info_panel.offset_top = -104.0
	_info_panel.offset_bottom = -104.0
	_info_panel.custom_minimum_size = Vector2(280.0, 0.0)
	# 盤面の隅に重なるので、下のマスを選べるよう、マウスは素通しにする。
	_info_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_panel.visible = false
	add_child(_info_panel)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 入れ物は既定でマウスを拾うので、こちらも素通しにする
	_info_panel.add_child(column)
	_info_name = _label(20)
	column.add_child(_info_name)
	_info_side = _label(14)
	_info_side.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	column.add_child(_info_side)
	_info_stats = _label(17)
	column.add_child(_info_stats)
	_info_state = _label(15)
	_info_state.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	column.add_child(_info_state)
	_info_forecast = _label(17)
	_info_forecast.add_theme_color_override("font_color", COLOR_FORECAST)
	column.add_child(_info_forecast)


func _build_bottom() -> void:
	var panel := _panel()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	panel.add_child(row)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	# 文が長くても、ボタンを画面の外へ押し出さない。
	_hint_label = _label(17)
	_hint_label.clip_text = true
	column.add_child(_hint_label)
	_cell_label = _label(14)
	_cell_label.clip_text = true
	_cell_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	column.add_child(_cell_label)
	_wait_button = _button("待機", wait_pressed)
	row.add_child(_wait_button)
	_cancel_button = _button("選択をやめる", cancel_pressed)
	row.add_child(_cancel_button)
	_end_turn_button = _button("ターン終了", end_turn_pressed)
	_end_turn_button.custom_minimum_size = Vector2(270.0, 48.0)
	row.add_child(_end_turn_button)

	var help_panel := _panel()
	help_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	help_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	help_panel.offset_left = -8.0
	help_panel.offset_right = -8.0
	help_panel.offset_top = 58.0
	help_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(help_panel)
	var help := _label(13)
	help.text = "WASD 移動 / Q E 回転 / R 角度 / ホイール 拡大\nSpace 待機 / Esc・右クリック 戻す / Enter ターン終了\n1・2 進化先を選ぶ\nF1〜F3 新しい盤面（ステージ 1〜3）/ F4 相手を人・CPU に切り替え"
	help.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	help_panel.add_child(help)


func _build_banner() -> void:
	_banner = _label(44)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.position.y = 150.0
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_constant_override("outline_size", 12)
	_banner.visible = false
	add_child(_banner)


func _build_result() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.visible = false
	add_child(shade)
	_result = shade
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var panel := _panel()
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	_result_title = _label(40)
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_result_title)
	_result_reason = _label(20)
	_result_reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_result_reason)
	var again := _button("同じ盤面でもう一度", Signal())
	again.pressed.connect(func() -> void: restart_pressed.emit(0, false))
	column.add_child(again)
	var caption := _label(15)
	caption.text = "新しい盤面で対戦する"
	caption.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(caption)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	column.add_child(row)
	for stage: int in STAGE_NAMES:
		var button := _button(STAGE_NAMES[stage], Signal())
		button.pressed.connect(func() -> void: restart_pressed.emit(stage, true))
		row.add_child(button)


## 進化先の選択肢（飾らない 2 つのボタン）。盤面が見えるよう、画面の上寄りに出す。
func _build_evolution() -> void:
	var panel := _panel()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.position.y = 70.0
	panel.visible = false
	add_child(panel)
	_evolution = panel
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	_evolution_title = _label(22)
	_evolution_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_evolution_title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	column.add_child(row)
	for i in 2:
		var button := _button("", Signal())
		button.custom_minimum_size = Vector2(330.0, 110.0)
		button.pressed.connect(func() -> void: evolution_chosen.emit(i))
		row.add_child(button)
		_evolution_buttons.append(button)


func _panel() -> PanelContainer:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10.0)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _label(font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	return label


## pressed を、そのまま to（この HUD の signal）として知らせるボタン。to が空なら、呼ぶ側でつなぐ。
func _button(text: String, to: Signal) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 18)
	button.custom_minimum_size = Vector2(150.0, 48.0)
	button.focus_mode = Control.FOCUS_NONE
	if not to.is_null():
		button.pressed.connect(to.emit)
	return button
