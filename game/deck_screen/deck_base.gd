extends Node
## 部隊編成の場面（game/deck_screen.gd）の土台: 読み込み、調整値、部品の変数と、部品を作る道具（札・見出し・ボタン・折り返し）、確かめと名前の入力の窓。
## 画面ごとのファイル（deck_*.gd）は、これを継いで順に積み重なる（deck_screen.gd が最後）。


const Text := preload("res://game/text.gd")
const CardKeys := preload("res://game/card_keys.gd")
const Names := preload("res://game/names.gd")
const Palette := preload("res://game/ui_palette.gd")
const UiTheme := preload("res://game/ui_theme.gd")
const AppContext := preload("res://game/app_context.gd")
const Backdrop := preload("res://game/backdrop.gd")
const ScreenSize := preload("res://game/screen_size.gd")
const DeckLibrary := preload("res://game/deck_library.gd")
const DeckText := preload("res://game/deck_text.gd")
const TextWrap := preload("res://game/text_wrap.gd")
const Story := preload("res://game/story.gd")
const Run := preload("res://game/run.gd")
const UnitCard := preload("res://game/unit_card.gd")
const ItemIcon := preload("res://game/item_icon.gd")
const Crest := preload("res://game/crest.gd")
const NationDecor := preload("res://game/nation_decor.gd")
const UnitFrame := preload("res://game/unit_frame.gd")
const RoleMark := preload("res://game/role_mark.gd")
const CostGems := preload("res://game/cost_gems.gd")
const StatsRow := preload("res://game/stats_row.gd")
const UnitDetail := preload("res://game/unit_detail.gd")
const UnitSummary := preload("res://game/unit_summary.gd")
const Steady := preload("res://game/steady.gd")
const UnitSheet := preload("res://game/unit_sheet.gd")
const Ornament := preload("res://game/ui_ornament.gd")
const FormationText := preload("res://game/formation_text.gd")


## 「タイトルへ戻る」で &"back"（流れの中なら Run.NEXT）。
signal finished(outcome: StringName)


## 色は UI のテーマの役割の色（ui_palette.gd）を引く。枠と札の形は UI のテーマ（ui_theme.gd）が当たる。
const COLOR_TEXT := Palette.TEXT
const COLOR_DIM := Palette.TEXT_DIM
const COLOR_BAD := Palette.DANGER
const COLOR_ACCENT := Palette.ACCENT
## 画面の上に空ける高さ（px）。右上のシステムメニューのボタンを、ほかの場面と同じく背景の上に置く（枠に埋もれないように）。
const TOP_ROOM := 52.0
## 詳しい中身の欄の、文を折り返す幅（px）。
const DETAIL_WIDTH := 400.0
## 組む画面の右の列: 駒の札の高さの下限（額と能力値の頭 + 文が 5 行ほど）、札と持ち物の欄の間、持ち物の欄の送れる部分の高さの下限（px）。
const DETAIL_MIN_HEIGHT := 200.0
const RIGHT_GAP := 10
const EQUIP_MIN_HEIGHT := 80.0
const ROSTER_WIDTH := 320.0
const TROOP_WIDTH := 420.0
## 組み方の欄の高さ（px）と、文の行数の上限（折り返した行も数える）。
const FORMATION_HEIGHT := 150.0
const FORMATION_LINES := 7
## 部隊の行の、組み方の札（分隊の印・誓いのボタン）の幅（px）。
const FORMATION_TAG_WIDTH := 64.0
## 一覧の右の、駒の札を並べる数（1 行）。
const LIST_CARD_COLUMNS := 3
## コストの目盛り（宝石の並び）の幅（px）。コスト上限が大きくても、この幅に詰めて収める。
const GAUGE_WIDTH := 236.0
## 画面の幅の上限（論理の px）。横長の画面では、これより広げずに真ん中に置く（docs/screen-size.md）。
const MAX_WIDTH := 1560.0


## 組む画面で使う決まり（雇える駒、予算、数の上限）。切り替え（set_mode）で変わる。
var rules: DeckRules = DeckRules.versus()
## 一覧の切り替え: 対戦用（DeckRules.VERSUS）か、物語ごとのストーリー用（物語の RULES_ID）。名前は modes() と mode_name()。
var context: AppContext


var _library: DeckLibrary
var _char_widths := {}


# ---- 一覧 ----
var _list_view: Control
var _list_rows: VBoxContainer
var _list_empty: Label
var _list_detail_title: Label
var _list_detail_body: Label
var _list_detail_crest: Crest
var _list_detail_gauge: CostGems
var _list_detail_decor: NationDecor
var _list_detail_cards: GridContainer
var _list_detail_card: Control
var _list_detail_issues: Label
var _list_actions: Array[Button] = []
var _list_selected := ""
## 一覧の見出しの横の、どの決まりの一覧か（「対戦用」か物語の名前）。切り替えのボタンは置かない（寄り道で開くので、決まりは開いたもとが決める）。
var _mode_label: Label
var _back_button: Button
## 流れの中で置かれたときに渡されたもの（{"rules": 決まりの名前, "back_label": 戻るボタンの文字}）。流れの外なら空。
var _detour := {}
## 寄り道の間に、最後に取っておいた部隊の id。
var _saved_in_detour := ""


