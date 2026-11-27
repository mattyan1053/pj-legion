class_name CpuPlayer
extends "res://rules/cpu/cpu_position_value.gd"
## CPU の思考（docs/cpu-ai.md）。いまの対戦を見て、次の行動を 1 つ返す。
##
##   var cpu := CpuPlayer.new()
##   battle.apply(cpu.next_action(battle))
##
## - 対戦の状態は変えない。返す行動は、いまのフェーズのプレイヤーのもの
## - 選べることは Battle.options() に聞き、行動の結果は Battle.clone() に apply() して、起きたこと（イベント）から読む。
##   ルールの計算（射程、ダメージ、移動範囲）をここに書き写さない。ルールが変われば、CPU の読みもそのまま変わる
## - ここが自分で持つのは「どの手が良いか」の見積もり（調整値）と、候補を絞るための目安だけ
## - 乱数は使わない。同じ状態からは、いつも同じ行動を返す（Battle.rng も進めない）
##
## 覚えているのは、盤面の歩けるマスと歩数の表だけ（速くするためで、判断には影響しない）。
## 1 つのインスタンスを、どの対戦・どちらのプレイヤーにも使い回せる。
##
## ここは、判断の流れ（次の行動、駒を選ぶ、動く前と動いたあとの手、進化先、必殺技、候補の手）だけ。
## 評価の種類ごとのファイル（rules/cpu/）: 調整値と状態と歩数の表（cpu_player_base）、危険なマス（cpu_threats）、
## 行動の結果の価値（cpu_outcome_value）、位置の価値と目標（cpu_position_value）。スキルごとの見積もりは rules/cpu/<スキル>_cpu.gd。
## ファイルは cpu_player_base.gd からこの順に継いで積み重なり、このファイルが最後（前のファイルは、後のファイルの関数を呼べない）。


## いまのフェーズのプレイヤーの、次の行動。決着のあとと中立のフェーズでは null。
## 返す行動は、必ず Battle.can_apply() が受け付ける。
func next_action(battle: Battle) -> BattleAction:
	if battle.is_over() or battle.phase == Unit.Side.NEUTRAL:
		return null
	_begin(battle)
	var action := _decide()
	_battle = null
	if action != null and battle.can_apply(action):
		return action
	return _fallback(battle)


## いまのフェーズのプレイヤーの駒 unit_id が cell に立っているとして、次の相手の番（と中立のフェーズ）に受けうるダメージの見積もり。
## CPU が立つマスを選ぶのに使っている値（docs/cpu-ai.md の「危険の見積もり」）。対戦の状態は変えない。
func danger(battle: Battle, unit_id: int, cell: Vector2i) -> int:
	var unit := battle.unit_by_id(unit_id)
	if unit == null or unit.side != battle.phase or battle.phase == Unit.Side.NEUTRAL or battle.is_over():
		return 0
	_begin(battle)
	_build_threats()
	var result := _threat_at(unit, cell, 0)
	_battle = null
	return result


func _decide() -> BattleAction:
	var evolving := _battle.evolving_unit()
	if evolving != null:
		return _choose_evolution(evolving)
	# 決めた移動の続き（転移と、その先の移動）は、ほかの手より先に返す（移動 1 回ぶんの手として決めたものなので、間に挟まない）。
	var acting := _battle.unit_by_id(_battle.acting_unit_id)
	var step := _next_route_step(acting)
	if step != null:
		return step
	if Ults.can_use(_battle) and call(ULT_USES[Ults.of(_battle, _me).id()]):
		return UseUltAction.new()
	if acting != null:
		return _follow_up(acting)
	var card := CpuCards.pick(_battle)  # 手札（試しの決まり）。入でなければ、いつも null
	if card != null:
		return card
	var unit := _next_unit()
	if unit == null:
		return EndPhaseAction.new()
	return _plan(unit)


