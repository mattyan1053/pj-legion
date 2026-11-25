extends Node
## 出撃準備の場面（docs/story.md）。ストーリーの話の最初の場面（出撃のあとに、前の会話と対戦）。マップ・勝ち方・敵を見て、出撃する部隊を選ぶ。
## 背景は話の盤（backdrop.gd）。場面の決まりは scene_flow.gd。流れ（run.gd）が {"episode": 話, "battle": 話の対戦（story_battle.gd）} を渡す。
##
## - 左: 初期位置（deploy_map.gd）。盤の縮図に、味方の駒のアイコンと、敵と中立の駒の点（選んだ部隊で置き直す）。
## - 右: この話で覚えること（話の lesson。チュートリアル）、勝ち方、敵の部隊、出撃する部隊の選択
##   （既定の編成と、取っておいたストーリー用の部隊。出せない部隊は理由つきで押せない）。
##   部隊が決まっている話（話の [ally] に unit がある）は、その部隊だけを出し、「部隊編成」も出さない。
## - 「出撃」で、選んだ部隊を話の対戦に持たせて Run.NEXT（対戦へ）。選んだ部隊は覚えておき（story.gd の squad_id）、次の話でも、次に起動しても選ばれている。
## - 「部隊編成」で、部隊編成（ストーリー用）へ寄り道する（流れに差し込む。編成の「出撃準備へ戻る」で、ここへ戻る）。
## - 「話の一覧へ戻る」（右クリック・Esc でも）で &"back"（流れは捨てる）。

const DeployMap := preload("res://game/deploy_map.gd")
const CardKeys := preload("res://game/card_keys.gd")
const DeployNote := preload("res://game/deploy_note.gd")
const UnitDetail := preload("res://game/unit_detail.gd")
const Steady := preload("res://game/steady.gd")
const Text := preload("res://game/text.gd")
const Palette := preload("res://game/ui_palette.gd")
const UiTheme := preload("res://game/ui_theme.gd")
const AppContext := preload("res://game/app_context.gd")
const Backdrop := preload("res://game/backdrop.gd")
const ScreenSize := preload("res://game/screen_size.gd")
const BattleScreen := preload("res://game/battle_screen.gd")
const DeckText := preload("res://game/deck_text.gd")
const Run := preload("res://game/run.gd")
const MapCard := preload("res://game/map_card.gd")
const TextWrap := preload("res://game/text_wrap.gd")
const SystemMenu := preload("res://game/system_menu.gd")
const Episode := preload("res://game/episode.gd")
const Story := preload("res://game/story.gd")
const SceneFlow := preload("res://game/scene_flow.gd")
const StoryBattle := preload("res://game/story_battle.gd")
const Names := preload("res://game/names.gd")
const RuleCard := preload("res://game/rule_card.gd")
const BattleTexts := preload("res://game/battle_texts.gd")
const Crest := preload("res://game/crest.gd")
const NationDecor := preload("res://game/nation_decor.gd")
const UnitFrame := preload("res://game/unit_frame.gd")
const Ornament := preload("res://game/ui_ornament.gd")

signal finished(outcome: StringName)

