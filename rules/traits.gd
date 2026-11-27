class_name Traits
extends RefCounted
## 軍略（docs/troop-traits.md）。軍ごとに 3 つあり、部隊編成で部隊ごとに 1 つ選ぶ。入・切は無い。
## 対戦モードでは、両方の部隊がいつも軍略を 1 つ持つ（MatchSetup.create_battle が部隊から写す）。
## ストーリーの話は、話のファイルが書いたときだけ持つ（Scenario.traits）。
##
## 連邦（MILITARY）
## - 集中砲火（FOCUS）: このターンに味方が攻撃した敵を攻撃すると、ダメージ +FOCUS_BONUS（自分の攻撃は数えない）
## - 隊列（RANKS）: 同じ兵種の味方と隣り合う兵は、攻撃で受けるダメージ -RANKS_GUARD
## - 補給線（SUPPLY）: 自分のターンの始めに、回復役と隣り合う兵の HP が SUPPLY_HEAL 回復する
## 騎士領（FANTASY）
## - 仇討ち（VENGEANCE）: 味方を倒した敵を攻撃すると、ダメージ +VENGEANCE_BONUS
## - 誓い（OATH）: 誓いを結んだ 2 人（編成で結ぶ。MAX_OATHS 組まで）が同じターンに同じ敵を攻撃すると、2 人目のダメージ +OATH_BONUS
## - 守護（GUARD）: パラディンと隣り合う兵（パラディンどうしも）は、攻撃で受けるダメージ -GUARD_SHIELD
##
## 「隣」は上下左右の 1 マス（マンハッタン距離 1）。数えるのは将も含めた、同じ陣営の駒。
## ダメージの増減は駒の攻撃（Combat.hit）にだけ掛かる。スキルのダメージと樽の爆発には掛からない。

enum Id {
	FOCUS,  ## 集中砲火（連邦）
	RANKS,  ## 隊列（連邦）
	SUPPLY,  ## 補給線（連邦）
	VENGEANCE,  ## 仇討ち（騎士領）
	OATH,  ## 誓い（騎士領）
	GUARD,  ## 守護（騎士領）
}

## 軍略が無い（ストーリーの話で書いていない陣営、中立）。
const NONE := -1

## 集中砲火で、与えるダメージに足す量。
const FOCUS_BONUS := 2
## 隊列で、攻撃で受けるダメージから引く量。
const RANKS_GUARD := 4
## 補給線で、ターンの始めに回復する量。
const SUPPLY_HEAL := 4
## 仇討ちで、与えるダメージに足す量。
const VENGEANCE_BONUS := 4
## 誓いで、2 人目のダメージに足す量。
const OATH_BONUS := 5
## 守護で、攻撃で受けるダメージから引く量。
const GUARD_SHIELD := 3
## 1 部隊で結べる誓いの数。
const MAX_OATHS := 2

## 守護で、隣の味方を守る兵の種類。
const GUARDIAN := UnitKind.Id.PALADIN


## その軍の軍略（並びは部隊編成の札の順。軍の表 Armies の traits）。軍でなければ空。
static func of_army(army: UnitKind.Army) -> Array[Id]:
	var result: Array[Id] = []
	result.assign(Armies.traits(army))
	return result


## その軍の既定の軍略（並びの最初。新しい部隊と、軍略を書いていない取っておいた部隊）。軍でなければ NONE。
static func default_of(army: UnitKind.Army) -> int:
	var all := of_army(army)
	return all[0] if not all.is_empty() else NONE


## その軍略の軍。
static func army_of(id: int) -> UnitKind.Army:
	for army in Armies.all():
		if Armies.traits(army).has(id):
			return army
	return UnitKind.Army.NONE


## 鍵（小文字の名前。部隊の保存と話のファイルが使う）。
static func key(id: int) -> String:
	return Id.keys()[id].to_lower() if id >= 0 and id < Id.size() else ""


## 鍵から軍略。知らない鍵なら NONE。
static func from_key(word: String) -> int:
	var index := Id.keys().find(word.strip_edges().to_upper())
	return index


# ---- 対戦の準備 ----


