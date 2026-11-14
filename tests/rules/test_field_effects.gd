extends "res://tests/base_test.gd"
## 盤の上の効果（盾、煙幕、聖域）: 置く・消える・期間が進む処理と、移動・攻撃・回復・樽・中立の駒・CPU への影響。

const Maps := preload("res://tests/support/maps.gd")

const P1 := Unit.Side.PLAYER1
const P2 := Unit.Side.PLAYER2
const NEUTRAL := Unit.Side.NEUTRAL

const OPEN: Array[String] = [
	"........",
	"........",
	"........",
	"........",
	"........",
]


func _battle(rows: Array[String] = OPEN) -> Battle:
	return Maps.battle(rows)


func _event_types(events: Array[BattleEvent]) -> Array[Script]:
	var result: Array[Script] = []
	for event in events:
		result.append(event.get_script())
	return result


## フェーズを 1 つ終える（プレイヤー2 のあとは、中立を通って次のターンのプレイヤー1 まで進む）。起きたことを返す。
func _end_phase(battle: Battle) -> Array[BattleEvent]:
	var result := battle.apply(EndPhaseAction.new())
	assert_true(result.accepted, "フェーズを終えられない")
	return result.events


# --- 層と問い合わせ ---


func test_effects_sit_on_their_own_layer() -> void:
	var battle := _battle(["F.S..", ".....", "....."])
	FieldEffects.place_smoke(battle, P1, Vector2i(1, 1))
	assert_eq(battle.board.terrain_at(Vector2i(0, 0)), Terrain.Type.FOREST)
	assert_eq(battle.board.object_at(Vector2i(2, 0)), MapObject.Type.SPRING)
	assert_eq(battle.board.move_cost(Vector2i(0, 0)), 2, "煙幕の下の森は、森のまま")
	var effects := battle.board.field_effects_at(Vector2i(2, 0))
	assert_eq(effects.size(), 1)
	assert_eq(effects[0].type, FieldEffect.Type.SMOKE)
	assert_eq(effects[0].side, P1)
	assert_true(effects[0].is_walkable())
	assert_false(effects[0].blocks_line_of_fire())
	assert_eq(battle.board.field_effects_at(Vector2i(3, 0)).size(), 0)


func test_barricade_has_durability_and_blocks() -> void:
	var battle := _battle()
	var events := FieldEffects.place_barricade(battle, P2, Vector2i(3, 2))
	assert_eq(_event_types(events), [BarricadePlacedEvent] as Array[Script])
	var placed := events[0] as BarricadePlacedEvent
	assert_eq(placed.durability, FieldEffects.BARRICADE_DURABILITY)
	assert_eq(placed.cells, [Vector2i(3, 2)] as Array[Vector2i])
	assert_eq(placed.side, P2)
	var barricade := battle.board.barricade_at(Vector2i(3, 2))
	assert_eq(barricade.id, placed.effect_id)
	assert_eq(barricade.durability, 20)
	assert_false(barricade.is_walkable())
	assert_true(barricade.blocks_line_of_fire())
	assert_false(battle.board.is_walkable(Vector2i(3, 2)))


func test_area_effects_cover_3x3_clipped_to_the_board() -> void:
	var battle := _battle()
	var smoke := FieldEffects.place_smoke(battle, P1, Vector2i(3, 2))[0] as AreaEffectPlacedEvent
	assert_eq(smoke.cells.size(), 9)
	assert_eq(smoke.cells[0], Vector2i(2, 1))
	assert_eq(smoke.cells[8], Vector2i(4, 3))
	assert_eq(smoke.turns_left, FieldEffects.SMOKE_TURNS)
	var corner := FieldEffects.place_sanctuary(battle, P2, Vector2i(0, 0))[0] as AreaEffectPlacedEvent
	assert_eq(corner.cells, [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)] as Array[Vector2i])
	assert_eq(corner.turns_left, FieldEffects.SANCTUARY_TURNS)
	assert_eq(corner.type, FieldEffect.Type.SANCTUARY)
	assert_ne(corner.effect_id, smoke.effect_id)
	assert_eq(FieldEffects.place_smoke(battle, P1, Vector2i(9, 9)).size(), 0, "中心が盤の外")


