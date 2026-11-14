class_name CpuPlayer
extends RefCounted
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

# ---- 調整値（docs/cpu-ai.md の「調整値」） ----

## 駒を動かす順（役割）。奇襲 → 後衛 → 前衛 → 回復 → 将。
const ROLE_ORDER: Array[UnitKind.Role] = [
	UnitKind.Role.RAIDER, UnitKind.Role.REARGUARD, UnitKind.Role.VANGUARD, UnitKind.Role.HEALER, UnitKind.Role.NONE,
]
## 役割 -> [目標へ 1 マス近づく価値, 受けうるダメージ 1 の重さ（攻撃・回復する手）, 同（動くだけの手）, 倒されうるマスの減点]。
## 動くだけの手のほうが重い: 手を出さずに敵の届くマスへ入ると、先に殴られるだけになる。前衛は構わず前へ出て、盾になる。
const STYLES := {
	UnitKind.Role.NONE: [8.0, 1.0, 1.0, 5000.0],  # 将。倒されうるマスには立たない。それ以外は本陣を空けない
	UnitKind.Role.VANGUARD: [4.0, 0.15, 0.15, 10.0],
	UnitKind.Role.REARGUARD: [4.0, 0.5, 1.5, 25.0],
	UnitKind.Role.RAIDER: [4.0, 0.35, 1.0, 20.0],
	UnitKind.Role.HEALER: [3.0, 0.8, 1.5, 30.0],
}
## 戦える駒（前衛・後衛・奇襲）が 1 体も残っていないときの将。待っていても勝てないので、自分で敵へ向かう。
const LONE_KING_STYLE: Array[float] = [4.0, 0.3, 0.3, 5000.0]
## 長引いたら踏み込む: このターンから、動くだけの手の危険の重さを、攻撃する手の重さへ少しずつ近づける（BOLD_BY_TURN で同じになる）。
## 互いに相手の届くマスの外で待ち合って、いつまでも決着しないのを防ぐ。
const BOLD_FROM_TURN := 20
const BOLD_BY_TURN := 40
## 勝ちが決まる手、引き分けになる手の価値（負けが決まる手は、勝ちの逆）。
const WIN_VALUE := 1000000.0
const DRAW_VALUE := -100000.0
## ダメージ 1 の価値。プレイヤーの駒、将、中立の駒。
const DAMAGE_VALUE := 2.0
const KING_DAMAGE_VALUE := 6.0
const NEUTRAL_DAMAGE_VALUE := 0.5
## 倒す価値。プレイヤーの駒は KILL_VALUE + コスト × KILL_VALUE_PER_COST。回復役は HEALER_KILL_BONUS を足す。
const KILL_VALUE := 60.0
const KILL_VALUE_PER_COST := 10.0
const HEALER_KILL_BONUS := 10.0
const NEUTRAL_KILL_VALUE := 15.0
## 倒せなかった相手に残る HP 1 の減点（HP の少ない相手を先に狙う）。
const REMAINING_HP_PENALTY := 0.2
## 自分の本陣からこの距離までに入った敵は「侵入者」。与えるダメージの価値を INTRUDER_RATE 倍にする。
const DEFENSE_RADIUS := 5
const INTRUDER_RATE := 1.5
## 自分の本陣に乗っている敵。ダメージの価値を OCCUPIER_RATE 倍にし、倒す価値に OCCUPIER_KILL_BONUS を足す。
const OCCUPIER_RATE := 2.0
const OCCUPIER_KILL_BONUS := 100.0
## 相手の盾を削る価値（耐久力 1 あたり）と、壊す価値。駒を攻撃できないときに、道をふさぐ盾を壊しに行く程度。
const BARRICADE_DAMAGE_VALUE := 0.5
const BARRICADE_BREAK_VALUE := 10.0
## 味方を巻き込むダメージ（樽の爆発）は、同じ量の敵へのダメージの何倍の損とみるか。
const FRIENDLY_FIRE_RATE := 1.5
## 回復 1 の価値、回復すること自体の価値、将を回復する上乗せ、減っている割合（0〜1）に掛ける上乗せ。
const HEAL_VALUE := 2.0
const HEAL_BASE_VALUE := 5.0
const KING_HEAL_BONUS := 10.0
const WOUNDED_BONUS := 10.0
## 入る経験値 1 の価値と、レベルが 1 つ上がる価値。中立の駒を狩る得は、ほぼこれで決まる（もう育たない駒は狩りに行かない）。
const EXPERIENCE_VALUE := 0.5
const LEVEL_UP_VALUE := 15.0
## 敵の本陣のマスに立つ価値（奇襲、それ以外）と、占拠を続けている 1 回ぶんの上乗せ。
const HQ_VALUE_RAIDER := 150.0
const HQ_VALUE_OTHER := 60.0
const HQ_HOLD_VALUE := 400.0
## 将のいない自分の本陣のマスに立つ価値（敵が GUARD_RADIUS 以内にいるとき。乗っていれば、敵は占拠できない）。
const HQ_GUARD_VALUE := 80.0
const GUARD_RADIUS := 10
## 巡航の減点（同じ良さなら、巡航しない）。
const CRUISE_PENALTY := 0.5
## 後衛が、狙う相手から 1 マス離れている価値（射程の中で、なるべく遠くに立つ）。
const STAND_OFF_VALUE := 0.5
## 回復役が、減っている味方を探す範囲（歩数）。
const HEALER_SEARCH_STEPS := 12
## スキル -> 使った結果の価値を見積もるメソッド（SkillUsedEvent と、使ったあとの複製を受け取る）。
## ダメージ・回復・経験値のイベントだけで価値が決まるスキルは、載せなくてよい（_outcome_value がそのまま読む）。
const SKILL_VALUES := {
	Skill.Id.TACTICAL_BARRICADE: &"_barricade_value",
	Skill.Id.SAINT_PLACE: &"_sanctuary_value",
	Skill.Id.SMOKE_GRENADE: &"_smoke_value",
	Skill.Id.DIVINE_SHIELD: &"_barrier_value",
	Skill.Id.PRECISION_AIM: &"_aim_value",
	Skill.Id.SHADOW_STEP: &"_shadow_step_value",
	Skill.Id.ADRENALINE_SHOT: &"_adrenaline_value",
}
## 盾: 敵の射線を 1 本切る価値は、その敵の攻撃 1 回ぶんのダメージの価値の何倍か（敵は回り込めるので、1 より小さい）。
const BARRICADE_COVER_RATE := 0.75
## 聖域: 中に、減っている味方がこの数だけいれば置く。1 体が回復すると見込むのは、聖域の回復の何回ぶんまでか。
const SANCTUARY_MIN_UNITS := 2
const SANCTUARY_EXPECTED_HEALS := 2
## 煙幕: 中に、離れた敵に狙われている味方がこの数だけいれば置く。
## 狙っている敵 1 体を防ぐ価値は、その敵の攻撃 1 回ぶんのダメージの価値の何倍か（敵は隣まで寄れば当てられるので、1 より小さい）。
const SMOKE_MIN_UNITS := 2
const SMOKE_COVER_RATE := 0.75
## バリア: 次の相手の番に自分を攻撃できる敵のうち、いちばん強い 1 体の攻撃を防ぐと見込む。
## その価値は、その攻撃 1 回ぶんのダメージの価値の何倍か（敵は弱い攻撃で先にはがせるので、1 より小さい）。
const BARRIER_COVER_RATE := 0.75
## 照準: 次の自分の番に、強めた攻撃を当てられそうな敵 1 体への、その攻撃の価値の何倍を見込むか。
## いま伸びた射程の中にいる敵（AIM_RATE）と、1 回動けば入ってくる敵（AIM_WATCH_RATE）。
## いまの位置から攻撃できる敵は数えない（構えるより、いま撃つほうが早い）。
const AIM_RATE := 0.4
const AIM_WATCH_RATE := 0.2
## アドレナリン注射: 対象が、いまの位置からもう一度手を出したときの価値（いちばん良い攻撃・回復）が、この値以上なら使う
## （回数に限りがあるので、倒せる・将を殴れるくらいの手に取っておく）。見込む価値は、その手の価値の何倍か。
const ADRENALINE_MIN_VALUE := 30.0
const ADRENALINE_RATE := 0.75

