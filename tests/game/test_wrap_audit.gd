extends "res://tests/base_test.gd"
## 全部の話の台詞を、出る所（会話の枠・会話のログ・途中の台詞の帯・負けの台詞の板）の幅で折り返して、
## 語の途中で切れる所も、枠の行の数を超える所も無いこと（tools/wrap_audit.gd と同じもの）。
## 台詞を足して引っ掛かったら、`godot --headless --path . -s res://tools/wrap_audit.gd -- --story` で場所を見る。

const WrapAudit := preload("res://tools/wrap_audit_lib.gd")


func test_story_lines_wrap_cleanly() -> void:
	assert_true(WrapAudit.story_lines().size() > 300, "話の台詞を読めていない")
	var found := WrapAudit.audit_story()
	assert_eq(found, [] as Array[String], "切れ方の悪い台詞:\n%s" % "\n".join(found))


## 幅の出し方の前提: 会話の枠は 2 行以上入り、途中の台詞の帯と負けの台詞の板は、名前とアイコンを引いても文の幅が残る。
func test_widths_are_sane() -> void:
	assert_true(WrapAudit.talk_max_lines() >= 2)
	assert_true(WrapAudit.cue_width("ハーデン") > 200.0)
	assert_true(WrapAudit.remark_width() > 150.0)
