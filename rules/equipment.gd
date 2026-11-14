class_name Equipment
extends RefCounted
## 装備。編成のときに駒へ持たせ、駒の能力値の「基礎 + 装備」の層に足される。
##
## 同じ装備を重ねて持てる。効果は個数ぶん足される。将は装備を持てない。

enum Id {
	SPEED_BOOTS,  ## スピードブーツ。移動力 +2
	IRON_SHIELD,  ## アイアンシールド。最大 HP +30
}

## 1 体が持てる装備の数。
const MAX_PER_UNIT := 3

## [名前, コスト, 足す能力値, 足す量]
const _TABLE := {
	Id.SPEED_BOOTS: ["スピードブーツ", 1, Unit.Stat.MOVE_RANGE, 2],
	Id.IRON_SHIELD: ["アイアンシールド", 1, Unit.Stat.MAX_HP, 30],
}


static func display_name(id: Id) -> String:
	return _TABLE[id][0]


static func cost(id: Id) -> int:
	return _TABLE[id][1]


## その装備 1 個が stat に足す量。関係のない能力値なら 0。
static func bonus(id: Id, stat: Unit.Stat) -> int:
	return _TABLE[id][3] if _TABLE[id][2] == stat else 0


## 装備の並びが stat に足す量の合計。
static func total_bonus(items: Array[Id], stat: Unit.Stat) -> int:
	var total := 0
	for item in items:
		total += bonus(item, stat)
	return total


## 装備の並びのコストの合計。
static func total_cost(items: Array[Id]) -> int:
	var total := 0
	for item in items:
		total += cost(item)
	return total


## その種類の駒が装備を持てるか。持てるのは、軍に属する駒（雇う駒）だけ。将と中立の駒は持てない。
static func can_equip(kind: UnitKind.Id) -> bool:
	return UnitKind.army(kind) != UnitKind.Army.NONE