func test_barricade_needs_an_empty_plain_cell() -> void:
	var battle := _battle(["#B*S..", "......"])
	battle.board.hq_cells = [Vector2i(0, 1), Vector2i(5, 1)]
	battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(1, 1))
	FieldEffects.place_smoke(battle, P1, Vector2i(4, 0))
	assert_false(FieldEffects.can_place_barricade(battle, Vector2i(0, 0)), "障害物")
	assert_false(FieldEffects.can_place_barricade(battle, Vector2i(1, 0)), "起爆樽")
	assert_false(FieldEffects.can_place_barricade(battle, Vector2i(2, 0)), "結晶泉")
	assert_false(FieldEffects.can_place_barricade(battle, Vector2i(3, 0)), "回復の泉（と煙幕）")
	assert_false(FieldEffects.can_place_barricade(battle, Vector2i(4, 0)), "煙幕")
	assert_false(FieldEffects.can_place_barricade(battle, Vector2i(0, 1)), "本陣")
	assert_false(FieldEffects.can_place_barricade(battle, Vector2i(1, 1)), "駒")
	assert_false(FieldEffects.can_place_barricade(battle, Vector2i(9, 9)), "盤の外")
	assert_true(FieldEffects.can_place_barricade(battle, Vector2i(2, 1)))
	FieldEffects.place_barricade(battle, P1, Vector2i(2, 1))
	assert_false(FieldEffects.can_place_barricade(battle, Vector2i(2, 1)), "もう盾がある")
	assert_eq(FieldEffects.place_barricade(battle, P1, Vector2i(0, 0)).size(), 0)
	assert_eq(FieldEffects.place_barricade(battle, NEUTRAL, Vector2i(3, 1)).size(), 0, "中立は置けない")
	assert_eq(battle.board.field_effects.size(), 2)


# --- 盾: 移動 ---


func test_barricade_blocks_movement_for_everyone() -> void:
	var battle := _battle(["#.#", "...", "#.#"])
	var runner := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(1, 0))
	FieldEffects.place_barricade(battle, P1, Vector2i(1, 1))  # 自分の盾でも通れない
	var reach := Movement.reachable(battle, runner)
	assert_false(reach.has(Vector2i(1, 1)))
	assert_false(reach.has(Vector2i(1, 2)), "盾の向こうへ回り込む道が無い")
	assert_eq(battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(1, 1)), null, "盾のマスに駒は置けない")


func test_walkable_revision_follows_barricades() -> void:
	var battle := _battle()
	var before := battle.board.walkable_revision
	FieldEffects.place_barricade(battle, P1, Vector2i(2, 2))
	assert_true(battle.board.walkable_revision > before)
	var middle := battle.board.walkable_revision
	FieldEffects.place_smoke(battle, P1, Vector2i(5, 2))
	assert_eq(battle.board.walkable_revision, middle, "煙幕は入れるマスを変えない")


# --- 盾: 射線 ---


func test_cells_between() -> void:
	assert_eq(Combat.cells_between(Vector2i(0, 0), Vector2i(3, 0)), [Vector2i(1, 0), Vector2i(2, 0)] as Array[Vector2i])
	assert_eq(Combat.cells_between(Vector2i(0, 0), Vector2i(1, 0)), [] as Array[Vector2i], "隣")
	assert_eq(Combat.cells_between(Vector2i(0, 0), Vector2i(1, 1)), [] as Array[Vector2i], "斜め隣は角に触れるだけ")
	assert_eq(Combat.cells_between(Vector2i(0, 0), Vector2i(2, 2)), [Vector2i(1, 1)] as Array[Vector2i], "斜めの線上")
	assert_eq(
		Combat.cells_between(Vector2i(0, 0), Vector2i(2, 1)), [Vector2i(1, 0), Vector2i(1, 1)] as Array[Vector2i], "桂馬の形"
	)
	assert_eq(
		Combat.cells_between(Vector2i(0, 0), Vector2i(3, 1)), [Vector2i(1, 0), Vector2i(2, 1)] as Array[Vector2i]
	)
	for pair: Array in [[Vector2i(0, 0), Vector2i(3, 1)], [Vector2i(5, 1), Vector2i(1, 3)], [Vector2i(2, 4), Vector2i(2, 0)]]:
		assert_eq(Combat.cells_between(pair[0], pair[1]), Combat.cells_between(pair[1], pair[0]), "向きで変わらない %s" % [pair])


