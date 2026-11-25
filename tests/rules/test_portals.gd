extends "res://tests/base_test.gd"
## 環境オブジェクトのポータル: 移動が止まる、転移、転移のあとの残りの移動、ふさがった出口、敵の支配域、並んだポータル（docs/map-objects.md）。
## ほかの環境オブジェクトは tests/rules/test_map_objects.gd。

const Maps := preload("res://tests/support/maps.gd")

const P1 := Unit.Side.PLAYER1
const P2 := Unit.Side.PLAYER2
const NEUTRAL := Unit.Side.NEUTRAL


func _portal_battle() -> Battle:
	return Maps.battle([
		"..1#####1..",
		"...........",
	])


const PORTAL_A := Vector2i(2, 0)
const PORTAL_B := Vector2i(8, 0)


func test_a_move_stops_at_the_portal_and_does_not_reach_past_it() -> void:
	var battle := _portal_battle()
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(0, 0))  # 移動力 3
	var reachable := Movement.reachable_now(battle, paladin)
	assert_eq(reachable[PORTAL_A], 2)
	assert_false(reachable.has(PORTAL_B), "移動の範囲は、転移の先まで広げない")
	assert_false(battle.can_apply(MoveAction.new(paladin.id, Vector2i(9, 0))))
	# 転移も使って行ける先（CPU の見積もり・脅威範囲）は、従来どおり。
	var through := Movement.reachable(battle, paladin, false, true)
	assert_eq(through[PORTAL_B], 2, "転移は移動力を使わない")
	assert_eq(through[Vector2i(9, 0)], 3)
	assert_eq(through[Vector2i(8, 1)], 3)
	assert_false(through.has(Vector2i(10, 0)))


func test_walk_warp_walk_carries_the_remaining_move_range() -> void:
	var battle := _portal_battle()
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(0, 0))  # 移動力 3
	var walked := battle.apply(MoveAction.new(paladin.id, PORTAL_A)).events
	assert_eq(walked.size(), 1)
	assert_eq((walked[0] as UnitMovedEvent).path, [Vector2i(0, 0), Vector2i(1, 0), PORTAL_A] as Array[Vector2i])
	assert_eq(battle.options(paladin.id).warp_exit, PORTAL_B)
	assert_true(battle.options(paladin.id).move_cells.is_empty(), "転移の前は、もう動けない")
	var warped := battle.apply(WarpAction.new(paladin.id)).events
	assert_eq(warped.size(), 1)
	var warp := warped[0] as UnitWarpedEvent
	assert_eq([warp.unit_id, warp.from, warp.to, warp.cruise], [paladin.id, PORTAL_A, PORTAL_B, false])
	assert_eq(paladin.cell, PORTAL_B)
	# 残りの移動力（1）で、続けて動ける。転移したばかりのポータルからは、転移し直せない。
	var options := battle.options(paladin.id)
	assert_eq(options.warp_exit, Board.NO_CELL)
	assert_eq(options.move_cells.keys(), [Vector2i(9, 0), Vector2i(8, 1)])
	assert_eq(options.cruise_cells.size(), 6, "巡航なら残りは 4")
	assert_false(battle.can_apply(MoveAction.new(paladin.id, PORTAL_B)), "続きは、ほかのマスへ")
	var events := battle.apply(MoveAction.new(paladin.id, Vector2i(9, 0))).events
	assert_eq((events[0] as UnitMovedEvent).path, [PORTAL_B, Vector2i(9, 0)] as Array[Vector2i])
	assert_eq(paladin.cell, Vector2i(9, 0))
	assert_true(battle.options(paladin.id).move_cells.is_empty(), "続きは 1 回だけ")
	assert_true(battle.options(paladin.id).can_undo)
	# 取り消すと、動き出したマスへ戻る。
	battle.apply(UndoMoveAction.new(paladin.id))
	assert_eq(paladin.cell, Vector2i(0, 0))
	assert_false(paladin.has_moved)
	assert_eq(Movement.reachable_now(battle, paladin)[PORTAL_A], 2, "取り消せば、移動力はまるごと戻る")


func test_a_unit_can_stay_on_the_portal_it_reached() -> void:
	var battle := _portal_battle()
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(0, 0))
	var events := battle.apply(MoveAction.new(paladin.id, PORTAL_A)).events
	assert_eq(events.size(), 1)
	assert_true(events[0] is UnitMovedEvent)
	assert_eq(paladin.cell, PORTAL_A)
	assert_true(battle.apply(WaitAction.new(paladin.id)).accepted)


