extends RefCounted
## 画面に出す「いま選べること」を、画面が使いやすい形にする。
##
## ルールは持たない。選べることはルールの問い合わせ（Battle.options）に聞き、
## どれも Battle.can_apply() が受け付けるものだけを返す（テストで確かめている）。
## ノードに依存しない。


## その駒がいま動ける行き先。マス -> 巡航でしか届かないか（bool）。いまのマスは含まない。
## 行動できない駒・もう動いた駒では空。
static func move_cells(battle: Battle, unit: Unit) -> Dictionary:
	var result := {}
	if unit == null:
		return result
	var options := battle.options(unit.id)
	for cell in options.move_cells:
		if cell != unit.cell:
			result[cell] = false
	for cell in options.cruise_cells:
		result[cell] = true
	return result


## その駒がいまの位置から攻撃できる相手（行動できない駒・巡航で動いた駒では空）。
static func attack_targets(battle: Battle, unit: Unit) -> Array[Unit]:
	var result: Array[Unit] = []
	if unit == null:
		return result
	for target_id in battle.options(unit.id).attack_target_ids:
		result.append(battle.unit_by_id(target_id))
	return result


## その駒がいまの位置から回復できる味方（回復役だけ。行動できない駒・巡航で動いた駒では空）。
static func heal_targets(battle: Battle, unit: Unit) -> Array[Unit]:
	var result: Array[Unit] = []
	if unit == null:
		return result
	for target_id in battle.options(unit.id).heal_target_ids:
		result.append(battle.unit_by_id(target_id))
	return result


## その駒がいまの位置から攻撃できる起爆樽のマス（行動できない駒・巡航で動いた駒・回復役では空）。
static func barrel_targets(battle: Battle, unit: Unit) -> Array[Vector2i]:
	if unit == null:
		return []
	return battle.options(unit.id).barrel_cells


## その駒がいまの位置から攻撃できる相手の盾のマス（行動できない駒・巡航で動いた駒・回復役では空）。
static func barricade_targets(battle: Battle, unit: Unit) -> Array[Vector2i]:
	if unit == null:
		return []
	return battle.options(unit.id).barricade_cells


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
