class_name MoveAction
extends RefCounted
## 駒を移動範囲の中のマスへ動かす。巡航なら移動力は 2 倍（そのかわり、この行動では攻撃できない）。
##
## 行動できる駒が、1 回の行動につき 1 回だけ動ける。いまのマスを行き先にしてもよい（動かない移動）。
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


func execute(battle: Battle) -> Array:
	var unit := battle.unit_by_id(unit_id)
	var path := Movement.path_to(battle, unit, to, cruise)
	battle.acting_unit_id = unit.id
	unit.has_moved = true
	unit.move_origin = unit.cell
	unit.cruised = cruise
	unit.cell = to
	return [UnitMovedEvent.new(unit_id, path)]
