extends "res://game/talk_screen/talk_board.gd"
## 会話の場面（docs/story.md）。話し手の姿（駒の 3D の形。talk_figure.gd）を左右に立たせ、下に話し手の名前の札（陣営の色）と文の枠。
## 人の軍の話し手は左、敵の軍の話し手は右。話している側を明るく大きく、話していない側を暗く小さく。背景は対戦と同じ景色（backdrop.gd）。
## 立つ所は左右に 1 つずつ。同じ所に立つ話し手が何人かいれば、いちばん近くに話した人（まだ誰も話していなければ、次に話す人）が立つ。
## 敵の軍が出てこない会話は、最初に話す人が左、ほかの人が右（味方どうしが向き合って話す）。
## 背景は、話の盤（渡されなければ、タイトルと同じ景色）。場面の決まりは scene_flow.gd。流れ（run.gd）が、会話（talk_scene.gd。story.gd の run_of）を渡す。
## 背景と出すものは、会話の型（talk.shape）で決まる（talk_scene.gd の表）。
##
## - クリック・Enter・Space で次の文へ。文が出きる前なら、出しきるだけ。最後の文のあとは Run.NEXT で終える（流れの次の場面へ）。
## - 右クリックで 1 つ前の文へ戻る。Esc はシステムメニュー（ほかの場面と同じ）。
## - 「ログ」・ホイールを上へ・L で、これまでの文を遡って読む窓（talk_log.gd）を開く。
## - 「飛ばす」で、残りを読まずに Run.NEXT で終える。知らせの行（side 2。駒の解放など）は飛ばさず、そこで止まる。
## - 渡された会話に次の話（next_episode。ストーリーの、あとの会話）があれば、終えるときに行き先を選ばせる:
##   「次の話へ」（その話の流れを始める。Enter でも）か「話の一覧へ」（Run.NEXT。流れの行き先）。右クリックで最後の文へ戻る。
##
## ここは、組み立て（_ready）、入力、文の送り。役割ごとのファイル（game/talk_screen/）を、次の順に継ぐ:
## talk_base.gd（調整値・変数・小さな道具）→ talk_figures.gd（話し手の姿）→ talk_choice.gd（終わり方と行き先の選択）→ talk_ask.gd（選択肢）→ talk_naming.gd（主人公の名前を聞く行）
## → talk_board.gd（盤のカットシーンの舞台と出来事の塊）→ ここ。
##
## 盤のカットシーン（型が BOARD_CUT。docs/story.md の「盤のカットシーン」）: 背景は舞台（台本の兵が動く盤）。話し手の姿と見出しは出さない。
## 文の前に出来事の塊があれば、それを再生してから文を出す（再生の間は文の枠を消し、クリックで進めない）。最後の文のあとの塊は、再生してから終える。
## 「スキップ」は、残りの塊を見せずに終わりの盤まで済ませてから終える。盤の動きをまたいで、右クリックで前の文へは戻れない。


