extends "res://tests/base_test.gd"
## 進化（docs/branch-evolution.md）: 16 の進化先の中身、選ぶまでの対戦の止まり方、選んだあとの能力値と特性。

const Maps := preload("res://tests/support/maps.gd")

const P1 := Unit.Side.PLAYER1
const P2 := Unit.Side.PLAYER2

const HP := Unit.Stat.MAX_HP
const POWER := Unit.Stat.POWER
const MOVE := Unit.Stat.MOVE_RANGE
const RANGE := Unit.Stat.ATTACK_RANGE

const HIREABLE: Array[UnitKind.Id] = [
	UnitKind.Id.SHIELD_TROOPER, UnitKind.Id.SNIPER, UnitKind.Id.COMMANDO, UnitKind.Id.MEDIC,
	UnitKind.Id.PALADIN, UnitKind.Id.SORCERER, UnitKind.Id.SPELLBLADE, UnitKind.Id.PRIEST,
]


func _battle() -> Battle:
	return Maps.battle([
		"........",
		"........",
		"........",
	])


func _types(events: Array[BattleEvent]) -> Array[Script]:
	var result: Array[Script] = []
	for event in events:
		result.append(event.get_script())
	return result


## あと 1 回当てれば上限のレベルに届く駒にする。
func _almost_max(unit: Unit) -> void:
	unit.level = Growth.MAX_LEVEL - 1
	unit.experience = Growth.EXPERIENCE_PER_LEVEL - Growth.HIT_EXPERIENCE


## 駒を置き、進化させて返す。
func _evolved(battle: Battle, evolution: Evolution.Id, side: Unit.Side, cell: Vector2i) -> Unit:
	var unit := battle.add_unit(Evolution.origin(evolution), side, cell)
	unit.evolve(evolution)
	return unit


## sniper が target に当てて上限のレベルに届き、進化先を選ぶのを待っている対戦。
func _waiting() -> Dictionary:
	var battle := _battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	var ally := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(0, 2))
	var target := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(3, 0))
	_almost_max(sniper)
	var events := battle.apply(AttackAction.new(sniper.id, target.id)).events
	return {"battle": battle, "sniper": sniper, "ally": ally, "target": target, "events": events}


# ---- 進化先の表 ----


func test_every_hireable_kind_has_two_evolutions() -> void:
	var names := {}
	for kind in HIREABLE:
		var options := Evolution.options_for(kind)
		assert_eq(options.size(), 2, str(UnitKind.Id.find_key(kind)))
		for id in options:
			assert_eq(Evolution.origin(id), kind)
			names[str(Evolution.Id.find_key(id))] = true
	assert_eq(names.size(), 16, "名前が重なっている")
	for kind: UnitKind.Id in UnitKind.Id.values():
		assert_false(names.has(str(UnitKind.Id.find_key(kind))), "種類の名前と同じ: %s" % str(UnitKind.Id.find_key(kind)))
	assert_eq(Evolution.Id.size(), 17)  # NONE + 16


func test_kings_and_neutrals_do_not_evolve() -> void:
	for kind: UnitKind.Id in [UnitKind.Id.KING, UnitKind.Id.MINION, UnitKind.Id.ELITE_MINION]:
		assert_eq(Evolution.options_for(kind), [] as Array[Evolution.Id])


func test_the_sixteen_routes() -> void:
	var zoc: Array[Evolution.Trait] = [Evolution.Trait.EXERTS_ZOC]
	var slip: Array[Evolution.Trait] = [Evolution.Trait.IGNORES_ZOC]
	var forest: Array[Evolution.Trait] = [Evolution.Trait.FOREST_WALK]
	var regeneration: Array[Evolution.Trait] = [Evolution.Trait.REGENERATION]
	var none: Array[Evolution.Trait] = []
	# 種類 -> [[A の名前, 増減, 特性], [B の名前, 増減, 特性]]
	var expected := {
		UnitKind.Id.SHIELD_TROOPER: [["BULWARK", {HP: 18}, none], ["JUGGERNAUT", {MOVE: 2, POWER: 2}, none]],
		UnitKind.Id.SNIPER: [["MARKSMAN", {RANGE: 2, POWER: 2, MOVE: -1}, none], ["SCOUT", {MOVE: 2, HP: 8}, none]],
		UnitKind.Id.COMMANDO: [["ASSAULT", {POWER: 4, HP: 6}, none], ["INFILTRATOR", {MOVE: 1}, slip]],
		UnitKind.Id.MEDIC: [["SURGEON", {POWER: 8}, none], ["COMBAT_MEDIC", {MOVE: 2, HP: 10}, none]],
		UnitKind.Id.PALADIN: [["SACRED", {HP: 10}, regeneration], ["CRUSADER", {POWER: 4, MOVE: 1}, none]],
		UnitKind.Id.SORCERER: [["ARCHMAGE", {POWER: 4, RANGE: 1}, none], ["ENCHANTER", {HP: 8}, zoc]],
		UnitKind.Id.SPELLBLADE: [["ARC_BLADE", {RANGE: 1, POWER: 1}, none], ["FEY_WALKER", {MOVE: 2}, forest]],
		UnitKind.Id.PRIEST: [["BISHOP", {RANGE: 2, POWER: 2}, none], ["SAINT", {HP: 12}, regeneration]],
	}
	for kind: UnitKind.Id in expected:
		var options := Evolution.options_for(kind)
		for i in 2:
			var route: Array = expected[kind][i]
			assert_eq(str(Evolution.Id.find_key(options[i])), route[0])
			assert_eq(Evolution.bonuses(options[i]), route[1], route[0])
			assert_eq(Evolution.traits(options[i]), route[2], route[0])


