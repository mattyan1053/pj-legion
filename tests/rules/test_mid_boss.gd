extends "res://tests/base_test.gd"
## 中ボス（エリートミニオン）: 置かれる場所、現れる時、倒した陣営の控え、経験値と必殺技のゲージ、CPU（docs/neutral-mid-boss.md）。

const Maps := preload("res://tests/support/maps.gd")

const P1 := Unit.Side.PLAYER1
const P2 := Unit.Side.PLAYER2
const NEUTRAL := Unit.Side.NEUTRAL
const STAGES: Array[BoardGenerator.Stage] = [
	BoardGenerator.Stage.PLAIN, BoardGenerator.Stage.LABYRINTH, BoardGenerator.Stage.TWIN_SPRINGS,
]
const SEEDS: Array[int] = [1, 2, 3, 42, 1234, 20261114]

## 壁の無い 16 x 5 の盤面。中ボスの場所は (6, 2)。
const OPEN_ROWS: Array[String] = [
	"................",
	"................",
	"................",
	"................",
	"................",
]
const HOME := Vector2i(6, 2)


func _battle() -> Battle:
	var battle := Maps.battle(OPEN_ROWS)
	battle.board.mid_boss_cells = [HOME]
	return battle


func _boss(battle: Battle, cell := HOME) -> Unit:
	var unit := battle.add_unit(UnitKind.Id.ELITE_MINION, NEUTRAL, cell)
	unit.home_cell = HOME
	return unit


## 中立のフェーズまで進め、そこで起きたことを返す（P1 の番から呼ぶ）。
func _through_neutral_phase(battle: Battle) -> Array[BattleEvent]:
	battle.apply(EndPhaseAction.new())
	return battle.apply(EndPhaseAction.new()).events


func _of_type(events: Array[BattleEvent], type: Script) -> Array[BattleEvent]:
	var result: Array[BattleEvent] = []
	for event in events:
		if event.get_script() == type:
			result.append(event)
	return result


# ---- 置かれる場所 ----


func test_each_stage_places_two_bosses_fair_to_both_players() -> void:
	for stage in STAGES:
		for map_seed in SEEDS:
			var board := BoardGenerator.generate(stage, map_seed)
			var label := "stage %d seed %d" % [stage, map_seed]
			assert_eq(board.mid_boss_cells.size(), 2, label)
			var left := board.mid_boss_cells[0]
			var right := board.mid_boss_cells[1]
			if stage == BoardGenerator.Stage.TWIN_SPRINGS:
				assert_true(left.y < right.y, "0 が上 " + label)
			else:
				assert_true(left.x < right.x, "0 が左 " + label)
			# 本陣どうしを入れ替える点対称で、2 体が入れ替わる。
			assert_eq(right, board.hq_cells[0] + board.hq_cells[1] - left, label)
			for cell in board.mid_boss_cells:
				assert_eq(board.terrain_at(cell), Terrain.Type.NORMAL, label)
				assert_true(board.can_place_object(cell), "オブジェクトが無い " + label)
				for hq in board.hq_cells:
					assert_true(board.is_reachable(hq, cell), "本陣から歩いて行ける %s %s" % [cell, label])
					# 本陣の近くで序盤に事故が起きない: 中ボスの届く距離（縄張り 4 + 射程 2）の 3 倍は離れている。
					assert_true(Combat.distance(hq, cell) >= 18, "本陣から遠い %s %s" % [cell, label])


func test_twin_springs_bosses_take_as_long_to_reach_for_both_players() -> void:
	# 上の中ボスへ: プレイヤー2 は歩いて、プレイヤー1 は近いポータルを抜けて。下はその逆。歩数（マンハッタン）は 4 歩と違わない（ポータルは、置きたいマスが壁なら 3 マスまでずれる）。
	for map_seed in SEEDS:
		var board := BoardGenerator.generate(BoardGenerator.Stage.TWIN_SPRINGS, map_seed)
		for index in 2:
			var boss := board.mid_boss_cells[index]
			var walker := board.hq_cells[1 - index]
			var jumper := board.hq_cells[index]
			var through := 9999
			for portal: Vector2i in board.portal_exits:
				through = mini(through, Combat.distance(jumper, portal) + Combat.distance(board.portal_exit(portal), boss))
			assert_true(absi(Combat.distance(walker, boss) - through) <= 4, "seed %d %s: 歩き %d、ポータル %d" % [map_seed, boss, Combat.distance(walker, boss), through])
			# ポータルの出口のそばではない（出てすぐ狩れると、そのポータルに近い側だけのものになる）。
			for portal: Vector2i in board.portal_exits:
				assert_true(Combat.distance(portal, boss) > Neutral.TERRITORY_RADIUS + 2, "seed %d %s %s" % [map_seed, boss, portal])


