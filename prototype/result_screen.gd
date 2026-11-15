extends Control
## リザルトの画面。決着したら、対戦の画面（盤面）の上に重ねて、段階的に出す（result_summary.gd の中身）。
##
## 1. 勝敗の見出し（VICTORY / DEFEAT、人どうしは勝った側の名前）が中央に大きく出て、上へ退く。
## 2. 戦績（作戦領域・経過ターン・敵軍撃破・聖遺物）が 1 行ずつ出る。
## 3. MVP が拡大しながら出る。
## 4. 行き先のボタンと、入力の案内が出る。**ここまで出そろうまで、行き先は選べない。**
## 出そろう前のクリック（Enter・Space でも）は、演出を飛ばして全部を出すだけ（行き先は選ばない）。
## 出そろったあとの Enter はタイトルへ（ボタンの「タイトルへ」と同じ）。両方の陣営の詳しい戦績は畳んでおき、ボタンで開く。
##
## 何を出すかは呼ぶ側（result_summary.gd）が決める。ここは見せ方と、押されたことを signal で知らせるだけ。

const ResultSummary := preload("res://prototype/result_summary.gd")
const OverlayStack := preload("res://prototype/overlay_stack.gd")
const TextWrap := preload("res://prototype/text_wrap.gd")

## 行き先のボタン。stage は BoardGenerator.Stage の値。new_board が偽なら、いまと同じ盤面でもう一度（stage は見ない）。
signal restart_pressed(stage: int, new_board: bool)
signal setup_pressed
signal title_pressed
## 全部が出そろった（行き先を選べるようになった）。
signal revealed

## 段階の時刻（秒。画面を出してから）。
const HEADLINE_IN := 0.45
const HEADLINE_RISE_AT := 0.9
const RISE_TIME := 0.4
const STATS_AT := 1.3
const STAT_GAP := 0.25
const MVP_GAP := 0.2
const MVP_IN := 0.45
const PROMPT_GAP := 0.3
## 飛ばしたあと、行き先のボタンが押せるようになるまで（飛ばしたクリックが、そのままボタンに届かないように）。
const SKIP_GUARD := 0.25
## 入力の案内の明滅の周期（秒）。
const BLINK_PERIOD := 1.4

## 見出しの位置（縦。中央に出たときと、退いたあと）と、退いたあとの大きさ。
const HEADLINE_CENTER_Y := 290.0
const HEADLINE_TOP_Y := 18.0
const HEADLINE_SHRUNK := 0.62
const BODY_TOP := 146.0
## 詳しい戦績を折り返す幅（px）。
const DETAIL_WIDTH := 760.0

const COLOR_SHADE := Color(0.0, 0.0, 0.0, 0.78)
const COLOR_PANEL := Color(0.09, 0.11, 0.15, 0.97)
const COLOR_DIM := Color(0.75, 0.78, 0.82)
const COLOR_VICTORY := Color("ffcf4a")
const COLOR_DEFEAT := Color("9cc8ff")
const COLOR_DRAW := Color("e6e6e6")
const COLOR_MVP := Color("ffd76a")

## 盤を見ている人の画面の、開いている重なる画面（システムメニューなど）。開いている間は、ここの Enter とクリックを使わない。
var overlays: OverlayStack
## 効果音を鳴らす（名前を渡す。無ければ鳴らさない）。
var play_sound := Callable()
## 陣営ごとの色（添字がプレイヤー番号）。見出しの色（人どうし）に使う。
var team_colors: Array[Color] = []

var _summary: RefCounted
var _shade: ColorRect
var _headline: Label
var _reason: Label
var _body: VBoxContainer
var _stats_panel: PanelContainer
var _stats_title: Label
var _stats_grid: GridContainer
var _stat_rows: Array = []
var _mvp_panel: PanelContainer
var _mvp_head: Label
var _mvp_name: Label
var _mvp_numbers: Label
var _detail_panel: PanelContainer
var _detail: Label
var _actions: VBoxContainer
var _detail_button: Button
var _prompt: Label
var _buttons: Array[Button] = []
var _tween: Tween
var _revealed := false
var _skipped := false
var _elapsed := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP  # 後ろの盤面へクリックを通さない
	visible = false
	_shade = ColorRect.new()
	_shade.color = COLOR_SHADE
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shade)

	_headline = _label(76)
	_headline.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_headline.add_theme_constant_override("outline_size", 14)
	add_child(_headline)
	_reason = _label(20)
	_reason.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_reason)

	_body = VBoxContainer.new()
	_body.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_body.offset_top = BODY_TOP
	_body.add_theme_constant_override("separation", 8)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_body)
	_build_stats()
	_build_mvp()
	_build_detail()
	_build_actions()