func test_barricade_blocks_ranged_attacks_on_units() -> void:
	var battle := _battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 2))
	var enemy := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(3, 2))
	var beside := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(3, 3))
	assert_true(Combat.can_attack(battle, sniper, enemy))
	FieldEffects.place_barricade(battle, P2, Vector2i(2, 2))
	assert_false(Combat.can_attack(battle, sniper, enemy), "間に盾")
	assert_false(battle.can_apply(AttackAction.new(sniper.id, enemy.id)))
	assert_true(Combat.can_attack(battle, sniper, beside), "線が盾のマスを通らない")
	# 壁（地形）は今までどおり遮らない。
	var walled := _battle(["....", ".#..", "...."])
	var shooter := walled.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 1))
	var target := walled.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(2, 1))
	assert_true(Combat.can_attack(walled, shooter, target))


func test_barricade_does_not_block_adjacent_attacks() -> void:
	var battle := _battle()
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(2, 2))
	var enemy := battle.add_unit(UnitKind.Id.COMMANDO, P2, Vector2i(3, 2))
	FieldEffects.place_barricade(battle, P2, Vector2i(3, 1))
	FieldEffects.place_barricade(battle, P2, Vector2i(2, 1))
	assert_true(Combat.can_attack(battle, paladin, enemy))


func test_barricade_blocks_shots_at_barrels_but_not_heals() -> void:
	var battle := _battle(["B.....", "......", "......"])
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(3, 0))
	var priest := battle.add_unit(UnitKind.Id.PRIEST, P1, Vector2i(3, 2))
	var hurt := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(5, 2))
	hurt.hp -= 10
	assert_true(MapObject.can_attack_barrel(battle, sniper, Vector2i(0, 0)))
	FieldEffects.place_barricade(battle, P2, Vector2i(1, 0))
	FieldEffects.place_barricade(battle, P2, Vector2i(4, 2))
	assert_false(MapObject.can_attack_barrel(battle, sniper, Vector2i(0, 0)), "間に盾")
	assert_true(Healing.can_heal(battle, priest, hurt), "回復は盾に遮られない")


# --- 盾: 攻撃して壊す ---


func test_enemies_can_attack_the_barricade() -> void:
	var battle := _battle()
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(2, 2))
	var own := battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(5, 2))
	var medic := battle.add_unit(UnitKind.Id.MEDIC, P1, Vector2i(4, 3))
	FieldEffects.place_barricade(battle, P2, Vector2i(3, 2))
	assert_eq(battle.options(commando.id).barricade_cells, [Vector2i(3, 2)] as Array[Vector2i])
	assert_false(FieldEffects.can_attack_barricade(battle, own, Vector2i(3, 2)), "持ち主の駒は攻撃できない")
	assert_false(FieldEffects.can_attack_barricade(battle, medic, Vector2i(3, 2)), "回復役は攻撃できない")
	assert_false(FieldEffects.can_attack_barricade(battle, commando, Vector2i(4, 2)), "盾の無いマス")

	var result := battle.apply(AttackBarricadeAction.new(commando.id, Vector2i(3, 2)))
	assert_true(result.accepted)
	assert_eq(_event_types(result.events), [BarricadeDamagedEvent, UnitActedEvent] as Array[Script], "経験値は入らない")
	var chipped := result.events[0] as BarricadeDamagedEvent
	assert_eq(chipped.amount, commando.power())
	assert_eq(chipped.durability, 20 - commando.power())
	assert_eq(battle.board.barricade_at(Vector2i(3, 2)).durability, 20 - commando.power())
	assert_eq(commando.experience, 0)
	assert_true(commando.acted)


func test_barricade_breaks_at_zero_durability() -> void:
	var battle := _battle()
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(2, 2))
	FieldEffects.place_barricade(battle, P2, Vector2i(3, 2))
	battle.board.barricade_at(Vector2i(3, 2)).durability = 5
	var result := battle.apply(AttackBarricadeAction.new(commando.id, Vector2i(3, 2)))
	assert_eq(
		_event_types(result.events),
		[BarricadeDamagedEvent, FieldEffectRemovedEvent, UnitActedEvent] as Array[Script],
	)
	assert_eq((result.events[0] as BarricadeDamagedEvent).durability, 0)
	var removed := result.events[1] as FieldEffectRemovedEvent
	assert_eq(removed.reason, FieldEffectRemovedEvent.Reason.DESTROYED)
	assert_eq(removed.cells, [Vector2i(3, 2)] as Array[Vector2i])
	assert_eq(battle.board.barricade_at(Vector2i(3, 2)), null)
	assert_true(battle.board.is_walkable(Vector2i(3, 2)), "壊れたら通れる")
	assert_eq(battle.board.field_effects.size(), 0)


