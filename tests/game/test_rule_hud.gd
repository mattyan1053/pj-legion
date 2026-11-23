extends "res://tests/base_test.gd"
## 対戦の画面の枠（game/battle_hud.gd）: 拠点の札、対戦の始めの「対戦ルール」。
## どれも大きさは中身で変えない（CLAUDE.md の人間の決定。11/22）。

const BattleHud := preload("res://game/battle_hud.gd")
const Palette := preload("res://game/ui_palette.gd")
const Text := preload("res://game/text.gd")
const BattleTexts := preload("res://game/battle_texts.gd")


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


## 「対戦ルール」: 札の数（勝利条件 1〜3 枚、縫い目の様子 0〜2 枚）で枠の大きさを変えず、中身が収まり、どの札の説明も切れない。
func test_notice_keeps_its_size_and_fits_any_cards() -> void:
	var hud := _hud()
	await settle(hud)
	var sizes := {}
	var goals: Array[int] = [GameWonEvent.Reason.KING_DEFEATED, GameWonEvent.Reason.HQ_CAPTURED, GameWonEvent.Reason.STRONGHOLD_HELD,
		GameWonEvent.Reason.TURNS_HELD, GameWonEvent.Reason.ROUTED, GameWonEvent.Reason.BOSS_SLAIN]
	for goal_count: int in [1, 2, 3]:
		for sign_count: int in [0, 2]:
			var cards: Array[Array] = []
			for i in goal_count:
				cards.append([&"goal", goals[i], "名前", "3 ターン、敵の本陣を占拠し続ける"])
			for i in sign_count:
				cards.append([&"sign", i, "名前", "森にいる駒が受けるダメージ 0.6 倍"])
			hud.show_notice(cards)
			await settle(hud)
			sizes[hud.notice_rect().size] = true
			var column := hud._notice.get_child(0) as Control
			assert_true(column.get_combined_minimum_size().y + 28.0 <= BattleHud.NOTICE_SIZE.y,
				"中身が収まらない（勝利条件 %d・様子 %d）: %s" % [goal_count, sign_count, column.get_combined_minimum_size()])
			assert_eq(hud.notice_cut_texts(), [] as Array[String])
			assert_eq(hud.notice_text().split("\n").size(), goal_count + sign_count)
	assert_eq(sizes.keys(), [BattleHud.NOTICE_SIZE])
	hud.hide_notice()
	assert_eq(hud.notice_text(), "")
	hud.free()


## 対戦の始めの「対戦ルール」の札: 人の側から見た、いま効いている勝利条件（並びは WinText.ORDER）と縫い目の様子。
func test_rule_cards_list_the_live_win_conditions() -> void:
	var board := preload("res://tests/support/maps.gd").board(["1...", "...2"])
	var battle := Battle.new(board)
	battle.win_conditions = [Scenario.STANDARD_WIN_CONDITIONS.duplicate(), Scenario.STANDARD_WIN_CONDITIONS.duplicate()]
	var cards := BattleTexts.rule_cards(battle, Unit.Side.PLAYER1)
	assert_eq(cards.map(func(card: Array) -> int: return card[1]), [GameWonEvent.Reason.KING_DEFEATED, GameWonEvent.Reason.HQ_CAPTURED])
	assert_eq(cards[0][2], "将の撃破")
	# 将の撃破の無い話（全滅だけ）でも成り立つ。相手が守り切る戦いは「時間の限り」が付く。
	battle.win_conditions = [[GameWonEvent.Reason.ROUTED], [GameWonEvent.Reason.KING_DEFEATED, GameWonEvent.Reason.TURNS_HELD]]
	battle.hold_turns = 10
	cards = BattleTexts.rule_cards(battle, Unit.Side.PLAYER1)
	assert_eq(cards.map(func(card: Array) -> int: return card[1]), [GameWonEvent.Reason.ROUTED, GameWonEvent.Reason.TURNS_HELD])
	assert_true(cards[1][3].contains("10"), cards[1][3])
	cards = BattleTexts.rule_cards(battle, Unit.Side.PLAYER2)
	assert_eq(cards.map(func(card: Array) -> int: return card[1]), [GameWonEvent.Reason.TURNS_HELD, GameWonEvent.Reason.KING_DEFEATED])


## 実際の札の文（どの勝利条件も、どの縫い目の様子も）が、札の欄に収まる（説明は 2 行まで）。
func test_every_real_card_text_fits() -> void:
	const RuleCard := preload("res://game/rule_card.gd")
	const Names := preload("res://game/names.gd")
	var card := RuleCard.new()
	await settle(card)
	var args := {"turns": 10, "capture": Battle.CAPTURE_TURNS_TO_WIN, "holds": Stronghold.HOLDS_TO_WIN}
	for reason: int in GameWonEvent.Reason.values():
		var word := String(GameWonEvent.Reason.find_key(reason)).to_lower()
		card.show_goal(reason, Text.t("battle.goal.name." + word), Text.t("battle.goal.win." + word, args))
		await settle(card)
		assert_true(card.fits(), card.shown_text())
	card.show_goal(GameWonEvent.Reason.TURNS_HELD, Text.t("battle.goal.name.deadline"), Text.t("battle.goal.deadline", args))
	await settle(card)
	assert_true(card.fits(), card.shown_text())
	for sign: int in Seam.Sign.values():
		card.show_sign(sign, Names.sign_name(sign), Names.sign_summary(sign))
		await settle(card)
		assert_true(card.fits(), card.shown_text())
		assert_eq(card.size, RuleCard.SIZE)
	card.free()


## 番人の名前がいちばん長い（Maps.BOSS_NAME_MAX 字）ときも、「〜の撃破」の名前が札の欄で切れない。枠の大きさは変わらない。
func test_longest_boss_name_fits_the_card() -> void:
	const RuleCard := preload("res://game/rule_card.gd")
	const Maps := preload("res://game/maps.gd")
	var card := RuleCard.new()
	await settle(card)
	var before: Variant = Text.shared.get("boss")
	Text.shared["boss"] = "縫".repeat(Maps.BOSS_NAME_MAX)
	card.show_goal(GameWonEvent.Reason.BOSS_SLAIN, Text.t("battle.goal.name.boss_slain"), Text.t("battle.goal.win.boss_slain"))
	await settle(card)
	assert_true(card.fits(), card.shown_text())
	var name_label: Label = card._name
	var width := name_label.get_theme_font("font").get_string_size(name_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, name_label.get_theme_font_size("font_size")).x
	assert_true(width <= RuleCard.SIZE.x - RuleCard.MARK_SIDE - 40.0, "名前が切れる: %s（%.0f px）" % [name_label.text, width])
	assert_eq(card.size, RuleCard.SIZE)
	# 短い名前は、もとの大きさのまま。
	card.show_goal(GameWonEvent.Reason.KING_DEFEATED, Text.t("battle.goal.name.king_defeated"), Text.t("battle.goal.win.king_defeated"))
	await settle(card)
	assert_true(card.fits(), card.shown_text())
	if before == null:
		Text.shared.erase("boss")
	else:
		Text.shared["boss"] = before
	card.free()
