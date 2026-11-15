extends "res://tests/base_test.gd"
## 日本語の折り返し（prototype/text_wrap.gd）。幅は、全角を 2、半角を 1 と数えて測る。

const TextWrap := preload("res://prototype/text_wrap.gd")


func _measure(text: String) -> float:
	var width := 0.0
	for i in text.length():
		width += 1.0 if text.unicode_at(i) < 0x7f else 2.0
	return width


func _wrap(text: String, width: float) -> PackedStringArray:
	return TextWrap.fold(text, width, _measure).split("\n")


func test_short_text_is_untouched() -> void:
	assert_eq(TextWrap.fold("駒をクリックして選ぶ", 40.0, _measure), "駒をクリックして選ぶ")
	assert_eq(TextWrap.fold("", 40.0, _measure), "")


func test_every_line_fits() -> void:
	var text := "このターンの間、軍の全員の移動力 +2、攻撃力（回復量）+5。使うと取り消せない"
	for width: float in [12.0, 20.0, 31.0, 50.0]:
		for line in _wrap(text, width):
			assert_true(_measure(line) <= width, "幅 %s を超えた: %s" % [width, line])
		assert_eq("".join(_wrap(text, width)), text, "文字が変わった（幅 %s）" % width)


func test_no_punctuation_at_line_start() -> void:
	# 「。」「）」「ー」が行の頭に来る幅でも、前の文字ごと次の行へ送る。
	for width: float in [8.0, 10.0, 12.0, 14.0, 16.0, 18.0]:
		for line in _wrap("耐久 20。通行と射撃を遮る（盾）を置くメーター", width):
			assert_false(TextWrap.NO_LINE_START.contains(line[0]), "行の頭に %s（幅 %s）" % [line[0], width])
			assert_false(TextWrap.NO_LINE_END.contains(line[line.length() - 1]), "行の末に %s（幅 %s）" % [line, width])


func test_number_and_unit_stay_together() -> void:
	# 「スキル 7 回」は切らない。全角の空白で切り、その空白は落とす。
	assert_eq(_wrap("与えたダメージ 152　回復 36　スキル 7 回　必殺技 0 回", 34.0), PackedStringArray([
		"与えたダメージ 152　回復 36", "スキル 7 回　必殺技 0 回",
	]))


func test_prefers_breaking_after_punctuation() -> void:
	# 行の末まで詰めれば「攻撃」と「力」の間で切れる幅でも、読点の後で切る。
	assert_eq(_wrap("軍の全員の移動力 +2、攻撃力 +5", 26.0), PackedStringArray(["軍の全員の移動力 +2、", "攻撃力 +5"]))


func test_keeps_newlines_and_indent() -> void:
	assert_eq(_wrap("一行目\n　MVP スナイパー Lv3", 40.0), PackedStringArray(["一行目", "　MVP スナイパー Lv3"]))


func test_line_count() -> void:
	assert_eq(TextWrap.line_count("あいうえおかきくけこ", 10.0, _measure), 2)