const _GOAL := 0
const _DANGER := 1
const _IDLE_DANGER := 2
const _LETHAL := 3
const _FAR := 9999

# ---- 覚えておくもの（盤面が同じ間だけ使い回す） ----

var _board: Board
var _walkable_revision := -1
## 駒が乗っているポータルのマス（その対は、いまは通れないものとして歩数を数える）。
var _blocked_portals: Array[Vector2i] = []
## 歩けるマスなら 1。添字は y * 幅 + x。
var _walkable := PackedByteArray()
## 目標のマス -> そこから各マスへの歩数（駒は無視する。届かないマスは _FAR）。
var _steps: Dictionary[Vector2i, PackedInt32Array] = {}

# ---- 1 回の判断の間だけ使うもの ----

var _battle: Battle
var _me: Unit.Side
var _foe: Unit.Side
## 自分と相手の本陣のマス。本陣の無い盤面（テスト用）では Board.NO_CELL。
var _my_hq := Board.NO_CELL
var _foe_hq := Board.NO_CELL
## マス -> そこを次の相手の番に攻撃できる敵（駒の番号 -> 攻撃力）。
var _threats: Dictionary[Vector2i, Dictionary] = {}
var _threats_ready := false
## いま考えている駒の目標までの歩数の表、そこまで近づけば足りる歩数、役割ごとの重み、離れて立つか。
var _goal_steps := PackedInt32Array()
var _goal_reach := 0
var _goal_weight := 0.0
var _danger_weight := 0.0
var _idle_danger_weight := 0.0
## 敵が自分の本陣の近く（GUARD_RADIUS 以内）にいるか。
var _hq_in_danger := false
var _lethal_penalty := 0.0
var _stand_off := false
## いま考えている駒が、ほかのマスへ動いたあとの射程（動くと外れる状態で伸びた射程は、動くと戻る）。
var _moved_reach := 0
## いま考えている駒が、戦える駒のいなくなった軍の将か。
var _lone_king := false


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


