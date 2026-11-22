extends "res://tests/base_test.gd"
## 画面に出す「いま選べること」が、ルールの受け付けるものと一致すること。

const Maps := preload("res://tests/support/maps.gd")
const Queries := preload("res://game/battle_queries.gd")

const P1 := Unit.Side.PLAYER1
const P2 := Unit.Side.PLAYER2


func _battle() -> Battle:
	return Maps.battle([
		"..........",
		"..#..F....",
		"..........",
		"..........",
	])


func test_move_cells_are_exactly_what_the_rules_accept() -> void:
	var battle := _battle()
	var unit := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(1, 1))  # 移動力 3
	battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(6, 2))  # 支配領域を持つ
	battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(1, 2))  # 味方（止まれない）
	var cells := Queries.move_cells(battle, unit)
	for y in battle.board.size.y:
		for x in battle.board.size.x:
			var cell := Vector2i(x, y)
			if cell == unit.cell:
				assert_false(cells.has(cell), "いまのマスは含まない")
				continue
			var normal := battle.can_apply(MoveAction.new(unit.id, cell, false))
			var cruise := battle.can_apply(MoveAction.new(unit.id, cell, true))
			assert_eq(cells.has(cell), cruise, "行けるかどうか %s" % cell)
			if cells.has(cell):
				assert_eq(cells[cell], not normal, "巡航でしか届かないか %s" % cell)


func test_no_move_cells_for_units_that_cannot_move() -> void:
	var battle := _battle()
	var mine := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(1, 1))
	var other := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(1, 3))
	var enemy := battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(8, 1))
	assert_true(Queries.move_cells(battle, null).is_empty())
	assert_true(Queries.move_cells(battle, enemy).is_empty(), "相手の番の駒")
	battle.apply(MoveAction.new(mine.id, Vector2i(1, 0)))
	assert_true(Queries.move_cells(battle, mine).is_empty(), "もう動いた駒")
	assert_true(Queries.move_cells(battle, other).is_empty(), "ほかの駒が行動の途中")
	battle.apply(WaitAction.new(mine.id))
	assert_true(Queries.move_cells(battle, mine).is_empty(), "行動済みの駒")
	assert_false(Queries.move_cells(battle, other).is_empty())


func test_attack_targets_are_what_the_rules_accept() -> void:
	var battle := _battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(1, 2))  # 射程 4
	var near := battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(4, 2))
	battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(9, 2))  # 届かない
	battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(1, 3))  # 味方
	assert_eq(Queries.attack_targets(battle, sniper), [near] as Array[Unit])
	assert_true(Queries.attack_targets(battle, near).is_empty(), "相手の番の駒は攻撃できない")
	assert_true(Queries.attack_targets(battle, null).is_empty())


func test_heal_targets_are_exactly_what_the_rules_accept() -> void:
	var battle := _battle()
	var priest := battle.add_unit(UnitKind.Id.PRIEST, P1, Vector2i(3, 2))  # 射程 2
	var near := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(5, 2))
	near.hp -= 5
	battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(3, 3))  # 減っていない
	battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(8, 2)).hp -= 5  # 届かない
	battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(4, 2)).hp -= 5  # 敵
	assert_eq(Queries.heal_targets(battle, priest), [near] as Array[Unit])
	for unit in battle.units:
		assert_eq(
			Queries.heal_targets(battle, priest).has(unit), battle.can_apply(HealAction.new(priest.id, unit.id)),
			"回復できるかどうか %s" % unit.cell,
		)
	assert_true(Queries.heal_targets(battle, near).is_empty(), "回復役でない駒")
	assert_true(Queries.heal_targets(battle, null).is_empty())
	battle.apply(MoveAction.new(priest.id, Vector2i(3, 1), true))
	assert_true(Queries.heal_targets(battle, priest).is_empty(), "巡航で動いた駒")


func test_no_attack_targets_after_cruising() -> void:
	var battle := _battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(1, 2))
	battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(4, 2))
	battle.apply(MoveAction.new(sniper.id, Vector2i(1, 3), true))
	assert_true(Queries.attack_targets(battle, sniper).is_empty())


