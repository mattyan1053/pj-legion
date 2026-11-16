extends CanvasLayer
## 対戦の画面の文字とボタン（ターン、番、駒とマスの情報、駒のそばのメニュー、決着）。
##
## 何を出すかは呼ぶ側が決める。ここはルールを持たず、押されたことを signal で知らせるだけ。
## 駒に属する操作（攻撃、スキル、待機…）は駒のそばのメニューに、駒に属さない操作（ターン終了、必殺技、相手の切り替え）は
## 画面の決まった場所に置く。どれもクリックだけで選べる。

## 駒のそばのメニューの項目が押された。id は set_menu() に渡した項目の名前。
const TextWrap := preload("res://game/text_wrap.gd")
const Names := preload("res://game/names.gd")
const SystemMenu := preload("res://game/system_menu.gd")
const ForecastPanel := preload("res://game/forecast_panel.gd")
const ForecastText := preload("res://game/forecast_text.gd")
const RelicIcon := preload("res://game/relic_icon.gd")
const ResultScreen := preload("res://game/result_screen.gd")
const Minimap := preload("res://game/minimap.gd")
const MinimapGeometry := preload("res://game/minimap_geometry.gd")

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
## 相手を人にするか CPU にするかの切り替えが押された。
signal opponent_pressed
## ログのボタンが押された。
signal log_pressed
## 決着の画面の「対戦の設定へ」が押された。
signal setup_pressed
## 決着の画面の「タイトルへ」が押された。
signal title_pressed
## stage は BoardGenerator.Stage の値。new_board が偽なら、いまと同じ盤面でやり直す（stage は見ない）。
signal restart_pressed(stage: int, new_board: bool)
## 決着の画面を出した（draw なら引き分けで、winner は使わない）。決着の曲を鳴らす合図。
signal result_shown(draw: bool, winner: Unit.Side)

const TERRAIN_NAMES := {
	Terrain.Type.NORMAL: "平地",
	Terrain.Type.OBSTACLE: "障害物（入れない）",
	Terrain.Type.FOREST: "森（移動 2・受けるダメージ 0.8 倍）",
	Terrain.Type.FONT: "結晶泉",
}
const OBJECT_NAMES := {
	MapObject.Type.BARREL: "起爆樽（入れない。攻撃すると爆発し、周り 8 マスの駒すべてに %d ダメージ）" % MapObject.BLAST_DAMAGE,
	MapObject.Type.SPRING: "回復の泉（自分の番の始めに、乗っている駒が %d 回復）" % MapObject.SPRING_HEAL,
	MapObject.Type.PORTAL: "ポータル",
}
const COLOR_PANEL := Color(0.07, 0.09, 0.12, 0.82)
## 後ろの盤面の文字が透けて読みにくくならないよう、決着の画面とメニューは透かさない。
const COLOR_PANEL_SOLID := Color(0.09, 0.11, 0.15, 0.97)
const COLOR_END_TURN := Color("2f6b3a")
const COLOR_END_TURN_READY := Color("3fa24f")
## 上の帯と下の帯の高さ（駒のそばのメニューは、この内側に置く）。
const TOP_BAR_HEIGHT := 50.0
const BOTTOM_BAR_HEIGHT := 92.0
## メニューが駒の中央からこれより離れたら、駒まで線を引く（px）。
const MENU_LINE_FROM := 70.0
## 文を折り返す幅（px）。情報の枠、必殺技の説明。下の帯の説明は、画面の幅からボタンのぶんを引く。
const INFO_WIDTH := 320.0
const ULT_SUMMARY_WIDTH := 480.0
const HINT_SIDE_WIDTH := 730.0
const COLOR_TEXT_DIM := Color(0.75, 0.78, 0.82)
const COLOR_FORECAST := Color("ffd76a")
const COLOR_STATUS := Color("8fe6ff")
const COLOR_TRAIT := Color("ffd34a")
## 状態の効果の短い説明（駒の情報の枠に、残りの期間と一緒に出す）。
const STATUS_TEXTS := {
	Status.Type.BARRIER: "次に受けるダメージを 1 回だけ防ぐ",
	Status.Type.AIM: "射程 +%d。次の攻撃がクリティカル（動くと解ける）" % PrecisionAimSkill.RANGE_BONUS,
	Status.Type.FATIGUE: "攻撃 -%d" % AdrenalineShotSkill.POWER_PENALTY,
	Status.Type.ASSAULT: "移動 +%d・攻撃 +%d" % [AllOutAssaultUlt.MOVE_BONUS, AllOutAssaultUlt.POWER_BONUS],
}
## 必殺技の画面のフラッシュ（濃さと、消えるまでの秒数）。
const FLASH_ALPHA := 0.45
const FLASH_TIME := 0.45
## READY の明滅（いちばん色づいたときの色と、1 回の秒数）。
const COLOR_PULSE := Color(1.0, 0.72, 0.25)
const PULSE_PERIOD := 1.1
## 必殺技の知らせの色（軍ごと）。
const ULT_COLORS := {
	Ult.Id.ALL_OUT_ASSAULT: Color("ff5a4a"),
	Ult.Id.MANA_ERUPTION: Color("9a7bff"),
}

