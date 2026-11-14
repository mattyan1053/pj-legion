extends "res://tests/base_test.gd"
## スモークグレネード（docs/skills/smoke-grenade.md）。煙幕そのものの決まりは tests/rules/test_field_effects.gd。

const Maps := preload("res://tests/support/maps.gd")

const P1 := Unit.Side.PLAYER1
const P2 := Unit.Side.PLAYER2

const OPEN_ROWS: Array[String] = [
	"................",
	"................",
	"................",
	"................",
	"................",
]
const HQ1 := Vector2i(0, 4)
const HQ2 := Vector2i(15, 0)


func _cpu_battle() -> Battle:
	var battle := Maps.battle(OPEN_ROWS)
	battle.board.hq_cells = [HQ1, HQ2]
	battle.add_unit(UnitKind.Id.KING, P1, HQ1)
	battle.add_unit(UnitKind.Id.KING, P2, HQ2)
	return battle


## いまのフェーズを、CPU に最後まで進めさせる。受け付けたスキルの行動を返す。
func _skill_uses_in_phase(battle: Battle) -> Array[UseSkillAction]:
	var cpu := CpuPlayer.new()
	var result: Array[UseSkillAction] = []
	var phase := battle.phase
	var count := 0
	while not battle.is_over() and battle.phase == phase and count < 200:
		var action := cpu.next_action(battle)
		assert_true(action != null and battle.apply(action).accepted, "CPU の行動が断られた")
		if action is UseSkillAction:
			result.append(action)
		count += 1
	return result


func test_commando_has_it() -> void:
	var skill := Skills.of_kind(UnitKind.Id.COMMANDO)
	assert_eq(skill.id(), Skill.Id.SMOKE_GRENADE)
	assert_eq(skill.cooldown(), SmokeGrenadeSkill.COOLDOWN)


func test_center_can_be_any_cell_within_range_including_the_own_cell() -> void:
	var battle := Maps.battle([
		".........",
		"...#.....",
		".........",
		".........",
		".........",
	])
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(4, 2))
	battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(5, 2))
	var cells := battle.options(commando.id).skill_cells
	for y in battle.board.size.y:
		for x in battle.board.size.x:
			var cell := Vector2i(x, y)
			var near := Combat.distance(commando.cell, cell) <= SmokeGrenadeSkill.CENTER_RANGE
			assert_eq(cells.has(cell), near, "中心に選べるか %s" % cell)
	assert_true(cells.has(commando.cell), "自分のマス")
	assert_true(cells.has(Vector2i(3, 1)), "障害物のマス")
	assert_true(cells.has(Vector2i(5, 2)), "駒のいるマス")


func test_places_a_smoke_of_the_users_side() -> void:
	var battle := Maps.battle([".....", ".....", ".....", "....."])
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(0, 1))
	var events := battle.apply(UseSkillAction.new(commando.id, Vector2i(3, 1))).events
	assert_eq(events.size(), 3)
	var placed := events[1] as AreaEffectPlacedEvent
	assert_eq(placed.type, FieldEffect.Type.SMOKE)
	assert_eq(placed.side, P1)
	assert_eq(placed.center, Vector2i(3, 1))
	assert_eq(placed.cells.size(), 9)
	assert_eq(placed.turns_left, FieldEffects.SMOKE_TURNS)
	assert_eq(commando.skill_cooldown, SmokeGrenadeSkill.COOLDOWN)
	assert_eq(Skills.of(commando).affected_cells(battle, commando, Vector2i(3, 1)), placed.cells)


func test_smoke_shields_allies_from_ranged_attacks_on_the_next_enemy_phase() -> void:
	var battle := Maps.battle(["........", "........", "........"])
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(0, 1))
	var ally := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(3, 1))
	var enemy := battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(7, 1))
	battle.apply(UseSkillAction.new(commando.id, Vector2i(3, 1)))
	battle.apply(EndPhaseAction.new())
	var events := battle.apply(AttackAction.new(enemy.id, ally.id)).events
	assert_true(events[0] is SmokeBlockedEvent)
	assert_eq(ally.hp, ally.max_hp())


# --- CPU ---


func test_cpu_covers_allies_under_a_snipers_aim() -> void:
	var battle := _cpu_battle()
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(3, 2))
	var covered: Array[Unit] = []
	for cell: Vector2i in [Vector2i(5, 1), Vector2i(5, 2)]:
		var ally := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, cell)
		ally.acted = true
		covered.append(ally)
	battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(10, 1))
	battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(10, 3))
	var uses := _skill_uses_in_phase(battle)
	assert_eq(uses.size(), 1, "煙幕を置かなかった")
	assert_eq(uses[0].unit_id, commando.id)
	for unit in covered:
		assert_true(FieldEffects.smoke_of(battle, unit) != null, "狙われている味方が煙幕の外")


func test_cpu_does_not_smoke_a_single_ally() -> void:
	var battle := _cpu_battle()
	battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(3, 2))
	battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(5, 2)).acted = true
	battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(10, 2))
	assert_true(_skill_uses_in_phase(battle).is_empty())


func test_cpu_does_not_smoke_against_melee_only() -> void:
	var battle := _cpu_battle()
	battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(3, 2))
	for cell: Vector2i in [Vector2i(5, 1), Vector2i(5, 2)]:
		battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, cell).acted = true
	battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(8, 1))
	battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(8, 3))
	assert_true(_skill_uses_in_phase(battle).is_empty(), "近くの敵は隣から当てるので、煙幕は効かない")
