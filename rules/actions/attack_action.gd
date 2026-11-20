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
	var events: Array[BattleEvent] = []
	var first := RuleProbe.f("brace_first") > 0
	if first:
		events.append_array(_counter(battle, target, attacker))
		if attacker.hp == 0:
			return events
	events.append_array(Combat.strike(battle, attacker, target))
	if not first and target.hp > 0:
		events.append_array(_counter(battle, target, attacker))
		if attacker.hp == 0:
			return events
	var reason := ExperienceGainedEvent.Reason.DEFEAT if target.hp == 0 else ExperienceGainedEvent.Reason.HIT
	events.append_array(Growth.gain(attacker, experience, reason))
	events.append(battle.finish_action(attacker))
	return events


## SCRATCH: 構えた駒の反撃（RuleProbe brace = 攻撃力の %）。
static func _counter(battle: Battle, defender: Unit, attacker: Unit) -> Array[BattleEvent]:
	var events: Array[BattleEvent] = []
	if not defender.braced or attacker.side == Unit.Side.NEUTRAL or defender.side == Unit.Side.NEUTRAL:
		return events
	if not Combat.can_attack(battle, defender, attacker):
		return events
	if RuleProbe.f("brace_keep") == 0:
		defender.braced = false
	var full := Combat.hit(battle, defender, attacker)
	if full.smoke != null:
		return events
	var amount := full.amount * int(RuleProbe.f("brace")) / 100
	var resolved := Hit.resolve(defender, attacker, amount, UnitDamagedEvent.Cause.ATTACK)
	var after := resolved.apply()
	events.append(AttackDamagedEvent.new(resolved))
	events.append_array(after)
	if attacker.hp == 0:
		events.append_array(battle.remove_unit(attacker, defender))
	return events