func _ready() -> void:
	if context == null:
		context = AppContext.new()  # アプリを通さずに置いたとき
	var given: Variant = context.run_data()
	if given != null:
		talk = given
	_refresh_lines()
	# カットシーン（docs/story.md の「カットシーン」）: 文の枠も話し手も出さず、背景（景色か、色の幕）の上に、地の文を真ん中に出す。
	var cut := talk.shape == TalkScene.Shape.CUT
	var on_board := is_board_cut()
	var layer := CanvasLayer.new()
	_layer = layer
	# 背景は、会話の型で決まる（talk_scene.gd の表）。
	match talk.shape:
		TalkScene.Shape.MAP:
			_make_backdrop(talk.battle)  # 対戦のある話なら、背景の盤に駒を立たせる
		TalkScene.Shape.PLACE:
			_make_backdrop(null)
		TalkScene.Shape.CUT:
			if CUT_COLORS.has(talk.color):
				var fill := ColorRect.new()
				fill.color = CUT_COLORS[talk.color]
				fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
				layer.add_child(fill)
			else:
				_make_backdrop(null)
		TalkScene.Shape.BOARD_CUT:
			_make_cut_stage()
	add_child(layer)
	# 背景の盤を少し沈め、話し手の姿と文を浮かせる。
	var shade := ColorRect.new()
	shade.color = Color(Palette.SHADE, BACKDROP_SHADE if talk.shows_speakers() else CUT_SHADE)
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
	heading.text = talk.title
	heading.modulate.a = 1.0 if talk.shows_speakers() else 0.0  # カットシーンは見出しを出さない（場所は取ったまま）
	root.add_child(heading)

	_stage = Control.new()
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.resized.connect(_place_figures)
	root.add_child(_stage)
	if not on_board:
		_make_figures()  # 盤のカットシーンは、盤の兵が話し手（姿は立たせない）
	_build_options()

	var bottom := VBoxContainer.new()
	bottom.add_theme_constant_override("separation", 0)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.custom_minimum_size = Vector2(BOX_WIDTH, 0.0)
	bottom.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	root.add_child(bottom)
	_bottom = bottom
	if cut:
		# 文を画面の真ん中の高さへ（下にも、舞台と同じだけ伸びる余白を置く）。上下に黒い帯。
		var below := Control.new()
		below.size_flags_vertical = Control.SIZE_EXPAND_FILL
		below.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(below)
		for preset: Control.LayoutPreset in [Control.PRESET_TOP_WIDE, Control.PRESET_BOTTOM_WIDE]:
			var bar := ColorRect.new()
			bar.color = Palette.OUTLINE
			bar.custom_minimum_size = Vector2(0.0, CUT_BAR)
			bar.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE)
			bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			layer.add_child(bar)
			layer.move_child(bar, shade.get_index() + 1)

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
	# 行の高さは、前に「ログ」「スキップ」を置いていたときのまま（文の枠の場所を変えない）。
	var held := Control.new()
	held.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	held.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(held)
	_build_corner(layer, cut)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0.0, PLATE_GAP)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(gap)

	# 文の枠: 影の付いた板。上の縁は太く、話し手の陣営の色にする（名前の札とつながって見える）。
	var box_style := UiTheme.box(COLOR_BOX, COLOR_BORDER, 1, 8, 12.0, 10)
	box_style.border_width_top = 3
	_box_style = box_style
	if cut:
		# 枠は見せない（地も縁も影も無し。大きさと置き方は同じ）。
		box_style.bg_color = Color(Palette.INK, 0.0)
		box_style.set_border_width_all(0)
		box_style.shadow_size = 0
	box_style.content_margin_left = BOX_MARGIN_X
	box_style.content_margin_right = BOX_MARGIN_X
	box_style.content_margin_top = 18.0
	box_style.content_margin_bottom = 12.0
	var box := PanelContainer.new()
	_box = box
	box.add_theme_stylebox_override("panel", box_style)
	box.custom_minimum_size = Vector2(BOX_WIDTH, BOX_HEIGHT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(box)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(column)
	# 駒の解放の知らせ（行の unit_kind）は、文の左に、その駒のアイコンを出す（unit_icons.gd）。持ち物（item）は持ち物の印（item_icon.gd）、軍略（troop_trait）は軍略の印。
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
	_trait_face = TraitIcon.new(Traits.NONE, NOTICE_FRAME - 16.0)
	_item_frame.add_child(_trait_face)
	# 折り返しは、文を出すときに text_wrap.gd で入れる（自動の折り返しは、ひらがなの語の途中や句読点の前で切る）。
	_text = _label(TEXT_FONT, COLOR_TEXT)
	if cut:
		_text.add_theme_constant_override("outline_size", 10)  # 景色の上に直に置くので、縁取りを太くする
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
	])
	foot.add_child(_hint)

	_log = TalkLog.new()
	add_child(_log)
	_log.setup(context.overlays)
	_log.opened.connect(func() -> void: context.play_sound(&"menu_open"))
	_log.closed.connect(func() -> void: context.play_sound(&"menu_close"))

	if on_board:
		_go_to_line(0)
	else:
		_show_line(0)


