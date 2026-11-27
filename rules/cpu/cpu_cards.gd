class_name CpuCards
extends RefCounted
## CPU が手札の札を使うかどうか（試しの決まり OptionalRules.HAND。docs/hand-cards.md の「CPU」）。
##
## 札ごとの単純な決まりで選ぶ（複製の上で読み比べない）。対戦の状態は変えない。乱数は使わない。
## 見るのは自分の手札だけ（相手の手札と、山の並びは読まない）。
## CpuPlayer が、駒を動かす前（行動の途中の駒がいないとき）に毎回聞く。1 つの番に 1 枚なので、札を返すのは番に 1 度。

# ---- 調整値 ----

## 手当てを使う、減っている HP（将はこの半分で使う）。
const MEND_MISSING := Card.MEND_HEAL
## 補給を使う、戻る HP の合計。
const RESUPPLY_TOTAL := 6
## 手札がこの枚数以上なら、条件をゆるめて使う（上限で引けなくなる前に使う）。
const SPEND_AT := Hand.HAND_LIMIT - 1
## 転移で逃がす、残りの HP の割合（%）。
const BLINK_HP_PERCENT := 40
const _FAR := 9999


## いまのフェーズのプレイヤーが使う札。使わなければ null。返す行動は Battle.can_apply が受け付ける。
static func pick(battle: Battle) -> PlayCardAction:
	if not Hand.can_play_now(battle):
		return null
	var hand := Hand.of(battle, battle.phase)
	var spend := hand.size() >= SPEND_AT
	for card: Card.Id in [
		Card.Id.MEND, Card.Id.RESUPPLY, Card.Id.WARD, Card.Id.MIGHT, Card.Id.MARCH, Card.Id.ENCORE, Card.Id.SHOVE, Card.Id.BLINK,
	]:
		if not hand.has(card) or not Hand.can_play(battle, card):
			continue
		var action := _choose(battle, card, spend)
		if action != null and battle.can_apply(action):
			return action
	return null


static func _choose(battle: Battle, card: Card.Id, spend: bool) -> PlayCardAction:
	var me := battle.phase
	match card:
		Card.Id.MEND:
			return _on_best(battle, card, func(unit: Unit) -> float:
				var missing := unit.max_hp() - unit.hp
				var king := unit.kind == UnitKind.Id.KING
				@warning_ignore("integer_division")
				if missing < (MEND_MISSING / 2 if king else MEND_MISSING):
					return -INF
				return missing + (100.0 if king else 0.0))
		Card.Id.RESUPPLY:
			var total := 0
			for unit in battle.units:
				if unit.side == me:
					total += Mend.amount(unit, Card.RESUPPLY_HEAL)
			return PlayCardAction.new(card) if total >= RESUPPLY_TOTAL else null
		Card.Id.WARD:
			return _on_best(battle, card, func(unit: Unit) -> float:
				if not _threatened(battle, unit):
					return -INF
				return (1000.0 if unit.kind == UnitKind.Id.KING else 0.0) - unit.hp)
		Card.Id.MIGHT:
			return _on_best(battle, card, func(unit: Unit) -> float:
				if not _fights(battle, unit):
					return -INF
				var foe := _nearest_foe(battle, unit)
				if foe == null or Combat.distance(unit.cell, foe.cell) > _reach(unit):
					return -INF
				return unit.power() - foe.hp * 0.1)
		Card.Id.MARCH:
			return _on_best(battle, card, func(unit: Unit) -> float:
				if not _fights(battle, unit):
					return -INF
				var foe := _nearest_foe(battle, unit)
				if foe == null:
					return -INF
				var gap := Combat.distance(unit.cell, foe.cell) - _reach(unit)
				if gap <= 0 or (gap > Card.MARCH_MOVE and not spend):
					return -INF
				return -gap + unit.power() * 0.1)
		Card.Id.ENCORE:
			if _has_pending(battle):
				return null  # 全員が動いてから（もう一度動かす駒を、動いたあとの盤で選ぶ）
			return _on_best(battle, card, func(unit: Unit) -> float:
				if not _fights(battle, unit):
					return -INF
				var foe := _nearest_foe(battle, unit)
				if foe == null or Combat.distance(unit.cell, foe.cell) > _reach(unit):
					return -INF
				return unit.power() - foe.hp * 0.1)
		Card.Id.SHOVE:
			return _shove(battle, spend)
		Card.Id.BLINK:
			return _blink(battle, spend)
	return null


