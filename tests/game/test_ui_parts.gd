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
		assert_eq(texts.size(), 4, "能力値は 4 項目: %s" % line)
		# 分けて出しても、文は元の 1 行と同じ（言葉を変えない）。
		assert_eq(char(0x3000).join(texts), line)
		for cell in row.get_children():
			assert_eq(cell.get_child_count(), 2, "名前と数に分かれる: %s" % line)
			assert_true((cell.get_child(1) as Label).text.is_valid_int(), "後ろは数: %s" % line)
		row.free()


func test_stats_row_keeps_cell_width_whatever_the_numbers() -> void:
	var small := StatsRow.new(DeckText.stats_line(UnitKind.Id.KING), 13, 50.0)
	var large := StatsRow.new(DeckText.stats_line(UnitKind.Id.KING, {Unit.Stat.MAX_HP: 200, Unit.Stat.POWER: 90}), 13, 50.0)
	for i in 4:
		assert_eq((small.get_child(i) as Control).custom_minimum_size.x, 50.0)
		assert_eq((large.get_child(i) as Control).custom_minimum_size.x, 50.0)
	small.free()
	large.free()


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


func test_unit_frame_size_does_not_follow_the_unit() -> void:
	var frame := UnitFrame.new(UnitKind.Id.KING, 0, 48.0)
	var before := frame.get_combined_minimum_size()
	for kind: UnitKind.Id in UnitKind.Id.values():
		frame.set_kind(kind)
		assert_eq(frame.get_combined_minimum_size(), before)
	frame.free()
