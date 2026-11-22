extends "res://tests/base_test.gd"
## 組み方（docs/formation.md）: 連邦の分隊（肩並べ・追い撃ち）、騎士領の誓い（仇討ち・誓いの果て）、編成の誓い、
## 切のときは何も変わらないこと、対戦を作るときの写し方、予測。

const Maps := preload("res://tests/support/maps.gd")

const P1 := Unit.Side.PLAYER1
const P2 := Unit.Side.PLAYER2
const K := UnitKind.Id


## 7 x 7 の平地。組み方は入。
func _battle(formation := true) -> Battle:
	var battle := Maps.battle([".......", ".......", ".......", ".......", ".......", ".......", "......."])
	battle.formation = formation
	return battle


func _effects(events: Array[BattleEvent]) -> Array[Array]:
	var found: Array[Array] = []
	for event in events:
		var triggered := event as FormationTriggeredEvent
		if triggered != null:
			found.append([triggered.effect, triggered.unit_id, triggered.other_id, triggered.amount])
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


# --- 分隊 ---


func test_two_of_a_kind_make_a_squad_and_it_lasts_while_two_remain() -> void:
	var battle := _battle()
	var a := battle.add_unit(K.SNIPER, P1, Vector2i(0, 0))
	var b := battle.add_unit(K.SNIPER, P1, Vector2i(2, 0))
	var c := battle.add_unit(K.SNIPER, P1, Vector2i(4, 0))
	var lone := battle.add_unit(K.COMMANDO, P1, Vector2i(6, 0))
	assert_true(Formation.in_squad(battle, a))
	assert_eq(Formation.squad_of(battle, a).size(), 3)
	assert_false(Formation.in_squad(battle, lone), "1 体では分隊にならない")
	battle.remove_unit(c)
	assert_true(Formation.in_squad(battle, a), "2 体残れば続く")
	battle.remove_unit(b)
	assert_false(Formation.in_squad(battle, a), "1 体になったら切れる")


func test_squads_are_only_for_the_federation() -> void:
	var battle := _battle()
	var a := battle.add_unit(K.PALADIN, P1, Vector2i(0, 0))
	battle.add_unit(K.PALADIN, P1, Vector2i(1, 0))
	assert_false(Formation.in_squad(battle, a))


func test_guard_cuts_attack_damage_next_to_a_squad_mate() -> void:
	var battle := _battle()
	var foe := battle.add_unit(K.COMMANDO, P2, Vector2i(3, 2))
	var guarded := battle.add_unit(K.SHIELD_TROOPER, P1, Vector2i(3, 3))
	battle.add_unit(K.SHIELD_TROOPER, P1, Vector2i(4, 4))  # 斜めの隣
	battle.phase = P2
	var events := _attack(battle, foe, guarded)
	assert_eq(_damage(events), foe.power() - Formation.SQUAD_GUARD)
	assert_eq(_effects(events), [[Formation.Effect.SQUAD_GUARD, guarded.id, foe.id, Formation.SQUAD_GUARD]])


func test_no_guard_when_the_squad_mate_is_two_cells_away() -> void:
	var battle := _battle()
	var foe := battle.add_unit(K.COMMANDO, P2, Vector2i(3, 2))
	var alone := battle.add_unit(K.SHIELD_TROOPER, P1, Vector2i(3, 3))
	battle.add_unit(K.SHIELD_TROOPER, P1, Vector2i(5, 3))
	battle.phase = P2
	var events := _attack(battle, foe, alone)
	assert_eq(_damage(events), foe.power())
	assert_eq(_effects(events), [])


func test_focus_adds_damage_to_the_second_hit_on_the_same_target_in_a_phase() -> void:
	var battle := _battle()
	var first := battle.add_unit(K.SNIPER, P1, Vector2i(0, 3))
	var second := battle.add_unit(K.SNIPER, P1, Vector2i(6, 3))
	var other := battle.add_unit(K.PALADIN, P2, Vector2i(3, 0))
	var target := battle.add_unit(K.PALADIN, P2, Vector2i(3, 3))
	assert_eq(_effects(_attack(battle, first, target)), [], "1 発目は伸びない")
	var events := _attack(battle, second, target)
	assert_eq(_damage(events), second.power() + Formation.SQUAD_FOCUS)
	assert_eq(_effects(events), [[Formation.Effect.SQUAD_FOCUS, second.id, target.id, Formation.SQUAD_FOCUS]])
	assert_false(Formation.focus_on(battle, second, other), "ほかの相手には効かない")
	battle.apply(EndPhaseAction.new())
	assert_false(Formation.focus_on(battle, second, target), "フェーズが替われば消える")


