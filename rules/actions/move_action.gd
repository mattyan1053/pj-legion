class_name MoveAction
extends BattleAction
## 駒を移動範囲の中のマスへ動かす。巡航なら移動力は 2 倍（そのかわり、この行動では攻撃できない）。
##
## 行動できる駒が、1 回の行動につき 1 回だけ動ける。いまのマスを行き先にしてもよい（動かない移動）。
## 移動はポータルを越えない。ポータルのマスで止まって転移（WarpAction）したあとは、残りの移動力（Movement.budget_left）で
## もう 1 回動ける（ほかのマスへ。巡航で動いていれば、続きも巡航）。
## ほかのマスへ動くと、動くと外れる状態（照準）が外れる（StatusRemovedEvent。移動のイベントのあと）。動かない移動では外れない。
## 動いたあとは、攻撃・待機・移動の取り消しのどれか（ポータルの上なら転移も）で行動を続ける。

var unit_id: int
var to: Vector2i
var cruise: bool


func _init(moving_unit_id: int, destination: Vector2i, is_cruise := false) -> void:
	unit_id = moving_unit_id
	to = destination
	cruise = is_cruise


func is_valid(battle: Battle) -> bool:
	var unit := battle.unit_by_id(unit_id)
	if not battle.can_act(unit) or (unit.has_moved and not unit.can_keep_moving):
		return false
	if unit.can_keep_moving and to == unit.cell:
		return false  # 転移のあとの続きは、ほかのマスへ
	return Movement.reachable_now(battle, unit, cruise).has(to)


func execute(battle: Battle) -> Array[BattleEvent]:
	var unit := battle.unit_by_id(unit_id)
	var found := Movement.search_now(battle, unit, cruise)
	var is_cruise := cruise or unit.cruised
	# 移動はポータルを越えないので、道は歩いた 1 本（隣り合うポータルの対を歩いて通っても、転移ではない）。
	var events: Array[BattleEvent] = [UnitMovedEvent.new(unit_id, found.path(to), is_cruise)]
	if not unit.has_moved:
		begin(battle, unit)
	unit.move_spent += found.cost[to]
	unit.cruised = is_cruise
	unit.can_keep_moving = false
	unit.just_warped = false
	var moved := to != unit.cell
	unit.cell = to
	if moved:
		events.append_array(Statuses.displace(unit))
	return events


## 行動の最初の移動（MoveAction か WarpAction）の前に、取り消しのために動く前の状態を覚え、駒を行動の途中にする。
static func begin(battle: Battle, unit: Unit) -> void:
	battle.acting_unit_id = unit.id
	battle.capture_turns_before_move = battle.capture_turns.duplicate()
	unit.has_moved = true
	unit.move_origin = unit.cell
	unit.move_spent = 0
	unit.statuses_before_move = unit.statuses.duplicate()


## 道を、歩いた区間（UnitMovedEvent）とポータルの転移（UnitWarpedEvent）に分けて並べる（転移を含む道は、中立の駒の移動だけ）。
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
