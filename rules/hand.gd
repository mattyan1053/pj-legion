class_name Hand
extends RefCounted
## 手札（試しの決まり OptionalRules.HAND。docs/hand-cards.md）。札を配る・引く・使う処理。
##
## 状態は対戦が持つ（Battle.hand_on、hands、piles、card_played）。ここの問い合わせは状態を変えない。
## 状態を変えるのは arm（対戦を作るとき）、start_phase（EndPhaseAction が呼ぶ）、play（PlayCardAction が呼ぶ）。
##
## - 軍ごとの札の山（Card.PILES）を、対戦の種で混ぜる（対戦の乱数 Battle.rng は進めない）
## - 始めに START_CARDS 枚。自分の番の始めに 1 枚引く（手札が HAND_LIMIT 枚なら引かない。山が尽きたら引かない）
## - 自分の番に 1 枚だけ使える。駒の行動は使わない。行動の途中の駒がいる間は使えない
## - 脅威範囲と CPU の危険の読みは、相手の手札を数えない

# ---- 調整値 ----

## 始めの手札の枚数、手札の上限、自分の番の始めに引く枚数、1 つの番に使える枚数。
const START_CARDS := 3
const HAND_LIMIT := 5
const DRAW_PER_PHASE := 1
const PLAYS_PER_PHASE := 1


