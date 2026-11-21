extends "res://tests/base_test.gd"
## 駒のステータス（game/unit_sheet.gd）と、その窓（game/unit_detail.gd。docs/deck-screen.md の「駒の詳細」）。

const UnitSheet := preload("res://game/unit_sheet.gd")
const UnitDetail := preload("res://game/unit_detail.gd")
const UnitSummary := preload("res://game/unit_summary.gd")
const OverlayStack := preload("res://game/overlay_stack.gd")
const Names := preload("res://game/names.gd")
const Maps := preload("res://tests/support/maps.gd")


func test_items_are_a_delta_on_top_of_the_plain_value() -> void:
	var held: Array[Equipment.Id] = [Equipment.Id.IRON_SHIELD, Equipment.Id.IRON_SHIELD, Equipment.Id.SPEED_BOOTS]
	var sheet: UnitSheet = UnitSheet.of_kind(UnitKind.Id.SHIELD_TROOPER, held)
	var hp := sheet.stat_line(Unit.Stat.MAX_HP)
	assert_eq(hp.plain, UnitKind.max_hp(UnitKind.Id.SHIELD_TROOPER), "素の値は持ち物を含まない")
	assert_eq(hp.delta(), 2 * Equipment.bonus(Equipment.Id.IRON_SHIELD, Unit.Stat.MAX_HP))
	assert_eq(sheet.hp, hp.value, "編成の駒は HP が満タン")
	assert_eq(sheet.stat_line(Unit.Stat.MOVE_RANGE).delta(), Equipment.bonus(Equipment.Id.SPEED_BOOTS, Unit.Stat.MOVE_RANGE))
	assert_eq(sheet.stat_line(Unit.Stat.POWER).delta(), 0)
	assert_eq(sheet.items, [[Equipment.Id.IRON_SHIELD, 2], [Equipment.Id.SPEED_BOOTS, 1]])
	assert_true(sheet.scale_of(Unit.Stat.MAX_HP) >= hp.value, "目盛りの端は、値より小さくならない")


func test_a_starting_level_matches_the_battle() -> void:
	# 対戦の始めに Growth.start_at で伸ばした駒と、同じ値を出す。伸びたぶんは素の値に入る（持ち物の増減ではない）。
	var battle := Maps.battle([".."])
	var unit := battle.add_unit(UnitKind.Id.PALADIN, Unit.Side.PLAYER1, Vector2i(0, 0))
	Growth.start_at(unit, 2, 0)
	var sheet: UnitSheet = UnitSheet.of_kind(UnitKind.Id.PALADIN, [], 0, -1, 2)
	assert_eq(sheet.level, 2)
	for line in sheet.stats:
		assert_eq(line.value, unit.stat(line.stat), line.name)
		assert_eq(line.delta(), 0, line.name)


func test_a_unit_in_battle_shows_its_current_state() -> void:
	var battle := Maps.battle(["..."])
	var unit := battle.add_unit(UnitKind.Id.COMMANDO, Unit.Side.PLAYER1, Vector2i(0, 0))
	unit.equipment.append(Equipment.Id.SPEED_BOOTS)
	unit.evolve(Evolution.Id.ASSAULT)
	unit.hp = 5
	unit.experience = 30
	var sheet: UnitSheet = UnitSheet.of_unit(unit, UnitKind.Army.MILITARY, "state")
	assert_eq(sheet.hp, 5)
	assert_eq(sheet.experience, 30)
	assert_eq(sheet.skill_state, "state")
	assert_eq(sheet.evolutions, [Evolution.Id.ASSAULT] as Array[Evolution.Id], "進化した駒は、その進化先だけ")
	# 進化のぶんは素の値、持ち物のぶんは増減。
	assert_eq(sheet.stat_line(Unit.Stat.POWER).plain, UnitKind.power(UnitKind.Id.COMMANDO) + Evolution.bonus(Evolution.Id.ASSAULT, Unit.Stat.POWER))
	assert_eq(sheet.stat_line(Unit.Stat.MOVE_RANGE).delta(), Equipment.bonus(Equipment.Id.SPEED_BOOTS, Unit.Stat.MOVE_RANGE))
	assert_eq(sheet.ult, Ults.of_army(UnitKind.Army.MILITARY))


