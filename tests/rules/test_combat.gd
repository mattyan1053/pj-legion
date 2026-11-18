extends "res://tests/base_test.gd"
## 攻撃の対象・射程・ダメージ・撃破と、攻撃の行動。

const Maps := preload("res://tests/support/maps.gd")

const P1 := Unit.Side.PLAYER1
const P2 := Unit.Side.PLAYER2


func _battle() -> Battle:
	return Maps.battle([
		"........",
		"..#.....",
		"..F.....",
	])


func test_range_is_manhattan_distance() -> void:
	var battle := _battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))  # 射程 4
	var near := battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(3, 1))  # 距離 4
	var far := battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(3, 2))  # 距離 5
	assert_true(Combat.can_attack(battle, sniper, near))
	assert_false(Combat.can_attack(battle, sniper, far))


func test_melee_reaches_only_neighbours() -> void:
	var battle := _battle()
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(4, 1))  # 射程 1
	var side := battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(5, 1))
	var diagonal := battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(5, 2))
	assert_true(Combat.can_attack(battle, paladin, side))
	assert_false(Combat.can_attack(battle, paladin, diagonal))


func test_walls_do_not_block_range() -> void:
	var battle := _battle()
	var sorcerer := battle.add_unit(UnitKind.Id.SORCERER, P1, Vector2i(1, 1))  # 射程 2
	var target := battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(3, 1))  # 間に壁
	assert_true(Combat.can_attack(battle, sorcerer, target))


func test_allies_cannot_be_attacked() -> void:
	var battle := _battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	var ally := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(1, 0))
	assert_false(Combat.can_attack(battle, sniper, ally))


func test_neutrals_can_be_attacked() -> void:
	var battle := _battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	var minion := battle.add_unit(UnitKind.Id.MINION, Unit.Side.NEUTRAL, Vector2i(1, 0))
	assert_true(Combat.can_attack(battle, sniper, minion))


func test_healers_do_not_attack() -> void:
	var battle := _battle()
	var medic := battle.add_unit(UnitKind.Id.MEDIC, P1, Vector2i(0, 0))
	var enemy := battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(1, 0))
	assert_false(Combat.can_attack(battle, medic, enemy))


func test_targets_lists_attackable_units_in_board_order() -> void:
	var battle := _battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(3, 0))
	var b := battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(5, 2))
	var a := battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(6, 0))
	battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(4, 0))
	assert_eq(Combat.targets(battle, sniper), [a, b] as Array[Unit])


func test_damage_is_attack_power() -> void:
	var battle := _battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))  # 攻撃力 7
	var target := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(1, 0))
	assert_eq(Combat.damage(battle, sniper, target), 7)


func test_forest_cuts_damage_by_20_percent_rounding_down() -> void:
	var battle := _battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 2))  # 攻撃力 7
	var target := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(2, 2))  # 森
	assert_eq(Combat.damage(battle, sniper, target), 5)  # 5.6 → 5


## 移動の軽減: 自分の番にほかのマスへ動いた駒は、次の自分の番が来るまで、受ける攻撃のダメージが 0.75 倍（端数切り捨て）。
func test_a_unit_that_moved_takes_less_damage_until_its_next_turn() -> void:
	var battle := _battle()
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(5, 0))
	var sorcerer := battle.add_unit(UnitKind.Id.SORCERER, P2, Vector2i(7, 1))  # 攻撃力 11
	assert_false(paladin.on_the_move)
	assert_true(battle.apply(MoveAction.new(paladin.id, Vector2i(6, 0))).accepted)
	assert_true(paladin.on_the_move)
	assert_true(battle.apply(WaitAction.new(paladin.id)).accepted)
	assert_true(battle.apply(EndPhaseAction.new()).accepted)
	assert_eq(battle.phase, P2)
	assert_eq(Combat.damage(battle, sorcerer, paladin), 11 * Combat.MOVING_DAMAGE_RATE_PERCENT / 100)  # 8.25 → 8
	var events := battle.apply(AttackAction.new(sorcerer.id, paladin.id)).events
	var damaged := events[0] as AttackDamagedEvent
	assert_true(damaged.moving)
	assert_false(damaged.forest)
	assert_eq(paladin.hp, paladin.max_hp() - 8)
	# 次の自分の番の始めに解ける。
	assert_true(battle.apply(EndPhaseAction.new()).accepted)
	while battle.phase != P1:
		assert_true(battle.apply(EndPhaseAction.new()).accepted)
	assert_false(paladin.on_the_move)