## 決めた移動の続き（_route）の次の行動。続きが無いか、ずれていれば null（続きは捨てる）。
func _next_route_step(acting: Unit) -> BattleAction:
	if _route.is_empty():
		return null
	var step: Array = _route.pop_front()
	var action: BattleAction = step[2]
	if acting == null or acting.id != step[0] or acting.cell != step[1] or not _battle.can_apply(action):
		_route = []
		return null
	return action


## unit が to へ動く行動の列（Movement.route）を、複製した対戦 sim に順に当てる。全部受け付けられたか。
static func _move_in(sim: Battle, unit_id: int, to: Vector2i, cruise := false) -> bool:
	var unit := sim.unit_by_id(unit_id)
	var actions := Movement.route(sim, unit, to, cruise)
	if actions.is_empty():
		return false
	for action in actions:
		if not sim.apply(action).accepted:
			return false
	return true


## unit が行動の始めから、移動と転移を続けて止まれるマス（Movement.search の through_portals）。
## [通常の移動で届くマス, 巡航でだけ届くマス]（どちらもマス -> 移動力）。
static func _reach(battle: Battle, unit: Unit) -> Array[Dictionary]:
	var normal: Dictionary[Vector2i, int] = {}
	var cruise: Dictionary[Vector2i, int] = {}
	var stops := Movement.search(battle, unit, true, true).stops()
	var limit := Movement.budget(unit, false)
	for cell: Vector2i in stops:
		if stops[cell] <= limit:
			normal[cell] = stops[cell]
		else:
			cruise[cell] = stops[cell]
	return [normal, cruise]


## 考えた行動が受け付けられなかったときの逃げ道（ふつうは通らない）。待機できる駒を待機させ、いなければフェーズを終える。
func _fallback(battle: Battle) -> BattleAction:
	var evolving := battle.evolving_unit()
	if evolving != null:
		return battle.options(evolving.id).actions()[0]
	for unit in battle.units:
		if battle.can_act(unit):
			return WaitAction.new(unit.id)
	return EndPhaseAction.new()


func _begin(battle: Battle) -> void:
	_battle = battle
	_me = battle.phase
	_foe = (1 - _me) as Unit.Side
	_threats = {}
	_close_threats = {}
	_smoked = {}
	_foe_stops = {}
	_moved_threats = {}
	_stand = Board.NO_CELL
	_threats_ready = false
	_hunts_ready = false
	_thinking_id = 0
	var board := battle.board
	var has_hqs := board.hq_cells.size() >= 2
	_my_hq = board.hq_cells[_me] if has_hqs else Board.NO_CELL
	# 本陣の占拠で勝てないなら、敵の本陣は目指すマスでない。
	_foe_hq = board.hq_cells[_foe] if has_hqs and CpuWinPlan.raids_hq(battle, _me) else Board.NO_CELL
	_holding = CpuWinPlan.holds(battle, _me)
	_takes_stronghold = Stronghold.holds_left(battle, _me) != -1 and Stronghold.holds_left(battle, _foe) != -1
	_stronghold_taker = 0
	_rushing = CpuWinPlan.rushes(battle, _me)
	_slays_bosses = battle.wins_by(_me, GameWonEvent.Reason.BOSS_SLAIN)
	for unit in battle.units:
		if unit.side == _foe and unit.kind == UnitKind.Id.KING:
			_slays_bosses = false
	_hq_in_danger = false
	_keeps_hq = has_hqs and CpuWinPlan.guards_hq(battle, _me) and battle.armies[_foe] == UnitKind.Army.NONE
	var keeper := battle.unit_at(_my_hq) if has_hqs else null
	if has_hqs and CpuWinPlan.guards_hq(battle, _me) and (keeper == null or keeper.kind != UnitKind.Id.KING):
		for unit in battle.units:
			if unit.side == _foe and Combat.distance(unit.cell, _my_hq) <= GUARD_RADIUS:
				_hq_in_danger = true
	# 駒が乗っているポータルは、いまは通れない（Battle.portal_exit）。通れる前提で道を見積もると、
	# ふさがったポータルの前で待ち続けてしまう。
	var blocked: Array[Vector2i] = []
	for cell in board.portal_exits:
		if battle.unit_at(cell) != null:
			blocked.append(cell)
	if board != _board or board.walkable_revision != _walkable_revision or blocked != _blocked_portals:
		# 盤面が替わったか、入れるマスが変わった（樽が消えた、盾が置かれた・消えた）か、ふさがったポータルが変わった。
		_board = board
		_walkable_revision = board.walkable_revision
		_blocked_portals = blocked
		_steps = {}
		_walkable.resize(board.size.x * board.size.y)
		for y in board.size.y:
			for x in board.size.x:
				_walkable[y * board.size.x + x] = 1 if board.move_cost(Vector2i(x, y)) >= 0 else 0


