class_name Equipment
extends RefCounted
## 装備（画面では「持ち物」）。編成のときに駒へ持たせ、駒の能力値の「基礎 + 装備」の層に足される（docs/player-loadout.md）。
##
## - 装備は、能力値を足すもの、進化の特性（Evolution.Trait）を与えるもの、その両方がある。新しい仕組みは足さない。
## - 1 体が持てる数は MAX_PER_UNIT まで。同じものを重ねて持てるのは、重ねられる装備（stack が 2 以上）だけ。効果は個数ぶん足される。
## - 役割を限る装備は、その役割の駒にしか持たせられない。将・中立・魔物は、どの装備も持てない。
## - どの装備をどこで持たせられるか（対戦モード、ストーリーの物語）は、編成の決まり（DeckRules）が決める。

enum Id {
	SPEED_BOOTS,  ## スピードブーツ。移動力 +2
	IRON_SHIELD,  ## アイアンシールド。最大 HP +30
	POWER_GAUNTLET,  ## 力の籠手。攻撃力（回復役は回復量）+2
	LONG_SCOPE,  ## 遠眼鏡。射程 +1。後衛だけ
	REGEN_CHARM,  ## 再生の護符。再生の特性
	TRAIL_MAP,  ## 獣道の地図。森歩きの特性
	SHADOW_CLOAK,  ## 隠れ蓑。浸透の特性
	WAR_BANNER,  ## 軍旗。支配領域の特性。前衛は元から持つので持てない
	JET_PACK,  ## 試作ジェットパック（ストーリー専用）。移動力 +2、浸透、森歩き
	DRAGON_SCALE,  ## 古竜の鱗（ストーリー専用）。最大 HP +20、再生
}

## 1 体が持てる装備の数。
const MAX_PER_UNIT := 3

const _ANY: Array[UnitKind.Role] = []
const _NOT_VANGUARD: Array[UnitKind.Role] = [UnitKind.Role.REARGUARD, UnitKind.Role.RAIDER, UnitKind.Role.HEALER]

## コスト、足す能力値（能力値 -> 1 個で足す量）、与える特性、持てる役割（空ならどの役割も）、1 体が重ねて持てる数。
## 名前は画面の文の表（game/text/names.csv の item.<id>）。調整値は docs/player-loadout.md の「装備」。
const _TABLE := {
	Id.SPEED_BOOTS: {"cost": 1, "stats": {Unit.Stat.MOVE_RANGE: 2}, "stack": MAX_PER_UNIT},
	Id.IRON_SHIELD: {"cost": 1, "stats": {Unit.Stat.MAX_HP: 30}, "stack": MAX_PER_UNIT},
	Id.POWER_GAUNTLET: {"cost": 2, "stats": {Unit.Stat.POWER: 2}},
	Id.LONG_SCOPE: {"cost": 2, "stats": {Unit.Stat.ATTACK_RANGE: 1}, "roles": [UnitKind.Role.REARGUARD]},
	Id.REGEN_CHARM: {"cost": 2, "traits": [Evolution.Trait.REGENERATION]},
	Id.TRAIL_MAP: {"cost": 1, "traits": [Evolution.Trait.FOREST_WALK]},
	Id.SHADOW_CLOAK: {"cost": 2, "traits": [Evolution.Trait.IGNORES_ZOC]},
	Id.WAR_BANNER: {"cost": 1, "traits": [Evolution.Trait.EXERTS_ZOC], "roles": _NOT_VANGUARD},
	Id.JET_PACK: {"cost": 3, "stats": {Unit.Stat.MOVE_RANGE: 2}, "traits": [Evolution.Trait.IGNORES_ZOC, Evolution.Trait.FOREST_WALK]},
	Id.DRAGON_SCALE: {"cost": 3, "stats": {Unit.Stat.MAX_HP: 20}, "traits": [Evolution.Trait.REGENERATION]},
}


static func cost(id: Id) -> int:
	return _TABLE[id]["cost"]


## その装備 1 個が stat に足す量。関係のない能力値なら 0。
static func bonus(id: Id, stat: Unit.Stat) -> int:
	return (_TABLE[id].get("stats", {}) as Dictionary).get(stat, 0)


## その装備が与える特性（Evolution.Trait）。無ければ空。
static func traits(id: Id) -> Array[Evolution.Trait]:
	var result: Array[Evolution.Trait] = []
	result.assign(_TABLE[id].get("traits", []))
	return result


## その装備を持てる役割。空なら、どの役割の駒も持てる。
static func roles(id: Id) -> Array[UnitKind.Role]:
	var result: Array[UnitKind.Role] = []
	result.assign(_TABLE[id].get("roles", _ANY))
	return result


## 1 体が、その装備を重ねて持てる数（1 なら重ねられない）。
static func stack_limit(id: Id) -> int:
	return _TABLE[id].get("stack", 1)


## 装備の並びが stat に足す量の合計。
static func total_bonus(items: Array[Id], stat: Unit.Stat) -> int:
	var total := 0
	for item in items:
		total += bonus(item, stat)
	return total


## 装備の並びのどれかが、その特性を与えるか。
static func grants(items: Array[Id], which: Evolution.Trait) -> bool:
	for item in items:
		if traits(item).has(which):
			return true
	return false


## 装備の並びのコストの合計。
static func total_cost(items: Array[Id]) -> int:
	var total := 0
	for item in items:
		total += cost(item)
	return total


## その種類の駒が装備を持てるか。持てるのは、軍に属する駒（雇う駒）だけ。将と中立の駒は持てない。
static func can_equip(kind: UnitKind.Id) -> bool:
	return UnitKind.army(kind) != UnitKind.Army.NONE


## その種類の駒が、その装備を持てる種類か（役割の限り）。数の上限は見ない（can_add）。
static func fits(item: Id, kind: UnitKind.Id) -> bool:
	if not can_equip(kind):
		return false
	var allowed := roles(item)
	return allowed.is_empty() or allowed.has(UnitKind.role(kind))


## held を持っている kind の駒に、item をもう 1 個持たせられるか（役割、1 体の数の上限、重ねて持てる数）。
static func can_add(kind: UnitKind.Id, held: Array[Id], item: Id) -> bool:
	return fits(item, kind) and held.size() < MAX_PER_UNIT and held.count(item) < stack_limit(item)


## kind の駒が、装備の並び items をそのまま持てるか（役割、数、重ねて持てる数）。
static func is_valid_for(kind: UnitKind.Id, items: Array[Id]) -> bool:
	if items.is_empty():
		return true
	if items.size() > MAX_PER_UNIT:
		return false
	for item in items:
		if not fits(item, kind) or items.count(item) > stack_limit(item):
			return false
	return true
