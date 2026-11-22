extends CanvasLayer
## 対戦の画面の文字とボタン（ターン、番、駒とマスの情報、駒のそばのメニュー、決着）。
##
## 何を出すかは呼ぶ側が決める。ここはルールを持たず、押されたことを signal で知らせるだけ。
## 駒に属する操作（攻撃、スキル、待機…）は駒のそばのメニューに、駒に属さない操作（ターン終了、必殺技、相手の切り替え）は
## 画面の決まった場所に置く。どれもクリックだけで選べる。

## 駒のそばのメニューの項目が押された。id は set_menu() に渡した項目の名前。
const Text := preload("res://game/text.gd")
const Palette := preload("res://game/ui_palette.gd")
const UiTheme := preload("res://game/ui_theme.gd")
const TextWrap := preload("res://game/text_wrap.gd")
const Names := preload("res://game/names.gd")
const SystemMenu := preload("res://game/system_menu.gd")
const Steady := preload("res://game/steady.gd")
const ForecastPanel := preload("res://game/forecast_panel.gd")
const ForecastText := preload("res://game/forecast_text.gd")
const RelicIcon := preload("res://game/relic_icon.gd")
const ResultScreen := preload("res://game/result_screen.gd")
const Minimap := preload("res://game/minimap.gd")
const MinimapGeometry := preload("res://game/minimap_geometry.gd")
const BannerBand := preload("res://game/banner_band.gd")
const UnitFrame := preload("res://game/unit_frame.gd")
const StatsRow := preload("res://game/stats_row.gd")

signal menu_pressed(id: StringName)
## 駒のそばのメニューの項目にマウスが乗った（id）、離れた（空の名前）。乗っている間、その項目の説明を出す。
signal menu_hovered(id: StringName)
## 必殺技のボタンが押された（確かめる・使うのは呼ぶ側が決める）。
signal ult_pressed
## 作戦のボタン（手札の何枚目か）が押された。
signal tactic_pressed(index: int)
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

const COLOR_PANEL := Palette.OVERLAY
## 後ろの盤面の文字が透けて読みにくくならないよう、決着の画面とメニューは透かさない。
const COLOR_PANEL_SOLID := Palette.SOLID
const COLOR_END_TURN := Palette.GO
const COLOR_END_TURN_READY := Palette.GO_READY
## 上の帯と下の帯の高さ（駒のそばのメニューは、この内側に置く）。
const TOP_BAR_HEIGHT := 50.0
## 下の帯の高さは、中身で伸び縮みしない（docs/ui-theme.md の「枠の大きさ」）。案内（2 行まで）とマスの説明で、合わせて 3 行が入る:
## 案内が 1 行ならマスの説明は 2 行まで、案内が 2 行ならマスの説明は 1 行。
const BOTTOM_BAR_HEIGHT := 92.0
## 下の帯の上下の余白（px）。3 行が入るよう、ほかの帯より詰める。
const BOTTOM_BAR_MARGIN := 6.0
## マスの説明の字の大きさ（px）。入る行の数に収まらないときだけ、小さいほうにする。それでも入らなければ「…」で切る（マスを押すと、情報の枠で全部読める）。
const CELL_FONT_SIZE := 14
const CELL_FONT_SIZE_SMALL := 12
## 駒のそばのメニューの項目の幅（px）。項目の言葉で幅を変えない。いちばん長い項目（スキルの名前と残りの回数）は、字を小さくして入れる。
const MENU_ITEM_WIDTH := 210.0
const MENU_FONT_SIZE := 17
const MENU_FONT_FLOOR := 13
const TACTIC_BUTTON_HEIGHT := 40.0
## 拠点の札の大きさ（px）。確保の数が変わっても、あと 1 回で勝つときも、この大きさのまま。
const STRONGHOLD_CHIP_SIZE := Vector2(360.0, 30.0)
## 対戦の始めの知らせ（試しの決まり）の枠の大きさ（px）。決まりの数で変えない。
const NOTICE_SIZE := Vector2(620.0, 290.0)
## 知らせの本文の行数の上限（折り返した行も数える）。これを超える分は出さない（枠を広げない）。
const NOTICE_LINES := 6
## 作戦のボタンの幅と、その上の説明の枠の大きさ（px）。札の名前・使用済み・確かめで変えない。
const TACTIC_BUTTON_WIDTH := 172.0
const TACTIC_NOTE_SIZE := Vector2(460.0, 70.0)
const TACTIC_FLASH_SECONDS := 5.0
## メニューが駒の中央からこれより離れたら、駒まで線を引く（px）。
const MENU_LINE_FROM := 70.0
## 文を折り返す幅（px）。情報の枠、必殺技の説明。下の帯の説明は、画面の幅からボタンのぶんを引く。
const INFO_WIDTH := 320.0
## 情報の枠の高さ（px）。駒でもマスでも、中身が多くても少なくても、この高さ（docs/ui-theme.md の「枠の大きさ」）。
## 入りきらない中身は、字を 1 段ずつ小さくして収め、それでも入らなければ、後で読めるものから省く（_fit_info）。
const INFO_HEIGHT := 460.0
const INFO_FONT_FLOOR := 12
## 字を小さくする段の数の上限（1 段 1 px）。
const INFO_SHRINK_STEPS := 3
## 駒の情報の枠の、駒のアイコンの大きさ（px）。
const INFO_ICON_SIZE := 48.0
const ULT_SUMMARY_WIDTH := 480.0
const COLOR_TEXT_DIM := Palette.TEXT_DIM
const COLOR_FORECAST := Palette.ACCENT
const COLOR_STATUS := Palette.INFO
const COLOR_TRAIT := Palette.ACCENT
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

var _turn_label: Label
var _phase_label: Label
## 上の帯の形（下の縁を、番の陣営の色にする）と、番の文字の後ろの札。
var _top_style: StyleBoxFlat
var _phase_chip_style: StyleBoxFlat
## 勝ち方の札（勝ち方がいつもと違う戦いだけ出す。win_text.gd の goal_tag）。
var _goal_panel: PanelContainer
var _goal_style: StyleBoxFlat
var _goal_label: Label
## 拠点の札（試しの決まり「拠点」の対戦だけ出す）: 見出しと、陣営ごとの確保の印。大きさは中身で変えない（STRONGHOLD_CHIP_SIZE）。
var _stronghold_panel: PanelContainer
var _stronghold_style: StyleBoxFlat
var _stronghold_caption: Label
var _stronghold_marks: Array[Label] = []
## 対戦の始めの知らせ（試しの決まり。見出し、決まりごとの行、閉じるボタン）。
var _notice: PanelContainer
var _notice_body: Label
var _side_labels: Array[Label] = []
var _relic_texts: Array[String] = ["", ""]
## 陣営ごとの聖遺物のアイコン（添字がプレイヤー番号。中は Relics.Id の順）。
var _relic_icons: Array[Array] = []
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
var _info_icon: UnitFrame
## 駒の能力値の欄（HP の棒、HP の数とレベル、攻撃・移動・射程の欄）と、その下の区切りの線。マスの情報では出さない。
var _info_unit_box: VBoxContainer
var _info_hp_label: Label
var _info_level: Label
var _info_stats_row: StatsRow
var _info_rule: HSeparator
var _info_name: Label
var _info_side: Label
var _info_hp: ProgressBar
var _info_hp_fill: StyleBoxFlat
var _info_stats: Label
var _info_state: Label
var _info_statuses: Label
var _info_items: Label
var _info_skill: Label
var _info_skill_note: Label
var _info_traits: Label
## 盤を見ている人のプレイヤー（駒の情報の [自軍] [敵軍] を決める）。呼ぶ側が合わせる。
var viewer_side := Unit.Side.PLAYER1
## 陣営ごとの軍（Battle.armies。対戦の画面が入れる）。所属の欄に出す軍は、駒の種類の軍でなく、陣営の軍。
var side_armies: Array = []
## いまの対戦（対戦の画面が入れる）。スキルが、いま使える状態か（動いたら使えない、など）を見るのに使う。
var battle: Battle
var _info_forecast: Label
## 見ている相手の駒の攻撃範囲を、表示したままにするスイッチ（枠のいちばん下。set_pin_switch）。
var _info_pin: CheckButton
## 情報の枠の、残りの高さに収める文の入れ物（_build_info_panel）と、その中の列。
var _info_room: ScrollContainer
var _info_lines: VBoxContainer
## 情報の枠の文を、いま何段小さくしているか（0 なら元の大きさ）。
var _info_shrink := 0
## 入りきらずに省いた文の数。
var _info_dropped := 0
var _info_detail: Button
var _cell_label: Label
var _hint_label: Label
## 下の帯の案内の、折り返す前の文。
var _hint_text := ""
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
var _tactic_box: HBoxContainer
## 作戦の説明の枠（手札のボタンの上）。札ごとの説明、確かめている札（無ければ -1）、検査で乗せたことにした札。
var _tactic_note_panel: PanelContainer
var _tactic_note: Label
var _tactic_notes: Array[String] = []
var _tactic_pinned := -1
var _tactic_hover_forced := -1
## 作戦が使われたときに、しばらく出す文（どちらの陣営でも）と、消す時刻（ミリ秒）。
var _tactic_flash := ""
var _tactic_flash_until := 0
var _tactic_buttons: Array[Button] = []
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


func setup(team_colors: Array[Color]) -> void:
	_team_colors = team_colors
	add_child(UiTheme.vignette(BOARD_VIGNETTE))  # 盤の四隅を、ごく薄く沈める（帯や枠の下）
	_build_top_bar()
	_build_info_panel()
	_build_bottom()
	_build_flash()
	_build_banner()
	_build_notice()
	_build_menu()
	_build_forecast()
	_build_minimap()
	_result = ResultScreen.new()
	_result.team_colors = team_colors
	add_child(_result)
	_result.restart_pressed.connect(restart_pressed.emit)
	_result.setup_pressed.connect(setup_pressed.emit)
	_result.title_pressed.connect(title_pressed.emit)
	_build_evolution()


