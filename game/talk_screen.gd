extends Node
## 会話の場面（docs/story.md）。話し手の姿（駒の 3D の形。talk_figure.gd）を左右に立たせ、下に話し手の名前の札（陣営の色）と文の枠。
## 人の軍の話し手は左、敵の軍の話し手は右。話している側を明るく大きく、話していない側を暗く小さく。背景は対戦と同じ景色（backdrop.gd）。
## 立つ所は左右に 1 つずつ。同じ所に立つ話し手が何人かいれば、いちばん近くに話した人（まだ誰も話していなければ、次に話す人）が立つ。
## 敵の軍が出てこない会話は、最初に話す人が左、ほかの人が右（味方どうしが向き合って話す）。
## 背景は、話の盤（渡されなければ、タイトルと同じ景色）。場面の決まりは scene_flow.gd。流れ（run.gd）が、会話（story.gd の talk_of）を渡す。
##
## - クリック・Enter・Space で次の文へ。文が出きる前なら、出しきるだけ。最後の文のあとは Run.NEXT で終える（流れの次の場面へ）。
## - 右クリックで 1 つ前の文へ戻る。Esc はシステムメニュー（ほかの場面と同じ）。
## - 「飛ばす」で、残りを読まずに Run.NEXT で終える。知らせの行（side 2。駒の解放など）は飛ばさず、そこで止まる。
## - 渡された会話に次の話（"next_episode"。ストーリーの、あとの会話）があれば、終えるときに行き先を選ばせる:
##   「次の話へ」（その話の流れを始める。Enter でも）か「話の一覧へ」（Run.NEXT。流れの行き先）。右クリックで最後の文へ戻る。

const Text := preload("res://game/text.gd")
const Palette := preload("res://game/ui_palette.gd")
const AppContext := preload("res://game/app_context.gd")
const UnitIcons := preload("res://game/unit_icons.gd")
const ItemIcon := preload("res://game/item_icon.gd")
const Backdrop := preload("res://game/backdrop.gd")
const Run := preload("res://game/run.gd")
const TalkFigure := preload("res://game/talk_figure.gd")
const UiTheme := preload("res://game/ui_theme.gd")

signal finished(outcome: StringName)

## 文を出す速さ（1 秒あたりの文字数）。検査では待たない。
const CHARS_PER_SECOND := 45.0
const BOX_WIDTH := 980.0
const BOX_HEIGHT := 150.0
const BOX_BOTTOM := 40.0
## 背景の盤に重ねる幕の濃さ（Palette.SHADE の色）。
const BACKDROP_SHADE := 0.3
## 画面の端から見出しまでの余白。
const MARGIN := Vector2(32.0, 24.0)
## 話し手の姿の枠の横幅の上限（文の枠の幅に対する割合。左右の姿が真ん中で重ならない）。
const FIGURE_MAX_WIDTH := 0.42
## 送りの印の明滅の周期（秒）。
const BLINK_PERIOD := 1.2
## 名前の札の色（0 = 人の軍、1 = 敵の軍は battle_screen.gd の TEAM_COLORS と同じ。2 = 知らせ）。
const TEAM_COLORS: Array[Color] = [Palette.TEAM_BLUE, Palette.TEAM_RED, Palette.TEXT_OFF]
## 知らせの行の side（story.gd の NOTICE_SIDE）。
const NOTICE_SIDE := 2

const COLOR_BOX := Color(Palette.PANEL, 0.92)
const COLOR_BORDER := Palette.BORDER
const COLOR_TEXT := Palette.TEXT
const COLOR_DIM := Palette.TEXT_DIM

var context: AppContext
## 渡された会話（{"title": 見出し, "lines": [{"side", "name", "text"}, …], "board": 背景の盤, "look": 盤の見た目,
## "figures": 話し手の姿（行の "who" の番号の並び）}。story.gd の talk_of）。行に "who" が無ければ、陣営（"side"）の番号。
var talk := {}
var _index := 0
var _shown := 0.0  # いまの文の、出した文字数
var _elapsed := 0.0
var _plate: PanelContainer
var _plate_style: StyleBoxFlat
var _name: Label
var _text: Label
var _face: TextureRect
var _item_face: Control  # item_icon.gd
var _hint: Label
var _count: Label
var _skip: Button
## 話し手の姿を立たせる所（見出しと、下の名前の札・文の枠の間）と、話し手の姿（会話に出てくる話し手ごとに 1 つ。
## 同じ所に立つ話し手のうち、いま立っている 1 人だけを見せる）。
var _stage: Control
var _figures: Array[TalkFigure] = []
## 下の名前の札・「飛ばす」・文の枠をまとめたもの（姿と重ねない）。
var _bottom: Control
## 会話を終えるときの行き先の選択（次の話があるときだけ。_end で出す）。
var _choice: Control
var _layer: CanvasLayer


