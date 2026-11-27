extends "res://tests/base_test.gd"
## 手札（試しの決まり OptionalRules.HAND。docs/hand-cards.md）。配る・引く・使う、札ごとの効果、切のとき何も起きないこと、CPU。

const Maps := preload("res://tests/support/maps.gd")

const P1 := Unit.Side.PLAYER1
const P2 := Unit.Side.PLAYER2
const C := Card.Id

const ROWS: Array[String] = [
	"........",
	"...F....",
	"........",
]


## MILITARY（P1）と FANTASY（P2）の小さな対戦。手札は入で、手は hands のとおり（山は空）。
func _battle(first: Array = [], second: Array = []) -> Battle:
	var battle := Maps.battle(ROWS)
	battle.add_unit(UnitKind.Id.KING, P1, Vector2i(0, 2))
	battle.add_unit(UnitKind.Id.KING, P2, Vector2i(7, 0))
	battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(2, 1))
	battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(3, 1))
	battle.hand_on = true
	battle.hands = [first.duplicate(), second.duplicate()]
	return battle


func _setup(rules: Array[StringName], battle_seed := 3) -> MatchSetup:
	var setup := MatchSetup.new()
	setup.battle_seed = battle_seed
	setup.set_cpu(P1, UnitKind.Army.MILITARY)
	setup.set_cpu(P2, UnitKind.Army.FANTASY)
	setup.rules = rules
	return setup


func _trooper(battle: Battle) -> Unit:
	return battle.unit_at(Vector2i(2, 1))


func _paladin(battle: Battle) -> Unit:
	for unit in battle.units:
		if unit.kind == UnitKind.Id.PALADIN:
			return unit
	return null


# ---- 山と手札 ----


func test_every_pile_has_the_same_size_and_only_known_cards() -> void:
	for army: UnitKind.Army in [UnitKind.Army.MILITARY, UnitKind.Army.FANTASY]:
		var pile := Card.pile_of(army)
		assert_eq(pile.size(), Card.PILE_SIZE, "山の枚数")
		for card in pile:
			assert_true(C.values().has(card))
	assert_true(Card.pile_of(UnitKind.Army.NONE).is_empty(), "軍の無い陣営は山を持たない")
	for id: Card.Id in C.values():
		assert_eq(Card.from_key(Card.key(id)), id)


func test_off_by_default_and_nothing_is_dealt() -> void:
	var battle := _setup([]).create_battle()
	assert_false(battle.hand_on)
	assert_eq(battle.hands, [[], []])
	assert_false(battle.can_apply(PlayCardAction.new(C.MARCH, battle.units[0].cell)))
	var events := battle.apply(EndPhaseAction.new()).events
	assert_false(events.any(func(event: BattleEvent) -> bool: return event is CardDrawnEvent), "切なら、札は引かない")
	assert_false(OptionalRules.DEFAULTS.has(OptionalRules.HAND), "既定は切")
	assert_true(OptionalRules.choosable().has(OptionalRules.HAND), "対戦設定で入にできる")


func test_arm_deals_the_starting_hand_without_touching_the_battle_rng() -> void:
	var off := _setup([]).create_battle()
	var on := _setup([OptionalRules.HAND]).create_battle()
	assert_true(on.hand_on)
	assert_eq(on.rng.state, off.rng.state, "山は対戦の乱数で混ぜない")
	for side: Unit.Side in [P1, P2]:
		assert_eq(Hand.of(on, side).size(), Hand.START_CARDS)
		assert_eq(Hand.pile_left(on, side), Card.PILE_SIZE - Hand.START_CARDS)
	var again := _setup([OptionalRules.HAND]).create_battle()
	assert_eq(again.hands, on.hands, "同じ種なら同じ手札")
	assert_ne(_setup([OptionalRules.HAND], 4).create_battle().piles, on.piles, "種が違えば山の並びも違う")


func test_draws_one_at_the_start_of_the_phase_up_to_the_limit() -> void:
	var battle := _battle([C.MARCH], [])
	battle.piles = [[C.MIGHT, C.MEND], [C.WARD]]
	var events := battle.apply(EndPhaseAction.new()).events
	var drawn := events.filter(func(event: BattleEvent) -> bool: return event is CardDrawnEvent)
	assert_eq(drawn.size(), 1)
	assert_eq([drawn[0].side, drawn[0].card, drawn[0].hand_size, drawn[0].pile_left], [P2, C.WARD, 1, 0])
	battle.apply(EndPhaseAction.new())
	assert_eq(Hand.of(battle, P1), [C.MARCH, C.MEND], "山の上（並びの最後）から引く")
	battle.apply(EndPhaseAction.new())
	assert_eq(Hand.of(battle, P2), [C.WARD], "山が尽きたら引かない")
	battle.hands[P1] = [C.MARCH, C.MARCH, C.MARCH, C.MARCH, C.MARCH]
	battle.apply(EndPhaseAction.new())
	assert_eq(Hand.of(battle, P1).size(), Hand.HAND_LIMIT, "上限なら引かない")
	assert_eq(battle.piles[P1], [C.MIGHT], "引かなかった札は山に残る")


