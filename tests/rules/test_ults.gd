extends "res://tests/base_test.gd"
## 必殺技（docs/tactical-ult.md）。ゲージ、使えるとき、2 つの必殺技の効果。

const Maps := preload("res://tests/support/maps.gd")

const P1 := Unit.Side.PLAYER1
const P2 := Unit.Side.PLAYER2
const NEUTRAL := Unit.Side.NEUTRAL
const MAX := Ults.GAUGE_MAX
const ASSAULT := Status.Type.ASSAULT

const ROWS: Array[String] = [
	"..........",
	"....F.....",
	"..........",
]


func _battle() -> Battle:
	return Maps.battle(ROWS)


## MILITARY（P1）と FANTASY（P2）が 1 体ずつ向かい合う対戦。
func _duel() -> Battle:
	var battle := _battle()
	battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(0, 0))
	battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(9, 0))
	return battle


func _fill(battle: Battle, side: Unit.Side) -> void:
	battle.ult_gauge[side] = MAX


func _end_turn(battle: Battle) -> void:
	battle.apply(EndPhaseAction.new())
	battle.apply(EndPhaseAction.new())


# ---- 軍とゲージ ----


func test_each_army_has_one_ult() -> void:
	assert_eq(Ults.of_army(UnitKind.Army.MILITARY).id(), Ult.Id.ALL_OUT_ASSAULT)
	assert_eq(Ults.of_army(UnitKind.Army.FANTASY).id(), Ult.Id.MANA_ERUPTION)
	assert_true(Ults.of_army(UnitKind.Army.NONE) == null)
	for ult in Ults.ALL:
		assert_eq(Ults.by_id(ult.id()), ult)
		assert_true(ult.display_name() != "" and ult.summary() != "")


func test_army_comes_from_the_first_hired_unit() -> void:
	var battle := _battle()
	battle.add_unit(UnitKind.Id.KING, P1, Vector2i(0, 0))
	assert_true(Ults.of(battle, P1) == null, "将だけでは軍が決まらない")
	battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(1, 0))
	battle.add_unit(UnitKind.Id.PRIEST, P2, Vector2i(9, 0))
	battle.add_unit(UnitKind.Id.MINION, NEUTRAL, Vector2i(5, 2))
	assert_eq(battle.armies, [UnitKind.Army.MILITARY, UnitKind.Army.FANTASY] as Array[UnitKind.Army])
	assert_eq(Ults.of(battle, P1).id(), Ult.Id.ALL_OUT_ASSAULT)
	assert_eq(Ults.of(battle, P2).id(), Ult.Id.MANA_ERUPTION)
	assert_true(Ults.of(battle, NEUTRAL) == null)


func test_deployment_sets_the_army_of_the_deck() -> void:
	var board := Maps.board(["......", "......", "......", "......", "......", "......"])
	board.hq_cells = [Vector2i(2, 5), Vector2i(2, 0)]
	var battle := Battle.new(board)
	var deck := Deck.new(UnitKind.Army.FANTASY)
	deck.add(UnitKind.Id.SORCERER)
	Deployment.deploy(battle, P2, deck)
	assert_eq(battle.armies[P2], UnitKind.Army.FANTASY)
	assert_eq(battle.armies[P1], UnitKind.Army.NONE)


func test_gauge_starts_empty() -> void:
	var battle := _duel()
	assert_eq(battle.ult_gauge, [0, 0] as Array[int])
	assert_eq(Ults.percent(battle, P1), 0)
	assert_eq(Ults.gauge(battle, NEUTRAL), 0)
	assert_false(Ults.can_use(battle))


func test_own_phase_start_charges() -> void:
	var battle := _duel()
	battle.apply(EndPhaseAction.new())
	assert_eq(battle.ult_gauge, [0, Ults.PHASE_GAIN] as Array[int], "プレイヤー2 のフェーズの始め")
	battle.apply(EndPhaseAction.new())
	assert_eq(battle.ult_gauge, [Ults.PHASE_GAIN, Ults.PHASE_GAIN] as Array[int])