func test_boss_surroundings_are_kept_clear() -> void:
	for stage in STAGES:
		for map_seed in SEEDS:
			var board := BoardGenerator.generate(stage, map_seed)
			for boss in board.mid_boss_cells:
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var cell := boss + Vector2i(dx, dy)
						assert_eq(board.terrain_at(cell), Terrain.Type.NORMAL, "stage %d seed %d %s" % [stage, map_seed, cell])
						assert_eq(board.object_at(cell), MapObject.Type.NONE, "stage %d seed %d %s" % [stage, map_seed, cell])


# ---- 現れる ----


func test_bosses_appear_in_the_first_neutral_phase() -> void:
	var battle := _battle()
	var spawned := _of_type(_through_neutral_phase(battle), UnitSpawnedEvent)
	assert_eq(spawned.size(), 1)
	var event := spawned[0] as UnitSpawnedEvent
	assert_eq(event.kind, UnitKind.Id.ELITE_MINION)
	assert_eq(event.cell, HOME)
	assert_eq(event.home_cell, HOME)
	assert_eq(event.hp, UnitKind.max_hp(UnitKind.Id.ELITE_MINION))
	var boss := battle.unit_at(HOME)
	assert_eq(boss.side, NEUTRAL)
	assert_eq(boss.power(), 10)
	assert_eq(boss.attack_range(), 2)


func test_a_living_boss_is_not_doubled() -> void:
	var battle := _battle()
	_through_neutral_phase(battle)
	var boss := battle.unit_at(HOME)
	boss.cell = HOME + Vector2i(1, 0)
	assert_true(_of_type(_through_neutral_phase(battle), UnitSpawnedEvent).is_empty())


func test_boss_waits_while_its_place_is_taken() -> void:
	var battle := _battle()
	var sitter := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, HOME)
	assert_true(_of_type(_through_neutral_phase(battle), UnitSpawnedEvent).is_empty())
	sitter.cell = Vector2i(0, 0)
	assert_eq(_of_type(_through_neutral_phase(battle), UnitSpawnedEvent).size(), 1)


func test_boss_guards_its_place_like_a_core() -> void:
	# 縄張りの中の駒は、移動 2 + 射程 2 から殴る。縄張りの外へは出ない。
	var battle := _battle()
	var boss := _boss(battle)
	var bait := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, HOME + Vector2i(-4, 0))
	_through_neutral_phase(battle)
	assert_eq(bait.hp, bait.max_hp() - boss.power())
	assert_eq(Combat.distance(boss.cell, bait.cell), 2, "射程 2 から殴る")
	var far := battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(0, 0))
	bait.cell = Vector2i(11, 4)
	far.cell = Vector2i(0, 0)
	assert_eq(Neutral.target_of(battle, boss), null, "縄張り + 射程の外は狙わない")


func test_boss_moves_to_a_cell_with_a_clear_line_of_fire() -> void:
	# いまのマス (8, 2) は射程 2 に入るが、間の (9, 2) に盾がある。動かずにいると撃てないので、盾を回り込むマスへ動いて撃つ。
	var battle := _battle()
	var boss := _boss(battle, Vector2i(8, 2))
	var bait := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(10, 2))
	FieldEffects.place_barricade(battle, P2, Vector2i(9, 2))
	assert_false(Combat.can_attack(battle, boss, bait), "いまのマスからは盾越し")
	var to := Neutral.destination(battle, boss, bait)
	assert_true(to != boss.cell, "盾越しのマスには留まらない")
	assert_true(Combat.reaches(battle, to, bait.cell, boss.attack_range()), "動いた先からは届く")
	assert_true(Neutral.in_territory(boss, to))
	_through_neutral_phase(battle)
	assert_eq(bait.hp, bait.max_hp() - boss.power(), "回り込んで撃つ")