func _decide() -> BattleAction:
	var evolving := _battle.evolving_unit()
	if evolving != null:
		return _choose_evolution(evolving)
	var acting := _battle.unit_by_id(_battle.acting_unit_id)
	if acting != null:
		return _follow_up(acting)
	var unit := _next_unit()
	if unit == null:
		return EndPhaseAction.new()
	return _plan(unit)


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
	_threats_ready = false
	var board := battle.board
	var has_hqs := board.hq_cells.size() >= 2
	_my_hq = board.hq_cells[_me] if has_hqs else Board.NO_CELL
	_foe_hq = board.hq_cells[_foe] if has_hqs else Board.NO_CELL
	_hq_in_danger = false
	var keeper := battle.unit_at(_my_hq) if has_hqs else null
	if has_hqs and (keeper == null or keeper.kind != UnitKind.Id.KING):
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


# ---- 進化先 ----


## 進化先を選ぶ。駒とターンで A・B を選び分ける（どちらの型も盤に出るように）。
func _choose_evolution(unit: Unit) -> BattleAction:
	var choices := _battle.options(unit.id).evolutions
	if choices.is_empty():
		return null
	return EvolveAction.new(unit.id, choices[(unit.id + _battle.turn) % choices.size()])


# ---- 駒を選ぶ ----


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


# ---- 動いたあとの行動 ----


## 動いたあとの駒が、いまの位置からすること。得になる攻撃・回復・スキルがあれば、いちばん良いもの。無ければ待機。
func _follow_up(unit: Unit) -> BattleAction:
	var best: BattleAction = WaitAction.new(unit.id)
	var best_value := 0.0
	for action in _battle.options(unit.id).actions():
		if action is MoveAction or action is WaitAction or action is UndoMoveAction:
			continue
		var sim := _battle.clone()
		var value := _outcome_value(sim, sim.apply(action).events)
		if value > best_value:
			best = action
			best_value = value
	return best


# ---- まだ動いていない駒の行動 ----


