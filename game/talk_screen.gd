extends "res://game/talk_screen/talk_choice.gd"
## 会話の場面（docs/story.md）。話し手の姿（駒の 3D の形。talk_figure.gd）を左右に立たせ、下に話し手の名前の札（陣営の色）と文の枠。
## 人の軍の話し手は左、敵の軍の話し手は右。話している側を明るく大きく、話していない側を暗く小さく。背景は対戦と同じ景色（backdrop.gd）。
## 立つ所は左右に 1 つずつ。同じ所に立つ話し手が何人かいれば、いちばん近くに話した人（まだ誰も話していなければ、次に話す人）が立つ。
## 敵の軍が出てこない会話は、最初に話す人が左、ほかの人が右（味方どうしが向き合って話す）。
## 背景は、話の盤（渡されなければ、タイトルと同じ景色）。場面の決まりは scene_flow.gd。流れ（run.gd）が、会話（story.gd の talk_of）を渡す。
##
## - クリック・Enter・Space で次の文へ。文が出きる前なら、出しきるだけ。最後の文のあとは Run.NEXT で終える（流れの次の場面へ）。
## - 右クリックで 1 つ前の文へ戻る。Esc はシステムメニュー（ほかの場面と同じ）。
## - 「ログ」・ホイールを上へ・L で、これまでの文を遡って読む窓（talk_log.gd）を開く。
## - 「飛ばす」で、残りを読まずに Run.NEXT で終える。知らせの行（side 2。駒の解放など）は飛ばさず、そこで止まる。
## - 渡された会話に次の話（"next_episode"。ストーリーの、あとの会話）があれば、終えるときに行き先を選ばせる:
##   「次の話へ」（その話の流れを始める。Enter でも）か「話の一覧へ」（Run.NEXT。流れの行き先）。右クリックで最後の文へ戻る。
##
## ここは、組み立て（_ready）、入力、文の送り。役割ごとのファイル（game/talk_screen/）を、次の順に継ぐ:
## talk_base.gd（調整値・変数・小さな道具）→ talk_figures.gd（話し手の姿）→ talk_choice.gd（終わり方と行き先の選択）→ ここ。


