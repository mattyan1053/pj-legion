extends "res://game/battle_hud/hud_overlays.gd"
## 対戦の画面の、駒のそばのメニュー（と駒を結ぶ線）と、戦闘予測のパネル。


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


## 上の帯のすぐ下に出す、決まった枠（左の勝ち方の札、右の視点の案内）の四角（出ていなければ大きさ 0）。駒のそばのメニューと予測のパネルは、ここに重ねない。
func top_tag_rects() -> Array[Rect2]:
	return [
		_goal_panel.get_global_rect() if _goal_panel.visible else Rect2(),
		_guide_panel.get_global_rect() if _guide_panel.visible else Rect2(),
		_stronghold_panel.get_global_rect() if _stronghold_panel.visible else Rect2(),
		_signs_panel.get_global_rect() if _signs_panel.visible else Rect2(),
	]


## メニューが画面に占める四角（出していなければ大きさ 0）。検査用。
func menu_rect() -> Rect2:
	return Rect2(_menu.position, _menu.get_combined_minimum_size()) if _menu.visible else Rect2()


## メニューを置いてよい範囲（画面から上の帯と下の帯を除いたところ）。
func menu_area() -> Rect2:
	var screen := _menu.get_viewport_rect().size
	return Rect2(4.0, TOP_BAR_HEIGHT + 4.0, screen.x - 8.0, screen.y - TOP_BAR_HEIGHT - BOTTOM_BAR_HEIGHT - bottom_reserved - 8.0)


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
