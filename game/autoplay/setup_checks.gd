extends "res://game/autoplay/unit_checks.gd"
## 自動の対戦の場面: 対戦設定の画面、システムメニューとオプション、ミニマップ。


## 対戦設定画面で、後手を選んで CPU と対戦する（CPU が先手で動き出す）。軍とマップも選んだとおりになる。
## 最後に、既定の設定（人が先手）へ戻す。
func _queue_setup_scene() -> void:
	var seen := {"actions": 0}
	_scripted.append(func() -> void:
		_scene.set_opponent(false)
		_scene.open_setup()
		var panel: Node = _scene.setup_panel()
		_expect(panel.visible and _scene.is_busy(), "設定画面が開かない")
		panel.choose_opponent(true)
		panel.choose_human_side(Unit.Side.PLAYER2)
		panel.choose_army(Unit.Side.PLAYER1, UnitKind.Army.FANTASY)
		panel.choose_army(Unit.Side.PLAYER2, UnitKind.Army.MILITARY)
		panel.choose_field(VersusFields.TWIN_SPRINGS)
		seen["actions"] = _scene.cpu_actions
		panel.confirm()
		# CPU（先手）の番の間も、必殺技のボタンは人（後手。MILITARY）のもの。
		_expect(_scene.ult_button_text().contains(Names.ult(Ults.of_army(UnitKind.Army.MILITARY))), "CPU の番に、必殺技のボタンが CPU のものになった: %s" % _scene.ult_button_text()))
	_scripted.append(func() -> void:
		var battle: Battle = _scene.battle
		_expect(not _scene.setup_panel().visible, "設定画面が閉じない")
		_expect(_scene.look == StageLook.CRYSTAL_FOREST, "選んだマップで始まらない")
		_expect(battle.armies == ([UnitKind.Army.FANTASY, UnitKind.Army.MILITARY] as Array[UnitKind.Army]), "選んだ軍で始まらない")
		_expect(_scene.cpu_actions > seen["actions"], "先手の CPU が動かなかった")
		_expect(battle.phase == Unit.Side.PLAYER2 and battle.turn == 1, "先手の CPU が番を終えなかった")
		var panel: Node = _scene.setup_panel()
		# 設定画面を開いて、選び直してから閉じても、いまの対戦と設定はそのまま（始めるボタンを押すまで、何も変わらない）。
		_scene.open_setup()
		_expect(panel.visible and panel.is_cancellable(), "対戦の途中の設定画面を、閉じられない")
		# 対戦の途中で開くと、マップの行に「マップ変更」のボタンと、下に注意の文が増える。それでも画面に収まる。
		_expect(panel.fits_screen(), "対戦の途中で開いた対戦設定のパネルが、画面からはみ出している: %s" % panel.panel_rect())
		panel.choose_field(VersusFields.LABYRINTH)
		panel.choose_opponent(false)
		panel.cancel()
		_expect(not panel.visible and not _scene.is_busy(), "設定画面が閉じない")
		_expect(_scene.battle == battle and _scene.look == StageLook.CRYSTAL_FOREST and _scene.cpu_opponent, "設定画面を閉じたら、対戦か設定が変わった")
		# 押すと対戦が終わるボタンは、2 回押させる（1 回目と、直後の 2 回目では終わらない。右クリックで確かめだけをやめる）。
		_scene.open_setup()
		for press: StringName in [&"press_map", &"press_start"]:
			panel.call(press)
			_expect(panel.visible and panel.confirming_text() != "", "%s の 1 回目で、確かめずに進んだ" % press)
			panel.call(press)
			_expect(panel.visible and _scene.battle == battle, "%s の確かめの直後の 2 回目で、対戦が終わった" % press)
			var right := InputEventMouseButton.new()
			right.button_index = MOUSE_BUTTON_RIGHT
			right.pressed = true
			panel._input(right)
			_expect(panel.visible and panel.confirming_text() == "", "右クリックで、%s の確かめがやめにならない" % press)
		panel.press_start()
		panel.press_map()  # ほかのボタンを押すと、そちらの確かめに変わる
		panel.pass_confirm_guard()
		panel.press_start()
		_expect(panel.visible and _scene.battle == battle, "別のボタンの確かめの間に、新しい対戦が始まった")
		panel.cancel()
		_expect(_scene.battle == battle and not panel.visible, "確かめの途中で閉じたら、対戦が変わった")
		# 手で作ったマップ（対戦モードで選べるもの）でも始まる。「新しいマップ」は生成のマップだけ（同じマップは形が変わらない）。
		# 画面に出していない（釣り合いがめやすを外れる）マップでも、入口は同じ。
		for field in VersusFields.all_ids():
			if VersusFields.is_generated(field):
				continue
			_scene.open_setup()
			panel.choose_field(field)
			panel.choose_opponent(false)  # 先手の CPU が動き出すと、次の設定画面が開けない
			panel.confirm()
			var expected := VersusFields.card_board(field, 0)
			_expect(_scene.battle.board.size == expected.size and _scene.battle.board.hq_cells == expected.hq_cells, "手で作ったマップで始まらない: %s" % field)
			_expect(_scene.look == VersusFields.look_of(field), "手で作ったマップの見た目にならない: %s" % field)
			_expect(_scene.source.new_board_fields() == VersusFields.generated_ids(), "手で作ったマップの対戦の「新しいマップ」が、生成のマップでない")
		# CPU の部隊を「ランダム編成」にすると、対戦の種から組んだ部隊で始まる。設定パネルの「編成確認」で、いまの部隊が見える。
		# 「同じマップで再戦」は同じ部隊、「新しいマップ」は新しい部隊（どちらも、ランダム編成のまま引き継ぐ）。
		_scene.open_setup()
		panel.choose_field(VersusFields.PLAIN)
		panel.choose_opponent(true)
		panel.choose_human_side(Unit.Side.PLAYER1)  # CPU は後手（始めてすぐには動かない）
		panel.choose_army(Unit.Side.PLAYER2, UnitKind.Army.FANTASY)
		_expect(panel.choose_deck(Unit.Side.PLAYER2, MatchChoice.RANDOM), "CPU の行で「ランダム編成」を選べない")
		panel.confirm()
		_expect(_cpu_kinds(Unit.Side.PLAYER2) == _squad_kinds(RandomSquad.for_battle(UnitKind.Army.FANTASY, _scene.map_seed, Unit.Side.PLAYER2)),
			"「ランダム編成」の CPU が、種から組んだ部隊で始まらない")
		var drawn := _cpu_kinds(Unit.Side.PLAYER2)
		_scene.open_setup()
		_expect(panel.current_choice().is_random(Unit.Side.PLAYER2) and panel.can_preview(Unit.Side.PLAYER2), "対戦の途中の設定パネルで、「ランダム編成」の部隊を確認できない")
		panel.open_preview(Unit.Side.PLAYER2)
		_expect(panel.preview().visible and panel.preview().shown_kinds().size() == drawn.size() + 1, "「編成確認」に、いまの対戦の「ランダム編成」の部隊が出ない")
		# 相手の部隊の札も、押すと詳しい説明が出る。右クリックで説明だけ閉じる。
		panel.preview().press_card(0)
		var detail: Control = panel.preview().detail()
		var first_kind: UnitKind.Id = panel.preview().shown_kinds()[1]
		_expect(detail.visible and detail.title_text() == Names.kind(first_kind) and detail.body_text().contains("スキル") == (Skills.of_kind(first_kind) != null),
			"対戦の途中の「編成確認」で、相手の駒の札を押しても詳しい説明が出ない: %s" % detail.title_text())
		var right := InputEventMouseButton.new()
		right.button_index = MOUSE_BUTTON_RIGHT
		right.pressed = true
		panel.get_viewport().push_input(right)
		_expect(not detail.visible and panel.preview().visible, "詳しい説明を右クリックで閉じると、編成確認まで閉じる（か、説明が閉じない）")
		panel.preview().close_preview()
		panel.cancel()
		_scene.start_battle(_scene.map_seed)  # 決着の画面の「同じマップで再戦」と同じ入口
		_expect(_cpu_kinds(Unit.Side.PLAYER2) == drawn, "「同じマップで再戦」で、「ランダム編成」の部隊が変わった")
		var changed := false
		for i in 3:  # 「新しいマップ」（種が替わる）。たまたま同じ部隊になることもあるので、何度か
			_scene.start_on_field(VersusFields.PLAIN, _scene.map_seed + 1)
			_expect(_scene.source.is_random(Unit.Side.PLAYER2), "「新しいマップ」で、「ランダム編成」が引き継がれない")
			_expect(_cpu_kinds(Unit.Side.PLAYER2) == _squad_kinds(RandomSquad.for_battle(UnitKind.Army.FANTASY, _scene.map_seed, Unit.Side.PLAYER2)),
				"「新しいマップ」の「ランダム編成」が、新しい種から組んだ部隊でない")
			changed = changed or _cpu_kinds(Unit.Side.PLAYER2) != drawn
		_expect(changed, "「新しいマップ」で、「ランダム編成」の部隊が変わらない")
		_scene.open_setup()
		panel.choose_deck(Unit.Side.PLAYER2, "")
		_scene.open_setup()
		panel.choose_opponent(false)
		panel.choose_human_side(Unit.Side.PLAYER1)
		panel.choose_army(Unit.Side.PLAYER1, UnitKind.Army.MILITARY)
		panel.choose_army(Unit.Side.PLAYER2, UnitKind.Army.FANTASY)
		panel.choose_field(VersusFields.PLAIN)
		var before: Battle = _scene.battle
		panel.press_start()  # 対戦の途中なので、確かめてから（間を置いた 2 回目で）始める
		_expect(_scene.battle == before, "「新しい対戦を始める」の 1 回目で、新しい対戦が始まった")
		panel.pass_confirm_guard()
		panel.press_start()
		_expect(_scene.battle != before and not panel.visible, "「新しい対戦を始める」の 2 回目で、新しい対戦が始まらない")
		_expect(not _scene.cpu_opponent and _scene.source.cpu_side() == Unit.Side.PLAYER2, "既定の設定に戻らない"))
	# 何も選び直せない対戦（battle_source.gd の既定の答え。ストーリーの 1 話も、マップ・相手・対戦設定は選び直せない）を渡すと、選び直す入口が出ない。
	var kept := {}
	_script_fixed_source(kept)


