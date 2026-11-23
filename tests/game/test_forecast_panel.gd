extends "res://tests/base_test.gd"
## 戦闘予測のパネル（game/forecast_panel.gd）の HP の行: 情報の枠と同じ部品（stat_meter.gd）で、文の段落にしない。
## 中身（減る・増える・倒れる・防がれる）を替えても、幅は変わらない。

const ForecastPanel := preload("res://game/forecast_panel.gd")
const ForecastText := preload("res://game/forecast_text.gd")
const StatMeter := preload("res://game/stat_meter.gd")
const Text := preload("res://game/text.gd")


func _panel() -> ForecastPanel:
	var panel := ForecastPanel.new()
	panel.setup([Color.SKY_BLUE, Color.TOMATO] as Array[Color], func(font: Font, font_size: int, character: String) -> float:
		return font.get_string_size(character, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	return panel


func _row(before: int, after: int, max_hp: int, damage := -1, healed := 0) -> ForecastText.Row:
	var row := ForecastText.Row.new()
	row.name = "スナイパー"
	row.side = Unit.Side.PLAYER2
	row.hp_before = before
	row.hp_after = after
	row.max_hp = max_hp
	row.damage = damage
	row.healed = healed
	row.defeated = damage >= 0 and after == 0
	return row


func _summary(rows: Array[ForecastText.Row]) -> ForecastText.Summary:
	var summary := ForecastText.Summary.new()
	summary.rows = rows
	return summary


func _meters(panel: Node) -> Array[StatMeter]:
	var found: Array[StatMeter] = []
	for node in panel.find_children("*", "", true, false):
		if node is StatMeter:
			found.append(node)
	return found


func test_hp_row_is_a_meter_not_a_sentence() -> void:
	var panel := _panel()
	panel.show_summary("攻撃", _summary([_row(12, 5, 20, 7)]))
	await settle(panel)
	var meters := _meters(panel)
	assert_eq(meters.size(), 1, "HP の行が、情報の枠と同じ部品になっていない")
	assert_eq(meters[0].texts(), [Text.t("deck.sheet.hp"), "5", Text.t("deck.sheet.loss", {"amount": 7})])
	assert_false(panel.shown_text().contains("残り"), "HP の行が文のまま: %s" % panel.shown_text())
	panel.free()


func test_heal_defeat_and_blocked_rows() -> void:
	var panel := _panel()
	panel.show_summary("回復", _summary([_row(8, 13, 20, -1, 5)]))
	assert_eq(_meters(panel)[0].texts()[2], Text.t("deck.sheet.gain", {"amount": 5}))
	panel.show_summary("攻撃", _summary([_row(4, 0, 20, 4)]))
	assert_eq(_meters(panel).back().texts()[1], "0")
	panel.show_summary("攻撃", _summary([_row(9, 9, 20, 0)]))
	assert_eq(_meters(panel).back().texts()[2], Text.t("battle.forecast.hp_same"))
	panel.free()


func test_width_does_not_follow_the_contents() -> void:
	var panel := _panel()
	await settle(panel)  # 木に入れてから中身を出す（木の外では、テーマが違う大きさになる）
	panel.show_summary("攻撃", _summary([] as Array[ForecastText.Row]))
	await settle(panel)
	var width: float = panel.size.x
	var cases: Array = [
		[_row(12, 5, 20, 7)],
		[_row(99, 0, 120, 99)],
		[_row(1, 120, 120, -1, 119)],
		[_row(9, 9, 20, 0), _row(15, 3, 18, 12)],
	]
	for rows: Array in cases:
		var typed: Array[ForecastText.Row] = []
		typed.assign(rows)
		panel.show_summary("攻撃", _summary(typed))
		await settle(panel)
		assert_eq(panel.size.x, width, "中身で幅が変わった: %s" % panel.shown_text().replace("\n", " / "))
	panel.free()
