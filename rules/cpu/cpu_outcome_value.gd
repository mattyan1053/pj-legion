extends "res://rules/cpu/cpu_threats.gd"
## CPU の思考の、行動の結果の価値（ダメージ・撃破・回復・経験・組み方・中ボスと聖遺物・狩り・障壁・倒れると何か起きる魔物）。


## 行動を複製（sim）に apply したあとの、その行動の価値。events はそのとき起きたこと。
## 駒が誰のものだったかは、行動の前の状態（_battle）で見る（倒れた駒は sim にもういない）。
func _outcome_value(sim: Battle, events: Array[BattleEvent]) -> float:
	if sim.is_over():
		if sim.is_draw():
			return DRAW_VALUE
		return WIN_VALUE if sim.winner == _me else -WIN_VALUE
	var value := 0.0
	for event in events:
		var damaged := event as UnitDamagedEvent
		if damaged != null:
			var victim := _battle.unit_by_id(damaged.unit_id)
			var worth := _damage_value(victim, damaged.hp)
			value += -FRIENDLY_FIRE_RATE * worth if victim.side == _me else worth
			if damaged is AttackDamagedEvent and _battle.formation and victim.side == _foe:
				value += _formation_value(sim, (damaged as AttackDamagedEvent).attacker_id, victim, damaged.hp)
			continue
		var healed := event as UnitHealedEvent
		if healed != null:
			var target := _battle.unit_by_id(healed.unit_id)
			value += HEAL_VALUE * healed.amount + HEAL_BASE_VALUE
			value += WOUNDED_BONUS * (1.0 - float(target.hp) / target.max_hp())
			if target.kind == UnitKind.Id.KING:
				value += KING_HEAL_BONUS
			continue
		var used := event as SkillUsedEvent
		if used != null:
			var estimate := CpuSkillEstimate.of(used.skill)
			if estimate != null:
				value += estimate.value(self, used, sim)
			continue
		var chipped := event as BarricadeDamagedEvent
		if chipped != null:
			value += BARRICADE_DAMAGE_VALUE * chipped.amount
			continue
		var stripped := event as StatusRemovedEvent
		if stripped != null:
			if stripped.reason == StatusRemovedEvent.Reason.CONSUMED and Status.blocks_damage(stripped.status):
				value += _barrier_strip_value(stripped.unit_id, sim)
			continue
		var removed := event as FieldEffectRemovedEvent
		if removed != null:
			if removed.reason == FieldEffectRemovedEvent.Reason.DESTROYED:
				value += BARRICADE_BREAK_VALUE
			continue
		var rally := event as RallyEvent
		if rally != null:
			var bearer := _battle.unit_by_id(rally.fallen_id)
			value += (RALLY_PENALTY if bearer.side == _me else -RALLY_PENALTY) * rally.rallied_ids.size()
			continue
		var knot := event as KnotPlacedEvent
		if knot != null:
			value += KNOT_PENALTY if knot.side == _me else -KNOT_PENALTY
			continue
		var gained := event as ExperienceGainedEvent
		if gained != null:
			value += EXPERIENCE_VALUE * gained.amount
		elif event is LevelUpEvent:
			value += LEVEL_UP_VALUE
	return value


## 組み方の見込み: 駒 attacker_id が相手の victim（攻撃の前の状態）を hp_after まで減らしたあとの、組み方のぶんの価値。
## 誓いの駒を倒せば OATH_BREAK_VALUE。倒しきらず、誓いの相手が近くにいれば -OATH_PROVOKE_PENALTY。
## 分隊の駒が倒しきらずに攻撃し、このあとに動ける同じ分隊の仲間が届きそうなら SQUAD_FOCUS_SETUP_VALUE（追い撃ちの見込み）。
func _formation_value(sim: Battle, attacker_id: int, victim: Unit, hp_after: int) -> float:
	var value := 0.0
	if Formation.partner_of(_battle, victim) != null:
		if hp_after == 0:
			value += OATH_BREAK_VALUE
		elif Formation.oath_near(_battle, victim):
			value -= OATH_PROVOKE_PENALTY
	var attacker := _battle.unit_by_id(attacker_id)
	if hp_after > 0 and attacker != null and Formation.in_squad(_battle, attacker):
		for mate in Formation.squad_of(_battle, attacker):
			if mate.id == attacker.id or not sim.can_act(sim.unit_by_id(mate.id)):
				continue
			if Combat.distance(mate.cell, victim.cell) <= mate.move_range() + mate.attack_range():
				value += SQUAD_FOCUS_SETUP_VALUE
				break
	return value