## 背景の盤（話の盤か、別の場所の景色）。story_battle（story_battle.gd）があれば、その駒を立たせる
## （前の会話は初期位置、あとの会話は決着したときの駒。story_battle.gd の talk_battle）。無ければ景色だけ（マス目も本陣の旗も出さない）。
func _make_backdrop(story_battle: RefCounted) -> void:
	var shown: Battle = story_battle.talk_battle(talk.after) if story_battle != null else null
	var king_looks: Array[StringName] = []  # 三項の式で型の付いた空の配列を返すと、型の無い配列になって入らない
	if story_battle != null:
		king_looks = story_battle.king_looks()
	# 名前のある人物は、盤と同じく、その人の乗る駒をその人の形で立たせる（unit_looks.gd の assign_people）。
	var people: Dictionary = UnitLooks.assign_people(shown.units, story_battle.cast_looks()) if shown != null else {}
	_backdrop = Backdrop.new(talk.board, talk.look, shown, king_looks, people)
	_backdrop.scenery_only = shown == null
	add_child(_backdrop)


## 「スキップ」「ログ」とホイールの案内: 画面の右上の角（システムメニューのボタンの左）。会話・カットシーン・盤のカットシーンのどれでも同じ所で、
## 「ログ」は対戦の上の帯の「ログ」と同じ所（system_menu.gd の BESIDE_*）。文や話し手で動かない。文のそばに置くのは「次へ」「戻る」の案内だけ。
func _build_corner(layer: CanvasLayer, cut: bool) -> void:
	var corner := Control.new()
	corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	corner.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	corner.offset_right = -SystemMenu.BESIDE_RIGHT
	corner.offset_left = corner.offset_right - CORNER_WIDTH
	corner.offset_top = 0.0
	corner.offset_bottom = SystemMenu.BAND_HEIGHT
	Steady.mark(corner, "talk.corner", Steady.RECT)
	layer.add_child(corner)
	_corner = corner
	_log_button = Button.new()
	_log_button.text = Text.t("talk.log")
	_log_button.tooltip_text = Text.t("talk.log.tooltip")
	_log_button.focus_mode = Control.FOCUS_NONE
	_log_button.add_theme_font_size_override("font_size", 15)
	_log_button.pressed.connect(open_log)
	corner.add_child(_log_button)
	_place_in_band(_log_button, CORNER_WIDTH, SystemMenu.BESIDE_SIZE)
	_skip = Button.new()
	_skip.text = Text.t("talk.skip")
	_skip.focus_mode = Control.FOCUS_NONE
	_skip.add_theme_font_size_override("font_size", 15)
	_skip.pressed.connect(press_skip)
	corner.add_child(_skip)
	_place_in_band(_skip, _log_button.position.x - CORNER_GAP, SKIP_SIZE)
	# ホイールでログ、の案内は、ボタンの左に小さく（右の端を決めて、左へ伸ばす）。景色の上でも読めるよう、沈んだ地の札に入れる。
	var hint_plate := PanelContainer.new()
	hint_plate.add_theme_stylebox_override("panel", UiTheme.box(Color(Palette.INK, 0.6), Color(Palette.BORDER, 0.0), 0, 4, 5.0))
	hint_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_plate.anchor_top = 0.5
	hint_plate.anchor_bottom = 0.5
	hint_plate.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hint_plate.grow_vertical = Control.GROW_DIRECTION_BOTH
	corner.add_child(hint_plate)
	hint_plate.offset_left = _skip.position.x - CORNER_GAP
	hint_plate.offset_right = hint_plate.offset_left
	_log_hint = KeyMarks.new()
	_log_hint.set_parts([KeyMarks.key(Text.t("common.key.wheel"), Text.t("talk.guide.log"))])
	_log_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_plate.add_child(_log_hint)
	if cut:
		# 文だけを見せる場面なので、控えめに。
		corner.modulate.a = CUT_BUTTONS