var _team_colors: Array[Color] = []

var _turn_label: Label
var _phase_label: Label
var _side_labels: Array[Label] = []
var _relic_texts: Array[String] = ["", ""]
## 陣営ごとの聖遺物のアイコン（添字がプレイヤー番号。中は Relics.Id の順）。
var _relic_icons: Array[Array] = []
var _relic_notes: Array[String] = ["", ""]
var _ult_bars: Array[ProgressBar] = []
var _ult_labels: Array[Label] = []
var _ult_button: Button
var _ult_summary: Label
var _info_panel: PanelContainer
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
var _info_forecast: Label
var _cell_label: Label
var _hint_label: Label
var _end_turn_button: Button
var _end_turn_style: StyleBoxFlat
var _opponent_button: Button
var _threat_button: CheckButton
var _ult_panel: PanelContainer
var _ult_pinned := false
var _menu: PanelContainer
var _forecast: ForecastPanel
var _menu_line: Line2D
var _menu_column: VBoxContainer
## いまメニューに出している項目（[名前, 文字, 押せるか] の列）と、項目の名前 -> ボタン。
var _menu_items: Array = []
var _menu_buttons := {}
## 文字の幅の覚え（"文字の大きさ:文字" -> px）。折り返しに使う。
var _char_widths := {}
var _banner: Label
var _banner_tween: Tween
var _flash: ColorRect
var _flash_tween: Tween
var _result: ResultScreen
var _guide_panel: PanelContainer
var _minimap: Minimap
## ミニマップを出すか（設定の「ミニマップ」）。
var _minimap_wanted := true
var _evolution: Control
var _evolution_title: Label
var _evolution_buttons: Array[Button] = []


func setup(team_colors: Array[Color]) -> void:
	_team_colors = team_colors
	_build_top_bar()
	_build_info_panel()
	_build_bottom()
	_build_flash()
	_build_banner()
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


## turn_text はターンの文（「ターン 3」、守り切るがあれば「ターン 3 / 10」。win_text.gd）。
## counts は陣営ごとの駒の数、captures は本陣の占拠の数（どちらも添字がプレイヤー番号）。
## capture_shown は陣営ごとの、占拠の数を出すか（本陣の占拠が勝ちの条件に無い陣営は出さない）。
## turn_note は、ターンの文にマウスを乗せると出る説明（守り切るの決まり。無ければ空）。
func set_status(
	turn_text: String, phase: Unit.Side, counts: Array[int], captures: Array[int], capture_goal: int,
	capture_shown: Array[bool] = [true, true], turn_note := "",
) -> void:
	_turn_label.text = turn_text
	_turn_label.tooltip_text = turn_note
	_turn_label.mouse_filter = Control.MOUSE_FILTER_STOP if turn_note != "" else Control.MOUSE_FILTER_IGNORE
	_phase_label.text = "%s の番" % Names.SIDE_NAMES[phase]
	_phase_label.add_theme_color_override("font_color", _side_color(phase))
	for player in 2:
		var text := "%s  駒 %d" % [Names.SIDE_WORDS[player], counts[player]]
		if capture_shown[player]:
			text += "  占拠 %s" % ("●".repeat(captures[player]) + "○".repeat(capture_goal - captures[player]))
		_side_labels[player].text = text
		# 幅が足りずに省かれても読めるよう、全文をツールチップにも置く。聖遺物の効果も、ここで読める。
		_side_labels[player].tooltip_text = _side_labels[player].text
		if _relic_notes[player] != "":
			_side_labels[player].tooltip_text += "
