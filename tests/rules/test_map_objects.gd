extends "res://tests/base_test.gd"
## 環境オブジェクト: 起爆樽の爆発、回復の泉、ポータル、樽による引き分け。

const Maps := preload("res://tests/support/maps.gd")

const P1 := Unit.Side.PLAYER1
const P2 := Unit.Side.PLAYER2
const NEUTRAL := Unit.Side.NEUTRAL


# --- 層 ---


func test_objects_sit_on_their_own_layer() -> void:
	var board := Maps.board([
		"...",
		".F.",
	])
	assert_true(board.add_barrel(Vector2i(0, 0)))
	assert_true(board.add_spring(Vector2i(1, 1)))
	assert_true(board.add_portal_pair(Vector2i(2, 0), Vector2i(2, 1)))
	assert_eq(board.object_at(Vector2i(0, 0)), MapObject.Type.BARREL)
	assert_eq(board.object_at(Vector2i(1, 1)), MapObject.Type.SPRING)
	assert_eq(board.object_at(Vector2i(2, 0)), MapObject.Type.PORTAL)
	assert_eq(board.object_at(Vector2i(1, 0)), MapObject.Type.NONE)
	assert_eq(board.terrain_at(Vector2i(0, 0)), Terrain.Type.NORMAL)
	assert_eq(board.terrain_at(Vector2i(1, 1)), Terrain.Type.FOREST)
	assert_eq(board.move_cost(Vector2i(1, 1)), 2)


func test_only_barrels_block_entry() -> void:
	var board := Maps.board(["BS1.1"])
	assert_false(board.is_walkable(Vector2i(0, 0)))
	assert_true(board.is_walkable(Vector2i(1, 0)))
	assert_true(board.is_walkable(Vector2i(2, 0)))
	assert_eq(board.move_cost(Vector2i(0, 0)), -1)


func test_portals_point_at_each_other() -> void:
	var board := Maps.board(["1.2", "2.1"])
	assert_eq(board.portal_exit(Vector2i(0, 0)), Vector2i(2, 1))
	assert_eq(board.portal_exit(Vector2i(2, 1)), Vector2i(0, 0))
	assert_eq(board.portal_exit(Vector2i(2, 0)), Vector2i(0, 1))
	assert_eq(board.portal_exit(Vector2i(1, 0)), Board.NO_CELL)


func test_objects_need_a_free_walkable_cell() -> void:
	var board := Maps.board(["#B.."])
	assert_false(board.add_barrel(Vector2i(0, 0)), "障害物")
	assert_false(board.add_spring(Vector2i(1, 0)), "もう樽がある")
	assert_false(board.add_barrel(Vector2i(9, 9)), "盤の外")
	assert_false(board.add_portal_pair(Vector2i(2, 0), Vector2i(1, 0)), "片方が置けない")
	assert_eq(board.object_at(Vector2i(2, 0)), MapObject.Type.NONE)
	assert_false(board.add_portal_pair(Vector2i(2, 0), Vector2i(2, 0)), "同じマス")


func test_units_cannot_be_placed_on_barrels() -> void:
	var battle := Maps.battle(["BS"])
	assert_eq(battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0)), null)
	assert_true(battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(1, 0)) != null)


# --- 起爆樽 ---


func _barrel_battle() -> Battle:
	return Maps.battle([
		".....",
		".FB..",
		".....",
		".....",
	])


const BARREL := Vector2i(2, 1)


func test_barrels_block_movement() -> void:
	var battle := Maps.battle([
		"#B#",
		"...",
		"#.#",
	])
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(1, 2))
	var reachable := Movement.reachable(battle, commando)
	assert_false(reachable.has(Vector2i(1, 0)))
	assert_false(battle.apply(MoveAction.new(commando.id, Vector2i(1, 0))).accepted)


func test_barrels_are_attacked_within_manhattan_range() -> void:
	var battle := _barrel_battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(4, 3))  # 射程 4、距離 4
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(3, 2))  # 射程 1、斜め隣は距離 2
	var medic := battle.add_unit(UnitKind.Id.MEDIC, P1, Vector2i(2, 2))  # 回復役は攻撃しない
	assert_true(MapObject.can_attack_barrel(battle, sniper, BARREL))
	assert_false(MapObject.can_attack_barrel(battle, paladin, BARREL))
	assert_false(MapObject.can_attack_barrel(battle, medic, BARREL))
	assert_false(MapObject.can_attack_barrel(battle, sniper, Vector2i(3, 3)), "樽の無いマス")
	assert_eq(MapObject.barrel_targets(battle, sniper), [BARREL] as Array[Vector2i])
	assert_eq(MapObject.barrel_targets(battle, paladin), [] as Array[Vector2i])