## 右上の角のボタン button を、右の端 right・大きさ wanted（テーマの字と余白のぶん高くなれば、その高さ）で、帯の高さの真ん中に置く
## （対戦の上の帯の並びと同じ寄せ方）。木に入れてから呼ぶ（入れる前は、字の大きさが効かない）。
static func _place_in_band(button: Button, right: float, wanted: Vector2) -> void:
	button.size = wanted.max(button.get_combined_minimum_size())
	button.position = Vector2(right - button.size.x, floorf((SystemMenu.BAND_HEIGHT - button.size.y) / 2.0))


## 盤のカットシーン: 文 index の前の塊を再生してから（無ければすぐ）、文 index を出す。最後の文のあと（index が文の数）なら、終える。
func _go_to_line(index: int) -> void:
	if index >= _beat_at and not _beat_before(index).is_empty():
		_beat_playing = index
		_set_text_shown(false)
		await _cut_stage.play(_beat_before(index))
		_beat_playing = -1
		_beat_at = index + 1
		if _board_skipped:
			return  # スキップが、残りを済ませて終える
	_beat_at = maxi(_beat_at, index + 1)
	if index >= line_count():
		_end()
		return
	_show_line(index)
	_set_text_shown(true)


## 会話のログを開く（これまでに出した文。いまの文まで）。
func open_log() -> void:
	if _log.is_open() or context.overlays.is_open():
		return
	_log.open(_log_lines())


## 会話のログの窓（検査用）。
func talk_log() -> TalkLog:
	return _log


func _process(delta: float) -> void:
	_elapsed += delta
	if _index < line_count() and _shown < _line_length():
		_shown = minf(_shown + delta * CHARS_PER_SECOND, _line_length())
		_text.visible_characters = int(_shown)
	_ask_if_due()
	_ask_name_if_due()
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
	var asking := is_asking()
	if asking:
		_options_input(event)
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				press_next()
			MOUSE_BUTTON_RIGHT:
				press_back()
	elif event is InputEventKey and event.pressed and not event.echo:
		if asking:
			return  # 選ぶ間のキーは、_options_input が受けた（答えを決めたキーで、次の文まで送らない）
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
	if _board_finished:
		_end()  # スキップで終えたあと、行き先の選択をやめて戻ってきた: もう一度、行き先を選ばせる
		return
	if is_beat_playing() or _board_skipped:
		return  # 兵が動いている間は、文を進めない
	if not is_line_shown():
		_shown = _line_length()
		_text.visible_characters = -1
		_ask_if_due()
		_ask_name_if_due()
		return
	if _choice_here() != null:
		_ask_if_due()  # 選ばせる行は、答えを選ぶまで進まない
		return
	if _names_at(_index):
		_ask_name_if_due()  # 名前を聞く行は、決めるまで進まない
		return
	if is_board_cut():
		if _index + 1 < line_count():
			context.play_sound(&"ui_click")
		_go_to_line(_index + 1)
	elif _index + 1 < line_count():
		context.play_sound(&"ui_click")
		_show_line(_index + 1)
	else:
		_end()


## 1 つ前の文へ戻る（最初の文なら何もしない）。戻った文は出しきって見せる。
func press_back() -> void:
	if _index == 0 or is_beat_playing() or _board_skipped or _moves_before(_index):
		return
	context.play_sound(&"ui_back")
	_show_line(_index - 1)
	_shown = _line_length()
	_text.visible_characters = -1
	_ask_if_due()


## 「飛ばす」: 残りを読まずに会話を終える。この先に知らせの行か、選ばせる行、名前を聞く行があれば、そこへ飛ぶ（知らせは読ませ、答えは選ばせ、名前は聞く）。
func press_skip() -> void:
	if is_asking():
		return
	if is_board_cut():
		if _board_skipped:
			if _board_finished:
				_end()  # 行き先の選択をやめて戻ってきた（話の最後の場面が盤のカットシーンのとき）: もう一度選ばせる
			return
		_board_skipped = true
		context.play_sound(&"ui_click")
		await _cut_stage.finish(_unplayed_events())
		_board_finished = true
		_end()
		return
	for index in range(_index, line_count()):
		if (index > _index and _lines[index].is_notice()) or _lines[index].asks() or _names_at(index):
			context.play_sound(&"ui_click")
			if index != _index:
				_show_line(index)
			_shown = _line_length()
			_text.visible_characters = -1
			_ask_if_due()
			_ask_name_if_due()
			return
	_end()


