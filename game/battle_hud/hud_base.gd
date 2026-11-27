extends CanvasLayer
## 対戦の画面の文字とボタン（game/battle_hud.gd）の土台: 読み込み、知らせ（signal）、調整値、部品の変数と、部品を作る道具（_panel・_label・_button など）。
## 帯・枠ごとのファイル（hud_*.gd）は、これを継いで順に積み重なる（battle_hud.gd が最後）。


## 駒のそばのメニューの項目が押された。id は set_menu() に渡した項目の名前。
const Text := preload("res://game/text.gd")
const Palette := preload("res://game/ui_palette.gd")
const UiTheme := preload("res://game/ui_theme.gd")
const TextWrap := preload("res://game/text_wrap.gd")
const Names := preload("res://game/names.gd")
const TraitText := preload("res://game/trait_text.gd")
const SystemMenu := preload("res://game/system_menu.gd")
const Steady := preload("res://game/steady.gd")
const KeyMarks := preload("res://game/key_marks.gd")
const SignMark := preload("res://game/sign_mark.gd")
const SignCard := preload("res://game/sign_card.gd")
const TraitCard := preload("res://game/trait_card.gd")
const RuleCard := preload("res://game/rule_card.gd")
const GoalMark := preload("res://game/goal_mark.gd")
const StrongholdFlags := preload("res://game/stronghold_flags.gd")
const ForecastPanel := preload("res://game/forecast_panel.gd")
const ForecastText := preload("res://game/forecast_text.gd")
const RelicIcon := preload("res://game/relic_icon.gd")
const TraitIcon := preload("res://game/trait_icon.gd")
const TraitTag := preload("res://game/trait_tag.gd")
const ResultScreen := preload("res://game/result_screen.gd")
const Minimap := preload("res://game/minimap.gd")
const MinimapGeometry := preload("res://game/minimap_geometry.gd")
const BannerBand := preload("res://game/banner_band.gd")
const UnitFrame := preload("res://game/unit_frame.gd")
const StatsRow := preload("res://game/stats_row.gd")
const InfoCard := preload("res://game/info_card.gd")
const UnitSheet := preload("res://game/unit_sheet.gd")
const UnitEffects := preload("res://game/unit_effects.gd")


signal menu_pressed(id: StringName)
## 駒のそばのメニューの項目にマウスが乗った（id）、離れた（空の名前）。乗っている間、その項目の説明を出す。
signal menu_hovered(id: StringName)
## 必殺技のボタンが押された（確かめる・使うのは呼ぶ側が決める）。
signal ult_pressed
signal end_turn_pressed
## 進化先を選んだ。index は、出している選択肢の何番目か（0 が A、1 が B）。
signal evolution_chosen(index: int)
## 敵の全員の脅威範囲の切り替えが押された（出す・消すは呼ぶ側が決める）。
signal threat_toggled
## 相手の番の「早送り」「スキップ」が押された。
signal fast_forward_toggled
signal skip_pressed
## 自分の番の「おまかせ」が押された。
signal auto_pressed
## 駒の情報の枠の「範囲を表示したまま」のスイッチが押された。
signal pin_toggled
## 駒の情報の枠の「詳細」を押した（その駒のステータスの窓を開く）。
signal detail_pressed
## 相手を人にするか CPU にするかの切り替えが押された。
signal opponent_pressed
## ログのボタンが押された。
signal log_pressed
## 決着の画面の「対戦設定へ」が押された。
signal setup_pressed
## 決着の画面の「タイトルへ」が押された。
signal title_pressed
## field はマップの鍵（versus_fields.gd）。new_board が偽なら、いまと同じ盤面でやり直す（field は見ない）。
signal restart_pressed(field: StringName, new_board: bool)
## 決着の画面を出した（draw なら引き分けで、winner は使わない）。決着の曲を鳴らす合図。
signal result_shown(draw: bool, winner: Unit.Side)
## 対戦の始めの「対戦ルール」を閉じた（出ていたものを閉じたときだけ）。対戦の場面は、ここから手番を始める。
signal notice_closed


