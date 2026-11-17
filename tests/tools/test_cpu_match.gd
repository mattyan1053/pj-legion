extends "res://tests/base_test.gd"
## CPU どうしの対戦を最後まで進める道具（tools/cpu_match.gd）。
## ここでは短い 1 局だけを回す（何局も回す集計は tools/cpu_matches.gd で、手元で回す）。
## その 1 局は、ほかのテストと共有する（tests/support/cpu_game.gd）。
## 同じ 1 局を何度も回して比べるものは時間が掛かるので、長い検査（`test_long_`）に回す。

const CpuMatch := preload("res://tools/cpu_match.gd")
const CpuGame := preload("res://tests/support/cpu_game.gd")
const Maps := preload("res://tests/support/maps.gd")


## 長い検査の 2 つのテストが比べる元の 1 局（種 3。1 回だけ回して控える）。
static var _seed_three: CpuMatch.Outcome


func _small_battle(battle_seed: int) -> Battle:
	return CpuGame.small_battle(battle_seed)


func _seed_three_game() -> CpuMatch.Outcome:
	if _seed_three == null:
		_seed_three = CpuMatch.play(_small_battle(3), 60)
	return _seed_three


func test_short_game_ends_and_every_action_is_accepted() -> void:
	var outcome := CpuGame.outcome()
	assert_true(outcome.finished, "決着しなかった（ターン %d）" % outcome.turns)
	assert_eq(outcome.rejected, 0)
	assert_true(outcome.ending in ["king", "hq", "draw"])
	assert_true(outcome.actions > 0)
	assert_eq(outcome.hired, [6, 5] as Array[int])


func test_replaying_the_shared_game_ends_the_same_way() -> void:
	# 共有の 1 局（cpu_game.gd）を当て直すと、道具で回したときと同じところで同じ決着になる。
	var outcome := CpuGame.outcome()
	assert_eq(CpuGame.actions().size(), outcome.actions)
	var battle := CpuGame.start()
	CpuGame.replay(battle)
	assert_true(battle.is_over())
	assert_eq(battle.turn, outcome.turns)
	assert_eq(battle.winner, outcome.winner)


func test_long_same_seed_plays_the_same_game() -> void:
	var a := _seed_three_game()
	var b := CpuMatch.play(_small_battle(3), 60)
	assert_eq(a.turns, b.turns)
	assert_eq(a.actions, b.actions)
	assert_eq(a.winner, b.winner)
	assert_eq(a.ending, b.ending)
	assert_eq(a.level_ups, b.level_ups)


func test_long_a_second_cpu_can_play_player_two() -> void:
	# 別の版の CPU と対戦させる入口。同じ CPU を渡せば、渡さないときと同じ対局になる。
	var alone := _seed_three_game()
	var paired := CpuMatch.play(_small_battle(3), 60, CpuPlayer.new(), CpuPlayer.new())
	assert_eq(paired.turns, alone.turns)
	assert_eq(paired.actions, alone.actions)
	assert_eq(paired.winner, alone.winner)


func test_a_rival_can_be_read_from_a_git_revision() -> void:
	# --rival=HEAD のように、git のリビジョンを渡す入口（docs/cpu-ai.md の「別の版と比べる」）。
	# 対局は、共有の 1 局（cpu_game.gd）のプレイヤー2 が、同じ入口でファイルから読んだ版で回している。
	var rival := CpuMatch.load_rival("HEAD")
	assert_true(rival != null, "HEAD の rules/cpu_player.gd を読めない")
	assert_false(rival is CpuPlayer)
	assert_true(rival.has_method(&"next_action"))
	assert_true(CpuMatch.load_rival("no-such-revision") == null)


func test_skill_kill_of_a_mid_boss_and_a_unit_counts_the_bigger_reward() -> void:
	# ファイアボール 1 発で中ボスとプレイヤーの駒が倒れたら、入る経験値（いちばん多い 1 体ぶん）は中ボスの撃破。
	for boss_first: bool in [true, false]:
		var battle := Maps.battle(["........", "........", "........"])
		var sorcerer := battle.add_unit(UnitKind.Id.SORCERER, Unit.Side.PLAYER1, Vector2i(1, 1))
		var boss_cell := Vector2i(4, 1) if boss_first else Vector2i(5, 1)
		var victim_cell := Vector2i(5, 1) if boss_first else Vector2i(4, 1)
		var boss := battle.add_unit(UnitKind.Id.ELITE_MINION, Unit.Side.NEUTRAL, boss_cell)
		battle.board.mid_boss_cells = [boss_cell]
		boss.home_cell = boss_cell
		boss.hp = 1
		var victim := battle.add_unit(UnitKind.Id.SNIPER, Unit.Side.PLAYER2, victim_cell)
		victim.hp = 1
		var outcome := CpuMatch.Outcome.new()
		var result := battle.apply(UseSkillAction.new(sorcerer.id, Vector2i(4, 1)))
		assert_true(result.accepted)
		for event in result.events:
			CpuMatch._count(outcome, event, battle, Unit.Side.PLAYER1)
		assert_eq(outcome.gains[sorcerer.id], [0, 0, 0, 0, 1], "中ボスが先: %s" % boss_first)


