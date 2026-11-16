extends "res://tests/base_test.gd"
## 対戦の設定のパネル（game/match_setup_panel.gd）。

const MatchSetupPanel := preload("res://game/match_setup_panel.gd")
const MatchChoice := preload("res://game/match_choice.gd")
const DeckLibrary := preload("res://game/deck_library.gd")
const DeckText := preload("res://game/deck_text.gd")
const OverlayStack := preload("res://game/overlay_stack.gd")


## 予算ぎりぎりで、装備をいちばん多く持たせた部隊（コマンドー 4 体に 3 つずつ）。
func _long_deck() -> Deck:
	var deck := Deck.new(UnitKind.Army.MILITARY)
	for i in 4:
		var entry := DeckEntry.new(UnitKind.Id.COMMANDO)
		entry.equipment.assign([Equipment.Id.IRON_SHIELD, Equipment.Id.IRON_SHIELD, Equipment.Id.SPEED_BOOTS])
		deck.entries.append(entry)
	return deck


func test_the_deck_line_groups_the_same_equipment() -> void:
	var text := DeckText.deck_summary(_long_deck())
	assert_true(text.begins_with("将、コマンドー+アイアンシールド×2+スピードブーツ、"), text)


## パネルの大きさは、選んだもの（軍、部隊、相手）に依らず同じ。部隊の中身は「編成を確認」で開く。
func test_the_panel_keeps_its_size_and_previews_decks() -> void:
	var deck := _long_deck()
	assert_true(deck.problems().is_empty(), "出せない部隊になった: %s" % [deck.problems()])
	var library := DeckLibrary.new()
	var id: String = library.add("とても長い名前の部隊をここに書く", deck).id
	var holder := Control.new()
	holder.size = Vector2(1280.0, 720.0)
	Engine.get_main_loop().root.add_child(holder)
	var panel := MatchSetupPanel.new()
	holder.add_child(panel)
	panel.setup([Color.BLUE, Color.RED] as Array[Color], library, OverlayStack.new())
	panel.open(MatchChoice.new())
	var sizes := {}
	var box: Control = panel.get_child(1).get_child(0)
	for step in 4:
		match step:
			1: panel.choose_army(Unit.Side.PLAYER2, UnitKind.Army.MILITARY)
			2: panel.choose_opponent(false)
			3:
				panel.choose_army(Unit.Side.PLAYER1, UnitKind.Army.MILITARY)
				assert_true(panel.choose_deck(Unit.Side.PLAYER1, id), "取っておいた部隊を選べない")
		sizes[box.get_combined_minimum_size()] = true
	assert_eq(sizes.size(), 1, "選んだもので、パネルの大きさが変わる: %s" % [sizes.keys()])
	panel.open_preview(Unit.Side.PLAYER1)
	assert_true(panel.preview().visible)
	var kinds: Array[UnitKind.Id] = [UnitKind.Id.KING]
	for entry in deck.entries:
		kinds.append(entry.kind)
	assert_eq(panel.preview().shown_kinds(), kinds, "選んだ部隊の駒を、将から並べる")
	panel.choose_opponent(true)
	panel.open_preview(Unit.Side.PLAYER2)
	assert_eq(panel.preview().shown_kinds().size(), CpuDeck.build(UnitKind.Army.MILITARY).entries.size() + 1, "CPU の編成も同じ見え方で開く")
	holder.free()


func test_random_side_labels_the_rows_by_who_plays() -> void:
	var panel := MatchSetupPanel.new()
	panel.setup([Color.BLUE, Color.RED] as Array[Color], DeckLibrary.new(), OverlayStack.new())
	panel.open(MatchChoice.new())
	panel.choose_random_side()
	assert_true(panel.current_choice().random_side)
	assert_eq(panel.who_text(Unit.Side.PLAYER1), "あなた")
	assert_eq(panel.who_text(Unit.Side.PLAYER2), "CPU")
	panel.choose_human_side(Unit.Side.PLAYER2)
	assert_false(panel.current_choice().random_side)
	assert_eq(panel.who_text(Unit.Side.PLAYER2), "あなた・後手（赤）")
	panel.free()
