class_name Deck
extends RefCounted
## プレイヤー 1 人の編成。選んだ軍と、雇った駒（将を除く）の並び。
##
## 将は編成に含めない。軍を盤に置くとき（Deployment.deploy）に、1 体だけ自動で加わる。
## 雇えるのは、選んだ軍のロスターの駒だけ。軍を変えるときは、編成を作り直す。
## 編成として成り立つか（予算、駒の数）の検査は、ここではしない。

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


## 駒を 1 体雇う。この軍のロスターに無い種類なら、何もせず null。
func add(kind: UnitKind.Id) -> DeckEntry:
	if army == UnitKind.Army.NONE or UnitKind.army(kind) != army:
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