func test_one_card_a_phase_and_not_while_a_unit_is_acting() -> void:
	var battle := _battle([C.MARCH, C.MIGHT], [])
	var trooper := _trooper(battle)
	assert_true(battle.apply(MoveAction.new(trooper.id, Vector2i(2, 0))).accepted)
	assert_false(battle.can_apply(PlayCardAction.new(C.MIGHT, trooper.cell)), "行動の途中の駒がいる間は使えない")
	assert_true(battle.apply(UndoMoveAction.new(trooper.id)).accepted)
	assert_true(battle.apply(PlayCardAction.new(C.MIGHT, trooper.cell)).accepted)
	assert_eq(Hand.of(battle, P1), [C.MARCH], "使った札は手から無くなる")
	assert_false(battle.can_apply(PlayCardAction.new(C.MARCH, trooper.cell)), "1 つの番に 1 枚")
	assert_false(battle.can_apply(PlayCardAction.new(C.WARD, trooper.cell)), "手に無い札は使えない")
	battle.apply(EndPhaseAction.new())
	battle.apply(EndPhaseAction.new())
	assert_true(battle.can_apply(PlayCardAction.new(C.MARCH, trooper.cell)), "次の番には、また使える")


func test_clone_keeps_hands_apart() -> void:
	var battle := _battle([C.MARCH], [])
	var copy := battle.clone()
	copy.apply(PlayCardAction.new(C.MARCH, _trooper(copy).cell))
	assert_eq(Hand.of(battle, P1), [C.MARCH])
	assert_eq(Hand.of(copy, P1), [])


# ---- 札ごとの効果 ----


func test_march_and_might_last_until_the_next_own_phase() -> void:
	var battle := _battle([C.MARCH], [])
	var trooper := _trooper(battle)
	var move := trooper.move_range()
	var events := battle.apply(PlayCardAction.new(C.MARCH, trooper.cell)).events
	assert_true(events[0] is CardPlayedEvent and events[1] is StatusAppliedEvent)
	assert_eq(trooper.move_range(), move + Card.MARCH_MOVE)
	assert_false(trooper.acted, "札は、駒の行動を使わない")
	battle.apply(EndPhaseAction.new())
	battle.apply(EndPhaseAction.new())
	assert_eq(trooper.move_range(), move, "次の自分の番の始めに外れる")

	battle = _battle([C.MIGHT], [])
	trooper = _trooper(battle)
	var paladin := _paladin(battle)
	var before := Forecast.of(battle, AttackAction.new(trooper.id, paladin.id)).outcome(paladin.id).damage
	battle.apply(PlayCardAction.new(C.MIGHT, trooper.cell))
	var forecast := Forecast.of(battle, AttackAction.new(trooper.id, paladin.id)).outcome(paladin.id).damage
	assert_true(forecast > before, "強打は予測に乗る")
	var hp := paladin.hp
	battle.apply(AttackAction.new(trooper.id, paladin.id))
	assert_eq(hp - paladin.hp, forecast, "予測 = 実際")


func test_mend_and_resupply_heal_through_the_mend_path() -> void:
	var battle := _battle([C.MEND, C.RESUPPLY], [])
	var trooper := _trooper(battle)
	assert_false(battle.can_apply(PlayCardAction.new(C.MEND, trooper.cell)), "減っていない駒は選べない")
	trooper.hp -= 3
	var events := battle.apply(PlayCardAction.new(C.MEND, trooper.cell)).events
	var healed := events[1] as CardHealedEvent
	assert_eq([healed.unit_id, healed.amount, healed.hp, healed.card], [trooper.id, 3, trooper.max_hp(), C.MEND], "最大 HP で止まる")
	battle.card_plays[P1] = 0
	var king := battle.units[0]
	king.hp -= 10
	trooper.hp -= 1
	events = battle.apply(PlayCardAction.new(C.RESUPPLY)).events
	assert_eq(events.filter(func(event: BattleEvent) -> bool: return event is CardHealedEvent).size(), 2)
	assert_eq([king.hp, trooper.hp], [king.max_hp() - 10 + Card.RESUPPLY_HEAL, trooper.max_hp()])


func test_encore_reactivates_with_fatigue_and_ward_blocks_one_hit() -> void:
	var battle := _battle([C.ENCORE], [C.WARD])
	var trooper := _trooper(battle)
	assert_false(battle.can_apply(PlayCardAction.new(C.ENCORE, trooper.cell)), "行動済みでない駒は選べない")
	battle.apply(WaitAction.new(trooper.id))
	var events := battle.apply(PlayCardAction.new(C.ENCORE, trooper.cell)).events
	assert_true(events[1] is UnitReactivatedEvent)
	assert_true(battle.can_act(trooper) and Statuses.has(trooper, Status.Type.FATIGUE))
	battle.apply(EndPhaseAction.new())
	var paladin := _paladin(battle)
	battle.apply(PlayCardAction.new(C.WARD, paladin.cell))
	assert_true(Statuses.has(paladin, Status.Type.BARRIER))
	assert_false(Hand.targets(battle, C.WARD).has(paladin.cell), "もうバリアのある駒は選べない")


