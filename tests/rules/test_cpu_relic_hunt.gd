extends "res://tests/base_test.gd"
## CPU が中ボスを狩る・狩らない・相手に取らせない（docs/relic-buff.md の「CPU」）。

const Maps := preload("res://tests/support/maps.gd")

const P1 := Unit.Side.PLAYER1
const P2 := Unit.Side.PLAYER2
const NEUTRAL := Unit.Side.NEUTRAL

## 壁の無い 30 x 9 の盤面。中ボスの場所は (8, 4)。本陣は左下と右上。
const HOME := Vector2i(8, 4)


func _battle() -> Battle:
	var rows: Array[String] = []
	for y in 9:
		rows.append(".".repeat(30))
	var battle := Maps.battle(rows)
	battle.board.mid_boss_cells = [HOME]
	battle.board.hq_cells = [Vector2i(0, 8), Vector2i(29, 0)]
	battle.add_unit(UnitKind.Id.KING, P1, Vector2i(0, 8))
	battle.add_unit(UnitKind.Id.KING, P2, Vector2i(29, 0))
	battle.turn = CpuPlayer.HUNT_FROM_TURN  # CPU は、序盤には狩りを始めない
	return battle


## 中ボス。hp を渡せば、そこまで減らしておく。
func _boss(battle: Battle, hp := 0) -> Unit:
	var unit := battle.add_unit(UnitKind.Id.ELITE_MINION, NEUTRAL, HOME)
	unit.home_cell = HOME
	if hp > 0:
		unit.hp = hp
	return unit


## いまのフェーズを CPU に最後まで進めさせ、返した行動を返す。
func _play_phase(battle: Battle) -> Array[BattleAction]:
	var cpu := CpuPlayer.new()
	var actions: Array[BattleAction] = []
	var phase := battle.phase
	while battle.phase == phase and not battle.is_over():
		var action := cpu.next_action(battle)
		assert_true(battle.apply(action).accepted)
		actions.append(action)
		if actions.size() > 60:
			break
	return actions


func _distance(unit: Unit, to: Vector2i) -> int:
	return Combat.distance(unit.cell, to)


func test_free_squad_hunts_the_boss() -> void:
	var battle := _battle()
	var boss := _boss(battle)
	# 手の空いた 4 体（攻撃力 6 + 6 + 9 + 12 = 33）。相手の戦う駒はいない。
	var squad: Array[Unit] = [
		battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(4, 4)),
		battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(4, 5)),
		battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(3, 3)),
		battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(3, 5)),
	]
	_play_phase(battle)
	assert_true(boss.hp < boss.max_hp(), "届く駒から殴り始める")
	for unit in squad:
		assert_true(_distance(unit, boss.cell) <= 4, "中ボスへ寄る: %s" % UnitKind.display_name(unit.kind))


func test_cpu_does_not_start_a_hunt_in_the_opening() -> void:
	var battle := _battle()
	battle.turn = CpuPlayer.HUNT_FROM_TURN - 1
	var boss := _boss(battle)
	battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(4, 4))
	battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(4, 5))
	battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(3, 3))
	battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(3, 5))
	_play_phase(battle)
	assert_eq(boss.hp, boss.max_hp(), "序盤は、相手の軍が無傷で残っている。狩りを始めない")


func test_small_squad_leaves_a_fresh_boss_alone() -> void:
	var battle := _battle()
	var boss := _boss(battle)
	# 2 体（攻撃力 6 + 9）では、決めたターン数のうちに倒せない。相手の将へ向かう。
	var trooper := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(2, 8))
	battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(1, 8))
	for i in 3:
		_play_phase(battle)
		battle.apply(EndPhaseAction.new())
		battle.apply(EndPhaseAction.new())
	assert_eq(boss.hp, boss.max_hp(), "倒しきれない中ボスを削りに行かない")
	assert_true(trooper.cell.x > 2, "相手のほうへ進む")