func test_cruised_units_cannot_attack_the_barricade() -> void:
	var battle := _battle()
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(0, 2))
	FieldEffects.place_barricade(battle, P2, Vector2i(7, 2))
	assert_true(battle.apply(MoveAction.new(commando.id, Vector2i(6, 2), true)).accepted)
	assert_eq(battle.options(commando.id).barricade_cells.size(), 0)
	assert_false(battle.can_apply(AttackBarricadeAction.new(commando.id, Vector2i(7, 2))))


# --- 煙幕 ---


func test_smoke_nullifies_ranged_attacks_on_its_owner() -> void:
	var battle := _battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 2))
	var hidden := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(3, 2))
	FieldEffects.place_smoke(battle, P2, Vector2i(4, 2))
	assert_eq(Combat.damage(battle, sniper, hidden), 0, "予測も 0")
	assert_true(battle.options(sniper.id).attack_target_ids.has(hidden.id), "攻撃はできる（無効になるだけ）")
	var result := battle.apply(AttackAction.new(sniper.id, hidden.id))
	assert_true(result.accepted)
	assert_eq(_event_types(result.events), [SmokeBlockedEvent, UnitActedEvent] as Array[Script], "経験値は入らない")
	var blocked := result.events[0] as SmokeBlockedEvent
	assert_eq(blocked.attacker_id, sniper.id)
	assert_eq(blocked.target_id, hidden.id)
	assert_eq(blocked.effect_id, battle.board.field_effects[0].id)
	assert_eq(hidden.hp, hidden.max_hp())
	assert_eq(sniper.experience, 0)
	assert_true(sniper.acted, "行動は終わる")


func test_smoke_does_not_stop_adjacent_attacks() -> void:
	var battle := _battle()
	var sorcerer := battle.add_unit(UnitKind.Id.SORCERER, P1, Vector2i(2, 2))
	var hidden := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(3, 2))
	FieldEffects.place_smoke(battle, P2, Vector2i(3, 2))
	# 射程 2 の駒でも、隣からなら当たる（測るのは距離）。
	assert_eq(Combat.damage(battle, sorcerer, hidden), sorcerer.power())
	var result := battle.apply(AttackAction.new(sorcerer.id, hidden.id))
	assert_true(result.events[0] is AttackDamagedEvent)
	assert_eq(hidden.hp, hidden.max_hp() - sorcerer.power())


func test_smoke_only_shields_its_owner() -> void:
	var battle := _battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 2))
	var enemy := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(3, 2))
	FieldEffects.place_smoke(battle, P1, Vector2i(3, 2))  # 撃つ側の煙幕
	assert_eq(Combat.damage(battle, sniper, enemy), sniper.power())
	var minion := battle.add_unit(UnitKind.Id.MINION, NEUTRAL, Vector2i(3, 3))
	assert_eq(FieldEffects.smoke_covering(battle, sniper.cell, minion), null, "中立の駒は守らない")


func test_smoke_lasts_two_of_its_owners_phase_starts() -> void:
	var battle := _battle()
	battle.add_unit(UnitKind.Id.KING, P1, Vector2i(0, 0))
	battle.add_unit(UnitKind.Id.KING, P2, Vector2i(7, 4))
	var smoke_id := (FieldEffects.place_smoke(battle, P1, Vector2i(3, 2))[0] as FieldEffectPlacedEvent).effect_id
	var events := _end_phase(battle)  # プレイヤー2 のフェーズ: 減らない
	assert_false(_event_types(events).has(FieldEffectTickedEvent))
	events = _end_phase(battle)  # ターン 2 のプレイヤー1: 2 -> 1
	var ticked: FieldEffectTickedEvent = null
	for event in events:
		if event is FieldEffectTickedEvent:
			ticked = event
	assert_true(ticked != null)
	assert_eq(ticked.effect_id, smoke_id)
	assert_eq(ticked.turns_left, 1)
	_end_phase(battle)
	events = _end_phase(battle)  # ターン 3 のプレイヤー1: 1 -> 0 で消える
	var removed: FieldEffectRemovedEvent = null
	for event in events:
		if event is FieldEffectRemovedEvent:
			removed = event
	assert_true(removed != null, "消えなかった")
	assert_eq(removed.reason, FieldEffectRemovedEvent.Reason.EXPIRED)
	assert_eq(battle.board.field_effects.size(), 0)
	assert_eq(battle.turn, 3)