## 部隊編成の場面の名前（scene_flow.gd）。
const DECKS := SceneFlow.DECKS
## 部隊の選択肢の、既定の編成の id（取っておいた部隊の id は数字の文字なので重ならない）。
const DEFAULT_ID := ""
## 部隊が決まっている話の、その部隊の選択肢の id。
const FIXED_ID := "fixed"
## 縮図の 1 マスの大きさ（px）。
const MAP_CELL := 20
## 勝利条件の札（rule_card.gd。対戦の始めの「対戦ルール」と同じ札）の数と、札の間（px）。話の人の勝ち方は 3 つまで
## （いつもの 2 つに守り切るを足したもの）。札は横に 1 列に並べ、右の欄の幅は 3 枚が入る幅にする。
const GOAL_CARDS := 3
const GOAL_CARD_GAP := 6.0
## この話で覚えること（演習の lesson）の札: 見出しの右（右の欄の上）に、決まった大きさで出す。演習でない話では出さない。
## 見出しの段に置くので、下の枠（勝利条件・敵の部隊・出撃する部隊）は、どの話でも同じ大きさ・同じ場所になる。
## 字の大きさ、文の幅（札の幅から、見出しの語の欄と余白を引いたもの）、行の数の上限。
const LESSON_FONT := 15
const LESSON_SIZE := Vector2(590.0, 56.0)
const LESSON_HEAD_WIDTH := 72.0
const LESSON_WIDTH := LESSON_SIZE.x - LESSON_HEAD_WIDTH - 36.0
const LESSON_MAX_LINES := 2
## 見出しの段（題と飾りの線、右に覚えることの札）の高さ（px）。
const HEADER_HEIGHT := 56.0
## 敵の部隊の文の行の数（いちばん敵の多い話で 2 行。行の数ぶんの高さを、いつも取っておく）と、字の大きさ。
const ENEMY_LINES := 2
const ENEMY_FONT := 14
## 選んだ部隊の中身の文の行の数（いつも、この行の数ぶんの高さを取る。部隊で欄の割り振りを変えない）と、字の大きさ（収まらなければ下限まで小さくする）。
const DECK_LINES := 2
const DECK_FONT := 14
const DECK_FONT_MIN := 12
## 選べる部隊の並び: 1 行の高さ、行の間、いつも丸ごと見えている行の数、その下にのぞく次の行（px。下に続きがあることを見せる）。
## 並びの欄の高さは、この行の数ぶんに決めてある（画面の高さが足りなくても、これより縮めない）。
const OPTION_HEIGHT := 36.0
const OPTION_GAP := 4.0
const OPTIONS_SHOWN := 3
const OPTIONS_PEEK := 8.0
const OPTIONS_HEIGHT := (OPTION_HEIGHT + OPTION_GAP) * OPTIONS_SHOWN + OPTIONS_PEEK
## 部隊の駒の額の大きさ（px）。
const FACE_SIZE := 40.0
## 送りの棒のつまみの太さ（px。つかみやすい太さ）。
const SCROLL_BAR_WIDTH := 14.0
## 画面の上下の端からの余白（px）。
const MARGIN_Y := 12.0
## 欄の縁の内側の余白（px。左右、上下）。
const PANEL_PAD := Vector2(14.0, 10.0)
## 縮図の高さの上限（px）。下に駒の欄（deploy_note.gd）を置いても、下のボタンが画面に収まるように。縦に長いマップは、1 マスを小さく描く。
const MAP_MAX_HEIGHT := 380.0
## 右の欄の幅（px）。勝利条件の札 3 枚と、欄の縁の内側の余白（左右 14）。
const RIGHT_WIDTH := RuleCard.SIZE.x * GOAL_CARDS + GOAL_CARD_GAP * (GOAL_CARDS - 1) + 28.0
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
## 話（episode.gd。game/story/<物語>/ の 1 ファイル）と、その対戦（story_battle.gd）。
var episode: Episode
var _layer: CanvasLayer
var _enemy_faces: HFlowContainer
var _detail: UnitDetail
var battle_source: RefCounted
## 選んでいる部隊の id（DEFAULT_ID なら既定の編成）。
var _chosen := DEFAULT_ID
var _deploy: DeployMap
var _deploy_note: DeployNote
var _auto_button: Button
## 勝利条件の欄の札（rule_card.gd）。
var _goal_cards: Array = []
var _options: VBoxContainer
var _option_buttons := {}  # id -> Button
var _deck_line: Label
var _deck_faces: HFlowContainer
var _sortie: Button
var _lesson_label: Label
var _options_scroll: ScrollContainer
var _root: VBoxContainer


