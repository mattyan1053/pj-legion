class_name Neutral
extends RefCounted
## 中立のフェーズ: 中立の駒（エナジー・コア）が動き、近くのプレイヤーの駒を襲い、結晶泉に新しく湧く。
##
## 中立の駒はどちらのプレイヤーにも操作されない。中立のフェーズに、ここが 1 体ずつ動かす。
## 移動・攻撃は、プレイヤーの駒と同じ計算（Movement、Combat）と同じイベントを通す。
## 確率は Battle.rng だけを使う。
##
## 中立の駒は「家」（Unit.home_cell。エナジー・コアなら、湧いた結晶泉）の周りの縄張りを守る:
## - 縄張りは、家からマンハッタン距離 TERRITORY_RADIUS 以内のマス。縄張りの外には止まらない
## - 狙うのは、縄張りから攻撃が届くプレイヤーの駒（家からの距離が TERRITORY_RADIUS + 射程 以内）
## - 狙う相手がいなければ、家へ戻る
##
## 問い合わせ（target_of、destination、attack_target_of）は盤と駒を変えない。
## ただし同点の決着に rng を引くことがあるので、先読み（戦闘予測、CPU）は Battle.clone() の上で呼ぶ。

# ---- 調整値（docs/neutral-minion.md の「調整値」） ----

## 縄張りの広さ（家からのマンハッタン距離）。
const TERRITORY_RADIUS := 4
## 泉のエナジー・コアが倒れたあと、中立のフェーズごとに新しく湧く確率（%）。
const RESPAWN_CHANCE_PERCENT := 35
## 結晶泉に湧く中立の駒の種類。
const SPAWN_KIND := UnitKind.Id.MINION


## 中立のフェーズの中身（PhaseStartedEvent のあと）。起きたことを起きた順に返す。
## 1. いまいる中立の駒が、番号の順に 1 体ずつ動いて攻撃する（湧いたばかりの駒は、次のフェーズから動く）
## 2. 空いている結晶泉に湧く（盤面の font_cells の順）
## 駒 1 体の行動のたびに Battle.settle() を呼ぶ。決着したら、そこで止める。
static func play_phase(battle: Battle) -> Array[BattleEvent]:
	var events: Array[BattleEvent] = []
	var acting: Array[Unit] = []
	for unit in battle.units:
		if unit.side == Unit.Side.NEUTRAL:
			acting.append(unit)
	for unit in acting:
		if not battle.units.has(unit):
			continue
		var step := _act(battle, unit)
		events.append_array(step)
		events.append_array(battle.settle(step))
		if battle.is_over():
			return events
	events.append_array(spawn(battle))
	return events


## 空いている結晶泉に、中立の駒を 1 体ずつ湧かせる。
## - その泉を家にする中立の駒が生きている間は、湧かない（泉ごとに 1 体まで）
## - 泉のマスにほかの駒が乗っている間は、湧かない（確率も引かない）
## - ターン 1 では必ず湧く。それより後は RESPAWN_CHANCE_PERCENT の確率で
static func spawn(battle: Battle) -> Array[BattleEvent]:
	var events: Array[BattleEvent] = []
	for font in battle.board.font_cells:
		if guardian_of(battle, font) != null or battle.unit_at(font) != null:
			continue
		if not battle.board.is_walkable(font):
			continue
		if battle.turn > 1 and battle.rng.randi_range(1, 100) > RESPAWN_CHANCE_PERCENT:
			continue
		var unit := battle.add_unit(SPAWN_KIND, Unit.Side.NEUTRAL, font)
		unit.home_cell = font
		events.append(UnitSpawnedEvent.new(unit))
	return events


## その場所を家にしている中立の駒（いなければ null）。
static func guardian_of(battle: Battle, home: Vector2i) -> Unit:
	for unit in battle.units:
		if unit.side == Unit.Side.NEUTRAL and unit.home_cell == home:
			return unit
	return null


## 縄張りのマスか（家を持たない中立の駒には、縄張りの制限が無い）。
static func in_territory(unit: Unit, cell: Vector2i) -> bool:
	return unit.home_cell == Board.NO_CELL or Combat.distance(cell, unit.home_cell) <= TERRITORY_RADIUS