func test_blast_reaches_the_eight_cells_around() -> void:
	var board := Maps.board(["B..", "...", "..."])
	assert_eq(MapObject.blast_cells(board, Vector2i(1, 1)).size(), 8)
	assert_eq(
		MapObject.blast_cells(board, Vector2i(0, 0)),
		[Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)] as Array[Vector2i],
	)


func test_attacking_a_barrel_blows_it_up() -> void:
	var battle := _barrel_battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(4, 3))
	var enemy := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(3, 0))  # 斜め隣。HP 40
	var ally := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(1, 1))  # 森の上。軽減なし
	var minion := battle.add_unit(UnitKind.Id.MINION, NEUTRAL, Vector2i(2, 2))  # HP 12
	var far := battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(4, 1))  # 2 マス離れている

	var result := battle.apply(AttackBarrelAction.new(sniper.id, BARREL))
	assert_true(result.accepted)
	assert_eq(battle.board.object_at(BARREL), MapObject.Type.NONE)
	assert_true(battle.board.is_walkable(BARREL))
	assert_eq(enemy.hp, 25)
	assert_eq(ally.hp, 25)
	assert_eq(far.hp, 16)
	assert_eq(battle.unit_by_id(minion.id), null)
	assert_true(sniper.acted)

	# 爆発 → 巻き込まれた駒のダメージ（上の行から、左の列から）→ 撃破 → 行動の終わり。
	var events := result.events
	assert_eq(events.size(), 6)
	var exploded := events[0] as BarrelExplodedEvent
	assert_eq(exploded.attacker_id, sniper.id)
	assert_eq(exploded.cell, BARREL)
	assert_eq(exploded.blast_cells.size(), 8)
	var hit_ids: Array[int] = []
	for i in range(1, 4):
		var damaged := events[i] as UnitDamagedEvent
		hit_ids.append(damaged.unit_id)
		assert_eq(damaged.amount, 15)
		assert_eq(damaged.attacker_id, 0)
		assert_eq(damaged.cause, UnitDamagedEvent.Cause.EXPLOSION)
	assert_eq(hit_ids, [enemy.id, ally.id, minion.id] as Array[int])
	assert_eq((events[2] as UnitDamagedEvent).hp, 25)
	assert_eq((events[3] as UnitDamagedEvent).hp, 0)
	assert_eq((events[4] as UnitDefeatedEvent).unit_id, minion.id)
	assert_eq((events[5] as UnitActedEvent).unit_id, sniper.id)


func test_blast_victims_can_be_asked_without_changing_anything() -> void:
	var battle := _barrel_battle()
	var enemy := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(3, 2))
	var ally := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(1, 0))
	battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(4, 1))
	assert_eq(MapObject.blast_victims(battle, BARREL), [ally, enemy] as Array[Unit])
	assert_eq(MapObject.blast_damage(enemy), 15)
	assert_eq(enemy.hp, 40)
	assert_eq(battle.board.object_at(BARREL), MapObject.Type.BARREL)


func test_melee_attackers_are_caught_in_their_own_blast() -> void:
	var battle := _barrel_battle()
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(2, 2))
	var events := battle.apply(AttackBarrelAction.new(paladin.id, BARREL)).events
	assert_eq(paladin.hp, 25)
	assert_eq(events.size(), 3)
	assert_eq((events[1] as UnitDamagedEvent).unit_id, paladin.id)
	assert_true(events[2] is UnitActedEvent)


func test_an_attacker_killed_by_its_own_blast_does_not_finish_an_action() -> void:
	var battle := _barrel_battle()
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(2, 3))
	commando.hp = 10
	var other := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 3))
	battle.apply(MoveAction.new(commando.id, Vector2i(2, 2)))
	var events := battle.apply(AttackBarrelAction.new(commando.id, BARREL)).events
	assert_eq(events.size(), 3)
	assert_true(events[2] is UnitDefeatedEvent)
	assert_eq(battle.unit_by_id(commando.id), null)
	assert_eq(battle.acting_unit_id, 0)
	assert_true(battle.can_apply(WaitAction.new(other.id)), "ほかの駒が行動を始められる")