func _ready() -> void:
	if context == null:
		context = AppContext.new()  # アプリを通さずに置いたとき
	var given: Variant = context.run_data()
	if given == null:
		given = {"episode": Story.military().episodes[0], "battle": Story.first_battle(Story.military().episodes[0])}
	episode = given["episode"]
	battle_source = given["battle"]
	add_child(Backdrop.new(episode.map.make_board(), episode.look))
	var layer := CanvasLayer.new()
	add_child(layer)
	var shade := ColorRect.new()
	shade.color = Color(Palette.SHADE, 0.35)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(shade)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 縦長・横長の画面では、枠を広げすぎず、真ん中にまとめる（中身の無い枠が伸びるだけになるため。docs/screen-size.md）。
	ScreenSize.cap(root, MAX_SIZE, Vector4(40.0, MARGIN_Y, 40.0, MARGIN_Y))
	root.add_theme_constant_override("separation", 6)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	_root = root
	_layer = layer
	# 見出しの段: 左に題と飾りの線、右に「この話で覚えること」の札（演習だけ）。段の高さは、札の有る無しで変えない。
	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0.0, HEADER_HEIGHT)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(header)
	var title_column := VBoxContainer.new()
	title_column.add_theme_constant_override("separation", 6)
	title_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(title_column)
	var heading := _text(30, COLOR_TEXT)
	heading.theme_type_variation = UiTheme.LABEL_HEADING
	heading.add_theme_constant_override("outline_size", 10)  # 景色の上に直に置くので、縁取りを太くする
	heading.text = Text.t("sortie.heading", {"number": Story.number_of(episode), "title": episode.title})
	title_column.add_child(heading)
	# 見出しの下の飾りの線は、人の軍の国の色（話の一覧と同じ）。
	var heading_line := Ornament.new(520.0, 8.0)
	heading_line.color = NationDecor.color_of(context.story.campaign.army)
	heading_line.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	title_column.add_child(heading_line)
	if episode.lesson != "":
		header.add_child(_build_lesson(episode.lesson))
		# 右上のシステムメニューのボタンに掛からないよう、札の右を空けておく。
		var corner := Control.new()
		corner.custom_minimum_size = Vector2(SystemMenu.CORNER_BUTTON_SIZE.x + SystemMenu.CORNER_MARGIN - 40.0, 0.0)
		corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		header.add_child(corner)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_theme_constant_override("separation", 28)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(body)

	var left := _panel()
	Steady.mark(left, "sortie.map", Steady.RECT)
	body.add_child(left)
	var left_column := VBoxContainer.new()
	left_column.add_theme_constant_override("separation", 12)
	left.add_child(left_column)
	# 初期位置: 盤の縮図に置けるマスを縁取り、駒を押してからマスを押すと置く（deploy_map.gd）。「おまかせ」でいつもの置き方へ。
	var map_head := HBoxContainer.new()
	map_head.add_theme_constant_override("separation", 12)
	left_column.add_child(map_head)
	var map_caption := _caption(Text.t("sortie.map", {"map": episode.map_title}))
	map_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_head.add_child(map_caption)
	_auto_button = _button(Text.t("sortie.auto_place"), 15)
	_auto_button.custom_minimum_size = Vector2(120.0, 32.0)
	_auto_button.pressed.connect(press_auto_place)
	map_head.add_child(_auto_button)
	_deploy = DeployMap.new()
	var board_size := Vector2(episode.map.make_board().size)
	_deploy.custom_minimum_size = board_size * minf(MAP_CELL, MAP_MAX_HEIGHT / board_size.y)
	_deploy.read_only = is_placement_fixed()
	_deploy.changed.connect(func() -> void:
		battle_source.placement = _deploy.offsets()
		_auto_button.disabled = _deploy.is_default())
	left_column.add_child(_deploy)
	if _deploy.read_only:
		var map_hint := _text(14, COLOR_DIM)
		map_hint.text = Text.t("sortie.place_fixed")
		left_column.add_child(map_hint)
	# 選んでいる駒（マウスを乗せている駒）の名前・役割・能力値（deploy_note.gd）。欄の下の端に置く（マップの大きさで場所が変わらない）。
	var map_rest := Control.new()
	map_rest.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_rest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_column.add_child(map_rest)
	_deploy_note = DeployNote.new()
	Steady.mark(_deploy_note, "sortie.unit_note", Steady.RECT)
	left_column.add_child(_deploy_note)
	_deploy_note.watch(_deploy)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(RIGHT_WIDTH, 0.0)
	right.add_theme_constant_override("separation", 6)
	body.add_child(right)
	# 勝利条件の欄は、対戦の上の帯の勝利条件の札と同じ色（金を混ぜた地と縁）。札の数で高さは変わらない（どの札も同じ大きさ）。
	var goal := _panel()
	goal.add_theme_stylebox_override("panel", _padded(UiTheme.box(Color(Palette.GOAL.lerp(Palette.PANEL, 0.55), 0.94), Palette.GOAL_BORDER, 1, 8, PANEL_PAD.x)))
	Steady.mark(goal, "sortie.goal", Steady.RECT)
	right.add_child(goal)
	var goal_column := VBoxContainer.new()
	goal_column.add_theme_constant_override("separation", 2)
	goal.add_child(goal_column)
	# 勝利条件の札（対戦の始めの「対戦ルール」と同じ札。rule_card.gd）。
	Names.set_boss(battle_source.boss_name())  # 札の中ボスの名前（話のファイルの boss）
	goal_column.add_child(_caption(Text.t("sortie.goal")))
	# 札は欄の真ん中に寄せる（対戦の始めの「対戦ルール」と同じ。1 枚でも 3 枚でも、左右の空きが同じ）。
	var goal_row := HBoxContainer.new()
	goal_row.alignment = BoxContainer.ALIGNMENT_CENTER
	goal_row.add_theme_constant_override("separation", int(GOAL_CARD_GAP))
	goal_column.add_child(goal_row)
	_goal_cards.clear()
	for card: Array in goal_cards():
		if _goal_cards.size() >= GOAL_CARDS:
			break
		var shown := RuleCard.new()
		shown.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		goal_row.add_child(shown)
		shown.show_goal(card[1], card[2], card[3])
		_goal_cards.append(shown)
	var enemy := _panel()
	Steady.mark(enemy, "sortie.enemy", Steady.RECT)
	right.add_child(enemy)
	_decorate(enemy, episode.enemy_army, Palette.TEAM_RED)
	var enemy_column := VBoxContainer.new()
	enemy_column.add_theme_constant_override("separation", 2)
	enemy.add_child(enemy_column)
	enemy_column.add_child(_army_caption(Text.t("sortie.enemy", {"army": DeckText.army_name(episode.enemy_army)}), episode.enemy_army))
	# 敵の駒のアイコン（押すと詳しい説明。魔物も）。
	var enemy_faces := HFlowContainer.new()
	enemy_faces.add_theme_constant_override("h_separation", 4)
	enemy_faces.add_theme_constant_override("v_separation", 4)
	enemy_column.add_child(enemy_faces)
	_enemy_faces = enemy_faces
	_fill_faces(enemy_faces, battle_source.scenario().fixed_decks[Unit.Side.PLAYER2], Unit.Side.PLAYER2, start_levels(Unit.Side.PLAYER2))
	var enemy_line := _wrapped(DeckText.deck_summary(
		battle_source.scenario().fixed_decks[Unit.Side.PLAYER2], start_levels(Unit.Side.PLAYER2),
		battle_source.scenario().has_king(Unit.Side.PLAYER2)), ENEMY_FONT, COLOR_TEXT)
	# 敵の数で欄の高さを変えない: 文は、いつも ENEMY_LINES 行ぶんの高さを取る。
	enemy_line.custom_minimum_size.y = _lines_height(ENEMY_FONT, ENEMY_LINES)
	enemy_line.clip_text = true
	enemy_column.add_child(enemy_line)

	var troops := _panel()
	troops.size_flags_vertical = Control.SIZE_EXPAND_FILL
	Steady.mark(troops, "sortie.troops", Steady.RECT)
	right.add_child(troops)
	_decorate(troops, context.story.campaign.army, Palette.TEAM_BLUE)
	var troops_column := VBoxContainer.new()
	troops_column.add_theme_constant_override("separation", 4)
	troops.add_child(troops_column)
	var troops_head := HBoxContainer.new()
	troops_head.add_theme_constant_override("separation", 12)
	troops_head.custom_minimum_size = Vector2(0.0, 36.0)  # 「部隊編成」のボタンの無い話（部隊が決まっている話）でも、同じ高さ
	troops_column.add_child(troops_head)
	var troops_caption := _army_caption(Text.t("sortie.troops"), context.story.campaign.army)
	troops_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	troops_head.add_child(troops_caption)
	var edit := _button(Text.t("setup.edit_deck"), 16)
	edit.custom_minimum_size = Vector2(180.0, 36.0)
	edit.pressed.connect(press_edit_decks)
	# 流れの外から置いたとき（検査）は、戻る先が無いので出さない。部隊が決まっている話も出さない。
	edit.visible = context.run != null and not is_squad_fixed()
	troops_head.add_child(edit)
	# 選んだ部隊の駒のアイコン（将から並びの順。unit_icons.gd）と、中身の文。見出しのすぐ下に置く（出撃する部隊が、まず目に入る）。
	# 部隊によって文の行の数が違うので、文の高さは、いつも DECK_LINES 行ぶん（収まらない部隊は、字を小さくする）。
	_deck_faces = HFlowContainer.new()
	_deck_faces.add_theme_constant_override("h_separation", 4)
	_deck_faces.add_theme_constant_override("v_separation", 4)
	troops_column.add_child(_deck_faces)
	_deck_line = _wrapped("", DECK_FONT, COLOR_DIM)
	_deck_line.custom_minimum_size.y = _lines_height(DECK_FONT, DECK_LINES)
	_deck_line.clip_text = true
	_deck_line.mouse_filter = Control.MOUSE_FILTER_PASS  # 切れた文の全部を、マウスを乗せると出す
	troops_column.add_child(_deck_line)
	# 選べる部隊の並び（部隊が決まっている話は 1 行）。いつも OPTIONS_SHOWN 行ぶんが見える高さを取り、多ければ欄の中で送る。
	# ホイールは 1 目盛りで 1 行ぶん送る（そのままだと、欄の高さの 1/8 ずつしか動かない）。送りの棒は、つかみやすい太さにする。
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0.0, OPTIONS_HEIGHT)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.get_v_scroll_bar().custom_minimum_size.x = SCROLL_BAR_WIDTH
	scroll.gui_input.connect(func(event: InputEvent) -> void:
		var wheel := event as InputEventMouseButton
		if wheel != null and wheel.pressed and wheel.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			scroll_options(-1 if wheel.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
			scroll.accept_event())
	Steady.mark(scroll, "sortie.options", Steady.RECT)
	troops_column.add_child(scroll)
	_options_scroll = scroll
	_options = VBoxContainer.new()
	_options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_options.add_theme_constant_override("separation", int(OPTION_GAP))
	scroll.add_child(_options)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 16)
	root.add_child(footer)
	# 「出撃」は、この画面の見せ場: 明朝の大きな字にして、左右へ飾りの線を伸ばす。
	footer.add_child(_footer_line())
	var back := _button(Text.t("story.episodes.resume"), 18)
	back.custom_minimum_size = Vector2(220.0, 48.0)
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(press_back)
	footer.add_child(back)
	_sortie = _button(Text.t("sortie.go"), 24)
	_sortie.custom_minimum_size = Vector2(300.0, 48.0)
	_sortie.set_meta(&"sound", &"ui_confirm")
	_sortie.theme_type_variation = UiTheme.BUTTON_PRIMARY
	_sortie.add_theme_font_override("font", UiTheme.FONT_HEADING)
	_sortie.pressed.connect(press_sortie)
	footer.add_child(_sortie)
	footer.add_child(_footer_line())

	var kept_placement: Array = battle_source.placement.duplicate()
	_build_options()
	if is_squad_fixed():
		choose(FIXED_ID)
	else:
		var remembered: String = context.story.squad_id
		choose(remembered if _option_buttons.has(remembered) and not (_option_buttons[remembered] as Button).disabled else DEFAULT_ID)
	# 決着の画面の「部隊変更」で戻ってきたときは、前に決めた初期位置を残す（同じ数の部隊なら）。
	if not kept_placement.is_empty() and kept_placement.size() == chosen_deck().entries.size() and not _deploy.read_only:
		battle_source.placement.assign(kept_placement)
		_refresh_deploy(chosen_deck())


