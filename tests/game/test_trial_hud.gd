extends "res://tests/base_test.gd"
## 選べる決まりの、対戦の画面の枠（game/battle_hud.gd）: 拠点の札、対戦の始めの知らせ。
## どれも大きさは中身で変えない（CLAUDE.md の人間の決定。11/22）。

const BattleHud := preload("res://game/battle_hud.gd")
const Palette := preload("res://game/ui_palette.gd")


func _hud() -> BattleHud:
	var hud := BattleHud.new()
	hud.setup([Palette.TEAM_BLUE, Palette.TEAM_RED] as Array[Color])
	return hud


func test_stronghold_chip_keeps_its_size_whatever_the_holds() -> void:
	var hud := _hud()
	await settle(hud)
	hud.set_stronghold([0, 0] as Array[int], 6, -1, "")
	await settle(hud)
	var before := hud.stronghold_chip_size()
	assert_eq(before, BattleHud.STRONGHOLD_CHIP_SIZE)
	assert_eq(hud.stronghold_text(), "拠点 青 ○○○○○○ 赤 ○○○○○○")
	assert_false(hud.stronghold_urgent())
	hud.set_stronghold([5, 0] as Array[int], 6, 0, "あと 1 回")
	await settle(hud)
	assert_eq(hud.stronghold_chip_size(), before)
	assert_eq(hud.stronghold_text(), "拠点 青 ●●●●●○ 赤 ○○○○○○")
	assert_true(hud.stronghold_urgent())
	hud.set_stronghold([0, 0] as Array[int], 0, -1, "")
	assert_eq(hud.stronghold_text(), "", "拠点の無い対戦では出さない")
	hud.free()


## 中身が枠に収まる（はみ出して切れない）。
func test_stronghold_chip_fits_its_content() -> void:
	var hud := _hud()
	await settle(hud)
	var needed := Stronghold.HOLDS_TO_WIN
	hud.set_stronghold([needed, needed] as Array[int], needed, 0, "")
	await settle(hud)
	var row := hud._stronghold_panel.get_child(0) as Control
	assert_true(row.get_combined_minimum_size().x + 20.0 <= BattleHud.STRONGHOLD_CHIP_SIZE.x,
		"拠点の札の中身が収まらない: %s" % row.get_combined_minimum_size())
	assert_eq(hud.stronghold_chip_size(), BattleHud.STRONGHOLD_CHIP_SIZE)
	hud.free()


func test_notice_keeps_its_size_and_fits_three_rules() -> void:
	var hud := _hud()
	await settle(hud)
	hud.show_notice(["1 行"] as Array[String])
	await settle(hud)
	var before := hud.notice_rect().size
	assert_eq(before, BattleHud.NOTICE_SIZE)
	var long_line := "あいうえおかきくけこ".repeat(5)  # 2 行に折り返す
	hud.show_notice([long_line, long_line, long_line] as Array[String])
	await settle(hud)
	assert_eq(hud.notice_rect().size, before)
	var column := hud._notice.get_child(0) as Control
	assert_true(column.get_combined_minimum_size().y + 28.0 <= BattleHud.NOTICE_SIZE.y,
		"知らせの中身が収まらない: %s" % column.get_combined_minimum_size())
	hud.hide_notice()
	assert_eq(hud.notice_text(), "")
	hud.free()
