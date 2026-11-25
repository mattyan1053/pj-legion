extends "res://tests/base_test.gd"
## CPU どうしの対戦を最後まで進める道具（tools/cpu_match.gd）。
## ここでは短い 1 局だけを回す（何局も回す集計は tools/cpu_matches.gd で、手元で回す）。
## その 1 局は、ほかのテストと共有する（tests/support/cpu_game.gd）。
## 同じ 1 局を何度も回して比べるものは時間が掛かるので、長い検査（`test_long_`）に回す。

const CpuMatch := preload("res://tools/cpu_match.gd")
const CpuGame := preload("res://tests/support/cpu_game.gd")
const Maps := preload("res://tests/support/maps.gd")
const RandomSquad := preload("res://game/random_squad.gd")


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


func test_first_hit_and_first_kill_count_only_blows_between_players() -> void:
	# 集計の「最初に当てた側・倒した側」: 中立の駒への攻撃は数えない。最初に当てたのはプレイヤー2、最初に倒したのはプレイヤー1。
	var battle := Maps.battle(["........", "........"])
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, Unit.Side.PLAYER1, Vector2i(1, 1))
	var finisher := battle.add_unit(UnitKind.Id.PALADIN, Unit.Side.PLAYER1, Vector2i(5, 1))
	var minion := battle.add_unit(UnitKind.Id.MINION, Unit.Side.NEUTRAL, Vector2i(2, 1))
	minion.hp = 1
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, Unit.Side.PLAYER2, Vector2i(4, 1))
	var outcome := CpuMatch.Outcome.new()
	outcome.stats = BattleStats.new(battle)
	var steps: Array[Array] = [
		[Unit.Side.PLAYER1, AttackAction.new(paladin.id, minion.id)],
		[Unit.Side.PLAYER2, AttackAction.new(sniper.id, paladin.id)],
		[Unit.Side.PLAYER1, AttackAction.new(finisher.id, sniper.id)],
	]
	for i in steps.size():
		battle.phase = steps[i][0]
		if i == 2:
			sniper.hp = 1
		var result := battle.apply(steps[i][1])
		assert_true(result.accepted, "%d 手目" % i)
		for event in result.events:
			outcome.stats.feed(event)
			CpuMatch._count(outcome, event, battle, steps[i][0])
		if i == 0:
			assert_eq([outcome.first_hit_side, outcome.first_kill_side], [-1, -1], "中立の駒は数えない")
	assert_eq([outcome.first_hit_side, outcome.first_hit_turn], [1, battle.turn])
	assert_eq([outcome.first_kill_side, outcome.first_kill_turn], [0, battle.turn])


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


func test_matches_tool_can_swap_budgets_for_a_measurement() -> void:
	# --budget=M,F（docs/cpu-ai.md の「集計の道具」）。測るためだけに、対戦の決まりの予算を置き換える。
	var tool := load("res://tools/cpu_matches.gd")
	var rules: DeckRules = tool._rules_without("", "22,20")
	assert_eq(rules.budget(UnitKind.Army.MILITARY), 22)
	assert_eq(rules.budget(UnitKind.Army.FANTASY), 20)
	assert_eq(rules.roster(UnitKind.Army.FANTASY), DeckRules.versus().roster(UnitKind.Army.FANTASY))
	assert_true(tool._rules_without("", "22") == null)
	var without: DeckRules = tool._rules_without("sniper", "")
	assert_false(without.roster(UnitKind.Army.MILITARY).has(UnitKind.Id.SNIPER))
	assert_eq(without.budget(UnitKind.Army.MILITARY), DeckRules.versus().budget(UnitKind.Army.MILITARY))
	for squad_seed in 20:
		var deck: Deck = RandomSquad.build(UnitKind.Army.FANTASY, rules, squad_seed)
		assert_true(deck.total_cost() <= 20)
		assert_true(deck.entries.size() > 0)