func resume_label() -> String:
	return Text.t("sortie.back")


## 勝利条件の札（[&"goal", 勝ち方, 短い名前, 1 行]。話の戦いの定義の勝ちの条件から。人はプレイヤー1。BattleTexts.goal_cards）。
func goal_cards() -> Array[Array]:
	var scenario: Scenario = battle_source.scenario()
	var conditions: Array = [scenario.win_conditions_of(Unit.Side.PLAYER1), scenario.win_conditions_of(Unit.Side.PLAYER2)]
	return BattleTexts.goal_cards(conditions, scenario.hold_turns, Unit.Side.PLAYER1)


## 勝利条件の欄に出している札（検査用）。
func shown_goal_cards() -> Array:
	return _goal_cards


## 部隊 id（DEFAULT_ID なら既定の編成）を選ぶ。出せない部隊なら何もしない。
func choose(id: String) -> void:
	if not _option_buttons.has(id) or (_option_buttons[id] as Button).disabled:
		return
	_chosen = id
	for key: String in _option_buttons:
		(_option_buttons[key] as Button).set_pressed_no_signal(key == id)
	var deck := chosen_deck()
	var levels := start_levels(Unit.Side.PLAYER1)
	_fold_deck_line(DeckText.deck_summary(deck, levels))
	_fill_faces(_deck_faces, deck, Unit.Side.PLAYER1, levels)
	# 部隊を替えたら、初期位置はおまかせに戻す。
	battle_source.placement.clear()
	_refresh_deploy(deck)


