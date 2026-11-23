extends RefCounted
## 日本語の文を、決まった幅で折り返す。ノードに依存しない（幅の測り方は、呼ぶ側が渡す）。
##
## Label の自動の折り返しは、日本語では語の切れ目も禁則も見ない（「攻撃」と「力」の間や、「。」の前で切る）ので、
## 文字を出す前にここで改行を入れる。辞書は使わず、字の種類の並びを手がかりにする。決まり:
## - 行の頭に置かない文字（句読点、閉じ括弧、長音、小さい仮名など）の前と、行の末に置かない文字（開き括弧）の後では切らない。
## - 半角の空白の前後と、半角の文字どうしの間では切らない（「スキル 7 回」「HP 20 / 30」「Lv3」を 1 つに保つ）。
##   ただし、ひらがなの後の半角の空白で、次が数でも英字でもない所（「パラディンが (1, 2)」の「が」の後。名前やマスを差し込む文）と、
##   「→」の前の半角の空白は、語の切れ目とみる（空白の後で切り、行の末の空白は落とす）。
## - カタカナ（長音も）どうしの間では切らない（「ダメージ」「シールドトルーパー」を 1 語に保つ。行より長ければ、行の末で切る）。
## - 語の途中（漢字どうし「表示」、漢字・カタカナの後のひらがな「届く」「範囲を」、ひらがなどうし「まずかった」）は、
##   ほかに切れる所が無いときだけ切る。ひらがなどうしでも、「を」の後は語の切れ目とみて、助詞らしい字（ひらがなの後の「は」「が」「に」「で」）の後は、
##   語の途中よりは先に選ぶ。
## - 次の行が、ひらがな 1〜2 字と句読点（または段落の終わり）だけで始まる所（「まずかっ / た。」）も、語の途中と同じに扱う。
## - 切るなら、全角の空白・句読点の後と、開き括弧の前を優先する（行の半分より後ろにあれば、そこで切る）。
##   次に、ひらがなの後に漢字・カタカナが来る所などの語の切れ目（行の 3 分の 1 より後ろにあれば）、その次に助詞の後。
##   どれも無ければ、切れるところで切る。
## - 段落の最後の行が短すぎる（行の幅の 2 割より短い）ときは、行の数を増やさない範囲で、行の長さをそろえる（fold_even と同じ）。
## - 元からある改行は、そのまま残す。
## - 送り仮名をはさむ言葉のうち、よく出るもの（KEEP_WORDS。「縫い目」など）は、中で切らない（ひらがなの後の漢字を、語の切れ目と見誤るため）。

const NO_LINE_START := "、。，．・：；？！ー〜～）」』】〉》〕％…‥ゃゅょっャュョッ々)]}%!?,.:;"
const NO_LINE_END := "（「『【〈《〔([{"
const STRONG_BREAK_AFTER := "　。、"
## ひらがなの後にあれば、助詞らしいとみる字（その後で切るのは、語の途中よりは良い）。
## 「も」「と」「の」は語の中にも多い（「まもる」「とき」「もの」）ので入れない。「を」は助詞のほかに無いので、語の切れ目とみる。
const PARTICLES := "はがにで"
## 中で切らない言葉（送り仮名をはさむので、字の種類の並びでは 1 語と分からないもの）。
const KEEP_WORDS: Array[String] = ["縫い目", "縫い代"]
## 優先する切れ目が、行の幅のこの割合より後ろにあれば、そこで切る。
const STRONG_BREAK_RATIO := 0.5
## 語の切れ目（WEAK）と助詞の後（SOFT）が、行の幅のこの割合より後ろにあれば、そこで切る。
const WEAK_BREAK_RATIO := 0.34
## 段落の最後の行が、行の幅のこの割合より短ければ、行の長さをそろえる。
const SHORT_LAST_RATIO := 0.2
## 次の行の頭に、句読点の前のひらがなが、この字数以下だけ残るなら、語の途中とみる。
const SHORT_TAIL := 2
## fold_even が、行の長さをそろえる幅を探す回数（半分ずつ狭める）。
const EVEN_STEPS := 6

## 切れ目の良さ。LOOSE は、語の途中だが、ほかに切れる所が無いときだけ切ってよい所（漢字どうしの間など）。
## SOFT は、ひらがなが続く中の、助詞らしい字の後。WEAK は語の切れ目。STRONG は句読点・空白の後と、開き括弧の前。
## TAIL は、次の行の頭にひらがな 1〜2 字と句読点だけが残る所（語の途中よりも、さらに後回し）。
enum { NO_BREAK, TAIL, LOOSE, SOFT, WEAK, STRONG }


