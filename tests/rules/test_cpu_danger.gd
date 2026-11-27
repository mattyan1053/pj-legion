extends "res://tests/base_test.gd"
## CPU の危険の見積もり（docs/cpu-ai.md の「危険の見積もり」）。駒に付く状態、相手のスキル、盾、煙幕を見ること。

const Maps := preload("res://tests/support/maps.gd")

const P1 := Unit.Side.PLAYER1
const P2 := Unit.Side.PLAYER2

## 壁の無い 16 x 5 の盤面。
const OPEN_ROWS: Array[String] = [
	"................",
	"................",
	"................",
	"................",
	"................",
]
const HERE := Vector2i(0, 2)


## P1 の将を HERE に置いた、P1 の番の対戦。
func _battle() -> Battle:
	var battle := Maps.battle(OPEN_ROWS)
	battle.add_unit(UnitKind.Id.KING, P1, HERE)
	return battle


func _danger(battle: Battle, cell := HERE) -> int:
	return CpuPlayer.new().danger(battle, battle.units[0].id, cell)


func test_counts_enemies_that_can_move_and_attack() -> void:
	var battle := _battle()
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P2, Vector2i(7, 2))
	assert_eq(_danger(battle), commando.power())
	assert_eq(_danger(battle, Vector2i(0, 0)), 0, "移動力 + 射程の外")


func test_own_units_are_no_danger_and_healers_count_their_strike() -> void:
	var battle := _battle()
	battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(1, 2))
	assert_eq(_danger(battle), 0)
	battle.add_unit(UnitKind.Id.PRIEST, P2, Vector2i(3, 2))
	assert_eq(_danger(battle), UnitKind.healer_strike(UnitKind.Id.PRIEST), "回復役は、回復役の攻撃の強さ")


func test_barrier_takes_off_the_weakest_hit() -> void:
	var battle := _battle()
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P2, Vector2i(7, 2))
	Statuses.add(battle.units[0], Status.Type.BARRIER, 2)
	assert_eq(_danger(battle), 0, "1 回だけの攻撃は、バリアが防ぐ")
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(6, 2))
	assert_true(sniper.power() < commando.power())
	assert_eq(_danger(battle), commando.power(), "弱いほうで先にはがされる")


func test_aimed_enemy_hits_twice_as_hard() -> void:
	var battle := _battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(7, 2))
	assert_eq(_danger(battle), sniper.power())
	Statuses.add(sniper, Status.Type.AIM, 2)
	var aimed := Combat.attack_power(sniper)
	assert_eq(aimed, sniper.power() * 2)
	assert_eq(_danger(battle), aimed, "伸びた射程（4 + 3）の中")
	# 構えたマスからは届かないが、動けば届くマス: もとの攻撃力。
	assert_eq(_danger(battle, Vector2i(0, 1)), 0, "構えたマスから 8。動いても（照準は外れる）3 + 4 では届かない")


func test_expired_aim_is_not_counted() -> void:
	# 残り 1 ターンの照準は、相手の番の始めに外れる。
	var battle := _battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(7, 2))
	Statuses.add(sniper, Status.Type.AIM, 1)
	assert_eq(_danger(battle), sniper.power())


func test_counts_a_ready_fireball() -> void:
	var battle := _battle()
	var sorcerer := battle.add_unit(UnitKind.Id.SORCERER, P2, Vector2i(7, 2))
	# 移動 3 + 射程 2 では届かないが、移動 3 + 中心 3 + 腕 1 で届く。
	assert_eq(_danger(battle), FireballSkill.DAMAGE)
	assert_eq(_danger(battle, Vector2i(2, 2)), sorcerer.power(), "攻撃も届くマスは、強いほう")
	sorcerer.skill_cooldown = 2
	assert_eq(_danger(battle), 0, "クールダウンの間は飛んでこない")
	sorcerer.skill_cooldown = 1
	assert_eq(_danger(battle), FireballSkill.DAMAGE, "相手の番の始めに 0 になる")


func test_counts_a_ready_shadow_step() -> void:
	var battle := _battle()
	var spellblade := battle.add_unit(UnitKind.Id.SPELLBLADE, P2, Vector2i(10, 2))
	# 移動 6 + 射程 1 では届かないが、跳べば（3）届く。
	assert_eq(_danger(battle), spellblade.power())
	spellblade.skill_cooldown = 2
	assert_eq(_danger(battle), 0)


