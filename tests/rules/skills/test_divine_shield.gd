extends "res://tests/base_test.gd"
## ディバインシールド（docs/skills/divine-shield.md）。バリアそのものの決まりは tests/rules/test_statuses.gd。

const Maps := preload("res://tests/support/maps.gd")

const P1 := Unit.Side.PLAYER1
const P2 := Unit.Side.PLAYER2
const BARRIER := Status.Type.BARRIER

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


## いまのフェーズを、CPU に最後まで進めさせる。受け付けたスキルの行動を返す。
func _skill_uses_in_phase(battle: Battle) -> Array[UseSkillAction]:
	var cpu := CpuPlayer.new()
	var result: Array[UseSkillAction] = []
	var phase := battle.phase
	var count := 0
	while not battle.is_over() and battle.phase == phase and count < 200:
		var action := cpu.next_action(battle)
		assert_true(action != null and battle.apply(action).accepted, "CPU の行動が断られた")
		if action is UseSkillAction:
			result.append(action)
		count += 1
	return result


func _end_turn(battle: Battle) -> void:
	battle.apply(EndPhaseAction.new())
	battle.apply(EndPhaseAction.new())


func test_paladin_has_it() -> void:
	var skill := Skills.of_kind(UnitKind.Id.PALADIN)
	assert_eq(skill.id(), Skill.Id.DIVINE_SHIELD)
	assert_eq(skill.cooldown(), DivineShieldSkill.COOLDOWN)


func test_the_only_target_is_the_own_cell() -> void:
	var battle := Maps.battle(["....", "...."])
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(1, 0))
	assert_eq(battle.options(paladin.id).skill_cells, [paladin.cell] as Array[Vector2i])
	assert_false(battle.can_apply(UseSkillAction.new(paladin.id, Vector2i(2, 0))))
	battle.apply(MoveAction.new(paladin.id, Vector2i(2, 1)))
	assert_eq(battle.options(paladin.id).skill_cells, [Vector2i(2, 1)] as Array[Vector2i], "動いたあとは、動いた先")
	assert_eq(Skills.of(paladin).affected_cells(battle, paladin, paladin.cell), [paladin.cell] as Array[Vector2i])


func test_gives_a_barrier_and_ends_the_action() -> void:
	var battle := Maps.battle(["....", "...."])
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(1, 0))
	var events := battle.apply(UseSkillAction.new(paladin.id, paladin.cell)).events
	assert_true(events[0] is SkillUsedEvent)
	var applied := events[1] as StatusAppliedEvent
	assert_eq([applied.unit_id, applied.status, applied.turns], [paladin.id, BARRIER, DivineShieldSkill.BARRIER_TURNS])
	assert_true(events[2] is UnitActedEvent)
	assert_true(Statuses.has(paladin, BARRIER))
	assert_true(paladin.acted)
	assert_eq(paladin.skill_cooldown, DivineShieldSkill.COOLDOWN)


func test_blocks_the_next_hit_only() -> void:
	var battle := Maps.battle(["....", "...."])
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(1, 0))
	var first := battle.add_unit(UnitKind.Id.COMMANDO, P2, Vector2i(2, 0))
	var second := battle.add_unit(UnitKind.Id.COMMANDO, P2, Vector2i(1, 1))
	battle.apply(UseSkillAction.new(paladin.id, paladin.cell))
	battle.apply(EndPhaseAction.new())
	battle.apply(AttackAction.new(first.id, paladin.id))
	assert_eq(paladin.hp, paladin.max_hp(), "1 回目は 0")
	battle.apply(AttackAction.new(second.id, paladin.id))
	assert_eq(paladin.hp, paladin.max_hp() - second.power(), "2 回目は通る")


