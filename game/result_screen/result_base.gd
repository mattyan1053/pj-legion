extends Control
## リザルトの画面（game/result_screen.gd）の土台: 読み込み、知らせ（signal）、調整値、部品の変数と、部品を作る道具。
## 部分ごとのファイル（result_*.gd）は、これを継いで順に積み重なる（result_screen.gd が最後）。


const Text := preload("res://game/text.gd")
const Names := preload("res://game/names.gd")
const Steady := preload("res://game/steady.gd")
const Palette := preload("res://game/ui_palette.gd")
const UiTheme := preload("res://game/ui_theme.gd")
const ResultSummary := preload("res://game/result_summary.gd")
const OverlayStack := preload("res://game/overlay_stack.gd")
const StatsText := preload("res://game/stats_text.gd")
const ResultGlow := preload("res://game/result_glow.gd")
const UnitFrame := preload("res://game/unit_frame.gd")
const UiTaper := preload("res://game/ui_taper.gd")
const UnitIcons := preload("res://game/unit_icons.gd")
const TextWrap := preload("res://game/text_wrap.gd")
const BattleCues := preload("res://game/battle_cues.gd")


## 行き先のボタン。field はマップの鍵（versus_fields.gd）。new_board が偽なら、いまと同じマップで再戦（field は見ない）。
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
## 後ろの光と粒が出きるまで。
const GLOW_IN := 0.6
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
## 戦績の行は最大 5 行（マップ・経過ターン・敵軍撃破・中立撃破・聖遺物）。5 行のときも、入力の案内が画面の下の帯
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
## 負けたときの台詞の板（set_remark。ストーリーの話の [lost]）: 幅、戦績の列との間、話し手のアイコン、文の大きさ。
## 戦績の列（幅 460）の左に置く（見出しの下は、戦績が 5 行のときに縦の余りが無い。人の軍の話し手は、会話の場面でも左に立つ）。
const REMARK_WIDTH := 300.0
const REMARK_GAP := 22.0
const REMARK_FACE := 40.0
const REMARK_FONT := 17


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
## 将の姿（陣営ごと。unit_looks.gd の KING_LOOKS の名前。空ならいつもの将）。MVP と表のアイコンに使う。
var king_looks: Array[StringName] = [&"", &""]


var _summary: RefCounted
var _shade: ColorRect
var _glow: ResultGlow
var _headline: Label
var _reason: Label
var _body: VBoxContainer
var _stats_panel: PanelContainer
var _stats_title: Label
var _stats_grid: GridContainer
var _stat_rows: Array = []
## 戦績の行の高さを上限の数ぶん取るための、空の行（段階の出し方には入れない）。
var _stat_pads: Array[Label] = []
var _mvp_panel: PanelContainer
var _mvp_head: Label
var _mvp_name: Label
var _mvp_icon: UnitFrame
var _mvp_numbers: Label
var _detail_panel: PanelContainer
var _detail: Label
## 詳しい戦績の表: 陣営の切り替え、陣営の 1 行、表の行の入れ物、いま出している陣営。
var _table_tabs: Array[Button] = []
var _table_summary: Label
## 表の、駒の名前の列の見出し（対戦モードは「駒」、ストーリーは「名前」）。
var _table_unit_head: Label
var _table_rows: VBoxContainer
var _table_side := 0
## 詳しい戦績の文（stats_text.gd。画面には表で出す。検査用）。
var _detail_text := ""
var _actions: VBoxContainer
var _detail_button: Button
## 行き先のボタンのうち、対戦によって出さないことがあるもの（set_destinations）。
var _board_buttons: Array[Button] = []  # 新しいマップ（ボタンの meta の &"field" がマップの鍵）
var _setup_button: Button
var _leave_button: Button
var _squad_button: Button
var _continue_button: Button
var _again_button: Button
## Enter で「同じマップで再戦」を選ぶか（set_continue）。
var _enter_retries := false
var _prompt: Label
## 負けたときの台詞の板と、その行の入れ物、出している台詞（「名前: 文」。検査用）。
var _remark: PanelContainer
var _remark_rows: VBoxContainer
var _remark_texts: Array[String] = []
var _buttons: Array[Button] = []
var _tween: Tween
var _revealed := false
var _skipped := false
var _elapsed := 0.0


func _sound(name: StringName) -> void:
	if play_sound.is_valid():
		play_sound.call(name)


## 陣営の色（team_colors。無ければ、いつもの青と赤）。
func _side_color(side: int) -> Color:
	if side >= 0 and side < team_colors.size():
		return team_colors[side]
	return Palette.TEAM_RED if side == 1 else Palette.TEAM_BLUE


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


## 見出しを真ん中に、左右に細くなる線（色は color）。
func _flanked(label: Label, color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(UiTaper.new(false, color))
	row.add_child(label)
	row.add_child(UiTaper.new(true, color))
	return row


## 板。上の縁を太くする（edge は縁の色。MVP は金、ほかは枠の真鍮）。
func _panel(edge: Color) -> PanelContainer:
	var style := UiTheme.box(COLOR_PANEL, edge, 1, 6, 12.0, 6)
	style.border_width_top = 3
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