## turn_text はターンの文（「ターン 3」。win_text.gd）。
## counts は陣営ごとの駒の数、captures は本陣の占拠の数（どちらも添字がプレイヤー番号）。
## capture_shown は陣営ごとの、占拠の数を出すか（本陣の占拠が勝ちの条件に無い陣営は出さない）。
## goal_tag は勝ち方の札（[ひとことの文, 目立たせるか]。文が空なら札を出さない）、goal_note は札にマウスを乗せると出る詳しい文。
func set_status(
	turn_text: String, phase: Unit.Side, counts: Array[int], captures: Array[int], capture_goal: int,
	capture_shown: Array[bool] = [true, true], goal_tag: Array = ["", false], goal_note := "",
) -> void:
	_turn_label.text = turn_text
	_goal_panel.visible = goal_tag[0] != ""
	_goal_label.text = goal_tag[0]
	_goal_panel.reset_size()  # 文が短くなったら、札も縮める
	_goal_panel.tooltip_text = goal_note
	var urgent: bool = goal_tag[1]
	_goal_style.bg_color = COLOR_GOAL_URGENT if urgent else COLOR_GOAL
	_goal_style.border_color = COLOR_PULSE if urgent else COLOR_GOAL_BORDER
	_goal_label.add_theme_color_override("font_color", Color.WHITE if urgent else COLOR_FORECAST)
	_phase_label.text = Text.t("battle.hud.phase", {"side": Names.side(phase)})
	# 番の陣営の色: 文字の後ろの札と、上の帯の下の縁。
	var phase_color := _side_color(phase)
	_phase_label.add_theme_color_override("font_color", phase_color.lightened(0.62))
	_phase_chip_style.bg_color = Palette.INK.lerp(phase_color, PHASE_CHIP_TINT)
	_phase_chip_style.border_color = phase_color.lightened(0.2)
	_top_style.border_color = Palette.BORDER.lerp(phase_color.lightened(0.2), 0.8)
	for player in 2:
		var text := Text.t("battle.hud.side", {"side": Names.side_word(player), "count": counts[player]})
		if capture_shown[player]:
			var marks := Text.t("battle.hud.capture_on").repeat(captures[player]) + Text.t("battle.hud.capture_off").repeat(capture_goal - captures[player])
			text += Text.t("battle.hud.capture", {"marks": marks})
		_side_labels[player].text = text
		# 幅が足りずに省かれても読めるよう、全文をツールチップにも置く。聖遺物の効果も、ここで読める。
		_side_labels[player].tooltip_text = _side_labels[player].text
		if _relic_notes[player] != "":
			_side_labels[player].tooltip_text += "
" + _relic_notes[player]


## 上の帯の陣営の欄のうち、幅が足りずに「…」で省かれる文。検査用。
## 並べ直しを待たずに測れるよう、帯の幅から、ほかの部品の幅と間を引いた残りを、2 つの欄で分けた幅と比べる。
func top_bar_cut_texts() -> Array[String]:
	var row := _side_labels[0].get_parent() as HBoxContainer
	var panel := row.get_parent() as Control
	var room := panel.get_viewport_rect().size.x - panel.get_theme_stylebox(&"panel").get_minimum_size().x
	var shown := row.get_children().filter(func(child: Node) -> bool: return (child as Control).visible)
	room -= row.get_theme_constant(&"separation") * (shown.size() - 1)
	for child: Control in shown:
		if not (child is Label and _side_labels.has(child as Label)):
			room -= child.get_combined_minimum_size().x
	var cut: Array[String] = []
	for label in _side_labels:
		var font := label.get_theme_font(&"font")
		if font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size(&"font_size")).x > room / _side_labels.size():
			cut.append(label.text)
	return cut


## 陣営ごとの、持っている聖遺物の名前（上の帯。添字がプレイヤー番号。持っていなければ空）。次の set_status で出る。
## notes は、聖遺物の効果の説明（陣営の欄にマウスを乗せると出る。無ければ空）。
## held は陣営ごとの持っている聖遺物（Relics.Id の列）。アイコンを点ける。
func set_relics(texts: Array[String], notes: Array[String] = ["", ""], held: Array = [[], []]) -> void:
	_relic_texts = texts
	_relic_notes = notes
	for player in _relic_icons.size():
		for icon: RelicIcon in _relic_icons[player]:
			icon.set_lit((held[player] as Array).has(icon.relic))


## 上の帯に出ている、陣営の聖遺物の文字（持っていなければ空）。検査用。
func relic_text(player: int) -> String:
	for icon: RelicIcon in _relic_icons[player]:
		if icon.lit:
			return _relic_texts[player]
	return ""


## 必殺技のゲージ（上の帯。添字がプレイヤー番号）。percents は 0〜100。names は必殺技の名前（持たなければ空で、ゲージを出さない）。
func set_ult_gauges(percents: Array[int], names: Array[String]) -> void:
	for player in 2:
		_ult_bars[player].visible = names[player] != ""
		_ult_labels[player].visible = names[player] != ""
		_ult_bars[player].value = percents[player]
		_ult_labels[player].text = "READY" if percents[player] >= 100 else "%d%%" % percents[player]
		_ult_bars[player].tooltip_text = names[player]


## 上の帯の勝ち方の札の文字（出ていなければ空）。検査用。
func goal_tag_text() -> String:
	return _goal_label.text if _goal_panel.visible else ""


## いちばん上の帯に出ている、必殺技のゲージの文字（"62%" か "READY"。出ていなければ空）。検査用。
func ult_gauge_text(player: int) -> String:
	return _ult_labels[player].text if _ult_labels[player].visible else ""


## 必殺技のボタン（下の帯）。text はボタンの文字、enabled は押せるか。summary は必殺技の説明（必殺技が無ければ空）。
## 説明は、ボタンにマウスを乗せている間と、pinned が真の間（使うかを確かめている間）だけ、ボタンの上に出す。
## percent はゲージの溜まり具合（0〜100。負なら出さない）、side はその陣営。押せない間、ボタンの中に陣営の色で溜まり具合を出す。
func set_ult_button(text: String, enabled: bool, summary: String, pinned := false, percent := -1, side := Unit.Side.PLAYER1) -> void:
	_ult_button.text = text
	_ult_button.disabled = not enabled
	_ult_fill_ratio = clampf(percent / 100.0, 0.0, 1.0) if percent >= 0 and not enabled else -1.0
	_ult_fill_color = _side_color(side)
	_ult_fill.queue_redraw()
	_set_folded(_ult_summary, summary, ULT_SUMMARY_WIDTH)
	_ult_pinned = pinned
	_show_ult_summary()
	_fold_hint()


## 拠点の札を出す（試しの決まり「拠点」）。holds は陣営ごとの確保の数（添字がプレイヤー番号）、needed は勝つ数（0 以下なら札を出さない）。
## near は、あと 1 回の確保で勝つ陣営（いなければ -1。札を急ぎの色にする）。note は札にマウスを乗せると出る決まりの文。
## 大きさは中身で変えない。勝ち方の札が出ていれば、その下に並べる。
func set_stronghold(holds: Array[int], needed: int, near: int, note: String) -> void:
	_stronghold_panel.visible = needed > 0
	if needed <= 0:
		return
	_stronghold_caption.text = Text.t("battle.hud.stronghold")
	for player in 2:
		var held := mini(holds[player], needed)
		_stronghold_marks[player].text = Text.t("battle.hud.stronghold_marks", {"side": Names.side_word(player),
			"marks": Text.t("battle.hud.capture_on").repeat(held) + Text.t("battle.hud.capture_off").repeat(needed - held)})
		_stronghold_marks[player].add_theme_color_override("font_color", _side_color(player).lightened(0.45 if held > 0 else 0.3))
	var urgent := near >= 0
	_stronghold_style.bg_color = COLOR_GOAL_URGENT if urgent else COLOR_GOAL
	_stronghold_style.border_color = COLOR_PULSE if urgent else COLOR_GOAL_BORDER
	_stronghold_caption.add_theme_color_override("font_color", Color.WHITE if urgent else COLOR_FORECAST)
	_stronghold_panel.tooltip_text = note
	_stronghold_panel.offset_top = TOP_BAR_HEIGHT + 4.0
	if _goal_panel.visible:
		_stronghold_panel.offset_top += _goal_panel.get_combined_minimum_size().y + 4.0
	_stronghold_panel.size = STRONGHOLD_CHIP_SIZE


## 拠点の札の文（見出しと、陣営ごとの印。出ていなければ空。検査用）。
func stronghold_text() -> String:
	if not _stronghold_panel.visible:
		return ""
	return " ".join([_stronghold_caption.text, _stronghold_marks[0].text, _stronghold_marks[1].text])


## 拠点の札の大きさ（検査用）。
func stronghold_chip_size() -> Vector2:
	return _stronghold_panel.size


## 拠点の札が、あと 1 回で勝つ急ぎの色か（検査用）。
func stronghold_urgent() -> bool:
	return _stronghold_panel.visible and _stronghold_style.border_color == COLOR_PULSE


## 作戦のボタンを並べる。items は手札の順に [文字, 押せるか, 説明, 確かめている途中か]。空なら出さない。
## ボタンの幅は文字で変えない（TACTIC_BUTTON_WIDTH）。説明は、ボタンの上の決まった大きさの枠（TACTIC_NOTE_SIZE）に、
## マウスを乗せている間と、使うかを確かめている間だけ出す。出している間は、必殺技の説明の枠を、そのぶん上へずらす（重ねない）。
func set_tactic_buttons(items: Array) -> void:
	while _tactic_buttons.size() < items.size():
		var index := _tactic_buttons.size()
		var button := _button("", Signal())
		button.custom_minimum_size = Vector2(TACTIC_BUTTON_WIDTH, TACTIC_BUTTON_HEIGHT)
		button.clip_text = true
		button.add_theme_font_size_override("font_size", 16)
		Steady.mark(button, "battle.tactic_button")
		button.pressed.connect(func() -> void: tactic_pressed.emit(index))
		button.mouse_entered.connect(_show_tactic_note)
		button.mouse_exited.connect(_show_tactic_note)
		_tactic_box.add_child(button)
		_tactic_buttons.append(button)
	_tactic_notes.clear()
	_tactic_pinned = -1
	for i in _tactic_buttons.size():
		var button := _tactic_buttons[i]
		button.visible = i < items.size()
		_tactic_notes.append(items[i][2] if button.visible else "")
		if button.visible:
			button.text = items[i][0]
			button.disabled = not items[i][1]
			if items[i].size() > 3 and items[i][3]:
				_tactic_pinned = i
	_tactic_box.visible = not items.is_empty()
	var lift := TACTIC_BUTTON_HEIGHT + 8.0 if _tactic_box.visible else 0.0
	_ult_panel.offset_top = -BOTTOM_BAR_HEIGHT - 8.0 - lift
	_ult_panel.offset_bottom = -BOTTOM_BAR_HEIGHT - 8.0 - lift
	_show_tactic_note()


## 作戦の説明の枠を出すか決める: 確かめている札があればその札、無ければマウスの乗っている札の説明。どちらも無ければ消す。
## 出している間は、必殺技の説明（同じ場所）を出さない。
func _show_tactic_note() -> void:
	var shown := _tactic_pinned
	if shown < 0:
		for i in _tactic_buttons.size():
			if _tactic_buttons[i].visible and (_tactic_buttons[i].is_hovered() or i == _tactic_hover_forced):
				shown = i
	var text := _tactic_notes[shown] if _tactic_box.visible and shown >= 0 and shown < _tactic_notes.size() else ""
	if text == "" and Time.get_ticks_msec() < _tactic_flash_until:
		text = _tactic_flash
	_tactic_note_panel.visible = text != ""
	if _tactic_note_panel.visible:
		_tactic_note.text = text
		_ult_panel.visible = false
	else:
		_show_ult_summary()


## 作戦が使われたことを、手札のボタンの上の枠に TACTIC_FLASH_SECONDS 秒だけ出す（札にマウスを乗せている間は、そちらが先）。
func flash_tactic_note(text: String) -> void:
	_tactic_flash = text
	_tactic_flash_until = Time.get_ticks_msec() + int(TACTIC_FLASH_SECONDS * 1000.0)
	_show_tactic_note()
	# 消す時刻は実時間で数える（早送りで Engine.time_scale が変わっても、時刻とずれない）。
	get_tree().create_timer(TACTIC_FLASH_SECONDS + 0.05, true, false, true).timeout.connect(_show_tactic_note)


