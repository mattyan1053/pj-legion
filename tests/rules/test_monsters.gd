extends "res://tests/base_test.gd"
## 魔物（軍に属さない、話の敵としてだけ出る駒。docs/unit-roster.md の「魔物」）を、いまの対戦と CPU が扱えること。

const Maps := preload("res://tests/support/maps.gd")

const P1 := Unit.Side.PLAYER1
const P2 := Unit.Side.PLAYER2


## 軍に属さない編成（軍 none）。決め打ちの敵と同じく、決まりの検査は通さずに組む。
func _monster_deck() -> Deck:
	var deck := Deck.new(UnitKind.Army.NONE)
	for kind: UnitKind.Id in [
		UnitKind.Id.SKELETON_BRUTE, UnitKind.Id.SKELETON_ARCHER, UnitKind.Id.SKELETON, UnitKind.Id.SKELETON, UnitKind.Id.SKELETON,
		UnitKind.Id.SKELETON_CALLER, UnitKind.Id.SKELETON_DRUMMER,
	]:
		deck.entries.append(DeckEntry.new(kind))
	return deck


## 12 x 8 の盤に、プレイヤー1 は MILITARY の CPU の編成、プレイヤー2 は魔物の群れ。
func _battle() -> Battle:
	var board := Maps.board([
		"............",
		"............",
		"....F..#....",
		"..#.........",
		".........#..",
		"....#..F....",
		"............",
		"............",
	])
	board.hq_cells = [Vector2i(2, 7), Vector2i(9, 0)]
	var battle := Battle.new(board, 1)
	Deployment.deploy(battle, P1, CpuDeck.build(UnitKind.Army.MILITARY))
	Deployment.deploy(battle, P2, _monster_deck())
	return battle


func test_a_monster_side_has_no_army_and_no_ult() -> void:
	var battle := _battle()
	assert_eq(battle.armies[P2], UnitKind.Army.NONE)
	assert_eq(Ults.of(battle, P2), null)
	assert_eq(battle.units.filter(func(unit: Unit) -> bool: return unit.side == P2).size(), 8, "将と 7 体")
	Ults.charge(battle, P2, Ults.GAUGE_MAX)
	assert_eq(Ults.gauge(battle, P2), 0, "必殺技の無い陣営のゲージはたまらない")
	assert_false(Ults.is_ready(battle, P2))


## 骸骨兵・骸骨射手・骸骨重兵はスキルを持たない。骸骨術師と骸骨鼓手だけが、固有のスキルを持つ。
func test_only_the_skilled_monsters_hold_a_skill() -> void:
	var skilled := {UnitKind.Id.SKELETON_CALLER: Skill.Id.BONE_RAISE, UnitKind.Id.SKELETON_DRUMMER: Skill.Id.WAR_DRUM}
	for kind: UnitKind.Id in UnitKind.Id.values():
		if not UnitKind.is_monster(kind):
			continue
		var skill := Skills.of_kind(kind)
		if skilled.has(kind):
			assert_true(skill != null and skill.id() == skilled[kind], str(UnitKind.Id.find_key(kind)))
		else:
			assert_eq(skill, null, str(UnitKind.Id.find_key(kind)))


## CPU が魔物の側を（そして魔物と戦う側を）、断られる行動なしに動かし続けられる。
func test_cpu_moves_monsters_through_a_game() -> void:
	var battle := _battle()
	var cpu := CpuPlayer.new()
	var moved := {}
	var steps := 0
	while not battle.is_over() and battle.turn <= 6 and steps < 2000:
		var action := cpu.next_action(battle)
		assert_true(action != null, "CPU が行動を返さない")
		if action == null:
			return
		var acting := battle.unit_by_id(action.unit_id) if "unit_id" in action else null
		if acting != null and UnitKind.is_monster(acting.kind):
			moved[acting.kind] = true
		var result := battle.apply(action)
		assert_true(result.accepted, "CPU の行動が断られた")
		if not result.accepted:
			return
		steps += 1
	assert_eq(moved.size(), 5, "5 種類の魔物が、どれも行動した: %s" % [moved.keys()])
	assert_false(battle.ult_uses[P2] > 0, "魔物の側は必殺技を使わない")
