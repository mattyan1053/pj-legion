extends "res://tests/base_test.gd"
## アドレナリン注射（docs/skills/adrenaline-shot.md）。回数の上限と、反動の決まりもここ。

const Maps := preload("res://tests/support/maps.gd")

const P1 := Unit.Side.PLAYER1
const P2 := Unit.Side.PLAYER2
const FATIGUE := Status.Type.FATIGUE
const PENALTY := AdrenalineShotSkill.POWER_PENALTY

const ROWS: Array[String] = [
	"..........",
	"..........",
	"..........",
]


func _battle() -> Battle:
	return Maps.battle(ROWS)


func _end_turn(battle: Battle) -> void:
	battle.apply(EndPhaseAction.new())
	battle.apply(EndPhaseAction.new())


func test_medic_has_it() -> void:
	var skill := Skills.of_kind(UnitKind.Id.MEDIC)
	assert_eq(skill.id(), Skill.Id.ADRENALINE_SHOT)
	assert_eq(skill.cooldown(), AdrenalineShotSkill.COOLDOWN)
	assert_eq(skill.max_uses(), AdrenalineShotSkill.MAX_USES)
	assert_true(skill.ends_action())


func test_targets_are_acted_friends_in_heal_range() -> void:
	var battle := _battle()
	var medic := battle.add_unit(UnitKind.Id.MEDIC, P1, Vector2i(2, 1))
	var near := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(3, 1))
	var fresh := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(1, 1))
	var far := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(4, 1))
	battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(2, 0))
	assert_true(battle.options(medic.id).skill_cells.is_empty(), "行動済みの味方がいない")
	battle.apply(WaitAction.new(near.id))
	battle.apply(WaitAction.new(far.id))
	assert_eq(battle.options(medic.id).skill_cells, [near.cell] as Array[Vector2i])
	assert_false(battle.can_apply(UseSkillAction.new(medic.id, fresh.cell)), "未行動の味方")
	assert_false(battle.can_apply(UseSkillAction.new(medic.id, far.cell)), "射程の外")
	assert_false(battle.can_apply(UseSkillAction.new(medic.id, medic.cell)), "自分")
	assert_false(battle.can_apply(UseSkillAction.new(medic.id, Vector2i(2, 0))), "敵")


func test_shot_lets_the_friend_act_again_in_the_same_phase() -> void:
	var battle := _battle()
	var medic := battle.add_unit(UnitKind.Id.MEDIC, P1, Vector2i(0, 1))
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(1, 1))
	var enemy := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(4, 1))
	var base := commando.power()
	battle.apply(MoveAction.new(commando.id, Vector2i(3, 1)))
	battle.apply(AttackAction.new(commando.id, enemy.id))
	battle.apply(MoveAction.new(medic.id, Vector2i(2, 1)))
	var events := battle.apply(UseSkillAction.new(medic.id, commando.cell)).events
	assert_true(events[0] is SkillUsedEvent)
	assert_eq((events[1] as UnitReactivatedEvent).unit_id, commando.id)
	var applied := events[2] as StatusAppliedEvent
	assert_eq([applied.unit_id, applied.status, applied.turns], [commando.id, FATIGUE, AdrenalineShotSkill.FATIGUE_TURNS])
	assert_eq((events[3] as UnitActedEvent).unit_id, medic.id)
	assert_true(medic.acted)
	assert_false(commando.acted)
	assert_eq(commando.power(), base - PENALTY, "もう一度の行動から、攻撃力が下がる")
	assert_eq(commando.base_stat(Unit.Stat.POWER), base, "もとの値は書き換えない")
	# 移動からやり直せる。
	assert_true(battle.apply(MoveAction.new(commando.id, Vector2i(3, 0))).accepted)
	assert_false(battle.apply(MoveAction.new(commando.id, Vector2i(3, 0))).accepted, "移動は 1 回")
	battle.apply(UndoMoveAction.new(commando.id))
	assert_true(battle.apply(AttackAction.new(commando.id, enemy.id)).accepted)
	assert_eq(enemy.hp, enemy.max_hp() - base - (base - PENALTY))
	assert_true(commando.acted)