func test_stopping_on_the_exit_after_the_warp() -> void:
	var battle := _portal_battle()
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(0, 0))
	battle.apply(MoveAction.new(paladin.id, PORTAL_A))
	battle.apply(WarpAction.new(paladin.id))
	var acted := battle.apply(WaitAction.new(paladin.id))
	assert_true(acted.accepted)
	assert_eq(paladin.cell, PORTAL_B)


func test_a_unit_standing_on_a_portal_can_warp_at_once() -> void:
	var battle := _portal_battle()
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P1, PORTAL_A)
	assert_eq(battle.options(paladin.id).warp_exit, PORTAL_B)
	var events := battle.apply(WarpAction.new(paladin.id)).events
	assert_eq(events.size(), 1)
	assert_true(events[0] is UnitWarpedEvent)
	assert_true(paladin.has_moved)
	# まだ歩いていないので、移動力はまるごと残る。巡航も選べる。
	var options := battle.options(paladin.id)
	assert_eq(options.move_cells.size(), 7)  # (5..10, 0) のうち 3 歩以内と、下の行
	assert_true(options.cruise_cells.has(Vector2i(5, 1)))
	assert_true(battle.apply(MoveAction.new(paladin.id, Vector2i(5, 1), true)).accepted)
	assert_true(paladin.cruised)
	# 取り消すと、転移の前のマスへ戻る。
	battle.apply(UndoMoveAction.new(paladin.id))
	assert_eq(paladin.cell, PORTAL_A)


func test_a_blocked_exit_turns_the_portal_off() -> void:
	for side: Unit.Side in [P1, P2, NEUTRAL]:
		var battle := _portal_battle()
		var paladin := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(0, 0))
		battle.add_unit(UnitKind.Id.MINION, side, PORTAL_B)
		assert_eq(battle.portal_exit(PORTAL_A), Board.NO_CELL, "side %d" % side)
		var reachable := Movement.reachable(battle, paladin, false, true)
		assert_true(reachable.has(PORTAL_A), "side %d" % side)
		assert_false(reachable.has(Vector2i(9, 0)), "side %d" % side)
		assert_false(reachable.has(Vector2i(8, 1)), "side %d" % side)
		battle.apply(MoveAction.new(paladin.id, PORTAL_A))
		assert_false(battle.can_apply(WarpAction.new(paladin.id)), "side %d" % side)
		assert_eq(battle.options(paladin.id).warp_exit, Board.NO_CELL, "side %d" % side)


func test_a_warp_needs_a_portal_and_a_unit_that_can_act() -> void:
	var battle := _portal_battle()
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(0, 0))
	var foe := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(2, 1))
	assert_false(battle.can_apply(WarpAction.new(paladin.id)), "ポータルの上にいない")
	foe.cell = PORTAL_A
	assert_false(battle.can_apply(WarpAction.new(foe.id)), "相手の番の駒")
	assert_false(battle.can_apply(WarpAction.new(99)), "いない駒")


func test_cruising_to_the_portal_keeps_the_doubled_range() -> void:
	var battle := _portal_battle()
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(0, 0))
	assert_eq(Movement.reachable(battle, paladin, true, true)[Vector2i(10, 1)], 5)  # 移動力 6
	var route := Movement.route(battle, paladin, Vector2i(10, 1), true)
	assert_eq(route.size(), 3)
	for action in route:
		assert_true(battle.apply(action).accepted, "%s" % action)
	assert_eq(paladin.cell, Vector2i(10, 1))
	assert_true(paladin.cruised)
	assert_eq(paladin.move_spent, 5)


func test_the_rest_after_a_cruise_stays_a_cruise() -> void:
	var battle := Maps.battle([
		"......1#####1..",
		"...............",
	])
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(0, 0))  # 移動力 3、巡航 6
	var walked := battle.apply(MoveAction.new(paladin.id, Vector2i(6, 0), true)).events
	assert_true((walked[0] as UnitMovedEvent).cruise)
	var warped := battle.apply(WarpAction.new(paladin.id)).events
	assert_true((warped[0] as UnitWarpedEvent).cruise)
	var options := battle.options(paladin.id)
	assert_true(options.move_cells.is_empty(), "巡航で動いたあとの続きは、巡航だけ")
	assert_eq(options.cruise_cells.size(), 0, "巡航の移動力 6 を使い切った")