# --- 聖域 ---


func test_sanctuary_heals_its_owner_at_phase_start() -> void:
	var battle := _battle()
	battle.add_unit(UnitKind.Id.KING, P1, Vector2i(0, 0))
	battle.add_unit(UnitKind.Id.KING, P2, Vector2i(7, 4))
	var inside := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(3, 2))
	var nearly := battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(4, 3))
	var outside := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(5, 2))
	var enemy := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(2, 2))
	for unit: Unit in [inside, nearly, outside, enemy]:
		unit.hp = unit.max_hp() - 10
	nearly.hp = nearly.max_hp() - 2
	FieldEffects.place_sanctuary(battle, P2, Vector2i(3, 2))
	var events := _end_phase(battle)  # プレイヤー2 のフェーズが始まる
	var healed: Array[SanctuaryHealedEvent] = []
	for event in events:
		if event is SanctuaryHealedEvent:
			healed.append(event)
	assert_eq(healed.size(), 2)
	assert_eq(healed[0].unit_id, inside.id)
	assert_eq(healed[0].amount, FieldEffects.SANCTUARY_HEAL)
	assert_eq(healed[0].cause, UnitHealedEvent.Cause.SANCTUARY)
	assert_eq(healed[1].unit_id, nearly.id)
	assert_eq(healed[1].amount, 2, "最大 HP を超えない")
	assert_eq(inside.hp, inside.max_hp() - 5)
	assert_eq(outside.hp, outside.max_hp() - 10, "範囲の外")
	assert_eq(enemy.hp, enemy.max_hp() - 10, "相手の駒は回復しない")
	# 相手（プレイヤー1）のフェーズの始めには回復しない。
	_end_phase(battle)
	assert_eq(inside.hp, inside.max_hp() - 5)


func test_sanctuary_heals_three_times_then_vanishes() -> void:
	var battle := _battle()
	battle.add_unit(UnitKind.Id.KING, P1, Vector2i(0, 0))
	battle.add_unit(UnitKind.Id.KING, P2, Vector2i(7, 4))
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(3, 2))
	paladin.hp = 10
	FieldEffects.place_sanctuary(battle, P1, Vector2i(3, 2))
	for i in 3:
		_end_phase(battle)
		_end_phase(battle)
	assert_eq(paladin.hp, 10 + 3 * FieldEffects.SANCTUARY_HEAL)
	assert_eq(battle.board.field_effects.size(), 0, "3 回目の回復のあとに消える")
	_end_phase(battle)
	_end_phase(battle)
	assert_eq(paladin.hp, 10 + 3 * FieldEffects.SANCTUARY_HEAL)


func test_overlapping_sanctuaries_heal_once() -> void:
	var battle := _battle()
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(3, 2))
	paladin.hp = 10
	FieldEffects.place_sanctuary(battle, P1, Vector2i(3, 2))
	FieldEffects.place_sanctuary(battle, P1, Vector2i(4, 2))
	var events := FieldEffects.start_phase(battle, P1)
	assert_eq(paladin.hp, 15)
	assert_eq((events[0] as SanctuaryHealedEvent).effect_id, battle.board.field_effects[0].id, "番号の小さいほう")


func test_phase_start_order_heals_before_ticking() -> void:
	var battle := _battle()
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(3, 2))
	paladin.hp = 10
	FieldEffects.place_sanctuary(battle, P1, Vector2i(3, 2))
	battle.board.field_effects[0].turns_left = 1
	var events := FieldEffects.start_phase(battle, P1)
	assert_eq(_event_types(events), [SanctuaryHealedEvent, FieldEffectRemovedEvent] as Array[Script])
	assert_eq(FieldEffects.start_phase(battle, NEUTRAL).size(), 0)


# --- 複製・選べること・中立・CPU ---


