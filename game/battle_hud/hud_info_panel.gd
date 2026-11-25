extends "res://game/battle_hud/hud_menu.gd"
## 対戦の画面の左下の枠: 駒のステータスの札とマスの札（info_card.gd）、範囲を表示したままのスイッチ、詳細のボタン。


## 駒の情報を出す。unit が null なら消す。state は行動の状態と、いるマスのこと。note は、そのときに読むべき説明
## （メニューの項目の説明、スキルの対象を選んでいるときの見込み。無ければ空）。
## skill_note が真なら、スキルの札に説明も出す（note のほうにスキルの説明を出すときは、偽にして重ねない）。
##
## 中身は、ステータスの札（info_card.gd）: 額・名前・札（所属・役割・軍・レベル）→ 能力値の行（HP・攻撃・移動・射程の棒と粒）と経験値 →
## 状態・特性の札 → スキルの札 → 持ち物の枠 → 行動の状態 → note の札。「詳細」で開くステータスの窓と同じ部品。
func show_unit(unit: Unit, state: String, note: String, skill_note := true) -> void:
	_info_panel.visible = unit != null
	_info_pin.visible = false  # 出すときは、このあとに set_pin_switch
	_info_detail.visible = false  # 出すときは、このあとに set_detail_button
	if unit == null:
		return
	var tint := _side_color(unit.side)
	_edge_info_panel(tint.lightened(0.15))
	var army: UnitKind.Army = side_armies[unit.side] if unit.side >= 0 and unit.side < side_armies.size() else UnitKind.Army.NONE
	var sheet: UnitSheet = UnitSheet.of_unit(unit, army, skill_state_text(unit, battle),
			unit_looks.get(unit.id, king_looks[unit.side] if unit.side < king_looks.size() else &""))
	var level := ""
	var experience: Array = []
	if Growth.can_grow(unit):
		if unit.level >= Growth.MAX_LEVEL:
			level = Text.t("battle.hud.level_max", {"level": unit.level})
		else:
			level = Text.t("deck.sheet.level", {"level": unit.level})
			experience = [unit.experience, Growth.EXPERIENCE_PER_LEVEL]
	var chips: Array = []
	for which: Evolution.Trait in Evolution.Trait.values():  # 進化先と持ち物の、どちらが与えた特性も（重ねても 1 つ）
		if unit.has_trait(which):
			chips.append([Text.t("battle.hud.trait", {"trait": Names.trait_text(which)}), COLOR_TRAIT])
	# 行動の状態（「未行動」など。state の 1 行目）は名前の右の札に、いるマスなどの残りは、札の下の小さな行に。
	var lines := state.split("\n", false)
	var action := ""
	if not lines.is_empty() and not lines[0].begins_with(Text.t("battle.unit.on_cell", {"terrain": ""})) and lines[0].length() <= ACTION_TAG_CHARS:
		action = lines[0]
		lines.remove_at(0)
	_info_card.show_unit(sheet, unit_title(unit), tint, side_tag(unit, viewer_side), level, experience, chips, action, "\n".join(lines), note, skill_note)
	_info_is_unit = true
	_fit_info()


## 駒の名前の欄の文。進化した駒は、進化先の名前と、元の種類（「アークブレード（スペルブレード）」）。
static func unit_title(unit: Unit) -> String:
	if unit.evolution != Evolution.Id.NONE:
		return Text.t("battle.hud.name_evolved", {"unit": Names.unit(unit), "kind": Names.kind(unit.kind)})
	return Names.unit(unit)


## 駒の所属の札の文。対戦モードは、盤を見ている人（viewer）から見た「自軍」「敵軍」「中立」。
## ストーリーは、遊ぶ人の側から「味方」「敵」（names.gd の story_sides）。
static func side_tag(unit: Unit, viewer: Unit.Side) -> String:
	if unit.side == Unit.Side.NEUTRAL:
		return Text.t("battle.hud.tag.neutral")
	if Names.story_sides:
		return Names.side(unit.side)
	return Text.t("battle.hud.tag.own" if unit.side == viewer else "battle.hud.tag.foe")


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


## クリックしたマスの情報を、駒の情報と同じ枠に出す。title は見出し（マスの位置と地形）、body は説明
## （項目の名前の行と、字下げした説明の行。BattleTexts.cell_body）。項目ごとに 1 枚の札にする。
func show_cell_info(title: String, body: String) -> void:
	_info_panel.visible = true
	_info_pin.visible = false
	_info_detail.visible = false
	_edge_info_panel(Palette.BORDER)
	var indent := Text.t("battle.cell.indent", {"text": ""})
	var entries: Array = []
	for line in body.split("\n", false):
		if line.begins_with(indent) and not entries.is_empty():
			(entries[-1][1] as Array).append(line.trim_prefix(indent))
		else:
			entries.append([line, []])
	_info_card.show_cell(title, [] as Array[String], entries)
	_info_is_unit = false
	_fit_info()


