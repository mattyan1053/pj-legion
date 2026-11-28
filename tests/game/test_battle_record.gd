extends "res://tests/base_test.gd"
## 対戦の記録（game/battle_record.gd。リプレイの元）: 始めの写しに記録した行動を当て直すと、元の対局と同じ終わりになること。
## 控えた CPU どうしの 1 局（tests/support/cpu_game.gd）を使う。

const CpuGame := preload("res://tests/support/cpu_game.gd")
const BattleRecord := preload("res://game/battle_record.gd")


## 対戦の、目に見えるところと決着（比べる用）。
static func shape(battle: Battle) -> Array:
	var units := []
	for unit in battle.units:
		units.append([unit.id, unit.side, unit.kind, unit.cell, unit.hp, unit.max_hp(), unit.level, unit.evolution, unit.acted, Statuses.types_of(unit)])
	return [battle.turn, battle.phase, battle.winner, battle.capture_turns, battle.stronghold_holds, battle.relics, battle.board.barrel_cells, units]


## 遊んだ対局を記録して、元の対局と同じ終わりの記録を返す: [記録, 元の終わりの対戦, 元の出来事の数]。
static func _recorded() -> Array:
	var battle := CpuGame.start()
	var record: RefCounted = BattleRecord.of(battle)
	var counts := [0]
	CpuGame.replay(battle, func(result: ActionResult) -> void: counts[0] += result.events.size(), record.add)
	return [record, battle, counts[0]]


func test_replaying_the_record_ends_like_the_game() -> void:
	var recorded := _recorded()
	var record: RefCounted = recorded[0]
	var ended: Battle = recorded[1]
	assert_true(ended.is_over(), "控えた局は決着している")
	assert_eq(record.size(), CpuGame.actions().size())
	var events := [0]
	var replayed: Battle = record.battle_at(record.size(), func(result: ActionResult) -> void: events[0] += result.events.size())
	assert_eq(shape(replayed), shape(ended), "終わりの盤と決着が元の対局と同じ")
	assert_eq(events[0], recorded[2], "出来事の数も同じ")
	# 何度当て直しても同じ（写しの乱数を進めない）。
	assert_eq(shape(record.battle_at(record.size())), shape(ended))


## 記録は、始めた時点の写し。元の対戦がそのあと進んでも変わらない。
func test_the_record_starts_from_a_copy() -> void:
	var recorded := _recorded()
	var record: RefCounted = recorded[0]
	assert_eq(shape(record.battle_at(0)), shape(CpuGame.start()))


## ターンの頭: そこまで当て直すと、そのターンの始め（先手の番、だれも行動していない）。
func test_turn_heads_are_the_starts_of_turns() -> void:
	var record: RefCounted = _recorded()[0]
	var first: int = record.turn_at(0)
	assert_eq(record.head_of(first), 0)
	assert_true(record.last_turn() > first + 2, "数ターン続く局")
	var previous := 0
	for turn in range(first + 1, record.last_turn() + 1):
		var head: int = record.head_of(turn)
		assert_true(head > previous, "ターン %d の頭は前のターンの頭より後" % turn)
		previous = head
		var at_head: Battle = record.battle_at(head)
		assert_eq(at_head.turn, turn)
		assert_eq(at_head.phase, record.battle_at(0).phase, "ターン %d の頭は先手の番" % turn)
		assert_eq(record.turn_at(head - 1), turn - 1, "頭の 1 つ前は前のターン")
	assert_eq(record.head_of(record.last_turn() + 1), -1, "決着より先のターンは無い")