func test_matches_tool_can_try_a_stronghold_cell() -> void:
	# --stronghold=列,行 か lean:K（docs/cpu-ai.md の「集計の道具」）。測るためだけに、拠点の場所を置き換える。
	var tool := load("res://tools/cpu_matches.gd")
	var setup := MatchSetup.versus_human(
		BoardGenerator.Stage.PLAIN, 4, MatchSetup.default_deck(UnitKind.Army.MILITARY), MatchSetup.default_deck(UnitKind.Army.FANTASY)
	)
	var battle := setup.create_battle()
	assert_true(tool._arm_trial_stronghold(battle, "5,6", 4))
	assert_eq(battle.board.stronghold_cell, Vector2i(5, 6))
	assert_true(battle.wins_by(Unit.Side.PLAYER1, GameWonEvent.Reason.STRONGHOLD_HELD))
	assert_true(battle.wins_by(Unit.Side.PLAYER2, GameWonEvent.Reason.STRONGHOLD_HELD))
	var leaned := setup.create_battle()
	assert_true(tool._arm_trial_stronghold(leaned, "lean:2", 4))
	assert_eq(leaned.board.stronghold_lean, 2)
	var near := Stronghold.distances(leaned.board, leaned.board.hq_cells[0])
	var far := Stronghold.distances(leaned.board, leaned.board.hq_cells[1])
	var i := leaned.board.stronghold_cell.y * leaned.board.size.x + leaned.board.stronghold_cell.x
	assert_eq(near[i] - far[i], 2, "後手の本陣に 2 歩近いマス")
	var blocked := setup.create_battle()
	assert_false(tool._arm_trial_stronghold(blocked, "%d,%d" % [blocked.board.hq_cells[0].x, blocked.board.hq_cells[0].y], 4), "本陣には置けない")
	assert_eq(blocked.board.stronghold_cell, Board.NO_CELL)


func test_matches_tool_can_fix_the_signs() -> void:
	# --signs=鍵,鍵 か none（docs/cpu-ai.md の「集計の道具」）。測るためだけに、縫い目の様子をめくらずに決める。
	var tool := load("res://tools/cpu_matches.gd")
	var setup := MatchSetup.versus_human(
		BoardGenerator.Stage.PLAIN, 4, MatchSetup.default_deck(UnitKind.Army.MILITARY), MatchSetup.default_deck(UnitKind.Army.FANTASY)
	)
	setup.rules.append_array(OptionalRules.DEFAULTS)
	tool._fix_signs(setup, "haze,taut")
	assert_eq(setup.create_battle().signs, [Seam.Sign.HAZE, Seam.Sign.TAUT] as Array[int])
	tool._fix_signs(setup, "none")
	assert_eq(setup.create_battle().signs, [] as Array[int])
	assert_false(setup.rules.has(OptionalRules.SEAM))


func test_matches_tool_sorts_a_squad_by_what_is_in_it() -> void:
	# --squads のときの「部隊の中身ごとの勝率」の鍵。CPU の編成そのものなら、そう分かる。
	var tool := load("res://tools/cpu_matches.gd")
	var deck := CpuDeck.build(UnitKind.Army.MILITARY)
	var keys: Array[String] = tool._squad_keys(deck, UnitKind.Army.MILITARY, UnitKind.Army.FANTASY)
	assert_true(keys.has("MILITARY 対 FANTASY 数 6 体"), str(keys))
	assert_true(keys.has("MILITARY 対 FANTASY 役割 前2 後2 奇1 回1"), str(keys))
	assert_true(keys.has("MILITARY 対 FANTASY CPU の編成と同じ"), str(keys))
	assert_true(keys.has("MILITARY 対 FANTASY 駒 スナイパー 2 体"), str(keys))
	var other: Deck = RandomSquad.build(UnitKind.Army.MILITARY, DeckRules.versus(), 5)
	assert_false(tool._squad_keys(other, UnitKind.Army.MILITARY, UnitKind.Army.FANTASY).has("MILITARY 対 FANTASY CPU の編成と同じ"))


func test_matches_tool_sorts_a_squad_by_its_trait() -> void:
	var tool := load("res://tools/cpu_matches.gd")
	var federation := CpuDeck.build(UnitKind.Army.MILITARY)
	assert_false(str(tool._squad_keys(federation, UnitKind.Army.MILITARY, UnitKind.Army.FANTASY)).contains("軍略"), "軍略が無ければ鍵も無い")
	var keys: Array[String] = tool._squad_keys(federation, UnitKind.Army.MILITARY, UnitKind.Army.FANTASY, Traits.Id.RANKS)
	assert_true(keys.has("MILITARY 対 FANTASY 軍略 隊列"), str(keys))
	assert_true(keys.has("MILITARY 対 FANTASY 軍略 隊列・駒 スナイパー 2 体"), str(keys))


