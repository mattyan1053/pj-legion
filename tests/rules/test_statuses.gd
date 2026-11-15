extends "res://tests/base_test.gd"
## 駒に付く状態（docs/unit-statuses.md）と、ダメージの解決への割り込み（docs/combat.md の「ダメージの解決」）。
## バリアと照準を、スキルを通さずに直に付けて確かめる。スキルごとの決まりは tests/rules/skills/。

const Maps := preload("res://tests/support/maps.gd")

const P1 := Unit.Side.PLAYER1
const P2 := Unit.Side.PLAYER2
const NEUTRAL := Unit.Side.NEUTRAL
const BARRIER := Status.Type.BARRIER
const AIM := Status.Type.AIM


func _open() -> Battle:
	return Maps.battle(["........", "........", "........", "........"])


func _of_type(events: Array[BattleEvent], type: Script) -> Array[BattleEvent]:
	return events.filter(func(event: BattleEvent) -> bool: return event.get_script() == type)


func _end_turn(battle: Battle) -> Array[BattleEvent]:
	var events := battle.apply(EndPhaseAction.new()).events
	events.append_array(battle.apply(EndPhaseAction.new()).events)
	return events


# --- 付ける・外す・期限 ---


func test_add_and_remove_report_events() -> void:
	var battle := _open()
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(0, 0))
	var applied := Statuses.add(paladin, BARRIER, 2)
	assert_eq([applied.unit_id, applied.status, applied.turns], [paladin.id, BARRIER, 2])
	assert_true(Statuses.has(paladin, BARRIER))
	assert_false(Statuses.has(paladin, AIM))
	var removed := Statuses.remove(paladin, BARRIER, StatusRemovedEvent.Reason.EXPIRED)
	assert_eq([removed.unit_id, removed.status, removed.reason], [paladin.id, BARRIER, StatusRemovedEvent.Reason.EXPIRED])
	assert_false(Statuses.has(paladin, BARRIER))


func test_turns_count_down_at_the_owners_phase_start() -> void:
	var battle := _open()
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(0, 0))
	battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(7, 3))
	Statuses.add(paladin, BARRIER, 2)
	var events := battle.apply(EndPhaseAction.new()).events
	assert_eq(paladin.statuses[BARRIER], 2, "相手のフェーズの始めには減らない")
	assert_eq(_of_type(events, StatusRemovedEvent).size(), 0)
	battle.apply(EndPhaseAction.new())
	assert_eq(paladin.statuses[BARRIER], 1, "自分のフェーズの始めに 1 減る")
	events = _end_turn(battle)
	assert_false(Statuses.has(paladin, BARRIER), "0 になったら外れる")
	var removed := _of_type(events, StatusRemovedEvent)
	assert_eq(removed.size(), 1)
	assert_eq((removed[0] as StatusRemovedEvent).reason, StatusRemovedEvent.Reason.EXPIRED)


func test_expiry_comes_after_field_effects_and_before_cooldowns() -> void:
	var battle := _open()
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(0, 0))
	Statuses.add(paladin, BARRIER, 1)
	paladin.skill_cooldown = 1
	FieldEffects.place_smoke(battle, P1, Vector2i(4, 2)).size()
	battle.board.field_effects[0].turns_left = 1
	var events := _end_turn(battle)
	var order: Array[int] = []
	for i in events.size():
		if events[i] is FieldEffectRemovedEvent or events[i] is StatusRemovedEvent or events[i] is SkillReadyEvent:
			order.append(i)
	assert_eq(order.size(), 3)
	assert_true(events[order[0]] is FieldEffectRemovedEvent)
	assert_true(events[order[1]] is StatusRemovedEvent)
	assert_true(events[order[2]] is SkillReadyEvent)


func test_stat_bonus_lives_in_the_temporary_layer_and_leaves_with_the_status() -> void:
	var battle := _open()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	var base := sniper.attack_range()
	sniper.temporary_bonus[Unit.Stat.POWER] = -3  # ほかの一時的な補正とは混ざらない
	Statuses.add(sniper, AIM, 2)
	assert_eq(sniper.attack_range(), base + PrecisionAimSkill.RANGE_BONUS)
	assert_eq(sniper.temporary_bonus[Unit.Stat.ATTACK_RANGE], PrecisionAimSkill.RANGE_BONUS)
	Statuses.add(sniper, AIM, 2)
	assert_eq(sniper.attack_range(), base + PrecisionAimSkill.RANGE_BONUS, "付け直しても、補正は重ならない")
	Statuses.remove(sniper, AIM, StatusRemovedEvent.Reason.EXPIRED)
	assert_eq(sniper.attack_range(), base)
	assert_eq(sniper.temporary_bonus, {Unit.Stat.POWER: -3})


