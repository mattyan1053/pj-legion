extends "res://game/battle_log/log_moves.gd"
## 対戦のログ（game/battle_log.gd）の、戦いの読み方: 攻撃・スキル・効果のダメージ、回復、軍略、状態、必殺技、撃破、中ボスと聖遺物、レベルと進化、決着。


func _read_attack_damaged(event: AttackDamagedEvent) -> void:
	_group = null
	_did_something[event.attacker_id] = true
	var text := Text.t("battle.log.attack", {
		"attacker": unit_name(event.attacker_id), "target": unit_name(event.unit_id), "result": _damage_text(event, true),
	})
	_line(text, _side_of(event.attacker_id), _cell_of(event.unit_id), [event.attacker_id, event.unit_id])


func _read_smoke_blocked(event: SmokeBlockedEvent) -> void:
	_group = null
	_did_something[event.attacker_id] = true
	var text := Text.t("battle.log.attack_smoked", {"attacker": unit_name(event.attacker_id), "target": unit_name(event.target_id)})
	_line(text, _side_of(event.attacker_id), _cell_of(event.target_id), [event.attacker_id, event.target_id])


func _read_skill_used(event: SkillUsedEvent) -> void:
	_did_something[event.unit_id] = true
	var text := Text.t("battle.log.skill", {"unit": unit_name(event.unit_id), "skill": Names.skill(Skills.by_id(event.skill))})
	if event.target != _cell_of(event.unit_id):
		text += Text.paren(cell_text(event.target))
	_begin_group(_line(text, _side_of(event.unit_id), event.target, [event.unit_id]), event.unit_id)


## スキル・樽の爆発のダメージ。まとめ先（スキルの行、爆発の行）の続きに書く。
func _read_effect_damaged(event: UnitDamagedEvent) -> void:
	var key := "battle.log.effect_blocked" if event.is_blocked() else "battle.log.effect_damage"
	var text := Text.t(key, {"unit": unit_name(event.unit_id), "result": _damage_text(event, false)})
	_detail(text, _side_of(event.unit_id), _cell_of(event.unit_id), [event.unit_id])


func _read_healer_healed(event: HealerHealedEvent) -> void:
	_group = null
	_did_something[event.healer_id] = true
	var text := Text.t("battle.log.heal", {"healer": unit_name(event.healer_id), "target": unit_name(event.unit_id), "amount": event.amount, "hp": event.hp})
	_line(text, _side_of(event.healer_id), _cell_of(event.unit_id), [event.healer_id, event.unit_id])


## フェーズの始めの回復（泉・再生・聖域・補給線）。
func _read_healed(event: UnitHealedEvent) -> void:
	var key := "battle.log.healed.sanctuary"
	if event is SpringHealedEvent:
		key = "battle.log.healed.spring"
	elif event is RegenerationHealedEvent:
		key = "battle.log.healed.regeneration"
	elif event is SupplyHealedEvent:
		key = "battle.log.healed.supply"
	_line(Text.t(key, {"unit": unit_name(event.unit_id), "amount": event.amount, "hp": event.hp, "effect": Names.troop_trait(Traits.Id.SUPPLY)}),
		_side_of(event.unit_id), _cell_of(event.unit_id), [event.unit_id])


## 軍略が攻撃に効いた（「青のスナイパーの集中砲火: ダメージ +2」）。
func _read_trait(event: TraitTriggeredEvent) -> void:
	var key := "battle.log.trait_down" if Traits.shields(event.trait_id) else "battle.log.trait_up"
	_line(Text.t(key, {"unit": unit_name(event.unit_id), "effect": Names.troop_trait(event.trait_id), "amount": event.amount}),
		_side_of(event.unit_id), _cell_of(event.unit_id), [event.unit_id, event.other_id])


## 骸骨旗手が倒れ、周りの味方が奮起した。続く奮起（StatusAppliedEvent）は、この行にまとめる。
func _read_rally(event: RallyEvent) -> void:
	var text := Text.t("battle.log.rally", {"unit": unit_name(event.fallen_id), "count": event.rallied_ids.size()})
	_begin_group(_line(text, _side_of(event.fallen_id), event.cell, [event.fallen_id]))


## 糸喰いが倒れて弾けた。続く巻き込み（ExplosionDamagedEvent）は、この行にまとめる。
func _read_burst(event: BurstEvent) -> void:
	var key := "battle.log.burst_alone" if event.victim_ids.is_empty() else "battle.log.burst"
	_begin_group(_line(Text.t(key, {"unit": unit_name(event.fallen_id)}), _side_of(event.fallen_id), event.cell, [event.fallen_id]))


