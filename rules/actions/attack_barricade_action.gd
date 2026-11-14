class_name AttackBarricadeAction
extends BattleAction
## 駒がいまの位置から、射程内の相手の盾を攻撃する。盾の耐久力が攻撃力のぶん減り、0 になれば盾は消える。
## 攻撃した駒は行動を終える。経験値は入らない（駒に何かをしたわけではない）。
##
## 駒への攻撃と同じく、動かずに攻撃してもよく、巡航で動いた駒は攻撃できない。docs/field-effects.md。

var unit_id: int
var cell: Vector2i


func _init(attacker_id: int, barricade_cell: Vector2i) -> void:
	unit_id = attacker_id
	cell = barricade_cell


func is_valid(battle: Battle) -> bool:
	var attacker := battle.unit_by_id(unit_id)
	if not battle.can_act(attacker) or attacker.cruised:
		return false
	return FieldEffects.can_attack_barricade(battle, attacker, cell)


func execute(battle: Battle) -> Array[BattleEvent]:
	var attacker := battle.unit_by_id(unit_id)
	var barricade := battle.board.barricade_at(cell)
	var amount := FieldEffects.barricade_damage(attacker)
	barricade.durability = maxi(0, barricade.durability - amount)
	var events: Array[BattleEvent] = [BarricadeDamagedEvent.new(attacker.id, barricade, amount)]
	if barricade.durability == 0:
		battle.board.remove_field_effect(barricade)
		events.append(FieldEffectRemovedEvent.new(barricade, FieldEffectRemovedEvent.Reason.DESTROYED))
	events.append_array(Statuses.after_attack(attacker))
	events.append(battle.finish_action(attacker))
	return events
