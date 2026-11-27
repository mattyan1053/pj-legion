extends "res://tests/base_test.gd"
## 対戦設定のパネル（game/match_setup_panel.gd）。

const MatchSetupPanel := preload("res://game/match_setup_panel.gd")
const MatchChoice := preload("res://game/match_choice.gd")
const DeckLibrary := preload("res://game/deck_library.gd")
const DeckText := preload("res://game/deck_text.gd")
const OverlayStack := preload("res://game/overlay_stack.gd")
const Names := preload("res://game/names.gd")
const TraitText := preload("res://game/trait_text.gd")


## 予算ぎりぎりで、装備をいちばん多く持たせた部隊（コマンドー 4 体に 3 つずつ）。
func _long_deck() -> Deck:
	var deck := Deck.new(UnitKind.Army.MILITARY)
	for i in 4:
		var entry := DeckEntry.new(UnitKind.Id.COMMANDO)
		entry.equipment.assign([Equipment.Id.IRON_SHIELD, Equipment.Id.IRON_SHIELD, Equipment.Id.SPEED_BOOTS])
		deck.entries.append(entry)
	return deck


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
	for step in 6:
		match step:
			1: panel.choose_army(Unit.Side.PLAYER2, UnitKind.Army.MILITARY)
			4: assert_true(panel.choose_deck(Unit.Side.PLAYER2, MatchChoice.RANDOM), "CPU の行でランダム編成を選べない")
			5: assert_true(panel.choose_deck(Unit.Side.PLAYER2, id), "CPU の行で取っておいた部隊を選べない")
			2: panel.choose_opponent(false)
			3:
				panel.choose_army(Unit.Side.PLAYER1, UnitKind.Army.MILITARY)
				assert_true(panel.choose_deck(Unit.Side.PLAYER1, id), "取っておいた部隊を選べない")
		await settle(holder)  # 木に入れて 1 コマ待ってから測る（base_test.gd の settle）
		sizes[box.get_combined_minimum_size()] = true
	assert_eq(sizes.size(), 1, "選んだもので、パネルの大きさが変わる: %s" % [sizes.keys()])
	panel.open_preview(Unit.Side.PLAYER1)
	assert_true(panel.preview().visible)
	var kinds: Array[UnitKind.Id] = [UnitKind.Id.KING]
	for entry in deck.entries:
		kinds.append(entry.kind)
	assert_eq(panel.preview().shown_kinds(), kinds, "選んだ部隊の駒を、将から並べる")
	var chosen := Names.troop_trait(TraitText.of_deck(deck))
	assert_true(panel.preview().trait_text().begins_with(chosen + " " + Names.troop_trait_text(TraitText.of_deck(deck))), "軍略の名前と文を出す: %s" % panel.preview().trait_text())
	panel.choose_opponent(true)
	panel.choose_deck(Unit.Side.PLAYER2, "")
	panel.open_preview(Unit.Side.PLAYER2)
	assert_eq(panel.preview().shown_kinds().size(), CpuDeck.build(UnitKind.Army.MILITARY).entries.size() + 1, "CPU の編成も同じ見え方で開く")
	assert_true(panel.preview().trait_text().begins_with(Names.troop_trait(CpuDeck.build(UnitKind.Army.MILITARY).trait_id) + " "), "CPU の軍略も出す（相手の軍略を、対戦の前に見られる）")
	holder.free()


## 手番の行に、先手の必殺技のゲージの始まりを書く（数は Ults.FIRST_PLAYER_START_GAUGE から作る。0 なら書かない）。
func test_the_side_row_notes_the_first_player_gauge() -> void:
	var note := MatchSetupPanel.first_gauge_note()
	if Ults.FIRST_PLAYER_START_GAUGE <= 0:
		assert_eq(note, "", "0 から始まるなら書かない")
		return
	assert_true(note.begins_with("先手"), note)
	assert_true(note.contains("%d%%" % (Ults.FIRST_PLAYER_START_GAUGE * 100 / Ults.GAUGE_MAX)), note)


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


