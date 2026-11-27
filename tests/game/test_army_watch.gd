extends "res://tests/base_test.gd"
## 見張り: テストの中だけで、仮の 3 つ目の軍を足す（ゲームには出さない）。
## その軍は、同じ役割の兵を 2 種（前衛が 2 種で 5 種）と、軍略を 4 つ持つ。
## 落ちる所と、黙って 2 軍の扱いになる所（ロスター・予算・軍略・CPU の編成・誓い・色と紋・部隊編成の欄）が無いことを見る。
## 部隊編成の画面で並べてみるのは、長い検査（tests/game/test_army_watch_screen.gd）。足し方は docs/unit-roster.md の「軍を足すとき」。

const ArmyLook := preload("res://game/army_look.gd")
const Crest := preload("res://game/crest.gd")
const Names := preload("res://game/names.gd")
const Story := preload("res://game/story.gd")

## 仮の軍（UnitKind.Army に無い数）。
const TRIAL := 7
const TRIAL_ROSTER: Array[UnitKind.Id] = [
	UnitKind.Id.SHIELD_TROOPER, UnitKind.Id.PALADIN, UnitKind.Id.SORCERER, UnitKind.Id.COMMANDO, UnitKind.Id.PRIEST,
]
const TRIAL_TRAITS: Array[int] = [Traits.Id.OATH, Traits.Id.SUPPLY, Traits.Id.GUARD, Traits.Id.FOCUS]
const TRIAL_COLOR := Color("4fb88a")


static func add_trial() -> void:
	Armies.add_for_test(TRIAL, {
		"budget": 20, "roster": TRIAL_ROSTER, "traits": TRIAL_TRAITS,
		"cpu_traits": [Traits.Id.GUARD, Traits.Id.SUPPLY, Traits.Id.OATH, Traits.Id.FOCUS],
	})
	ArmyLook.add_for_test(TRIAL, {"color": TRIAL_COLOR, "crest": &"crystal", "sky": TRIAL_COLOR, "view": &"ruel_map"})
	DeckRules.forget_versus()


static func remove_trial() -> void:
	Armies.reset_for_test()
	ArmyLook.reset_for_test()
	DeckRules.forget_versus()


func test_a_third_army_is_read_from_the_table() -> void:
	add_trial()
	assert_eq(Armies.all().size(), 3)
	assert_eq(Armies.most_kinds(), 5)
	assert_eq(Armies.most_traits(), 4)
	var versus := DeckRules.versus()
	assert_eq(versus.armies().back(), TRIAL, "対戦の決まりに、仮の軍が出ない")
	assert_eq(versus.roster(TRIAL), TRIAL_ROSTER, "同じ役割が 2 種のロスター")
	assert_eq(versus.budget(TRIAL), 20)
	assert_eq(Traits.of_army(TRIAL).size(), 4, "4 つ目の軍略")
	assert_eq(Traits.default_of(TRIAL), Traits.Id.OATH)
	# CPU の編成: 出せる部隊になり、軍略は仮の軍のもの。守護の兵が 2 体いれば守護（名前でなく Traits.GUARDIAN で数える）。
	var deck := CpuDeck.build(TRIAL)
	assert_true(deck.is_valid(), "CPU の編成が出せない: %s" % [deck.problems()])
	assert_true(Traits.of_army(TRIAL).has(deck.trait_id), "CPU の軍略が、仮の軍のものでない")
	var guarded := Deck.new(TRIAL)
	for n in 2:
		guarded.add(UnitKind.Id.PALADIN)
	assert_eq(CpuDeck.choose_trait(guarded), Traits.Id.GUARD)
	var healed := Deck.new(TRIAL)
	for n in 2:
		healed.add(UnitKind.Id.PRIEST)
	assert_eq(CpuDeck.choose_trait(healed), Traits.Id.SUPPLY, "回復役は役割で数える（衛生兵でなくても）")
	# 誓いは、誓いを持つ軍なら結べる（騎士領かどうかは見ない）。
	assert_true(guarded.can_bind(guarded.entries[0], guarded.entries[1]), "仮の軍で誓いを結べない")
	# 対戦が作れて、両方の軍が対戦に写る。
	var setup := MatchSetup.humans_on(Scenario.versus(BoardGenerator.Stage.PLAIN), 1, deck, MatchSetup.default_deck(UnitKind.Army.MILITARY))
	var battle := setup.create_battle()
	assert_eq(battle.armies[Unit.Side.PLAYER1], TRIAL)
	assert_eq(battle.traits[Unit.Side.PLAYER1], deck.trait_id)
	# 見た目: 色と紋は、表の値（連邦か騎士領の色に、黙ってならない）。
	assert_eq(Crest.color_of(TRIAL), TRIAL_COLOR)
	assert_eq(ArmyLook.crest(TRIAL), &"crystal")
	remove_trial()
	assert_eq(Armies.all().size(), 2, "仮の軍が残った")
	assert_eq(DeckRules.versus().armies().size(), 2, "仮の軍が、対戦の決まりに残った")


## 足し忘れても、ほかのテストが拾わなかったもの。
func test_every_healer_strikes_and_every_item_can_be_had() -> void:
	for army in Armies.all():
		for kind in Armies.roster(army):
			if UnitKind.role(kind) == UnitKind.Role.HEALER:
				assert_true(UnitKind.HEALER_STRIKE.has(kind), "回復役 %s の攻撃の強さ（UnitKind.HEALER_STRIKE）が無い（無いと攻撃 0）" % Names.word(UnitKind.Id, kind))
	var had := {}
	for item in DeckRules.VERSUS_ITEMS:
		had[item] = true
	for campaign: RefCounted in Story.campaigns():
		for item: Equipment.Id in Story.offered_items(campaign):
			had[item] = true
	for item: Equipment.Id in Equipment.Id.values():
		assert_true(had.has(item), "持ち物 %s は、対戦でもどの物語でも手に入らない" % Names.item(item))
