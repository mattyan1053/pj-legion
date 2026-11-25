extends "res://tests/base_test.gd"
## CPU の思考（docs/cpu-ai.md）。

const CpuGame := preload("res://tests/support/cpu_game.gd")
const Maps := preload("res://tests/support/maps.gd")

const P1 := Unit.Side.PLAYER1
const P2 := Unit.Side.PLAYER2

## 壁の無い 16 x 5 の盤面。本陣は左下と右上の隅。
const OPEN_ROWS: Array[String] = [
	"................",
	"................",
	"................",
	"................",
	"................",
]
const HQ1 := Vector2i(0, 4)
const HQ2 := Vector2i(15, 0)


func _battle(rows: Array[String] = OPEN_ROWS, hqs: Array[Vector2i] = [HQ1, HQ2]) -> Battle:
	var battle := Maps.battle(rows)
	battle.board.hq_cells = hqs
	return battle


## 両方の将を本陣に置いた対戦。
func _battle_with_kings() -> Battle:
	var battle := _battle()
	battle.add_unit(UnitKind.Id.KING, P1, HQ1)
	battle.add_unit(UnitKind.Id.KING, P2, HQ2)
	return battle


## いまのフェーズを、CPU に最後まで進めさせる（フェーズが替わるか、決着するまで）。受け付けた行動を返す。
func _play_phase(battle: Battle) -> Array[BattleAction]:
	var cpu := CpuPlayer.new()
	var actions: Array[BattleAction] = []
	var phase := battle.phase
	var turn := battle.turn
	while not battle.is_over() and battle.phase == phase and battle.turn == turn:
		var action := cpu.next_action(battle)
		assert_true(action != null and battle.apply(action).accepted, "CPU の行動が断られた")
		actions.append(action)
		if actions.size() > 200:
			assert_true(false, "フェーズが終わらない")
			break
	return actions


func test_returns_null_after_the_game_is_over() -> void:
	var battle := _battle_with_kings()
	battle.winner = P1
	assert_eq(CpuPlayer.new().next_action(battle), null)


func test_ends_the_phase_when_every_unit_has_acted() -> void:
	var battle := _battle_with_kings()
	var actions := _play_phase(battle)
	assert_true(actions[-1] is EndPhaseAction)
	assert_eq(battle.phase, P2)


func test_defeats_the_enemy_king_when_it_can() -> void:
	var battle := _battle()
	battle.add_unit(UnitKind.Id.KING, P1, HQ1)
	var king := battle.add_unit(UnitKind.Id.KING, P2, Vector2i(9, 2))
	king.hp = 12
	battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(4, 2))
	# ほかにも倒せる相手がいる（将より近く、HP が少ない）。それでも将を取る。
	battle.add_unit(UnitKind.Id.SORCERER, P2, Vector2i(6, 2)).hp = 1
	_play_phase(battle)
	assert_eq(battle.winner, P1)


func test_defeats_an_enemy_it_can_finish() -> void:
	var battle := _battle_with_kings()
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(3, 2))
	var weak := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(7, 1))
	weak.hp = 12
	var healthy := battle.add_unit(UnitKind.Id.SORCERER, P2, Vector2i(7, 3))
	_play_phase(battle)
	assert_eq(battle.unit_by_id(weak.id), null, "倒せる相手を倒さなかった")
	assert_eq(healthy.hp, healthy.max_hp())
	assert_true(commando.acted or battle.phase == P2)


func test_attacks_without_moving_when_already_in_range() -> void:
	var battle := _battle_with_kings()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(3, 2))
	var enemy := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(6, 2))
	_play_phase(battle)
	assert_eq(enemy.hp, enemy.max_hp() - sniper.power())


func test_king_leaves_cells_where_it_could_be_defeated() -> void:
	var battle := _battle()
	var king := battle.add_unit(UnitKind.Id.KING, P1, HQ1)
	king.hp = 10
	battle.add_unit(UnitKind.Id.KING, P2, HQ2)
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P2, Vector2i(5, 4))
	_play_phase(battle)
	assert_ne(king.cell, HQ1, "倒されうるマスに残った")
	var reach := commando.move_range() + commando.attack_range()
	assert_true(Combat.distance(king.cell, commando.cell) > reach, "逃げた先も攻撃が届く")
	# 相手の番を進めても、将は倒れない。
	_play_phase(battle)
	assert_false(battle.is_over())