const COLOR_PANEL := Palette.OVERLAY
## 後ろの盤面の文字が透けて読みにくくならないよう、決着の画面とメニューは透かさない。
const COLOR_PANEL_SOLID := Palette.SOLID
const COLOR_END_TURN := Palette.GO
const COLOR_END_TURN_READY := Palette.GO_READY
## 上の帯と下の帯の高さ（駒のそばのメニューは、この内側に置く）。
const TOP_BAR_HEIGHT := 50.0
## 下の帯の高さは、中身で伸び縮みしない（docs/ui-theme.md の「枠の大きさ」）。左の欄に、案内（句と印の小さな並び。1 行）と、
## マスの説明（CELL_LINES 行まで）が入る。
const BOTTOM_BAR_HEIGHT := 92.0
## 下の帯の上下の余白（px）。ほかの帯より詰める。
const BOTTOM_BAR_MARGIN := 6.0
## 下の帯の案内の欄の高さと、マスの説明の欄の高さ・行の数。出すものが無くても、この高さのまま。
const GUIDE_HEIGHT := 24.0
const CELL_HEIGHT := 46.0
const CELL_LINES := 2
## マスの説明の字の大きさ（px）。入る行の数に収まらないときだけ、小さいほうにする。それでも入らなければ「…」で切る（マスを押すと、情報の枠で全部読める）。
const CELL_FONT_SIZE := 14
const CELL_FONT_SIZE_SMALL := 12
## 駒のそばのメニューの項目の幅（px）。項目の言葉で幅を変えない。いちばん長い項目（スキルの名前と残りの回数）は、字を小さくして入れる。
const MENU_ITEM_WIDTH := 210.0
const MENU_FONT_SIZE := 17
const MENU_FONT_FLOOR := 13
## 拠点の札の大きさ（px）。確保の数が変わっても、あと 1 回で勝つときも、この大きさのまま。
## 陣営ごとの数の欄（「青 3 / 8」）は、決まった幅。拠点ごとの持ち主の旗の欄（stronghold_flags.gd）も決まった幅で、拠点がいくつでも同じ。
const STRONGHOLD_CHIP_SIZE := Vector2(316.0, 30.0)
const STRONGHOLD_SIDE_WIDTH := 76.0
## あと 1 回で勝つ（急ぎの赤い地の）ときの、陣営ごとの数の字を白に寄せる割合。
const STRONGHOLD_URGENT_LIGHTEN := 0.7
## 縫い目の様子の札の帯（選べる決まり。上の帯の下の左、勝ち方の札・拠点の札の下）の大きさと、札 1 枚ぶんの欄の幅、印の大きさ。
const SIGNS_CHIP_SIZE := Vector2(440.0, 34.0)
const SIGN_SLOT_WIDTH := 205.0
const SIGN_MARK_SIDE := 26.0
## 上の帯の勝ち方の札・拠点の札の印の大きさ（px）と、勝ち方の札に並べる印の数の上限。
const GOAL_MARK_SIDE := 24.0
## 上の帯の、軍略の札の印の大きさと、名前の字の大きさ。
const TRAIT_MARK_SIDE := 20.0
const TRAIT_NAME_FONT := 14
## 上の帯の中身の高さと、上下の余白（合わせて、もとの帯の高さ）。陣営の欄の字の大きさ（1 段のときと、軍略の段を足した 2 段のとき）。
const TOP_BAND_ROW := 42.0
const TOP_BAND_PAD := 4.0
const SIDE_FONT := 16
const SIDE_FONT_STACKED := 15
const GOAL_TAG_MARKS := 3
## 対戦の始めの「対戦ルール」の枠の大きさ（px）。札の数で変えない（勝利条件の段と縫い目の様子の段が入る高さ）。
const NOTICE_SIZE := Vector2(720.0, 400.0)
## 「対戦ルール」に並べる勝利条件の札の数の上限（1 段）。対戦モードは 3 つ（将・本陣・拠点）、話は 2 つまで + 時間の限り。
const NOTICE_GOALS := 3
## メニューが駒の中央からこれより離れたら、駒まで線を引く（px）。
const MENU_LINE_FROM := 70.0
## 文を折り返す幅（px）。情報の枠、必殺技の説明。下の帯の説明は、画面の幅からボタンのぶんを引く。
const INFO_WIDTH := 320.0
## 情報の枠の高さ（px）。駒でもマスでも、中身が多くても少なくても、この高さ（docs/ui-theme.md の「枠の大きさ」）。
## 入りきらない中身は、後で読めるものから省く（info_card.gd の fit）。
const INFO_HEIGHT := 460.0
## 行動の状態を、名前の右の札にする長さの上限（字。これより長い文は、札の下の行に出す）。
const ACTION_TAG_CHARS := 6
## 情報の枠の札と、下のボタンの行の間（px）。
const INFO_FOOT_GAP := 6.0
const ULT_SUMMARY_WIDTH := 480.0
const COLOR_TEXT_DIM := Palette.TEXT_DIM
const COLOR_FORECAST := Palette.ACCENT
const COLOR_STATUS := Palette.INFO
## 勝ち方の札の地と枠（いつもと、最後のターンのように急ぐとき）。
const COLOR_GOAL := Palette.GOAL
const COLOR_GOAL_BORDER := Palette.GOAL_BORDER
const COLOR_GOAL_URGENT := Palette.GOAL_URGENT
## 必殺技の画面のフラッシュ（濃さと、消えるまでの秒数）。
const FLASH_ALPHA := 0.45
const FLASH_TIME := 0.45
## READY の明滅（いちばん色づいたときの色と、1 回の秒数）。
const COLOR_PULSE := Palette.WARN
const PULSE_PERIOD := 1.1
## 必殺技の知らせの色（軍ごと）。
const ULT_COLORS := {
	Ult.Id.ALL_OUT_ASSAULT: Color("ff5a4a"),
	Ult.Id.MANA_ERUPTION: Color("9a7bff"),
}