## 初期位置の縮図を、部隊 deck と、いまの初期位置（battle_source.placement）で作り直す。
func _refresh_deploy(deck: Deck) -> void:
	var source: RefCounted = battle_source.copy()
	source.human_deck = deck
	var placed: Battle = source.make_setup(1).create_battle()
	source.placement.clear()
	var usual: Battle = source.make_setup(1).create_battle()
	var defaults: Array[Vector2i] = []
	for unit: Unit in usual.units:
		if unit.side == Unit.Side.PLAYER1 and unit.kind != UnitKind.Id.KING:
			defaults.append(unit.cell)
	_deploy.setup(placed, Unit.Side.PLAYER1, defaults, battle_source.scenario().deploy_cells_of(Unit.Side.PLAYER1), episode.look, BattleScreen.TEAM_COLORS)
	_auto_button.disabled = _deploy.is_default() or _deploy.read_only


## 「おまかせ」: 初期位置を、いつもの置き方へ戻す。
func press_auto_place() -> void:
	_deploy.reset()


## 初期位置を決められない話か（部隊も位置も決まっている演習）。
func is_placement_fixed() -> bool:
	return is_squad_fixed() and not episode.deploy[Unit.Side.PLAYER1].is_empty()


## 初期位置の縮図と、その下の駒の欄（検査用）。
func deploy_map() -> DeployMap:
	return _deploy


func deploy_note() -> DeployNote:
	return _deploy_note