## 作戦の説明の枠の文（出ていなければ空。検査用）。
func tactic_note_text() -> String:
	return _tactic_note.text if _tactic_note_panel.visible else ""


## 作戦の説明の枠と、手札のボタンの大きさ（検査用）。
func tactic_sizes() -> Array[Vector2]:
	var sizes: Array[Vector2] = [_tactic_note_panel.size]
	for button in _tactic_buttons:
		sizes.append(button.size)
	return sizes


## 作戦のボタンにマウスを乗せたことにする（スクリーンショット・検査用。-1 で外す）。
func hover_tactic(index: int) -> void:
	_tactic_hover_forced = index
	_show_tactic_note()


## 作戦のボタンの [文字, 押せるか] の列（出しているものだけ）。検査用。
func tactic_buttons() -> Array:
	var shown: Array = []
	if _tactic_box.visible:
		for button in _tactic_buttons:
			if button.visible:
				shown.append([button.text, not button.disabled])
	return shown


## 必殺技のボタンの中のゲージ（押せない間だけ）: 左から溜まり具合まで陣営の色を薄く敷き、下の辺に溝と陣営の色の棒。
## 溜まった先の端に、明るい細い線。
func _draw_ult_fill() -> void:
	if _ult_fill_ratio < 0.0:
		return
	var inset := 3.0
	var area := Rect2(Vector2(inset, inset), _ult_fill.size - Vector2(inset, inset) * 2.0)
	var filled := area.size.x * _ult_fill_ratio
	if filled > 0.0:
		_ult_fill.draw_rect(Rect2(area.position, Vector2(filled, area.size.y)), Color(_ult_fill_color, 0.26))
	var groove := Rect2(area.position.x, area.end.y - ULT_FILL_BAR, area.size.x, ULT_FILL_BAR)
	_ult_fill.draw_rect(groove, Color(Palette.INK, 0.9))
	if filled > 0.0:
		_ult_fill.draw_rect(Rect2(groove.position, Vector2(filled, ULT_FILL_BAR)), _ult_fill_color.lightened(0.25))
		_ult_fill.draw_rect(Rect2(area.position.x + filled - 1.0, area.position.y, 1.0, area.size.y), Color(_ult_fill_color.lightened(0.5), 0.6))


## 必殺技のボタンの中のゲージの溜まり具合（0〜1。出していなければ負）。検査用。
func ult_fill_ratio() -> float:
	return _ult_fill_ratio


func _show_ult_summary() -> void:
	_ult_panel.visible = _ult_summary.text != "" and (_ult_pinned or _ult_button.is_hovered()) and not _tactic_note_panel.visible


func ult_button_text() -> String:
	return _ult_button.text


func is_ult_enabled() -> bool:
	return not _ult_button.disabled


## 駒の情報を出す。unit が null なら消す。state は行動の状態と、いるマスのこと。note は、そのときに読むべき説明
## （メニューの項目の説明、スキルの対象を選んでいるときの見込み。無ければ空）。
## skill_note が真なら、スキルの説明も出す（note のほうにスキルの説明を出すときは、偽にして重ねない）。
##
## 並び（上から、大事な順）: 名前と役割 → 所属（[自軍] [敵軍] [中立]、陣営、軍） → HP の棒と数 → 能力値とレベル →
## 状態（残りの期間と効果） → 装備 → スキル（名前と使えるか、説明） → 特性（進化先と持ち物） → 行動の状態といるマス → note。
func show_unit(unit: Unit, state: String, note: String, skill_note := true) -> void:
	_info_panel.visible = unit != null
	_info_pin.visible = false  # 出すときは、このあとに set_pin_switch
	_info_detail.visible = false  # 出すときは、このあとに set_detail_button
	if unit == null:
		return
	var role: String = Names.role(UnitKind.role(unit.kind))
	var kind := Names.kind(unit.kind)
	if unit.evolution != Evolution.Id.NONE:
		# 進化した駒は、進化先の名前と、元の種類。
		var key := "battle.hud.name_evolved_role" if role else "battle.hud.name_evolved"
		_info_name.text = Text.t(key, {"unit": Names.unit(unit), "kind": kind, "role": role})
	else:
		_info_name.text = Text.t("battle.hud.name_role", {"unit": Names.unit(unit), "role": role}) if role else Names.unit(unit)
	_info_name.add_theme_color_override("font_color", _side_color(unit.side).lightened(0.35))
	_edge_info_panel(_side_color(unit.side).lightened(0.15))
	_set_folded(_info_name, _info_name.text, INFO_WIDTH - INFO_ICON_SIZE - 6.0)
	_info_icon.set_kind(unit.kind, unit.side, unit.evolution != Evolution.Id.NONE,
			king_looks[unit.side] if unit.side < king_looks.size() else &"")
	_info_icon.edge = Color(_side_color(unit.side).lightened(0.15), 0.9)
	_info_icon.visible = true
	var army: UnitKind.Army = side_armies[unit.side] if unit.side >= 0 and unit.side < side_armies.size() else UnitKind.Army.NONE
	_info_side.text = affiliation_text(unit, viewer_side, army)
	_info_side.add_theme_color_override("font_color", _side_color(unit.side).lightened(0.5))
	_info_side.visible = true
	var ratio := float(unit.hp) / maxf(unit.max_hp(), 1.0)
	_info_unit_box.visible = true
	_info_rule.visible = true
	_info_hp.value = ratio * 100.0
	_info_hp_fill.bg_color = hp_color(ratio)
	var key := "battle.hud.stats_healer" if UnitKind.role(unit.kind) == UnitKind.Role.HEALER else "battle.hud.stats"
	var stats := Text.t(key, {
		"hp": unit.hp, "max_hp": unit.max_hp(), "power": unit.power(), "move": unit.move_range(), "range": unit.attack_range(),
	})
	if Growth.can_grow(unit):
		if unit.level >= Growth.MAX_LEVEL:
			stats += "\n" + Text.t("battle.hud.level_max", {"level": unit.level})
		else:
			stats += "\n" + Text.t("battle.hud.level", {"level": unit.level, "experience": unit.experience, "needed": Growth.EXPERIENCE_PER_LEVEL})
	# 文は 1 つのまま持ち（info_text）、見せるときは行に分ける: HP の数（棒の下、太字）とレベル（その右）、能力値は幅のそろった欄。
	_set_folded(_info_stats, stats, INFO_WIDTH)
	_info_stats.visible = false
	var stat_lines := stats.split("\n")
	_info_hp_label.text = stat_lines[0]
	_info_stats_row.set_line(stat_lines[1] if stat_lines.size() > 1 else "")
	_info_level.text = stat_lines[2] if stat_lines.size() > 2 else ""

	var statuses: Array[String] = []
	for type in Statuses.types_of(unit):
		statuses.append(status_text(type, unit.statuses[type]))
	_set_shown(_info_statuses, "\n".join(statuses))

	var items := ""
	if Equipment.can_equip(unit.kind):
		items = Text.t("battle.hud.equipment", {"items": equipment_text(unit.equipment)})
	_set_shown(_info_items, items)

	var skill := Skills.of(unit)
	var skill_text := ""
	if skill != null:
		skill_text = Text.t("battle.hud.skill", {"skill": Names.skill(skill), "state": skill_state_text(unit, battle)})
	_set_shown(_info_skill, skill_text)
	# スキルの中身は、読んで知るもの。選んだ駒・マウスを乗せた駒のスキルの説明を、いつも出す。
	_set_shown(_info_skill_note, Names.skill_summary(skill) if skill != null and skill_note else "")

	var traits: Array[String] = []
	for which: Evolution.Trait in Evolution.Trait.values():  # 進化先と持ち物の、どちらが与えた特性も（重ねても 1 つ）
		if unit.has_trait(which):
			traits.append(Text.t("battle.hud.trait", {"trait": Names.trait_text(which)}))
	_set_shown(_info_traits, "\n".join(traits))
	_set_shown(_info_state, state)
	_set_shown(_info_forecast, note)
	_fit_info()


## 駒の所属の文。盤を見ている人（viewer）から見た [自軍] [敵軍] [中立] と、陣営、軍（雇う駒だけ。魔物は「魔物」）。
## 軍は陣営の軍（side_army。NONE なら駒の種類の軍）。ストーリーでほかの軍の駒を雇ったときは「MILITARY（FANTASY の駒）」と並べる
## （駒の種類の軍だけを出すと、味方の駒に敵と同じ軍の名前が出て紛らわしい）。
static func affiliation_text(unit: Unit, viewer: Unit.Side, side_army := UnitKind.Army.NONE) -> String:
	var tag := Text.t("battle.hud.tag.neutral")
	if unit.side == viewer:
		tag = Text.t("battle.hud.tag.own")
	elif unit.side != Unit.Side.NEUTRAL:
		tag = Text.t("battle.hud.tag.foe")
	var parts: Array[String] = [tag, Names.side(unit.side)]
	var army := UnitKind.army(unit.kind)
	if UnitKind.is_monster(unit.kind):
		parts.append(Text.t("battle.hud.monster"))  # 魔物は軍を持たない（陣営の軍の名前は出さない）
	elif army != UnitKind.Army.NONE:
		if side_army == UnitKind.Army.NONE or side_army == army:
			parts.append(Names.army(army))
		else:
			parts.append(Text.t("battle.hud.borrowed_army", {"army": Names.army(side_army), "origin": Names.army(army)}))
	return Text.t("battle.hud.separator").join(parts)


## 装備の一覧（同じものは数をまとめる。「スピードブーツ ×2・アイアンシールド」）。無ければ「なし」。
static func equipment_text(items: Array[Equipment.Id]) -> String:
	var counts := {}
	var order: Array[Equipment.Id] = []
	for item in items:
		if not counts.has(item):
			order.append(item)
		counts[item] = counts.get(item, 0) + 1
	var parts: Array[String] = []
	for item in order:
		parts.append(Text.t("battle.hud.item_count", {"item": Names.item(item), "count": counts[item]}) if counts[item] > 1 else Names.item(item))
	return Text.join_dot(parts) if not parts.is_empty() else Text.t("battle.hud.no_items")


## 付いている状態の文（名前、残りのターン数、効果）。
static func status_text(type: Status.Type, turns: int) -> String:
	return Text.t("battle.hud.status", {"status": Names.status(type), "turns": turns, "effect": Names.status_summary(type)})


## クリックしたマスの情報を、駒の情報と同じ枠に出す。title は見出し（マスの位置と地形）、body は説明（行ごと）。
func show_cell_info(title: String, body: String) -> void:
	_info_panel.visible = true
	_info_pin.visible = false
	_info_detail.visible = false
	_info_name.text = title
	_info_name.add_theme_color_override("font_color", Palette.TEXT)
	_edge_info_panel(Palette.BORDER)
	_info_icon.visible = false
	_info_side.visible = false
	_info_unit_box.visible = false
	_info_rule.visible = false
	_info_stats.visible = true
	_set_folded(_info_stats, body, INFO_WIDTH)
	for label: Label in [_info_statuses, _info_items, _info_skill, _info_skill_note, _info_traits, _info_state, _info_forecast]:
		label.visible = false
	_fit_info()


