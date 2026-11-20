extends "res://tests/base_test.gd"
## 骨太鼓（docs/skills/war-drum.md）。

const Maps := preload("res://tests/support/maps.gd")

const P1 := Unit.Side.PLAYER1
const P2 := Unit.Side.PLAYER2
const ASSAULT := Status.Type.ASSAULT


func _battle() -> Battle:
	return Maps.battle(["..........", "..........", "..........", "..........", "..........", ".........."])


func test_drummer_has_it() -> void:
	var skill := Skills.of_kind(UnitKind.Id.SKELETON_DRUMMER)
	assert_eq(skill.id(), Skill.Id.WAR_DRUM)
	assert_eq(skill.cooldown(), WarDrumSkill.COOLDOWN)
	assert_true(skill.ends_action())


func test_target_is_its_own_cell() -> void:
	var battle := _battle()
	var drummer := battle.add_unit(UnitKind.Id.SKELETON_DRUMMER, P1, Vector2i(4, 3))
	battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(9, 0))
	assert_eq(battle.options(drummer.id).skill_cells, [drummer.cell] as Array[Vector2i])


func test_friends_within_radius_charge() -> void:
	var battle := _battle()
	var drummer := battle.add_unit(UnitKind.Id.SKELETON_DRUMMER, P1, Vector2i(4, 3))
	var near := battle.add_unit(UnitKind.Id.SKELETON, P1, Vector2i(4, 1))
	var edge := battle.add_unit(UnitKind.Id.SKELETON, P1, Vector2i(6, 4))
	var far := battle.add_unit(UnitKind.Id.SKELETON, P1, Vector2i(8, 3))
	var foe := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(5, 3))
	assert_eq(WarDrumSkill.RADIUS, 3, "下の置き方は、届く広さ 3 のため")
	var power := near.power()
	var move := near.move_range()
	var result := battle.apply(UseSkillAction.new(drummer.id, drummer.cell))
	assert_true(result.accepted)
	var applied: Array[int] = []
	for event in result.events:
		if event is StatusAppliedEvent:
			applied.append((event as StatusAppliedEvent).unit_id)
	assert_eq(applied, [near.id, edge.id] as Array[int], "3 マス以内の味方だけ（上の行から）。自分と敵には付かない")
	assert_true(Statuses.has(near, ASSAULT))
	assert_false(Statuses.has(far, ASSAULT))
	assert_false(Statuses.has(drummer, ASSAULT))
	assert_false(Statuses.has(foe, ASSAULT))
	assert_eq(near.power(), power + AllOutAssaultUlt.POWER_BONUS)
	assert_eq(near.move_range(), move + AllOutAssaultUlt.MOVE_BONUS)
	assert_true(result.events[-1] is UnitActedEvent)
	# 次の自分の番の始めに外れる。
	battle.apply(EndPhaseAction.new())
	assert_true(Statuses.has(near, ASSAULT), "相手の番の間は残る")
	battle.apply(EndPhaseAction.new())
	assert_false(Statuses.has(near, ASSAULT), "次の自分の番の始めに外れる")


## CPU は、届く味方が戦える距離にいれば鳴らし、そうでなければ鳴らさない。
func test_cpu_drums_when_friends_can_reach_foes() -> void:
	var battle := _battle()
	var drummer := battle.add_unit(UnitKind.Id.SKELETON_DRUMMER, P1, Vector2i(1, 5))
	battle.add_unit(UnitKind.Id.SKELETON, P1, Vector2i(2, 4))
	battle.add_unit(UnitKind.Id.SKELETON, P1, Vector2i(1, 3))
	battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(6, 1))
	var action := _cpu_turn_skill(battle, drummer)
	assert_true(action != null, "骨太鼓を使う: %s" % [action])


func test_cpu_does_not_drum_alone() -> void:
	var battle := _battle()
	var drummer := battle.add_unit(UnitKind.Id.SKELETON_DRUMMER, P1, Vector2i(1, 5))
	battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(8, 0))
	assert_eq(_cpu_turn_skill(battle, drummer), null, "届く味方がいなければ鳴らさない")


## CPU に、unit が行動を終えるまで動かさせ、unit が使ったスキルの行動を返す（使わなければ null）。
func _cpu_turn_skill(battle: Battle, unit: Unit) -> UseSkillAction:
	var cpu := CpuPlayer.new()
	var used: UseSkillAction = null
	for i in 20:
		if battle.phase != unit.side or unit.acted:
			break
		var action := cpu.next_action(battle)
		if action is UseSkillAction and action.unit_id == unit.id:
			used = action
		if not battle.apply(action).accepted:
			break
	return used
