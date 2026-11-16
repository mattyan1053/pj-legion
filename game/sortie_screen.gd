extends Node
## 出撃の準備の場面（docs/story.md）。ストーリーの話の、前の会話と対戦のあいだ。マップ・勝ち方・敵を見て、出撃する部隊を選ぶ。
## 背景は話の盤（backdrop.gd）。場面の決まりは scene_flow.gd。流れ（run.gd）が {"episode": 話, "battle": 話の対戦（story_battle.gd）} を渡す。
##
## - 左: 盤の縮図。両軍の駒の初期位置に、陣営の色の点（選んだ部隊で置き直す）。
## - 右: 勝ち方、敵の部隊、出撃する部隊の選択（既定の編成と、取っておいたストーリー用の部隊。出せない部隊は理由つきで押せない）。
## - 「出撃」で、選んだ部隊を話の対戦に持たせて Run.NEXT（対戦へ）。選んだ部隊は覚えておき（story.gd の squad_id）、次の話でも、次に起動しても選ばれている。
## - 「部隊を編成する」で、部隊の編成（ストーリー用）へ寄り道する（流れに差し込む。編成の「出撃の準備へ戻る」で、ここへ戻る）。
## - 「話の一覧へ戻る」（右クリック・Esc でも）で &"back"（流れは捨てる）。

const Palette := preload("res://game/ui_palette.gd")
const UiTheme := preload("res://game/ui_theme.gd")
const AppContext := preload("res://game/app_context.gd")
const Backdrop := preload("res://game/backdrop.gd")
const ScreenSize := preload("res://game/screen_size.gd")
const BattleScreen := preload("res://game/battle_screen.gd")
const DeckText := preload("res://game/deck_text.gd")
const Run := preload("res://game/run.gd")
const StageCardMap := preload("res://game/stage_card_map.gd")
const TextWrap := preload("res://game/text_wrap.gd")
const Story := preload("res://game/story.gd")
const SceneFlow := preload("res://game/scene_flow.gd")
const StoryBattle := preload("res://game/story_battle.gd")
const WinText := preload("res://game/win_text.gd")

signal finished(outcome: StringName)

## 部隊の編成の場面の名前（scene_flow.gd）。
const DECKS := SceneFlow.DECKS
## 部隊の選択肢の、既定の編成の id（取っておいた部隊の id は数字の文字なので重ならない）。
const DEFAULT_ID := ""
## 縮図の 1 マスの大きさ（px）。
const MAP_CELL := 20
const RIGHT_WIDTH := 600.0
## 中身の大きさの上限（論理の px）。縦長・横長の画面では、これより広げずに真ん中に置く（docs/screen-size.md）。
const MAX_SIZE := Vector2(1560.0, 820.0)
## 右の欄の文を折り返す幅（px）。
const WRAP_WIDTH := RIGHT_WIDTH - 40.0

const COLOR_PANEL := Color(Palette.PANEL, 0.92)
const COLOR_TEXT := Palette.TEXT
const COLOR_DIM := Palette.TEXT_DIM
const COLOR_BAD := Palette.DANGER
const COLOR_ACCENT := Palette.ACCENT

var context: AppContext
## 話（game/episodes/ の 1 ファイル）と、その対戦（story_battle.gd）。
var episode: Script
var battle_source: RefCounted
## 選んでいる部隊の id（DEFAULT_ID なら既定の編成）。
var _chosen := DEFAULT_ID
var _map: TextureRect
var _options: VBoxContainer
var _option_buttons := {}  # id -> Button
var _deck_line: Label
var _sortie: Button