func test_barricade_cuts_the_line_of_a_ranged_enemy() -> void:
	var rows: Array[String] = [
		"....#...",
		"....#...",
		"........",
		"....#...",
		"....#...",
	]
	var battle := Maps.battle(rows)
	battle.add_unit(UnitKind.Id.KING, P1, Vector2i(3, 2))
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(7, 2))
	assert_eq(CpuPlayer.new().danger(battle, 1, Vector2i(3, 2)), sniper.power())
	# 通路の口に盾を置くと、通れず、射線も切れる。
	assert_false(FieldEffects.place_barricade(battle, P1, Vector2i(4, 2)).is_empty())
	assert_eq(CpuPlayer.new().danger(battle, 1, Vector2i(3, 2)), 0)
	assert_eq(CpuPlayer.new().danger(battle, 1, Vector2i(3, 1)), sniper.power(), "壁越しには届く")


func test_own_smoke_keeps_out_ranged_attacks_but_not_close_ones() -> void:
	var rows: Array[String] = [
		"....#...",
		"....#...",
		"....#...",
		"....#...",
		"....#...",
	]
	var battle := Maps.battle(rows)
	battle.add_unit(UnitKind.Id.KING, P1, Vector2i(3, 2))
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(6, 2))
	var cpu := CpuPlayer.new()
	assert_eq(cpu.danger(battle, 1, Vector2i(3, 2)), sniper.power())
	FieldEffects.place_smoke(battle, P1, Vector2i(3, 2))
	assert_eq(cpu.danger(battle, 1, Vector2i(3, 2)), 0, "壁の向こうからは、隣まで寄れない")
	assert_eq(cpu.danger(battle, 1, Vector2i(3, 0)), sniper.power(), "煙幕の外")
	# 隣まで寄れる敵と、スキルのダメージは、煙幕では防げない。
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P2, Vector2i(0, 2))
	assert_eq(cpu.danger(battle, 1, Vector2i(3, 2)), commando.power())
	var sorcerer := battle.add_unit(UnitKind.Id.SORCERER, P2, Vector2i(7, 4))
	assert_true(Skills.can_use(battle, sorcerer))
	assert_eq(cpu.danger(battle, 1, Vector2i(3, 2)), commando.power() + FireballSkill.DAMAGE)


func test_own_smoke_does_not_keep_out_a_neutral_that_can_walk_up() -> void:
	var battle := _battle()
	var minion := battle.add_unit(UnitKind.Id.MINION, Unit.Side.NEUTRAL, HERE + Vector2i(3, 0))
	FieldEffects.place_smoke(battle, P1, HERE)
	assert_eq(minion.move_range() + minion.attack_range(), 3)
	assert_eq(_danger(battle), minion.power(), "中立の駒は、隣まで寄って殴る")
	minion.cell = HERE + Vector2i(4, 0)
	assert_eq(_danger(battle), 0)


func test_danger_does_not_change_the_battle() -> void:
	var battle := _battle()
	battle.add_unit(UnitKind.Id.SORCERER, P2, Vector2i(7, 2))
	var before := battle.clone()
	_danger(battle)
	assert_eq(battle.turn, before.turn)
	assert_eq(battle.phase, before.phase)
	assert_eq(battle.units[1].skill_cooldown, before.units[1].skill_cooldown)
	assert_eq(battle.rng.state, before.rng.state)


# ---- 本物のダメージと同じ（見張り） ----
# CPU の読むダメージが、同じ場面で実際に攻撃したときのダメージと同じになること。効果を重ねた場面で見る。
# 攻撃する駒は動けなくして（移動力 0）、いまのマスから攻撃させる（CPU が見込む攻撃するマスと同じになる）。
# 新しい効果をダメージの解決（Combat.hit_from）の外に足したり、CPU の側に別の計算を書いたりすると、ここが落ちる。


## 動けない駒を置く。
func _fixed(battle: Battle, kind: UnitKind.Id, side: Unit.Side, cell: Vector2i) -> Unit:
	var unit := battle.add_unit(kind, side, cell)
	unit.relic_bonus[Unit.Stat.MOVE_RANGE] = -99
	return unit