func test_an_unevolved_unit_has_no_bonus_and_no_trait() -> void:
	assert_eq(Evolution.origin(Evolution.Id.BULWARK), UnitKind.Id.SHIELD_TROOPER)
	assert_eq(Evolution.bonus(Evolution.Id.NONE, HP), 0)
	assert_eq(Evolution.traits(Evolution.Id.NONE), [] as Array[Evolution.Trait])
	var battle := _battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	assert_eq(sniper.evolution, Evolution.Id.NONE)
	assert_false(sniper.exerts_zoc())
	assert_false(sniper.ignores_zoc())


# ---- 選ぶまで ----


func test_reaching_the_top_level_offers_the_two_evolutions() -> void:
	var made := _waiting()
	var battle: Battle = made["battle"]
	var sniper: Unit = made["sniper"]
	var events: Array[BattleEvent] = made["events"]
	assert_eq(
		_types(events),
		[AttackDamagedEvent, ExperienceGainedEvent, LevelUpEvent, EvolutionOfferedEvent, UnitActedEvent] as Array[Script]
	)
	var offered := events[3] as EvolutionOfferedEvent
	assert_eq(offered.unit_id, sniper.id)
	assert_eq(offered.choices, [Evolution.Id.MARKSMAN, Evolution.Id.SCOUT] as Array[Evolution.Id])
	assert_eq(battle.evolving_unit(), sniper)
	assert_eq(sniper.evolution, Evolution.Id.NONE)
	assert_true(sniper.acted)


func test_healing_to_the_top_level_offers_too() -> void:
	var battle := _battle()
	var priest := battle.add_unit(UnitKind.Id.PRIEST, P1, Vector2i(0, 0))
	var ally := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(1, 0))
	ally.hp = 1
	priest.level = 2
	priest.experience = Growth.EXPERIENCE_PER_LEVEL - Growth.HEAL_EXPERIENCE
	var events := battle.apply(HealAction.new(priest.id, ally.id)).events
	assert_eq(
		_types(events),
		[HealerHealedEvent, ExperienceGainedEvent, LevelUpEvent, EvolutionOfferedEvent, UnitActedEvent] as Array[Script]
	)
	assert_eq((events[3] as EvolutionOfferedEvent).choices, [Evolution.Id.BISHOP, Evolution.Id.SAINT] as Array[Evolution.Id])


func test_lower_levels_offer_nothing() -> void:
	var battle := _battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	var events := Growth.gain(sniper, Growth.EXPERIENCE_PER_LEVEL, ExperienceGainedEvent.Reason.HIT)
	assert_eq(_types(events), [ExperienceGainedEvent, LevelUpEvent] as Array[Script])
	assert_eq(battle.evolving_unit(), null)
	assert_false(Growth.preview(sniper, 50).evolution_ready)
	assert_true(Growth.preview(sniper, Growth.EXPERIENCE_PER_LEVEL).evolution_ready)
	assert_false(sniper.evolution_ready, "見込みは状態を変えない")


