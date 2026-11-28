extends "res://tests/base_test.gd"
## 見張り（tests/game/test_army_watch.gd）の、部隊編成の画面の側。画面を作るので、長い検査だけで回す。
## 仮の 3 つ目の軍（前衛が 2 種で 5 種、軍略が 4 つ）を足して、部隊編成の欄の並びを見る。

const Watch := preload("res://tests/game/test_army_watch.gd")


## 部隊編成: 雇う欄は 5 つ並び（いつもの 4 枚ぶんの高さに収まる）、軍略の札は 4 枚。同じ画面で 2 軍の部隊を開いても、欄の位置は同じ。
func test_long_the_deck_editor_lays_out_a_third_army() -> void:
	Watch.add_trial()
	var DeckScreen: GDScript = load("res://game/deck_screen.gd")
	var DeckBase: GDScript = load("res://game/deck_screen/deck_base.gd")
	var context: RefCounted = load("res://game/app_context.gd").new()
	context.decks.load_data({"decks": []})
	var screen: Node = DeckScreen.new()
	screen.context = context
	await settle(screen)
	screen.choose_new_army(Watch.TRIAL)
	await settle(screen)
	await settle(screen)
	var trial_rects: Array[Rect2] = screen.roster_slot_rects()
	assert_eq(trial_rects.size(), 5, "雇う欄が 5 つ見えない")
	assert_eq(screen.trait_card_counts(), Vector2i(4, 4), "軍略の札が 4 枚並ばない")
	screen.leave_editor()
	screen.choose_new_army(UnitKind.Army.MILITARY)
	await settle(screen)
	await settle(screen)
	var military_rects: Array[Rect2] = screen.roster_slot_rects()
	assert_eq(military_rects.size(), 4, "2 軍の部隊で、雇う欄が 4 つでない")
	assert_eq(military_rects.map(func(rect: Rect2) -> Vector2: return rect.position), trial_rects.slice(0, 4).map(func(rect: Rect2) -> Vector2: return rect.position), "軍で、雇う欄の位置が変わる")
	var four_slots: float = DeckBase.ROSTER_CARD_HEIGHT * 4 + DeckBase.ROSTER_GAP * 3
	assert_true(trial_rects.back().end.y - trial_rects[0].position.y <= four_slots + 0.5, "5 つの雇う欄が、4 枚ぶんの高さに収まらない")
	assert_eq(screen.trait_card_counts(), Vector2i(4, 3), "2 軍の部隊で、押せる軍略の札が 3 枚でない")
	screen.free()
	Watch.remove_trial()
