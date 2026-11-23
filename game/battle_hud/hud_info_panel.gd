extends "res://game/battle_hud/hud_menu.gd"
## 対戦の画面の左下の枠: 駒の情報とマスの情報（文を縮めて収める、範囲を表示したままのスイッチ、詳細のボタン）。


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
			unit_looks.get(unit.id, king_looks[unit.side] if unit.side < king_looks.size() else &""))
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
	# 組み方（分隊・誓い）。相手の駒も同じように出す（docs/formation.md）。
	_set_shown(_info_formation, "\n".join(FormationText.unit_lines(battle, unit)))

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
	for label: Label in [_info_statuses, _info_formation, _info_items, _info_skill, _info_skill_note, _info_traits, _info_state, _info_forecast]:
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
	for label: Label in [_info_skill_note, _info_traits, _info_items, _info_formation, _info_statuses, _info_state]:
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
	for label: Label in [_info_side, _info_stats, _info_statuses, _info_formation, _info_items, _info_skill, _info_skill_note, _info_traits, _info_state, _info_forecast]:
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
	_info_formation = _info_line(column, 15, COLOR_FORMATION)
	_info_items = _info_line(column, 15, Palette.TEXT)
	_info_skill = _info_line(column, 15, Palette.TEXT)
	_info_skill_note = _info_line(column, 14, COLOR_TEXT_DIM)
	_info_traits = _info_line(column, 15, COLOR_TRAIT)
	_info_state = _info_line(column, 14, COLOR_TEXT_DIM)
	_info_forecast = _label(17)
	_info_forecast.add_theme_color_override("font_color", COLOR_FORECAST)
	# スキルの説明のように長い文は、枠の幅で折り返してから出す（_set_folded。枠を横に広げて盤面を隠さない）。
	column.add_child(_info_forecast)
	for label: Label in [_info_stats, _info_statuses, _info_formation, _info_items, _info_skill, _info_skill_note, _info_traits, _info_state, _info_forecast]:
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
