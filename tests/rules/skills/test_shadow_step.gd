extends "res://tests/base_test.gd"
## シャドウステップ（docs/skills/shadow-step.md）。行動を終えないスキルの決まりは docs/active-skills.md。

const Maps := preload("res://tests/support/maps.gd")

const P1 := Unit.Side.PLAYER1
const P2 := Unit.Side.PLAYER2
const NEUTRAL := Unit.Side.NEUTRAL
const RANGE := ShadowStepSkill.RANGE

const OPEN_ROWS: Array[String] = [
	".........",
	".........",
	".........",
	".........",
	".........",
	".........",
	".........",
	".........",
	".........",
]
const CENTER := Vector2i(4, 4)


func _open() -> Battle:
	return Maps.battle(OPEN_ROWS)


func _step(battle: Battle, unit: Unit, to: Vector2i) -> Array[BattleEvent]:
	var result := battle.apply(UseSkillAction.new(unit.id, to))
	assert_true(result.accepted, "シャドウステップが断られた")
	return result.events


func test_spellblade_has_it() -> void:
	var skill := Skills.of_kind(UnitKind.Id.SPELLBLADE)
	assert_eq(skill.id(), Skill.Id.SHADOW_STEP)
	assert_eq(skill.cooldown(), ShadowStepSkill.COOLDOWN)
	assert_false(skill.ends_action())


func test_targets_are_the_eight_lines_up_to_the_range() -> void:
	var battle := _open()
	var blade := battle.add_unit(UnitKind.Id.SPELLBLADE, P1, CENTER)
	var cells := battle.options(blade.id).skill_cells
	assert_eq(cells.size(), 8 * RANGE)
	assert_true(cells.has(CENTER + Vector2i(RANGE, 0)))
	assert_true(cells.has(CENTER + Vector2i(-RANGE, RANGE)), "斜め")
	assert_false(cells.has(CENTER + Vector2i(RANGE + 1, 0)), "距離の外")
	assert_false(cells.has(CENTER + Vector2i(2, 1)), "8 方向の線の上だけ")
	assert_false(cells.has(CENTER), "自分のマスは選べない")


func test_landing_needs_a_free_cell_a_unit_can_stand_on() -> void:
	var battle := Maps.battle([
		".....",
		"..#..",
		".B.F.",
		".....",
		".....",
	])
	var blade := battle.add_unit(UnitKind.Id.SPELLBLADE, P1, Vector2i(2, 2))
	var friend := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(2, 3))
	FieldEffects.place_barricade(battle, P2, Vector2i(3, 3))
	var cells := battle.options(blade.id).skill_cells
	assert_false(cells.has(Vector2i(2, 1)), "障害物")
	assert_false(cells.has(Vector2i(1, 2)), "樽")
	assert_false(cells.has(Vector2i(3, 3)), "盾")
	assert_false(cells.has(friend.cell), "味方")
	assert_false(cells.has(Vector2i(2, -1)), "盤の外")
	assert_true(cells.has(Vector2i(3, 2)), "森には着ける")
	assert_true(cells.has(Vector2i(2, 0)), "壁の向こう")
	assert_true(cells.has(Vector2i(2, 4)), "味方の向こう")
	assert_true(cells.has(Vector2i(0, 2)), "樽の向こう")
	assert_true(cells.has(Vector2i(4, 4)), "盾の向こう")


func test_step_ignores_walls_and_zoc() -> void:
	# 壁に囲まれていて、歩いては出られない。壁の向こうは敵の前衛の支配領域。
	var battle := Maps.battle([
		".......",
		".###...",
		".#.#...",
		".###...",
		".......",
	])
	var blade := battle.add_unit(UnitKind.Id.SPELLBLADE, P1, Vector2i(2, 2))
	battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(5, 3))
	assert_eq(battle.options(blade.id).move_cells.size(), 1, "歩いては動けない")
	var events := _step(battle, blade, Vector2i(4, 2))
	assert_true(battle.is_in_enemy_zoc(blade.cell, P1))
	assert_eq(blade.cell, Vector2i(4, 2))
	assert_true(events[0] is SkillUsedEvent)
	var teleported := events[1] as UnitTeleportedEvent
	assert_eq([teleported.unit_id, teleported.from, teleported.to], [blade.id, Vector2i(2, 2), Vector2i(4, 2)])
	assert_eq(events.size(), 2, "行動を終えるイベントは出ない")


