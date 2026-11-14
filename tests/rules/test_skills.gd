extends "res://tests/base_test.gd"
## スキルの土台（docs/active-skills.md）: 誰が・いつ使えるか、クールダウン、使ったときの流れ、選べること、複製、予測。
## スキルごとの中身は tests/rules/skills/ の下。ここでは、土台を通すのに戦術バリケードとセイントプレイスを使う。

const Maps := preload("res://tests/support/maps.gd")

const P1 := Unit.Side.PLAYER1
const P2 := Unit.Side.PLAYER2

const OPEN: Array[String] = [
	"........",
	"........",
	"........",
	"........",
	"........",
]


func _battle() -> Battle:
	return Maps.battle(OPEN)


func _event_types(events: Array[BattleEvent]) -> Array[Script]:
	var result: Array[Script] = []
	for event in events:
		result.append(event.get_script())
	return result


func _end_phase(battle: Battle) -> Array[BattleEvent]:
	var result := battle.apply(EndPhaseAction.new())
	assert_true(result.accepted, "フェーズを終えられない")
	return result.events


# --- 定義 ---


func test_every_skill_has_its_own_id_and_kind() -> void:
	var ids := {}
	var kinds := {}
	for skill in Skills.ALL:
		assert_false(ids.has(skill.id()), "番号が重なっている: %s" % skill.display_name())
		assert_false(kinds.has(skill.kind()), "1 種類の駒にスキルが 2 つある: %s" % skill.display_name())
		ids[skill.id()] = true
		kinds[skill.kind()] = true
		assert_eq(Skills.by_id(skill.id()), skill)
		assert_eq(Skills.of_kind(skill.kind()), skill)
		assert_ne(skill.display_name(), "")
		assert_ne(skill.summary(), "")
		assert_true(skill.cooldown() >= 1, "クールダウンが無い: %s" % skill.display_name())
	assert_eq(ids.size(), Skill.Id.size(), "Skills.ALL に載っていないスキルがある")


func test_king_and_neutral_units_have_no_skill() -> void:
	for kind: UnitKind.Id in [UnitKind.Id.KING, UnitKind.Id.MINION, UnitKind.Id.ELITE_MINION]:
		assert_eq(Skills.of_kind(kind), null)
	var battle := _battle()
	var king := battle.add_unit(UnitKind.Id.KING, P1, Vector2i(2, 2))
	assert_true(battle.options(king.id).skill_cells.is_empty())
	assert_false(battle.can_apply(UseSkillAction.new(king.id, Vector2i(3, 2))))
	assert_false(battle.can_apply(UseSkillAction.new(king.id, king.cell)))


# --- 使う ---


func test_using_a_skill_sets_the_cooldown_and_ends_the_action() -> void:
	var battle := _battle()
	var trooper := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(2, 2))
	var result := battle.apply(UseSkillAction.new(trooper.id, Vector2i(3, 2)))
	assert_true(result.accepted)
	assert_eq(_event_types(result.events), [SkillUsedEvent, BarricadePlacedEvent, UnitActedEvent] as Array[Script])
	var used := result.events[0] as SkillUsedEvent
	assert_eq(used.unit_id, trooper.id)
	assert_eq(used.skill, Skill.Id.TACTICAL_BARRICADE)
	assert_eq(used.target, Vector2i(3, 2))
	assert_eq(used.cooldown, TacticalBarricadeSkill.COOLDOWN)
	assert_eq(trooper.skill_cooldown, TacticalBarricadeSkill.COOLDOWN)
	assert_true(trooper.acted)
	assert_false(battle.can_apply(WaitAction.new(trooper.id)), "使ったあとは、待機も攻撃もできない")
	assert_false(battle.can_apply(UndoMoveAction.new(trooper.id)))


func test_skill_can_be_used_after_a_move_but_not_after_a_cruise() -> void:
	var battle := _battle()
	var trooper := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(0, 2))
	var other := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(0, 0))
	assert_true(battle.apply(MoveAction.new(trooper.id, Vector2i(2, 2))).accepted)
	assert_false(battle.options(trooper.id).skill_cells.is_empty())
	assert_true(battle.apply(UseSkillAction.new(trooper.id, Vector2i(3, 2))).accepted)
	assert_eq(trooper.cell, Vector2i(2, 2))
	assert_true(battle.apply(MoveAction.new(other.id, Vector2i(5, 0), true)).accepted, "巡航できない")
	assert_true(battle.options(other.id).skill_cells.is_empty())
	assert_false(battle.can_apply(UseSkillAction.new(other.id, Vector2i(6, 0))))


