class_name BarrelExplodedEvent
extends BattleEvent
## 起爆樽が攻撃されて爆発し、盤から消えた。cell は樽のあったマス、blast_cells は爆発の届いたマス。
## 巻き込まれた駒のダメージと撃破は、このあとに UnitDamagedEvent / UnitDefeatedEvent で続く。

var attacker_id: int
var cell: Vector2i
var blast_cells: Array[Vector2i]


func _init(by_unit_id: int, barrel_cell: Vector2i, reached: Array[Vector2i]) -> void:
	attacker_id = by_unit_id
	cell = barrel_cell
	blast_cells = reached
