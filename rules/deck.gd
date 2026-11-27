class_name Deck
extends RefCounted
## プレイヤー 1 人の編成。選んだ軍と、雇った駒（将を除く）の並び。
##
## 将は編成に含めない。軍を盤に置くとき（Deployment.deploy）に、1 体だけ自動で加わる。
## どの駒を雇えるか・予算・数の上限は、編成の決まり（DeckRules。既定は対戦の決まり）が決める。
## 雇えるのは、選んだ軍のロスターの駒だけ。軍を変えるときは、編成を作り直す。
## 対戦に出せる形かどうかは problems() / is_valid() で調べる（docs/deck-building.md）。
## 編成の途中は、通らない形（駒が 0 体、予算を超えている）にもなる。

## 編成が対戦に出せない理由。
enum Problem {
	NO_UNITS,  ## 雇った駒が 1 体もいない
	TOO_MANY_UNITS,  ## 雇った駒が決まりの上限（対戦の決まりでは MAX_UNITS）を超えている
	OVER_BUDGET,  ## 合計コストが予算を超えている
	TOO_MUCH_EQUIPMENT,  ## 装備を持てる数を超えて持っている駒がいる
	NOT_IN_ROSTER,  ## この軍のロスターに無い駒がいる
	ITEM_NOT_ALLOWED,  ## 決まりで持たせられない装備を持っている駒がいる
	ITEM_NOT_FIT,  ## その駒が持てない装備（役割の限り、重ねられない装備の 2 個目）を持っている駒がいる
}

## 対戦の決まりで雇える駒の数の上限（将を除く）。
const MAX_UNITS := 6

var army: UnitKind.Army
var entries: Array[DeckEntry] = []
## この編成の決まり（ロスター、予算、数の上限）。
var rules: DeckRules
## 軍略（Traits.Id。docs/troop-traits.md）。その軍の 3 つから 1 つ。作ったときは軍の既定（Traits.default_of）。
## 対戦モードで使う。ストーリーの話は、自分で部隊を選ぶ話だけ、教わった軍略から（DeckRules.trait_for。部隊が決まっている話は、話のファイルが決める）。
var trait_id := Traits.NONE
## 誓い（軍略の「誓い」。Traits）で結んだ 2 体の組（[DeckEntry, DeckEntry] の並び）。騎士領だけ。軍略が誓いの部隊で効く。
## 結ぶ・ほどくのは bind / unbind（1 体は 1 組まで、Traits.MAX_OATHS 組まで）。駒を外すと、その組もほどける。
## 軍略を替えても、結んだ組は残る（誓いに戻すと、また効く）。
var oaths: Array[Array] = []


## deck_rules を渡さなければ、対戦の決まり（DeckRules.versus()）で組む。
func _init(deck_army: UnitKind.Army, deck_rules: DeckRules = null) -> void:
	army = deck_army
	rules = deck_rules if deck_rules != null else DeckRules.versus()
	trait_id = Traits.default_of(army)


## 対戦の決まりで、その軍が雇える駒の種類。並びは 前衛・後衛・奇襲・回復。
static func roster(of_army: UnitKind.Army) -> Array[UnitKind.Id]:
	return DeckRules.versus().roster(of_army)


## 対戦の決まりでの、その軍の予算。軍でなければ 0。
static func budget_of(of_army: UnitKind.Army) -> int:
	return DeckRules.versus().budget(of_army)


## この編成の予算（決まりと軍で決まる）。
func budget() -> int:
	return rules.budget(army)


## この編成で雇える駒の種類（決まりと軍で決まる）。
func available_kinds() -> Array[UnitKind.Id]:
	return rules.roster(army)


## 駒を 1 体雇う。この軍のロスターに無い種類か、もう雇えなければ（上限に達している）、何もせず null。
## 予算は見ない（超えた編成は作れて、検査で分かる）。
func add(kind: UnitKind.Id) -> DeckEntry:
	if not _in_roster(kind) or entries.size() >= rules.max_units:
		return null
	var entry := DeckEntry.new(kind)
	entries.append(entry)
	return entry


## 駒を 1 体外す。この編成の駒でなければ何もせず false。
func remove(entry: DeckEntry) -> bool:
	var index := entries.find(entry)
	if index == -1:
		return false
	entries.remove_at(index)
	unbind(entry)
	return true