func test_inspect_cells_work_for_any_unit() -> void:
	var battle := _battle()
	var enemy := battle.add_unit(UnitKind.Id.COMMANDO, P2, Vector2i(8, 2))
	var cells := Queries.inspect_cells(battle, enemy)
	assert_true(cells.has(Vector2i(8, 2)))
	assert_true(cells.has(Vector2i(2, 2)), "移動力 6")
	assert_false(cells.has(Vector2i(1, 2)))
	assert_true(Queries.inspect_cells(battle, null).is_empty())


func test_counts_and_king() -> void:
	var battle := _battle()
	var king := battle.add_unit(UnitKind.Id.KING, P1, Vector2i(0, 0))
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(1, 2))
	battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(8, 2))
	assert_eq(Queries.unit_count(battle, P1), 2)
	assert_eq(Queries.unit_count(battle, P2), 1)
	assert_eq(Queries.king_of(battle, P1), king)
	assert_eq(Queries.king_of(battle, P2), null)
	assert_eq(Queries.unacted_count(battle), 2)
	battle.apply(WaitAction.new(sniper.id))
	assert_eq(Queries.unacted_count(battle), 1)
	battle.apply(EndPhaseAction.new())
	assert_eq(Queries.unacted_count(battle), 1, "プレイヤー2 の番")


func test_barrel_targets_are_exactly_what_the_rules_accept() -> void:
	var battle := Maps.battle([
		"..B.......",
		"......B...",
		"..........",
		"B.........",
	])
	var unit := battle.add_unit(UnitKind.Id.SORCERER, P1, Vector2i(2, 2))  # 射程 2
	var targets := Queries.barrel_targets(battle, unit)
	assert_eq(targets, [Vector2i(2, 0)] as Array[Vector2i])
	for y in battle.board.size.y:
		for x in battle.board.size.x:
			var cell := Vector2i(x, y)
			assert_eq(targets.has(cell), battle.can_apply(AttackBarrelAction.new(unit.id, cell)), "狙えるかどうか %s" % cell)


func test_no_barrel_targets_for_units_that_cannot_attack() -> void:
	var battle := Maps.battle([
		".B....",
		"......",
	])
	var enemy := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(0, 0))
	var healer := battle.add_unit(UnitKind.Id.MEDIC, P1, Vector2i(1, 1))
	var runner := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(5, 1))
	assert_eq(Queries.barrel_targets(battle, null).size(), 0)
	assert_eq(Queries.barrel_targets(battle, enemy).size(), 0, "相手の番の駒")
	assert_eq(Queries.barrel_targets(battle, healer).size(), 0, "回復役")
	battle.apply(MoveAction.new(runner.id, Vector2i(2, 1), true))
	assert_eq(Queries.barrel_targets(battle, runner).size(), 0, "巡航で動いた駒")


func test_skill_cells_are_what_the_rules_accept() -> void:
	var battle := _battle()
	var trooper := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(3, 1))
	var enemy := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P2, Vector2i(8, 1))
	assert_true(Queries.skill_cells(battle, null).is_empty())
	assert_true(Queries.skill_cells(battle, enemy).is_empty(), "相手の番の駒")
	var cells := Queries.skill_cells(battle, trooper)
	assert_false(cells.is_empty())
	for y in battle.board.size.y:
		for x in battle.board.size.x:
			var cell := Vector2i(x, y)
			assert_eq(cells.has(cell), battle.can_apply(UseSkillAction.new(trooper.id, cell)), "スキルの対象 %s" % cell)
	battle.apply(UseSkillAction.new(trooper.id, cells[0]))
	assert_true(Queries.skill_cells(battle, trooper).is_empty(), "使ったあと")


func test_threat_cells_are_the_threat_range_of_the_rules() -> void:
	var battle := _battle()
	var enemy := battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(8, 1))
	assert_eq(Queries.threat_cells(battle, enemy), Threat.of(battle, enemy.id).cells())
	assert_true(Queries.threat_cells(battle, enemy).has(Vector2i(2, 1)), "移動 3 + 射程 4")
	assert_true(Queries.threat_cells(battle, null).is_empty())


# ---- ポータルの転移 ----