## victim の HP を hp_after まで減らす価値（victim は減らす前の状態）。
func _damage_value(victim: Unit, hp_after: int) -> float:
	var rate := DAMAGE_VALUE
	var kill := KILL_VALUE + KILL_VALUE_PER_COST * UnitKind.cost(victim.kind)
	if victim.kind == UnitKind.Id.ELITE_MINION:
		return _mid_boss_damage_value(victim, hp_after)
	elif victim.side == Unit.Side.NEUTRAL:
		rate = NEUTRAL_DAMAGE_VALUE
		kill = NEUTRAL_KILL_VALUE
	elif victim.kind == UnitKind.Id.KING:
		rate = KING_DAMAGE_VALUE
	elif UnitKind.role(victim.kind) == UnitKind.Role.HEALER:
		kill += HEALER_KILL_BONUS
	if victim.side == _foe and victim.cell == _board.stronghold_cell and Stronghold.counts(victim):
		rate *= STRONGHOLD_RATE
		kill += STRONGHOLD_KILL_BONUS * (1 + _battle.stronghold_holds[_foe])
	if victim.side == _foe and _my_hq != Board.NO_CELL:
		if victim.cell == _my_hq:
			rate *= OCCUPIER_RATE
			kill += OCCUPIER_KILL_BONUS
		elif Combat.distance(victim.cell, _my_hq) <= DEFENSE_RADIUS:
			rate *= INTRUDER_RATE
	var value := rate * (victim.hp - hp_after)
	if hp_after == 0:
		return value + kill
	return maxf(1.0, value - REMAINING_HP_PENALTY * hp_after)


## 中ボス boss の HP を hp_after まで減らす価値。倒す価値は、聖遺物の価値（_relic_value）。
## 削る価値は、狩ると決めた中ボスだけ（HUNT_DAMAGE_VALUE）。狩ると決めていない中ボスは、削らない（MID_BOSS_IDLE_PENALTY を引く。
## 倒しきれないのに削ると、殴り返されるうえに、止めを相手に渡す）。止めを相手に渡す削りは、MID_BOSS_FEED_PENALTY を引く。
func _mid_boss_damage_value(boss: Unit, hp_after: int) -> float:
	_build_hunts()
	if hp_after == 0:
		return HUNT_DAMAGE_VALUE * boss.hp + _relic_value()
	if not _chipped.has(boss.id):
		return -MID_BOSS_IDLE_PENALTY
	var value := HUNT_DAMAGE_VALUE * (boss.hp - hp_after)
	if hp_after <= _rival_strike.get(boss.id, 0) and _follow_up_strike(boss) < hp_after:
		value -= MID_BOSS_FEED_PENALTY
	return value


## 聖遺物を受け取る価値（どちらの聖遺物も同じに見る）。効果は自分の駒の数だけ掛かる。
func _relic_value() -> float:
	var count := 0
	for unit in _battle.units:
		if unit.side == _me:
			count += 1
	return RELIC_BASE_VALUE + RELIC_UNIT_VALUE * count


## このフェーズに、いま考えている駒のあとで boss に届きそうな味方（まだ行動していない戦う駒。移動力 + 射程の中。目安）の攻撃力の合計。
func _follow_up_strike(boss: Unit) -> int:
	var total := 0
	for friend in _battle.units:
		if friend.side != _me or friend.id == _thinking_id or friend.acted or _is_healer(friend):
			continue
		if Combat.distance(friend.cell, boss.cell) <= friend.move_range() + friend.attack_range():
			total += friend.power()
	return total


