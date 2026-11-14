class_name StatusAppliedEvent
extends BattleEvent
## 駒に状態が付いた（docs/unit-statuses.md）。turns は残りのターン数。
## もう付いている状態を付け直したとき（残りのターン数が戻る）と、移動の取り消しで戻ったときにも出る。

var unit_id: int
var status: Status.Type
var turns: int


func _init(on_unit_id: int, applied: Status.Type, turns_left: int) -> void:
	unit_id = on_unit_id
	status = applied
	turns = turns_left