func test_damage_charges_both_sides() -> void:
	var battle := _battle()
	var trooper := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(3, 0))
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(4, 0))
	battle.apply(AttackAction.new(trooper.id, paladin.id))
	var dealt := trooper.power()
	assert_eq(battle.ult_gauge, [dealt * Ults.DEALT_GAIN, dealt * Ults.TAKEN_GAIN] as Array[int])
	assert_true(Ults.TAKEN_GAIN > Ults.DEALT_GAIN, "受けた側のほうが多くたまる")


func test_forest_reduced_damage_charges_by_the_reduced_amount() -> void:
	var battle := _battle()
	var trooper := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(3, 1))
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(4, 1))
	battle.apply(AttackAction.new(trooper.id, paladin.id))
	var lost := paladin.max_hp() - paladin.hp
	assert_true(lost < trooper.power())
	assert_eq(battle.ult_gauge[P1], lost * Ults.DEALT_GAIN)
	assert_eq(battle.ult_gauge[P2], lost * Ults.TAKEN_GAIN)


func test_overkill_charges_only_the_hp_lost_and_defeat_charges_the_owner() -> void:
	var battle := _battle()
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(3, 0))
	battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(9, 2))
	var sorcerer := battle.add_unit(UnitKind.Id.SORCERER, P2, Vector2i(4, 0))
	sorcerer.hp = 3
	battle.apply(AttackAction.new(commando.id, sorcerer.id))
	assert_eq(battle.ult_gauge[P1], 3 * Ults.DEALT_GAIN)
	assert_eq(battle.ult_gauge[P2], 3 * Ults.TAKEN_GAIN + Ults.DEFEAT_GAIN)


func test_blocked_damage_does_not_charge() -> void:
	var battle := _battle()
	var trooper := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(3, 0))
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(4, 0))
	Statuses.add(paladin, Status.Type.BARRIER, 2)
	battle.apply(AttackAction.new(trooper.id, paladin.id))
	assert_eq(battle.ult_gauge, [0, 0] as Array[int])


func test_barrel_blast_charges_only_for_defeats() -> void:
	var battle := Maps.battle(["...B......", "..........", ".........."])
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(9, 2))
	var hurt := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(4, 0))
	var weak := battle.add_unit(UnitKind.Id.SORCERER, P2, Vector2i(4, 1))
	weak.hp = 1
	battle.apply(AttackBarrelAction.new(sniper.id, Vector2i(3, 0)))
	assert_true(hurt.hp < hurt.max_hp())
	assert_eq(battle.ult_gauge, [0, Ults.DEFEAT_GAIN] as Array[int], "爆発のダメージではたまらない。倒れたぶんだけ")


func test_skill_damage_charges() -> void:
	var battle := _battle()
	battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 2))
	var trooper := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(5, 2))
	battle.apply(EndPhaseAction.new())
	var sorcerer := battle.add_unit(UnitKind.Id.SORCERER, P2, Vector2i(7, 2))
	var before := battle.ult_gauge.duplicate()
	battle.apply(UseSkillAction.new(sorcerer.id, trooper.cell))
	assert_eq(battle.ult_gauge[P2] - before[P2], FireballSkill.DAMAGE * Ults.DEALT_GAIN)
	assert_eq(battle.ult_gauge[P1] - before[P1], FireballSkill.DAMAGE * Ults.TAKEN_GAIN)


func test_neutral_units_count_as_enemies_but_have_no_gauge() -> void:
	var battle := _battle()
	var trooper := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(3, 0))
	var core := battle.add_unit(UnitKind.Id.MINION, NEUTRAL, Vector2i(4, 0))
	battle.apply(AttackAction.new(trooper.id, core.id))
	assert_eq(battle.ult_gauge, [trooper.power() * Ults.DEALT_GAIN, 0] as Array[int])
	Combat.strike(battle, core, trooper)
	assert_eq(battle.ult_gauge[P1], trooper.power() * Ults.DEALT_GAIN + core.power() * Ults.TAKEN_GAIN)
	assert_eq(battle.ult_gauge.size(), 2)


