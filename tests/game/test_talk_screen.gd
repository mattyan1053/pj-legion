extends "res://tests/base_test.gd"
## 会話の場面（game/talk_screen.gd）。

const TalkScreen := preload("res://game/talk_screen.gd")
const Story := preload("res://game/story.gd")


## 話の流れの外の会話（"battle" の無いもの。物語の解放の知らせを出すときなど）も、開いて最初の行を出す。
## 背景の盤に立たせる駒が無いだけで、ほかは同じ。
func test_talk_without_a_battle_opens() -> void:
	var episode: RefCounted = Story.military().episodes[0]
	var screen := TalkScreen.new()
	screen.talk = Story.talk_of(episode, [[0, "はじめの台詞", 0]])
	await settle(screen)
	assert_eq(screen.speaker(), episode.speakers[0], "最初の行の話し手が出ない（_ready が途中で止まった）")
	screen.free()