## パネルの頭の帯は、いま選んでいる組み合わせ（だれが・どの軍で）とマップの縮図を出し、選び直すと追従する。帯の大きさは変わらない。
func test_the_banner_follows_the_choice() -> void:
	var panel := MatchSetupPanel.new()
	panel.setup([Color.BLUE, Color.RED] as Array[Color], DeckLibrary.new(), OverlayStack.new())
	panel.open(MatchChoice.new())
	var banner := panel.banner()
	await settle(panel)  # 木に入れて 1 コマ待ってから測る（base_test.gd の settle）
	var size_before := banner.get_combined_minimum_size()
	assert_true(banner.has_map(), "マップの縮図が出ていない")
	assert_eq(banner.texts(), [panel.who_text(Unit.Side.PLAYER1), "MILITARY", panel.who_text(Unit.Side.PLAYER2), "FANTASY"] as Array[String])
	panel.choose_army(Unit.Side.PLAYER1, UnitKind.Army.FANTASY)
	panel.choose_army(Unit.Side.PLAYER2, UnitKind.Army.MILITARY)
	panel.choose_random_side()
	assert_eq(banner.texts(), ["あなた", "FANTASY", "CPU", "MILITARY"] as Array[String])
	panel.choose_opponent(false)
	assert_eq(banner.texts()[0], panel.who_text(Unit.Side.PLAYER1))
	await settle(panel)
	assert_eq(banner.get_combined_minimum_size(), size_before)
	panel.free()


## 帯の大きさは中身で変わらない（文は欄の幅で切り、「…」にする）。どの組み合わせでも、文が切れずに収まる。
## 対戦設定の画面と同じ 1280×720 の中に置き、1 コマ待ってから測る（base_test.gd の settle）。
func test_the_banner_texts_fit_without_trimming() -> void:
	preload("res://game/ui_theme.gd").install()
	var holder := Control.new()
	holder.size = Vector2(1280.0, 720.0)
	var panel := MatchSetupPanel.new()
	holder.add_child(panel)
	panel.setup([Color.BLUE, Color.RED] as Array[Color], DeckLibrary.new(), OverlayStack.new())
	panel.open(MatchChoice.new())
	for step in 5:
		match step:
			1: panel.choose_random_side()
			2: panel.choose_human_side(Unit.Side.PLAYER2)
			3: panel.choose_opponent(false)
			4:
				panel.choose_army(Unit.Side.PLAYER1, UnitKind.Army.FANTASY)
				panel.choose_army(Unit.Side.PLAYER2, UnitKind.Army.MILITARY)
		await settle(holder)
		for label: Label in panel.banner().find_children("*", "Label", true, false):
			var width := label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x
			assert_true(width <= label.size.x + 0.5, "帯の文が切れる（%.0f px の欄に %.0f px）: %s" % [label.size.x, width, label.text])
	holder.free()


## 対戦の途中で開いたら、押すと対戦が終わるボタン（マップを選び直す・新しい対戦を始める）は 2 回押させる。
## 1 回目はボタンが「もう一度押す」になって理由を下に出し、直後の 2 回目は受けない。選び直すと確かめはやめる。
## 対戦の途中でなければ（対戦設定の場面、決着のあと）、1 回で進む。
func test_buttons_that_end_the_battle_ask_twice_in_a_battle() -> void:
	var holder := Control.new()
	Engine.get_main_loop().root.add_child(holder)
	var panel := MatchSetupPanel.new()
	holder.add_child(panel)
	panel.setup([Color.BLUE, Color.RED] as Array[Color], DeckLibrary.new(), OverlayStack.new())
	var started := [0]
	var staged := [0]
	panel.start_pressed.connect(func(_choice: RefCounted) -> void: started[0] += 1)
	panel.map_pressed.connect(func(_choice: RefCounted) -> void: staged[0] += 1)
	for press: StringName in [&"press_start", &"press_map"]:
		var count: Array = started if press == &"press_start" else staged
		panel.open(MatchChoice.new(), true, true)
		panel.call(press)
		assert_eq(count[0], 0, "%s の 1 回目で進んだ" % press)
		assert_true(panel.confirming_text().contains("いまの対戦を終えて"), panel.confirming_text())
		panel.call(press)
		assert_eq(count[0], 0, "%s の確かめの直後の 2 回目で進んだ" % press)
		panel.choose_opponent(false)
		assert_eq(panel.confirming_text(), "", "選び直しても、確かめがやめにならない")
		panel.call(press)
		panel.pass_confirm_guard()
		panel.call(press)
		assert_eq(count[0], 1, "%s の間を置いた 2 回目で進まない" % press)
		assert_true(not panel.visible)
		panel.open(MatchChoice.new(), true, false)
		panel.call(press)
		assert_eq(count[0], 2, "決着のあとの %s が、1 回で進まない" % press)
	holder.free()


