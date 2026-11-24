extends "res://tests/base_test.gd"
## 部隊の特徴（docs/troop-traits.md）: 6 つの特徴の効き方、特徴の無い陣営では何も変わらないこと、部隊の特徴と誓い、
## 対戦を作るときの写し方（対戦モードは部隊から、ストーリーは話から）、予測、CPU の選び方。

const Maps := preload("res://tests/support/maps.gd")
const RandomSquad := preload("res://game/random_squad.gd")

const P1 := Unit.Side.PLAYER1
const P2 := Unit.Side.PLAYER2
const K := UnitKind.Id
const T := Traits.Id


## 7 x 7 の平地。先手の特徴は mine、後手は theirs。
func _battle(mine: int, theirs := Traits.NONE) -> Battle:
	var battle := Maps.battle([".......", ".......", ".......", ".......", ".......", ".......", "......."])
	battle.traits = [mine, theirs]
	return battle


func _effects(events: Array[BattleEvent]) -> Array[Array]:
	var found: Array[Array] = []
	for event in events:
		var triggered := event as TraitTriggeredEvent
		if triggered != null:
			found.append([triggered.trait_id, triggered.unit_id, triggered.other_id, triggered.amount])
	return found


func _damage(events: Array[BattleEvent]) -> int:
	for event in events:
		if event is AttackDamagedEvent:
			return (event as AttackDamagedEvent).amount
	return -1


func _attack(battle: Battle, attacker: Unit, target: Unit) -> Array[BattleEvent]:
	var result := battle.apply(AttackAction.new(attacker.id, target.id))
	assert_true(result.accepted, "攻撃が通らない")
	return result.events


func test_each_army_has_three_traits_and_a_default() -> void:
	assert_eq(Traits.of_army(UnitKind.Army.MILITARY), [T.FOCUS, T.RANKS, T.SUPPLY] as Array[Traits.Id])
	assert_eq(Traits.of_army(UnitKind.Army.FANTASY), [T.VENGEANCE, T.OATH, T.LONE] as Array[Traits.Id])
	assert_eq(Traits.default_of(UnitKind.Army.MILITARY), T.FOCUS)
	assert_eq(Traits.default_of(UnitKind.Army.FANTASY), T.VENGEANCE)
	assert_eq(Traits.default_of(UnitKind.Army.NONE), Traits.NONE)
	for id: int in T.values():
		assert_eq(Traits.from_key(Traits.key(id)), id)
	assert_eq(Traits.from_key("formation"), Traits.NONE)


# --- 集中砲火 ---


func test_focus_adds_damage_to_a_target_an_ally_hit_this_turn() -> void:
	var battle := _battle(T.FOCUS)
	var first := battle.add_unit(K.SNIPER, P1, Vector2i(0, 3))
	var second := battle.add_unit(K.COMMANDO, P1, Vector2i(3, 4))
	var target := battle.add_unit(K.PALADIN, P2, Vector2i(3, 3))
	assert_eq(_effects(_attack(battle, first, target)), [], "1 発目には乗らない")
	assert_true(Traits.focus_marked(battle, target, P1), "攻撃された敵に印")
	var events := _attack(battle, second, target)
	assert_eq(_damage(events), second.power() + Traits.FOCUS_BONUS)
	assert_eq(_effects(events), [[T.FOCUS, second.id, target.id, Traits.FOCUS_BONUS]])


func test_own_second_attack_and_the_next_turn_do_not_count_for_focus() -> void:
	var battle := _battle(T.FOCUS)
	var sniper := battle.add_unit(K.SNIPER, P1, Vector2i(0, 3))
	var target := battle.add_unit(K.PALADIN, P2, Vector2i(3, 3))
	_attack(battle, sniper, target)
	assert_eq(Traits.attack_boosts(battle, sniper, target), {}, "自分の攻撃は数えない")
	battle.apply(EndPhaseAction.new())
	assert_false(Traits.focus_marked(battle, target, P1), "フェーズが替わると印は消える")


# --- 隊列 ---


