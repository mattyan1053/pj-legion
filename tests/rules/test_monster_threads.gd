extends "res://tests/base_test.gd"
## 骸骨でない、糸の魔物の決まり（docs/monsters.md）: 当てると絡める糸蜘蛛と、倒れると弾ける糸喰い。
## 予測・脅威範囲・CPU の評価が、その効果を含むこと。

const Maps := preload("res://tests/support/maps.gd")

const P1 := Unit.Side.PLAYER1
const P2 := Unit.Side.PLAYER2
const SNARE := Status.Type.SNARE


func _battle() -> Battle:
	return Maps.battle(["..........", "..........", "..........", "..........", "..........", ".........."])


func _of_type(events: Array[BattleEvent], script: Script) -> Array:
	return events.filter(func(event: BattleEvent) -> bool: return is_instance_of(event, script))


## P1 の番を終えて、P2 の番にする（間の中立の番も進める）。
func _to_p2(battle: Battle) -> void:
	while battle.phase != P2:
		assert_true(battle.apply(EndPhaseAction.new()).accepted)


func _to_p1(battle: Battle) -> void:
	battle.apply(EndPhaseAction.new())
	while battle.phase != P1:
		assert_true(battle.apply(EndPhaseAction.new()).accepted)


func test_kinds_carry_their_traits() -> void:
	var battle := _battle()
	var spider := battle.add_unit(UnitKind.Id.SPIDER, P1, Vector2i(0, 0))
	var eater := battle.add_unit(UnitKind.Id.EATER, P1, Vector2i(2, 0))
	assert_true(spider.has_trait(Evolution.Trait.BINDS_ON_HIT))
	assert_true(eater.has_trait(Evolution.Trait.BURSTS_ON_FALL) and eater.exerts_zoc())
	for unit: Unit in [spider, eater]:
		assert_true(UnitKind.is_monster(unit.kind))
		assert_false(Equipment.can_equip(unit.kind))


# ---- 糸蜘蛛と絡み ----


## 糸蜘蛛の攻撃が当たると、相手は次の自分の番に動けない。その次の番には動ける。攻撃はできる。
func test_spider_binds_its_target_for_one_turn() -> void:
	var battle := _battle()
	battle.add_unit(UnitKind.Id.KING, P1, Vector2i(0, 0))
	battle.add_unit(UnitKind.Id.KING, P2, Vector2i(9, 5))
	var target := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(4, 3))
	var foe := battle.add_unit(UnitKind.Id.SKELETON, P2, Vector2i(3, 3))
	var spider := battle.add_unit(UnitKind.Id.SPIDER, P2, Vector2i(5, 3))
	_to_p2(battle)
	var result := battle.apply(AttackAction.new(spider.id, target.id))
	assert_true(result.accepted)
	var applied := _of_type(result.events, StatusAppliedEvent)
	assert_eq(applied.size(), 1)
	assert_eq((applied[0] as StatusAppliedEvent).status, SNARE)
	assert_eq(target.hp, UnitKind.max_hp(UnitKind.Id.PALADIN) - UnitKind.power(UnitKind.Id.SPIDER))
	_to_p1(battle)
	assert_true(Statuses.has(target, SNARE), "自分の番のあいだ、残っている")
	assert_eq(target.move_range(), 0)
	assert_eq(Movement.reachable(battle, target).keys(), [target.cell])
	assert_false(battle.apply(MoveAction.new(target.id, Vector2i(4, 2))).accepted, "動けない")
	assert_true(battle.apply(AttackAction.new(target.id, foe.id)).accepted, "攻撃はできる")
	_to_p2(battle)
	_to_p1(battle)
	assert_false(Statuses.has(target, SNARE), "次の自分の番の始めに外れる")
	assert_eq(target.move_range(), UnitKind.move_range(UnitKind.Id.PALADIN))


## 突撃で移動力が上がっても、ポータルの上でも、絡まった駒は動かない。
func test_snare_holds_through_assault_and_portals() -> void:
	var battle := _battle()
	assert_true(battle.board.add_portal_pair(Vector2i(4, 3), Vector2i(8, 0)))
	var unit := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(4, 3))
	battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(9, 5))
	Statuses.add(unit, SNARE, 1)
	Statuses.add(unit, Status.Type.ASSAULT, 1)
	assert_eq(unit.move_range(), 0)
	assert_false(battle.can_apply(WarpAction.new(unit.id)))
	assert_eq(Movement.reachable(battle, unit, false, true).keys(), [unit.cell])


