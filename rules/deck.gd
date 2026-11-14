class_name Deck
extends RefCounted
## プレイヤー 1 人の編成。選んだ軍と、雇った駒（将を除く）の並び。
##
## 将は編成に含めない。軍を盤に置くとき（Deployment.deploy）に、1 体だけ自動で加わる。
## 雇えるのは、選んだ軍のロスターの駒だけ。軍を変えるときは、編成を作り直す。
## 対戦に出せる形かどうかは problems() / is_valid() で調べる（docs/deck-building.md）。
## 編成の途中は、通らない形（駒が 0 体、予算を超えている）にもなる。

## 編成が対戦に出せない理由。
enum Problem {
	NO_UNITS,  ## 雇った駒が 1 体もいない
	TOO_MANY_UNITS,  ## 雇った駒が MAX_UNITS を超えている
	OVER_BUDGET,  ## 合計コストが予算を超えている
	TOO_MUCH_EQUIPMENT,  ## 装備を持てる数を超えて持っている駒がいる
	NOT_IN_ROSTER,  ## この軍のロスターに無い駒がいる
}

## 雇える駒の数の上限（将を除く）。
const MAX_UNITS := 6

## 軍ごとの予算（合計コストの上限）。
const _BUDGETS := {
	UnitKind.Army.MILITARY: 24,
	UnitKind.Army.FANTASY: 18,
}

var army: UnitKind.Army
var entries: Array[DeckEntry] = []


func _init(deck_army: UnitKind.Army) -> void:
	army = deck_army


## その軍で雇える駒の種類。並びは 前衛・後衛・奇襲・回復。
static func roster(of_army: UnitKind.Army) -> Array[UnitKind.Id]:
	var result: Array[UnitKind.Id] = []
	if of_army == UnitKind.Army.NONE:
		return result
	for id: UnitKind.Id in UnitKind.Id.values():
		if UnitKind.army(id) == of_army:
			result.append(id)
	result.sort_custom(func(a: UnitKind.Id, b: UnitKind.Id) -> bool:
		return UnitKind.role(a) < UnitKind.role(b))
	return result


## その軍の予算。軍でなければ 0。
static func budget_of(of_army: UnitKind.Army) -> int:
	return _BUDGETS.get(of_army, 0)


func budget() -> int:
	return budget_of(army)


## 駒を 1 体雇う。この軍のロスターに無い種類か、もう雇えなければ（上限に達している）、何もせず null。
## 予算は見ない（超えた編成は作れて、検査で分かる）。
func add(kind: UnitKind.Id) -> DeckEntry:
	if not _in_roster(kind) or entries.size() >= MAX_UNITS:
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
	return true


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
	if entries.size() > MAX_UNITS:
		found.append(Problem.TOO_MANY_UNITS)
	if total_cost() > budget():
		found.append(Problem.OVER_BUDGET)
	if entries.any(func(entry: DeckEntry) -> bool: return entry.equipment.size() > Equipment.MAX_PER_UNIT):
		found.append(Problem.TOO_MUCH_EQUIPMENT)
	if entries.any(func(entry: DeckEntry) -> bool: return not _in_roster(entry.kind)):
		found.append(Problem.NOT_IN_ROSTER)
	return found


## 対戦に出せる形か。
func is_valid() -> bool:
	return problems().is_empty()


func _in_roster(kind: UnitKind.Id) -> bool:
	return army != UnitKind.Army.NONE and UnitKind.army(kind) == army