func test_fatigue_lasts_through_the_next_own_turn() -> void:
	var battle := _battle()
	var medic := battle.add_unit(UnitKind.Id.MEDIC, P1, Vector2i(0, 1))
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(1, 1))
	var base := commando.power()
	battle.apply(WaitAction.new(commando.id))
	battle.apply(UseSkillAction.new(medic.id, commando.cell))
	_end_turn(battle)
	assert_eq(commando.power(), base - PENALTY, "次の自分の番の間も、下がったまま")
	battle.apply(EndPhaseAction.new())
	assert_eq(commando.power(), base - PENALTY, "続く相手の番の間も残る")
	var events := battle.apply(EndPhaseAction.new()).events
	var removed: Array[BattleEvent] = events.filter(func(event: BattleEvent) -> bool: return event is StatusRemovedEvent)
	assert_eq((removed[0] as StatusRemovedEvent).reason, StatusRemovedEvent.Reason.EXPIRED)
	assert_false(Statuses.has(commando, FATIGUE))
	assert_eq(commando.power(), base)


func test_fatigue_never_drops_the_power_below_zero() -> void:
	var battle := _battle()
	var core := battle.add_unit(UnitKind.Id.MINION, P1, Vector2i(0, 0))
	core.growth_bonus[Unit.Stat.POWER] = -(core.power() - 1)
	Statuses.add(core, FATIGUE, 1)
	assert_eq(core.power(), 0)


func test_a_second_shot_renews_the_fatigue_without_stacking() -> void:
	var battle := _battle()
	var medic := battle.add_unit(UnitKind.Id.MEDIC, P1, Vector2i(0, 1))
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(1, 1))
	var base := commando.power()
	Statuses.add(commando, FATIGUE, 1)
	battle.apply(WaitAction.new(commando.id))
	battle.apply(UseSkillAction.new(medic.id, commando.cell))
	assert_eq(commando.statuses[FATIGUE], AdrenalineShotSkill.FATIGUE_TURNS, "残りのターン数を付け直す")
	assert_eq(commando.power(), base - PENALTY, "下がる量は重ならない")


func test_uses_are_limited_per_medic() -> void:
	var battle := _battle()
	var medic := battle.add_unit(UnitKind.Id.MEDIC, P1, Vector2i(0, 1))
	var other := battle.add_unit(UnitKind.Id.MEDIC, P1, Vector2i(2, 1))
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(1, 1))
	assert_eq(Skills.uses_left(medic), AdrenalineShotSkill.MAX_USES)
	assert_eq(Skills.uses_left(commando), -1, "回数に上限の無いスキル")
	for i in AdrenalineShotSkill.MAX_USES:
		battle.apply(WaitAction.new(commando.id))
		assert_true(battle.apply(UseSkillAction.new(medic.id, commando.cell)).accepted)
		assert_eq(Skills.uses_left(medic), AdrenalineShotSkill.MAX_USES - i - 1)
		for turn in AdrenalineShotSkill.COOLDOWN:
			_end_turn(battle)
	assert_eq(medic.skill_cooldown, 0)
	battle.apply(WaitAction.new(commando.id))
	assert_false(battle.can_apply(UseSkillAction.new(medic.id, commando.cell)), "使い切った")
	assert_true(battle.options(medic.id).skill_cells.is_empty())
	assert_true(battle.can_apply(UseSkillAction.new(other.id, commando.cell)), "回数は、衛生兵ごとに数える")
	assert_eq(battle.clone().unit_by_id(medic.id).skill_uses, AdrenalineShotSkill.MAX_USES)


func test_no_ready_event_once_the_uses_run_out() -> void:
	var battle := _battle()
	var medic := battle.add_unit(UnitKind.Id.MEDIC, P1, Vector2i(0, 1))
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(1, 1))
	medic.skill_uses = AdrenalineShotSkill.MAX_USES - 1
	battle.apply(WaitAction.new(commando.id))
	battle.apply(UseSkillAction.new(medic.id, commando.cell))
	for turn in AdrenalineShotSkill.COOLDOWN:
		battle.apply(EndPhaseAction.new())
		var events := battle.apply(EndPhaseAction.new()).events
		assert_false(events.any(func(event: BattleEvent) -> bool: return event is SkillReadyEvent))
	assert_eq(medic.skill_cooldown, 0)


