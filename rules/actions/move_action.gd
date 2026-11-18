class_name MoveAction
extends BattleAction
## 駒を移動範囲の中のマスへ動かす。巡航なら移動力は 2 倍（そのかわり、この行動では攻撃できない）。
##
## 行動できる駒が、1 回の行動につき 1 回だけ動ける。いまのマスを行き先にしてもよい（動かない移動）。
## 道がポータルを通るときは、歩いた区間ごとの UnitMovedEvent の間に UnitWarpedEvent が入る。
## ほかのマスへ動くと、動くと外れる状態（照準）が外れる（StatusRemovedEvent。移動のイベントのあと）。動かない移動では外れない。
## 動いたあとは、攻撃・待機・移動の取り消しのどれかで行動を続ける。

var unit_id: int
var to: Vector2i
var cruise: bool


func _init(moving_unit_id: int, destination: Vector2i, is_cruise := false) -> void:
	unit_id = moving_unit_id
	to = destination
	cruise = is_cruise


func is_valid(battle: Battle) -> bool:
	var unit := battle.unit_by_id(unit_id)
	return battle.can_act(unit) and not unit.has_moved and Movement.reachable(battle, unit, cruise).has(to)


func execute(battle: Battle) -> Array[BattleEvent]:
	var unit := battle.unit_by_id(unit_id)
	var path := Movement.path_to(battle, unit, to, cruise)
	# 転移かどうかは駒を動かす前の盤で見る（行き先が空いているポータルだけが使える）。
	var events := events_along(battle, unit_id, path, cruise)
	battle.acting_unit_id = unit.id
	battle.capture_turns_before_move = battle.capture_turns.duplicate()
	unit.has_moved = true
	unit.move_origin = unit.cell
	unit.cruised = cruise
	var moved := to != unit.cell
	if moved:
		unit.probe_moved_turn = battle.turn
	unit.cell = to
	unit.statuses_before_move = {}
	if moved:
		events.append_array(Statuses.after_move(unit))
	return events


## 道を、歩いた区間（UnitMovedEvent）とポータルの転移（UnitWarpedEvent）に分けて並べる。
## 転移の前後の、1 歩も歩いていない区間は出さない。ポータルを通らない移動は、UnitMovedEvent が 1 つ。
static func events_along(
	battle: Battle, moving_unit_id: int, path: Array[Vector2i], is_cruise: bool
) -> Array[BattleEvent]:
	var events: Array[BattleEvent] = []
	var leg: Array[Vector2i] = [path[0]]
	for i in range(1, path.size()):
		if battle.portal_exit(path[i - 1]) == path[i]:
			if leg.size() > 1:
				events.append(UnitMovedEvent.new(moving_unit_id, leg, is_cruise))
			events.append(UnitWarpedEvent.new(moving_unit_id, path[i - 1], path[i], is_cruise))
			leg = [path[i]]
		else:
			leg.append(path[i])
	if leg.size() > 1 or events.is_empty():
		events.append(UnitMovedEvent.new(moving_unit_id, leg, is_cruise))
	return events