func test_king_stays_on_its_hq_when_safe() -> void:
	var battle := _battle_with_kings()
	battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(14, 1))
	battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(1, 3)).acted = true
	var actions := _play_phase(battle)
	assert_eq(battle.unit_at(HQ1).kind, UnitKind.Id.KING)
	assert_true(actions[0] is WaitAction)


func test_king_goes_out_when_no_fighter_is_left() -> void:
	# 戦える駒がいなければ、本陣で待っていても勝てない。将が自分で敵へ向かう。
	var battle := _battle_with_kings()
	battle.add_unit(UnitKind.Id.MEDIC, P1, Vector2i(1, 3))
	_play_phase(battle)
	assert_true(Combat.distance(battle.units[0].cell, HQ2) < Combat.distance(HQ1, HQ2))


func test_king_stays_on_its_hq_under_a_threat_it_survives() -> void:
	# 本陣を空けると占拠される。倒されない間は、将は本陣に残って殴り返す。
	var battle := _battle_with_kings()
	battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(8, 0)).acted = true
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P2, Vector2i(1, 4))
	_play_phase(battle)
	assert_eq(battle.unit_at(HQ1).kind, UnitKind.Id.KING)
	assert_eq(commando.hp, commando.max_hp() - UnitKind.power(UnitKind.Id.KING))


## 相手が魔物の群れ（軍なし）なら、受けるダメージが少し減るくらいでは、将は本陣を降りない（降りると、寄ってくる群れに乗られる）。
func test_king_keeps_its_hq_from_a_horde_while_it_survives() -> void:
	var battle := _battle()
	battle.add_unit(UnitKind.Id.KING, P1, HQ1)
	battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(8, 0)).acted = true
	battle.add_unit(UnitKind.Id.SKELETON_BRUTE, P2, Vector2i(3, 4))  # 本陣に届く。1 つ上のマスには届かない
	battle.add_unit(UnitKind.Id.SKELETON_ARCHER, P2, Vector2i(6, 4))  # 同じ
	assert_eq(battle.armies[P2], UnitKind.Army.NONE)
	_play_phase(battle)
	assert_eq(battle.unit_at(HQ1).kind, UnitKind.Id.KING, "倒されないのに、群れの前で本陣を降りた")


func test_attacks_the_enemy_standing_on_own_hq_first() -> void:
	var battle := _battle()
	battle.add_unit(UnitKind.Id.KING, P1, Vector2i(0, 0))
	battle.add_unit(UnitKind.Id.KING, P2, HQ2)
	var occupier := battle.add_unit(UnitKind.Id.PALADIN, P2, HQ1)
	# もっと近くに、HP の少ない敵もいる。それでも、本陣に乗っている敵を先に叩く。
	var other := battle.add_unit(UnitKind.Id.SORCERER, P2, Vector2i(6, 2))
	other.hp = 10
	other.skill_cooldown = 3  # ファイアボールが届くと、本陣のそばは倒されうるマスになる（その場面は、ここでは見ない）
	battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(4, 2))
	_play_phase(battle)
	assert_true(occupier.hp < occupier.max_hp(), "本陣の占拠を放置した")
	assert_eq(other.hp, 10)


func test_raider_takes_the_empty_enemy_hq_and_holds_it() -> void:
	var battle := _battle()
	battle.add_unit(UnitKind.Id.KING, P1, HQ1)
	battle.add_unit(UnitKind.Id.KING, P2, Vector2i(15, 4))
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(10, 0))
	_play_phase(battle)
	assert_eq(commando.cell, HQ2)
	assert_eq(battle.capture_turns[P1], 1)
	battle.apply(EndPhaseAction.new())
	_play_phase(battle)
	assert_eq(commando.cell, HQ2, "占拠の途中で本陣を離れた")
	assert_eq(battle.capture_turns[P1], 2)