func test_gauge_stops_at_the_maximum_and_ready_is_announced_once() -> void:
	var battle := _battle()
	var trooper := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(3, 0))
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(4, 0))
	battle.ult_gauge[P2] = MAX - 1
	var events := battle.apply(AttackAction.new(trooper.id, paladin.id)).events
	assert_eq(battle.ult_gauge[P2], MAX)
	assert_eq(Ults.percent(battle, P2), 100)
	var ready := events[-1] as UltReadyEvent
	assert_eq([ready.side, ready.ult], [P2, Ult.Id.MANA_ERUPTION], "行動のイベントの最後に知らせる")
	events = battle.apply(EndPhaseAction.new()).events
	assert_eq(battle.ult_gauge[P2], MAX)
	assert_false(events.any(func(event: BattleEvent) -> bool: return event is UltReadyEvent), "もういっぱいなら知らせない")


func test_side_without_an_army_never_charges() -> void:
	var battle := _battle()
	var king := battle.add_unit(UnitKind.Id.KING, P1, Vector2i(3, 0))
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(4, 0))
	battle.apply(AttackAction.new(king.id, paladin.id))
	_end_turn(battle)
	assert_eq(battle.ult_gauge[P1], 0)
	battle.ult_gauge[P1] = MAX
	assert_false(battle.can_apply(UseUltAction.new()))


# ---- 使う ----


func test_cannot_use_below_the_maximum() -> void:
	var battle := _duel()
	battle.ult_gauge[P1] = MAX - 1
	assert_false(battle.can_apply(UseUltAction.new()))
	assert_false(battle.apply(UseUltAction.new()).accepted)
	assert_true(Ults.preview(battle).is_empty())


func test_use_is_for_the_player_whose_phase_it_is() -> void:
	var battle := _duel()
	_fill(battle, P2)
	assert_false(battle.can_apply(UseUltAction.new()), "プレイヤー1 の番。いっぱいなのはプレイヤー2")
	battle.apply(EndPhaseAction.new())
	var events := battle.apply(UseUltAction.new()).events
	var used := events[0] as UltUsedEvent
	assert_eq([used.side, used.ult], [P2, Ult.Id.MANA_ERUPTION])
	assert_eq(battle.ult_gauge[P2], 0, "使うと空になる")
	assert_eq(battle.ult_uses, [0, 1] as Array[int])
	assert_false(battle.can_apply(UseUltAction.new()), "同じフェーズにもう一度は使えない")


func test_use_does_not_spend_unit_actions() -> void:
	var battle := _duel()
	var trooper := battle.units[0]
	_fill(battle, P1)
	battle.apply(MoveAction.new(trooper.id, Vector2i(1, 0)))
	assert_true(battle.apply(UseUltAction.new()).accepted, "駒が行動の途中でも使える")
	assert_eq(battle.acting_unit_id, trooper.id)
	assert_false(trooper.acted)
	assert_true(battle.apply(UndoMoveAction.new(trooper.id)).accepted)
	assert_true(battle.apply(MoveAction.new(trooper.id, Vector2i(2, 0))).accepted)
	assert_true(battle.apply(WaitAction.new(trooper.id)).accepted)


func test_cannot_use_after_the_game_is_over_or_while_choosing_an_evolution() -> void:
	var battle := _duel()
	_fill(battle, P1)
	battle.units[0].evolution_ready = true
	assert_false(battle.can_apply(UseUltAction.new()))
	battle.units[0].evolution_ready = false
	battle.winner = P2
	assert_false(battle.can_apply(UseUltAction.new()))
	assert_false(Ults.can_use(battle))


func test_preview_and_clone_leave_the_battle_alone() -> void:
	var battle := _duel()
	_fill(battle, P1)
	var events := Ults.preview(battle)
	assert_true(events[0] is UltUsedEvent)
	assert_eq(battle.ult_gauge[P1], MAX)
	assert_false(Statuses.has(battle.units[0], ASSAULT))
	var copy := battle.clone()
	copy.apply(UseUltAction.new())
	assert_eq([battle.ult_gauge[P1], copy.ult_gauge[P1]], [MAX, 0])
	assert_eq([battle.ult_uses[P1], copy.ult_uses[P1]], [0, 1])
	assert_eq(copy.armies, battle.armies)


# ---- 総員突撃（MILITARY） ----