## 盤の四隅を沈める幕の濃さ（景色の上に題字を置く画面を 1 として）。
const BOARD_VIGNETTE := 0.4
## 番の文字の後ろの札に、陣営の色を混ぜる割合（地は INK）。
const PHASE_CHIP_TINT := 0.42
## 画面の中央の知らせの帯の、上からの位置。
const BANNER_TOP := 132.0


var _team_colors: Array[Color] = []
## 将の姿（陣営ごと。unit_looks.gd の KING_LOOKS の名前。空ならいつもの将）。駒の情報のアイコンに使う。
var king_looks: Array[StringName] = [&"", &""]
## 名前のある人物の形の付いた駒（駒の id -> unit_looks.gd の PERSONS の名前）。駒の情報のアイコンに使う（将の姿より先）。
var unit_looks := {}


var _turn_label: Label
var _phase_label: Label
## 上の帯の形（下の縁を、番の陣営の色にする）と、番の文字の後ろの札。
var _top_style: StyleBoxFlat
var _phase_chip_style: StyleBoxFlat
## 勝ち方の札（勝ち方がいつもと違う戦いだけ出す。win_text.gd の goal_tag）。
var _goal_panel: PanelContainer
var _goal_style: StyleBoxFlat
var _goal_label: Label
## 拠点の札（選べる決まり「拠点」の対戦だけ出す）: 見出しと、陣営ごとの確保の印。大きさは中身で変えない（STRONGHOLD_CHIP_SIZE）。
var _stronghold_panel: PanelContainer
var _stronghold_style: StyleBoxFlat
var _stronghold_caption: Label
var _stronghold_marks: Array[Label] = []
var _stronghold_flags: StrongholdFlags
## 縫い目の様子の札の帯と、札ごとの欄（印と名前。マウスを乗せると効果の文）。
var _signs_panel: PanelContainer
var _sign_slots: Array[Control] = []
var _sign_marks: Array[SignMark] = []
var _sign_names: Array[Label] = []
## 札の名前をクリックすると出す、札 1 枚の窓（決まった大きさ。sign_card.gd）と、出している札の位置（出していなければ -1）。
var _sign_note: PanelContainer
var _sign_note_card: SignCard
var _sign_note_index := -1
## 上の帯の軍略の札をクリックすると出す、軍略 1 つの窓（trait_card.gd）と、どちらの陣営のものを出しているか（出していなければ -1）。
var _trait_note: PanelContainer
var _trait_note_card: TraitCard
var _trait_note_player := -1
## 対戦の始めの知らせ（選べる決まり。見出し、決まりごとの行、閉じるボタン）。
## 上の帯の勝ち方の札の印（goal_mark.gd）。
var _goal_marks: Array[GoalMark] = []
var _notice: PanelContainer
## 「対戦ルール」を出している間、盤と帯へのクリックを受け止めて、札を閉じる（札の後ろで何も押せない）。
var _notice_catcher: Control
## 「対戦ルール」の札（勝利条件と縫い目の様子）と、縫い目の様子の段の見出し・段。
var _notice_goals: Array[RuleCard] = []
var _notice_signs: Array[RuleCard] = []
var _notice_signs_caption: Label
var _notice_signs_row: Control
var _side_labels: Array[Label] = []
var _relic_texts: Array[String] = ["", ""]
## 陣営ごとの聖遺物のアイコン（添字がプレイヤー番号。中は Relics.Id の順）。
var _relic_icons: Array[Array] = []
## 陣営ごとの軍略の札（上の帯。印と名前。乗せると文。docs/troop-traits.md）。
var _trait_icons: Array[Control] = []
var _relic_notes: Array[String] = ["", ""]
var _ult_bars: Array[ProgressBar] = []
var _ult_labels: Array[Label] = []
var _ult_button: Button
## 必殺技のボタンの中のゲージ（描く所、溜まり具合（負なら出さない）、陣営の色）と、下の辺の棒の太さ（px）。
const ULT_FILL_BAR := 4.0
var _ult_fill: Control
var _ult_fill_ratio := -1.0
var _ult_fill_color := Palette.TEAM_BLUE
var _ult_summary: Label
var _info_panel: PanelContainer
var _info_style: StyleBoxFlat
## 情報の枠の中身（駒のステータスの札、マスの札。info_card.gd）と、下のボタンの行。いま出しているのが駒の札か。
var _info_card: InfoCard
var _info_foot: HBoxContainer
var _info_is_unit := false
## 盤を見ている人のプレイヤー（駒の情報の「自軍」「敵軍」を決める）。呼ぶ側が合わせる。
var viewer_side := Unit.Side.PLAYER1
## 陣営ごとの軍（Battle.armies。対戦の画面が入れる）。所属の欄に出す軍は、駒の種類の軍でなく、陣営の軍。
var side_armies: Array = []
## いまの対戦（対戦の画面が入れる）。スキルが、いま使える状態か（動いたら使えない、など）を見るのに使う。
var battle: Battle
## 見ている相手の駒の攻撃範囲を、表示したままにするスイッチ（枠のいちばん下。set_pin_switch）。
var _info_pin: CheckButton
var _info_detail: Button
var _cell_label: Label
## 下の帯の案内（句と印の並び）と、色の印の名前 -> 盤に塗る色（対戦の画面が入れる）。
var _guide: KeyMarks
var range_colors := {}
var _cell_text := ""
var _end_turn_button: Button
var _end_turn_style: StyleBoxFlat
var _opponent_button: Button
var _threat_button: CheckButton
## 相手の番（見ているだけの番）に、必殺技のボタンの代わりに出す「早送り」「スキップ」（set_watch_controls）。
var _watch_box: HBoxContainer
var _fast_button: Button
var _skip_button: Button
## 自分の番の残りを CPU に任せるボタン（ターン終了の左。set_auto_button）。
var _auto_button: Button
var _ult_panel: PanelContainer
var _ult_pinned := false
var _menu: PanelContainer
var _forecast: ForecastPanel
var _menu_line: Line2D
var _menu_column: VBoxContainer
## いまメニューに出している項目（[名前, 文字, 押せるか] の列）と、項目の名前 -> ボタン。
var _menu_items: Array = []
var _menu_buttons := {}
## メニューが届くマスに掛かっているか（set_menu_see_through）。
var _menu_see_through := false
## 届くマスに掛かったメニューの、マウスが乗っていない間の濃さ。
const MENU_SEE_THROUGH_ALPHA := 0.6
## 文字の幅の覚え（"文字の大きさ:文字" -> px）。折り返しに使う。
var _char_widths := {}
var _banner: BannerBand
var _flash: ColorRect
var _flash_tween: Tween
var _result: ResultScreen
var _guide_panel: PanelContainer
var _minimap: Minimap
## ミニマップを出すか（設定の「ミニマップ」）。
var _minimap_wanted := true
## 進化先の札の大きさの下限と、札の額の辺（px）。
const EVOLUTION_CARD := Vector2(330.0, 110.0)
const EVOLUTION_FRAME := 64.0
var _evolution: Control
var _evolution_title: Label
var _evolution_buttons: Array[Button] = []