## 中立の駒が狙うプレイヤーの駒（いなければ null）。
## 縄張りから攻撃が届く駒のうち、いちばん近い（マンハッタン距離）もの。同じ近さなら HP の少ないもの。
## それでも並べば、rng で選ぶ（盤の上下や番号の順で、片方のプレイヤーに寄らないように）。
static func target_of(battle: Battle, unit: Unit) -> Unit:
	var candidates: Array[Unit] = []
	for other in battle.units:
		if other.side == Unit.Side.NEUTRAL:
			continue
		if unit.home_cell != Board.NO_CELL:
			if Combat.distance(other.cell, unit.home_cell) > TERRITORY_RADIUS + unit.attack_range():
				continue
		candidates.append(other)
	return _closest(battle, unit.cell, candidates)


## 中立の駒が動く先。target が null なら家へ戻る（家を持たなければ動かない）。
## - target を攻撃できるマスがあれば、そのうち使う移動力がいちばん少ないマス
## - 無ければ、target にいちばん近づけるマス（同じなら使う移動力の少ないマス）
## どれも縄張りの中で、通常の移動で止まれるマス（いまのマスを含む）。同点は移動範囲の探索の順で先のもの。
static func destination(battle: Battle, unit: Unit, target: Unit) -> Vector2i:
	var goal := unit.home_cell if target == null else target.cell
	if goal == Board.NO_CELL:
		return unit.cell
	var reach := unit.attack_range() if target != null else 0
	var best := unit.cell
	var best_key := Vector2i(_gap(unit.cell, goal, reach), 0)
	var stops := Movement.reachable(battle, unit, false)
	for cell: Vector2i in stops:
		if not in_territory(unit, cell):
			continue
		var key := Vector2i(_gap(cell, goal, reach), stops[cell])
		if key < best_key:
			best = cell
			best_key = key
	return best


## 動いたあとに攻撃する相手（いなければ null）。target を攻撃できれば target。
## できなければ、いまの位置から攻撃できるプレイヤーの駒のうち、target_of と同じ決め方で選ぶ。
static func attack_target_of(battle: Battle, unit: Unit, target: Unit) -> Unit:
	if target != null and Combat.can_attack(battle, unit, target):
		return target
	var candidates: Array[Unit] = []
	for other in Combat.targets(battle, unit):
		if other.side != Unit.Side.NEUTRAL:
			candidates.append(other)
	return _closest(battle, unit.cell, candidates)


## 中立の駒 1 体の行動: 動いて（UnitMovedEvent。ポータルを通れば UnitWarpedEvent も）、
## 攻撃できれば攻撃する（AttackDamagedEvent、倒れたら UnitDefeatedEvent）。
## 中立の駒は「行動済み」を持たないので、UnitActedEvent は出さない。
static func _act(battle: Battle, unit: Unit) -> Array[BattleEvent]:
	var events: Array[BattleEvent] = []
	var target := target_of(battle, unit)
	var to := destination(battle, unit, target)
	if to != unit.cell:
		var path := Movement.path_to(battle, unit, to)
		events.append_array(MoveAction.events_along(battle, unit.id, path, false))
		unit.cell = to
	var victim := attack_target_of(battle, unit, target)
	if victim != null:
		var amount := Combat.damage(battle, unit, victim)
		victim.hp = maxi(0, victim.hp - amount)
		events.append(AttackDamagedEvent.new(unit.id, victim.id, amount, victim.hp))
		if victim.hp == 0:
			events.append(battle.remove_unit(victim))
	return events


## from からいちばん近い駒。同じ近さなら HP の少ないもの。それでも並べば rng で選ぶ。
static func _closest(battle: Battle, from: Vector2i, candidates: Array[Unit]) -> Unit:
	var best: Array[Unit] = []
	var best_key := Vector2i(1 << 30, 0)
	for other in candidates:
		var key := Vector2i(Combat.distance(from, other.cell), other.hp)
		if key < best_key:
			best = [other]
			best_key = key
		elif key == best_key:
			best.append(other)
	if best.is_empty():
		return null
	if best.size() == 1:
		return best[0]
	return best[battle.rng.randi_range(0, best.size() - 1)]


## cell から goal を射程 reach で捉えるまでに足りない距離（届いていれば 0）。
static func _gap(cell: Vector2i, goal: Vector2i, reach: int) -> int:
	return maxi(0, Combat.distance(cell, goal) - reach)