## battle（P1 の番）を相手の番まで進めて、attackers の順に defender を攻撃させたときのダメージの合計（実際の攻撃）。
func _real(battle: Battle, defender: Unit, attackers: Array[Unit]) -> int:
	var sim := battle.clone()
	for i in 3:
		if sim.phase == P2:
			break
		assert_true(sim.apply(EndPhaseAction.new()).accepted)
	var total := 0
	for attacker in attackers:
		var result := sim.apply(AttackAction.new(attacker.id, defender.id))
		assert_true(result.accepted, "%s が攻撃できる" % attacker.kind)
		for event in result.events:
			if event is AttackDamagedEvent:
				total += (event as AttackDamagedEvent).amount
	return total


func test_reads_the_real_damage_with_forest_guard_spores_and_focus() -> void:
	# 守る側は森に立ち、パラディンの隣（守護）。近くの敵は胞子（守る側の糸茸）の中から殴る。遠くの敵は 2 体目なので集中砲火。
	var rows: Array[String] = [".......", ".......", "...F...", ".......", "......."]
	var battle := Maps.battle(rows)
	battle.traits = [Traits.Id.GUARD, Traits.Id.FOCUS]
	var defender := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(3, 2))
	battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(3, 1))
	battle.add_unit(UnitKind.Id.SHROOM, P1, Vector2i(5, 3))
	var near := _fixed(battle, UnitKind.Id.COMMANDO, P2, Vector2i(4, 2))
	var far := _fixed(battle, UnitKind.Id.SNIPER, P2, Vector2i(3, 4))
	var real := _real(battle, defender, [near, far])
	assert_true(Combat.hit(battle, near, defender).spores, "胞子が効く場面")
	assert_eq(CpuPlayer.new().danger(battle, defender.id, defender.cell), real)


func test_reads_the_real_damage_with_ranks_vengeance_and_smoke() -> void:
	# 守る側は隊列（同じ兵種の隣）で、相手の仇。自分の煙幕の中なので、離れた敵の攻撃は 0。
	var battle := Maps.battle(OPEN_ROWS)
	battle.traits = [Traits.Id.RANKS, Traits.Id.VENGEANCE]
	var defender := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(5, 2))
	battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(5, 1))
	defender.slew_sides = 1 << int(P2)
	FieldEffects.place_smoke(battle, P1, defender.cell)
	var near := _fixed(battle, UnitKind.Id.SPELLBLADE, P2, Vector2i(6, 2))
	var far := _fixed(battle, UnitKind.Id.SORCERER, P2, Vector2i(5, 4))
	far.skill_cooldown = 2  # ファイアボールは煙幕に防がれないので、ここでは数えない
	var real := _real(battle, defender, [near, far])
	assert_eq(Combat.damage(battle, far, defender), 0, "煙幕が防ぐ場面")
	assert_eq(CpuPlayer.new().danger(battle, defender.id, defender.cell), real)


func test_reads_the_real_damage_of_an_oath_pair_in_the_forest() -> void:
	# 誓いの 2 人が同じ敵を攻撃すると、2 人目が伸びる。守る側は森。
	var rows: Array[String] = ["........", "........", "...F....", "........", "........"]
	var battle := Maps.battle(rows)
	battle.traits = [Traits.NONE, Traits.Id.OATH]
	var defender := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(3, 2))
	var first := _fixed(battle, UnitKind.Id.PALADIN, P2, Vector2i(4, 2))
	var second := _fixed(battle, UnitKind.Id.SORCERER, P2, Vector2i(3, 4))
	Traits.bind(first, second)
	var real := _real(battle, defender, [first, second])
	assert_true(real > Combat.damage(battle, first, defender) + Combat.damage(battle, second, defender), "誓いが効く場面")
	assert_eq(CpuPlayer.new().danger(battle, defender.id, defender.cell), real)


func test_guard_does_not_soften_skill_damage() -> void:
	# 守護・隊列・森は駒の攻撃にだけ掛かる。ファイアボールの量はそのまま（Hit.resolve）。
	var rows: Array[String] = ["................", "................", "F...............", "................", "................"]
	var battle := Maps.battle(rows)
	battle.traits = [Traits.Id.GUARD, Traits.NONE]
	var defender := battle.add_unit(UnitKind.Id.COMMANDO, P1, HERE)
	battle.add_unit(UnitKind.Id.PALADIN, P1, HERE + Vector2i(0, 1))
	battle.add_unit(UnitKind.Id.SORCERER, P2, Vector2i(7, 2))
	assert_eq(CpuPlayer.new().danger(battle, defender.id, HERE), FireballSkill.DAMAGE)