func test_barrel_attacks_follow_the_attack_rules() -> void:
	var battle := _barrel_battle()
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(4, 3))
	var enemy := battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(0, 3))
	assert_false(battle.can_apply(AttackBarrelAction.new(commando.id, BARREL)), "射程の外")
	assert_false(battle.can_apply(AttackBarrelAction.new(enemy.id, BARREL)), "相手のフェーズ")
	assert_false(battle.can_apply(AttackBarrelAction.new(99, BARREL)), "いない駒")
	battle.apply(MoveAction.new(commando.id, Vector2i(3, 1), true))
	assert_false(battle.can_apply(AttackBarrelAction.new(commando.id, BARREL)), "巡航のあと")
	assert_eq(battle.board.object_at(BARREL), MapObject.Type.BARREL)


func test_a_blast_does_not_set_off_other_barrels() -> void:
	var battle := Maps.battle(["BB..."])
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(4, 0))
	var events := battle.apply(AttackBarrelAction.new(sniper.id, Vector2i(1, 0))).events
	assert_eq(events.size(), 2)
	assert_eq(battle.board.barrel_cells, [Vector2i(0, 0)] as Array[Vector2i])


func test_exploding_a_barrel_in_a_clone_leaves_the_original_alone() -> void:
	var battle := _barrel_battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(4, 3))
	var enemy := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(3, 1))
	var copy := battle.clone()
	assert_eq(copy.board.barrel_cells, battle.board.barrel_cells)
	assert_true(copy.apply(AttackBarrelAction.new(sniper.id, BARREL)).accepted)
	assert_eq(copy.board.object_at(BARREL), MapObject.Type.NONE)
	assert_eq(copy.unit_by_id(enemy.id).hp, 25)
	assert_eq(battle.board.object_at(BARREL), MapObject.Type.BARREL)
	assert_eq(enemy.hp, 40)
	assert_false(sniper.acted)


func test_clone_copies_springs_and_portals() -> void:
	var battle := Maps.battle(["S1.1"])
	var copy := battle.clone()
	assert_eq(copy.board.spring_cells, battle.board.spring_cells)
	assert_eq(copy.board.portal_exit(Vector2i(1, 0)), Vector2i(3, 0))
	copy.board.spring_cells.clear()
	copy.board.portal_exits.clear()
	assert_eq(battle.board.object_at(Vector2i(0, 0)), MapObject.Type.SPRING)
	assert_eq(battle.board.portal_exit(Vector2i(3, 0)), Vector2i(1, 0))


# --- 樽と勝ち負け ---


func test_a_blast_that_kills_the_enemy_king_wins() -> void:
	var battle := _barrel_battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(4, 3))
	var king := battle.add_unit(UnitKind.Id.KING, P2, Vector2i(3, 1))
	king.hp = 15
	var events := battle.apply(AttackBarrelAction.new(sniper.id, BARREL)).events
	var won := events[-1] as GameWonEvent
	assert_true(won != null)
	assert_eq(won.winner, P1)
	assert_eq(battle.winner, P1)
	assert_false(battle.is_draw())


func test_a_blast_that_kills_your_own_king_loses() -> void:
	var battle := _barrel_battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(4, 3))
	var king := battle.add_unit(UnitKind.Id.KING, P1, Vector2i(3, 1))
	king.hp = 15
	var events := battle.apply(AttackBarrelAction.new(sniper.id, BARREL)).events
	assert_eq((events[-1] as GameWonEvent).winner, P2)


func test_a_blast_that_kills_both_kings_is_a_draw() -> void:
	var battle := _barrel_battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(4, 3))
	var king1 := battle.add_unit(UnitKind.Id.KING, P1, Vector2i(1, 2))
	var king2 := battle.add_unit(UnitKind.Id.KING, P2, Vector2i(3, 0))
	king1.hp = 10
	king2.hp = 15
	var events := battle.apply(AttackBarrelAction.new(sniper.id, BARREL)).events
	var drawn := events[-1] as GameDrawnEvent
	assert_true(drawn != null)
	assert_eq(drawn.reason, GameDrawnEvent.Reason.BOTH_KINGS_DEFEATED)
	for event in events:
		assert_false(event is GameWonEvent)
	assert_true(battle.is_over())
	assert_true(battle.is_draw())
	assert_eq(battle.winner, -1)
	assert_false(battle.apply(EndPhaseAction.new()).accepted, "決着のあとは受け付けない")
	assert_true(battle.clone().is_draw())