func test_bonus_expires_with_the_status() -> void:
	var battle := _open()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	var base := sniper.attack_range()
	Statuses.add(sniper, AIM, 1)
	_end_turn(battle)
	assert_eq(sniper.attack_range(), base)
	assert_true(sniper.temporary_bonus.is_empty())


func test_clone_copies_statuses_and_keeps_them_apart() -> void:
	var battle := _open()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(1, 0))
	Statuses.add(sniper, AIM, 2)
	Statuses.add(paladin, BARRIER, 2)
	battle.apply(MoveAction.new(sniper.id, Vector2i(0, 1)))
	var copy := battle.clone()
	var copied := copy.unit_by_id(sniper.id)
	assert_eq(copy.unit_by_id(paladin.id).statuses, paladin.statuses)
	assert_eq(copied.statuses_before_move, sniper.statuses_before_move, "動く前の状態も写す（複製の上で取り消せる）")
	assert_true(copy.apply(UndoMoveAction.new(sniper.id)).accepted)
	assert_true(Statuses.has(copied, AIM))
	assert_false(Statuses.has(sniper, AIM), "複製で戻しても、元は変わらない")
	Statuses.remove(copy.unit_by_id(paladin.id), BARRIER, StatusRemovedEvent.Reason.CONSUMED)
	assert_true(Statuses.has(paladin, BARRIER))


# --- バリア: どのダメージも 1 回だけ 0 にする ---


func test_barrier_blocks_one_attack_and_is_consumed() -> void:
	var battle := _open()
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(0, 0))
	var other := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(1, 1))
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(1, 0))
	Statuses.add(paladin, BARRIER, 2)
	assert_eq(Combat.damage(battle, commando, paladin), 0, "予測も 0")
	assert_true(Statuses.has(paladin, BARRIER), "予測では外れない")
	var events := battle.apply(AttackAction.new(commando.id, paladin.id)).events
	var damaged := events[0] as AttackDamagedEvent
	assert_eq(damaged.amount, 0)
	assert_eq(damaged.hp, paladin.max_hp())
	assert_true(damaged.is_blocked())
	assert_eq(damaged.blocked_by, BARRIER)
	var removed := events[1] as StatusRemovedEvent
	assert_eq([removed.unit_id, removed.status, removed.reason], [paladin.id, BARRIER, StatusRemovedEvent.Reason.CONSUMED])
	assert_eq(paladin.hp, paladin.max_hp())
	assert_false(Statuses.has(paladin, BARRIER))
	# 防がれても「当たった」ぶんの経験値は入る（バリアをはがす仕事をした）。
	assert_eq((_of_type(events, ExperienceGainedEvent)[0] as ExperienceGainedEvent).amount, Growth.HIT_EXPERIENCE)
	assert_true(events[-1] is UnitActedEvent)
	battle.apply(AttackAction.new(other.id, paladin.id))
	assert_eq(paladin.hp, paladin.max_hp() - other.power(), "2 回目は通る")


func test_barrier_survives_an_attack_stopped_by_smoke() -> void:
	var battle := _open()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(3, 0))
	Statuses.add(paladin, BARRIER, 2)
	FieldEffects.place_smoke(battle, P2, paladin.cell)
	var events := battle.apply(AttackAction.new(sniper.id, paladin.id)).events
	assert_true(events[0] is SmokeBlockedEvent)
	assert_true(Statuses.has(paladin, BARRIER), "煙幕が先に阻む。バリアは残る")


func test_barrier_blocks_a_neutral_attack() -> void:
	var battle := Maps.battle(["....", ".*..", "...."])
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(2, 1))
	var minion := battle.add_unit(UnitKind.Id.MINION, NEUTRAL, Vector2i(1, 1))
	minion.home_cell = Vector2i(1, 1)
	Statuses.add(paladin, BARRIER, 2)
	var events := _end_turn(battle)
	var hits := _of_type(events, AttackDamagedEvent)
	assert_eq(hits.size(), 1)
	assert_true((hits[0] as AttackDamagedEvent).is_blocked())
	assert_eq(paladin.hp, paladin.max_hp())
	assert_false(Statuses.has(paladin, BARRIER))