func _ready() -> void:
	if context == null:
		context = AppContext.new()  # アプリを通さずに置いたとき
	var given: Variant = context.run_data()
	if given == null:
		given = {"episode": Story.EPISODES[0], "battle": Story.first_battle(Story.EPISODES[0])}
	episode = given["episode"]
	battle_source = given["battle"]
	add_child(Backdrop.new(episode.MAP.map().make_board(), episode.LOOK))
	var layer := CanvasLayer.new()
	add_child(layer)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.35)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(shade)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 縦長・横長の画面では、枠を広げすぎず、真ん中にまとめる（中身の無い枠が伸びるだけになるため。docs/screen-size.md）。
	ScreenSize.cap(root, MAX_SIZE, Vector4(40.0, 24.0, 40.0, 24.0))
	root.add_theme_constant_override("separation", 12)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var heading := _text(30, COLOR_TEXT)
	heading.theme_type_variation = UiTheme.LABEL_HEADING
	heading.text = "出撃の準備　　第 %d 話「%s」" % [Story.number_of(episode), episode.TITLE]
	root.add_child(heading)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_theme_constant_override("separation", 28)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(body)

	var left := _panel()
	body.add_child(left)
	var left_column := VBoxContainer.new()
	left_column.add_theme_constant_override("separation", 6)
	left.add_child(left_column)
	left_column.add_child(_caption("マップ「%s」（点は駒の初期位置。青が味方、赤が敵）" % episode.MAP.TITLE))
	_map = TextureRect.new()
	_map.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_map.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_column.add_child(_map)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(RIGHT_WIDTH, 0.0)
	right.add_theme_constant_override("separation", 10)
	body.add_child(right)
	var goal := _panel()
	right.add_child(goal)
	var goal_column := VBoxContainer.new()
	goal.add_child(goal_column)
	goal_column.add_child(_caption("勝ち方"))
	goal_column.add_child(_wrapped(win_text(), 17, COLOR_TEXT))
	var enemy := _panel()
	right.add_child(enemy)
	var enemy_column := VBoxContainer.new()
	enemy.add_child(enemy_column)
	enemy_column.add_child(_caption("敵の部隊（%s）" % DeckText.army_name(episode.ENEMY_ARMY)))
	enemy_column.add_child(_wrapped(DeckText.deck_summary(battle_source.scenario().fixed_decks[Unit.Side.PLAYER2]), 17, COLOR_TEXT))

	var troops := _panel()
	troops.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(troops)
	var troops_column := VBoxContainer.new()
	troops_column.add_theme_constant_override("separation", 6)
	troops.add_child(troops_column)
	var troops_head := HBoxContainer.new()
	troops_head.add_theme_constant_override("separation", 12)
	troops_column.add_child(troops_head)
	var troops_caption := _caption("出撃する部隊")
	troops_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	troops_head.add_child(troops_caption)
	var edit := _button("部隊を編成する", 16)
	edit.custom_minimum_size = Vector2(180.0, 36.0)
	edit.pressed.connect(press_edit_decks)
	edit.visible = context.run != null  # 流れの外から置いたとき（検査）は、戻る先が無いので出さない
	troops_head.add_child(edit)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	troops_column.add_child(scroll)
	_options = VBoxContainer.new()
	_options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_options.add_theme_constant_override("separation", 4)
	scroll.add_child(_options)
	_deck_line = _wrapped("", 15, COLOR_DIM)
	troops_column.add_child(_deck_line)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 16)
	root.add_child(footer)
	var back := _button("話の一覧へ戻る", 18)
	back.custom_minimum_size = Vector2(220.0, 48.0)
	back.pressed.connect(press_back)
	footer.add_child(back)
	_sortie = _button("出撃", 22)
	_sortie.custom_minimum_size = Vector2(280.0, 54.0)
	_sortie.set_meta(&"sound", &"ui_confirm")
	_sortie.theme_type_variation = UiTheme.BUTTON_PRIMARY
	_sortie.pressed.connect(press_sortie)
	footer.add_child(_sortie)

	_build_options()
	var remembered: String = context.story.squad_id
	choose(remembered if _option_buttons.has(remembered) and not (_option_buttons[remembered] as Button).disabled else DEFAULT_ID)


func resume_label() -> String:
	return "出撃の準備へ戻る"


## 勝ち方の文（話の戦いの定義の勝ちの条件から。人はプレイヤー1。win_text.gd、docs/win-conditions.md）。
func win_text() -> String:
	return WinText.of_scenario(battle_source.scenario(), Unit.Side.PLAYER1)


## 部隊 id（DEFAULT_ID なら既定の編成）を選ぶ。出せない部隊なら何もしない。
func choose(id: String) -> void:
	if not _option_buttons.has(id) or (_option_buttons[id] as Button).disabled:
		return
	_chosen = id
	for key: String in _option_buttons:
		(_option_buttons[key] as Button).set_pressed_no_signal(key == id)
	var deck := chosen_deck()
	_fold(_deck_line, DeckText.deck_summary(deck))
	_map.texture = ImageTexture.create_from_image(map_image(deck))


## 選んでいる部隊の id（DEFAULT_ID なら既定の編成）と、その部隊（写し）。
func chosen_id() -> String:
	return _chosen


func chosen_deck() -> Deck:
	if _chosen != DEFAULT_ID:
		var saved: RefCounted = context.decks.find(_chosen)
		if saved != null:
			return saved.deck.copy()
	return Story.default_deck(context.story.unlocked_kinds())


