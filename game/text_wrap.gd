extends RefCounted
## 日本語の文を、決まった幅で折り返す。ノードに依存しない（幅の測り方は、呼ぶ側が渡す）。
##
## Label の自動の折り返しは、日本語では語の切れ目も禁則も見ない（「攻撃」と「力」の間や、「。」の前で切る）ので、
## 文字を出す前にここで改行を入れる。決まり:
## - 行の頭に置かない文字（句読点、閉じ括弧、長音、小さい仮名など）の前と、行の末に置かない文字（開き括弧）の後では切らない。
## - 半角の空白の前後と、半角の文字どうしの間では切らない（「スキル 7 回」「HP 20 / 30」「Lv3」を 1 つに保つ）。
## - カタカナ（長音も）どうしの間では切らない（「ダメージ」「シールドトルーパー」を 1 語に保つ。行より長ければ、行の末で切る）。
## - 漢字どうしの間（「表示」「攻撃力」）と、漢字・カタカナの後のひらがな（送り仮名と助詞。「届く」「範囲を」「ダメージを」）の前は、
##   ほかに切れる所が無いときだけ切る（「表 / 示」のように語の途中で 1 文字だけ次の行へ送らない。ふつうは、ひらがなの後に
##   漢字・カタカナが来る所などの、語の切れ目で切る）。
## - 切るなら、全角の空白・句読点の後と、開き括弧の前を優先する（行の半分より後ろにあれば、そこで切る）。無ければ、切れるところで切る。
## - 元からある改行は、そのまま残す。

const NO_LINE_START := "、。，．・：；？！ー）」』】〉》〕％…‥ゃゅょっャュョッ々)]}%!?,.:;"
const NO_LINE_END := "（「『【〈《〔([{"
const STRONG_BREAK_AFTER := "　。、"
## 優先する切れ目が、行の幅のこの割合より後ろにあれば、そこで切る。
const STRONG_BREAK_RATIO := 0.5

## LOOSE は、語の途中だが、ほかに切れる所が無いときだけ切ってよい所（漢字どうしの間など）。
enum { NO_BREAK, LOOSE, WEAK, STRONG }


## text を、どの行も width に収まるように折り返す。measure は、1 文字を渡すと幅を返す Callable
## （行の幅は、文字の幅の合計で測る。呼ぶ回数は、文字の数だけ）。
static func fold(text: String, width: float, measure: Callable) -> String:
	var lines: Array[String] = []
	for paragraph in text.split("\n"):
		lines.append_array(_fold_paragraph(paragraph, width, measure))
	return "\n".join(lines)


## 折り返したあとの行の数。
static func line_count(text: String, width: float, measure: Callable) -> int:
	return fold(text, width, measure).count("\n") + 1


static func _fold_paragraph(text: String, width: float, measure: Callable) -> Array[String]:
	var lines: Array[String] = []
	var start := 0
	while start < text.length():
		var loose := -1
		var weak := -1
		var strong := -1
		var strong_width := 0.0
		var end := text.length()
		var used := 0.0
		for i in range(start, text.length()):
			used += float(measure.call(text[i]))
			if used > width and i > start:
				# i 文字目が入らない。優先する切れ目が行の半分より後ろにあればそこで、無ければ切れるところで、それも無ければここで切る。
				end = i
				if strong > start and strong_width >= width * STRONG_BREAK_RATIO:
					end = strong
				elif weak > start:
					end = weak
				elif loose > start:
					end = loose
				break
			var kind := _break_after(text, i)
			if kind == STRONG:
				strong = i + 1
				strong_width = used
				weak = i + 1
			elif kind == WEAK:
				weak = i + 1
			elif kind == LOOSE:
				loose = i + 1
		var line := text.substr(start, end - start)
		# 折り返したところの全角の空白は、行の末と次の行の頭から落とす（段落の頭の字下げは残す）。
		if end < text.length():
			line = line.rstrip("　")
		lines.append(line)
		start = end
		while start < text.length() and end < text.length() and text[start] == "　":
			start += 1
	if lines.is_empty():
		lines.append("")
	return lines


## text の i 文字目の後で切ってよいか（NO_BREAK / WEAK / STRONG）。
static func _break_after(text: String, i: int) -> int:
	if i + 1 >= text.length():
		return NO_BREAK
	var here := text[i]
	var next := text[i + 1]
	if _is_glue(here) or _is_glue(next) or (_is_ascii(here) and _is_ascii(next)) or (_is_katakana(here) and _is_katakana(next)):
		return NO_BREAK
	if NO_LINE_START.contains(next) or NO_LINE_END.contains(here):
		return NO_BREAK
	if (_is_kanji(here) or _is_katakana(here)) and (_is_kanji(next) or _is_hiragana(next)):
		return LOOSE
	return STRONG if STRONG_BREAK_AFTER.contains(here) or NO_LINE_END.contains(next) else WEAK


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