# ---- 軍の選択（新しい部隊） ----
var _army_view: Control
var _army_cards := {}


# ---- 組む画面 ----
var _edit_view: Control
## 組み直している部隊の id（新しく組んでいるなら空）。
var _editing_id := ""
var _deck: Deck
var _deck_name := ""
var _dirty := false
var _selected := -1
## 誓い（組み方）で結ぶ相手を選んでいる駒の番号（部隊の並びの添字）。選んでいなければ -1。
var _binding := -1
## 組み方の欄（対戦用の部隊だけ。決まった大きさ）と、その文。
var _formation_box: PanelContainer
var _formation_label: Label
## マウスを乗せている雇える駒（無ければ -1）。
var _hover_kind := -1
var _name_label: Label
var _army_label: Label
var _army_crest: Crest
var _edit_decor: NationDecor
var _budget_gauge: CostGems
var _budget_label: Label
var _count_label: Label
var _issues_label: Label
var _roster_buttons := {}
var _ult_box: VBoxContainer
var _troop_rows: VBoxContainer
var _detail_card: PanelContainer
var _detail_summary: UnitSummary
var _detail_open: Button
var _unit_detail: UnitDetail
var _layer: CanvasLayer
var _equip_box: PanelContainer
var _equip_scroll: ScrollContainer
var _equip_list: VBoxContainer
var _right: VBoxContainer
var _equip_title: Label
var _equip_rows := {}
var _save_button: Button


# ---- 確かめと名前の入力 ----
var _dialog: Control
var _dialog_text: Label
var _dialog_rule: Control
var _dialog_input: LineEdit
var _dialog_ok: Button
var _dialog_action: Callable


