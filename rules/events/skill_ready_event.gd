class_name SkillReadyEvent
extends BattleEvent
## 駒のクールダウンが 0 になり、またスキルを使えるようになった（持ち主のフェーズの始め）。

var unit_id: int
var skill: Skill.Id


func _init(ready_unit_id: int, ready_skill: Skill.Id) -> void:
	unit_id = ready_unit_id
	skill = ready_skill
