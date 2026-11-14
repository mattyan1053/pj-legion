class_name StatusRemovedEvent
extends BattleEvent
## 駒の状態が外れた（docs/unit-statuses.md）。

enum Reason {
	EXPIRED,  ## 残りのターン数が 0 になった（持ち主のフェーズの始め）
	CONSUMED,  ## 使い切った（バリアがダメージを防いだ、照準の攻撃をした）
	MOVED,  ## 駒が動いた（照準）
}

var unit_id: int
var status: Status.Type
var reason: Reason


func _init(on_unit_id: int, removed: Status.Type, why: Reason) -> void:
	unit_id = on_unit_id
	status = removed
	reason = why