## 答え at（0 から）を選ぶ: 覚えて、その答えに続く行へ進む。
func press_option(at: int) -> void:
	var choice := _choice_here()
	if not is_asking() or choice == null or at < 0 or at >= choice.options.size():
		return
	var key := choice.options[at].key
	_answers[choice.name] = String(key)
	if context.story != null:
		context.story.choose_answer(choice.name, key)
	_close_options()
	_refresh_lines()
	if _index + 1 < _lines.size():
		_show_line(_index + 1)
	else:
		_answered_last = true  # 最後の行で選んだ: もう選ばせない（行き先の選択の下に、答えの枠を出し直さない）
		_end()


## 名前を決めたあと: 次の行へ（名を問う行が最後なら、会話を終える）。
func _after_naming() -> void:
	if _index + 1 < _lines.size():
		_show_line(_index + 1)
	else:
		_end()


## 選ぶ間のキー: 上下（W/S）で印を動かし、Enter・Space で決める。数字のキーは、その番号の答え。Esc はシステムメニュー。
func _options_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var count := option_texts().size()
	match event.physical_keycode:
		KEY_UP, KEY_W:
			_mark_option(count - 1 if _option_at <= 0 else _option_at - 1)
			context.play_sound(&"ui_click")
		KEY_DOWN, KEY_S:
			_mark_option(0 if _option_at < 0 or _option_at >= count - 1 else _option_at + 1)
			context.play_sound(&"ui_click")
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if _option_at >= 0:
				context.play_sound(&"ui_confirm")
				press_option(_option_at)
		KEY_1, KEY_2, KEY_3, KEY_KP_1, KEY_KP_2, KEY_KP_3:
			var at: int = [KEY_1, KEY_2, KEY_3, KEY_KP_1, KEY_KP_2, KEY_KP_3].find(event.physical_keycode) % 3
			if at < count:
				context.play_sound(&"ui_confirm")
				press_option(at)
		KEY_ESCAPE:
			context.open_menu()


func line_count() -> int:
	return _lines.size()


## いま出している文の番号（0 から）。
func line_index() -> int:
	return _index


## いまの文が出きっているか。
func is_line_shown() -> bool:
	return _index >= line_count() or _shown >= _line_length()


## 背景の盤に立たせた駒の数（陣営ごと: [味方, 敵, 中立]。検査用）。
func backdrop_units() -> Array[int]:
	var counts: Array[int] = [0, 0, 0]
	if _backdrop == null:
		return counts
	for view in _backdrop.unit_views:
		counts[_backdrop.unit_sides[_backdrop.unit_views.find(view)]] += 1
	return counts


## いま立っている話し手の姿（検査用。左右に 1 人ずつまで）。
func figures() -> Array[TalkFigure]:
	return _figures.filter(func(view: TalkFigure) -> bool: return view.visible)


## 下の名前の札・「飛ばす」・文の枠が画面に占める四角（検査用。姿はこれと重ねない）。
func bottom_rect() -> Rect2:
	return _bottom.get_global_rect()


## 背景が景色だけか（検査用。マス目も本陣の旗も出さない。色の幕なら偽）。
func is_scenery_only() -> bool:
	return _backdrop != null and _backdrop.scenery_only and not _backdrop.board_view().is_grid_visible()


## 「ログ」と「スキップ」が画面に占める四角（検査用）。
func buttons_rect() -> Rect2:
	return _log_button.get_global_rect().merge(_skip.get_global_rect())


## 「ログ」のボタンが画面に占める四角（検査用。対戦の上の帯の「ログ」と同じ所）。
func log_button_rect() -> Rect2:
	return _log_button.get_global_rect()


## 右上の角（「スキップ」「ログ」とホイールの案内）が画面に占める四角（検査用）。
func corner_rect() -> Rect2:
	return _corner.get_global_rect()


## カットシーンか（検査用。盤のカットシーンは is_board_cut）。
func is_cut() -> bool:
	return talk.shape == TalkScene.Shape.CUT


