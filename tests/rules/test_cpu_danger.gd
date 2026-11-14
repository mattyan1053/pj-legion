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


func test_healers_and_own_units_are_no_danger() -> void:
	var battle := _battle()
	battle.add_unit(UnitKind.Id.PRIEST, P2, Vector2i(3, 2))
	battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(1, 2))
	assert_eq(_danger(battle), 0)


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


func test_danger_does_not_change_the_battle() -> void:
	var battle := _battle()
	battle.add_unit(UnitKind.Id.SORCERER, P2, Vector2i(7, 2))
	var before := battle.clone()
	_danger(battle)
	assert_eq(battle.turn, before.turn)
	assert_eq(battle.phase, before.phase)
	assert_eq(battle.units[1].skill_cooldown, before.units[1].skill_cooldown)
	assert_eq(battle.rng.state, before.rng.state)