func test_focus_needs_the_same_kind() -> void:
	var battle := _battle()
	var sniper := battle.add_unit(K.SNIPER, P1, Vector2i(0, 3))
	battle.add_unit(K.SNIPER, P1, Vector2i(0, 6))
	var commando := battle.add_unit(K.COMMANDO, P1, Vector2i(3, 4))
	battle.add_unit(K.COMMANDO, P1, Vector2i(6, 6))
	var target := battle.add_unit(K.PALADIN, P2, Vector2i(3, 3))
	_attack(battle, sniper, target)
	assert_eq(_effects(_attack(battle, commando, target)), [], "違う兵種の分隊は続かない")


# --- 誓い ---


func _oath_battle() -> Array:
	var battle := _battle()
	var knight := battle.add_unit(K.PALADIN, P1, Vector2i(2, 3))
	var mage := battle.add_unit(K.SORCERER, P1, Vector2i(2, 5))
	Formation.bind(knight, mage)
	var foe := battle.add_unit(K.COMMANDO, P2, Vector2i(2, 2))
	return [battle, knight, mage, foe]


func test_vengeance_adds_damage_against_the_foe_that_hit_the_partner() -> void:
	var parts := _oath_battle()
	var battle: Battle = parts[0]
	var knight: Unit = parts[1]
	var mage: Unit = parts[2]
	var foe: Unit = parts[3]
	battle.phase = P2
	_attack(battle, foe, knight)
	assert_eq(knight.oath_foe, foe.id)
	battle.phase = P1
	battle.units.map(func(unit: Unit) -> Unit: unit.reset_action(); return unit)
	mage.cell = Vector2i(2, 4)  # 射程 2 で届く、相手から 2 マス
	var events := _attack(battle, mage, foe)
	assert_eq(_damage(events), mage.power() + Formation.OATH_VENGEANCE)
	assert_eq(_effects(events), [[Formation.Effect.OATH_VENGEANCE, mage.id, foe.id, Formation.OATH_VENGEANCE]])


func test_vengeance_needs_the_partner_close() -> void:
	var parts := _oath_battle()
	var battle: Battle = parts[0]
	var knight: Unit = parts[1]
	var mage: Unit = parts[2]
	var foe: Unit = parts[3]
	knight.oath_foe = foe.id
	knight.cell = Vector2i(6, 6)  # 誓いの相手から 4 マスより遠い
	assert_false(Formation.vengeance_on(battle, mage, foe))
	knight.cell = Vector2i(2, 6)
	assert_true(Formation.vengeance_on(battle, mage, foe))


func test_partner_falling_gives_resolve_for_the_next_own_phase_and_breaks_the_oath() -> void:
	var parts := _oath_battle()
	var battle: Battle = parts[0]
	var knight: Unit = parts[1]
	var mage: Unit = parts[2]
	var foe: Unit = parts[3]
	battle.phase = P2
	mage.hp = 1
	mage.cell = Vector2i(2, 1)
	var power := knight.power()
	var events := _attack(battle, foe, mage)
	var broken := events.filter(func(event: BattleEvent) -> bool: return event is OathBrokenEvent)
	assert_eq(broken.size(), 1)
	assert_eq((broken[0] as OathBrokenEvent).survivor_id, knight.id)
	assert_true(Statuses.has(knight, Status.Type.RESOLVE))
	assert_eq(knight.power(), power + Formation.RESOLVE_POWER)
	assert_eq(knight.oath_partner, 0, "誓いは切れる")
	battle.apply(EndPhaseAction.new())  # 中立を通って、次のターンのプレイヤー1
	assert_eq(battle.phase, P1)
	assert_true(Statuses.has(knight, Status.Type.RESOLVE), "自分のフェーズの間は残る")
	battle.apply(EndPhaseAction.new())
	battle.apply(EndPhaseAction.new())
	assert_false(Statuses.has(knight, Status.Type.RESOLVE), "次の自分のフェーズの始めに外れる")
	assert_eq(knight.power(), power)


# --- 切のとき ---


func test_nothing_happens_when_the_rule_is_off() -> void:
	var battle := _battle(false)
	var first := battle.add_unit(K.SNIPER, P1, Vector2i(0, 3))
	var second := battle.add_unit(K.SNIPER, P1, Vector2i(1, 4))
	var target := battle.add_unit(K.SHIELD_TROOPER, P2, Vector2i(3, 3))
	battle.add_unit(K.SHIELD_TROOPER, P2, Vector2i(3, 4))
	assert_false(Formation.in_squad(battle, first))
	_attack(battle, first, target)
	var events := _attack(battle, second, target)
	assert_eq(_effects(events), [])
	assert_eq(_damage(events), second.power())
	assert_eq(battle.focus_marks, {})


# --- 編成 ---


