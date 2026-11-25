extends "res://tests/base_test.gd"
## 脅威範囲（docs/threat-range.md）: 次の自分の番に攻撃・スキルで届くマス。
## 移動、射程、ZOC、盾、ポータル、駒の状態、スキル、必殺技、アドレナリン注射、樽を、いまのルールどおりに通すこと。

const Maps := preload("res://tests/support/maps.gd")

const P1 := Unit.Side.PLAYER1
const P2 := Unit.Side.PLAYER2
const NEUTRAL := Unit.Side.NEUTRAL

## 壁の無い 16 x 5 の盤面。
const OPEN_ROWS: Array[String] = [
	"................",
	"................",
	"................",
	"................",
	"................",
]


func _open() -> Battle:
	return Maps.battle(OPEN_ROWS)


## from からマンハッタン距離 reach 以内の、盤の中のマス。
func _diamond(battle: Battle, from: Vector2i, reach: int) -> Dictionary[Vector2i, bool]:
	var result: Dictionary[Vector2i, bool] = {}
	for y in battle.board.size.y:
		for x in battle.board.size.x:
			var cell := Vector2i(x, y)
			if Combat.distance(from, cell) <= reach:
				result[cell] = true
	return result


func _same_cells(map: Threat.Map, expected: Dictionary[Vector2i, bool], message := "") -> void:
	var cells: Array[Vector2i] = []
	cells.assign(expected.keys())
	cells.sort_custom(Board.in_reading_order)
	assert_eq(map.cells(), cells, message)


func test_moves_then_attack_range() -> void:
	var battle := _open()
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P2, Vector2i(8, 2))
	var map := Threat.of(battle, commando.id)
	# 移動 6 + 射程 1。巡航（移動 12）は攻撃できないので数えない。
	_same_cells(map, _diamond(battle, commando.cell, 7))
	assert_eq(map.at(Vector2i(1, 2)), {commando.id: commando.power()})
	assert_false(map.has(Vector2i(0, 2)))


func test_a_cell_the_rules_let_the_enemy_attack_is_always_in_the_threat() -> void:
	# 壁、森、ポータル、ZOC、盾の混じった盤面で、相手が実際に動いて攻撃できるマスは、すべて脅威範囲に入る。
	var battle := Maps.battle([
		"..#.F...1.",
		"..#.F.....",
		"....#..F..",
		"1...#.....",
	])
	battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(6, 3))  # ZOC
	FieldEffects.place_barricade(battle, P1, Vector2i(5, 1))
	var raider := battle.add_unit(UnitKind.Id.COMMANDO, P2, Vector2i(7, 1))
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(9, 3))
	for attacker: Unit in [raider, sniper]:
		var map := Threat.of(battle, attacker.id)
		for y in battle.board.size.y:
			for x in battle.board.size.x:
				var cell := Vector2i(x, y)
				if not battle.board.is_walkable(cell) or battle.unit_at(cell) != null:
					continue
				var probe := battle.clone()
				probe.add_unit(UnitKind.Id.KING, P1, cell)
				var victim := probe.unit_at(cell)
				probe.apply(EndPhaseAction.new())  # 相手の番へ
				var hit := false
				for to: Vector2i in probe.options(attacker.id).move_cells:
					var tried := probe.clone()
					tried.apply(MoveAction.new(attacker.id, to))
					if tried.can_apply(AttackAction.new(attacker.id, victim.id)):
						hit = true
						break
				if hit:
					assert_true(map.has(cell), "%s から %s へ届く" % [UnitKind.Id.find_key(attacker.kind), cell])


func test_zone_of_control_stops_the_approach() -> void:
	var battle := Maps.battle([
		".........",
		".........",
		".........",
	])
	battle.add_unit(UnitKind.Id.SHIELD_TROOPER, P1, Vector2i(4, 1))  # ZOC が x 3〜5 の 3 行すべてを覆う
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P2, Vector2i(8, 1))
	var map := Threat.of(battle, commando.id)
	# x 5 で ZOC に止まる。そこから射程 1。
	assert_true(map.has(Vector2i(4, 0)))
	assert_false(map.has(Vector2i(3, 0)), "ZOC の先へは進めない")
	assert_false(map.has(Vector2i(2, 1)))


func test_barricade_blocks_the_path_and_the_line() -> void:
	var battle := Maps.battle([
		"....#...",
		"....#...",
		"........",
		"....#...",
		"....#...",
	])
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(7, 2))
	assert_true(Threat.of(battle, sniper.id).has(Vector2i(3, 2)))
	FieldEffects.place_barricade(battle, P1, Vector2i(4, 2))
	var map := Threat.of(battle, sniper.id)
	assert_false(map.has(Vector2i(3, 2)), "盾が道も射線もふさぐ")
	assert_true(map.has(Vector2i(3, 1)), "壁越しには届く")