## 倒した相手と、煙幕に阻まれた攻撃には付かない。ほかの魔物の攻撃にも付かない。
func test_no_snare_without_a_landed_hit_on_a_survivor() -> void:
	var battle := _battle()
	var spider := battle.add_unit(UnitKind.Id.SPIDER, P1, Vector2i(3, 3))
	var weak := battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(4, 3))
	weak.hp = 1
	var result := battle.apply(AttackAction.new(spider.id, weak.id))
	assert_true(result.accepted)
	assert_true(_of_type(result.events, StatusAppliedEvent).is_empty(), "倒した相手には付かない")
	var other := _battle()
	var bat := other.add_unit(UnitKind.Id.BAT, P1, Vector2i(3, 3))
	var target := other.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(4, 3))
	other.apply(AttackAction.new(bat.id, target.id))
	assert_false(Statuses.has(target, SNARE), "大蝙蝠の攻撃では絡まない")


## 予測に、絡みの付くことが入る。
func test_forecast_shows_the_snare() -> void:
	var battle := _battle()
	var spider := battle.add_unit(UnitKind.Id.SPIDER, P1, Vector2i(3, 3))
	var target := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(4, 3))
	var forecast := Forecast.of(battle, AttackAction.new(spider.id, target.id))
	assert_eq(forecast.outcome(target.id).statuses_applied.get(SNARE, 0), 2)
	assert_false(Statuses.has(target, SNARE), "予測は状態を変えない")


## 敵の脅威範囲は、絡まった駒のいまのマスから届くところだけ。
func test_threat_of_a_snared_unit_stays_put() -> void:
	var battle := _battle()
	var unit := battle.add_unit(UnitKind.Id.COMMANDO, P2, Vector2i(4, 3))
	var free_reach := Threat.of(battle, unit.id).cells().size()
	Statuses.add(unit, SNARE, 2)
	var cells := Threat.of(battle, unit.id).cells()
	assert_true(cells.size() < free_reach)
	for cell: Vector2i in cells:
		assert_true(Combat.distance(cell, unit.cell) <= unit.attack_range(), str(cell))


## CPU は、まだ絡まっていない相手に絡みを付ける手を、SNARE_VALUE だけ高く見る。
func test_cpu_values_a_fresh_snare() -> void:
	var values: Array[float] = []
	for already: bool in [false, true]:
		var battle := _battle()
		var spider := battle.add_unit(UnitKind.Id.SPIDER, P1, Vector2i(3, 3))
		var target := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(4, 3))
		battle.add_unit(UnitKind.Id.KING, P2, Vector2i(9, 0))
		if already:
			Statuses.add(target, SNARE, 1)
		values.append(_cpu_value(battle, AttackAction.new(spider.id, target.id)))
	assert_eq(values[0] - values[1], CpuPlayer.SNARE_VALUE)


# ---- 糸喰い ----


## 倒れると、周り 8 マスの駒すべて（敵も味方も、倒した駒も）に BURST_DAMAGE。遠い駒には届かない。
func test_eater_bursts_when_it_falls() -> void:
	var battle := _battle()
	var killer := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(3, 3))
	var eater := battle.add_unit(UnitKind.Id.EATER, P2, Vector2i(4, 3))
	var friend := battle.add_unit(UnitKind.Id.SKELETON_BRUTE, P2, Vector2i(5, 4))
	var ally := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(4, 2))
	var far := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(6, 3))
	eater.hp = 1
	var result := battle.apply(AttackAction.new(killer.id, eater.id))
	assert_true(result.accepted)
	var bursts := _of_type(result.events, BurstEvent)
	assert_eq(bursts.size(), 1)
	var burst: BurstEvent = bursts[0]
	assert_eq(burst.fallen_id, eater.id)
	assert_eq(burst.by_id, killer.id)
	assert_eq(burst.cell, Vector2i(4, 3))
	assert_eq(burst.victim_ids, [ally.id, killer.id, friend.id] as Array[int], "上の行から、左の列から")
	assert_eq(_of_type(result.events, ExplosionDamagedEvent).size(), 3)
	assert_eq(killer.hp, UnitKind.max_hp(UnitKind.Id.PALADIN) - Monsters.BURST_DAMAGE, "倒した駒も巻き込まれる")
	assert_eq(ally.hp, UnitKind.max_hp(UnitKind.Id.SHIELD_TROOPER) - Monsters.BURST_DAMAGE)
	assert_eq(friend.hp, UnitKind.max_hp(UnitKind.Id.SKELETON_BRUTE) - Monsters.BURST_DAMAGE, "味方も巻き込まれる")
	assert_eq(far.hp, UnitKind.max_hp(UnitKind.Id.SNIPER), "2 マス先には届かない")
	assert_true(killer.acted, "倒した駒は、ふつうに行動を終える")


