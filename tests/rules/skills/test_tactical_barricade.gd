extends "res://tests/base_test.gd"
## 戦術バリケード（docs/skills/tactical-barricade.md）。盾そのものの決まりは tests/rules/test_field_effects.gd。

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


## いまのフェーズを、CPU に最後まで進めさせる。受け付けた行動を返す。
func _play_phase(battle: Battle) -> Array[BattleAction]:
	var cpu := CpuPlayer.new()
	var actions: Array[BattleAction] = []
	var phase := battle.phase
	var turn := battle.turn
	while not battle.is_over() and battle.phase == phase and battle.turn == turn and actions.size() < 200:
		var action := cpu.next_action(battle)
		assert_true(action != null and battle.apply(action).accepted, "CPU の行動が断られた")
		actions.append(action)
	return actions


func _skill_uses(actions: Array[BattleAction]) -> Array[UseSkillAction]:
	var result: Array[UseSkillAction] = []
	for action in actions:
		if action is UseSkillAction:
			result.append(action)
	return result


func test_shield_trooper_has_it() -> void:
	var skill := Skills.of_kind(UnitKind.Id.SHIELD_TROOPER)
	assert_eq(skill.id(), Skill.Id.TACTICAL_BARRICADE)
	assert_eq(skill.cooldown(), TacticalBarricadeSkill.COOLDOWN)
	assert_ne(Skills.of_kind(UnitKind.Id.PALADIN).id(), Skill.Id.TACTICAL_BARRICADE, "もう一方の前衛は持たない")


func test_targets_are_the_free_cells_around_the_unit() -> void:
	var battle := Maps.battle([
		".....",
		".#B..",
		".....",
		".S...",
		".....",
	])
	var trooper := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(2, 2))
	battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(3, 1))
	battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(3, 3))
	FieldEffects.place_barricade(battle, P2, Vector2i(1, 2))
	# 周り 8 マスのうち、障害物・樽・味方・敵・盾・回復の泉を除いた、右と下だけが残る。
	assert_eq(battle.options(trooper.id).skill_cells, [Vector2i(3, 2), Vector2i(2, 3)] as Array[Vector2i])


func test_diagonal_cells_count_as_adjacent_but_not_the_own_cell_or_farther() -> void:
	var battle := Maps.battle([".....", ".....", ".....", ".....", "....."])
	var trooper := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(2, 2))
	var cells := battle.options(trooper.id).skill_cells
	assert_eq(cells.size(), 8)
	assert_true(cells.has(Vector2i(1, 1)) and cells.has(Vector2i(3, 3)))
	assert_false(cells.has(trooper.cell))
	assert_false(cells.has(Vector2i(4, 2)))


func test_cannot_place_on_hq_font_or_outside_the_board() -> void:
	var battle := Maps.battle(["..*", "...", "..."])
	battle.board.hq_cells = [Vector2i(0, 0), Vector2i(2, 2)]
	var trooper := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(1, 0))
	# 盤の外（上）、自分の本陣（左）、結晶泉（右）を除く。
	assert_eq(battle.options(trooper.id).skill_cells, [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)] as Array[Vector2i])


func test_places_a_barricade_of_the_users_side() -> void:
	var battle := Maps.battle([".....", ".....", "....."])
	var trooper := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(1, 1))
	var events := battle.apply(UseSkillAction.new(trooper.id, Vector2i(2, 0))).events
	var placed := events[1] as BarricadePlacedEvent
	assert_eq(placed.side, P1)
	assert_eq(placed.center, Vector2i(2, 0))
	assert_eq(placed.durability, FieldEffects.BARRICADE_DURABILITY)
	var barricade := battle.board.barricade_at(Vector2i(2, 0))
	assert_eq(barricade.side, P1)
	assert_false(battle.board.is_walkable(Vector2i(2, 0)))
	for event in events:
		assert_false(event is ExperienceGainedEvent, "経験値は入らない")


func test_no_targets_when_every_cell_around_is_taken() -> void:
	var battle := Maps.battle(["#.", "##"])
	var trooper := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(1, 0))
	assert_true(battle.options(trooper.id).skill_cells.is_empty())
	assert_true(battle.can_apply(WaitAction.new(trooper.id)))


# --- CPU ---


func test_cpu_cuts_the_line_of_a_sniper_aiming_at_its_king() -> void:
	var battle := Maps.battle(OPEN_ROWS)
	battle.board.hq_cells = [HQ1, HQ2]
	var king := battle.add_unit(UnitKind.Id.KING, P1, HQ1)
	battle.add_unit(UnitKind.Id.KING, P2, HQ2)
	var trooper := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(2, 3))
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(4, 4))
	assert_true(Combat.can_attack(battle, sniper, king))
	var first := CpuPlayer.new().next_action(battle) as UseSkillAction
	assert_true(first != null, "盾を置かなかった")
	assert_eq(first.unit_id, trooper.id)
	assert_true(battle.apply(first).accepted)
	assert_false(Combat.can_attack(battle, sniper, king), "射線が切れていない")


func test_cpu_does_not_place_a_barricade_that_blocks_nothing() -> void:
	var battle := Maps.battle(OPEN_ROWS)
	battle.board.hq_cells = [HQ1, HQ2]
	battle.add_unit(UnitKind.Id.KING, P1, HQ1)
	battle.add_unit(UnitKind.Id.KING, P2, HQ2)
	battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(2, 3))
	battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(12, 1))
	assert_true(_skill_uses(_play_phase(battle)).is_empty())


func test_cpu_does_not_block_its_own_sniper() -> void:
	var battle := Maps.battle(OPEN_ROWS)
	battle.board.hq_cells = [HQ1, HQ2]
	battle.add_unit(UnitKind.Id.KING, P1, HQ1)
	battle.add_unit(UnitKind.Id.KING, P2, HQ2)
	var trooper := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(6, 1))
	battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(5, 2))
	battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(9, 2))
	for action in _skill_uses(_play_phase(battle)):
		assert_ne(action.unit_id, trooper.id, "味方の射線に盾を置いた")