## まだ動いていない駒の、次の行動。「どこへ動くか」と「そこで何をするか」の組をすべて比べて、最初の 1 手を返す。
## 動く先を決めたら、そこで何をするかは次の呼び出し（_follow_up）がもう一度決める（同じ見積もりを使うので、同じ結論になる）。
func _plan(unit: Unit) -> BattleAction:
	var options := _battle.options(unit.id)
	_set_goal(unit)
	_build_threats()
	_moved_reach = Statuses.stat_after_move(unit, Unit.Stat.ATTACK_RANGE)

	# 動くだけ（待機）の手。
	var best_cell := unit.cell
	var best_cruise := false
	var best_action: BattleAction = null
	var best_value := _position_value(unit, unit.cell, 0, false)
	var positions: Dictionary[Vector2i, float] = {}
	for cell in options.move_cells:
		var value := _position_value(unit, cell, 0, false)
		positions[cell] = value
		if value > best_value:
			best_cell = cell
			best_value = value
	for cell in options.cruise_cells:
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
		if from != unit.cell and not sim.apply(MoveAction.new(unit.id, from)).accepted:
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

	# 動かずにスキルを使う手。動いてから使う手は並べない（動いた先で得になるなら、_follow_up が使う）。
	for cell in options.skill_cells:
		var action := UseSkillAction.new(unit.id, cell)
		var sim := _battle.clone()
		var value := _outcome_value(sim, sim.apply(action).events)
		if value <= 0.0:
			continue
		value += _position_value(unit, unit.cell, 0, true)
		if value > best_value:
			best_cell = unit.cell
			best_cruise = false
			best_action = action
			best_value = value

	if best_cell != unit.cell:
		return MoveAction.new(unit.id, best_cell, best_cruise)
	if best_action != null:
		return best_action
	return WaitAction.new(unit.id)


## 攻撃・回復の候補。[行動, 相手のマス, 相手の駒の番号（樽と盾は 0）] の列。
## cells（通常の移動で止まれるマス。ポータルの先も含む）のどれかから、射程の歩数の中にいる相手を並べる。
## 広めに並べるだけで、届くかどうかはルールに聞く（_plan が複製の上で確かめる）。
func _candidates(unit: Unit, cells: Dictionary[Vector2i, float]) -> Array[Array]:
	var result: Array[Array] = []
	var healer := UnitKind.role(unit.kind) == UnitKind.Role.HEALER
	for other in _battle.units:
		if other == unit or not _in_reach(unit, cells, other.cell):
			continue
		if healer:
			if other.side == _me and other.hp < other.max_hp():
				result.append([HealAction.new(unit.id, other.id), other.cell, other.id])
		elif other.side != _me:
			result.append([AttackAction.new(unit.id, other.id), other.cell, other.id])
	if not healer:
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
	return unit.attack_range() if cell == unit.cell else _moved_reach


## cells（通常の移動で止まれるマス）のうち、at に手が届き、そこで手を出すのにいちばん良いマス。無ければ Board.NO_CELL。
## 攻撃は、間に盾があるマスと、相手（target_id の駒。樽と盾なら 0）が煙幕に守られるマスを除く（ルールの問い合わせで見る）。
## ignored_id の敵からの危険は数えない。avoid_blast が真なら、at の周り 8 マス（樽の爆発が届く）をなるべく避ける。
func _best_cell_in_reach(
	unit: Unit, cells: Dictionary[Vector2i, float], at: Vector2i, target_id: int, ignored_id: int, avoid_blast: bool
) -> Vector2i:
	var healer := UnitKind.role(unit.kind) == UnitKind.Role.HEALER
	var target := _battle.unit_by_id(target_id)
	var best := Board.NO_CELL
	var best_value := -INF
	for cell in cells:
		var reach := _reach_from(unit, cell)
		if healer:
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


# ---- 行動の結果の価値 ----


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
			if SKILL_VALUES.has(used.skill):
				value += call(SKILL_VALUES[used.skill], used, sim)
			continue
		var chipped := event as BarricadeDamagedEvent
		if chipped != null:
			value += BARRICADE_DAMAGE_VALUE * chipped.amount
			continue
		var removed := event as FieldEffectRemovedEvent
		if removed != null:
			if removed.reason == FieldEffectRemovedEvent.Reason.DESTROYED:
				value += BARRICADE_BREAK_VALUE
			continue
		var gained := event as ExperienceGainedEvent
		if gained != null:
			value += EXPERIENCE_VALUE * gained.amount
		elif event is LevelUpEvent:
			value += LEVEL_UP_VALUE
	return value