## 札 card の相手に選べる駒のうち、value がいちばん高い駒に使う行動。どの駒も -INF なら null。
static func _on_best(battle: Battle, card: Card.Id, value: Callable) -> PlayCardAction:
	var best := Board.NO_CELL
	var best_value := -INF
	for cell in Hand.targets(battle, card):
		var found: float = value.call(battle.unit_at(cell))
		if found > best_value:
			best = cell
			best_value = found
	return PlayCardAction.new(card, best) if best != Board.NO_CELL else null


## 押し出し。本陣・拠点・回復の泉に乗っている敵をどかす。手札が多ければ、味方がいちばん多く隣り合うマスへ寄せる。
static func _shove(battle: Battle, spend: bool) -> PlayCardAction:
	var me := battle.phase
	var board := battle.board
	var best: PlayCardAction = null
	var best_value := -INF
	for cell in Hand.targets(battle, Card.Id.SHOVE):
		var sits := board.hq_owner(cell) == me or cell == board.stronghold_cell or board.object_at(cell) == MapObject.Type.SPRING
		if not sits and not spend:
			continue
		for spot in Hand.spots(battle, Card.Id.SHOVE, cell):
			var value := 100.0 if sits else 0.0
			for unit in battle.units:
				if unit.side == me and Combat.distance(unit.cell, spot) == 1:
					value += 1.0
			if board.terrain_at(spot) == Terrain.Type.FOREST:
				value -= 1.0
			if value > best_value:
				best = PlayCardAction.new(Card.Id.SHOVE, cell, spot)
				best_value = value
	return best


## 転移。狙われている、HP の少ない味方（将を先に）を、敵からいちばん遠いマスへ逃がす。
## 手札が多ければ、まだ動いていない戦う駒を、敵に手が届くマスへ寄せる。
static func _blink(battle: Battle, spend: bool) -> PlayCardAction:
	var best: PlayCardAction = null
	var best_value := -INF
	for cell in Hand.targets(battle, Card.Id.BLINK):
		var unit := battle.unit_at(cell)
		var flees := _threatened(battle, unit) and unit.hp * 100 <= unit.max_hp() * BLINK_HP_PERCENT
		if not flees and not (spend and _fights(battle, unit)):
			continue
		for spot in Hand.spots(battle, Card.Id.BLINK, cell):
			var near := _FAR
			for foe in battle.units:
				if foe.side != unit.side and foe.side != Unit.Side.NEUTRAL:
					near = mini(near, Combat.distance(spot, foe.cell))
			var value := 0.0
			if flees:
				value = 100.0 + near + (50.0 if unit.kind == UnitKind.Id.KING else 0.0)
			else:
				var before := _nearest_foe(battle, unit)
				if before == null or Combat.distance(cell, before.cell) <= _reach(unit) or near > _reach(unit):
					continue
				value = -absf(near - unit.attack_range())
			if value > best_value:
				best = PlayCardAction.new(Card.Id.BLINK, cell, spot)
				best_value = value
	return best


## unit が、このあと攻撃に使える駒か（まだ動いていないかは、札の相手の決まりが見る）。回復役は除く。将は、ほかに戦う駒がいないときだけ。
static func _fights(battle: Battle, unit: Unit) -> bool:
	if UnitKind.role(unit.kind) == UnitKind.Role.HEALER:
		return false
	if unit.kind != UnitKind.Id.KING:
		return true
	for other in battle.units:
		if other.side == unit.side and other.kind != UnitKind.Id.KING and UnitKind.role(other.kind) != UnitKind.Role.HEALER:
			return false
	return true


## unit が動いてから手の届く歩数（移動力 + 動いたあとの射程）。
static func _reach(unit: Unit) -> int:
	return unit.move_range() + Statuses.stat_after_move(unit, Unit.Stat.ATTACK_RANGE)


static func _nearest_foe(battle: Battle, unit: Unit) -> Unit:
	var best: Unit = null
	var best_distance := _FAR
	for other in battle.units:
		if other.side == unit.side or other.side == Unit.Side.NEUTRAL:
			continue
		var distance := Combat.distance(unit.cell, other.cell)
		if distance < best_distance:
			best = other
			best_distance = distance
	return best


## 相手の駒のどれかが、次の番に unit へ手が届きそうか（歩数だけで見る）。
static func _threatened(battle: Battle, unit: Unit) -> bool:
	for foe in battle.units:
		if foe.side == unit.side or foe.side == Unit.Side.NEUTRAL:
			continue
		if Combat.distance(unit.cell, foe.cell) <= foe.move_range() + foe.attack_range():
			return true
	return false


static func _has_pending(battle: Battle) -> bool:
	for unit in battle.units:
		if battle.can_act(unit):
			return true
	return false
