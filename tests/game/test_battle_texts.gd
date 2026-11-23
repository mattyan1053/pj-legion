extends "res://tests/base_test.gd"
## 対戦の画面の文（game/battle_texts.gd）: 下の帯の案内、メニュー、マスの説明、駒の状態、必殺技のボタン。

const Maps := preload("res://tests/support/maps.gd")
const BattleTexts := preload("res://game/battle_texts.gd")
const BattleHud := preload("res://game/battle_hud.gd")
const KeyMarks := preload("res://game/key_marks.gd")
const UiTheme := preload("res://game/ui_theme.gd")
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
	assert_eq(notes, ["ポータル → (4, 0)（止まると、駒のそばのメニューの「転移」で対のポータル（同じ色の印）へ移れる。移動力は使わず、残りで続けて動ける）"] as Array[String])
	var body := BattleTexts.cell_body(battle, Vector2i(0, 0))
	assert_true(body.contains("\n　止まると、駒のそばのメニューの「転移」で"), "転送の説明を行に分けていない: " + body)
	battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(4, 0))
	notes = BattleTexts.cell_notes(battle, Vector2i(0, 0))
	assert_eq(notes, ["ポータル → (4, 0)（止まると、駒のそばのメニューの「転移」で対のポータルへ移れる。移動力は使わず、残りで続けて動ける。行き先に駒がいて、いまは使えない）"] as Array[String],
		"行き先がふさがっていることを書いていない")

## 下の帯の案内を 1 行の文にしたもの（key_marks.gd の parts_text と同じ形）。
func _guide(battle: Battle, unit: Unit, inspected: Unit, mode: Mode, cpu_turn := false, confirming := false, unacted := 0, pinned := 0) -> String:
	var marks := KeyMarks.new()
	marks.set_parts(BattleTexts.guide(battle, unit, inspected, mode, cpu_turn, confirming, unacted, pinned))
	var text := marks.parts_text()
	marks.free()
	return text


## 下の帯の案内は、短い句と、キーの印・色の印だけ。分かりきった場面では何も出さない（docs/wording.md の決まり 1）。
func test_guide_follows_the_state() -> void:
	var battle := _battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	var paladin := battle.add_unit(UnitKind.Id.PALADIN, P2, Vector2i(4, 2))
	assert_eq(_guide(battle, null, null, Mode.NONE), "", "駒を選ぶ前に、操作を教えている")
	assert_eq(_guide(battle, sniper, null, Mode.NONE, true), "", "相手の番（ターン終了のボタンに出ている）")
	assert_eq(_guide(battle, sniper, null, Mode.ATTACK), "対象を選択  [右クリック] キャンセル")
	assert_eq(_guide(battle, sniper, null, Mode.SKILL), "対象を選択  [右クリック] キャンセル")
	assert_eq(_guide(battle, sniper, null, Mode.NONE, false, true), "[右クリック] キャンセル", "必殺技・おまかせの確かめ")
	# ターン終了の確かめの理由（まだ行動していない駒の数）は、ボタンでなく下の帯に出す。
	assert_eq(_guide(battle, sniper, null, Mode.NONE, false, false, 2), "未行動 2 体  [右クリック] キャンセル")
	assert_eq(_guide(battle, sniper, paladin, Mode.NONE), "* 移動  * 攻撃  [右クリック] 戻る", "相手の駒を見ている")
	assert_eq(_guide(battle, sniper, sniper, Mode.NONE, false, false, 0, 1), "* 移動  * 表示中  [右クリック] 戻る")
	assert_eq(_guide(battle, null, null, Mode.NONE, false, false, 0, 1), "* 表示中  [右クリック] 解除")
	assert_eq(_guide(battle, sniper, null, Mode.NONE), "* 移動  * 巡航  * 攻撃")
	var priest := battle.add_unit(UnitKind.Id.PRIEST, P1, Vector2i(0, 2))
	assert_eq(_guide(battle, priest, null, Mode.NONE), "* 移動  * 巡航  * 回復")
	assert_eq(_guide(battle, paladin, null, Mode.NONE), "* 移動  * 攻撃", "相手の駒を選んでいる")
	sniper.has_moved = true
	sniper.move_origin = Vector2i(0, 0)
	sniper.cell = Vector2i(2, 0)
	assert_eq(_guide(battle, sniper, null, Mode.NONE), "[右クリック] 取り消し", "動いたあと")
	# どの場面の文にも、文末の「。」と、です・ます調が無い。
	for text: String in [_guide(battle, sniper, null, Mode.ATTACK), _guide(battle, sniper, null, Mode.NONE, false, false, 2)]:
		assert_false(text.contains("。") or text.contains("ます"), text)