## 倒した駒が弾けて倒れたら、経験値も行動を終えるイベントも出ない。弾けて倒れた糸喰いは、続けて弾ける。
func test_bursts_can_take_the_killer_and_chain() -> void:
	var battle := _battle()
	battle.add_unit(UnitKind.Id.KING, P1, Vector2i(0, 0))
	battle.add_unit(UnitKind.Id.KING, P2, Vector2i(9, 5))
	var killer := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(3, 3))
	var first := battle.add_unit(UnitKind.Id.EATER, P2, Vector2i(4, 3))
	var second := battle.add_unit(UnitKind.Id.EATER, P2, Vector2i(5, 3))
	var beyond := battle.add_unit(UnitKind.Id.SKELETON, P2, Vector2i(6, 3))
	killer.hp = 5
	first.hp = 1
	second.hp = 5
	var result := battle.apply(AttackAction.new(killer.id, first.id))
	assert_true(result.accepted)
	assert_false(battle.units.has(killer), "倒した駒も弾けて倒れた")
	assert_false(battle.units.has(second))
	assert_eq(_of_type(result.events, BurstEvent).size(), 2, "続けて弾ける")
	assert_eq(beyond.hp, UnitKind.max_hp(UnitKind.Id.SKELETON) - Monsters.BURST_DAMAGE, "2 つめの糸喰いの隣")
	assert_true(_of_type(result.events, ExperienceGainedEvent).is_empty())
	assert_true(_of_type(result.events, UnitActedEvent).is_empty())
	var second_burst: BurstEvent = _of_type(result.events, BurstEvent)[1]
	assert_eq(second_burst.by_id, killer.id, "続けて弾けたのも、はじめに倒した駒のもの")


## 樽の爆発で倒れても弾ける。弾けて倒れた駒を、樽の爆発がもう一度取り除かない。
func test_a_barrel_can_set_off_an_eater() -> void:
	var battle := _battle()
	battle.board.add_barrel(Vector2i(4, 3))
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 3))
	var eater := battle.add_unit(UnitKind.Id.EATER, P2, Vector2i(4, 2))
	var both := battle.add_unit(UnitKind.Id.SKELETON, P2, Vector2i(5, 2))  # 樽にも糸喰いにも隣り合う
	eater.hp = 1
	both.hp = 1
	var result := battle.apply(AttackBarrelAction.new(sniper.id, Vector2i(4, 3)))
	assert_true(result.accepted)
	assert_eq(_of_type(result.events, BurstEvent).size(), 1)
	var defeated := _of_type(result.events, UnitDefeatedEvent)
	assert_eq(defeated.size(), 2, "2 体とも 1 回ずつ倒れる")
	var burst: BurstEvent = _of_type(result.events, BurstEvent)[0]
	assert_false(burst.victim_ids.has(both.id), "同じ爆発で倒れた駒に、2 度当てない")
	var hits_on_both := _of_type(result.events, ExplosionDamagedEvent).filter(
		func(event: ExplosionDamagedEvent) -> bool: return event.unit_id == both.id)
	assert_eq(hits_on_both.size(), 1)


## 予測に、弾けて巻き込まれる駒が入る（倒した駒自身も）。
func test_forecast_shows_the_burst() -> void:
	var battle := _battle()
	var killer := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(3, 3))
	var eater := battle.add_unit(UnitKind.Id.EATER, P2, Vector2i(4, 3))
	eater.hp = 1
	var forecast := Forecast.of(battle, AttackAction.new(killer.id, eater.id))
	var mine := forecast.outcome(killer.id)
	assert_true(mine != null and mine.exploded)
	assert_eq(mine.damage, Monsters.BURST_DAMAGE)
	assert_eq(killer.hp, UnitKind.max_hp(UnitKind.Id.PALADIN), "予測は状態を変えない")


## CPU は、弾けて自分の駒が倒れるなら、隣から叩くより、離れて撃つほうを高く見る（巻き込まれて倒れる分だけ）。
func test_cpu_prefers_to_shoot_an_eater_from_afar() -> void:
	var battle := _battle()
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(3, 3))
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(4, 0))
	var eater := battle.add_unit(UnitKind.Id.EATER, P2, Vector2i(4, 3))
	battle.add_unit(UnitKind.Id.KING, P2, Vector2i(9, 0))
	eater.hp = 1
	paladin.hp = Monsters.BURST_DAMAGE
	var close := _cpu_value(battle, AttackAction.new(paladin.id, eater.id))
	var afar := _cpu_value(battle, AttackAction.new(sniper.id, eater.id))
	assert_true(afar > close, "%s > %s" % [afar, close])


## CPU が、いまの手番の陣営として action の結果をどう見るか（_outcome_value）。
func _cpu_value(battle: Battle, action: BattleAction) -> float:
	var cpu := CpuPlayer.new()
	cpu._begin(battle)
	var sim := battle.clone()
	var result := sim.apply(action)
	assert_true(result.accepted)
	return cpu._outcome_value(sim, result.events)