func test_step_keeps_the_action_open_for_one_attack() -> void:
	var battle := _open()
	var blade := battle.add_unit(UnitKind.Id.SPELLBLADE, P1, CENTER)
	var other := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(0, 0))
	var enemy := battle.add_unit(UnitKind.Id.SNIPER, P2, CENTER + Vector2i(RANGE + 1, 0))
	assert_true(battle.options(blade.id).attack_target_ids.is_empty())
	_step(battle, blade, CENTER + Vector2i(RANGE, 0))
	assert_false(blade.acted)
	assert_eq(battle.acting_unit_id, blade.id)
	assert_eq(blade.skill_cooldown, ShadowStepSkill.COOLDOWN)
	assert_false(battle.can_act(other), "ほかの駒は、行動を始められない")
	var options := battle.options(blade.id)
	assert_eq(options.attack_target_ids, [enemy.id] as Array[int])
	assert_true(options.move_cells.is_empty() and options.cruise_cells.is_empty(), "跳んだあとは動けない")
	assert_true(options.skill_cells.is_empty())
	assert_true(options.can_wait)
	assert_false(options.can_undo)
	assert_false(battle.can_apply(UndoMoveAction.new(blade.id)), "取り消せない")
	assert_false(battle.can_apply(MoveAction.new(blade.id, CENTER)))
	var events := battle.apply(AttackAction.new(blade.id, enemy.id)).events
	assert_true(events[-1] is UnitActedEvent)
	assert_true(blade.acted)
	assert_false(blade.move_locked)
	assert_eq(battle.acting_unit_id, 0)


func test_step_can_end_with_a_wait_or_the_end_of_the_phase() -> void:
	var battle := _open()
	var blade := battle.add_unit(UnitKind.Id.SPELLBLADE, P1, CENTER)
	_step(battle, blade, CENTER + Vector2i(1, 1))
	assert_true(battle.apply(WaitAction.new(blade.id)).accepted)
	assert_true(blade.acted)

	battle = _open()
	blade = battle.add_unit(UnitKind.Id.SPELLBLADE, P1, CENTER)
	_step(battle, blade, CENTER + Vector2i(1, 1))
	var events := battle.apply(EndPhaseAction.new()).events
	assert_true(events[0] is UnitActedEvent, "行動の途中でフェーズを終えると、待機したことになる")
	assert_eq(battle.acting_unit_id, 0)


func test_step_after_a_walk_locks_the_undo() -> void:
	var battle := _open()
	var blade := battle.add_unit(UnitKind.Id.SPELLBLADE, P1, CENTER)
	battle.apply(MoveAction.new(blade.id, CENTER + Vector2i(1, 0)))
	assert_true(battle.options(blade.id).can_undo)
	assert_eq(battle.options(blade.id).skill_cells.size(), 8 * RANGE, "歩いたあとでも跳べる")
	_step(battle, blade, CENTER + Vector2i(1, -RANGE))
	assert_false(battle.options(blade.id).can_undo)
	assert_eq(blade.cell, CENTER + Vector2i(1, -RANGE))


func test_step_only_after_a_short_walk() -> void:
	# 歩いたあとに跳べるのは、このターンに使った移動力が WALK_LIMIT までのとき。
	var battle := _open()
	var blade := battle.add_unit(UnitKind.Id.SPELLBLADE, P1, CENTER)
	battle.apply(MoveAction.new(blade.id, CENTER + Vector2i(ShadowStepSkill.WALK_LIMIT, 0)))
	assert_eq(battle.options(blade.id).skill_cells.size() > 0, true, "WALK_LIMIT まで歩いたなら跳べる")
	battle.apply(UndoMoveAction.new(blade.id))
	battle.apply(MoveAction.new(blade.id, CENTER + Vector2i(ShadowStepSkill.WALK_LIMIT, 1)))
	assert_true(battle.options(blade.id).skill_cells.is_empty(), "WALK_LIMIT より多く歩いたら跳べない")
	assert_false(battle.can_apply(UseSkillAction.new(blade.id, blade.cell + Vector2i(0, -1))))


