class_name CutPlacedEvent
extends BattleEvent
## 台本の出来事（カットシーンの台本だけが出す。ルールは出さない。docs/battle-view.md の「盤のカットシーン」）:
## 兵を、光を出さずに盤へ置く（盤の外から歩いて入ってくる兵を、端に置くときなど）。光とともに現れるのは UnitSpawnedEvent。

var unit_id: int
var kind: UnitKind.Id
var side: Unit.Side
var cell: Vector2i
var hp: int
var max_hp: int


func _init(placed: Unit) -> void:
	unit_id = placed.id
	kind = placed.kind
	side = placed.side
	cell = placed.cell
	hp = placed.hp
	max_hp = placed.max_hp()
