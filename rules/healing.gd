class_name Healing
extends RefCounted
## 回復役（衛生兵・プリースト）の回復の届く範囲と、回復量の計算。
##
## - 回復できるのは回復役だけ。相手は同じ陣営のほかの駒で、HP が最大 HP より少ないもの（自分は回復できない）
## - 射程は攻撃と同じ測り方（マンハッタン距離。地形は遮らない）
## - 回復量は回復役の power() の実効値。回復後の HP は最大 HP の実効値を超えない


static func can_heal(battle: Battle, healer: Unit, target: Unit) -> bool:
	if healer == null or target == null or healer == target:
		return false
	if UnitKind.role(healer.kind) != UnitKind.Role.HEALER:
		return false
	if healer.side != target.side or not battle.units.has(target):
		return false
	if target.hp >= target.max_hp():
		return false
	return Combat.distance(healer.cell, target.cell) <= healer.attack_range()


## いまの位置から回復できる駒。並びは盤面の上の行から、左の列から。
static func targets(battle: Battle, healer: Unit) -> Array[Unit]:
	var result: Array[Unit] = []
	for unit in battle.units:
		if can_heal(battle, healer, unit):
			result.append(unit)
	result.sort_custom(func(a: Unit, b: Unit) -> bool:
		return a.cell.y < b.cell.y or (a.cell.y == b.cell.y and a.cell.x < b.cell.x))
	return result


## healer が target を回復したときに、実際に増える HP（予測にも使う）。
## 最大 HP を超えるぶんは切り捨てる。
static func amount(healer: Unit, target: Unit) -> int:
	return clampi(target.max_hp() - target.hp, 0, healer.power())
