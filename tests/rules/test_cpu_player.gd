extends "res://tests/base_test.gd"
## CPU の思考（docs/cpu-ai.md）。

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


func test_attacks_the_enemy_standing_on_own_hq_first() -> void:
	var battle := _battle()
	battle.add_unit(UnitKind.Id.KING, P1, Vector2i(0, 0))
	battle.add_unit(UnitKind.Id.KING, P2, HQ2)
	var occupier := battle.add_unit(UnitKind.Id.PALADIN, P2, HQ1)
	# もっと近くに、HP の少ない敵もいる。それでも、本陣に乗っている敵を先に叩く。
	var other := battle.add_unit(UnitKind.Id.SORCERER, P2, Vector2i(6, 2))
	other.hp = 10
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


func test_healer_never_attacks() -> void:
	var battle := _battle_with_kings()
	battle.add_unit(UnitKind.Id.PRIEST, P1, Vector2i(3, 2))
	var enemy := battle.add_unit(UnitKind.Id.SORCERER, P2, Vector2i(5, 2))
	for action in _play_phase(battle):
		assert_false(action is AttackAction)
	assert_eq(enemy.hp, enemy.max_hp())


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
	var battle := CpuMatchSetup.create()
	var first := CpuPlayer.new()
	for i in 30:
		# 使い回したインスタンスと、作りたてのインスタンスで、同じ行動になる（覚えているものが判断を変えない）。
		var a := first.next_action(battle)
		var b := CpuPlayer.new().next_action(battle.clone())
		assert_eq(_text(a), _text(b), "%d 手目" % i)
		battle.apply(a)


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
