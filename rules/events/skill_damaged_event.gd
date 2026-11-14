class_name SkillDamagedEvent
extends UnitDamagedEvent
## 駒が、ダメージのあるスキルでダメージを受けた。user_id は使った駒、skill はそのスキル。
##
## 同じスキルのダメージは同時に当たったもので、間にほかのイベントをはさまずに続く（Skills.deal_damage）。
## 倒れた駒の UnitDefeatedEvent は、全員ぶんのこのイベントのあとに並ぶ。

var user_id: int
var skill: Skill.Id


func _init(by_unit_id: int, used: Skill.Id, damaged_unit_id: int, damage: int, hp_after: int) -> void:
	user_id = by_unit_id
	skill = used
	unit_id = damaged_unit_id
	amount = damage
	hp = hp_after
	cause = Cause.SKILL