## いまの対戦の、side の駒（将を除く）の種類の並び（小さい順）。
func _cpu_kinds(side: Unit.Side) -> Array:
	var kinds: Array = _scene.battle.units.filter(func(unit: Unit) -> bool: return unit.side == side and unit.kind != UnitKind.Id.KING).map(func(unit: Unit) -> int: return unit.kind)
	kinds.sort()
	return kinds


## 部隊 deck の駒の種類の並び（小さい順）。
func _squad_kinds(deck: Deck) -> Array:
	var kinds: Array = deck.entries.map(func(entry: DeckEntry) -> int: return entry.kind)
	kinds.sort()
	return kinds


func _script_fixed_source(kept: Dictionary) -> void:
	_scripted.append(func() -> void:
		kept["source"] = _scene.source
		_scene.source = FixedSource.new()
		_scene.start_battle(_scene.map_seed + 1)
		var battle: Battle = _scene.battle
		_expect(_scene.look == StageLook.STONE_WALLS and battle.board.size == BoardGenerator.DEFAULT_SIZE, "渡したもので対戦が始まらない")
		_expect(not _scene.cpu_opponent, "渡した対戦設定の、誰が動かすかに従わない")
		_expect(not _scene.opponent_switch_shown(), "切り替えられない対戦に、相手のボタンが出た")
		_scene.toggle_opponent()
		_expect(not _scene.cpu_opponent, "切り替えられない対戦で、相手が切り替わった")
		_expect(_scene.menu_items().is_empty(), "対戦設定を開けない対戦に、システムメニューの「対戦設定へ」が出た")
		_scene.open_setup()
		_expect(not _scene.setup_panel().visible, "対戦設定を開けない対戦で、設定画面が開いた")
		_scene.start_on_field(VersusFields.PLAIN, _scene.map_seed + 1)
		_expect(_scene.battle == battle, "マップを選べない対戦で、マップを替えてやり直した")
		_expect(not _scene.result_screen().can_go_to_setup() and _scene.result_screen().new_board_fields().is_empty(),
			"選び直せない対戦の決着の画面に、対戦設定・新しいマップのボタンがある")
		_scene.source = kept["source"]
		_scene.start_battle(_scene.map_seed + 1)
		_expect(_scene.opponent_switch_shown() and _scene.result_screen().can_go_to_setup()
			and _scene.result_screen().new_board_fields() == VersusFields.generated_ids(), "対戦モードに戻すと、選び直す入口が戻らない"))