# --- 回復の泉 ---


func _spring_battle() -> Battle:
	return Maps.battle([
		"S...",
		"..S.",
	])


func test_springs_heal_at_the_start_of_the_owners_phase() -> void:
	var battle := _spring_battle()
	var mine := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(2, 1))
	var theirs := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(0, 0))
	var off := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(3, 0))
	mine.hp = 10
	theirs.hp = 10
	off.hp = 10

	var events := battle.apply(EndPhaseAction.new()).events  # プレイヤー2 のフェーズが始まる
	assert_eq(theirs.hp, 22)
	assert_eq(mine.hp, 10)
	assert_eq(off.hp, 10)
	assert_eq(events.size(), 2)
	assert_eq((events[0] as PhaseStartedEvent).side, P2)
	var healed := events[1] as UnitHealedEvent
	assert_eq(healed.unit_id, theirs.id)
	assert_eq(healed.healer_id, 0)
	assert_eq(healed.amount, 12)
	assert_eq(healed.hp, 22)
	assert_eq(healed.cause, UnitHealedEvent.Cause.SPRING)

	events = battle.apply(EndPhaseAction.new()).events  # 中立を通って、プレイヤー1 のフェーズが始まる
	assert_eq(mine.hp, 22)
	assert_eq(theirs.hp, 22)
	assert_eq(events.size(), 3)
	assert_eq((events[0] as PhaseStartedEvent).side, NEUTRAL)
	assert_eq((events[1] as PhaseStartedEvent).side, P1)
	assert_eq((events[2] as UnitHealedEvent).unit_id, mine.id)


func test_springs_do_not_heal_past_max_hp() -> void:
	var battle := _spring_battle()
	var hurt := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(0, 0))
	var full := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(2, 1))
	hurt.hp = 35
	var events := battle.apply(EndPhaseAction.new()).events
	assert_eq(hurt.hp, 40)
	assert_eq(full.hp, 40)
	assert_eq(events.size(), 2, "満タンの駒にはイベントが出ない")
	assert_eq((events[1] as UnitHealedEvent).amount, 5)


func test_springs_do_not_heal_neutral_units() -> void:
	var battle := _spring_battle()
	var minion := battle.add_unit(UnitKind.Id.MINION, NEUTRAL, Vector2i(0, 0))
	minion.hp = 1
	battle.apply(EndPhaseAction.new())
	battle.apply(EndPhaseAction.new())
	assert_eq(minion.hp, 1)


func test_spring_healing_can_be_asked_without_changing_anything() -> void:
	var battle := _spring_battle()
	var lower := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(2, 1))
	var upper := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(0, 0))
	lower.hp = 1
	upper.hp = 30
	assert_eq(MapObject.spring_targets(battle, P1), [upper, lower] as Array[Unit])
	assert_eq(MapObject.spring_targets(battle, P2), [] as Array[Unit])
	assert_eq(MapObject.spring_heal(upper), 10)
	assert_eq(upper.hp, 30)


# --- ポータル ---


func _portal_battle() -> Battle:
	return Maps.battle([
		"..1#####1..",
		"...........",
	])


const PORTAL_A := Vector2i(2, 0)
const PORTAL_B := Vector2i(8, 0)


func test_portals_carry_the_remaining_move_range() -> void:
	var battle := _portal_battle()
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(0, 0))  # 移動力 3
	var reachable := Movement.reachable(battle, paladin)
	assert_eq(reachable[PORTAL_A], 2)
	assert_eq(reachable[PORTAL_B], 2, "転移は移動力を使わない")
	assert_eq(reachable[Vector2i(9, 0)], 3)
	assert_eq(reachable[Vector2i(8, 1)], 3)
	assert_false(reachable.has(Vector2i(10, 0)))