## 進化先を選ぶ。駒とターンで A・B を選び分ける（どちらの型も盤に出るように）。
func _choose_evolution(unit: Unit) -> BattleAction:
	var choices := _battle.options(unit.id).evolutions
	if choices.is_empty():
		return null
	return EvolveAction.new(unit.id, choices[(unit.id + _battle.turn) % choices.size()])


## 総員突撃を、いま使うか。まだ行動していない戦う駒（前衛・後衛・奇襲。1 体もいなければ将）のうち、
## 伸びた移動力 + 射程の中に敵の駒がいる駒を数える。
func _assault_pays() -> bool:
	var fighters := 0
	var ready := 0
	var lone := not _has_fighters()
	for unit in _battle.units:
		if unit.side != _me:
			continue
		var role := UnitKind.role(unit.kind)
		if role == UnitKind.Role.HEALER or (unit.kind == UnitKind.Id.KING and not lone):
			continue
		fighters += 1
		if unit.acted or unit.has_moved:
			continue
		var reach := unit.move_range() + AllOutAssaultUlt.MOVE_BONUS + Statuses.stat_after_move(unit, Unit.Stat.ATTACK_RANGE)
		if _nearest_foe_distance(unit) <= reach:
			ready += 1
	return ready > 0 and ready >= mini(ASSAULT_MIN_UNITS, fighters)


## 魔力解放を、いま使うか。まだ行動していない駒のうち、クールダウンが長く残っていて、敵の駒が近くにいる駒を数える。
func _eruption_pays() -> bool:
	var holders := 0
	var waiting := 0
	for unit in _battle.units:
		if unit.side != _me or Skills.of(unit) == null or Skills.uses_left(unit) == 0:
			continue
		holders += 1
		if unit.acted or unit.cruised or unit.skill_cooldown < ERUPTION_MIN_COOLDOWN:
			continue
		if _nearest_foe_distance(unit) <= ERUPTION_RADIUS:
			waiting += 1
	return waiting > 0 and waiting >= mini(ERUPTION_MIN_UNITS, holders)


## 次に動かす駒。役割の順（ROLE_ORDER）、同じ役割なら番号の順。いなければ null。
func _next_unit() -> Unit:
	var best: Unit = null
	var best_key := Vector2i(_FAR, 0)
	for unit in _battle.units:
		if not _battle.can_act(unit):
			continue
		var key := Vector2i(ROLE_ORDER.find(UnitKind.role(unit.kind)), unit.id)
		if key < best_key:
			best = unit
			best_key = key
	return best