func test_taking_back_a_relic_restores_the_side() -> void:
	# 報酬なしの比べ（play の no_reward）: 受け取った聖遺物を、効果とゲージごと取り消す。
	for relic: Relics.Id in [Relics.Id.WISDOM, Relics.Id.COURAGE]:
		var battle := Maps.battle(["........", "........"])
		var unit := battle.add_unit(UnitKind.Id.PALADIN, Unit.Side.PLAYER1, Vector2i(1, 1))
		unit.hp -= 3
		var before := [unit.hp, unit.max_hp(), unit.power(), Ults.gauge(battle, Unit.Side.PLAYER1)]
		var events := Relics.grant(battle, Unit.Side.PLAYER1, relic, Relics.boss_of(relic))
		CpuMatch._take_back(battle, events[0] as RelicGainedEvent)
		assert_eq([unit.hp, unit.max_hp(), unit.power(), Ults.gauge(battle, Unit.Side.PLAYER1)], before, "聖遺物 %d" % relic)
		assert_false(Relics.has(battle, Unit.Side.PLAYER1, relic))


func test_army_hp_at_a_mid_boss_kill_leaves_out_the_new_relic() -> void:
	# 英知の聖遺物は、倒した行動の中で掛かる。倒れた時点の戦力は、掛かる前の HP で数える。
	var battle := Maps.battle(["........", "........"])
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, Unit.Side.PLAYER1, Vector2i(1, 1))
	battle.add_unit(UnitKind.Id.SNIPER, Unit.Side.PLAYER2, Vector2i(7, 0))
	var boss := battle.add_unit(UnitKind.Id.ELITE_MINION, Unit.Side.NEUTRAL, Vector2i(2, 1))
	battle.board.mid_boss_cells = [Vector2i(2, 1)]
	boss.home_cell = Vector2i(2, 1)
	boss.hp = 1
	var before := paladin.hp
	var outcome := CpuMatch.Outcome.new()
	outcome.stats = BattleStats.new(battle)
	var result := battle.apply(AttackAction.new(paladin.id, boss.id))
	assert_true(result.accepted)
	for event in result.events:
		outcome.stats.feed(event)
		CpuMatch._count(outcome, event, battle, Unit.Side.PLAYER1)
	assert_eq(paladin.hp, before + Relics.WISDOM_MAX_HP)
	assert_eq(outcome.boss_falls.size(), 1)
	assert_eq(outcome.boss_falls[0].slayer_hp, before)
	assert_eq(outcome.boss_falls[0].first_slayer_hp, before)


func test_a_finish_on_a_boss_the_rival_wore_down_counts_as_finish_only() -> void:
	# 相手（プレイヤー2）が 40 削った中ボスを、プレイヤー1 が止めの一撃だけで倒す（集計の「削った量の分け前」）。
	var battle := Maps.battle(["........", "........"])
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, Unit.Side.PLAYER1, Vector2i(1, 1))
	battle.add_unit(UnitKind.Id.SNIPER, Unit.Side.PLAYER2, Vector2i(7, 0))
	var boss := battle.add_unit(UnitKind.Id.ELITE_MINION, Unit.Side.NEUTRAL, Vector2i(2, 1))
	battle.board.mid_boss_cells = [Vector2i(2, 1)]
	boss.home_cell = Vector2i(2, 1)
	boss.hp = 3
	var outcome := CpuMatch.Outcome.new()
	outcome.stats = BattleStats.new(battle)
	outcome.boss_damage[boss.id] = [0, 40]
	outcome.boss_hp[boss.id] = 3
	var result := battle.apply(AttackAction.new(paladin.id, boss.id))
	assert_true(result.accepted)
	for event in result.events:
		outcome.stats.feed(event)
		CpuMatch._count(outcome, event, battle, Unit.Side.PLAYER1)
	var fall := outcome.boss_falls[0]
	assert_eq([fall.slayer_damage, fall.rival_damage, fall.finish_damage], [3, 40, 3])
	assert_true(fall.is_finish_only())
	assert_true(fall.is_low_share())
	# 自分が削ってから止めを刺したなら、止めだけではない。
	fall.slayer_damage = 20
	assert_false(fall.is_finish_only())
	assert_false(fall.is_low_share())


func test_the_finish_only_rival_loads() -> void:
	# 測るための版（tools/rivals/finish_only.gd）。--rival と同じ入口で読める。
	var rival := CpuMatch.load_rival("res://tools/rivals/finish_only.gd")
	assert_true(rival != null, "finish_only.gd を読めない")
	assert_true(rival is CpuPlayer)