## 倒されうる本陣に乗る手より、そばのやわらかい駒を倒す手を選ぶ（倒されうる本陣にも乗ること自体は、決めた挙動。docs/cpu-ai.md）。
func test_raider_takes_a_kill_over_an_enemy_hq_where_it_would_be_defeated() -> void:
	var battle := _battle()
	battle.add_unit(UnitKind.Id.KING, P1, HQ1)
	battle.add_unit(UnitKind.Id.KING, P2, Vector2i(15, 4))
	# 攻撃 9 のスナイパー（将の 8 と合わせて、コマンドーの HP 16 を超える）。HP は、コマンドーの一撃で倒れる 12。
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(13, 4))
	sniper.add_growth(Unit.Stat.POWER, 2)
	sniper.hp = 12
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(10, 0))
	var cpu := CpuPlayer.new()
	assert_true(cpu.danger(battle, commando.id, HQ2) >= commando.hp)
	_play_phase(battle)
	assert_ne(commando.cell, HQ2, "倒せる駒を倒さずに、倒されうる本陣に乗った")
	assert_false(battle.units.has(sniper), "そばのスナイパーを倒す")


func test_raider_does_not_run_ahead_of_its_army() -> void:
	var battle := _battle_with_kings()
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(1, 2))
	var trooper := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(1, 3))
	battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(14, 2))
	_play_phase(battle)
	# 巡航なら 12 マス進めるが、前衛から離れすぎない。
	assert_true(commando.cell.x > 1, "前へ出なかった")
	assert_true(Combat.distance(commando.cell, trooper.cell) <= CpuPlayer.SUPPORT_DISTANCE, "味方から離れすぎた")


func test_raider_heads_for_the_soft_units_first() -> void:
	var battle := _battle_with_kings()
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(1, 2))
	battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(1, 3))
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(11, 0))
	var priest := battle.add_unit(UnitKind.Id.PRIEST, P2, Vector2i(13, 4))
	_play_phase(battle)
	# 前衛のほうが近いが、回復役のいる側へ寄る。
	assert_true(Combat.distance(commando.cell, priest.cell) < Combat.distance(Vector2i(1, 2), priest.cell))
	assert_eq(commando.cell.y, 4, "やわらかい駒のいる側へ寄らなかった（%s）" % commando.cell)
	assert_true(paladin.hp == paladin.max_hp())


func test_raider_strikes_a_unit_it_can_defeat_even_far_from_its_army() -> void:
	var battle := _battle_with_kings()
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(1, 2))
	battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(0, 2)).acted = true
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(8, 2))
	sniper.hp = commando.power()  # 無傷のスナイパー（HP 13）は、レベル 1 の奇襲の一撃（12）では倒れない
	_play_phase(battle)
	assert_eq(battle.unit_by_id(sniper.id), null, "倒せる後衛を倒さなかった")
	assert_true(commando.acted)


func test_fighters_act_before_raiders() -> void:
	# 奇襲は、前衛と後衛が動いたあとに動く（敵が減ったあとの危険を見て、踏み込む先を選べる）。
	var battle := _battle_with_kings()
	battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(1, 1))
	battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(1, 2))
	battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(1, 3))
	battle.add_unit(UnitKind.Id.MEDIC, P1, Vector2i(1, 4))
	var order: Array[UnitKind.Id] = []
	for action in _play_phase(battle):
		var unit := battle.unit_by_id(action.get("unit_id")) if action.get("unit_id") != null else null
		if unit != null and not order.has(unit.kind):
			order.append(unit.kind)
	assert_eq(order, [
		UnitKind.Id.SNIPER, UnitKind.Id.SHIELD_TROOPER, UnitKind.Id.COMMANDO, UnitKind.Id.MEDIC, UnitKind.Id.KING,
	] as Array[UnitKind.Id])


func test_advances_toward_the_enemy_when_nothing_is_in_reach() -> void:
	var battle := _battle_with_kings()
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(1, 2))
	var enemy := battle.add_unit(UnitKind.Id.SORCERER, P2, Vector2i(14, 2))
	var before := Combat.distance(paladin.cell, enemy.cell)
	_play_phase(battle)
	# 通常の移動では届かないので、巡航（移動力 2 倍）で近づく。
	assert_eq(before - Combat.distance(paladin.cell, enemy.cell), paladin.move_range() * 2)


func test_healer_heals_the_wounded_ally() -> void:
	var battle := _battle_with_kings()
	var medic := battle.add_unit(UnitKind.Id.MEDIC, P1, Vector2i(2, 2))
	var wounded := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(5, 2))
	wounded.hp = 10
	wounded.acted = true
	# 隣にも少しだけ減っている味方がいる。動かずに届くが、そちらは選ばない。
	var scratched := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(2, 3))
	scratched.hp -= 2
	scratched.acted = true
	_play_phase(battle)
	assert_eq(wounded.hp, 10 + medic.power(), "いちばん減っている味方を回復しなかった")