## 動いたあとの駒が、いまの位置からすること。得になる攻撃・回復・スキルがあれば、いちばん良いもの。無ければ待機。
func _follow_up(unit: Unit) -> BattleAction:
	var best: BattleAction = WaitAction.new(unit.id)
	var best_value := 0.0
	_thinking_id = unit.id
	_build_threats()
	_set_goal(unit)
	_moved_reach = _unhazed(unit, func() -> int: return unit.attack_range())
	var here: Dictionary[Vector2i, float] = {unit.cell: 0.0}
	var wanted := _wanted_skill_targets(unit, here)
	var skill := Skills.of(unit)
	var limited := skill != null and CpuSkillEstimate.of(skill.id()) != null
	var options := _battle.options(unit.id)
	var healer := UnitKind.role(unit.kind) == UnitKind.Role.HEALER
	for action in options.actions():
		if action is MoveAction or action is WarpAction or action is WaitAction or action is UndoMoveAction:
			continue
		if healer and _healer_holds_fire(action, options):
			continue
		var skill_use := action as UseSkillAction
		if skill_use != null and limited and not wanted.has(skill_use.target):
			continue
		var sim := _battle.clone()
		var value := _outcome_value(sim, sim.apply(action).events)
		if value > best_value:
			best = action
			best_value = value
	return best


## 回復役が、この攻撃の手を見送るか。治せる味方がいれば攻撃しない。樽と盾は撃たない（_candidates と同じ）。
func _healer_holds_fire(action: BattleAction, options: UnitOptions) -> bool:
	if action is AttackBarrelAction or action is AttackBarricadeAction:
		return true
	return action is AttackAction and not options.heal_target_ids.is_empty()


## まだ動いていない駒の、次の行動。「どこへ動くか」と「そこで何をするか」の組をすべて比べて、最初の 1 手を返す。
## 動く先を決めたら、そこで何をするかは次の呼び出し（_follow_up）がもう一度決める（同じ見積もりを使うので、同じ結論になる）。
func _plan(unit: Unit) -> BattleAction:
	var options := _battle.options(unit.id)
	var reach := _reach(_battle, unit)
	_thinking_id = unit.id
	_build_threats()
	_set_goal(unit)
	_moved_reach = _unhazed(unit, func() -> int: return Statuses.stat_after_move(unit, Unit.Stat.ATTACK_RANGE))

	# 動くだけ（待機）の手。
	var best_cell := unit.cell
	var best_cruise := false
	var best_action: BattleAction = null
	var best_value := _position_value(unit, unit.cell, 0, false)
	var positions: Dictionary[Vector2i, float] = {}
	for cell: Vector2i in reach[0]:
		var value := _position_value(unit, cell, 0, false)
		positions[cell] = value
		if value > best_value:
			best_cell = cell
			best_value = value
	for cell: Vector2i in reach[1]:
		var value := _position_value(unit, cell, 0, false) - CRUISE_PENALTY
		if value > best_value:
			best_cell = cell
			best_cruise = true
			best_value = value

	# 動いて（動かずに）攻撃・回復する手。
	for candidate in _candidates(unit, positions):
		var action: BattleAction = candidate[0]
		var at: Vector2i = candidate[1]
		var target_id: int = candidate[2]
		var from := _best_cell_in_reach(unit, positions, at, target_id, 0, action is AttackBarrelAction)
		if from == Board.NO_CELL:
			continue
		# その手を複製の上で実際にやってみて、起きたことから価値を読む。
		var sim := _battle.clone()
		if from != unit.cell and not _move_in(sim, unit.id, from):
			continue
		var result := sim.apply(action)
		if not result.accepted:
			continue  # 目安では届くはずが、ルールでは届かなかった
		var value := _outcome_value(sim, result.events)
		if value <= 0.0:
			continue
		if target_id != 0 and sim.unit_by_id(target_id) == null:
			# 相手を倒せる。その相手からの反撃は無いものとして、立つマスを選び直す。
			from = _best_cell_in_reach(unit, positions, at, target_id, target_id, false)
			value += _position_value(unit, from, target_id, true)
		else:
			value += _position_value(unit, from, 0, true)
		if value > best_value:
			best_cell = from
			best_cruise = false
			best_action = action
			best_value = value

	# 動いて（動かずに）スキルを使う手。
	for candidate in _skill_candidates(unit, options, positions):
		var from: Vector2i = candidate[0]
		var action := UseSkillAction.new(unit.id, candidate[1])
		var sim := _battle.clone()
		if from != unit.cell and not _move_in(sim, unit.id, from):
			continue
		var result := sim.apply(action)
		if not result.accepted:
			continue  # 目安では使えるはずが、ルールでは使えなかった
		_stand = from
		var value := _outcome_value(sim, result.events)
		_stand = Board.NO_CELL
		if value <= 0.0:
			continue
		value += _position_value(unit, from, 0, true)
		if value > best_value:
			best_cell = from
			best_cruise = false
			best_action = action
			best_value = value

	if best_cell != unit.cell:
		return _start_route(unit, best_cell, best_cruise)
	if best_action != null:
		return best_action
	return WaitAction.new(unit.id)