func test_barrier_blocks_a_barrel_blast() -> void:
	var battle := Maps.battle([".....", "..B..", "....."])
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 1))
	var shielded := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(3, 0))
	var bare := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(3, 2))
	Statuses.add(shielded, BARRIER, 2)
	assert_eq(MapObject.blast_damage(shielded), 0, "予測も 0")
	assert_eq(MapObject.blast_damage(bare), MapObject.BLAST_DAMAGE)
	var events := battle.apply(AttackBarrelAction.new(sniper.id, Vector2i(2, 1))).events
	assert_true(events[0] is BarrelExplodedEvent)
	# 全員のダメージが続いたあとに、バリアが外れる。
	assert_true(events[1] is ExplosionDamagedEvent and events[2] is ExplosionDamagedEvent)
	assert_true((events[1] as ExplosionDamagedEvent).is_blocked())
	assert_false((events[2] as ExplosionDamagedEvent).is_blocked())
	assert_true(events[3] is StatusRemovedEvent)
	assert_eq(shielded.hp, shielded.max_hp())
	assert_eq(bare.hp, bare.max_hp() - MapObject.BLAST_DAMAGE)
	assert_false(Statuses.has(shielded, BARRIER))


func test_barrier_blocks_skill_damage() -> void:
	var battle := _open()
	var sorcerer := battle.add_unit(UnitKind.Id.SORCERER, P1, Vector2i(0, 0))
	var shielded := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(2, 0))
	var bare := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(3, 0))
	Statuses.add(shielded, BARRIER, 2)
	var forecast := Skills.preview(battle, sorcerer.id, Vector2i(2, 0))
	assert_true(Statuses.has(shielded, BARRIER), "予測では外れない")
	var events := battle.apply(UseSkillAction.new(sorcerer.id, Vector2i(2, 0))).events
	assert_eq(forecast.size(), events.size(), "予測と実際が同じ")
	var damaged := _of_type(events, SkillDamagedEvent)
	assert_eq(damaged.size(), 2)
	assert_true((damaged[0] as SkillDamagedEvent).is_blocked())
	assert_eq((damaged[0] as SkillDamagedEvent).amount, 0)
	assert_eq((damaged[1] as SkillDamagedEvent).amount, FireballSkill.DAMAGE)
	assert_true(events[events.find(damaged[1]) + 1] is StatusRemovedEvent, "全員のダメージのあとに外れる")
	assert_eq(shielded.hp, shielded.max_hp())
	assert_eq(bare.hp, bare.max_hp() - FireballSkill.DAMAGE)
	assert_false(Statuses.has(shielded, BARRIER))


func test_barrier_saves_a_king_from_a_lethal_blow() -> void:
	var battle := _open()
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(0, 0))
	var king := battle.add_unit(UnitKind.Id.KING, P2, Vector2i(1, 0))
	king.hp = 1
	Statuses.add(king, BARRIER, 2)
	var events := battle.apply(AttackAction.new(commando.id, king.id)).events
	assert_eq(_of_type(events, UnitDefeatedEvent).size(), 0)
	assert_false(battle.is_over())


# --- 照準: 射程が伸び、次の攻撃 1 回が確定クリティカル ---


func test_aimed_attack_is_critical_and_consumes_the_aim() -> void:
	var battle := Maps.battle(["........F"])
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(6, 0))
	Statuses.add(sniper, AIM, 2)
	var doubled := sniper.power() * PrecisionAimSkill.CRITICAL_PERCENT / 100
	assert_eq(Combat.attack_power(sniper), doubled)
	assert_eq(Combat.damage(battle, sniper, paladin), doubled, "予測もクリティカル")
	assert_true(Combat.hit(battle, sniper, paladin).critical)
	assert_true(Statuses.has(sniper, AIM), "予測では外れない")
	var events := battle.apply(AttackAction.new(sniper.id, paladin.id)).events
	var damaged := events[0] as AttackDamagedEvent
	assert_true(damaged.critical)
	assert_eq(damaged.amount, doubled)
	assert_eq(paladin.hp, paladin.max_hp() - doubled)
	var removed := events[1] as StatusRemovedEvent
	assert_eq([removed.unit_id, removed.status, removed.reason], [sniper.id, AIM, StatusRemovedEvent.Reason.CONSUMED])
	assert_eq(sniper.attack_range(), UnitKind.attack_range(UnitKind.Id.SNIPER), "射程も戻る")
	assert_eq(Combat.attack_power(sniper), sniper.power())


func test_forest_cut_comes_after_the_critical() -> void:
	var battle := Maps.battle(["...F"])
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(3, 0))
	sniper.add_growth(Unit.Stat.POWER, 4)  # 11 → 22 → 17（先に森なら 8 → 16）
	Statuses.add(sniper, AIM, 2)
	assert_eq(Combat.damage(battle, sniper, paladin), 17)


