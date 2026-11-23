class_name BurstEvent
extends BattleEvent
## 倒れた糸喰い（魔物）の腹の糸が弾けた（docs/monsters.md）。cell は糸喰いのいたマス、blast_cells は弾けて届いたマス。
##
## victim_ids は巻き込まれた駒（上の行から、左の列から。陣営を問わない）。全員に同時に当たる。
## このすぐあとに、同じ並びで駒ごとの ExplosionDamagedEvent（barrel_cell がこの cell）が victim_ids の数だけ続き、
## そのあとに倒れた駒の UnitDefeatedEvent が続く（起爆樽の爆発 BarrelExplodedEvent と同じ並び）。

## 倒れた糸喰いの番号。
var fallen_id: int
## 糸喰いを倒した駒の番号（倒した駒がいなければ 0）。巻き込んで倒した駒も、この駒が倒したことにする（BattleStats）。
var by_id: int
var cell: Vector2i
var blast_cells: Array[Vector2i]
var victim_ids: Array[int]


func _init(fallen: Unit, by: Unit, reached: Array[Vector2i], caught: Array[int]) -> void:
	fallen_id = fallen.id
	by_id = by.id if by != null else 0
	cell = fallen.cell
	blast_cells = reached
	victim_ids = caught