## CPU の行も、人の行と同じ欄で部隊を選ぶ: 「CPU の編成」、ランダム編成、取っておいた部隊。ランダム編成は対戦を作るまで「編成確認」できず、
## 対戦の途中で開けば、いまの対戦で組んだ部隊を見せる。
func test_the_cpu_row_picks_a_squad_too() -> void:
	var library := DeckLibrary.new()
	var id: String = library.add("CPU に渡す部隊", _long_deck()).id
	var panel := MatchSetupPanel.new()
	panel.setup([Color.BLUE, Color.RED] as Array[Color], library, OverlayStack.new())
	var choice := MatchChoice.new()
	choice.choose_army(Unit.Side.PLAYER2, UnitKind.Army.MILITARY)
	panel.open(choice)
	var ids: Array = panel.deck_options(Unit.Side.PLAYER2).map(func(option: Array) -> String: return option[0])
	assert_eq(ids, ["", MatchChoice.RANDOM, id])
	assert_true(panel.deck_options(Unit.Side.PLAYER2)[0][1].begins_with("CPU の編成"), "CPU の行の既定は「CPU の編成」")
	assert_true(panel.deck_options(Unit.Side.PLAYER1)[0][1].begins_with("既定の編成"), "人の行の既定は「既定の編成」")
	assert_true(panel.choose_deck(Unit.Side.PLAYER2, MatchChoice.RANDOM))
	assert_false(panel.can_preview(Unit.Side.PLAYER2), "ランダム編成は、対戦を作るまで部隊が決まらない")
	panel.open_preview(Unit.Side.PLAYER2)
	assert_false(panel.preview().visible)
	var started: RefCounted = panel.current_choice().copy()
	var setup: MatchSetup = started.to_setup(5)  # 対戦を始めた
	panel.open(started, true, true)  # 対戦の途中で開いた
	assert_true(panel.can_preview(Unit.Side.PLAYER2))
	panel.open_preview(Unit.Side.PLAYER2)
	assert_eq(panel.preview().shown_kinds().size(), setup.decks[1].entries.size() + 1, "いまの対戦で組んだ部隊を見せる")
	panel.free()


## 選べる決まりは、行ごとに「あり」「なし」と、右に決まりの説明。説明の欄の大きさは、入・切で変わらない（木に入れて測る）。
func test_the_rule_rows_switch_and_keep_their_note_size() -> void:
	var panel := MatchSetupPanel.new()
	panel.setup([Color.BLUE, Color.RED] as Array[Color], DeckLibrary.new(), OverlayStack.new())
	panel.open(MatchChoice.new())
	await settle(panel)
	assert_true(panel.current_choice().has_rule(OptionalRules.STRONGHOLD), "拠点は既定であり")
	assert_true(panel.current_choice().has_rule(OptionalRules.SEAM), "縫い目の様子は既定でランダム")
	assert_false(MatchSetupPanel.RULE_ROWS.has(&"formation"), "軍略は決まりの行に無い（部隊が持つ）")
	for rule: StringName in MatchSetupPanel.RULE_ROWS:
		var note: Label = panel._rule_notes[rule]
		var before := note.size
		assert_eq(before, MatchSetupPanel.TRIAL_NOTE_SIZE)
		assert_eq(panel.rule_note_text(rule), panel.rule_note(rule))
		for on: bool in [true, false, true]:
			panel._choose(StringName("rule_%s" % rule), on)
			await settle(panel)
			assert_eq(panel.current_choice().has_rule(rule), on)
			assert_eq(note.size, before, "%s で欄の大きさが変わった" % rule)
	panel.free()
