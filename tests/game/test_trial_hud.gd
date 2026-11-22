extends "res://tests/base_test.gd"
## 試しの決まりの、対戦の画面の枠（game/battle_hud.gd）: 拠点の札、対戦の始めの知らせ、作戦の説明の枠と手札のボタン。
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
	hud.set_stronghold([6, 6] as Array[int], 6, 0, "")
	await settle(hud)
	var row := hud._stronghold_panel.get_child(0) as Control
	assert_true(row.get_combined_minimum_size().x + 20.0 <= BattleHud.STRONGHOLD_CHIP_SIZE.x,
		"拠点の札の中身が収まらない: %s" % row.get_combined_minimum_size())
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


func test_tactic_note_and_buttons_keep_their_size() -> void:
	var hud := _hud()
	await settle(hud)
	hud.set_tactic_buttons([["強行軍", true, "強行軍: 短い", false], ["補給", true, "補給: 短い", false]])
	await settle(hud)
	var before := hud.tactic_sizes()
	assert_eq(hud.tactic_note_text(), "", "乗せていなければ出さない")
	hud.hover_tactic(1)
	assert_eq(hud.tactic_note_text(), "補給: 短い")
	var long_note := "加護: " + "将にバリア".repeat(14)
	hud.set_tactic_buttons([["もう一度押して発動", true, long_note, true], ["補給（使用済み）", false, "補給: 短い", false]])
	await settle(hud)
	assert_eq(hud.tactic_note_text(), long_note, "確かめている札の説明を、乗せている札より先に出す")
	assert_eq(hud.tactic_sizes(), before, "文で大きさが変わった")
	assert_eq(before[0], BattleHud.TACTIC_NOTE_SIZE)
	hud.hover_tactic(-1)
	hud.set_tactic_buttons([["強行軍", true, "強行軍: 短い", false], ["補給", true, "補給: 短い", false]])
	hud.flash_tactic_note("赤の作戦「補給」: 軍の全員が 8 回復")
	assert_eq(hud.tactic_note_text(), "赤の作戦「補給」: 軍の全員が 8 回復", "使われた札を知らせる")
	hud.free()