func test_ranks_cut_damage_next_to_the_same_kind() -> void:
	var battle := _battle(Traits.NONE, T.RANKS)
	var foe := battle.add_unit(K.SORCERER, P1, Vector2i(0, 3))
	var guarded := battle.add_unit(K.SHIELD_TROOPER, P2, Vector2i(2, 3))
	battle.add_unit(K.SHIELD_TROOPER, P2, Vector2i(2, 4))
	var events := _attack(battle, foe, guarded)
	assert_eq(_damage(events), foe.power() - Traits.RANKS_GUARD)
	assert_eq(_effects(events), [[T.RANKS, guarded.id, foe.id, Traits.RANKS_GUARD]])


func test_ranks_need_the_same_kind_side_by_side() -> void:
	var battle := _battle(Traits.NONE, T.RANKS)
	var target := battle.add_unit(K.SHIELD_TROOPER, P2, Vector2i(2, 3))
	var diagonal := battle.add_unit(K.SHIELD_TROOPER, P2, Vector2i(3, 4))
	var other := battle.add_unit(K.SNIPER, P2, Vector2i(2, 2))
	assert_eq(Traits.guard_of(battle, target), 0, "斜めは隣ではない。違う兵種は数えない")
	diagonal.cell = Vector2i(1, 3)
	assert_eq(Traits.guard_of(battle, target), Traits.RANKS_GUARD)
	assert_eq(Traits.guard_of(battle, other), 0)


# --- 補給線 ---


func test_supply_heals_units_next_to_a_medic_at_the_start_of_their_turn() -> void:
	var battle := _battle(T.SUPPLY)
	var medic := battle.add_unit(K.MEDIC, P1, Vector2i(3, 3))
	var near := battle.add_unit(K.SHIELD_TROOPER, P1, Vector2i(3, 4))
	var scratched := battle.add_unit(K.SNIPER, P1, Vector2i(4, 3))
	var far := battle.add_unit(K.COMMANDO, P1, Vector2i(0, 0))
	near.hp -= 10
	scratched.hp -= 1
	far.hp -= 10
	medic.hp -= 10
	battle.apply(EndPhaseAction.new())  # 後手の番。先手の兵は回復しない
	assert_eq(near.hp, near.max_hp() - 10)
	var events := battle.apply(EndPhaseAction.new()).events  # 中立のあと、次のターンの先手の番
	var healed: Array = events.filter(func(event: BattleEvent) -> bool: return event is SupplyHealedEvent)
	assert_eq(healed.size(), 2, "回復役と隣り合う、減った兵だけ")
	assert_eq(near.hp, near.max_hp() - 10 + Traits.SUPPLY_HEAL)
	assert_eq(scratched.hp, scratched.max_hp(), "最大 HP を超えない")
	assert_eq(far.hp, far.max_hp() - 10)
	assert_eq(medic.hp, medic.max_hp() - 10, "回復役は、自分では回復しない")
	assert_eq((healed[0] as SupplyHealedEvent).medic_id, medic.id)


# --- 仇討ち ---


func test_vengeance_adds_damage_against_the_enemy_that_defeated_an_ally() -> void:
	var battle := _battle(T.VENGEANCE)
	var fallen := battle.add_unit(K.SORCERER, P1, Vector2i(3, 2))
	var mage := battle.add_unit(K.SORCERER, P1, Vector2i(3, 5))
	var killer := battle.add_unit(K.COMMANDO, P2, Vector2i(3, 3))
	assert_eq(Traits.attack_boosts(battle, mage, killer), {})
	fallen.hp = 1
	battle.phase = P2
	_attack(battle, killer, fallen)
	assert_true(Traits.vengeance_marked(battle, killer, P1), "味方を倒した敵に印")
	battle.phase = P1
	var events := _attack(battle, mage, killer)
	assert_eq(_damage(events), mage.power() + Traits.VENGEANCE_BONUS)
	assert_eq(_effects(events), [[T.VENGEANCE, mage.id, killer.id, Traits.VENGEANCE_BONUS]])
	battle.apply(EndPhaseAction.new())
	assert_true(Traits.vengeance_marked(battle, killer, P1), "印は倒れるまで残る")


# --- 誓い ---


