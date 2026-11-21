class_name Threat
extends RefCounted
## 脅威範囲: 駒が、次の自分の番に攻撃・スキルで届くマス（docs/threat-range.md）。状態は変えない。
##
## 「遊ぶ人が安全だと思ったマスで、不意に倒されない」ことを基準に、届きうるものは広めに数える。
## 移動、射程、ZOC、盾、ポータル、駒の状態、スキル、必殺技は、どれもルールに聞く（自分では計算しない）:
##
## - 次の自分の番の始めの状態を、複製の上でフェーズを進めて作る（状態の期限、クールダウン、ゲージがルールどおりに進む）。
##   必殺技を使えるなら、使ったものとする（総員突撃の移動力と攻撃力、魔力解放で明けたスキル）
## - 動けるマス（通常の移動。Movement.reachable。巡航は攻撃できないので数えない）から、射程の中で届くマス（Combat.reaches）。
##   動くと外れる状態（照準）は、いまのマスからだけ効く
## - 届く樽を攻撃したときの爆発のマス
## - スキル（使えるときだけ）: ダメージの届くマス（Skill.threat_damage）と、使ったあとに攻撃できる移った先（Skill.threat_origins）
## - 同じ陣営の衛生兵がアドレナリン注射を打てるなら、1 度目の行動のあと、注射の届くマスから、もう一度の移動と攻撃
## - 中立の駒は、縄張りの中で止まれるマス（いまのマスも）から、射程の中
##
## 量は、その駒の 1 回ぶんのいちばん強い値（受ける側の森とバリアは引かない。受ける駒で変わるので、読む側が見る）。
## 確率で決まるルール（中立の駒の同点）は複製の上で引くので、元の Battle.rng は進まない。

## 届くマスの表。of / against が返す。
class Map:
	extends RefCounted
	## マス -> {駒の番号: その駒の 1 回ぶんのいちばん強いダメージ}。
	var hits: Dictionary[Vector2i, Dictionary] = {}
	## hits のうち、煙幕に防がれないもの（隣からの攻撃、樽の爆発、スキルのダメージ）。
	var close: Dictionary[Vector2i, Dictionary] = {}
	## 攻撃のために止まれるマス（プレイヤーの駒のうち、回復役を除く。中立の駒は含まない）。
	var stops: Dictionary[Vector2i, bool] = {}

	func has(cell: Vector2i) -> bool:
		return hits.has(cell)

	## 届くマス。上の行から、左の列から。
	func cells() -> Array[Vector2i]:
		var result: Array[Vector2i] = []
		result.assign(hits.keys())
		result.sort_custom(Board.in_reading_order)
		return result

	## cell に届く駒と量（{駒の番号: 量}）。smoked なら、煙幕に防がれないものだけ。
	func at(cell: Vector2i, smoked := false) -> Dictionary:
		return (close if smoked else hits).get(cell, {})

	func note(cell: Vector2i, unit_id: int, amount: int, unsmokable: bool) -> void:
		_note(hits, cell, unit_id, amount)
		if unsmokable:
			_note(close, cell, unit_id, amount)

	func _note(table: Dictionary[Vector2i, Dictionary], cell: Vector2i, unit_id: int, amount: int) -> void:
		var by: Dictionary = table.get_or_add(cell, {})
		by[unit_id] = maxi(amount, by.get(unit_id, 0))


## 駒 unit_id の脅威範囲。いない駒では空。
static func of(battle: Battle, unit_id: int) -> Map:
	var map := Map.new()
	var unit := battle.unit_by_id(unit_id)
	if unit == null:
		return map
	if unit.side == Unit.Side.NEUTRAL:
		_neutral(battle, unit, map)
		return map
	var sim := next_phase(battle, unit.side)
	if sim != null:
		_player(sim, sim.unit_by_id(unit_id), map)
	return map


## side の敵（相手のプレイヤーの駒と、中立の駒）全員の脅威範囲を重ねたもの。
## 同じマスに届く駒は、駒ごとに分けて持つ（Map.at）。
static func against(battle: Battle, side: Unit.Side) -> Map:
	var map := Map.new()
	var sims: Dictionary[int, Battle] = {}
	for unit in battle.units:
		if unit.side == side:
			continue
		if unit.side == Unit.Side.NEUTRAL:
			_neutral(battle, unit, map)
			continue
		if not sims.has(unit.side):
			sims[unit.side] = next_phase(battle, unit.side)
		var sim: Battle = sims[unit.side]
		if sim != null:
			_player(sim, sim.unit_by_id(unit.id), map)
	return map


