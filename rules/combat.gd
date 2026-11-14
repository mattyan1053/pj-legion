class_name Combat
extends RefCounted
## 攻撃の届く範囲と、ダメージの計算。
##
## - 射程はマンハッタン距離（上下左右の歩数）。地形は射程を遮らない（壁越しに撃てる）
## - 攻撃できるのは敵（違う陣営）の駒だけ。中立の駒は両プレイヤーの敵
## - ダメージは攻撃側の攻撃力。守る側が森にいれば 0.8 倍（端数切り捨て）
## - 回復役（衛生兵・プリースト）は攻撃しない（回復は回復役の仕様で入れる）

const FOREST_DAMAGE_RATE_PERCENT := 80


static func distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


static func can_attack(battle: Battle, attacker: Unit, target: Unit) -> bool:
	if attacker == null or target == null or not attacker.is_enemy_of(target):
		return false
	if UnitKind.role(attacker.kind) == UnitKind.Role.HEALER:
		return false
	if not battle.units.has(target):
		return false
	return distance(attacker.cell, target.cell) <= attacker.attack_range()


## いまの位置から攻撃できる駒。並びは盤面の上の行から、左の列から。
static func targets(battle: Battle, attacker: Unit) -> Array[Unit]:
	var result: Array[Unit] = []
	for unit in battle.units:
		if can_attack(battle, attacker, unit):
			result.append(unit)
	result.sort_custom(func(a: Unit, b: Unit) -> bool:
		return a.cell.y < b.cell.y or (a.cell.y == b.cell.y and a.cell.x < b.cell.x))
	return result


## attacker が target に与えるダメージ（予測にも使う）。
static func damage(battle: Battle, attacker: Unit, target: Unit) -> int:
	var amount := attacker.power()
	if battle.board.terrain_at(target.cell) == Terrain.Type.FOREST:
		amount = amount * FOREST_DAMAGE_RATE_PERCENT / 100
	return amount