func test_critical_against_a_barrier_is_blocked_and_both_are_consumed() -> void:
	var battle := _open()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(5, 0))
	Statuses.add(sniper, AIM, 2)
	Statuses.add(paladin, BARRIER, 2)
	var events := battle.apply(AttackAction.new(sniper.id, paladin.id)).events
	assert_eq((events[0] as AttackDamagedEvent).amount, 0)
	assert_eq((events[1] as StatusRemovedEvent).status, BARRIER)
	assert_eq((events[2] as StatusRemovedEvent).status, AIM)
	assert_eq(paladin.hp, paladin.max_hp())
	assert_false(Statuses.has(sniper, AIM) or Statuses.has(paladin, BARRIER))


func test_aim_is_consumed_by_a_smoked_attack_a_barrel_and_a_barricade() -> void:
	var battle := Maps.battle(["......B.", "........", "........", "........"])
	var smoked := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	var at_barrel := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(1, 0))
	var at_wall := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 3))
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(5, 2))
	FieldEffects.place_smoke(battle, P2, paladin.cell)
	FieldEffects.place_barricade(battle, P2, Vector2i(7, 3))
	for sniper: Unit in [smoked, at_barrel, at_wall]:
		Statuses.add(sniper, AIM, 2)
	battle.apply(AttackAction.new(smoked.id, paladin.id))
	assert_false(Statuses.has(smoked, AIM), "煙幕に阻まれても、攻撃はした")
	assert_true(battle.can_apply(AttackBarrelAction.new(at_barrel.id, Vector2i(6, 0))), "伸びた射程で樽に届く")
	battle.apply(AttackBarrelAction.new(at_barrel.id, Vector2i(6, 0)))
	assert_false(Statuses.has(at_barrel, AIM))
	var barricade := battle.board.barricade_at(Vector2i(7, 3))
	assert_eq(FieldEffects.barricade_damage(at_wall), at_wall.power() * PrecisionAimSkill.CRITICAL_PERCENT / 100)
	battle.apply(AttackBarricadeAction.new(at_wall.id, Vector2i(7, 3)))
	assert_eq(barricade.durability, FieldEffects.BARRICADE_DURABILITY - 2 * at_wall.power(), "盾にもクリティカル")
	assert_false(Statuses.has(at_wall, AIM))


func test_moving_breaks_the_aim_and_undo_brings_it_back() -> void:
	var battle := _open()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	Statuses.add(sniper, AIM, 2)
	var extended := sniper.attack_range()
	assert_eq(Statuses.stat_after_move(sniper, Unit.Stat.ATTACK_RANGE), extended - PrecisionAimSkill.RANGE_BONUS)
	assert_eq(sniper.attack_range(), extended, "問い合わせでは変わらない")
	var events := battle.apply(MoveAction.new(sniper.id, Vector2i(1, 0))).events
	assert_true(events[0] is UnitMovedEvent)
	var removed := events[1] as StatusRemovedEvent
	assert_eq([removed.status, removed.reason], [AIM, StatusRemovedEvent.Reason.MOVED])
	assert_false(Statuses.has(sniper, AIM))
	assert_eq(sniper.attack_range(), extended - PrecisionAimSkill.RANGE_BONUS)
	events = battle.apply(UndoMoveAction.new(sniper.id)).events
	var back := events[1] as StatusAppliedEvent
	assert_eq([back.status, back.turns], [AIM, 2])
	assert_eq(sniper.attack_range(), extended)


func test_a_move_to_the_own_cell_keeps_the_aim() -> void:
	var battle := _open()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(6, 0))
	Statuses.add(sniper, AIM, 2)
	battle.apply(MoveAction.new(sniper.id, sniper.cell))
	assert_true(Statuses.has(sniper, AIM))
	assert_true(battle.can_apply(AttackAction.new(sniper.id, paladin.id)))


func test_options_follow_the_aim() -> void:
	var battle := _open()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(7, 0))
	assert_false(battle.options(sniper.id).attack_target_ids.has(paladin.id))
	Statuses.add(sniper, AIM, 2)
	assert_true(battle.options(sniper.id).attack_target_ids.has(paladin.id), "伸びた射程で届く")
	battle.apply(MoveAction.new(sniper.id, Vector2i(1, 0)))
	assert_false(battle.options(sniper.id).attack_target_ids.has(paladin.id), "動いたら、もとの射程")