## いまの文が地の文か（検査用）。
func is_narrating() -> bool:
	return _index < line_count() and _lines[_index].is_narration()


## いまの話し手の名前と文（検査用）。
func speaker() -> String:
	return _name.text


## いまの文（折り返す前のもの）。
func line_text() -> String:
	return _raw_text


func _show_line(index: int) -> void:
	_index = index
	_shown = 0.0
	_answered_last = false
	_close_options()
	if index >= line_count():
		_name.text = ""
		_text.text = ""
		_raw_text = ""
		_face.visible = false
		_item_frame.visible = false
		_count.text = ""
		_plate.visible = false
		if is_board_cut():
			_cut_stage.show_speaker("")
		return
	var line := _lines[index]
	var narration := line.is_narration()
	_plate.visible = true
	_plate.modulate.a = 0.0 if narration else 1.0  # 地の文は札を出さない（場所は取ったまま。文の枠が上下に動かないように）
	_name.text = line.name
	_text.add_theme_font_override("font", UiTheme.FONT_HEADING if narration else UiTheme.FONT_BODY)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if narration else HORIZONTAL_ALIGNMENT_LEFT
	_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER if narration else VERTICAL_ALIGNMENT_TOP
	var team := TEAM_COLORS[clampi(line.side, 0, TEAM_COLORS.size() - 1)]
	if narration:
		_box_style.border_color = COLOR_BORDER
	elif line.side >= NOTICE_SIDE:
		# 知らせ（手に入れたもの）は、陣営の色ではなく金: 選ばれている地の札と、金の縁。
		_plate_style.bg_color = Palette.CHOSEN
		_plate_style.border_color = Palette.BORDER_BRIGHT
		_box_style.border_color = Palette.BORDER_BRIGHT
	else:
		_plate_style.bg_color = team.darkened(0.15)
		_plate_style.border_color = team.lightened(0.35)
		_box_style.border_color = COLOR_BORDER.lerp(team.lightened(0.2), 0.85)
	if is_board_cut():
		_cut_stage.show_speaker("" if narration else line.name, team)  # 盤にいる話し手の頭の上に印
	_raw_text = line.text
	_text.text = fold_line(line)
	_face.visible = line.unit_kind >= 0
	if _face.visible:
		_face.set_kind(line.unit_kind as UnitKind.Id)
	_item_frame.visible = line.item >= 0 or line.troop_trait >= 0
	_item_face.visible = line.item >= 0
	if _item_face.visible:
		_item_face.item = line.item
		_item_face.queue_redraw()
	_trait_face.visible = line.troop_trait >= 0
	_trait_face.set(&"trait_id", line.troop_trait if line.troop_trait >= 0 else Traits.NONE)
	_count.text = "%d / %d" % [index + 1, line_count()]
	var standing := _standing_at(index)
	for view in _figures:
		var stands := standing[view.place] == view.who
		# 立ったばかりの姿は、動きを挟まずに明るさを決める（暗いまま出てきて、あとから明るくならない）。
		view.set_speaking(view.who == line.speaker_no(), context.checking != &"" or not view.visible or not stands)
		view.visible = stands
	if context.checking != &"":
		_shown = _line_length()  # 検査とスクリーンショットは、文を出しきって始める
	_text.visible_characters = -1 if is_line_shown() else 0
	_ask_if_due()
	_ask_name_if_due()


## いまの文が、文の枠からはみ出しているか（検査用）。文の欄より文が大きいか、文に押されて枠が決まった大きさ（BOX_WIDTH × BOX_HEIGHT）を超えたか。
func is_text_cut() -> bool:
	var need := _text.get_theme_font(&"font").get_multiline_string_size(_text.text, HORIZONTAL_ALIGNMENT_LEFT, -1, _text.get_theme_font_size(&"font_size"))
	return need.x > _text.size.x + 0.5 or need.y > _text.size.y + 0.5 or _box.size.x > BOX_WIDTH + 0.5 or _box.size.y > BOX_HEIGHT + 0.5


func _line_length() -> float:
	return float(_text.get_total_character_count())