func test_shove_moves_a_foe_next_to_a_friend_one_cell() -> void:
	var battle := _battle([C.SHOVE], [])
	var paladin := _paladin(battle)
	assert_eq(Hand.targets(battle, C.SHOVE), [paladin.cell], "味方と隣り合う敵だけ（遠い将は選べない）")
	assert_eq(Hand.spots(battle, C.SHOVE, paladin.cell), [Vector2i(3, 0), Vector2i(4, 1), Vector2i(3, 2)] as Array[Vector2i], "隣の空いたマス（味方のいるマスは除く）")
	assert_false(battle.can_apply(PlayCardAction.new(C.SHOVE, paladin.cell, Vector2i(2, 1))), "駒のいるマスへは押せない")
	assert_false(battle.can_apply(PlayCardAction.new(C.SHOVE, paladin.cell)), "動かす先が要る")
	var events := battle.apply(PlayCardAction.new(C.SHOVE, paladin.cell, Vector2i(4, 1))).events
	var pushed := events[1] as UnitPushedEvent
	assert_eq([pushed.unit_id, pushed.from, pushed.to, paladin.cell], [paladin.id, Vector2i(3, 1), Vector2i(4, 1), Vector2i(4, 1)])


func test_shove_off_the_hq_resets_the_capture_count() -> void:
	var battle := _battle([C.SHOVE], [])
	var paladin := _paladin(battle)
	battle.board.hq_cells = [Vector2i(3, 1), Vector2i(7, 0)]
	battle.capture_turns[P2] = 2
	var events := battle.apply(PlayCardAction.new(C.SHOVE, paladin.cell, Vector2i(4, 1))).events
	assert_eq(battle.capture_turns[P2], 0, "本陣から押し出すと、占拠の数が戻る")
	assert_true(events.any(func(event: BattleEvent) -> bool: return event is CaptureProgressEvent))


func test_blink_moves_a_friend_within_range_and_breaks_aim() -> void:
	var battle := _battle([], [C.BLINK])
	battle.apply(EndPhaseAction.new())
	var paladin := _paladin(battle)
	Statuses.add(paladin, Status.Type.AIM, 2)
	var spots := Hand.spots(battle, C.BLINK, paladin.cell)
	assert_true(spots.has(Vector2i(6, 1)) and not spots.has(Vector2i(7, 1)), "BLINK_RANGE 歩まで")
	assert_false(spots.has(Vector2i(2, 1)), "駒のいるマスへは移せない")
	var events := battle.apply(PlayCardAction.new(C.BLINK, paladin.cell, Vector2i(6, 1))).events
	assert_true(events[1] is UnitTeleportedEvent)
	assert_eq(paladin.cell, Vector2i(6, 1))
	assert_false(Statuses.has(paladin, Status.Type.AIM), "動くと外れる状態は外れる")


# ---- CPU ----


func test_cpu_plays_cards_it_can_apply_and_never_reads_the_foe_hand() -> void:
	var battle := _battle([C.MEND], [C.WARD, C.WARD])
	_trooper(battle).hp -= Card.MEND_HEAL
	var action := CpuPlayer.new().next_action(battle)
	assert_true(action is PlayCardAction and (action as PlayCardAction).card == C.MEND, "減っている味方に手当てを使う")
	var blind := battle.clone()
	blind.hands[P2] = []
	blind.piles[P2] = []
	assert_eq((CpuPlayer.new().next_action(blind) as PlayCardAction).target, (action as PlayCardAction).target, "相手の手札と山で、手が変わらない")
	battle.apply(action)
	assert_false(CpuPlayer.new().next_action(battle) is PlayCardAction, "1 つの番に 1 枚")
	var off := _battle()
	off.hand_on = false
	assert_eq(CpuCards.pick(off), null, "切なら、何も返さない")


func test_cpu_games_with_cards_finish_and_use_cards() -> void:
	var setup := _setup([OptionalRules.STRONGHOLD, OptionalRules.HAND], 2)
	setup.scenario = Scenario.versus(BoardGenerator.Stage.LABYRINTH)
	var battle := setup.create_battle()
	var cpu := CpuPlayer.new()
	var plays := 0
	for i in 60:
		var action := cpu.next_action(battle)
		if action == null or battle.is_over():
			break
		assert_true(battle.can_apply(action))
		plays += 1 if action is PlayCardAction else 0
		battle.apply(action)
	assert_true(plays >= 1, "CPU が札を使わない")
	for side: Unit.Side in [P1, P2]:
		assert_true(Hand.of(battle, side).size() <= Hand.HAND_LIMIT)
