extends RefCounted
## 主人公の名前（docs/story.md の「主人公の名前」）。遊ぶ人は、物語の将（連邦のハーデン、騎士領のイェルダ）の立場に入り、名前を変えられる。
## ここは、名前の決まり（長さ、使える文字）と、文への差し込み。ノードに依存しない。
##
## - 話と物語のファイルは、文の中の主人公の名前を、差し込みの印 MARK で書く（「{hero}少尉、前へ」）。
## - 名前の長さは、名前の出る枠（会話の名前の札、対戦の途中の台詞の札、ログの札）で決まる: 全角 MAX_CHARS 字ぶんの幅まで。
##   半角の字は幅が狭いので、そのぶん多く入る（字の数は MAX_LETTERS まで）。
## - 使えない文字: 改行などの制御文字、印に使う波括弧、画面の字（本文・見出し・太字のフォント）に無い文字（絵文字など）。前後の空白は落とす。

const UiTheme := preload("res://game/ui_theme.gd")

## 文の中の、主人公の名前の差し込みの印。
const MARK := "{hero}"
## 名前の長さの上限: 全角の字の数（この幅まで）と、字の数。
const MAX_CHARS := 5
const MAX_LETTERS := 10
## 幅を測る字（名前の札の字）: [フォント, 大きさ]。talk_screen.gd の名前の札と、battle_talk.gd の名前の札。
const _FACES := [[&"body", 22], [&"bold", 15]]
## 使えない文字（差し込みの印と、話のファイルの書式に使う文字）。
const FORBIDDEN := "{}"


## いちばん幅の広い名前（文の長さと枠の検査が、これを差し込んで測る）。
static func widest() -> String:
	return char(0x3042).repeat(MAX_CHARS)  # ひらがなの「あ」（全角の字の幅）


## 文 text の差し込みの印を、名前 name に替える。
static func fill(text: String, name: String) -> String:
	return text.replace(MARK, name) if text.contains(MARK) else text


## 文 text の、いちばん長いときの字の数（印を、いちばん長い名前で数える）。話と物語のファイルの長さの検査が使う。
static func longest_length(text: String) -> int:
	return fill(text, widest()).length()


## 打たれた文 typed を、使える名前にする: 使えない文字を落とし、前後の空白を落とし、枠に入る長さで切る。空になったら空。
static func clean(typed: String) -> String:
	var kept := ""
	for i in typed.length():
		var letter := typed[i]
		if _usable(letter):
			kept += letter
	kept = kept.strip_edges()
	while kept != "" and not fits(kept):
		kept = kept.substr(0, kept.length() - 1).strip_edges()
	return kept


## 名前 name が、そのまま使えるか（clean しても変わらない、空でない）。
static func is_valid(name: String) -> bool:
	return name != "" and clean(name) == name


## 名前 name が、名前の出る枠に入る長さか。
static func fits(name: String) -> bool:
	if name.length() > MAX_LETTERS:
		return false
	for face: Array in _FACES:
		var font: Font = UiTheme.FONT_BODY if face[0] == &"body" else UiTheme.FONT_BOLD
		if _width(font, name, face[1]) > _width(font, widest(), face[1]) + 0.5:
			return false
	return true


static func _width(font: Font, text: String, font_size: int) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


static func _usable(letter: String) -> bool:
	var code := letter.unicode_at(0)
	if code < 0x20 or code == 0x7f or FORBIDDEN.contains(letter):
		return false
	if code == 0x20 or code == 0x3000:  # 半角と全角の空白
		return true
	for font: Font in [UiTheme.FONT_BODY, UiTheme.FONT_BOLD, UiTheme.FONT_HEADING]:
		if not font.has_char(code):
			return false
	return true