func test_oath_adds_damage_to_the_target_the_partner_hit_this_turn() -> void:
	var battle := _battle(T.OATH)
	var knight := battle.add_unit(K.PALADIN, P1, Vector2i(2, 3))
	var mage := battle.add_unit(K.SORCERER, P1, Vector2i(3, 1))
	var other := battle.add_unit(K.SORCERER, P1, Vector2i(3, 5))
	var target := battle.add_unit(K.SHIELD_TROOPER, P2, Vector2i(3, 3))
	Traits.bind(knight, mage)
	_attack(battle, other, target)
	assert_eq(Traits.attack_boosts(battle, mage, target), {}, "誓いの相手でない味方の攻撃は数えない")
	_attack(battle, knight, target)
	var events := _attack(battle, mage, target)
	assert_eq(_damage(events), mage.power() + Traits.OATH_BONUS)
	assert_eq(_effects(events), [[T.OATH, mage.id, target.id, Traits.OATH_BONUS]])


func test_oath_ends_when_a_partner_falls() -> void:
	var battle := _battle(T.OATH)
	var knight := battle.add_unit(K.PALADIN, P1, Vector2i(2, 3))
	var mage := battle.add_unit(K.SORCERER, P1, Vector2i(0, 3))
	Traits.bind(knight, mage)
	assert_eq(Traits.partner_of(battle, mage), knight)
	battle.remove_unit(knight)
	assert_eq(Traits.partner_of(battle, mage), null)
	assert_eq(mage.oath_partner, 0)


# --- 単騎 ---


func test_lone_adds_damage_without_an_ally_next_to_the_attacker() -> void:
	var battle := _battle(T.LONE)
	var blade := battle.add_unit(K.SPELLBLADE, P1, Vector2i(2, 3))
	var target := battle.add_unit(K.SHIELD_TROOPER, P2, Vector2i(3, 3))
	var mate := battle.add_unit(K.PRIEST, P1, Vector2i(2, 4))
	assert_eq(Traits.attack_boosts(battle, blade, target), {}, "隣に味方がいる")
	mate.cell = Vector2i(1, 4)
	var events := _attack(battle, blade, target)
	assert_eq(_damage(events), blade.power() + Traits.LONE_BONUS, "斜めは隣ではない")
	assert_eq(_effects(events), [[T.LONE, blade.id, target.id, Traits.LONE_BONUS]])


# --- 特徴の無い陣営 ---


func test_nothing_happens_without_a_trait() -> void:
	var battle := _battle(Traits.NONE, Traits.NONE)
	var first := battle.add_unit(K.SNIPER, P1, Vector2i(0, 3))
	var second := battle.add_unit(K.SNIPER, P1, Vector2i(1, 4))
	var target := battle.add_unit(K.SHIELD_TROOPER, P2, Vector2i(3, 3))
	battle.add_unit(K.SHIELD_TROOPER, P2, Vector2i(3, 4))
	_attack(battle, first, target)
	var events := _attack(battle, second, target)
	assert_eq(_effects(events), [])
	assert_eq(_damage(events), second.power())
	assert_false(Traits.focus_marked(battle, target, P1))


func test_traits_belong_to_one_side_only() -> void:
	var battle := _battle(T.FOCUS, Traits.NONE)
	var first := battle.add_unit(K.SNIPER, P2, Vector2i(0, 3))
	var second := battle.add_unit(K.SNIPER, P2, Vector2i(1, 4))
	var target := battle.add_unit(K.SHIELD_TROOPER, P1, Vector2i(3, 3))
	battle.phase = P2
	_attack(battle, first, target)
	assert_eq(_effects(_attack(battle, second, target)), [], "相手の陣営の特徴は、自分の攻撃に乗らない")


# --- 糸の魔物と一緒に（docs/monsters.md） ---


## 糸喰いが弾けたダメージは、起爆樽の爆発と同じく、隊列で減らない。
func test_ranks_do_not_cut_an_eater_burst() -> void:
	var battle := _battle(T.FOCUS, T.RANKS)
	var sniper := battle.add_unit(K.SNIPER, P1, Vector2i(3, 0))
	var eater := battle.add_unit(K.EATER, Unit.Side.NEUTRAL, Vector2i(3, 3))
	var front := battle.add_unit(K.SHIELD_TROOPER, P2, Vector2i(2, 3))
	var back := battle.add_unit(K.SHIELD_TROOPER, P2, Vector2i(2, 4))
	assert_eq(Traits.guard_of(battle, front), Traits.RANKS_GUARD, "並んでいる")
	eater.hp = 1
	var events := _attack(battle, sniper, eater)
	assert_false(battle.units.has(eater))
	assert_eq(front.hp, front.max_hp() - Monsters.BURST_DAMAGE)
	assert_eq(back.hp, back.max_hp() - Monsters.BURST_DAMAGE)
	assert_eq(_effects(events), [], "弾けたダメージに特徴は掛からない")