## 何も選び直せない対戦を渡すもの（_script_fixed_source）。迷宮回廊の人どうし。
class FixedSource extends "res://game/battle_source.gd":
	func make_setup(battle_seed: int) -> MatchSetup:
		var deck := MatchSetup.default_deck(UnitKind.Army.MILITARY)
		return MatchSetup.versus_human(BoardGenerator.Stage.LABYRINTH, battle_seed, deck, deck.copy())

	func look() -> StringName:
		return StageLook.STONE_WALLS


## システムメニュー。Esc は、戻すもの（選択）があれば戻し、無ければメニューを開く。開いている間は盤面を操作できず、時間が止まる。
## オプションの画面で変えた値は、その場でカメラに効く。ゲームを終える項目は、対戦の途中なら確かめる（ここでは、やめる）。
func _queue_system_menu_scene() -> void:
	var board := _small_board(Vector2i(6, 5))
	var battle := Battle.new(board)
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER1, Vector2i(0, 4))
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER2, Vector2i(5, 0))
	var trooper := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, Unit.Side.PLAYER1, Vector2i(2, 2))
	_scripted.append(func() -> void:
		_scene.set_opponent(false)
		_scene.start_with(battle, StageLook.GRASSLAND, 1))
	_scripted.append(func() -> void:
		var menu: Node = _scene.system_menu()
		var settings: RefCounted = _scene.settings
		var base := Engine.time_scale
		_scene.click_cell(trooper.cell)
		_scene.press_escape()
		_expect(not menu.is_open() and _scene.selected_unit() == null, "選んでいる駒があるのに、Esc で選択をやめずにメニューを開いた")
		_scene.press_escape()
		_expect(menu.is_open() and _scene.is_busy() and Engine.time_scale == 0.0, "戻すものが無いのに、Esc でメニューが開かない（か、止まらない）")
		_expect(menu.item_ids() == ([&"resume", &"settings", &"match_setup", &"exit:map_select", &"title", &"quit"] as Array[StringName]), "メニューの項目が違う: %s" % [menu.item_ids()])
		_scene.click_cell(trooper.cell)
		_expect(_scene.selected_unit() == null, "メニューを開いている間に、駒を選べた")
		# 対戦が失われる項目は、確かめる。「やめる」で、メニューへ戻る。
		menu.press(&"quit")
		_expect(menu.confirming() == &"quit" and menu.confirm_text() != "", "ゲームを終える前に、確かめない")
		menu.back()
		_expect(menu.is_open() and menu.confirming() == &"", "確かめを、やめられない")
		# 設定の値は、その場で効く。
		menu.press(&"settings")
		_expect(menu.is_settings_open(), "オプションの画面が開かない")
		settings.set_value(&"mouse_sensitivity", 200)
		settings.set_value(&"invert_vertical_drag", true)
		var drag: Array = _scene.camera_drag_settings()
		_expect(is_equal_approx(drag[0], 2.0 * OrbitCamera.DEFAULT_DRAG_SENSITIVITY) and drag[1], "設定の値がカメラに効かない")
		settings.reset_all()
		drag = _scene.camera_drag_settings()
		_expect(is_equal_approx(drag[0], OrbitCamera.DEFAULT_DRAG_SENSITIVITY) and not drag[1], "既定に戻せない")
		menu.back()
		_expect(menu.is_open() and not menu.is_settings_open(), "オプションの画面から、メニューへ戻らない")
		menu.back()
		_expect(not menu.is_open() and not _scene.is_busy() and Engine.time_scale == base, "メニューを閉じても、元の速さに戻らない")
		# CPU の駒の行動を再生する間だけ、設定の速さを掛ける。
		settings.set_value(&"cpu_playback_speed", 3)
		_scene.set_cpu_fast(true)
		_expect(is_equal_approx(Engine.time_scale, base * 3.0), "CPU の番の速さが効かない")
		_scene.set_cpu_fast(false)
		settings.reset_all()
		_expect(Engine.time_scale == base, "CPU の番の速さが残った"))


