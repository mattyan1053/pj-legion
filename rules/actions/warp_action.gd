class_name WarpAction
extends BattleAction
## ポータルのマスにいる駒を、対になるポータルへ移す（転移。移動力は使わない）。docs/map-objects.md。
##
## - 行動できる駒が、ポータルのマスにいて、行き先のポータルに駒がいないとき（Battle.portal_exit）。
##   まだ動いていなくても（フェーズの始めからポータルの上にいる）、ポータルまで動いたあとでもよい。
## - 敵の支配領域にあるポータルへ歩いて入ったあとは、転移できない（動き出したマスなら転移できる）。
## - 転移してすぐ、もう一度転移することはできない（戻るだけ。取り消しを使う）。行動を終えないスキルを使ったあとも、できない。
## - 転移したあとは、残りの移動力で続けて動ける（MoveAction。巡航かどうかは、それまでの移動のまま。まだ動いていなければ選べる）。
##   転移した先が敵の支配領域なら、そこで止まる（続けて動けない）。
## - 起きたことは UnitWarpedEvent。ほかのマスへ移るので、動くと外れる状態（照準）が外れる（StatusRemovedEvent）。
##   移動の取り消し（UndoMoveAction）は、転移の前の、動き出したマスへ戻す。

var unit_id: int


func _init(warping_unit_id: int) -> void:
	unit_id = warping_unit_id


func is_valid(battle: Battle) -> bool:
	var unit := battle.unit_by_id(unit_id)
	if not battle.can_act(unit) or unit.move_locked or unit.just_warped:
		return false
	if unit.has_trait(Evolution.Trait.ROOTED):
		return false
	if battle.portal_exit(unit.cell) == Board.NO_CELL:
		return false
	# 歩いて入ったポータルが敵の支配領域なら、そこで止まっている。
	return not (unit.has_moved and unit.cell != unit.move_origin and _stopped_by_zoc(battle, unit, unit.cell))


func execute(battle: Battle) -> Array[BattleEvent]:
	var unit := battle.unit_by_id(unit_id)
	var from := unit.cell
	var exit := battle.portal_exit(from)
	if not unit.has_moved:
		MoveAction.begin(battle, unit)
	var events: Array[BattleEvent] = [UnitWarpedEvent.new(unit.id, from, exit, unit.cruised)]
	unit.cell = exit
	unit.just_warped = true
	unit.can_keep_moving = not _stopped_by_zoc(battle, unit, exit)
	events.append_array(Statuses.displace(unit))
	return events


## cell が unit を止める敵の支配領域か（支配領域で止まらない特性の駒は、止まらない）。
static func _stopped_by_zoc(battle: Battle, unit: Unit, cell: Vector2i) -> bool:
	return not unit.ignores_zoc() and battle.is_in_enemy_zoc(cell, unit.side)
