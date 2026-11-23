extends "res://tests/base_test.gd"
## 縫い目の様子（選べる決まり。docs/seam-signs.md）: めくる札、札ごとの効果、切のときは何も変わらないこと、CPU の部隊の選び方。

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


func test_two_signs_are_drawn_from_the_seed_and_match_the_battle() -> void:
	for stage in STAGES:
		for battle_seed in range(1, 4):
			var setup := _setup(stage, battle_seed, [OptionalRules.SEAM])
			var signs := setup.signs()
			assert_eq(signs.size(), Seam.DRAWN)
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
			assert_eq(signs.size(), Seam.DRAWN)
			assert_false(signs.has(S.LOOSE) and signs.has(S.HUSH), "マップ %d 種 %d" % [stage, battle_seed])
			for sign in signs:
				seen[sign] = true
			if stage != BoardGenerator.Stage.TWIN_SPRINGS:
				assert_false(signs.has(S.SHIFT), "ポータルの無い盤に、仮縫いのずれは出ない")
	for sign: int in S.values():
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


func test_dusk_and_mend_raise_raiders_and_healers() -> void:
	var battle := _battle(["......", "......"], [S.DUSK, S.MEND])
	var commando := battle.add_unit(K.COMMANDO, P1, Vector2i(0, 0))
	var medic := battle.add_unit(K.MEDIC, P1, Vector2i(1, 0))
	var trooper := battle.add_unit(K.SHIELD_TROOPER, P1, Vector2i(2, 0))
	assert_eq(commando.move_range(), UnitKind.move_range(K.COMMANDO) + Seam.DUSK_MOVE)
	assert_eq(medic.power(), UnitKind.power(K.MEDIC) + Seam.MEND_HEAL)
	assert_eq(trooper.move_range(), UnitKind.move_range(K.SHIELD_TROOPER))
	assert_eq(trooper.power(), UnitKind.power(K.SHIELD_TROOPER))


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


# --- CPU の部隊の選び方 ---


func test_cpu_picks_the_squad_that_suits_the_signs() -> void:
	var snipers := Deck.new(UnitKind.Army.MILITARY)
	snipers.add(K.SNIPER)
	snipers.add(K.SNIPER)
	var raiders := Deck.new(UnitKind.Army.MILITARY)
	raiders.add(K.COMMANDO)
	raiders.add(K.SHIELD_TROOPER)
	var candidates: Array[Deck] = [snipers, raiders]
	assert_eq(CpuDeck.pick_for_signs(candidates, []), snipers, "札が部隊を選ばなければ、先頭")
	assert_eq(CpuDeck.pick_for_signs(candidates, [S.HAZE]), raiders, "霞の日は、スナイパーの少ない部隊")
	assert_eq(CpuDeck.pick_for_signs(candidates, [S.DUSK]), raiders, "宵闇は、奇襲のいる部隊")
	assert_eq(CpuDeck.pick_for_signs(candidates, [S.BRIM]), snipers, "どの部隊にも同じに効く札は、先頭")