## 陣営 side の軍略を id にし、誓いなら、部隊 deck の誓いを置いた駒 placed（将が先頭、あとは部隊の並びの順）に写す。
static func arm(battle: Battle, side: Unit.Side, id: int, deck: Deck, placed: Array[Unit]) -> void:
	battle.traits[side] = id
	if id != Id.OATH or deck == null:
		return
	var units := placed.filter(func(unit: Unit) -> bool: return unit.kind != UnitKind.Id.KING)
	for pair in deck.oath_pairs():
		if pair.x < units.size() and pair.y < units.size():
			bind(units[pair.x], units[pair.y])


## 2 体を誓いで結ぶ。
static func bind(a: Unit, b: Unit) -> void:
	a.oath_partner = b.id
	b.oath_partner = a.id


# ---- 対戦中に読むもの ----


## 陣営 side の軍略。中立なら NONE。
static func of_side(battle: Battle, side: Unit.Side) -> int:
	return battle.traits[side] if side != Unit.Side.NEUTRAL else NONE


## unit の陣営が、軍略 id を持っているか。
static func has(battle: Battle, unit: Unit, id: Id) -> bool:
	return unit != null and of_side(battle, unit.side) == id


## 2 つのマスが隣（上下左右）か。
static func adjacent(a: Vector2i, b: Vector2i) -> bool:
	return absi(a.x - b.x) + absi(a.y - b.y) == 1


## unit が cell に立ったときの、隣の味方（同じ陣営の駒。unit は除く）。
static func neighbors_at(battle: Battle, unit: Unit, cell: Vector2i) -> Array[Unit]:
	var result: Array[Unit] = []
	for other in battle.units:
		if other != unit and other.side == unit.side and adjacent(other.cell, cell):
			result.append(other)
	return result


## 隊列: unit が cell に立ったら、同じ兵種の味方と隣り合うか（隊列の陣営の駒だけ）。
static func ranked_at(battle: Battle, unit: Unit, cell: Vector2i) -> bool:
	if not has(battle, unit, Id.RANKS):
		return false
	return neighbors_at(battle, unit, cell).any(func(other: Unit) -> bool: return other.kind == unit.kind)


## 守護: unit が cell に立ったら、隣り合うパラディン（守護の陣営の駒だけ。unit 自身は除く）。いなければ null。
static func guardian_at(battle: Battle, unit: Unit, cell: Vector2i) -> Unit:
	if not has(battle, unit, Id.GUARD):
		return null
	for other in neighbors_at(battle, unit, cell):
		if other.kind == GUARDIAN:
			return other
	return null


## 補給線: unit が cell に立ったら、隣り合う回復役（補給線の陣営の駒だけ。unit 自身は除く）。いなければ null。
static func supplier_at(battle: Battle, unit: Unit, cell: Vector2i) -> Unit:
	if not has(battle, unit, Id.SUPPLY):
		return null
	for other in neighbors_at(battle, unit, cell):
		if UnitKind.role(other.kind) == UnitKind.Role.HEALER:
			return other
	return null


## このターンに、陣営 side の駒が target を攻撃したか（except の駒の攻撃は数えない）。
static func struck_by_side(battle: Battle, target: Unit, side: Unit.Side, except: Unit = null) -> bool:
	for mark: Vector2i in battle.struck.get(target.id, []):
		if mark.y == int(side) and (except == null or mark.x != except.id):
			return true
	return false


## 集中砲火の印: target が、このターンに陣営 side（集中砲火の陣営）の駒に攻撃されているか。
static func focus_marked(battle: Battle, target: Unit, side: Unit.Side) -> bool:
	return of_side(battle, side) == Id.FOCUS and target.side != side and struck_by_side(battle, target, side)


## 仇の印: target が、陣営 side の駒を倒したことがあるか（その陣営が仇討ちでなくても覚えている）。
static func slew(target: Unit, side: Unit.Side) -> bool:
	return side != Unit.Side.NEUTRAL and (target.slew_sides & (1 << int(side))) != 0


## 仇討ちの印: target が、陣営 side（仇討ちの陣営）の仇か。
static func vengeance_marked(battle: Battle, target: Unit, side: Unit.Side) -> bool:
	return of_side(battle, side) == Id.VENGEANCE and target.side != side and slew(target, side)


## unit の誓いの相手（盤にいれば）。結んでいないか、相手が倒れていれば null。
static func partner_of(battle: Battle, unit: Unit) -> Unit:
	if unit == null or unit.oath_partner == 0 or not has(battle, unit, Id.OATH):
		return null
	var partner := battle.unit_by_id(unit.oath_partner)
	return partner if partner != null and partner.oath_partner == unit.id else null


