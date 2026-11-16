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


## その駒が、いまのマス（ポータル）から対のポータルへ転移できるなら [行き先, 巡航か]。できなければ空の列。
## ルールに「転移する」行動は無い（転移は移動の道の中だけ。docs/map-objects.md）ので、画面はこれを次の行動の組に直す。
## - まだ動いていない駒（フェーズの始めからポータルの上にいる）: 行き先への移動（MoveAction）。
## - ポータルへ動いたあとの駒: 移動の取り消し（UndoMoveAction）と、動く前のマスから行き先への移動。
##   取り消せない（スキルを使った）か、動く前のマスから行き先へ届かない（ポータルが敵の支配領域にある、など）なら空。
## どちらも、行き先に駒がいれば空（Battle.portal_exit）。返す組は Battle.can_apply() が受け付ける（テストで確かめている）。
static func warp(battle: Battle, unit: Unit) -> Array:
	if unit == null or battle.is_over() or not battle.can_act(unit):
		return []
	var exit := battle.portal_exit(unit.cell)
	if exit == Board.NO_CELL:
		return []
	if not unit.has_moved:
		var cells := move_cells(battle, unit)
		return [exit, cells[exit]] if cells.has(exit) else []
	if not battle.options(unit.id).can_undo:
		return []
	var before := battle.clone()
	if not before.apply(UndoMoveAction.new(unit.id)).accepted:
		return []
	var origin := before.unit_by_id(unit.id)
	var path := Movement.path_to(before, origin, exit, unit.cruised)
	var at := path.find(unit.cell)
	if at < 0 or at + 1 >= path.size() or path[at + 1] != exit:
		return []  # 動く前のマスから、このポータルを通って行き先へは行けない
	return [exit, unit.cruised]


## warp が返す転移を、ルールの行動の列にする（空なら空）。
static func warp_actions(battle: Battle, unit: Unit) -> Array[BattleAction]:
	var actions: Array[BattleAction] = []
	var found := warp(battle, unit)
	if found.is_empty():
		return actions
	if unit.has_moved:
		actions.append(UndoMoveAction.new(unit.id))
	actions.append(MoveAction.new(unit.id, found[0], found[1]))
	return actions


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
		result.assign(Movement.reachable(battle, unit, false).keys())
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
