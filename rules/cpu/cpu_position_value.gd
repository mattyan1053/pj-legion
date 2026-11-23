extends "res://rules/cpu/cpu_outcome_value.gd"
## CPU の思考の、位置の価値と目標（どこへ向かうか、砲台・拠点、狙う相手と付いていく味方）。


## unit が cell に立って行動を終える価値。目標への近さ、敵の本陣、相手の結び目（踏んでほどく）、次の相手の番に受けうるダメージで決まる。
## ignored_id の敵からの危険は数えない（この行動で倒す相手）。acting は、そこで攻撃・回復する手か。
## _set_goal と _build_threats のあとに呼ぶ。
func _position_value(unit: Unit, cell: Vector2i, ignored_id: int, acting: bool) -> float:
	var steps := _goal_steps[cell.y * _board.size.x + cell.x]
	var value := -_goal_weight * maxi(0, steps - _goal_reach)
	if _stand_off:
		value += STAND_OFF_VALUE * mini(steps, _goal_reach)
	if cell == _foe_hq and (unit.kind != UnitKind.Id.KING or _lone_king):
		if UnitKind.role(unit.kind) != UnitKind.Role.HEALER:
			value += HQ_VALUE_RAIDER if UnitKind.role(unit.kind) == UnitKind.Role.RAIDER else HQ_VALUE_OTHER
		if unit.cell == cell:
			value += HQ_HOLD_VALUE * _battle.capture_turns[_me]
	if cell == _my_hq and _hq_in_danger and UnitKind.role(unit.kind) != UnitKind.Role.RAIDER:
		value += HQ_GUARD_VALUE
	if not _support.is_empty():
		var apart := _FAR
		for friend_cell in _support:
			apart = mini(apart, Combat.distance(cell, friend_cell))
		value -= ISOLATION_WEIGHT * maxi(0, apart - SUPPORT_DISTANCE)
	value += _battery_pull(unit, cell)
	if cell == _board.stronghold_cell and _takes_stronghold and Stronghold.counts(unit) and UnitKind.role(unit.kind) != UnitKind.Role.HEALER:
		value += STRONGHOLD_VALUE
		if unit.cell == cell:
			value += STRONGHOLD_HOLD_VALUE * _battle.stronghold_holds[_me]
	elif _takes_stronghold and Combat.distance(cell, _board.stronghold_cell) <= Stronghold.CONTEST_RADIUS:
		var holder := _battle.unit_at(_board.stronghold_cell)
		if holder != null and holder.side == _foe and Stronghold.counts(holder):
			value += STRONGHOLD_BLOCK_VALUE
	if _battle.formation:
		if Formation.guarded_at(_battle, unit, cell):
			value += SQUAD_HUDDLE_VALUE
		var partner := Formation.partner_of(_battle, unit)
		if partner != null and Combat.distance(partner.cell, cell) <= Formation.OATH_RANGE:
			value += OATH_NEAR_VALUE
	var knot := Monsters.knot_at(_battle, cell)
	if knot != null and knot.side != _me:
		value += KNOT_STEP_VALUE
	var threat := _threat_at(unit, cell, ignored_id)
	value -= (_danger_weight if acting else _idle_danger_weight) * threat
	if threat >= unit.hp:
		value -= _lethal_penalty
	return value


## 後衛が砲台（docs/map-objects.md）へ寄る・居座る重み。空いている（か自分が乗っている）砲台で、
## 伸びた射程 + BATTERY_WATCH の中に相手の駒がいるものへ、歩数 BATTERY_STEPS までの所から引かれる。砲台の無い盤では 0。
func _battery_pull(unit: Unit, cell: Vector2i) -> float:
	if _board.battery_cells.is_empty() or UnitKind.role(unit.kind) != UnitKind.Role.REARGUARD:
		return 0.0
	var best := 0.0
	var reach := _unhazed(unit, func() -> int: return unit.attack_range()) - unit.site_range + MapObject.BATTERY_RANGE
	if unit.hazed:
		reach = Seam.hazed_range(reach)
	for battery in _board.battery_cells:
		var holder := _battle.unit_at(battery)
		if holder != null and holder != unit:
			continue
		var steps := _steps_from(battery)[cell.y * _board.size.x + cell.x]
		if steps > BATTERY_STEPS:
			continue
		var watched := false
		for other in _battle.units:
			if other.side == _foe and Combat.distance(other.cell, battery) <= reach + BATTERY_WATCH:
				watched = true
				break
		if watched:
			best = maxf(best, BATTERY_VALUE - BATTERY_STEP_COST * steps)
	return best