func test_the_same_medic_cannot_be_looped_within_a_phase() -> void:
	# 衛生兵 2 体が互いに打ち合っても、クールダウンがあるので、同じ衛生兵は 1 フェーズに 1 回しか打てない。
	var battle := _battle()
	var first := battle.add_unit(UnitKind.Id.MEDIC, P1, Vector2i(0, 1))
	var second := battle.add_unit(UnitKind.Id.MEDIC, P1, Vector2i(1, 1))
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(0, 0))
	battle.apply(WaitAction.new(commando.id))
	battle.apply(UseSkillAction.new(first.id, commando.cell))
	battle.apply(UseSkillAction.new(second.id, first.cell))
	assert_false(first.acted)
	assert_true(battle.options(first.id).skill_cells.is_empty(), "クールダウンが残っている")


func test_shot_restores_a_healer_and_cuts_its_heal_next_turn() -> void:
	var battle := _battle()
	var medic := battle.add_unit(UnitKind.Id.MEDIC, P1, Vector2i(0, 1))
	var other := battle.add_unit(UnitKind.Id.MEDIC, P1, Vector2i(1, 1))
	var base := other.power()
	battle.apply(WaitAction.new(other.id))
	battle.apply(UseSkillAction.new(medic.id, other.cell))
	assert_eq(other.power(), base - PENALTY, "回復役は、回復量が下がる")


func test_preview_and_options_match_the_rules() -> void:
	var battle := _battle()
	var medic := battle.add_unit(UnitKind.Id.MEDIC, P1, Vector2i(1, 1))
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(1, 0))
	battle.apply(WaitAction.new(commando.id))
	var events := Skills.preview(battle, medic.id, commando.cell)
	assert_true(events[1] is UnitReactivatedEvent)
	assert_true(commando.acted, "予測は状態を変えない")
	assert_eq(medic.skill_uses, 0)
	var listed := battle.options(medic.id).skill_cells
	for y in battle.board.size.y:
		for x in battle.board.size.x:
			var cell := Vector2i(x, y)
			assert_eq(battle.can_apply(UseSkillAction.new(medic.id, cell)), listed.has(cell), str(cell))


# ---- CPU ----


func _cpu_battle() -> Battle:
	var battle := Maps.battle([
		"................",
		"................",
		"................",
		"................",
		"................",
	])
	battle.board.hq_cells = [Vector2i(0, 4), Vector2i(15, 0)]
	battle.add_unit(UnitKind.Id.KING, P1, Vector2i(0, 4))
	battle.add_unit(UnitKind.Id.KING, P2, Vector2i(15, 0))
	return battle


func _play_phase(battle: Battle) -> Array[BattleAction]:
	var cpu := CpuPlayer.new()
	var result: Array[BattleAction] = []
	var phase := battle.phase
	while not battle.is_over() and battle.phase == phase and result.size() < 200:
		var action := cpu.next_action(battle)
		assert_true(action != null and battle.apply(action).accepted, "CPU の行動が断られた")
		result.append(action)
	return result


func _skill_uses(actions: Array[BattleAction]) -> Array[BattleAction]:
	return actions.filter(func(action: BattleAction) -> bool: return action is UseSkillAction)


func test_cpu_shoots_a_friend_who_can_finish_an_enemy() -> void:
	# スナイパーが 1 発撃ったあと。もう 1 発で倒せる敵が、射程の中に残っている。
	var battle := _cpu_battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(5, 2))
	var medic := battle.add_unit(UnitKind.Id.MEDIC, P1, Vector2i(4, 2))
	var enemy := battle.add_unit(UnitKind.Id.SORCERER, P2, Vector2i(9, 2))
	enemy.hp = sniper.power() + 1
	var actions := _play_phase(battle)
	var used := _skill_uses(actions)
	assert_eq(used.size(), 1, "打たなかった")
	assert_eq((used[0] as UseSkillAction).unit_id, medic.id)
	assert_eq(battle.unit_by_id(enemy.id), null, "もう 1 発で倒す")
	assert_eq(medic.skill_uses, 1)


func test_cpu_keeps_the_shot_when_the_second_action_gains_little() -> void:
	var battle := _cpu_battle()
	battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(5, 2))
	battle.add_unit(UnitKind.Id.MEDIC, P1, Vector2i(4, 2))
	battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(9, 2))
	assert_true(_skill_uses(_play_phase(battle)).is_empty(), "倒せもしない相手に、回数を使った")