func _ready() -> void:
	if context == null:
		context = AppContext.new()  # アプリを通さずに置いたとき
	var given: Variant = context.run_data()
	if given != null:
		talk = given
	add_child(Backdrop.new(talk.get("board"), talk.get("look", &"")))
	var layer := CanvasLayer.new()
	add_child(layer)
	_layer = layer
	# 背景の盤を少し沈め、話し手の姿と文を浮かせる。
	var shade := ColorRect.new()
	shade.color = Color(Palette.SHADE, BACKDROP_SHADE)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(shade)
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

	var heading := _label(26, COLOR_TEXT)
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
	_plate_style = StyleBoxFlat.new()
	_plate_style.set_corner_radius_all(4)
	_plate_style.corner_radius_bottom_left = 0
	_plate_style.corner_radius_bottom_right = 0
	_plate_style.content_margin_left = 18.0
	_plate_style.content_margin_right = 18.0
	_plate_style.content_margin_top = 4.0
	_plate_style.content_margin_bottom = 4.0
	_plate = PanelContainer.new()
	_plate.add_theme_stylebox_override("panel", _plate_style)
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(_plate)
	_name = _label(22, Color.WHITE)
	_plate.add_child(_name)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(spacer)
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

	var box_style := StyleBoxFlat.new()
	box_style.bg_color = COLOR_BOX
	box_style.border_color = COLOR_BORDER
	box_style.set_border_width_all(1)
	box_style.set_corner_radius_all(6)
	box_style.content_margin_left = 28.0
	box_style.content_margin_right = 28.0
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
	text_row.add_theme_constant_override("separation", 12)
	column.add_child(text_row)
	_face = UnitIcons.rect(UnitKind.Id.KING, 0, false, 72.0)
	_face.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_face.visible = false
	text_row.add_child(_face)
	_item_face = ItemIcon.new(Equipment.Id.IRON_SHIELD, 72.0)
	_item_face.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_item_face.visible = false
	text_row.add_child(_item_face)
	_text = _label(25, COLOR_TEXT)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_row.add_child(_text)
	var foot := HBoxContainer.new()
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(foot)
	_count = _label(15, COLOR_DIM)
	_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(_count)
	_hint = _label(15, COLOR_DIM)
	_hint.text = Text.t("talk.hint")
	foot.add_child(_hint)

	_show_line(0)


## 行 line の話し手の番号（"who"。無ければ陣営の番号）。知らせの行は -1。
static func _who(line: Dictionary) -> int:
	var side := int(line.get("side", 0))
	return -1 if side >= NOTICE_SIDE else int(line.get("who", side))


## 会話に出てくる話し手ごとに、姿を 1 つ作る。立つ所は、人の軍が左、敵の軍が右。
## 敵の軍が出てこない会話は、最初に話す人が左、ほかの人が右。
func _make_figures() -> void:
	var shapes: Array = talk.get("figures", [])
	var lines: Array = talk.get("lines", [])
	var has_foe := lines.any(func(line: Dictionary) -> bool: return int(line.get("side", 0)) == 1)
	var seen := {}
	for line: Dictionary in lines:
		var who := _who(line)
		if who < 0 or who >= shapes.size() or seen.has(who):
			continue
		var side := int(line.get("side", 0))
		var place := side if has_foe or seen.is_empty() else 1
		seen[who] = true
		var figure: Dictionary = shapes[who]
		var view := TalkFigure.new(figure["kind"], side, figure.get("evolved", false), figure.get("look", &""), place)
		view.who = who
		view.visible = false
		_stage.add_child(view)
		_figures.append(view)


## 話し手の姿を、舞台の高さいっぱいに、文の枠の左端と右端にそろえて置く。
func _place_figures() -> void:
	var height := _stage.size.y
	var width := minf(height * TalkFigure.ASPECT, BOX_WIDTH * FIGURE_MAX_WIDTH)
	var left := (_stage.size.x - BOX_WIDTH) / 2.0
	for view in _figures:
		view.size = Vector2(width, height)
		view.position = Vector2(left if view.place == 0 else left + BOX_WIDTH - width, 0.0)


## 行 index のときに、左右それぞれの所に立つ話し手の番号（[左, 右]。誰もいなければ -1）。
## いちばん近くに話した人。まだ誰も話していない所は、次に話す人。
func _standing_at(index: int) -> Array[int]:
	var place_of := {}
	for view in _figures:
		place_of[view.who] = view.place
	var standing: Array[int] = [-1, -1]
	var lines: Array = talk.get("lines", [])
	for i in range(mini(index, lines.size() - 1), -1, -1):
		var who := _who(lines[i])
		if place_of.has(who) and standing[place_of[who]] < 0:
			standing[place_of[who]] = who
	for i in range(index + 1, lines.size()):
		var who := _who(lines[i])
		if place_of.has(who) and standing[place_of[who]] < 0:
			standing[place_of[who]] = who
	return standing