## unit の目標（どこへ近づきたいか）を決めて、_goal_steps、_goal_reach、役割ごとの重み、_stand_off に置く。
## - 将: 自分の本陣。戦える駒が 1 体も残っていなければ、前衛と同じに敵へ向かう
## - 奇襲: 敵の本陣（敵が乗っていれば、そこを攻撃できるところまで）
## - 前衛・後衛: 自分の本陣の近くに入った敵（侵入者）がいれば、そのいちばん近いもの。いなければ、いちばん近い敵の駒
## - 回復: 近くの減っている味方（減っている割合がいちばん大きいもの）。いなければ、いちばん近い味方の戦う駒
## - 相手の駒が 1 体も残っていない（占拠でしか勝てない話）: 回復と、戦える駒の残っている軍の将のほかは、敵の本陣
func _set_goal(unit: Unit) -> void:
	var role := UnitKind.role(unit.kind)
	_lone_king = unit.kind == UnitKind.Id.KING and not _has_fighters()
	var style: Array = LONE_KING_STYLE if _lone_king else STYLES[role]
	_goal_weight = style[_GOAL]
	_danger_weight = style[_DANGER]
	var bold := clampf(float(_battle.turn - BOLD_FROM_TURN) / (BOLD_BY_TURN - BOLD_FROM_TURN), 0.0, 1.0)
	if _rushing:
		bold = 1.0  # 守り切られる前に、踏み込む
	_idle_danger_weight = lerpf(style[_IDLE_DANGER], minf(style[_DANGER], style[_IDLE_DANGER]), bold)
	_lethal_penalty = style[_LETHAL]
	_stand_off = role == UnitKind.Role.REARGUARD
	_support = []
	var goal := _my_hq if _my_hq != Board.NO_CELL else unit.cell
	_goal_reach = 0
	if unit.kind == UnitKind.Id.KING and not _lone_king:
		pass
	elif _holding and role != UnitKind.Role.HEALER:
		# 守る側: 本陣の近くに入った敵だけを追い、ほかは本陣のそばで待つ。
		var enemy := _enemy_to_hold_off(unit)
		if enemy != null:
			goal = enemy.cell
			_goal_reach = unit.attack_range()
		else:
			_goal_reach = CpuWinPlan.HOLD_REACH
	elif (
		_rushing and role != UnitKind.Role.HEALER and _foe_king() != null
		and not (role == UnitKind.Role.RAIDER and _can_raid_hq(unit))
	):
		# 攻める側で、残りのターンが少ない: 敵の将へ向かう。
		goal = _foe_king().cell
		_goal_reach = unit.attack_range()
	elif role == UnitKind.Role.RAIDER:
		var prey := _prey(unit)
		var boss := _boss_to_hunt(unit)
		if boss == null:
			boss = _boss_to_steal(unit)
		if _can_raid_hq(unit):
			goal = _foe_hq
		elif boss != null:
			goal = boss.cell
			_goal_reach = unit.attack_range()
		elif prey != null:
			goal = prey.cell
			_goal_reach = unit.attack_range()
			for other in _battle.units:
				if other.side == _me and other != unit and UnitKind.role(other.kind) in SUPPORT_ROLES:
					_support.append(other.cell)
	elif role == UnitKind.Role.HEALER:
		var friend := _friend_to_follow(unit)
		if friend != null:
			goal = friend.cell
			_goal_reach = unit.attack_range()
	else:
		var enemy := _enemy_to_chase(unit)
		var boss: Unit = null if _lone_king else _boss_to_hunt(unit)
		if boss == null and role == UnitKind.Role.REARGUARD:
			boss = _boss_to_steal(unit)
		if boss != null:
			goal = boss.cell
			_goal_reach = unit.attack_range()
		elif enemy != null:
			goal = enemy.cell
			_goal_reach = unit.attack_range()
	if _takes_stronghold and unit.kind != UnitKind.Id.KING and role != UnitKind.Role.HEALER:
		# 拠点: 待てば相手が確保を進めるので、戦う駒は動くだけの手の危険を、攻撃する手の重さで見る（長引いたときの踏み込みと同じ）。
		# 相手が拠点に乗っていれば、乗っている駒を追う。そうでなければ、受け持ちの 1 体（_choose_stronghold_taker）が拠点へ向かう。
		_choose_stronghold_taker()
		_idle_danger_weight = minf(_danger_weight, _idle_danger_weight)
		var holder := _battle.unit_at(_board.stronghold_cell)
		if holder != null and holder.side == _foe and Stronghold.counts(holder):
			goal = holder.cell
			_goal_reach = unit.attack_range()
			_stand_off = false
		elif unit.id == _stronghold_taker:
			goal = _board.stronghold_cell
			_goal_reach = 0
			_stand_off = false
	if _foe_hq != Board.NO_CELL and role != UnitKind.Role.HEALER and not _foes_left() and (unit.kind != UnitKind.Id.KING or _lone_king):
		# 相手の駒が残っていなくても終わらない（占拠でしか勝てない）: 追う敵がいないので、敵の本陣へ向かう。
		goal = _foe_hq
		_goal_reach = 0
	_goal_steps = _steps_from(goal)


