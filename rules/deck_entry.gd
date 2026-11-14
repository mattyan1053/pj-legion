class_name DeckEntry
extends RefCounted
## 編成（Deck）の中の駒 1 体。種類と、持たせた装備。

var kind: UnitKind.Id
## 持たせた装備。同じものを重ねて持てる。持たせた順に並ぶ。
var equipment: Array[Equipment.Id] = []


func _init(entry_kind: UnitKind.Id) -> void:
	kind = entry_kind


## 装備を 1 個持たせる。もう持てなければ（上限に達している）何もせず false。
func equip(item: Equipment.Id) -> bool:
	if equipment.size() >= Equipment.MAX_PER_UNIT:
		return false
	equipment.append(item)
	return true


## 装備を 1 個外す。持っていなければ何もせず false。
func unequip(item: Equipment.Id) -> bool:
	var index := equipment.rfind(item)
	if index == -1:
		return false
	equipment.remove_at(index)
	return true


## その装備を何個持っているか。
func count(item: Equipment.Id) -> int:
	return equipment.count(item)


## この駒のぶんのコスト（駒のコスト + 装備のコスト）。
func cost() -> int:
	return UnitKind.cost(kind) + Equipment.total_cost(equipment)