func test_boss_behind_a_barricade_with_no_clear_cell_still_closes_in() -> void:
	# 撃てるマスへ届かなければ、盾越しのマスも、射程の 1 歩外と同じに数えて近づく（使う移動力の少ないほう）。
	var battle := _battle()
	var boss := _boss(battle)
	var bait := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(10, 2))
	FieldEffects.place_barricade(battle, P2, Vector2i(9, 2))
	var to := Neutral.destination(battle, boss, bait)
	assert_eq(to, Vector2i(7, 2), "(8, 2) は射程に入るが盾越し。(7, 2) と同じ近さで、移動力が少ない")


# ---- 倒す ----


func test_last_hit_records_the_slayer() -> void:
	var battle := _battle()
	var boss := _boss(battle)
	boss.hp = 5
	var raider := battle.add_unit(UnitKind.Id.COMMANDO, P1, HOME + Vector2i(0, 1))
	var events := battle.apply(AttackAction.new(raider.id, boss.id)).events
	var types: Array[Script] = []
	for event in events:
		types.append(event.get_script())
	var at := types.find(UnitDefeatedEvent)
	assert_true(at >= 0)
	assert_eq(types[at + 1], MidBossDefeatedEvent, "UnitDefeatedEvent のすぐあと")
	var slain := events[at + 1] as MidBossDefeatedEvent
	assert_eq(slain.boss_index, 0)
	assert_eq(slain.unit_id, boss.id)
	assert_eq(slain.cell, HOME)
	assert_eq(slain.slayer_id, raider.id)
	assert_eq(slain.slayer_side, P1)
	assert_true(battle.is_mid_boss_defeated(0))
	assert_eq(battle.mid_boss_slayers[0], P1)


func test_slain_boss_never_returns() -> void:
	var battle := _battle()
	var boss := _boss(battle)
	boss.hp = 1
	var raider := battle.add_unit(UnitKind.Id.COMMANDO, P1, HOME + Vector2i(0, 1))
	battle.apply(AttackAction.new(raider.id, boss.id))
	raider.cell = Vector2i(0, 0)
	for i in 3:
		assert_true(_of_type(_through_neutral_phase(battle), UnitSpawnedEvent).is_empty())
	assert_eq(battle.unit_at(HOME), null)


func test_killing_the_boss_gives_more_experience_than_a_core() -> void:
	var battle := _battle()
	var boss := _boss(battle)
	boss.hp = 1
	var raider := battle.add_unit(UnitKind.Id.COMMANDO, P1, HOME + Vector2i(0, 1))
	var gained := _of_type(battle.apply(AttackAction.new(raider.id, boss.id)).events, ExperienceGainedEvent)
	assert_eq((gained[0] as ExperienceGainedEvent).amount, Growth.MID_BOSS_DEFEAT_EXPERIENCE)
	assert_true(Growth.MID_BOSS_DEFEAT_EXPERIENCE > Growth.NEUTRAL_DEFEAT_EXPERIENCE)
	var hit := battle.add_unit(UnitKind.Id.ELITE_MINION, NEUTRAL, Vector2i(0, 0))
	assert_eq(Growth.damage_experience(hit, 50), Growth.HIT_EXPERIENCE, "削るだけなら、当たりの 10")


func test_skill_kill_credits_the_user() -> void:
	var battle := _battle()
	var boss := _boss(battle)
	boss.hp = 1
	var sorcerer := battle.add_unit(UnitKind.Id.SORCERER, P2, HOME + Vector2i(-3, 0))
	battle.apply(EndPhaseAction.new())
	var events := battle.apply(UseSkillAction.new(sorcerer.id, HOME)).events
	var slain := _of_type(events, MidBossDefeatedEvent)
	assert_eq(slain.size(), 1)
	assert_eq((slain[0] as MidBossDefeatedEvent).slayer_id, sorcerer.id)
	assert_eq(battle.mid_boss_slayers[0], P2)


func test_barrel_kill_credits_the_attacker_without_experience() -> void:
	var battle := _battle()
	var boss := _boss(battle)
	boss.hp = 1
	battle.board.add_barrel(HOME + Vector2i(1, 1))
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(10, 4))
	var events := battle.apply(AttackBarrelAction.new(sniper.id, HOME + Vector2i(1, 1))).events
	var slain := _of_type(events, MidBossDefeatedEvent)
	assert_eq(slain.size(), 1)
	assert_eq((slain[0] as MidBossDefeatedEvent).slayer_side, P1)
	assert_true(_of_type(events, ExperienceGainedEvent).is_empty(), "樽の爆発では経験値が入らない")