## victim の HP を hp_after まで減らす価値（victim は減らす前の状態）。
func _damage_value(victim: Unit, hp_after: int) -> float:
	var rate := DAMAGE_VALUE
	var kill := KILL_VALUE + KILL_VALUE_PER_COST * UnitKind.cost(victim.kind)
	if victim.side == Unit.Side.NEUTRAL:
		rate = NEUTRAL_DAMAGE_VALUE
		kill = NEUTRAL_KILL_VALUE
	elif victim.kind == UnitKind.Id.KING:
		rate = KING_DAMAGE_VALUE
	elif UnitKind.role(victim.kind) == UnitKind.Role.HEALER:
		kill += HEALER_KILL_BONUS
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


# ---- スキルの価値 ----


## 盾を置いた価値。いま敵の離れた攻撃が味方に届いていて、盾で届かなくなる組を数える。味方の攻撃を遮るぶんは引く。
## 届くかどうかは、置く前（_battle）と置いたあと（sim）のルールの答えを比べる。
func _barricade_value(_used: SkillUsedEvent, sim: Battle) -> float:
	var value := 0.0
	for shooter in _battle.units:
		if shooter.side == Unit.Side.NEUTRAL or shooter.attack_range() < Combat.RANGED_DISTANCE:
			continue
		for target in _battle.units:
			if target.side == Unit.Side.NEUTRAL or not Combat.can_attack(_battle, shooter, target):
				continue
			if Combat.can_attack(sim, sim.unit_by_id(shooter.id), sim.unit_by_id(target.id)):
				continue
			var rate := KING_DAMAGE_VALUE if target.kind == UnitKind.Id.KING else DAMAGE_VALUE
			var worth := BARRICADE_COVER_RATE * rate * shooter.power()
			value += worth if target.side == _me else -worth
	return value


## 聖域を置いた価値。中にいる、減っている味方（もう自分の聖域の中にいる駒は除く）の、見込める回復量。
## 減っている味方が SANCTUARY_MIN_UNITS 体に満たなければ 0（回復役は、ふつうの回復のほうが早い）。
func _sanctuary_value(used: SkillUsedEvent, sim: Battle) -> float:
	var cells := Skills.by_id(used.skill).affected_cells(sim, sim.unit_by_id(used.unit_id), used.target)
	var wounded := 0
	var total := 0
	for unit in _battle.units:
		if unit.side != _me or not cells.has(unit.cell) or FieldEffects.sanctuary_of(_battle, unit) != null:
			continue
		var missing := unit.max_hp() - unit.hp
		if missing > 0:
			wounded += 1
			total += mini(missing, FieldEffects.SANCTUARY_HEAL * SANCTUARY_EXPECTED_HEALS)
	return HEAL_VALUE * total if wounded >= SANCTUARY_MIN_UNITS else 0.0


## 煙幕を置いた価値。中にいる味方（もう自分の煙幕の中にいる駒は除く）のうち、次の相手の番に
## 離れた攻撃（射程 2 以上の敵）に狙われうる駒を数え、その敵の攻撃を防ぐぶんを見込む。
## 狙われている味方が SMOKE_MIN_UNITS 体に満たなければ 0。
func _smoke_value(used: SkillUsedEvent, sim: Battle) -> float:
	_build_threats()
	var cells := Skills.by_id(used.skill).affected_cells(sim, sim.unit_by_id(used.unit_id), used.target)
	var covered := 0
	var value := 0.0
	for unit in _battle.units:
		if unit.side != _me or not cells.has(unit.cell) or FieldEffects.smoke_of(_battle, unit) != null:
			continue
		if not _threats.has(unit.cell):
			continue
		var rate := KING_DAMAGE_VALUE if unit.kind == UnitKind.Id.KING else DAMAGE_VALUE
		var worth := 0.0
		var by: Dictionary = _threats[unit.cell]
		for enemy_id: int in by:
			var enemy := _battle.unit_by_id(enemy_id)
			if enemy != null and enemy.attack_range() >= Combat.RANGED_DISTANCE:
				worth += SMOKE_COVER_RATE * rate * mini(by[enemy_id], unit.hp)
		if worth > 0.0:
			covered += 1
			value += worth
	return value if covered >= SMOKE_MIN_UNITS else 0.0


