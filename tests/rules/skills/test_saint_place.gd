extends "res://tests/base_test.gd"
## セイントプレイス（docs/skills/saint-place.md）。聖域そのものの決まりは tests/rules/test_field_effects.gd。

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


func test_priest_has_it() -> void:
	var skill := Skills.of_kind(UnitKind.Id.PRIEST)
	assert_eq(skill.id(), Skill.Id.SAINT_PLACE)
	assert_eq(skill.cooldown(), SaintPlaceSkill.COOLDOWN)
	assert_eq(Skills.of_kind(UnitKind.Id.MEDIC), null, "もう一方の回復役は持たない")


func test_center_can_be_any_cell_within_range_including_the_own_cell() -> void:
	var battle := Maps.battle([
		".......",
		"..#....",
		".......",
		".......",
		".......",
	])
	var priest := battle.add_unit(UnitKind.Id.PRIEST, P1, Vector2i(3, 2))
	battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(4, 2))
	var cells := battle.options(priest.id).skill_cells
	for y in battle.board.size.y:
		for x in battle.board.size.x:
			var cell := Vector2i(x, y)
			var near := Combat.distance(priest.cell, cell) <= SaintPlaceSkill.CENTER_RANGE
			assert_eq(cells.has(cell), near, "中心に選べるか %s" % cell)
	assert_true(cells.has(priest.cell), "自分のマス")
	assert_true(cells.has(Vector2i(2, 1)), "障害物のマス")
	assert_true(cells.has(Vector2i(4, 2)), "駒のいるマス")


func test_center_must_be_on_the_board() -> void:
	var battle := Maps.battle(["...", "...", "..."])
	var priest := battle.add_unit(UnitKind.Id.PRIEST, P1, Vector2i(0, 0))
	assert_eq(battle.options(priest.id).skill_cells.size(), 6)
	assert_false(battle.can_apply(UseSkillAction.new(priest.id, Vector2i(-1, 0))))


func test_barricades_do_not_block_it() -> void:
	var battle := Maps.battle([".....", ".....", "....."])
	var priest := battle.add_unit(UnitKind.Id.PRIEST, P1, Vector2i(0, 1))
	FieldEffects.place_barricade(battle, P2, Vector2i(1, 1))
	assert_true(battle.can_apply(UseSkillAction.new(priest.id, Vector2i(2, 1))), "盾の向こう")
	assert_true(battle.can_apply(UseSkillAction.new(priest.id, Vector2i(1, 1))), "盾のマス")


func test_places_a_sanctuary_of_the_users_side() -> void:
	var battle := Maps.battle([".....", ".....", ".....", "....."])
	var priest := battle.add_unit(UnitKind.Id.PRIEST, P1, Vector2i(1, 1))
	var events := battle.apply(UseSkillAction.new(priest.id, Vector2i(3, 1))).events
	var placed := events[1] as AreaEffectPlacedEvent
	assert_eq(placed.type, FieldEffect.Type.SANCTUARY)
	assert_eq(placed.side, P1)
	assert_eq(placed.center, Vector2i(3, 1))
	assert_eq(placed.cells.size(), 9)
	assert_eq(placed.turns_left, FieldEffects.SANCTUARY_TURNS)
	assert_eq(battle.board.field_effects.size(), 1)
	for event in events:
		assert_false(event is ExperienceGainedEvent, "経験値は入らない")


func test_affected_cells_are_the_cells_of_the_sanctuary() -> void:
	var battle := Maps.battle([".....", ".....", "....."])
	var priest := battle.add_unit(UnitKind.Id.PRIEST, P1, Vector2i(1, 1))
	var skill := Skills.of(priest)
	var cells := skill.affected_cells(battle, priest, Vector2i(0, 0))
	assert_eq(cells, [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)] as Array[Vector2i])
	battle.apply(UseSkillAction.new(priest.id, Vector2i(0, 0)))
	assert_eq(battle.board.field_effects[0].cells, cells)


func test_sanctuary_heals_from_the_next_own_phase() -> void:
	var battle := Maps.battle([".....", ".....", "....."])
	var priest := battle.add_unit(UnitKind.Id.PRIEST, P1, Vector2i(1, 1))
	var wounded := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(3, 1))
	wounded.hp -= 20
	battle.apply(UseSkillAction.new(priest.id, Vector2i(3, 1)))
	battle.apply(EndPhaseAction.new())
	battle.apply(EndPhaseAction.new())
	assert_eq(wounded.hp, wounded.max_hp() - 20 + FieldEffects.SANCTUARY_HEAL)


# --- CPU ---


func test_cpu_places_a_sanctuary_over_several_wounded_allies() -> void:
	var battle := _cpu_battle()
	var priest := battle.add_unit(UnitKind.Id.PRIEST, P1, Vector2i(3, 2))
	var wounded: Array[Unit] = []
	for cell: Vector2i in [Vector2i(4, 1), Vector2i(4, 2), Vector2i(4, 3)]:
		var paladin := battle.add_unit(UnitKind.Id.PALADIN, P1, cell)
		paladin.hp -= 10
		paladin.acted = true
		wounded.append(paladin)
	var action := CpuPlayer.new().next_action(battle) as UseSkillAction
	assert_true(action != null, "聖域を置かなかった")
	assert_eq(action.unit_id, priest.id)
	assert_true(battle.apply(action).accepted)
	for unit in wounded:
		assert_true(FieldEffects.sanctuary_of(battle, unit) != null, "減っている味方が聖域の外")


func test_cpu_heals_a_single_wounded_ally_instead() -> void:
	var battle := _cpu_battle()
	var priest := battle.add_unit(UnitKind.Id.PRIEST, P1, Vector2i(3, 2))
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(4, 2))
	paladin.hp -= 10
	paladin.acted = true
	var action := CpuPlayer.new().next_action(battle) as HealAction
	assert_true(action != null, "回復しなかった")
	assert_eq(action.unit_id, priest.id)


func test_cpu_does_not_stack_a_sanctuary_on_allies_already_inside_one() -> void:
	var battle := _cpu_battle()
	var priest := battle.add_unit(UnitKind.Id.PRIEST, P1, Vector2i(3, 2))
	for cell: Vector2i in [Vector2i(4, 1), Vector2i(4, 2), Vector2i(4, 3)]:
		var paladin := battle.add_unit(UnitKind.Id.PALADIN, P1, cell)
		paladin.hp -= 10
		paladin.acted = true
	FieldEffects.place_sanctuary(battle, P1, Vector2i(4, 2))
	var action := CpuPlayer.new().next_action(battle)
	assert_false(action is UseSkillAction and (action as UseSkillAction).unit_id == priest.id, "聖域を重ねた")