func test_menu_lists_only_what_can_be_done() -> void:
	var battle := _battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	var ids: Array = []
	for item: Array in BattleTexts.menu_items(battle, sniper, Mode.NONE, false, false, true):
		ids.append(item[0])
	assert_eq(ids, [BattleTexts.MENU_SKILL, BattleTexts.MENU_WAIT], "攻撃できないのに攻撃を出した（か、スキル・待機が無い）")
	var choosing := BattleTexts.menu_items(battle, sniper, Mode.SKILL, false, false, true)
	assert_eq(choosing, [[BattleTexts.MENU_BACK, "キャンセル", true]], "対象を選ぶ途中は「キャンセル」だけ")
	var enemy := battle.add_unit(UnitKind.Id.SNIPER, P2, Vector2i(4, 0))
	assert_eq(BattleTexts.menu_items(battle, enemy, Mode.NONE, true, false, true), [], "相手の駒にメニューを出した")
	var warp := BattleTexts.menu_items(battle, sniper, Mode.NONE, false, false, true, Vector2i(3, 0))
	assert_eq(warp[0], [BattleTexts.MENU_WARP, "転移", true], "転移できるなら、いちばん上に「転移」")


## 押すと何が起きるかを添えるのは、名前だけでは分からない項目。名前で分かる項目（待機・移動を取り消す・キャンセル）には添えない。
func test_menu_notes_only_where_the_name_is_not_enough() -> void:
	var battle := _battle()
	var priest := battle.add_unit(UnitKind.Id.PRIEST, P1, Vector2i(0, 0))
	for id: StringName in [BattleTexts.MENU_ATTACK, BattleTexts.MENU_HEAL, BattleTexts.MENU_SKILL, BattleTexts.MENU_WARP]:
		var note := BattleTexts.menu_note(id, priest)
		assert_ne(note, "", "項目 %s に説明が無い" % id)
		assert_false(note.contains("する。") or note.contains("できる"), "説明書の調子: %s" % note)
	for id: StringName in [BattleTexts.MENU_WAIT, BattleTexts.MENU_UNDO, BattleTexts.MENU_BACK]:
		assert_eq(BattleTexts.menu_note(id, priest), "", "項目 %s は、名前で分かる" % id)


## 左下の枠のスキルの状態は、メニューと同じに、動いたら使えない（精密照準）ことまで見る（Issue #46）。
func test_skill_state_matches_the_menu_after_moving() -> void:
	var battle := _battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	assert_eq(BattleHud.skill_state_text(sniper, battle), "使用可")
	sniper.has_moved = true
	sniper.move_origin = Vector2i(0, 0)
	sniper.cell = Vector2i(2, 0)
	assert_eq(BattleHud.skill_state_text(sniper, battle), "使用不可", "動いたスナイパーの精密照準を「使用可」と出した")
	assert_eq(BattleTexts.skill_button_text(sniper, Skills.can_use(battle, sniper)), "スキル（使用不可）")
	assert_true(BattleTexts.menu_note(BattleTexts.MENU_SKILL, sniper, battle).contains("使用不可"))
	battle.phase = P2
	assert_eq(BattleHud.skill_state_text(sniper, battle), "使用可", "相手の番に、前の番に動いたことで「使用不可」と出した")


func test_skill_button_gives_the_reason_it_cannot_be_used() -> void:
	var battle := _battle()
	var sniper := battle.add_unit(UnitKind.Id.SNIPER, P1, Vector2i(0, 0))
	assert_eq(BattleTexts.skill_button_text(sniper, false), "スキル（使用不可）")
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


## 拠点のマスの説明: 下の帯の 1 行は短い説明で、帯に収まる。クリックした枠の説明は、決まりを 2 行で。
func test_stronghold_cell_fits_the_bottom_line_and_the_info_panel() -> void:
	var battle := Maps.battle([
		"1....",
		".....",
		"....2",
	])
	battle.board.stronghold_cell = Vector2i(2, 1)
	var line := BattleTexts.cell_line(battle, Vector2i(2, 1))
	assert_true(line.contains("拠点"))
	var width := UiTheme.FONT_BODY.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	assert_true(width <= 480.0, "下の帯の 1 行に収まらない（%d px）: %s" % [width, line])
	var body := BattleTexts.cell_body(battle, Vector2i(2, 1))
	assert_true(body.contains("%d 回で勝ち" % Stronghold.HOLDS_TO_WIN), body)
	assert_eq(body.split("\n").size(), 4, "見出しの「拠点」と、決まりの 3 文のほかに行がある: " + body)
	for row in body.split("\n"):
		assert_true(UiTheme.FONT_BODY.get_string_size(row, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x <= BattleHud.INFO_WIDTH, "枠の 1 行に収まらない: " + row)
