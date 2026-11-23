extends "res://tests/base_test.gd"
## 縫い目の様子（docs/seam-signs.md）: めくる札の数と札、話が決めた様子、札ごとの効果、切のときは何も変わらないこと。

const Maps := preload("res://tests/support/maps.gd")

const P1 := Unit.Side.PLAYER1
const P2 := Unit.Side.PLAYER2
const K := UnitKind.Id
const S := Seam.Sign
const STAGES: Array[BoardGenerator.Stage] = [
	BoardGenerator.Stage.PLAIN, BoardGenerator.Stage.LABYRINTH, BoardGenerator.Stage.TWIN_SPRINGS,
]


func _setup(stage: BoardGenerator.Stage, battle_seed: int, rules: Array[StringName] = []) -> MatchSetup:
	var setup := MatchSetup.versus_human(
		stage, battle_seed, MatchSetup.default_deck(UnitKind.Army.MILITARY), MatchSetup.default_deck(UnitKind.Army.FANTASY)
	)
	setup.rules = rules
	return setup


## 札 signs の入った、盤 rows の対戦。
func _battle(rows: Array[String], signs: Array[int]) -> Battle:
	var battle := Battle.new(Maps.board(rows))
	Seam.arm(battle, signs)
	return battle


# --- 切のとき ---


func test_off_has_no_signs_and_changes_no_unit() -> void:
	for stage in STAGES:
		var setup := _setup(stage, 3)
		assert_eq(setup.signs(), [] as Array[int])
		var battle := setup.create_battle()
		assert_eq(battle.signs, [] as Array[int])
		for unit in battle.units:
			assert_eq(unit.sign_bonus, {})
			assert_false(unit.hazed)
		assert_eq(battle.board.portal_exits, BoardGenerator.generate(stage, 3).portal_exits, "ポータルの対はそのまま")


# --- めくる ---


func test_signs_are_drawn_from_the_seed_and_match_the_battle() -> void:
	for stage in STAGES:
		for battle_seed in range(1, 8):
			var setup := _setup(stage, battle_seed, [OptionalRules.SEAM])
			var signs := setup.signs()
			assert_eq(signs.size(), Seam.draw_count(battle_seed))
			if signs.size() == 2:
				assert_ne(signs[0], signs[1])
			assert_eq(setup.signs(), signs, "同じ種なら同じ札")
			assert_eq(setup.create_battle().signs, signs, "対戦に入る札は、見せた札と同じ")


## 盤の形は種で変わっても、札の効くかどうか（ポータル・結晶泉・森の有無）は変わらないので、盤は 1 つずつ作り、種だけ変えてめくる。
func test_drawn_signs_never_clash_and_skip_signs_that_do_not_apply() -> void:
	var seen := {}
	for stage in STAGES:
		var board := BoardGenerator.generate(stage, 1)
		for battle_seed in range(1, 301):
			var signs := Seam.draw(board, battle_seed)
			assert_eq(signs.size(), Seam.draw_count(battle_seed))
			assert_false(signs.has(S.LOOSE) and signs.has(S.HUSH), "マップ %d 種 %d" % [stage, battle_seed])
			for sign in signs:
				seen[sign] = true
			if stage != BoardGenerator.Stage.TWIN_SPRINGS:
				assert_false(signs.has(S.SHIFT), "ポータルの無い盤に、仮縫いのずれは出ない")
	for sign: int in S.values():
		if Seam.STORY_ONLY.has(sign):
			assert_false(seen.has(sign), "話だけの札は、対戦モードではめくらない: %s" % Seam.key(sign))
		else:
			assert_true(seen.has(sign), "どの札も、どこかの局で出る: %s" % Seam.key(sign))
	var bare := Maps.board(["....", "...."])
	assert_false(Seam.applies(S.SHIFT, bare))
	assert_false(Seam.applies(S.LOOSE, bare))
	assert_false(Seam.applies(S.HUSH, bare))
	assert_false(Seam.applies(S.THICKET, bare))
	assert_true(Seam.applies(S.HAZE, bare))


func test_drawing_does_not_move_the_battle_random() -> void:
	var off := _setup(BoardGenerator.Stage.PLAIN, 5).create_battle()
	var on := _setup(BoardGenerator.Stage.PLAIN, 5, [OptionalRules.SEAM]).create_battle()
	assert_eq(on.rng.state, off.rng.state)


