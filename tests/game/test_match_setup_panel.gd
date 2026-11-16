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


## 出せるいちばん長い部隊でも、部隊の中身の行は決まった幅で折り返し、パネル（と画面）を横に広げない。
func test_a_long_deck_does_not_widen_the_panel() -> void:
	var deck := _long_deck()
	assert_true(deck.problems().is_empty(), "出せない部隊になった: %s" % [deck.problems()])
	var library := DeckLibrary.new()
	var id: String = library.add("長い部隊", deck).id
	var panel := MatchSetupPanel.new()
	panel.setup([Color.BLUE, Color.RED] as Array[Color], library, OverlayStack.new())
	var choice := MatchChoice.new()
	choice.cpu_opponent = false
	choice.armies = [UnitKind.Army.MILITARY, UnitKind.Army.MILITARY] as Array[UnitKind.Army]
	panel.open(choice)
	assert_true(panel.choose_deck(Unit.Side.PLAYER1, id), "取っておいた部隊を選べない")
	var label: Label = panel.deck_line(Unit.Side.PLAYER1)
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	assert_true(label.text.contains("\n"), "折り返していない: %s" % label.text)
	for line in label.text.split("\n"):
		var width := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		assert_true(width <= MatchSetupPanel.DECK_LINE_WIDTH + 1.0, "行が幅を超える（%d px）: %s" % [width, line])
	panel.free()
