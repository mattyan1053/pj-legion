extends "res://tests/base_test.gd"
## 作戦（試しの決まり。docs/tactics.md）: 手札、使う、札ごとの効果、CPU。

const Maps := preload("res://tests/support/maps.gd")

const P1 := Unit.Side.PLAYER1
const P2 := Unit.Side.PLAYER2
const MARCH := Tactics.Id.MARCH
const SUPPLY := Tactics.Id.SUPPLY
const RALLY := Tactics.Id.RALLY
const WARD := Tactics.Id.WARD


## 将が両端にいる 1 行の盤。プレイヤー1 の手札は hand。
func _battle(hand: Array) -> Battle:
	var battle := Maps.battle(["................", "................"])
	battle.add_unit(UnitKind.Id.KING, P1, Vector2i(0, 0))
	battle.add_unit(UnitKind.Id.KING, P2, Vector2i(15, 0))
	battle.tactics[P1] = hand
	return battle


func _setup(trials: Array[StringName]) -> MatchSetup:
	var setup := MatchSetup.versus_human(
		BoardGenerator.Stage.PLAIN, 1, MatchSetup.default_deck(UnitKind.Army.MILITARY), MatchSetup.default_deck(UnitKind.Army.FANTASY)
	)
	setup.trials = trials
	return setup


# --- 手札 ---


func test_no_hand_without_the_trial() -> void:
	var setup := _setup([])
	setup.tactics[P1] = [MARCH, WARD]
	var battle := setup.create_battle()
	assert_eq(battle.tactics, [[], []])
	for id in Tactics.ALL:
		assert_false(battle.can_apply(UseTacticAction.new(id)))


func test_trial_deals_the_chosen_hand_or_the_default() -> void:
	var setup := _setup([TrialRules.TACTICS])
	setup.tactics[P1] = [WARD, RALLY]
	var battle := setup.create_battle()
	assert_eq(battle.tactics[P1], [WARD, RALLY])
	assert_eq(battle.tactics[P2], Tactics.DEFAULT_HAND as Array)
	assert_eq(battle.tactics_used, [[], []])


func test_hand_is_made_valid() -> void:
	assert_eq(Tactics.hand_from([]), Tactics.DEFAULT_HAND)
	assert_eq(Tactics.hand_from([WARD, WARD, 99, "x"]).size(), Tactics.HAND_SIZE)
	assert_eq(Tactics.hand_from([WARD, WARD])[0], WARD)
	assert_eq(Tactics.hand_from([RALLY, WARD, MARCH]), [RALLY, WARD] as Array[Tactics.Id], "枚数まで")
	for hand_seed in 20:
		var hand := Tactics.random_hand(hand_seed)
		assert_eq(hand.size(), Tactics.HAND_SIZE)
		assert_ne(hand[0], hand[1])
		assert_eq(hand, Tactics.random_hand(hand_seed), "同じ種なら同じ手札")


# --- 使う ---


func test_each_card_is_used_once_on_your_own_phase() -> void:
	var battle := _battle([MARCH, RALLY])
	battle.tactics[P2] = [WARD, SUPPLY]
	assert_false(battle.can_apply(UseTacticAction.new(WARD)), "手札に無い札")
	var result := battle.apply(UseTacticAction.new(MARCH))
	assert_true(result.accepted)
	var used := result.events[0] as TacticUsedEvent
	assert_eq([used.side, used.tactic], [P1, MARCH])
	assert_eq(battle.tactics_used[P1], [MARCH])
	assert_false(battle.can_apply(UseTacticAction.new(MARCH)), "同じ札は 1 回だけ")
	assert_true(battle.can_apply(UseTacticAction.new(RALLY)), "同じ番に、ほかの札は使える")
	battle.apply(EndPhaseAction.new())
	assert_false(battle.can_apply(UseTacticAction.new(RALLY)), "相手の番には使えない")
	assert_true(battle.can_apply(UseTacticAction.new(WARD)))


func test_using_a_card_does_not_spend_a_unit_action() -> void:
	var battle := _battle([SUPPLY])
	var trooper := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(2, 0))
	battle.apply(MoveAction.new(trooper.id, Vector2i(3, 0)))
	assert_true(battle.apply(UseTacticAction.new(SUPPLY)).accepted, "駒が行動の途中でも使える")
	assert_false(trooper.acted)
	assert_true(battle.can_apply(UndoMoveAction.new(trooper.id)))


func test_clone_keeps_hands_apart() -> void:
	var battle := _battle([MARCH, RALLY])
	var copy := battle.clone()
	copy.apply(UseTacticAction.new(MARCH))
	assert_eq(copy.tactics[P1], [MARCH, RALLY])
	assert_eq(battle.tactics_used[P1], [], "複製で使っても、元は使っていない")


# --- 札ごとの効果 ---