## 糸喰いが弾けて倒れた駒は、糸喰いを倒した駒が倒したことにする。だから、その駒は倒れた駒の陣営の仇になる（味方を巻き込んでも仇にはならない）。
func test_units_felled_by_a_burst_make_the_eater_killer_a_foe_to_avenge() -> void:
	var battle := _battle(T.VENGEANCE, T.VENGEANCE)
	var killer := battle.add_unit(K.SNIPER, P2, Vector2i(3, 0))
	var eater := battle.add_unit(K.EATER, Unit.Side.NEUTRAL, Vector2i(3, 3))
	var victim := battle.add_unit(K.SORCERER, P1, Vector2i(3, 4))
	var mate := battle.add_unit(K.SORCERER, P2, Vector2i(2, 2))
	var mage := battle.add_unit(K.SORCERER, P1, Vector2i(3, 6))
	eater.hp = 1
	victim.hp = Monsters.BURST_DAMAGE
	mate.hp = Monsters.BURST_DAMAGE
	battle.phase = P2
	_attack(battle, killer, eater)
	assert_false(battle.units.has(victim) or battle.units.has(mate), "2 体とも弾けて倒れた")
	assert_true(Traits.vengeance_marked(battle, killer, P1), "弾けて倒れた味方の仇")
	assert_false(Traits.slew(killer, P2), "自分の陣営の駒を巻き込んでも仇ではない")
	assert_eq(Traits.attack_boosts(battle, mage, killer), {T.VENGEANCE: Traits.VENGEANCE_BONUS})


## 糸蜘蛛の攻撃は駒の攻撃なので、隊列で減る（0 より下にはならない）。減っても絡む。
func test_ranks_cut_a_spider_bite_and_the_target_is_still_snared() -> void:
	var battle := _battle(Traits.NONE, T.RANKS)
	var spider := battle.add_unit(K.SPIDER, P1, Vector2i(3, 3))
	var guarded := battle.add_unit(K.SHIELD_TROOPER, P2, Vector2i(3, 4))
	battle.add_unit(K.SHIELD_TROOPER, P2, Vector2i(2, 4))
	var events := _attack(battle, spider, guarded)
	assert_eq(_damage(events), maxi(spider.power() - Traits.RANKS_GUARD, 0))
	assert_true(Statuses.has(guarded, Status.Type.SNARE))


# --- 部隊 ---


func test_deck_starts_with_the_army_default_and_copies_its_trait() -> void:
	var deck := Deck.new(UnitKind.Army.MILITARY)
	assert_eq(deck.trait_id, T.FOCUS)
	deck.trait_id = T.SUPPLY
	assert_eq(deck.copy().trait_id, T.SUPPLY)


func test_deck_binds_up_to_two_oaths_for_the_knights_only() -> void:
	var deck := Deck.new(UnitKind.Army.FANTASY)
	var a := deck.add(K.PALADIN)
	var b := deck.add(K.SORCERER)
	var c := deck.add(K.SPELLBLADE)
	var d := deck.add(K.SORCERER)
	var e := deck.add(K.PALADIN)
	assert_true(deck.bind(a, b))
	assert_false(deck.bind(a, c), "1 体は 1 組まで")
	assert_true(deck.bind(c, d))
	assert_false(deck.bind(e, e))
	assert_eq(deck.oaths.size(), Traits.MAX_OATHS)
	var federation := Deck.new(UnitKind.Army.MILITARY)
	assert_false(federation.bind(federation.add(K.SNIPER), federation.add(K.SNIPER)), "連邦は結べない")


# --- 対戦を作るとき ---


