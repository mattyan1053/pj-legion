extends "res://tests/base_test.gd"
## 「この駒がいま選べること」（Battle.options）が、ルールの受け付ける行動と一致すること。

const Maps := preload("res://tests/support/maps.gd")

const P1 := Unit.Side.PLAYER1
const P2 := Unit.Side.PLAYER2


## 駒・地形・樽・ポータルが一通りある盤面。
func _battle() -> Battle:
	return Maps.battle([
		"....1.....",
		"..#..F..B.",
		"......1...",
		".B........",
	])


## options の中身が、can_apply を総当たりした結果と一致することを確かめる。
func _assert_matches_rules(battle: Battle, unit_id: int, message: String) -> void:
	var options := battle.options(unit_id)
	assert_eq(options.unit_id, unit_id)
	var attack_ids: Array[int] = []
	var heal_ids: Array[int] = []
	for other in battle.units:
		if battle.can_apply(AttackAction.new(unit_id, other.id)):
			attack_ids.append(other.id)
		if battle.can_apply(HealAction.new(unit_id, other.id)):
			heal_ids.append(other.id)
	var listed_attacks := options.attack_target_ids.duplicate()
	var listed_heals := options.heal_target_ids.duplicate()
	listed_attacks.sort()
	listed_heals.sort()
	assert_eq(listed_attacks, attack_ids, "攻撃できる駒 %s" % message)
	assert_eq(listed_heals, heal_ids, "回復できる駒 %s" % message)
	for y in battle.board.size.y:
		for x in battle.board.size.x:
			var cell := Vector2i(x, y)
			var normal := battle.can_apply(MoveAction.new(unit_id, cell, false))
			var cruise := battle.can_apply(MoveAction.new(unit_id, cell, true))
			assert_eq(options.move_cells.has(cell), normal, "通常の移動 %s %s" % [cell, message])
			assert_eq(options.cruise_cells.has(cell), cruise and not normal, "巡航でだけ %s %s" % [cell, message])
			assert_eq(options.can_move_to(cell), cruise, "動けるか %s %s" % [cell, message])
			assert_eq(
				options.barrel_cells.has(cell), battle.can_apply(AttackBarrelAction.new(unit_id, cell)),
				"樽 %s %s" % [cell, message]
			)
			assert_eq(
				options.skill_cells.has(cell), battle.can_apply(UseSkillAction.new(unit_id, cell)),
				"スキル %s %s" % [cell, message]
			)
	assert_eq(options.can_wait, battle.can_apply(WaitAction.new(unit_id)), "待機 %s" % message)
	assert_eq(options.can_undo, battle.can_apply(UndoMoveAction.new(unit_id)), "取り消し %s" % message)
	assert_eq(options.is_empty(), options.actions().is_empty(), "空かどうか %s" % message)
	for action in options.actions():
		assert_true(battle.can_apply(action), "並べた行動が断られる %s" % message)


func _populate(battle: Battle) -> Dictionary:
	var units := {
		"sniper": battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(1, 2)),  # 移動力 3、射程 4
		"medic": battle.add_unit(UnitKind.Id.MEDIC, P1, Vector2i(0, 1)),  # 射程 1
		"commando": battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(3, 0)),
		"ally": battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(1, 1)),
		"paladin": battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(4, 2)),  # 支配領域を持つ
		"enemy": battle.add_unit(UnitKind.Id.SORCERER, P2, Vector2i(9, 3)),
		"minion": battle.add_unit(UnitKind.Id.MINION, Unit.Side.NEUTRAL, Vector2i(7, 3)),
	}
	units["ally"].hp -= 10
	units["paladin"].hp -= 10
	return units


func test_options_are_exactly_what_the_rules_accept() -> void:
	var battle := _battle()
	var units := _populate(battle)
	for name: String in units:
		_assert_matches_rules(battle, units[name].id, name)
	# 動いたあと（攻撃・待機・取り消しが選べて、移動は選べない）。ほかの駒は何も選べない。
	battle.apply(MoveAction.new(units["sniper"].id, Vector2i(2, 2)))
	for name: String in units:
		_assert_matches_rules(battle, units[name].id, "動いたあとの %s" % name)
	battle.apply(UndoMoveAction.new(units["sniper"].id))
	# 巡航で動いたあと（攻撃も回復も選べない）。
	battle.apply(MoveAction.new(units["medic"].id, Vector2i(0, 0), true))
	for name: String in units:
		_assert_matches_rules(battle, units[name].id, "巡航のあとの %s" % name)
	battle.apply(WaitAction.new(units["medic"].id))
	# 相手の番。
	battle.apply(EndPhaseAction.new())
	for name: String in units:
		_assert_matches_rules(battle, units[name].id, "プレイヤー2 の番の %s" % name)


