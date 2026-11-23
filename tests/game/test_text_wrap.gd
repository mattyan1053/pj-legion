extends "res://tests/base_test.gd"
## 日本語の折り返し（game/text_wrap.gd）。幅は、全角を 2、半角を 1 と数えて測る。

const TextWrap := preload("res://game/text_wrap.gd")


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
	var text := "このターンの間、軍の全員の移動力 +2、攻撃力・回復量 +5。使うと取り消せない"
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


func test_breaks_at_space_after_particle() -> void:
	# 名前やマスを差し込むログの文: 「が」の後の半角の空白と「→」の前で切れる（空白は落とす）。数の前の空白（「を 3 ターン」）では切らない。
	assert_eq(_wrap("パラディンが (1, 2) → (5, 6) へ移動", 26.0), PackedStringArray(["パラディンが (1, 2)", "→ (5, 6) へ移動"]))
	assert_eq(_wrap("パラディンが (1, 2) → (5, 6) へ移動", 18.0), PackedStringArray(["パラディンが", "(1, 2)", "→ (5, 6) へ移動"]))
	assert_eq(TextWrap.bad_breaks("パラディンが (1, 2) → (5, 6) へ移動", 26.0, _measure), [] as Array[String])
	assert_false(_wrap("敵の本陣を 3 ターン占拠する", 16.0).has("敵の本陣を"))


func test_prefers_breaking_after_punctuation() -> void:
	# 行の末まで詰めれば「攻撃」と「力」の間で切れる幅でも、読点の後で切る。
	assert_eq(_wrap("軍の全員の移動力 +2、攻撃力 +5", 26.0), PackedStringArray(["軍の全員の移動力 +2、", "攻撃力 +5"]))


func test_keeps_newlines_and_indent() -> void:
	assert_eq(_wrap("一行目\n　MVP スナイパー Lv3", 40.0), PackedStringArray(["一行目", "　MVP スナイパー Lv3"]))


func test_line_count() -> void:
	assert_eq(TextWrap.line_count("あいうえおかきくけこ", 10.0, _measure), 2)


func test_katakana_word_stays_together() -> void:
	# 「ダメージ」を「ダメー」と「ジ」に分けない（数とつながった「ジ 0.8 倍」だけを次の行へ送らない）。
	var lines := _wrap("森にいると受けるダメージ 0.8 倍", 26.0)
	assert_true(lines[1].begins_with("ダメージ"), "カタカナの語が切れた: %s" % [lines])
	# 行より長いカタカナは、行の末で切る（はみ出さない）。
	for line in _wrap("インフィルトレーターインフィルトレーター", 12.0):
		assert_true(_measure(line) <= 12.0, "幅を超えた: %s" % line)


func test_kanji_words_and_their_kana_stay_together() -> void:
	# 「表示」を「表 / 示」にしない。漢字・カタカナの後の送り仮名と助詞（「届く」「範囲を」「ダメージを」）も、前の語から離さない。
	var text := "攻撃の届く範囲を表示中。ダメージを受ける"
	for width: float in [10.0, 12.0, 14.0, 16.0, 18.0, 20.0, 22.0, 24.0, 26.0, 30.0]:
		var lines := _wrap(text, width)
		assert_eq("".join(lines), text, "文字が変わった（幅 %s）" % width)
		for i in range(1, lines.size()):
			var tail := lines[i - 1].right(1) + lines[i].left(1)
			assert_false(tail in ["表示", "示中", "範囲", "囲を", "届く", "ジを", "攻撃", "撃の"], "語の途中で切った: %s（幅 %s）" % [lines, width])


## fold_even は、行の数を増やさずに、行の長さをそろえる（2 行目に 1 語だけ残さない）。
func test_fold_even_leaves_no_orphan_word() -> void:
	var text := "駒をクリックで選択。相手の駒は移動・攻撃の届く範囲を表示"
	var plain := TextWrap._fold_paragraph(text, 55.0, _measure)
	assert_eq(plain.size(), 2)
	assert_eq(plain[1], "表示", "前提: 行の末まで詰めると、2 行目が 1 語だけになる")
	var even := TextWrap.fold_even(text, 55.0, _measure).split("\n")
	assert_eq(even.size(), 2, "行が増えた")
	assert_eq("".join(even), text)
	for line in even:
		assert_true(_measure(line) <= 55.0, "幅を超えた: %s" % line)
	assert_true(_measure(even[1]) >= _measure(text) * 0.3, "2 行目が短いまま: %s" % even[1])


