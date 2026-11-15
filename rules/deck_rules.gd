class_name DeckRules
extends RefCounted
## 編成の決まり: どの軍を選べ、それぞれの軍でどの駒を雇え、予算はいくつか、何体まで雇えるか（docs/deck-building.md）。
##
## 編成（Deck）と、その検査（Deck.problems）、編成の画面は、決まりを外から受け取る。
## いまある決まりは対戦の決まり（versus()。全員同じ）だけ。後で、ストーリーの進み具合に応じた決まり
## （雇える駒が増えていく）を、ここに足す（Issue #49）。取っておく部隊は、どの決まりで組んだか（id）を持つ。
##
## 決まりは組んだら変えない（読むだけ）。versus() はいつも同じものを返す。

## 対戦の決まりの名前。
const VERSUS := &"versus"

## 決まりの名前（取っておく部隊に書く。by_id で引き直す）。
var id: StringName
## 画面に出す名前。
var display_name: String
## 雇える駒の数の上限（将を除く）。
var max_units: int
## 軍 -> 雇える駒の種類（並びは 前衛・後衛・奇襲・回復）。ここに無い軍は選べない。
var _rosters: Dictionary = {}
## 軍 -> 予算（合計コストの上限）。
var _budgets: Dictionary = {}

static var _versus: DeckRules


func _init(rules_id: StringName, name: String, unit_limit: int, rosters: Dictionary, budgets: Dictionary) -> void:
	id = rules_id
	display_name = name
	max_units = unit_limit
	_rosters = rosters
	_budgets = budgets


## 対戦の決まり。軍ごとに、その軍の 4 種を雇える。予算は軍ごとの値（MILITARY 24、FANTASY 18。docs/player-loadout.md）。
static func versus() -> DeckRules:
	if _versus == null:
		var rosters := {}
		for army: UnitKind.Army in [UnitKind.Army.MILITARY, UnitKind.Army.FANTASY]:
			rosters[army] = _army_kinds(army)
		_versus = DeckRules.new(VERSUS, "対戦", Deck.MAX_UNITS, rosters, {
			UnitKind.Army.MILITARY: 24,
			UnitKind.Army.FANTASY: 18,
		})
	return _versus


## 名前から決まりを引く。知らない名前なら null。
static func by_id(rules_id: StringName) -> DeckRules:
	match rules_id:
		VERSUS:
			return versus()
	return null


## 選べる軍（並びは Army の順）。
func armies() -> Array[UnitKind.Army]:
	var result: Array[UnitKind.Army] = []
	for army: UnitKind.Army in UnitKind.Army.values():
		if _rosters.has(army):
			result.append(army)
	return result


## その軍で雇える駒の種類。選べない軍なら空。
func roster(army: UnitKind.Army) -> Array[UnitKind.Id]:
	var result: Array[UnitKind.Id] = []
	if _rosters.has(army):
		result.assign(_rosters[army])
	return result


## その軍の予算。選べない軍なら 0。
func budget(army: UnitKind.Army) -> int:
	return _budgets.get(army, 0)


## その軍で、その種類の駒を雇えるか。
func allows(army: UnitKind.Army, kind: UnitKind.Id) -> bool:
	return _rosters.has(army) and (_rosters[army] as Array).has(kind)


## その軍に属する駒の種類。並びは 前衛・後衛・奇襲・回復。
static func _army_kinds(army: UnitKind.Army) -> Array[UnitKind.Id]:
	var result: Array[UnitKind.Id] = []
	for kind: UnitKind.Id in UnitKind.Id.values():
		if UnitKind.army(kind) == army:
			result.append(kind)
	result.sort_custom(func(a: UnitKind.Id, b: UnitKind.Id) -> bool:
		return UnitKind.role(a) < UnitKind.role(b))
	return result
