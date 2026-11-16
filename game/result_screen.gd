extends Control
## リザルトの画面。決着したら、対戦の画面（盤面）の上に重ねて、段階的に出す（result_summary.gd の中身）。
##
## 1. 勝敗の見出し（VICTORY / DEFEAT、人どうしは勝った側の名前）が中央に大きく出て、上へ退く。
## 2. 戦績（ステージ・経過ターン・敵軍撃破・中立撃破・聖遺物）が 1 行ずつ出る。
## 3. MVP が拡大しながら出る。
## 4. 行き先のボタンと、入力の案内が出る。**ここまで出そろうまで、行き先は選べない。**
## 出そろう前のクリック（Enter・Space でも）は、演出を飛ばして全部を出すだけ（行き先は選ばない）。
## 出そろったあとの Enter は、「次へ」を出していればそれ、「同じ盤面でもう一度」にすると決めていればそれ（ストーリーで負けたとき）、
## どちらでもなければタイトルへ（ボタンの「タイトルへ」と同じ）。Enter で選ぶボタンは、文字を大きくして目立たせる。両方の陣営の詳しい戦績は畳んでおき、ボタンで開く。
##
## 何を出すかは呼ぶ側（result_summary.gd）が決める。ここは見せ方と、押されたことを signal で知らせるだけ。

const Text := preload("res://game/text.gd")
const Palette := preload("res://game/ui_palette.gd")
const UiTheme := preload("res://game/ui_theme.gd")
const ResultSummary := preload("res://game/result_summary.gd")
const OverlayStack := preload("res://game/overlay_stack.gd")
const StatsText := preload("res://game/stats_text.gd")
const UnitIcons := preload("res://game/unit_icons.gd")

## 行き先のボタン。field はステージの鍵（versus_fields.gd）。new_board が偽なら、いまと同じ盤面でもう一度（field は見ない）。
signal restart_pressed(field: StringName, new_board: bool)
signal setup_pressed
signal title_pressed
## 「次へ」（set_continue で出したときだけ。ストーリーで勝ったとき、流れの次の場面へ）。
signal continue_pressed
## 「部隊を選び直す」（set_destinations で出したときだけ。ストーリーで、出撃準備へ戻る）。
signal squad_pressed
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
## 行き先のボタンの文字の大きさ（Enter で選ぶボタンは大きく）。
const BUTTON_FONT := 17
const BIG_FONT := 21
## 入力の案内の明滅の周期（秒）。
const BLINK_PERIOD := 1.4

## 見出しの位置（縦。中央に出たときと、退いたあと）と、退いたあとの大きさ。
const HEADLINE_CENTER_Y := 290.0
const HEADLINE_TOP_Y := 18.0
const HEADLINE_SHRUNK := 0.62
## 戦績の行は最大 5 行（ステージ・経過ターン・敵軍撃破・中立撃破・聖遺物）。5 行のときも、入力の案内が画面の下の帯
## （対戦の画面の下の帯。BattleHud.BOTTOM_BAR_HEIGHT）にかからないよう、行と行の間を詰めてある。
const BODY_TOP := 140.0
const STAT_FONT := 22
## 詳しい戦績の表: 駒の名前の列の幅、数の列の幅、行の高さ、送れる部分の高さ（px）。
## 名前の列は、いちばん長い進化先の名前（MVP の印と Lv 込み）が、数の列は見出しが切れずに収まる幅（tests/game/test_result_table.gd）。
const TABLE_NAME_WIDTH := 316.0
const TABLE_NUMBER_WIDTH := 98.0
const TABLE_ROW_HEIGHT := 34.0
const TABLE_ICON := 30.0
const TABLE_HEIGHT := 210.0
## 倒れた駒の印の列の幅（px）。
const TABLE_STATE_WIDTH := 64.0
## 表の駒の名前と、見出しの文字の大きさ。
const TABLE_NAME_FONT := 15
const TABLE_HEADING_FONT := 14