func test_all_out_assault_raises_move_and_power_of_every_unit() -> void:
	var battle := _battle()
	var king := battle.add_unit(UnitKind.Id.KING, P1, Vector2i(0, 0))
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(1, 0))
	var medic := battle.add_unit(UnitKind.Id.MEDIC, P1, Vector2i(2, 0))
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(9, 2))
	_fill(battle, P1)
	var move := sniper.move_range()
	var power := sniper.power()
	var heal := medic.power()
	var reach := battle.options(sniper.id).move_cells.size()
	var events := battle.apply(UseUltAction.new()).events
	assert_eq(events.size(), 4, "UltUsedEvent と、駒ごとの StatusAppliedEvent")
	for i in 3:
		var applied := events[i + 1] as StatusAppliedEvent
		assert_eq([applied.unit_id, applied.status], [battle.units[i].id, ASSAULT], "駒の番号の順")
	assert_eq(sniper.move_range(), move + AllOutAssaultUlt.MOVE_BONUS)
	assert_eq(sniper.power(), power + AllOutAssaultUlt.POWER_BONUS)
	assert_eq(medic.power(), heal + AllOutAssaultUlt.POWER_BONUS, "回復役は回復量")
	assert_true(Statuses.has(king, ASSAULT), "将にも付く")
	assert_false(Statuses.has(paladin, ASSAULT), "相手には付かない")
	assert_eq(sniper.base_stat(Unit.Stat.POWER), power, "もとの値は書き換えない")
	assert_true(battle.options(sniper.id).move_cells.size() > reach, "動けるマスが広がる")


func test_all_out_assault_damage_uses_the_raised_power() -> void:
	var battle := _battle()
	var trooper := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(3, 0))
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(4, 0))
	_fill(battle, P1)
	var power := trooper.power()
	battle.apply(UseUltAction.new())
	assert_eq(Combat.damage(battle, trooper, paladin), power + AllOutAssaultUlt.POWER_BONUS)
	battle.apply(AttackAction.new(trooper.id, paladin.id))
	assert_eq(paladin.hp, paladin.max_hp() - power - AllOutAssaultUlt.POWER_BONUS)


func test_all_out_assault_ends_at_the_start_of_the_next_own_phase() -> void:
	var battle := _duel()
	var trooper := battle.units[0]
	_fill(battle, P1)
	var move := trooper.move_range()
	var power := trooper.power()
	battle.apply(UseUltAction.new())
	battle.apply(EndPhaseAction.new())
	var events := battle.apply(EndPhaseAction.new()).events
	assert_false(Statuses.has(trooper, ASSAULT))
	assert_eq([trooper.move_range(), trooper.power()], [move, power])
	var expired := false
	for event in events:
		var removed := event as StatusRemovedEvent
		if removed != null and removed.status == ASSAULT:
			expired = removed.reason == StatusRemovedEvent.Reason.EXPIRED and removed.unit_id == trooper.id
	assert_true(expired)


## 突撃した駒（種類 kind、レベル level、進化先 evolution）の、満タンの将（森の外、バリア無し）への 1 発のダメージ。
## aimed なら照準を構えている。
func _assault_blow(kind: UnitKind.Id, level: int, evolution: Evolution.Id, aimed: bool) -> int:
	var battle := _battle()
	var unit := battle.add_unit(kind, P1, Vector2i(0, 0))
	var king := battle.add_unit(UnitKind.Id.KING, P2, Vector2i(9, 0))
	Growth.gain(unit, (level - 1) * Growth.EXPERIENCE_PER_LEVEL, ExperienceGainedEvent.Reason.HIT)
	if evolution != Evolution.Id.NONE:
		unit.evolve(evolution)
	Statuses.add(unit, ASSAULT, 1)
	if aimed:
		Statuses.add(unit, Status.Type.AIM, 1)
	assert_eq(king.hp, king.max_hp())
	return Combat.damage(battle, unit, king)


## MILITARY の戦う駒を [種類, 進化先] で並べる。evolved なら進化先ごと（上限のレベルでは、どの駒も進化している）、そうでなければ進化しないまま。
func _military_fighters(evolved: bool) -> Array[Array]:
	var result: Array[Array] = []
	for kind in Deck.roster(UnitKind.Army.MILITARY):
		if UnitKind.role(kind) == UnitKind.Role.HEALER:
			continue
		if not evolved:
			result.append([kind, Evolution.Id.NONE])
			continue
		for evolution in Evolution.options_for(kind):
			result.append([kind, evolution])
	return result


