extends "res://tests/base_test.gd"
## 魔物だけの決まり（docs/monsters.md）: 種類の特性（大蝙蝠・糸針）と、倒れると何か起きる魔物（骸骨旗手・ほつれ）。
## 予測・脅威範囲・CPU の評価が、その効果を含むこと。

const Maps := preload("res://tests/support/maps.gd")

const P1 := Unit.Side.PLAYER1
const P2 := Unit.Side.PLAYER2
const RESOLVE := Status.Type.RESOLVE


func _battle() -> Battle:
	return Maps.battle(["..........", "..........", "..........", "..........", "..........", ".........."])


## battle で unit_id の駒を target_id の駒に、動かずに攻撃させる。
func _attack(battle: Battle, unit_id: int, target_id: int) -> ActionResult:
	var result := battle.apply(AttackAction.new(unit_id, target_id))
	assert_true(result.accepted, "攻撃が断られた")
	return result


func _of_type(events: Array[BattleEvent], script: Script) -> Array:
	return events.filter(func(event: BattleEvent) -> bool: return is_instance_of(event, script))


# ---- 種類の特性 ----


func test_kinds_carry_their_traits() -> void:
	var battle := _battle()
	var bat := battle.add_unit(UnitKind.Id.BAT, P1, Vector2i(0, 0))
	var needle := battle.add_unit(UnitKind.Id.NEEDLE, P1, Vector2i(2, 0))
	var banner := battle.add_unit(UnitKind.Id.SKELETON_BANNER, P1, Vector2i(4, 0))
	var fray := battle.add_unit(UnitKind.Id.FRAY, P1, Vector2i(6, 0))
	assert_true(bat.ignores_zoc() and bat.has_trait(Evolution.Trait.FOREST_WALK))
	assert_true(needle.has_trait(Evolution.Trait.ROOTED))
	assert_true(banner.has_trait(Evolution.Trait.RALLY_ON_FALL))
	assert_true(fray.has_trait(Evolution.Trait.KNOT_ON_FALL) and fray.exerts_zoc())
	for unit: Unit in [bat, needle, banner, fray]:
		assert_true(UnitKind.is_monster(unit.kind))


## 大蝙蝠は、前衛の支配領域で止まらずに抜ける。
func test_bat_flies_past_a_zoc() -> void:
	var battle := Maps.battle(["......", "......", "......"])
	var bat := battle.add_unit(UnitKind.Id.BAT, P1, Vector2i(0, 1))
	battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(2, 0))
	assert_true(Movement.reachable(battle, bat).has(Vector2i(5, 1)), "支配領域を抜けて、向こう側まで")
	var skeleton := battle.add_unit(UnitKind.Id.SKELETON, P1, Vector2i(0, 2))
	assert_false(Movement.reachable(battle, skeleton).has(Vector2i(5, 2)), "骸骨兵は支配領域で止まる")


## 糸針は動けない。突撃で移動力が上がっても、ポータルの上でも。
func test_needle_never_moves() -> void:
	var battle := _battle()
	var needle := battle.add_unit(UnitKind.Id.NEEDLE, P1, Vector2i(4, 3))
	battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(9, 0))
	assert_eq(needle.move_range(), 0)
	Statuses.add(needle, Status.Type.ASSAULT, 1)
	assert_eq(needle.move_range(), 0, "突撃でも動けない")
	assert_eq(Movement.reachable(battle, needle).keys(), [needle.cell], "止まれるのは、いまのマスだけ")
	assert_false(battle.apply(MoveAction.new(needle.id, Vector2i(4, 2))).accepted)
	assert_eq(needle.attack_range(), 4)


func test_needle_cannot_take_a_portal() -> void:
	var battle := _battle()
	assert_true(battle.board.add_portal_pair(Vector2i(4, 3), Vector2i(8, 0)))
	var needle := battle.add_unit(UnitKind.Id.NEEDLE, P1, Vector2i(4, 3))
	battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(9, 5))
	assert_false(battle.can_apply(WarpAction.new(needle.id)))
	assert_eq(Movement.reachable(battle, needle, false, true).keys(), [needle.cell], "ポータルを越えた探索でも、いまのマスだけ")
	assert_false(Threat.of(battle, needle.id).has(Vector2i(8, 4)), "ポータルの先からは撃たない")


