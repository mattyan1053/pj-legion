class_name UnitSpawnedEvent
extends BattleEvent
## 駒が盤に現れた（中立のフェーズに、結晶泉にエナジー・コアが湧いた。中ボスが現れた。骨起こしで骸骨兵が起きた）。
## 見た目は、この値だけで駒を作って置ける。home_cell はその駒が守る場所（docs/neutral-minion.md）。

var unit_id: int
var kind: UnitKind.Id
var side: Unit.Side
var cell: Vector2i
var home_cell: Vector2i
var hp: int
var max_hp: int
## 行動済みで現れたか（骨起こしで起きた骸骨兵は、そのフェーズには動けない）。見た目は行動済みの姿で置く。
var acted: bool


func _init(spawned: Unit) -> void:
	unit_id = spawned.id
	kind = spawned.kind
	side = spawned.side
	cell = spawned.cell
	home_cell = spawned.home_cell
	hp = spawned.hp
	max_hp = spawned.max_hp()
	acted = spawned.acted
