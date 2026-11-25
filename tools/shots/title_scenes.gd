extends "res://tools/shots/shot_base.gd"
## スクリーンショットの場面: タイトル、マップ選択、部隊編成、システムメニュー、オプション。


func _scene_title() -> bool:
	await _app.go(SceneFlow.TITLE)
	return _app.current_id() == SceneFlow.TITLE


## タイトルの背景を、景色 look にしたところ。
func _title_scape(look: StringName) -> bool:
	if not await _scene_title():
		return false
	var scapes: Array = _app.current_scene().title_scapes()
	for index in scapes.size():
		if scapes[index][0] == look:
			_app.current_scene().show_scape_at(index)
			return true
	return false


func _scene_title_scape_ruins() -> bool:
	return await _title_scape(StageLook.STONE_WALLS)


func _scene_title_scape_night() -> bool:
	return await _title_scape(StageLook.CRYSTAL_NIGHT)


func _scene_title_scape_barrow() -> bool:
	return await _title_scape(StageLook.BARROW)


func _scene_map_select() -> bool:
	await _app.go(SceneFlow.MAP_SELECT)
	return _app.current_id() == SceneFlow.MAP_SELECT


func _scene_map_hover() -> bool:
	if not await _scene_map_select():
		return false
	_app.current_scene().hover(VersusFields.LABYRINTH)
	_app.current_scene().show_scape_now()  # 背景の景色が、乗せたマップのものに替わるのを待たない
	return _app.current_scene().hovered_field() == VersusFields.LABYRINTH


func _scene_map_hover_pass() -> bool:
	return await _map_hover(VersusFields.BOULDER_PASS)


func _scene_map_hover_twin() -> bool:
	return await _map_hover(VersusFields.TWIN_SPRINGS)


func _map_hover(field: StringName) -> bool:
	if not await _scene_map_select():
		return false
	_app.current_scene().hover(field)
	_app.current_scene().show_scape_now()
	return _app.current_scene().hovered_field() == field


func _scene_title_menu() -> bool:
	await _app.go(SceneFlow.TITLE)
	_app.open_menu()
	return _app.system_menu().is_open()


## 部隊の一覧に、見本の部隊を入れる（検査とスクリーンショットでは、取っておく先が無いので、毎回ここで作る）。
func _fill_decks() -> void:
	var library: RefCounted = _app.context.decks
	library.load_data({"decks": []})
	var first := Deck.new(UnitKind.Army.MILITARY)
	for kind: UnitKind.Id in [UnitKind.Id.SHIELD_TROOPER, UnitKind.Id.SNIPER, UnitKind.Id.SNIPER, UnitKind.Id.COMMANDO, UnitKind.Id.MEDIC]:
		first.add(kind)
	first.entries[0].equip(Equipment.Id.IRON_SHIELD)
	first.entries[0].equip(Equipment.Id.IRON_SHIELD)
	first.entries[3].equip(Equipment.Id.SPEED_BOOTS)
	library.add("狙撃の布陣", first)
	var second := Deck.new(UnitKind.Army.FANTASY)
	for kind: UnitKind.Id in [UnitKind.Id.PALADIN, UnitKind.Id.SPELLBLADE, UnitKind.Id.SPELLBLADE, UnitKind.Id.PRIEST]:
		second.add(kind)
	second.entries[1].equip(Equipment.Id.SPEED_BOOTS)
	library.add("速攻の騎士団", second)
	var third := Deck.new(UnitKind.Army.MILITARY)
	for i in 6:
		third.add(UnitKind.Id.SHIELD_TROOPER)
	third.entries[0].equip(Equipment.Id.IRON_SHIELD)
	library.add("盾の壁（予算の見直し前）", third)


func _deck_scene() -> Node:
	_fill_decks()
	await _app.go(SceneFlow.DECKS)
	return _app.current_scene() if _app.current_id() == SceneFlow.DECKS else null


func _scene_deck_list() -> bool:
	var screen: Node = await _deck_scene()
	if screen == null:
		return false
	screen.select_saved(_app.context.decks.items()[2].id)
	return screen.list_selected() != ""


func _scene_deck_delete() -> bool:
	var screen: Node = await _deck_scene()
	if screen == null:
		return false
	screen.press_delete()
	return screen.is_dialog_open()


func _scene_deck_rename() -> bool:
	var screen: Node = await _deck_scene()
	if screen == null:
		return false
	screen.press_rename()
	return screen.is_dialog_open()


func _scene_deck_army() -> bool:
	var screen: Node = await _deck_scene()
	if screen == null:
		return false
	screen.press_new()
	return screen.is_choosing_army()


func _scene_deck_none() -> bool:
	var screen: Node = await _deck_scene()
	if screen == null:
		return false
	_app.context.decks.load_data({"decks": []})
	screen.show_list()
	return screen.listed_ids().is_empty()