## faces に、部隊 deck の駒のアイコン（将から並びの順。将のいない群れは将なし）を並べ直す。side は陣営、levels は始めのレベル（start_levels）。
## アイコンを押すと、その駒の詳しい説明（unit_detail.gd）を開く。始めのレベルが 1 でない駒は、アイコンの右下にレベル。
func _fill_faces(faces: Container, deck: Deck, side: Unit.Side, levels: Array) -> void:
	for face in faces.get_children():
		faces.remove_child(face)
		face.queue_free()
	var look: StringName = battle_source.king_looks()[side] if side < battle_source.king_looks().size() else &""
	if battle_source.scenario().has_king(side):  # 将のいない群れ（docs/scenario.md）は、将を並べない
		faces.add_child(_face(UnitKind.Id.KING, [], side, deck.army, 1, look))
	for i in deck.entries.size():
		var level: int = levels[i] if i < levels.size() else 1
		faces.add_child(_face(deck.entries[i].kind, deck.entries[i].equipment, side, deck.army, level))


func _face(kind: UnitKind.Id, equipment: Array[Equipment.Id], side: Unit.Side, army: UnitKind.Army, level: int, look := &"") -> Control:
	# 駒の額（役割の印つき）。縁は陣営の色。
	var face := UnitFrame.new(kind, side, FACE_SIZE, true, false, look)
	face.edge = Color(BattleScreen.TEAM_COLORS[side], 0.85)
	face.mouse_filter = Control.MOUSE_FILTER_STOP
	face.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	face.tooltip_text = Text.t("deck.detail.click")
	face.set_meta(&"detail", [kind, equipment, side, army, level, look])
	face.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_open_detail(face))
	if level > 1:
		# 始めのレベルが 1 でない駒（進化を教える話など）は、アイコンの右下にレベル。
		var tag := _text(13, COLOR_ACCENT)
		tag.text = Text.t("sortie.level", {"level": level})
		tag.add_theme_constant_override("outline_size", 4)
		tag.add_theme_color_override("font_outline_color", Palette.OUTLINE)
		# 右下は役割の印なので、レベルは左上に置く。
		tag.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE)
		tag.offset_left = 3.0
		face.add_child(tag)
	return face


func _open_detail(face: Control) -> void:
	if _detail == null:
		_detail = UnitDetail.new()
		_layer.add_child(_detail)
		_detail.setup(context.overlays)
	var given: Array = face.get_meta(&"detail")
	_detail.open(given[0], given[1], given[2], given[3], given[4], given[5])


## 部隊の駒のアイコン（side の陣営。将から並びの順）を押す（検査用）: その駒の詳しい説明を開き、それを返す。
func press_face(side: Unit.Side, index: int) -> Control:
	var faces: Array[Node] = (_deck_faces if side == Unit.Side.PLAYER1 else _enemy_faces).get_children().filter(
		func(face: Node) -> bool: return not face.is_queued_for_deletion())
	if index < 0 or index >= faces.size():
		return null
	_open_detail(faces[index])
	return _detail


## side の部隊の並びの順の、駒の始めのレベル（話の戦いの定義の start_growth。決めていなければ空）。
## 人の側は、部隊が決まっている話だけ（選んだ部隊には当てない）。
func start_levels(side: Unit.Side) -> Array:
	var levels: Array = []
	if side == Unit.Side.PLAYER1 and _chosen != FIXED_ID:
		return levels
	for row: Array in battle_source.scenario().start_growth[side]:
		levels.append(row[0])
	return levels


## 選んでいる部隊の id（DEFAULT_ID なら既定の編成）と、その部隊（写し）。
func chosen_id() -> String:
	return _chosen


func chosen_deck() -> Deck:
	if _chosen == FIXED_ID:
		return episode.squad_deck()
	if _chosen != DEFAULT_ID:
		var saved: RefCounted = context.decks.find(_chosen)
		if saved != null:
			return saved.deck.copy()
	return Story.default_deck(context.story.unlocked())


## 選択肢の id の並び（既定の編成が先頭）と、押せるか（検査用）。
func option_ids() -> Array[String]:
	var ids: Array[String] = []
	for key: String in _option_buttons:
		ids.append(key)
	return ids


func is_option_enabled(id: String) -> bool:
	return _option_buttons.has(id) and not (_option_buttons[id] as Button).disabled


## 部隊が決まっている話か（話の [ally] に unit がある）。
func is_squad_fixed() -> bool:
	return episode.squad_deck() != null


## 「出撃」: 選んだ部隊を話の対戦に持たせて、対戦へ。部隊が決まっている話では、覚えている部隊を変えない。
func press_sortie() -> void:
	battle_source.human_deck = chosen_deck()
	if not is_squad_fixed():
		context.story.choose_squad(_chosen)
	finished.emit(Run.NEXT)


