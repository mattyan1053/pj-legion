class_name Armies
extends RefCounted
## 軍の表（docs/unit-roster.md の「軍を足すとき」）。軍で決まるルールの値は、ここ 1 か所から読む。
## 軍で決まる見た目（色・紋・空）は game/army_look.gd の表。名前は文の表（game/text/names.csv の army.<鍵> ほか）。
##
## ここに無いもの（軍の側でなく、もう一方が軍を名乗る）:
## - 雇える兵: 兵の種類が軍を持つ（UnitKind._TABLE）。ロスターは、その軍の兵を役割の順に並べたもの（roster）。
## - 必殺技: 必殺技が軍を持つ（Ult.army。Ults.of_army が引く）。
##
## 表の欄:
## - budget: 対戦モードの予算（合計コストの上限。docs/player-loadout.md）
## - traits: 軍略（並びが部隊編成の札の並び。先頭が既定。docs/troop-traits.md）
## - cpu_traits: CPU が部隊の中身から軍略を選ぶときに、合うかを見る順（CpuDeck.choose_trait。どれも合わなければ既定）

const _BUILT_IN := {
	UnitKind.Army.MILITARY: {
		"budget": 24,
		"traits": [Traits.Id.FOCUS, Traits.Id.RANKS, Traits.Id.SUPPLY],
		"cpu_traits": [Traits.Id.SUPPLY, Traits.Id.RANKS, Traits.Id.FOCUS],
	},
	UnitKind.Army.FANTASY: {
		"budget": 18,
		"traits": [Traits.Id.VENGEANCE, Traits.Id.OATH, Traits.Id.GUARD],
		"cpu_traits": [Traits.Id.GUARD, Traits.Id.OATH, Traits.Id.VENGEANCE],
	},
}

## いまの表（テストが仮の軍を足すときだけ替わる。add_for_test）。
static var _table: Dictionary = _BUILT_IN


## 選べる軍（並びは表の順。対戦設定・部隊編成の軍の並び）。
static func all() -> Array[UnitKind.Army]:
	var result: Array[UnitKind.Army] = []
	result.assign(_table.keys())
	return result


## 表にある軍か（軍なし NONE は偽）。
static func has(army: int) -> bool:
	return _table.has(army)


## 対戦モードの予算。表に無い軍なら 0。
static func budget(army: int) -> int:
	return int(_row(army).get("budget", 0))


## その軍の軍略（並びは部隊編成の札の順。先頭が既定）。表に無い軍なら空。
static func traits(army: int) -> Array[int]:
	var result: Array[int] = []
	result.assign(_row(army).get("traits", []))
	return result


## CPU が軍略を選ぶときに見る順。表に無い軍なら空。
static func cpu_traits(army: int) -> Array[int]:
	var result: Array[int] = []
	result.assign(_row(army).get("cpu_traits", []))
	return result


## その軍の雇える兵（兵の種類が名乗る軍で集める。並びは役割の順、同じ役割なら UnitKind.Id の順）。
## 表の行に roster があれば、それ（テストの仮の軍だけ）。
static func roster(army: int) -> Array[UnitKind.Id]:
	var result: Array[UnitKind.Id] = []
	if _row(army).has("roster"):
		result.assign(_row(army)["roster"])
		return result
	if army == UnitKind.Army.NONE:
		return result
	for kind: UnitKind.Id in UnitKind.Id.values():
		if UnitKind.army(kind) == army:
			result.append(kind)
	result.sort_custom(func(a: UnitKind.Id, b: UnitKind.Id) -> bool:
		return UnitKind.role(a) < UnitKind.role(b) or (UnitKind.role(a) == UnitKind.role(b) and a < b))
	return result


## いちばん大きいロスターの兵の数（部隊編成の雇う欄の数。docs/deck-screen.md）。
static func most_kinds() -> int:
	var most := 0
	for army in all():
		most = maxi(most, roster(army).size())
	return most


## いちばん多い軍略の数（部隊編成の軍略の札の数）。
static func most_traits() -> int:
	var most := 0
	for army in all():
		most = maxi(most, traits(army).size())
	return most


static func _row(army: int) -> Dictionary:
	return _table.get(army, {})


# ---- テストだけが使う ----


## 仮の軍 army（UnitKind.Army に無い数でよい）を、表の終わりに足す（tests/rules/test_armies.gd）。reset_for_test で戻す。
static func add_for_test(army: int, row: Dictionary) -> void:
	var table := _table.duplicate()
	table[army] = row
	_table = table


static func reset_for_test() -> void:
	_table = _BUILT_IN
