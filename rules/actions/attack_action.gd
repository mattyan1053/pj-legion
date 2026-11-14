class_name AttackAction
extends BattleAction
## 駒がいまの位置から、射程内の敵 1 体を攻撃する。攻撃すると行動を終える。
##
## 動かずに攻撃してもよい。巡航で動いた駒は攻撃できない。
## HP が 0 になった駒は倒れ、盤から取り除かれる。

var unit_id: int
var target_id: int


func _init(attacker_id: int, attacked_id: int) -> void:
	unit_id = attacker_id
	target_id = attacked_id


func is_valid(battle: Battle) -> bool:
	var attacker := battle.unit_by_id(unit_id)
	if not battle.can_act(attacker) or attacker.cruised:
		return false
	return Combat.can_attack(battle, attacker, battle.unit_by_id(target_id))


func execute(battle: Battle) -> Array[BattleEvent]:
	var attacker := battle.unit_by_id(unit_id)
	var target := battle.unit_by_id(target_id)
	var amount := Combat.damage(battle, attacker, target)
	target.hp = maxi(0, target.hp - amount)
	var events: Array[BattleEvent] = [UnitDamagedEvent.new(attacker.id, target.id, amount, target.hp)]
	if target.hp == 0:
		events.append(battle.remove_unit(target))
	events.append(battle.finish_action(attacker))
	return events
