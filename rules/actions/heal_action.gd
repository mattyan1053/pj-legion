class_name HealAction
extends BattleAction
## 回復役がいまの位置から、射程内の味方 1 体を回復する。回復すると行動を終える。
##
## 動かずに回復してもよい。巡航で動いた駒は回復できない（攻撃と同じ扱い）。
## 回復した駒には経験値が入る（Growth）。

var unit_id: int
var target_id: int


func _init(healer_id: int, healed_id: int) -> void:
	unit_id = healer_id
	target_id = healed_id


func is_valid(battle: Battle) -> bool:
	var healer := battle.unit_by_id(unit_id)
	if not battle.can_act(healer) or healer.cruised:
		return false
	return Healing.can_heal(battle, healer, battle.unit_by_id(target_id))


func execute(battle: Battle) -> Array[BattleEvent]:
	var healer := battle.unit_by_id(unit_id)
	var target := battle.unit_by_id(target_id)
	var events: Array[BattleEvent] = [Mend.give(target, Healing.limit(healer), HealerHealedEvent.new(healer.id))]
	events.append_array(Growth.gain(healer, Growth.heal_experience(), ExperienceGainedEvent.Reason.HEAL))
	events.append(battle.finish_action(healer))
	return events
