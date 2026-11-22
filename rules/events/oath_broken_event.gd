class_name OathBrokenEvent
extends BattleEvent
## 誓い（組み方。Formation）を結んだ片方（fallen_id）が倒れ、誓いが切れた。残った駒（survivor_id）には、続けて奮起が付く（StatusAppliedEvent）。

var survivor_id: int
var fallen_id: int


func _init(left_id: int, lost_id: int) -> void:
	survivor_id = left_id
	fallen_id = lost_id
