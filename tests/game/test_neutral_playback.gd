extends "res://tests/base_test.gd"
## 中立のフェーズの見せ方の単位（game/neutral_playback.gd）。ルールが返したイベントを、場面に分ける。

const Maps := preload("res://tests/support/maps.gd")
const NeutralPlayback := preload("res://game/neutral_playback.gd")

const NEUTRAL := Unit.Side.NEUTRAL


## 中立のフェーズを 1 回回し、そこで起きたこと（中立の PhaseStartedEvent の次から、次のフェーズの手前まで）を返す。
func _neutral_phase(battle: Battle) -> Array[BattleEvent]:
	if battle.phase == Unit.Side.PLAYER1:
		battle.apply(EndPhaseAction.new())
	var result: Array[BattleEvent] = []
	var inside := false
	for event in battle.apply(EndPhaseAction.new()).events:
		var started := event as PhaseStartedEvent
		if started != null:
			inside = started.side == NEUTRAL
		elif inside:
			result.append(event)
	return result


func _core(battle: Battle, cell: Vector2i, home: Vector2i) -> Unit:
	var unit := battle.add_unit(UnitKind.Id.MINION, NEUTRAL, cell)
	unit.home_cell = home
	return unit


func test_spawns_are_quiet_and_flow_together() -> void:
	var battle := Maps.battle([
		".......",
		".*...*.",
		".......",
	])
	var beats := NeutralPlayback.beats(_neutral_phase(battle))
	assert_eq(beats.size(), 2, "湧いた駒ごとに場面を分けていない")
	assert_true(beats[0].quiet and beats[1].quiet, "湧いただけなのに、見せる場面になった")
	assert_ne(beats[0].actor_id, beats[1].actor_id)
	assert_eq(NeutralPlayback.groups(beats).size(), 1, "続いている静かな場面を、まとめていない")


func test_an_attack_is_shown_one_by_one_in_order() -> void:
	var battle := Maps.battle([
		".........",
		".........",
		".........",
	])
	# 泉が無いので、湧かない。左の駒は動くだけ、真ん中の駒は隣の駒を攻撃する、右の駒は動くだけ。
	battle.add_unit(UnitKind.Id.SHIELD_TROOPER, Unit.Side.PLAYER1, Vector2i(4, 0))
	var walker1 := _core(battle, Vector2i(0, 2), Vector2i(0, 2))
	var striker := _core(battle, Vector2i(4, 1), Vector2i(4, 1))
	var walker2 := _core(battle, Vector2i(8, 2), Vector2i(8, 2))
	var events := _neutral_phase(battle)
	var beats := NeutralPlayback.beats(events)
	var shown: Array[NeutralPlayback.Beat] = []
	var total := 0
	for beat in beats:
		total += beat.events.size()
		if not beat.quiet:
			shown.append(beat)
	assert_eq(total, events.size(), "場面に入っていないイベントがある")
	assert_eq(shown.size(), 1, "見せる場面は、攻撃した駒の 1 つ")
	assert_eq(shown[0].actor_id, striker.id)
	assert_true(shown[0].events.any(func(event: BattleEvent) -> bool: return event is AttackDamagedEvent))
	# 見せる場面をはさむ静かな場面は、まとめない（起きた順を変えない）。
	var groups := NeutralPlayback.groups(beats)
	var order: Array[int] = []
	for group in groups:
		for beat: NeutralPlayback.Beat in group:
			order.append(beat.actor_id)
		if not (group[0] as NeutralPlayback.Beat).quiet:
			assert_eq(group.size(), 1, "見せる場面を、ほかとまとめた")
	var expected: Array[int] = []
	for beat in beats:
		expected.append(beat.actor_id)
	assert_eq(order, expected, "順番が変わった")
	assert_true(walker1.id != 0 and walker2.id != 0)


func test_moving_only_is_quiet() -> void:
	var battle := Maps.battle([
		".........",
		".........",
	])
	# 縄張りの中に相手がいるが、届かない。近づくだけ。
	battle.add_unit(UnitKind.Id.SHIELD_TROOPER, Unit.Side.PLAYER1, Vector2i(5, 0))
	var core := _core(battle, Vector2i(0, 0), Vector2i(2, 0))
	var beats := NeutralPlayback.beats(_neutral_phase(battle))
	if beats.is_empty():
		return  # 動かなかった（縄張りの外）。見せるものは無い。
	assert_eq(beats.size(), 1)
	assert_eq(beats[0].actor_id, core.id)
	assert_true(beats[0].quiet, "動いただけなのに、見せる場面になった")


# ---- 中立の駒のいない番を飛ばす ----


## P2 のフェーズを終えたときに起きたことと、そのうちの中立の PhaseStartedEvent の位置と、中立のフェーズの始めに盤にいた中立の駒の番号。
func _ending_p2(battle: Battle) -> Array:
	if battle.phase == Unit.Side.PLAYER1:
		battle.apply(EndPhaseAction.new())
	var ids: Array[int] = []
	for unit in battle.units:
		if unit.side == NEUTRAL:
			ids.append(unit.id)
	var events := battle.apply(EndPhaseAction.new()).events
	var at := -1
	for i in events.size():
		var started := events[i] as PhaseStartedEvent
		if started != null and started.side == NEUTRAL:
			at = i
	return [events, at, ids]


func test_a_phase_without_neutral_units_is_skipped() -> void:
	var found := _ending_p2(Maps.battle(["......."]))
	assert_true(found[1] >= 0, "中立のフェーズが来ていない")
	assert_false(NeutralPlayback.phase_has_neutrals(found[0], found[1], found[2]))


func test_a_phase_with_a_neutral_unit_on_the_board_is_shown() -> void:
	var battle := Maps.battle(["......."])
	_core(battle, Vector2i(3, 0), Vector2i(3, 0))
	var found := _ending_p2(battle)
	assert_true(NeutralPlayback.phase_has_neutrals(found[0], found[1], found[2]))


func test_a_phase_where_a_neutral_unit_appears_is_shown() -> void:
	var found := _ending_p2(Maps.battle([".......", ".*.....", "......."]))
	assert_true(NeutralPlayback.phase_has_neutrals(found[0], found[1], found[2]), "湧いた番から出す")


func test_a_neutral_unit_on_the_board_at_the_start_counts_even_if_defeated_later() -> void:
	var core := Unit.new(9, UnitKind.Id.MINION, NEUTRAL, Vector2i(1, 0))
	var events: Array[BattleEvent] = [
		PhaseStartedEvent.new(1, NEUTRAL), PhaseStartedEvent.new(2, Unit.Side.PLAYER1), UnitDefeatedEvent.new(core),
	]
	assert_true(NeutralPlayback.phase_has_neutrals(events, 0, [9] as Array[int]), "あとで倒れても、その番の始めには盤にいた")


func test_a_neutral_unit_that_appears_in_a_later_phase_does_not_count() -> void:
	var core := Unit.new(9, UnitKind.Id.MINION, NEUTRAL, Vector2i(1, 0))
	var events: Array[BattleEvent] = [
		PhaseStartedEvent.new(1, NEUTRAL), PhaseStartedEvent.new(2, Unit.Side.PLAYER1), PhaseStartedEvent.new(2, NEUTRAL),
		UnitSpawnedEvent.new(core),
	]
	assert_false(NeutralPlayback.phase_has_neutrals(events, 0, [] as Array[int]), "あとの番で湧いた駒は、その番にはいなかった")
	assert_true(NeutralPlayback.phase_has_neutrals(events, 2, [] as Array[int]), "湧いた番は出す")
