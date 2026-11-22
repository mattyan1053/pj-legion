class_name Formation
extends RefCounted
## 組み方（選べる決まり OptionalRules.FORMATION。docs/formation.md）。軍ごとに、組み合わせの決まりが違う。
##
## 連邦（MILITARY）の「分隊」: 同じ兵種が 2 体以上（SQUAD_SIZE）盤に残っている間、その兵種の駒は分隊。数えるのは、いま盤にいる駒だけなので、
## 1 体倒されても、同じ兵種が 2 体以上残れば続く。
## - 肩並べ（Effect.SQUAD_GUARD）: 周り 8 マスに同じ分隊の仲間がいる駒は、攻撃で受けるダメージ -SQUAD_GUARD
## - 追い撃ち（Effect.SQUAD_FOCUS）: このフェーズに同じ分隊の仲間が攻撃した相手を攻撃すると、ダメージ +SQUAD_FOCUS
##
## 騎士領（FANTASY）の「誓い」: 編成で 2 人を結ぶ（Deck.oaths。1 部隊に MAX_OATHS 組まで）。
## - 仇討ち（Effect.OATH_VENGEANCE）: 誓いの相手を最後に攻撃した敵を攻撃すると、ダメージ +OATH_VENGEANCE。
##   誓いの相手が OATH_RANGE マス以内にいる間だけ
## - 誓いの果て（Effect.OATH_RESOLVE）: 片方が倒れると、残った側に「奮起」（Status.Type.RESOLVE。攻撃 +RESOLVE_POWER）が
##   次の自分のフェーズの終わりまで付き、誓いは切れる
##
## 決まりが切の対戦（Battle.formation が偽）では、どれも何もしない（数も、イベントも変わらない）。
## 効果は駒の攻撃（Combat.hit）にだけ掛かる。スキルのダメージと樽の爆発には掛からない。

## 効果の種類。FormationTriggeredEvent と、ダメージの内訳（Hit.formation）が持つ。
enum Effect {
	SQUAD_GUARD,  ## 肩並べ（受けるダメージが減る）
	SQUAD_FOCUS,  ## 追い撃ち（与えるダメージが増える）
	OATH_VENGEANCE,  ## 仇討ち（与えるダメージが増える）
	OATH_RESOLVE,  ## 誓いの果て（奮起が付く。OathBrokenEvent）
}

## 分隊になる、同じ兵種の数。
const SQUAD_SIZE := 2
## 肩並べで、攻撃で受けるダメージから引く量。
const SQUAD_GUARD := 2
## 追い撃ちで、与えるダメージに足す量。
const SQUAD_FOCUS := 3
## 1 部隊で結べる誓いの数。
const MAX_OATHS := 2
## 誓いの 2 人が、この距離（マンハッタン距離）以内にいる間、仇討ちが効く。
const OATH_RANGE := 3
## 仇討ちで、与えるダメージに足す量。
const OATH_VENGEANCE := 3
## 奮起の攻撃力（回復役は回復量）の上がり幅。
const RESOLVE_POWER := 4


## その軍の組み方の効果（Effect の並び）。軍でなければ空。
static func effects_of(army: UnitKind.Army) -> Array[Effect]:
	match army:
		UnitKind.Army.MILITARY:
			return [Effect.SQUAD_GUARD, Effect.SQUAD_FOCUS]
		UnitKind.Army.FANTASY:
			return [Effect.OATH_VENGEANCE, Effect.OATH_RESOLVE]
	return []


## その軍の駒が、編成で誓いを結べるか（騎士領だけ）。
static func binds_oaths(army: UnitKind.Army) -> bool:
	return army == UnitKind.Army.FANTASY


## その種類が分隊を作るか（連邦の、将でない駒）。
static func forms_squads(kind: UnitKind.Id) -> bool:
	return UnitKind.army(kind) == UnitKind.Army.MILITARY


# ---- 編成から読むもの（対戦の前。画面と CPU の編成） ----


## 編成で、分隊になる兵種（同じ兵種が SQUAD_SIZE 体以上。並びは編成のロスターの順）。連邦でなければ空。
static func squad_kinds(deck: Deck) -> Array[UnitKind.Id]:
	var result: Array[UnitKind.Id] = []
	if deck == null:
		return result
	for kind in deck.available_kinds():
		if forms_squads(kind) and deck.entries.filter(func(entry: DeckEntry) -> bool: return entry.kind == kind).size() >= SQUAD_SIZE:
			result.append(kind)
	return result


# ---- 対戦の準備 ----


## 置いた駒 placed（将が先頭、あとは編成の並びの順。Deployment.deploy の返り値）に、編成の誓いを写す（決まりが入の対戦だけ。MatchSetup.create_battle）。
static func arm(battle: Battle, deck: Deck, placed: Array[Unit]) -> void:
	if not battle.formation or deck == null or not binds_oaths(deck.army):
		return
	var units := placed.filter(func(unit: Unit) -> bool: return unit.kind != UnitKind.Id.KING)
	for pair in deck.oath_pairs():
		var a: int = pair.x
		var b: int = pair.y
		if a < units.size() and b < units.size():
			bind(units[a], units[b])


## 2 体を誓いで結ぶ。
static func bind(a: Unit, b: Unit) -> void:
	a.oath_partner = b.id
	b.oath_partner = a.id


# ---- 対戦中に読むもの ----


## unit が分隊にいるか（決まりが入で、連邦の将でない駒で、同じ陣営の同じ兵種が盤に SQUAD_SIZE 体以上いる）。
static func in_squad(battle: Battle, unit: Unit) -> bool:
	return not squad_of(battle, unit).is_empty()