## 駒の情報の枠の「範囲を表示したまま」のスイッチ。shown で出すか、pinned で入っているか（show_unit のあとに呼ぶ）。
func set_pin_switch(shown: bool, pinned: bool) -> void:
	_info_pin.visible = shown and _info_panel.visible
	_info_pin.set_pressed_no_signal(pinned)
	_fit_info()


## 駒の情報の枠の「詳細」のボタンを出すか（show_unit のあとに呼ぶ。枠が出ていなければ出さない）。
func set_detail_button(shown: bool) -> void:
	_info_detail.visible = shown and _info_panel.visible and _info_unit_box.visible
	_fit_info()


## 「詳細」のボタンを出しているか。検査用。
func detail_button_shown() -> bool:
	return _info_detail.visible


## 「詳細」のボタンを押す（クリックと同じ道）。出ていれば真。検査用。
func press_detail() -> bool:
	if not _info_detail.visible:
		return false
	_info_detail.pressed.emit()
	return true


## 「範囲を表示したまま」のスイッチを出しているか、入っているか。検査用。
func pin_switch_state() -> Array[bool]:
	return [_info_pin.visible, _info_pin.button_pressed]


## 「範囲を表示したまま」のスイッチを押す（クリックと同じ道）。出ていれば真。検査用。
func press_pin_switch() -> bool:
	if not _info_pin.visible:
		return false
	_info_pin.button_pressed = not _info_pin.button_pressed
	_info_pin.pressed.emit()
	return true


## label に、折り返した text を出す。空なら隠す。
func _set_shown(label: Label, text: String) -> void:
	label.visible = text != ""
	if label.visible:
		_set_folded(label, text, INFO_WIDTH)


## 情報の枠の文を、枠の残りの高さに収める（枠は伸ばさない）。中身かボタンの出し入れが変わるたびに呼ぶ。
## 入りきらなければ、字を 1 段（1 px）ずつ小さくして折り返し直す（下限は INFO_FONT_FLOOR）。
## それでも入らなければ、後で読めるものから順に省く（スキルの説明 → 特性 → 持ち物 → 状態 → 行動の状態。「詳細」の窓で全部読める）。
## スキルの名前と、いま要る説明（メニューの項目の説明、スキルの見込み）は省かない。並べ直しを待たずに、いまの中身から求める。
func _fit_info() -> void:
	if not _info_panel.visible:
		return
	var labels: Array[Label] = []
	for child in _info_lines.get_children():
		labels.append(child as Label)
	_info_shrink = 0
	_info_dropped = 0
	while true:
		for label in labels:
			label.add_theme_font_size_override("font_size", _info_font_size(label))
			if label.visible:
				_fold_info(label)
		if _info_over() <= 0.0 or _info_shrink >= INFO_SHRINK_STEPS:
			break
		_info_shrink += 1
	for label: Label in [_info_skill_note, _info_traits, _info_items, _info_statuses, _info_state]:
		if _info_over() <= 0.0:
			break
		if label.visible:
			label.visible = false
			_info_dropped += 1


## 情報の枠の文が、枠の残りの高さからはみ出している高さ（px。収まっていれば 0 以下）。
func _info_over() -> float:
	var fixed := _info_room.get_parent() as VBoxContainer
	# 文の高さは、行の数と字の高さから求める（字の大きさを変えた直後は、Label の大きさがまだ前のまま）。
	var needed := 0.0
	var shown := 0
	for child in _info_lines.get_children():
		var label := child as Label
		if not label.visible:
			continue
		var lines := label.text.count("\n") + 1
		needed += lines * label.get_theme_font("font").get_height(_info_font_size(label)) + (lines - 1) * label.get_theme_constant("line_spacing")
		shown += 1
	needed += maxi(shown - 1, 0) * _info_lines.get_theme_constant("separation")
	return needed - (INFO_HEIGHT - _info_style.get_minimum_size().y - fixed.get_combined_minimum_size().y)


## 情報の枠の文 label を、いまの字の大きさで折り返し直す。
func _fold_info(label: Label) -> void:
	var font := label.get_theme_font("font")
	var size := _info_font_size(label)
	label.text = TextWrap.fold(label.get_meta(&"plain"), INFO_WIDTH, func(character: String) -> float: return _char_width(font, size, character))


## 情報の枠の文 label の、いまの字の大きさ（小さくした段を引いたもの）。
func _info_font_size(label: Label) -> int:
	return maxi(int(label.get_meta(&"font_size")) - _info_shrink, INFO_FONT_FLOOR)


## 情報の枠の文を、何段小さくしているか（0 なら元の大きさ）、いくつ省いたか、それでも下が切れているか。検査用。
func info_shrink() -> int:
	return _info_shrink


func info_dropped() -> int:
	return _info_dropped


func is_info_cut() -> bool:
	return _info_panel.visible and _info_over() > 0.5


## 駒の情報の枠に出している文（見出しを除く。出ていなければ空）。検査用。
func info_text() -> String:
	if not _info_panel.visible:
		return ""
	var parts: Array[String] = []
	for label: Label in [_info_side, _info_stats, _info_statuses, _info_items, _info_skill, _info_skill_note, _info_traits, _info_state, _info_forecast]:
		# 駒の能力値は、欄に分けて出している間も、文としてはここにある。
		if label.visible or (label == _info_stats and _info_unit_box.visible):
			parts.append(label.text)
	return "\n".join(parts)


## 駒の情報の枠に出している見出し（出ていなければ空）。検査用。
func info_title() -> String:
	return _info_name.text if _info_panel.visible else ""


## HP の割合（0〜1）の色。半分より多ければ緑、4 分の 1 より多ければ黄、それより少なければ赤。
static func hp_color(ratio: float) -> Color:
	return Palette.hp(ratio)


## マウスの下のマスの説明。盤の外なら空を渡す。
func show_cell(text: String) -> void:
	_cell_text = text
	_fold_cell()


## マスの説明を、案内と同じ幅で折り返す。行の数は、案内が 1 行なら 2 行まで、案内が 2 行なら 1 行（帯の高さは変えない）。
## 入らなければ字を小さくし、それでも入らなければ、最後の行を「…」で切る。
func _fold_cell() -> void:
	if _cell_label == null:
		return
	var font := _cell_label.get_theme_font("font")
	var room := _hint_room()
	var lines := 1 if _hint_label.text.contains("\n") else 2
	var folded := ""
	for size: int in [CELL_FONT_SIZE, CELL_FONT_SIZE_SMALL]:
		folded = TextWrap.fold(_cell_text, room, func(character: String) -> float: return _char_width(font, size, character))
		_cell_label.add_theme_font_size_override("font_size", size)
		if folded.count("\n") < lines:
			break
	_cell_label.max_lines_visible = lines
	_cell_label.text = folded


## マスの説明のうち、帯に収まらずに切れる行（3 行目から）。検査用。
func cell_cut_lines() -> Array[String]:
	var cut: Array[String] = []
	cut.assign(Array(_cell_label.text.split("\n")).slice(_cell_label.max_lines_visible))
	return cut


## 下の帯に出しているマスの説明（折り返したあと）。検査用。
func cell_line_text() -> String:
	return _cell_label.text


func set_hint(text: String) -> void:
	_hint_text = text
	_fold_hint()


## 案内を、いま使える幅で折り返し直す。右のボタンの文字や出し入れが変わると、使える幅も変わるので、そのたびに呼ぶ。
func _fold_hint() -> void:
	if _hint_label != null:
		# 2 行に分かれるときは、行の長さをそろえる（2 行目に 1 語だけ残さない）。
		var font := _hint_label.get_theme_font("font")
		var font_size := _hint_label.get_theme_font_size("font_size")
		_hint_label.text = TextWrap.fold_even(_hint_text, _hint_room(), func(character: String) -> float: return _char_width(font, font_size, character))
		_fold_cell()  # 案内の行の数で、マスの説明の字の大きさが変わる


## 下の帯の案内のうち、案内に使える幅に収まらない行（3 行目からは、収まっていても切れる）。検査用。
func hint_cut_lines() -> Array[String]:
	var font := _hint_label.get_theme_font(&"font")
	var font_size := _hint_label.get_theme_font_size(&"font_size")
	var room := _hint_room()
	var cut: Array[String] = []
	var lines := _hint_label.text.split("\n")
	for i in lines.size():
		if i >= _hint_label.max_lines_visible or font.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > room + 0.5:
			cut.append(lines[i])
	return cut


## 下の帯で、案内に使える幅: 帯の幅から、右のボタンとスイッチ（出ているもの）の幅と間を引いた残り。
## 並べ直しを待たずに求める（ボタンの文字が変わった直後にも正しい）。
func _hint_room() -> float:
	var column := _hint_label.get_parent() as Control
	var row := column.get_parent() as HBoxContainer
	var panel := row.get_parent() as Control
	var room := panel.get_viewport_rect().size.x - panel.get_theme_stylebox(&"panel").get_minimum_size().x
	var shown := row.get_children().filter(func(child: Node) -> bool: return (child as Control).visible)
	room -= row.get_theme_constant(&"separation") * (shown.size() - 1)
	for child: Control in shown:
		if child != column:
			room -= child.get_combined_minimum_size().x
	return room


## ターン終了のボタン。ready が真なら、明るくして目立たせる（動かせる駒が残っていないとき）。
func set_end_turn(enabled: bool, text: String, ready := false) -> void:
	_end_turn_button.disabled = not enabled
	_end_turn_button.text = text
	_end_turn_style.bg_color = COLOR_END_TURN_READY if ready else COLOR_END_TURN
	_fold_hint()


## 相手の番の「早送り」「スキップ」を出すか（出している間は、必殺技のボタンを隠す）。fast は早送りが入っているか、
## can_skip はスキップを押せるか（スキップの途中は「スキップ中…」にして押せない）。
func set_watch_controls(shown: bool, fast: bool, can_skip: bool) -> void:
	_watch_box.visible = shown
	_ult_button.visible = not shown
	_auto_button.visible = not shown
	_fast_button.set_pressed_no_signal(fast)
	_skip_button.disabled = not can_skip
	_skip_button.text = Text.t("battle.hud.skip") if can_skip else Text.t("battle.hud.skipping")
	_fold_hint()


## 自分の番の「おまかせ」。confirming なら、もう一度押すと任せる、の形にする。
func set_auto_button(enabled: bool, confirming: bool) -> void:
	_auto_button.disabled = not enabled
	_auto_button.text = Text.t("battle.hud.auto_confirm") if confirming else Text.t("battle.hud.auto")
	_fold_hint()


## 「おまかせ」の文字と、押せるか。検査用。
func auto_button_state() -> Array:
	return [_auto_button.text, not _auto_button.disabled]


## 相手の番の「早送り」「スキップ」: [出ているか, 早送りが入っているか]。検査用。
func watch_controls_state() -> Array[bool]:
	return [_watch_box.visible, _fast_button.button_pressed]


## 相手の番の「スキップ」を押す（クリックと同じ道）。出ていて押せれば真。検査用。
func press_skip() -> bool:
	if not _watch_box.visible or _skip_button.disabled:
		return false
	_skip_button.pressed.emit()
	return true


