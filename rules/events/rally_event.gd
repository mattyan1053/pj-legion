class_name RallyEvent
extends BattleEvent
## 倒れた骸骨旗手（魔物）の周りの味方が、奮起した（docs/monsters.md）。続けて、奮起した駒ごとの StatusAppliedEvent。

## 倒れた駒の番号と、そのいたマス。
var fallen_id: int
var cell: Vector2i
## 奮起した駒の番号（上の行から、左の列から）。
var rallied_ids: Array[int] = []


func _init(fallen: Unit, rallied: Array[Unit]) -> void:
	fallen_id = fallen.id
	cell = fallen.cell
	for unit in rallied:
		rallied_ids.append(unit.id)