## 守る側の前衛・後衛・奇襲が追う敵: 自分の本陣から CpuWinPlan.HOLD_RADIUS 以内の敵のうち、侵入者を先に、その中でいちばん近いもの。
## いなければ null（本陣のそばで待つ）。
func _enemy_to_hold_off(unit: Unit) -> Unit:
	if _my_hq == Board.NO_CELL:
		return null
	var best: Unit = null
	var best_key := Vector2i(_FAR, _FAR)
	for other in _battle.units:
		if other.side != _foe or Combat.distance(other.cell, _my_hq) > CpuWinPlan.HOLD_RADIUS:
			continue
		var intruder := Combat.distance(other.cell, _my_hq) <= DEFENSE_RADIUS
		var key := Vector2i(0 if intruder else 1, Combat.distance(unit.cell, other.cell))
		if key < best_key:
			best = other
			best_key = key
	return best


## 相手の将。いなければ null。
func _foe_king() -> Unit:
	for other in _battle.units:
		if other.side == _foe and other.kind == UnitKind.Id.KING:
			return other
	return null


## 相手の軍の駒（将を含む）が、1 体でも残っているか。
func _foes_left() -> bool:
	for other in _battle.units:
		if other.side == _foe:
			return true
	return false


## 自分の軍に、戦える駒（前衛・後衛・奇襲）が残っているか。
func _has_fighters() -> bool:
	for other in _battle.units:
		if other.side == _me and other.kind != UnitKind.Id.KING and UnitKind.role(other.kind) != UnitKind.Role.HEALER:
			return true
	return false


## 奇襲が、敵の本陣へ乗りに行くか。もう乗っているか、本陣が空いていて、RAID_STEPS 歩以内で、
## いまそこに立っても倒されない（危険の見積もりが HP より小さい）とき。_build_threats のあとに呼ぶ。
func _can_raid_hq(unit: Unit) -> bool:
	if _foe_hq == Board.NO_CELL:
		return false
	if unit.cell == _foe_hq:
		return true
	if _battle.unit_at(_foe_hq) != null:
		return false
	if _steps_from(_foe_hq)[unit.cell.y * _board.size.x + unit.cell.x] > RAID_STEPS:
		return false
	return _threat_at(unit, _foe_hq, 0) < unit.hp