func test_no_step_after_a_cruise() -> void:
	var battle := _open()
	var blade := battle.add_unit(UnitKind.Id.SPELLBLADE, P1, Vector2i(0, 0))
	battle.apply(MoveAction.new(blade.id, Vector2i(8, 0), true))
	assert_true(blade.cruised)
	assert_true(battle.options(blade.id).skill_cells.is_empty())


func test_step_onto_an_enemy_swaps_places() -> void:
	var battle := _open()
	var blade := battle.add_unit(UnitKind.Id.SPELLBLADE, P1, CENTER)
	var enemy := battle.add_unit(UnitKind.Id.PALADIN, P2, CENTER + Vector2i(2, 2))
	var events := _step(battle, blade, enemy.cell)
	var swapped := events[1] as UnitsSwappedEvent
	assert_eq([swapped.unit_id, swapped.from, swapped.other_id, swapped.other_from], [blade.id, CENTER, enemy.id, CENTER + Vector2i(2, 2)])
	assert_eq(blade.cell, CENTER + Vector2i(2, 2))
	assert_eq(enemy.cell, CENTER)
	assert_eq(enemy.hp, enemy.max_hp(), "入れ替えるだけで、ダメージは無い")
	assert_true(battle.options(blade.id).attack_target_ids.is_empty(), "2 マス斜めの相手には、続けて攻撃は届かない")


func test_swap_with_a_neighbour_and_strike_from_behind() -> void:
	var battle := _open()
	var blade := battle.add_unit(UnitKind.Id.SPELLBLADE, P1, CENTER)
	var enemy := battle.add_unit(UnitKind.Id.SNIPER, P2, CENTER + Vector2i(1, 0))
	_step(battle, blade, enemy.cell)
	assert_eq(battle.options(blade.id).attack_target_ids, [enemy.id] as Array[int])


func test_swap_works_on_neutral_units_but_not_on_friends() -> void:
	var battle := _open()
	var blade := battle.add_unit(UnitKind.Id.SPELLBLADE, P1, CENTER)
	var core := battle.add_unit(UnitKind.Id.MINION, NEUTRAL, CENTER + Vector2i(0, 2))
	var friend := battle.add_unit(UnitKind.Id.PALADIN, P1, CENTER + Vector2i(0, -2))
	assert_false(battle.can_apply(UseSkillAction.new(blade.id, friend.cell)))
	_step(battle, blade, core.cell)
	assert_eq(core.cell, CENTER)


func test_swap_breaks_the_aim_of_the_swapped_sniper() -> void:
	var battle := _open()
	var blade := battle.add_unit(UnitKind.Id.SPELLBLADE, P1, CENTER)
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P2, CENTER + Vector2i(3, 0))
	Statuses.add(sniper, Status.Type.AIM, 2)
	var events := _step(battle, blade, sniper.cell)
	var removed := events[2] as StatusRemovedEvent
	assert_eq([removed.unit_id, removed.status, removed.reason], [sniper.id, Status.Type.AIM, StatusRemovedEvent.Reason.MOVED])
	assert_false(Statuses.has(sniper, Status.Type.AIM))
	assert_eq(sniper.attack_range(), UnitKind.attack_range(UnitKind.Id.SNIPER))


func test_step_does_not_use_a_portal_it_lands_on() -> void:
	var battle := Maps.battle([
		"....1",
		".....",
		"1....",
	])
	var blade := battle.add_unit(UnitKind.Id.SPELLBLADE, P1, Vector2i(2, 2))
	_step(battle, blade, Vector2i(0, 2))
	assert_eq(blade.cell, Vector2i(0, 2), "着いたポータルでは転移しない")