func test_skill_is_rejected_when_the_unit_cannot_act() -> void:
	var battle := _battle()
	var mine := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(1, 2))
	var friend := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(1, 0))
	var enemy := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P2, Vector2i(6, 2))
	assert_false(battle.can_apply(UseSkillAction.new(enemy.id, Vector2i(5, 2))), "相手の番の駒")
	assert_false(battle.can_apply(UseSkillAction.new(999, Vector2i(5, 2))), "いない駒")
	assert_false(battle.can_apply(UseSkillAction.new(mine.id, Vector2i(4, 2))), "対象に選べないマス")
	battle.apply(MoveAction.new(friend.id, Vector2i(2, 0)))
	assert_false(battle.can_apply(UseSkillAction.new(mine.id, Vector2i(2, 2))), "ほかの駒が行動の途中")
	battle.apply(WaitAction.new(friend.id))
	assert_false(battle.can_apply(UseSkillAction.new(friend.id, Vector2i(3, 0))), "行動済みの駒")
	assert_true(battle.can_apply(UseSkillAction.new(mine.id, Vector2i(2, 2))))
	battle.winner = P1
	assert_false(battle.can_apply(UseSkillAction.new(mine.id, Vector2i(2, 2))), "決着のあと")


func test_a_rejected_skill_changes_nothing() -> void:
	var battle := _battle()
	var trooper := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(2, 2))
	var result := battle.apply(UseSkillAction.new(trooper.id, Vector2i(5, 2)))
	assert_false(result.accepted)
	assert_true(result.events.is_empty())
	assert_eq(trooper.skill_cooldown, 0)
	assert_false(trooper.acted)
	assert_true(battle.board.field_effects.is_empty())


# --- クールダウン ---


func test_skill_cannot_be_used_during_the_cooldown() -> void:
	var battle := _battle()
	var trooper := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(2, 2))
	battle.apply(UseSkillAction.new(trooper.id, Vector2i(3, 2)))
	_end_phase(battle)
	_end_phase(battle)
	assert_eq(battle.turn, 2)
	assert_true(battle.can_act(trooper))
	assert_eq(trooper.skill_cooldown, TacticalBarricadeSkill.COOLDOWN - 1)
	assert_true(battle.options(trooper.id).skill_cells.is_empty())
	assert_false(battle.can_apply(UseSkillAction.new(trooper.id, Vector2i(1, 2))))
	assert_true(battle.can_apply(WaitAction.new(trooper.id)), "スキルのほかは選べる")


func test_cooldown_ticks_at_the_start_of_the_owners_phase_only() -> void:
	var battle := _battle()
	var trooper := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(2, 2))
	battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P2, Vector2i(6, 4))
	battle.apply(UseSkillAction.new(trooper.id, Vector2i(3, 2)))
	var cooldown := TacticalBarricadeSkill.COOLDOWN
	assert_eq(trooper.skill_cooldown, cooldown, "使ったフェーズの中では減らない")
	_end_phase(battle)
	assert_eq(battle.phase, P2)
	assert_eq(trooper.skill_cooldown, cooldown, "相手のフェーズの始めには減らない")
	_end_phase(battle)
	assert_eq(battle.phase, P1)
	assert_eq(trooper.skill_cooldown, cooldown - 1, "自分のフェーズの始めに 1 減る")


func test_skill_is_ready_again_after_cooldown_turns() -> void:
	var battle := _battle()
	var trooper := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(2, 2))
	battle.apply(UseSkillAction.new(trooper.id, Vector2i(3, 2)))
	var cooldown := TacticalBarricadeSkill.COOLDOWN
	for turn in range(2, 1 + cooldown):
		_end_phase(battle)
		var events := _end_phase(battle)
		assert_eq(battle.turn, turn)
		assert_false(_event_types(events).has(SkillReadyEvent), "ターン %d でもう使える" % turn)
		assert_false(battle.can_apply(UseSkillAction.new(trooper.id, Vector2i(1, 2))), "ターン %d でもう使える" % turn)
	_end_phase(battle)
	var events := _end_phase(battle)
	assert_eq(battle.turn, 1 + cooldown, "使ったターンの COOLDOWN ターン後")
	assert_eq(trooper.skill_cooldown, 0)
	var ready := events[-1] as SkillReadyEvent
	assert_true(ready != null, "フェーズの始めの最後に SkillReadyEvent")
	assert_eq(ready.unit_id, trooper.id)
	assert_eq(ready.skill, Skill.Id.TACTICAL_BARRICADE)
	assert_true(battle.can_apply(UseSkillAction.new(trooper.id, Vector2i(1, 2))))
	_end_phase(battle)
	events = _end_phase(battle)
	assert_eq(trooper.skill_cooldown, 0, "0 より下がらない")
	assert_false(_event_types(events).has(SkillReadyEvent), "明けたあとは、もう知らせない")