func test_options_list_each_kind_of_choice() -> void:
	var battle := _battle()
	var units := _populate(battle)
	var sniper: Unit = units["sniper"]
	var options := battle.options(sniper.id)
	assert_eq(options.move_cells[sniper.cell], 0, "いまのマス（動かない移動）")
	assert_eq(options.move_cells[Vector2i(1, 0)], 2, "味方を通り抜けた先")
	assert_false(options.move_cells.has(Vector2i(1, 1)), "味方のいるマスには止まれない")
	assert_eq(options.cruise_cells[Vector2i(4, 0)], 5, "巡航でだけ届く")
	assert_false(options.move_cells.has(Vector2i(4, 0)))
	assert_eq(options.cruise_cells[Vector2i(6, 2)], 5, "巡航でポータルを通った先")
	assert_eq(options.attack_target_ids, [units["paladin"].id] as Array[int])
	assert_eq(options.barrel_cells, [Vector2i(1, 3)] as Array[Vector2i])
	assert_true(options.heal_target_ids.is_empty(), "回復役でない")
	assert_true(options.can_wait)
	assert_false(options.can_undo)

	var medic: Unit = units["medic"]
	options = battle.options(medic.id)
	assert_eq(options.heal_target_ids, [units["ally"].id] as Array[int])
	assert_true(options.attack_target_ids.is_empty(), "回復役は攻撃しない")
	assert_true(options.barrel_cells.is_empty())

	battle.apply(MoveAction.new(sniper.id, Vector2i(2, 2)))
	options = battle.options(sniper.id)
	assert_true(options.move_cells.is_empty() and options.cruise_cells.is_empty(), "もう動いた")
	assert_true(options.can_undo)
	assert_true(options.can_wait)
	assert_true(battle.options(medic.id).is_empty(), "ほかの駒が行動の途中")


func test_cruise_only_cells_are_the_ones_past_the_normal_range() -> void:
	var battle := Maps.battle([".........."])
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))  # 移動力 3
	var options := battle.options(sniper.id)
	assert_eq(options.move_cells.size(), 4)
	assert_eq(options.cruise_cells.size(), 3)
	assert_eq(options.move_cells[Vector2i(3, 0)], 3)
	assert_eq(options.cruise_cells[Vector2i(4, 0)], 4)
	assert_eq(options.cruise_cells[Vector2i(6, 0)], 6)


func test_options_are_empty_for_missing_units_and_after_the_game() -> void:
	var battle := Maps.battle(["....."])
	var king := battle.add_unit(UnitKind.Id.KING, P2, Vector2i(1, 0))
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	var other := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(4, 0))
	assert_true(battle.options(0).is_empty())
	assert_true(battle.options(999).is_empty())
	assert_true(battle.options(999).actions().is_empty())
	king.hp = 1
	battle.apply(AttackAction.new(sniper.id, king.id))
	assert_true(battle.is_over())
	assert_true(battle.options(other.id).is_empty(), "決着のあと")
	assert_true(battle.options(other.id).move_cells.is_empty())


func test_asking_does_not_change_anything() -> void:
	var battle := _battle()
	var units := _populate(battle)
	var before := battle.clone()
	var rng_state := battle.rng.state
	for name: String in units:
		battle.options(units[name].id).actions()
	assert_eq(battle.rng.state, rng_state)
	assert_eq(battle.units.size(), before.units.size())
	for unit in battle.units:
		var same := before.unit_by_id(unit.id)
		assert_eq(unit.cell, same.cell)
		assert_eq(unit.hp, same.hp)
		assert_eq(unit.has_moved, same.has_moved)
		assert_eq(unit.acted, same.acted)
	assert_eq(battle.acting_unit_id, before.acting_unit_id)
	assert_eq(battle.board.barrel_cells, before.board.barrel_cells)


func test_options_work_on_a_clone_with_the_same_ids() -> void:
	# CPU の先読み: 元から作った行動を、複製にそのまま渡せる。
	var battle := _battle()
	var units := _populate(battle)
	var copy := battle.clone()
	for action in battle.options(units["commando"].id).actions():
		assert_true(copy.can_apply(action))
	var first := battle.options(units["sniper"].id).actions()[1]
	assert_true(copy.apply(first).accepted)
	assert_false(units["sniper"].has_moved, "元は変わらない")


func test_actions_come_in_the_same_order_every_time() -> void:
	var battle := _battle()
	var units := _populate(battle)
	var first := _describe(battle.options(units["commando"].id).actions())
	for i in 3:
		assert_eq(_describe(battle.clone().options(units["commando"].id).actions()), first)


func _describe(actions: Array[BattleAction]) -> Array[String]:
	var result: Array[String] = []
	for action in actions:
		var move := action as MoveAction
		if move != null:
			result.append("move %s %s" % [move.to, move.cruise])
		else:
			result.append((action.get_script() as Script).get_global_name())
	return result