## 奇襲が狙う敵。やわらかい駒（後衛・回復）を先に、次に奇襲、最後に前衛と将。同じなら、歩数の近いもの。
func _prey(unit: Unit) -> Unit:
	var from := _steps_from(unit.cell)
	var width := _board.size.x
	var best: Unit = null
	var best_key := Vector2i(_FAR, _FAR)
	for other in _battle.units:
		if other.side != _foe:
			continue
		var rank := 2
		match UnitKind.role(other.kind):
			UnitKind.Role.REARGUARD, UnitKind.Role.HEALER:
				rank = 0
			UnitKind.Role.RAIDER:
				rank = 1
		# 駒のいるマスは歩数の表で通れるので、そのマスまでの歩数で測る。
		var key := Vector2i(rank, from[other.cell.y * width + other.cell.x])
		if key < best_key:
			best = other
			best_key = key
	return best


## 前衛・後衛（と、戦える駒のいなくなった軍の将）が向かう敵（プレイヤーの駒）。侵入者を先に、その中でいちばん近いもの（マンハッタン距離）。
func _enemy_to_chase(unit: Unit) -> Unit:
	var best: Unit = null
	var best_key := Vector2i(_FAR, _FAR)
	for other in _battle.units:
		if other.side != _foe:
			continue
		var intruder := _my_hq != Board.NO_CELL and Combat.distance(other.cell, _my_hq) <= DEFENSE_RADIUS
		var key := Vector2i(0 if intruder else 1, Combat.distance(unit.cell, other.cell) - _poacher_pull(unit, other))
		if key < best_key:
			best = other
			best_key = key
	return best


## 相手が狩っている中ボスのそばの相手の駒（狩りの最中）は、DENY_PULL マスぶん近いものとして追う（取らせない）。
func _poacher_pull(unit: Unit, foe: Unit) -> int:
	_build_hunts()
	for boss_id in _rival_hunts:
		var boss := _battle.unit_by_id(boss_id)
		if Combat.distance(foe.cell, boss.cell) <= HUNT_RIVAL_RADIUS and Combat.distance(unit.cell, boss.cell) <= DENY_RADIUS:
			return DENY_PULL
	return 0


## 回復役がついて行く味方。
func _friend_to_follow(unit: Unit) -> Unit:
	var from := _steps_from(unit.cell)
	var width := _board.size.x
	var wounded: Unit = null
	var wounded_rate := 1.0
	var nearest: Unit = null
	var nearest_steps := _FAR
	var king: Unit = null
	for other in _battle.units:
		if other.side != _me or other == unit:
			continue
		var steps := from[other.cell.y * width + other.cell.x]
		var rate := float(other.hp) / other.max_hp()
		if rate < wounded_rate and steps <= HEALER_SEARCH_STEPS:
			wounded = other
			wounded_rate = rate
		if other.kind == UnitKind.Id.KING:
			king = other
		elif UnitKind.role(other.kind) != UnitKind.Role.HEALER and steps < nearest_steps:
			nearest = other
			nearest_steps = steps
	if wounded != null:
		return wounded
	return nearest if nearest != null else king


## 拠点へ向かう駒（戦う駒 = 前衛・後衛・奇襲のうち、拠点までの歩数がいちばん近いもの。同じなら番号の小さいもの）を決めて _stronghold_taker に置く。
## 自分の駒が拠点に乗っていれば、その駒。1 手を考えるたびに、最初に要ったときに決める。
func _choose_stronghold_taker() -> void:
	if _stronghold_taker != 0:
		return
	_stronghold_taker = -1
	var cell := _board.stronghold_cell
	var holder := _battle.unit_at(cell)
	if holder != null and holder.side == _me and Stronghold.counts(holder):
		_stronghold_taker = holder.id
		return
	var steps := _steps_from(cell)
	var best := _FAR
	for other in _battle.units:
		if other.side != _me or other.kind == UnitKind.Id.KING or UnitKind.role(other.kind) == UnitKind.Role.HEALER:
			continue
		var far := steps[other.cell.y * _board.size.x + other.cell.x]
		if far >= 0 and far < best:
			best = far
			_stronghold_taker = other.id
