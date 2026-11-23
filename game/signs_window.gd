extends Control
## 縫い目の様子の札がめくられる窓（docs/seam-signs.md、docs/battle-view.md の「縫い目の様子」）。
## 対戦設定の「対戦開始」のあと、対戦の画面の上に重ねて出す。札 2 枚（名前と効果）を見せ、その下で、両方のプレイヤーが出す部隊を選び直す。
## 人の行: 部隊（既定の編成・ランダム編成・取っておいた部隊）、「編成確認」、「初期位置」。CPU の行: 札を見て CPU が選んだ部隊と「編成確認」。
## 「対戦開始」で started（選び直したものの写し）を出す。「対戦設定へ」で setup_requested。右クリック・Esc は何もしない（札は読んでから閉じる）。
## 選んだもの（match_choice.gd）を持つが、ルールは持たない。窓の大きさは、札と部隊に依らず同じ（Steady.mark）。

const Text := preload("res://game/text.gd")
const Names := preload("res://game/names.gd")
const Steady := preload("res://game/steady.gd")
const UiTheme := preload("res://game/ui_theme.gd")
const Palette := preload("res://game/ui_palette.gd")
const CardKeys := preload("res://game/card_keys.gd")
const MatchChoice := preload("res://game/match_choice.gd")
const VersusFields := preload("res://game/versus_fields.gd")
const SignCard := preload("res://game/sign_card.gd")
const DeckPreview := preload("res://game/deck_preview.gd")
const DeployDialog := preload("res://game/deploy_dialog.gd")

## 「対戦開始」。選び直したもの（写し）を渡す。
signal started(choice: RefCounted)
## 「対戦設定へ」（対戦設定のパネルを開き直す）。
signal setup_requested

## 窓の中身の幅（px）と、部隊の欄の幅。
const WINDOW_WIDTH := 860.0
const PICKER_WIDTH := 330.0
const WHO_WIDTH := 200.0

var _overlays: RefCounted
var _library: RefCounted
var _team_colors: Array[Color] = []
var _choice: RefCounted = MatchChoice.new()
var _seed := 0
var _cards: Array[SignCard] = []
## プレイヤー番号ごとの、見出し、部隊の欄（人）か部隊の名前（CPU）、「編成確認」、「初期位置」、部隊の選択肢（[id, 文, 出せるか]）。
var _who: Array[Label] = []
var _pickers: Array[OptionButton] = []
var _cpu_decks: Array[Label] = []
var _preview_buttons: Array[Button] = []
var _placement_buttons: Array[Button] = []
var _options: Array = [[], []]
var _start: Button
var _preview: DeckPreview
var _placement: DeployDialog
var _placing_side := -1