func test_clone_copies_effects_separately() -> void:
	var battle := _battle()
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(2, 2))
	FieldEffects.place_barricade(battle, P2, Vector2i(3, 2))
	FieldEffects.place_smoke(battle, P2, Vector2i(6, 2))
	var copy := battle.clone()
	assert_eq(copy.board.field_effects.size(), 2)
	assert_true(copy.board.field_effects[0] != battle.board.field_effects[0], "効果を共有している")
	copy.apply(AttackBarricadeAction.new(commando.id, Vector2i(3, 2)))
	FieldEffects.start_phase(copy, P2)
	assert_eq(battle.board.barricade_at(Vector2i(3, 2)).durability, 20, "元の盾が削れた")
	assert_eq(battle.board.field_effects[1].turns_left, FieldEffects.SMOKE_TURNS, "元の煙幕の期間が進んだ")
	assert_false(battle.board.is_walkable(Vector2i(3, 2)))
	# 番号の採番も同じ続きになる。
	var a := FieldEffects.place_smoke(battle, P1, Vector2i(0, 0))[0] as FieldEffectPlacedEvent
	var b := FieldEffects.place_smoke(copy, P1, Vector2i(0, 0))[0] as FieldEffectPlacedEvent
	assert_eq(a.effect_id, b.effect_id)


func test_options_match_what_the_rules_accept() -> void:
	var battle := _battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(1, 2))
	battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(5, 2))
	battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(4, 4))
	FieldEffects.place_barricade(battle, P2, Vector2i(3, 2))
	FieldEffects.place_barricade(battle, P1, Vector2i(1, 3))
	FieldEffects.place_smoke(battle, P2, Vector2i(4, 4))
	var options := battle.options(sniper.id)
	for cell: Vector2i in [Vector2i(3, 2), Vector2i(1, 3)]:
		assert_eq(
			options.barricade_cells.has(cell), battle.can_apply(AttackBarricadeAction.new(sniper.id, cell)), "盾 %s" % cell
		)
	for unit in battle.units:
		assert_eq(
			options.attack_target_ids.has(unit.id), battle.can_apply(AttackAction.new(sniper.id, unit.id)), "駒 %d" % unit.id
		)
	for action in options.actions():
		assert_true(battle.can_apply(action), "載っている行動が断られた")


func test_cpu_breaks_through_a_barricade_in_a_corridor() -> void:
	var battle := _battle([
		"#########",
		".........",
		"#########",
	])
	battle.board.hq_cells = [Vector2i(0, 1), Vector2i(8, 1)]
	battle.add_unit(UnitKind.Id.KING, P1, Vector2i(0, 1))
	battle.add_unit(UnitKind.Id.KING, P2, Vector2i(8, 1))
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(2, 1))
	FieldEffects.place_barricade(battle, P2, Vector2i(4, 1))
	var cpu := CpuPlayer.new()
	for i in 6:
		var action := cpu.next_action(battle)
		assert_true(battle.can_apply(action), "CPU の行動が断られる")
		battle.apply(action)
		if battle.phase != P1:
			break
	assert_true(commando.acted)
	assert_true(battle.board.barricade_at(Vector2i(4, 1)).durability < FieldEffects.BARRICADE_DURABILITY, "盾を削らなかった")


func test_cpu_steps_next_to_a_smoked_target() -> void:
	var battle := _battle([
		"..........",
		"..........",
		"..........",
		"..........",
		"..........",
	])
	battle.board.hq_cells = [Vector2i(0, 4), Vector2i(9, 0)]
	battle.add_unit(UnitKind.Id.KING, P1, Vector2i(0, 4))
	battle.add_unit(UnitKind.Id.KING, P2, Vector2i(9, 0))
	var sorcerer := battle.add_unit(UnitKind.Id.SORCERER, P1, Vector2i(3, 2))
	var hidden := battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(6, 2))
	hidden.hp = sorcerer.power()  # 隣から撃てば倒せる
	FieldEffects.place_smoke(battle, P2, Vector2i(6, 2))
	var cpu := CpuPlayer.new()
	for i in 4:
		if battle.phase != P1 or battle.is_over():
			break
		battle.apply(cpu.next_action(battle))
	assert_eq(battle.unit_by_id(hidden.id), null, "煙幕の中の相手を、隣から倒さなかった")