## 敵の全員の脅威範囲の切り替えを、出しているかに合わせる。
func set_threat_button(shown: bool) -> void:
	_threat_button.set_pressed_no_signal(shown)
	_fold_hint()


func end_turn_text() -> String:
	return _end_turn_button.text


## 相手を切り替えるボタンの文字（いまの相手を書く）。空なら、ボタンを出さない（切り替えられない対戦）。
func set_opponent(text: String) -> void:
	_opponent_button.text = text
	_opponent_button.visible = text != ""
	_fold_hint()


## 相手を切り替えるボタンを出しているか。検査用。
func opponent_shown() -> bool:
	return _opponent_button.visible


## 駒のそばのメニューに出す項目。items は [名前（StringName）, 文字, 押せるか] の列（上から）。空なら消す。
## 置き場所は place_menu() で決める（項目を変えたら、大きさが変わる）。
func set_menu(items: Array) -> void:
	_menu.visible = not items.is_empty()
	_menu_line.visible = false
	if items == _menu_items:
		return
	_menu_items = items.duplicate(true)
	for button: Button in _menu_buttons.values():
		_menu_column.remove_child(button)
		button.queue_free()
	_menu_buttons.clear()
	for item: Array in items:
		var id: StringName = item[0]
		var button := Button.new()
		button.text = item[1]
		button.disabled = not item[2]
		button.focus_mode = Control.FOCUS_NONE
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.theme_type_variation = UiTheme.BUTTON_ACTION
		# 幅は決めておき、項目の言葉で変えない。入らない言葉は字を小さくし、それでも入らなければ「…」（いまの項目では切れない。tests/game/test_steady_frames.gd）。
		button.custom_minimum_size = Vector2(MENU_ITEM_WIDTH, 34.0)
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.clip_text = true
		button.pressed.connect(func() -> void: menu_pressed.emit(id))
		button.mouse_entered.connect(func() -> void: menu_hovered.emit(id))
		button.mouse_exited.connect(func() -> void: menu_hovered.emit(&""))
		_menu_column.add_child(button)
		_menu_buttons[id] = button
		# 長い言葉（スキルの名前と残りの回数）は、字を小さくして幅に収める（下限は MENU_FONT_FLOOR）。
		var font := button.get_theme_font("font")
		var room := MENU_ITEM_WIDTH - button.get_theme_stylebox("normal").get_minimum_size().x
		for size in range(MENU_FONT_SIZE, MENU_FONT_FLOOR - 1, -1):
			button.add_theme_font_size_override("font_size", size)
			if font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= room:
				break
	_menu.reset_size()


## メニューの大きさ（出していなければ 0）。
func menu_size() -> Vector2:
	return _menu.get_combined_minimum_size() if _menu.visible else Vector2.ZERO


## メニューを置く（左上の、画面の座標）。from は、駒の画面の上の位置。メニューが駒から離れたら、駒まで細い線を引く
## （どの駒のメニューかが分かるように）。駒が下の帯の後ろにいるときは、線を帯の上の縁で止める（帯の文字の上に引かない）。
func place_menu(at: Vector2, from: Vector2) -> void:
	_menu.position = at.round()
	_menu.size = _menu.get_combined_minimum_size()
	var rect := Rect2(_menu.position, _menu.size)
	var near := Vector2(clampf(from.x, rect.position.x, rect.end.x), clampf(from.y, rect.position.y, rect.end.y))
	_menu_line.visible = _menu.visible and near.distance_to(from) > MENU_LINE_FROM
	_menu_line.points = PackedVector2Array([menu_line_start(from, near, _menu.get_viewport_rect().size.y - BOTTOM_BAR_HEIGHT), near])


## メニューと駒を結ぶ線の、駒の側の端。駒（from）が下の帯（上の縁が bar_top）の後ろにいれば、メニューの側の端（near）へ向かう
## 線が帯の上の縁と交わる所。帯の上にいれば from のまま。
static func menu_line_start(from: Vector2, near: Vector2, bar_top: float) -> Vector2:
	if from.y <= bar_top or near.y >= bar_top:
		return from
	return from.lerp(near, (from.y - bar_top) / (from.y - near.y))


## メニューが届くマスに掛かっているか（see_through）。掛かっている間は、マウスが乗っていなければ薄く描く（_process）。
func set_menu_see_through(see_through: bool) -> void:
	_menu_see_through = see_through


## メニューの濃さ（1 で、ふつう）。検査用。
func menu_alpha() -> float:
	return _menu.modulate.a


func _update_menu_alpha() -> void:
	var faded := _menu_see_through and _menu.visible and not menu_rect().grow(6.0).has_point(get_viewport().get_mouse_position())
	_menu.modulate.a = MENU_SEE_THROUGH_ALPHA if faded else 1.0


## 対戦の途中の会話の札（battle_talk.gd）を入れる。帯・駒のそばのメニュー・予測のパネル・進化の選択・決着の画面より下に描く
## （札はクリックを受けないので、上に描くと、隠れたボタンを押せてしまう。札は上の帯のすぐ下の真ん中にあり、帯とは重ならない）。
## 駒のそばのメニューか予測のパネルが札に重なったら、札を薄くする（下のメニューやパネルが読めるように）。
func add_talk_card(card: Control) -> void:
	add_child(card)
	move_child(card, 0)
	card.obstacles = func() -> Array[Rect2]: return [menu_rect(), forecast_rect(), evolution_rect()]


## 上の帯のすぐ下に出す、決まった枠（左の勝ち方の札、右の視点の案内）の四角（出ていなければ大きさ 0）。検査用。
func top_tag_rects() -> Array[Rect2]:
	return [
		_goal_panel.get_global_rect() if _goal_panel.visible else Rect2(),
		_guide_panel.get_global_rect() if _guide_panel.visible else Rect2(),
		_stronghold_panel.get_global_rect() if _stronghold_panel.visible else Rect2(),
	]


## メニューが画面に占める四角（出していなければ大きさ 0）。検査用。
func menu_rect() -> Rect2:
	return Rect2(_menu.position, _menu.get_combined_minimum_size()) if _menu.visible else Rect2()


## メニューを置いてよい範囲（画面から上の帯と下の帯を除いたところ）。
func menu_area() -> Rect2:
	var screen := _menu.get_viewport_rect().size
	return Rect2(4.0, TOP_BAR_HEIGHT + 4.0, screen.x - 8.0, screen.y - TOP_BAR_HEIGHT - BOTTOM_BAR_HEIGHT - 8.0)


## メニューが隠したくない、画面の決まった枠（駒とマスの情報）。出ていなければ大きさ 0。
func info_rect() -> Rect2:
	return _info_panel.get_global_rect() if _info_panel.visible else Rect2()


## メニューの項目を押す（クリックと同じ道を通る）。出ていて押せる項目なら真を返す。
func press_menu(id: StringName) -> bool:
	if not is_menu_enabled(id):
		return false
	(_menu_buttons[id] as Button).pressed.emit()
	return true


## メニューに id の項目が出ていて、押せるか。
func is_menu_enabled(id: StringName) -> bool:
	return _menu.visible and _menu_buttons.has(id) and not (_menu_buttons[id] as Button).disabled


## メニューに出ている id の項目の文字（出ていなければ空）。
func menu_text(id: StringName) -> String:
	return (_menu_buttons[id] as Button).text if _menu.visible and _menu_buttons.has(id) else ""


## メニューに出ている id の項目のボタン（無ければ null）。検査用。
func menu_button(id: StringName) -> Button:
	return _menu_buttons.get(id)


## メニューに出ている項目の名前（上から）。出ていなければ空。
func menu_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	if _menu.visible:
		for item: Array in _menu_items:
			ids.append(item[0])
	return ids


## 駒のスキルの状態（使えるか、あと何ターンか。回数に上限があれば、残りの回数）。
## in_battle があれば、クールダウンのほかの条件（動いたら使えない、巡航した、など。Skills.can_use）も見て、使えなければ「使用不可」
## （メニューの「スキル（使用不可）」とそろえる）。見るのは、その駒の陣営の番の間だけ（相手の番には、動いたかどうかは次の番に戻る）。
static func skill_state_text(unit: Unit, in_battle: Battle = null) -> String:
	var uses := Skills.uses_left(unit)
	if uses == 0:
		return Text.t("battle.hud.skill_state.used_up")
	var state := Text.t("battle.hud.skill_state.ready")
	if unit.skill_cooldown > 0:
		state = Text.t("battle.hud.skill_state.cooldown", {"turns": unit.skill_cooldown})
	elif in_battle != null and in_battle.phase == unit.side and not Skills.can_use(in_battle, unit):
		state = Text.t("battle.hud.skill_state.unusable")
	return state if uses < 0 else Text.t("battle.hud.skill_state.uses_left", {"state": state, "uses": uses})


## 画面の全体を、color で一瞬だけ光らせる（必殺技）。強すぎないよう、薄く出してすぐ消す。
func flash_screen(color: Color) -> void:
	if _flash_tween != null:
		_flash_tween.kill()
	_flash.color = Color(color.lightened(0.2), FLASH_ALPHA)
	_flash.visible = true
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash, "color:a", 0.0, FLASH_TIME).set_ease(Tween.EASE_IN)
	_flash_tween.tween_callback(_flash.hide)


func _build_flash() -> void:
	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.visible = false
	add_child(_flash)


## ゲージが READY のあいだ、上の帯のゲージと、押せる必殺技のボタンを、金色にゆっくり明滅させる。
## 時計は実時間で測る（CPU の番の速さや、メニューで時間が止まっているのに依らない）。
func _process(_delta: float) -> void:
	var phase := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * TAU / PULSE_PERIOD)
	var tint := Color.WHITE.lerp(COLOR_PULSE, phase)
	for player in _ult_labels.size():
		var shade := tint if _ult_labels[player].text == "READY" else Color.WHITE
		_ult_bars[player].self_modulate = shade
		_ult_labels[player].self_modulate = shade
	if _ult_button != null:
		_ult_button.self_modulate = tint if not _ult_button.disabled else Color.WHITE
	_update_menu_alpha()


## 画面の中央に、しばらくだけ大きな文字を、color の帯（banner_band.gd）で出す。strong は強い知らせ（必殺技）。
func show_banner(text: String, color: Color, strong := false) -> void:
	_banner.play(text, color, strong)


## 画面の中央の大きな文字（検査用）。
func banner_text() -> String:
	return _banner.label.text if _banner.visible else ""


## 画面の中央の大きな文字が出ているか（スクリーンショットの道具が、消えるのを待つ）。
func is_banner_shown() -> bool:
	return _banner.visible


## 知らせの帯が画面に占める四角（出ていなければ空）。浮かぶ文字が帯にかからないよう、再生が見る。
func banner_rect() -> Rect2:
	return _banner.get_global_rect() if _banner.visible else Rect2()


## 画面の中央の大きな文字を、すぐに消す（時間を止めて読む画面を開いたとき、止まったまま残らないように）。
func hide_banner() -> void:
	_banner.stop()