## 「部隊編成」: 部隊編成（ストーリー用）へ寄り道する。編成の「出撃準備へ戻る」で、ここへ戻る（選んでいた部隊は覚えておく）。
func press_edit_decks() -> void:
	if context.run == null or is_squad_fixed():
		return
	context.story.choose_squad(_chosen)
	context.run.insert(DECKS, {"rules": context.story.campaign.rules_id, "back_label": "sortie.back"})
	context.start_run(context.run)


## 「話の一覧へ戻る」。
func press_back() -> void:
	finished.emit(&"back")


## 右クリックと Esc は 1 つ戻る（話の一覧へ）。重なる画面（システムメニュー）が開いている間は、そちらが受ける。
func _input(event: InputEvent) -> void:
	if context.overlays.is_open():
		return
	if CardKeys.is_back(event):
		get_viewport().set_input_as_handled()
		context.play_sound(&"ui_back")
		if not _deploy.cancel():  # 初期位置で駒を選んでいれば、まず選ぶのをやめる
			press_back()


func _build_options() -> void:
	if is_squad_fixed():
		_add_option(FIXED_ID, Text.t("sortie.option.fixed"), Text.t("sortie.option.fixed.note"), true)
		return
	_add_option(DEFAULT_ID, Text.t("sortie.option.default"), Text.t("sortie.option.default.note"), true)
	for item in context.decks.for_rules(context.story.campaign.rules_id, context.story.campaign.army):
		var issues: Array[String] = item.issues()
		var note := Text.t("sortie.option.saved.note", {"count": item.deck.entries.size(), "cost": item.deck.total_cost(), "budget": item.deck.budget()})
		_add_option(item.id, item.name, note if issues.is_empty() else Text.t("sortie.option.unplayable", {"issue": issues[0]}), issues.is_empty())


func _add_option(id: String, name: String, note: String, enabled: bool) -> void:
	var button := _button(Text.t("sortie.option", {"name": name, "note": note}), 16)
	button.toggle_mode = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0.0, OPTION_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.disabled = not enabled
	if not enabled:
		button.add_theme_color_override("font_disabled_color", COLOR_BAD)
	button.pressed.connect(func() -> void: choose(id))
	_options.add_child(button)
	_option_buttons[id] = button


## 選べる部隊の並びを、行の数 rows だけ送る（負で上へ。ホイールの 1 目盛りが 1 行）。
func scroll_options(rows: int) -> void:
	_options_scroll.scroll_vertical += int((OPTION_HEIGHT + OPTION_GAP) * rows)


## 画面に収めるのに要る高さ（px。上下の余白を含む。検査用。いちばん低い画面の 720 を超えないこと）。
func needed_height() -> float:
	return _root.get_combined_minimum_size().y + MARGIN_Y * 2.0


## 選べる部隊の並びの欄（検査用）と、その中でいま丸ごと見えている行の数。
func options_scroll() -> ScrollContainer:
	return _options_scroll


func options_fully_shown() -> int:
	var view := _options_scroll.get_global_rect()
	var shown := 0
	for id: String in _option_buttons:
		if view.grow(0.5).encloses((_option_buttons[id] as Button).get_global_rect()):
			shown += 1
	return shown


