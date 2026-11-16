extends RefCounted
## 画面の文の表（docs/text.md）を引く。ノードに依存しない（ルールの外の、画面・道具・テストから使う）。
##
## 文は game/text/*.csv（Godot の翻訳の仕組み。鍵 -> 文）にある。日本語 1 つだけで、文を 1 か所で読んで直すための表。
## 数や名前を差し込む文は、名前つきの差し込み（{name}）で書き、t の args で渡す（語順は表の側で決める）。
## 表に無い鍵は、鍵そのものが返る（tests/game/test_text.gd が、コードの鍵が表にあることを確かめる）。


## 鍵 key の文。args があれば、文の {名前} に差し込む。
static func t(key: String, args: Dictionary = {}) -> String:
	var text := String(TranslationServer.translate(key))
	return text if args.is_empty() else text.format(args)


## 鍵 key が表にあるか。
static func has(key: String) -> bool:
	return String(TranslationServer.translate(key)) != key


## 括弧で囲む（「（…）」。表の common.paren）。
static func paren(text: String) -> String:
	return t("common.paren", {"text": text})


## 注の並び（「（巡航・ポータル経由）」）。無ければ空。
static func notes(parts: Array) -> String:
	return "" if parts.is_empty() else paren(join_dot(parts))


## 「・」でつなぐ（表の common.joiner.dot）。
static func join_dot(parts: Array) -> String:
	return t("common.joiner.dot").join(PackedStringArray(parts))


## 「、」でつなぐ（表の common.joiner.comma）。
static func join_comma(parts: Array) -> String:
	return t("common.joiner.comma").join(PackedStringArray(parts))