" + _relic_notes[player]


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


## いちばん上の帯に出ている、必殺技のゲージの文字（"62%" か "READY"。出ていなければ空）。検査用。
func ult_gauge_text(player: int) -> String:
	return _ult_labels[player].text if _ult_labels[player].visible else ""


## 必殺技のボタン（下の帯）。text はボタンの文字、enabled は押せるか。summary は必殺技の説明（必殺技が無ければ空）。
## 説明は、ボタンにマウスを乗せている間と、pinned が真の間（使うかを確かめている間）だけ、ボタンの上に出す。
func set_ult_button(text: String, enabled: bool, summary: String, pinned := false) -> void:
	_ult_button.text = text
	_ult_button.disabled = not enabled
	_set_folded(_ult_summary, summary, ULT_SUMMARY_WIDTH)
	_ult_pinned = pinned
	_show_ult_summary()


func _show_ult_summary() -> void:
	_ult_panel.visible = _ult_summary.text != "" and (_ult_pinned or _ult_button.is_hovered())


func ult_button_text() -> String:
	return _ult_button.text


func is_ult_enabled() -> bool:
	return not _ult_button.disabled


## 駒の情報を出す。unit が null なら消す。state は行動の状態と、いるマスのこと。note は、そのときに読むべき説明
## （メニューの項目の説明、スキルの対象を選んでいるときの見込み。無ければ空）。
## skill_note が真なら、スキルの説明も出す（note のほうにスキルの説明を出すときは、偽にして重ねない）。
##
## 並び（上から、大事な順）: 名前と役割 → 所属（[自軍] [敵軍] [中立]、陣営、軍） → HP の棒と数 → 能力値とレベル →
## 状態（残りの期間と効果） → 装備 → スキル（名前と使えるか、説明） → 進化の特性 → 行動の状態といるマス → note。
func show_unit(unit: Unit, state: String, note: String, skill_note := true) -> void:
	_info_panel.visible = unit != null
	if unit == null:
		return
	var role: String = Names.ROLE_NAMES.get(UnitKind.role(unit.kind), "")
	var kind := UnitKind.display_name(unit.kind)
	if unit.evolution != Evolution.Id.NONE:
		# 進化した駒は、進化先の名前と、元の種類。
		_info_name.text = "%s（%s から進化%s）" % [unit.display_name(), kind, "・" + role if role else ""]
	else:
		_info_name.text = unit.display_name() + ("（%s）" % role if role else "")
	_info_name.add_theme_color_override("font_color", _side_color(unit.side).lightened(0.35))
	_set_folded(_info_name, _info_name.text, INFO_WIDTH)
	var army: UnitKind.Army = side_armies[unit.side] if unit.side >= 0 and unit.side < side_armies.size() else UnitKind.Army.NONE
	_info_side.text = affiliation_text(unit, viewer_side, army)
	_info_side.add_theme_color_override("font_color", _side_color(unit.side).lightened(0.5))
	_info_side.visible = true
	var ratio := float(unit.hp) / maxf(unit.max_hp(), 1.0)
	_info_hp.visible = true
	_info_hp.value = ratio * 100.0
	_info_hp_fill.bg_color = hp_color(ratio)
	var power_name := "回復" if UnitKind.role(unit.kind) == UnitKind.Role.HEALER else "攻撃"
	var stats := "HP %d / %d\n%s %d　移動 %d　射程 %d" % [
		unit.hp, unit.max_hp(), power_name, unit.power(), unit.move_range(), unit.attack_range(),
	]
	if Growth.can_grow(unit):
		if unit.level >= Growth.MAX_LEVEL:
			stats += "\nレベル %d（最大）" % unit.level
		else:
			stats += "\nレベル %d　経験 %d / %d" % [unit.level, unit.experience, Growth.EXPERIENCE_PER_LEVEL]
	_set_folded(_info_stats, stats, INFO_WIDTH)

	var statuses: Array[String] = []
	for type in Statuses.types_of(unit):
		statuses.append(status_text(type, unit.statuses[type]))
	_set_shown(_info_statuses, "\n".join(statuses))

	var items := ""
	if Equipment.can_equip(unit.kind):
		items = "装備: " + equipment_text(unit.equipment)
	_set_shown(_info_items, items)

	var skill := Skills.of(unit)
	var skill_text := ""
	if skill != null:
		skill_text = "スキル: %s（%s）" % [skill.display_name(), skill_state_text(unit)]
	_set_shown(_info_skill, skill_text)
	# スキルの中身は、読んで知るもの。選んだ駒・マウスを乗せた駒のスキルの説明を、いつも出す。
	_set_shown(_info_skill_note, skill.summary() if skill != null and skill_note else "")

	var traits: Array[String] = []
	for which in Evolution.traits(unit.evolution):
		traits.append("★ " + Names.TRAIT_TEXTS[which])
	_set_shown(_info_traits, "\n".join(traits))
	_set_shown(_info_state, state)
	_set_shown(_info_forecast, note)


