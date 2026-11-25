extends "res://tests/base_test.gd"
## 番人を狙わない陣営（Battle.spares_bosses。話の [enemy] の spare_boss。docs/scenario.md の「番人を狙わない群れ」）と、
## 将のいない群れとの、中ボスの撃破で勝つ戦いで、長引いたときの CPU（docs/cpu-ai.md の「膠着を解く」）。

const Maps := preload("res://tests/support/maps.gd")

const P1 := Unit.Side.PLAYER1
const P2 := Unit.Side.PLAYER2
const NEUTRAL := Unit.Side.NEUTRAL

## 中ボスは (3, 1)。その左隣 (2, 1) に樽。
const ROWS: Array[String] = [
	".......",
	"..B....",
	".......",
	".......",
]
const BOSS_CELL := Vector2i(3, 1)


func _battle() -> Battle:
	var battle := Maps.battle(ROWS)
	battle.spares_bosses[P2] = true
	return battle


func _boss(battle: Battle) -> Unit:
	var boss := battle.add_unit(UnitKind.Id.ELITE_MINION, NEUTRAL, BOSS_CELL)
	boss.home_cell = BOSS_CELL
	return boss


func test_the_sparing_side_cannot_attack_the_boss() -> void:
	var battle := _battle()
	var boss := _boss(battle)
	var archer := battle.add_unit(UnitKind.Id.SKELETON_ARCHER, P2, Vector2i(3, 3))
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(5, 2))
	assert_false(Combat.can_attack(battle, archer, boss), "番人を狙わない陣営は、番人を攻撃できない")
	assert_false(Combat.targets(battle, archer).has(boss))
	assert_true(Combat.can_attack(battle, archer, sniper), "ほかの相手は、いつもどおり")
	assert_true(Combat.can_attack(battle, sniper, boss), "相手の陣営は、いつもどおり番人を攻撃できる")
	battle.phase = P2
	assert_false(battle.apply(AttackAction.new(archer.id, boss.id)).accepted)
	battle.spares_bosses[P2] = false
	assert_true(Combat.can_attack(battle, archer, boss), "決まりを外せば、いつもどおり")


func test_a_barrel_the_sparing_side_sets_off_misses_the_boss() -> void:
	var battle := _battle()
	var boss := _boss(battle)
	var trooper := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(1, 1))
	var archer := battle.add_unit(UnitKind.Id.SKELETON_ARCHER, P2, Vector2i(2, 3))
	battle.phase = P2
	var result := battle.apply(AttackBarrelAction.new(archer.id, Vector2i(2, 1)))
	assert_true(result.accepted)
	assert_eq(boss.hp, boss.max_hp(), "番人は巻き込まれない")
	assert_true(trooper.hp < trooper.max_hp(), "ほかの駒は、いつもどおり巻き込まれる")
	var hit_ids: Array[int] = []
	for event in result.events:
		if event is BarrelExplodedEvent:
			hit_ids.assign((event as BarrelExplodedEvent).victim_ids)
	assert_false(hit_ids.has(boss.id), "爆発の巻き込みの列にも、番人は入らない")


func test_a_barrel_the_other_side_sets_off_still_hits_the_boss() -> void:
	var battle := _battle()
	var boss := _boss(battle)
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(2, 3))
	assert_true(battle.apply(AttackBarrelAction.new(sniper.id, Vector2i(2, 1))).accepted)
	assert_true(boss.hp < boss.max_hp())


## 糸喰いが弾けたダメージは、糸喰いを倒した陣営が起こしたことになる（docs/monsters.md）。
func test_a_burst_the_sparing_side_sets_off_misses_the_boss() -> void:
	var battle := _battle()
	var boss := _boss(battle)
	var eater := battle.add_unit(UnitKind.Id.EATER, P1, Vector2i(3, 2))
	var neighbor := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(4, 2))
	var brute := battle.add_unit(UnitKind.Id.SKELETON_BRUTE, P2, Vector2i(2, 2))
	eater.hp = 1
	battle.phase = P2
	assert_true(battle.apply(AttackAction.new(brute.id, eater.id)).accepted)
	assert_false(battle.units.has(eater), "糸喰いが倒れて弾けた")
	assert_true(neighbor.hp < neighbor.max_hp(), "周りの駒は、いつもどおり焼かれる")
	assert_eq(boss.hp, boss.max_hp(), "番人は焼かれない")


## 将のいない群れとの、中ボスの撃破で勝つ戦い。群れが全滅しても、ターン 40 を過ぎたら、傷んだ兵も将も中ボスへ向かう
## （敵の本陣へ向かっても勝てない。戦える兵がいなければ、将が向かう）。
func test_past_the_stall_turn_the_hunters_head_for_the_boss_when_the_horde_is_gone() -> void:
	for lone_king: bool in [false, true]:
		var battle := Maps.battle([
			".........",
			".........",
			".........",
			".........",
			".........",
			".........",
			".........",
			".........",
			".........",
		])
		battle.board.mid_boss_cells = [Vector2i(1, 2)]
		var boss := battle.add_unit(UnitKind.Id.ELITE_MINION, NEUTRAL, Vector2i(1, 2))
		boss.home_cell = Vector2i(1, 2)
		battle.win_conditions[P1] = [GameWonEvent.Reason.BOSS_SLAIN] as Array[GameWonEvent.Reason]
		var king := battle.add_unit(UnitKind.Id.KING, P1, Vector2i(4, 8))
		var mover := king
		if not lone_king:
			mover = battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(7, 7))
			mover.hp = 4
		battle.turn = CpuPlayer.STALL_TURN + 1
		var before := Combat.distance(mover.cell, boss.cell)
		var cpu := CpuPlayer.new()
		while battle.phase == P1 and not battle.is_over():
			assert_true(battle.apply(cpu.next_action(battle)).accepted)
		assert_true(Combat.distance(mover.cell, boss.cell) < before, "%s: 中ボスへ近づく（%s → %s）" % [
			"将だけ" if lone_king else "傷んだ奇襲", before, Combat.distance(mover.cell, boss.cell),
		])