## 駒の情報の枠の「範囲を表示したまま」のスイッチ。shown で出すか、pinned で入っているか（show_unit のあとに呼ぶ）。
func set_pin_switch(shown: bool, pinned: bool) -> void:
	_info_pin.visible = shown and _info_panel.visible
	_info_pin.set_pressed_no_signal(pinned)
	_fit_info()


## 駒の情報の枠の「詳細」のボタンを出すか（show_unit のあとに呼ぶ。枠が出ていなければ出さない）。
func set_detail_button(shown: bool) -> void:
	_info_detail.visible = shown and _info_panel.visible and _info_is_unit
	_fit_info()


## 「詳細」のボタンを出しているか。検査用。
func detail_button_shown() -> bool:
	return _info_detail.visible


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


## 情報の枠の中身を、枠の高さに収める（枠は伸ばさない）。中身かボタンの出し入れが変わるたびに呼ぶ。
## 入りきらなければ、後で読めるものから順に省く（info_card.gd の fit。「詳細」の窓で全部読める）。
func _fit_info() -> void:
	if _info_panel.visible:
		_info_card.fit(_info_room_height())


## 札に使える高さ: 枠の高さから、縁の余白と、下のボタンの行（出しているときだけ）を引いた残り。
func _info_room_height() -> float:
	var foot := _info_foot.get_combined_minimum_size().y + INFO_FOOT_GAP if _info_pin.visible or _info_detail.visible else 0.0
	return INFO_HEIGHT - _info_style.get_minimum_size().y - foot


## 入りきらずに省いた欄の数と、それでも下が切れているか。検査用（字は小さくしないので、info_shrink はいつも 0）。
func info_shrink() -> int:
	return 0


func info_dropped() -> int:
	return _info_card.dropped()


func is_info_cut() -> bool:
	return _info_panel.visible and _info_card.is_cut(_info_room_height())


## 情報の枠の中身が、枠の幅からはみ出している量（px。0 以下なら収まっている）。検査用。
func info_overflow() -> float:
	return _info_card.overflow()


## 駒の情報の枠に出している文（見出しを除く。欄ごとに 1 行。出ていなければ空）。検査用。
func info_text() -> String:
	return _info_card.text() if _info_panel.visible else ""


## 駒の情報の枠に出している見出し（出ていなければ空）。検査用。
func info_title() -> String:
	return _info_card.heading() if _info_panel.visible else ""


## HP の割合（0〜1）の色。半分より多ければ緑、4 分の 1 より多ければ黄、それより少なければ赤。
static func hp_color(ratio: float) -> Color:
	return Palette.hp(ratio)


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
	_info_panel.clip_contents = true
	Steady.mark(_info_panel, "battle.info", Steady.RECT)
	# 盤面の隅に重なるので、下のマスを選べるよう、マウスは素通しにする。
	_info_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_panel.visible = false
	add_child(_info_panel)
	# 札は上に、ボタンの行は下に寄せる（枠は下にそろうので、中身が変わってもボタンは動かない）。札の高さで枠を伸ばさない。
	var room := Control.new()
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_panel.add_child(room)
	_info_card = InfoCard.new(INFO_WIDTH)
	_info_card.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	room.add_child(_info_card)
	_info_foot = HBoxContainer.new()
	_info_foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_foot.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_info_foot.grow_vertical = Control.GROW_DIRECTION_BEGIN
	room.add_child(_info_foot)
	# 枠は素通しだが、スイッチとボタンはクリックを受ける。左に「範囲を表示したまま」、右に「詳細」。
	_info_pin = CheckButton.new()
	_info_pin.text = Text.t("battle.hud.pin")
	_info_pin.focus_mode = Control.FOCUS_NONE
	_info_pin.add_theme_font_size_override("font_size", 14)
	_info_pin.visible = false
	_info_pin.pressed.connect(pin_toggled.emit)
	_info_foot.add_child(_info_pin)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_foot.add_child(spacer)
	# 「詳細」: 見ている駒・選んでいる駒のステータスの窓（unit_detail.gd）を開く。控えめなボタンで、右に寄せる。
	_info_detail = _button(Text.t("battle.hud.detail"), detail_pressed)
	_info_detail.theme_type_variation = UiTheme.BUTTON_GHOST
	_info_detail.add_theme_font_size_override("font_size", 14)
	_info_detail.custom_minimum_size = Vector2(88.0, 30.0)
	_info_detail.visible = false
	_info_foot.add_child(_info_detail)