## 駒の所属の文。盤を見ている人（viewer）から見た [自軍] [敵軍] [中立] と、陣営、軍（雇う駒だけ）。
## 軍は陣営の軍（side_army。NONE なら駒の種類の軍）。ストーリーでほかの軍の駒を雇ったときは「MILITARY（FANTASY の駒）」と並べる
## （駒の種類の軍だけを出すと、味方の駒に敵と同じ軍の名前が出て紛らわしい）。
static func affiliation_text(unit: Unit, viewer: Unit.Side, side_army := UnitKind.Army.NONE) -> String:
	var tag := "[中立]"
	if unit.side == viewer:
		tag = "[自軍]"
	elif unit.side != Unit.Side.NEUTRAL:
		tag = "[敵軍]"
	var parts: Array[String] = [tag, Names.SIDE_NAMES[unit.side]]
	var army := UnitKind.army(unit.kind)
	if army != UnitKind.Army.NONE:
		if side_army == UnitKind.Army.NONE or side_army == army:
			parts.append(Names.ARMY_NAMES[army])
		else:
			parts.append("%s（%s の駒）" % [Names.ARMY_NAMES[side_army], Names.ARMY_NAMES[army]])
	return "　".join(parts)


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
		parts.append(Equipment.display_name(item) + (" ×%d" % counts[item] if counts[item] > 1 else ""))
	return "・".join(parts) if not parts.is_empty() else "なし"


## 付いている状態の文（名前、残りのターン数、効果）。
static func status_text(type: Status.Type, turns: int) -> String:
	return "%s（あと %d ターン）: %s" % [Status.display_name(type), turns, STATUS_TEXTS[type]]


## クリックしたマスの情報を、駒の情報と同じ枠に出す。title は見出し（マスの位置と地形）、body は説明（行ごと）。
func show_cell_info(title: String, body: String) -> void:
	_info_panel.visible = true
	_info_name.text = title
	_info_name.add_theme_color_override("font_color", Color("e6e6e6"))
	_info_side.visible = false
	_info_hp.visible = false
	_set_folded(_info_stats, body, INFO_WIDTH)
	for label: Label in [_info_statuses, _info_items, _info_skill, _info_skill_note, _info_traits, _info_state, _info_forecast]:
		label.visible = false


## label に、折り返した text を出す。空なら隠す。
func _set_shown(label: Label, text: String) -> void:
	label.visible = text != ""
	if label.visible:
		_set_folded(label, text, INFO_WIDTH)


## 駒の情報の枠に出している文（見出しを除く。出ていなければ空）。検査用。
func info_text() -> String:
	if not _info_panel.visible:
		return ""
	var parts: Array[String] = []
	for label: Label in [_info_side, _info_stats, _info_statuses, _info_items, _info_skill, _info_skill_note, _info_traits, _info_state, _info_forecast]:
		if label.visible:
			parts.append(label.text)
	return "\n".join(parts)


## 駒の情報の枠に出している見出し（出ていなければ空）。検査用。
func info_title() -> String:
	return _info_name.text if _info_panel.visible else ""


## HP の割合（0〜1）の色。半分より多ければ緑、4 分の 1 より多ければ黄、それより少なければ赤。
static func hp_color(ratio: float) -> Color:
	return Color("5fd35f") if ratio > 0.5 else (Color("e8c23a") if ratio > 0.25 else Color("e8503a"))


## マウスの下のマスの説明。盤の外なら空を渡す。
func show_cell(text: String) -> void:
	_cell_label.text = text


func set_hint(text: String) -> void:
	_set_folded(_hint_label, text, _hint_label.get_viewport_rect().size.x - HINT_SIDE_WIDTH)