func test_lasts_through_two_enemy_phases_then_fades() -> void:
	var battle := Maps.battle(["....", "...."])
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(1, 0))
	battle.add_unit(UnitKind.Id.COMMANDO, P2, Vector2i(3, 1))
	battle.apply(UseSkillAction.new(paladin.id, paladin.cell))
	_end_turn(battle)
	assert_true(Statuses.has(paladin, BARRIER), "次の自分の番も残る（バリアを張ったまま前へ出られる）")
	battle.apply(EndPhaseAction.new())
	assert_true(Statuses.has(paladin, BARRIER), "2 回目の相手の番も残る")
	battle.apply(EndPhaseAction.new())
	assert_false(Statuses.has(paladin, BARRIER), "その次の自分の番の始めに消える")
	assert_true(paladin.skill_cooldown > 0, "消えてすぐには張り直せない")


func test_preview_matches_and_changes_nothing() -> void:
	var battle := Maps.battle(["....", "...."])
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(1, 0))
	var forecast := Skills.preview(battle, paladin.id, paladin.cell)
	assert_false(Statuses.has(paladin, BARRIER))
	assert_eq(paladin.skill_cooldown, 0)
	var events := battle.apply(UseSkillAction.new(paladin.id, paladin.cell)).events
	assert_eq(forecast.size(), events.size())
	assert_true(forecast[1] is StatusAppliedEvent)


func test_cpu_raises_it_when_it_will_be_shot_and_cannot_attack() -> void:
	var battle := _cpu_battle()
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(4, 2))
	battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(10, 2))
	# 前へ出たが、殴れる相手はいない。次の相手の番に、スナイパーに撃たれる。
	battle.apply(MoveAction.new(paladin.id, Vector2i(5, 2)))
	var uses := _skill_uses_in_phase(battle)
	assert_eq(uses.size(), 1, "バリアを張らなかった")
	assert_eq(uses[0].unit_id, paladin.id)
	assert_true(Statuses.has(paladin, BARRIER))


func test_cpu_attacks_instead_when_it_can() -> void:
	var battle := _cpu_battle()
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(4, 2))
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(6, 2))
	var uses := _skill_uses_in_phase(battle)
	assert_eq(uses.size(), 0)
	assert_true(sniper.hp < sniper.max_hp() and paladin.acted)


func test_cpu_does_not_raise_it_with_no_enemy_near() -> void:
	var battle := _cpu_battle()
	battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(1, 3))
	assert_eq(_skill_uses_in_phase(battle).size(), 0)


func test_cpu_strips_the_enemy_barrier_and_then_hits() -> void:
	var battle := _cpu_battle()
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(8, 2))
	Statuses.add(paladin, BARRIER, 2)
	var trooper := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(6, 2))
	battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(4, 2))
	_skill_uses_in_phase(battle)
	# 後衛が先に動いてバリアをはがし、続く前衛の攻撃が通る。
	assert_false(Statuses.has(paladin, BARRIER))
	assert_eq(paladin.hp, paladin.max_hp() - trooper.power())


func test_cpu_does_not_waste_a_hit_on_a_barrier_nobody_can_follow() -> void:
	var battle := _cpu_battle()
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(8, 2))
	Statuses.add(paladin, BARRIER, 2)
	var priest := battle.add_unit(UnitKind.Id.PRIEST, P2, Vector2i(8, 3))
	battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(5, 3))
	_skill_uses_in_phase(battle)
	# 続く味方がいないなら、バリアの無い相手を殴る。
	assert_true(Statuses.has(paladin, BARRIER))
	assert_true(priest.hp < priest.max_hp())


func test_cpu_stops_short_and_raises_it_instead_of_cruising_into_fire() -> void:
	# 巡航で寄ると、バリアを張れないまま撃たれる。通常の移動で届くマスに止まって張る手と比べる。
	var battle := _cpu_battle()
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(3, 2))
	battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(12, 2))
	var uses := _skill_uses_in_phase(battle)
	assert_eq(uses.size(), 1, "バリアを張らなかった")
	assert_true(Statuses.has(paladin, BARRIER))
	assert_ne(paladin.cell, Vector2i(3, 2), "前へ出なかった")
	assert_false(paladin.cruised)