func test_versus_takes_each_trait_from_the_squad_and_binds_oaths_for_the_oath_trait() -> void:
	var federation := MatchSetup.default_deck(UnitKind.Army.MILITARY).copy()
	federation.trait_id = T.RANKS
	var knights := Deck.new(UnitKind.Army.FANTASY)
	var a := knights.add(K.PALADIN)
	var b := knights.add(K.SORCERER)
	knights.add(K.SPELLBLADE)
	knights.bind(a, b)
	knights.trait_id = T.OATH
	var setup := MatchSetup.versus_human(BoardGenerator.Stage.PLAIN, 1, federation, knights)
	var battle := setup.create_battle()
	assert_eq(battle.traits, [T.RANKS, T.OATH] as Array[int])
	var bound := battle.units.filter(func(unit: Unit) -> bool: return unit.oath_partner != 0)
	assert_eq(bound.size(), 2)
	knights.trait_id = T.LONE
	battle = setup.create_battle()
	assert_eq(battle.traits, [T.RANKS, T.LONE] as Array[int])
	assert_true(battle.units.all(func(unit: Unit) -> bool: return unit.oath_partner == 0), "誓いでなければ結ばない")


func test_a_trait_of_the_other_army_falls_back_to_the_default() -> void:
	var federation := MatchSetup.default_deck(UnitKind.Army.MILITARY).copy()
	federation.trait_id = T.LONE
	var setup := MatchSetup.versus_human(BoardGenerator.Stage.PLAIN, 1, federation, MatchSetup.default_deck(UnitKind.Army.FANTASY))
	assert_eq(setup.trait_of(P1), T.FOCUS)


func test_story_battles_have_traits_only_where_the_episode_sets_them() -> void:
	var defined := Scenario.new()
	var setup := MatchSetup.humans_on(defined, 1, MatchSetup.default_deck(UnitKind.Army.MILITARY), MatchSetup.default_deck(UnitKind.Army.FANTASY))
	assert_eq(setup.create_battle().traits, [Traits.NONE, Traits.NONE] as Array[int], "話は部隊の特徴を使わない")
	defined.traits[P2] = T.LONE
	assert_eq(setup.create_battle().traits, [Traits.NONE, T.LONE] as Array[int])


# --- 予測 ---


func test_forecast_shows_the_trait_part() -> void:
	var battle := _battle(T.FOCUS, T.RANKS)
	var first := battle.add_unit(K.SNIPER, P1, Vector2i(0, 3))
	var second := battle.add_unit(K.SNIPER, P1, Vector2i(1, 4))
	var target := battle.add_unit(K.SHIELD_TROOPER, P2, Vector2i(3, 3))
	battle.add_unit(K.SHIELD_TROOPER, P2, Vector2i(3, 4))
	_attack(battle, first, target)
	var outcome := Forecast.of(battle, AttackAction.new(second.id, target.id)).outcome(target.id)
	assert_eq(outcome.traits, {T.FOCUS: Traits.FOCUS_BONUS, T.RANKS: Traits.RANKS_GUARD} as Dictionary[int, int])
	assert_eq(outcome.damage, second.power() + Traits.FOCUS_BONUS - Traits.RANKS_GUARD)


# --- CPU ---


func test_cpu_picks_a_trait_that_fits_the_squad() -> void:
	var deck := Deck.new(UnitKind.Army.MILITARY)
	for kind: UnitKind.Id in [K.SNIPER, K.COMMANDO, K.MEDIC]:
		deck.add(kind)
	assert_eq(CpuDeck.choose_trait(deck), T.FOCUS)
	deck.add(K.MEDIC)
	assert_eq(CpuDeck.choose_trait(deck), T.SUPPLY, "回復役が 2 体")
	var knights := Deck.new(UnitKind.Army.FANTASY)
	for kind: UnitKind.Id in [K.PALADIN, K.SPELLBLADE, K.SPELLBLADE, K.SPELLBLADE]:
		knights.add(kind)
	assert_eq(CpuDeck.choose_trait(knights), T.LONE, "奇襲が 3 体")
	var built := CpuDeck.build(UnitKind.Army.FANTASY)
	assert_eq(built.trait_id, CpuDeck.choose_trait(built))
	assert_eq(built.oaths.is_empty(), built.trait_id != T.OATH, "誓いのときだけ結ぶ")


func test_random_squad_picks_a_trait_without_changing_the_units() -> void:
	for squad_seed in 6:
		var deck: Deck = RandomSquad.build(UnitKind.Army.FANTASY, DeckRules.versus(), squad_seed)
		assert_eq(deck.trait_id, CpuDeck.choose_trait(deck))
		assert_true(Traits.of_army(UnitKind.Army.FANTASY).has(deck.trait_id))
