extends "res://tests/base_test.gd"
## 対戦の画面の文（game/battle_texts.gd）: 下の帯の説明、メニュー、マスの説明、駒の状態、必殺技のボタン。

const Maps := preload("res://tests/support/maps.gd")
const BattleTexts := preload("res://game/battle_texts.gd")
const Mode := BattleTexts.Mode

const P1 := Unit.Side.PLAYER1
const P2 := Unit.Side.PLAYER2


func _battle() -> Battle:
	return Maps.battle([
		".....",
		".F.B.",
		".....",
	])


func test_plain_cell_is_just_its_title() -> void:
	var battle := _battle()
	assert_eq(BattleTexts.cell_notes(battle, Vector2i(0, 0)), [BattleTexts.nothing_special()] as Array[String])
	assert_eq(BattleTexts.cell_line(battle, Vector2i(0, 0)), "マス (0, 0)　平地")


func test_forest_and_barrel_explain_themselves() -> void:
	var battle := _battle()
	assert_eq(BattleTexts.cell_title(battle, Vector2i(1, 1)), "マス (1, 1)　森", "見出しに地形の説明まで入れた")
	assert_true(BattleTexts.cell_line(battle, Vector2i(1, 1)).contains("移動 2"))
	var body := BattleTexts.cell_body(battle, Vector2i(3, 1))
	assert_true(body.begins_with("起爆樽\n　"), "名前の行と、字下げした説明の行に分けない: " + body)



func test_portal_says_where_it_sends() -> void:
	var battle := Maps.battle([
		"1...1",
	])
	var notes := BattleTexts.cell_notes(battle, Vector2i(0, 0))
	assert_eq(notes, ["ポータル → (4, 0)（止まると、駒のそばのメニューの「転移」で対のポータルへ移れる。移動力は使わない）"] as Array[String])
	var body := BattleTexts.cell_body(battle, Vector2i(0, 0))
	assert_true(body.contains("\n　止まると、駒のそばのメニューの「転移」で"), "転送の説明を行に分けていない: " + body)
	battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(4, 0))
	notes = BattleTexts.cell_notes(battle, Vector2i(0, 0))
	assert_eq(notes, ["ポータル → (4, 0)（止まると、駒のそばのメニューの「転移」で対のポータルへ移れる。移動力は使わない。行き先に駒がいて、いまは使えない）"] as Array[String],
		"行き先がふさがっていることを書いていない")

func test_hint_follows_the_state() -> void:
	var battle := _battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(4, 2))
	assert_true(BattleTexts.hint(battle, null, null, Mode.NONE, false, false, false).begins_with("駒をクリックして選ぶ"))
	assert_eq(BattleTexts.hint(battle, sniper, null, Mode.NONE, true, false, false), "相手（CPU）の番")
	assert_true(BattleTexts.hint(battle, sniper, null, Mode.ATTACK, false, false, false).begins_with("攻撃:"))
	assert_true(BattleTexts.hint(battle, sniper, null, Mode.NONE, false, true, false).begins_with("もう一度押すと必殺技"))
	# ターン終了の確かめの理由（まだ行動していない駒の数）は、ボタンでなく下の帯に出す。
	var unacted := BattleTexts.hint(battle, sniper, null, Mode.NONE, false, false, false, 2)
	assert_true(unacted.contains("2 体") and unacted.contains("右クリックでやめる"), unacted)
	var seen := BattleTexts.hint(battle, sniper, paladin, Mode.NONE, false, false, false)
	assert_true(seen.contains("を見ている") and seen.contains("選んでいる駒へ戻る"), seen)
	assert_true(BattleTexts.hint(battle, sniper, null, Mode.NONE, false, false, false).begins_with("青: 移動"))


func test_menu_lists_only_what_can_be_done() -> void:
	var battle := _battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	var ids: Array = []
	for item: Array in BattleTexts.menu_items(battle, sniper, Mode.NONE, false, false, true):
		ids.append(item[0])
	assert_eq(ids, [BattleTexts.MENU_SKILL, BattleTexts.MENU_WAIT], "攻撃できないのに攻撃を出した（か、スキル・待機が無い）")
	var choosing := BattleTexts.menu_items(battle, sniper, Mode.SKILL, false, false, true)
	assert_eq(choosing, [[BattleTexts.MENU_BACK, "やめる", true]], "対象を選ぶ途中は「やめる」だけ")
	var enemy := battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(4, 0))
	assert_eq(BattleTexts.menu_items(battle, enemy, Mode.NONE, true, false, true), [], "相手の駒にメニューを出した")
	var warp := BattleTexts.menu_items(battle, sniper, Mode.NONE, false, false, true, Vector2i(3, 0))
	assert_eq(warp[0], [BattleTexts.MENU_WARP, "転移", true], "転移できるなら、いちばん上に「転移」")


func test_every_menu_item_has_a_note() -> void:
	var battle := _battle()
	var priest := battle.add_unit(UnitKind.Id.PRIEST, P1, Vector2i(0, 0))
	for id: StringName in [BattleTexts.MENU_ATTACK, BattleTexts.MENU_HEAL, BattleTexts.MENU_SKILL, BattleTexts.MENU_WAIT, BattleTexts.MENU_UNDO, BattleTexts.MENU_BACK, BattleTexts.MENU_WARP]:
		assert_ne(BattleTexts.menu_note(id, priest), "", "項目 %s に説明が無い" % id)


func test_skill_button_gives_the_reason_it_cannot_be_used() -> void:
	var battle := _battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	assert_eq(BattleTexts.skill_button_text(sniper, false), "スキル（いまは使えない）")
	sniper.skill_cooldown = 2
	assert_eq(BattleTexts.skill_button_text(sniper, true), "スキル（あと 2 ターン）")


func test_unit_state_only_for_the_side_to_move() -> void:
	var battle := _battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(1, 1))
	var enemy := battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(4, 0))
	assert_eq(BattleTexts.unit_state(battle, sniper), "未行動\nいるマス: 森（移動 2・受けるダメージ 0.8 倍）")
	assert_eq(BattleTexts.unit_state(battle, enemy), "", "相手の駒に行動の状態を出した")


func test_ult_button_without_an_ult() -> void:
	var battle := _battle()
	assert_eq(BattleTexts.ult_button_text(battle, P1, false), "必殺技（なし）")
