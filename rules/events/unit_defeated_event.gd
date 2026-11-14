class_name UnitDefeatedEvent
extends BattleEvent
## 駒が倒れ、盤から取り除かれた。cell は倒れたマス。

var unit_id: int
var cell: Vector2i
var kind: UnitKind.Id
var side: Unit.Side


func _init(defeated: Unit) -> void:
	unit_id = defeated.id
	cell = defeated.cell
	kind = defeated.kind
	side = defeated.side
