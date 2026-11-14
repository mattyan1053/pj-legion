extends "res://tests/base_test.gd"
## 勝ち負け: 敵の将を倒す / 敵の本陣を 3 フェーズ占拠し続ける。

const Maps := preload("res://tests/support/maps.gd")

const P1 := Unit.Side.PLAYER1
const P2 := Unit.Side.PLAYER2
const P1_HQ := Vector2i(2, 4)
const P2_HQ := Vector2i(2, 0)


func _battle() -> Battle:
	var battle := Maps.battle([
		".....",
		".....",
		".....",
		".....",
		".....",
	])
	battle.board.hq_cells = [P1_HQ, P2_HQ]
	return battle


## プレイヤー2 のフェーズとその先の中立を飛ばして、次のターンのプレイヤー1 のフェーズへ。
func _skip_to_next_p1_phase(battle: Battle) -> void:
	assert_eq(battle.phase, P2)
	battle.apply(EndPhaseAction.new())
	assert_eq(battle.phase, P1)


func test_defeating_the_enemy_king_wins() -> void:
	var battle := _battle()
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(0, 0))
	var king := battle.add_unit(UnitKind.Id.KING, P2, Vector2i(1, 0))
	king.hp = 5
	var events := battle.apply(AttackAction.new(commando.id, king.id))
	var won := events[-1] as GameWonEvent
	assert_true(won != null)
	assert_eq(won.winner, P1)
	assert_eq(won.reason, GameWonEvent.Reason.KING_DEFEATED)
	assert_eq(battle.winner, P1)
	assert_true(battle.is_over())


func test_defeating_other_units_does_not_win() -> void:
	var battle := _battle()
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(0, 0))
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(1, 0))
	sniper.hp = 5
	battle.apply(AttackAction.new(commando.id, sniper.id))
	assert_eq(battle.unit_by_id(sniper.id), null)
	assert_false(battle.is_over())


func test_nothing_is_accepted_after_the_game_ends() -> void:
	var battle := _battle()
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(0, 0))
	var other := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 3))
	var king := battle.add_unit(UnitKind.Id.KING, P2, Vector2i(1, 0))
	king.hp = 1
	battle.apply(AttackAction.new(commando.id, king.id))
	assert_eq(battle.apply(MoveAction.new(other.id, Vector2i(1, 3))), [])
	assert_eq(battle.apply(WaitAction.new(other.id)), [])
	assert_eq(battle.apply(EndPhaseAction.new()), [])


func test_holding_the_enemy_hq_for_three_phases_wins() -> void:
	var battle := _battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(2, 2))
	battle.apply(MoveAction.new(sniper.id, P2_HQ))

	var events := battle.apply(EndPhaseAction.new())  # ターン 1 の P1 の終わり
	assert_eq((events[1] as CaptureProgressEvent).turns, 1)
	assert_eq(battle.capture_turns[P1], 1)
	_skip_to_next_p1_phase(battle)

	battle.apply(EndPhaseAction.new())  # ターン 2
	assert_eq(battle.capture_turns[P1], 2)
	assert_false(battle.is_over())
	_skip_to_next_p1_phase(battle)

	events = battle.apply(EndPhaseAction.new())  # ターン 3
	assert_eq(battle.capture_turns[P1], 3)
	var won := events[-1] as GameWonEvent
	assert_true(won != null)
	assert_eq(won.winner, P1)
	assert_eq(won.reason, GameWonEvent.Reason.HQ_CAPTURED)
	assert_eq(battle.phase, P1)  # 決着したので次のフェーズへは進まない
	for event in events:
		assert_false(event is PhaseStartedEvent)


func test_entering_the_hq_alone_does_not_win() -> void:
	var battle := _battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(2, 2))
	var events := battle.apply(MoveAction.new(sniper.id, P2_HQ))
	assert_eq(events.size(), 1)
	assert_eq(battle.capture_turns[P1], 0)  # 数えるのはフェーズの終わり
	battle.apply(EndPhaseAction.new())
	assert_eq(battle.capture_turns[P1], 1)
	assert_false(battle.is_over())


func test_leaving_the_hq_resets_the_count_at_once() -> void:
	var battle := _battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(2, 2))
	battle.apply(MoveAction.new(sniper.id, P2_HQ))
	battle.apply(EndPhaseAction.new())
	_skip_to_next_p1_phase(battle)
	var events := battle.apply(MoveAction.new(sniper.id, Vector2i(2, 1)))
	assert_eq(battle.capture_turns[P1], 0)
	var reset := events[-1] as CaptureProgressEvent
	assert_true(reset != null)
	assert_eq(reset.player, P1)
	assert_eq(reset.turns, 0)


func test_losing_the_occupier_resets_the_count() -> void:
	var battle := _battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(2, 2))
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P2, Vector2i(1, 0))  # 本陣の隣
	battle.apply(MoveAction.new(sniper.id, P2_HQ))
	battle.apply(EndPhaseAction.new())  # 占拠 1、P2 のフェーズへ
	sniper.hp = 1
	var events := battle.apply(AttackAction.new(commando.id, sniper.id))
	assert_eq(battle.capture_turns[P1], 0)
	assert_true(events[-1] is CaptureProgressEvent)


func test_standing_on_your_own_hq_does_not_count() -> void:
	var battle := _battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(2, 2))
	battle.apply(MoveAction.new(sniper.id, P1_HQ))
	battle.apply(EndPhaseAction.new())
	assert_eq(battle.capture_turns[P1], 0)


func test_player2_can_capture_player1_hq() -> void:
	var battle := _battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(2, 2))
	battle.apply(EndPhaseAction.new())  # P2 のフェーズへ
	battle.apply(MoveAction.new(sniper.id, P1_HQ))
	for turn in 3:
		battle.apply(EndPhaseAction.new())  # P2 の終わり（→ 次のターンの P1）
		if battle.is_over():
			break
		battle.apply(EndPhaseAction.new())  # P1 の終わり
	assert_eq(battle.winner, P2)
	assert_eq(battle.capture_turns[P2], 3)
