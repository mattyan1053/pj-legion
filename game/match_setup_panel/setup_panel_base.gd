extends Control
## 対戦設定のパネル（game/match_setup_panel.gd）の土台: 読み込み、知らせ（signal）、調整値、部品の変数と、部品を作る小さな道具。
## 部分ごとのファイル（setup_panel_*.gd）は、これを継いで順に積み重なる（match_setup_panel.gd が最後）。


## 選んだもの（match_choice.gd の値。呼ぶ側に渡すのは写し）。
signal start_pressed(choice: RefCounted)
## 何も変えずに閉じた（「対戦へ戻る」、右クリック、Esc）。いまの対戦は、そのまま続く。
signal cancelled
## 「マップを選び直す」。いまの選択（写し）を渡す。持ち主がマップ選択の場面へ進む。
signal map_pressed(choice: RefCounted)
## 「部隊編成」。いまの選択（写し）と、部隊を組むプレイヤーを渡す。持ち主が部隊編成へ寄り道する。
signal decks_pressed(choice: RefCounted, side: Unit.Side)


const DeployDialog := preload("res://game/deploy_dialog.gd")
## 初期位置の窓で見せる盤の種（生成のマップは、マップ選択のカードと同じ代表の形）。
const PLACEMENT_SEED := 3
## 選べる決まりの行（並び）、「あり」「なし」のボタンの大きさ、右の説明の欄の大きさ（px。1 行）。
const RULE_ROWS: Array[StringName] = [OptionalRules.STRONGHOLD, OptionalRules.SEAM]
const TRIAL_BUTTON_WIDTH := 110.0
const TRIAL_BUTTON_HEIGHT := 26.0
const TRIAL_NOTE_SIZE := Vector2(440.0, 26.0)
const Text := preload("res://game/text.gd")
const Steady := preload("res://game/steady.gd")
const Palette := preload("res://game/ui_palette.gd")
const UiTheme := preload("res://game/ui_theme.gd")
const MatchChoice := preload("res://game/match_choice.gd")
const VersusFields := preload("res://game/versus_fields.gd")
const DeckText := preload("res://game/deck_text.gd")
const DeckPreview := preload("res://game/deck_preview.gd")
const Names := preload("res://game/names.gd")
const BattleUiState := preload("res://game/battle_ui_state.gd")
const VersusBanner := preload("res://game/versus_banner.gd")
const MapCard := preload("res://game/map_card.gd")
const Ornament := preload("res://game/ui_ornament.gd")


const ARMIES: Array[UnitKind.Army] = [UnitKind.Army.MILITARY, UnitKind.Army.FANTASY]
## パネルの中身の幅（px）。選んだものに依らず、この幅に固定する。
const PANEL_WIDTH := 900.0
## 見出しの列の幅と、部隊を選ぶ欄の幅（px）。
const CAPTION_WIDTH := 180.0
const PICKER_WIDTH := 330.0
## 手番の「ランダム」のボタンの値（Unit.Side の値と重ならない）。
const RANDOM_SIDE := -1
## 確かめの間のボタンの文字（「マップ変更」と、始めるボタン）と、下の文（理由）。
const CONFIRM_MAP_BUTTON := "setup.confirm.map"
const CONFIRM_START_BUTTON := "setup.confirm.start"
const MAP_TEXT := "setup.map"
const WARNING_TEXT := "setup.warning"
const CONFIRM_MAP_TEXT := "setup.confirm_map"
const CONFIRM_START_TEXT := "setup.confirm_start"


var _choice: RefCounted = MatchChoice.new()
var _team_colors: Array[Color] = []
## 選択肢の名前 -> その行のボタン（値 -> Button）。
var _rows := {}
## プレイヤーごとの、軍の行の見出し（「あなた」「CPU」など）、部隊を選ぶ欄、「編成確認」、「部隊編成」、その選択肢
## （並びの番号 -> 部隊の id。空は既定の編成、MatchChoice.RANDOM はランダム編成）。
var _who_labels: Array[Label] = []
var _deck_pickers: Array[OptionButton] = []
var _preview_buttons: Array[Button] = []
var _edit_buttons: Array[Button] = []
var _deck_choices: Array = [[], []]
var _map_name: Label
## 対戦の組み合わせの帯（versus_banner.gd）と、その縮図に出しているマップ（選び直したときだけ描き直す）。
var _banner: VersusBanner
var _banner_field := &""
## プレイヤーごとの、軍と部隊の 2 行を囲む板（左の縁に陣営の色）。
var _side_boxes: Array[PanelContainer] = []
var _map_button: Button
var _preview: DeckPreview
var _placement_buttons: Array[Button] = []
var _placement: DeployDialog
## 初期位置の窓で決めている行。
var _placing_row := -1
## 「部隊編成」を出すか（対戦設定の場面だけ。対戦の途中では出さない）。
var _can_edit_decks := false
## 取っておいた部隊（deck_library.gd）。無ければ既定の編成だけ。
var _library: RefCounted
var _side_caption: Label
## 選べる決まりの行の右の説明（決まりの名前 → Label）。
var _rule_notes: Dictionary[StringName, Label] = {}
var _panel: PanelContainer
var _first_gauge_note: Label
var _start_button: Button
var _back_button: Button
var _warning: Label
## 閉じて、いまの対戦へ戻れるか（起動した直後の、まだ対戦を始めていないときだけ偽）。
var _cancellable := false
## 決着していない対戦の途中で開いたか（押すと対戦が終わるボタンを 2 回押させる）。
var _in_progress := false
## 2 回目を待っているボタン（無ければ null）と、確かめを始めた時刻（ミリ秒）。
var _confirming: Button
var _confirm_started_msec := 0
## 始めるボタンのいまの文字（確かめをやめたら戻す）。
var _start_text := ""


## 開いている重なる画面の積み上げ（overlay_stack.gd。AppContext.overlays）。見えている間は積んでおく。
var _overlays: RefCounted


## プレイヤーの 2 行を囲む板の形: 薄い地と、左の縁の太い線（陣営の色。tint が透明なら枠の真鍮）。大きさは色で変わらない。
static func _side_box(tint: Color) -> StyleBoxFlat:
	var sided := tint.a > 0.0
	var edge := tint.lightened(0.15) if sided else Palette.BORDER
	var fill := Color(tint, 0.1) if sided else Color(Palette.RAISED, 0.35)
	var style := UiTheme.box(fill, Color(edge, 0.55), 1, UiTheme.CORNER, 8.0)
	style.border_width_left = 4
	style.border_color = Color(edge, 0.85)
	style.content_margin_left = 10.0
	return style


func _label(font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", 4)
	return label


func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 17)
	button.custom_minimum_size = Vector2(150.0, 40.0)
	button.focus_mode = Control.FOCUS_NONE
	return button
