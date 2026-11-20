extends "res://tests/base_test.gd"
## 骨起こし（docs/skills/bone-raise.md）。

const Maps := preload("res://tests/support/maps.gd")

const P1 := Unit.Side.PLAYER1
const P2 := Unit.Side.PLAYER2

const ROWS: Array[String] = [
	"......",
	"..#...",
	"......",
	"......",
]


func _end_turn(battle: Battle) -> void:
	battle.apply(EndPhaseAction.new())
	battle.apply(EndPhaseAction.new())


func test_caller_has_it() -> void:
	var skill := Skills.of_kind(UnitKind.Id.SKELETON_CALLER)
	assert_eq(skill.id(), Skill.Id.BONE_RAISE)
	assert_eq(skill.cooldown(), BoneRaiseSkill.COOLDOWN)
	assert_eq(skill.max_uses(), BoneRaiseSkill.MAX_USES)
	assert_true(skill.ends_action())


func test_targets_are_free_neighbours() -> void:
	var battle := Maps.battle(ROWS)
	var caller := battle.add_unit(UnitKind.Id.SKELETON_CALLER, P1, Vector2i(2, 2))
	battle.add_unit(UnitKind.Id.SKELETON, P1, Vector2i(3, 2))
	battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(2, 3))
	# 上は障害物、右は味方、下は敵。空いているのは左だけ。
	assert_eq(battle.options(caller.id).skill_cells, [Vector2i(1, 2)] as Array[Vector2i])


func test_raises_an_acted_skeleton_on_the_callers_side() -> void:
	var battle := Maps.battle(ROWS)
	var caller := battle.add_unit(UnitKind.Id.SKELETON_CALLER, P1, Vector2i(3, 2))
	battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(0, 0))
	var result := battle.apply(UseSkillAction.new(caller.id, Vector2i(4, 2)))
	assert_true(result.accepted)
	assert_true(result.events[0] is SkillUsedEvent)
	var spawned := result.events[1] as UnitSpawnedEvent
	assert_true(spawned != null, "骸骨兵が起きる")
	assert_eq(spawned.kind, UnitKind.Id.SKELETON)
	assert_eq(spawned.side, P1)
	assert_eq(spawned.cell, Vector2i(4, 2))
	assert_true(result.events[2] is UnitActedEvent, "術師は行動を終える")
	var raised := battle.unit_at(Vector2i(4, 2))
	assert_eq(raised.level, 1)
	assert_false(battle.can_act(raised), "起きたフェーズには動けない")
	_end_turn(battle)
	assert_true(battle.can_act(raised), "次の自分の番から動く")


func test_runs_out_after_max_uses() -> void:
	var battle := Maps.battle(ROWS)
	var caller := battle.add_unit(UnitKind.Id.SKELETON_CALLER, P1, Vector2i(3, 2))
	battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(0, 0))
	var cells: Array[Vector2i] = [Vector2i(4, 2), Vector2i(3, 3), Vector2i(3, 1)]
	for i in BoneRaiseSkill.MAX_USES:
		assert_true(battle.apply(UseSkillAction.new(caller.id, cells[i])).accepted, "%d 回目" % (i + 1))
		for turn in BoneRaiseSkill.COOLDOWN:
			_end_turn(battle)
	assert_eq(Skills.uses_left(caller), 0)
	assert_false(Skills.can_use(battle, caller), "使い切った")


## CPU は、届く敵がいないときに、骸骨兵を起こす。
func test_cpu_raises_when_nothing_to_hit() -> void:
	var battle := Maps.battle(["........", "........", "........", "........", "........", "........"])
	var caller := battle.add_unit(UnitKind.Id.SKELETON_CALLER, P1, Vector2i(1, 4))
	battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(6, 0))
	var action := _cpu_turn_skill(battle, caller)
	assert_true(action != null, "骨起こしを使う: %s" % [action])


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