func test_all_out_assault_cannot_fell_a_full_health_king_in_one_blow() -> void:
	var king_hp := UnitKind.max_hp(UnitKind.Id.KING)
	for fighter in _military_fighters(false):
		var name := UnitKind.display_name(fighter[0])
		assert_true(_assault_blow(fighter[0], 1, fighter[1], false) < king_hp, "%s の一撃は、将の HP に届かない" % name)
		if fighter[0] == UnitKind.Id.SNIPER:
			assert_true(_assault_blow(fighter[0], 1, fighter[1], true) < king_hp, "構えたスナイパーの一撃でも届かない")


## 育った駒は届くことがある（docs/tactical-ult.md）。いまの数値では、突撃して構えたレベル 3 のマークスマンだけ。
## 許すかどうかは、遊んでみて決める（Issue #47）。数値を変えてこれが変わったら、文書も直す。
func test_all_out_assault_fells_a_full_health_king_only_with_an_aimed_grown_marksman() -> void:
	var king_hp := UnitKind.max_hp(UnitKind.Id.KING)
	var fellers: Array[String] = []
	for fighter in _military_fighters(true):
		var aims: Array[bool] = [false]
		if fighter[0] == UnitKind.Id.SNIPER:
			aims.append(true)
		for aimed: bool in aims:
			if _assault_blow(fighter[0], Growth.MAX_LEVEL, fighter[1], aimed) >= king_hp:
				fellers.append(Evolution.display_name(fighter[1]) + ("（照準）" if aimed else ""))
	assert_eq(fellers, ["マークスマン（照準）"] as Array[String], "レベル 3 で届くのは、構えたマークスマンだけ")


# ---- 魔力解放（FANTASY） ----


func test_mana_eruption_clears_every_cooldown() -> void:
	var battle := _battle()
	battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	var king := battle.add_unit(UnitKind.Id.KING, P2, Vector2i(9, 0))
	var sorcerer := battle.add_unit(UnitKind.Id.SORCERER, P2, Vector2i(8, 0))
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(7, 0))
	var priest := battle.add_unit(UnitKind.Id.PRIEST, P2, Vector2i(6, 0))
	battle.apply(EndPhaseAction.new())
	sorcerer.skill_cooldown = 4
	paladin.skill_cooldown = 1
	_fill(battle, P2)
	var events := battle.apply(UseUltAction.new()).events
	assert_eq(events.size(), 3, "UltUsedEvent と、クールダウンの残っていた駒の SkillReadyEvent")
	assert_eq((events[1] as SkillReadyEvent).unit_id, sorcerer.id)
	assert_eq((events[2] as SkillReadyEvent).unit_id, paladin.id)
	assert_eq([sorcerer.skill_cooldown, paladin.skill_cooldown, priest.skill_cooldown, king.skill_cooldown], [0, 0, 0, 0])
	assert_false(Statuses.has(sorcerer, ASSAULT))


func test_mana_eruption_lets_a_unit_use_its_skill_in_the_same_phase() -> void:
	var battle := _battle()
	var trooper := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(5, 2))
	battle.apply(EndPhaseAction.new())
	var sorcerer := battle.add_unit(UnitKind.Id.SORCERER, P2, Vector2i(7, 2))
	var waited := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(9, 0))
	sorcerer.skill_cooldown = 3
	waited.skill_cooldown = 3
	battle.apply(WaitAction.new(waited.id))
	assert_false(battle.can_apply(UseSkillAction.new(sorcerer.id, trooper.cell)))
	_fill(battle, P2)
	battle.apply(UseUltAction.new())
	assert_true(battle.apply(UseSkillAction.new(sorcerer.id, trooper.cell)).accepted)
	assert_eq(sorcerer.skill_cooldown, FireballSkill.COOLDOWN, "使えば、いつものクールダウンが付く")
	assert_eq(waited.skill_cooldown, 0, "行動済みの駒のクールダウンも 0 になる")
	assert_true(waited.acted, "行動は戻らない")