func setup(team_colors: Array[Color], library: RefCounted, overlays: RefCounted) -> void:
	_team_colors = team_colors
	_library = library
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
	panel.custom_minimum_size = Vector2(WINDOW_WIDTH, 0.0)
	Steady.mark(panel, "signs.window", Steady.RECT)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var title := Label.new()
	UiTheme.style_window_title(title)
	title.text = Text.t("signs.title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	column.add_child(UiTheme.window_rule())
	var cards := HBoxContainer.new()
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 16)
	column.add_child(cards)
	for i in Seam.DRAWN:
		var card := SignCard.new()
		cards.add_child(card)
		_cards.append(card)
	var lead := Label.new()
	lead.text = Text.t("signs.lead")
	lead.add_theme_font_size_override("font_size", 15)
	lead.add_theme_color_override("font_color", Palette.TEXT_DIM)
	lead.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(lead)
	for side in 2:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		column.add_child(row)
		var who := Label.new()
		who.add_theme_font_size_override("font_size", 17)
		who.add_theme_font_override("font", UiTheme.FONT_BOLD)
		who.custom_minimum_size = Vector2(WHO_WIDTH, 40.0)
		who.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		who.clip_text = true
		row.add_child(who)
		_who.append(who)
		var picker := OptionButton.new()
		picker.focus_mode = Control.FOCUS_NONE
		picker.add_theme_font_size_override("font_size", 17)
		picker.custom_minimum_size = Vector2(PICKER_WIDTH, 40.0)
		picker.fit_to_longest_item = false
		picker.clip_text = true
		picker.get_popup().add_theme_font_size_override("font_size", 17)
		var picked_side := side
		picker.item_selected.connect(func(index: int) -> void: _on_picked(picked_side, index))
		row.add_child(picker)
		_pickers.append(picker)
		var cpu_deck := Label.new()
		cpu_deck.add_theme_font_size_override("font_size", 17)
		cpu_deck.custom_minimum_size = Vector2(PICKER_WIDTH, 40.0)
		cpu_deck.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cpu_deck.clip_text = true
		cpu_deck.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(cpu_deck)
		_cpu_decks.append(cpu_deck)
		var look := _button(Text.t("setup.deck_preview"))
		look.pressed.connect(func() -> void: open_preview(picked_side))
		row.add_child(look)
		_preview_buttons.append(look)
		var place := _button(Text.t("setup.placement"))
		place.pressed.connect(func() -> void: open_placement(picked_side))
		row.add_child(place)
		_placement_buttons.append(place)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	column.add_child(buttons)
	var back := _button(Text.t("signs.to_setup"))
	back.custom_minimum_size = Vector2(200.0, 52.0)
	back.pressed.connect(func() -> void:
		visible = false
		setup_requested.emit())
	buttons.add_child(back)
	_start = _button(Text.t("setup.start"))
	_start.custom_minimum_size = Vector2(220.0, 52.0)
	_start.theme_type_variation = UiTheme.BUTTON_PRIMARY
	_start.set_meta(&"sound", &"ui_confirm")
	_start.pressed.connect(press_start)
	buttons.add_child(_start)
	_preview = DeckPreview.new()
	add_child(_preview)
	_preview.setup(overlays)
	_placement = DeployDialog.new()
	add_child(_placement)
	_placement.setup(overlays)
	_placement.closed.connect(func() -> void:
		if _placing_side != -1:
			_choice.placements[_row_of(_placing_side)] = _placement.offsets()
		_placing_side = -1
		_refresh())


## 選んだもの choice（写して持つ）の、種 battle_seed の対戦でめくった札 signs を見せて開く。
func open(chosen: RefCounted, battle_seed: int, signs: Array[int]) -> void:
	_choice = chosen.copy()
	_seed = battle_seed
	for i in _cards.size():
		_cards[i].visible = i < signs.size()
		if i < signs.size():
			_cards[i].show_sign(signs[i])
	_refresh()
	visible = true


## 「対戦開始」: 窓を閉じて、選び直したものの写しを知らせる。
func press_start() -> void:
	if not visible:
		return
	visible = false
	started.emit(_choice.copy())


## いまの選び直し（検査用。写しではない）。
func choice() -> RefCounted:
	return _choice


## 見せている札の文（検査用）。
func card_texts() -> Array[String]:
	var texts: Array[String] = []
	for card in _cards:
		if card.visible:
			texts.append(card.shown_text())
	return texts


## プレイヤー side（Unit.Side）の部隊を、id（空なら既定の編成、MatchChoice.RANDOM ならランダム編成、ほかは取っておいた部隊）にする。
## 人の行だけ。選べなければ偽。
func choose_deck(side: Unit.Side, id: String) -> bool:
	var row := _row_of(side)
	if not _choice.is_human(row):
		return false
	if id == "":
		_choice.choose_default(row)
	elif id == MatchChoice.RANDOM:
		_choice.choose_random(row)
	else:
		var item: Variant = _library.find(id) if _library != null else null
		if item == null or not item.playable():
			return false
		_choice.choose_deck(row, item.id, item.deck)
	_refresh()
	return true


## 「編成確認」: プレイヤー side が出す部隊を札にして出す。
func open_preview(side: Unit.Side) -> void:
	var deck := deck_of(side)
	if deck != null:
		_preview.open(_who[side].text, deck, side)