## 2 体を誓いで結ぶ（docs/troop-traits.md）。結べなければ（誓いを持てる軍（騎士領）でない、どちらかがこの編成に無い、同じ駒、もう誓いを結んでいる、組の数が上限）何もせず false。
func bind(a: DeckEntry, b: DeckEntry) -> bool:
	if not can_bind(a, b):
		return false
	oaths.append([a, b])
	return true


## 2 体を誓いで結べるか。
func can_bind(a: DeckEntry, b: DeckEntry) -> bool:
	if not Traits.of_army(army).has(Traits.Id.OATH) or a == b or not entries.has(a) or not entries.has(b):
		return false
	if partner_of(a) != null or partner_of(b) != null:
		return false
	return oaths.size() < Traits.MAX_OATHS


## entry の誓いをほどく。結んでいなければ何もせず false。
func unbind(entry: DeckEntry) -> bool:
	for i in oaths.size():
		if oaths[i].has(entry):
			oaths.remove_at(i)
			return true
	return false


## entry と誓いを結んでいる駒。結んでいなければ null。
func partner_of(entry: DeckEntry) -> DeckEntry:
	for pair in oaths:
		if pair[0] == entry:
			return pair[1]
		if pair[1] == entry:
			return pair[0]
	return null


## 誓いの組を、駒の並びの添字の組（小さいほうが x）で。並びは結んだ順。
func oath_pairs() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for pair in oaths:
		var a := entries.find(pair[0])
		var b := entries.find(pair[1])
		if a != -1 and b != -1:
			result.append(Vector2i(mini(a, b), maxi(a, b)))
	return result


## 合計コスト（駒のコスト + 装備のコスト）。将は含まない。
func total_cost() -> int:
	var total := 0
	for entry in entries:
		total += entry.cost()
	return total


## 対戦に出せない理由の一覧。空なら出せる。並びは Problem の順で、同じ理由は 1 回だけ。
func problems() -> Array[Problem]:
	var found: Array[Problem] = []
	if entries.is_empty():
		found.append(Problem.NO_UNITS)
	if entries.size() > rules.max_units:
		found.append(Problem.TOO_MANY_UNITS)
	if total_cost() > budget():
		found.append(Problem.OVER_BUDGET)
	if entries.any(func(entry: DeckEntry) -> bool: return entry.equipment.size() > Equipment.MAX_PER_UNIT):
		found.append(Problem.TOO_MUCH_EQUIPMENT)
	if entries.any(func(entry: DeckEntry) -> bool: return not _in_roster(entry.kind)):
		found.append(Problem.NOT_IN_ROSTER)
	if entries.any(func(entry: DeckEntry) -> bool: return entry.equipment.any(func(item: Equipment.Id) -> bool: return not rules.allows_item(item))):
		found.append(Problem.ITEM_NOT_ALLOWED)
	if entries.any(func(entry: DeckEntry) -> bool: return _misfit(entry)):
		found.append(Problem.ITEM_NOT_FIT)
	return found


## 駒 entry が、数の上限（TOO_MUCH_EQUIPMENT）のほかの理由で、持っている装備を持てないか（役割の限り、重ねられない装備の 2 個目）。
static func _misfit(entry: DeckEntry) -> bool:
	for item in entry.equipment:
		if not Equipment.fits(item, entry.kind):
			return true
		var limit := Equipment.stack_limit(item)
		if limit < Equipment.MAX_PER_UNIT and entry.equipment.count(item) > limit:
			return true
	return false


## 対戦に出せる形か。
func is_valid() -> bool:
	return problems().is_empty()


## 同じ決まり・軍・駒・装備・軍略・誓いの、別の編成（片方を変えても、もう片方は変わらない）。
func copy() -> Deck:
	var other := Deck.new(army, rules)
	other.trait_id = trait_id
	for entry in entries:
		var twin := DeckEntry.new(entry.kind)
		twin.equipment = entry.equipment.duplicate()
		other.entries.append(twin)
	for pair in oath_pairs():
		other.oaths.append([other.entries[pair.x], other.entries[pair.y]])
	return other


## 駒の並びを入れ替える。from の駒を to の位置へ動かす（間の駒は 1 つずつずれる）。どちらかが範囲の外なら何もせず false。
func move(from: int, to: int) -> bool:
	if from < 0 or from >= entries.size() or to < 0 or to >= entries.size():
		return false
	if from != to:
		var entry := entries[from]
		entries.remove_at(from)
		entries.insert(to, entry)
	return true


func _in_roster(kind: UnitKind.Id) -> bool:
	return rules.allows(army, kind)