## text を、どの行も width に収まるように折り返す。measure は、1 文字を渡すと幅を返す Callable
## （行の幅は、文字の幅の合計で測る）。
static func fold(text: String, width: float, measure: Callable) -> String:
	var lines: Array[String] = []
	for paragraph in text.split("\n"):
		var folded := _fold_paragraph(paragraph, width, measure)
		if folded.size() > 1 and _width_of(folded[folded.size() - 1], measure) < width * SHORT_LAST_RATIO:
			folded = _even(paragraph, folded, width, measure)
		lines.append_array(folded)
	return "\n".join(lines)


## fold と同じに折り返すが、行の数を増やさない範囲で、行の長さをそろえる（最後の行が 1 語だけ残らないように）。
## 折り返さずに収まる段落と、元からある改行は、そのまま。短い案内の文（1〜2 行）に使う。
static func fold_even(text: String, width: float, measure: Callable) -> String:
	var lines: Array[String] = []
	for paragraph in text.split("\n"):
		lines.append_array(_even(paragraph, _fold_paragraph(paragraph, width, measure), width, measure))
	return "\n".join(lines)


## 折り返したあとの行の数。
static func line_count(text: String, width: float, measure: Callable) -> int:
	return fold(text, width, measure).count("\n") + 1


## text を width で折り返したときの、切れ目の良くない所（検査と点検の道具のため。tools/wrap_audit.gd）。
## 返すのは、折り返しで入れた切れ目のうち、語の途中で切った所の「前の行の末 / 次の行の頭」と、短すぎる段落の最後の行。
## 元からある改行は見ない。
static func bad_breaks(text: String, width: float, measure: Callable) -> Array[String]:
	var found: Array[String] = []
	for paragraph in text.split("\n"):
		var lines := fold(paragraph, width, measure).split("\n")
		var at := 0
		for i in range(1, lines.size()):
			var before := lines[i - 1]
			at = paragraph.find(lines[i], at + before.length())
			if at <= 0 or _break_after(paragraph, at - 1) <= LOOSE:
				found.append("%s / %s" % [before.right(6), lines[i].left(6)])
		if lines.size() > 1 and _width_of(lines[lines.size() - 1], measure) < width * SHORT_LAST_RATIO:
			found.append("%s / %s（短い）" % [lines[lines.size() - 2].right(6), lines[lines.size() - 1]])
	return found


static func _even(paragraph: String, folded: Array[String], width: float, measure: Callable) -> Array[String]:
	if folded.size() <= 1:
		return folded
	# 同じ行の数に収まる、いちばん狭い幅を探して、その幅で折り返す。
	var low := _width_of(paragraph, measure) / folded.size()
	var high := width
	for step in EVEN_STEPS:
		var middle := (low + high) / 2.0
		var tried := _fold_paragraph(paragraph, middle, measure)
		if tried.size() <= folded.size():
			high = middle
			folded = tried
		else:
			low = middle
	return folded


static func _width_of(text: String, measure: Callable) -> float:
	var total := 0.0
	for character in text:
		total += float(measure.call(character))
	return total


static func _fold_paragraph(text: String, width: float, measure: Callable) -> Array[String]:
	var lines: Array[String] = []
	var start := 0
	while start < text.length():
		# 切れ目の良さごとに、いちばん後ろの切れ目（次の行の頭の位置）と、そこまでの幅。
		var best: Array[int] = [-1, -1, -1, -1, -1, -1]
		var best_width: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
		var end := text.length()
		var used := 0.0
		for i in range(start, text.length()):
			used += float(measure.call(text[i]))
			if used > width and i > start:
				# i 文字目が入らない。良い切れ目が行の十分後ろにあればそこで、無ければ切れるところで、それも無ければここで切る。
				end = i
				if best[STRONG] > start and best_width[STRONG] >= width * STRONG_BREAK_RATIO:
					end = best[STRONG]
				elif best[WEAK] > start and best_width[WEAK] >= width * WEAK_BREAK_RATIO:
					end = best[WEAK]
				elif best[SOFT] > start and best_width[SOFT] >= width * WEAK_BREAK_RATIO:
					end = best[SOFT]
				elif best[WEAK] > start:
					end = best[WEAK]
				elif best[SOFT] > start:
					end = best[SOFT]
				elif best[LOOSE] > start:
					end = best[LOOSE]
				elif best[TAIL] > start:
					end = best[TAIL]
				break
			var kind := _break_after(text, i)
			if kind == NO_BREAK:
				continue
			# 良い切れ目は、それより弱い切れ目としても使える。
			for level in range(TAIL, kind + 1):
				best[level] = i + 1
				best_width[level] = used
		var line := text.substr(start, end - start)
		# 折り返したところの全角の空白は、行の末と次の行の頭から落とす（段落の頭の字下げは残す）。
		if end < text.length():
			line = line.rstrip("　 ")
		lines.append(line)
		start = end
		while start < text.length() and end < text.length() and text[start] == "　":
			start += 1
	if lines.is_empty():
		lines.append("")
	return lines


