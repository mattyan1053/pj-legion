extends "res://tests/base_test.gd"
## 縫い目の様子の画面の側（docs/seam-signs.md、docs/battle-view.md の「縫い目の様子」）: 対戦設定の選択から CPU が札を見て部隊を選ぶこと（match_choice.gd）、
## 札がめくられる窓（signs_window.gd）、上の帯の下の札の帯と始めの知らせ（battle_hud.gd、battle_texts.gd）、マスの説明の森。

const MatchChoice := preload("res://game/match_choice.gd")
const DeckLibrary := preload("res://game/deck_library.gd")
const SignsWindow := preload("res://game/signs_window.gd")
const SignCard := preload("res://game/sign_card.gd")
const BattleHud := preload("res://game/battle_hud.gd")
const BattleTexts := preload("res://game/battle_texts.gd")
const OverlayStack := preload("res://game/overlay_stack.gd")
const Palette := preload("res://game/ui_palette.gd")
const Names := preload("res://game/names.gd")
const Maps := preload("res://tests/support/maps.gd")

const COLORS: Array[Color] = [Palette.TEAM_BLUE, Palette.TEAM_RED]


func _seam_choice() -> MatchChoice:
	var choice := MatchChoice.new()
	choice.set_rule(OptionalRules.SEAM, true)
	return choice


## 札に天裂の名残り（スナイパーが損をする）が出る種。
func _haze_seed(choice: MatchChoice) -> int:
	for battle_seed in range(1, 200):
		if choice.to_setup(battle_seed).signs().has(Seam.Sign.HAZE):
			return battle_seed
	return -1


# --- 選んだものから ---


func test_off_keeps_the_cpu_deck_and_shows_no_signs() -> void:
	var choice := MatchChoice.new()
	assert_false(choice.shows_signs())
	var setup: MatchSetup = choice.to_setup(4)
	assert_eq(setup.signs(), [] as Array[int])
	assert_eq(_deck_text(setup.decks[1]), _deck_text(CpuDeck.build(UnitKind.Army.FANTASY)))
	assert_true(choice.signs_pick == null)


func test_cpu_on_its_own_deck_picks_among_its_deck_and_saved_decks_by_the_signs() -> void:
	var library := DeckLibrary.new()
	var snipers := Deck.new(UnitKind.Army.MILITARY)
	for i in 4:
		snipers.add(UnitKind.Id.SNIPER)
	var raiders := Deck.new(UnitKind.Army.MILITARY)
	for i in 4:
		raiders.add(UnitKind.Id.COMMANDO)
	library.add("狙撃", snipers)
	library.add("突撃", raiders)
	var choice := _seam_choice()
	choice.human_side = Unit.Side.PLAYER2  # CPU は先手の MILITARY
	choice.refresh_decks(library)
	assert_true(choice.shows_signs())
	var candidates := choice.cpu_candidates(1)
	assert_eq(candidates.size(), 3, "CPU の編成と、取っておいた 2 つ")
	var battle_seed := _haze_seed(choice)
	assert_true(battle_seed > 0)
	var setup: MatchSetup = choice.to_setup(battle_seed)
	var signs := setup.signs()
	assert_eq(_deck_text(setup.decks[0]), _deck_text(CpuDeck.pick_for_signs(candidates, signs)))
	assert_ne(_deck_text(setup.decks[0]), _deck_text(snipers), "霞の日に、スナイパー 4 体の部隊は選ばない")
	assert_true(choice.signs_pick != null)


func test_cpu_with_a_named_saved_deck_keeps_it() -> void:
	var library := DeckLibrary.new()
	var deck := Deck.new(UnitKind.Army.FANTASY)
	deck.add(UnitKind.Id.PRIEST)
	var item: RefCounted = library.add("祈り", deck)
	var choice := _seam_choice()
	choice.refresh_decks(library)
	choice.choose_deck(Unit.Side.PLAYER2, item.id, item.deck)
	assert_eq(choice.cpu_candidates(1).size(), 0)
	assert_eq(choice.to_setup(1).decks[1].entries.size(), 1, "人が名指しした部隊は選び直さない")


func test_cpu_on_a_random_squad_picks_among_three_drawn_squads() -> void:
	var choice := _seam_choice()
	choice.choose_random(Unit.Side.PLAYER2)
	var candidates := choice.cpu_candidates(5)
	assert_eq(candidates.size(), MatchChoice.SIGN_CANDIDATES)
	var setup: MatchSetup = choice.to_setup(5)
	assert_eq(_deck_text(setup.decks[1]), _deck_text(CpuDeck.pick_for_signs(candidates, setup.signs())))
	assert_eq(_deck_text(choice.drawn_deck(Unit.Side.PLAYER2)), _deck_text(setup.decks[1]), "編成確認は、選んだ部隊")