## side の次のフェーズの始めの状態（複製）。必殺技を使えるなら、使ったあと。その前に決着するなら null。
## いま side のフェーズなら、1 巡したあとの次のフェーズ。進化先を選ぶのを待つ駒がいれば、先の候補を選んだことにする。
static func next_phase(battle: Battle, side: Unit.Side) -> Battle:
	if side == Unit.Side.NEUTRAL or battle.is_over():
		return null
	var sim := battle.clone()
	for i in 3:
		var evolving := sim.evolving_unit()
		if evolving != null:
			sim.apply(EvolveAction.new(evolving.id, sim.options(evolving.id).evolutions[0]))
		if not sim.apply(EndPhaseAction.new()).accepted or sim.is_over():
			return null
		if sim.phase == side:
			break
	if Ults.can_use(sim):
		sim.apply(UseUltAction.new())
	return sim


## プレイヤーの駒 unit（sim の中の駒。sim は unit の番の始め）の脅威範囲を map に書く。
static func _player(sim: Battle, unit: Unit, map: Map) -> void:
	if unit == null:
		return
	var first := _stops(sim, unit, [unit.cell])
	_action(sim, unit, first, false, map)
	if not _can_be_reactivated(sim, unit):
		return
	# アドレナリン注射: 1 度目の行動を終えたマスのうち、衛生兵の注射が届くマスから、反動の付いたもう一度の行動。
	var shot := _shot_cells(sim, unit)
	var starts: Array[Vector2i] = []
	for cell in first:
		if shot.has(cell):
			starts.append(cell)
	if not starts.is_empty():
		_action(sim, unit, _stops(sim, unit, starts), true, map)