## バリアを付けた価値。次の相手の番に、いまのマスの自分を攻撃できる敵がいれば、いちばん強い 1 体の攻撃を防ぐぶんを見込む。
## 攻撃されそうになければ 0（バリアは期限で消える）。
func _barrier_value(used: SkillUsedEvent, _sim: Battle) -> float:
	_build_threats()
	var unit := _battle.unit_by_id(used.unit_id)
	if Statuses.has(unit, Status.Type.BARRIER) or not _threats.has(unit.cell):
		return 0.0
	var strongest := 0
	var by: Dictionary = _threats[unit.cell]
	for enemy_id: int in by:
		strongest = maxi(strongest, by[enemy_id])
	return BARRIER_COVER_RATE * DAMAGE_VALUE * mini(strongest, unit.hp)


## 照準を付けた価値。次の自分の番に、構えたマスから強めた攻撃を当てられそうな敵のうち、いちばん価値の高い 1 体ぶん。
## 当てたときのダメージは、構えたあとの複製（sim）のルールの答え（Combat.damage。確定クリティカル、森、煙幕、バリアを通る）。
## - いまの位置から攻撃できる敵は数えない
## - 伸びた射程の中にいる敵は AIM_RATE、相手が 1 回動けば入ってくる距離の敵は AIM_WATCH_RATE（距離は目安。地形は見ない）
func _aim_value(used: SkillUsedEvent, sim: Battle) -> float:
	var unit := _battle.unit_by_id(used.unit_id)
	var aimed := sim.unit_by_id(used.unit_id)
	var best := 0.0
	if Statuses.has(unit, Status.Type.AIM):
		return best  # もう構えている
	for enemy in _battle.units:
		if enemy.side != _foe or Combat.can_attack(_battle, unit, enemy):
			continue
		var rate := AIM_WATCH_RATE
		if Combat.can_attack(sim, aimed, sim.unit_by_id(enemy.id)):
			rate = AIM_RATE
		elif Combat.distance(unit.cell, enemy.cell) > aimed.attack_range() + enemy.move_range():
			continue
		var amount := Combat.damage(sim, aimed, sim.unit_by_id(enemy.id))
		if amount > 0:
			best = maxf(best, rate * _damage_value(enemy, maxi(0, enemy.hp - amount)))
	return best


## シャドウステップで跳んだ価値。跳んだ先から続けてできる攻撃（駒・樽・盾）のうち、いちばん良いものの価値に、
## 立つマスの価値の差（跳んだ先 − いまのマス）を足す。続けてできる攻撃は、跳んだあとの複製（sim）のルールに聞く。
## 攻撃できる相手がいなければ 0（跳ぶだけの手は選ばない）。ただし、次の 2 つは攻撃できなくても数える。
## - 敵の本陣のマスに着く（立つマスの価値に入っている）
## - 自分の本陣に乗っている敵と入れ替わる（占拠が途切れる。OCCUPIER_KILL_BONUS を足す）
func _shadow_step_value(used: SkillUsedEvent, sim: Battle) -> float:
	var unit := _battle.unit_by_id(used.unit_id)
	_set_goal(unit)
	_build_threats()
	var best := 0.0
	var killed_id := 0
	for action in sim.options(used.unit_id).actions():
		if not (action is AttackAction or action is AttackBarrelAction or action is AttackBarricadeAction):
			continue
		var after := sim.clone()
		var value := _outcome_value(after, after.apply(action).events)
		if value > best:
			best = value
			var attack := action as AttackAction
			killed_id = attack.target_id if attack != null and after.unit_by_id(attack.target_id) == null else 0
	var swapped := _battle.unit_at(used.target)
	if swapped != null and swapped.side == _foe and used.target == _my_hq:
		best += OCCUPIER_KILL_BONUS
	if best <= 0.0 and used.target != _foe_hq:
		return 0.0
	return best + _position_value(unit, used.target, killed_id, true) - _position_value(unit, unit.cell, 0, true)