## リザルトの画面（result_screen.gd）を、summary（result_summary.gd）で段階的に出し始める。
func show_result(summary: RefCounted) -> void:
	_result.present(summary)
	result_shown.emit(summary.winner == Unit.Side.NEUTRAL, summary.winner)


## リザルトの画面（検査と、場面が入力の取り次ぎを渡すのに使う）。
func result_screen() -> ResultScreen:
	return _result


## いま出ている詳しい戦績（出ていなければ空）。検査用。
func result_stats() -> String:
	return _result.detail_text()


## いま出ている結果の見出し（出ていなければ空）。検査用。
func result_title() -> String:
	return _result.headline()


func hide_result() -> void:
	_result.hide_result()


## 進化先の説明（名前、能力値の増減、特性）。healer なら、攻撃の欄を「回復」と書く。
static func evolution_text(id: Evolution.Id, healer: bool) -> String:
	var parts: Array[String] = []
	var bonuses := Evolution.bonuses(id)
	for which: Unit.Stat in Names.STATS:
		if bonuses.has(which):
			var stat_name: String = Text.t("battle.log.stat_heal") if healer and which == Unit.Stat.POWER else Names.stat(which)
			parts.append(Text.t("battle.log.stat_gain", {"stat": stat_name, "amount": "%+d" % bonuses[which]}))
	var text := Names.evolution(id) + "\n" + Text.t("battle.hud.separator").join(parts)
	for which in Evolution.traits(id):
		text += "\n" + Text.t("battle.hud.trait", {"trait": Names.trait_text(which)})
	return text


## 進化先の選択肢を出す。texts は選択肢ごとの説明（evolution_text。1 行目が名前、2 行目が能力値の増減、残りが特性）。
## kind と side は進化する駒（札の額に、進化後の姿を陣営の色で出す）。
func show_evolution(title: String, texts: Array[String], kind := UnitKind.Id.KING, side := 0) -> void:
	_evolution_title.text = title
	var shown := "%s|%d|%d|%s" % [title, kind, side, "|".join(texts)]
	if _evolution.get_meta(&"shown", "") != shown:
		_evolution.set_meta(&"shown", shown)
		for i in _evolution_buttons.size():
			_evolution_buttons[i].visible = i < texts.size()
			if i < texts.size():
				_fill_evolution_card(_evolution_buttons[i], i, texts[i], kind, side)
	_evolution.visible = true


## 進化先の札の中身: 左に進化後の姿の額（縁は陣営の色）、右に名前（明朝）・能力値の増減（欄）・特性（金）。左上の隅に、選ぶキーの番号。
func _fill_evolution_card(button: Button, index: int, text: String, kind: UnitKind.Id, side: int) -> void:
	for child in button.get_children():
		button.remove_child(child)
		child.queue_free()
	var lines := text.split("\n")
	var inside := MarginContainer.new()
	inside.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inside.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for edge: String in ["left", "right"]:
		inside.add_theme_constant_override("margin_" + edge, 16)
	for edge: String in ["top", "bottom"]:
		inside.add_theme_constant_override("margin_" + edge, 10)
	button.add_child(inside)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inside.add_child(row)
	var frame := UnitFrame.new(kind, side, EVOLUTION_FRAME, true, true, king_looks[side] if side < king_looks.size() else &"")
	frame.edge = _side_color(side)
	row.add_child(frame)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(column)
	var name_label := _label(21)
	name_label.add_theme_font_override("font", UiTheme.FONT_HEADING)
	name_label.text = lines[0]
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(name_label)
	if lines.size() > 1 and lines[1] != "":
		column.add_child(StatsRow.new(lines[1], 16))
	for i in range(2, lines.size()):
		var trait_label := _label(15)
		trait_label.add_theme_color_override("font_color", Palette.ACCENT)
		trait_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_folded(trait_label, lines[i], EVOLUTION_CARD.x - EVOLUTION_FRAME - 46.0)
		column.add_child(trait_label)
	# 選ぶキー（1・2）の番号の札。札の左上の隅に、縁へ掛けて置く。
	var key := PanelContainer.new()
	key.add_theme_stylebox_override("panel", UiTheme.number_box())
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key.position = Vector2(-6.0, -8.0)
	key.custom_minimum_size = Vector2(22.0, 22.0)
	var key_label := _label(13)
	key_label.text = str(index + 1)
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_label.add_theme_color_override("font_color", Palette.TEXT_DIM)
	key.add_child(key_label)
	button.add_child(key)
	button.custom_minimum_size = Vector2(EVOLUTION_CARD.x, maxf(EVOLUTION_CARD.y, inside.get_combined_minimum_size().y))


func hide_evolution() -> void:
	_evolution.visible = false


## 進化先の選択肢を出しているか。検査用。
func is_evolution_shown() -> bool:
	return _evolution.visible


## 進化先の選択肢の枠の四角（出していなければ大きさ 0）。会話の札は、これと重なる間は薄くする。
func evolution_rect() -> Rect2:
	return _evolution.get_global_rect() if _evolution.visible else Rect2()


## マウスがボタンやパネルの上にあるか（盤面のクリックと取り違えないため）。
func is_mouse_over_ui() -> bool:
	return get_viewport().gui_get_hovered_control() != null


func _side_color(side: Unit.Side) -> Color:
	return _team_colors[side] if side < _team_colors.size() else Color.WHITE


# ---- ミニマップ ----


## ミニマップ（盤を描かせる・押されたことを受ける）。
func minimap() -> Minimap:
	return _minimap


## ミニマップを出すか（設定の「ミニマップ」）。決着の画面を出している間は、出さない。
func set_minimap_shown(shown: bool) -> void:
	_minimap_wanted = shown
	_minimap.visible = shown and not _result.visible


## ミニマップを、視点の案内の下・画面の右の端に置く。
func place_minimap() -> void:
	_minimap.visible = _minimap_wanted and not _result.visible
	var top := _guide_panel.get_global_rect().end.y if _guide_panel.size.y > 0.0 else TOP_BAR_HEIGHT + 30.0
	var rect := MinimapGeometry.place(_minimap.get_viewport_rect().size, _minimap.board_size(), top)
	_minimap.position = rect.position


## ミニマップが画面に占める四角（出していなければ大きさ 0）。駒のそばのメニューと予測のパネルは、ここに重ねない。
func minimap_rect() -> Rect2:
	return Rect2(_minimap.position, _minimap.size) if _minimap.visible else Rect2()


# ---- 組み立て ----


func _build_minimap() -> void:
	_minimap = Minimap.new()
	_minimap.team_colors = _team_colors
	add_child(_minimap)



func _build_top_bar() -> void:
	var panel := _panel()
	_top_style = UiTheme.band_box(true)
	panel.add_theme_stylebox_override("panel", _top_style)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	add_child(panel)
	var row := HBoxContainer.new()
	# 間とゲージの幅は、相手が CPU（「相手: CPU」）で、ターンが 2 桁でも、陣営の欄（駒の数と占拠の印）が省かれずに収まる大きさ。
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	_turn_label = _label(20)
	row.add_child(_turn_label)
	_phase_label = _label(20)
	row.add_child(_phase_label)
	# 番の文字の後ろに、番の陣営の色の札を敷く（札は文字の枠の外へはみ出させて描く。並びの幅は変えない）。
	_phase_chip_style = UiTheme.box(Palette.RAISED, Palette.BORDER, 1, 4, 0.0)
	_phase_chip_style.expand_margin_left = 6.0
	_phase_chip_style.expand_margin_right = 6.0
	_phase_label.add_theme_stylebox_override("normal", _phase_chip_style)
	for player in 2:
		# 陣営の欄は、残った幅を分け合う。足りなければ「…」で省く（帯が画面の幅を超えて、右端のボタンが切れないように）。
		var label := _label(16)
		label.add_theme_color_override("font_color", _team_colors[player].lightened(0.4))
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(label)
		_side_labels.append(label)
		# 聖遺物のアイコン（持っていなければ暗い輪郭、持っていれば点く）。名前と効果は、アイコンにマウスを乗せると出る。
		var icons: Array = []
		for relic: Relics.Id in Relics.Id.values():
			var icon := RelicIcon.new(relic)
			row.add_child(icon)
			icons.append(icon)
		_relic_icons.append(icons)
		# 必殺技のゲージ（飾らない棒と数字）。軍の色で塗る。
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(76.0, 22.0)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.show_percentage = false
		bar.add_theme_stylebox_override("fill", UiTheme.box(_team_colors[player].lightened(0.2), _team_colors[player].lightened(0.55), 1, 3, 0.0))
		row.add_child(bar)
		_ult_bars.append(bar)
		# 数字は棒の上に重ねる（上の帯の幅を取らない）。
		var percent := _label(14)
		percent.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		percent.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		percent.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_child(percent)
		_ult_labels.append(percent)
	_opponent_button = _button("", opponent_pressed)
	_opponent_button.custom_minimum_size = Vector2(0.0, 30.0)
	_opponent_button.add_theme_font_size_override("font_size", 15)
	_opponent_button.tooltip_text = Text.t("battle.hud.opponent.tooltip")
	row.add_child(_opponent_button)
	# ログは、いつでも開ける（相手の番や中立のフェーズで起きたことを、あとから確かめる）。
	var log_button := _button(Text.t("battle.hud.log"), log_pressed)
	log_button.custom_minimum_size = Vector2(64.0, 30.0)
	log_button.add_theme_font_size_override("font_size", 15)
	log_button.tooltip_text = Text.t("battle.hud.log.tooltip")
	row.add_child(log_button)
	# 右端は、システムメニューのボタン（system_menu.gd。別の層に置く）のぶんを空けておく。
	var corner := Control.new()
	corner.custom_minimum_size = Vector2(SystemMenu.CORNER_BUTTON_SIZE.x + SystemMenu.CORNER_MARGIN, 0.0)
	corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(corner)

	# 勝ち方の札。上の帯の中は陣営の欄で埋まっているので、帯のすぐ下の左に、視点の案内（右）と並べて出す。
	# 枠で囲んで金色の文字にし、詳しい文は、マウスを乗せると出す。
	_goal_panel = PanelContainer.new()
	_goal_style = StyleBoxFlat.new()
	_goal_style.set_corner_radius_all(4)
	_goal_style.set_border_width_all(1)
	_goal_style.content_margin_left = 10.0
	_goal_style.content_margin_right = 10.0
	_goal_style.content_margin_top = 3.0
	_goal_style.content_margin_bottom = 3.0
	_goal_panel.add_theme_stylebox_override("panel", _goal_style)
	_goal_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_goal_panel.offset_left = 6.0
	_goal_panel.offset_top = TOP_BAR_HEIGHT + 4.0
	_goal_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_goal_panel.visible = false
	add_child(_goal_panel)
	_goal_label = _label(17)
	_goal_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_goal_panel.add_child(_goal_label)

	# 拠点の札（試しの決まり）。勝ち方の札と同じ所（出ていれば、その下）に、決まった大きさで出す。
	_stronghold_panel = PanelContainer.new()
	_stronghold_style = StyleBoxFlat.new()
	_stronghold_style.set_corner_radius_all(4)
	_stronghold_style.set_border_width_all(1)
	_stronghold_style.content_margin_left = 10.0
	_stronghold_style.content_margin_right = 10.0
	_stronghold_panel.add_theme_stylebox_override("panel", _stronghold_style)
	_stronghold_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_stronghold_panel.offset_left = 6.0
	_stronghold_panel.offset_top = TOP_BAR_HEIGHT + 4.0
	_stronghold_panel.custom_minimum_size = STRONGHOLD_CHIP_SIZE
	_stronghold_panel.size = STRONGHOLD_CHIP_SIZE
	_stronghold_panel.clip_contents = true
	_stronghold_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_stronghold_panel.visible = false
	add_child(_stronghold_panel)
	Steady.mark(_stronghold_panel, "battle.stronghold_chip")
	var stronghold_row := HBoxContainer.new()
	stronghold_row.add_theme_constant_override("separation", 10)
	stronghold_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stronghold_panel.add_child(stronghold_row)
	_stronghold_caption = _label(17)
	_stronghold_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stronghold_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stronghold_row.add_child(_stronghold_caption)
	for player in 2:
		var marks := _label(17)
		marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
		marks.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		stronghold_row.add_child(marks)
		_stronghold_marks.append(marks)

	# 視点の動かし方（マウスに割り当てていない平行移動を含む）。小さく 1 行だけ。
	var help_panel := _panel()
	_guide_panel = help_panel
	(help_panel.get_theme_stylebox("panel") as StyleBoxFlat).set_content_margin_all(4.0)
	help_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	help_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	help_panel.offset_left = -6.0
	help_panel.offset_right = -6.0
	help_panel.offset_top = TOP_BAR_HEIGHT + 4.0
	help_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(help_panel)
	var help := _label(13)
	help.text = Text.t("battle.hud.camera_help")
	help.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	help.add_theme_constant_override("outline_size", 0)
	help_panel.add_child(help)