## 「初期位置」: プレイヤー side（人の行で、ランダム編成でないとき）の初期位置を、この対戦の盤で決める窓を開く。
func open_placement(side: Unit.Side) -> void:
	var row := _row_of(side)
	if not _choice.is_human(row) or _choice.is_random(row):
		return
	_placing_side = side
	var shown: Array = _choice.placement_preview(row, _seed)
	var defined := VersusFields.scenario_of(_choice.field)
	_placement.open(_who[side].text, shown, defined.deploy_cells_of(shown[2]), VersusFields.look_of(_choice.field), _team_colors, false)


## プレイヤー side がこの対戦に出す部隊（いまの選び直しで作る対戦の部隊。CPU の側は、札を見て選んだもの）。
func deck_of(side: Unit.Side) -> Deck:
	var made: MatchSetup = _choice.copy().to_setup(_seed)
	return made.deck_of(side)


## 初期位置の窓（検査用）。
func placement_dialog() -> DeployDialog:
	return _placement


## 編成の確認の画面（検査用）。
func preview() -> DeckPreview:
	return _preview


## プレイヤー side を、選んだもの（match_choice.gd）のどの行が受け持つか（CPU 戦で手番がランダムなら、行と側が違う）。
func _row_of(side: int) -> Unit.Side:
	if not _choice.cpu_opponent:
		return side as Unit.Side
	return _choice.human_row() if side == _choice.human_side_now() else _choice.cpu_row()


func _refresh() -> void:
	var made: MatchSetup = _choice.copy().to_setup(_seed)
	for side in 2:
		var row := _row_of(side)
		var human: bool = _choice.is_human(row)
		var turn: String = [Text.t("setup.side.first"), Text.t("setup.side.second")][side]
		var who := Text.t("setup.who.you") if human else "CPU"
		_who[side].text = Text.t("setup.who_side", {"who": who, "turn": turn}) if _choice.cpu_opponent else turn
		_who[side].add_theme_color_override("font_color", _team_colors[side].lightened(0.35) if side < _team_colors.size() else Palette.TEXT)
		_pickers[side].visible = human
		_cpu_decks[side].visible = not human
		_placement_buttons[side].visible = human
		_placement_buttons[side].disabled = _choice.is_random(row)
		_placement_buttons[side].text = Text.t("setup.placement_set" if not _choice.placements[row].is_empty() else "setup.placement")
		if human:
			_fill_picker(side, row)
		else:
			var deck := made.deck_of(side as Unit.Side)
			_cpu_decks[side].text = Text.t("signs.cpu_deck", {"cost": deck.total_cost(), "budget": deck.budget()}) if deck != null else ""


func _fill_picker(side: int, row: Unit.Side) -> void:
	var army: UnitKind.Army = _choice.armies[row]
	var default_deck := MatchSetup.default_deck(army)
	var options: Array = [
		["", Text.t("setup.deck.default", {"cost": default_deck.total_cost(), "budget": default_deck.budget()}), true],
		[MatchChoice.RANDOM, Text.t("setup.deck.random"), true],
	]
	if _library != null:
		for item: RefCounted in _library.for_rules(DeckRules.VERSUS, army):
			var playable: bool = item.playable()
			var text := Text.t("setup.deck.saved", {"name": item.name, "cost": item.deck.total_cost(), "budget": item.deck.budget()})
			if not playable:
				text = Text.t("setup.deck.unplayable", {"name": item.name, "issue": item.issues()[0]})
			options.append([item.id, text, playable])
	_options[side] = options
	var picker := _pickers[side]
	picker.clear()
	for i in options.size():
		picker.add_item(options[i][1], i)
		picker.set_item_disabled(i, not options[i][2])
	var picked := 0
	for i in options.size():
		if options[i][0] == _choice.deck_ids[row]:
			picked = i
	picker.select(picked)


func _on_picked(side: int, index: int) -> void:
	var options: Array = _options[side]
	if index < 0 or index >= options.size() or not choose_deck(side as Unit.Side, options[index][0]):
		_refresh()


func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 17)
	button.custom_minimum_size = Vector2(130.0, 40.0)
	button.focus_mode = Control.FOCUS_NONE
	return button


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
		get_viewport().set_input_as_handled()  # 札は読んでから閉じる（右クリック・Esc では閉じない）