## ターン終了のボタン。ready が真なら、明るくして目立たせる（動かせる駒が残っていないとき）。
func set_end_turn(enabled: bool, text: String, ready := false) -> void:
	_end_turn_button.disabled = not enabled
	_end_turn_button.text = text
	_end_turn_style.bg_color = COLOR_END_TURN_READY if ready else COLOR_END_TURN


## 敵の全員の脅威範囲の切り替えを、出しているかに合わせる。
func set_threat_button(shown: bool) -> void:
	_threat_button.set_pressed_no_signal(shown)


func end_turn_text() -> String:
	return _end_turn_button.text


## 相手を切り替えるボタンの文字（いまの相手を書く）。空なら、ボタンを出さない（切り替えられない対戦）。
func set_opponent(text: String) -> void:
	_opponent_button.text = text
	_opponent_button.visible = text != ""


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
		button.add_theme_font_size_override("font_size", 17)
		button.custom_minimum_size = Vector2(118.0, 34.0)
		button.pressed.connect(func() -> void: menu_pressed.emit(id))
		button.mouse_entered.connect(func() -> void: menu_hovered.emit(id))
		button.mouse_exited.connect(func() -> void: menu_hovered.emit(&""))
		_menu_column.add_child(button)
		_menu_buttons[id] = button
	_menu.reset_size()


## メニューの大きさ（出していなければ 0）。
func menu_size() -> Vector2:
	return _menu.get_combined_minimum_size() if _menu.visible else Vector2.ZERO


## メニューを置く（左上の、画面の座標）。from は、駒の画面の上の位置。メニューが駒から離れたら、駒まで細い線を引く
## （どの駒のメニューかが分かるように）。
func place_menu(at: Vector2, from: Vector2) -> void:
	_menu.position = at.round()
	_menu.size = _menu.get_combined_minimum_size()
	var rect := Rect2(_menu.position, _menu.size)
	var near := Vector2(clampf(from.x, rect.position.x, rect.end.x), clampf(from.y, rect.position.y, rect.end.y))
	_menu_line.visible = _menu.visible and near.distance_to(from) > MENU_LINE_FROM
	_menu_line.points = PackedVector2Array([from, near])


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


## メニューに出ている項目の名前（上から）。出ていなければ空。
func menu_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	if _menu.visible:
		for item: Array in _menu_items:
			ids.append(item[0])
	return ids


## 駒のスキルの状態（使えるか、あと何ターンか。回数に上限があれば、残りの回数）。
static func skill_state_text(unit: Unit) -> String:
	var uses := Skills.uses_left(unit)
	if uses == 0:
		return "使い切った"
	var state := "使える" if unit.skill_cooldown == 0 else "あと %d ターン" % unit.skill_cooldown
	return state if uses < 0 else "%s。残り %d 回" % [state, uses]


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


## 画面の中央に、しばらくだけ大きな文字を出す。
func show_banner(text: String, color: Color) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color.lightened(0.4))
	_banner.modulate.a = 1.0
	_banner.visible = true
	if _banner_tween != null:
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_interval(0.9)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.5)
	_banner_tween.tween_callback(_banner.hide)


## 画面の中央の大きな文字が出ているか（スクリーンショットの道具が、消えるのを待つ）。
func is_banner_shown() -> bool:
	return _banner.visible


## 画面の中央の大きな文字を、すぐに消す（時間を止めて読む画面を開いたとき、止まったまま残らないように）。
func hide_banner() -> void:
	if _banner_tween != null:
		_banner_tween.kill()
	_banner.visible = false


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
	for which: Unit.Stat in Names.STAT_NAMES:
		if bonuses.has(which):
			var stat_name: String = "回復" if healer and which == Unit.Stat.POWER else Names.STAT_NAMES[which]
			parts.append("%s %+d" % [stat_name, bonuses[which]])
	var text := "%s\n%s" % [Evolution.display_name(id), "　".join(parts)]
	for which in Evolution.traits(id):
		text += "\n★ %s" % Names.TRAIT_TEXTS[which]
	return text


## 進化先の選択肢を出す。texts は選択肢ごとの説明（evolution_text）。
func show_evolution(title: String, texts: Array[String]) -> void:
	_evolution_title.text = title
	for i in _evolution_buttons.size():
		_evolution_buttons[i].visible = i < texts.size()
		if i < texts.size():
			_evolution_buttons[i].text = texts[i]
	_evolution.visible = true


