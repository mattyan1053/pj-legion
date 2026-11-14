class_name ExplosionDamagedEvent
extends UnitDamagedEvent
## 駒が、起爆樽の爆発でダメージを受けた。barrel_cell は爆発した樽のマス。
##
## 攻撃した駒は持たない（樽を攻撃した駒は BarrelExplodedEvent.attacker_id）。
## 同じ爆発のダメージは同時に当たったもので、直前の BarrelExplodedEvent（cell が同じ）の
## victim_ids と同じ並びで、間にほかのイベントをはさまずに続く。

var barrel_cell: Vector2i


func _init(exploded_cell: Vector2i, hit: Hit) -> void:
	barrel_cell = exploded_cell
	_fill(hit)