func test_the_count_follows_the_weights() -> void:
	var counts := [0, 0, 0]
	for battle_seed in range(1, 401):
		counts[Seam.draw_count(battle_seed)] += 1
	# 重み 1 : 2 : 1（DRAW_WEIGHTS）。400 局でおよそ 100 : 200 : 100。
	assert_eq(Seam.DRAW_WEIGHTS.size(), Seam.DRAWN + 1)
	assert_true(counts[0] > 60 and counts[0] < 140 and counts[1] > 150 and counts[2] > 60 and counts[2] < 140, str(counts))


func test_a_scenario_with_signs_always_has_them() -> void:
	# ストーリーの話のファイルが様子を決めた戦い: 決まり（OptionalRules.SEAM）に依らず、いつもその様子。
	var defined := Scenario.versus(BoardGenerator.Stage.PLAIN)
	defined.signs = [S.GALE, S.TAUT] as Array[int]
	for battle_seed in range(1, 6):
		var setup := MatchSetup.humans_on(defined, battle_seed, MatchSetup.default_deck(UnitKind.Army.MILITARY), MatchSetup.default_deck(UnitKind.Army.FANTASY))
		assert_eq(setup.signs(), [S.GALE, S.TAUT] as Array[int])
		assert_eq(setup.create_battle().signs, [S.GALE, S.TAUT] as Array[int])


func test_keys_read_back_to_signs() -> void:
	var wrong: Array[String] = []
	assert_eq(Seam.from_keys(PackedStringArray(["gale", " taut"]), wrong), [S.GALE, S.TAUT] as Array[int])
	assert_eq(wrong, [] as Array[String])
	assert_eq(Seam.from_keys(PackedStringArray(["loose", "hush", "fog", "loose"]), wrong), [S.LOOSE] as Array[int])
	assert_eq(wrong, ["hush", "fog", "loose"] as Array[String], "打ち消し合う札、知らない鍵、重なる札")


func test_keys_name_every_sign() -> void:
	assert_eq(Seam.KEYS.size(), S.values().size())
	for sign: int in S.values():
		assert_eq(Seam.from_key(Seam.key(sign)), sign)


# --- 札ごとの効果 ---


func test_haze_shortens_long_ranges_only() -> void:
	var battle := _battle(["......", "......"], [S.HAZE])
	var sniper := battle.add_unit(K.SNIPER, P1, Vector2i(0, 0))
	var sorcerer := battle.add_unit(K.SORCERER, P2, Vector2i(5, 0))
	assert_eq(sniper.attack_range(), UnitKind.attack_range(K.SNIPER) - Seam.HAZE_CUT)
	assert_eq(sorcerer.attack_range(), UnitKind.attack_range(K.SORCERER), "射程 2 は縮まない")
	sorcerer.site_range = MapObject.BATTERY_RANGE  # 砲台で伸びた射程も縮む
	assert_eq(sorcerer.attack_range(), UnitKind.attack_range(K.SORCERER) + MapObject.BATTERY_RANGE - Seam.HAZE_CUT)


func test_gleam_lengthens_rearguards_and_clashes_with_haze() -> void:
	var battle := _battle(["......", "......"], [S.GLEAM])
	var sniper := battle.add_unit(K.SNIPER, P1, Vector2i(0, 0))
	var sorcerer := battle.add_unit(K.SORCERER, P2, Vector2i(5, 0))
	var trooper := battle.add_unit(K.SHIELD_TROOPER, P1, Vector2i(1, 0))
	assert_eq(sniper.attack_range(), UnitKind.attack_range(K.SNIPER) + Seam.GLEAM_RANGE)
	assert_eq(sorcerer.attack_range(), UnitKind.attack_range(K.SORCERER) + Seam.GLEAM_RANGE)
	assert_eq(trooper.attack_range(), UnitKind.attack_range(K.SHIELD_TROOPER))
	assert_false(Seam.compatible(S.HAZE, S.GLEAM))


func test_gale_lengthens_only_the_cruise() -> void:
	var battle := _battle(["................................"], [S.GALE])
	var trooper := battle.add_unit(K.SHIELD_TROOPER, P1, Vector2i(0, 0))
	var move := UnitKind.move_range(K.SHIELD_TROOPER)
	assert_eq(Movement.budget(trooper, false), move)
	assert_eq(Movement.budget(trooper, true), move * 2 + Seam.GALE_CRUISE)
	assert_true(Movement.reachable_now(battle, trooper, true).has(Vector2i(move * 2 + Seam.GALE_CRUISE, 0)), "巡航の範囲に入る")
	assert_false(Movement.reachable_now(battle, trooper, false).has(Vector2i(move + 1, 0)))
	var calm := _battle(["......"], [])
	assert_eq(Movement.budget(calm.add_unit(K.SHIELD_TROOPER, P1, Vector2i(0, 0)), true), move * 2)