func test_nothing_else_is_accepted_until_the_choice() -> void:
	var made := _waiting()
	var battle: Battle = made["battle"]
	var sniper: Unit = made["sniper"]
	var ally: Unit = made["ally"]
	assert_false(battle.can_act(ally))
	assert_false(battle.can_apply(MoveAction.new(ally.id, Vector2i(1, 2), false)))
	assert_false(battle.can_apply(WaitAction.new(ally.id)))
	assert_false(battle.can_apply(EndPhaseAction.new()))
	assert_false(battle.apply(EndPhaseAction.new()).accepted)
	assert_eq(battle.phase, P1)
	assert_true(battle.options(ally.id).is_empty())
	var options := battle.options(sniper.id)
	assert_eq(options.evolutions, [Evolution.Id.MARKSMAN, Evolution.Id.SCOUT] as Array[Evolution.Id])
	assert_false(options.is_empty())
	assert_false(options.can_wait)
	assert_true(options.move_cells.is_empty())
	var actions := options.actions()
	assert_eq(actions.size(), 2)
	for action in actions:
		assert_true(action is EvolveAction)
		assert_true(battle.can_apply(action))


func test_only_the_waiting_unit_can_choose_one_of_its_own() -> void:
	var made := _waiting()
	var battle: Battle = made["battle"]
	var sniper: Unit = made["sniper"]
	var ally: Unit = made["ally"]
	assert_false(battle.can_apply(EvolveAction.new(ally.id, Evolution.Id.ASSAULT)))
	assert_false(battle.can_apply(EvolveAction.new(sniper.id, Evolution.Id.ASSAULT)))
	assert_false(battle.can_apply(EvolveAction.new(sniper.id, Evolution.Id.NONE)))
	assert_false(battle.can_apply(EvolveAction.new(99, Evolution.Id.MARKSMAN)))
	assert_true(battle.can_apply(EvolveAction.new(sniper.id, Evolution.Id.MARKSMAN)))
	assert_true(battle.can_apply(EvolveAction.new(sniper.id, Evolution.Id.SCOUT)))


func test_choosing_evolves_the_unit_and_resumes_the_battle() -> void:
	var made := _waiting()
	var battle: Battle = made["battle"]
	var sniper: Unit = made["sniper"]
	var ally: Unit = made["ally"]
	sniper.hp -= 5
	var result := battle.apply(EvolveAction.new(sniper.id, Evolution.Id.SCOUT))
	assert_true(result.accepted)
	assert_eq(_types(result.events), [UnitEvolvedEvent] as Array[Script])
	var evolved := result.events[0] as UnitEvolvedEvent
	assert_eq(evolved.unit_id, sniper.id)
	assert_eq(evolved.evolution, Evolution.Id.SCOUT)
	# スナイパー: HP 13、攻撃 7、移動 3、射程 4。ここではレベル 3 へ上がった 1 回ぶんだけ伸びている（HP +3、攻撃 +1）。
	# スカウトで 移動 +2、HP +8。
	assert_eq(evolved.max_hp, 24)
	assert_eq(evolved.hp, 19, "最大 HP が伸びたぶん、HP も増える")
	assert_eq(evolved.power, 8)
	assert_eq(evolved.move_range, 5)
	assert_eq(evolved.attack_range, 4)
	assert_eq(sniper.max_hp(), 24)
	assert_eq(sniper.hp, 19)
	assert_eq(sniper.move_range(), 5)
	assert_eq(sniper.evolution, Evolution.Id.SCOUT)
	assert_eq(sniper.kind, UnitKind.Id.SNIPER, "種類（役割と軍）は変わらない")
	# 対戦が続く。進化した駒は、もう行動を終えている。
	assert_eq(battle.evolving_unit(), null)
	assert_true(sniper.acted)
	assert_false(battle.can_act(sniper))
	assert_true(battle.can_act(ally))
	assert_true(battle.can_apply(EndPhaseAction.new()))
	assert_true(battle.options(sniper.id).is_empty())
	assert_false(battle.can_apply(EvolveAction.new(sniper.id, Evolution.Id.MARKSMAN)), "選び直せない")


func test_an_evolved_unit_gains_nothing_more() -> void:
	var made := _waiting()
	var battle: Battle = made["battle"]
	var sniper: Unit = made["sniper"]
	battle.apply(EvolveAction.new(sniper.id, Evolution.Id.MARKSMAN))
	assert_eq(Growth.gain(sniper, Growth.EXPERIENCE_PER_LEVEL, ExperienceGainedEvent.Reason.HIT), [] as Array[BattleEvent])
	assert_eq(battle.evolving_unit(), null)