func test_does_not_wait_in_front_of_a_blocked_portal() -> void:
	# ポータルの出口に駒がいる間は通れない。通れるつもりで入口の前に居座らず、歩いて向かう。
	var battle := _battle([
		".1...#.......1..",
		".....#..........",
		".....#..........",
		".....#..........",
		"................",
	], [Vector2i(0, 2), Vector2i(15, 4)])
	battle.add_unit(UnitKind.Id.KING, P1, Vector2i(0, 2))
	battle.add_unit(UnitKind.Id.KING, P2, Vector2i(13, 0))
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(2, 0))
	_play_phase(battle)
	assert_true(paladin.cell.y > 0, "ふさがったポータルの前から動かなかった")


func test_reaches_a_target_through_a_portal() -> void:
	# ポータルを通れば届く相手は、元の距離が「移動力 + 射程」より遠くても見落とさない。
	var battle := _battle([
		"................",
		"................",
		"..1..........1..",
		"................",
		"................",
	])
	battle.add_unit(UnitKind.Id.KING, P1, HQ1)
	battle.add_unit(UnitKind.Id.KING, P2, Vector2i(14, 2)).hp = 5
	battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(1, 2))
	_play_phase(battle)
	assert_eq(battle.winner, P1)


func test_healer_strikes_only_when_no_friend_needs_healing() -> void:
	var battle := _battle_with_kings()
	var priest := battle.add_unit(UnitKind.Id.PRIEST, P1, Vector2i(3, 2))
	var enemy := battle.add_unit(UnitKind.Id.SORCERER, P2, Vector2i(5, 2))
	for action in _play_phase(battle):
		if action is AttackAction:
			assert_eq((action as AttackAction).unit_id, priest.id)
	assert_eq(enemy.hp, enemy.max_hp() - UnitKind.healer_strike(UnitKind.Id.PRIEST), "治す相手がいなければ撃つ")


func test_healer_heals_rather_than_strikes() -> void:
	var battle := _battle_with_kings()
	battle.add_unit(UnitKind.Id.PRIEST, P1, Vector2i(3, 2))
	var enemy := battle.add_unit(UnitKind.Id.SORCERER, P2, Vector2i(5, 2))
	var wounded := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(3, 3))
	wounded.acted = true
	wounded.hp = 20
	for action in _play_phase(battle):
		assert_false(action is AttackAction, "治せる味方がいるのに撃った")
	assert_eq(enemy.hp, enemy.max_hp())
	assert_true(wounded.hp > 20, "治していない")


func test_does_not_blow_up_a_barrel_next_to_own_king() -> void:
	var battle := _battle([
		"................",
		"................",
		"................",
		".B..............",
		"................",
	])
	battle.add_unit(UnitKind.Id.KING, P1, HQ1).hp = 10
	battle.add_unit(UnitKind.Id.KING, P2, HQ2)
	battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(4, 3))
	_play_phase(battle)
	assert_false(battle.is_over())
	assert_eq(battle.board.barrel_cells.size(), 1)


func test_blows_up_a_barrel_next_to_the_enemy_king() -> void:
	var battle := _battle([
		"................",
		"................",
		"..........B.....",
		"................",
		"................",
	])
	battle.add_unit(UnitKind.Id.KING, P1, HQ1)
	battle.add_unit(UnitKind.Id.KING, P2, Vector2i(11, 2)).hp = 15
	battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(4, 2))
	_play_phase(battle)
	assert_eq(battle.winner, P1)


func test_chooses_an_evolution() -> void:
	var battle := _battle_with_kings()
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P1, Vector2i(5, 2))
	paladin.level = Growth.MAX_LEVEL - 1
	paladin.experience = Growth.EXPERIENCE_PER_LEVEL - Growth.HIT_EXPERIENCE
	battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P2, Vector2i(6, 2))
	_play_phase(battle)
	assert_ne(paladin.evolution, Evolution.Id.NONE, "進化先を選ばなかった")
	assert_eq(battle.phase, P2)


func test_next_action_does_not_change_the_battle() -> void:
	var battle := CpuMatchSetup.create()
	var cpu := CpuPlayer.new()
	for i in 12:
		var before := _snapshot(battle)
		var action := cpu.next_action(battle)
		assert_eq(_snapshot(battle), before, "%d 手目" % i)
		battle.apply(action)