## 情報の枠の上の縁を、color にする（駒なら陣営の色、マスなら枠の真鍮）。
func _edge_info_panel(color: Color) -> void:
	_info_style.border_color = Palette.BORDER.lerp(color, 0.85)


func _build_info_panel() -> void:
	_info_panel = _panel()
	_info_style = _info_panel.get_theme_stylebox("panel") as StyleBoxFlat
	_info_style.border_width_top = 3
	_info_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_info_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_info_panel.offset_left = 10.0
	_info_panel.offset_right = 10.0
	_info_panel.offset_top = -BOTTOM_BAR_HEIGHT - 8.0
	_info_panel.offset_bottom = -BOTTOM_BAR_HEIGHT - 8.0
	_info_panel.custom_minimum_size = Vector2(INFO_WIDTH + 20.0, INFO_HEIGHT)
	Steady.mark(_info_panel, "battle.info", Steady.RECT)
	# 盤面の隅に重なるので、下のマスを選べるよう、マウスは素通しにする。
	_info_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_panel.visible = false
	add_child(_info_panel)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 入れ物は既定でマウスを拾うので、こちらも素通しにする
	_info_panel.add_child(column)
	# 名前の左に、駒のアイコン（unit_icons.gd。陣営の色と、進化したかで変わる）。
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(head)
	# 駒の額（縁は陣営の色。右下に役割の印）。
	_info_icon = UnitFrame.new(UnitKind.Id.KING, 0, INFO_ICON_SIZE)
	head.add_child(_info_icon)
	_info_name = _label(20)
	_info_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_info_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info_name.clip_text = true  # 折り返した行の端数で、枠の幅を広げない
	head.add_child(_info_name)
	_info_side = _label(14)
	_info_side.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_info_side.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	column.add_child(_info_side)
	# HP の棒（駒の頭の上には出さないので、ここで割合が分かるようにする）。
	_info_unit_box = VBoxContainer.new()
	_info_unit_box.add_theme_constant_override("separation", 3)
	_info_unit_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_info_unit_box)
	_info_hp = ProgressBar.new()
	_info_hp.custom_minimum_size = Vector2(0.0, 13.0)
	_info_hp.show_percentage = false
	_info_hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_hp_fill = UiTheme.box(Palette.HP_HIGH, Color(0, 0, 0, 0), 0, 3, 0.0)
	_info_hp.add_theme_stylebox_override("fill", _info_hp_fill)
	_info_unit_box.add_child(_info_hp)
	# HP の数（太字）と、その右にレベルと経験。
	var hp_row := HBoxContainer.new()
	hp_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_unit_box.add_child(hp_row)
	_info_hp_label = _label(17)
	_info_hp_label.add_theme_font_override("font", UiTheme.FONT_BOLD)
	_info_hp_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_row.add_child(_info_hp_label)
	_info_level = _label(14)
	_info_level.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	_info_level.size_flags_vertical = Control.SIZE_SHRINK_END
	hp_row.add_child(_info_level)
	# 攻撃・移動・射程は、幅のそろった欄（駒を見比べても、数が同じ所にある）。
	_info_stats_row = StatsRow.new("", 16, floorf(INFO_WIDTH / 3.0))  # 端数を持たせない（3 つ並べると枠が 1 px 広がる）
	_info_unit_box.add_child(_info_stats_row)
	_info_rule = HSeparator.new()
	_info_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_info_rule)
	# ここから下の文は、枠の残りの高さの中に収める（枠は伸ばさない）。入りきらなければ、字を小さくする（_fit_info）。
	# 送りの棒は出さない（枠はマウスを素通しにする）。それでも入らないぶんは、下が切れる。
	_info_room = ScrollContainer.new()
	_info_room.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_info_room.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_info_room.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_info_room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_info_room)
	var fixed_column := column
	column = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info_room.add_child(column)
	_info_lines = column
	# マスの情報の本文（駒の能力値は、上の欄に分けて出す。文はここに持つ）。
	_info_stats = _label(17)
	column.add_child(_info_stats)
	# 状態は、残りの期間と効果。付いている間だけ（盤の上では、足元の水色の輪だけで分かる）。
	_info_statuses = _info_line(column, 15, COLOR_STATUS)
	_info_items = _info_line(column, 15, Palette.TEXT)
	_info_skill = _info_line(column, 15, Palette.TEXT)
	_info_skill_note = _info_line(column, 14, COLOR_TEXT_DIM)
	_info_traits = _info_line(column, 15, COLOR_TRAIT)
	_info_state = _info_line(column, 14, COLOR_TEXT_DIM)
	_info_forecast = _label(17)
	_info_forecast.add_theme_color_override("font_color", COLOR_FORECAST)
	# スキルの説明のように長い文は、枠の幅で折り返してから出す（_set_folded。枠を横に広げて盤面を隠さない）。
	column.add_child(_info_forecast)
	for label: Label in [_info_stats, _info_statuses, _info_items, _info_skill, _info_skill_note, _info_traits, _info_state, _info_forecast]:
		label.clip_text = true  # 折り返した行の端数で、枠の幅を広げない
		label.set_meta(&"font_size", label.get_theme_font_size("font_size"))
		label.set_meta(&"plain", "")
	column = fixed_column
	# 枠は素通しだが、スイッチはクリックを受ける。いちばん下に置く（枠は下にそろうので、中身が変わってもスイッチは動かない）。
	_info_pin = CheckButton.new()
	_info_pin.text = Text.t("battle.hud.pin")
	_info_pin.focus_mode = Control.FOCUS_NONE
	_info_pin.add_theme_font_size_override("font_size", 15)
	_info_pin.visible = false
	_info_pin.pressed.connect(pin_toggled.emit)
	column.add_child(_info_pin)
	# 「詳細」: 見ている駒・選んでいる駒のステータスの窓（unit_detail.gd）を開く。控えめなボタンで、右に寄せる。
	_info_detail = _button(Text.t("battle.hud.detail"), detail_pressed)
	_info_detail.theme_type_variation = UiTheme.BUTTON_GHOST
	_info_detail.add_theme_font_size_override("font_size", 14)
	_info_detail.custom_minimum_size = Vector2(88.0, 30.0)
	_info_detail.size_flags_horizontal = Control.SIZE_SHRINK_END
	_info_detail.visible = false
	column.add_child(_info_detail)


func _info_line(column: VBoxContainer, font_size: int, color: Color) -> Label:
	var label := _label(font_size)
	label.add_theme_color_override("font_color", color)
	label.visible = false
	column.add_child(label)
	return label