func test_clone_keeps_the_slayers_apart() -> void:
	var battle := _battle()
	var boss := _boss(battle)
	boss.hp = 1
	var raider := battle.add_unit(UnitKind.Id.COMMANDO, P1, HOME + Vector2i(0, 1))
	var copy := battle.clone()
	copy.apply(AttackAction.new(raider.id, boss.id))
	assert_true(copy.is_mid_boss_defeated(0))
	assert_false(battle.is_mid_boss_defeated(0), "複製で倒しても、元は変わらない")
	battle.apply(AttackAction.new(raider.id, boss.id))
	assert_eq(battle.clone().mid_boss_slayers, {0: P1})


# ---- 必殺技のゲージ ----


func test_hitting_the_boss_charges_but_being_hit_does_not() -> void:
	var battle := _battle()
	battle.add_unit(UnitKind.Id.KING, P1, Vector2i(0, 0))
	battle.add_unit(UnitKind.Id.KING, P2, Vector2i(11, 0))
	var boss := _boss(battle)
	var raider := battle.add_unit(UnitKind.Id.COMMANDO, P1, HOME + Vector2i(0, 1))
	battle.armies[P1] = UnitKind.Army.MILITARY
	battle.ult_gauge[P1] = 0
	battle.apply(AttackAction.new(raider.id, boss.id))
	assert_eq(Ults.gauge(battle, P1), raider.power() * Ults.DEALT_GAIN)
	battle.ult_gauge[P1] = 0
	var hp := raider.hp
	var events := battle.apply(EndPhaseAction.new()).events
	events.append_array(battle.apply(EndPhaseAction.new()).events)
	assert_eq(raider.hp, hp - boss.power(), "中ボスが殴り返す")
	# 次のプレイヤー1 のフェーズの始めにたまるぶんだけ。
	assert_eq(Ults.gauge(battle, P1), Ults.PHASE_GAIN)


# ---- CPU ----


func test_cpu_danger_follows_the_territory() -> void:
	var battle := _battle()
	var king := battle.add_unit(UnitKind.Id.KING, P1, Vector2i(11, 4))
	var boss := _boss(battle)
	var cpu := CpuPlayer.new()
	assert_eq(cpu.danger(battle, king.id, HOME + Vector2i(4, 0)), boss.power(), "移動 2 + 射程 2")
	assert_eq(cpu.danger(battle, king.id, HOME + Vector2i(5, 0)), 0)
	# 縄張りの端にいる中ボスは、縄張りの外へは寄ってこない。
	boss.cell = HOME + Vector2i(4, 0)
	assert_eq(cpu.danger(battle, king.id, HOME + Vector2i(6, 0)), boss.power(), "いまの位置から射程 2")
	assert_eq(cpu.danger(battle, king.id, HOME + Vector2i(7, 0)), 0, "縄張りの外へは出ない")


func test_cpu_takes_the_last_hit() -> void:
	var battle := _battle()
	battle.add_unit(UnitKind.Id.KING, P1, Vector2i(0, 4))
	battle.add_unit(UnitKind.Id.KING, P2, Vector2i(11, 0))
	var boss := _boss(battle)
	boss.hp = 8
	battle.add_unit(UnitKind.Id.COMMANDO, P1, HOME + Vector2i(-4, 2))
	var cpu := CpuPlayer.new()
	var first := cpu.next_action(battle)
	battle.apply(first)
	var second := cpu.next_action(battle)
	assert_true(second is AttackAction and (second as AttackAction).target_id == boss.id, "弱った中ボスに止めを刺す")
	battle.apply(second)
	assert_eq(battle.mid_boss_slayers.get(0, -1), P1)


func test_cpu_does_not_walk_a_lone_sniper_into_a_fresh_boss() -> void:
	var battle := _battle()
	battle.add_unit(UnitKind.Id.KING, P1, Vector2i(0, 4))
	battle.add_unit(UnitKind.Id.KING, P2, Vector2i(11, 0))
	var boss := _boss(battle)
	battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 2))
	var cpu := CpuPlayer.new()
	for i in 2:
		var action := cpu.next_action(battle)
		battle.apply(action)
		if action is EndPhaseAction:
			break
	assert_eq(boss.hp, boss.max_hp(), "1 体で中ボスを削りに行かない")