func test_same_battle_gets_the_same_action() -> void:
	# 使い回したインスタンスと、作りたてのインスタンスで、同じ行動になる（覚えているものが判断を変えない）。
	# 使い回したほうは、ほかのテストと共有する CPU どうしの 1 局（tests/support/cpu_game.gd。1 つの CpuPlayer が両方の陣営を考えた）。
	var battle := CpuGame.start()
	var played := CpuGame.actions()
	assert_true(played.size() >= 30, "共有の 1 局が短すぎる")
	for i in mini(30, played.size()):
		var fresh := CpuPlayer.new().next_action(battle.clone())
		assert_eq(_text(fresh), _text(played[i]), "%d 手目" % i)
		battle.apply(played[i])


func _snapshot(battle: Battle) -> String:
	var parts: Array[String] = ["%d %d %d %d %d" % [
		battle.turn, battle.phase, battle.acting_unit_id, battle.rng.state, battle.board.barrel_cells.size(),
	]]
	for unit in battle.units:
		parts.append("%d %s %d %s %s %d %d" % [
			unit.id, unit.cell, unit.hp, unit.acted, unit.has_moved, unit.level, unit.experience,
		])
	return "/".join(parts)


func _text(action: BattleAction) -> String:
	if action == null:
		return "null"
	var script: Script = action.get_script()
	var text := script.resource_path.get_file()
	for property in script.get_script_property_list():
		if property["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			text += " %s" % action.get(property["name"])
	return text


## 小さな盤面に、両方の軍（CPU の編成）を置いた対戦。
class CpuMatchSetup:
	static func create() -> Battle:
		var battle := Maps.battle([
			"..........",
			"..........",
			"....F.....",
			"...#..#...",
			".....F....",
			"..........",
			"..........",
		])
		battle.board.hq_cells = [Vector2i(2, 6), Vector2i(7, 0)]
		Deployment.deploy(battle, Unit.Side.PLAYER1, CpuDeck.build(UnitKind.Army.MILITARY))
		Deployment.deploy(battle, Unit.Side.PLAYER2, CpuDeck.build(UnitKind.Army.FANTASY))
		return battle


# ---- 勝ちの条件（rules/cpu/win_conditions_cpu.gd） ----


func test_raider_does_not_go_for_the_enemy_hq_when_capture_cannot_win() -> void:
	var battle := _battle()
	battle.add_unit(UnitKind.Id.KING, P1, HQ1)
	battle.add_unit(UnitKind.Id.KING, P2, Vector2i(15, 4))
	battle.win_conditions[P1].erase(GameWonEvent.Reason.HQ_CAPTURED)
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(10, 0))
	_play_phase(battle)
	assert_true(commando.cell != HQ2, "占拠で勝てないのに、敵の本陣へ乗った")


## 占拠でしか勝てない話で、相手の駒が残っていない（倒しても終わらなかった）とき、戦う駒は自分の本陣へ戻らず、敵の本陣へ向かう。
func test_heads_for_the_enemy_hq_when_no_enemy_is_left_and_only_capture_wins() -> void:
	var battle := _battle()
	battle.add_unit(UnitKind.Id.KING, P1, HQ1)
	battle.win_conditions[P1] = [GameWonEvent.Reason.HQ_CAPTURED] as Array[GameWonEvent.Reason]
	var trooper := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(4, 3))
	var before := Combat.distance(trooper.cell, HQ2)
	_play_phase(battle)
	assert_false(battle.is_over())
	assert_true(Combat.distance(trooper.cell, HQ2) < before, "敵のいない盤で、敵の本陣へ向かわなかった")


## 同じとき、戦える駒の残っていない軍の将も、敵の本陣へ向かう。
func test_lone_king_heads_for_the_enemy_hq_when_no_enemy_is_left() -> void:
	var battle := _battle()
	var king := battle.add_unit(UnitKind.Id.KING, P1, HQ1)
	battle.win_conditions[P1] = [GameWonEvent.Reason.HQ_CAPTURED] as Array[GameWonEvent.Reason]
	_play_phase(battle)
	assert_true(Combat.distance(king.cell, HQ2) < Combat.distance(HQ1, HQ2), "敵のいない盤で、将が本陣に残った")