func test_winning_with_the_same_attack_ends_the_game_without_a_choice() -> void:
	var battle := _battle()
	battle.add_unit(UnitKind.Id.KING, P1, Vector2i(7, 2))
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	var king := battle.add_unit(UnitKind.Id.KING, P2, Vector2i(3, 0))
	king.hp = 1
	sniper.level = 2
	sniper.experience = Growth.EXPERIENCE_PER_LEVEL - Growth.DEFEAT_EXPERIENCE  # この攻撃で上限のレベルに届く
	battle.apply(AttackAction.new(sniper.id, king.id))
	assert_true(battle.is_over())
	assert_eq(battle.winner, P1)
	assert_true(battle.options(sniper.id).is_empty())
	assert_false(battle.can_apply(EvolveAction.new(sniper.id, Evolution.Id.SCOUT)))


func test_the_choice_carries_over_to_a_clone() -> void:
	var made := _waiting()
	var battle: Battle = made["battle"]
	var sniper: Unit = made["sniper"]
	var copy := battle.clone()
	assert_eq(copy.evolving_unit().id, sniper.id)
	assert_true(copy.apply(EvolveAction.new(sniper.id, Evolution.Id.MARKSMAN)).accepted)
	assert_eq(copy.unit_by_id(sniper.id).evolution, Evolution.Id.MARKSMAN)
	assert_eq(sniper.evolution, Evolution.Id.NONE)
	assert_eq(battle.evolving_unit(), sniper, "元は待ったまま")
	battle.apply(EvolveAction.new(sniper.id, Evolution.Id.SCOUT))
	var later := battle.clone()
	assert_eq(later.unit_by_id(sniper.id).evolution, Evolution.Id.SCOUT)
	assert_eq(later.unit_by_id(sniper.id).move_range(), 5)


# ---- 能力値 ----


func test_bonuses_stack_on_growth_and_equipment() -> void:
	var battle := _battle()
	var boots: Array[Equipment.Id] = [Equipment.Id.SPEED_BOOTS]
	var trooper := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(0, 0), boots)
	Growth.gain(trooper, 2 * Growth.EXPERIENCE_PER_LEVEL, ExperienceGainedEvent.Reason.HIT)  # レベル 3: HP +12、攻撃 +2
	trooper.evolve(Evolution.Id.JUGGERNAUT)
	assert_eq(trooper.max_hp(), 44 + 12)
	assert_eq(trooper.power(), 6 + 2 + 2)
	assert_eq(trooper.move_range(), 3 + 2 + 2)
	assert_eq(UnitKind.move_range(UnitKind.Id.SHIELD_TROOPER), 3, "種類の基本の値は変わらない")


func test_a_longer_range_reaches_further() -> void:
	var battle := _battle()
	var marksman := _evolved(battle, Evolution.Id.MARKSMAN, P1, Vector2i(0, 0))
	var near := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(6, 0))
	var far := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(7, 0))
	assert_eq(marksman.attack_range(), 6)
	assert_eq(marksman.move_range(), 2)
	assert_eq(battle.options(marksman.id).attack_target_ids, [near.id] as Array[int])
	assert_false(battle.can_apply(AttackAction.new(marksman.id, far.id)))
	assert_eq(Combat.damage(battle, marksman, near), 9)


func test_healer_evolutions_change_the_heal() -> void:
	var battle := _battle()
	var bishop := _evolved(battle, Evolution.Id.BISHOP, P1, Vector2i(0, 0))
	var surgeon := _evolved(battle, Evolution.Id.SURGEON, P1, Vector2i(0, 2))
	var ally := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(4, 0))
	ally.hp = 1
	assert_true(Healing.can_heal(battle, bishop, ally), "射程 4")
	assert_eq(Healing.amount(bishop, ally), 16)
	assert_false(Healing.can_heal(battle, surgeon, ally))
	surgeon.cell = Vector2i(4, 1)
	assert_eq(Healing.amount(surgeon, ally), 23)


# ---- 特性 ----


func test_an_enchanter_makes_a_zone_of_control() -> void:
	var battle := _battle()
	var enchanter := _evolved(battle, Evolution.Id.ENCHANTER, P2, Vector2i(3, 1))
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(0, 1))
	assert_true(enchanter.exerts_zoc())
	assert_true(battle.is_in_enemy_zoc(Vector2i(2, 1), P1))
	assert_false(battle.is_in_enemy_zoc(Vector2i(2, 1), P2))
	var reach := Movement.reachable(battle, commando)
	assert_true(reach.has(Vector2i(2, 1)))
	assert_false(reach.has(Vector2i(4, 1)) and reach[Vector2i(4, 1)] <= 4, "支配領域を通り抜けては行けない")
	enchanter.evolution = Evolution.Id.ARCHMAGE
	assert_false(battle.is_in_enemy_zoc(Vector2i(2, 1), P1))


