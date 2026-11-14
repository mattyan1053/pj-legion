class_name BarrelExplodedEvent
extends BattleEvent
## 起爆樽が攻撃されて爆発し、盤から消えた。cell は樽のあったマス、blast_cells は爆発の届いたマス。
##
## victim_ids は巻き込まれた駒（上の行から、左の列から）。爆発は全員に同時に当たる。
## このすぐあとに、同じ並びで駒ごとの ExplosionDamagedEvent（barrel_cell がこの cell）が victim_ids の数だけ続き、
## そのあとに倒れた駒の UnitDefeatedEvent が続く。同時に見せたい画面は、victim_ids の数だけ先を読めばよい。

var attacker_id: int
var cell: Vector2i
var blast_cells: Array[Vector2i]
var victim_ids: Array[int]


func _init(by_unit_id: int, barrel_cell: Vector2i, reached: Array[Vector2i], caught: Array[int]) -> void:
	attacker_id = by_unit_id
	cell = barrel_cell
	blast_cells = reached
	victim_ids = caught