func test_moving_cut_stacks_with_forest_and_skips_units_that_stayed() -> void:
	var battle := _battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 2))  # 攻撃力 7
	var target := battle.add_unit(UnitKind.Id.SORCERER, P2, Vector2i(2, 2))  # 森
	target.on_the_move = true
	assert_eq(Combat.damage(battle, sniper, target), 7 * 80 / 100 * Combat.MOVING_DAMAGE_RATE_PERCENT / 100, "森のあとに掛ける")
	var hit := Combat.hit(battle, sniper, target)
	assert_true(hit.forest and hit.moving)
	# 動かない移動（いまのマスへ）と、取り消した移動では付かない。
	var mover := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(5, 0))
	assert_true(battle.apply(MoveAction.new(mover.id, mover.cell)).accepted)
	assert_false(mover.on_the_move)
	assert_true(battle.apply(UndoMoveAction.new(mover.id)).accepted)
	assert_true(battle.apply(MoveAction.new(mover.id, Vector2i(6, 0))).accepted)
	assert_true(mover.on_the_move)
	assert_true(battle.apply(UndoMoveAction.new(mover.id)).accepted)
	assert_false(mover.on_the_move, "取り消すと戻る")


func test_attack_reduces_hp_and_ends_the_action() -> void:
	var battle := _battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	var target := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(4, 0))  # HP 52
	var events := battle.apply(AttackAction.new(sniper.id, target.id)).events
	assert_eq(target.hp, 45)
	assert_eq(events.size(), 3)
	var damaged := events[0] as AttackDamagedEvent
	assert_eq(damaged.attacker_id, sniper.id)
	assert_eq(damaged.unit_id, target.id)
	assert_eq(damaged.amount, 7)
	assert_eq(damaged.hp, 45)
	assert_eq(damaged.cause, UnitDamagedEvent.Cause.ATTACK)
	assert_true(events[1] is ExperienceGainedEvent)  # docs/experience-levelup.md
	assert_eq((events[2] as UnitActedEvent).unit_id, sniper.id)
	assert_true(sniper.acted)


func test_attack_after_moving() -> void:
	var battle := _battle()
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(0, 0))
	var target := battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(4, 0))
	battle.apply(MoveAction.new(paladin.id, Vector2i(3, 0)))
	assert_eq(battle.apply(AttackAction.new(paladin.id, target.id)).events.size(), 3)


func test_no_attack_after_cruise() -> void:
	var battle := _battle()
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(0, 0))
	var target := battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(5, 0))
	battle.apply(MoveAction.new(paladin.id, Vector2i(4, 0), true))
	assert_false(battle.apply(AttackAction.new(paladin.id, target.id)).accepted)
	assert_eq(battle.apply(WaitAction.new(paladin.id)).events.size(), 1)


func test_out_of_range_attack_is_rejected() -> void:
	var battle := _battle()
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(0, 0))
	var target := battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(5, 0))
	assert_false(battle.apply(AttackAction.new(paladin.id, target.id)).accepted)
	assert_eq(target.hp, 13)
	assert_false(paladin.acted)


func test_acted_units_cannot_attack() -> void:
	var battle := _battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	var target := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(1, 0))
	battle.apply(AttackAction.new(sniper.id, target.id))
	assert_false(battle.apply(AttackAction.new(sniper.id, target.id)).accepted)


func test_zero_hp_defeats_and_removes_the_unit() -> void:
	var battle := _battle()
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(0, 0))  # 攻撃力 12
	var minion := battle.add_unit(UnitKind.Id.MINION, Unit.Side.NEUTRAL, Vector2i(1, 0))  # HP 12
	var events := battle.apply(AttackAction.new(commando.id, minion.id)).events
	assert_eq(events.size(), 4)
	assert_eq((events[0] as UnitDamagedEvent).hp, 0)
	var defeated := events[1] as UnitDefeatedEvent
	assert_eq(defeated.unit_id, minion.id)
	assert_eq(defeated.cell, Vector2i(1, 0))
	assert_true(events[2] is ExperienceGainedEvent)
	assert_true(events[3] is UnitActedEvent)
	assert_eq(battle.unit_at(Vector2i(1, 0)), null)
	assert_eq(battle.unit_by_id(minion.id), null)


func test_overkill_stops_hp_at_zero() -> void:
	var battle := _battle()
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(0, 0))
	var minion := battle.add_unit(UnitKind.Id.MINION, Unit.Side.NEUTRAL, Vector2i(1, 0))
	minion.hp = 3
	var events := battle.apply(AttackAction.new(commando.id, minion.id)).events
	assert_eq((events[0] as UnitDamagedEvent).hp, 0)
	assert_eq((events[0] as UnitDamagedEvent).amount, 12)