## アドレナリン注射を使った価値。対象が、いまの位置からもう一度手を出したとき（攻撃・樽・盾・回復。動く手とスキルは見ない）の、
## いちばん良い手の価値の ADRENALINE_RATE 倍。その手の価値が ADRENALINE_MIN_VALUE に満たなければ 0。
## できる手は、使ったあとの複製（sim）のルールに聞く。
func _adrenaline_value(used: SkillUsedEvent, sim: Battle) -> float:
	var friend := sim.unit_at(used.target)
	var best := 0.0
	for action in sim.options(friend.id).actions():
		if action is MoveAction or action is WaitAction or action is UndoMoveAction or action is UseSkillAction:
			continue
		var after := sim.clone()
		best = maxf(best, _outcome_value(after, after.apply(action).events))
	return ADRENALINE_RATE * best if best >= ADRENALINE_MIN_VALUE else 0.0


# ---- 位置の価値 ----


## unit が cell に立って行動を終える価値。目標への近さ、敵の本陣、次の相手の番に受けうるダメージで決まる。
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
	var threat := 0
	if _threats.has(cell):
		var by: Dictionary = _threats[cell]
		for enemy_id: int in by:
			if enemy_id != ignored_id:
				threat += by[enemy_id]
	value -= (_danger_weight if acting else _idle_danger_weight) * threat
	if threat >= unit.hp:
		value -= _lethal_penalty
	return value


## unit の目標（どこへ近づきたいか）を決めて、_goal_steps、_goal_reach、役割ごとの重み、_stand_off に置く。
## - 将: 自分の本陣。戦える駒が 1 体も残っていなければ、前衛と同じに敵へ向かう
## - 奇襲: 敵の本陣（敵が乗っていれば、そこを攻撃できるところまで）
## - 前衛・後衛: 自分の本陣の近くに入った敵（侵入者）がいれば、そのいちばん近いもの。いなければ、いちばん近い敵の駒
## - 回復: 近くの減っている味方（減っている割合がいちばん大きいもの）。いなければ、いちばん近い味方の戦う駒
func _set_goal(unit: Unit) -> void:
	var role := UnitKind.role(unit.kind)
	_lone_king = unit.kind == UnitKind.Id.KING and not _has_fighters()
	var style: Array = LONE_KING_STYLE if _lone_king else STYLES[role]
	_goal_weight = style[_GOAL]
	_danger_weight = style[_DANGER]
	var bold := clampf(float(_battle.turn - BOLD_FROM_TURN) / (BOLD_BY_TURN - BOLD_FROM_TURN), 0.0, 1.0)
	_idle_danger_weight = lerpf(style[_IDLE_DANGER], minf(style[_DANGER], style[_IDLE_DANGER]), bold)
	_lethal_penalty = style[_LETHAL]
	_stand_off = role == UnitKind.Role.REARGUARD
	var goal := _my_hq if _my_hq != Board.NO_CELL else unit.cell
	_goal_reach = 0
	if unit.kind == UnitKind.Id.KING and not _lone_king:
		pass
	elif role == UnitKind.Role.RAIDER and _foe_hq != Board.NO_CELL:
		goal = _foe_hq
		var occupant := _battle.unit_at(goal)
		if occupant != null and occupant != unit:
			_goal_reach = unit.attack_range()
	elif role == UnitKind.Role.HEALER:
		var friend := _friend_to_follow(unit)
		if friend != null:
			goal = friend.cell
			_goal_reach = unit.attack_range()
	else:
		var enemy := _enemy_to_chase(unit)
		if enemy != null:
			goal = enemy.cell
			_goal_reach = unit.attack_range()
	_goal_steps = _steps_from(goal)


## 自分の軍に、戦える駒（前衛・後衛・奇襲）が残っているか。
func _has_fighters() -> bool:
	for other in _battle.units:
		if other.side == _me and other.kind != UnitKind.Id.KING and UnitKind.role(other.kind) != UnitKind.Role.HEALER:
			return true
	return false