## 対戦に手札を付ける（MatchSetup.create_battle が、軍を置いたあとに呼ぶ）。山を混ぜ、始めの手札を配る。出来事は無い。
static func arm(battle: Battle, battle_seed: int) -> void:
	battle.hand_on = true
	for side: Unit.Side in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
		var pile := Card.pile_of(battle.armies[side])
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([&"hand", battle_seed, side])
		for i in range(pile.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var held := pile[i]
			pile[i] = pile[j]
			pile[j] = held
		battle.piles[side] = pile
		battle.hands[side] = []
		battle.card_plays[side] = 0
		for i in START_CARDS:
			_take(battle, side)


## 山の上（並びの最後）から 1 枚、手札へ。引けなければ -1。
static func _take(battle: Battle, side: Unit.Side) -> int:
	if battle.piles[side].is_empty() or battle.hands[side].size() >= HAND_LIMIT:
		return -1
	var card: int = battle.piles[side].pop_back()
	battle.hands[side].append(card)
	return card


## side のフェーズの始め（EndPhaseAction が、必殺技のゲージのあとに呼ぶ）。使った数を戻し、1 枚引く（CardDrawnEvent）。
static func start_phase(battle: Battle, side: Unit.Side) -> Array[BattleEvent]:
	var events: Array[BattleEvent] = []
	if not battle.hand_on or side == Unit.Side.NEUTRAL:
		return events
	battle.card_plays[side] = 0
	for i in DRAW_PER_PHASE:
		var card := _take(battle, side)
		if card != -1:
			events.append(CardDrawnEvent.new(side, card as Card.Id, battle.hands[side].size(), battle.piles[side].size()))
	return events


## side の手札（Card.Id の並び。引いた順）。
static func of(battle: Battle, side: Unit.Side) -> Array[int]:
	var cards: Array[int] = []
	if battle.hand_on and side < battle.hands.size():
		cards.assign(battle.hands[side])
	return cards


## side の山の残りの枚数。
static func pile_left(battle: Battle, side: Unit.Side) -> int:
	return battle.piles[side].size() if battle.hand_on and side < battle.piles.size() else 0


## いまのフェーズのプレイヤーが、いま札を使える状態か（どの札かは見ない）。
static func can_play_now(battle: Battle) -> bool:
	if not battle.hand_on or battle.is_over() or battle.phase == Unit.Side.NEUTRAL:
		return false
	return battle.card_plays[battle.phase] < PLAYS_PER_PHASE and battle.acting_unit_id == 0


## いまのフェーズのプレイヤーが、札 card をいま使えるか（手にあり、相手に選べるものが 1 つはある）。
static func can_play(battle: Battle, card: Card.Id) -> bool:
	if not can_play_now(battle) or not battle.hands[battle.phase].has(card):
		return false
	return Card.aim(card) == Card.Aim.NONE or not targets(battle, card).is_empty()


## いまのフェーズのプレイヤーが、札 card の相手に選べる駒のマス。上の行から、左の列から。相手を選ばない札では空。
static func targets(battle: Battle, card: Card.Id) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if Card.aim(card) == Card.Aim.NONE or battle.phase == Unit.Side.NEUTRAL:
		return cells
	for unit in battle.units:
		if _suits(battle, card, unit):
			cells.append(unit.cell)
	cells.sort_custom(Board.in_reading_order)
	return cells


static func _suits(battle: Battle, card: Card.Id, unit: Unit) -> bool:
	var side := battle.phase
	if Card.aims_at_foe(card):
		if unit.side == side or unit.side == Unit.Side.NEUTRAL:
			return false
	elif unit.side != side:
		return false
	match card:
		Card.Id.MARCH:
			return not unit.acted and not unit.is_rooted()
		Card.Id.MIGHT:
			return not unit.acted
		Card.Id.MEND:
			return Mend.amount(unit, Card.MEND_HEAL) > 0
		Card.Id.ENCORE:
			return unit.acted
		Card.Id.WARD:
			return not Statuses.has(unit, Status.Type.BARRIER)
		Card.Id.SHOVE:
			return _has_neighbor_of(battle, unit.cell, side) and not spots(battle, card, unit.cell).is_empty()
		Card.Id.BLINK:
			return not spots(battle, card, unit.cell).is_empty()
	return false


static func _has_neighbor_of(battle: Battle, cell: Vector2i, side: Unit.Side) -> bool:
	for unit in battle.units:
		if unit.side == side and Combat.distance(unit.cell, cell) == 1:
			return true
	return false


## 駒を動かす札（Card.Aim.UNIT_THEN_CELL）で、target の駒を動かせる先のマス。上の行から、左の列から。ほかの札では空。
## 押し出しは隣の 4 マス、転移は BLINK_RANGE 歩の中の、駒が立てる空いたマス。
static func spots(battle: Battle, card: Card.Id, target: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if Card.aim(card) != Card.Aim.UNIT_THEN_CELL:
		return cells
	var reach := 1 if card == Card.Id.SHOVE else Card.BLINK_RANGE
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var cell := target + Vector2i(dx, dy)
			var steps := absi(dx) + absi(dy)
			if steps == 0 or steps > reach:
				continue
			if battle.board.is_walkable(cell) and battle.unit_at(cell) == null:
				cells.append(cell)
	cells.sort_custom(Board.in_reading_order)
	return cells


## いまのフェーズのプレイヤーが、札 card を target（と spot）に使えるか（PlayCardAction が受け付けるか）。
static func can_play_at(battle: Battle, card: Card.Id, target: Vector2i, spot: Vector2i) -> bool:
	if not can_play(battle, card):
		return false
	match Card.aim(card):
		Card.Aim.NONE:
			return true
		Card.Aim.UNIT:
			return targets(battle, card).has(target)
	return targets(battle, card).has(target) and spots(battle, card, target).has(spot)


## いまのフェーズのプレイヤーが札を使う（使えるかどうかは呼ぶ側が確かめる）。起きたことを返す。
## CardPlayedEvent、札の効果のイベントの順。札は手札から無くなる（山へは戻らない）。
static func play(battle: Battle, card: Card.Id, target: Vector2i, spot: Vector2i) -> Array[BattleEvent]:
	var side := battle.phase
	battle.hands[side].erase(card)
	battle.card_plays[side] += 1
	var unit := battle.unit_at(target) if Card.aim(card) != Card.Aim.NONE else null
	var events: Array[BattleEvent] = [
		CardPlayedEvent.new(side, card, unit.id if unit != null else 0, target, spot, battle.hands[side].size())
	]
	match card:
		Card.Id.MARCH:
			events.append(Statuses.add(unit, Status.Type.HASTE, Card.BOOST_TURNS))
		Card.Id.MIGHT:
			events.append(Statuses.add(unit, Status.Type.MIGHT, Card.BOOST_TURNS))
		Card.Id.MEND:
			events.append(Mend.give(unit, Card.MEND_HEAL, CardHealedEvent.new(card)))
		Card.Id.RESUPPLY:
			for friend in battle.units:
				if friend.side == side and Mend.amount(friend, Card.RESUPPLY_HEAL) > 0:
					events.append(Mend.give(friend, Card.RESUPPLY_HEAL, CardHealedEvent.new(card)))
		Card.Id.ENCORE:
			unit.reset_action()
			events.append(UnitReactivatedEvent.new(unit.id))
			events.append(Statuses.add(unit, Status.Type.FATIGUE, AdrenalineShotSkill.FATIGUE_TURNS))
		Card.Id.WARD:
			events.append(Statuses.add(unit, Status.Type.BARRIER, DivineShieldSkill.BARRIER_TURNS))
		Card.Id.SHOVE:
			unit.cell = spot
			events.append(UnitPushedEvent.new(unit.id, target, spot))
			events.append_array(Statuses.displace(unit))
		Card.Id.BLINK:
			unit.cell = spot
			events.append(UnitTeleportedEvent.new(unit.id, target, spot))
			events.append_array(Statuses.displace(unit))
	return events