func test_matches_tool_can_override_the_traits() -> void:
	var tool := load("res://tools/cpu_matches.gd")
	var setup := MatchSetup.versus_human(BoardGenerator.Stage.PLAIN, 1, CpuDeck.build(UnitKind.Army.MILITARY), CpuDeck.build(UnitKind.Army.FANTASY))
	tool._override_traits(setup, "supply,oath", 1)
	assert_eq(setup.create_battle().traits, [Traits.Id.SUPPLY, Traits.Id.OATH] as Array[int])
	assert_false(setup.decks[1].oaths.is_empty(), "誓いにしたら、誓いを結ぶ")
	tool._override_traits(setup, "none", 1)
	assert_eq(setup.create_battle().traits, [Traits.NONE, Traits.NONE] as Array[int])


func test_trait_effects_are_counted() -> void:
	var battle := Maps.battle([".........", ".........", ".........", ".........", "........."])
	battle.traits = [Traits.Id.FOCUS, Traits.NONE]
	battle.board.hq_cells = [Vector2i(0, 4), Vector2i(8, 0)]
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER1, Vector2i(0, 4))
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER2, Vector2i(8, 0))
	battle.add_unit(UnitKind.Id.SNIPER, Unit.Side.PLAYER1, Vector2i(2, 2))
	battle.add_unit(UnitKind.Id.SNIPER, Unit.Side.PLAYER1, Vector2i(2, 3))
	battle.add_unit(UnitKind.Id.PALADIN, Unit.Side.PLAYER2, Vector2i(5, 2))
	var outcome := CpuMatch.play(battle, 3)
	assert_true(outcome.traits.get(Traits.Id.FOCUS, 0) >= 1, str(outcome.traits))
	assert_eq(outcome.trait_hits, [outcome.traits[Traits.Id.FOCUS], 0] as Array[int], "効いた回数は、その軍略の陣営に数える")


## 両方の部隊が同じ軍略の局は、効いた回数を陣営ごとに分けて数える（合計を 2 回数えない）。
func test_mirror_trait_hits_are_counted_per_side() -> void:
	var battle := Maps.battle([".........", ".........", ".........", ".........", "........."])
	battle.traits = [Traits.Id.FOCUS, Traits.Id.FOCUS]
	var a := battle.add_unit(UnitKind.Id.SNIPER, Unit.Side.PLAYER1, Vector2i(2, 2))
	var b := battle.add_unit(UnitKind.Id.PALADIN, Unit.Side.PLAYER2, Vector2i(5, 2))
	var outcome := CpuMatch.Outcome.new()
	CpuMatch._count(outcome, TraitTriggeredEvent.new(Traits.Id.FOCUS, a.id, b.id, 2), battle, Unit.Side.PLAYER1)
	CpuMatch._count(outcome, TraitTriggeredEvent.new(Traits.Id.FOCUS, b.id, a.id, 2), battle, Unit.Side.PLAYER2)
	CpuMatch._count(outcome, TraitTriggeredEvent.new(Traits.Id.FOCUS, b.id, a.id, 2), battle, Unit.Side.PLAYER2)
	assert_eq(outcome.trait_hits, [1, 2] as Array[int])
	assert_eq(outcome.traits[Traits.Id.FOCUS], 3)


func test_a_stronghold_win_is_counted_as_its_own_ending() -> void:
	var battle := Maps.battle([".........", ".........", ".........", ".........", "........."])
	battle.board.hq_cells = [Vector2i(0, 4), Vector2i(8, 0)]
	battle.board.stronghold_cell = Vector2i(4, 2)
	for side: Unit.Side in [Unit.Side.PLAYER1, Unit.Side.PLAYER2]:
		battle.win_conditions[side].append(GameWonEvent.Reason.STRONGHOLD_HELD)
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER1, Vector2i(0, 4))
	battle.add_unit(UnitKind.Id.SHIELD_TROOPER, Unit.Side.PLAYER1, Vector2i(4, 2))
	battle.add_unit(UnitKind.Id.KING, Unit.Side.PLAYER2, Vector2i(8, 0))
	battle.stronghold_holds[Unit.Side.PLAYER1] = Stronghold.HOLDS_TO_WIN - 1
	var outcome := CpuMatch.play(battle, 5)
	assert_eq(outcome.ending, "point")
	assert_eq(outcome.winner, Unit.Side.PLAYER1)