func test_holding_side_waits_near_its_hq_instead_of_chasing_far_enemies() -> void:
	var battle := _battle_with_kings()
	battle.win_conditions[P1].append(GameWonEvent.Reason.TURNS_HELD)
	battle.hold_turns = 8
	var trooper := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(2, 3))
	battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(14, 1))
	_play_phase(battle)
	assert_true(Combat.distance(trooper.cell, HQ1) <= CpuWinPlan.HOLD_REACH, "守る側が、遠くの敵へ出ていった")


func test_holding_side_still_strikes_enemies_near_its_hq() -> void:
	var battle := _battle_with_kings()
	battle.win_conditions[P1].append(GameWonEvent.Reason.TURNS_HELD)
	battle.hold_turns = 8
	battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(2, 2))
	var intruder := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(5, 2))
	_play_phase(battle)
	assert_true(intruder.hp < intruder.max_hp(), "本陣の近くの敵を放っておいた")


func test_holding_side_chases_the_enemy_inside_the_radius_not_a_closer_one_outside() -> void:
	var battle := _battle_with_kings()
	battle.win_conditions[P1].append(GameWonEvent.Reason.TURNS_HELD)
	battle.hold_turns = 8
	var trooper := battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(11, 1))
	battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(11, 4))  # 本陣から 11 マス。近いが、追わない
	var inside := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(7, 1))  # 本陣から 10 マス
	var cpu := CpuPlayer.new()
	cpu._begin(battle)
	assert_eq(cpu._enemy_to_hold_off(trooper), inside)


func test_win_plan_reads_the_conditions() -> void:
	var battle := _battle_with_kings()
	assert_true(CpuWinPlan.raids_hq(battle, P1))
	assert_false(CpuWinPlan.holds(battle, P2))
	assert_false(CpuWinPlan.rushes(battle, P1))
	battle.win_conditions[P2].append(GameWonEvent.Reason.TURNS_HELD)
	battle.hold_turns = 6
	assert_true(CpuWinPlan.holds(battle, P2))
	assert_false(CpuWinPlan.rushes(battle, P1), "まだ残りのターンが多い")
	battle.turn = 6 - CpuWinPlan.RUSH_TURNS + 1
	assert_true(CpuWinPlan.rushes(battle, P1))
	assert_false(CpuWinPlan.rushes(battle, P2), "守る側は急がない")
	battle.turn = 5  # 残り 2 ターン。占拠の 3 回に届かない
	assert_false(CpuWinPlan.raids_hq(battle, P1))
	assert_true(CpuWinPlan.raids_hq(battle, P2), "守る側の占拠は、ターンに縛られない")
	battle.capture_turns[P1] = 1
	assert_true(CpuWinPlan.raids_hq(battle, P1), "もう 1 回占拠していれば、まだ間に合う")


## 拠点のある 16 x 5 の盤（拠点は (7,2)。両方とも拠点の確保で勝てる）。ターン 40（膠着を解く）。
## プレイヤー1 は将と、拠点に乗った前衛（と、fighters が 2 なら、もう 1 体の前衛）。プレイヤー2 は将だけ。
func _stalled_stronghold(fighters: int) -> Battle:
	var battle := _battle_with_kings()
	battle.board.stronghold_cell = Vector2i(7, 2)
	for side: Unit.Side in [P1, P2]:
		battle.win_conditions[side].append(GameWonEvent.Reason.STRONGHOLD_HELD)
	battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(7, 2))
	if fighters > 1:
		battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(5, 3))
	battle.turn = CpuPlayer.STALL_TURN
	return battle


## 膠着を解く（docs/cpu-ai.md）: 戦う駒が拠点の受け持ちの 1 体だけなら、それも敵の将へ向かう（拠点の隣で治し合うまま終わらないので）。
func test_lone_stronghold_taker_heads_for_the_enemy_general_when_the_game_stalls() -> void:
	var battle := _stalled_stronghold(1)
	var taker := battle.unit_at(Vector2i(7, 2))
	_play_phase(battle)
	assert_true(Combat.distance(taker.cell, HQ2) < Combat.distance(Vector2i(7, 2), HQ2), "敵の将へ寄る: %s" % taker.cell)


## 戦う駒がほかにもいれば、拠点の受け持ちは拠点に残る。
func test_stronghold_taker_stays_when_another_fighter_breaks_the_stall() -> void:
	var battle := _stalled_stronghold(2)
	var taker := battle.unit_at(Vector2i(7, 2))
	_play_phase(battle)
	assert_eq(taker.cell, Vector2i(7, 2))