## 状態が付いた。まとめ先があれば、状態ごとに 1 行にまとめる（「突撃（2 ターン）: 青の将、青のパラディン…」）。
func _read_status_applied(event: StatusAppliedEvent) -> void:
	if _undoing:
		return  # 移動を取り消して、元に戻っただけ
	var name := Names.status(event.status)
	if _group == null:
		_line(Text.t("battle.log.status", {"unit": unit_name(event.unit_id), "status": name, "turns": event.turns}), _side_of(event.unit_id),
			_cell_of(event.unit_id), [event.unit_id])
		return
	var known: Array = _group_statuses.get(event.status, [])
	if known.is_empty():
		known = [_group.details.size(), [] as Array[String], event.turns]
		_group.details.append("")
		_group_statuses[event.status] = known
	(known[1] as Array[String]).append(unit_name(event.unit_id))
	_group.details[known[0]] = Text.t("battle.log.status_group", {"status": name, "turns": known[2], "units": Text.join_comma(known[1])})
	if _group_user != 0 and known[1] == [unit_name(_group_user)]:
		_group.details[known[0]] = Text.t("battle.log.status_self", {"status": name, "turns": known[2]})  # 使った駒が自分に付けた
	if not _group.unit_ids.has(event.unit_id):
		_group.unit_ids.append(event.unit_id)
	_touch(_group)


func _read_ult_used(event: UltUsedEvent) -> void:
	var text := Text.t("battle.log.ult", {"side": Names.side_word(event.side), "ult": Names.ult(Ults.by_id(event.ult))})
	_begin_group(_line(text, event.side))


func _read_ult_ready(event: UltReadyEvent) -> void:
	_line(Text.t("battle.log.ult_ready", {"side": Names.side_word(event.side), "ult": Names.ult(Ults.by_id(event.ult))}), event.side)


func _read_defeated(event: UnitDefeatedEvent) -> void:
	_set_cell(event.unit_id, event.cell)
	if _noted_defeats.has(event.unit_id):
		_noted_defeats.erase(event.unit_id)  # ダメージの行に「倒した」と書いた
		return
	_detail(Text.t("battle.log.defeated", {"unit": unit_name(event.unit_id)}), event.side, event.cell, [event.unit_id])


func _read_mid_boss_defeated(event: MidBossDefeatedEvent) -> void:
	_group = null
	var place := mid_boss_place(_board, event.boss_index)
	if event.slayer_side < 0:
		_line(Text.t("battle.log.boss_fell", {"place": place}), -1, event.cell)
		return
	_line(Text.t("battle.log.boss_slain", {"side": Names.side_word(event.slayer_side), "place": place}), event.slayer_side, event.cell, [event.slayer_id])


func _read_relic_gained(event: RelicGainedEvent) -> void:
	_group = null
	var text := Text.t("battle.log.relic", {
		"side": Names.side_word(event.side), "relic": Names.relic(event.relic), "effect": Names.relic_summary(event.relic),
	})
	_line(text, event.side)


func _read_level_up(event: LevelUpEvent) -> void:
	var known: Known = _units.get(event.unit_id)
	var healer := known != null and UnitKind.role(known.kind) == UnitKind.Role.HEALER
	var gains: Array[String] = []
	for stat: Unit.Stat in Names.STATS:
		if event.gains.get(stat, 0) != 0:
			var stat_name: String = Text.t("battle.log.stat_heal") if healer and stat == Unit.Stat.POWER else Names.stat(stat)
			gains.append(Text.t("battle.log.stat_gain", {"stat": stat_name, "amount": "%+d" % event.gains[stat]}))
	var text := Text.t("battle.log.level_up", {"unit": unit_name(event.unit_id), "level": event.level}) + Text.notes(gains)
	_line(text, _side_of(event.unit_id), _cell_of(event.unit_id), [event.unit_id])


func _read_evolved(event: UnitEvolvedEvent) -> void:
	var before := unit_name(event.unit_id)
	var known: Known = _units.get(event.unit_id)
	if known != null:
		known.evolution = event.evolution
	_line(Text.t("battle.log.evolved", {"unit": before, "evolution": Names.evolution(event.evolution)}), _side_of(event.unit_id),
		_cell_of(event.unit_id), [event.unit_id])


func _read_won(event: GameWonEvent) -> void:
	_group = null
	_line(Text.t("battle.log.won", {"side": side_names[event.winner], "reason": Text.t(WIN_TEXTS[event.reason])}), event.winner)


func _read_drawn(event: GameDrawnEvent) -> void:
	_group = null
	_line(Text.t("battle.log.drawn", {"reason": Text.t(DRAW_TEXTS[event.reason])}), -1)