## unit を to へ動かす行動の列（Movement.route）の最初の 1 手を返し、続きを _route に覚える。
func _start_route(unit: Unit, to: Vector2i, cruise: bool) -> BattleAction:
	_route = []
	var actions := Movement.route(_battle, unit, to, cruise)
	if actions.is_empty():
		return MoveAction.new(unit.id, to, cruise)  # ふつうは通らない（next_action が受け付けられるかを見る）
	var sim := _battle.clone()
	for i in actions.size():
		if i > 0:
			_route.append([unit.id, sim.unit_by_id(unit.id).cell, actions[i]])
		sim.apply(actions[i])
	return actions[0]


## スキルを使う手の候補。[立つマス, 対象のマス] の列。対象ごとに、そこを選べるマスのうち、立つマスの価値がいちばん高いもの。
## - 対象は、スキルごとの「選ぶ価値のありそうなマス」（rules/cpu/ の targets）に絞る
## - いまのマスから選べる対象は Battle.options() の skill_cells。ほかのマスからは、そこへ動いた写しの駒でスキルの定義に聞く
##   （Skill.is_ready、Skill.target_cells）。広めに並べるだけで、使えるかどうかは _plan が複製の上で確かめる
func _skill_candidates(unit: Unit, options: UnitOptions, positions: Dictionary[Vector2i, float]) -> Array[Array]:
	var result: Array[Array] = []
	var skill := Skills.of(unit)
	if skill == null or not Skills.can_use(_battle, unit):
		return result
	var limited := CpuSkillEstimate.of(skill.id()) != null
	var wanted := _wanted_skill_targets(unit, positions)
	if limited and wanted.is_empty():
		return result
	var best_from: Dictionary[Vector2i, Vector2i] = {}
	var best_value: Dictionary[Vector2i, float] = {}
	var probe := unit.copy()
	probe.has_moved = true
	probe.move_origin = unit.cell
	for cell in positions:
		var targets := options.skill_cells
		if cell != unit.cell:
			probe.cell = cell
			if not skill.is_ready(_battle, probe):
				continue
			targets = skill.target_cells(_battle, probe)
		var value := _position_value(unit, cell, 0, true)
		for target in targets:
			if limited and not wanted.has(target):
				continue
			if value > best_value.get(target, -INF):
				best_value[target] = value
				best_from[target] = cell
	for target in best_from:
		result.append([best_from[target], target])
	return result


## unit のスキルの、対象に選ぶ価値のありそうなマス（rules/cpu/ の targets の答え）。
## スキルを持たない・いま使えない駒と、rules/cpu/ に見積もりの無いスキルでは空（載せていないスキルは、呼ぶ側が絞らずに全部試す）。
## cells は、unit が立つかもしれないマス（_plan では通常の移動で止まれるマス、_follow_up ではいまのマスだけ）。
func _wanted_skill_targets(unit: Unit, cells: Dictionary[Vector2i, float]) -> Dictionary[Vector2i, bool]:
	var skill := Skills.of(unit)
	var wanted: Dictionary[Vector2i, bool] = {}
	if skill == null or CpuSkillEstimate.of(skill.id()) == null or not Skills.can_use(_battle, unit):
		return wanted
	_build_threats()
	wanted = CpuSkillEstimate.of(skill.id()).targets(self, unit, cells)
	return wanted