## 選んだ部隊の中身の文を、DECK_LINES 行に収める（収まらなければ、字を DECK_FONT_MIN まで小さくする）。欄の高さは変えない。
func _fold_deck_line(text: String) -> void:
	var font := _deck_line.get_theme_font("font")
	for font_size in range(DECK_FONT, DECK_FONT_MIN - 1, -1):
		_deck_line.add_theme_font_size_override("font_size", font_size)
		_deck_line.text = TextWrap.fold(text, WRAP_WIDTH, func(character: String) -> float:
			return font.get_string_size(character, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
		if _deck_line.text.count("\n") < DECK_LINES:
			_deck_line.tooltip_text = ""
			return
	# いちばん小さい字でも収まらない部隊（持ち物の多い大きな部隊）: DECK_LINES 行で切って「…」を付け、全部はマウスを乗せると出す。
	var lines := _deck_line.text.split("\n").slice(0, DECK_LINES)
	lines[DECK_LINES - 1] = lines[DECK_LINES - 1].left(-1) + "…"
	_deck_line.text = "\n".join(lines)
	_deck_line.tooltip_text = text


## 選んだ部隊の中身の文（折り返したもの。検査用）。
func deck_line_text() -> String:
	return _deck_line.text


## 選んだ部隊の中身の文にマウスを乗せると出る文（切れた文の全部。切れていなければ空。検査用）。
func deck_line_tooltip() -> String:
	return _deck_line.tooltip_text


## 字の大きさ font_size の文の、lines 行ぶんの高さ（px）。
func _lines_height(font_size: int, lines: int) -> float:
	var probe := _text(font_size, COLOR_TEXT)
	probe.add_theme_constant_override("line_spacing", 0)
	probe.text = "0" + "\n0".repeat(lines - 1)
	var height := probe.get_minimum_size().y
	probe.free()
	return height


## 板の形 style の上下の余白を、欄の決まった余白（PANEL_PAD.y）にする。
func _padded(style: StyleBoxFlat) -> StyleBoxFlat:
	style.content_margin_top = PANEL_PAD.y
	style.content_margin_bottom = PANEL_PAD.y
	return style


func _panel() -> PanelContainer:
	var style := _padded(UiTheme.box(COLOR_PANEL, Color(Palette.BORDER, 0.9), 1, 8, PANEL_PAD.x))
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel


func _caption(text: String) -> Label:
	var label := _text(15, COLOR_ACCENT)
	label.add_theme_font_override("font", UiTheme.FONT_BOLD)
	label.text = text
	return label


## 「この話で覚えること」の札（決まった大きさ）: 左に見出しの語、右に文（LESSON_MAX_LINES 行まで）。勝利条件の欄と同じ金を混ぜた地。
func _build_lesson(lesson: String) -> Control:
	var panel := _panel()
	panel.add_theme_stylebox_override("panel", UiTheme.box(Color(Palette.GOAL.lerp(Palette.PANEL, 0.55), 0.94), Palette.GOAL_BORDER, 1, 8, 6.0))
	panel.custom_minimum_size = LESSON_SIZE
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.clip_contents = true
	Steady.mark(panel, "sortie.lesson", Steady.RECT)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	var head := _text(13, COLOR_ACCENT)
	head.add_theme_font_override("font", UiTheme.FONT_BOLD)
	head.add_theme_constant_override("line_spacing", 0)
	head.custom_minimum_size = Vector2(LESSON_HEAD_WIDTH, 0.0)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.text = Text.t("sortie.lesson")
	row.add_child(head)
	_lesson_label = _text(LESSON_FONT, COLOR_TEXT)
	_lesson_label.custom_minimum_size = Vector2(LESSON_WIDTH, 0.0)
	_lesson_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lesson_label.add_theme_constant_override("line_spacing", 0)
	var font := _lesson_label.get_theme_font("font")
	_lesson_label.text = TextWrap.fold(lesson, LESSON_WIDTH, func(character: String) -> float:
		return font.get_string_size(character, HORIZONTAL_ALIGNMENT_LEFT, -1, LESSON_FONT).x)
	row.add_child(_lesson_label)
	return panel


## 「この話で覚えること」の札の文（出ていなければ空。検査用）。
func lesson_text() -> String:
	return _lesson_label.text.replace("\n", "") if _lesson_label != null else ""


## 枠の大きさ（勝利条件・敵の部隊・出撃する部隊・初期位置。検査用。どの話でも同じ）。
func frame_rects() -> Dictionary:
	var rects := {}
	for frame: Control in get_tree().get_nodes_in_group(Steady.GROUP):
		if is_ancestor_of(frame) and Steady.kind_of(frame) == Steady.RECT and Steady.name_of(frame) != "sortie.lesson":
			rects[Steady.name_of(frame)] = frame.get_global_rect()
	return rects


## 部隊の欄の飾り: 上の縁にその軍の国の色の帯（軍なしは陣営の色）と、その下の淡い光。
func _decorate(panel: PanelContainer, army: UnitKind.Army, team: Color) -> void:
	var decor := NationDecor.new(army, 0.0, 44.0)
	if army == UnitKind.Army.NONE:
		decor.band_color = team
	panel.add_child(decor)


## 部隊の欄の小見出し: 軍の国の紋（軍なしは出さない）と、文。高さは小見出しの文と同じ（紋で行を高くしない）。
func _army_caption(text: String, army: UnitKind.Army) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if army != UnitKind.Army.NONE:
		var crest := Crest.new(army, 20.0)
		crest.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(crest)
	row.add_child(_caption(text))
	return row


## 下のボタンの左右へ伸びる飾りの線。
func _footer_line() -> Control:
	var line := Ornament.new(120.0, 12.0)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.color = Palette.BORDER_BRIGHT
	return line


## 右の欄の幅で折り返す文の札（Label の自動の折り返しは語の途中で切るので、text_wrap.gd で折り返す）。
func _wrapped(text: String, font_size: int, color: Color) -> Label:
	var label := _text(font_size, color)
	label.custom_minimum_size = Vector2(WRAP_WIDTH, 0.0)
	label.add_theme_constant_override("line_spacing", 0)
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