## label に、折り返した text を出す。空なら隠す。
func _set_shown(label: Label, text: String) -> void:
	label.visible = text != ""
	if label.visible:
		_set_folded(label, text, INFO_WIDTH)


func _side_color(side: Unit.Side) -> Color:
	return _team_colors[side] if side < _team_colors.size() else Color.WHITE


func _panel(color := COLOR_PANEL) -> PanelContainer:
	var style := UiTheme.box(color, Color(Palette.BORDER, 0.9), 1, 6, 10.0)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _label(font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", 4)
	return label


## 文字の幅（px）。何度も測り直さないよう覚えておく（画面を作り直すたびに呼ばれる）。
func _char_width(font: Font, font_size: int, character: String) -> float:
	var key := "%d:%s" % [font_size, character]
	if not _char_widths.has(key):
		_char_widths[key] = font.get_string_size(character, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	return _char_widths[key]


## label に、width（px）で折り返した text を出す（text_wrap.gd。日本語の禁則を守る）。
func _set_folded(label: Label, text: String, width: float) -> void:
	if label.has_meta(&"plain"):
		label.set_meta(&"plain", text)  # 字の大きさを変えて折り返し直すときの、元の文（_fit_info）
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	label.text = TextWrap.fold(text, width, func(character: String) -> float: return _char_width(font, font_size, character))


## pressed を、そのまま to（この HUD の signal）として知らせるボタン。to が空なら、呼ぶ側でつなぐ。
func _button(text: String, to: Signal) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 18)
	button.custom_minimum_size = Vector2(150.0, 48.0)
	button.focus_mode = Control.FOCUS_NONE
	if not to.is_null():
		button.pressed.connect(to.emit)
	return button
