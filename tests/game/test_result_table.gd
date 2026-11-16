extends "res://tests/base_test.gd"
## 決着の画面の、詳しい戦績の表の列の幅（game/result_screen.gd）。どの駒の名前も、見出しも、列に収まって切れないこと。

const ResultScreen := preload("res://game/result_screen.gd")
const StatsText := preload("res://game/stats_text.gd")
const Names := preload("res://game/names.gd")
const Text := preload("res://game/text.gd")
const UiTheme := preload("res://game/ui_theme.gd")


func _width(text: String, font_size: int) -> float:
	return UiTheme.FONT_BODY.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


func test_every_evolved_name_fits_the_name_column_with_the_mvp_mark() -> void:
	for id: Evolution.Id in Evolution.Id.values():
		if id == Evolution.Id.NONE:
			continue
		var name := "★ " + Text.t("stats.unit_evolved", {"kind": Names.kind(Evolution.origin(id)), "evolution": Names.evolution(id), "level": Growth.MAX_LEVEL})
		assert_true(_width(name, ResultScreen.TABLE_NAME_FONT) <= ResultScreen.TABLE_NAME_WIDTH, "%s が駒の列に収まらない" % name)


func test_every_column_heading_fits_its_column() -> void:
	for spec: Array in StatsText.COLUMNS:
		var heading := Text.t(spec[1])
		assert_true(_width(heading, ResultScreen.TABLE_HEADING_FONT) <= ResultScreen.TABLE_NUMBER_WIDTH, "見出し「%s」が列に収まらない" % heading)