func test_march_adds_move_for_this_phase() -> void:
	var battle := _battle([MARCH])
	var trooper := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(2, 0))
	var foe := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(12, 0))
	var move := trooper.move_range()
	var power := trooper.power()
	battle.apply(UseTacticAction.new(MARCH))
	assert_eq(trooper.move_range(), move + Tactics.MARCH_MOVE)
	assert_eq(trooper.power(), power, "攻撃力は変わらない")
	assert_true(Statuses.has(battle.units[0], Status.Type.MARCH), "将にも付く")
	assert_false(Statuses.has(foe, Status.Type.MARCH))
	battle.apply(EndPhaseAction.new())
	battle.apply(EndPhaseAction.new())
	assert_eq(trooper.move_range(), move, "次の自分の番の始めに外れる")


func test_supply_heals_everyone_up_to_max() -> void:
	var battle := _battle([SUPPLY])
	var trooper := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(2, 0))
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(2, 1))
	var foe := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(12, 0))
	trooper.hp -= 20
	sniper.hp -= 3
	foe.hp -= 20
	var events := battle.apply(UseTacticAction.new(SUPPLY)).events
	assert_eq(trooper.hp, trooper.max_hp() - 20 + Tactics.SUPPLY_HEAL)
	assert_eq(sniper.hp, sniper.max_hp(), "最大 HP は超えない")
	assert_eq(foe.hp, foe.max_hp() - 20, "相手は回復しない")
	var healed := events.filter(func(event: BattleEvent) -> bool: return event is TacticHealedEvent)
	assert_eq(healed.size(), 2, "減っていない駒（将）には出ない")
	assert_eq((healed[1] as TacticHealedEvent).amount, 3)
	assert_eq((healed[0] as UnitHealedEvent).cause, UnitHealedEvent.Cause.TACTIC)


func test_rally_charges_the_gauge() -> void:
	var battle := _battle([RALLY])
	battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(2, 0))  # 軍が決まり、ゲージを持つ
	battle.ult_gauge[P1] = Ults.GAUGE_MAX - Tactics.RALLY_GAIN
	var events := battle.apply(UseTacticAction.new(RALLY)).events
	assert_eq(battle.ult_gauge[P1], Ults.GAUGE_MAX)
	assert_true(events[-1] is UltReadyEvent, "いっぱいになったら知らせる")
	assert_true(battle.can_apply(UseUltAction.new()))


func test_ward_puts_a_barrier_on_the_king() -> void:
	var battle := _battle([WARD])
	var trooper := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(2, 0))
	battle.apply(UseTacticAction.new(WARD))
	assert_true(Statuses.has(battle.units[0], Status.Type.BARRIER))
	assert_false(Statuses.has(trooper, Status.Type.BARRIER))
	assert_false(Statuses.has(battle.units[1], Status.Type.BARRIER), "相手の将には付かない")


# --- CPU ---


func _first_action(battle: Battle) -> BattleAction:
	return CpuPlayer.new().next_action(battle)


func test_cpu_never_uses_cards_it_does_not_hold() -> void:
	var battle := _battle([])
	var trooper := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(2, 0))
	trooper.hp = 5
	assert_false(_first_action(battle) is UseTacticAction)


func test_cpu_supplies_when_enough_is_missing() -> void:
	var battle := _battle([SUPPLY])
	var units: Array[Unit] = []
	for x in 3:
		units.append(battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(2 + x, 1)))
	assert_false(_first_action(battle) is UseTacticAction, "減っていなければ使わない")
	for unit in units:
		unit.hp -= 10
	var action := _first_action(battle) as UseTacticAction
	assert_true(action != null and action.tactic == SUPPLY)


func test_cpu_marches_when_it_brings_units_into_reach() -> void:
	var battle := _battle([MARCH])
	for y in 2:
		battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(2, y))
	# コマンドーは移動 6 + 射程 1 = 7。8〜9 マス先なら、強行軍で届く。
	var foe := battle.add_unit(UnitKind.Id.SORCERER, P2, Vector2i(10, 0))
	var action := _first_action(battle) as UseTacticAction
	assert_true(action != null and action.tactic == MARCH)
	foe.cell = Vector2i(14, 0)
	assert_false(_first_action(battle) is UseTacticAction, "それでも届かないなら使わない")


func test_cpu_rallies_to_fill_the_gauge() -> void:
	var battle := _battle([RALLY])
	battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(2, 0))
	assert_false(_first_action(battle) is UseTacticAction, "いっぱいにならないうちは持っておく")
	battle.ult_gauge[P1] = Ults.GAUGE_MAX - Tactics.RALLY_GAIN
	assert_true(_first_action(battle) is UseTacticAction)


func test_cpu_wards_a_threatened_king() -> void:
	var battle := _battle([WARD])
	battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(2, 1))
	assert_false(_first_action(battle) is UseTacticAction, "危なくなければ使わない")
	battle.add_unit(UnitKind.Id.SPELLBLADE, P2, Vector2i(4, 0))
	var action := _first_action(battle) as UseTacticAction
	assert_true(action != null and action.tactic == WARD)
	battle.apply(action)
	assert_false(_first_action(battle) is UseTacticAction, "バリアがあれば、もう使わない")