func test_kings_and_monsters_have_no_cost_items_or_army_of_their_own() -> void:
	var king: UnitSheet = UnitSheet.of_kind(UnitKind.Id.KING, [], 0, UnitKind.Army.FANTASY)
	assert_eq(king.cost(), 0)
	assert_eq(king.item_slots, 0)
	assert_false(king.grows)
	assert_eq(king.ult, Ults.of_army(UnitKind.Army.FANTASY), "将は部隊の軍の必殺技を出す")
	var monster: UnitSheet = UnitSheet.of_kind(UnitKind.Id.SKELETON_BRUTE, [], 1, UnitKind.Army.MILITARY)
	assert_eq(monster.cost(), 0, "魔物はコストを出さない")
	assert_eq(monster.ult, null)
	assert_false(monster.borrowed)
	var borrowed: UnitSheet = UnitSheet.of_kind(UnitKind.Id.PRIEST, [], 0, UnitKind.Army.MILITARY)
	assert_true(borrowed.borrowed, "ほかの軍から雇った駒")
	assert_eq(borrowed.ult, Ults.of_army(UnitKind.Army.MILITARY), "必殺技は部隊の軍のもの")


## 窓の大きさは、木に入れて 1 コマ待ってから測る（base_test.gd の settle）。遊ぶときの字（UI のテーマ）で測る。
func test_the_window_fits_the_screen_for_every_unit() -> void:
	preload("res://game/ui_theme.gd").install()
	var detail := UnitDetail.new()
	detail.setup(OverlayStack.new())
	await settle(detail)
	var loads: Array = [
		[] as Array[Equipment.Id],
		[Equipment.Id.JET_PACK, Equipment.Id.DRAGON_SCALE, Equipment.Id.WAR_BANNER] as Array[Equipment.Id],
	]
	for kind: UnitKind.Id in UnitKind.Id.values():
		for held: Array[Equipment.Id] in loads:
			if not held.is_empty() and not Equipment.can_equip(kind):
				continue
			detail.open(kind, held, 0, UnitKind.Army.MILITARY, 2)
			assert_eq(detail.title_text(), Names.kind(kind))
			await settle(detail)
			var size := detail.panel_size()
			assert_true(size.x <= 1240.0 and size.y <= 700.0, "%s の窓が 1280×720 に収まらない: %s" % [Names.kind(kind), size])
			var texts := detail.stat_meters()[0].texts()
			assert_eq(texts[0], "HP")
			assert_eq(texts[2] != "", not held.is_empty(), "持ち物で HP が増えた駒にだけ、増減が出る")
	detail.free()


## 小さなステータスの札（部隊編成の右の札。game/unit_summary.gd）: 能力値の行は、ステータスの窓と同じ値（持ち物込みの値と増減）を出す。
## 「詳細」などのボタンの場所は、名前や札と別の行（飾りの線の右）にある。
## 札の幅が中身で広がらないことは、自動の対戦が画面の上で確かめる（game/autoplay.gd の _visit_decks。木の外では、大きさが測れない）。
func test_the_summary_card_shows_the_sheet() -> void:
	var card := UnitSummary.new(376.0)
	var loads: Array = [
		[] as Array[Equipment.Id],
		[Equipment.Id.JET_PACK, Equipment.Id.DRAGON_SCALE, Equipment.Id.WAR_BANNER] as Array[Equipment.Id],
	]
	for kind: UnitKind.Id in UnitKind.Id.values():
		for held: Array[Equipment.Id] in loads:
			if not held.is_empty() and not Equipment.can_equip(kind):
				continue
			var sheet: UnitSheet = UnitSheet.of_kind(kind, held, 0, UnitKind.Army.MILITARY)
			card.show_sheet(sheet, "12. %s" % sheet.name)
			assert_eq(card.title_text(), "12. %s" % Names.kind(kind))
			assert_eq(card.shown_sheet(), sheet)
			var hp := card.stat_meters()[0].texts()
			assert_eq(hp[1], str(sheet.max_hp()), "満タンの駒の HP は、値を 1 つだけ出す")
			assert_eq(hp[2] != "", sheet.stat_line(Unit.Stat.MAX_HP).delta() != 0)
	var row: Node = card.corner().get_parent()
	assert_true(row.get_parent() == card and row.get_index() > 0, "ボタンの場所が、頭の行（名前の行）と同じ行にある")
	card.free()


## HP の棒の枠: 最大 HP が大きいほど長いが、小さい駒でも棒の欄の半分近くはある（HP が減った駒の塗りが、割合で読める）。
func test_the_hp_frame_keeps_a_readable_length() -> void:
	const StatMeter := preload("res://game/stat_meter.gd")
	var scale: int = UnitSheet.SCALES[Unit.Stat.MAX_HP]
	var small := StatMeter.Meter.hp_frame_ratio(20, scale)
	var large := StatMeter.Meter.hp_frame_ratio(90, scale)
	assert_true(small >= StatMeter.Meter.HP_FRAME_FLOOR)
	assert_true(large > small, "最大 HP が大きい駒の枠のほうが長い")
	assert_eq(StatMeter.Meter.hp_frame_ratio(scale, scale), 1.0)
	assert_eq(StatMeter.Meter.hp_frame_ratio(scale * 2, scale), 1.0, "端を超えても、欄からはみ出さない")