## unit の分隊（unit を含む、同じ陣営の同じ兵種の駒。番号の順）。分隊でなければ空。
static func squad_of(battle: Battle, unit: Unit) -> Array[Unit]:
	var result: Array[Unit] = []
	if not battle.formation or unit == null or unit.side == Unit.Side.NEUTRAL or not forms_squads(unit.kind):
		return result
	for other in battle.units:
		if other.side == unit.side and other.kind == unit.kind:
			result.append(other)
	if result.size() < SQUAD_SIZE:
		result.clear()
	return result


## unit が肩並べ（周り 8 マスに同じ分隊の仲間）になっているか。
static func guarded(battle: Battle, unit: Unit) -> bool:
	return guarded_at(battle, unit, unit.cell)


## unit が cell に立ったら、肩並べになるか（CPU が立つマスを比べるのに使う）。
static func guarded_at(battle: Battle, unit: Unit, cell: Vector2i) -> bool:
	for mate in squad_of(battle, unit):
		if mate != unit and maxi(absi(mate.cell.x - cell.x), absi(mate.cell.y - cell.y)) == 1:
			return true
	return false


## attacker が target を攻撃すると、追い撃ちになるか（このフェーズに、同じ分隊の仲間が target を攻撃した）。
static func focus_on(battle: Battle, attacker: Unit, target: Unit) -> bool:
	if not in_squad(battle, attacker):
		return false
	var by: Array = battle.focus_marks.get(target.id, [])
	return by.has(attacker.kind)


## unit の誓いの相手（盤にいれば）。結んでいないか、相手が倒れていれば null。
static func partner_of(battle: Battle, unit: Unit) -> Unit:
	if not battle.formation or unit == null or unit.oath_partner == 0:
		return null
	var partner := battle.unit_by_id(unit.oath_partner)
	return partner if partner != null and partner.oath_partner == unit.id else null


## unit が、誓いの相手から OATH_RANGE マス以内にいるか。
static func oath_near(battle: Battle, unit: Unit) -> bool:
	var partner := partner_of(battle, unit)
	return partner != null and Combat.distance(partner.cell, unit.cell) <= OATH_RANGE


## unit の誓いの相手を、最後に攻撃した敵（仇）。いなければ null。
static func foe_of_partner(battle: Battle, unit: Unit) -> Unit:
	var partner := partner_of(battle, unit)
	if partner == null or partner.oath_foe == 0:
		return null
	return battle.unit_by_id(partner.oath_foe)


## attacker が target を攻撃すると、仇討ちになるか（target が誓いの相手を最後に攻撃した敵で、誓いの相手が近くにいる）。
static func vengeance_on(battle: Battle, attacker: Unit, target: Unit) -> bool:
	return oath_near(battle, attacker) and foe_of_partner(battle, attacker) == target


## attacker が target を攻撃するときに足すダメージの内訳（Effect -> 量）。無ければ空。
static func attack_boosts(battle: Battle, attacker: Unit, target: Unit) -> Dictionary:
	var result := {}
	if not battle.formation:
		return result
	if focus_on(battle, attacker, target):
		result[Effect.SQUAD_FOCUS] = SQUAD_FOCUS
	if vengeance_on(battle, attacker, target):
		result[Effect.OATH_VENGEANCE] = OATH_VENGEANCE
	return result


## target が攻撃で受けるダメージから引く量（肩並べ）。
static func guard_of(battle: Battle, target: Unit) -> int:
	return SQUAD_GUARD if guarded(battle, target) else 0


# ---- 起きたこと ----


## 駒の攻撃のあとに覚えること（Combat.strike が、ダメージを当てたあとに呼ぶ。煙幕に阻まれた攻撃では呼ばない）。
## - attacker が分隊にいれば、このフェーズに target をその兵種が攻撃したと覚える（追い撃ち）
## - target が誓いを結んでいれば、attacker を仇として覚える（仇討ち。上書きする）
static func note_attack(battle: Battle, attacker: Unit, target: Unit) -> void:
	if not battle.formation:
		return
	if in_squad(battle, attacker):
		var by: Array = battle.focus_marks.get(target.id, [])
		if not by.has(attacker.kind):
			by.append(attacker.kind)
		battle.focus_marks[target.id] = by
	if partner_of(battle, target) != null:
		target.oath_foe = attacker.id


## 駒 fallen が倒れたあと（Battle.remove_unit が、盤から取り除いたあとに呼ぶ）。
## 誓いの相手が残っていれば、その駒に奮起を付け（OathBrokenEvent、StatusAppliedEvent）、誓いを切る。
static func on_defeated(battle: Battle, fallen: Unit) -> Array[BattleEvent]:
	var events: Array[BattleEvent] = []
	if not battle.formation or fallen.oath_partner == 0:
		return events
	var survivor := battle.unit_by_id(fallen.oath_partner)
	fallen.oath_partner = 0
	if survivor == null or survivor.oath_partner != fallen.id:
		return events
	survivor.oath_partner = 0
	survivor.oath_foe = 0
	events.append(OathBrokenEvent.new(survivor.id, fallen.id))
	# 次の自分のフェーズの終わりまで（自分のフェーズの途中なら、このフェーズの終わりまで）。
	var turns := 1 if battle.phase == survivor.side else 2
	events.append(Statuses.add(survivor, Status.Type.RESOLVE, turns))
	return events


## フェーズの始めに、追い撃ちの覚えを消す（EndPhaseAction）。
static func start_phase(battle: Battle) -> void:
	battle.focus_marks.clear()
