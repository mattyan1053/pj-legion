extends "res://tests/base_test.gd"
## 会話の場面（game/talk_screen.gd）。

const TalkScreen := preload("res://game/talk_screen.gd")
const Story := preload("res://game/story.gd")
const Episode := preload("res://game/episode.gd")
const Campaign := preload("res://game/campaign.gd")
const UiTheme := preload("res://game/ui_theme.gd")


## 話の流れの外の会話（"battle" の無いもの。物語の解放の知らせを出すときなど）も、開いて最初の行を出す。
## 背景の盤に立たせる駒が無いだけで、ほかは同じ。
func test_talk_without_a_battle_opens() -> void:
	var episode: RefCounted = Story.military().episodes[0]
	var screen := TalkScreen.new()
	screen.talk = Story.talk_of(episode, [Story.Episode.TalkLine.speech(0, "はじめの台詞", 0)] as Array[Story.Episode.TalkLine])
	await settle(screen)
	assert_eq(screen.speaker(), episode.speakers[0], "最初の行の話し手が出ない（_ready が途中で止まった）")
	assert_true(screen.is_scenery_only(), "兵を立たせない背景に、マス目の線が出ている")
	screen.free()


## 選択肢（docs/story.md の「選択肢」）の会話: 問い → 答え 2 つ（それぞれに続く行）→ 元の流れ → 条件の行。
func _asking_talk() -> Dictionary:
	var when_a := {"choice": &"way", "answer": &"a", "not": false}
	var when_b := {"choice": &"way", "answer": &"b", "not": false}
	return {"title": "", "figures": [{"kind": UnitKind.Id.KING}, {"kind": UnitKind.Id.KING}], "lines": [
		{"side": 0, "name": "新兵", "text": "どちらへ？", "choice": {"name": &"way", "options": [{"key": &"a", "text": "左"}, {"key": &"b", "text": "右へ急ぐ"}]}},
		{"side": 0, "who": 1, "name": "少尉", "text": "左だ。", "when": when_a},
		{"side": 0, "who": 1, "name": "少尉", "text": "右だ。", "when": when_b},
		{"side": 0, "name": "新兵", "text": "走るんですね。", "when": when_b},
		{"side": 0, "name": "少尉", "text": "行くぞ。"},
		{"side": 0, "name": "新兵", "text": "左で正解でした。", "when": when_a},
	]}


func _asking_screen() -> Node:
	var context := preload("res://game/app_context.gd").new()
	context.story = Story.new()
	var screen := TalkScreen.new()
	screen.context = context
	screen.talk = _asking_talk()
	await settle(screen)
	return screen


func test_a_choice_asks_and_branches_then_returns_to_the_flow() -> void:
	var screen: Node = await _asking_screen()
	screen.press_next()  # 文を出しきる
	assert_true(screen.is_asking(), "問いの行を出しきると、答えが出る")
	assert_eq(screen.option_texts(), ["左", "右へ急ぐ"] as Array[String])
	screen.press_next()
	screen.press_skip()
	assert_true(screen.line_index() == 0 and screen.is_asking(), "選ぶまで、クリックでも「スキップ」でも進まない")
	screen.press_option(1)
	assert_false(screen.is_asking())
	assert_eq([screen.line_index(), screen.line_text()], [1, "右だ。"], "選んだ答えに続く行へ")
	assert_eq(screen.context.story.answer_of(&"way"), "b", "選んだ答えを覚える")
	assert_eq(screen.line_count(), 4, "右の 2 行と、元の流れの 1 行（左を選んだときだけの行は出ない）")
	screen.press_next()
	screen.press_next()
	screen.press_next()
	screen.press_next()
	assert_eq(screen.line_text(), "行くぞ。", "元の流れに戻る")
	# ログに、選んだ答えが 1 行で残る。
	screen.open_log()
	await settle(screen)
	assert_eq(screen.talk_log().row_texts(), [["新兵", "どちらへ？"], ["選択", "右へ急ぐ"], ["少尉", "右だ。"], ["新兵", "走るんですね。"], ["少尉", "行くぞ。"]])
	screen.talk_log().close()
	# 問いの行まで戻れば、選び直せる。
	for i in 3:
		screen.press_back()
	assert_true(screen.line_index() == 0 and screen.is_asking(), "問いの行へ戻ると、また選ばせる")
	screen.press_option(0)
	assert_eq([screen.line_text(), screen.line_count(), screen.context.story.answer_of(&"way")], ["左だ。", 4, "a"])
	screen.free()


