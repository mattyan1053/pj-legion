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


## その駒が、いまのマス（ポータル）から対のポータルへ転移（WarpAction）できるなら行き先。できなければ Board.NO_CELL。
static func warp_exit(battle: Battle, unit: Unit) -> Vector2i:
	if unit == null:
		return Board.NO_CELL
	return battle.options(unit.id).warp_exit


## その駒の移動の範囲の中にある、いま転移に使えるポータル（入るポータル -> 出るポータル）。駒がいま乗っているポータルも含む。
## 動けない駒・転移したばかりで乗っているポータルは含まない。範囲は転移の先まで広げない（転移は止まってから選ぶ）。
static func reachable_portals(battle: Battle, unit: Unit) -> Dictionary:
	var result := {}
	if unit == null:
		return result
	var options := battle.options(unit.id)
	if options.warp_exit != Board.NO_CELL:
		result[unit.cell] = options.warp_exit
	for portal: Vector2i in battle.board.portal_exits:
		if portal == unit.cell or not options.can_move_to(portal):
			continue
		var exit := battle.portal_exit(portal)
		if exit == Board.NO_CELL or exit == unit.cell:
			continue
		var probe := battle.clone()
		var action := MoveAction.new(unit.id, portal, options.cruise_cells.has(portal))
		if probe.apply(action).accepted and probe.options(unit.id).warp_exit != Board.NO_CELL:
			result[portal] = exit
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


## その駒がいまの位置からスキルの対象に選べるマス（スキルを使えない駒・行動できない駒・巡航で動いた駒では空）。
static func skill_cells(battle: Battle, unit: Unit) -> Array[Vector2i]:
	if unit == null:
		return []
	return battle.options(unit.id).skill_cells


## 駒の移動範囲（巡航なし）。ほかの駒を見る（閲覧）ときに使う。
static func inspect_cells(battle: Battle, unit: Unit) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if unit != null:
		result.assign(Movement.reachable(battle, unit, false).keys())  # ポータルの先へは広げない（自分の駒と同じ）
	return result


## 駒の脅威範囲（次の自分の番に攻撃・スキルが届くマス。Threat）。相手の駒を見るときに使う。
static func threat_cells(battle: Battle, unit: Unit) -> Array[Vector2i]:
	if unit == null:
		return []
	return Threat.of(battle, unit.id).cells()


## いまのフェーズの陣営の、行動済みでない駒の数。
static func unacted_count(battle: Battle) -> int:
	return unacted_units(battle).size()


## いまの番の陣営の、まだ行動を終えていない駒（ターン終了の確かめで、足元を光らせる）。
static func unacted_units(battle: Battle) -> Array[Unit]:
	var units: Array[Unit] = []
	for unit in battle.units:
		if unit.side == battle.phase and not unit.acted:
			units.append(unit)
	return units


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
