extends "res://game/battle_hud/hud_bottom_bar.gd"
## 対戦の画面に重ねて出すもの: 画面の光、中央の知らせの帯、始めの知らせ、決着の画面、進化先の選択、ミニマップ。


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


## 画面の中央に、しばらくだけ大きな文字を、color の帯（banner_band.gd）で出す。strong は強い知らせ（必殺技）。
func show_banner(text: String, color: Color, strong := false) -> void:
	_banner.play(text, color, strong)


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


func _build_minimap() -> void:
	_minimap = Minimap.new()
	_minimap.team_colors = _team_colors
	add_child(_minimap)


## 対戦の始めの「対戦ルール」（docs/battle-view.md の「対戦ルール」）。盤の上寄りの真ん中に、決まった大きさで出す。
## 勝利条件の札の段（NOTICE_GOALS 枚まで。多い分は出さない）と、縫い目の様子の札の段（あれば）。札は決まった大きさで、真ん中に寄せて並べる（少なくても間延びしない）。
## 閉じるボタン、枠のクリック、盤のクリック、Enter・Space・Esc で閉じる（screen_input.gd）。
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
	_notice.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			hide_notice()
			_notice.accept_event())
	add_child(_notice)
	Steady.mark(_notice, "battle.rule_notice", Steady.RECT)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice.add_child(column)
	var title := _label(20)
	title.text = Text.t("battle.notice.title")
	UiTheme.style_window_title(title, 20)
	column.add_child(title)
	column.add_child(UiTheme.window_rule(Palette.BORDER_BRIGHT))
	# 札の塊は、見出しの下と閉じるボタンの上の間の、真ん中に置く。
	var middle := VBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.alignment = BoxContainer.ALIGNMENT_CENTER
	middle.add_theme_constant_override("separation", 6)
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(middle)
	middle.add_child(_notice_caption(Text.t("battle.notice.goals")))
	var goals := HBoxContainer.new()
	goals.alignment = BoxContainer.ALIGNMENT_CENTER
	goals.add_theme_constant_override("separation", 10)
	goals.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.add_child(goals)
	for i in NOTICE_GOALS:
		var card := RuleCard.new()
		card.visible = false
		goals.add_child(card)
		_notice_goals.append(card)
	_notice_signs_caption = _notice_caption(Text.t("battle.notice.signs"))
	middle.add_child(_notice_signs_caption)
	var signs := HBoxContainer.new()
	signs.alignment = BoxContainer.ALIGNMENT_CENTER
	signs.add_theme_constant_override("separation", 10)
	signs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.add_child(signs)
	_notice_signs_row = signs
	for i in Seam.DRAWN:
		var card := RuleCard.new()
		card.visible = false
		signs.add_child(card)
		_notice_signs.append(card)
	var close := _button(Text.t("battle.notice.close"), Signal())
	close.custom_minimum_size = Vector2(120.0, 32.0)
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.pressed.connect(hide_notice)
	column.add_child(close)


## 「対戦ルール」の段の見出し（小さな金の字。真ん中）。
func _notice_caption(text: String) -> Label:
	var caption := _label(14)
	caption.text = text
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_color_override("font_color", Palette.GOLD)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return caption


## 「対戦ルール」を出す（cards は BattleTexts.rule_cards の札。空なら出さない）。
func show_notice(cards: Array[Array]) -> void:
	var goals := cards.filter(func(card: Array) -> bool: return card[0] == &"goal")
	var signs := cards.filter(func(card: Array) -> bool: return card[0] == &"sign")
	for i in _notice_goals.size():
		_notice_goals[i].visible = i < goals.size()
		if i < goals.size():
			_notice_goals[i].show_goal(goals[i][1], goals[i][2], goals[i][3])
	for i in _notice_signs.size():
		_notice_signs[i].visible = i < signs.size()
		if i < signs.size():
			_notice_signs[i].show_sign(signs[i][1], signs[i][2], signs[i][3])
	_notice_signs_caption.visible = not signs.is_empty()
	_notice_signs_row.visible = not signs.is_empty()
	_notice.visible = not cards.is_empty()


func hide_notice() -> void:
	_notice.visible = false


func notice_open() -> bool:
	return _notice.visible


## 「対戦ルール」の文（出ている札の名前と説明を、1 枚 1 行で。出ていなければ空。検査用）。
func notice_text() -> String:
	if not _notice.visible:
		return ""
	var lines: Array[String] = []
	for card in _notice_goals + _notice_signs:
		if card.visible:
			lines.append(card.shown_text())
	return "\n".join(lines)


## 出ている札のうち、説明の文が欄からはみ出しているものの文（検査用）。
func notice_cut_texts() -> Array[String]:
	var cut: Array[String] = []
	for card in _notice_goals + _notice_signs:
		if card.visible and not card.fits():
			cut.append(card.shown_text())
	return cut


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