func test_squad_does_not_start_a_hunt_with_stronger_rivals_close() -> void:
	var battle := _battle()
	var boss := _boss(battle)
	battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(4, 4))
	battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(4, 5))
	battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(3, 3))
	battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(3, 5))
	# 倒しきる前（3 ターン）に着ける相手（攻撃力 8 + 8 + 11 + 11 + 12 = 50）のほうが、はっきり強い（自分は 31）。
	battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(13, 3))
	battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(13, 5))
	battle.add_unit(UnitKind.Id.SORCERER, P2, Vector2i(14, 4))
	battle.add_unit(UnitKind.Id.SORCERER, P2, Vector2i(14, 3))
	battle.add_unit(UnitKind.Id.SPELLBLADE, P2, Vector2i(14, 5))
	_play_phase(battle)
	assert_eq(boss.hp, boss.max_hp(), "横取りされる狩りを始めない")


func test_engaged_units_fight_instead_of_hunting() -> void:
	var battle := _battle()
	var boss := _boss(battle)
	battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(4, 4))
	battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(4, 5))
	battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(3, 3))
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(3, 5))
	# 弱い相手が 1 体、すぐそばにいる。届く駒は、中ボスではなく相手を殴る。
	var foe := battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(3, 8))
	_play_phase(battle)
	assert_true(battle.unit_by_id(foe.id) == null, "そばの相手を先に倒す")
	assert_true(battle.unit_by_id(commando.id) != null)
	assert_eq(boss.hp, boss.max_hp())


func test_cpu_does_not_set_up_the_last_hit_for_the_foe() -> void:
	var battle := _battle()
	var boss := _boss(battle, 20)
	# 自分の 1 体（攻撃力 12）で殴ると、残り 8。そばの相手（攻撃力 12）に止めを渡すことになる。
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, HOME + Vector2i(-1, 0))
	battle.add_unit(UnitKind.Id.SPELLBLADE, P2, HOME + Vector2i(5, 0))
	_play_phase(battle)
	assert_eq(boss.hp, 20, "止めを相手に渡す削りをしない")
	assert_true(battle.unit_by_id(commando.id) != null)


func test_cpu_chips_when_a_friend_can_finish_this_phase() -> void:
	var battle := _battle()
	_boss(battle, 19)
	# 同じ形でも、このフェーズに味方が続けて殴れば倒しきれるなら、殴る（スナイパー 7 + コマンドー 12）。
	battle.add_unit(UnitKind.Id.COMMANDO, P1, HOME + Vector2i(-1, 0))
	battle.add_unit(UnitKind.Id.SNIPER, P1, HOME + Vector2i(-4, 0))
	battle.add_unit(UnitKind.Id.SPELLBLADE, P2, HOME + Vector2i(5, 0))
	_play_phase(battle)
	assert_true(battle.is_mid_boss_defeated(0), "2 体で倒しきる")
	assert_eq(battle.mid_boss_slayers[0], P1)
	assert_true(Relics.has(battle, P1, Relics.Id.WISDOM))


func test_raider_goes_to_steal_a_boss_the_foe_has_worn_down() -> void:
	var battle := _battle()
	var boss := _boss(battle, 25)
	# 相手の 3 体が中ボスを削っている。離れた奇襲が、止めを取りに寄る。
	battle.add_unit(UnitKind.Id.PALADIN, P2, HOME + Vector2i(1, 0))
	battle.add_unit(UnitKind.Id.PALADIN, P2, HOME + Vector2i(0, -1))
	battle.add_unit(UnitKind.Id.SORCERER, P2, HOME + Vector2i(2, -1))
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(0, 4))
	battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(1, 4))
	var before := _distance(commando, boss.cell)
	_play_phase(battle)
	assert_true(_distance(commando, boss.cell) < before, "中ボスへ寄る")
	assert_eq(boss.hp, 25, "届かないうちは削らない")


func test_cpu_prefers_the_relic_to_a_small_hit() -> void:
	var battle := _battle()
	_boss(battle, 10)
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, HOME + Vector2i(-1, 0))
	# 隣に相手の前衛もいる。殴れば 12 のダメージだが、聖遺物のほうが重い。
	battle.add_unit(UnitKind.Id.PALADIN, P2, HOME + Vector2i(-1, 1))
	_play_phase(battle)
	assert_true(Relics.has(battle, P1, Relics.Id.WISDOM), "止めを刺して聖遺物を取る")
	assert_true(battle.unit_by_id(commando.id) != null)