func test_portal_carries_the_threat() -> void:
	var battle := Maps.battle([
		"1..............1",
		"................",
	])
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P2, Vector2i(2, 0))
	var map := Threat.of(battle, commando.id)
	assert_true(map.has(Vector2i(11, 1)), "2 歩でポータルへ。移った先から残り 4 歩と射程 1")
	battle.add_unit(UnitKind.Id.KING, P1, Vector2i(15, 0))
	assert_false(Threat.of(battle, commando.id).has(Vector2i(11, 1)), "行き先に駒がいれば移れない")


func test_aim_counts_only_from_the_aimed_cell() -> void:
	var battle := _open()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(8, 2))
	Statuses.add(sniper, Status.Type.AIM, 2)
	var map := Threat.of(battle, sniper.id)
	# いまのマスから射程 4 + 3、2 倍の攻撃力。動いた先からは、もとの射程と攻撃力。
	assert_eq(map.at(Vector2i(1, 2)), {sniper.id: sniper.power() * 2}, "構えたマスから 7")
	assert_eq(map.at(Vector2i(4, 2)), {sniper.id: sniper.power() * 2})
	assert_false(map.has(Vector2i(0, 2)), "8 マス先は、構えたままでも、動いても届かない")
	# 残り 1 ターンの照準は、相手の番の始めに外れる。
	sniper.statuses[Status.Type.AIM] = 1
	assert_false(Threat.of(battle, sniper.id).has(Vector2i(0, 2)))


func test_assault_ult_adds_move_and_power() -> void:
	var battle := _open()
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P2, Vector2i(10, 2))
	assert_false(Threat.of(battle, commando.id).has(Vector2i(2, 2)))
	battle.ult_gauge[P2] = Ults.GAUGE_MAX - Ults.PHASE_GAIN  # 相手の番の始めにいっぱいになる
	var map := Threat.of(battle, commando.id)
	assert_true(map.has(Vector2i(2, 2)), "移動 6 + 2 + 射程 1")
	assert_eq(map.at(Vector2i(2, 2)), {commando.id: commando.power() + AllOutAssaultUlt.POWER_BONUS})


func test_mana_eruption_readies_the_fireball() -> void:
	var battle := _open()
	var sorcerer := battle.add_unit(UnitKind.Id.SORCERER, P2, Vector2i(8, 2))
	sorcerer.skill_cooldown = 3
	var far := Vector2i(1, 2)  # 移動 3 + 射程 2 では届かず、移動 3 + 中心 3 + 腕 1 で届く
	assert_false(Threat.of(battle, sorcerer.id).has(far))
	battle.ult_gauge[P2] = Ults.GAUGE_MAX
	var map := Threat.of(battle, sorcerer.id)
	assert_eq(map.at(far), {sorcerer.id: FireballSkill.DAMAGE})
	assert_eq(map.at(far, true), {sorcerer.id: FireballSkill.DAMAGE}, "煙幕に防がれない")


func test_shadow_step_attacks_from_where_it_lands() -> void:
	var battle := Maps.battle([
		"........#.......",
		"........#.......",
		"........#.......",
		"........#.......",
		"........#.......",
	])
	var blade := battle.add_unit(UnitKind.Id.SPELLBLADE, P2, Vector2i(11, 2))
	var far := Vector2i(5, 2)  # 壁のそばまで歩いて（3 まで）、壁を跳び越えて (6, 2)、射程 1
	assert_true(Threat.of(battle, blade.id).has(far))
	assert_false(Threat.of(battle, blade.id).has(Vector2i(4, 2)), "歩いてから跳べるのは WALK_LIMIT まで")
	blade.skill_cooldown = 2
	assert_false(Threat.of(battle, blade.id).has(far))


func test_adrenaline_shot_gives_a_second_action() -> void:
	var battle := _open()
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P2, Vector2i(15, 2))
	var far := Vector2i(2, 2)  # 1 度目の行動（6 歩と射程 1）では届かず、(9, 2) からの 2 度目で届く
	assert_false(Threat.of(battle, commando.id).has(far))
	var medic := battle.add_unit(UnitKind.Id.MEDIC, P2, Vector2i(10, 0))
	var map := Threat.of(battle, commando.id)
	assert_true(map.has(far), "衛生兵が注射を打てば、もう一度動いて攻撃する")
	assert_eq(map.at(far), {commando.id: commando.power() - AdrenalineShotSkill.POWER_PENALTY}, "2 度目は反動の付いた攻撃力")
	assert_false(Threat.of(battle, medic.id).has(far), "衛生兵そのものは攻撃しない")
	medic.skill_uses = AdrenalineShotSkill.MAX_USES
	assert_false(Threat.of(battle, commando.id).has(far), "使い切った衛生兵は打てない")


func test_adrenaline_needs_the_medic_to_reach_the_spot() -> void:
	var battle := _open()
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P2, Vector2i(15, 2))
	battle.add_unit(UnitKind.Id.MEDIC, P2, Vector2i(15, 0))
	# 衛生兵（移動 4 + 射程 1）が打てるのは (15, 0) から 5 以内のマスだけ。いちばん左の (11, 1) からでも、もう 6 歩と射程 1 では届かない。
	assert_false(Threat.of(battle, commando.id).has(Vector2i(2, 2)))
	assert_true(Threat.of(battle, commando.id).has(Vector2i(4, 1)), "(11, 1) から 7")


