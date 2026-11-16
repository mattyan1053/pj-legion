extends "res://tests/base_test.gd"
## 駒のそばのメニューと駒を結ぶ線（game/battle_hud.gd の place_menu、menu_line_start）。

const BattleHud := preload("res://game/battle_hud.gd")


## 駒が下の帯の後ろにいても、線は帯の上の縁で止まる（帯の文字の上に引かない。Issue #46）。
func test_line_stops_at_the_bottom_bar() -> void:
	var bar_top := 720.0 - BattleHud.BOTTOM_BAR_HEIGHT
	var from := Vector2(400.0, 700.0)
	var near := Vector2(300.0, 300.0)
	var start := BattleHud.menu_line_start(from, near, bar_top)
	assert_between(start.y, bar_top - 0.01, bar_top + 0.01, "線が下の帯にかかる")
	assert_true((from - near).normalized().dot((start - near).normalized()) > 0.9999, "線が駒の方を向いていない")
	assert_eq(BattleHud.menu_line_start(Vector2(600.0, 400.0), near, bar_top), Vector2(600.0, 400.0), "帯の上の駒なのに、線を縮めた")
