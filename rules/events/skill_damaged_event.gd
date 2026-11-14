class_name SkillDamagedEvent
extends UnitDamagedEvent
## 駒が、ダメージのあるスキルでダメージを受けた。user_id は使った駒、skill はそのスキル。
##
## 同じスキルのダメージは同時に当たったもので、間にほかのイベントをはさまずに続く（Skills.deal_damage）。
## 倒れた駒の UnitDefeatedEvent は、全員ぶんのこのイベントのあとに並ぶ。

var user_id: int
var skill: Skill.Id


func _init(used: Skill.Id, hit: Hit) -> void:
	user_id = hit.source.id
	skill = used
	_fill(hit)
