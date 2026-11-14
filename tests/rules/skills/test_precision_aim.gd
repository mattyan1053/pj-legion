extends "res://tests/base_test.gd"
## 精密照準（docs/skills/precision-aim.md）。照準そのものの決まりは tests/rules/test_statuses.gd。

const Maps := preload("res://tests/support/maps.gd")

const P1 := Unit.Side.PLAYER1
const P2 := Unit.Side.PLAYER2
const AIM := Status.Type.AIM

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


## いまのフェーズを、CPU に最後まで進めさせる。受け付けた行動を返す。
func _play_phase(battle: Battle) -> Array[BattleAction]:
	var cpu := CpuPlayer.new()
	var result: Array[BattleAction] = []
	var phase := battle.phase
	while not battle.is_over() and battle.phase == phase and result.size() < 200:
		var action := cpu.next_action(battle)
		assert_true(action != null and battle.apply(action).accepted, "CPU の行動が断られた")
		result.append(action)
	return result


func _skill_uses(actions: Array[BattleAction]) -> Array[BattleAction]:
	return actions.filter(func(action: BattleAction) -> bool: return action is UseSkillAction)


func _end_turn(battle: Battle) -> void:
	battle.apply(EndPhaseAction.new())
	battle.apply(EndPhaseAction.new())


func test_sniper_has_it() -> void:
	var skill := Skills.of_kind(UnitKind.Id.SNIPER)
	assert_eq(skill.id(), Skill.Id.PRECISION_AIM)
	assert_eq(skill.cooldown(), PrecisionAimSkill.COOLDOWN)


func test_only_before_moving() -> void:
	var battle := Maps.battle(["........", "........"])
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	assert_eq(battle.options(sniper.id).skill_cells, [sniper.cell] as Array[Vector2i])
	battle.apply(MoveAction.new(sniper.id, Vector2i(1, 0)))
	assert_true(battle.options(sniper.id).skill_cells.is_empty(), "動いたあとは使えない")
	assert_false(battle.can_apply(UseSkillAction.new(sniper.id, sniper.cell)))
	battle.apply(UndoMoveAction.new(sniper.id))
	assert_true(battle.can_apply(UseSkillAction.new(sniper.id, sniper.cell)), "取り消せば使える")
	battle.apply(MoveAction.new(sniper.id, sniper.cell))
	assert_true(battle.can_apply(UseSkillAction.new(sniper.id, sniper.cell)), "動かない移動のあとは使える")


func test_gives_the_aim_and_ends_the_action() -> void:
	var battle := Maps.battle(["........", "........"])
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	var base := sniper.attack_range()
	var events := battle.apply(UseSkillAction.new(sniper.id, sniper.cell)).events
	assert_true(events[0] is SkillUsedEvent)
	var applied := events[1] as StatusAppliedEvent
	assert_eq([applied.unit_id, applied.status, applied.turns], [sniper.id, AIM, PrecisionAimSkill.AIM_TURNS])
	assert_true(events[2] is UnitActedEvent)
	assert_true(sniper.acted)
	assert_eq(sniper.skill_cooldown, PrecisionAimSkill.COOLDOWN)
	assert_eq(sniper.attack_range(), base + PrecisionAimSkill.RANGE_BONUS, "構えた時から、届く範囲が相手に見える")


func test_next_turn_one_long_critical_shot_from_the_same_cell() -> void:
	var battle := Maps.battle(["........", "........"])
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	var far := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(7, 0))
	var base := sniper.attack_range()
	assert_eq(Combat.distance(sniper.cell, far.cell), base + PrecisionAimSkill.RANGE_BONUS)
	battle.apply(UseSkillAction.new(sniper.id, sniper.cell))
	_end_turn(battle)
	assert_true(Statuses.has(sniper, AIM))
	var doubled := sniper.power() * PrecisionAimSkill.CRITICAL_PERCENT / 100
	var events := battle.apply(AttackAction.new(sniper.id, far.id)).events
	assert_true((events[0] as AttackDamagedEvent).critical)
	assert_eq(far.hp, far.max_hp() - doubled)
	assert_false(Statuses.has(sniper, AIM), "1 回で使い切る")
	assert_eq(sniper.attack_range(), base)


