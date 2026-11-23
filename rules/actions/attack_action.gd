class_name AttackAction
extends BattleAction
## 駒がいまの位置から、射程内の敵 1 体を攻撃する。攻撃すると行動を終える。
##
## 動かずに攻撃してもよい。巡航で動いた駒は攻撃できない。
## HP が 0 になった駒は倒れ、盤から取り除かれる。
## 攻撃した駒には経験値が入る（Growth。倒したかどうかで量が違う）。
## 煙幕に阻まれた攻撃（ダメージ 0。SmokeBlockedEvent）でも行動は終わる。経験値は入らない。

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
	var experience := Growth.attack_experience(battle, attacker, target)
	var events := Combat.strike(battle, attacker, target)
	# 倒した糸喰いが弾けて、攻撃した駒も倒れたら、経験値も行動を終えるイベントも出ない。
	if not battle.units.has(attacker):
		return events
	var reason := ExperienceGainedEvent.Reason.DEFEAT if target.hp == 0 else ExperienceGainedEvent.Reason.HIT
	events.append_array(Growth.gain(attacker, experience, reason))
	events.append(battle.finish_action(attacker))
	return events