## ミニマップ: 画面に収まって帯と重ならない、押すとその場所へ視点が移る（ドラッグは付いてきて、盤の外へは出ない）、
## 設定で隠すと消え、戻すと出る。
func _queue_minimap_scene() -> void:
	var board := _small_board(Vector2i(12, 10))
	var battle := Battle.new(board)
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER1, Vector2i(0, 9))
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER2, Vector2i(11, 0))
	# 軍を持たせて、上の帯に必殺技のゲージを出す（ゲージのぶん、陣営の欄が狭くなる）。
	battle.add_unit(UnitKind.Id.SNIPER, Unit.Side.PLAYER1, Vector2i(1, 9))
	battle.add_unit(UnitKind.Id.SORCERER, Unit.Side.PLAYER2, Vector2i(10, 0))
	battle.turn = 99  # 上の帯のターンの文がいちばん長いとき
	battle.traits = [Traits.Id.FOCUS, Traits.Id.VENGEANCE]  # 部隊の特徴の札（印と名前）も出す
	_scripted.append(func() -> void:
		_scene.set_opponent(true)  # 「相手: CPU」（「相手: 人」より幅を取る）。プレイヤー1 の番なので、CPU は動かない
		_scene.start_with(battle, StageLook.GRASSLAND, 1))
	_scripted.append(func() -> void:
		_expect(_scene.top_bar_cut_texts().is_empty(), "上の帯の陣営の欄（駒の数と占拠）が切れている: %s" % [_scene.top_bar_cut_texts()])
		# 上の帯の特徴の札をクリックすると、その陣営の特徴 1 つの窓（名前・効果・効く相手。選ばなかった特徴は出さない）。
		# もう一度クリックか、盤のクリックで閉じる。相手の札を押すと、相手のものに替わる。
		_scene.toggle_trait_note(0)
		var note: String = _scene.trait_note_text()
		_expect(note.contains(Names.troop_trait(Traits.Id.FOCUS)) and note.contains(Names.troop_trait_effect(Traits.Id.FOCUS))
			and note.contains(Names.troop_trait_when(Traits.Id.FOCUS)) and not note.contains(Names.troop_trait(Traits.Id.RANKS)),
			"上の帯の特徴の札で、特徴の窓が開かない（か、中身が違う）: %s" % note)
		var screen_rect: Rect2 = _scene.get_viewport().get_visible_rect()
		_expect(screen_rect.encloses(_scene.trait_note_rect()) and _scene.trait_note_rect().position.y >= BattleHud.TOP_BAR_HEIGHT,
			"特徴の窓が、画面からはみ出すか上の帯に重なる: %s" % _scene.trait_note_rect())
		_scene.toggle_trait_note(1)
		_expect(_scene.trait_note_text().contains(Names.troop_trait(Traits.Id.VENGEANCE)), "相手の特徴の札で、相手の特徴の窓に替わらない")
		_scene.toggle_trait_note(1)
		_expect(_scene.trait_note_text() == "", "特徴の札をもう一度押しても、窓が閉じない")
		_scene.toggle_trait_note(0)
		_scene.click_cell(Vector2i(5, 5))
		_expect(_scene.trait_note_text() == "", "盤をクリックしても、特徴の窓が閉じない")
		_scene.set_opponent(false)
		var rect: Rect2 = _scene.minimap_rect()
		var screen: Rect2 = _scene.get_viewport().get_visible_rect()
		_expect(rect.has_area() and screen.encloses(rect), "ミニマップが出ていないか、画面からはみ出した: %s" % rect)
		_expect(rect.position.y >= BattleHud.TOP_BAR_HEIGHT and rect.end.y <= screen.size.y - BattleHud.BOTTOM_BAR_HEIGHT, "ミニマップが上か下の帯に重なった: %s" % rect)
		_expect(_scene.minimap_view().size() >= 3, "ミニマップに、見ている範囲が描かれていない")
		# 真ん中を押すと、盤の真ん中を見る。
		_minimap_button(rect.get_center(), true)
		_minimap_button(rect.get_center(), false)
		var center: Vector3 = _scene.camera_center()
		_expect(Vector2(center.x, center.z).distance_to(Vector2(6.0, 5.0)) < 0.6, "ミニマップの真ん中を押しても、盤の真ん中へ移らない: %s" % center)
		# 押したまま右下の外までドラッグすると、付いてきて、盤の端で止まる。離したあとの動きでは動かない。
		_minimap_button(rect.get_center(), true)
		_minimap_motion(rect.end + Vector2(40, 40), true)
		_minimap_button(rect.end + Vector2(40, 40), false)
		center = _scene.camera_center()
		_expect(is_equal_approx(center.x, 12.0) and is_equal_approx(center.z, 10.0), "ミニマップのドラッグが盤の端で止まらない: %s" % center)
		_minimap_motion(rect.position + Vector2(10, 10), false)
		_expect(_scene.camera_center().is_equal_approx(center), "ミニマップで、押していないのに視点が動いた")
		# 設定で隠すと消え、押せない。戻すと出る。
		_scene.settings.set_value(&"show_minimap", false))
	_scripted.append(func() -> void:
		_expect(not _scene.minimap_rect().has_area(), "設定で隠しても、ミニマップが消えない")
		_scene.settings.reset_all())
	_scripted.append(func() -> void:
		_expect(_scene.minimap_rect().has_area(), "設定を戻しても、ミニマップが出ない"))


## ミニマップに、画面の位置 at でのマウスのボタンを入れる（ミニマップが受けるのと同じ道）。
func _minimap_button(at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = at
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	_scene.feed_minimap_input(event)


func _minimap_motion(at: Vector2, held: bool) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	_scene.feed_minimap_input(event)