func test_fold_even_keeps_what_fits_and_newlines() -> void:
	assert_eq(TextWrap.fold_even("駒をクリックして選ぶ", 40.0, _measure), "駒をクリックして選ぶ")
	assert_eq(TextWrap.fold_even("攻撃する\n待機する", 40.0, _measure), "攻撃する\n待機する")


## fold も、段落の最後の行が短すぎれば（幅の 2 割より短い）、行の数を増やさずに長さをそろえる。
func test_fold_leaves_no_short_last_line() -> void:
	var text := "駒をクリックで選択。相手の駒は移動・攻撃の届く範囲を表示"
	var lines := _wrap(text, 55.0)
	assert_eq(lines.size(), 2, "行が増えた")
	assert_true(_measure(lines[1]) >= 55.0 * TextWrap.SHORT_LAST_RATIO, "最後の行が短いまま: %s" % [lines])


## ひらがなが続く所は、語の途中（「まずかっ / た。」）で切らない（負けの台詞の板で起きていた）。
func test_hiragana_word_is_not_split() -> void:
	var text := "ばらけて押したのがまずかった。道を 1 本に絞れ、隊長。"
	for width: float in range(16, 60, 2):
		var lines := _wrap(text, float(width))
		assert_eq("".join(lines), text, "文字が変わった（幅 %s）" % width)
		for i in range(1, lines.size()):
			assert_false(lines[i].begins_with("た。"), "語の途中で切った: %s（幅 %s）" % [lines, width])
			assert_false(lines[i - 1].ends_with("かっ") or lines[i - 1].ends_with("まず"), "語の途中で切った: %s（幅 %s）" % [lines, width])


## 次の行が、ひらがな 1〜2 字と句読点だけで始まらない（「行く / よ。」）。
func test_short_kana_tail_stays_with_its_word() -> void:
	for width: float in range(10, 40, 2):
		for line in _wrap("ここは通さないぞ。おまえたちの好きにはさせないよ。", float(width)):
			assert_false(line.begins_with("よ。") or line.begins_with("ぞ。") or line.begins_with("いよ。"), "短い尾が次の行に落ちた（幅 %s）: %s" % [width, line])


## ひらがなばかりの文では、助詞らしい字（「を」「が」）の後で切る。
func test_hiragana_breaks_after_particles() -> void:
	var lines := _wrap("おれたちがここをまもりぬくのだ", 20.0)
	assert_eq(lines.size(), 2)
	assert_true(lines[0].ends_with("が") or lines[0].ends_with("を"), "助詞の後で切っていない: %s" % [lines])


## 語の切れ目が見つからない所は、bad_breaks が拾う（点検の道具 tools/wrap_audit.gd が使う）。
func test_bad_breaks_reports_word_splits() -> void:
	# 「表示中」は、幅 4（2 文字）では語の途中で切るほかない。
	assert_eq(TextWrap.bad_breaks("表示中だ", 4.0, _measure).size(), 1)
	assert_eq(TextWrap.bad_breaks("ばらけて押したのがまずかった。", 18.0, _measure), [] as Array[String])
	# 元からある改行は見ない。
	assert_eq(TextWrap.bad_breaks("まずかっ\nた。道を", 40.0, _measure), [] as Array[String])


## 送り仮名をはさむ言葉（KEEP_WORDS の「縫い目」など）は、中で切らない。切るほかなければ、bad_breaks が拾う。
func test_keep_words_stay_together() -> void:
	# 幅 20（10 字）では「土地の縫い」で 1 行が埋まる。語の切れ目に見える「い」の後でなく、「縫い目」の前で切る。
	var lines := _wrap("少ない隊で土地の縫い目を預かる", 20.0)
	assert_true(lines[0].ends_with("の"), "縫い目の前で切っていない: %s" % [lines])
	assert_true(lines[1].begins_with("縫い目"), "縫い目を割った: %s" % [lines])
	assert_eq(TextWrap.bad_breaks("縫い目", 4.0, _measure).size(), 1)