## 前衛・後衛（と、戦える駒のいなくなった軍の将）が向かう敵（プレイヤーの駒）。侵入者を先に、その中でいちばん近いもの（マンハッタン距離）。
func _enemy_to_chase(unit: Unit) -> Unit:
	var best: Unit = null
	var best_key := Vector2i(_FAR, _FAR)
	for other in _battle.units:
		if other.side != _foe:
			continue
		var intruder := _my_hq != Board.NO_CELL and Combat.distance(other.cell, _my_hq) <= DEFENSE_RADIUS
		var key := Vector2i(0 if intruder else 1, Combat.distance(unit.cell, other.cell))
		if key < best_key:
			best = other
			best_key = key
	return best


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


# ---- 危険なマス ----


## 次の相手の番（と中立のフェーズ）に、敵が攻撃できるマスを調べる。
## 相手の動けるマスは、複製の上で自分のフェーズを終え、相手の番になった状態の Battle.options() に聞く。
## そこから攻撃の届くマスは目安（動けるマスから射程の歩数まで。地形は見ない）。中立の駒は、いまの位置から移動力 + 射程まで。
func _build_threats() -> void:
	if _threats_ready:
		return
	_threats_ready = true
	var sim := _battle.clone()
	var next_phase := sim.apply(EndPhaseAction.new()).accepted and not sim.is_over()
	for enemy in _battle.units:
		if enemy.side == _me or UnitKind.role(enemy.kind) == UnitKind.Role.HEALER:
			continue
		var from: Array[Vector2i] = [enemy.cell]
		var reach := enemy.move_range() + enemy.attack_range()
		if enemy.side == _foe:
			if not next_phase or sim.unit_by_id(enemy.id) == null:
				continue
			from.assign(sim.options(enemy.id).move_cells.keys())
			reach = enemy.attack_range()
		_spread_threat(enemy.id, enemy.power(), from, reach)


## from のマスから reach 歩までのマスに、敵 enemy_id の攻撃（power）が届くと書き込む。
func _spread_threat(enemy_id: int, power: int, from: Array[Vector2i], reach: int) -> void:
	var seen: Dictionary[Vector2i, bool] = {}
	var frontier := from
	for cell in from:
		seen[cell] = true
	for step in reach + 1:
		var next: Array[Vector2i] = []
		for cell in frontier:
			if not _threats.has(cell):
				_threats[cell] = {}
			_threats[cell][enemy_id] = power
			if step == reach:
				continue
			for direction in Board.DIRECTIONS:
				var near := cell + direction
				if not seen.has(near) and _board.in_bounds(near):
					seen[near] = true
					next.append(near)
		frontier = next


# ---- 歩数の表 ----


## goal から各マスへの歩数（上下左右に 1 歩ずつ。ポータルの転移も 1 歩。駒の乗っているポータルは通れない）。ほかは駒を無視する。
## 遠くの目標へ「どちらが近いか」を比べるための目安で、移動のルール（Movement）の代わりではない。
func _steps_from(goal: Vector2i) -> PackedInt32Array:
	if _steps.has(goal):
		return _steps[goal]
	if _steps.size() >= 128:
		_steps = {}
	var width := _board.size.x
	var height := _board.size.y
	var steps := PackedInt32Array()
	steps.resize(width * height)
	steps.fill(_FAR)
	var queue := PackedInt32Array()
	queue.resize(width * height)
	var head := 0
	var tail := 1
	queue[0] = goal.y * width + goal.x
	steps[queue[0]] = 0
	var portals := not _board.portal_exits.is_empty()
	while head < tail:
		var index := queue[head]
		head += 1
		var next_steps := steps[index] + 1
		var x := index % width
		@warning_ignore("integer_division")
		var y := index / width
		var near: Array[int] = []
		if x > 0:
			near.append(index - 1)
		if x < width - 1:
			near.append(index + 1)
		if y > 0:
			near.append(index - width)
		if y < height - 1:
			near.append(index + width)
		if portals:
			var exit := _board.portal_exit(Vector2i(x, y))
			if exit != Board.NO_CELL and not _blocked_portals.has(exit) and not _blocked_portals.has(Vector2i(x, y)):
				near.append(exit.y * width + exit.x)
		for other in near:
			if _walkable[other] == 1 and steps[other] == _FAR:
				steps[other] = next_steps
				queue[tail] = other
				tail += 1
	_steps[goal] = steps
	return steps