func test_barrel_blast_is_in_the_threat() -> void:
	var battle := Maps.battle([
		"................",
		"................",
		"......B.........",
		"................",
		"................",
	])
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(13, 2))
	var map := Threat.of(battle, sniper.id)
	# 移動 3 + 射程 4 で、(6, 2) の樽に届く。爆発は (5, 1) にも届く（攻撃そのものは届かない）。
	assert_eq(map.at(Vector2i(5, 1)), {sniper.id: MapObject.BLAST_DAMAGE})
	assert_eq(map.at(Vector2i(5, 1), true), {sniper.id: MapObject.BLAST_DAMAGE}, "爆発は煙幕に防がれない")


func test_close_table_holds_only_what_smoke_cannot_stop() -> void:
	var battle := _open()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(8, 2))
	var map := Threat.of(battle, sniper.id)
	assert_eq(map.at(Vector2i(4, 2), true), {sniper.id: sniper.power()}, "隣まで寄れる")
	assert_true(map.has(Vector2i(1, 2)))
	assert_eq(map.at(Vector2i(1, 2), true), {}, "離れたところからだけ")


func test_healers_have_no_threat() -> void:
	var battle := _open()
	var priest := battle.add_unit(UnitKind.Id.PRIEST, P2, Vector2i(8, 2))
	assert_true(Threat.of(battle, priest.id).cells().is_empty())


func test_neutral_stays_in_its_territory() -> void:
	var battle := _open()
	var minion := battle.add_unit(UnitKind.Id.MINION, NEUTRAL, Vector2i(2, 2))
	minion.home_cell = Vector2i(2, 2)
	var map := Threat.of(battle, minion.id)
	_same_cells(map, _diamond(battle, minion.cell, minion.move_range() + minion.attack_range()))
	minion.cell = Vector2i(2 + Neutral.TERRITORY_RADIUS, 2)
	assert_false(Threat.of(battle, minion.id).has(Vector2i(2 + Neutral.TERRITORY_RADIUS + 3, 2)), "縄張りの外には止まらない")


func test_against_overlays_every_enemy() -> void:
	var battle := _open()
	battle.add_unit(UnitKind.Id.KING, P1, Vector2i(0, 0))
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P2, Vector2i(8, 2))
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(12, 2))
	var minion := battle.add_unit(UnitKind.Id.MINION, NEUTRAL, Vector2i(2, 2))
	var map := Threat.against(battle, P1)
	var cell := Vector2i(5, 2)
	assert_eq(map.at(cell), {commando.id: commando.power(), sniper.id: sniper.power(), minion.id: minion.power()})
	for enemy: Unit in [commando, sniper, minion]:
		for at in Threat.of(battle, enemy.id).cells():
			assert_true(map.has(at))
	assert_true(map.stops.has(Vector2i(8, 2)), "相手の駒の止まれるマス")
	assert_false(Threat.against(battle, P2).has(Vector2i(15, 4)), "P2 の敵は将と中立の駒だけ")


func test_threat_in_the_threatening_side_own_phase_is_for_its_next_turn() -> void:
	var battle := _open()
	var commando := battle.add_unit(UnitKind.Id.COMMANDO, P1, Vector2i(8, 2))
	commando.acted = true
	assert_true(Threat.of(battle, commando.id).has(Vector2i(1, 2)), "行動済みでも、次の番には動ける")


func test_threat_does_not_change_the_battle() -> void:
	var battle := Maps.battle([
		"..*.............",
		"................",
	])
	battle.add_unit(UnitKind.Id.KING, P1, Vector2i(0, 0))
	var sorcerer := battle.add_unit(UnitKind.Id.SORCERER, P2, Vector2i(8, 1))
	battle.add_unit(UnitKind.Id.MEDIC, P2, Vector2i(9, 1))
	battle.ult_gauge[P2] = Ults.GAUGE_MAX
	battle.turn = 3  # 結晶泉の湧きに乱数を引く
	var before := battle.clone()
	Threat.of(battle, sorcerer.id)
	Threat.against(battle, P1)
	assert_eq(battle.turn, before.turn)
	assert_eq(battle.phase, before.phase)
	assert_eq(battle.ult_gauge, before.ult_gauge)
	assert_eq(battle.units.size(), before.units.size())
	assert_eq(battle.rng.state, before.rng.state)


func test_barrel_shot_after_shadow_step_is_in_the_threat() -> void:
	var battle := Maps.battle(["......#........."])
	var blade := battle.add_unit(UnitKind.Id.SPELLBLADE, P2, Vector2i(10, 0))
	battle.board.add_barrel(Vector2i(4, 0))
	# 歩いて (7, 0)、壁を跳び越えて (5, 0)、樽を撃てば (3, 0) まで爆発が届く。
	assert_eq(Threat.of(battle, blade.id).at(Vector2i(3, 0)), {blade.id: MapObject.BLAST_DAMAGE})
	blade.skill_cooldown = 2
	assert_false(Threat.of(battle, blade.id).has(Vector2i(3, 0)), "跳べなければ届かない")