func _ready() -> void:
	if context == null:
		context = AppContext.new()  # アプリを通さずに置いたとき
	var given: Variant = context.run_data()
	if given != null:
		talk = given
	# 話の流れの会話なら、背景の盤に駒を立たせる（前の会話は初期位置、あとの会話は決着したときの駒。story_battle.gd の talk_battle）。
	var story_battle: RefCounted = talk.get("battle")
	var shown: Battle = story_battle.talk_battle(talk.get("after", false)) if story_battle != null else null
	var king_looks: Array[StringName] = []  # 三項の式で型の付いた空の配列を返すと、型の無い配列になって入らない
	if story_battle != null:
		king_looks = story_battle.king_looks()
	# 名前のある人物は、盤と同じく、その人の乗る駒をその人の形で立たせる（unit_looks.gd の assign_people）。
	var people: Dictionary = UnitLooks.assign_people(shown.units, story_battle.cast_looks()) if shown != null else {}
	_backdrop = Backdrop.new(talk.get("board"), talk.get("look", &""), shown, king_looks, people)
	add_child(_backdrop)
	var layer := CanvasLayer.new()
	add_child(layer)
	_layer = layer
	# 背景の盤を少し沈め、話し手の姿と文を浮かせる。
	var shade := ColorRect.new()
	shade.color = Color(Palette.SHADE, BACKDROP_SHADE)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(shade)
	# 足元を、下から夜の藍へ沈める（話し手の姿が、舞台に立って見える）。四隅も沈める。
	layer.add_child(_floor_shade())
	layer.add_child(UiTheme.vignette())
	# 縦に、見出し・話し手の姿の舞台・下の名前の札と文の枠。姿は舞台の中に収め、札・文の枠・「飛ばす」とは重ねない。
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = MARGIN.x
	root.offset_right = -MARGIN.x
	root.offset_top = MARGIN.y
	root.offset_bottom = -BOX_BOTTOM
	root.add_theme_constant_override("separation", 0)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var heading := _label(28, COLOR_TEXT)
	heading.theme_type_variation = UiTheme.LABEL_HEADING
	heading.add_theme_constant_override("outline_size", 10)  # 景色の上に直に置くので、縁取りを太くする
	heading.text = talk.get("title", "")
	root.add_child(heading)

	_stage = Control.new()
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.resized.connect(_place_figures)
	root.add_child(_stage)
	_make_figures()

	var bottom := VBoxContainer.new()
	bottom.add_theme_constant_override("separation", 0)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.custom_minimum_size = Vector2(BOX_WIDTH, 0.0)
	bottom.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	root.add_child(bottom)
	_bottom = bottom

	var top_row := HBoxContainer.new()
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(top_row)
	# 名前の札: 話し手の陣営の色の、角を落とした札（色と縁は、行を出すときに決める）。
	_plate_style = UiTheme.box(Palette.RAISED, Palette.BORDER, 1, 8, 4.0, 4)
	_plate_style.corner_detail = 1
	_plate_style.border_width_bottom = 2
	_plate_style.content_margin_left = 20.0
	_plate_style.content_margin_right = 20.0
	_plate = PanelContainer.new()
	_plate.add_theme_stylebox_override("panel", _plate_style)
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 札の幅は、話し手の名前の長さで変えない（docs/ui-theme.md の「枠の大きさ」）。名前は真ん中に置く。
	_plate.custom_minimum_size = Vector2(PLATE_WIDTH, 0.0)
	Steady.mark(_plate, "talk.name_plate", Steady.RECT)
	top_row.add_child(_plate)
	_name = _label(22, Color.WHITE)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_plate.add_child(_name)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(spacer)
	_log_button = Button.new()
	_log_button.text = Text.t("talk.log")
	_log_button.tooltip_text = Text.t("talk.log.tooltip")
	_log_button.focus_mode = Control.FOCUS_NONE
	_log_button.add_theme_font_size_override("font_size", 17)
	_log_button.custom_minimum_size = Vector2(110.0, 36.0)
	_log_button.size_flags_vertical = Control.SIZE_SHRINK_END
	_log_button.pressed.connect(open_log)
	top_row.add_child(_log_button)
	var buttons_gap := Control.new()
	buttons_gap.custom_minimum_size = Vector2(8.0, 0.0)
	buttons_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(buttons_gap)
	_skip = Button.new()
	_skip.text = Text.t("talk.skip")
	_skip.focus_mode = Control.FOCUS_NONE
	_skip.add_theme_font_size_override("font_size", 17)
	_skip.custom_minimum_size = Vector2(110.0, 36.0)
	_skip.size_flags_vertical = Control.SIZE_SHRINK_END
	_skip.pressed.connect(press_skip)
	top_row.add_child(_skip)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0.0, 6.0)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(gap)

	# 文の枠: 影の付いた板。上の縁は太く、話し手の陣営の色にする（名前の札とつながって見える）。
	var box_style := UiTheme.box(COLOR_BOX, COLOR_BORDER, 1, 8, 12.0, 10)
	box_style.border_width_top = 3
	_box_style = box_style
	box_style.content_margin_left = BOX_MARGIN_X
	box_style.content_margin_right = BOX_MARGIN_X
	box_style.content_margin_top = 18.0
	box_style.content_margin_bottom = 12.0
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", box_style)
	box.custom_minimum_size = Vector2(BOX_WIDTH, BOX_HEIGHT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(box)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(column)
	# 駒の解放の知らせ（行に "kind" がある）は、文の左に、その駒のアイコンを出す（unit_icons.gd）。持ち物（"item"）は持ち物の印（item_icon.gd）。
	var text_row := HBoxContainer.new()
	text_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_row.add_theme_constant_override("separation", NOTICE_GAP)
	column.add_child(text_row)
	# どちらも、金の縁の額に入れる（手に入れたものとして見せる）。駒の額には役割の印が付く。
	_face = UnitFrame.new(UnitKind.Id.KING, 0, NOTICE_FRAME)
	_face.edge = Palette.BORDER_BRIGHT
	_face.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_face.visible = false
	text_row.add_child(_face)
	_item_frame = PanelContainer.new()
	_item_frame.add_theme_stylebox_override("panel", UiTheme.box(Color(Palette.INK, 0.85), Palette.BORDER_BRIGHT, 1, 6, 8.0))
	_item_frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_item_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_item_frame.visible = false
	text_row.add_child(_item_frame)
	_item_face = ItemIcon.new(Equipment.Id.IRON_SHIELD, NOTICE_FRAME - 16.0)
	_item_frame.add_child(_item_face)
	# 折り返しは、文を出すときに text_wrap.gd で入れる（自動の折り返しは、ひらがなの語の途中や句読点の前で切る）。
	_text = _label(TEXT_FONT, COLOR_TEXT)
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_row.add_child(_text)
	var foot := HBoxContainer.new()
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(foot)
	_count = _label(15, COLOR_DIM)
	_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(_count)
	_hint = KeyMarks.new()
	_hint.set_parts([
		KeyMarks.key(Text.t("common.key.click"), Text.t("talk.guide.next")),
		KeyMarks.key(Text.t("common.key.right_click"), Text.t("talk.guide.back")),
		KeyMarks.key(Text.t("common.key.wheel"), Text.t("talk.guide.log")),
	])
	foot.add_child(_hint)

	_log = TalkLog.new()
	add_child(_log)
	_log.setup(context.overlays)
	_log.opened.connect(func() -> void: context.play_sound(&"menu_open"))
	_log.closed.connect(func() -> void: context.play_sound(&"menu_close"))

	_show_line(0)


## 会話のログを開く（これまでに出した文。いまの文まで）。
func open_log() -> void:
	if _log.is_open() or context.overlays.is_open():
		return
	var lines: Array = talk.get("lines", [])
	_log.open(lines.slice(0, mini(_index + 1, lines.size())))


## 会話のログの窓（検査用）。
func talk_log() -> TalkLog:
	return _log


func _process(delta: float) -> void:
	_elapsed += delta
	if _index < line_count() and _shown < _line_length():
		_shown = minf(_shown + delta * CHARS_PER_SECOND, _line_length())
		_text.visible_characters = int(_shown)
	_hint.modulate.a = 1.0 if not is_line_shown() else 0.5 + 0.5 * (0.5 + 0.5 * cos(_elapsed * TAU / BLINK_PERIOD))


func _unhandled_input(event: InputEvent) -> void:
	if context.overlays.is_open():
		return
	var wheel_up: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP
	var log_key: bool = event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_L
	if wheel_up or log_key:
		get_viewport().set_input_as_handled()
		open_log()
		return
	if is_choosing():
		_choice_input(event)
		return
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				press_next()
			MOUSE_BUTTON_RIGHT:
				press_back()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				press_next()
			KEY_ESCAPE:
				context.open_menu()


## システムメニューの「戻る」の文字（ほかの場面と同じく、行き先を書く）。
func resume_label() -> String:
	return Text.t("talk.resume")


## 次へ: 文が出きる前なら出しきる。出ていたら次の文へ。最後の文のあとは、会話を終える。
func press_next() -> void:
	if not is_line_shown():
		_shown = _line_length()
		_text.visible_characters = -1
		return
	if _index + 1 < line_count():
		context.play_sound(&"ui_click")
		_show_line(_index + 1)
	else:
		_end()


## 1 つ前の文へ戻る（最初の文なら何もしない）。戻った文は出しきって見せる。
func press_back() -> void:
	if _index == 0:
		return
	context.play_sound(&"ui_back")
	_show_line(_index - 1)
	_shown = _line_length()
	_text.visible_characters = -1


## 「飛ばす」: 残りを読まずに会話を終える。この先に知らせの行があれば、そこへ飛ぶ（知らせは読ませる）。
func press_skip() -> void:
	for index in range(_index + 1, line_count()):
		if int(talk["lines"][index].get("side", 0)) == NOTICE_SIDE:
			context.play_sound(&"ui_click")
			_show_line(index)
			return
	_end()


func line_count() -> int:
	return talk.get("lines", []).size()


## いま出している文の番号（0 から）。
func line_index() -> int:
	return _index


## いまの文が出きっているか。
func is_line_shown() -> bool:
	return _index >= line_count() or _shown >= _line_length()


## 背景の盤に立たせた駒の数（陣営ごと: [味方, 敵, 中立]。検査用）。
func backdrop_units() -> Array[int]:
	var counts: Array[int] = [0, 0, 0]
	for view in _backdrop.unit_views:
		counts[_backdrop.unit_sides[_backdrop.unit_views.find(view)]] += 1
	return counts


## いま立っている話し手の姿（検査用。左右に 1 人ずつまで）。
func figures() -> Array[TalkFigure]:
	return _figures.filter(func(view: TalkFigure) -> bool: return view.visible)


## 下の名前の札・「飛ばす」・文の枠が画面に占める四角（検査用。姿はこれと重ねない）。
func bottom_rect() -> Rect2:
	return _bottom.get_global_rect()


## いまの文が地の文か（検査用）。
func is_narrating() -> bool:
	return _index < line_count() and is_narration(talk["lines"][_index])


## いまの話し手の名前と文（検査用）。
func speaker() -> String:
	return _name.text


## いまの文（折り返す前のもの）。
func line_text() -> String:
	return _raw_text


func _show_line(index: int) -> void:
	_index = index
	_shown = 0.0
	if index >= line_count():
		_name.text = ""
		_text.text = ""
		_raw_text = ""
		_face.visible = false
		_item_frame.visible = false
		_count.text = ""
		_plate.visible = false
		return
	var line: Dictionary = talk["lines"][index]
	var narration := is_narration(line)
	_plate.visible = true
	_plate.modulate.a = 0.0 if narration else 1.0  # 地の文は札を出さない（場所は取ったまま。文の枠が上下に動かないように）
	_name.text = line.get("name", "")
	_text.add_theme_font_override("font", UiTheme.FONT_HEADING if narration else UiTheme.FONT_BODY)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if narration else HORIZONTAL_ALIGNMENT_LEFT
	_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER if narration else VERTICAL_ALIGNMENT_TOP
	var team := TEAM_COLORS[clampi(int(line.get("side", 0)), 0, TEAM_COLORS.size() - 1)]
	if narration:
		_box_style.border_color = COLOR_BORDER
	elif int(line.get("side", 0)) >= NOTICE_SIDE:
		# 知らせ（手に入れたもの）は、陣営の色ではなく金: 選ばれている地の札と、金の縁。
		_plate_style.bg_color = Palette.CHOSEN
		_plate_style.border_color = Palette.BORDER_BRIGHT
		_box_style.border_color = Palette.BORDER_BRIGHT
	else:
		_plate_style.bg_color = team.darkened(0.15)
		_plate_style.border_color = team.lightened(0.35)
		_box_style.border_color = COLOR_BORDER.lerp(team.lightened(0.2), 0.85)
	_raw_text = line.get("text", "")
	_text.text = fold_line(line)
	_face.visible = line.has("kind")
	if _face.visible:
		_face.set_kind(line["kind"])
	_item_frame.visible = line.has("item")
	if _item_frame.visible:
		_item_face.item = line["item"]
		_item_face.queue_redraw()
	_count.text = "%d / %d" % [index + 1, line_count()]
	var standing := _standing_at(index)
	for view in _figures:
		var stands := standing[view.place] == view.who
		# 立ったばかりの姿は、動きを挟まずに明るさを決める（暗いまま出てきて、あとから明るくならない）。
		view.set_speaking(view.who == _who(line), context.checking != &"" or not view.visible or not stands)
		view.visible = stands
	if context.checking != &"":
		_shown = _line_length()  # 検査とスクリーンショットは、文を出しきって始める
	_text.visible_characters = -1 if is_line_shown() else 0


func _line_length() -> float:
	return float(_text.get_total_character_count())