func test_brim_fills_the_gauge_faster() -> void:
	var battle := _battle(["......"], [S.BRIM])
	battle.add_unit(K.SNIPER, P1, Vector2i(0, 0))
	Ults.charge(battle, P1, 100)
	assert_eq(battle.ult_gauge[P1], 100 * Seam.BRIM_PERCENT / 100)


func test_loose_and_hush_change_the_respawn() -> void:
	assert_eq(Seam.respawn_percent(_battle(["."], [])), Neutral.RESPAWN_CHANCE_PERCENT)
	assert_eq(Seam.respawn_percent(_battle(["."], [S.LOOSE])), Seam.LOOSE_RESPAWN_PERCENT)
	assert_eq(Seam.respawn_percent(_battle(["."], [S.HUSH])), 0)
	var battle := _battle(["*...."], [S.HUSH])
	battle.turn = 2
	for i in 20:
		assert_eq(Neutral.spawn(battle).size(), 0, "骨の眠りでは湧き直さない")


func test_thicket_deepens_the_forest_cut() -> void:
	var battle := _battle(["..F"], [S.THICKET])
	var attacker := battle.add_unit(K.SHIELD_TROOPER, P1, Vector2i(1, 0))
	var target := battle.add_unit(K.PALADIN, P2, Vector2i(2, 0))
	assert_eq(Combat.damage(battle, attacker, target), attacker.power() * Seam.THICKET_RATE_PERCENT / 100)


func test_taut_shortens_cooldowns_but_not_below_one() -> void:
	var battle := _battle(["."], [S.TAUT])
	assert_eq(Seam.cooldown_of(battle, 3), 3 - Seam.TAUT_CUT)
	assert_eq(Seam.cooldown_of(battle, 1), 1)
	assert_eq(Seam.cooldown_of(_battle(["."], []), 3), 3)


func test_shift_repairs_the_portals_into_new_pairs() -> void:
	var battle := _battle(["1..2", "....", "1..2"], [S.SHIFT])
	var exits := battle.board.portal_exits
	assert_eq(exits[Vector2i(0, 0)], Vector2i(3, 2))
	assert_eq(exits[Vector2i(3, 2)], Vector2i(0, 0))
	assert_eq(exits[Vector2i(3, 0)], Vector2i(0, 2))
	assert_eq(exits[Vector2i(0, 2)], Vector2i(3, 0))


func test_shift_on_the_twin_springs_keeps_every_portal_paired() -> void:
	for battle_seed in range(1, 60):
		var setup := _setup(BoardGenerator.Stage.TWIN_SPRINGS, battle_seed, [OptionalRules.SEAM])
		if not setup.signs().has(S.SHIFT):
			continue
		var battle := setup.create_battle()
		var plain := BoardGenerator.generate(BoardGenerator.Stage.TWIN_SPRINGS, battle_seed)
		assert_eq(battle.board.portal_exits.size(), plain.portal_exits.size())
		for portal: Vector2i in battle.board.portal_exits:
			assert_eq(battle.board.portal_exits[battle.board.portal_exits[portal]], portal)
			assert_ne(battle.board.portal_exits[portal], plain.portal_exits[portal], "行き先が替わる")
		return
	_fail("仮縫いのずれの局が見つからない", "")


# --- CPU ---


## 天裂の名残りと砲台が重なっても、CPU の「動いた先の射程」は、その先の実際の射程と同じ（Codex の指摘。#400）。
func test_cpu_reach_on_and_off_a_battery_under_haze() -> void:
	var board := Maps.board(["..........", ".........."])
	board.add_battery(Vector2i(2, 0))
	var battle := Battle.new(board)
	Seam.arm(battle, [S.HAZE] as Array[int])
	var sorcerer := battle.add_unit(K.SORCERER, P1, Vector2i(2, 0))
	battle.refresh_sites()
	assert_eq(sorcerer.attack_range(), UnitKind.attack_range(K.SORCERER) + MapObject.BATTERY_RANGE - Seam.HAZE_CUT)
	var cpu := CpuPlayer.new()
	cpu._battle = battle
	cpu._board = board
	cpu._moved_reach = CpuPlayer._unhazed(sorcerer, func() -> int: return sorcerer.attack_range())
	assert_eq(cpu._reach_from(sorcerer, Vector2i(5, 0)), UnitKind.attack_range(K.SORCERER), "砲台を降りれば、射程 2 のまま")
	assert_eq(cpu._reach_from(sorcerer, Vector2i(2, 0)), sorcerer.attack_range())