func _scene_deck_empty() -> bool:
	var screen: Node = await _deck_scene()
	if screen == null:
		return false
	screen.press_new()
	screen.choose_new_army(UnitKind.Army.MILITARY)
	return screen.is_editing()


## 組み直す部隊（一覧の最初の部隊）を開く。
func _deck_editor() -> Node:
	var screen: Node = await _deck_scene()
	if screen == null:
		return null
	screen.select_saved(_app.context.decks.items()[0].id)
	screen.press_edit()
	return screen if screen.is_editing() else null


func _scene_deck_built() -> bool:
	var screen: Node = await _deck_editor()
	if screen == null:
		return false
	screen.hover_kind(UnitKind.Id.SNIPER)
	return true


## 騎士領の部隊で、軍略の「誓い」を選び、2 人を結んだところ（単騎の札にマウスを乗せて、文を読んでいる）。
func _scene_deck_trait() -> bool:
	var screen: Node = await _deck_scene()
	if screen == null:
		return false
	screen.press_new()
	screen.choose_new_army(UnitKind.Army.FANTASY)
	for kind: UnitKind.Id in [UnitKind.Id.PALADIN, UnitKind.Id.SORCERER, UnitKind.Id.SPELLBLADE, UnitKind.Id.PRIEST]:
		screen.hire(kind)
	screen.select_entry(-1)
	screen.choose_trait(Traits.Id.OATH)
	screen.press_oath(0)
	screen.press_oath(1)
	screen.hover_trait_card(2)
	return screen.shows_oaths() and not screen.editing_deck().oaths.is_empty()


func _scene_deck_equip() -> bool:
	var screen: Node = await _deck_editor()
	if screen == null:
		return false
	screen.select_entry(3)
	screen.equip(Equipment.Id.SPEED_BOOTS)
	return screen.selected_entry() == 3


func _scene_deck_unit_detail() -> bool:
	var screen: Node = await _deck_editor()
	if screen == null:
		return false
	screen.select_entry(0)
	screen.equip(Equipment.Id.IRON_SHIELD)
	screen.equip(Equipment.Id.IRON_SHIELD)
	screen.equip(Equipment.Id.SPEED_BOOTS)
	screen.press_unit_detail()
	return screen.unit_detail() != null and screen.unit_detail().visible


## 衛生兵（部隊に無ければ、先頭の駒と入れ替えて雇う）の「詳細」。回復役の攻撃が、窓の名前の右と、雇える駒の札の能力の行に出る。
func _scene_deck_healer_detail() -> bool:
	var screen: Node = await _deck_editor()
	if screen == null:
		return false
	var deck: Deck = screen.editing_deck()
	var index := -1
	for i in deck.entries.size():
		if deck.entries[i].kind == UnitKind.Id.MEDIC:
			index = i
	if index < 0:
		screen.remove_entry(0)
		screen.hire(UnitKind.Id.MEDIC)
		index = deck.entries.size() - 1
	screen.select_entry(index)
	screen.press_unit_detail()
	return deck.entries[index].kind == UnitKind.Id.MEDIC and screen.unit_detail() != null and screen.unit_detail().visible


func _scene_deck_over() -> bool:
	var screen: Node = await _deck_editor()
	if screen == null:
		return false
	screen.hire(UnitKind.Id.SHIELD_TROOPER)
	screen.equip(Equipment.Id.IRON_SHIELD)
	screen.equip(Equipment.Id.IRON_SHIELD)
	screen.equip(Equipment.Id.SPEED_BOOTS)
	return not screen.can_save()


## 対戦の途中の盤面を出し、カメラが落ち着いてからシステムメニューを開く（開くと時間が止まる）。
func _open_system_menu() -> bool:
	if not _advance(func() -> bool: return _battle.turn >= 3 and _battle.phase == Unit.Side.PLAYER1):
		return false
	_show()
	await get_tree().create_timer(SETTLE).timeout
	_scene.press_escape()
	return _app.system_menu().is_open()


func _scene_system_menu() -> bool:
	return await _open_system_menu()


func _scene_system_quit() -> bool:
	if not await _open_system_menu():
		return false
	_app.system_menu().press(&"quit")
	return _app.system_menu().confirming() == &"quit"


func _scene_window_close() -> bool:
	if not _advance(func() -> bool: return _battle.turn >= 3 and _battle.phase == Unit.Side.PLAYER1):
		return false
	_show()
	await get_tree().create_timer(SETTLE).timeout
	_app.request_close()
	return _app.quit_window.is_open()


func _scene_settings() -> bool:
	if not await _open_system_menu():
		return false
	_app.system_menu().press(&"settings")
	_scene.settings.set_value(&"mouse_sensitivity", 150)
	return _app.system_menu().is_settings_open()


func _scene_settings_screen() -> bool:
	if not await _scene_settings():
		return false
	_scene.settings.set_value(&"fullscreen", true)  # 撮る間は窓に触らない（app.gd）ので、値だけが変わって見える
	await get_tree().process_frame
	_app.system_menu().settings_panel().scroll_to_end()
	return true