func test_stepping_off_the_enemy_hq_resets_the_capture() -> void:
	var battle := _open()
	battle.board.hq_cells = [Vector2i(0, 8), CENTER]
	var blade := battle.add_unit(UnitKind.Id.SPELLBLADE, P1, CENTER)
	battle.capture_turns[P1] = 2
	var events := _step(battle, blade, CENTER + Vector2i(1, 0))
	var progress := events[-1] as CaptureProgressEvent
	assert_eq([progress.player, progress.turns], [P1, 0])
	assert_eq(battle.capture_turns[P1], 0, "取り消せないので、数は戻らない")


func test_swapping_an_occupier_off_the_own_hq_breaks_the_capture() -> void:
	var battle := _open()
	battle.board.hq_cells = [CENTER + Vector2i(2, 0), Vector2i(8, 0)]
	var blade := battle.add_unit(UnitKind.Id.SPELLBLADE, P1, CENTER)
	var occupier := battle.add_unit(UnitKind.Id.COMMANDO, P2, CENTER + Vector2i(2, 0))
	battle.capture_turns[P2] = 2
	_step(battle, blade, occupier.cell)
	assert_eq(battle.capture_turns[P2], 0)
	assert_eq(battle.unit_at(battle.board.hq_cells[P1]), blade)


func test_swapping_onto_the_enemy_hq_counts_at_the_end_of_the_phase() -> void:
	var battle := _open()
	battle.board.hq_cells = [Vector2i(0, 8), CENTER + Vector2i(0, -3)]
	var blade := battle.add_unit(UnitKind.Id.SPELLBLADE, P1, CENTER)
	var king := battle.add_unit(UnitKind.Id.KING, P2, CENTER + Vector2i(0, -3))
	_step(battle, blade, king.cell)
	assert_eq(battle.capture_turns[P1], 0, "入っただけでは数えない")
	battle.apply(EndPhaseAction.new())
	assert_eq(battle.capture_turns[P1], 1)


func test_clone_and_preview_leave_the_battle_alone() -> void:
	var battle := _open()
	var blade := battle.add_unit(UnitKind.Id.SPELLBLADE, P1, CENTER)
	var enemy := battle.add_unit(UnitKind.Id.PALADIN, P2, CENTER + Vector2i(3, 3))
	var events := Skills.preview(battle, blade.id, enemy.cell)
	assert_true(events[1] is UnitsSwappedEvent)
	assert_eq(blade.cell, CENTER)
	assert_eq(enemy.cell, CENTER + Vector2i(3, 3))
	assert_eq(blade.skill_cooldown, 0)
	_step(battle, blade, enemy.cell)
	var copy := battle.clone()
	assert_true(copy.unit_by_id(blade.id).move_locked)
	assert_false(copy.can_apply(UndoMoveAction.new(blade.id)))
	copy.apply(WaitAction.new(blade.id))
	assert_false(blade.acted)


func test_options_list_exactly_what_the_rules_accept() -> void:
	var battle := Maps.battle([
		"...#.",
		".....",
		"..B..",
		".....",
	])
	var blade := battle.add_unit(UnitKind.Id.SPELLBLADE, P1, Vector2i(1, 1))
	battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(3, 1))
	battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(1, 3))
	var listed := battle.options(blade.id).skill_cells
	for y in battle.board.size.y:
		for x in battle.board.size.x:
			var cell := Vector2i(x, y)
			assert_eq(battle.can_apply(UseSkillAction.new(blade.id, cell)), listed.has(cell), str(cell))


# ---- CPU ----


func _cpu_battle() -> Battle:
	var battle := Maps.battle([
		"................",
		"................",
		"......#.........",
		"......#.........",
		"......#.........",
		"................",
		"................",
	])
	battle.board.hq_cells = [Vector2i(0, 6), Vector2i(15, 0)]
	battle.add_unit(UnitKind.Id.KING, P1, Vector2i(0, 6))
	battle.add_unit(UnitKind.Id.KING, P2, Vector2i(15, 0))
	return battle