const COLOR_SHADE := Color(Palette.SHADE, 0.78)
const COLOR_PANEL := Palette.SOLID
const COLOR_DIM := Palette.TEXT_DIM
const COLOR_VICTORY := Palette.ACCENT
const COLOR_DEFEAT := Color("9cc8ff")
const COLOR_DRAW := Palette.TEXT
const COLOR_MVP := Palette.ACCENT

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
var _mvp_icon: TextureRect
var _mvp_numbers: Label
var _detail_panel: PanelContainer
var _detail: Label
## 詳しい戦績の表: 陣営の切り替え、陣営の 1 行、表の行の入れ物、いま出している陣営。
var _table_tabs: Array[Button] = []
var _table_summary: Label
var _table_rows: VBoxContainer
var _table_side := 0
## 詳しい戦績の文（stats_text.gd。画面には表で出す。検査用）。
var _detail_text := ""
var _actions: VBoxContainer
var _detail_button: Button
## 行き先のボタンのうち、対戦によって出さないことがあるもの（set_destinations）。
var _board_buttons: Array[Button] = []  # 新しい盤面（ボタンの meta の &"field" がステージの鍵）
var _setup_button: Button
var _squad_button: Button
var _continue_button: Button
var _again_button: Button
## Enter で「同じ盤面でもう一度」を選ぶか（set_continue）。
var _enter_retries := false
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
	_headline.theme_type_variation = UiTheme.LABEL_HEADING
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
	_body.add_theme_constant_override("separation", 6)
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
	_stats_title.text = Text.t("result.stats_title", {"side": summary.focus_name})
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
		var value_label := _label(STAT_FONT)
		value_label.text = line[1]
		_stats_grid.add_child(name_label)
		_stats_grid.add_child(value_label)
		_stat_rows.append([name_label, value_label])
	_mvp_icon.visible = summary.mvp_name != ""
	if summary.mvp_name != "":
		_mvp_icon.texture = UnitIcons.texture(summary.mvp_kind, summary.mvp_side, summary.mvp_evolved)
		_mvp_name.text = summary.mvp_name
		_mvp_numbers.text = summary.mvp_numbers
	else:
		_mvp_name.text = Text.t("result.mvp_none")
		_mvp_numbers.text = Text.t("result.mvp_none_note")
	_detail.text = summary.detail_head
	for side in _table_tabs.size():
		_table_tabs[side].text = summary.tables[side]["name"] if side < summary.tables.size() else ""
	show_table(summary.focus_side if summary.focus_side >= 0 and summary.focus_side < 2 else 0)
	_detail_text = summary.detail
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
	return _detail_text if visible else ""


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
				if _continue_button.visible:
					press_continue()
				elif _enter_retries:
					press_again()
				else:
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


## 出す行き先を決める（対戦の画面が、渡されたもの（battle_source.gd）に聞いて決める）。
## boards は「新しい盤面」で選べるステージの [鍵, 名前] の列（並びの順にボタンを出す）、setup は「対戦設定へ」、squad は「部隊を選び直す」を出すか。
## 「同じ盤面でもう一度」と「タイトルへ」は、いつも出す。
func set_destinations(boards: Array[Array], setup: bool, squad := false) -> void:
	while _board_buttons.size() < boards.size():
		var button := _button("", 0.0)
		button.set_meta(&"sound", &"ui_confirm")
		button.mouse_filter = _again_button.mouse_filter
		button.pressed.connect(func() -> void: restart_pressed.emit(button.get_meta(&"field"), true))
		_again_button.get_parent().add_child(button)
		_board_buttons.append(button)
	for index in _board_buttons.size():
		var button := _board_buttons[index]
		button.visible = index < boards.size()
		if button.visible:
			button.set_meta(&"field", boards[index][0])
			button.text = Text.t("result.new_board", {"board": boards[index][1]})
	_setup_button.visible = setup
	_squad_button.visible = squad


## 「次へ」を出すか（対戦の画面が、渡されたもの（battle_source.gd）に聞いて決める。決着の画面を出すたびに決める）。
## retry は、「次へ」が無いときの Enter を「同じ盤面でもう一度」にするか（偽ならタイトルへ）。
func set_continue(shown: bool, retry := false) -> void:
	_continue_button.visible = shown
	_enter_retries = retry and not shown
	_again_button.add_theme_font_size_override("font_size", BIG_FONT if _enter_retries else BUTTON_FONT)
	_prompt.text = Text.t("result.prompt", {"destination": enter_destination()})


## 入力の案内（「行き先を選ぶ（Enter で…）」）の、画面の上の場所。検査用。
func prompt_rect() -> Rect2:
	return _prompt.get_global_rect()


## 出そろったあとの Enter で選ぶ行き先の名前（ボタンの文字）。
func enter_destination() -> String:
	if _continue_button.visible:
		return _continue_button.text
	if _enter_retries:
		return _again_button.text
	return Text.t("result.to_title")


## 「同じ盤面でもう一度」を押す。
func press_again() -> void:
	restart_pressed.emit(&"", false)


## 「次へ」を出しているか。検査用。
func can_continue() -> bool:
	return _continue_button.visible


## 「次へ」を押す（出していなければ何もしない）。
func press_continue() -> void:
	if _continue_button.visible:
		continue_pressed.emit()


## 「対戦設定へ」を出しているか。検査用。
func can_go_to_setup() -> bool:
	return _setup_button.visible