## 選択肢の id の並び（既定の編成が先頭）と、押せるか（検査用）。
func option_ids() -> Array[String]:
	var ids: Array[String] = []
	for key: String in _option_buttons:
		ids.append(key)
	return ids


func is_option_enabled(id: String) -> bool:
	return _option_buttons.has(id) and not (_option_buttons[id] as Button).disabled


## 「出撃」: 選んだ部隊を話の対戦に持たせて、対戦へ。
func press_sortie() -> void:
	battle_source.human_deck = chosen_deck()
	context.story.choose_squad(_chosen)
	finished.emit(Run.NEXT)


## 「部隊を編成する」: 部隊の編成（ストーリー用）へ寄り道する。編成の「出撃の準備へ戻る」で、ここへ戻る（選んでいた部隊は覚えておく）。
func press_edit_decks() -> void:
	if context.run == null:
		return
	context.story.choose_squad(_chosen)
	context.run.insert(DECKS, {"rules": Story.RULES_ID, "back_label": "出撃の準備へ戻る"})
	context.start_run(context.run)


## 「話の一覧へ戻る」。
func press_back() -> void:
	finished.emit(&"back")


## 右クリックと Esc は 1 つ戻る（話の一覧へ）。重なる画面（システムメニュー）が開いている間は、そちらが受ける。
func _input(event: InputEvent) -> void:
	if context.overlays.is_open():
		return
	var right: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT
	var escape: bool = event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE
	if right or escape:
		get_viewport().set_input_as_handled()
		context.play_sound(&"ui_back")
		press_back()


## 盤の縮図。両軍の駒の初期位置（人は deck で置く）に、陣営の色の点を打つ。
func map_image(deck: Deck) -> Image:
	var source: RefCounted = battle_source.copy()
	source.human_deck = deck
	var battle: Battle = source.make_setup(1).create_battle()
	var image := StageCardMap.draw(battle.board, episode.LOOK, BattleScreen.TEAM_COLORS, MAP_CELL)
	for unit in battle.units:
		if unit.side == Unit.Side.NEUTRAL or unit.kind == UnitKind.Id.KING:
			continue
		var corner := unit.cell * MAP_CELL
		image.fill_rect(Rect2i(corner + Vector2i(3, 3), Vector2i(MAP_CELL - 6, MAP_CELL - 6)), Color.BLACK)
		image.fill_rect(Rect2i(corner + Vector2i(4, 4), Vector2i(MAP_CELL - 8, MAP_CELL - 8)), BattleScreen.TEAM_COLORS[unit.side].lightened(0.2))
	return image


func _build_options() -> void:
	_add_option(DEFAULT_ID, "既定の編成", "いま雇える駒で組んだもの", true)
	for item in context.decks.for_rules(Story.RULES_ID, Story.ARMY):
		var issues: Array[String] = item.issues()
		var note := "%d 体・コスト %d / %d" % [item.deck.entries.size(), item.deck.total_cost(), item.deck.budget()]
		_add_option(item.id, item.name, note if issues.is_empty() else "出せない: " + issues[0], issues.is_empty())


func _add_option(id: String, name: String, note: String, enabled: bool) -> void:
	var button := _button("%s　　%s" % [name, note], 16)
	button.toggle_mode = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0.0, 40.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.disabled = not enabled
	if not enabled:
		button.add_theme_color_override("font_disabled_color", COLOR_BAD)
	button.pressed.connect(func() -> void: choose(id))
	_options.add_child(button)
	_option_buttons[id] = button


func _panel() -> PanelContainer:
	var style := UiTheme.box(COLOR_PANEL, Color(Palette.BORDER, 0.9), 1, 8, 14.0)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel


func _caption(text: String) -> Label:
	var label := _text(15, COLOR_ACCENT)
	label.text = text
	return label


## 右の欄の幅で折り返す文の札（Label の自動の折り返しは語の途中で切るので、text_wrap.gd で折り返す）。
func _wrapped(text: String, font_size: int, color: Color) -> Label:
	var label := _text(font_size, color)
	label.custom_minimum_size = Vector2(WRAP_WIDTH, 0.0)
	_fold(label, text)
	return label


## 札 label の文を text にする（右の欄の幅で折り返す）。
func _fold(label: Label, text: String) -> void:
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	label.text = TextWrap.fold(text, WRAP_WIDTH, func(character: String) -> float:
		return font.get_string_size(character, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)


func _text(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _button(text: String, font_size: int) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", font_size)
	return button
