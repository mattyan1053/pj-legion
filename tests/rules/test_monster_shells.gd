extends "res://tests/base_test.gd"
## 骸骨でない魔物の決まり（docs/monsters.md）: 離れた所からは狙えない殻蟹と、周りの敵の攻撃を弱める糸茸。
## 予測・ログの印・CPU の見積もりが、その効果を含むこと。

const Maps := preload("res://tests/support/maps.gd")

const P1 := Unit.Side.PLAYER1
const P2 := Unit.Side.PLAYER2


func _battle() -> Battle:
	return Maps.battle(["..........", "..........", "..........", "..........", "..........", ".........."])


func _of_type(events: Array[BattleEvent], script: Script) -> Array:
	return events.filter(func(event: BattleEvent) -> bool: return is_instance_of(event, script))


func test_kinds_carry_their_traits() -> void:
	var battle := _battle()
	var crab := battle.add_unit(UnitKind.Id.CRAB, P1, Vector2i(0, 0))
	var shroom := battle.add_unit(UnitKind.Id.SHROOM, P1, Vector2i(2, 0))
	assert_true(crab.has_trait(Evolution.Trait.SHELLED) and crab.exerts_zoc())
	assert_true(shroom.has_trait(Evolution.Trait.SPORES))
	assert_false(shroom.exerts_zoc())
	for unit: Unit in [crab, shroom]:
		assert_true(UnitKind.is_monster(unit.kind))
		assert_false(Equipment.can_equip(unit.kind))


# ---- 殻蟹 ----


## 2 マス以上離れた所からの攻撃では狙えない。隣からなら狙える。
func test_crab_turns_away_ranged_attacks() -> void:
	var battle := _battle()
	var crab := battle.add_unit(UnitKind.Id.CRAB, P2, Vector2i(4, 3))
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(4, 0))
	var sorcerer := battle.add_unit(UnitKind.Id.SORCERER, P1, Vector2i(5, 2))  # 斜め隣は距離 2
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(3, 3))
	assert_false(Combat.can_attack(battle, sniper, crab))
	assert_false(Combat.can_attack(battle, sorcerer, crab), "斜め隣（距離 2）も離れた所")
	assert_false(Combat.targets(battle, sniper).has(crab))
	assert_false(battle.can_apply(AttackAction.new(sniper.id, crab.id)))
	assert_true(Combat.can_attack(battle, paladin, crab))
	var result := battle.apply(AttackAction.new(paladin.id, crab.id))
	assert_true(result.accepted)
	assert_eq(crab.hp, UnitKind.max_hp(UnitKind.Id.CRAB) - UnitKind.power(UnitKind.Id.PALADIN))


## 殻蟹は、自分の攻撃と、ほかの駒への攻撃には関わらない（殻蟹の攻撃する側は、ふつうに狙える）。
func test_crab_itself_attacks_as_usual() -> void:
	var battle := _battle()
	var crab := battle.add_unit(UnitKind.Id.CRAB, P2, Vector2i(4, 3))
	var target := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(4, 2))
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(4, 0))
	var skeleton := battle.add_unit(UnitKind.Id.SKELETON, P2, Vector2i(6, 1))
	assert_true(Combat.can_attack(battle, crab, target))
	assert_true(Combat.can_attack(battle, sniper, skeleton))


## 狙わずに範囲で当たるもの（起爆樽の爆発）は、殻蟹にも当たる。
func test_blasts_still_hit_a_crab() -> void:
	var battle := _battle()
	battle.board.add_barrel(Vector2i(4, 2))
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(4, 0))
	var crab := battle.add_unit(UnitKind.Id.CRAB, P2, Vector2i(4, 3))
	var result := battle.apply(AttackBarrelAction.new(sniper.id, Vector2i(4, 2)))
	assert_true(result.accepted)
	assert_true(crab.hp < UnitKind.max_hp(UnitKind.Id.CRAB))


## CPU の危険の見積もりは、殻蟹には離れた所からの攻撃を数えない。
func test_cpu_danger_of_a_crab_counts_only_close_attacks() -> void:
	var battle := _battle()
	battle.add_unit(UnitKind.Id.KING, P1, Vector2i(9, 5))
	battle.add_unit(UnitKind.Id.KING, P2, Vector2i(0, 0))
	battle.add_unit(UnitKind.Id.NEEDLE, P2, Vector2i(9, 0))  # 動けないが、遠くまで撃つ
	var crab := battle.add_unit(UnitKind.Id.CRAB, P1, Vector2i(6, 0))
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(6, 1))
	var cpu := CpuPlayer.new()
	assert_eq(cpu.danger(battle, crab.id, Vector2i(6, 0)), 0)
	assert_true(cpu.danger(battle, paladin.id, Vector2i(6, 0)) > 0, "殻の無い駒は、同じマスで撃たれる")


# ---- 糸茸 ----