func _build_bottom() -> void:
	var panel := _panel()
	var band := UiTheme.band_box(false)
	band.content_margin_top = BOTTOM_BAR_MARGIN
	band.content_margin_bottom = BOTTOM_BAR_MARGIN
	panel.add_theme_stylebox_override("panel", band)
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.custom_minimum_size = Vector2(0.0, BOTTOM_BAR_HEIGHT)
	Steady.mark(panel, "battle.bottom_band", Steady.RECT)
	add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	# 案内の頭の、金の細い線（案内の欄がどこから始まるかの目印。幅は _hint_room が引く）。
	var hint_mark := ColorRect.new()
	hint_mark.color = Palette.BORDER_BRIGHT
	hint_mark.custom_minimum_size = Vector2(3.0, 44.0)
	hint_mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hint_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(hint_mark)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(column)
	# いまできること。長ければ 2 行まで折り返す（ボタンを画面の外へ押し出さない）。
	_hint_label = _label(17)
	_hint_label.max_lines_visible = 2
	_hint_label.clip_text = true
	column.add_child(_hint_label)
	# マウスの下のマスの説明。長ければ 2 行まで折り返す（拠点の説明のように長いものも読める。_fold_cell）。
	_cell_label = _label(CELL_FONT_SIZE)
	_cell_label.max_lines_visible = 2
	_cell_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_cell_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	column.add_child(_cell_label)

	# 駒に属さない操作は、いつも同じ場所（右下）に置く。
	# 敵の全員の脅威範囲の切り替え。入・切が見て分かるよう、スイッチの形にする。
	_threat_button = CheckButton.new()
	_threat_button.text = Text.t("battle.hud.threat")
	_threat_button.focus_mode = Control.FOCUS_NONE
	_threat_button.add_theme_font_size_override("font_size", 17)
	_threat_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_threat_button.tooltip_text = Text.t("battle.hud.threat.tooltip")
	_threat_button.pressed.connect(threat_toggled.emit)
	row.add_child(_threat_button)
	_watch_box = HBoxContainer.new()
	_watch_box.add_theme_constant_override("separation", 8)
	_watch_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_watch_box.visible = false
	row.add_child(_watch_box)
	_fast_button = _button(Text.t("battle.hud.fast"), fast_forward_toggled)
	_fast_button.toggle_mode = true
	_fast_button.custom_minimum_size = Vector2(120.0, 44.0)
	_fast_button.theme_type_variation = UiTheme.BUTTON_GHOST
	_fast_button.tooltip_text = Text.t("battle.hud.fast.tooltip")
	_watch_box.add_child(_fast_button)
	_skip_button = _button(Text.t("battle.hud.skip"), skip_pressed)
	_skip_button.custom_minimum_size = Vector2(120.0, 44.0)
	_skip_button.theme_type_variation = UiTheme.BUTTON_GHOST
	_skip_button.tooltip_text = Text.t("battle.hud.skip.tooltip")
	_watch_box.add_child(_skip_button)
	_ult_button = _button(Text.t("battle.hud.ult"), ult_pressed)
	_ult_button.custom_minimum_size = Vector2(220.0, 48.0)
	_ult_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_ult_button.disabled = true
	# 押せるとき（ゲージが READY）は、金の縁と金の文字（押せない間は、テーマの押せない形）。
	var ult_ready := UiTheme.box(Palette.CHOSEN, Palette.ACCENT, 2, UiTheme.CORNER, 6.0, 4)
	_ult_button.add_theme_stylebox_override("normal", ult_ready)
	var ult_hover := ult_ready.duplicate() as StyleBoxFlat
	ult_hover.bg_color = Palette.CHOSEN.lightened(0.12)
	_ult_button.add_theme_stylebox_override("hover", ult_hover)
	_ult_button.add_theme_color_override("font_color", Palette.ACCENT)
	_ult_button.add_theme_color_override("font_hover_color", Palette.ACCENT)
	_ult_button.add_theme_font_override("font", UiTheme.FONT_BOLD)
	_ult_fill = Control.new()
	_ult_fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ult_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ult_fill.draw.connect(_draw_ult_fill)
	_ult_button.add_child(_ult_fill)
	_ult_button.mouse_entered.connect(_show_ult_summary)
	_ult_button.mouse_exited.connect(_show_ult_summary)
	row.add_child(_ult_button)
	_auto_button = _button(Text.t("battle.hud.auto"), auto_pressed)
	_auto_button.custom_minimum_size = Vector2(112.0, 44.0)
	_auto_button.theme_type_variation = UiTheme.BUTTON_GHOST
	_auto_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_auto_button.tooltip_text = Text.t("battle.hud.auto.tooltip")
	_auto_button.disabled = true
	row.add_child(_auto_button)
	# ターン終了は、見つけやすいよう色を付けて、いちばん端に置く（駒のそばのメニューからは離れている）。
	_end_turn_button = _button(Text.t("battle.hud.end_turn"), end_turn_pressed)
	_end_turn_button.custom_minimum_size = Vector2(210.0, 60.0)
	_end_turn_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_end_turn_button.add_theme_font_size_override("font_size", 21)
	_end_turn_button.add_theme_font_override("font", UiTheme.FONT_BOLD)
	_end_turn_style = UiTheme.box(COLOR_END_TURN, COLOR_END_TURN_READY.lightened(0.3), 2, 8, 6.0, 4)
	_end_turn_button.add_theme_stylebox_override("normal", _end_turn_style)
	_end_turn_button.add_theme_stylebox_override("hover", _end_turn_style)
	row.add_child(_end_turn_button)

	# 必殺技の説明。ボタンの上に、マウスを乗せている間と、使うかを確かめている間だけ出す。
	_ult_panel = _panel(COLOR_PANEL_SOLID)
	_ult_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_ult_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_ult_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_ult_panel.offset_left = -10.0
	_ult_panel.offset_right = -10.0
	_ult_panel.offset_top = -BOTTOM_BAR_HEIGHT - 8.0
	_ult_panel.offset_bottom = -BOTTOM_BAR_HEIGHT - 8.0
	_ult_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ult_panel.visible = false
	add_child(_ult_panel)
	_ult_summary = _label(15)
	_ult_panel.add_child(_ult_summary)
	# 作戦（試しの決まり）のボタン。下の帯のすぐ上の右端。手札の無い対戦では出さない。
	_tactic_box = HBoxContainer.new()
	_tactic_box.add_theme_constant_override("separation", 8)
	_tactic_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_tactic_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_tactic_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_tactic_box.offset_left = -10.0
	_tactic_box.offset_right = -10.0
	_tactic_box.offset_top = -BOTTOM_BAR_HEIGHT - 8.0
	_tactic_box.offset_bottom = -BOTTOM_BAR_HEIGHT - 8.0
	_tactic_box.visible = false
	add_child(_tactic_box)
	var tactic_caption := _label(15)
	tactic_caption.text = Text.t("battle.tactic.caption")
	tactic_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tactic_box.add_child(tactic_caption)
	# 作戦の説明。ボタンの上の決まった場所・大きさに、乗せている間と確かめている間だけ出す。
	_tactic_note_panel = _panel(COLOR_PANEL_SOLID)
	_tactic_note_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_tactic_note_panel.custom_minimum_size = TACTIC_NOTE_SIZE
	_tactic_note_panel.offset_left = -10.0 - TACTIC_NOTE_SIZE.x
	_tactic_note_panel.offset_right = -10.0
	_tactic_note_panel.offset_bottom = -BOTTOM_BAR_HEIGHT - 8.0 - TACTIC_BUTTON_HEIGHT - 8.0
	_tactic_note_panel.offset_top = _tactic_note_panel.offset_bottom - TACTIC_NOTE_SIZE.y
	_tactic_note_panel.clip_contents = true
	_tactic_note_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tactic_note_panel.visible = false
	add_child(_tactic_note_panel)
	Steady.mark(_tactic_note_panel, "battle.tactic_note", Steady.RECT)
	_tactic_note = _label(15)
	_tactic_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tactic_note.max_lines_visible = 2
	_tactic_note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tactic_note_panel.add_child(_tactic_note)


## 戦闘予測のパネル。中身は show_forecast()、置き場所は place_forecast() で決める。
func _build_forecast() -> void:
	_forecast = ForecastPanel.new()
	Steady.mark(_forecast, "battle.forecast", Steady.WIDTH)  # 高さは、相手の数（行の数）で変わる
	add_child(_forecast)
	_forecast.setup(_team_colors, _char_width)


## 戦闘予測のパネルを出す（title は何をするか）。
func show_forecast(title: String, summary: ForecastText.Summary) -> void:
	_forecast.show_summary(title, summary)


func hide_forecast() -> void:
	_forecast.hide_summary()


## 戦闘予測のパネルの大きさ（出していなければ 0）。
func forecast_size() -> Vector2:
	return _forecast.get_combined_minimum_size() if _forecast.visible else Vector2.ZERO


func place_forecast(at: Vector2) -> void:
	_forecast.position = at.round()
	_forecast.size = _forecast.get_combined_minimum_size()


## 戦闘予測のパネルが画面に占める四角と、出している中身の文（出していなければ空）。検査用。
func forecast_rect() -> Rect2:
	return Rect2(_forecast.position, _forecast.size) if _forecast.visible else Rect2()


func forecast_text() -> String:
	return _forecast.shown_text()


## 駒のそばのメニュー。中身は set_menu()、置き場所は place_menu() で決める。
func _build_menu() -> void:
	_menu_line = Line2D.new()
	_menu_line.width = 2.0
	_menu_line.default_color = Color(1.0, 1.0, 1.0, 0.75)
	_menu_line.visible = false
	add_child(_menu_line)
	# 板は、上の縁の太い真鍮と、落ちる影（盤の上で、札として浮く）。項目は板の上の行（BUTTON_ACTION）。
	_menu = PanelContainer.new()
	var menu_style := UiTheme.box(COLOR_PANEL_SOLID, Palette.BORDER, 1, 6, 5.0, 5)
	menu_style.border_width_top = 3
	menu_style.border_color = Palette.BORDER_BRIGHT.darkened(0.25)
	_menu.add_theme_stylebox_override("panel", menu_style)
	_menu.visible = false
	Steady.mark(_menu, "battle.menu", Steady.WIDTH)
	add_child(_menu)
	_menu_column = VBoxContainer.new()
	_menu_column.add_theme_constant_override("separation", 2)
	_menu.add_child(_menu_column)


## 対戦の始めの知らせ（試しの決まり）。盤の上寄りの真ん中に、決まった大きさで出す。閉じるまで（か、盤をクリックするまで）出したまま。
func _build_notice() -> void:
	_notice = PanelContainer.new()
	var plate := UiTheme.box(COLOR_PANEL_SOLID, Palette.BORDER_BRIGHT, 1, 8, 14.0, 6)
	plate.border_width_top = 3
	_notice.add_theme_stylebox_override("panel", plate)
	_notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_notice.custom_minimum_size = NOTICE_SIZE
	_notice.offset_left = -NOTICE_SIZE.x / 2.0
	_notice.offset_right = NOTICE_SIZE.x / 2.0
	_notice.offset_top = BANNER_TOP + BannerBand.HEIGHT + 12.0
	_notice.offset_bottom = _notice.offset_top + NOTICE_SIZE.y
	_notice.clip_contents = true
	_notice.mouse_filter = Control.MOUSE_FILTER_STOP
	_notice.visible = false
	add_child(_notice)
	Steady.mark(_notice, "battle.trial_notice", Steady.RECT)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_notice.add_child(column)
	var title := _label(20)
	title.text = Text.t("battle.notice.title")
	UiTheme.style_window_title(title, 20)
	column.add_child(title)
	column.add_child(UiTheme.window_rule(Palette.BORDER_BRIGHT))
	_notice_body = _label(16)
	_notice_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice_body.max_lines_visible = NOTICE_LINES
	_notice_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_notice_body)
	var close := _button(Text.t("battle.notice.close"), Signal())
	close.custom_minimum_size = Vector2(120.0, 32.0)
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.pressed.connect(hide_notice)
	column.add_child(close)


## 対戦の始めの知らせを出す（lines は決まりごとの行。空なら出さない）。
func show_notice(lines: Array[String]) -> void:
	_notice_body.text = "\n".join(lines)
	_notice.visible = not lines.is_empty()


func hide_notice() -> void:
	_notice.visible = false


## 対戦の始めの知らせの文（出ていなければ空。検査用）。
func notice_text() -> String:
	return _notice_body.text if _notice.visible else ""


## 対戦の始めの知らせの枠の四角（出ていなければ大きさ 0。検査用）。
func notice_rect() -> Rect2:
	return _notice.get_global_rect() if _notice.visible else Rect2()


func _build_banner() -> void:
	_banner = BannerBand.new()
	_banner.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_banner.offset_top = BANNER_TOP
	_banner.offset_bottom = BANNER_TOP + BannerBand.HEIGHT
	_banner.visible = false
	add_child(_banner)


## 進化先の選択肢（2 つの札）。盤面が見えるよう、画面の上寄りに出す。板は予測のパネルと同じく、上の縁が太い金。
func _build_evolution() -> void:
	var panel := PanelContainer.new()
	var plate := UiTheme.box(COLOR_PANEL, Palette.BORDER_BRIGHT, 1, 8, 12.0, 6)
	plate.border_width_top = 3
	panel.add_theme_stylebox_override("panel", plate)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.position.y = 70.0
	panel.visible = false
	add_child(panel)
	_evolution = panel
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	_evolution_title = _label(22)
	UiTheme.style_window_title(_evolution_title, 22)
	column.add_child(_evolution_title)
	column.add_child(UiTheme.window_rule(Palette.BORDER_BRIGHT))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	column.add_child(row)
	for i in 2:
		var button := _button("", Signal())
		button.theme_type_variation = UiTheme.BUTTON_CARD
		button.custom_minimum_size = EVOLUTION_CARD
		button.pressed.connect(func() -> void: evolution_chosen.emit(i))
		row.add_child(button)
		_evolution_buttons.append(button)


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