# ---- 骸骨旗手 ----


## 倒れると、周り RALLY_RADIUS マスの味方に奮起。遠い味方と敵には付かない。
func test_banner_rallies_friends_when_it_falls() -> void:
	var battle := _battle()
	var killer := battle.add_unit(UnitKind.Id.SPELLBLADE, P1, Vector2i(3, 3))
	var banner := battle.add_unit(UnitKind.Id.SKELETON_BANNER, P2, Vector2i(4, 3))
	var near := battle.add_unit(UnitKind.Id.SKELETON, P2, Vector2i(5, 2))
	var edge := battle.add_unit(UnitKind.Id.SKELETON, P2, Vector2i(6, 3))
	var far := battle.add_unit(UnitKind.Id.SKELETON, P2, Vector2i(7, 3))
	assert_eq(Monsters.RALLY_RADIUS, 2, "下の置き方は、広さ 2 のため")
	banner.hp = 1
	var power := near.power()
	var result := _attack(battle, killer.id, banner.id)
	var rallies := _of_type(result.events, RallyEvent)
	assert_eq(rallies.size(), 1)
	var rally: RallyEvent = rallies[0]
	assert_eq(rally.fallen_id, banner.id)
	assert_eq(rally.rallied_ids, [near.id, edge.id] as Array[int], "2 マス以内の味方（上の行から）")
	assert_eq(near.power(), power + Formation.RESOLVE_POWER)
	assert_false(Statuses.has(far, RESOLVE))
	assert_false(Statuses.has(killer, RESOLVE))
	var defeated := result.events.find_custom(func(event: BattleEvent) -> bool: return event is UnitDefeatedEvent)
	assert_true(defeated < result.events.find(rally), "倒れたあとに奮起")
	# 相手（旗手の側）の番の終わりまで残り、そのあとの自分の番の始めに外れる。
	battle.apply(EndPhaseAction.new())
	assert_true(Statuses.has(near, RESOLVE), "旗手の側の番の間は残る")
	battle.apply(EndPhaseAction.new())
	battle.apply(EndPhaseAction.new())
	assert_false(Statuses.has(near, RESOLVE), "次の自分の番の終わりまで")


func test_banner_alone_rallies_nobody() -> void:
	var battle := _battle()
	var killer := battle.add_unit(UnitKind.Id.SPELLBLADE, P1, Vector2i(3, 3))
	var banner := battle.add_unit(UnitKind.Id.SKELETON_BANNER, P2, Vector2i(4, 3))
	banner.hp = 1
	assert_true(_of_type(_attack(battle, killer.id, banner.id).events, RallyEvent).is_empty())


## 予測は、奮起する駒を知っている。
func test_forecast_shows_the_rally() -> void:
	var battle := _battle()
	var killer := battle.add_unit(UnitKind.Id.SPELLBLADE, P1, Vector2i(3, 3))
	var banner := battle.add_unit(UnitKind.Id.SKELETON_BANNER, P2, Vector2i(4, 3))
	var near := battle.add_unit(UnitKind.Id.SKELETON, P2, Vector2i(5, 3))
	banner.hp = 1
	var forecast := Forecast.of(battle, AttackAction.new(killer.id, banner.id))
	assert_true(forecast.outcome(near.id) != null and forecast.outcome(near.id).rallied)
	assert_eq(forecast.outcome(near.id).statuses_applied.get(RESOLVE, 0), 2)
	assert_false(Statuses.has(near, RESOLVE), "予測は状態を変えない")


## CPU は、同じ旗手を倒すなら、周りに味方の少ない時に倒すほうを高く見る（倒す価値から、奮起する駒の数だけ引く）。
func test_cpu_values_a_lonely_banner_kill_higher() -> void:
	var values: Array[float] = []
	for crowd: int in [0, 3]:
		var battle := _battle()
		var killer := battle.add_unit(UnitKind.Id.SPELLBLADE, P1, Vector2i(3, 3))
		var banner := battle.add_unit(UnitKind.Id.SKELETON_BANNER, P2, Vector2i(4, 3))
		for i: int in crowd:
			battle.add_unit(UnitKind.Id.SKELETON, P2, Vector2i(5, 2 + i))
		banner.hp = 1
		values.append(_cpu_value(battle, AttackAction.new(killer.id, banner.id)))
	assert_eq(values[0] - values[1], 3 * CpuPlayer.RALLY_PENALTY)


