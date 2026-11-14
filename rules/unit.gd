class_name Unit
extends RefCounted
## 盤上の駒 1 体。種類・陣営・位置と、いまの状態を持つ。

## 陣営。PLAYER1 / PLAYER2 の値は Board.hq_cells の添字と同じ。
enum Side { PLAYER1 = 0, PLAYER2 = 1, NEUTRAL = 2 }

## 戦いの中で駒を指す番号。Battle が振る。
var id: int
var kind: UnitKind.Id
var side: Unit.Side
var cell: Vector2i
var hp: int


func _init(unit_id: int, unit_kind: UnitKind.Id, unit_side: Unit.Side, at: Vector2i) -> void:
	id = unit_id
	kind = unit_kind
	side = unit_side
	cell = at
	hp = UnitKind.max_hp(kind)


func move_range() -> int:
	return UnitKind.move_range(kind)


func is_enemy_of(other: Unit) -> bool:
	return side != other.side
