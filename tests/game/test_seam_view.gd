extends "res://tests/base_test.gd"
## 縫い目の様子の画面の側（docs/seam-signs.md、docs/battle-view.md の「縫い目の様子」）: 対戦設定の「ランダム」「なし」（match_choice.gd）、
## 上の帯の下の札の帯とクリックで開く札の窓、始めの知らせ（battle_hud.gd、battle_texts.gd）、マスの説明の森。

const MatchChoice := preload("res://game/match_choice.gd")
const DeckLibrary := preload("res://game/deck_library.gd")
const SignCard := preload("res://game/sign_card.gd")
const BattleHud := preload("res://game/battle_hud.gd")
const BattleTexts := preload("res://game/battle_texts.gd")
const OverlayStack := preload("res://game/overlay_stack.gd")
const Palette := preload("res://game/ui_palette.gd")
const Names := preload("res://game/names.gd")
const Maps := preload("res://tests/support/maps.gd")

const COLORS: Array[Color] = [Palette.TEAM_BLUE, Palette.TEAM_RED]


# --- 選んだものから ---


func test_the_versus_default_is_random_and_needs_no_window() -> void:
	var choice := MatchChoice.new()
	assert_true(choice.has_rule(OptionalRules.SEAM), "対戦モードの既定は「ランダム」")
	var counts := {}
	var battle_seed := 0
	# 0〜2 つのどれも出るまで（多くても 40 局）。対戦を作るのに時間が掛かるので、出揃ったら止める（少なくとも 8 局は見る）。
	while battle_seed < 40 and (battle_seed < 8 or counts.size() < Seam.DRAWN + 1):
		battle_seed += 1
		var setup: MatchSetup = choice.to_setup(battle_seed)
		var signs := setup.signs()
		assert_true(signs.size() <= Seam.DRAWN)
		assert_eq(setup.create_battle().signs, signs, "対戦設定と対戦が同じ様子")
		counts[signs.size()] = true
		# CPU は札を見て部隊を選び直さない（いつもの CPU の編成のまま）。
		assert_eq(_deck_text(setup.decks[1]), _deck_text(CpuDeck.build(UnitKind.Army.FANTASY)))
	assert_eq(counts.size(), Seam.DRAWN + 1, "0〜2 つのどれも出る")


func test_none_shows_no_signs() -> void:
	var choice := MatchChoice.new()
	choice.set_rule(OptionalRules.SEAM, false)
	for battle_seed in range(1, 10):
		assert_eq(choice.to_setup(battle_seed).create_battle().signs, [] as Array[int])


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
	for pair: Array in [[Seam.Sign.HAZE, Seam.Sign.BRIM], [Seam.Sign.THICKET, Seam.Sign.TAUT], [Seam.Sign.SHIFT, Seam.Sign.GLEAM]]:
		var signs: Array[int] = []
		signs.assign(pair)
		hud.show_signs(signs)
		await settle(hud)
		assert_eq(hud.signs_text(), "%s・%s" % [Names.sign_name(pair[0]), Names.sign_name(pair[1])])
		assert_true(hud.sign_notes()[0].contains(Names.sign_summary(pair[0])), "乗せると効果の文")
		sizes[hud.top_tag_rects()[3].size] = true
	assert_eq(sizes.keys(), [BattleHud.SIGNS_CHIP_SIZE])
	hud.free()


func test_clicking_a_sign_name_opens_a_steady_note() -> void:
	var hud := BattleHud.new()
	hud.setup(COLORS)
	await settle(hud)
	hud.show_signs([Seam.Sign.THICKET, Seam.Sign.TAUT] as Array[int])
	assert_eq(hud.sign_note_text(), "")
	var sizes := {}
	for i in 2:
		hud.toggle_sign_note(i)
		await settle(hud)
		var sign: int = [Seam.Sign.THICKET, Seam.Sign.TAUT][i]
		assert_true(hud.sign_note_text().contains(Names.sign_summary(sign)), "クリックすると効果が読める")
		sizes[hud._sign_note.size] = true
	assert_eq(sizes.size(), 1, "札の窓は、どの札でも同じ大きさ")
	hud.toggle_sign_note(1)
	assert_eq(hud.sign_note_text(), "", "もう一度クリックで閉じる")
	hud.toggle_sign_note(0)
	hud.show_signs([] as Array[int])
	assert_eq(hud.sign_note_text(), "", "様子の無い対戦では閉じる")
	hud.free()


func test_sign_summaries_say_no_base_value() -> void:
	# 効果は短く言い切る 1 行（「いつもは」など、比べる元の値を書かない。Issue #46 の 11/23）。
	for sign: int in Seam.Sign.values():
		var summary := Names.sign_summary(sign)
		assert_false(summary.contains("いつも") or summary.contains("→") or summary.contains("\n"), summary)
		assert_true(summary.length() <= 24, "%s: %d 字" % [summary, summary.length()])


func test_start_notice_has_a_card_per_sign() -> void:
	var battle := Battle.new(Maps.board(["...."]))
	Seam.arm(battle, [Seam.Sign.GALE, Seam.Sign.GLEAM] as Array[int])
	var signs := BattleTexts.rule_cards(battle, Unit.Side.PLAYER1).filter(func(card: Array) -> bool: return card[0] == &"sign")
	assert_eq(signs.map(func(card: Array) -> int: return card[1]), [Seam.Sign.GALE, Seam.Sign.GLEAM])
	assert_eq(signs[0][2], Names.sign_name(Seam.Sign.GALE))
	assert_false(BattleTexts.rule_cards(Battle.new(Maps.board(["...."])), Unit.Side.PLAYER1).any(func(card: Array) -> bool: return card[0] == &"sign"))


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