func _process(delta: float) -> void:
	_elapsed += delta
	if _index < line_count() and _shown < _line_length():
		_shown = minf(_shown + delta * CHARS_PER_SECOND, _line_length())
		_text.visible_characters = int(_shown)
	_hint.modulate.a = 1.0 if not is_line_shown() else 0.5 + 0.5 * (0.5 + 0.5 * cos(_elapsed * TAU / BLINK_PERIOD))


func _unhandled_input(event: InputEvent) -> void:
	if context.overlays.is_open():
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


## いま立っている話し手の姿（検査用。左右に 1 人ずつまで）。
func figures() -> Array[TalkFigure]:
	return _figures.filter(func(view: TalkFigure) -> bool: return view.visible)


## 下の名前の札・「飛ばす」・文の枠が画面に占める四角（検査用。姿はこれと重ねない）。
func bottom_rect() -> Rect2:
	return _bottom.get_global_rect()


## いまの話し手の名前と文（検査用）。
func speaker() -> String:
	return _name.text


func line_text() -> String:
	return _text.text


func _show_line(index: int) -> void:
	_index = index
	_shown = 0.0
	if index >= line_count():
		_name.text = ""
		_text.text = ""
		_face.visible = false
		_item_face.visible = false
		_count.text = ""
		_plate.visible = false
		return
	var line: Dictionary = talk["lines"][index]
	_plate.visible = true
	_name.text = line.get("name", "")
	_plate_style.bg_color = TEAM_COLORS[clampi(int(line.get("side", 0)), 0, TEAM_COLORS.size() - 1)].darkened(0.15)
	_text.text = line.get("text", "")
	_face.visible = line.has("kind")
	if _face.visible:
		_face.texture = UnitIcons.texture(line["kind"])
	_item_face.visible = line.has("item")
	if _item_face.visible:
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


var _ended := false


func _end() -> void:
	if _ended:
		return
	if next_episode() != null:
		_open_choice()
		return
	_ended = true
	context.play_sound(&"ui_confirm")
	finished.emit(Run.NEXT)


## 会話を終えたあとに始められる次の話（渡された会話の "next_episode" が、いま遊べるときだけ。無ければ null）。
func next_episode() -> RefCounted:
	var next: RefCounted = talk.get("next_episode")
	if next == null or context.story == null or not context.story.is_available(next):
		return null
	return next


## 「スキップ」を出しているか（検査用）。
func is_skip_shown() -> bool:
	return _skip.visible


## 行き先の選択を出しているか。
func is_choosing() -> bool:
	return _choice != null and _choice.visible


## 「次の話へ」: 次の話の流れを（出撃準備から）始める。
func press_next_episode() -> void:
	var next := next_episode()
	if next == null or _ended:
		return
	_ended = true
	context.play_sound(&"ui_confirm")
	context.start_run(context.story.run_now(next))


## 「話の一覧へ」: 流れを終えて、話の一覧へ。
func press_to_episodes() -> void:
	if _ended:
		return
	_ended = true
	context.play_sound(&"ui_confirm")
	finished.emit(Run.NEXT)


func _open_choice() -> void:
	if _choice == null:
		var center := CenterContainer.new()
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_layer.add_child(center)
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", UiTheme.solid_box(22.0))
		center.add_child(panel)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		panel.add_child(row)
		var next := Button.new()
		next.text = Text.t("talk.next_episode")
		next.theme_type_variation = UiTheme.BUTTON_PRIMARY
		next.custom_minimum_size = Vector2(240.0, 52.0)
		next.add_theme_font_size_override("font_size", 22)
		next.focus_mode = Control.FOCUS_NONE
		next.set_meta(&"sound", &"ui_confirm")
		next.pressed.connect(press_next_episode)
		row.add_child(next)
		var list := Button.new()
		list.text = Text.t("result.to_episodes")
		list.custom_minimum_size = Vector2(220.0, 52.0)
		list.add_theme_font_size_override("font_size", 18)
		list.focus_mode = Control.FOCUS_NONE
		list.pressed.connect(press_to_episodes)
		row.add_child(list)
		_choice = center
	_choice.visible = true
	_hint.visible = false  # 「クリック: 次へ」と「スキップ」は、選ぶ間は出さない
	_skip.visible = false
	context.play_sound(&"menu_open")


## 行き先の選択の間の入力: Enter で「次の話へ」、右クリックで選択をやめて最後の文へ。Esc はシステムメニュー。
func _choice_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_choice.visible = false
		_hint.visible = true
		_skip.visible = true
		context.play_sound(&"ui_back")
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ENTER, KEY_KP_ENTER:
				press_next_episode()
			KEY_ESCAPE:
				context.open_menu()


func _label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