func hide_evolution() -> void:
	_evolution.visible = false


## 進化先の選択肢を出しているか。検査用。
func is_evolution_shown() -> bool:
	return _evolution.visible


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
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	_turn_label = _label(20)
	row.add_child(_turn_label)
	_phase_label = _label(20)
	row.add_child(_phase_label)
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
		bar.custom_minimum_size = Vector2(84.0, 22.0)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.show_percentage = false
		var fill := StyleBoxFlat.new()
		fill.bg_color = _team_colors[player].lightened(0.2)
		bar.add_theme_stylebox_override("fill", fill)
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
	_opponent_button.tooltip_text = "押すと、相手を CPU にするか人にするかを切り替える"
	row.add_child(_opponent_button)
	# ログは、いつでも開ける（相手の番や中立のフェーズで起きたことを、あとから確かめる）。
	var log_button := _button("ログ", log_pressed)
	log_button.custom_minimum_size = Vector2(64.0, 30.0)
	log_button.add_theme_font_size_override("font_size", 15)
	log_button.tooltip_text = "対戦で起きたことを、ターンごとにさかのぼって読む"
	row.add_child(log_button)
	# 右端は、システムメニューのボタン（system_menu.gd。別の層に置く）のぶんを空けておく。
	var corner := Control.new()
	corner.custom_minimum_size = Vector2(SystemMenu.CORNER_BUTTON_SIZE.x + SystemMenu.CORNER_MARGIN, 0.0)
	corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(corner)

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
	help.text = "視点: ドラッグで回転・傾き　ホイールで拡大　WASD で移動"
	help.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	help.add_theme_constant_override("outline_size", 0)
	help_panel.add_child(help)


func _build_info_panel() -> void:
	_info_panel = _panel()
	_info_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_info_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_info_panel.offset_left = 10.0
	_info_panel.offset_right = 10.0
	_info_panel.offset_top = -BOTTOM_BAR_HEIGHT - 8.0
	_info_panel.offset_bottom = -BOTTOM_BAR_HEIGHT - 8.0
	_info_panel.custom_minimum_size = Vector2(INFO_WIDTH + 20.0, 0.0)
	# 盤面の隅に重なるので、下のマスを選べるよう、マウスは素通しにする。
	_info_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_panel.visible = false
	add_child(_info_panel)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 入れ物は既定でマウスを拾うので、こちらも素通しにする
	_info_panel.add_child(column)
	_info_name = _label(20)
	column.add_child(_info_name)
	_info_side = _label(14)
	_info_side.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	column.add_child(_info_side)
	# HP の棒（駒の頭の上には出さないので、ここで割合が分かるようにする）。
	_info_hp = ProgressBar.new()
	_info_hp.custom_minimum_size = Vector2(0.0, 10.0)
	_info_hp.show_percentage = false
	_info_hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_hp_fill = StyleBoxFlat.new()
	_info_hp.add_theme_stylebox_override("fill", _info_hp_fill)
	column.add_child(_info_hp)
	_info_stats = _label(17)
	column.add_child(_info_stats)
	# 状態は、残りの期間と効果。付いている間だけ（盤の上では、足元の水色の輪だけで分かる）。
	_info_statuses = _info_line(column, 15, COLOR_STATUS)
	_info_items = _info_line(column, 15, Color("e6e6e6"))
	_info_skill = _info_line(column, 15, Color("e6e6e6"))
	_info_skill_note = _info_line(column, 14, COLOR_TEXT_DIM)
	_info_traits = _info_line(column, 15, COLOR_TRAIT)
	_info_state = _info_line(column, 14, COLOR_TEXT_DIM)
	_info_forecast = _label(17)
	_info_forecast.add_theme_color_override("font_color", COLOR_FORECAST)
	# スキルの説明のように長い文は、枠の幅で折り返してから出す（_set_folded。枠を横に広げて盤面を隠さない）。
	column.add_child(_info_forecast)


func _info_line(column: VBoxContainer, font_size: int, color: Color) -> Label:
	var label := _label(font_size)
	label.add_theme_color_override("font_color", color)
	label.visible = false
	column.add_child(label)
	return label