## 誓いの印: target が、このターンに unit の誓いの相手に攻撃されているか（unit が攻撃すると誓いが効く）。
static func oath_marked(battle: Battle, unit: Unit, target: Unit) -> bool:
	var partner := partner_of(battle, unit)
	if partner == null:
		return false
	for mark: Vector2i in battle.struck.get(target.id, []):
		if mark.x == partner.id:
			return true
	return false


## attacker が target を攻撃するときに足すダメージ（軍略 -> 量）。無ければ空。
static func attack_boosts(battle: Battle, attacker: Unit, target: Unit) -> Dictionary:
	var result := {}
	if attacker.side == Unit.Side.NEUTRAL or target.side == attacker.side:
		return result
	match of_side(battle, attacker.side):
		Id.FOCUS:
			if struck_by_side(battle, target, attacker.side, attacker):
				result[Id.FOCUS] = FOCUS_BONUS
		Id.VENGEANCE:
			if slew(target, attacker.side):
				result[Id.VENGEANCE] = VENGEANCE_BONUS
		Id.OATH:
			if oath_marked(battle, attacker, target):
				result[Id.OATH] = OATH_BONUS
	return result


## target が攻撃で受けるダメージから引く量（隊列か守護）。
static func guard_of(battle: Battle, target: Unit) -> int:
	return guard_at(battle, target, target.cell)


## unit が cell に立ったら、攻撃で受けるダメージから引く量（隊列か守護。CPU は動いた先で読む）。
static func guard_at(battle: Battle, unit: Unit, cell: Vector2i) -> int:
	if ranked_at(battle, unit, cell):
		return RANKS_GUARD
	if guardian_at(battle, unit, cell) != null:
		return GUARD_SHIELD
	return 0


## 受けるダメージを減らす軍略か（隊列・守護。効いたときの「軍略を持つ側の駒」は攻撃された駒）。
static func shields(id: int) -> bool:
	return id == Id.RANKS or id == Id.GUARD


# ---- 起きたこと ----


## 駒の攻撃のあとに覚えること（Combat.strike が、ダメージを当てたあとに呼ぶ。煙幕に阻まれた攻撃では呼ばない）。
## このターンに target を attacker（番号と陣営）が攻撃した（集中砲火と誓いが読む）。
static func note_attack(battle: Battle, attacker: Unit, target: Unit) -> void:
	if attacker.side == Unit.Side.NEUTRAL:
		return
	var marks: Array = battle.struck.get(target.id, [])
	var mark := Vector2i(attacker.id, int(attacker.side))
	if not marks.has(mark):
		marks.append(mark)
	battle.struck[target.id] = marks


## 駒 fallen が by に倒された（Battle.remove_unit が呼ぶ）。by に、fallen の陣営の仇の印を付ける（仇討ちが読む）。
## 誓いの相手が倒れたら、残った駒の誓いは切れる（もう結んでいない）。
static func on_defeated(battle: Battle, fallen: Unit, by: Unit) -> void:
	if by != null and by != fallen and by.hp > 0 and fallen.side != Unit.Side.NEUTRAL and by.side != fallen.side:
		by.slew_sides |= 1 << int(fallen.side)
	if fallen.oath_partner != 0:
		var survivor := battle.unit_by_id(fallen.oath_partner)
		if survivor != null and survivor.oath_partner == fallen.id:
			survivor.oath_partner = 0
		fallen.oath_partner = 0


## フェーズの始め（EndPhaseAction）。このターンの攻撃の覚えを消し、補給線の陣営なら、回復役と隣り合う駒が回復する（SupplyHealedEvent）。
## 回復するのは、そのフェーズの陣営の駒だけ。並びは駒の番号の順。
static func start_phase(battle: Battle, side: Unit.Side) -> Array[BattleEvent]:
	battle.struck.clear()
	var events: Array[BattleEvent] = []
	if of_side(battle, side) != Id.SUPPLY:
		return events
	for unit: Unit in battle.units.duplicate():
		if unit.side != side or unit.hp >= unit.max_hp():
			continue
		var medic := supplier_at(battle, unit, unit.cell)
		if medic == null:
			continue
		events.append(Mend.give(unit, SUPPLY_HEAL, SupplyHealedEvent.new(medic.id)))
	return events
