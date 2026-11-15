extends "res://tests/base_test.gd"
## CPU どうしの対戦を最後まで進める道具（tools/cpu_match.gd）。
## ここでは短い 1 局だけを回す（何局も回す集計は tools/cpu_matches.gd で、手元で回す）。

const CpuMatch := preload("res://tools/cpu_match.gd")
const Maps := preload("res://tests/support/maps.gd")


func _small_battle(battle_seed: int) -> Battle:
	var board := Maps.board([
		"............",
		"............",
		"....F..#....",
		"..#.....*...",
		"...*.....#..",
		"....#..F....",
		"............",
		"............",
	])
	board.hq_cells = [Vector2i(2, 7), Vector2i(9, 0)]
	var battle := Battle.new(board, battle_seed)
	Deployment.deploy(battle, Unit.Side.PLAYER1, CpuDeck.build(UnitKind.Army.MILITARY))
	Deployment.deploy(battle, Unit.Side.PLAYER2, CpuDeck.build(UnitKind.Army.FANTASY))
	return battle


func test_short_game_ends_and_every_action_is_accepted() -> void:
	var outcome := CpuMatch.play(_small_battle(1), 60)
	assert_true(outcome.finished, "決着しなかった（ターン %d）" % outcome.turns)
	assert_eq(outcome.rejected, 0)
	assert_true(outcome.ending in ["king", "hq", "draw"])
	assert_true(outcome.actions > 0)
	assert_eq(outcome.hired, [6, 5] as Array[int])


func test_same_seed_plays_the_same_game() -> void:
	var a := CpuMatch.play(_small_battle(3), 60)
	var b := CpuMatch.play(_small_battle(3), 60)
	assert_eq(a.turns, b.turns)
	assert_eq(a.actions, b.actions)
	assert_eq(a.winner, b.winner)
	assert_eq(a.ending, b.ending)
	assert_eq(a.level_ups, b.level_ups)


func test_a_second_cpu_can_play_player_two() -> void:
	# 別の版の CPU と対戦させる入口。同じ CPU を渡せば、渡さないときと同じ対局になる。
	var alone := CpuMatch.play(_small_battle(3), 60)
	var paired := CpuMatch.play(_small_battle(3), 60, CpuPlayer.new(), CpuPlayer.new())
	assert_eq(paired.turns, alone.turns)
	assert_eq(paired.actions, alone.actions)
	assert_eq(paired.winner, alone.winner)


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
			CpuMatch._count(outcome, event)
		assert_eq(outcome.gains[sorcerer.id], [0, 0, 0, 0, 1], "中ボスが先: %s" % boss_first)