func _is_healer(unit: Unit) -> bool:
	return UnitKind.role(unit.kind) == UnitKind.Role.HEALER


## 中ボスごとに、狩るか（_hunted。値は、もう削り切れるところまで来ているか）、相手が狩っているか（_rival_hunts）、
## 次の相手の番に届きそうな相手の攻撃力（_rival_strike）を読む。条件は、調整値の HUNT_* のところ。
## 距離は目安（自分の駒は歩数、相手の駒はマンハッタン距離。地形は見ない）。
func _build_hunts() -> void:
	if _hunts_ready:
		return
	_hunts_ready = true
	_hunted = {}
	_chipped = {}
	_rival_hunts = {}
	_rival_strike = {}
	var home_threat := false
	if _my_hq != Board.NO_CELL:
		for foe in _battle.units:
			if foe.side == _foe and Combat.distance(foe.cell, _my_hq) <= GUARD_RADIUS:
				home_threat = true
	var width := _board.size.x
	for boss in _battle.units:
		if boss.kind != UnitKind.Id.ELITE_MINION:
			continue
		var steps := _steps_from(boss.cell)
		# 狩りに加われる自分の駒の [着くまでのターン数, 攻撃力]。全部と、手の空いている駒だけ。
		var squad: Array[Vector2i] = []
		var free_squad: Array[Vector2i] = []
		var foes: Array[Unit] = []
		var strike := 0
		var near_rivals := 0
		for other in _battle.units:
			if other.side == Unit.Side.NEUTRAL or _is_healer(other):
				continue
			if other.side == _foe:
				var apart := Combat.distance(other.cell, boss.cell)
				if apart <= other.move_range() + other.attack_range():
					strike += other.power()
				if other.kind != UnitKind.Id.KING:
					foes.append(other)
					if apart <= HUNT_RIVAL_RADIUS:
						near_rivals += other.power()
			elif other.kind != UnitKind.Id.KING:
				var away := steps[other.cell.y * width + other.cell.x]
				if away > HUNT_RADIUS:
					continue
				var member := Vector2i(ceili(float(maxi(0, away - other.attack_range())) / maxi(1, other.move_range())), other.power())
				squad.append(member)
				if _nearest_foe_distance(other) > HUNT_ENGAGE_DISTANCE:
					free_squad.append(member)
		_rival_strike[boss.id] = strike
		if near_rivals > 0 and boss.hp < boss.max_hp() and near_rivals * HUNT_TURNS >= boss.hp:
			_rival_hunts[boss.id] = true
		if home_threat or _battle.turn < HUNT_FROM_TURN or _holding or _rushing:
			continue
		var need := ceili(boss.hp * HUNT_MARGIN)
		# 加われる駒の全部で倒せるなら、届いた駒は削ってよい。
		if _outguns_rivals(boss, squad, foes, _kill_turns(squad, need, HUNT_TURNS)):
			_chipped[boss.id] = true
		# 向かうのは、手の空いている駒だけで倒せるとき。もう削り切れるところまで来ていれば、全部の駒が向かう。
		if _outguns_rivals(boss, squad, foes, _kill_turns(squad, need, HUNT_COMMIT_TURNS)):
			_hunted[boss.id] = true
		elif _outguns_rivals(boss, free_squad, foes, _kill_turns(free_squad, need, HUNT_TURNS)):
			_hunted[boss.id] = false