## 攻撃・回復の候補。[行動, 相手のマス, 相手の駒の番号（樽と盾は 0）] の列。
## cells（通常の移動で止まれるマス。ポータルの先も含む）のどれかから、射程の歩数の中にいる相手を並べる。
## 広めに並べるだけで、届くかどうかはルールに聞く（_plan が複製の上で確かめる）。
func _candidates(unit: Unit, cells: Dictionary[Vector2i, float]) -> Array[Array]:
	var result: Array[Array] = []
	var healer := UnitKind.role(unit.kind) == UnitKind.Role.HEALER
	var attacks: Array[Array] = []
	for other in _battle.units:
		if other == unit or not _in_reach(unit, cells, other.cell):
			continue
		if healer and other.side == _me:
			if other.hp < other.max_hp():
				result.append([HealAction.new(unit.id, other.id), other.cell, other.id])
		elif other.side != _me:
			attacks.append([AttackAction.new(unit.id, other.id), other.cell, other.id])
	# 回復役は、このターンに治せる味方がいないときだけ攻撃する（駒だけ。樽と盾は撃たない）。
	if healer:
		if result.is_empty():
			result.append_array(attacks)
		return result
	result.append_array(attacks)
	for cell in _battle.board.barrel_cells:
		if _in_reach(unit, cells, cell):
			result.append([AttackBarrelAction.new(unit.id, cell), cell, 0])
	for effect in _battle.board.field_effects:
		if effect.type == FieldEffect.Type.BARRICADE and effect.side != _me and _in_reach(unit, cells, effect.center):
			result.append([AttackBarricadeAction.new(unit.id, effect.center), effect.center, 0])
	return result


## cells のどれかから、at が射程の歩数の中にあるか。
func _in_reach(unit: Unit, cells: Dictionary[Vector2i, float], at: Vector2i) -> bool:
	for cell in cells:
		if Combat.distance(cell, at) <= _reach_from(unit, cell):
			return true
	return false


## unit が cell から手を出すときの射程。いまのマスなら、いまの射程。ほかのマスなら、動いたあとの射程。
func _reach_from(unit: Unit, cell: Vector2i) -> int:
	if cell == unit.cell:
		return unit.attack_range()
	var reach := _moved_reach - unit.site_range + MapObject.battery_bonus(_board, unit, cell)
	return Seam.hazed_range(reach) if unit.hazed else reach


## cells（通常の移動で止まれるマス）のうち、at に手が届き、そこで手を出すのにいちばん良いマス。無ければ Board.NO_CELL。
## 攻撃は、間に盾があるマスと、相手（target_id の駒。樽と盾なら 0）が煙幕に守られるマスを除く（ルールの問い合わせで見る）。
## ignored_id の敵からの危険は数えない。avoid_blast が真なら、at の周り 8 マス（樽の爆発が届く）をなるべく避ける。
func _best_cell_in_reach(
	unit: Unit, cells: Dictionary[Vector2i, float], at: Vector2i, target_id: int, ignored_id: int, avoid_blast: bool
) -> Vector2i:
	var target := _battle.unit_by_id(target_id)
	var healing := UnitKind.role(unit.kind) == UnitKind.Role.HEALER and target != null and target.side == _me
	var best := Board.NO_CELL
	var best_value := -INF
	for cell in cells:
		var reach := _reach_from(unit, cell)
		if healing:
			if Combat.distance(cell, at) > reach:
				continue
		elif not Combat.reaches(_battle, cell, at, reach):
			continue
		elif target != null and FieldEffects.smoke_covering(_battle, cell, target) != null:
			continue
		var value := _position_value(unit, cell, ignored_id, true)
		if avoid_blast and maxi(absi(cell.x - at.x), absi(cell.y - at.y)) <= 1:
			value -= WIN_VALUE
		if value > best_value:
			best = cell
			best_value = value
	return best