func test_a_move_through_a_portal_is_walk_warp_walk() -> void:
	var battle := _portal_battle()
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(0, 0))
	var events := battle.apply(MoveAction.new(paladin.id, Vector2i(9, 0))).events
	assert_eq(paladin.cell, Vector2i(9, 0))
	assert_eq(events.size(), 3)
	assert_eq((events[0] as UnitMovedEvent).path, [Vector2i(0, 0), Vector2i(1, 0), PORTAL_A] as Array[Vector2i])
	var warped := events[1] as UnitWarpedEvent
	assert_eq(warped.unit_id, paladin.id)
	assert_eq(warped.from, PORTAL_A)
	assert_eq(warped.to, PORTAL_B)
	assert_eq((events[2] as UnitMovedEvent).path, [PORTAL_B, Vector2i(9, 0)] as Array[Vector2i])


func test_stopping_on_the_exit_ends_with_the_warp() -> void:
	var battle := _portal_battle()
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(0, 0))
	var events := battle.apply(MoveAction.new(paladin.id, PORTAL_B)).events
	assert_eq(events.size(), 2)
	assert_true(events[0] is UnitMovedEvent)
	assert_true(events[1] is UnitWarpedEvent)
	assert_eq(paladin.cell, PORTAL_B)


func test_a_unit_can_stay_on_the_portal_it_reached() -> void:
	var battle := _portal_battle()
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(0, 0))
	var events := battle.apply(MoveAction.new(paladin.id, PORTAL_A)).events
	assert_eq(events.size(), 1)
	assert_true(events[0] is UnitMovedEvent)
	assert_eq(paladin.cell, PORTAL_A)


func test_a_unit_standing_on_a_portal_can_warp_at_once() -> void:
	var battle := _portal_battle()
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P1, PORTAL_A)
	assert_eq(Movement.reachable(battle, paladin)[PORTAL_B], 0)
	var events := battle.apply(MoveAction.new(paladin.id, PORTAL_B)).events
	assert_eq(events.size(), 1)
	assert_true(events[0] is UnitWarpedEvent)
	# 取り消すと、転移の前のマスへ戻る。
	battle.apply(UndoMoveAction.new(paladin.id))
	assert_eq(paladin.cell, PORTAL_A)


func test_a_blocked_exit_turns_the_portal_off() -> void:
	for side: Unit.Side in [P1, P2, NEUTRAL]:
		var battle := _portal_battle()
		var paladin := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(0, 0))
		battle.add_unit(UnitKind.Id.MINION, side, PORTAL_B)
		assert_eq(battle.portal_exit(PORTAL_A), Board.NO_CELL, "side %d" % side)
		var reachable := Movement.reachable(battle, paladin)
		assert_true(reachable.has(PORTAL_A), "side %d" % side)
		assert_false(reachable.has(Vector2i(9, 0)), "side %d" % side)
		assert_false(reachable.has(Vector2i(8, 1)), "side %d" % side)


func test_cruising_through_a_portal_keeps_the_doubled_range() -> void:
	var battle := _portal_battle()
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(0, 0))
	var reachable := Movement.reachable(battle, paladin, true)  # 移動力 6
	assert_eq(reachable[Vector2i(10, 1)], 5)
	assert_true(battle.apply(MoveAction.new(paladin.id, Vector2i(10, 1), true)).accepted)


func test_enemy_zoc_on_the_portal_stops_the_warp() -> void:
	var battle := _portal_battle()
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(0, 0))
	battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(3, 1))  # ポータル A が支配領域に入る
	var reachable := Movement.reachable(battle, commando)
	assert_true(reachable.has(PORTAL_A))
	assert_false(reachable.has(PORTAL_B))


func test_enemy_zoc_on_the_exit_stops_the_unit_there() -> void:
	var battle := _portal_battle()
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(0, 0))
	battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(9, 1))  # ポータル B が支配領域に入る
	var reachable := Movement.reachable(battle, commando)
	assert_eq(reachable[PORTAL_B], 2)
	assert_false(reachable.has(Vector2i(9, 0)))


func test_neighbouring_portals_still_warp() -> void:
	var battle := Maps.battle(["..11.."])
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(0, 0))
	var events := battle.apply(MoveAction.new(commando.id, Vector2i(4, 0))).events
	assert_eq(events.size(), 3)
	assert_true(events[1] is UnitWarpedEvent)


func test_walking_past_an_ally_on_the_exit_is_not_a_warp() -> void:
	var battle := Maps.battle(["..11.."])
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(0, 0))
	battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(3, 0))
	var events := battle.apply(MoveAction.new(commando.id, Vector2i(4, 0))).events
	assert_eq(events.size(), 1)
	assert_eq((events[0] as UnitMovedEvent).path.size(), 5)