func _portal_battle() -> Battle:
	var battle := Maps.battle([
		"..........",
		"..........",
		"..........",
		"..........",
	])
	battle.board.add_portal_pair(Vector2i(1, 1), Vector2i(8, 1))
	return battle


func test_warp_after_stepping_onto_a_portal() -> void:
	var battle := _portal_battle()
	var unit := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 1))  # 移動力 3
	assert_eq(Queries.warp_exit(battle, unit), Board.NO_CELL, "ポータルの上にいない")
	assert_eq(Queries.reachable_portals(battle, unit), {Vector2i(1, 1): Vector2i(8, 1)}, "範囲の中のポータルと、出る先")
	assert_false(Queries.move_cells(battle, unit).has(Vector2i(8, 1)), "範囲は転移の先まで広げない")
	battle.apply(MoveAction.new(unit.id, Vector2i(1, 1)))
	assert_eq(Queries.warp_exit(battle, unit), Vector2i(8, 1))
	assert_true(battle.can_apply(WarpAction.new(unit.id)))
	battle.apply(WarpAction.new(unit.id))
	assert_eq(unit.cell, Vector2i(8, 1))
	assert_eq(battle.acting_unit_id, unit.id, "転移のあとも、行動の途中")
	assert_eq(Queries.warp_exit(battle, unit), Board.NO_CELL, "転移したばかり（すぐには戻れない）")
	assert_true(Queries.reachable_portals(battle, unit).is_empty())
	var cells := Queries.move_cells(battle, unit)
	assert_eq(cells.get(Vector2i(9, 1)), false, "残りの移動力（2）で続けて動ける")
	assert_eq(cells.get(Vector2i(8, 3)), false)
	assert_eq(cells.get(Vector2i(8, 4)), null)
	for cell: Vector2i in cells:
		assert_true(battle.can_apply(MoveAction.new(unit.id, cell, cells[cell])), "%s" % cell)


func test_warp_from_a_portal_at_the_start_of_the_phase() -> void:
	var battle := _portal_battle()
	var unit := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(1, 1))
	assert_eq(Queries.warp_exit(battle, unit), Vector2i(8, 1))
	assert_eq(Queries.reachable_portals(battle, unit), {Vector2i(1, 1): Vector2i(8, 1)})
	battle.apply(WarpAction.new(unit.id))
	assert_eq(unit.cell, Vector2i(8, 1))
	assert_eq(Queries.move_cells(battle, unit).size(), Movement.reachable(battle, unit, true).size() - 1, "移動力はまるごと残る")


func test_no_warp_when_the_exit_is_taken() -> void:
	var battle := _portal_battle()
	var unit := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 1))
	battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(8, 1))
	assert_true(Queries.reachable_portals(battle, unit).is_empty())
	battle.apply(MoveAction.new(unit.id, Vector2i(1, 1)))
	assert_eq(Queries.warp_exit(battle, unit), Board.NO_CELL)


func test_no_warp_from_a_portal_in_an_enemy_zone() -> void:
	var battle := _portal_battle()
	var unit := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(2, 1))  # (1, 1) は支配領域
	assert_true(Queries.reachable_portals(battle, unit).is_empty(), "止まっても転移できないポータルは、印を付けない")
	battle.apply(MoveAction.new(unit.id, Vector2i(1, 1)))
	assert_eq(Queries.warp_exit(battle, unit), Board.NO_CELL, "敵の支配領域で止まったポータルからは、転移できない")


func test_cruise_warp_keeps_cruising() -> void:
	var battle := Maps.battle([
		"..........",
		"..........",
	])
	battle.board.add_portal_pair(Vector2i(5, 0), Vector2i(9, 1))
	var unit := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))  # 移動力 3。巡航で 6
	assert_eq(Queries.reachable_portals(battle, unit), {Vector2i(5, 0): Vector2i(9, 1)}, "巡航でだけ届くポータルも")
	battle.apply(MoveAction.new(unit.id, Vector2i(5, 0), true))
	battle.apply(WarpAction.new(unit.id))
	assert_true(unit.cruised)
	assert_eq(Queries.move_cells(battle, unit), {Vector2i(8, 1): true, Vector2i(9, 0): true}, "続きも巡航（残り 1）")
