extends RefCounted
## 画面に出す「いま選べること」を、ルールの公開の関数を組み合わせて求める。
##
## ルールは持たない。どれも Battle.can_apply() が受け付けるものだけを返す（テストで確かめている）。
## ノードに依存しない。


## その駒がいま動ける行き先。マス -> 巡航でしか届かないか（bool）。いまのマスは含まない。
## 行動できない駒・もう動いた駒では空。
static func move_cells(battle: Battle, unit: Unit) -> Dictionary:
	var result := {}
	if unit == null or battle.is_over() or not battle.can_act(unit) or unit.has_moved:
		return result
	var normal := Movement.reachable(battle, unit, false)
	for cell: Vector2i in Movement.reachable(battle, unit, true):
		if cell != unit.cell:
			result[cell] = not normal.has(cell)
	return result


## その駒がいまの位置から攻撃できる相手（行動できない駒・巡航で動いた駒では空）。
static func attack_targets(battle: Battle, unit: Unit) -> Array[Unit]:
	var result: Array[Unit] = []
	if unit == null:
		return result
	for target in Combat.targets(battle, unit):
		if battle.can_apply(AttackAction.new(unit.id, target.id)):
			result.append(target)
	return result


## その駒がいまの位置から攻撃できる起爆樽のマス（行動できない駒・巡航で動いた駒・回復役では空）。
static func barrel_targets(battle: Battle, unit: Unit) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if unit == null:
		return result
	for cell in MapObject.barrel_targets(battle, unit):
		if battle.can_apply(AttackBarrelAction.new(unit.id, cell)):
			result.append(cell)
	return result


## 駒の移動範囲（巡航なし）。行動できない駒や相手の駒を選んで眺めるときに使う。
static func inspect_cells(battle: Battle, unit: Unit) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if unit != null:
		result.assign(Movement.reachable(battle, unit, false).keys())
	return result


## いまのフェーズの陣営の、行動済みでない駒の数。
static func unacted_count(battle: Battle) -> int:
	var count := 0
	for unit in battle.units:
		if unit.side == battle.phase and not unit.acted:
			count += 1
	return count


## side の駒の数。
static func unit_count(battle: Battle, side: Unit.Side) -> int:
	var count := 0
	for unit in battle.units:
		if unit.side == side:
			count += 1
	return count


## side の将。いなければ null。
static func king_of(battle: Battle, side: Unit.Side) -> Unit:
	for unit in battle.units:
		if unit.side == side and unit.kind == UnitKind.Id.KING:
			return unit
	return null
