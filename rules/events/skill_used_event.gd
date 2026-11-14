class_name SkillUsedEvent
extends BattleEvent
## 駒がスキルを使った。効果のイベント（盾が置かれた、など）は、このあとに続く。
## target は対象のマス、cooldown は使ったあとに付いたクールダウン。

var unit_id: int
var skill: Skill.Id
var target: Vector2i
var cooldown: int


func _init(user_id: int, used: Skill.Id, target_cell: Vector2i, cooldown_after: int) -> void:
	unit_id = user_id
	skill = used
	target = target_cell
	cooldown = cooldown_after