## summary（result_summary.gd）を、段階的に出し始める。
func present(summary: RefCounted) -> void:
	_summary = summary
	_revealed = false
	_skipped = false
	_elapsed = 0.0
	if _tween != null:
		_tween.kill()
	_headline.text = summary.headline
	_headline.add_theme_color_override("font_color", _headline_color(summary))
	_reason.text = summary.reason
	_stats_title.text = "%s の戦績" % summary.focus_name
	for row: Array in _stat_rows:
		for label: Label in row:
			label.queue_free()
	_stat_rows.clear()
	for line: Array in summary.lines:
		var name_label := _label(18)
		name_label.text = line[0]
		name_label.add_theme_color_override("font_color", COLOR_DIM)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		name_label.custom_minimum_size = Vector2(130.0, 0.0)
		var value_label := _label(24)
		value_label.text = line[1]
		_stats_grid.add_child(name_label)
		_stats_grid.add_child(value_label)
		_stat_rows.append([name_label, value_label])
	if summary.mvp_name != "":
		_mvp_name.text = summary.mvp_name
		_mvp_numbers.text = "与えたダメージ %d　撃破 %d" % [summary.mvp_damage, summary.mvp_kills]
	else:
		_mvp_name.text = "該当なし"
		_mvp_numbers.text = "敵にダメージを与えた駒がいない"
	var font := _detail.get_theme_font("font")
	var font_size := _detail.get_theme_font_size("font_size")
	_detail.text = TextWrap.fold(summary.detail, DETAIL_WIDTH,
		func(character: String) -> float: return font.get_string_size(character, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	_show_detail(false)

	# 始めの形: 見出しは中央で透明、ほかは場所を取ったまま透明（出るときに配置が動かないように）。
	_shade.modulate.a = 0.0
	_headline.modulate.a = 0.0
	_headline.position.y = HEADLINE_CENTER_Y
	_headline.scale = Vector2.ONE * 1.25
	_reason.modulate.a = 0.0
	_stats_panel.modulate.a = 0.0
	for row: Array in _stat_rows:
		for label: Label in row:
			label.modulate.a = 0.0
	_mvp_panel.modulate.a = 0.0
	_actions.modulate.a = 0.0
	_set_buttons_enabled(false)
	visible = true
	# 大きさが決まってから、見出しの拡大の中心を決める。
	await get_tree().process_frame
	if _summary != summary:
		return
	_headline.pivot_offset = _headline.size / 2.0
	_place_reason()
	_stage()


## 段階を、出し始めてからの時刻で並べる（どれも、始めからの時刻で置く）。
func _stage() -> void:
	_tween = create_tween().set_parallel(true)
	var t := _tween
	# 1. 勝敗の見出し
	t.tween_property(_shade, "modulate:a", 1.0, 0.35)
	t.tween_property(_headline, "modulate:a", 1.0, HEADLINE_IN)
	t.tween_property(_headline, "scale", Vector2.ONE, HEADLINE_IN).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_reason, "modulate:a", 1.0, HEADLINE_IN).set_delay(0.15)
	# 上へ退く
	t.tween_property(_headline, "position:y", HEADLINE_TOP_Y, RISE_TIME).set_delay(HEADLINE_RISE_AT) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_headline, "scale", Vector2.ONE * HEADLINE_SHRUNK, RISE_TIME).set_delay(HEADLINE_RISE_AT) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	t.tween_method(func(_v: float) -> void: _place_reason(), 0.0, 1.0, RISE_TIME).set_delay(HEADLINE_RISE_AT)
	# 2. 戦績を 1 行ずつ
	t.tween_property(_stats_panel, "modulate:a", 1.0, 0.2).set_delay(STATS_AT)
	var at := STATS_AT + 0.1
	for row: Array in _stat_rows:
		t.tween_callback(_sound.bind(&"ui_click")).set_delay(at)
		for label: Label in row:
			t.tween_property(label, "modulate:a", 1.0, 0.18).set_delay(at)
		at += STAT_GAP
	# 3. MVP
	at += MVP_GAP
	t.tween_callback(func() -> void:
		_mvp_panel.pivot_offset = _mvp_panel.size / 2.0
		_sound(&"relic")).set_delay(at)
	t.tween_property(_mvp_panel, "modulate:a", 1.0, MVP_IN * 0.6).set_delay(at)
	t.tween_property(_mvp_panel, "scale", Vector2.ONE, MVP_IN).from(Vector2.ONE * 0.6).set_delay(at) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# 4. 行き先と、入力の案内
	at += MVP_IN + PROMPT_GAP
	t.tween_property(_actions, "modulate:a", 1.0, 0.25).set_delay(at)
	t.tween_callback(_on_revealed).set_delay(at + 0.25)