# ---- ほつれと結び目 ----


func _fray_battle() -> Array:
	var battle := _battle()
	var killer := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(1, 3))
	var fray := battle.add_unit(UnitKind.Id.FRAY, P2, Vector2i(4, 3))
	battle.add_unit(UnitKind.Id.KING, P2, Vector2i(9, 0))
	fray.hp = 1
	return [battle, killer, fray]


## 倒れると、そのマスに結び目が残る。
func test_fray_leaves_a_knot() -> void:
	var made := _fray_battle()
	var battle: Battle = made[0]
	var fray: Unit = made[2]
	var result := _attack(battle, made[1].id, fray.id)
	var placed := _of_type(result.events, KnotPlacedEvent)
	assert_eq(placed.size(), 1)
	var event: KnotPlacedEvent = placed[0]
	assert_eq([event.center, event.side, event.turns_left, event.kind], [Vector2i(4, 3), P2, Monsters.KNOT_TURNS, UnitKind.Id.FRAY])
	var knot := Monsters.knot_at(battle, Vector2i(4, 3))
	assert_true(knot != null and knot.is_walkable() and not knot.blocks_line_of_fire())


## 放っておくと、持ち主の KNOT_TURNS 回目のフェーズの始めに立ち直り、そのフェーズから動ける。
func test_an_untouched_knot_reforms() -> void:
	var made := _fray_battle()
	var battle: Battle = made[0]
	_attack(battle, made[1].id, made[2].id)
	assert_eq(Monsters.KNOT_TURNS, 2, "下の進め方は、2 のため")
	var first := battle.apply(EndPhaseAction.new())  # P2 の番の始め: 残り 1
	assert_eq(_of_type(first.events, UnitSpawnedEvent).size(), 0)
	assert_eq(Monsters.knot_at(battle, Vector2i(4, 3)).turns_left, 1)
	battle.apply(EndPhaseAction.new())  # 中立、P1
	var second := battle.apply(EndPhaseAction.new())  # P2 の番の始め: 立ち直る
	var removed := _of_type(second.events, FieldEffectRemovedEvent)
	assert_eq(removed.size(), 1)
	assert_eq((removed[0] as FieldEffectRemovedEvent).reason, FieldEffectRemovedEvent.Reason.REFORMED)
	var spawned := _of_type(second.events, UnitSpawnedEvent)
	assert_eq(spawned.size(), 1)
	var reformed := battle.unit_at(Vector2i(4, 3))
	assert_true(reformed != null and reformed.kind == UnitKind.Id.FRAY and reformed.side == P2)
	assert_eq(reformed.hp, reformed.max_hp(), "HP は満ちて")
	assert_true(battle.can_act(reformed), "そのフェーズから動ける")
	assert_eq(Monsters.knot_at(battle, Vector2i(4, 3)), null)


## 相手の駒が乗っていれば、持ち主のフェーズの始めにほどける。
func test_standing_on_a_knot_unties_it() -> void:
	var made := _fray_battle()
	var battle: Battle = made[0]
	var stepper := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(6, 3))
	_attack(battle, made[1].id, made[2].id)
	assert_true(battle.apply(MoveAction.new(stepper.id, Vector2i(4, 3))).accepted, "結び目のマスに入れる")
	battle.apply(WaitAction.new(stepper.id))
	var result := battle.apply(EndPhaseAction.new())
	var removed := _of_type(result.events, FieldEffectRemovedEvent)
	assert_eq(removed.size(), 1)
	assert_eq((removed[0] as FieldEffectRemovedEvent).reason, FieldEffectRemovedEvent.Reason.UNTIED)
	assert_eq(Monsters.knot_at(battle, Vector2i(4, 3)), null)