func test_copy_keeps_the_saved_pool() -> void:
	var library := DeckLibrary.new()
	var deck := Deck.new(UnitKind.Army.FANTASY)
	deck.add(UnitKind.Id.PRIEST)
	library.add("祈り", deck)
	var choice := _seam_choice()
	choice.refresh_decks(library)
	var other: MatchChoice = choice.copy()
	assert_eq(other.cpu_candidates(1).size(), 2)


# --- 札がめくられる窓 ---


func test_window_shows_the_two_signs_and_starts_with_the_new_squad() -> void:
	var overlays := OverlayStack.new()
	var window := SignsWindow.new()
	window.setup(COLORS, DeckLibrary.new(), overlays)
	await settle(window)
	var choice := _seam_choice()
	var setup: MatchSetup = choice.to_setup(3)
	window.open(choice, 3, setup.signs())
	await settle(window)
	assert_true(overlays.is_top(window), "重なる画面として積む")
	var texts := window.card_texts()
	assert_eq(texts.size(), Seam.DRAWN)
	for i in Seam.DRAWN:
		assert_true(texts[i].contains(Names.sign_name(setup.signs()[i])))
	assert_true(window.choose_deck(Unit.Side.PLAYER1, MatchChoice.RANDOM))
	assert_false(window.choose_deck(Unit.Side.PLAYER2, ""), "CPU の行は選べない")
	var started: Array = []
	window.started.connect(func(chosen: RefCounted) -> void: started.append(chosen))
	window.press_start()
	assert_eq(started.size(), 1)
	assert_true(started[0].is_random(Unit.Side.PLAYER1), "選び直した部隊で始める")
	assert_false(window.visible)
	assert_false(overlays.is_open())
	window.free()


func test_sign_cards_keep_their_size_whatever_the_sign() -> void:
	var card := SignCard.new()
	await settle(card)
	var sizes := {}
	for sign: int in Seam.Sign.values():
		card.show_sign(sign)
		await settle(card)
		sizes[card.size] = true
	assert_eq(sizes.keys(), [SignCard.SIZE], "どの札でも同じ大きさ")
	card.free()


# --- 対戦の画面 ---


func test_signs_chip_shows_names_and_notes_and_keeps_its_size() -> void:
	var hud := BattleHud.new()
	hud.setup(COLORS)
	await settle(hud)
	hud.show_signs([] as Array[int])
	assert_eq(hud.signs_text(), "", "札の無い対戦では出さない")
	var sizes := {}
	for pair: Array in [[Seam.Sign.HAZE, Seam.Sign.BRIM], [Seam.Sign.THICKET, Seam.Sign.TAUT], [Seam.Sign.SHIFT, Seam.Sign.MEND]]:
		var signs: Array[int] = []
		signs.assign(pair)
		hud.show_signs(signs)
		await settle(hud)
		assert_eq(hud.signs_text(), "%s・%s" % [Names.sign_name(pair[0]), Names.sign_name(pair[1])])
		assert_true(hud.sign_notes()[0].contains(Names.sign_summary(pair[0])), "乗せると効果の文")
		sizes[hud.top_tag_rects()[3].size] = true
	assert_eq(sizes.keys(), [BattleHud.SIGNS_CHIP_SIZE])
	hud.free()


func test_start_notice_names_the_signs() -> void:
	var battle := Battle.new(Maps.board(["...."]))
	Seam.arm(battle, [Seam.Sign.DUSK, Seam.Sign.MEND] as Array[int])
	var notice := BattleTexts.rule_notice(battle)
	assert_true(notice.any(func(line: String) -> bool: return line.contains(Names.sign_name(Seam.Sign.DUSK)) and line.contains(Names.sign_name(Seam.Sign.MEND))))
	assert_false(BattleTexts.rule_notice(Battle.new(Maps.board(["...."]))).any(func(line: String) -> bool: return line.contains("縫い目")))


func test_forest_note_follows_the_thicket() -> void:
	var plain := Battle.new(Maps.board(["F"]))
	assert_true(BattleTexts.cell_body(plain, Vector2i(0, 0)).contains("0.8"))
	var deep := Battle.new(Maps.board(["F"]))
	Seam.arm(deep, [Seam.Sign.THICKET] as Array[int])
	assert_true(BattleTexts.cell_body(deep, Vector2i(0, 0)).contains("0.6"))


func _deck_text(deck: Deck) -> String:
	if deck == null:
		return ""
	return ",".join(deck.entries.map(func(entry: DeckEntry) -> String: return "%d%s" % [entry.kind, entry.equipment]))