func test_an_infiltrator_walks_through_zones_of_control() -> void:
	var board := Maps.board([
		"...#....",
		"........",
		"...#....",
	])
	var battle := Battle.new(board)
	battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(4, 0))
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(0, 1))
	# 壁（パラディンが (4, 0)）の脇を抜ける道は、(3, 1) で支配領域に入る。
	assert_true(battle.is_in_enemy_zoc(Vector2i(3, 1), P1))
	assert_false(Movement.reachable(battle, commando).has(Vector2i(5, 1)))
	commando.evolve(Evolution.Id.INFILTRATOR)
	assert_true(commando.ignores_zoc())
	var reach := Movement.reachable(battle, commando)
	assert_eq(reach.get(Vector2i(5, 1), -1), 5)
	assert_eq(commando.move_range(), 7)
	assert_false(reach.has(Vector2i(4, 0)), "敵のいるマスには入れない")
	assert_true(battle.apply(MoveAction.new(commando.id, Vector2i(5, 1), false)).accepted)


func test_a_fey_walker_crosses_forests_at_plain_cost() -> void:
	var battle := Maps.battle([
		".FFFFFFFF.",
	])
	var blade := battle.add_unit(UnitKind.Id.SPELLBLADE, P1, Vector2i(0, 0))  # 移動力 6
	assert_false(Movement.reachable(battle, blade).has(Vector2i(4, 0)))
	blade.evolve(Evolution.Id.FEY_WALKER)  # 移動力 8
	var reach := Movement.reachable(battle, blade)
	assert_eq(reach.get(Vector2i(8, 0), -1), 8)
	assert_false(reach.has(Vector2i(9, 0)))
	assert_eq(Movement.reachable(battle, blade, true).get(Vector2i(9, 0), -1), 9)


func test_forest_walkers_still_cannot_enter_obstacles_and_barrels() -> void:
	var battle := Maps.battle([
		".#.",
		"B..",
	])
	var blade := _evolved(battle, Evolution.Id.FEY_WALKER, P1, Vector2i(0, 0))
	assert_true(blade.move_cost(battle.board, Vector2i(1, 0)) < 0)
	assert_true(blade.move_cost(battle.board, Vector2i(0, 1)) < 0)
	assert_eq(Movement.reachable(battle, blade).keys(), [Vector2i(0, 0)])


func test_regeneration_heals_at_the_start_of_the_own_phase() -> void:
	var battle := Maps.battle([
		"S.......",
		"........",
	])
	var sacred := _evolved(battle, Evolution.Id.SACRED, P1, Vector2i(3, 0))
	var bathing := _evolved(battle, Evolution.Id.SAINT, P1, Vector2i(0, 0))
	var scratched := _evolved(battle, Evolution.Id.SACRED, P1, Vector2i(5, 1))
	var healthy := _evolved(battle, Evolution.Id.SACRED, P1, Vector2i(7, 1))
	var plain := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(6, 0))
	sacred.hp -= 20
	bathing.hp -= 25
	scratched.hp -= 2
	plain.hp -= 20
	assert_eq(Evolution.regeneration_targets(battle, P1), [bathing, sacred, scratched] as Array[Unit])
	assert_eq(Evolution.regeneration_targets(battle, P2), [] as Array[Unit])
	assert_eq(Evolution.regeneration_heal(scratched), 2)
	assert_eq(Evolution.regeneration_heal(healthy), 0)
	assert_eq(Evolution.regeneration_heal(plain), 0)

	var events := battle.apply(EndPhaseAction.new()).events
	assert_eq(_types(events), [PhaseStartedEvent] as Array[Script], "相手のフェーズの始めには回復しない")
	events = battle.apply(EndPhaseAction.new()).events
	# 中立のフェーズ、次のターンのプレイヤー1 のフェーズ。泉の回復のあとに、再生が続く。
	var tail := events.slice(events.size() - 4)
	assert_eq(
		_types(tail),
		[SpringHealedEvent, RegenerationHealedEvent, RegenerationHealedEvent, RegenerationHealedEvent] as Array[Script]
	)
	var first := tail[1] as RegenerationHealedEvent
	assert_eq(first.unit_id, bathing.id)
	assert_eq(first.amount, 5)
	assert_eq(first.cause, UnitHealedEvent.Cause.REGENERATION)
	assert_eq(bathing.hp, bathing.max_hp() - 25 + MapObject.SPRING_HEAL + 5)
	assert_eq(sacred.hp, sacred.max_hp() - 15)
	assert_eq(scratched.hp, scratched.max_hp())
	assert_eq((tail[3] as RegenerationHealedEvent).amount, 2)
	assert_eq(plain.hp, plain.max_hp() - 20)
