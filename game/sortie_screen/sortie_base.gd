extends Node
## 出撃準備の場面（game/sortie_screen.gd）の土台: 読み込み、調整値、部品の変数と、部品を作る道具（欄・見出し・文・ボタン・覚えることの札）。
## 役割ごとのファイル（sortie_*.gd）は、これを継いで順に積み重なる（sortie_screen.gd が最後）。


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
const TraitTag := preload("res://game/trait_tag.gd")
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
## 見出しの後ろの、陣営ごとの軍略の札（_army_caption）。
var _trait_tags: Array[Control] = [null, null]
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


## 部隊の欄の飾り: 上の縁にその軍の国の色の帯（軍なしは陣営の色）と、その下の淡い光。
func _decorate(panel: PanelContainer, army: UnitKind.Army, team: Color) -> void:
	var decor := NationDecor.new(army, 0.0, 44.0)
	if army == UnitKind.Army.NONE:
		decor.band_color = team
	panel.add_child(decor)


## 部隊の欄の小見出し: 軍の国の紋（軍なしは出さない）と、文。高さは小見出しの文と同じ（紋で行を高くしない）。
## side が 0 以上なら、見出しの後ろに、その陣営の軍略の札（印と名前。話のファイルの trait。乗せると文）の場所を取る。
## 軍略が無い話でも場所は取ったまま見せないので、軍略のある話と枠が変わらない。
func _army_caption(text: String, army: UnitKind.Army, side := -1) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if army != UnitKind.Army.NONE:
		var crest := Crest.new(army, 20.0)
		crest.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(crest)
	row.add_child(_caption(text))
	if side >= 0:
		var id: int = episode.traits[side] if side < episode.traits.size() else Traits.NONE
		var tag := TraitTag.new(20.0, 14)
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tag.trait_id = id
		tag.modulate.a = 1.0 if id != Traits.NONE else 0.0
		tag.mouse_filter = Control.MOUSE_FILTER_STOP if id != Traits.NONE else Control.MOUSE_FILTER_IGNORE
		tag.tooltip_text = Names.troop_trait_text(id)
		_trait_tags[side] = tag
		row.add_child(tag)
	return row


## 見出しの後ろの軍略の札の名前（陣営 side。見せていなければ空。検査用）。
func trait_tag_text(side: int) -> String:
	var tag: Control = _trait_tags[side]
	return (tag as TraitTag).shown_name() if tag != null and tag.modulate.a > 0.0 else ""


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