# --- 選べること ---


func test_options_list_exactly_the_cells_the_rules_accept() -> void:
	var battle := Maps.battle([
		"........",
		"..#.B...",
		"........",
		"........",
	])
	var trooper := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(3, 2))
	var priest := battle.add_unit(UnitKind.Id.PRIEST, P1, Vector2i(6, 1))
	battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(4, 3))
	for unit: Unit in [trooper, priest]:
		var options := battle.options(unit.id)
		assert_false(options.skill_cells.is_empty())
		for y in battle.board.size.y:
			for x in battle.board.size.x:
				var cell := Vector2i(x, y)
				assert_eq(
					options.skill_cells.has(cell), battle.can_apply(UseSkillAction.new(unit.id, cell)),
					"%s %s" % [unit.display_name(), cell]
				)
		var sorted := options.skill_cells.duplicate()
		sorted.sort_custom(Board.in_reading_order)
		assert_eq(options.skill_cells, sorted, "上の行から、左の列から")
		var listed: Array[Vector2i] = []
		for action in options.actions():
			var use := action as UseSkillAction
			if use != null:
				assert_eq(use.unit_id, unit.id)
				listed.append(use.target)
				assert_true(battle.can_apply(action))
		assert_eq(listed, options.skill_cells, "actions() に、対象のマスごとに 1 つ")


func test_skill_actions_come_after_heals_and_before_wait() -> void:
	var battle := _battle()
	var priest := battle.add_unit(UnitKind.Id.PRIEST, P1, Vector2i(2, 2))
	var wounded := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(3, 2))
	wounded.hp -= 5
	battle.apply(MoveAction.new(priest.id, priest.cell))
	var actions := battle.options(priest.id).actions()
	assert_true(actions[0] is HealAction)
	assert_true(actions[1] is UseSkillAction)
	assert_true(actions[-2] is WaitAction)
	assert_true(actions[-1] is UndoMoveAction)


# --- 複製と予測 ---


func test_clone_keeps_the_cooldown_and_stays_separate() -> void:
	var battle := _battle()
	var trooper := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(2, 2))
	var other := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(5, 2))
	battle.apply(UseSkillAction.new(trooper.id, Vector2i(3, 2)))
	var copy := battle.clone()
	assert_eq(copy.unit_by_id(trooper.id).skill_cooldown, TacticalBarricadeSkill.COOLDOWN)
	assert_true(copy.apply(UseSkillAction.new(other.id, Vector2i(6, 2))).accepted)
	assert_eq(other.skill_cooldown, 0, "元は変わらない")
	assert_false(other.acted)
	assert_eq(battle.board.field_effects.size(), 1)
	assert_eq(copy.board.field_effects.size(), 2)


func test_preview_returns_what_would_happen_without_changing_the_battle() -> void:
	var battle := _battle()
	var priest := battle.add_unit(UnitKind.Id.PRIEST, P1, Vector2i(2, 2))
	var rng_state := battle.rng.state
	var events := Skills.preview(battle, priest.id, Vector2i(3, 2))
	assert_eq(_event_types(events), [SkillUsedEvent, AreaEffectPlacedEvent, UnitActedEvent] as Array[Script])
	assert_true(battle.board.field_effects.is_empty())
	assert_eq(priest.skill_cooldown, 0)
	assert_false(priest.acted)
	assert_eq(battle.rng.state, rng_state)
	var real := battle.apply(UseSkillAction.new(priest.id, Vector2i(3, 2))).events
	assert_eq(_event_types(real), _event_types(events), "実際に使った結果と同じ")
	assert_eq((real[1] as AreaEffectPlacedEvent).cells, (events[1] as AreaEffectPlacedEvent).cells)
	assert_true(Skills.preview(battle, priest.id, Vector2i(3, 2)).is_empty(), "使えなければ空")