## 持ち主の駒が乗っていると、空くまで待つ（残り 1 のまま）。
func test_a_knot_waits_under_a_friend() -> void:
	var made := _fray_battle()
	var battle: Battle = made[0]
	_attack(battle, made[1].id, made[2].id)
	battle.apply(EndPhaseAction.new())
	var friend := battle.add_unit(UnitKind.Id.SKELETON, P2, Vector2i(4, 3))
	battle.apply(EndPhaseAction.new())
	var result := battle.apply(EndPhaseAction.new())
	assert_eq(_of_type(result.events, UnitSpawnedEvent).size(), 0)
	assert_eq(Monsters.knot_at(battle, Vector2i(4, 3)).turns_left, 1)
	assert_eq(battle.unit_at(Vector2i(4, 3)), friend)


## 予測は、残る結び目を知っている。
func test_forecast_shows_the_knot() -> void:
	var made := _fray_battle()
	var battle: Battle = made[0]
	var forecast := Forecast.of(battle, AttackAction.new(made[1].id, made[2].id))
	assert_eq(forecast.placed.size(), 1)
	assert_true(forecast.placed[0] is KnotPlacedEvent)
	assert_eq(Monsters.knot_at(battle, Vector2i(4, 3)), null, "予測は盤を変えない")


## 脅威範囲（敵の全員）は、次の番に立ち直るほつれが届くマスも含む。
func test_threat_counts_the_fray_that_will_reform() -> void:
	var made := _fray_battle()
	var battle: Battle = made[0]
	_attack(battle, made[1].id, made[2].id)
	battle.apply(EndPhaseAction.new())
	battle.apply(EndPhaseAction.new())  # P1 の番。次の P2 の番の始めに立ち直る
	assert_eq(Monsters.knot_at(battle, Vector2i(4, 3)).turns_left, 1)
	var map := Threat.against(battle, P1)
	assert_true(map.has(Vector2i(4, 1)), "立ち直ったほつれが 2 歩動いて隣を叩けるマス")
	assert_true(map.has(Vector2i(4, 6 - 1)))


## CPU は、相手の結び目の上に立つことを高く見て、ほつれを倒す価値は結び目のぶん下げる。
func test_cpu_steps_on_a_foe_knot() -> void:
	var made := _fray_battle()
	var battle: Battle = made[0]
	_attack(battle, made[1].id, made[2].id)
	var commando := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(6, 4))  # 将には届かない所
	var cpu := CpuPlayer.new()
	var steps := 0
	while battle.phase == P1 and steps < 20:
		var action := cpu.next_action(battle)
		if action is EndPhaseAction:
			break
		assert_true(battle.apply(action).accepted)
		steps += 1
	assert_eq(commando.cell, Vector2i(4, 3), "結び目を踏みに行く")


func test_cpu_lowers_the_fray_kill_by_the_knot() -> void:
	var made := _fray_battle()
	var battle: Battle = made[0]
	var fray_value := _cpu_value(battle, AttackAction.new(made[1].id, made[2].id))
	var other := _battle()
	var sniper := other.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(1, 3))
	var skeleton := other.add_unit(UnitKind.Id.SKELETON_BANNER, P2, Vector2i(4, 3))  # 同じコスト 2、倒れても何も残らない
	other.add_unit(UnitKind.Id.KING, P2, Vector2i(9, 0))
	skeleton.hp = 1
	var plain_value := _cpu_value(other, AttackAction.new(sniper.id, skeleton.id))
	assert_eq(UnitKind.cost(UnitKind.Id.FRAY), UnitKind.cost(UnitKind.Id.SKELETON_BANNER))
	assert_eq(plain_value - fray_value, CpuPlayer.KNOT_PENALTY)


## CPU が、いまの手番の陣営として action の結果をどう見るか（_outcome_value）。
func _cpu_value(battle: Battle, action: BattleAction) -> float:
	var cpu := CpuPlayer.new()
	cpu._begin(battle)
	var sim := battle.clone()
	var result := sim.apply(action)
	assert_true(result.accepted)
	return cpu._outcome_value(sim, result.events)