## text の i 文字目の後で切ってよいか、どのくらい良いか（NO_BREAK / TAIL / LOOSE / SOFT / WEAK / STRONG）。
static func _break_after(text: String, i: int) -> int:
	if i + 1 >= text.length():
		return NO_BREAK
	var here := text[i]
	var next := text[i + 1]
	if _inside_word(text, i):
		return NO_BREAK
	if _is_phrase_gap(text, i):
		return WEAK
	if _is_glue(here) or _is_glue(next) or (_is_ascii(here) and _is_ascii(next)) or (_is_katakana(here) and _is_katakana(next)):
		return NO_BREAK
	if NO_LINE_START.contains(next) or NO_LINE_END.contains(here):
		return NO_BREAK
	if _short_tail(text, i + 1):
		return TAIL
	if (_is_kanji(here) or _is_katakana(here)) and (_is_kanji(next) or _is_hiragana(next)):
		return LOOSE
	if _is_hiragana(here) and _is_hiragana(next):
		if here == "を":
			return WEAK
		var particle := i > 0 and _is_hiragana(text[i - 1]) and PARTICLES.contains(here)
		return SOFT if particle else LOOSE
	return STRONG if STRONG_BREAK_AFTER.contains(here) or NO_LINE_END.contains(next) else WEAK


## i 文字目と次の字が、KEEP_WORDS の言葉の中で並んでいるか。
static func _inside_word(text: String, i: int) -> bool:
	for word in KEEP_WORDS:
		for offset in range(1, word.length()):
			var start := i + 1 - offset
			if start >= 0 and text.substr(start, word.length()) == word:
				return true
	return false


## from 文字目から、ひらがなが SHORT_TAIL 字以下だけ続いて、句読点・閉じ括弧か段落の終わりが来るか（「た。」「よ」）。
static func _short_tail(text: String, from: int) -> bool:
	var count := 0
	var i := from
	while i < text.length() and _is_hiragana(text[i]) and not NO_LINE_START.contains(text[i]):
		count += 1
		i += 1
	if count == 0 or count > SHORT_TAIL:
		return false
	return i >= text.length() or STRONG_BREAK_AFTER.contains(text[i]) or NO_LINE_START.contains(text[i])


## i 文字目が、切ってよい半角の空白か: ひらがなの後で、次が数でも英字でもない（「が (1, 2)」）か、次が「→」。
static func _is_phrase_gap(text: String, i: int) -> bool:
	if text[i] != " " or i == 0 or i + 1 >= text.length():
		return false
	var next := text[i + 1]
	if next == "→":
		return true
	return _is_hiragana(text[i - 1]) and not _is_ascii_word(next) and not _is_glue(next) and not NO_LINE_START.contains(next)


## 半角の数か英字か。
static func _is_ascii_word(character: String) -> bool:
	var code := character.unicode_at(0)
	return (code >= 0x30 and code <= 0x39) or (code >= 0x41 and code <= 0x5a) or (code >= 0x61 and code <= 0x7a)


static func _is_glue(character: String) -> bool:
	return character == " " or character == " "


static func _is_ascii(character: String) -> bool:
	var code := character.unicode_at(0)
	return code > 0x20 and code < 0x7f


## 漢字か（「々」も）。
static func _is_kanji(character: String) -> bool:
	var code := character.unicode_at(0)
	return (code >= 0x4e00 and code <= 0x9fff) or code == 0x3005


## ひらがなか。
static func _is_hiragana(character: String) -> bool:
	var code := character.unicode_at(0)
	return code >= 0x3041 and code <= 0x3096


## カタカナか（長音・中黒を除く。中黒は語の区切り）。
static func _is_katakana(character: String) -> bool:
	var code := character.unicode_at(0)
	return (code >= 0x30a1 and code <= 0x30fa) or code == 0x30fc