func test_enemy_zoc_on_the_portal_stops_the_warp() -> void:
	var battle := _portal_battle()
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(0, 0))
	battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(3, 1))  # ポータル A が支配領域に入る
	var through := Movement.reachable(battle, commando, false, true)
	assert_true(through.has(PORTAL_A))
	assert_false(through.has(PORTAL_B))
	battle.apply(MoveAction.new(commando.id, PORTAL_A))
	assert_false(battle.can_apply(WarpAction.new(commando.id)), "敵の支配領域で止まった")


func test_a_warp_from_the_start_cell_in_enemy_zoc_is_allowed() -> void:
	var battle := _portal_battle()
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, PORTAL_A)
	battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(3, 1))
	assert_true(battle.can_apply(WarpAction.new(commando.id)), "動き出したマスなら転移できる")
	assert_true(battle.apply(MoveAction.new(commando.id, PORTAL_A)).accepted)  # 動かない移動のあとでも
	assert_true(battle.can_apply(WarpAction.new(commando.id)))


func test_enemy_zoc_on_the_exit_stops_the_unit_there() -> void:
	var battle := _portal_battle()
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(0, 0))
	battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(9, 1))  # ポータル B が支配領域に入る
	var through := Movement.reachable(battle, commando, false, true)
	assert_eq(through[PORTAL_B], 2)
	assert_false(through.has(Vector2i(9, 0)))
	battle.apply(MoveAction.new(commando.id, PORTAL_A))
	battle.apply(WarpAction.new(commando.id))
	assert_false(commando.can_keep_moving)
	assert_true(battle.options(commando.id).move_cells.is_empty())
	assert_true(battle.options(commando.id).can_undo)


func test_a_warp_takes_off_the_statuses_that_break_on_moving() -> void:
	var battle := _portal_battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, PORTAL_A)
	Statuses.add(sniper, Status.Type.AIM, 1)
	var events := battle.apply(WarpAction.new(sniper.id)).events
	assert_eq(events.size(), 2)
	assert_true(events[1] is StatusRemovedEvent)
	battle.apply(UndoMoveAction.new(sniper.id))
	assert_true(sniper.statuses.has(Status.Type.AIM), "取り消すと戻る")


func test_no_warp_after_a_skill_that_keeps_the_action_going() -> void:
	var battle := _portal_battle()
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P1, PORTAL_A)
	battle.hold_action(paladin)
	assert_false(battle.can_apply(WarpAction.new(paladin.id)))


func test_neighbouring_portals_still_warp() -> void:
	var battle := Maps.battle(["..11.."])
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(0, 0))
	var route := Movement.route(battle, commando, Vector2i(4, 0))
	assert_eq(route.size(), 3)
	assert_true(route[1] is WarpAction)


func test_walking_across_neighbouring_portals_is_not_a_warp() -> void:
	var battle := Maps.battle(["..11.."])
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(0, 0))
	var events := battle.apply(MoveAction.new(commando.id, Vector2i(4, 0))).events
	assert_eq(events.size(), 1, "隣り合うポータルの対を歩いて通っただけ")
	assert_eq((events[0] as UnitMovedEvent).path.size(), 5)


func test_walking_past_an_ally_on_the_exit_is_not_a_warp() -> void:
	var battle := Maps.battle(["..11.."])
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(0, 0))
	battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(3, 0))
	var events := battle.apply(MoveAction.new(commando.id, Vector2i(4, 0))).events
	assert_eq(events.size(), 1)
	assert_eq((events[0] as UnitMovedEvent).path.size(), 5)


func test_no_warp_from_a_portal_the_unit_cannot_stop_on() -> void:
	# ほかの駒のいるポータルには止まれないので、そこから転移する道は探さない（行動の列にできない）。
	var battle := _portal_battle()
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(0, 0))
	battle.add_unit(UnitKind.Id.SNIPER, P1, PORTAL_A)
	assert_false(Movement.reachable(battle, commando, false, true).has(PORTAL_B))


func test_a_route_through_two_portals_is_move_warp_move_warp_move() -> void:
	var battle := Maps.battle([
		".1###",
		"#####",
		"1.2##",
		"#####",
		"..2..",
	])
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(0, 0))  # 移動力 6
	var route := Movement.route(battle, commando, Vector2i(4, 4))
	var kinds: Array[String] = []
	for action in route:
		kinds.append("warp" if action is WarpAction else "move")
	assert_eq(kinds, ["move", "warp", "move", "warp", "move"] as Array[String])
	for action in route:
		assert_true(battle.apply(action).accepted, "%s" % action)
	assert_eq(commando.cell, Vector2i(4, 4))
