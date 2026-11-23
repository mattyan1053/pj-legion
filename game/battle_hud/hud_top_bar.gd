extends "res://game/battle_hud/hud_base.gd"
## 対戦の画面の上の帯: ターンと番、陣営の欄（駒の数・聖遺物・必殺技のゲージ）、勝ち方の札、拠点の札、縫い目の様子の札。


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
	_place_signs()
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


## いちばん上の帯に出ている、必殺技のゲージの文字（"62%" か "READY"。出ていなければ空）。検査用。
func ult_gauge_text(player: int) -> String:
	return _ult_labels[player].text if _ult_labels[player].visible else ""


## 拠点の札を出す（選べる決まり「拠点」）。holds は陣営ごとの確保の数（添字がプレイヤー番号）、needed は勝つ数（0 以下なら札を出さない）。
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
	_place_signs()


## 縫い目の様子の札を、上の帯の下の帯に出す（signs は Seam.Sign の並び。空なら出さない）。札ごとに印と名前、マウスを乗せると効果の文。
## 大きさは中身で変えない。勝ち方の札・拠点の札が出ていれば、その下に並べる。
func show_signs(signs: Array[int]) -> void:
	_signs_panel.visible = not signs.is_empty()
	for i in _sign_slots.size():
		var shown := i < signs.size()
		_sign_slots[i].visible = shown
		_sign_marks[i].sign = signs[i] if shown else -1
		_sign_names[i].text = Names.sign_name(signs[i]) if shown else ""
		_sign_slots[i].tooltip_text = Text.t("battle.hud.sign_note", {"name": Names.sign_name(signs[i]), "summary": Names.sign_summary(signs[i])}) if shown else ""
	_place_signs()


## 札の帯の文（札の名前を並べたもの。出ていなければ空。検査用）と、札ごとの、マウスを乗せると出る文。
func signs_text() -> String:
	if not _signs_panel.visible:
		return ""
	var names: Array[String] = []
	for i in _sign_slots.size():
		if _sign_slots[i].visible:
			names.append(_sign_names[i].text)
	return Text.t("common.joiner.dot").join(names)


func sign_notes() -> Array[String]:
	var notes: Array[String] = []
	for slot in _sign_slots:
		if slot.visible:
			notes.append(slot.tooltip_text)
	return notes


func _place_signs() -> void:
	if _signs_panel == null:
		return
	var top := TOP_BAR_HEIGHT + 4.0
	if _goal_panel.visible:
		top += _goal_panel.get_combined_minimum_size().y + 4.0
	if _stronghold_panel.visible:
		top += STRONGHOLD_CHIP_SIZE.y + 4.0
	_signs_panel.offset_top = top
	_signs_panel.size = SIGNS_CHIP_SIZE


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


func _build_top_bar() -> void:
	var panel := _panel()
	_top_style = UiTheme.band_box(true)
	panel.add_theme_stylebox_override("panel", _top_style)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	Steady.mark(panel, "battle.top_band", Steady.RECT)
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

	# 拠点の札（選べる決まり）。勝ち方の札と同じ所（出ていれば、その下）に、決まった大きさで出す。
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

	# 縫い目の様子の札の帯（選べる決まり）。拠点の札の下に、決まった大きさで出す。札 1 枚ごとに印と名前、マウスを乗せると効果の文。
	_signs_panel = PanelContainer.new()
	var signs_style := StyleBoxFlat.new()
	signs_style.set_corner_radius_all(4)
	signs_style.set_border_width_all(1)
	signs_style.bg_color = COLOR_GOAL
	signs_style.border_color = COLOR_GOAL_BORDER
	signs_style.content_margin_left = 8.0
	signs_style.content_margin_right = 8.0
	_signs_panel.add_theme_stylebox_override("panel", signs_style)
	_signs_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_signs_panel.offset_left = 6.0
	_signs_panel.custom_minimum_size = SIGNS_CHIP_SIZE
	_signs_panel.size = SIGNS_CHIP_SIZE
	_signs_panel.clip_contents = true
	_signs_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_signs_panel.visible = false
	add_child(_signs_panel)
	Steady.mark(_signs_panel, "battle.signs_chip")
	var signs_row := HBoxContainer.new()
	signs_row.add_theme_constant_override("separation", 8)
	signs_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_signs_panel.add_child(signs_row)
	for i in Seam.DRAWN:
		var slot := HBoxContainer.new()
		slot.add_theme_constant_override("separation", 6)
		slot.custom_minimum_size = Vector2(SIGN_SLOT_WIDTH, 0.0)
		slot.mouse_filter = Control.MOUSE_FILTER_STOP  # 乗せると効果の文
		signs_row.add_child(slot)
		var mark := SignMark.new(-1, SIGN_MARK_SIDE)
		slot.add_child(mark)
		var name := _label(16)
		name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name.clip_text = true
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name.add_theme_color_override("font_color", COLOR_FORECAST)
		slot.add_child(name)
		_sign_slots.append(slot)
		_sign_marks.append(mark)
		_sign_names.append(name)

	# 視点の動かし方（マウスに割り当てていない平行移動を含む）。キーの印と一語を、小さく 1 行だけ。
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
	var help := KeyMarks.new()
	help.set_parts([
		KeyMarks.key(Text.t("common.key.drag"), Text.t("battle.hud.camera.turn")),
		KeyMarks.key(Text.t("common.key.wheel"), Text.t("battle.hud.camera.zoom")),
		KeyMarks.key(Text.t("common.key.wasd"), Text.t("battle.hud.camera.pan")),
	])
	help_panel.add_child(help)