func test_deck_binds_up_to_two_oaths_for_the_knights_only() -> void:
	var deck := Deck.new(UnitKind.Army.FANTASY)
	var a := deck.add(K.PALADIN)
	var b := deck.add(K.SORCERER)
	var c := deck.add(K.SPELLBLADE)
	var d := deck.add(K.PRIEST)
	var e := deck.add(K.PALADIN)
	assert_true(deck.bind(a, b))
	assert_false(deck.bind(a, c), "1 体は 1 組まで")
	assert_false(deck.bind(c, c))
	assert_true(deck.bind(c, d))
	assert_eq(deck.partner_of(d), c)
	assert_false(deck.bind(e, e), "同じ駒は結べない")
	assert_eq(deck.oath_pairs(), [Vector2i(0, 1), Vector2i(2, 3)])
	var copy := deck.copy()
	assert_eq(copy.oath_pairs(), [Vector2i(0, 1), Vector2i(2, 3)])
	assert_eq(copy.partner_of(copy.entries[0]), copy.entries[1])
	deck.remove(b)
	assert_eq(deck.oath_pairs(), [Vector2i(1, 2)], "外した駒の誓いはほどける")
	assert_true(deck.bind(a, e))
	var federation := Deck.new(UnitKind.Army.MILITARY)
	assert_false(federation.bind(federation.add(K.SNIPER), federation.add(K.MEDIC)))


func test_deck_squad_kinds() -> void:
	var deck := Deck.new(UnitKind.Army.MILITARY)
	for kind: UnitKind.Id in [K.SNIPER, K.SNIPER, K.COMMANDO, K.SHIELD_TROOPER, K.SHIELD_TROOPER]:
		deck.add(kind)
	assert_eq(Formation.squad_kinds(deck), [K.SHIELD_TROOPER, K.SNIPER])


func test_match_setup_copies_oaths_only_when_the_rule_is_on() -> void:
	var knights := Deck.new(UnitKind.Army.FANTASY)
	var a := knights.add(K.PALADIN)
	knights.add(K.SORCERER)
	var c := knights.add(K.PRIEST)
	knights.bind(a, c)
	var setup := MatchSetup.versus_human(BoardGenerator.Stage.PLAIN, 1, MatchSetup.default_deck(UnitKind.Army.MILITARY), knights)
	var off := setup.create_battle()
	assert_false(off.formation)
	for unit in off.units:
		assert_eq(unit.oath_partner, 0)
	setup.rules = [OptionalRules.FORMATION]
	var on := setup.create_battle()
	assert_true(on.formation)
	var paladin: Unit = on.units.filter(func(unit: Unit) -> bool: return unit.kind == K.PALADIN)[0]
	var priest: Unit = on.units.filter(func(unit: Unit) -> bool: return unit.kind == K.PRIEST)[0]
	assert_eq(paladin.oath_partner, priest.id)
	assert_eq(priest.oath_partner, paladin.id)


func test_forecast_shows_the_formation_part() -> void:
	var battle := _battle()
	var first := battle.add_unit(K.SNIPER, P1, Vector2i(0, 3))
	var second := battle.add_unit(K.SNIPER, P1, Vector2i(6, 3))
	var target := battle.add_unit(K.SHIELD_TROOPER, P2, Vector2i(3, 3))
	battle.add_unit(K.SHIELD_TROOPER, P2, Vector2i(3, 4))
	battle.add_unit(K.SHIELD_TROOPER, P2, Vector2i(3, 2))  # 相手も連邦の分隊で、肩並べになる
	_attack(battle, first, target)
	var forecast := Forecast.of(battle, AttackAction.new(second.id, target.id))
	var outcome := forecast.outcome(target.id)
	assert_eq(outcome.formation, {Formation.Effect.SQUAD_FOCUS: Formation.SQUAD_FOCUS, Formation.Effect.SQUAD_GUARD: Formation.SQUAD_GUARD})
	assert_eq(outcome.damage, second.power() + Formation.SQUAD_FOCUS - Formation.SQUAD_GUARD)


# --- CPU の編成 ---


func test_cpu_deck_binds_fighting_pairs_for_the_knights() -> void:
	var deck := CpuDeck.build(UnitKind.Army.FANTASY)
	assert_eq(deck.oaths.size(), Formation.MAX_OATHS)
	for pair in deck.oaths:
		for entry: DeckEntry in pair:
			assert_ne(UnitKind.role(entry.kind), UnitKind.Role.HEALER, "回復役は結ばない")
	assert_eq(CpuDeck.build(UnitKind.Army.MILITARY).oaths, [])


func test_random_squad_binds_oaths_without_changing_the_units() -> void:
	const RandomSquad := preload("res://game/random_squad.gd")
	for squad_seed in 20:
		var deck := RandomSquad.build(UnitKind.Army.FANTASY, DeckRules.versus(), squad_seed)
		assert_between(deck.oaths.size(), 1, Formation.MAX_OATHS)
		var bare := deck.copy()
		bare.oaths.clear()
		assert_eq(bare.entries.size(), deck.entries.size())
		assert_eq(RandomSquad.build(UnitKind.Army.MILITARY, DeckRules.versus(), squad_seed).oaths, [])