## 全部が出そろったか（行き先を選べるか）。
func is_revealed() -> bool:
	return _revealed


## 演出を飛ばして、全部を出す（出そろっていれば何もしない）。飛ばした直後の少しの間は、行き先のボタンを押せない。
func skip() -> void:
	if not visible or _revealed:
		return
	_skipped = true
	if _tween != null and _tween.is_valid():
		_tween.custom_step(60.0)
	elif _summary != null:
		# まだ始まっていない（大きさを決める 1 フレームの間）。始めてから飛ばす。
		await get_tree().process_frame
		if _tween != null and _tween.is_valid():
			_tween.custom_step(60.0)


## 演出を、出し始めてから seconds 秒のところで止める（スクリーンショットの道具が、段階ごとに撮るのに使う）。
func hold_at(seconds: float) -> void:
	while visible and (_tween == null or not _tween.is_valid()):
		await get_tree().process_frame
	if _tween != null and _tween.is_valid():
		_tween.pause()
		_tween.custom_step(seconds)


## いま出しているもの（result_summary.gd。出ていなければ null）。
func shown_summary() -> RefCounted:
	return _summary if visible else null


func hide_result() -> void:
	if _tween != null:
		_tween.kill()
	_summary = null
	_revealed = false
	visible = false


## いま出ている見出し（出ていなければ空）。検査用。
func headline() -> String:
	return _headline.text if visible else ""


## いま出している詳しい戦績（出ていなければ空。畳んでいても返す）。検査用。
func detail_text() -> String:
	return _detail.text if visible else ""


## 戦績の行の文字（[項目, 値] の列）。検査用。
func stat_lines() -> Array:
	return _summary.lines if visible and _summary != null else []


## MVP の名前（いなければ「該当なし」）。検査用。
func mvp_text() -> String:
	return _mvp_name.text if visible else ""


## 押せる行き先のボタンの文字（出そろう前は空）。検査用。
func enabled_buttons() -> Array[String]:
	var texts: Array[String] = []
	for button in _buttons:
		if button.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			texts.append(button.text)
	return texts


## 詳しい戦績を開く・閉じる。
func toggle_detail() -> void:
	_show_detail(not _detail_panel.visible)


func is_detail_open() -> bool:
	return _detail_panel.visible


func _process(delta: float) -> void:
	if not visible:
		return
	_elapsed += delta
	if _revealed:
		_prompt.modulate.a = 0.45 + 0.55 * (0.5 + 0.5 * cos(_elapsed * TAU / BLINK_PERIOD))


func _gui_input(event: InputEvent) -> void:
	# 出そろう前のクリックは、飛ばすだけ（ボタンは押せないので、ここへ届く）。
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not _revealed:
		skip()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or (overlays != null and overlays.is_open()):
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if not _revealed:
				skip()
			elif event.physical_keycode != KEY_SPACE and _buttons_ready():
				title_pressed.emit()
			get_viewport().set_input_as_handled()


func _on_revealed() -> void:
	_revealed = true
	_elapsed = 0.0
	if _skipped:
		await get_tree().create_timer(SKIP_GUARD, true, false, true).timeout
		if not _revealed:
			return
	_set_buttons_enabled(true)
	revealed.emit()


func _buttons_ready() -> bool:
	return not _buttons.is_empty() and _buttons[0].mouse_filter != Control.MOUSE_FILTER_IGNORE


func _set_buttons_enabled(enabled: bool) -> void:
	for button in _buttons:
		button.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE


func _show_detail(open: bool) -> void:
	_detail_panel.visible = open
	_stats_panel.visible = not open
	_mvp_panel.visible = not open
	_detail_button.text = "戦績の要点へ戻る" if open else "詳しい戦績（両軍）"