func test_moving_next_turn_gives_it_up() -> void:
	var battle := Maps.battle(["........", "........"])
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	var near := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(5, 0))
	battle.apply(UseSkillAction.new(sniper.id, sniper.cell))
	_end_turn(battle)
	battle.apply(MoveAction.new(sniper.id, Vector2i(1, 0)))
	assert_false(Statuses.has(sniper, AIM))
	battle.apply(AttackAction.new(sniper.id, near.id))
	assert_eq(near.hp, near.max_hp() - sniper.power(), "ふつうの攻撃")


func test_unused_aim_fades_at_the_turn_after_next() -> void:
	var battle := Maps.battle(["........", "........"])
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(7, 1))
	battle.apply(UseSkillAction.new(sniper.id, sniper.cell))
	_end_turn(battle)
	assert_true(Statuses.has(sniper, AIM))
	_end_turn(battle)
	assert_false(Statuses.has(sniper, AIM), "撃たなければ、次の次の自分の番の始めに消える")
	assert_eq(sniper.attack_range(), UnitKind.attack_range(UnitKind.Id.SNIPER))


func test_cpu_aims_at_an_enemy_it_cannot_reach_this_turn() -> void:
	# 壁に囲まれて動けない。敵は射程の外だが、伸びた射程なら、いまのマスから届く。
	var battle := Maps.battle([
		"................",
		"................",
		"................",
		".....###........",
		".....#.#........",
	])
	battle.board.hq_cells = [HQ1, HQ2]
	battle.add_unit(UnitKind.Id.KING, P1, HQ1)
	battle.add_unit(UnitKind.Id.KING, P2, HQ2)
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(6, 4))
	var target := battle.add_unit(UnitKind.Id.SORCERER, P2, Vector2i(11, 3))
	var uses := _skill_uses(_play_phase(battle))
	assert_eq(uses.size(), 1, "構えなかった")
	assert_true(Statuses.has(sniper, AIM))
	# 次の番、相手が動かなければ、構えたマスから撃つ。
	battle.apply(EndPhaseAction.new())
	_play_phase(battle)
	assert_eq(sniper.cell, Vector2i(6, 4), "動かずに撃つ")
	assert_eq(target.hp, target.max_hp() - sniper.power() * PrecisionAimSkill.CRITICAL_PERCENT / 100)


func test_cpu_shoots_instead_of_aiming_when_it_can_shoot_now() -> void:
	var battle := _cpu_battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(4, 2))
	var target := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(8, 2))
	assert_eq(_skill_uses(_play_phase(battle)).size(), 0)
	assert_eq(target.hp, target.max_hp() - sniper.power())


func test_cpu_does_not_aim_with_no_enemy_near() -> void:
	var battle := _cpu_battle()
	battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(1, 3))
	assert_eq(_skill_uses(_play_phase(battle)).size(), 0)


func test_cpu_with_an_aim_can_still_walk_and_shoot_at_normal_range() -> void:
	# 構えたが、相手は盾の陰に入った（いまのマスからは射線が通らない）。歩けば、もとの射程で届く。
	var battle := _cpu_battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(2, 1))
	var target := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P2, Vector2i(7, 1))
	FieldEffects.place_barricade(battle, P2, Vector2i(4, 1))
	Statuses.add(sniper, AIM, 1)
	sniper.skill_cooldown = 2
	assert_false(Combat.can_attack(battle, sniper, target))
	var actions := _play_phase(battle)
	assert_true(actions[0] is MoveAction, "動かなかった")
	assert_eq(target.hp, target.max_hp() - sniper.power(), "動いて、ふつうの攻撃を当てる")