static func _text_width(label: Label, text: String) -> float:
	return label.get_theme_font(&"font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size(&"font_size")).x


# ==== 確かめと名前の入力 ====


func is_dialog_open() -> bool:
	return _dialog.visible


## 確かめ・名前の入力の「決める」。
func accept_dialog() -> void:
	if not _dialog.visible:
		return
	var action := _dialog_action
	var input := _dialog_input.text
	var asking_name := _dialog_input.visible
	close_dialog()
	if asking_name:
		action.call(input)
	else:
		action.call()


func close_dialog() -> void:
	_dialog.visible = false
	_dialog_input.release_focus()


## 名前の入力に入っている文字（検査用に、書き換えもできる）。
func set_dialog_input(text: String) -> void:
	_dialog_input.text = text


func _confirm(text: String, ok_text: String, action: Callable) -> void:
	_dialog_text.text = text
	_dialog_ok.text = ok_text
	_dialog_ok.theme_type_variation = UiTheme.BUTTON_DANGER  # 確かめるのは、元に戻せないこと（消す）
	_dialog_rule.set(&"color", Palette.DANGER)
	_dialog_input.visible = false
	_dialog_action = action
	_dialog.visible = true


func _ask_name(title: String, current: String, action: Callable) -> void:
	_dialog_text.text = Text.t("deck.name.prompt", {"title": title, "max": DeckLibrary.MAX_NAME_LENGTH})
	_dialog_ok.text = Text.t("deck.dialog.ok")
	_dialog_ok.theme_type_variation = UiTheme.BUTTON_PRIMARY
	_dialog_rule.set(&"color", Palette.BORDER)
	_dialog_input.visible = true
	_dialog_input.text = current
	_dialog_action = action
	_dialog.visible = true
	_dialog_input.grab_focus()
	_dialog_input.select_all()


func _build_dialog() -> Control:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	var shade := ColorRect.new()
	shade.color = Palette.SHADE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.theme_type_variation = UiTheme.PANEL_SOLID
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	column.custom_minimum_size = Vector2(460.0, 0.0)
	panel.add_child(column)
	# 見出し（何を確かめるか）と、その下の飾りの線（消す確かめは危険の色、名前の入力は枠の真鍮）。
	_dialog_text = _text(20, COLOR_TEXT)
	UiTheme.style_window_title(_dialog_text, 20)
	column.add_child(_dialog_text)
	_dialog_rule = UiTheme.window_rule()
	column.add_child(_dialog_rule)
	_dialog_input = LineEdit.new()
	_dialog_input.max_length = DeckLibrary.MAX_NAME_LENGTH
	_dialog_input.add_theme_font_size_override("font_size", 20)
	_dialog_input.custom_minimum_size = Vector2(0.0, 44.0)
	_dialog_input.context_menu_enabled = false
	_dialog_input.text_submitted.connect(func(_submitted: String) -> void: accept_dialog())
	column.add_child(_dialog_input)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	column.add_child(buttons)
	var cancel := _button(Text.t("deck.dialog.cancel"), 18)
	cancel.custom_minimum_size = Vector2(180.0, 46.0)
	cancel.pressed.connect(close_dialog)
	buttons.add_child(cancel)
	_dialog_ok = _button(Text.t("deck.dialog.ok"), 18)
	_dialog_ok.custom_minimum_size = Vector2(180.0, 46.0)
	_dialog_ok.pressed.connect(accept_dialog)
	buttons.add_child(_dialog_ok)
	return overlay


# ==== 部品 ====


## 画面いっぱいの枠（外側の余白 + 中の縦の並び）。root.get_child(0).get_child(0) が縦の並び。
func _frame() -> Control:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 横長の画面では、横に広げすぎない（項目と説明が離れて読みにくくなる。docs/screen-size.md）。
	ScreenSize.cap(margin, Vector2(MAX_WIDTH, INF))
	for side: String in ["left", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	margin.add_theme_constant_override("margin_top", int(TOP_ROOM))
	var panel := PanelContainer.new()
	panel.theme_type_variation = UiTheme.PANEL_SOLID
	margin.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	return margin


## 枠の中の区切り（UI のテーマの札）。
func _card() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = UiTheme.PANEL_CARD
	return panel


## 欄の小見出し（金の太字と、右へ伸びる細い線）。
func _caption(text: String) -> Control:
	return UiTheme.section_head(text, 15)


## 画面の見出し（明朝）。
func _heading(text: String) -> Label:
	var label := Label.new()
	label.theme_type_variation = UiTheme.LABEL_HEADING
	label.add_theme_font_size_override("font_size", 26)
	label.text = text
	return label


## 必殺技の文（「必殺技: 名前」と説明）。1 行目を小見出しの色、説明を補足の色で、幅 width に折り返して出す。
func _ult_lines(text: String, width: float, font_size: int) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var parts := text.split("\n", true, 1)
	var head := _text(font_size, COLOR_ACCENT)
	head.add_theme_font_override("font", UiTheme.FONT_BOLD)
	_fold(head, parts[0], width)
	box.add_child(head)
	if parts.size() > 1:
		var body := _text(font_size, COLOR_DIM)
		_fold(body, parts[1], width)
		box.add_child(body)
	return box


## 雇える駒の札の中身を作る（額、名前、役割とコスト、能力値の欄、右上にコストの宝石）。中身は _show_roster_unit が入れる。
func _fill_roster_button(button: Button) -> void:
	var inside := HBoxContainer.new()
	inside.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inside.offset_left = 8.0
	inside.offset_right = -10.0
	inside.add_theme_constant_override("separation", 10)
	inside.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(inside)
	var frame := UnitFrame.new(UnitKind.Id.KING, 0, 48.0)
	inside.add_child(frame)
	var lines := VBoxContainer.new()
	lines.alignment = BoxContainer.ALIGNMENT_CENTER
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lines.add_theme_constant_override("separation", 1)
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inside.add_child(lines)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_child(top)
	var head := _text(14, COLOR_TEXT)
	head.add_theme_font_override("font", UiTheme.FONT_BOLD)
	head.clip_text = true
	head.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(head)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 0)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_child(bottom)
	var stats := StatsRow.new("", 13, 48.0)
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(stats)
	var gems := CostGems.new(0, 0, 7.0, 58.0)
	bottom.add_child(gems)
	button.set_meta(&"inside", inside)
	button.set_meta(&"parts", [frame, head, gems, stats])


## 雇える駒の札に、kind の駒を出す。文は「名前　役割　コスト N」と能力値の 2 行（deck.edit.roster_unit）を、行ごとに分けて置く。
func _show_roster_unit(button: Button, kind: UnitKind.Id) -> void:
	var text := Text.t("deck.edit.roster_unit", {"unit": Names.kind(kind), "role": DeckText.role_name(kind), "cost": UnitKind.cost(kind), "stats": DeckText.stats_line(kind)})
	button.set_meta(&"row_text", text)
	var parts: Array = button.get_meta(&"parts")
	var split := text.split("\n", true, 1)
	(parts[0] as UnitFrame).set_kind(kind)
	(parts[1] as Label).text = split[0]
	(parts[2] as CostGems).count = UnitKind.cost(kind)
	(parts[3] as StatsRow).set_line(split[1] if split.size() > 1 else "")


func _text(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


## 札の形のボタン（雇える駒、部隊の駒、一覧の部隊、軍）。UI のテーマのカード（乗ると金の縁）。
func _card_button(text: String, font_size: int) -> Button:
	var button := _button(text, font_size)
	button.theme_type_variation = UiTheme.BUTTON_CARD
	return button


func _button(text: String, font_size: int) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", font_size)
	return button


func _fold(label: Label, text: String, width: float) -> void:
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	label.text = TextWrap.fold(text, width, func(character: String) -> float:
		var key := "%d:%s" % [font_size, character]
		if not _char_widths.has(key):
			_char_widths[key] = font.get_string_size(character, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		return _char_widths[key])