func test_a_choice_is_picked_with_keys_and_skip_stops_at_it() -> void:
	var screen: Node = await _asking_screen()
	screen.talk["lines"].push_front({"side": 0, "name": "少尉", "text": "着いた。"})
	screen._refresh_lines()
	screen._show_line(0)
	screen.press_skip()
	assert_true(screen.line_index() == 1 and screen.is_asking(), "「スキップ」は、選ばせる行で止まる")
	for code: Key in [KEY_ENTER, KEY_DOWN, KEY_DOWN, KEY_DOWN, KEY_UP]:
		_key(screen, code)
	assert_true(screen.is_asking() and screen._option_at == 1, "Enter だけでは選ばない。上下の矢印で印が動く（端で回る）")
	_key(screen, KEY_ENTER)
	assert_eq(screen.context.story.answer_of(&"way"), "b")
	screen.press_back()
	_key(screen, KEY_1)
	assert_eq(screen.context.story.answer_of(&"way"), "a", "数字のキーでも選べる")
	screen.free()


func _key(screen: Node, code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	screen._unhandled_input(event)


## 選択肢の枠は、答えの数や長さで大きさを変えない。いちばん長い答え（22 字）もボタンに収まり、画面からはみ出さない。
func test_the_options_frame_keeps_its_size() -> void:
	var screen: Node = await _asking_screen()
	screen.press_next()
	await settle(screen)
	var small: Rect2 = screen.options_rect()
	var longest := "あ".repeat(Story.Episode.OPTION_MAX_CHARS)
	screen.talk["lines"][0]["choice"]["options"] = [{"key": &"a", "text": longest}, {"key": &"b", "text": longest}, {"key": &"c", "text": longest}]
	screen._refresh_lines()
	screen._show_line(0)
	screen.press_next()
	await settle(screen)
	assert_eq(screen.option_texts().size(), 3)
	assert_eq(screen.options_rect(), small, "答えが 2 つでも 3 つでも、短くても長くても、枠は同じ")
	assert_true(screen.get_viewport().get_visible_rect().encloses(small), "枠が画面からはみ出す: %s" % small)
	var width := UiTheme.FONT_BODY.get_string_size(longest, HORIZONTAL_ALIGNMENT_LEFT, -1, TalkScreen.OPTION_FONT).x
	assert_true(width + 24.0 <= TalkScreen.OPTION_SIZE.x, "いちばん長い答えが、ボタンに 1 行で入らない（要る幅 %d）" % width)
	# 問われている人（答えを選ぶまで、行がどれも出ない）も、選ぶ前から立っている。枠は、左右の姿と重ならない。
	assert_eq(screen.figures().size(), 2, "問われている人が、選ぶ前に立っていない")
	for figure: Control in screen.figures():
		assert_false(figure.get_global_rect().intersects(small), "選択肢の枠が、話し手の姿に重なる: %s / %s" % [figure.get_global_rect(), small])
	screen.free()


## 答えを Enter で決めても、次の文は 1 文字ずつ出る（決めたキーで、次の文まで送らない）。
## 最後の行で答えを選ぶと会話が終わり、答えの枠は出し直さない。ログには、選んだ答えが残る。
func test_the_key_that_picks_an_answer_does_not_also_advance_and_a_last_question_ends_the_talk() -> void:
	var screen: Node = await _asking_screen()
	screen.press_next()
	_key(screen, KEY_DOWN)
	_key(screen, KEY_ENTER)
	assert_true(screen.line_index() == 1 and not screen.is_line_shown(), "答えを決めたキーで、次の文を出しきった")
	screen.free()
	screen = await _asking_screen()
	screen.talk["lines"] = [screen.talk["lines"][0]]
	screen._refresh_lines()
	screen._show_line(0)
	var ended := [0]
	screen.finished.connect(func(_outcome: StringName) -> void: ended[0] += 1)
	screen.press_next()
	screen.press_option(0)
	await settle(screen)
	assert_true(ended[0] == 1 and not screen.is_asking(), "最後の行で選ぶと、会話が終わる（答えの枠を出し直さない）")
	assert_eq(screen._log_lines().size(), 2, "ログに、選んだ答えが残る")
	screen.free()


## カットシーン: 話し手の姿を立てず、地の文を出す。色の幕なら、背景の盤を作らない。クリックで送れて、最後で終わる。
func test_a_cutscene_shows_narration_without_figures() -> void:
	var screen := TalkScreen.new()
	screen.talk = {"title": "見出し", "cut": true, "color": &"night", "lines": [
		{"side": TalkScreen.NARRATION_SIDE, "who": -1, "name": "", "text": "隊は、夜のうちに谷を抜けた。"},
		{"side": TalkScreen.NARRATION_SIDE, "who": -1, "name": "", "text": "だれも、口をきかなかった。"}]}
	await settle(screen)
	assert_true(screen.is_cut() and screen.is_narrating() and screen.figures().is_empty())
	assert_eq(screen.backdrop_units(), [0, 0, 0] as Array[int])
	var bottom: Rect2 = screen.bottom_rect()
	var view: Rect2 = screen.get_viewport().get_visible_rect()
	assert_true(view.encloses(bottom) and absf(bottom.get_center().y - view.get_center().y) < 40.0, "文が画面の真ん中の高さに無い: %s" % bottom)
	# 「ログ」「スキップ」は、会話の場面と同じ所（下の文の枠があるはずの所の右上）。真ん中の文の枠に重ならない。
	var buttons: Rect2 = screen.buttons_rect()
	assert_false(buttons.intersects(bottom), "カットシーンのボタンが、文に重なる: %s / %s" % [buttons, bottom])
	var corner := Vector2(view.get_center().x + TalkScreen.BOX_WIDTH / 2.0, view.end.y - TalkScreen.BOX_BOTTOM - TalkScreen.BOX_HEIGHT - TalkScreen.PLATE_GAP)
	assert_true(buttons.end.distance_to(corner) < 1.5, "カットシーンのボタンが、会話の場面と同じ所に無い: %s / %s" % [buttons.end, corner])  # 半端な高さの窓では 1px 丸まる
	var ended := [0]
	screen.finished.connect(func(_outcome: StringName) -> void: ended[0] += 1)
	for i in 4:
		screen.press_next()
	assert_eq(ended[0], 1)
	screen.free()


## 盤のカットシーン（docs/story.md の「盤のカットシーン」）: 兵が動いている間は文を進めず、文の間は盤が止まる。
## 盤の動きをまたいで前の文へは戻れない。スキップで、終わりの盤まで済ませて終える。舞台を作って再生するので、長い検査。
func test_long_board_cutscene_alternates_moves_and_lines() -> void:
	var episode: Episode = Campaign.load_file("res://game/story/_template/story.txt").episodes[1]
	var run := Story.run_of(episode, Story.default_deck(Story.starting()))
	while not run.data().has("cut_board"):
		run.advance()
	var screen := TalkScreen.new()
	screen.talk = run.data()
	await settle(screen)
	assert_true(screen.is_board_cut() and screen.figures().is_empty(), "盤のカットシーンは、話し手の姿を立たせない")
	assert_eq(screen.cut_stage().views().size(), 3, "台本の兵が立つ")
	assert_false(screen.is_beat_playing(), "最初の文の前に動きが無ければ、すぐ文")
	assert_eq(screen.cut_stage().speaker, "", "地の文では、話し手の印を出さない")
	var scale := Engine.time_scale
	Engine.time_scale = 50.0
	_next_line(screen)
	assert_true(screen.is_beat_playing(), "次の文の前の動きを再生する")
	assert_eq(screen.cut_stage().speaker, "", "兵が動いている間は、話し手の印を出さない")
	screen.press_next()
	assert_eq(screen.line_index(), 0, "動いている間は、文を進めない")
	assert_eq(screen._log_lines().size(), 1, "動いている間のログは、動きの前の文まで")
	while screen.is_beat_playing():
		await (Engine.get_main_loop() as SceneTree).process_frame
	assert_eq(screen.line_index(), 1, "動き終えたら、次の文")
	assert_eq(screen.cut_stage().speaker, "新兵", "盤にいる話し手の頭の上に印")
	screen.press_back()
	assert_eq(screen.line_index(), 1, "盤の動きをまたいで、前の文へは戻らない")
	_next_line(screen)
	assert_eq(screen.line_index(), 2, "動きの無い文の間は、そのまま進む")
	screen.press_back()
	assert_eq(screen.line_index(), 1, "動きの無い文の間は、戻れる")
	var ended := [0]
	screen.finished.connect(func(_outcome: StringName) -> void: ended[0] += 1)
	await screen.press_skip()
	Engine.time_scale = scale
	assert_eq(ended[0], 1, "スキップで終える")
	var replay: RefCounted = screen.cut_stage().replay()
	var names: Dictionary = run.data()["cut_board"].names
	assert_true(replay.piece(names["骸骨"]) == null and replay.piece(names["新兵"]).cell == Vector2i(9, 17), "スキップで、終わりの盤まで済ませる")
	assert_eq(screen.cut_stage().views().size(), 2, "見た目も、終わりの盤")
	screen.free()


## 次の文へ（文が出きる前なら、出しきってから）。
func _next_line(screen: Node) -> void:
	if not screen.is_line_shown():
		screen.press_next()
	screen.press_next()