func test_cpu_steps_through_a_wall_to_finish_an_enemy() -> void:
	var battle := _cpu_battle()
	var blade := battle.add_unit(UnitKind.Id.SPELLBLADE, P1, Vector2i(5, 3))
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(8, 3))
	sniper.hp = blade.power()  # 削れたスナイパー。無傷（HP 13）なら、一撃（12）では倒れない
	# 歩いても届かないように、もう動いたことにする（動いたあとの駒は、いまの位置からできることを選ぶ）。
	battle.apply(MoveAction.new(blade.id, blade.cell))
	var cpu := CpuPlayer.new()
	var first := cpu.next_action(battle) as UseSkillAction
	assert_true(first != null, "跳ばなかった")
	battle.apply(first)
	assert_true(Combat.can_attack(battle, blade, sniper))
	var second := cpu.next_action(battle) as AttackAction
	assert_true(second != null and second.target_id == sniper.id, "跳んだあとに攻撃しなかった")
	battle.apply(second)
	assert_eq(battle.unit_by_id(sniper.id), null)


func test_cpu_walks_and_then_steps_to_reach_a_far_sniper() -> void:
	# 壁を回って歩くと届かない。少し歩いた先から壁を跳び越えれば届く（スキルを使うために立つマスを探す）。
	var battle := _cpu_battle()
	var blade := battle.add_unit(UnitKind.Id.SPELLBLADE, P1, Vector2i(2, 3))
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(8, 3))
	sniper.hp = blade.power()  # 削れたスナイパー。無傷（HP 13）なら、一撃（12）では倒れない
	var cpu := CpuPlayer.new()
	var kinds: Array[String] = []
	while battle.phase == P1 and not battle.is_over() and kinds.size() < 10:
		var action := cpu.next_action(battle)
		assert_true(battle.apply(action).accepted)
		if action.get("unit_id") == blade.id:
			kinds.append(action.get_script().resource_path.get_file())
	assert_eq(kinds, ["move_action.gd", "use_skill_action.gd", "attack_action.gd"] as Array[String])
	assert_eq(battle.unit_by_id(sniper.id), null, "倒せなかった")


func test_cpu_does_not_walk_far_and_then_step() -> void:
	# 歩いて 6 + 跳んで 3 + 攻撃 1 なら届くが、歩いてから跳べるのは WALK_LIMIT まで。届かないので跳ばない。
	var battle := _cpu_battle()
	var blade := battle.add_unit(UnitKind.Id.SPELLBLADE, P1, Vector2i(0, 1))
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(10, 1))
	sniper.hp = blade.power()
	assert_true(Combat.distance(blade.cell, sniper.cell) > ShadowStepSkill.WALK_LIMIT + RANGE + blade.attack_range())
	var cpu := CpuPlayer.new()
	while battle.phase == P1 and not battle.is_over():
		var action := cpu.next_action(battle)
		assert_false(action is UseSkillAction, "届かないのに跳んだ")
		assert_true(battle.apply(action).accepted)
	assert_eq(sniper.hp, blade.power())


func test_cpu_does_not_step_when_there_is_nothing_to_attack() -> void:
	var battle := _cpu_battle()
	var blade := battle.add_unit(UnitKind.Id.SPELLBLADE, P1, Vector2i(2, 5))
	var cpu := CpuPlayer.new()
	for i in 4:
		var action := cpu.next_action(battle)
		assert_false(action is UseSkillAction, "攻撃できないのに跳んだ")
		if action is EndPhaseAction:
			break
		battle.apply(action)
	assert_eq(blade.skill_cooldown, 0)


func test_cpu_plays_a_whole_phase_with_a_spellblade() -> void:
	var battle := _cpu_battle()
	battle.add_unit(UnitKind.Id.SPELLBLADE, P1, Vector2i(4, 5))
	battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(8, 5))
	battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(9, 4))
	var cpu := CpuPlayer.new()
	var count := 0
	while battle.phase == P1 and not battle.is_over() and count < 50:
		var action := cpu.next_action(battle)
		assert_true(action != null and battle.apply(action).accepted, "CPU の行動が断られた")
		count += 1
	assert_true(count < 50, "フェーズが終わらない")
