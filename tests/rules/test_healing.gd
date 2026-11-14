extends "res://tests/base_test.gd"
## 回復役の回復の対象・射程・回復量と、回復の行動。

const Maps := preload("res://tests/support/maps.gd")

const P1 := Unit.Side.PLAYER1
const P2 := Unit.Side.PLAYER2
const SHIELD := Equipment.Id.IRON_SHIELD


func _battle() -> Battle:
	return Maps.battle([
		"........",
		"..#.....",
		"........",
	])


## HP を減らした駒を置く。
func _wounded(battle: Battle, kind: UnitKind.Id, side: Unit.Side, cell: Vector2i, hp: int) -> Unit:
	var unit := battle.add_unit(kind, side, cell)
	unit.hp = hp
	return unit


func test_medic_heals_15_at_range_1() -> void:
	var battle := _battle()
	var medic := battle.add_unit(UnitKind.Id.MEDIC, P1, Vector2i(4, 1))
	var near := _wounded(battle, UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(5, 1), 10)
	var diagonal := _wounded(battle, UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(5, 2), 10)
	assert_true(Healing.can_heal(battle, medic, near))
	assert_false(Healing.can_heal(battle, medic, diagonal))  # 斜め隣は距離 2
	assert_eq(Healing.amount(medic, near), 15)


func test_priest_heals_12_at_range_2() -> void:
	var battle := _battle()
	var priest := battle.add_unit(UnitKind.Id.PRIEST, P1, Vector2i(4, 1))
	var near := _wounded(battle, UnitKind.Id.PALADIN, P1, Vector2i(5, 2), 10)  # 距離 2
	var far := _wounded(battle, UnitKind.Id.PALADIN, P1, Vector2i(7, 1), 10)  # 距離 3
	assert_true(Healing.can_heal(battle, priest, near))
	assert_false(Healing.can_heal(battle, priest, far))
	assert_eq(Healing.amount(priest, near), 12)


func test_walls_do_not_block_healing() -> void:
	var battle := _battle()
	var priest := battle.add_unit(UnitKind.Id.PRIEST, P1, Vector2i(1, 1))
	var ally := _wounded(battle, UnitKind.Id.PALADIN, P1, Vector2i(3, 1), 10)  # 間に壁
	assert_true(Healing.can_heal(battle, priest, ally))


func test_only_healers_heal() -> void:
	var battle := _battle()
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(0, 0))
	var ally := _wounded(battle, UnitKind.Id.SNIPER, P1, Vector2i(1, 0), 5)
	assert_false(Healing.can_heal(battle, paladin, ally))
	assert_false(battle.apply(HealAction.new(paladin.id, ally.id)).accepted)
	assert_eq(ally.hp, 5)


func test_enemies_and_neutrals_cannot_be_healed() -> void:
	var battle := _battle()
	var medic := battle.add_unit(UnitKind.Id.MEDIC, P1, Vector2i(4, 0))
	var enemy := _wounded(battle, UnitKind.Id.SNIPER, P2, Vector2i(5, 0), 5)
	var minion := _wounded(battle, UnitKind.Id.MINION, Unit.Side.NEUTRAL, Vector2i(3, 0), 5)
	assert_false(Healing.can_heal(battle, medic, enemy))
	assert_false(Healing.can_heal(battle, medic, minion))
	assert_eq(Healing.targets(battle, medic), [] as Array[Unit])
	assert_false(battle.apply(HealAction.new(medic.id, enemy.id)).accepted)
	assert_eq(enemy.hp, 5)


func test_healers_cannot_heal_themselves() -> void:
	var battle := _battle()
	var medic := _wounded(battle, UnitKind.Id.MEDIC, P1, Vector2i(4, 0), 5)
	assert_false(Healing.can_heal(battle, medic, medic))
	assert_false(battle.apply(HealAction.new(medic.id, medic.id)).accepted)
	assert_eq(medic.hp, 5)


func test_allies_at_full_hp_cannot_be_healed() -> void:
	var battle := _battle()
	var medic := battle.add_unit(UnitKind.Id.MEDIC, P1, Vector2i(4, 0))
	var ally := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(5, 0))
	assert_false(Healing.can_heal(battle, medic, ally))
	assert_false(battle.apply(HealAction.new(medic.id, ally.id)).accepted)
	assert_false(medic.acted)


func test_healers_can_heal_each_other() -> void:
	var battle := _battle()
	var medic := battle.add_unit(UnitKind.Id.MEDIC, P1, Vector2i(4, 0))
	var other := _wounded(battle, UnitKind.Id.MEDIC, P1, Vector2i(5, 0), 5)
	assert_true(battle.apply(HealAction.new(medic.id, other.id)).accepted)
	assert_eq(other.hp, 20)