func _build_bottom() -> void:
	var panel := _panel()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.custom_minimum_size = Vector2(0.0, BOTTOM_BAR_HEIGHT)
	add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(column)
	# いまできること。長ければ 2 行まで折り返す（ボタンを画面の外へ押し出さない）。
	_hint_label = _label(17)
	_hint_label.max_lines_visible = 2
	_hint_label.clip_text = true
	column.add_child(_hint_label)
	_cell_label = _label(14)
	_cell_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_cell_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	column.add_child(_cell_label)

	# 駒に属さない操作は、いつも同じ場所（右下）に置く。
	# 敵の全員の脅威範囲の切り替え。入・切が見て分かるよう、スイッチの形にする。
	_threat_button = CheckButton.new()
	_threat_button.text = "敵の攻撃範囲"
	_threat_button.focus_mode = Control.FOCUS_NONE
	_threat_button.add_theme_font_size_override("font_size", 17)
	_threat_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_threat_button.tooltip_text = "敵が次の番に攻撃を届かせうるマスを、赤い斜線で重ねて出す"
	_threat_button.pressed.connect(threat_toggled.emit)
	row.add_child(_threat_button)
	_ult_button = _button("必殺技", ult_pressed)
	_ult_button.custom_minimum_size = Vector2(250.0, 48.0)
	_ult_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_ult_button.disabled = true
	_ult_button.mouse_entered.connect(_show_ult_summary)
	_ult_button.mouse_exited.connect(_show_ult_summary)
	row.add_child(_ult_button)
	# ターン終了は、見つけやすいよう色を付けて、いちばん端に置く（駒のそばのメニューからは離れている）。
	_end_turn_button = _button("ターン終了", end_turn_pressed)
	_end_turn_button.custom_minimum_size = Vector2(230.0, 60.0)
	_end_turn_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_end_turn_button.add_theme_font_size_override("font_size", 20)
	_end_turn_style = StyleBoxFlat.new()
	_end_turn_style.bg_color = COLOR_END_TURN
	_end_turn_style.set_corner_radius_all(6)
	_end_turn_style.set_content_margin_all(6.0)
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


## 戦闘予測のパネル。中身は show_forecast()、置き場所は place_forecast() で決める。
func _build_forecast() -> void:
	_forecast = ForecastPanel.new()
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
	_menu = _panel(COLOR_PANEL_SOLID)
	(_menu.get_theme_stylebox("panel") as StyleBoxFlat).set_content_margin_all(5.0)
	_menu.visible = false
	add_child(_menu)
	_menu_column = VBoxContainer.new()
	_menu_column.add_theme_constant_override("separation", 3)
	_menu.add_child(_menu_column)


func _build_banner() -> void:
	_banner = _label(44)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.position.y = 150.0
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_constant_override("outline_size", 12)
	_banner.visible = false
	add_child(_banner)


## 進化先の選択肢（飾らない 2 つのボタン）。盤面が見えるよう、画面の上寄りに出す。
func _build_evolution() -> void:
	var panel := _panel()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.position.y = 70.0
	panel.visible = false
	add_child(panel)
	_evolution = panel
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	_evolution_title = _label(22)
	_evolution_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_evolution_title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	column.add_child(row)
	for i in 2:
		var button := _button("", Signal())
		button.custom_minimum_size = Vector2(330.0, 110.0)
		button.pressed.connect(func() -> void: evolution_chosen.emit(i))
		row.add_child(button)
		_evolution_buttons.append(button)


func _panel(color := COLOR_PANEL) -> PanelContainer:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10.0)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _label(font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
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


## マスの説明に出す、盤の上の効果の種類と簡易説明（持ち主、残り、効果）。
static func field_effect_text(effect: FieldEffect) -> String:
	var owner: String = Names.SIDE_NAMES[effect.side]
	match effect.type:
		FieldEffect.Type.BARRICADE:
			return "盾（%s。耐久 %d / 通行・射撃を遮断）" % [owner, effect.durability]
		FieldEffect.Type.SMOKE:
			return "煙幕（%s。残り %d ターン / 中の味方への、離れたところからの攻撃を無効）" % [owner, effect.turns_left]
		_:
			return "聖域（%s。残り %d ターン / 自分の番の始めに中の味方が HP %d 回復）" % [
				owner, effect.turns_left, FieldEffects.SANCTUARY_HEAL,
			]