## 糸茸の周り 8 マス（斜めも）にいる敵の攻撃は、SPORE_PENALTY だけ弱まる。離れた駒の攻撃は弱まらない。
func test_spores_weaken_attacks_from_next_to_a_shroom() -> void:
	var battle := _battle()
	var shroom := battle.add_unit(UnitKind.Id.SHROOM, P2, Vector2i(4, 3))
	var target := battle.add_unit(UnitKind.Id.SKELETON_BRUTE, P2, Vector2i(6, 2))
	var near := battle.add_unit(UnitKind.Id.SORCERER, P1, Vector2i(5, 2))  # 糸茸の斜め隣
	var far := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(6, 5))
	var power_near := UnitKind.power(UnitKind.Id.SORCERER)
	assert_eq(Monsters.spore_penalty(battle, near), Monsters.SPORE_PENALTY)
	assert_eq(Monsters.spore_sources(battle, near), [shroom] as Array[Unit])
	assert_eq(Combat.damage(battle, near, target), power_near - Monsters.SPORE_PENALTY)
	assert_eq(Combat.damage(battle, far, target), UnitKind.power(UnitKind.Id.SNIPER))
	var result := battle.apply(AttackAction.new(near.id, target.id))
	var damaged: AttackDamagedEvent = _of_type(result.events, AttackDamagedEvent)[0]
	assert_true(damaged.spores, "ログが読む印")
	assert_eq(damaged.amount, power_near - Monsters.SPORE_PENALTY)


## 糸茸そのものを隣から叩いても弱まる。何本の糸茸の隣でも 1 回だけ。味方の糸茸では弱まらない。0 より下にはならない。
func test_spores_do_not_stack_or_touch_friends() -> void:
	var battle := _battle()
	var shroom := battle.add_unit(UnitKind.Id.SHROOM, P2, Vector2i(4, 3))
	battle.add_unit(UnitKind.Id.SHROOM, P2, Vector2i(3, 2))
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(4, 2))
	assert_eq(Monsters.spore_sources(battle, commando).size(), 2)
	assert_eq(Combat.damage(battle, commando, shroom), UnitKind.power(UnitKind.Id.COMMANDO) - Monsters.SPORE_PENALTY)
	var friend := battle.add_unit(UnitKind.Id.SKELETON, P2, Vector2i(5, 3))
	assert_eq(Monsters.spore_penalty(battle, friend), 0, "糸茸の味方は弱まらない")
	var weak := battle.add_unit(UnitKind.Id.SKELETON_DRUMMER, P1, Vector2i(5, 4))
	Statuses.add(weak, Status.Type.FATIGUE, 2)  # 攻撃力が胞子の量より低い
	assert_true(weak.power() < Monsters.SPORE_PENALTY)
	assert_eq(Combat.damage(battle, weak, shroom), 0)


## 予測に、胞子で弱まることが入る。
func test_forecast_shows_the_spores() -> void:
	var battle := _battle()
	battle.add_unit(UnitKind.Id.SHROOM, P2, Vector2i(4, 3))
	var target := battle.add_unit(UnitKind.Id.SKELETON_BRUTE, P2, Vector2i(5, 3))
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(5, 2))
	var forecast := Forecast.of(battle, AttackAction.new(paladin.id, target.id))
	var outcome := forecast.outcome(target.id)
	assert_true(outcome.spores)
	assert_eq(outcome.damage, UnitKind.power(UnitKind.Id.PALADIN) - Monsters.SPORE_PENALTY)


## バリアに防がれたときは、胞子の印を付けない（ダメージは 0 のまま）。
func test_no_spore_mark_on_a_blocked_hit() -> void:
	var battle := _battle()
	battle.add_unit(UnitKind.Id.SHROOM, P2, Vector2i(4, 3))
	var target := battle.add_unit(UnitKind.Id.SKELETON_BRUTE, P2, Vector2i(5, 3))
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(5, 2))
	Statuses.add(target, Status.Type.BARRIER, 2)
	var hit := Combat.hit(battle, paladin, target)
	assert_eq(hit.amount, 0)
	assert_false(hit.spores)


## CPU は、胞子で弱まらない手を高く見る（同じ相手を、糸茸の隣から叩くより、離れた所から叩く）。
func test_cpu_values_attacks_away_from_spores() -> void:
	var values: Array[float] = []
	for beside: bool in [false, true]:
		var battle := _battle()
		battle.add_unit(UnitKind.Id.KING, P2, Vector2i(9, 0))
		var attacker := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(4, 2))
		var target := battle.add_unit(UnitKind.Id.SKELETON_BRUTE, P2, Vector2i(4, 3))
		battle.add_unit(UnitKind.Id.SHROOM, P2, Vector2i(3, 1) if beside else Vector2i(0, 5))
		var cpu := CpuPlayer.new()
		cpu._begin(battle)
		var sim := battle.clone()
		var result := sim.apply(AttackAction.new(attacker.id, target.id))
		assert_true(result.accepted)
		values.append(cpu._outcome_value(sim, result.events))
	assert_true(values[0] > values[1], "%s > %s" % values)