## 「部隊を選び直す」を出しているか。検査用。
func can_choose_squad() -> bool:
	return _squad_button.visible


## 「部隊を選び直す」を押す（出していなければ何もしない）。
func press_choose_squad() -> void:
	if _squad_button.visible:
		squad_pressed.emit()


## 「新しい盤面」で出しているステージの鍵。検査用。
func new_board_fields() -> Array[StringName]:
	var shown: Array[StringName] = []
	for button in _board_buttons:
		if button.visible:
			shown.append(button.get_meta(&"field"))
	return shown


func _set_buttons_enabled(enabled: bool) -> void:
	for button in _buttons:
		button.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE


func _show_detail(open: bool) -> void:
	_detail_panel.visible = open
	_stats_panel.visible = not open
	_mvp_panel.visible = not open
	_detail_button.text = Text.t("result.detail_back") if open else Text.t("result.detail_open")


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
	_stats_grid.add_theme_constant_override("v_separation", 0)
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
	# アイコン（左）と、名前・数（右）を 1 段に並べる（アイコンのぶん、枠を高くしない）。
	var mvp_row := HBoxContainer.new()
	mvp_row.alignment = BoxContainer.ALIGNMENT_CENTER
	mvp_row.add_theme_constant_override("separation", 10)
	column.add_child(mvp_row)
	_mvp_icon = UnitIcons.rect(UnitKind.Id.KING, 0, false, 64.0)
	mvp_row.add_child(_mvp_icon)
	var mvp_lines := VBoxContainer.new()
	mvp_lines.add_theme_constant_override("separation", 0)
	mvp_lines.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mvp_row.add_child(mvp_lines)
	_mvp_name = _label(28)
	_mvp_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mvp_lines.add_child(_mvp_name)
	_mvp_numbers = _label(19)
	_mvp_numbers.add_theme_color_override("font_color", COLOR_DIM)
	_mvp_numbers.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mvp_lines.add_child(_mvp_numbers)


## 詳しい戦績（両軍）: 全体の 1 行、陣営の切り替え、陣営の 1 行、駒ごとの表（行が駒、列が数。長ければ縦に送る）。
func _build_detail() -> void:
	_detail_panel = _panel()
	_detail_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_detail_panel.visible = false
	_body.add_child(_detail_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	_detail_panel.add_child(column)
	_detail = _label(15)
	_detail.add_theme_color_override("font_color", COLOR_DIM)
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_detail)
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 8)
	column.add_child(tabs)
	for side in 2:
		var tab := Button.new()
		tab.toggle_mode = true
		tab.focus_mode = Control.FOCUS_NONE
		tab.custom_minimum_size = Vector2(220.0, 34.0)
		tab.add_theme_font_size_override("font_size", 16)
		tab.pressed.connect(func() -> void: show_table(side))
		tabs.add_child(tab)
		_table_tabs.append(tab)
	_table_summary = _label(15)
	_table_summary.add_theme_color_override("font_color", COLOR_DIM)
	_table_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_table_summary)
	var header_box := PanelContainer.new()
	header_box.add_theme_stylebox_override("panel", UiTheme.box(Color.TRANSPARENT, Color.TRANSPARENT, 0, UiTheme.CORNER, 2.0))
	column.add_child(header_box)
	var header := _table_line()
	header_box.add_child(header)
	var icon_room := Control.new()
	icon_room.custom_minimum_size = Vector2(TABLE_ICON, 0.0)
	header.add_child(icon_room)
	header.add_child(_table_cell(Text.t("result.table.unit"), TABLE_NAME_WIDTH, true, HORIZONTAL_ALIGNMENT_LEFT))
	for spec: Array in StatsText.COLUMNS:
		header.add_child(_table_cell(Text.t(spec[1]), TABLE_NUMBER_WIDTH, true))
	header.add_child(_table_cell("", TABLE_STATE_WIDTH, true))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0.0, TABLE_HEIGHT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_table_rows = VBoxContainer.new()
	_table_rows.add_theme_constant_override("separation", 2)
	scroll.add_child(_table_rows)


## 詳しい戦績の表に、side の陣営の駒を出す（切り替えのボタンと同じ）。
func show_table(side: int) -> void:
	if _summary == null or _summary.tables.size() <= side:
		return
	_table_side = side
	for i in _table_tabs.size():
		_table_tabs[i].set_pressed_no_signal(i == side)
	var table: Dictionary = _summary.tables[side]
	_table_summary.text = table["summary"]
	for child in _table_rows.get_children():
		_table_rows.remove_child(child)
		child.queue_free()
	for row: Dictionary in table["rows"]:
		_table_rows.add_child(_table_row(row))


## いま表に出している陣営と、その行の駒の名前（検査用）。
func table_side() -> int:
	return _table_side