func test_targets_lists_healable_units_in_board_order() -> void:
	var battle := _battle()
	var priest := battle.add_unit(UnitKind.Id.PRIEST, P1, Vector2i(4, 1))
	var b := _wounded(battle, UnitKind.Id.PALADIN, P1, Vector2i(4, 2), 10)
	var a := _wounded(battle, UnitKind.Id.PALADIN, P1, Vector2i(5, 0), 10)
	battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(3, 1))  # 満タン
	_wounded(battle, UnitKind.Id.PALADIN, P2, Vector2i(5, 1), 10)  # 敵
	assert_eq(Healing.targets(battle, priest), [a, b] as Array[Unit])


func test_heal_restores_hp_and_ends_the_action() -> void:
	var battle := _battle()
	var medic := battle.add_unit(UnitKind.Id.MEDIC, P1, Vector2i(4, 0))
	var ally := _wounded(battle, UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(5, 0), 10)  # 最大 HP 44
	var result := battle.apply(HealAction.new(medic.id, ally.id))
	assert_true(result.accepted)
	assert_eq(ally.hp, 25)
	assert_eq(result.events.size(), 2)
	var healed := result.events[0] as UnitHealedEvent
	assert_eq(healed.healer_id, medic.id)
	assert_eq(healed.unit_id, ally.id)
	assert_eq(healed.amount, 15)
	assert_eq(healed.hp, 25)
	assert_eq((result.events[1] as UnitActedEvent).unit_id, medic.id)
	assert_true(medic.acted)
	assert_false(battle.apply(HealAction.new(medic.id, ally.id)).accepted)
	assert_false(battle.apply(WaitAction.new(medic.id)).accepted)


func test_heal_stops_at_max_hp() -> void:
	var battle := _battle()
	var medic := battle.add_unit(UnitKind.Id.MEDIC, P1, Vector2i(4, 0))
	var ally := _wounded(battle, UnitKind.Id.SNIPER, P1, Vector2i(5, 0), 10)  # 最大 HP 16
	assert_eq(Healing.amount(medic, ally), 6)
	var healed := battle.apply(HealAction.new(medic.id, ally.id)).events[0] as UnitHealedEvent
	assert_eq(ally.hp, 16)
	assert_eq(healed.amount, 6)
	assert_eq(healed.hp, 16)


func test_heal_uses_effective_stats() -> void:
	var battle := _battle()
	var medic := battle.add_unit(UnitKind.Id.MEDIC, P1, Vector2i(4, 0))
	var ally := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(6, 0), [SHIELD] as Array[Equipment.Id])
	ally.hp = 16  # 最大 HP は盾で 46
	assert_false(Healing.can_heal(battle, medic, ally))  # 距離 2
	medic.relic_bonus[Unit.Stat.ATTACK_RANGE] = 1
	medic.temporary_bonus[Unit.Stat.POWER] = 5
	assert_true(Healing.can_heal(battle, medic, ally))
	battle.apply(HealAction.new(medic.id, ally.id))
	assert_eq(ally.hp, 36)


func test_heal_after_moving() -> void:
	var battle := _battle()
	var medic := battle.add_unit(UnitKind.Id.MEDIC, P1, Vector2i(0, 0))
	var ally := _wounded(battle, UnitKind.Id.SNIPER, P1, Vector2i(4, 0), 1)
	battle.apply(MoveAction.new(medic.id, Vector2i(3, 0)))
	assert_true(battle.apply(HealAction.new(medic.id, ally.id)).accepted)
	assert_eq(ally.hp, 16)


func test_no_heal_after_cruise() -> void:
	var battle := _battle()
	var medic := battle.add_unit(UnitKind.Id.MEDIC, P1, Vector2i(0, 0))
	var ally := _wounded(battle, UnitKind.Id.SNIPER, P1, Vector2i(7, 0), 1)
	battle.apply(MoveAction.new(medic.id, Vector2i(6, 0), true))
	assert_false(battle.apply(HealAction.new(medic.id, ally.id)).accepted)
	assert_eq(ally.hp, 1)
	assert_true(battle.apply(WaitAction.new(medic.id)).accepted)


func test_no_heal_in_the_enemy_phase() -> void:
	var battle := _battle()
	var priest := battle.add_unit(UnitKind.Id.PRIEST, P2, Vector2i(4, 0))
	var ally := _wounded(battle, UnitKind.Id.PALADIN, P2, Vector2i(5, 0), 10)
	assert_false(battle.can_apply(HealAction.new(priest.id, ally.id)))
	battle.apply(EndPhaseAction.new())
	assert_true(battle.can_apply(HealAction.new(priest.id, ally.id)))
	assert_eq(ally.hp, 10)  # can_apply は状態を変えない


func test_heal_on_a_clone_leaves_the_original() -> void:
	var battle := _battle()
	var medic := battle.add_unit(UnitKind.Id.MEDIC, P1, Vector2i(4, 0))
	var ally := _wounded(battle, UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(5, 0), 10)
	var copy := battle.clone()
	copy.apply(HealAction.new(medic.id, ally.id))
	assert_eq(copy.unit_by_id(ally.id).hp, 25)
	assert_eq(ally.hp, 10)
	assert_false(medic.acted)