## unit が starts のどれかのマスから、通常の移動で止まれるマス（starts も含む）。
static func _stops(sim: Battle, unit: Unit, starts: Array[Vector2i]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	result.assign(Movement.reachable_from_any(sim, unit, starts, false, true).keys())
	return result


## unit が stops のどれかに止まって、攻撃か、スキルを使ったら届くマスを map に書く。tired なら反動の付いた写しで数える。
## 動くと外れる状態は、いまのマス（unit.cell）からだけ効く。
static func _action(sim: Battle, unit: Unit, stops: Array[Vector2i], tired: bool, map: Map) -> void:
	var stay := _probe(unit, unit.cell, tired)
	var moved := _probe(unit, Board.NO_CELL, tired)
	var attacks := UnitKind.role(unit.kind) != UnitKind.Role.HEALER
	if attacks:
		for cell in stops:
			map.stops[cell] = true
		if Combat.attack_power(stay) == Combat.attack_power(moved) and stay.attack_range() == moved.attack_range():
			_attacks(sim, unit.id, moved, stops, map)
		else:
			var away := stops.duplicate()
			away.erase(unit.cell)
			_attacks(sim, unit.id, moved, away, map)
			if stops.has(unit.cell):
				_attacks(sim, unit.id, stay, [unit.cell], map)
		_barrels(sim, unit.id, stay, moved, stops, map)
		for cell in stops:
			var bonus := MapObject.battery_bonus(sim.board, unit, cell)
			if bonus > 0 and cell != unit.cell:
				var gunner := moved.copy()
				gunner.site_range = bonus
				_attacks(sim, unit.id, gunner, [cell], map)
				_barrels(sim, unit.id, gunner, gunner, [cell], map)  # 伸びた射程で撃てる樽の爆発も
	var skill := Skills.of(unit)
	if skill == null or not Skills.can_use(sim, unit):
		return
	var damage: Dictionary[Vector2i, int] = {}
	var origins: Dictionary[Vector2i, bool] = {}
	for cell in stops:
		var user := stay if cell == unit.cell else moved
		user.cell = cell
		if not skill.is_ready(sim, user):
			continue
		var reached := skill.threat_damage(sim, user)
		for target: Vector2i in reached:
			damage[target] = maxi(damage.get(target, 0), reached[target])
		for origin in skill.threat_origins(sim, user):
			origins[origin] = true
	stay.cell = unit.cell
	for target: Vector2i in damage:
		map.note(target, unit.id, damage[target], true)
	if attacks and not origins.is_empty():
		var from: Array[Vector2i] = []
		from.assign(origins.keys())
		_attacks(sim, unit.id, moved, from, map)
		_barrels(sim, unit.id, moved, moved, from, map)  # 跳んだ先から樽も撃てる


## unit の写し。at がいまのマスでなければ、動くと外れる状態を外す（動いたあとの駒）。tired なら反動を付ける。
static func _probe(unit: Unit, at: Vector2i, tired: bool) -> Unit:
	var probe := unit.copy()
	if at != unit.cell:
		Statuses.displace(probe)
		probe.site_range = 0
		probe.has_moved = true
		probe.move_origin = unit.cell
	if tired and not Statuses.has(probe, Status.Type.FATIGUE):
		Statuses.add(probe, Status.Type.FATIGUE, AdrenalineShotSkill.FATIGUE_TURNS)
	return probe


## attacker（写し）が from のどれかのマスから攻撃して届くマスを map に書く。
## from から射程の歩数まで広げ（地形は射程を遮らない）、盤に盾があれば、離れたマスは間の盾をルールに聞く（Combat.reaches）。
static func _attacks(sim: Battle, unit_id: int, attacker: Unit, from: Array[Vector2i], map: Map) -> void:
	var reach := attacker.attack_range()
	var power := Combat.attack_power(attacker)
	var check_lines := reach >= Combat.RANGED_DISTANCE and sim.board.has_barricades()
	var seen: Dictionary[Vector2i, bool] = {}
	var frontier: Array[Vector2i] = []
	for cell in from:
		if not seen.has(cell):
			seen[cell] = true
			frontier.append(cell)
	for step in reach + 1:
		var next: Array[Vector2i] = []
		for cell in frontier:
			if step < Combat.RANGED_DISTANCE or not check_lines or _reaches_from_any(sim, from, cell, reach):
				map.note(cell, unit_id, power, step < Combat.RANGED_DISTANCE)
			if step == reach:
				continue
			for direction in Board.DIRECTIONS:
				var near := cell + direction
				if not seen.has(near) and sim.board.in_bounds(near):
					seen[near] = true
					next.append(near)
		frontier = next


static func _reaches_from_any(sim: Battle, from: Array[Vector2i], at: Vector2i, reach: int) -> bool:
	for cell in from:
		if Combat.distance(cell, at) <= reach and Combat.reaches(sim, cell, at, reach):
			return true
	return false


## 止まれるマスのどれかから攻撃できる樽の、爆発のマスを map に書く（煙幕に防がれない）。
static func _barrels(sim: Battle, unit_id: int, stay: Unit, moved: Unit, stops: Array[Vector2i], map: Map) -> void:
	for barrel in sim.board.barrel_cells:
		for cell in stops:
			var attacker := stay if cell == stay.cell else moved
			if Combat.reaches(sim, cell, barrel, attacker.attack_range()):
				for near in MapObject.blast_cells(sim.board, barrel):
					map.note(near, unit_id, MapObject.BLAST_DAMAGE, true)
				break


## 同じ陣営に、unit にアドレナリン注射を打てる衛生兵（いまスキルを使える、unit でない駒）がいるか。
static func _can_be_reactivated(sim: Battle, unit: Unit) -> bool:
	return not _medics(sim, unit).is_empty()


static func _medics(sim: Battle, unit: Unit) -> Array[Unit]:
	var result: Array[Unit] = []
	for other in sim.units:
		if other == unit or other.side != unit.side:
			continue
		var skill := Skills.of(other)
		if skill != null and skill.id() == Skill.Id.ADRENALINE_SHOT and Skills.can_use(sim, other):
			result.append(other)
	return result


## 衛生兵が、動いた先（いまのマスも）から unit に注射を打てるマス。
static func _shot_cells(sim: Battle, unit: Unit) -> Dictionary[Vector2i, bool]:
	var result: Dictionary[Vector2i, bool] = {}
	for medic in _medics(sim, unit):
		var reach := medic.attack_range()
		for from: Vector2i in Movement.reachable(sim, medic, false, true):
			for dy in range(-reach, reach + 1):
				var width := reach - absi(dy)
				for dx in range(-width, width + 1):
					result[from + Vector2i(dx, dy)] = true
	return result


## 中立の駒 unit の脅威範囲を map に書く。縄張りの中で止まれるマス（いまのマスも）から、射程の中。
static func _neutral(battle: Battle, unit: Unit, map: Map) -> void:
	var posts: Array[Vector2i] = [unit.cell]
	for cell: Vector2i in Movement.reachable(battle, unit, false, true):
		if cell != unit.cell and Neutral.in_territory(unit, cell):
			posts.append(cell)
	_attacks(battle, unit.id, unit, posts, map)
