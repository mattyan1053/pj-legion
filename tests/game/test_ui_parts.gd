extends "res://tests/base_test.gd"
## 札の部品（能力値の欄 game/stats_row.gd、コストの宝石 game/cost_gems.gd、役割の印 game/role_mark.gd、駒の額 game/unit_frame.gd）。
## 大きさが中身で変わらないことと、能力値の 1 行を項目に分けること。

const StatsRow := preload("res://game/stats_row.gd")
const CostGems := preload("res://game/cost_gems.gd")
const UnitFrame := preload("res://game/unit_frame.gd")
const DeckText := preload("res://game/deck_text.gd")


func _texts(row: StatsRow) -> Array[String]:
	var texts: Array[String] = []
	for cell in row.get_children():
		if cell.is_queued_for_deletion():
			continue
		var words: Array[String] = []
		for label: Label in cell.get_children():
			words.append(label.text)
		texts.append(" ".join(words))
	return texts


func test_stats_row_splits_a_line_into_names_and_numbers() -> void:
	for kind: UnitKind.Id in UnitKind.Id.values():
		var line := DeckText.stats_line(kind)
		var row := StatsRow.new(line, 13, 50.0)
		var texts := _texts(row)
		var healer := UnitKind.role(kind) == UnitKind.Role.HEALER
		assert_eq(texts.size(), 5 if healer else 4, "能力値は 4 項目（回復役は攻撃を足して 5 項目）: %s" % line)
		# 分けて出しても、文は元の 1 行と同じ（言葉を変えない）。
		assert_eq(char(0x3000).join(texts), line)
		for cell in row.get_children():
			assert_eq(cell.get_child_count(), 2, "名前と数に分かれる: %s" % line)
			assert_true((cell.get_child(1) as Label).text.is_valid_int(), "後ろは数: %s" % line)
		row.free()


## 欄の幅は、数の桁で変わらない。木に入れて 1 コマ待ってから測る（base_test.gd の settle。木の外では、前の大きさが返る）。
func test_stats_row_keeps_cell_width_whatever_the_numbers() -> void:
	preload("res://game/ui_theme.gd").install()
	var small := StatsRow.new(DeckText.stats_line(UnitKind.Id.KING), 13, 50.0)
	var large := StatsRow.new(DeckText.stats_line(UnitKind.Id.KING, {Unit.Stat.MAX_HP: 200, Unit.Stat.POWER: 90}), 13, 50.0)
	await settle(small)
	await settle(large)
	for i in 4:
		assert_eq((small.get_child(i) as Control).get_combined_minimum_size().x, 50.0, "%d 番目の欄（小さい数）" % i)
		assert_eq((large.get_child(i) as Control).get_combined_minimum_size().x, 50.0, "%d 番目の欄（大きい数）: %s" % [i, _texts(large)])
	assert_eq(large.get_combined_minimum_size(), small.get_combined_minimum_size(), "行の大きさが、数で変わる")
	small.free()
	large.free()


## 回復役の行（5 項目）も、ほかの駒の行（4 項目）と同じ幅に収まる。
func test_stats_row_keeps_row_width_for_healers() -> void:
	preload("res://game/ui_theme.gd").install()
	var fighter := StatsRow.new(DeckText.stats_line(UnitKind.Id.COMMANDO), 13, 50.0)
	var medic := StatsRow.new(DeckText.stats_line(UnitKind.Id.MEDIC), 13, 50.0)
	var priest := StatsRow.new(DeckText.stats_line(UnitKind.Id.PRIEST, {Unit.Stat.MAX_HP: 90}), 13, 50.0)
	await settle(fighter)
	await settle(medic)
	await settle(priest)
	assert_true(DeckText.stats_line(UnitKind.Id.MEDIC).contains("攻撃 %d" % UnitKind.healer_strike(UnitKind.Id.MEDIC)), "回復役の攻撃が出る")
	assert_eq(medic.get_combined_minimum_size().x, fighter.get_combined_minimum_size().x, "衛生兵の行の幅: %s" % [_texts(medic)])
	assert_eq(priest.get_combined_minimum_size().x, fighter.get_combined_minimum_size().x, "プリーストの行の幅: %s" % [_texts(priest)])
	fighter.free()
	medic.free()
	priest.free()


func test_stats_row_shows_an_unsplittable_part_whole() -> void:
	var row := StatsRow.new("ABC", 13)
	assert_eq(_texts(row), ["ABC"] as Array[String])
	row.free()


func test_cost_gauge_size_does_not_follow_the_count() -> void:
	var gauge := CostGems.new(0, 24, 9.0, 236.0)
	var before := gauge.custom_minimum_size
	gauge.count = 30  # 上限を超えても、大きさは変わらない（色が変わるだけ）
	gauge.slots = 14
	assert_eq(gauge.custom_minimum_size, before)
	gauge.free()


## 額の大きさは、駒で変わらない。木に入れて 1 コマ待ってから測る（base_test.gd の settle）。
func test_unit_frame_size_does_not_follow_the_unit() -> void:
	var frame := UnitFrame.new(UnitKind.Id.KING, 0, 48.0)
	await settle(frame)
	var before := frame.get_combined_minimum_size()
	assert_eq(before, Vector2(48.0, 48.0))
	for kind: UnitKind.Id in UnitKind.Id.values():
		frame.set_kind(kind)
		await settle(frame)
		assert_eq(frame.get_combined_minimum_size(), before, "%d" % kind)
	frame.free()