## 理由の行を、見出しのすぐ下に置く（見出しの大きさに合わせる）。
func _place_reason() -> void:
	var height := _headline.size.y * _headline.scale.y
	var top := _headline.position.y + _headline.size.y / 2.0 - height / 2.0
	_reason.position.y = top + height - 6.0


func _headline_color(summary: RefCounted) -> Color:
	match summary.tone:
		ResultSummary.Tone.VICTORY:
			return COLOR_VICTORY
		ResultSummary.Tone.DEFEAT:
			return COLOR_DEFEAT
		ResultSummary.Tone.SIDE:
			if summary.winner < team_colors.size():
				return team_colors[summary.winner].lightened(0.4)
	return COLOR_DRAW


func _sound(name: StringName) -> void:
	if play_sound.is_valid():
		play_sound.call(name)


# ---- 組み立て ----


func _build_stats() -> void:
	_stats_panel = _panel()
	_stats_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_stats_panel.custom_minimum_size = Vector2(460.0, 0.0)
	_body.add_child(_stats_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	_stats_panel.add_child(column)
	_stats_title = _label(18)
	_stats_title.add_theme_color_override("font_color", COLOR_DIM)
	_stats_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_stats_title)
	_stats_grid = GridContainer.new()
	_stats_grid.columns = 2
	_stats_grid.add_theme_constant_override("h_separation", 18)
	_stats_grid.add_theme_constant_override("v_separation", 2)
	_stats_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_stats_grid)


func _build_mvp() -> void:
	_mvp_panel = _panel()
	_mvp_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_mvp_panel.custom_minimum_size = Vector2(460.0, 0.0)
	_body.add_child(_mvp_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	_mvp_panel.add_child(column)
	_mvp_head = _label(24)
	_mvp_head.text = "★ M V P ★"
	_mvp_head.add_theme_color_override("font_color", COLOR_MVP)
	_mvp_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_mvp_head)
	_mvp_name = _label(28)
	_mvp_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_mvp_name)
	_mvp_numbers = _label(19)
	_mvp_numbers.add_theme_color_override("font_color", COLOR_DIM)
	_mvp_numbers.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_mvp_numbers)


func _build_detail() -> void:
	_detail_panel = _panel()
	_detail_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_detail_panel.visible = false
	_body.add_child(_detail_panel)
	_detail = _label(15)
	_detail.add_theme_color_override("font_color", COLOR_DIM)
	_detail.custom_minimum_size = Vector2(DETAIL_WIDTH, 0.0)
	_detail_panel.add_child(_detail)


func _build_actions() -> void:
	_actions = VBoxContainer.new()
	_actions.add_theme_constant_override("separation", 8)
	_actions.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_body.add_child(_actions)
	var row := _row()
	var again := _button("同じ盤面でもう一度", 240.0)
	again.set_meta(&"sound", &"ui_confirm")
	again.pressed.connect(func() -> void: restart_pressed.emit(0, false))
	row.add_child(again)
	for stage: BoardGenerator.Stage in MatchSetup.STAGE_NAMES:
		var button := _button("新しい盤面: %s" % MatchSetup.stage_name(stage), 0.0)
		button.set_meta(&"sound", &"ui_confirm")
		button.pressed.connect(func() -> void: restart_pressed.emit(stage, true))
		row.add_child(button)
	var leave := _row()
	var to_setup := _button("対戦の設定へ（軍・相手・手番）", 320.0)
	to_setup.pressed.connect(setup_pressed.emit)
	leave.add_child(to_setup)
	var to_title := _button("タイトルへ", 180.0)
	to_title.pressed.connect(title_pressed.emit)
	leave.add_child(to_title)
	_detail_button = _button("", 220.0)
	_detail_button.pressed.connect(toggle_detail)
	leave.add_child(_detail_button)
	_prompt = _label(16)
	_prompt.text = "行き先を選ぶ（Enter でタイトルへ）"
	_prompt.add_theme_color_override("font_color", COLOR_DIM)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_actions.add_child(_prompt)


func _row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_actions.add_child(row)
	return row


func _button(text: String, width: float) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 17)
	button.custom_minimum_size = Vector2(width, 42.0)
	button.focus_mode = Control.FOCUS_NONE
	_buttons.append(button)
	return button


func _panel() -> PanelContainer:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12.0)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel


func _label(font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