func test_mana_eruption_does_not_refill_spent_uses() -> void:
	var battle := _battle()
	var medic := battle.add_unit(UnitKind.Id.MEDIC, P1, Vector2i(0, 0))
	battle.armies[P1] = UnitKind.Army.FANTASY  # 回数に上限のあるスキルは MILITARY にしか無いので、軍だけ替えて確かめる
	battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(9, 0))
	medic.skill_uses = AdrenalineShotSkill.MAX_USES
	medic.skill_cooldown = 2
	_fill(battle, P1)
	var events := battle.apply(UseUltAction.new()).events
	assert_eq(events.size(), 1, "使い切った駒には SkillReadyEvent が出ない")
	assert_eq(Skills.uses_left(medic), 0)


# ---- CPU ----

const OPEN_ROWS: Array[String] = [
	"................",
	"................",
	"................",
	"................",
	"................",
]


## 両方の将を隅に置いた、壁の無い 16 x 5 の対戦。
func _open_battle() -> Battle:
	var battle := Maps.battle(OPEN_ROWS)
	battle.board.hq_cells = [Vector2i(0, 4), Vector2i(15, 0)]
	battle.add_unit(UnitKind.Id.KING, P1, Vector2i(0, 4))
	battle.add_unit(UnitKind.Id.KING, P2, Vector2i(15, 0))
	return battle


func test_cpu_uses_all_out_assault_when_the_army_can_strike() -> void:
	var battle := _open_battle()
	for y in 3:
		battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(4, y + 1))
		battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(9, y + 1))
	_fill(battle, P1)
	# 前衛は移動力 3 + 射程 1。5 マス先の敵には、伸びた移動力（+2）でだけ届く。
	assert_true(CpuPlayer.new().next_action(battle) is UseUltAction)
	battle.ult_gauge[P1] = MAX - 1
	assert_false(CpuPlayer.new().next_action(battle) is UseUltAction, "いっぱいでなければ使えない")


func test_cpu_keeps_all_out_assault_while_the_enemy_is_out_of_reach() -> void:
	var battle := _open_battle()
	for y in 3:
		battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(1, y + 1))
		battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(12, y + 1))
	_fill(battle, P1)
	assert_false(CpuPlayer.new().next_action(battle) is UseUltAction)


func test_cpu_keeps_all_out_assault_after_its_units_have_acted() -> void:
	var battle := _open_battle()
	for y in 3:
		var trooper := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(4, y + 1))
		battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(9, y + 1))
		battle.apply(WaitAction.new(trooper.id))
	_fill(battle, P1)
	assert_false(CpuPlayer.new().next_action(battle) is UseUltAction, "行動済みの駒は、突撃しても動けない")


func test_cpu_uses_mana_eruption_when_skills_are_on_cooldown_near_the_enemy() -> void:
	var battle := _open_battle()
	battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(6, 2))
	battle.apply(EndPhaseAction.new())
	var sorcerer := battle.add_unit(UnitKind.Id.SORCERER, P2, Vector2i(9, 2))
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(8, 2))
	_fill(battle, P2)
	assert_false(CpuPlayer.new().next_action(battle) is UseUltAction, "スキルはどれも使える。解放しても得が無い")
	sorcerer.skill_cooldown = 3
	paladin.skill_cooldown = 3
	assert_true(CpuPlayer.new().next_action(battle) is UseUltAction)
	paladin.skill_cooldown = 1
	assert_false(CpuPlayer.new().next_action(battle) is UseUltAction, "待っている駒が 1 体だけなら、まだ使わない")


func test_cpu_counts_a_ready_enemy_ult_as_danger() -> void:
	var battle := Maps.battle(OPEN_ROWS)
	var king := battle.add_unit(UnitKind.Id.KING, P1, Vector2i(0, 2))
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P2, Vector2i(9, 2))
	var cpu := CpuPlayer.new()
	assert_eq(cpu.danger(battle, king.id, king.cell), 0, "移動力 6 + 射程 1 の外")
	_fill(battle, P2)
	assert_eq(
		cpu.danger(battle, king.id, king.cell), commando.power() + AllOutAssaultUlt.POWER_BONUS,
		"相手が総員突撃を使えるなら、伸びた移動力と攻撃力で数える",
	)
	assert_eq(battle.ult_gauge[P2], MAX, "見積もりは対戦を変えない")
