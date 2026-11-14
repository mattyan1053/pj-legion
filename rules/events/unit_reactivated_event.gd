class_name UnitReactivatedEvent
extends BattleEvent
## 行動済みの駒が、行動前に戻った（アドレナリン注射）。このフェーズに、もう一度行動できる。

var unit_id: int


func _init(reactivated_unit_id: int) -> void:
	unit_id = reactivated_unit_id