func table_names() -> Array[String]:
	var names: Array[String] = []
	for row in _table_rows.get_children():
		if not row.is_queued_for_deletion():
			names.append((row.get_child(0).get_child(1) as Label).text)
	return names


## 表の 1 行（駒）。MVP の行は札の地と金の文字、倒れた駒は「撃破された」の印。
func _table_row(row: Dictionary) -> Control:
	# どの行も同じ余白の地（MVP の行だけ薄く塗る）にして、列の位置をそろえる。
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.box(Palette.WASH if row["mvp"] else Color.TRANSPARENT, Color.TRANSPARENT, 0, UiTheme.CORNER, 2.0))
	var line := _table_line()
	panel.add_child(line)
	var icon := UnitIcons.rect(row["kind"], row["side"], row["evolved"], TABLE_ICON)
	line.add_child(icon)
	var name_label := _table_cell(("★ " if row["mvp"] else "") + row["name"], TABLE_NAME_WIDTH, false, HORIZONTAL_ALIGNMENT_LEFT)
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	line.add_child(name_label)
	for spec: Array in StatsText.COLUMNS:
		var value: int = row[spec[0]]
		var cell := _table_cell(str(value) if value != 0 else "-", TABLE_NUMBER_WIDTH)
		line.add_child(cell)
	line.add_child(_table_cell(Text.t("result.table.defeated") if row["defeated"] else "", TABLE_STATE_WIDTH, true))
	if row["mvp"]:
		for cell in line.get_children():
			if cell is Label:
				(cell as Label).add_theme_color_override("font_color", COLOR_MVP)
	if row["defeated"]:
		icon.modulate.a = 0.45
	return panel


func _table_line() -> HBoxContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 6)
	line.custom_minimum_size = Vector2(0.0, TABLE_ROW_HEIGHT - 4.0)
	return line


func _table_cell(text: String, width: float, dim := false, align := HORIZONTAL_ALIGNMENT_RIGHT) -> Label:
	var label := _label(TABLE_NAME_FONT if not dim else TABLE_HEADING_FONT)
	label.text = text
	label.custom_minimum_size = Vector2(width, 0.0)
	label.clip_text = true  # 列の幅を中身で広げない（見出しと数の列がずれないように）
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_vertical = Control.SIZE_FILL
	if dim:
		label.add_theme_color_override("font_color", COLOR_DIM)
	return label


func _build_actions() -> void:
	_actions = VBoxContainer.new()
	_actions.add_theme_constant_override("separation", 6)
	_actions.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_body.add_child(_actions)
	var row := _row()
	# 「次へ」は「同じ盤面でもう一度」と同じ行の先頭に置く（ストーリーでは新しい盤面のボタンが出ないので、行が空く。
	# 行を分けると、戦績の行が多いときにボタンが画面の下の帯に重なる）。
	_continue_button = _button(Text.t("result.next"), 240.0)
	_continue_button.set_meta(&"sound", &"ui_confirm")
	_continue_button.theme_type_variation = UiTheme.BUTTON_PRIMARY
	_continue_button.add_theme_font_size_override("font_size", BIG_FONT)
	_continue_button.pressed.connect(press_continue)
	_continue_button.visible = false
	row.add_child(_continue_button)
	_again_button = _button(Text.t("result.again"), 240.0)
	_again_button.set_meta(&"sound", &"ui_confirm")
	_again_button.pressed.connect(press_again)
	row.add_child(_again_button)
	# 「新しい盤面」のボタンは、この行に set_destinations が足す。
	var leave := _row()
	_setup_button = _button(Text.t("result.setup"), 320.0)
	_setup_button.pressed.connect(setup_pressed.emit)
	leave.add_child(_setup_button)
	_squad_button = _button(Text.t("result.squad"), 220.0)
	_squad_button.pressed.connect(press_choose_squad)
	_squad_button.visible = false
	leave.add_child(_squad_button)
	var to_title := _button(Text.t("result.to_title"), 180.0)
	to_title.pressed.connect(title_pressed.emit)
	leave.add_child(to_title)
	_detail_button = _button("", 220.0)
	_detail_button.pressed.connect(toggle_detail)
	leave.add_child(_detail_button)
	_prompt = _label(16)
	_prompt.text = Text.t("result.prompt_title")
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
	button.add_theme_font_size_override("font_size", BUTTON_FONT)
	button.custom_minimum_size = Vector2(width, 42.0)
	button.focus_mode = Control.FOCUS_NONE
	_buttons.append(button)
	return button


func _panel() -> PanelContainer:
	var style := UiTheme.box(COLOR_PANEL, Color(Palette.BORDER, 0.9), 1, 6, 12.0)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel


func _label(font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