## squad が turns ターンで boss を倒しきるまでに、ここへ着ける相手の戦う駒（foes のうち、turns × 移動力 + 射程の中）の
## 攻撃力の合計の HUNT_SUPERIORITY 倍以上の攻撃力が、squad にあるか。turns が 0（倒せない）なら偽。
func _outguns_rivals(boss: Unit, squad: Array[Vector2i], foes: Array[Unit], turns: int) -> bool:
	if turns == 0:
		return false
	var power := 0
	for member in squad:
		power += member.y
	var rivals := 0
	for foe in foes:
		if Combat.distance(foe.cell, boss.cell) <= turns * foe.move_range() + foe.attack_range():
			rivals += foe.power()
	return power >= HUNT_SUPERIORITY * rivals


## squad（[着くまでのターン数, 攻撃力] の列）が、着いた順に毎ターン殴って、合わせて need のダメージを与えるまでのターン数。
## limit ターンでは足りなければ 0。
func _kill_turns(squad: Array[Vector2i], need: int, limit: int) -> int:
	for turns in range(1, limit + 1):
		var dealt := 0
		for member in squad:
			dealt += member.y * maxi(0, turns - member.x)
		if dealt >= need:
			return turns
	return 0


## unit が狩りに向かう中ボス（いなければ null）。狩ると決めた中ボスのうち、HUNT_RADIUS 歩以内で、いちばん近いもの。
## 手の空いていない駒（HUNT_ENGAGE_DISTANCE マス以内に相手の駒がいる）は、もう削り切れるところまで来た中ボスにだけ向かう。
func _boss_to_hunt(unit: Unit) -> Unit:
	_build_hunts()
	if _hunted.is_empty():
		return null
	var engaged := _nearest_foe_distance(unit) <= HUNT_ENGAGE_DISTANCE
	var best: Unit = null
	var best_steps := HUNT_RADIUS + 1
	var from := _steps_from(unit.cell)
	for boss_id in _hunted:
		if engaged and not _hunted[boss_id]:
			continue
		var boss := _battle.unit_by_id(boss_id)
		var steps := from[boss.cell.y * _board.size.x + boss.cell.x]
		if steps < best_steps:
			best = boss
			best_steps = steps
	return best


## unit が止めを横取りしに向かう中ボス（いなければ null）。相手が狩っていて、HP が最大 HP の STEAL_HP_PERCENT % まで減った中ボスのうち、
## DENY_RADIUS マス以内で、いちばん近いもの。向かうのは、後衛と奇襲だけ（離れて撃てるか、速い）。
func _boss_to_steal(unit: Unit) -> Unit:
	_build_hunts()
	var best: Unit = null
	var best_distance := DENY_RADIUS + 1
	for boss_id in _rival_hunts:
		var boss := _battle.unit_by_id(boss_id)
		var apart := Combat.distance(unit.cell, boss.cell)
		if boss.hp * 100 <= boss.max_hp() * STEAL_HP_PERCENT and apart < best_distance:
			best = boss
			best_distance = apart
	return best


## 駒 victim_id のバリアが外れた価値（sim は、外れたあとの複製）。敵のバリアをはがしたなら、このあとに動ける味方のうち、
## その敵に届きそうな駒（移動力 + 射程の歩数の中。目安）のいちばん強い攻撃 1 回ぶんを見込む。味方のバリアなら、同じだけ引く。
func _barrier_strip_value(victim_id: int, sim: Battle) -> float:
	var victim := sim.unit_by_id(victim_id)
	if victim == null or victim.side == Unit.Side.NEUTRAL:
		return 0.0
	if victim.side == _me:
		return -BARRIER_STRIP_VALUE
	var strongest := 0
	for friend in sim.units:
		if friend.side != _me or not sim.can_act(friend) or friend.id == sim.acting_unit_id:
			continue
		if UnitKind.role(friend.kind) == UnitKind.Role.HEALER:
			continue
		if Combat.distance(friend.cell, victim.cell) <= friend.move_range() + friend.attack_range():
			strongest = maxi(strongest, Combat.attack_power(friend))
	var rate := KING_DAMAGE_VALUE if victim.kind == UnitKind.Id.KING else DAMAGE_VALUE
	return BARRIER_STRIP_VALUE + BARRIER_STRIP_RATE * rate * mini(strongest, victim.hp)
